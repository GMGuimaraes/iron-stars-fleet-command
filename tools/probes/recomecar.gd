extends SceneTree

## Sonda do RECOMEÇAR: o botão que desmonta a batalha dentro da mesma ponte.
##
## O pedido do comandante foi «põe um recomeçar ao lado do pausar para facilitar os testes», e um
## botão de teste que não devolve o tabuleiro de abertura é pior que não ter botão — é uma segunda
## partida secreta cujo passado ninguém conferiu. A régua desta sonda é uma frase: depois de um
## recomeço, o jogo tem de ser INDISTINGUÍVEL de uma montagem nova. Não «parecido»: campo a campo,
## dígito a dígito, contra uma instância que acabou de abrir.
##
## 1) A RÉGUA É COMPARAÇÃO, NÃO LISTA. Existe uma instância B que nunca viu batalha. A assinatura
##    do tabuleiro de A (depois de apanhar, morrer, disparar e recomeçar) é conferida contra a
##    assinatura de B, casco a casco e campo a campo — nome, esquadrão, classe, ordem, os cinco
##    subsistemas, posição, escala. Uma lista de campos esquecida vira asserção ausente, não erro.
## 2) O CORPO SAI TODO. O reset não conhece nomes de efeito: ele varre o carimbo `de_batalha`. A
##    asserção é por CONTAGEM EXAUSTA — em tabuleiro montado o carimbo marca exatamente os doze
##    cascos, e depois do recomeço não sobra nenhum nem em `game` nem na ponte. Um estilhaço velho
##    navegando na partida nova é o defeito que nenhuma conta de dano pega.
## 3) A PINTURA DE FORMAÇÃO VOLTA À BASE. O `y` de cada casco sai de `visual_rng`, e o recomeço
##    recrava o gerador em `visual_base` antes de remontar. Prova por ESTADO, não por opinião: o
##    `visual_rng.state` depois do recomeço é o de uma montagem nova, e os doze `y` são iguais.
## 4) A BATALHA DEPOIS DO RECOMEÇO É A BATALHA DO COMEÇO. Com a mesma semente cravada nos dois
##    lados, a mesma sequência de salvas produz as mesmas seis contas e a mesma tabela de casco.
##    Se o recomeço deixasse um resto — ordem herdada, alvo morto, setor de fogo velho — a cauda
##    divergiria na primeira salva.
## 5) A PONDE MORREU, A PONDE VOLTA. Esta é a parte que nenhum teste de economia vê: a ruína escreve
##    sobre a ponte persistente (atitude, luz, tela, materiais do deck, holografia escondida). O
##    recomeço devolve o retrato gravado na ignição, e a assinatura da ponte é conferida contra B.
## 6) O QUE É DO COMANDANTE FICA. Cenário escolhido, faixa da trilha e input pendente dos campos do
##    painel NÃO são do combate. Só uma exceção, escrita de propósito: a trilha cortada pelo fim de
##    combate volta porque a batalha voltou.
##
## Uso: godot --headless --path . --quit-after 6000 -s res://tools/probes/recomecar.gd

## Espelho das constantes de `main.gd` — a instância do jogo é não tipada (mesmo motivo em
## `tools/probes/capitania.gd`). Mudar o número lá quebra a asserção aqui: é de propósito.
const NOMES_GRUPOS := ["ATAQUE", "POSTURA", "FORMAÇÕES", "MANOBRA", "ARMAMENTO", "REPAROS",
	"RECONHECIMENTO", "CENÁRIO", "TRILHA"]
const TAMANHOS := {"ATAQUE": 4, "POSTURA": 5, "FORMAÇÕES": 4, "MANOBRA": 3, "ARMAMENTO": 4,
	"REPAROS": 5, "RECONHECIMENTO": 1, "CENÁRIO": 5, "TRILHA": 4}
const SEMENTE := 1234567890
## Salvas da corrida A/B. Seis é o bastante para a cauda divergir em qualquer resto de partida.
const SALVAS := 6
## Passo da ruína: o mesmo `PASSO` de `tools/probes/morte.gd`, para anunciar as fases reais.
const PASSO_RUINA := 0.1
const QUADROS_RUINA := 24
## Tolerância de float32 lido de volta do motor (perto de 80 u o ulp é ~7,6e-6).
const FOLGA := 0.00005
## As contas zeradas com as MESMAS chaves da declaração em `main.gd`. Chave faltando não é zero: é
## uma asserção que lê nulo e aprova sozinha.
const CONTAS_ZERADAS := [
	{"aliados": 0, "aliados_feriram": 0, "hostis": 0, "hostis_feriram": 0, "vaos": 0, "pedras": 0},
	{"lancados": 0, "detonados": 0, "bloqueados": 0, "rachadas": 0, "cascos": 0, "dano": 0.0},
	{"lancados": 0, "abatidos": 0, "bloqueados": 0, "pousados": 0, "no_vao": 0, "feridos": 0,
		"dano": 0.0},
	{"salvas": 0, "lancados": 0, "feriram": 0, "no_vao": 0, "parados": 0, "dano": 0.0},
]
const CONTAS_NOMES := ["salva_contagem", "missil_contagem", "caca_contagem", "capitania_contagem"]

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

## Botões de um grupo do painel, contados dentro do corpo — o mesmo instrumento de
## `tools/probes/capitania.gd`, porque o contrato de 35 comandos só vale se a contagem for a que
## `menu.gd` faz: `Label` no corpo não é comando, e botão no trilho de cima não entra na conta.
func _botoes(game, nome: String) -> int:
	var total := 0
	var corpo: Control = game.group_bodies[nome]
	for filho in corpo.get_children():
		if filho is Button:
			total += 1
	return total

func _montar_jogo() -> Node3D:
	var game: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	# Congelar por `process_mode`, nunca por `set_process(false)` (lei de `congelamento.gd`). Aqui o
	# congelamento tem outro motivo além do tempo de voo: um `_process` rodando entre a morte e o
	# recomeço escreveria atitude na ponte já içada, e a asserção 5 passaria a medir o azar.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(3)
	game._update_bridge(0.0)
	# O HUD é escrito à mão em toda sonda: sem isto o letreiro de uma instância parada seria o
	# inicial de `_build_ui`, não a leitura do tabuleiro, e a comparação dos dois lados mentiria.
	game._update_hud()
	return game

## Uma linha por casco, nos dois grupos. É a assinatura do tabuleiro: se os dois lados divergem em
## um caractere, a comparação da seção 1 falha e a nota diz QUAL linha.
func _assinatura_cascos(game) -> Array[String]:
	var linhas: Array[String] = []
	for grupo in [game.fleet, game.enemies]:
		for unit in grupo:
			var node: Node3D = unit["node"]
			var p := node.position
			var e := node.scale
			var linha: String = "%s|%s|%s|%s|%s|%0.3f|%0.3f|%0.3f|%0.3f|%0.3f|%0.3f|%0.4f,%0.4f,%0.4f|%0.4f,%0.4f,%0.4f" % [
				unit["name"], unit["squadron"], unit["team"], unit["order"],
				str(unit["classe"]) if unit.has("classe") else str(unit["role"]),
				float(unit["hp"]), float(unit["max_hp"]), float(unit["engines"]),
				float(unit["weapons"]), float(unit["crew"]), float(unit["repair"]),
				p.x, p.y, p.z, e.x, e.y, e.z]
			linhas.append(linha)
	return linhas

## Os escalares e as contas que definem «partida nova». Tudo que o RECOMEÇAR escreve à mão.
func _assinatura_estado(game) -> Array[String]:
	var linhas: Array[String] = []
	linhas.append("formacao=%s fogo=%d escopo=%s alvo=%d reserva=%s encour=%d porta=%d" % [
		game.formation, int(game.fogo_densidade), game.selection_scope, int(game.selected_target),
		bool(game.reserve_mode), int(game.encoracados), int(game.porta_avioes)])
	linhas.append("postura=%s foco=%d nota=%s" % [game.hostile_posture, int(game.hostile_focus),
		game.tactical_note])
	linhas.append("voo=%0.3f hp=%0.3f vel=%0.4f,%0.4f,%0.4f ram=%d pausada=%s encerrada=%s" % [
		float(game.throttle), float(game.capital_hp), float(game.capital_velocity.x),
		float(game.capital_velocity.y), float(game.capital_velocity.z),
		(game.ram_windows as Dictionary).size(), bool(game.paused), bool(game.batalha_encerrada)])
	linhas.append("clock=%0.4f fire=%0.4f resumo=%s alcance=%s setor=%0.4f,%0.4f,%0.4f" % [
		float(game.battle_clock), float(game.fire_clock), game.salva_resumo,
		bool(game.capitania_em_alcance), float(game.setor_fogo_pos.x),
		float(game.setor_fogo_pos.y), float(game.setor_fogo_pos.z)])
	linhas.append("listas=%d/%d/%d/%d/%d prox=%d/%d recon=%d/%d/%0.3f blips=%d" % [
		(game.fleet as Array).size(), (game.enemies as Array).size(),
		(game.misseis as Array).size(), (game.cacas as Array).size(),
		(game.probes as Array).size(), int(game.missil_proximo_id), int(game.caca_proximo_id),
		int(game.recon_contacts), int(game.recon_total), float(game.recon_progress),
		(game.holo_blips as Dictionary).size()])
	var i := 0
	for chave in CONTAS_NOMES:
		linhas.append("%s=%s" % [chave, str(game[chave])])
		i += 1
	return linhas

## A fotografia da ponte, lida dos mesmos nós que `_gravar_base_da_ponte` lê. Não é cópia da
## constante: é o valor vivo, para que a instância B seja o gabarito.
func _assinatura_ponte(game) -> Array[String]:
	var linhas: Array[String] = []
	var rig: Node3D = game.bridge_rig
	var r := rig.position
	var t := rig.rotation
	linhas.append("rig=%0.4f,%0.4f,%0.4f rot=%0.4f,%0.4f,%0.4f" % [r.x, r.y, r.z, t.x, t.y, t.z])
	var c: Vector3 = game.ponte_camera.position
	linhas.append("camera=%0.4f,%0.4f,%0.4f" % [c.x, c.y, c.z])
	linhas.append("luz=%0.4f,%0.4f" % [float(game.ponte_luz_trabalho.light_energy),
		float(game.ponte_luz_fria.light_energy)])
	var tela: StandardMaterial3D = game.ponte_telas
	linhas.append("tela=%s|%s|%0.4f" % [str(tela.albedo_color), str(tela.emission),
		float(tela.emission_energy_multiplier)])
	var mats: Dictionary = rig.get_meta("mat")
	var chaves: Array = mats.keys()
	chaves.sort()
	for chave in chaves:
		var mat: StandardMaterial3D = mats[chave]
		linhas.append("mat:%s=%s|%s|%0.4f" % [str(chave), str(mat.albedo_color), str(mat.emission),
			float(mat.emission_energy_multiplier)])
	for i in range(4):
		var no: Node3D = [game.holo_root, game.holo_anel, game.holo_capitania,
			game.holo_setor][i]
		linhas.append("holo:%d=%s" % [i, str(no.visible)])
	linhas.append("morte=%s sem_energia=%s alarme=%s t=%0.3f fase=%d claroes=%d" % [
		bool(game.ponte_condenada), bool(game.ponte_sem_energia), bool(game.ponte_em_alarme),
		float(game.morte_t), int(game.morte_fase), (game.morte_claroes as Array).size()])
	return linhas

func _compara(rotulo: String, a: Array, b: Array) -> void:
	var igual := a.size() == b.size()
	var primeiro := ""
	if igual:
		for i in range(a.size()):
			if str(a[i]) != str(b[i]):
				igual = false
				primeiro = "linha %d: A=%s B=%s" % [i, str(a[i]), str(b[i])]
	else:
		primeiro = "contagem A=%d B=%d" % [a.size(), b.size()]
	_assert(rotulo, igual, primeiro if not igual else "%d campos idênticos" % a.size())

## Conta os corpos carimbados nos dois pais que a var varre. `self` é o jogo, `bridge_rig` é a
## ponte — é onde cada ponto de `add_child` carimbado pendura o corpo.
func _carimbados(game) -> Array:
	var nos: Array = []
	for pai in [game, game.bridge_rig]:
		for filho in (pai as Node).get_children():
			if filho.has_meta("de_batalha"):
				nos.append(filho)
	return nos

## O que a lei proíbe: um corpo carimbado que não é casco da esquadra remontada. Explosion,
## clarão, sonda, míssil, caça ou traço velho. Os doze cascos são carimbados de propósito (a
## montagem nova os içaria de novo), então carimbo sozinho não é resto — resto é carimbo fora da
## lista viva.
func _resto_da_batalha(game) -> Array:
	var cascos: Array = []
	for grupo in [game.fleet, game.enemies]:
		for unit in grupo:
			cascos.append(unit["node"])
	var resto: Array = []
	for no in _carimbados(game):
		if not cascos.has(no):
			resto.append(no)
	return resto

## Avança a ruína inteira e devolve o máximo de clarões visto no caminho: o clarão vive
## `MORTE_CLARAO_VIDA` e se apaga sozinho, então medir a sequência só no último quadro é medir a
## cinza, não o incêndio.
func _matar_ponte(game) -> int:
	game.capital_hp = 0.0
	var max_claroes := 0
	for i in range(QUADROS_RUINA):
		game._atualizar_ruina(PASSO_RUINA)
		max_claroes = maxi(max_claroes, (game.morte_claroes as Array).size())
	return max_claroes

## Deixa a partida A com passado: dispara, escolhe cenário, inclina a ponte, escolta um casco e
## digita um destino. É o que torna a comparação uma prova em vez de um retrato de duas inocências.
func _apanhar_batalha(game) -> void:
	game.rng.seed = SEMENTE
	# `fogo_densidade` é ÍNDICE de `FOGO_RAIO` (0 disco estreito, 2 largo), não degrau 1..3: cravar 3
	# aqui era o que estourava o array dentro de `_pontos_de_impacto`.
	game.fogo_densidade = 2
	game._resolve_volley()
	game._resolve_volley()
	game._montar_cenario("CINTURAO")
	game._set_formation("COLUNA")
	game.hostile_posture = "CONCENTRAR"
	# A escolta entra pelo caminho do painel, não pela variavel: `protected_unit_index` é derivado
	# do seletor em `_rebuild_selectors`, e é essa derivação que a seção 7 confere depois do recomeço.
	game.protected_selector.select(3)
	game._on_protected_selected(3)
	game.subsystem_selector.select(1)
	game.position_x_input.value = 25.0
	game.position_z_input.value = -44.0
	game.paused = true
	game.throttle = 0.62
	game.capital_velocity = Vector3(1.5, 0.0, -3.0)
	game.battle_clock = 11.25
	game.fire_clock = 4.5
	game.salva_resumo = "31/42 impactos"
	game.capitania_em_alcance = true
	game.misseis.append({"id": 99})
	game.cacas.append({"id": 77})
	game.probes.append({"id": 55})
	game.ram_windows[7] = 1.0

func _initialize() -> void:
	var base: Node3D = await _montar_jogo()
	var novo: Node3D = await _montar_jogo()

	# ─── 1) o botão existe, fica ao lado do PAUSAR e não inchou o painel ────────────────────
	var pv: Node = base.pause_button
	var rv: Node = base.restart_button
	var mesmo_trilho := is_instance_valid(pv) and is_instance_valid(rv) \
		and pv.get_parent() == rv.get_parent()
	var ordem := false
	if mesmo_trilho:
		var irmaos: Array = pv.get_parent().get_children()
		ordem = irmaos.find(pv) + 1 == irmaos.find(rv)
	_assert("recomeçar ao lado do pausar", mesmo_trilho and ordem,
		"mesmo trilho=%s RECOMEÇAR logo depois de PAUSAR=%s" % [mesmo_trilho, ordem])
	_assert("rótulo e ligação do botão", str(rv.text) == "RECOMEÇAR" \
		and int((rv as Button).pressed.get_connections().size()) == 1,
		"texto=%s conexões=%d (um só clique, nenhum duplicado por retrabalho)" % [str(rv.text),
			(rv as Button).pressed.get_connections().size()])
	var botoes := 0
	var tamanhos_ok := true
	var corpo_armamento := ""
	for nome in NOMES_GRUPOS:
		var n := _botoes(base, nome)
		botoes += n
		if n != int(TAMANHOS[nome]):
			tamanhos_ok = false
		if nome == "ARMAMENTO":
			corpo_armamento = "%d botões + %d nós no corpo" % [n,
				(base.group_bodies[nome] as Control).get_child_count()]
	_assert("painel ainda 9 grupos / 35 comandos", botoes == 35 and NOMES_GRUPOS.size() == 9,
		"%d botões contados só dentro dos corpos dos grupos: o contador de menu.gd não vê top_row" % botoes)
	_assert("nenhum grupo ganhou ou perdeu filho", tamanhos_ok,
		"per grupo, %s — o letreiro do canhão é Label e não entra na conta de comandos" % corpo_armamento)

	# ─── 2) tabuleiro indistinguível de uma montagem nova, campo a campo ────────────────────
	_apanhar_batalha(base)
	base._recomecar_batalha()
	await _frames(3)
	_compara("recomeço: cascos campo a campo", _assinatura_cascos(base), _assinatura_cascos(novo))
	_compara("recomeço: estado campo a campo", _assinatura_estado(base), _assinatura_estado(novo))
	var zeradas := true
	var qual_zerada := ""
	for i in range(CONTAS_ZERADAS.size()):
		if str(base[CONTAS_NOMES[i]]) != str(CONTAS_ZERADAS[i]):
			zeradas = false
			qual_zerada = CONTAS_NOMES[i]
	_assert("contas zeram com as chaves da declaração", zeradas,
		qual_zerada if not zeradas else "as quatro contas fecham em zero chave a chave")
	var nomes_unicos := {}
	for unit in base.fleet:
		nomes_unicos[unit["name"]] = true
	for unit in base.enemies:
		nomes_unicos[unit["name"]] = true
	_assert("cascos remontados sem sufixo de nome", nomes_unicos.size() == 12,
		"%d nomes distintos entre 12 cascos: remove_child antes de queue_free devolveu os nomes" % nomes_unicos.size())

	# ─── 3) o corpo da batalha inteira saiu ────────────────────────────────────────────────
	# O gabarito desta conta é montado com o MESMO cinturão do lado A: sem ele a comparação medir
	# o mapa (pedras a mais) em vez do resto da batalha. Cenário é escolha do comandante e fica.
	var gab: Node3D = await _montar_jogo()
	gab._montar_cenario("CINTURAO")
	await _frames(2)
	var antes := _carimbados(gab).size()
	var resto := _resto_da_batalha(base)
	_assert("carimbo cobre exatamente os doze cascos", antes == 12,
		"tabuleiro montado tem %d nós com meta de_batalha, nem um a mais" % antes)
	_assert("nenhum corpo de batalha sobra depois do recomeço", resto.is_empty() \
		and _carimbados(base).size() == antes,
		"%d carimbados fora da lista viva (%s) e %d no total contra %d da montagem nova" % [
			resto.size(), str(resto), _carimbados(base).size(), antes])
	_assert("conta de filhos volta ao valor de uma montagem nova",
		base.get_child_count() == gab.get_child_count() \
			and base.bridge_rig.get_child_count() == gab.bridge_rig.get_child_count(),
		"jogo A=%d gabarito=%d • ponte A=%d gabarito=%d" % [base.get_child_count(),
			gab.get_child_count(), base.bridge_rig.get_child_count(),
			gab.bridge_rig.get_child_count()])

	# ─── 4) a pintura de formação volta à base, por estado do gerador ───────────────────────
	_assert("visual_rng recrava na base da esquadra",
		int(base.visual_rng.state) == int(novo.visual_rng.state),
		"estado A=%d B=%d — os doze sorteios do y saem de novo da mesma base" % [
			int(base.visual_rng.state), int(novo.visual_rng.state)])
	var ys_iguais := true
	for i in range(base.fleet.size()):
		if not _igual(float((base.fleet[i]["node"] as Node3D).position.y),
				float((novo.fleet[i]["node"] as Node3D).position.y), FOLGA):
			ys_iguais = false
		if not _igual(float((base.enemies[i]["node"] as Node3D).position.y),
				float((novo.enemies[i]["node"] as Node3D).position.y), FOLGA):
			ys_iguais = false
	_assert("os doze y da esquadra são os da abertura", ys_iguais,
		"comparados com folga de %s contra a montagem nova" % [str(FOLGA)])

	# ─── 5) a batalha depois do recomeço é a batalha do começo ─────────────────────────────
	var a: Node3D = await _montar_jogo()
	var b: Node3D = await _montar_jogo()
	_apanhar_batalha(a)
	a._recomecar_batalha()
	await _frames(3)
	# O cenário é escolha do comandante e fica (seção 7), então os dois lados precisam de MESMA
	# faixa de pedra para que a salva compare a batalha, não o mapa. `_montar_cenario` não sorteia.
	b._montar_cenario("CINTURAO")
	a.rng.seed = SEMENTE
	b.rng.seed = SEMENTE
	for i in range(SALVAS):
		a._resolve_volley()
		b._resolve_volley()
	_compara("%d salvas com a mesma semente: cascos" % SALVAS,
		_assinatura_cascos(a), _assinatura_cascos(b))
	_compara("%d salvas com a mesma semente: estado e contas" % SALVAS,
		_assinatura_estado(a), _assinatura_estado(b))
	_assert("a salva recomeçada não herda resto de partida",
		int(a.salva_contagem["aliados"]) > 0 and int(a.salva_contagem["aliados"]) \
			== int(b.salva_contagem["aliados"]),
		"linhas atiraram nos dois lados: A=%d B=%d" % [int(a.salva_contagem["aliados"]),
			int(b.salva_contagem["aliados"])])

	# ─── 6) a ponte morreu e voltou: a pintura da ruína é devolvida ─────────────────────────
	var c: Node3D = await _montar_jogo()
	var claroes_na_ruina := _matar_ponte(c)
	_assert("antes do recomeço a ruína pintou", bool(c.ponte_condenada) \
		and int(c.morte_fase) == 5 and claroes_na_ruina > 0 \
		and not bool((c.holo_root as Node3D).visible),
		"condenada=%s fase=%d clarões no caminho=%d holografia visível=%s" % [bool(c.ponte_condenada),
			int(c.morte_fase), claroes_na_ruina, str((c.holo_root as Node3D).visible)])
	c._recomecar_batalha()
	await _frames(3)
	_compara("ponte restaurada, nó a nó e material a material",
		_assinatura_ponte(c), _assinatura_ponte(novo))
	_assert("a ruína apagou antes dos relógios", not bool(c.ponte_condenada) \
		and float(c.morte_t) == 0.0 and int(c.morte_fase) == 0 \
		and (c.morte_claroes as Array).size() == 0,
		"condenada=%s t=%0.3f fase=%d clarões=%d" % [bool(c.ponte_condenada), float(c.morte_t),
			int(c.morte_fase), (c.morte_claroes as Array).size()])

	# ─── 7) cenário, trilha e input do comandante ficam onde ele os deixou ──────────────────
	var d: Node3D = await _montar_jogo()
	var e: Node3D = await _montar_jogo()
	d._montar_cenario("CINTURAO")
	e._montar_cenario("CINTURAO")
	d._nova_rocha(Vector3(0.0, 0.0, -70.0), 3.0, Vector3.ZERO, 0, 0.0)
	d._desenhar_setor_de_fogo()
	d.subsystem_selector.select(2)
	d.position_x_input.value = 25.0
	d.protected_selector.select(3)
	d._on_protected_selected(3)
	d.rng.seed = SEMENTE
	d._resolve_volley()
	d._recomecar_batalha()
	await _frames(3)
	_assert("o cenário escolhido continua escolhido", str(d.cenario_atual) == "CINTURAO" \
		and (d.rochas as Array).size() == (e.rochas as Array).size() \
		and int(d.rocha_proxima_id) == int(e.rocha_proxima_id),
		"cenário=%s pedras A=%d B=%d • ids A=%d B=%d" % [str(d.cenario_atual),
			(d.rochas as Array).size(), (e.rochas as Array).size(), int(d.rocha_proxima_id),
			int(e.rocha_proxima_id)])
	# A pedra rachada pela salva some do mapa e o id volta a zero: a janela de abalroamento é
	# chaveada por id, e uma pedra nova herdando a janela do destroço velho acordaria protegida
	# contra uma colisão que nunca aconteceu.
	var rochas_iguais := (d.rochas as Array).size() == (e.rochas as Array).size()
	for i in range(mini((d.rochas as Array).size(), (e.rochas as Array).size())):
		var ra: Dictionary = d.rochas[i]
		var rb: Dictionary = e.rochas[i]
		var pa: Vector3 = ra["pos"]
		var pb: Vector3 = rb["pos"]
		if int(ra["id"]) != int(rb["id"]) or int(ra["geracao"]) != int(rb["geracao"]) \
			or not _igual(float(ra["integridade"]), float(rb["integridade"]), FOLGA) \
			or not _igual(pa.x, pb.x, FOLGA) or not _igual(pa.y, pb.y, FOLGA) \
			or not _igual(pa.z, pb.z, FOLGA):
			rochas_iguais = false
	_assert("o mapa volta sem as rachaduras da batalha", rochas_iguais,
		"id, geração, integridade e posição pedra a pedra contra o cinturão da montagem nova")
	_assert("o input pendente do painel sobrevive", int(d.subsystem_selector.selected) == 2 \
		and _igual(float(d.position_x_input.value), 25.0, FOLGA),
		"subsistema=%d campo x=%0.1f — apagar o que ele digitou seria trocar escolha por reset" % [
			int(d.subsystem_selector.selected), float(d.position_x_input.value)])
	_assert("a escolta sobrevive pelo nome e rederiva o mesmo índice",
		int(d.protected_unit_index) == 2 and str(d.protected_selector.get_item_text(
			int(d.protected_selector.selected))) == "ALIADA 03",
		"índice=%d e seletor=%s: _rebuild_selectors procura o nome escolhido, não guarda a posição" % [
			int(d.protected_unit_index), str(d.protected_selector.get_item_text(
				int(d.protected_selector.selected)))])
	var d2: Node3D = await _montar_jogo()
	d2._encerra_batalha()
	_assert("o fim de combate corta a trilha", not bool(d2.audio.trilha_ao_vivo()),
		"pedidos de trilha=%d" % int(d2.audio.pedidos["TRILHA"]))
	var pedidos_antes := int(d2.audio.pedidos["TRILHA"])
	d2._recomecar_batalha()
	_assert("a trilha cortada volta porque a batalha voltou",
		bool(d2.audio.trilha_ao_vivo()) and int(d2.audio.pedidos["TRILHA"]) == pedidos_antes + 1 \
			and _igual(float(d2.audio.trilha_player.volume_db), float(novo.audio.trilha_player.volume_db), 0.001),
		"pedidos %d → %d, volume devolvido ao valor da montagem nova" % [pedidos_antes,
			int(d2.audio.pedidos["TRILHA"])])
	var vivo: Node3D = await _montar_jogo()
	var ao_anto := int(vivo.audio.pedidos["TRILHA"])
	vivo._recomecar_batalha()
	_assert("com a trilha já viva o recomeço não pede de novo",
		int(vivo.audio.pedidos["TRILHA"]) == ao_anto,
		"pedidos=%d antes e depois: um recomeço não reinicia a frase no meio" % ao_anto)

	# ─── 8) o HUD honesto e o recomeço duplo ───────────────────────────────────────────────
	_assert("command_label continua com cinco linhas",
		str(base.command_label.text).split("\n").size() == 5,
		"%d linhas: morte, ia e caças indexam o texto por posição" % str(base.command_label.text).split("\n").size())
	base._update_hud()
	_assert("o painel recomeçado diz o que o tabuleiro é",
		str(base.salva_resumo) == "0/0 impactos" \
			and str(base.report_label.text).begins_with("RECOMEOU") \
			and str(base.pause_button.text) == "PAUSAR [ESPAÇO]",
		"resumo=%s botão=%s relatório=%s" % [str(base.salva_resumo), str(base.pause_button.text),
			str(base.report_label.text)])
	_compara("leitura da capitânia volta ao piso", [str(base.capitania_label.text)],
		[str(novo.capitania_label.text)])
	_apanhar_batalha(base)
	base._recomecar_batalha()
	base._recomecar_batalha()
	await _frames(3)
	_compara("recomeço duplo não acumula resto", _assinatura_cascos(base), _assinatura_cascos(novo))
	_compara("recomeço duplo não acumula estado", _assinatura_estado(base), _assinatura_estado(novo))
	_assert("recomeço duplo não deixa corpo", _resto_da_batalha(base).is_empty(),
		"%d corpos de batalha depois de dois recomeços seguidos" % _resto_da_batalha(base).size())

	for linha in notes:
		print(linha)
	print("SONDA-RECOMECAR: veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	quit()
