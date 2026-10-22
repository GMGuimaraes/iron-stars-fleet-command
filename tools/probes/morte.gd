extends SceneTree

## Sonda da ruína: a ponte do jogador morre por dentro, em fases cravadas, sem sortear nada.
##
## O pedido do comandante foi «não temos animação da nossa nave sendo destruída». A capitânia deste
## jogo É a ponte — a câmera mora dentro do rig — então destruir a nave não pode ser um estouro visto
## de fora seguido de desaparecimento: tem ser o quadro em que se está a bordo escurecendo, adernando
## e continuando a deriva. Cinco decisões são conferidas aqui, uma por seção, porque cada uma falha
## de um jeito diferente e silencioso:
##
## 1) ZERO SORTEIO. A morte anda no relógio que o chamador entrega (`morte_t += delta`) com tempos,
##    posições e tetos vindos de `MORTE_FASES` e das constantes `MORTE_*` — `create_tween` de tempo
##    real seria invisível para esta sonda e um `visual_rng` na ignição empurraria a cauda de quem
##    veio depois. As duas assinaturas são cobradas IDÊNTICAS, não apenas próximas: é a asserção mais
##    forte que existe neste repositório e a morte inteira tem de passar nela.
## 2) ESCREVER UMA VEZ. Tela morta, deck escurecido, holografia apagada: cada material é tocado na
##    ignição e não por quadro — mesma disciplina do flanco de `ponte_em_alarme`. A sonda grava o
##    albedo ANTES e cobra `darkened(0.7)` DEPOIS, e ainda roda 190 quadros extras para provar que a
##    ignição não aconteceu duas vezes (escurecer de novo seria a ponte virando tinta preta a cada
##    quadro). E o vermelho do alarme não volta por cima da tela morta: `capital_hp == 0` é
##    `capital_hp < ALARME_CASCO`, então sem a guarda de `_update_tripulacao` a ponte reacenderia em
##    alarme exatamente no quadro em que perdeu a energia.
## 3) CONTADOR, NÃO WALL-CLOCK. As cinco fases têm de nascer na ordem e no tempo da tabela, o clarão
##    tem de morrer `MORTE_CLARAO_VIDA` depois de abrir (senão o billet fica pendurado no rig e este
##    portão reprova recurso preso no encerramento), e nunca pode haver mais de dois no ar — três
##    estalamos sobrepostos em aditivo apagam o resto do quadro e a morte vira tela branca.
## 4) DENTRO E FORA. Quatro clarões são filhos do rig (queimam com a ponte); o de `t=0.82` é filho da
##    cena e fica PARADO enquanto o rig deriva — detrito colado ao casco seria a nave arrastando o
##    próprio estilhaço. A sonda prende o nó do de fora e cobra coordenada invariada com a ponte
##    tendo se movido.
## 5) Tetos EXATOS. Luz de trabalho em 0.0 a partir de `MORTE_APAGAO`, luz fria em 0.0 depois da
##    última fase, câmera de volta à posição crua a partir de `MORTE_TREMOR_FIM` (com exatidão
##    bitwise — o tremor é offset sobre `ponte_camera_base`, não sobre a posição do rig, que é a
##    assinatura de blip, mesa e abalroamento), e os três adernamentos fechados em cima do teto no
##    fim da sequência. `move_toward` devolve o alvo verbatim quando a passada ultrapassa: é por
##    isso que o número assinado aqui é o teto, não uma aproximação.
##
## Mais duas inércias que só a ruína expõe: o timão morre com o reactor (rota de `_process` muda de
## `_update_capital_ship` para `_atualizar_ruina`, e a rota é provada por quadro real, não por chamada
## direta) e o relatório de rotina não pode mais escrever «contato hostil confirmado» sobre um casco
## que afundou — cobrado no A/B em que o controle vivo muda de texto e o cadáver mantém o DERROTA.
## O que a trilha cortada e o alarme de fim de combate têm de fazer no quadro da morte, e não até a
## próxima salva, também é medido: a janela anti-spam do áudio é relógio do motor, então daqui só se
## cobra o número de PEDIDOS (um por fase, com o som que a tabela anuncia), nunca o de toques.
##
## Uso: godot --headless --path . --quit-after 1800 -s res://tools/probes/morte.gd

## Espelho das constantes de `main.gd` — a instância do jogo é não tipada (mesmo motivo em
## `tools/probes/tripulacao.gd`). Se o número aqui divergir do código, a asserção quebra: é de propósito.
const MORTE_FASES_T := [0.0, 0.40, 0.82, 1.26, 1.70]
const MORTE_FASES_FORA := [false, false, true, false, false]
const MORTE_CLARAO_VIDA := 0.6
const MORTE_DURACAO := 2.2
const MORTE_APAGAO := 0.55
const MORTE_STROBO := 0.1
const MORTE_STROBO_PICO := 1.8
const MORTE_TILT_ROLAGEM := 0.3
const MORTE_TILT_ARFAGEM := -0.16
const MORTE_TILT_GUIRADA := 0.22
const MORTE_TREMOR := 0.11
const MORTE_TREMOR_FIM := 0.9
const CORTE_RUINA := 0.7
const COR_TELA_CALMA := Color(0.03, 0.22, 0.34)
const COR_TELA_MORTA := Color(0.012, 0.014, 0.02)
const MAP_X := 320.0
const MAP_Z_FAR := -600.0
## Passo da morte: 0.02 s fecha 2,6 s em 130 quadros, e 130 é número de iteração que o
## `--quit-after 1800` cobre com folga.
const PASSO := 0.02
const QUADROS_MORTE := 130
## Deriva da seção 9: velocidade escolhida para que 2,6 s de arrasto (156 u em -z) não encostem em
## nenhum muro do campo — a deriva livre e a deriva barrada são duas asserções separadas justamente
## para o clamp não mascarar a conta do arrasto.
const DERIVA_V := Vector3(0.0, 0.0, -60.0)

var breaks := 0
var notes: Array[String] = []

func _assert(label: String, condition: bool, detail: String) -> void:
	if condition:
		notes.append("OK   %s — %s" % [label, detail])
	else:
		breaks += 1
		notes.append("QUEBRA %s — %s" % [label, detail])

func _igual(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _montar_jogo() -> Node3D:
	var game: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	await _frames(3)
	return game

## Quantas fases a tabela já anunciou neste tempo. É a mesma conta que `_atualizar_ruina` faz, mas
## escrita aqui a partir do `morte_t` que o próprio jogo devolve: conferir o CONTADOR do relógio,
## não o instante exato em que o passo de vírgula flutuante atravessa a fronteira.
func _fases_anunciadas(t: float) -> int:
	var n := 0
	for ft in MORTE_FASES_T:
		if t >= float(ft):
			n += 1
	return n

func _initialize() -> void:
	var game: Node3D = await _montar_jogo()

	# ---- 1. O chão: uma ponte viva, acesa e no timão ------------------------------------------
	_assert("ponte viva: nada condenado", not bool(game.ponte_condenada)
		and not bool(game.ponte_sem_energia) and int(game.morte_fase) == 0,
		"condenada=%s sem_energia=%s fase=%d" % [bool(game.ponte_condenada),
			bool(game.ponte_sem_energia), int(game.morte_fase)])
	var luz_trabalho_antes: float = (game.ponte_luz_trabalho as OmniLight3D).light_energy
	var luz_fria_antes: float = (game.ponte_luz_fria as OmniLight3D).light_energy
	_assert("duas luzes acesas na ponte viva", luz_trabalho_antes > 0.0 and luz_fria_antes > 0.0,
		"trabalho %0.2f / fria %0.2f" % [luz_trabalho_antes, luz_fria_antes])
	var camera_base: Vector3 = game.ponte_camera_base
	_assert("câmera cruda na base antes da morte",
		(game.ponte_camera as Camera3D).position == camera_base,
		"[%0.2f %0.2f %0.2f] contra [%0.2f %0.2f %0.2f]" % [(game.ponte_camera as Camera3D).position.x,
			(game.ponte_camera as Camera3D).position.y, (game.ponte_camera as Camera3D).position.z,
			camera_base.x, camera_base.y, camera_base.z])
	var mats: Dictionary = game.bridge_rig.get_meta("mat")
	var cores_antes: Dictionary = {}
	for chave in mats:
		var mat: StandardMaterial3D = mats[chave]
		cores_antes[chave] = mat.albedo_color
	var tela: StandardMaterial3D = game.ponte_telas
	_assert("telas vivas antes da ignição", tela.emission == COR_TELA_CALMA
		and not bool(game.ponte_em_alarme),
		"emission [%0.2f %0.2f %0.2f] alarme=%s" % [tela.emission.r, tela.emission.g,
			tela.emission.b, bool(game.ponte_em_alarme)])
	var blips_antes := (game.holo_root as Node3D).get_child_count()
	var filhos_rig_antes := (game.bridge_rig as Node3D).get_child_count()
	var filhos_cena_antes := game.get_child_count()
	_assert("mesa com um blip por casco vivo, sem clarão pendurado", blips_antes == 12
		and (game.morte_claroes as Array).is_empty(),
		"%d blips, %d clarões na lista" % [blips_antes, (game.morte_claroes as Array).size()])
	game._update_hud()
	var hud_antes: PackedStringArray = String(game.command_label.text).split("\n")
	_assert("HUD vivo lê EM COMBATE em cinco linhas", hud_antes.size() == 5
		and hud_antes[3].contains("EM COMBATE"), "[%s]" % hud_antes[3])

	# ---- 2. Ignição: tudo que é escrito uma vez, no quadro em que o casco fecha ----------------
	var rng_antes: int = game.rng.state
	var visual_antes: int = game.visual_rng.state
	var pedidos_antes := {"EXPLOSAO": int(game.audio.pedidos["EXPLOSAO"]),
		"IMPACTO": int(game.audio.pedidos["IMPACTO"]), "ALARME": int(game.audio.pedidos["ALARME"])}
	game.capital_velocity = DERIVA_V
	(game.bridge_rig as Node3D).rotation = Vector3(0.05, 0.0, -0.05)
	var rumo_ignicao: float = (game.bridge_rig as Node3D).rotation.y
	game.throttle = 0.8
	game.capital_hp = 0.0
	game.report_label.text = "DERROTA // capitânia perdida: a frota ficou sem ponte de comando."
	game._atualizar_ruina(PASSO)
	_assert("a ignição roda uma vez e congela o timão", bool(game.ponte_condenada)
		and bool(game.ponte_sem_energia) and _igual(float(game.throttle), 0.0, 0.0),
		"condenada=%s sem_energia=%s empuxo %0.2f" % [bool(game.ponte_condenada),
			bool(game.ponte_sem_energia), float(game.throttle)])
	_assert("morrer é fim de combate: trilha cortada e alarme pedido no quadro da morte",
		bool(game.batalha_encerrada) and int(game.audio.pedidos["ALARME"]) == pedidos_antes["ALARME"] + 1
			and not bool(game.audio.trilha_ao_vivo()),
		"encerrada=%s pedidos de alarme %d -> %d ao_vivo=%s" % [bool(game.batalha_encerrada),
			pedidos_antes["ALARME"], int(game.audio.pedidos["ALARME"]),
			bool(game.audio.trilha_ao_vivo())])
	_assert("telas mortas, não vermelhas: o alarme não reacende sobre o apagão",
		tela.emission == COR_TELA_MORTA and _igual(tela.emission_energy_multiplier, 0.0, 0.0),
		"emission [%0.3f %0.3f %0.3f] energia %0.2f" % [tela.emission.r, tela.emission.g,
			tela.emission.b, tela.emission_energy_multiplier])
	game._update_tripulacao()
	_assert("a guarda de energia segura a tela morta (a pose congela com ela)",
		tela.emission == COR_TELA_MORTA, "[%0.3f %0.3f %0.3f]" % [tela.emission.r,
			tela.emission.g, tela.emission.b])
	var escurecidos := 0
	for chave in ["piso", "casco", "trim", "ouro"]:
		var mat: StandardMaterial3D = mats[chave]
		var antes: Color = cores_antes[chave]
		if mat.albedo_color.is_equal_approx(antes.darkened(CORTE_RUINA)) \
				and _igual(mat.emission_energy_multiplier, 0.0, 0.0):
			escurecidos += 1
	_assert("deck apagado: soalho, casco, friso e ouro escurecidos num único traço",
		escurecidos == 4, "%d de 4 materiais em `darkened(%.1f)` sem emissão" % [escurecidos,
			CORTE_RUINA])
	var escuras := 0
	for nos in [game.holo_root, game.holo_anel, game.holo_capitania, game.holo_setor]:
		if is_instance_valid(nos) and not bool((nos as Node3D).visible):
			escuras += 1
	_assert("projetor morto: os quatro nós da holografia somem sem sumir da conta",
		escuras == 4 and (game.holo_root as Node3D).get_child_count() == blips_antes,
			"%d de 4 ocultos, mesa ainda com %d filhos" % [escuras,
				(game.holo_root as Node3D).get_child_count()])

	# ---- 3. A sequência inteira: cinco fases, nenhum sorteio ----------------------------------
	var fases_antes := int(game.morte_fase)
	var max_concorrentes := 0
	var fora_que_nasceu: MeshInstance3D = null
	var fora_pos_em_nascimento := Vector3.ZERO
	var rig_andou_desde_fora := 0.0
	var fora_parado := true
	var trabalho_positiva_ate_fim := true
	var apago_em := -1.0
	var fria_fora_do_estrobo := 0
	var fria_apagada_em := -1.0
	var viu_estrobo_aceso := false
	var viu_estrobo_apagado := false
	var camera_fora_da_base_depois_do_tremor := 0
	var maior_tremor := 0.0
	var passou_do_teto_rolagem := 0
	var passou_do_teto_arfagem := 0
	var passou_do_teto_guinada := 0
	var atraso_de_fase := 0
	var passo_da_derradeira_fase := -1.0
	var teto_de_em := -1.0
	# Comparação de VECTOR3 e não de componente: `float` em GDScript é double e a transformada do nó
	# é single, então `rotation.z == 0.3` é falso para sempre mesmo no quadro em que o motor devolveu
	# o alvo verbatim. Os três eixos de uma vez arredondam os dois lados do mesmo jeito, e é assim que
	# o teto continua assinado como número cravado e não como aproximação.
	var teto_vetor := Vector3(MORTE_TILT_ARFAGEM, rumo_ignicao + MORTE_TILT_GUIRADA,
		MORTE_TILT_ROLAGEM)
	for i in range(QUADROS_MORTE):
		game._atualizar_ruina(PASSO)
		var t: float = float(game.morte_t)
		if int(game.morte_fase) != _fases_anunciadas(t):
			atraso_de_fase += 1
		if int(game.morte_fase) > fases_antes:
			passo_da_derradeira_fase = float(i)
			fases_antes = int(game.morte_fase)
		var concorrentes := (game.morte_claroes as Array).size()
		if concorrentes > max_concorrentes:
			max_concorrentes = concorrentes
		if fora_que_nasceu == null:
			for entrada in (game.morte_claroes as Array):
				var candidato: MeshInstance3D = entrada["no"]
				if candidato.get_parent() != game.bridge_rig:
					fora_que_nasceu = candidato
					fora_pos_em_nascimento = candidato.position
		if (game.ponte_luz_trabalho as OmniLight3D).light_energy > 0.0 \
				and t > MORTE_APAGAO + 0.0001:
			trabalho_positiva_ate_fim = false
		if apago_em < 0.0 and _igual(float((game.ponte_luz_trabalho as OmniLight3D).light_energy),
				0.0, 0.0):
			apago_em = t
		var fria_atual: float = (game.ponte_luz_fria as OmniLight3D).light_energy
		if t < MORTE_FASES_T[MORTE_FASES_T.size() - 1]:
			if _igual(fria_atual, luz_fria_antes * MORTE_STROBO_PICO, 0.0001):
				viu_estrobo_aceso = true
			elif _igual(fria_atual, luz_fria_antes * 0.05, 0.0001):
				viu_estrobo_apagado = true
			else:
				fria_fora_do_estrobo += 1
		elif fria_apagada_em < 0.0 and _igual(fria_atual, 0.0, 0.0):
			fria_apagada_em = t
		var desloc := (game.ponte_camera as Camera3D).position - camera_base
		if desloc.length() > maior_tremor:
			maior_tremor = desloc.length()
		if t > MORTE_TREMOR_FIM + 0.0001 and (game.ponte_camera as Camera3D).position != camera_base:
			camera_fora_da_base_depois_do_tremor += 1
		var at: Vector3 = (game.bridge_rig as Node3D).rotation
		if teto_de_em < 0.0 and at == teto_vetor:
			teto_de_em = t
		if at.z > MORTE_TILT_ROLAGEM + 0.0001:
			passou_do_teto_rolagem += 1
		if at.x < MORTE_TILT_ARFAGEM - 0.0001:
			passou_do_teto_arfagem += 1
		if at.y > rumo_ignicao + MORTE_TILT_GUIRADA + 0.0001:
			passou_do_teto_guinada += 1
		if fora_que_nasceu != null and is_instance_valid(fora_que_nasceu):
			if fora_pos_em_nascimento.distance_to(fora_que_nasceu.position) > 0.0001:
				fora_parado = false
			rig_andou_desde_fora = maxf(rig_andou_desde_fora,
				(game.bridge_rig as Node3D).position.distance_to(Vector3(0.0, 0.0, 0.0)))
	var t_final := float(game.morte_t)
	_assert("cinco fases anunciadas no tempo da tabela e no contador do relógio",
		int(game.morte_fase) == MORTE_FASES_T.size() and atraso_de_fase == 0,
		"morte_fase=%d contra %d na tabela, %d quadros fora do contador" % [int(game.morte_fase),
			MORTE_FASES_T.size(), atraso_de_fase])
	_assert("a morte não sorteia: nem rng de combate, nem o gerador do visual",
		game.rng.state == rng_antes and game.visual_rng.state == visual_antes,
		"rng %d intacto, visual %d intacto em %d quadros" % [int(game.rng.state),
			int(game.visual_rng.state), QUADROS_MORTE + 1])
	_assert("cada fase pede o som que a tabela anuncia (quatro estouros e um impacto)",
		int(game.audio.pedidos["EXPLOSAO"]) == pedidos_antes["EXPLOSAO"] + 4
			and int(game.audio.pedidos["IMPACTO"]) == pedidos_antes["IMPACTO"] + 1,
		"EXPLOSAO %d -> %d, IMPACTO %d -> %d" % [pedidos_antes["EXPLOSAO"],
			int(game.audio.pedidos["EXPLOSAO"]), pedidos_antes["IMPACTO"],
			int(game.audio.pedidos["IMPACTO"])])
	_assert("no máximo dois clarões no ar: três sobrepostos em aditivo apagam o resto do quadro",
		max_concorrentes == 2, "concorrentes máximos = %d" % max_concorrentes)
	_assert("todo clarão apaga `MORTE_CLARAO_VIDA` depois de abrir",
		(game.morte_claroes as Array).is_empty(),
		"%d clarões vivos em t=%0.2f (última fase no quadro %0.0f)" % [(game.morte_claroes as Array).size(),
			t_final, passo_da_derradeira_fase])
	_assert("luz de trabalho zero a partir de `MORTE_APAGAO` e nunca reacendida",
		trabalho_positiva_ate_fim and _igual(apago_em, MORTE_APAGAO + PASSO, 0.021),
		"apaga no primeiro passo em %0.3f s (cravado %0.2f, passo %0.2f)" % [apago_em, MORTE_APAGAO,
			PASSO])
	_assert("luz fria estroba entre dois valores fixos e apaga com a última fase",
		fria_fora_do_estrobo == 0 and viu_estrobo_aceso and viu_estrobo_apagado
			and _igual(fria_apagada_em, MORTE_FASES_T[4], 0.021),
		"%d amostras fora do estrobo, apagada em %0.3f (fase 5 em %0.2f)" % [fria_fora_do_estrobo,
			fria_apagada_em, MORTE_FASES_T[4]])
	_assert("tremor existe, decai e devolve a câmera à posição crua com exatidão de vírgula",
		maior_tremor > 0.001 and camera_fora_da_base_depois_do_tremor == 0,
			"maior deslocamento %0.4f (amplitude por eixo %0.2f), %d quadros fora da base depois de %0.2f s" % [
				maior_tremor, MORTE_TREMOR, camera_fora_da_base_depois_do_tremor, MORTE_TREMOR_FIM])
	_assert("os três tetos fecham quando a rampa percorre a distância real, partindo de -0,05",
		teto_de_em > 0.0 and _igual(teto_de_em, MORTE_DURACAO, 0.021),
		"teto em %0.3f s (duração cravada %0.2f)" % [teto_de_em, MORTE_DURACAO])
	_assert("os três adernamentos nunca passam do teto assinado",
		passou_do_teto_rolagem == 0 and passou_do_teto_arfagem == 0 and passou_do_teto_guinada == 0,
		"%d/%d/%d passos acima de rolagem/arfagem/guinada" % [passou_do_teto_rolagem,
			passou_do_teto_arfagem, passou_do_teto_guinada])
	_assert("o clarão de fora fica parado enquanto a ponte deriva com os outros quatro",
		fora_que_nasceu != null and fora_parado and rig_andou_desde_fora > 0.0001,
			"nascido=%d parado=%s rig andou %0.3f u" % [int(fora_que_nasceu != null), fora_parado,
				rig_andou_desde_fora])

	# ---- 4. Tetos fechados em cima do número, não perto ----------------------------------------
	# O mesmo `teto_vetor` do laço: a asserção abaixo e o detector do quadro em que o teto fecha têm
	# de ler o mesmo número, senão a sonda prova duas ruínas diferentes.
	var atitudes: Vector3 = (game.bridge_rig as Node3D).rotation
	_assert("atitude final nos tetos exatos da tabela", atitudes == teto_vetor,
		"[%0.4f %0.4f %0.4f] contra o teto [%0.4f %0.4f %0.4f]" % [
			atitudes.x, atitudes.y, atitudes.z, teto_vetor.x, teto_vetor.y, teto_vetor.z])
	_assert("a sequência dura `MORTE_DURACAO` e nada continua depois dela",
		t_final > MORTE_DURACAO and _igual(float(game.morte_t), PASSO * float(QUADROS_MORTE + 1),
			0.0001),
		"%0.2f s em %d passos de %0.2f (duração cravada %0.2f)" % [t_final, QUADROS_MORTE + 1,
			PASSO, MORTE_DURACAO])

	# ---- 5. Deriva: o casco conserva a velocidade, o muro não a reescreve ----------------------
	var z_deriva: float = (game.bridge_rig as Node3D).position.z
	_assert("deriva fria sobre a última velocidade medida (sem motor, sem sorteio)",
		_igual(z_deriva, DERIVA_V.z * t_final, 0.02),
		"z %0.3f contra %0.3f = %0.0f u/s × %0.2f s" % [z_deriva, DERIVA_V.z * t_final,
			DERIVA_V.z, t_final])
	game.capital_velocity = Vector3(900.0, 0.0, 0.0)
	for i in range(60):
		game._atualizar_ruina(PASSO)
	_assert("na borda do campo o casco encosta e para, e a velocidade registrada fica honesta",
		(game.bridge_rig as Node3D).position.x == MAP_X
			and float(game.capital_velocity.x) == 900.0,
		"x %0.3f (muro %0.0f), velocidade %0.0f preservada" % [(game.bridge_rig as Node3D).position.x,
			MAP_X, float(game.capital_velocity.x)])
	var cor_piso_depois: Color = (mats["piso"] as StandardMaterial3D).albedo_color
	for i in range(60):
		game._atualizar_ruina(PASSO)
	_assert("ignição idempotente: 120 quadros de casco morto não escurecem a ponte outra vez",
		(mats["piso"] as StandardMaterial3D).albedo_color == cor_piso_depois
			and int(game.morte_fase) == MORTE_FASES_T.size()
			and (game.morte_claroes as Array).is_empty(),
		"albedo do soalfo [%0.3f %0.3f %0.3f], fases %d, clarões %d" % [
			(mats["piso"] as StandardMaterial3D).albedo_color.r,
			(mats["piso"] as StandardMaterial3D).albedo_color.g,
			(mats["piso"] as StandardMaterial3D).albedo_color.b, int(game.morte_fase),
			(game.morte_claroes as Array).size()])

	# ---- 6. HUD e relatório: a ponte perdida não volta a ser rotina ---------------------------
	game._update_hud()
	var hud_morto: PackedStringArray = String(game.command_label.text).split("\n")
	_assert("HUD da ruína lê PONTE PERDIDA nas mesmas cinco linhas", hud_morto.size() == 5
		and hud_morto[3].contains("PONTE PERDIDA"), "[%s]" % hud_morto[3])
	var relatorio_antes := String(game.report_label.text)
	_assert("com a batalha encerrada o relatório de rotina nem é candidato: a guarda está no laço",
		bool(game.batalha_encerrada) and relatorio_antes.begins_with("DERROTA")
			and bool((game.holo_root as Node3D).visible) == false,
		"encerrada=%d [%s]" % [int(bool(game.batalha_encerrada)), relatorio_antes])

	# ---- 7. Rota de `_process`: o timão morre junto com o reactor ------------------------------
	var vivo: Node3D = await _montar_jogo()
	# 119 e não 120: `_process` soma `delta` antes de ler o relógio, então a fronteira de doza
	# segundos é cruzada pela própria chamada que se está a conferir.
	vivo.battle_clock = 119.0
	vivo.report_label.text = "nada"
	vivo._process(1.0)
	_assert("controle vivo: a mesma chamada de `_process` escreve o relatório de rotina",
		String(vivo.report_label.text).begins_with("RELATÓRIO"),
		"[%s]" % String(vivo.report_label.text))
	vivo.capital_hp = 0.0
	vivo.capital_velocity = Vector3.ZERO
	var quadro_anterior := (vivo.bridge_rig as Node3D).position
	await _frames(2)
	_assert("`_process` real roteia o casco morto para a ruína (não para o timão)",
		bool(vivo.ponte_condenada) and float(vivo.morte_t) > 0.0
			and (vivo.bridge_rig as Node3D).position == quadro_anterior
			and bool((vivo.holo_root as Node3D).visible) == false,
		"condenada=%d morte %0.3f s, rig parado em [%0.2f %0.2f %0.2f], mesa visível=%d" % [
			int(bool(vivo.ponte_condenada)), float(vivo.morte_t),
			(vivo.bridge_rig as Node3D).position.x, (vivo.bridge_rig as Node3D).position.y,
			(vivo.bridge_rig as Node3D).position.z, int(bool((vivo.holo_root as Node3D).visible))])
	var alarme_aceso := false
	for i in range(240):
		await _frames(1)
		if vivo.ponte_telas.emission != COR_TELA_MORTA:
			alarme_aceso = true
	_assert("a tela morta aguenta 240 quadros de `_process`: o alarme do casco zero não reacende",
		not alarme_aceso, "[%0.3f %0.3f %0.3f] depois de 240 quadros" % [
			(vivo.ponte_telas as StandardMaterial3D).emission.r,
			(vivo.ponte_telas as StandardMaterial3D).emission.g,
			(vivo.ponte_telas as StandardMaterial3D).emission.b])
	vivo.queue_free()
	await _frames(2)

	# ---- 8. Nada fica pendurado no encerramento ------------------------------------------------
	await _frames(2)
	_assert("os cinco clarões saíram da árvore: nem no rig, nem na cena",
		(game.bridge_rig as Node3D).get_child_count() == filhos_rig_antes
			and game.get_child_count() == filhos_cena_antes,
		"rig %d filhos (chão %d), cena %d filhos (chão %d)" % [(game.bridge_rig as Node3D).get_child_count(),
			filhos_rig_antes, game.get_child_count(), filhos_cena_antes])

	notes.append("veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	for linha in notes:
		print("SONDA-MORTE: %s" % linha)
	game.queue_free()
	await _frames(2)
	quit()
