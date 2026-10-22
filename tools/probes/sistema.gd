extends SceneTree

## Sonda do sistema planetário: três luas numa forma fechada e um mapa que abre e fecha.
##
## O pedido do comandante foi «planetas podem ter luas». Lua que só enfeita o visor não atende ao
## pedido, então esta peça cobra as quatro consequências que fazem do sistema um mapa:
##
## 1) FORMA FECHADA, NÃO INTEGRAÇÃO. A posição de cada lua é `fase + TAU × battle_clock / período`,
##    lida do relógio, e a velocidade é a DERIVADA exata dessa forma. O espelho em RAM abaixo
##    reimplementa a conta sem chamar o jogo: se o `sin`, o `cos` ou o `0,88` da inclinação mudarem
##    no código, a coordenada assinada aqui quebra. A consequência conferida é a que importa para a
##    física do abalroamento — mudada a taxa de quadro (seiscentos passos de 0,1 s contra sessenta de
##    1,0 s), a lua acorda no MESMO ponto do céu, porque não há estado acumulado para acumular erro.
## 2) A ESCADA DAS TRÊS LUAS. `TAU × órbita / período` dá 6,81 / 4,19 / 2,76 u/s. O teto de
##    abalroamento é 3,0 u/s, então as duas de dentro ferem e a de fora EMPURRA SEM FERIR. Isso é
##    medido casco a casco, com o valor previsto pela fórmula do próprio `main.gd`
##    (`clampf((aproximacao - 3,0) × 1,9, 1,0, 18,0)`), e com o controle ligado: a lua miúda e lenta
##    desloca o casco exatamente para a soma dos raios, que é o que prova que ela é corpo e não
##    flag de painel.
## 3) O CORREDOR QUE ABRE E FECHA. A inclinação de 0,88 rad faz a órbita de 26 u descer até a
##    altitude dos cascos, e a asserção que vale é a do tempo: percorrido um período inteiro em
##    passos de 0,1 s, há quadros em que a linha aliada-hostil está bloqueada e quadros em que não
##    está, e o veredito do jogo bate com o espelho em TODOS os passos. Um mapa sempre aberto ou
##    sempre fechado seria pedra parada com outro nome.
## 4) A SOMBRA SERVE AOS DOIS LADOS. O mesmo corpo que para a salva para a varredura da sonda, e é a
##    MESMA régua (`_barreira_entre`), não uma conta paralela de reconhecimento. Medido nos dois
##    lados: com lua no corredor o seletor devolve `NÃO IDENTIFICADO`, com a lua fora devolve
##    `CASCO 100%`.
##
## E o contrato da casa, conferido aqui como em toda peça: barreira nenhuma move sorteio. A corrida
## A/B na mesma semente, com a lua no caminho do lance âncora contra a mesma lua estacionada 22 u
## acima do corredor, dá `rng.state` idêntico, `impactos` idênticos e 4,500 de casco hostil a mais
## do outro lado — que é a diferença entre escudo e reroll disfarçado. Planeta e lua não racham
## (`"pedra"` sempre vazio), não comem integridade e não têm janela de abalroamento emprestada da
## pedra homônima: a chave leva prefixo, e a seção 7 prova os dois convívios.
##
## Uso: godot --headless --path . --quit-after 6000 -s res://tools/probes/sistema.gd

## Espelho das constantes de `main.gd` — a instância do jogo é não tipada (mesmo motivo em
## `tools/probes/cinturao.gd`). Se o número lá mudar, a asserção quebra: é de propósito.
const SISTEMA_POS := Vector3(0.0, 22.0, -64.0)
const SISTEMA_PLANETA_RAIO := 15.0
const SISTEMA_ORBITA := [26.0, 40.0, 58.0]
const SISTEMA_PERIODO := [24.0, 60.0, 132.0]
const SISTEMA_LUA_RAIO := [2.4, 3.2, 1.9]
const SISTEMA_INCLINACAO := 0.88
const SISTEMA_FASE_AUREA := 2.39996
const RAM_SPEED := 3.0
const RAM_DAMAGE := 1.9
const RAM_MAX_DAMAGE := 18.0
const RAM_WINDOW := 1.5
const HULL_RADIUS := 2.4
const PROBE_SCAN_RADIUS := 9.0
const FLECHAS_POR_SALVA := 3
const PASSO := 0.1
## Tolerância de float32 lida de volta do motor: perto de 80 u o ulp é ~7,6e-6, e uma comparação
## exata acusaria a aritmética da GPU como se fosse erro de fórmula.
const FOLGA := 0.00005
## Um período da lua de dentro, varrido em passos de 0,1 s: a resolução que mede a janela de
## fechamento do corredor sem virar teste de desempenho.
const AMOSTRAS_PERIODO := 240

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

func _alinhar(game) -> void:
	for i in range(game.fleet.size()):
		(game.fleet[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 5.0, 0.0, -38.0)
	for i in range(game.enemies.size()):
		(game.enemies[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 6.0, 0.0, -82.0)

func _zerar(game) -> void:
	for list in [game.fleet, game.enemies]:
		for unit in list:
			unit["hp"] = 100.0
			unit["engines"] = 100.0
			unit["weapons"] = 100.0
			unit["crew"] = 100.0
			unit["veloc"] = Vector3.ZERO
	game.capital_hp = 100.0
	game.batalha_encerrada = false

func _hostis_somados(game) -> float:
	var total := 0.0
	for unit in game.enemies:
		total += float(unit["hp"])
	return total

## ---- O espelho em RAM: a mesma conta, reimplementada sem chamar o jogo -----------------------
func _angulo(no: int, clock: float) -> float:
	return float(no) * SISTEMA_FASE_AUREA + TAU * clock / float(SISTEMA_PERIODO[no])

func _posto(no: int, clock: float) -> Vector3:
	var ang := _angulo(no, clock)
	var orbita := float(SISTEMA_ORBITA[no])
	return SISTEMA_POS + Vector3(cos(ang) * orbita, -sin(ang) * orbita * sin(SISTEMA_INCLINACAO),
		sin(ang) * orbita * cos(SISTEMA_INCLINACAO))

func _velocidade(no: int, clock: float) -> Vector3:
	var ang := _angulo(no, clock)
	var omega := TAU / float(SISTEMA_PERIODO[no])
	var orbita := float(SISTEMA_ORBITA[no])
	return Vector3(-sin(ang) * orbita * omega, cos(ang) * orbita * sin(SISTEMA_INCLINACAO) * omega,
		-cos(ang) * orbita * cos(SISTEMA_INCLINACAO) * omega)

## Os quatro corpos no relógio pedido: planeta parado (id 0) e as três luas (ids 1..3). Os ids são
## os do espelho, não os do jogo — aqui eles só servem para dizer QUEM fecha o corredor.
func _ceu(clock: float) -> Array[Dictionary]:
	var lista: Array[Dictionary] = [{"pos": SISTEMA_POS, "raio": SISTEMA_PLANETA_RAIO, "id": 0}]
	for no in range(SISTEMA_ORBITA.size()):
		lista.append({"pos": _posto(no, clock), "raio": float(SISTEMA_LUA_RAIO[no]), "id": no + 1})
	return lista

## Segmento contra esfera, com o `t` clampado — reproduzido do `main.gd` de propósito: é a régua que
## decide se o obstáculo está DENTRO do trecho, e uma sonda que usasse reta infinita aprovaria uma
## lua atrás da linha de batalha como se estivesse na frente dela.
func _corta_na_lista(lista: Array[Dictionary], origem: Vector3, destino: Vector3) -> Dictionary:
	var melhor_t := INF
	var melhor := {}
	for corpo in lista:
		var centro: Vector3 = corpo["pos"]
		var trecho := destino - origem
		var comprimento := trecho.length_squared()
		if comprimento < 0.0001:
			continue
		var t := clampf((centro - origem).dot(trecho) / comprimento, 0.0, 1.0)
		var ponto := origem + trecho * t
		if ponto.distance_to(centro) > float(corpo["raio"]):
			continue
		if t < melhor_t:
			melhor_t = t
			melhor = {"t": t, "id": int(corpo["id"]), "pos": ponto}
	return melhor

## Quantos lances a fatura da salva anuncia como parados em astro. É leitura do texto que o jogador
## vê, não de variável interna: se o resumo mentir, a asserção quebra junto.
func _lances_parados(resumo: String) -> int:
	var marca := resumo.find("sistema: ")
	if marca < 0:
		return -1
	var digitos := ""
	var i := marca + 9
	while i < resumo.length():
		var c := resumo[i]
		if c == " ":
			break
		digitos += c
		i += 1
	return int(digitos)

func _initialize() -> void:
	var game: Node3D = await _montar_jogo()
	_alinhar(game)
	_zerar(game)

	# ---- 1. Montagem: quatro corpos, nenhum sorteio ------------------------------------------
	var rng_montar: int = game.rng.state
	var visual_montar: int = game.visual_rng.state
	game.battle_clock = 0.0
	game._montar_cenario("SISTEMA")
	_assert("o sistema monta planeta mais três luas", int(game.astros.size()) == 4
		and bool(game.planeta_ativa) and int(game.rochas.size()) == 0,
		"%d astros, %d rochas, planeta=%s" % [game.astros.size(), game.rochas.size(),
			game.planeta_ativa])
	_assert("montar o sistema não sorteia um pixel",
		int(game.rng.state) == rng_montar and int(game.visual_rng.state) == visual_montar,
		"rng %d e visual_rng %d intactos" % [rng_montar, visual_montar])
	var planeta: Dictionary = game.astros[0]
	_assert("o planeta é corpo parado, não uma lua de órbita",
		int(planeta["orbita"]) == -1 and (planeta["vel"] as Vector3) == Vector3.ZERO
		and (planeta["pos"] as Vector3).distance_to(SISTEMA_POS) < FOLGA,
		"orbita=%s vel=%s" % [str(planeta["orbita"]), str(planeta["vel"])])
	_assert("o raio do planeta é o do painel", _igual(float(planeta["raio"]),
		SISTEMA_PLANETA_RAIO, FOLGA), "%0.1f u" % float(planeta["raio"]))

	# ---- 2. A forma fechada, conferida no espelho em RAM ---------------------------------------
	var desencontros := ""
	var relógios := [0.0, 3.7, 11.25, 24.0, 61.5, 200.0]
	for clock in relógios:
		game.battle_clock = clock
		game._orbitar_luas()
		for no in range(3):
			var astro: Dictionary = game.astros[no + 1]
			if (astro["pos"] as Vector3).distance_to(_posto(no, clock)) > FOLGA:
				desencontros += "p%d@%s " % [no, str(clock)]
			if (astro["vel"] as Vector3).distance_to(_velocidade(no, clock)) > FOLGA:
				desencontros += "v%d@%s " % [no, str(clock)]
	_assert("posição e velocidade de cada lua batem com a forma fechada em seis relógios",
		desencontros == "", "descasos: [%s]" % desencontros)
	var escada := ""
	var escada_ok := true
	for no in range(3):
		game.battle_clock = 7.3
		game._orbitar_luas()
		var medida: float = (game.astros[no + 1]["vel"] as Vector3).length()
		var prevista := TAU * float(SISTEMA_ORBITA[no]) / float(SISTEMA_PERIODO[no])
		if not _igual(medida, prevista, 0.0005):
			escada_ok = false
		escada += "%0.2f " % medida
	_assert("a escada de varredura sai de TAU × órbita / período: 6,81 / 4,19 / 2,76 u/s",
		escada_ok, "velocidades medidas: %s" % escada)
	var minimo_y := INF
	for s in range(AMOSTRAS_PERIODO):
		minimo_y = minf(minimo_y, _posto(0, float(s) * PASSO).y)
	_assert("a lua de dentro desce até a altitude dos cascos",
		minimo_y < 2.0 and _igual(minimo_y, SISTEMA_POS.y
			- float(SISTEMA_ORBITA[0]) * sin(SISTEMA_INCLINACAO), 0.0005),
		"ponto mais baixo a y %0.4f, previsto %0.4f" % [minimo_y, SISTEMA_POS.y
			- float(SISTEMA_ORBITA[0]) * sin(SISTEMA_INCLINACAO)])
	_assert("o planeta nunca desce ao plano da linha: fica fora do corredor por construção",
		SISTEMA_POS.y > SISTEMA_PLANETA_RAIO, "planeta a y %0.1f contra raio %0.1f" % [
			SISTEMA_POS.y, SISTEMA_PLANETA_RAIO])

	# ---- 3. Taxa de quadro não muda o céu ------------------------------------------------------
	var fino := await _montar_jogo()
	var bruto := await _montar_jogo()
	fino.battle_clock = 0.0
	bruto.battle_clock = 0.0
	fino._montar_cenario("SISTEMA")
	bruto._montar_cenario("SISTEMA")
	for s in range(600):
		fino.battle_clock += PASSO
		fino._aplicar_cenario(PASSO)
	for s in range(60):
		bruto.battle_clock += 1.0
		bruto._aplicar_cenario(1.0)
	var quadro := ""
	var quadro_ok := true
	for no in range(3):
		var pf: Vector3 = fino.astros[no + 1]["pos"]
		var pb: Vector3 = bruto.astros[no + 1]["pos"]
		var esperado := _posto(no, 60.0)
		if pf.distance_to(pb) > 0.001 or pf.distance_to(esperado) > 0.001:
			quadro_ok = false
		quadro += "%0.4f " % pf.distance_to(esperado)
	_assert("seiscentos quadros de 0,1 s e sessenta de 1,0 s acordam na mesma lua",
		quadro_ok and _igual(float(fino.battle_clock), 60.0, 0.0001)
			and _igual(float(bruto.battle_clock), 60.0, 0.0001),
		"desvio contra o espelho: %s u" % quadro)
	_assert("a forma fechada não acumula estado: dois relógios iguais, duas posições iguais",
		_fino_igual_a_bruto(fino, bruto), "posições conferidas lua a lua no mesmo `battle_clock`")
	fino.queue_free()
	bruto.queue_free()
	await _frames(2)

	# ---- 4. A escada de perigo: 6,81 e 4,19 ferem, 2,76 empurra --------------------------------
	game.ram_windows.clear()
	game.battle_clock = 7.3
	game._orbitar_luas()
	game.bridge_rig.position = Vector3(0.0, 0.0, 30.0)
	var casco: Node3D = game.fleet[0]["node"]
	var escada_medida := ""
	var fere := true
	var separa_ok := true
	var empurra_sem_ferir := true
	for no in range(3):
		var lua: Dictionary = game.astros[no + 1]
		var centro: Vector3 = lua["pos"]
		var rumo: Vector3 = (lua["vel"] as Vector3).normalized()
		var soma := HULL_RADIUS + float(lua["raio"])
		var antes := float(game.fleet[0]["hp"])
		casco.position = centro + rumo * (soma - 0.5)
		game.fleet[0]["veloc"] = Vector3.ZERO
		game._chocar_com_barreiras()
		var perda := antes - float(game.fleet[0]["hp"])
		var aproximacao: float = (lua["vel"] as Vector3).length()
		var previsto := clampf((aproximacao - RAM_SPEED) * RAM_DAMAGE, 1.0, RAM_MAX_DAMAGE)
		escada_medida += "%0.3f " % perda
		if aproximacao > RAM_SPEED:
			if not _igual(perda, previsto, 0.0005):
				fere = false
		else:
			if perda > 0.0001:
				empurra_sem_ferir = false
		if not _igual(casco.global_position.distance_to(centro), soma, 0.0005):
			separa_ok = false
	_assert("a lua rápida fere pela régua de abalroamento (6,81 → 7,23 e 4,19 → 2,26 de casco)",
		fere, "perdas medidas: %s" % escada_medida)
	_assert("a lua lenta empurra sem ferir: 2,76 u/s está abaixo do teto de 3,0",
		empurra_sem_ferir, "perdas medidas: %s" % escada_medida)
	_assert("empurrar é resolver a sobreposição: cada lua acorda o casco exatamente na soma dos raios",
		separa_ok, "mesma passada que cobra o dano tem de tirar o casco de dentro da lua")
	# A segunda chamada com o casco recolocado dentro da soma, no mesmo relógio: sem a janela, o
	# astro viraria moedor — e a janela só prova alguma coisa se o contato for recriado de propósito.
	game._orbitar_luas()
	var lua0: Dictionary = game.astros[1]
	var centro0: Vector3 = lua0["pos"]
	var rumo0: Vector3 = (lua0["vel"] as Vector3).normalized()
	var soma0 := HULL_RADIUS + float(lua0["raio"])
	casco.position = centro0 + rumo0 * (soma0 - 0.5)
	var apos_primeiro := float(game.fleet[0]["hp"])
	game._chocar_com_barreiras()
	_assert("o segundo contato com a mesma lua, na mesma janela de 1,5 s, não cobra de novo",
		_igual(float(game.fleet[0]["hp"]), apos_primeiro, 0.0001),
		"%0.3f -> %0.3f com o casco recolocado dentro da soma" % [apos_primeiro,
			float(game.fleet[0]["hp"])])

	# ---- 5. A janela tem dono: astro e pedra com o mesmo id não se emprestam ---------------------
	# Sem o prefixo na chave, a pedra 2 e a lua 2 dividiriam a mesma janela de 1,5 s e um casco
	# recém-chocado por uma lua ignoraria de graça o choque contra uma pedra — proteção herdada de um
	# contato que não aconteceu. O risco é real porque os dois contadores são independentes e voltam a
	# zero com o mapa: o planeta fica com id 1, as luas com 2, 3 e 4, e a primeira pedra injetada com 1.
	# Daí duas pedras: a segunda tem id 2 e é ela que enfrenta a lua de dentro. A pedra entra pelo
	# construtor do jogo (nunca por dicionário artesanal: sem `vel`, `fase` e `geracao` a correnteza
	# aborta no primeiro quadro, armadilha nº 7 da casa).
	game._nova_rocha(Vector3(60.0, 0.0, -64.0), 3.2, Vector3.ZERO, 0, 0.0)
	var rocha: Dictionary = game._nova_rocha(Vector3(84.0, 0.0, -64.0), 3.2, Vector3.ZERO, 0, 0.0)
	_assert("a segunda pedra injetada tem o mesmo id da lua de dentro",
		int(rocha["id"]) == int(lua0["id"]),
		"pedra id %s contra lua id %s" % [str(rocha["id"]), str(lua0["id"])])
	var antes_convivio := float(game.fleet[0]["hp"])
	var soma_pedra := HULL_RADIUS + float(rocha["raio"])
	casco.position = (rocha["pos"] as Vector3) + Vector3(0.0, 0.0, soma_pedra - 0.5)
	game.fleet[0]["veloc"] = Vector3(0.0, 0.0, -30.0)
	game._chocar_com_barreiras()
	game.fleet[0]["veloc"] = Vector3.ZERO
	_assert("a janela da lua não protege o casco do choque contra a pedra de mesmo id",
		float(game.fleet[0]["hp"]) < antes_convivio,
		"%0.3f -> %0.3f fechando a 30 u/s numa pedra id %s com a janela da lua 1 aberta" % [
			antes_convivio, float(game.fleet[0]["hp"]), str(rocha["id"])])
	var chaves_astro := 0
	var chaves_rocha := 0
	for chave in game.ram_windows.keys():
		if String(chave).begins_with("astro:"):
			chaves_astro += 1
		elif String(chave).begins_with("rocha:"):
			chaves_rocha += 1
	_assert("as duas famílias de janela coexistem com prefixo próprio",
		chaves_astro > 0 and chaves_rocha > 0,
		"%d chaves astro: e %d chaves rocha:" % [chaves_astro, chaves_rocha])
	game._desmontar_cenario()
	game.battle_clock = 0.0
	game._montar_cenario("SISTEMA")

	# ---- 6. O corredor que abre e fecha ----------------------------------------------------------
	var origem := Vector3(0.0, 0.0, -38.0)
	var destino := Vector3(0.0, 0.0, -82.0)
	var desacordos := ""
	var fechados := 0
	var fechados_por_dentro := 0
	for s in range(AMOSTRAS_PERIODO):
		var clock := float(s) * PASSO
		game.battle_clock = clock
		game._orbitar_luas()
		var do_jogo: Dictionary = game._barreira_entre(origem, destino)
		var do_espelho: Dictionary = _corta_na_lista(_ceu(clock), origem, destino)
		if do_jogo.is_empty() != do_espelho.is_empty():
			desacordos += "%0.1f " % clock
		elif not do_jogo.is_empty():
			fechados += 1
			if int(do_espelho["id"]) == 1:
				fechados_por_dentro += 1
	_assert("o veredito do corredor bate com o espelho em duzentos e quarenta passos",
		desacordos == "", "descasos: [%s]" % desacordos)
	_assert("a lua de dentro fecha e abre o corredor: nenhum mapa de pedra parada",
		fechados >= 2 and fechados < AMOSTRAS_PERIODO - 2,
		"%d de %d passos bloqueados (%0.1f s a cada %0.0f s de período), todos pela lua de dentro: %s"
		% [fechados, AMOSTRAS_PERIODO, float(fechados) * PASSO, SISTEMA_PERIODO[0],
			str(fechados_por_dentro == fechados)])
	game.battle_clock = 0.0
	game._orbitar_luas()
	var pelo_planeta: Dictionary = game._barreira_entre(SISTEMA_POS + Vector3(0.0, 0.0, 30.0),
		SISTEMA_POS + Vector3(0.0, 0.0, -30.0))
	_assert("o planeta é barreira: um corredor que o atravessa morre no meio",
		not pelo_planeta.is_empty() and not (pelo_planeta["astro"] as Dictionary).is_empty()
			and (pelo_planeta["pedra"] as Dictionary).is_empty(),
		"contato a %0.1f u do centro, raio %0.1f" % [
			(pelo_planeta["pos"] as Vector3).distance_to(SISTEMA_POS),
			float(pelo_planeta["raio"])])
	var zero: Dictionary = game._barreira_entre(origem, origem)
	_assert("trecho de comprimento zero não inventa astro no caminho", zero.is_empty(),
		"%s" % str(zero))

	# ---- 7. A salva parada pela lua: escudo, não reroll ------------------------------------------
	var bloqueado := await _tabuleiro_salva(0.0, false)
	var livre := await _tabuleiro_salva(0.0, true)
	_assert("a pré-condição dos dois tabuleiros: a lua está no corredor aliado só do lado bloqueado",
		bool(bloqueado["cortou"]) and not bool(livre["cortou"]),
		"cortou=%s no mapa contra cortou=%s no controle" % [bloqueado["cortou"], livre["cortou"]])
	_assert("o lance âncora passa pelo centro da lua de dentro no mapa bloqueado",
		bloqueado["parados"] >= FLECHAS_POR_SALVA,
		"%d lances parados, resumo: %s" % [bloqueado["parados"], bloqueado["resumo"]])
	_assert("com as luas estacionadas fora do corredor, nenhum lance é parado por astro",
		livre["parados"] < bloqueado["parados"],
		"%d parados no controle contra %d no mapa" % [livre["parados"], bloqueado["parados"]])
	_assert("absorver não compra sorteio extra: o rng dos dois tabuleiros é o mesmo",
		int(bloqueado["estado"]) == int(livre["estado"]),
		"rng %d dos dois lados depois da salva" % int(bloqueado["estado"]))
	_assert("o número de lances sorteados não depende da lua",
		int(bloqueado["impactos"]) == int(livre["impactos"]),
		"%d impactos aliados dos dois lados" % int(bloqueado["impactos"]))
	var diferenca: float = float(livre["perda"]) - float(bloqueado["perda"])
	_assert("o casco que a lua comeu é o casco que o alvo não perdeu: 4,500 por salva",
		_igual(diferenca, 2.5 * 1.8, 0.001),
		"perda %0.3f no controle contra %0.3f bloqueado (%0.3f absorvidos = %d setas × 1,5)" % [
			float(livre["perda"]), float(bloqueado["perda"]), diferenca, FLECHAS_POR_SALVA])
	_assert("astro não racha nem vira pedra: `rochas` continua vazia depois da salva",
		int(bloqueado["rochas"]) == 0 and int(bloqueado["astros"]) == 4,
		"%d rochas e %d astros depois de %d lances absorvidos" % [bloqueado["rochas"],
			bloqueado["astros"], bloqueado["parados"]])
	bloqueado["no"].queue_free()
	livre["no"].queue_free()
	await _frames(2)

	# ---- 8. A sombra serve ao reconhecimento -------------------------------------------------------
	game.battle_clock = 0.0
	game._orbitar_luas()
	var lua_s: Dictionary = game.astros[1]
	var centro_s: Vector3 = lua_s["pos"]
	var rumo_s: Vector3 = (lua_s["vel"] as Vector3).normalized()
	var olho := Node3D.new()
	game.add_child(olho)
	olho.position = centro_s - rumo_s * 4.0
	var vitima: Node3D = game.enemies[0]["node"]
	vitima.position = centro_s + rumo_s * 4.0
	var distancia_sonda := olho.global_position.distance_to(vitima.global_position)
	var outro_casco := 0
	for foe in game.enemies:
		if is_instance_valid(foe["node"]):
			var outro: Node3D = foe["node"]
			if outro != vitima and outro.global_position.distance_to(olho.global_position) \
					<= PROBE_SCAN_RADIUS:
				outro_casco += 1
	_assert("a geometria da varredura cabe no raio da sonda e não tem vizinho dentro dele",
		distancia_sonda < PROBE_SCAN_RADIUS and outro_casco == 0,
		"%0.2f u entre sonda e casco contra %0.1f u de raio, %d vizinhos" % [distancia_sonda,
			PROBE_SCAN_RADIUS, outro_casco])
	_preparar_alvo(game, 0)
	var rng_sombra: int = game.rng.state
	game._scan_with_probe(olho)
	game._update_hud()
	var texto_cego := String(game.target_selector.get_item_text(0))
	_assert("lua no corredor cega a varredura: o casco continua não visto",
		not bool(game.enemies[0].get("seen", false)), "seletor lê «%s»" % texto_cego)
	_assert("com a lua na frente o seletor devolve NÃO IDENTIFICADO",
		texto_cego.contains("NÃO IDENTIFICADO"), texto_cego)
	game.battle_clock = 3.0
	game._orbitar_luas()
	var lua_andou: Dictionary = _corta_na_lista(_ceu(3.0), olho.global_position,
		vitima.global_position)
	_assert("três segundos depois a mesma lua saiu do corredor (espelho, não vontade)",
		lua_andou.is_empty(), "corredor da sonda livre a y %0.1f" % _posto(0, 3.0).y)
	game._scan_with_probe(olho)
	game._update_hud()
	var texto_limpo := String(game.target_selector.get_item_text(0))
	_assert("fora do corredor a mesma sonda vê o mesmo casco",
		bool(game.enemies[0].get("seen", false)), "seletor lê «%s»" % texto_limpo)
	_assert("identificado, o seletor devolve o casco", texto_limpo.contains("CASCO 100%"),
		texto_limpo)
	_assert("nem a sombra nem a leitura consomem sorteio", int(game.rng.state) == rng_sombra,
		"rng %d antes e depois das duas varreduras" % rng_sombra)
	olho.queue_free()

	# ---- 9. Painel, nós e a margem do campo aberto -------------------------------------------------
	# Contar filhos do `Cenario` pede o `queue_free` diferido já executado: a desmonta marca os nós
	# para apagar e o motor só os libera no fim do quadro, então ler `get_child_count()` logo depois de
	# um re-montar contaria os corpos velhos pendurados. A pausa congela relógio, salva e tripulação
	# durante a espera — nenhum quadro mexe numa lua entre o `await` e a régua.
	game.paused = true
	game._desmontar_cenario()
	await _frames(3)
	game.battle_clock = 0.0
	game._montar_cenario("SISTEMA")
	game._orbitar_luas()
	_assert("o sistema pinta oito corpos e nenhum fica pendurado de outro mapa",
		is_instance_valid(game.cenario_root) and game.cenario_root.get_child_count() == 8,
		"%d filhos em Cenario (planeta + limbo + três aros + três luas)"
		% game.cenario_root.get_child_count())
	var corpo_fora := ""
	var marca_fora := ""
	for i in range(game.astros.size()):
		var astro_i: Dictionary = game.astros[i]
		var corpo_i: MeshInstance3D = astro_i["no"]
		var marca_i: MeshInstance3D = astro_i["marca"]
		if not is_instance_valid(corpo_i) \
				or corpo_i.position.distance_to(astro_i["pos"]) > FOLGA:
			corpo_fora += "%d " % i
		if not is_instance_valid(marca_i) \
				or marca_i.position.distance_to(game._holo_de(astro_i["pos"])) > FOLGA:
			marca_fora += "%d " % i
	_assert("o corpo do astro É a pintura: cada nó está na posição da conta",
		corpo_fora == "", "fora do lugar: [%s]" % corpo_fora)
	_assert("cada astro tem marca na mesa, no lugar da conta", marca_fora == ""
		and int(game.holo_cenario.size()) == 4,
		"%d marcas, fora do lugar: [%s]" % [game.holo_cenario.size(), marca_fora])
	game.battle_clock = 9.0
	game._orbitar_luas()
	var seguiu := 0
	for i in range(1, game.astros.size()):
		var astro_m: Dictionary = game.astros[i]
		var corpo_m: MeshInstance3D = astro_m["no"]
		var marca_m: MeshInstance3D = astro_m["marca"]
		if corpo_m.position.distance_to(astro_m["pos"]) < FOLGA \
				and marca_m.position.distance_to(game._holo_de(astro_m["pos"])) < FOLGA:
			seguiu += 1
	_assert("andada a lua, corpo e marca andam juntos: nada fica congelado no quadro",
		seguiu == 3 and (game.astros[1]["pos"] as Vector3).distance_to(_posto(0, 9.0)) < FOLGA,
		"%d de 3 luas coerentes no relógio 9,0 s" % seguiu)
	var nota := String(game._nota_cenario())
	_assert("a nota do sistema anuncia raios, períodos e as duas pontas da escada",
		nota.contains("planeta de 15 u") and nota.contains("26, 40 e 58 u")
			and nota.contains("24, 60 e 132 s") and nota.contains("a 6.8 u/s")
			and nota.contains("a 2.8 u/s"), nota)
	_assert("a nota diz o que a sonda perde, não só o que o casco ganha",
		nota.contains("sai da varredura da sonda"), nota)
	var rng_laco: int = game.rng.state
	var visual_laco: int = game.visual_rng.state
	for i in range(200):
		game._aplicar_cenario(0.0)
	_assert("duzentas chamadas do laço de cenário não movem um dígito",
		int(game.rng.state) == rng_laco and int(game.visual_rng.state) == visual_laco,
		"rng %d e visual_rng %d com o sistema rodando" % [rng_laco, visual_laco])
	game._montar_cenario("ABERTO")
	_assert("sair do sistema larga astros, marcas e flag",
		int(game.astros.size()) == 0 and int(game.holo_cenario.size()) == 0
			and not bool(game.planeta_ativa),
		"%d astros, %d marcas, planeta=%s" % [game.astros.size(), game.holo_cenario.size(),
			game.planeta_ativa])
	_assert("em campo aberto nenhum astro aparece no corredor",
		game._barreira_entre(origem, destino).is_empty(), "%d astros na conta"
		% game.astros.size())
	# A liberação dos nós marcados acontece no fim do quadro: só depois de três frames o `Cenario` do
	# campo aberto tem de estar vazio de verdade, e é essa a conta que o jogador veria.
	await _frames(3)
	_assert("passado o quadro de liberação, o campo aberto não deixa corpo pendurado",
		is_instance_valid(game.cenario_root) and game.cenario_root.get_child_count() == 0,
		"%d filhos em Cenario" % game.cenario_root.get_child_count())
	game.paused = false

	notes.append("veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	for linha in notes:
		print("SONDA-SISTEMA: %s" % linha)
	game.queue_free()
	await _frames(2)
	quit()

## Dois tabuleiros idênticos, montados já com o sistema no ar, na mesma semente. A única diferença
## entre os lados é a posição das três luas: no controle cada astro é deslocado `raio + 20` para
## cima, fora de qualquer corredor. Mede a salva dos dois lados e devolve a fatura.
func _tabuleiro_salva(clock: float, controle: bool) -> Dictionary:
	var game: Node3D = await _montar_jogo()
	_alinhar(game)
	_zerar(game)
	game.battle_clock = clock
	game._montar_cenario("SISTEMA")
	game.bridge_rig.position = Vector3(0.0, 0.0, 30.0)
	# Um único atirador e um único alvo no corredor da lua: com o resto da linha armado, a diferença
	# entre os lados seria a soma de vários corredores e deixaria de ser conferível dígito a dígito.
	for i in range(1, game.fleet.size()):
		game.fleet[i]["weapons"] = 0.0
		(game.fleet[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 5.0, 150.0, -38.0)
	for i in range(1, game.enemies.size()):
		(game.enemies[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 6.0, -150.0, -82.0)
	var lua: Dictionary = game.astros[1]
	var centro: Vector3 = lua["pos"]
	var rumo: Vector3 = (lua["vel"] as Vector3).normalized()
	var origem := centro - rumo * 22.0
	var destino := centro + rumo * 22.0
	(game.fleet[0]["node"] as Node3D).position = origem
	(game.enemies[0]["node"] as Node3D).position = destino
	game.fleet[0]["order"] = "ATACAR"
	game.selected_target = 0
	game.fogo_densidade = 0
	if controle:
		for i in range(1, game.astros.size()):
			var astro: Dictionary = game.astros[i]
			astro["pos"] = (astro["pos"] as Vector3) + Vector3(0.0, float(astro["raio"]) + 20.0, 0.0)
			game.astros[i] = astro
	var corte: Dictionary = game._barreira_entre(origem, destino)
	game.rng.seed = 606162
	var antes := _hostis_somados(game)
	game._resolve_volley()
	var resumo := String(game.salva_resumo)
	return {"no": game, "perda": antes - _hostis_somados(game), "estado": int(game.rng.state),
		"impactos": int(game.salva_contagem["aliados"]), "parados": _lances_parados(resumo),
		"resumo": resumo, "rochas": int(game.rochas.size()), "astros": int(game.astros.size()),
		"cortou": not corte.is_empty()}

## Alvo limpo para a medida da sombra: casco inteiro, ordem que não é captura e contato apagado —
## sem isto a segunda leitura da varredura herda o `seen` da primeira e aprova por acidente.
func _preparar_alvo(game, indice: int) -> void:
	var foe: Dictionary = game.enemies[indice]
	foe["hp"] = 100.0
	foe["order"] = "LINHA"
	foe["seen"] = false
	game.enemies[indice] = foe

## Os dois tabuleiros da seção 3, lidos lua a lua no mesmo relógio.
func _fino_igual_a_bruto(fino, bruto) -> bool:
	for no in range(3):
		var pf: Vector3 = fino.astros[no + 1]["pos"]
		var pb: Vector3 = bruto.astros[no + 1]["pos"]
		if pf.distance_to(pb) > FOLGA:
			return false
	return true
