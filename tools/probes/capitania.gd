extends SceneTree

## Sonda do canhão da capitânia: a ponte que é corpo no tabuleiro e agora também é boca de fogo.
##
## O pedido do comandante foi «a minha nave também deve atirar». Um casco que só leva dano e não
## devolve nada é um alvo, não uma nau capitânea, então esta peça cobra as consequências que fazem
## do canhão dela uma arma da ponte e não um bônus pintado por cima da batalha:
##
## 1) INÉRCIA NA ABERTURA. A capitânia abre a cena a ~83 u do hostil comandado e o alcance dela é
##    60 u. No tabuleiro de abertura ela não atira, não move um sorteio e não escreve cláusula no
##    resumo — é o piso que deixa as dezoito sondas antigas conferíveis dígito a dígito. O canhão
##    só acorda quando o comandante AVANÇA a ponte ou o hostil fecha para abalroar: alcance é ordem
##    de voo, não interruptor de conveniência.
## 2) UMA RÉGUA SÓ. O letreiro do painel e a salva medem a MESMA grandeza pela MESMA função
##    (`_capitania_alcance`). Dois números de alcance — um pintado, outro cobrado — mentiriam um
##    para o outro, e o comandante leria «atirei e não aconteceu nada». A porta é `<=`: a 60,0 u
##    exatos ela atira, a 60,002 u não.
## 3) SEM FÓRMULA PARALELA. O dano dela sai de `_dano_de_canhao(CAPITAL_CANHAO)`, o mesmo canhão da
##    linha, pelo mesmo disco `_pontos_de_impacto`, pela mesma barreira e pela mesma escolha de
##    casco. Medido com a linha desarmada: o hostil perde exatamente o que a função anuncia.
## 4) ELA PAGA O PREÇO DO DESENHO. Lance aliado consome dois `rng.randf_range(-1, 1)` no
##    `_spawn_bolt`. Três lances dela custam seis sorteios, e a prova é por REPRODUÇÃO DE ESTADO: o
##    estado depois da salva fora de alcance, adiantado à mão em seis sorteios, é o estado depois da
##    salva dentro do alcance. Não é contagem deduzida — é a cauda conferida.
## 5) A CONTA DELA FECHA. `feriram + no vão + parados == lançados` em tabuleiro de acerto, em
##    tabuleiro de pedra no corredor e em DISPERSAR, sempre conferido contra a PREDIÇÃO feita pelas
##    funções puras antes do tiro. E o agregado da ponte (`salva_contagem`) recebe os lances dela:
##    canhão de capitânia é fogo aliado, não uma segunda categoria de relatório.
##
## A lei da casa está toda aqui: o seletor de subsistema do painel é a ordem que a ponte dá aos
## cascos DELA, não ao próprio casco dela — torre de linha bate casco e ponto. A pedra não sabe quem
## atirou e cobra a mesma integridade dos dois lados. E o quadro de comando continua com cinco
## linhas: a cláusula `capitânia:` entra embutida na linha da última salva, porque `morte`, `ia` e
## `caças` indexam o texto do HUD por posição.
##
## Uso: godot --headless --path . --quit-after 6000 -s res://tools/probes/capitania.gd

## Espelho das constantes de `main.gd` — a instância do jogo é não tipada (mesmo motivo em
## `tools/probes/misseis.gd`). Mudar o número lá quebra a asserção aqui: é de propósito.
const CAPITAL_ALCANCE := 60.0
const CAPITAL_CANHAO := {"weapons": 100.0, "crew": 100.0, "classe": "CRUZADOR"}
const DANO_NOMINAL := 2.5
const FLECHAS_POR_SALVA := 3
const FOGO_RAIO := [4.5, 14.0, 28.0]
const ROCHA_INTEGRIDADE_POR_RAIO := 6.0
const SEMENTE := 1234567890
## Tolerância de float32 lida de volta do motor: perto de 80 u o ulp é ~7,6e-6.
const FOLGA := 0.00005
## Nove grupos e trinta e seis comandos: a capitânia ganha um letreiro, não um botão — `Label` é
## filho do corpo do grupo e o contador de `tools/probes/menu.gd` só enxerga `Button`.
const NOMES_GRUPOS := ["ATAQUE", "POSTURA", "FORMAÇÕES", "MANOBRA", "ARMAMENTO", "REPAROS",
	"RECONHECIMENTO", "CENÁRIO", "TRILHA"]
const TAMANHOS := {"ATAQUE": 4, "POSTURA": 5, "FORMAÇÕES": 4, "MANOBRA": 4, "ARMAMENTO": 4,
	"REPAROS": 5, "RECONHECIMENTO": 1, "CENÁRIO": 5, "TRILHA": 4}

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
	# Congelar por `process_mode`, nunca por `set_process(false)`: chamado dentro de `_initialize`,
	# o `set_process` é engolido porque `add_child` ainda não completou o `_ready`. Lei medida em
	# `tools/probes/congelamento.gd`. Sem o congelamento, dois tabuleiros que deviam diferir só pela
	# distância da ponte difeririam também pelo tempo de voo decorrido entre as duas medições.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(3)
	game._update_bridge(0.0)
	# Precondition da fatia 3, declarada sem afrouxar nenhum número: esta sonda mede a aritmética
	# do canhão, e com a casca de pé todo lance abaixo de 20,0 morde nela em vez de chegar a `hp`.
	# Despido o tabuleiro, cada número daqui volta a ser o de antes, dígito a dígito — a muralha em
	# si é cobrada por `tools/probes/escudo.gd`, com a casca armada.
	for casca_lista in [game.fleet, game.enemies]:
		for casca_unidade in casca_lista:
			casca_unidade["escudo"] = 0.0
			casca_unidade["escudo_max"] = 0.0
			casca_unidade["escudo_cai"] = 0.0
	return game

func _alinhar(game) -> void:
	for i in range(game.fleet.size()):
		(game.fleet[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 5.0, 0.0, -38.0)
	for i in range(game.enemies.size()):
		(game.enemies[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 6.0, 0.0, -82.0)

## Blindagem de laboratório: 500 de casco em todo corpo. Não é conveniência — é a condição de
## validade das asserções de conta e de RNG: morto um casco na janela, muda o número de salvas
## hostis, muda a cadeia de sorteios, e a medição deixaria de provar o canhão da ponte.
func _blindar(game) -> void:
	for list in [game.fleet, game.enemies]:
		for unit in list:
			unit["hp"] = 500.0
			unit["engines"] = 100.0
			unit["weapons"] = 100.0
			unit["crew"] = 100.0
			unit["veloc"] = Vector3.ZERO
	game.capital_hp = 100.0
	game.batalha_encerrada = false

## Linha e hostil sem canhão: resta o canhão da capitânia como única fonte de dano do tabuleiro, e a
## escada de `elif` da retaliação hostil (`rng.randf()`, um a três sorteios por casco atingido) sai
## de cena. É o que transforma o preço de RNG em contagem exata em vez de média.
func _desarmar(game) -> void:
	for list in [game.fleet, game.enemies]:
		for unit in list:
			unit["weapons"] = 0.0

## Tabuleiro padrão das seções de medida: alinhado, blindado, desarmado, alvo comandado a `dist`
## unidades da ponte (que abre na origem) e densidade de fogo cravada.
func _tabuleiro(dist: float, densidade: int) -> Node3D:
	var game: Node3D = await _montar_jogo()
	_alinhar(game)
	_blindar(game)
	_desarmar(game)
	(game.enemies[0]["node"] as Node3D).position = Vector3(0.0, 0.0, -dist)
	game.fogo_densidade = densidade
	return game

## Ponte avançada para dentro do alcance sem mexer em nenhum casco: é a alavanca do comandante
## («avance a ponte») e deixa o tabuleiro da salva idêntico ao tabuleiro de controle.
func _avancar_ponte(game) -> void:
	game.bridge_rig.global_position = Vector3(-15.0, 0.0, -30.0)

func _hostis_somados(game) -> float:
	var total := 0.0
	for unit in game.enemies:
		total += float(unit["hp"])
	return total

func _conta(game) -> Dictionary:
	var c: Dictionary = game.capitania_contagem
	return {"salvas": int(c["salvas"]), "lancados": int(c["lancados"]), "feriram": int(c["feriram"]),
		"no_vao": int(c["no_vao"]), "parados": int(c["parados"]), "dano": float(c["dano"])}

func _fechada(c: Dictionary) -> bool:
	return int(c["feriram"]) + int(c["no_vao"]) + int(c["parados"]) == int(c["lancados"])

## Predição independente da salva: as três funções puras (`_pontos_de_impacto`, `_barreira_entre`,
## `_casco_em`) dizem, ANTES de qualquer tiro, por qual das três portas cada ponto vai sair. Se a
## conta do jogo bate com a predição, a contagem não é saldo arbitrário — é o desenho.
func _predizer(game, origem: Vector3, centro: Vector3, densidade: int) -> Dictionary:
	var pontos: Array = game._pontos_de_impacto(origem, centro, -1, densidade)
	var feriram := 0
	var vaos := 0
	var parados := 0
	for ponto_bruto in pontos:
		var ponto: Vector3 = ponto_bruto
		if not (game._barreira_entre(origem, ponto) as Dictionary).is_empty():
			parados += 1
		elif int(game._casco_em(ponto, game.enemies)) >= 0:
			feriram += 1
		else:
			vaos += 1
	return {"lancados": pontos.size(), "feriram": feriram, "no_vao": vaos, "parados": parados}

func _botoes(game, nome: String) -> Array[Button]:
	var lista: Array[Button] = []
	var corpo: Control = game.group_bodies[nome]
	for filho in corpo.get_children():
		if filho is Button:
			lista.append(filho as Button)
	return lista

func _nao_botoes(game, nome: String) -> int:
	var total := 0
	var corpo: Control = game.group_bodies[nome]
	for filho in corpo.get_children():
		if not (filho is Button):
			total += 1
	return total

## ---- 1) Inércia no tabuleiro de abertura ----
func _secao_abertura() -> void:
	var game: Node3D = await _montar_jogo()
	_blindar(game)
	var alcance: float = game._capitania_alcance()
	_assert("abertura.fora", alcance > CAPITAL_ALCANCE,
		"a ponte abre a %.2f u do alvo comandado e o canhão de linha alcança %.0f u" % [alcance, CAPITAL_ALCANCE])
	var antes := _conta(game)
	var resumo_antes := String(game.salva_resumo)
	game._resolve_volley()
	var depois := _conta(game)
	var resumo := String(game.salva_resumo)
	_assert("abertura.nada_mudou", depois == antes,
		"uma salva de linha inteira não moveu a contagem da capitânia: %s" % str(depois))
	_assert("abertura.sem_clausula", (not resumo.contains("capitânia:")) and resumo.length() > 0,
		"o resumo fecha como fechava antes deste canhão (%d caracteres, começando em «%s»)" % [resumo.length(),
		resumo.substr(0, 22)])
	_assert("abertura.a_linha_atirou", int(game.salva_contagem["aliados"]) > 0,
		"a própria salva aconteceu (%d impactos aliados no agregado) — a inércia dela não é salva vazia"
		% int(game.salva_contagem["aliados"]))
	_assert("abertura.sem_flip", not bool(game.capitania_em_alcance),
		"o letreiro de entrada em alcance não acendeu: capitania_em_alcance=%s" % str(game.capitania_em_alcance))

## ---- 2) Uma régua só: a porta é <= e painel e salva concordam ----
func _secao_regua() -> void:
	for caso_bruto in [[59.0, true], [60.0, true], [60.002, false], [61.0, false]]:
		var caso: Array = caso_bruto
		var dist := float(caso[0])
		var deve_atirar := bool(caso[1])
		var game: Node3D = await _tabuleiro(dist, 0)
		var alcance: float = game._capitania_alcance()
		game._update_hud()
		var letreiro := String(game.capitania_label.text)
		var antes := int(game.capitania_contagem["lancados"])
		game._resolve_volley()
		var disparou := int(game.capitania_contagem["lancados"]) - antes == FLECHAS_POR_SALVA
		var diz_dentro := letreiro.contains("EM ALCANCE, ATIRA NA PRÓXIMA SALVA")
		var diz_fora := letreiro.contains("FORA DE ALCANCE")
		var rotulo := "%0.3f" % dist
		_assert("regua.leitura_" + rotulo, _igual(alcance, dist, 0.05),
			"`_capitania_alcance()` leu %.4f u para um setor plantado a %.4f u" % [alcance, dist])
		_assert("regua.tiro_" + rotulo, disparou == deve_atirar,
			"a %s u: %s — a porta `<=` de %.0f u manda %s" % [rotulo, "atirou" if disparou else "não atirou",
			CAPITAL_ALCANCE, "atirar" if deve_atirar else "segurar o fogo"])
		_assert("regua.painel_" + rotulo, diz_dentro == deve_atirar and diz_fora == (not deve_atirar) \
				and (alcance <= CAPITAL_ALCANCE) == deve_atirar,
			"painel e salva dão o mesmo veredito: [%s]" % letreiro.substr(letreiro.find("//")))

## ---- 3) O dano vem do mesmo canhão da linha ----
func _secao_dano() -> void:
	var game: Node3D = await _tabuleiro(52.0, 0)
	var origem: Vector3 = game.bridge_rig.global_position
	var calor: float = game._fator_calor(origem)
	var anunciado: float = game._dano_de_canhao(CAPITAL_CANHAO) * calor
	var antes_hp := _hostis_somados(game)
	var agregado_antes := int(game.salva_contagem["aliados"])
	game._resolve_volley()
	var c := _conta(game)
	var perdido := antes_hp - _hostis_somados(game)
	var resumo := String(game.salva_resumo)
	_assert("dano.preco", _igual(anunciado, DANO_NOMINAL, 0.0001) and _igual(calor, 1.0, 0.0001),
		"campo aberto e cruzador nominal: `_dano_de_canhao` devolve %0.4f com calor %0.2f" % [anunciado, calor])
	_assert("dano.casco_saiu", _igual(perdido, anunciado, 0.0001),
		"linha desarmada e o hostil perdeu %0.4f de casco — nem um centésimo de bônus paralelo" % perdido)
	_assert("dano.conta_cheia", int(c["salvas"]) == 1 and int(c["lancados"]) == FLECHAS_POR_SALVA \
			and int(c["feriram"]) == FLECHAS_POR_SALVA and int(c["no_vao"]) == 0 and int(c["parados"]) == 0 \
			and _igual(c["dano"], perdido, 0.0001) and _fechada(c),
		"CONCENTRADO sem pedra fecha em %s" % str(c))
	_assert("dano.agregado_aliado", int(game.salva_contagem["aliados"]) - agregado_antes == FLECHAS_POR_SALVA,
		"os três lances dela entram no agregado aliado da ponte: %d -> %d impactos" % [agregado_antes,
		int(game.salva_contagem["aliados"])])
	_assert("dano.clausula", resumo.contains("capitânia:") and resumo.contains("%0.1f de dano" % perdido),
		"a cláusula nasceu com o primeiro lance e cobra o dano medido: %s"
		% resumo.substr(resumo.find("// capitânia")))

## ---- 4) A conta fecha nos três tabuleiros, conferida contra a predição ----
func _secao_fechamento() -> void:
	for caso_bruto in [[0, 52.0], [1, 52.0], [2, 52.0], [2, 30.0]]:
		var caso: Array = caso_bruto
		var dens := int(caso[0])
		var dist := float(caso[1])
		var game: Node3D = await _tabuleiro(dist, dens)
		var origem: Vector3 = game.bridge_rig.global_position
		var centro: Vector3 = (game.enemies[0]["node"] as Node3D).global_position
		var esperado := _predizer(game, origem, centro, dens)
		game._resolve_volley()
		var c := _conta(game)
		var bate := int(c["lancados"]) == int(esperado["lancados"]) \
			and int(c["feriram"]) == int(esperado["feriram"]) \
			and int(c["no_vao"]) == int(esperado["no_vao"]) \
			and int(c["parados"]) == int(esperado["parados"])
		_assert("fechar.d%d_a%0.0f" % [dens, dist], _fechada(c) and bate \
				and int(c["lancados"]) == FLECHAS_POR_SALVA,
			"disco de %.1f u: predição %s -> jogo %s" % [FOGO_RAIO[dens], str(esperado), str(c)])
		# Tabuleiro vazio aprova por ausência: o DISPERSAR tem de abrir de verdade, senão o
		# fechamento só teria provado que ninguém atirou.
		if dens == 2 and dist == 52.0:
			_assert("fechar.vao_existe", int(c["no_vao"]) >= 1,
				"a %.1f u de raio o leque dela abriu no vazio: %d no vão, %d feriram" % [FOGO_RAIO[dens],
				int(c["no_vao"]), int(c["feriram"])])

## ---- 5) Preço de RNG, por reprodução de estado ----
func _secao_rng() -> void:
	var fora: Node3D = await _tabuleiro(83.39, 0)
	fora.rng.state = SEMENTE
	fora.visual_rng.state = SEMENTE
	var fora_antes := int(fora.rng.state)
	var fora_visual := int(fora.visual_rng.state)
	fora._resolve_volley()
	_assert("rng.fora_custa_zero", int(fora.rng.state) == fora_antes \
			and int(fora.visual_rng.state) == fora_visual \
			and int(fora.capitania_contagem["lancados"]) == 0,
		"salva sem nenhum canhão disparando não consome sorteio: rng %d -> %d, visual %d -> %d" \
			% [fora_antes, int(fora.rng.state), fora_visual, int(fora.visual_rng.state)])

	# Mesmo tabuleiro, ponte avançada para dentro do alcance: a linha continua desarmada, então os
	# únicos sorteios novos do quadro são os dois por lance dela — seis para três lances.
	var dentro: Node3D = await _tabuleiro(83.39, 0)
	_avancar_ponte(dentro)
	var alc: float = dentro._capitania_alcance()
	dentro.rng.state = SEMENTE
	dentro.visual_rng.state = SEMENTE
	var dentro_antes := int(dentro.rng.state)
	var dentro_visual_antes := int(dentro.visual_rng.state)
	dentro._resolve_volley()
	var lanc := int(dentro.capitania_contagem["lancados"])
	var ref := RandomNumberGenerator.new()
	ref.state = dentro_antes
	for i in range(2 * FLECHAS_POR_SALVA):
		ref.randf_range(-1.0, 1.0)
	_assert("rng.seis_sorteios_exatos", int(ref.state) == int(dentro.rng.state),
		"ponte a %.1f u e %d lances: o estado depois da salva é o de antes adiantado em %d sorteios de `randf_range(-1, 1)` (%d == %d)" % [alc, lanc, 2 * FLECHAS_POR_SALVA, int(ref.state), int(dentro.rng.state)])
	_assert("rng.visual_intacto", int(dentro.visual_rng.state) == dentro_visual_antes,
		"visual_rng intacto: hostil desarmado não desenha lance, então ela não puxa a cauda dele")

## ---- 6) Ponte condenada não atira ----
func _secao_morta() -> void:
	var game: Node3D = await _tabuleiro(52.0, 0)
	var antes := _conta(game)
	var estado := int(game.rng.state)
	game.capital_hp = 0.0
	game._resolve_volley()
	_assert("morta.sem_tiro", _conta(game) == antes,
		"capital_hp = 0 devolve a salva antes de qualquer canhão: %s" % str(_conta(game)))
	_assert("morta.sem_sorteio", int(game.rng.state) == estado,
		"nem um sorteio gasto: rng %d -> %d" % [estado, int(game.rng.state)])
	_assert("morta.fim", bool(game.batalha_encerrada) and String(game.report_label.text).contains("DERROTA"),
		"a ponte perdida encerra a batalha: [%s]" % String(game.report_label.text).substr(0, 46))

## ---- 7) O leque dela nunca é o leque da linha ----
func _secao_leque() -> void:
	var game: Node3D = await _tabuleiro(52.0, 1)
	var origem := Vector3.ZERO
	var centro := Vector3(0.0, 0.0, -52.0)
	for dens in [0, 1, 2]:
		var dela: Array = game._pontos_de_impacto(origem, centro, -1, dens)
		var minimo := INF
		var centro_compartilhado := true
		for i in range(game.fleet.size()):
			var da_linha: Array = game._pontos_de_impacto(origem, centro, i, dens)
			if (dela[0] as Vector3).distance_to(da_linha[0] as Vector3) > FOLGA:
				centro_compartilhado = false
			for a_bruto in dela:
				var a: Vector3 = a_bruto
				if int(dela.find(a_bruto)) == 0:
					continue
				for b_bruto in da_linha:
					var b: Vector3 = b_bruto
					if int(da_linha.find(b_bruto)) == 0:
						continue
					var d := a.distance_to(b)
					if d < minimo:
						minimo = d
		_assert("leque.d%d" % dens, minimo > 0.5 and centro_compartilhado,
			"densidade %d: fora do centro, o lance dela mais perto de um lance de casco fica a %.3f u, e o centro do disco é comum (%s)" % [dens, minimo, "sim" if centro_compartilhado else "não"])

## ---- 8) A pedra no corredor cobra dela o mesmo preço ----
func _secao_pedra() -> void:
	var game: Node3D = await _tabuleiro(83.39, 0)
	_avancar_ponte(game)
	var origem: Vector3 = game.bridge_rig.global_position
	var centro: Vector3 = (game.enemies[0]["node"] as Node3D).global_position
	var sem_pedra := _predizer(game, origem, centro, 0)
	var pedra: Dictionary = game._nova_rocha((origem + centro) * 0.5, 3.2, Vector3.ZERO, 0, 0.0)
	var integridade_antes := float(pedra["integridade"])
	var hp_antes := _hostis_somados(game)
	# A pedra muda o corredor, então a predição é refeita com ela no lugar.
	var esperado := _predizer(game, origem, centro, 0)
	game._resolve_volley()
	var c := _conta(game)
	var absorvido := float(esperado["parados"]) * (DANO_NOMINAL / float(FLECHAS_POR_SALVA))
	_assert("pedra.predicao", int(c["feriram"]) == int(esperado["feriram"]) \
			and int(c["parados"]) == int(esperado["parados"]) \
			and int(c["no_vao"]) == int(esperado["no_vao"]) and int(c["lancados"]) == FLECHAS_POR_SALVA \
			and _fechada(c),
			"sem pedra %s -> com 3,2 u no meio do corredor %s (jogo: %s)" % [str(sem_pedra), str(esperado), str(c)])
	_assert("pedra.hostis_intactos", _igual(_hostis_somados(game), hp_antes, FOLGA),
		"nenhum casco hostil perdeu hp: soma %0.3f -> %0.3f" % [hp_antes, _hostis_somados(game)])
	_assert("pedra.paga_integridade", pedra.is_empty() or _igual(float(pedra["integridade"]),
			integridade_antes - absorvido, 0.0001),
		"a pedra não sabe quem atirou: cobra %0.4f de integridade, a conta do canhão nominal (%0.3f -> %0.3f)"
			% [absorvido, integridade_antes, float(pedra["integridade"]) if not pedra.is_empty() else 0.0])

	# Fratura: pedra pré-machucada abaixo de uma salva dela. Não assento para onde as filhas vão nem
	# quantos lances racham — só que rachou pelo mesmo caminho e a conta dela fechou.
	var g2: Node3D = await _tabuleiro(83.39, 0)
	_avancar_ponte(g2)
	var o2: Vector3 = g2.bridge_rig.global_position
	var c2: Vector3 = (g2.enemies[0]["node"] as Node3D).global_position
	var frail: Dictionary = g2._nova_rocha((o2 + c2) * 0.5, 3.2, Vector3.ZERO, 0, 0.0)
	frail["integridade"] = 2.0
	var corpos_antes := int(g2.rochas.size())
	var pred := _predizer(g2, o2, c2, 0)
	g2._resolve_volley()
	var k := _conta(g2)
	_assert("pedra.fratura", int(k["parados"]) == int(pred["parados"]) and _fechada(k) \
			and int(g2.rochas.size()) != corpos_antes,
			"integridade 2,0 sob %d lances de %0.4f: o cinturão mudou de %d para %d corpo(s) e a conta dela fechou: %s" % [int(pred["parados"]), DANO_NOMINAL / float(FLECHAS_POR_SALVA), corpos_antes,
			int(g2.rochas.size()), str(k)])

## ---- 9) Painel: um letreiro a mais, nenhum comando a mais ----
func _secao_painel() -> void:
	var game: Node3D = await _tabuleiro(52.0, 0)
	var total := 0
	for nome in NOMES_GRUPOS:
		total += _botoes(game, nome).size()
	_assert("painel.grupos", int(game.group_bodies.size()) == NOMES_GRUPOS.size(),
		"%d grupos de comando no painel" % game.group_bodies.size())
	_assert("painel.comandos", total == 36, "%d botões de comando em todo o painel" % total)
	_assert("painel.armamento", _botoes(game, "ARMAMENTO").size() == int(TAMANHOS["ARMAMENTO"]) \
			and _nao_botoes(game, "ARMAMENTO") == 1 and is_instance_valid(game.capitania_label),
			"ARMAMENTO segue com %d botões e ganhou exatamente um filho que não é botão: o letreiro da capitânia" % TAMANHOS["ARMAMENTO"])
	game._update_hud()
	var dentro := String(game.capitania_label.text)
	_assert("painel.dentro", dentro.contains("EM ALCANCE, ATIRA NA PRÓXIMA SALVA") \
			and dentro.contains("%0.0f u de alcance" % CAPITAL_ALCANCE), "[%s]" % dentro)
	# A salva DENTRO do alcance é o que faz a cláusula nascer: o quadro de comando só pode ser
	# conferido depois de ela existir. Ler o HUD antes disto era conferir a string da montagem.
	game._resolve_volley()
	# `command_label` é escrito por `_update_hud`, que em sonda congelada só existe quando chamada à
	# mão. Sem esta linha o letreiro leria o resumo velho, não o da salva que acabou de acontecer.
	game._update_hud()
	var quadro := String(game.command_label.text)
	var linhas := quadro.split("\n")
	_assert("painel.cinco_linhas", quadro.count("\n") == 4,
		"o letreiro de comando continua com cinco linhas (%d quebras) — morte, ia e caças indexam o texto por posição" % quadro.count("\n"))
	_assert("painel.clausula_na_quarta", int(linhas.size()) == 5 and String(linhas[3]).contains("capitânia:"),
		"a cláusula entrou embutida na linha da última salva: %s" % String(linhas[3]).substr(0, 150))
	(game.enemies[0]["node"] as Node3D).position = Vector3(0.0, 0.0, -90.0)
	game._update_hud()
	var fora_txt := String(game.capitania_label.text)
	_assert("painel.fora", fora_txt.contains("FORA DE ALCANCE"), "[%s]" % fora_txt)
	# Sem contato comandado a régua devolve INF e o letreiro diz isso — distância zero seria mentira.
	for unit in game.enemies:
		unit["hp"] = 0.0
	var sem_contato: float = game._capitania_alcance()
	game._update_hud()
	_assert("painel.sem_contato", is_inf(sem_contato) \
			and String(game.capitania_label.text).contains("sem contato comandado"),
			"alcance=%s e o painel não inventa número: [%s]" % [str(sem_contato), String(game.capitania_label.text)])

func _initialize() -> void:
	await _secao_abertura()
	await _secao_regua()
	await _secao_dano()
	await _secao_fechamento()
	await _secao_rng()
	await _secao_morta()
	await _secao_leque()
	await _secao_pedra()
	await _secao_painel()
	for linha in notes:
		print(linha)
	print("SONDA-CAPITANIA: veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	quit()
