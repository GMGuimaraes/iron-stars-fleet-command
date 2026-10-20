extends SceneTree

## Prova que a leitura tática hostil decide sem empurrar número: a mesma força dos dois
## lados continua em AVANÇAR, a capitânia hostil ferida vira ESCOLTA com exatamente dois
## cascos em postos opostos, a desproporção vira RECUAR, a capitânia perdida vira DEBACLA,
## uma salva hostil inteira cai sobre um único casco aliado, a reserva tática não é lida
## como alvo, a escolta fecha distância e a retirada para na linha de reunião. Avaliar e
## aplicar não consomem sorteio nenhum e não tocam em casco, motores, armas nem tripulação.
##
## Uso: godot --headless --path . --quit-after 1800 -s res://tools/probes/tatica.gd

## Os tetos de navegação são as constantes HOSTILE_ADVANCE_Z / HOSTILE_RALLY_Z de main.gd.
## Aquí estão escritos por extenso porque a sonda mede o contrato, não relê a constante.
const FUNDO_RETIRADA := -92.0
const TETO_AVANCO := -60.0

var breaks := 0
var notes: Array[String] = []

func _assert(label: String, condition: bool, detail: String) -> void:
	if condition:
		notes.append("OK   %s — %s" % [label, detail])
	else:
		breaks += 1
		notes.append("QUEBRA %s — %s" % [label, detail])

## Subsistemas de todas as naves, nas duas listas. Sem ordem nem posição: é por esta
## assinatura que se separa "a IA leu o tabuleiro" de "a IA mexeu no tabuleiro".
func _valores(game) -> String:
	var parts: Array[String] = []
	for list in [game.fleet, game.enemies]:
		for unit in list:
			parts.append("%s:%.2f/%.2f/%.2f/%.2f" % [unit["name"], float(unit["hp"]),
				float(unit["engines"]), float(unit["weapons"]), float(unit["crew"])])
	return "|".join(parts)

func _ordens(game) -> String:
	var parts: Array[String] = []
	for unit in game.enemies:
		parts.append("%s=%s" % [unit["name"], unit["order"]])
	return " ".join(parts)

## Só casco vivo conta: um destroço continua carregando a última ordem que recebeu, e
## contá-lo como obediência é a mesma fraude de medir prateleira vazia como venda.
func _count_order(game, wanted: String) -> int:
	var n := 0
	for unit in game.enemies:
		if float(unit["hp"]) > 0.0 and String(unit["order"]) != "CAPTURADO" and String(unit["order"]) == wanted:
			n += 1
	return n

func _marca(list, index: int, key: String, value) -> void:
	var unit: Dictionary = list[index]
	unit[key] = value

func _initialize() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	await _frames(3)
	game.paused = true
	game.rng.seed = 20261020

	# 1 — paridade de forças não é risco: a linha hostil continua avançando.
	var read: Dictionary = game._assess_hostiles()
	_assert("base 6x6", game.fleet.size() == 6 and game.enemies.size() == 6,
		"aliadas %d, hostis %d" % [game.fleet.size(), game.enemies.size()])
	_assert("paridade avança", String(read["posture"]) == "AVANÇAR",
		"força relativa %.3f, postura %s" % [float(read["ratio"]), read["posture"]])
	_assert("razão de paridade", absf(float(read["ratio"]) - 0.5) < 0.01,
		"hostil %.1f contra aliado %.1f" % [float(read["hostile_power"]), float(read["friendly_power"])])
	_assert("capitânia identificada", int(read["command_index"]) == 0
		and String(game.enemies[0]["role"]) == "COMANDO", String(game.enemies[0]["name"]))
	_assert("alarmes desligados na largada", not bool(read["rout"]) and not bool(read["command_hurt"]),
		"capitânia inteira, frota equilibrada")

	# 2 — avaliar é puro: nem número, nem ordem, nem sorteio se move.
	var valores_antes := _valores(game)
	var ordens_antes := _ordens(game)
	var sorteio_antes := int(game.rng.state)
	game._assess_hostiles()
	game._assess_hostiles()
	_assert("avaliar não move número", _valores(game) == valores_antes, "assinatura idêntica")
	_assert("avaliar não move ordem", _ordens(game) == ordens_antes, "assinatura idêntica")
	_assert("avaliar não sorteia", int(game.rng.state) == sorteio_antes, "estado do RNG intacto")

	# 3 — aplicar converte a leitura em ordens uma vez por salva, sem tocar nos números.
	game._apply_hostile_tactics()
	_assert("aplicar não move número", _valores(game) == valores_antes,
		"cascos, motores, armas e tripulações idênticos")
	_assert("aplicar não sorteia", int(game.rng.state) == sorteio_antes, "estado do RNG intacto")
	_assert("postura vira ordem em todos", _count_order(game, "AVANÇAR") == 6, _ordens(game))
	_assert("foco declarado", game.hostile_focus == game._hostile_victim_index(),
		"foco %d" % game.hostile_focus)
	_assert("nota lê a postura", String(game.tactical_note).contains("AVANÇAR"),
		String(game.tactical_note))

	# 4 — escolha de vítima: vulnerável e que ameaça.
	_marca(game.fleet, 2, "hp", 20.0)
	_marca(game.fleet, 2, "order", "ATACAR")
	var vitima: int = game._hostile_victim_index()
	_assert("casco ferido e agressivo é o alvo", vitima == 2,
		"índice %d (%s)" % [vitima, game.fleet[vitima]["name"]])

	# 5 — reserva tática não é lida como alvo, por pior que esteja.
	_marca(game.fleet, 2, "hp", 5.0)
	_marca(game.fleet, 2, "order", "RESERVA")
	vitima = game._hostile_victim_index()
	_assert("reserva intocável", vitima != 2,
		"fogo em %d (%s)" % [vitima, game.fleet[vitima]["name"]])

	# 6 — se tudo está em reserva, ainda há a quem atirar: nunca índice negativo.
	for i in range(game.fleet.size()):
		_marca(game.fleet, i, "order", "RESERVA")
	_assert("sem alvo válido não trava a salva", game._hostile_victim_index() == 0,
		"primeiro casco vivo")
	for i in range(game.fleet.size()):
		_marca(game.fleet, i, "order", "LINHA")

	# 7 — capitânia hostil ferida: escolta, com dois cascos em postos opostos.
	_marca(game.enemies, 0, "hp", 45.0)
	read = game._assess_hostiles()
	_assert("capitânia ferida vira escolta", String(read["posture"]) == "ESCOLTA"
		and bool(read["command_hurt"]), "razão %.3f" % float(read["ratio"]))
	var valores_escolta := _valores(game)
	game._apply_hostile_tactics()
	_assert("escolta não move número", _valores(game) == valores_escolta, "assinatura idêntica")
	_assert("exatamente dois escoltas", _count_order(game, "ESCOLTAR") == 2, _ordens(game))
	var postos: Array[String] = []
	for unit in game.enemies:
		if unit["order"] == "ESCOLTAR":
			postos.append(str(unit.get("escort_offset", 0.0)))
	_assert("postos alternados", postos.size() == 2 and postos[0] != postos[1], ", ".join(postos))
	_assert("capitânia se afasta", String(game.enemies[0]["order"]) == "RECUAR",
		"o grosso também recua: %s" % _ordens(game))
	_assert("nota lê a escolta", String(game.tactical_note).contains("ESCOLTA")
		and String(game.tactical_note).contains("2 casco"), String(game.tactical_note))

	# 8 — a escolta fecha distância até o próprio posto.
	var escolta_index := -1
	for i in range(game.enemies.size()):
		if game.enemies[i]["order"] == "ESCOLTAR":
			escolta_index = i
			break
	var escolta_node: Node3D = game.enemies[escolta_index]["node"]
	var ancora: Vector3 = (game.enemies[0]["node"] as Node3D).position
	var posto := ancora + Vector3(float(game.enemies[escolta_index].get("escort_offset", 3.0)), 0.0, 7.0)
	var antes := escolta_node.position.distance_to(posto)
	for i in range(12):
		game._update_fleet(1.0)
	var depois := escolta_node.position.distance_to(posto)
	_assert("escolta alcança o posto", depois < antes, "%.2f -> %.2f até o posto" % [antes, depois])

	# 9 — desproporção: a linha hostil recua quando vale pouco diante da aliada.
	_marca(game.enemies, 0, "hp", 100.0)
	# Limpa a aliada ferida da medida anterior: sem isso a razão não é 3 cascos contra 6,
	# e a sonda leria um número que ela mesma bagunçou.
	_marca(game.fleet, 2, "hp", 100.0)
	for i in range(1, 4):
		_marca(game.enemies, i, "hp", 0.0)
	read = game._assess_hostiles()
	_assert("três cascos a menos", absf(float(read["ratio"]) - 0.333) < 0.01,
		"razão %.3f (hostil %.1f contra aliado %.1f)" % [float(read["ratio"]),
		float(read["hostile_power"]), float(read["friendly_power"])])
	_assert("desproporção recua", String(read["posture"]) == "RECUAR", String(read["posture"]))
	game._apply_hostile_tactics()
	_assert("recuo é ordem de quem vive", _count_order(game, "RECUAR") == 3, _ordens(game))
	var fugitiva: Node3D = game.enemies[4]["node"]
	var morta: Node3D = game.enemies[1]["node"]
	var z_morta := morta.position.z
	var z_antes := fugitiva.position.z
	game._update_fleet(1.0)
	_assert("recuo afasta do jogador", fugitiva.position.z < z_antes,
		"z %.2f -> %.2f" % [z_antes, fugitiva.position.z])
	_assert("destroço não manobra", is_equal_approx(morta.position.z, z_morta),
		"o casco morto conserva a última ordem (%s) e não se move um centímetro" % game.enemies[1]["order"])

	# 10 — recuo tem fundo: a linha de reunião, não o vazio do mapa.
	fugitiva.position = Vector3(fugitiva.position.x, fugitiva.position.y, -260.0)
	game._update_fleet(1.0)
	_assert("fundo da retirada", is_equal_approx(fugitiva.position.z, FUNDO_RETIRADA),
		"z %.2f com fundo em %.2f" % [fugitiva.position.z, FUNDO_RETIRADA])

	# 11 — avanço tem teto: a linha de engajamento fica à vista da ponte.
	_marca(game.enemies, 4, "order", "AVANÇAR")
	for i in range(90):
		game._update_fleet(1.0)
	_assert("teto do avanço", is_equal_approx(fugitiva.position.z, TETO_AVANCO),
		"z %.2f com teto em %.2f" % [fugitiva.position.z, TETO_AVANCO])

	# 12 — sem capitânia entre os vivos não há manobra: debandada.
	for i in range(1, 4):
		_marca(game.enemies, i, "hp", 100.0)
	_marca(game.enemies, 0, "hp", 0.0)
	read = game._assess_hostiles()
	_assert("capitânia perdida é debandada", bool(read["rout"])
		and String(read["posture"]) == "RECUAR", String(read["posture"]))
	game._apply_hostile_tactics()
	_assert("nota lê a debandada", String(game.tactical_note).contains("DEBACLA"),
		String(game.tactical_note))

	# 13 — a mudança de postura chega ao comandante uma vez; postura repetida não spammar.
	game.report_label.text = "SILÊNCIO DE RÁDIO"
	game._apply_hostile_tactics()
	_assert("postura repetida não spammar", String(game.report_label.text) == "SILÊNCIO DE RÁDIO",
		String(game.report_label.text))
	_marca(game.enemies, 0, "hp", 40.0)
	game._apply_hostile_tactics()
	_assert("postura nova notifica", String(game.report_label.text).begins_with("INTELIGÊNCIA //"),
		String(game.report_label.text))

	# 14 — fogo concentrado: a retaliação inteira cai sobre um só casco aliado.
	for i in range(game.enemies.size()):
		_marca(game.enemies, i, "hp", 100.0)
		_marca(game.enemies, i, "weapons", 100.0)
		_marca(game.enemies, i, "crew", 100.0)
	for i in range(game.fleet.size()):
		_marca(game.fleet, i, "hp", 100.0)
	var tocadas_antes := 0
	for i in range(game.fleet.size()):
		if float(game.fleet[i]["hp"]) < 100.0:
			tocadas_antes += 1
	game._resolve_volley()
	var atingidas: Array[int] = []
	for i in range(game.fleet.size()):
		if float(game.fleet[i]["hp"]) < 100.0:
			atingidas.append(i)
	_assert("nenhum aliado já ferido", tocadas_antes == 0, "partida limpa para a medida")
	_assert("retaliação concentrada num casco", atingidas.size() == 1
		and atingidas[0] == game.hostile_focus,
		"foco %d, atingidas %s" % [game.hostile_focus, str(atingidas)])
	_assert("dano aplicado no foco", float(game.fleet[game.hostile_focus]["hp"]) < 100.0,
		"casco %.1f do foco %d" % [float(game.fleet[game.hostile_focus]["hp"]), game.hostile_focus])

	# 15 — o HUD devolve a leitura ao comandante sem esconder o resto.
	game._update_hud()
	var linhas: PackedStringArray = String(game.command_label.text).split("\n")
	_assert("HUD mostra a postura", linhas.size() == 5 and linhas[4] == String(game.tactical_note)
		and String(linhas[4]).begins_with("POSTURA HOSTIL:"), linhas[linhas.size() - 1])

	# 16 — tabuleiro vazio não quebra a leitura: sem hostis, sem índice inválido.
	for unit in game.enemies:
		unit["order"] = "CAPTURADO"
	game._resolve_volley()
	_assert("frota inteira por captura", game.enemies.is_empty() and game.fleet.size() == 12,
		"%d aliadas, %d hostis" % [game.fleet.size(), game.enemies.size()])
	game._apply_hostile_tactics()
	_assert("leitura sem tabuleiro", String(game.hostile_posture) == "RECUAR"
		and int(game.hostile_focus) >= 0,
		"%s / foco %d" % [game.hostile_posture, game.hostile_focus])

	for line in notes:
		print("SONDA-TATICA: %s" % line)
	print("SONDA-TATICA: veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	quit()

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame
