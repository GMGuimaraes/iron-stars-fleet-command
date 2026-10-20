extends SceneTree

## Fotogramas reais da ponte para ajuste de pintura. Headless usa o renderizador dummy e devolve
## tela preta: neblina, exposição, glow e recorte da janela só se medem com PNG de verdade, e
## estes quatro quadros são o material de leitura. Não move número nenhum do jogo — só olha.
##
## Uso (janela real, sem --headless):
##   godot --path . --quit-after 1200 -s res://tools/probes/fotograma.gd

const OUT := "D:/Downloads/tmp-userdata/frame/"

var breaks := 0
var notes: Array[String] = []

func _assert(label: String, condition: bool, detail: String) -> void:
	if condition:
		notes.append("OK   %s — %s" % [label, detail])
	else:
		breaks += 1
		notes.append("QUEBRA %s — %s" % [label, detail])

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var game := (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	await _frames(8)
	_tabular(game)
	await _fotograma(game, "01_abertura")

	# 02 — batalha pintada: cascos em estados diferentes, para brasa e pluma aparecerem juntas.
	for i in range(game.enemies.size()):
		game.enemies[i]["hp"] = [100.0, 72.0, 55.0, 40.0, 22.0, 8.0][i % 6]
		game.enemies[i]["engines"] = 40.0
		game.enemies[i]["weapons"] = 80.0
	for i in range(game.fleet.size()):
		game.fleet[i]["hp"] = [100.0, 88.0, 61.0, 100.0, 47.0, 93.0][i % 6]
		game.fleet[i]["engines"] = [100.0, 55.0, 12.0, 100.0, 70.0, 30.0][i % 6]
	for i in range(40):
		game._update_fleet(0.1)
		game._update_probes(0.1)
		game._update_bridge(0.1)
	var antes_da_salva := game.get_child_count()
	game._resolve_volley()
	var lances := game.get_child_count() - antes_da_salva
	_assert("a salva desenhou lances", lances > 0, "%d filhos novos no jogo" % lances)
	await _fotograma(game, "02_salva")

	# 03 — destroço e captura lado a lado: carvão com brasa baixa ao lado de quem pegou filete azul.
	var morto: Dictionary = game.enemies[4]
	(morto["node"] as Node3D).global_position = Vector3(-8.0, 0.0, -70.0)
	morto["hp"] = 0.0
	game._mark_wreck(morto["node"] as Node3D)
	var presa: Dictionary = game.enemies[5]
	(presa["node"] as Node3D).global_position = Vector3(9.0, 0.0, -66.0)
	presa["hp"] = 30.0
	game._mark_as_prize(presa["node"] as Node3D)
	for i in range(20):
		game._update_fleet(0.1)
		game._update_bridge(0.1)
	await _fotograma(game, "03_destroco_e_captura")

	# 04 — aproximação: o mesmo tabuleiro pelo visor, para julgar silhueta sem HUD na frente.
	# A camada de UI é local do `_build_ui`, então a sonda a procura pelos filhos em vez de
	# exigir um membro novo no jogo só para tirar foto.
	for filho in game.get_children():
		if filho is CanvasLayer:
			filho.visible = false
	await _fotograma(game, "04_sem_hud")

	# 05 — close-up de casco: a silhueta tem de ler de perto também, com o HUD fora do caminho.
	var perto: Node3D = game.fleet[1]["node"]
	perto.position = Vector3(0.0, -1.2, -26.0)
	var hostil_perto: Node3D = game.enemies[2]["node"]
	hostil_perto.position = Vector3(4.5, -0.6, -34.0)
	await _fotograma(game, "05_casco_perto")

	for note in notes:
		print("SONDA-FOTOGRAMA: " + note)
	print("SONDA-FOTOGRAMA: veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	quit()

## Luminância média da tela. Espera dois fotogramas de desenho antes de ler a textura: sem isso
## o quadro sai byte-idêntico ao anterior e a leitura de pintura é feita sobre estado velho.
func _fotograma(game, nome: String) -> void:
	await _frames(2)
	var img := get_root().get_texture().get_image()
	img.save_png(OUT + nome + ".png")
	var soma := 0.0
	var amostras := 0
	for u in range(0, img.get_width(), 37):
		for v in range(0, img.get_height(), 37):
			var c := img.get_pixel(u, v)
			soma += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			amostras += 1
	var media := soma / maxf(float(amostras), 1.0)
	_assert("%s tem imagem" % nome, media > 0.01,
		"luminância média %.4f em %dx%d, salvo em %s%s.png"
		% [media, img.get_width(), img.get_height(), OUT, nome])
	# A ponte é o `_build_bridge` do jogo; sem blips no ar o quadro não prova a mesa holográfica.
	_assert("%s tem mesa holográfica viva" % nome, is_instance_valid(game.holo_root)
		and game.holo_blips.size() > 0, "%d blips" % game.holo_blips.size())

func _tabular(game) -> void:
	for i in range(game.fleet.size()):
		(game.fleet[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 5.0, 0.0, -38.0)
	for i in range(game.enemies.size()):
		(game.enemies[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 6.0, 0.0, -82.0)

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame
