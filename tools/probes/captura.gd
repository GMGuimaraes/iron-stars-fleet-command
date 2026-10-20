extends SceneTree

## Prova que a abordagem entrega uma unidade, não um troféu parado: a presa sai de
## `enemies`, entra em `fleet` como esquadrão PRESA, obedece ordem, é reparada pela própria
## tripulação, sai do fogo hostil, e seletores + HUD passam a contar a frota nova.
##
## Uso: godot --headless --path . --quit-after 1800 -s res://tools/probes/captura.gd

var breaks := 0
var notes: Array[String] = []

func _assert(label: String, condition: bool, detail: String) -> void:
	if condition:
		notes.append("OK   %s — %s" % [label, detail])
	else:
		breaks += 1
		notes.append("QUEBRA %s — %s" % [label, detail])

func _initialize() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	await _frames(3)
	game.paused = true
	game.rng.seed = 20261020

	# 1 — chão da medição: a frota e a lista de hostis como o jogo as monta.
	_assert("base", game.fleet.size() == 6 and game.enemies.size() == 6,
		"aliadas %d, hostis %d" % [game.fleet.size(), game.enemies.size()])

	# 2 — prepara a captura: alvo a 40% de casco e tripulação por um fio, abordador colado.
	var prize_index := 2
	var prize_enemy: Dictionary = game.enemies[prize_index]
	prize_enemy["hp"] = 40.0
	prize_enemy["crew"] = 1.0
	prize_enemy["weapons"] = 60.0
	game.enemies[prize_index] = prize_enemy
	game.selected_target = prize_index
	var boarder: Dictionary = game.fleet[0]
	boarder["order"] = "ABORDAR"
	game.fleet[0] = boarder
	var prize_node: Node3D = prize_enemy["node"]
	var boarder_node: Node3D = boarder["node"]
	boarder_node.position = prize_node.position + Vector3(0, 0, 8)
	_assert("aproximação", boarder_node.global_position.distance_to(prize_node.global_position) <= 18.0,
		"distância %.1f" % boarder_node.global_position.distance_to(prize_node.global_position))

	# 3 — salva 1: a tripulação inimiga cai a zero e o alvo é marcado CAPTURADO.
	game._resolve_volley()
	var marked: Dictionary = game.enemies[prize_index]
	_assert("abordagem conclui", marked["order"] == "CAPTURADO",
		"ordem=%s tripulação=%.1f" % [marked["order"], float(marked["crew"])])
	_assert("ainda na lista de hostis", game.enemies.size() == 6 and game.fleet.size() == 6,
		"a incorporação é uma salva depois, nunca no meio da varredura")

	# 4 — salva 2: a presa atravessa para o lado do jogador.
	game._resolve_volley()
	_assert("sai de enemies", game.enemies.size() == 5, "hostis agora %d" % game.enemies.size())
	_assert("entra em fleet", game.fleet.size() == 7, "aliadas agora %d" % game.fleet.size())
	var prize: Dictionary = game.fleet[6]
	_assert("é a mesma nave", prize["node"] == prize_node, "nó preservado, sem reconstruir a geometria")
	_assert("esquadrão PRESA", prize["squadron"] == "PRESA" and prize["team"] == "friendly",
		"%s / %s" % [prize["squadron"], prize["team"]])
	_assert("batismo da presa", String(prize["name"]).begins_with("PRESA "), String(prize["name"]))
	_assert("nó vivo e visível", is_instance_valid(prize_node) and prize_node.visible,
		"a captura não apaga o casco da cena")
	_assert("armamentos zerados ficam zerados", float(prize["weapons"]) == 0.0,
		"reparo devolve tique a tique, sem número inventado na incorporação")

	# 5 — a presa não atira mais em quem a capturou: nenhum hostil aponta para o seu nó.
	var still_hostile := false
	for foe in game.enemies:
		if foe["node"] == prize_node:
			still_hostile = true
	_assert("fora do fogo hostil", not still_hostile, "nenhum dos %d hostis restantes é a presa" % game.enemies.size())

	# 6 — obedece ordens: o escopo ESQUADRÃO PRESA existe e move só ela.
	var scope_names: Array[String] = []
	for i in range(game.scope_selector.item_count):
		scope_names.append(game.scope_selector.get_item_text(i))
	_assert("escopo PRESA na lista", scope_names.has("ESQUADRÃO PRESA"), ", ".join(scope_names))
	game.selection_scope = "ESQUADRÃO PRESA"
	game._give_order("RECUAR")
	_assert("recebe ordem", String(game.fleet[6]["order"]) == "RECUAR",
		"ordem=%s" % game.fleet[6]["order"])
	_assert("não contamina o ALFA", String(game.fleet[0]["order"]) == "ABORDAR",
		"abordador continua com a ordem anterior")

	# 7 — reparo automático devolve os armamentos da incorporada.
	var weapons_before := float(game.fleet[6]["weapons"])
	for i in range(20):
		game._update_fleet(1.0)
	_assert("reparo alcança a presa", float(game.fleet[6]["weapons"]) > weapons_before,
		"armamentos %.1f -> %.1f em 20 s de reparo" % [weapons_before, float(game.fleet[6]["weapons"])])

	# 8 — os três seletores contam a frota real.
	_assert("seletor de escopo", game.scope_selector.item_count == 4 + game.fleet.size(),
		"%d itens para %d naves (FROTA/ALFA/BETA/PRESA + NAVE n)" % [game.scope_selector.item_count, game.fleet.size()])
	_assert("seletor de alvo", game.target_selector.item_count == game.enemies.size(),
		"%d itens" % game.target_selector.item_count)
	_assert("seletor de escolta", game.protected_selector.item_count == game.fleet.size() + 1,
		"%d itens (CAPITÂNIA + cada unidade)" % game.protected_selector.item_count)

	# 9 — o HUD não assume mais seis cascos.
	game._update_hud()
	_assert("HUD conta a frota nova", String(game.command_label.text).contains("FROTA: 7/7 NAVES"),
	(game.command_label.text as String).split("\n")[0])

	# 10 — sem hostis sobrando, o seletor de alvo não aponta para o vazio.
	for foe in game.enemies:
		foe["order"] = "CAPTURADO"
	game._resolve_volley()
	game._resolve_volley()
	_assert("frota inteira por captura", game.enemies.is_empty() and game.fleet.size() == 12,
		"%d aliadas, %d hostis" % [game.fleet.size(), game.enemies.size()])
	_assert("alvo sem contato", game.target_selector.item_count == 1
		and game.target_selector.get_item_text(0) == "SEM CONTATO HOSTIL",
		"%d item(ns)" % game.target_selector.item_count)
	_assert("nave 12 selecionável", game.scope_selector.item_count == 4 + 12,
		"%d itens = 3 grupos + PRESA + NAVE 1..12" % game.scope_selector.item_count)

	for line in notes:
		print("SONDA-CAPTURA: %s" % line)
	print("SONDA-CAPTURA: veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	quit()

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame
