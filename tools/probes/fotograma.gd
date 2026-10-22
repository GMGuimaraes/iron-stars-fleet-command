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
## Espelho do poço em `main.gd`: é aqui, e só aqui, que a pintura das 252 amostras pode ser conferida
## instância a instância. Sob `--headless` o `MultiMesh.set_instance_transform` é descartado sem erro
## e a leitura volta identidade; em janela os dois lados batem. Um `ang` trocado num laço de desenho
## não dá exceção — dá um céu torto, e é de desenho que esta sonda trata.
const POCO_POS := Vector3(0.0, 0.0, -78.0)
const POCO_HORIZONTE := 9.0
const POCO_ANEL_FOTON := 1.08
const POCO_DISCO_INTERNO := 1.55
const POCO_DISCO_EXTERNO := 3.80
const POCO_DISCO_FAIXAS := 3
const POCO_DISCO_AMOSTRAS := 44
const POCO_DISCO_INCLINACAO := 0.17
const POCO_ARCO_ALTO := 1.24
const POCO_ARCO_BAIXO := 1.06
const POCO_ARCO_AMOSTRAS := 40
const POCO_ARCO_LARGO := 3.10
const POCO_DOPPLER := 0.45

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
	_assert("o poço pinta três nós: sombra, disco e arco",
		game.cenario_root.get_child_count() == 3 and game.holo_cenario.size() == 1,
		"%d nós e %d marcas na mesa" % [game.cenario_root.get_child_count(),
			game.holo_cenario.size()])
	# Em janela a escrita por instância pega, então a régua volta a ser o MultiMesh — e a comparação
	# com o espelho em RAM é o que prova que os dois lados são o mesmo céu, não dois céus.
	var disco_mm: MultiMesh = game.poco_disco.multimesh
	var arco_mm: MultiMesh = game.poco_lente.multimesh
	_assert("disco e arco têm a conta de amostras da tabela",
		int(disco_mm.instance_count) == POCO_DISCO_FAIXAS * POCO_DISCO_AMOSTRAS
			and int(arco_mm.instance_count) == POCO_ARCO_AMOSTRAS * 3,
		"%d de disco e %d de arco" % [disco_mm.instance_count, arco_mm.instance_count])
	var fora_disco := 0
	for faixa in range(POCO_DISCO_FAIXAS):
		for i in range(POCO_DISCO_AMOSTRAS):
			var n := faixa * POCO_DISCO_AMOSTRAS + i
			var esperado := _ponto_disco(faixa, i)
			if _tr_errado(disco_mm.get_instance_transform(n), esperado["tr"]) \
					or _cor_errada(disco_mm.get_instance_color(n), esperado["cor"]):
				fora_disco += 1
	_assert("cada amostra do disco está no lugar, no tamanho e no tom da fórmula",
		fora_disco == 0, "%d de %d amostras fora do esperado" % [fora_disco,
			disco_mm.instance_count])
	var fora_arco := 0
	for i in range(POCO_ARCO_AMOSTRAS * 3):
		var quer := _ponto_arco(i)
		if _tr_errado(arco_mm.get_instance_transform(i), quer["tr"]) \
				or _cor_errada(arco_mm.get_instance_color(i), quer["cor"]):
			fora_arco += 1
	_assert("aro de fótons e os dois arcos dobrados batem com a tabela",
		fora_arco == 0, "%d de %d amostras fora do esperado" % [fora_arco,
			arco_mm.instance_count])
	var aro_ok := 0
	for i in range(POCO_ARCO_AMOSTRAS):
		if absf((arco_mm.get_instance_transform(i) as Transform3D).origin.length()
				- POCO_HORIZONTE * POCO_ANEL_FOTON) < 0.002:
			aro_ok += 1
	_assert("o aro de fótons está colado na sombra: os %d a %0.2f u do centro" % [
			POCO_ARCO_AMOSTRAS, POCO_HORIZONTE * POCO_ANEL_FOTON],
		aro_ok == POCO_ARCO_AMOSTRAS, "%d de %d no raio cravado" % [aro_ok, POCO_ARCO_AMOSTRAS])
	var pintadas: Array = game.estrelas_pintadas
	var fora_ceu := 0
	for i in range(pintadas.size()):
		if _tr_errado((game.campo_estelar as MultiMeshInstance3D).multimesh
				.get_instance_transform(i), pintadas[i]):
			fora_ceu += 1
	_assert("o céu pintado no MultiMesh é o mesmo céu do espelho em RAM",
		int(pintadas.size()) == 900 and fora_ceu == 0 and int(game.estrelas_dobradas) > 0,
		"%d de %d estrelas fora do espelho, %d dobradas pela lente" % [fora_ceu,
			pintadas.size(), game.estrelas_dobradas])
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

## Espelho literal de `_montar_disco_de_acrescao`: um `ang` trocado no laço mudaria o disco inteiro
## sem dar erro de parse, e em pintura não há exceção que avise.
func _ponto_disco(faixa: int, i: int) -> Dictionary:
	var t := 0.0
	if POCO_DISCO_FAIXAS > 1:
		t = float(faixa) / float(POCO_DISCO_FAIXAS - 1)
	var raio := POCO_HORIZONTE * lerpf(POCO_DISCO_INTERNO, POCO_DISCO_EXTERNO, t)
	var ang := float(i) * TAU / float(POCO_DISCO_AMOSTRAS) + float(faixa) * 0.11
	var incl := Basis(Vector3.RIGHT, POCO_DISCO_INCLINACAO)
	var feixe := 1.0 + POCO_DOPPLER * cos(ang)
	var cor := Color(1.0, lerpf(0.42, 0.86, 1.0 - t), lerpf(0.16, 0.62, 1.0 - t))
	var tam := 1.5 + 1.9 * t
	return {"tr": Transform3D(incl.scaled(Vector3(tam, tam, tam)),
			POCO_POS + incl * (Vector3(cos(ang), 0.0, sin(ang)) * raio)),
		"cor": Color(cor.r * feixe, cor.g * feixe, cor.b * feixe, 0.72 - 0.16 * t)}

## Espelho de `_montar_arco_de_lente`: aro de fótons primeiro, depois o arco de cima e o de baixo,
## na mesma ordem em que as instâncias foram escritas.
func _ponto_arco(i: int) -> Dictionary:
	var deitado := Basis(Vector3.RIGHT, PI / 2.0)
	if i < POCO_ARCO_AMOSTRAS:
		var ang := float(i) * TAU / float(POCO_ARCO_AMOSTRAS)
		var feixe := 1.0 + POCO_DOPPLER * 0.5 * cos(ang)
		return {"tr": Transform3D(deitado.scaled(Vector3(0.62, 0.62, 0.62)),
				Vector3(cos(ang), sin(ang), 0.0) * POCO_HORIZONTE * POCO_ANEL_FOTON),
			"cor": Color(1.0 * feixe, 0.82 * feixe, 0.55 * feixe, 0.9)}
	var k := (i - POCO_ARCO_AMOSTRAS) % POCO_ARCO_AMOSTRAS
	var lado: int = int(float(i - POCO_ARCO_AMOSTRAS) / float(POCO_ARCO_AMOSTRAS))
	var amplitude := POCO_HORIZONTE * (POCO_ARCO_ALTO if lado == 0 else POCO_ARCO_BAIXO)
	var sinal := 1.0 if lado == 0 else -1.0
	var base := 1.0 if lado == 0 else 0.55
	var u := float(k) * PI / float(POCO_ARCO_AMOSTRAS - 1)
	var altura := sin(u)
	var feixe := 1.0 + POCO_DOPPLER * cos(u - PI / 2.0)
	var tam := 0.7 + 2.2 * altura
	return {"tr": Transform3D(deitado.scaled(Vector3(tam, tam, tam)),
			Vector3(-POCO_ARCO_LARGO * POCO_HORIZONTE * cos(u), sinal * amplitude * altura, 0.0)),
		"cor": Color(base * feixe, base * 0.78 * feixe, base * 0.5 * feixe, 0.2 + 0.6 * altura)}

## Transformada conferida inteira (origem e as três colunas da base), nunca um componente avulso
## contra uma constante: o MultiMesh devolve precisão simples e o espelho é dupla — conferir eixo a
## eixo contra o valor cru é a armadilha do arredondamento. Os nove números juntos, com tolerância.
func _tr_errado(escrito: Transform3D, esperado: Transform3D) -> bool:
	if escrito.origin.distance_to(esperado.origin) > 0.001:
		return true
	return escrito.basis.x.distance_to(esperado.basis.x) > 0.0005 \
		or escrito.basis.y.distance_to(esperado.basis.y) > 0.0005 \
		or escrito.basis.z.distance_to(esperado.basis.z) > 0.0005

func _cor_errada(escrita: Color, esperada: Color) -> bool:
	return absf(escrita.r - esperada.r) > 0.002 or absf(escrita.g - esperada.g) > 0.002 \
		or absf(escrita.b - esperada.b) > 0.002 or absf(escrita.a - esperada.a) > 0.002
