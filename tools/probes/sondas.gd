extends SceneTree

## Prova que o reconhecimento virou corpo no tabuleiro: a ordem SONDAS DE RECONHECIMENTO põe
## uma sonda visível por casco vivo (e no máximo uma por casco), a sonda anda, confirma só o
## hull que ela fisicamente alcança, expira depois de um tempo, e a barra da ponte passa a
## ser a fração da linha hostil encostada — não o tempo decorrido. Contato não confirmado é
## "NÃO IDENTIFICADO" no seletor; o casco do inimigo que nenhuma sonda alcançou continua
## escondido. A prova central é a inércia: com e sem sonda, na mesma semente e no mesmo
## tabuleiro alinhado, casco/motores/armas/tripulação, as posições dos cascos e o estado do
## RNG permanecem idênticos.
##
## Uso: godot --headless --path . --quit-after 1800 -s res://tools/probes/sondas.gd

## As constantes de main.gd estão escritas por extenso porque a sonda mede o contrato; elas
## não são alcançáveis através da instância não tipada do jogo.
const VIDA_SONDA := 30.0
const RAIO_VARREDURA := 9.0
const PASSO_SONDA := 16.0
const FUNDO_VARREDURA := -104.0

var breaks := 0
var notes: Array[String] = []

func _assert(label: String, condition: bool, detail: String) -> void:
	if condition:
		notes.append("OK   %s — %s" % [label, detail])
	else:
		breaks += 1
		notes.append("QUEBRA %s — %s" % [label, detail])

## Tabuleiro canônico: sem isto a medida dependesse do `rng.randomize()` do `_ready()` e cada
## rodada imprimiria um número diferente, como acontecia com a distância da escolta.
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
			unit["seen"] = false

## Assinatura de combate: só subsistemas e posições dos cascos. As sondas ficam de fora
## de propósito — é exatamente isso que se quer comparar entre os dois lados do A/B.
func _assinatura(game) -> String:
	var parts: Array[String] = []
	for list in [game.fleet, game.enemies]:
		for unit in list:
			var node: Node3D = unit["node"]
			parts.append("%s:%.2f/%.2f/%.2f/%.2f@%.2f,%.2f,%.2f" % [unit["name"], float(unit["hp"]),
				float(unit["engines"]), float(unit["weapons"]), float(unit["crew"]),
				node.position.x, node.position.y, node.position.z])
	return "|".join(parts)

func _vistos(game) -> int:
	var n := 0
	for foe in game.enemies:
		if bool(foe.get("seen", false)):
			n += 1
	return n

func _escolha(game, scope: String, order: String) -> void:
	game.selection_scope = scope
	game._give_order(order)

func _initialize() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	await _frames(3)
	game.paused = true
	game.rng.seed = 20261020
	_alinhar(game)

	# 1 — o estado de partida: nada no ar, seis cascos a confirmar, zero cobertura.
	_assert("largada sem sonda", game.probes.is_empty(), "%d sonda(s)" % game.probes.size())
	_assert("denominador real na largada", int(game.recon_total) == 6 and int(game.recon_contacts) == 0,
		"%d/%d contato(s)" % [game.recon_contacts, game.recon_total])
	_assert("cobertura zero na largada", absf(float(game.recon_progress)) < 0.001,
		"%.1f%%" % float(game.recon_progress))
	_assert("nenhum hull visto", _vistos(game) == 0, "%d marcado(s) como visto" % _vistos(game))
	game._update_hud()
	_assert("ponte esconde o casco não varrido", String(game.target_selector.get_item_text(0)).contains("NÃO IDENTIFICADO"),
		String(game.target_selector.get_item_text(0)))

	# 2 — a ordem cria um objeto de verdade, e um só por casco.
	_escolha(game, "NAVE 1", "RECONHECER")
	_assert("uma sonda por casco lançado", game.probes.size() == 1, "%d sonda(s)" % game.probes.size())
	var node: Node3D = game.probes[0]["node"]
	_assert("a sonda está na cena", is_instance_valid(node) and node.is_inside_tree()
		and node.visible and node.get_child_count() >= 2,
		"%s, %d filho(s)" % [str(node), node.get_child_count()])
	_assert("a sonda sabe de quem saiu", int(game.probes[0]["from"]) == 0
		and String(game.probes[0]["launcher"]) == String(game.fleet[0]["name"]),
		"de %s" % game.probes[0]["launcher"])
	_assert("relatório de lançamento", String(game.report_label.text).contains("SONDAS LANÇADAS"),
		String(game.report_label.text))
	_escolha(game, "NAVE 1", "RECONHECER")
	_assert("segundo clique não empilha", game.probes.size() == 1, "%d sonda(s)" % game.probes.size())
	_assert("relatório de recusa", String(game.report_label.text).contains("JÁ EM VARREDURA"),
		String(game.report_label.text))

	# 3 — a sonda é um corpo que anda, e anda no rumo certo.
	var z_inicial := float(node.position.z)
	var x_inicial := absf(float(node.position.x) - float(game.probes[0]["lane_x"]))
	game._update_probes(1.0)
	_assert("a sonda avança sobre o tabuleiro", float(node.position.z) < z_inicial - 1.0,
		"z %.2f → %.2f" % [z_inicial, float(node.position.z)])
	_assert("a sonda fecha para o próprio corredor",
		absf(float(node.position.x) - float(game.probes[0]["lane_x"])) < x_inicial,
		"Δx %.2f → %.2f" % [x_inicial, absf(float(node.position.x) - float(game.probes[0]["lane_x"]))])
	_assert("a sonda não sai do mapa", float(node.position.z) >= FUNDO_VARREDURA - 0.5,
		"z %.2f" % float(node.position.z))
	_assert("vida contada", absf(float(game.probes[0]["life"]) - (VIDA_SONDA - 1.0)) < 0.001,
		"restam %.1f" % float(game.probes[0]["life"]))

	# 4 — a varredura é de vizinhança, não de cronômetro.
	var frames := 0
	while frames < 12 and int(game.recon_contacts) == 0:
		game._update_probes(1.0)
		frames += 1
	_assert("a sonda confirmou o corredor dela", bool(game.enemies[0].get("seen", false)),
		"-%d quadro(s), %d/%d" % [frames, game.recon_contacts, game.recon_total])
	_assert("a sonda solitária não cobre a linha", int(game.recon_contacts) < int(game.recon_total),
		"%d/%d confirmado(s)" % [game.recon_contacts, game.recon_total])
	_assert("quem está do outro lado da linha continua escuro",
		not bool(game.enemies[3].get("seen", false)),
		"x %.1f a %.1f de distância, raio %.1f" % [(game.enemies[3]["node"] as Node3D).position.x,
			float(game.probes[0]["lane_x"]), RAIO_VARREDURA])
	_assert("cobertura igual à fração vista",
		absf(float(game.recon_progress) - 100.0 * float(game.recon_contacts) / float(game.recon_total)) < 0.001,
		"%.1f%% = %d/%d" % [float(game.recon_progress), game.recon_contacts, game.recon_total])
	game._update_hud()
	_assert("seletor mostra o casco varrido", String(game.target_selector.get_item_text(0)).contains("CASCO"),
		String(game.target_selector.get_item_text(0)))
	_assert("seletor esconde o não varrido", not String(game.target_selector.get_item_text(3)).contains("CASCO"),
		String(game.target_selector.get_item_text(3)))

	# 5 — frota inteira lançada fecha a cobertura, com teto de uma sonda por casco.
	_escolha(game, "FROTA", "RECONHECER")
	_assert("sonda por casco vivo, sem duplicar", game.probes.size() == 6, "%d sonda(s)" % game.probes.size())
	frames = 0
	while frames < 24 and int(game.recon_contacts) < int(game.recon_total):
		game._update_probes(1.0)
		frames += 1
	_assert("varredura total", int(game.recon_contacts) == int(game.recon_total)
		and absf(float(game.recon_progress) - 100.0) < 0.001,
		"%d/%d em %d quadro(s), %.1f%%" % [game.recon_contacts, game.recon_total, frames, float(game.recon_progress)])
	game._update_hud()
	var opacos := 0
	for i in range(game.enemies.size()):
		if not String(game.target_selector.get_item_text(i)).contains("CASCO"):
			opacos += 1
	_assert("ponte inteira identificada", opacos == 0, "%d contato(s) ainda sem casco" % opacos)

	# 6 — o denominador são cascos vivos: um destroço sai da conta mesmo se já foi visto, e
	# é por isso que a cobertura não pode passar de 100% quando a linha encolhe.
	(game.enemies[0]["node"] as Node3D).visible = false
	game.enemies[0]["hp"] = 0.0
	game._update_probes(0.1)
	_assert("destroço fora do denominador", int(game.recon_total) == 5, "%d hostil(is) vivo(s)" % game.recon_total)
	_assert("destroço visto fora do numerador", int(game.recon_contacts) == 5,
		"%d/%d — o morto saiu dos dois lados" % [game.recon_contacts, game.recon_total])
	_assert("cobertura não estoura o teto", absf(float(game.recon_progress) - 100.0) < 0.001,
		"%.1f%%" % float(game.recon_progress))
	_assert("conhecimento não é apagado pela morte", bool(game.enemies[0].get("seen", false)),
		"destroço continua marcado")

	# 7 — a sonda sobrevive à morte de quem a lançou.
	game.fleet[1]["hp"] = 0.0
	(game.fleet[1]["node"] as Node3D).visible = false
	var antes: int = game.probes.size()
	game._update_probes(1.0)
	_assert("morta a nave, a sonda continua", game.probes.size() == antes,
		"%d → %d sonda(s)" % [antes, game.probes.size()])

	# 8 — expiração: o objeto sai de cena e a informação fica.
	var contatos_fixados := int(game.recon_contacts)
	var cobertura_fixada := float(game.recon_progress)
	for i in range(int(VIDA_SONDA) + 2):
		game._update_probes(1.0)
	_assert("sondas expiram", game.probes.is_empty(), "%d no ar" % game.probes.size())
	_assert("conhecimento sobrevive à sonda", int(game.recon_contacts) == contatos_fixados
		and absf(float(game.recon_progress) - cobertura_fixada) < 0.001,
		"%d/%d contato(s), %.1f%%" % [game.recon_contacts, game.recon_total, game.recon_progress])

	# 9 — sem hostil, sem divisão por zero e sem barra falsa.
	for foe in game.enemies:
		foe["hp"] = 0.0
	game.enemies.clear()
	game._update_probes(0.1)
	_assert("tabuleiro vazio zera a conta", int(game.recon_total) == 0 and int(game.recon_contacts) == 0
		and absf(float(game.recon_progress)) < 0.001,
		"%d/%d, %.1f%%" % [game.recon_contacts, game.recon_total, game.recon_progress])
	game._update_hud()
	_assert("HUD com tabuleiro vazio", String(game.command_label.text).contains("0/0"),
		String(game.command_label.text).split("\n")[2])

	# 10 — a prova central: a sonda não move um número de combate nem gasta um sorteio.
	var controle := (load("res://main.tscn") as PackedScene).instantiate()
	var experimental := (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(controle)
	get_root().add_child(experimental)
	await _frames(3)
	for side in [controle, experimental]:
		side.paused = true
		side.rng.seed = 20261020
		_alinhar(side)
		_zerar(side)
		side.selection_scope = "FROTA"
		for unit in side.fleet:
			unit["order"] = "RECONHECER"
	_escolha(experimental, "FROTA", "RECONHECER")
	_assert("lado B tem as seis sondas", experimental.probes.size() == 6
		and controle.probes.is_empty(),
		"B=%d, A=%d" % [experimental.probes.size(), controle.probes.size()])
	for cycle in range(8):
		for side in [controle, experimental]:
			side._update_fleet(0.1)
			side._update_probes(0.1)
			side._resolve_volley()
	var valores_a := _assinatura(controle)
	var valores_b := _assinatura(experimental)
	_assert("mesmos números, com e sem sonda", valores_a == valores_b,
		"A=%.1f/%.1f de casco somado, B idêntico=%s" % [_somar_casco(controle), _somar_casco(experimental),
			str(valores_a == valores_b)])
	_assert("mesma cauda de RNG", int(controle.rng.state) == int(experimental.rng.state),
		"estado A=%d, B=%d" % [int(controle.rng.state), int(experimental.rng.state)])
	_assert("o A/B não foi medida em tabuleiro vazio", _assinatura(controle).length() > 100
		and _somar_casco(controle) > 0.0,
		"casco total %.1f" % _somar_casco(controle))

	# 11 — o contrato do HUD: cinco linhas, a linha da sonda é a terceira, a postura continua
	# na última (é assim que `tatica.gd` lê).
	_escolha(controle, "FROTA", "RECONHECER")
	controle._update_hud()
	var linhas: PackedStringArray = String(controle.command_label.text).split("\n")
	_assert("HUD em cinco linhas", linhas.size() == 5, "%d linha(s)" % linhas.size())
	_assert("linhas da sonda e da postura intactas",
		String(linhas[2]).begins_with("RECONHECIMENTO:") and String(linhas[2]).contains("sonda(s)")
			and String(linhas[4]) == String(controle.tactical_note),
		linhas[2])

	for line in notes:
		print("SONDA-SONDAS: %s" % line)
	print("SONDA-SONDAS: veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	quit()

func _somar_casco(game) -> float:
	var total := 0.0
	for list in [game.fleet, game.enemies]:
		for unit in list:
			total += float(unit["hp"])
	return total

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame
