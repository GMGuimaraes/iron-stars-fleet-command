extends SceneTree

## Fotogramas reais da ponte para ajuste de pintura. Headless usa o renderizador dummy e devolve
## tela preta: neblina, exposição, glow e recorte da janela só se medem com PNG de verdade, e
## estes treze quadros são o material de leitura. Não mexe na economia nem no sorteio de combate —
## mas os três do meio montam cenário de verdade, e cenário engole e queima: por isso a sonda
## devolve os cascos a 100 antes de fotografar a estrela e diz isso na asserção.
##
## Uso (janela real, sem --headless):
##   godot --path . --quit-after 2000 -s res://tools/probes/fotograma.gd
## O orçamento é em quadros e a ruína espera segundos reais: 2000 cobre a sequência inteira mesmo
## numa máquina que desenha a 144 Hz, e `quit()` fecha a sonda antes disso quando ela termina.

const OUT := "D:/Downloads/tmp-userdata/frame/"
## Espelho de `main.gd` para o quadro da ruína: se a tabela de fases ou o teto de rolagem mudarem
## lá, o asserção aqui quebra — é de propósito, o mesmo motivo de `tools/probes/morte.gd`.
const FASES_DA_TABELA := 5
const TETO_ROLAGEM := 0.3

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

	# 06 — painel em acordeão: a dobra é pintura, e sonda de lógica não mede se o grupo fechado
	# ainda cabe na janela. A camada de UI volta a ficar visível de propósito: os quadros 04 e 05 a
	# esconderam.
	for filho in game.get_children():
		if filho is CanvasLayer:
			filho.visible = true
	game._toggle_grupo("MANOBRA")
	await _fotograma(game, "06_painel_grupo_aberto")
	game._toggle_grupo("MANOBRA")
	await _fotograma(game, "07_painel_recolhido")

	# 08, 09, 10 — os três cenários novos pintados em janela real. A sonda de lógica (`tools/
	# probes/cenarios.gd`) já conta as rochas e confere o raio; aqui a pergunta é outra: a geometria
	# aparece na tela? Foi exatamente assim que a mesa holográfica sumiu uma rodada inteira — um
	# nome de propriedade errado num `CylinderMesh` não falha no parse, aborta a função em runtime
	# e devolve `Nil`, e todas as sondas de lógica continuaram verdes.
	game._montar_cenario("CINTURAO")
	await _frames(3)
	_assert("o cinturão tem corpo na cena", game.cenario_root.get_child_count() == 14
		and game.holo_cenario.size() == 14,
		"%d nós e %d marcas na mesa" % [game.cenario_root.get_child_count(),
			game.holo_cenario.size()])
	await _fotograma(game, "08_cinturao")

	game._montar_cenario("POCO")
	await _frames(3)
	_assert("o poço tem corpo na cena (boca + 28 billets do aro)",
		game.cenario_root.get_child_count() == 29 and game.holo_cenario.size() == 1,
		"%d nós e %d marcas na mesa" % [game.cenario_root.get_child_count(),
			game.holo_cenario.size()])
	await _fotograma(game, "09_poco")

	game._montar_cenario("ESTRELA")
	await _frames(3)
	_assert("a estrela tem corpo na cena (disco + 20 billets da coroa + luz)",
		game.cenario_root.get_child_count() == 22 and game.holo_cenario.size() == 1,
		"%d nós e %d marcas na mesa" % [game.cenario_root.get_child_count(),
			game.holo_cenario.size()])
	# A linha hostil mora dentro da corona (a ~25 u do disco) e o poço acabou de engolir metade
	# dela: para o quadro julgar pintura, e não a fatura do perigo, os cascos voltam a 100.
	for lista in [game.fleet, game.enemies]:
		for corpo in lista:
			corpo["hp"] = 100.0
	game.capital_hp = 100.0
	game.batalha_encerrada = false
	await _fotograma(game, "10_estrela")

	# 11 — tripulação em alarme: com a capitânia ferida, as quatro telas de console viram vermelhas
	# e os operadores sentados se debruçam. É pintura, e pintura só se julga em PNG — mas a contagem
	# dos seis corpos e o flanco do alarme são conferidos aqui, para o quadro não ser tela de fundo.
	game.capital_hp = 40.0
	await _frames(4)
	_assert("a ponte fotografada tem seis tripulantes e o alarme aceso",
		int(game.tripulacao.size()) == 6 and bool(game.ponte_em_alarme),
		"%d corpos, alarme=%s" % [game.tripulacao.size(), game.ponte_em_alarme])
	await _fotograma(game, "11_tripulacao_alarme")

	# 12 e 13 — a ruína da capitânia fotografada em dois momentos do próprio relógio da morte: a
	# meia-sequência, com clarão aberto dentro do casco e estrobo na luz fria, e o fim dela, com os
	# três adernamentos nos tetos, o deck escurecido e a holografia apagada. `tools/probes/morte.gd`
	# conta fases, tetos e clarões com o relógio passo a passo; se a morte é legível na tela, só o PNG
	# diz — e é ela quem pega geometria ausente, que em GDScript não falha no parse e devolve `Nil`
	# em silêncio.
	# A espera é por condição e limitada por relógio de parede, não por contagem de quadros: em janela
	# o `delta` é o tempo real, e a taxa de quadros da máquina (60 ou 144 Hz) não pode decidir se o
	# quadro sai fotografado. Se o laço morto não andar, a asserção quebra com o número na mão.
	game.capital_hp = 0.0
	var inicio_do_clarao := Time.get_ticks_msec()
	var quadros_do_clarao := 0
	while float(game.morte_t) < 0.90 and Time.get_ticks_msec() - inicio_do_clarao < 6000:
		await process_frame
		quadros_do_clarao += 1
	_assert("a ponte morta roteia o laço real: a sequência anda em janela",
		bool(game.ponte_condenada) and float(game.morte_t) >= 0.90,
		"condenada=%s morte em %0.2f s depois de %d quadros reais" % [game.ponte_condenada,
			game.morte_t, quadros_do_clarao])
	_assert("no meio da ruína ainda há clarão no ar e a luz fria estroba",
		(game.morte_claroes as Array).size() > 0
			and float(game.ponte_luz_fria.light_energy) > 0.0,
		"%d clarões, fria %0.2f, trabalho %0.2f" % [(game.morte_claroes as Array).size(),
			game.ponte_luz_fria.light_energy, game.ponte_luz_trabalho.light_energy])
	await _fotograma(game, "12_ruina_claroes", false)
	var inicio_do_fim := Time.get_ticks_msec()
	var quadros_do_fim := 0
	while float(game.morte_t) < 2.75 and Time.get_ticks_msec() - inicio_do_fim < 6000:
		await process_frame
		quadros_do_fim += 1
	_assert("a ruína fecha os tetos e apaga tudo no quadro final",
		int(game.morte_fase) == FASES_DA_TABELA and (game.morte_claroes as Array).is_empty()
			and absf(float((game.bridge_rig as Node3D).rotation.z)) >= TETO_ROLAGEM - 0.01
			and float(game.ponte_luz_fria.light_energy) == 0.0,
		"fase=%d contra %d na tabela, %d clarões vivos, rolagem %0.3f contra o teto %0.2f, fria %0.2f, %d quadros" % [
			game.morte_fase, FASES_DA_TABELA, (game.morte_claroes as Array).size(),
			(game.bridge_rig as Node3D).rotation.z, TETO_ROLAGEM,
			game.ponte_luz_fria.light_energy, quadros_do_fim])
	await _fotograma(game, "13_ruina_extinta", false)

	for note in notes:
		print("SONDA-FOTOGRAMA: " + note)
	print("SONDA-FOTOGRAMA: veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	quit()

## Luminância média da tela. Espera dois fotogramas de desenho antes de ler a textura: sem isso
## o quadro sai byte-idêntico ao anterior e a leitura de pintura é feita sobre estado velho.
func _fotograma(game, nome: String, mesa_viva := true) -> void:
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
	# A ponte é o `_build_bridge` do jogo; sem blips no ar o quadro não prova a mesa holográfica. Na
	# ruína a mesa some da vista de propósito — a asserção então cobra o oposto, senão o quadro novo
	# seria reprovado por um contrato que a própria morte assinou.
	_assert("%s tem mesa holográfica %s" % [nome, "viva" if mesa_viva else "apagada de propósito"],
		game.holo_blips.size() > 0 and (game.holo_root as Node3D).visible == mesa_viva,
		"%d blips, visível=%s" % [game.holo_blips.size(), (game.holo_root as Node3D).visible])

func _tabular(game) -> void:
	for i in range(game.fleet.size()):
		(game.fleet[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 5.0, 0.0, -38.0)
	for i in range(game.enemies.size()):
		(game.enemies[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 6.0, 0.0, -82.0)

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame
