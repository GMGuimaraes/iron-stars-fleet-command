extends SceneTree

## Sonda dos cenários: a barreira que vale, o poço que engole e a estrela que aquece.
##
## O pedido do comandante foi «diversas opções onde aplicas a estratégia», e opção falsa é a que
## existe só no painel. Então cada cenário é cobrado pela consequência que ele promete:
##
## 1) CINTURÃO: se a rocha não bloqueia lance, ela é decoração. A barreira tem de parar o tiro que
##    passa por dentro dela, e o preço de bater nela tem de cair no casco que bateu, não na pedra.
##    A prova central é esta: um lance absorvido muda o DANO e não muda o SORTEIO. Se bloquear
##    também pulasse o `rng.randf()` da retaliação, o cinturão seria um reroll disfarçado e toda a
##    cauda da batalha seguinte mudaria por acaso.
## 2) POÇO: quem cruza o horizonte é perdido, e perdido sem pontos de vida intermediários — um poço
##    que fere devagar é uma parede com textura. O puxo, esse, tem de crescer conforme a aproximação
##    (é a única assinatura de gravidade conferível em três linhas), e destroço não volta a cair:
##    quem já afundou é marca no quadro, não corpo na correnteza.
## 3) ESTRELA: calor de arma ≠ cozimento de casco. São dois raios diferentes, e a sonda confere que
##    quem está entre eles só ganha o multiplicador.
##
## E a margem que vale para os três: com o campo aberto nada disso existe. `rochas` vazio, nenhum
## ponto de perigo, `_fator_calor` devolvendo 1,0 em qualquer coordenada. É por isso que a inércia
## não é uma promessa de design, é a primeira família de asserções desta sonda.
##
## O painel também é cobrado: o sétimo grupo existe, os quatro botões executam por `pressed`, trocar
## de cenário desmonta o anterior (rocha dobrada empurraria o casco duas vezes no mesmo quadro) e a
## mesa holográfica mostra a barreira onde mostra os cascos — sem nunca virar blip de casco.
##
## Uso: godot --headless --path . --quit-after 1800 -s res://tools/probes/cenarios.gd

## Espelho das constantes de `main.gd` — a instância do jogo é não tipada (mesmo motivo em
## `tools/probes/menu.gd`). Se o número aqui divergir do código, a asserção quebra: é de propósito.
const MAP_X := 320.0
const MAP_Y := 180.0
const MAP_Z_NEAR := 40.0
const MAP_Z_FAR := -600.0
const HULL_RADIUS := 2.4
const CAPITAL_RADIUS := 6.0
const RAM_SPEED := 3.0
const RAM_WINDOW := 1.5
const ROCHA_QTDE := 14
const ROCHA_RAIO_BASE := 3.2
const ROCHA_RAIO_DEGRAU := 0.9
const ROCHA_LEQUE_X := 58.0
const ROCHA_Z_INICIAL := -24.0
const ROCHA_Z_PASSO := 4.0
const ROCHA_Y_LEQUE := 13.0
const POCO_POS := Vector3(0.0, 0.0, -78.0)
const POCO_ALCANCE := 46.0
const POCO_HORIZONTE := 9.0
const ESTRELA_POS := Vector3(0.0, 24.0, -74.0)
const ESTRELA_CALOR_RAIO := 70.0
const ESTRELA_CALOR_FATOR := 1.25
const ESTRELA_CORONA_RAIO := 30.0
const ESTRELA_QUEIMA := 6.0
const PASSO := 0.1
const NOMES_GRUPOS := ["ATAQUE", "POSTURA", "FORMAÇÕES", "MANOBRA", "REPAROS", "RECONHECIMENTO",
	"CENÁRIO"]
const NOMES_CENARIO := ["ABERTO", "CINTURAO", "POCO", "ESTRELA"]

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

func _cascos_somados(game) -> float:
	var total := 0.0
	for unit in game.fleet:
		total += float(unit["hp"])
	for unit in game.enemies:
		total += float(unit["hp"])
	return total

func _botoes(game, nome: String) -> Array[Button]:
	var lista: Array[Button] = []
	var corpo: Control = game.group_bodies[nome]
	for filho in corpo.get_children():
		if filho is Button:
			lista.append(filho as Button)
	return lista

## A rocha do cinturão, na fórmula de `main.gd` — conferida posição a posição, não "alguma pedra
## existe". Um `ang` trocado no laço mudaria o mapa inteiro sem dar erro.
func _posicao_esperada(i: int) -> Dictionary:
	var ang := float(i) * 2.39996
	var x := cos(ang) * ROCHA_LEQUE_X * (0.35 + 0.13 * float(i % 5))
	var y := sin(ang * 1.7) * ROCHA_Y_LEQUE
	var z := ROCHA_Z_INICIAL - float(i) * ROCHA_Z_PASSO
	return {"pos": Vector3(x, y, z), "raio": ROCHA_RAIO_BASE + float(i % 4) * ROCHA_RAIO_DEGRAU}

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _montar_jogo() -> Node3D:
	var game: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	await _frames(3)
	return game

func _initialize() -> void:
	var game: Node3D = await _montar_jogo()
	_alinhar(game)
	_zerar(game)

	# ---- 1. O padrão é a ausência: campo aberto não tem cenário nenhum ----------------------
	_assert("a ponte abre em campo aberto", String(game.cenario_atual) == "ABERTO"
		and int(game.rochas.size()) == 0
		and bool(game.poco_ativo) == false and bool(game.estrela_ativa) == false,
		"cenario=%s rochas=%d poco=%s estrela=%s" % [game.cenario_atual, game.rochas.size(),
			game.poco_ativo, game.estrela_ativa])
	var calor_fora: float = game._fator_calor(POCO_POS)
	var calor_dentro: float = game._fator_calor(ESTRELA_POS)
	_assert("sem estrela o multiplicador é 1,0 em qualquer ponto do campo",
		_igual(float(calor_fora), 1.0, 0.000001) and _igual(float(calor_dentro), 1.0, 0.000001),
		"1,000 na boca do poço e 1,000 na fotosfera")
	_assert("sem rocha nenhum corredor é bloqueado",
		game._rocha_entre(Vector3(0, 0, -38), Vector3(0, 0, -82)).is_empty(),
		"%d rochas na conta" % game.rochas.size())
	_assert("a nota do campo aberto diz que não há nada no mapa",
		String(game._nota_cenario()).contains("nenhuma barreira"), game._nota_cenario())
	_assert("duzentas chamadas de cenário em campo aberto não movem um dígito",
		_prova_inercia(game), "rng e visual_rng intactos sob ABERTO")

	# ---- 2. O mapa é grande de verdade -------------------------------------------------------
	game.bridge_rig.position = Vector3(900.0, 900.0, -900.0)
	game._update_capital_ship(0.1)
	_assert("o campo novo fecha em x 320 / y 180 / z -600",
		_igual(game.bridge_rig.position.x, MAP_X, 0.0001)
			and _igual(game.bridge_rig.position.y, MAP_Y, 0.0001)
			and _igual(game.bridge_rig.position.z, MAP_Z_FAR, 0.0001),
		"x %0.2f y %0.2f z %0.2f" % [game.bridge_rig.position.x, game.bridge_rig.position.y,
			game.bridge_rig.position.z])
	game.bridge_rig.position = Vector3.ZERO
	_assert("o limite é mar de manobra, não vitrine: a banda de batalha cabe três vezes",
		absf(MAP_Z_FAR - MAP_Z_NEAR) > 3.0 * absf(-92.0 - MAP_Z_NEAR),
		"de %0.0f a %0.0f de ré contra 52 u de banda de batalha" % [MAP_Z_NEAR, MAP_Z_FAR])

	# ---- 3. Cinturão: a pedra é um lugar, não uma lista --------------------------------------
	var visual_antes: int = game.visual_rng.state
	game._montar_cenario("CINTURAO")
	_assert("montar o cinturão não sorteia um pixel",
		int(game.visual_rng.state) == visual_antes,
		"visual_rng %d -> %d" % [visual_antes, game.visual_rng.state])
	_assert("o cinturão tem catorze rochas", int(game.rochas.size()) == ROCHA_QTDE,
		"%d rochas" % game.rochas.size())
	var desencontros := ""
	for i in range(ROCHA_QTDE):
		var esperado := _posicao_esperada(i)
		var medida: Dictionary = game.rochas[i]
		var dp: Vector3 = esperado["pos"]
		var mp: Vector3 = medida["pos"]
		if not _igual(dp.x, mp.x, 0.0001) or not _igual(dp.y, mp.y, 0.0001) \
				or not _igual(dp.z, mp.z, 0.0001) \
				or not _igual(float(esperado["raio"]), float(medida["raio"]), 0.0001):
			desencontros += "%d " % i
	_assert("cada rocha está no lugar e do tamanho da fórmula", desencontros == "",
		"fora do esperado: [%s]" % desencontros)
	var faixa_z := ""
	var minimo_z := INF
	var maximo_z := -INF
	for rocha in game.rochas:
		minimo_z = minf(minimo_z, (rocha["pos"] as Vector3).z)
		maximo_z = maxf(maximo_z, (rocha["pos"] as Vector3).z)
	faixa_z = "%0.0f a %0.0f" % [maximo_z, minimo_z]
	_assert("a barreira veste o corredor entre as duas linhas",
		_igual(maximo_z, ROCHA_Z_INICIAL, 0.0001) and minimo_z < -70.0,
		"z da frente %s — aliada em -38, hostil em -82" % faixa_z)
	var raios := ""
	for i in range(4):
		raios += "%0.1f " % float(game.rochas[i]["raio"])
	_assert("o raio de casco da rocha entra na conta de separação",
		_igual(float(game.rochas[0]["raio"]), ROCHA_RAIO_BASE, 0.0001)
			and float(game.rochas[3]["raio"]) > float(game.rochas[0]["raio"]),
		"quatro primeiros raios: %s" % raios)

	# ---- 4. Barreira que vale: o lance morre na pedra ---------------------------------------
	# Pedra ISOLADA: no cinturão real outras rochas também cruzam este corredor, e a asserção
	# aprovaria pelo obstáculo errado — foi exatamente assim que a primeira rodada quebrou.
	var origem: Vector3 = (game.fleet[0]["node"] as Node3D).position
	var destino: Vector3 = (game.enemies[0]["node"] as Node3D).position
	var meio := (origem + destino) * 0.5
	game._desmontar_cenario()
	game.rochas.append({"no": null, "pos": meio, "raio": ROCHA_RAIO_BASE})
	var corte: Dictionary = game._rocha_entre(origem, destino)
	_assert("rocha no corredor bloqueia o lance", not corte.is_empty(),
		"ponto de contato a %0.2f u do centro da pedra" % (corte["pos"] as Vector3).distance_to(meio))
	game.rochas[0]["pos"] = meio + Vector3(0.0, ROCHA_RAIO_BASE + 4.0, 0.0)
	_assert("corredor a 4 u por fora da pedra está limpo",
		game._rocha_entre(origem, destino).is_empty(),
		"centro deslocado %0.1f u para cima do eixo do tiro" % (ROCHA_RAIO_BASE + 4.0))
	game.rochas[0]["pos"] = meio + Vector3(0.0, ROCHA_RAIO_BASE - 0.1, 0.0)
	var roçando: bool = not game._rocha_entre(origem, destino).is_empty()
	game.rochas[0]["pos"] = meio + Vector3(0.0, ROCHA_RAIO_BASE + 0.1, 0.0)
	_assert("o corte obedece ao raio: 0,1 u dentro bloqueia, 0,1 u fora fura",
		roçando and game._rocha_entre(origem, destino).is_empty(),
		"a %0.1f e a %0.1f u do eixo, pedra de %0.1f u" % [ROCHA_RAIO_BASE - 0.1,
			ROCHA_RAIO_BASE + 0.1, ROCHA_RAIO_BASE])
	_assert("origem e destino no mesmo ponto não inventam barreira",
		game._rocha_entre(origem, origem).is_empty(), "trecho de comprimento zero")
	game.rochas.append({"no": null, "pos": meio, "raio": ROCHA_RAIO_BASE})
	_assert("a barreira mais próxima vence a mais longe",
		_mais_perto_vence(game, origem, destino), "dois bloqueios no mesmo corredor")

	# ---- 5. Bloquear dano não mexe no sorteio ------------------------------------------------
	var a := await _montar_jogo()
	_alinhar(a)
	_zerar(a)
	a.rng.seed = 909090
	var estado_a: int = a.rng.state
	var cascos_a := _cascos_somados(a)
	a._resolve_volley()
	var depois_a: int = a.rng.state
	var cascos_depois_a := _cascos_somados(a)
	var b := await _montar_jogo()
	_alinhar(b)
	_zerar(b)
	b._montar_cenario("CINTURAO")
	b._desmontar_cenario()
	b.rochas.append({"no": null, "pos": ((b.fleet[0]["node"] as Node3D).position
		+ (b.enemies[0]["node"] as Node3D).position) * 0.5, "raio": 6.0})
	b.rng.seed = 909090
	var estado_b: int = b.rng.state
	var cascos_b := _cascos_somados(b)
	b._resolve_volley()
	var depois_b: int = b.rng.state
	var cascos_depois_b := _cascos_somados(b)
	_assert("os dois tabuleiros largam do mesmo estado de gerador",
		int(estado_a) == int(estado_b) and int(cascos_a) == int(cascos_b),
		"rng %d, cascos %.1f dos dois lados" % [estado_a, cascos_a])
	_assert("a pedra absorve o dano da salva", cascos_depois_b > cascos_depois_a + 0.001,
		"cascos %.1f com barreira contra %.1f sem" % [cascos_depois_b, cascos_depois_a])
	_assert("absorver dano não muda quantos sorteios a salva consome",
		int(depois_a) == int(depois_b), "rng %d -> %d, igual nos dois lados" % [estado_a, depois_a])
	_assert("a medida não foi feita em tabuleiro vazio",
		cascos_depois_a < cascos_a - 0.001, "ferimento real de %.1f de casco sem barreira" % (
			cascos_a - cascos_depois_a))
	a.queue_free()
	b.queue_free()
	await _frames(2)

	# ---- 6. Quem bate na pedra perde casco; a pedra não perde nada --------------------------
	game._montar_cenario("CINTURAO")
	_zerar(game)
	_alinhar(game)
	var rocha: Dictionary = game.rochas[0]
	var centro_rocha: Vector3 = rocha["pos"]
	var vitima: Dictionary = game.fleet[0]
	var nodo_vitima: Node3D = vitima["node"]
	nodo_vitima.position = centro_rocha + Vector3(0.0, 0.0, float(rocha["raio"]) - 1.0)
	vitima["veloc"] = Vector3(0.0, 0.0, -30.0)
	var pos_rocha_antes: Vector3 = (rocha["no"] as Node3D).position if rocha["no"] != null else Vector3.INF
	game._chocar_com_rochas()
	_assert("bater no cinturão cobra casco", float(vitima["hp"]) < 100.0,
		"%s: %0.2f de casco após o choque" % [vitima["name"], float(vitima["hp"])])
	_assert("a rocha não cede nem afofa", (rocha["no"] as Node3D).position == pos_rocha_antes
		and (rocha["no"] as Node3D).global_position.distance_to(centro_rocha) < 0.0001,
		"pedra continua em %s" % str(centro_rocha))
	_assert("o casco fica exatamente encostado na pedra",
		_igual(nodo_vitima.global_position.distance_to(centro_rocha),
			HULL_RADIUS + float(rocha["raio"]), 0.001),
		"%0.3f contra %0.3f de soma de raios" % [nodo_vitima.global_position.distance_to(centro_rocha),
			HULL_RADIUS + float(rocha["raio"])])
	var casco_depois := float(vitima["hp"])
	game._chocar_com_rochas()
	_assert("o segundo contato na mesma janela não cobra de novo",
		_igual(float(vitima["hp"]), casco_depois, 0.0001),
		"%0.2f -> %0.2f dentro da janela de %0.1f s" % [casco_depois, float(vitima["hp"]),
			RAM_WINDOW])
	# A ponte é o único aliado que fere a própria frota; contra pedra, quem paga é ela também.
	# O empuxo tem de ser AO LONGO da normal (a ponte está acima da rocha): velocidade lateral
	# daria `aproximacao` zero e a asserção aprovaria um cenário onde nada encosta.
	game.bridge_rig.position = centro_rocha + Vector3(0.0, float(rocha["raio"]) - 1.0, 0.0)
	game.capital_velocity = Vector3(0.0, -40.0, 0.0)
	var capitania_antes := float(game.capital_hp)
	game._chocar_com_rochas()
	_assert("a capitânia abrindo no cinturão perde casco",
		float(game.capital_hp) < capitania_antes, "%0.2f -> %0.2f" % [capitania_antes,
			game.capital_hp])
	game.capital_velocity = Vector3.ZERO

	# ---- 7. Poço: puxo que cresce e horizonte que não negocia --------------------------------
	game._montar_cenario("POCO")
	_zerar(game)
	_assert("o poço acende a flag e apaga o cinturão",
		bool(game.poco_ativo) and int(game.rochas.size()) == 0
			and String(game.cenario_atual) == "POCO",
		"poco=%s rochas=%d" % [game.poco_ativo, game.rochas.size()])
	var rng_antes: int = game.rng.state
	var longe := (game.fleet[0]["node"] as Node3D)
	longe.position = POCO_POS + Vector3(POCO_ALCANCE + 6.0, 0.0, 0.0)
	var antes_longe := longe.position
	game._puxar_para_o_poco(PASSO)
	_assert("fora do alcance o casco não sente nada", longe.position == antes_longe,
		"a %0.0f u do centro, puxo nenhum" % (POCO_ALCANCE + 6.0))
	var midway := (game.fleet[1]["node"] as Node3D)
	midway.position = POCO_POS + Vector3(30.0, 0.0, 0.0)
	var antes_mid := midway.position
	game._puxar_para_o_poco(PASSO)
	# Medir o passo de cada casco na CHAMADA que o move: no empurrão seguinte o casco de 30 u
	# anda de novo, e acumular os dois dava ao mais longe um passo maior que o do mais perto.
	var passo_mid := antes_mid.distance_to(midway.position)
	var perto := (game.fleet[2]["node"] as Node3D)
	perto.position = POCO_POS + Vector3(15.0, 0.0, 0.0)
	var antes_perto := perto.position
	game._puxar_para_o_poco(PASSO)
	var passo_perto := antes_perto.distance_to(perto.position)
	_assert("o puxo cresce conforme o casco se aproxima", passo_perto > passo_mid + 0.001,
		"%0.4f u a 15 contra %0.4f u a 30" % [passo_perto, passo_mid])
	_assert("puxado, o casco anda para dentro e não para o lado",
		midway.position.distance_to(POCO_POS) < 30.0 - 0.001,
		"30 -> %0.4f u do centro" % midway.position.distance_to(POCO_POS))
	_assert("o puxo não sorteia nada", int(game.rng.state) == rng_antes,
		"rng %d intacto em três empurrões" % rng_antes)
	var dentro := (game.fleet[3]["node"] as Node3D)
	var unidade_dentro: Dictionary = game.fleet[3]
	dentro.position = POCO_POS + Vector3(POCO_HORIZONTE - 1.0, 0.0, 0.0)
	game._puxar_para_o_poco(PASSO)
	_assert("quem cruza o horizonte é perdido, não ferido",
		_igual(float(unidade_dentro["hp"]), 0.0, 0.0001)
			and _igual(float(unidade_dentro["engines"]), 0.0, 0.0001)
			and String(game.report_label.text).begins_with("POÇO"),
		"hp %0.1f // %s" % [float(unidade_dentro["hp"]), game.report_label.text])
	var ancora := dentro.position
	game._puxar_para_o_poco(PASSO)
	_assert("destroço não volta a cair: quem afundou é marca, não corpo",
		dentro.position == ancora, "a %0.2f u do centro, parado" % dentro.position.distance_to(POCO_POS))
	# O hostil obedece à mesma conta: é isto que faz do poço uma arma e não um susto só da ponte.
	for enemy in game.enemies:
		(enemy["node"] as Node3D).position = POCO_POS + Vector3(POCO_HORIZONTE - 2.0, 0.0, 0.0)
	game._puxar_para_o_poco(PASSO)
	var hostis_vivos := 0
	for enemy in game.enemies:
		if float(enemy["hp"]) > 0.0 and String(enemy["order"]) != "CAPTURADO":
			hostis_vivos += 1
	_assert("a linha hostil cai no mesmo horizonte", hostis_vivos == 0,
		"%d hostis vivos depois da travessia" % hostis_vivos)
	game._resolve_volley()
	_assert("poço usado como arma fecha a batalha",
		String(game.report_label.text).contains("VITÓRIA"), game.report_label.text)
	# E a ponte, que é o jogador: perdida a capitânia, o relatório é o de sempre.
	var c := await _montar_jogo()
	_zerar(c)
	c._montar_cenario("POCO")
	c.bridge_rig.position = POCO_POS + Vector3(POCO_HORIZONTE - 3.0, 0.0, 0.0)
	c._puxar_para_o_poco(PASSO)
	_assert("a capitânia no horizonte derruba a ponte",
		_igual(float(c.capital_hp), 0.0, 0.0001) and String(c.report_label.text).contains("capitânia"),
		"casco da ponte %0.1f // %s" % [c.capital_hp, c.report_label.text])
	c._resolve_volley()
	_assert("sem ponte a salva declara derrota", String(c.report_label.text).begins_with("DERROTA"),
		c.report_label.text)
	c.queue_free()
	await _frames(2)

	# ---- 8. Estrela: dois raios, duas consequências ------------------------------------------
	game._montar_cenario("ESTRELA")
	_zerar(game)
	_assert("a estrela acende e o poço apaga", bool(game.estrela_ativa) and not bool(game.poco_ativo),
		"estrela=%s poco=%s" % [game.estrela_ativa, game.poco_ativo])
	_assert("dentro do raio de calor a arma bate 25% mais quente",
		_igual(float(game._fator_calor(ESTRELA_POS + Vector3(0, 0, 40))), ESTRELA_CALOR_FATOR, 0.000001),
		"a 40 u do disco: %0.2f" % game._fator_calor(ESTRELA_POS + Vector3(0, 0, 40)))
	_assert("fora do raio de calor o multiplicador é exatamente 1,0",
		_igual(float(game._fator_calor(ESTRELA_POS + Vector3(0, 0, ESTRELA_CALOR_RAIO + 30.0))),
			1.0, 0.000001),
		"a %0.0f u: 1,00" % (ESTRELA_CALOR_RAIO + 30.0))
	var queima := (game.fleet[4]["node"] as Node3D)
	var unidade_queima: Dictionary = game.fleet[4]
	queima.position = ESTRELA_POS + Vector3(0.0, 0.0, 20.0)
	game._queimar_na_corona(1.0)
	_assert("dentro da corona o casco cozinha a seis pontos por segundo",
		_igual(float(unidade_queima["hp"]), 100.0 - ESTRELA_QUEIMA, 0.0001),
		"hp %0.2f depois de 1,0 s a 20 u do disco" % float(unidade_queima["hp"]))
	var assada := (game.fleet[5]["node"] as Node3D)
	var unidade_assada: Dictionary = game.fleet[5]
	assada.position = ESTRELA_POS + Vector3(0.0, 0.0, 40.0)
	game._queimar_na_corona(1.0)
	_assert("aquecer não é cozinhar: a 40 u só o multiplicador vale",
		_igual(float(unidade_assada["hp"]), 100.0, 0.0001),
		"hp %0.2f a 40 u, dentro do calor e fora da corona" % float(unidade_assada["hp"]))
	var ponte_antes := float(game.capital_hp)
	game.bridge_rig.position = ESTRELA_POS + Vector3(0.0, 0.0, 10.0)
	game._queimar_na_corona(1.0)
	_assert("a ponte na corona perde casco do mesmo jeito",
		float(game.capital_hp) < ponte_antes, "%0.2f -> %0.2f" % [ponte_antes, game.capital_hp])

	# ---- 9. Calor que muda a salva, sem mudar o sorteio ---------------------------------------
	var d := await _montar_jogo()
	_alinhar(d)
	_zerar(d)
	d.rng.seed = 31337
	var alvo_d: Dictionary = d.enemies[0]
	var antes_d := float(alvo_d["hp"])
	d._resolve_volley()
	var perda_d := antes_d - float(alvo_d["hp"])
	var estado_d: int = d.rng.state
	var e := await _montar_jogo()
	_zerar(e)
	e._montar_cenario("ESTRELA")
	for i in range(e.fleet.size()):
		var ang := TAU * float(i) / 6.0
		(e.fleet[i]["node"] as Node3D).position = ESTRELA_POS + Vector3(cos(ang) * 45.0, 0.0,
			sin(ang) * 45.0)
	for i in range(e.enemies.size()):
		(e.enemies[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 6.0, 0.0, -82.0)
	e.rng.seed = 31337
	var alvo_e: Dictionary = e.enemies[0]
	var antes_e := float(alvo_e["hp"])
	e._resolve_volley()
	var perda_e := antes_e - float(alvo_e["hp"])
	var estado_e: int = e.rng.state
	_assert("a salva quente bate 25% mais", _igual(perda_e, perda_d * ESTRELA_CALOR_FATOR, 0.001),
		"%.3f de casco contra %.3f no campo aberto" % [perda_e, perda_d])
	_assert("o calor não compra sorteio extra", int(estado_d) == int(estado_e),
		"rng %d dos dois lados depois da salva" % estado_d)
	d.queue_free()
	e.queue_free()
	await _frames(2)

	# ---- 10. O painel entrega o cenário --------------------------------------------------------
	var corpos: Dictionary = game.group_bodies
	_assert("sete grupos no painel", corpos.size() == 7 and game.group_heads.size() == 7,
		"%d cabeçalhos / %d corpos" % [game.group_heads.size(), corpos.size()])
	var cenario_botoes := _botoes(game, "CENÁRIO")
	var rotulos := ""
	for botao in cenario_botoes:
		rotulos += botao.text + " | "
	_assert("o grupo CENÁRIO traz os quatro mapas", cenario_botoes.size() == 4,
		"%d botões: %s" % [cenario_botoes.size(), rotulos])
	var total := 0
	for nome in NOMES_GRUPOS:
		total += _botoes(game, nome).size()
	_assert("vinte e quatro comandos agrupados", total == 24, "%d botões em 7 grupos" % total)
	for botao in cenario_botoes:
		if botao.text.contains("CINTURÃO"):
			botao.pressed.emit()
	_assert("clicar no cinturão monta o cinturão", int(game.rochas.size()) == ROCHA_QTDE
		and String(game.report_label.text).begins_with("CENÁRIO: CINTURÃO"),
		game.report_label.text)
	for botao in cenario_botoes:
		if botao.text.contains("POÇO"):
			botao.pressed.emit()
	_assert("trocar de cenário desmonta o anterior (nada de rocha dobrada)",
		int(game.rochas.size()) == 0 and bool(game.poco_ativo) and not bool(game.estrela_ativa),
		"agora %d rochas, poco=%s" % [game.rochas.size(), game.poco_ativo])
	await _frames(4)
	# 1 cilindro de boca + 28 billets do aro = 29 nós. Medir a conta exata é o que pega nó órfão:
	# `>= 1` aprovaria o cinturão inteiro ainda pendurado junto do poço.
	_assert("os nós do cenário antigo saem de cena, não ficam pendurados",
		is_instance_valid(game.cenario_root) and game.cenario_root.get_child_count() == 29,
		"%d filhos em Cenario com o poço montado" % game.cenario_root.get_child_count())
	for botao in cenario_botoes:
		if botao.text.contains("CAMPO ABERTO"):
			botao.pressed.emit()
	await _frames(4)
	_assert("voltar ao campo aberto larga todos os nós",
		int(game.cenario_root.get_child_count()) == 0 and int(game.holo_cenario.size()) == 0,
		"%d filhos e %d marcas na mesa" % [game.cenario_root.get_child_count(),
			game.holo_cenario.size()])

	# ---- 11. A mesa lê a barreira onde lê os cascos -------------------------------------------
	game._montar_cenario("CINTURAO")
	var blips_cascos: int = (game.holo_blips as Dictionary).size()
	var cascos_vivos := 0
	for unit in game.fleet:
		if is_instance_valid(unit["node"]):
			cascos_vivos += 1
	for unit in game.enemies:
		if is_instance_valid(unit["node"]):
			cascos_vivos += 1
	_assert("rocha não vira blip de casco: a conta da mesa continua um blip por corpo no quadro",
		blips_cascos == cascos_vivos, "%d blips para %d cascos no quadro" % [blips_cascos, cascos_vivos])
	_assert("cada pedra tem marca na mesa", int(game.holo_cenario.size()) == ROCHA_QTDE,
		"%d marcas para %d rochas" % [game.holo_cenario.size(), game.rochas.size()])
	var fora := 0
	for i in range(game.rochas.size()):
		var marca: MeshInstance3D = game.holo_cenario[i]
		var esperado: Vector3 = game._holo_de(game.rochas[i]["pos"])
		if marca.position.distance_to(esperado) > 0.0001:
			fora += 1
	_assert("a marca holográfica bate com a posição real da pedra", fora == 0,
		"%d de %d marcas fora do lugar" % [fora, game.rochas.size()])
	game._montar_cenario("POCO")
	_assert("o poço tem uma marca na mesa", int(game.holo_cenario.size()) == 1,
		"%d marcas" % game.holo_cenario.size())
	game._montar_cenario("ESTRELA")
	_assert("a estrela tem uma marca na mesa", int(game.holo_cenario.size()) == 1,
		"%d marcas" % game.holo_cenario.size())
	game._montar_cenario("ABERTO")
	_assert("o campo aberto não pinta marca nenhuma", int(game.holo_cenario.size()) == 0,
		"%d marcas" % game.holo_cenario.size())

	# ---- 12. Nota do painel: cada cenário diz o preço que cobra ------------------------------
	var notas := ""
	for nome in NOMES_CENARIO:
		game._montar_cenario(nome)
		notas += String(game.report_label.text) + "\n     "
	_assert("as quatro notas anunciam consequência, não enfeite",
		notas.contains("14 rochas") and notas.contains("46 u") and notas.contains("25% mais quente")
			and notas.contains("nenhuma barreira"),
		"\n     %s" % notas)
	game._montar_cenario("ABERTO")

	notes.append("veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	for linha in notes:
		print("SONDA-CENARIOS: %s" % linha)
	game.queue_free()
	await _frames(2)
	quit()

## A pedra mais próxima do corredor é a que bloqueia: se a conta devolvesse a segunda, o lance
## morreria atrás de um obstáculo que já estava para trás. Uma asserção que valesse "qualquer
## pedra" aprovaria a errada — aqui o ponto devolvido tem de cair no lado de cá do meio do tiro.
func _mais_perto_vence(game, origem: Vector3, destino: Vector3) -> bool:
	var meio := (origem + destino) * 0.5
	game.rochas[0]["pos"] = meio + Vector3(0.0, 0.0, -6.0)
	game.rochas[1]["pos"] = meio + Vector3(0.0, 0.0, 12.0)
	var corte: Dictionary = game._rocha_entre(origem, destino)
	if corte.is_empty():
		return false
	return (corte["pos"] as Vector3).z > meio.z + 0.001

## Duzentas chamadas do laço de cenário em campo aberto: nenhum gerador se move.
func _prova_inercia(game) -> bool:
	var rng_antes: int = game.rng.state
	var visual_antes: int = game.visual_rng.state
	for i in range(200):
		game._aplicar_cenario(PASSO)
	return int(game.rng.state) == rng_antes and int(game.visual_rng.state) == visual_antes
