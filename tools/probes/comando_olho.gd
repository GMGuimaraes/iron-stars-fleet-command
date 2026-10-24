extends SceneTree

## Sonda de OLHO do comando por clique (fatia 1): o que só existe com matriz de câmera viva.
##
## As leis de dado — escala, seleção, translação, anel, despacho, inércia, modo, painel, RECOMEÇAR —
## moram em `tools/probes/comando.gd` e rodam de cabeça fria. Esta aqui não pode: escolha é
## `unproject_position` e ponto de ordem é `Plane.intersects_ray`, e sob `--headless` o renderizador
## é dummy — a projeção devolve lixo honesto e a asserção aprovaria um olho que não enquadra nada.
## O que ela cobra é quadro, e quadro só existe em janela real.
##
## 1) A PONTE É O OLHO DA ABERTURA, MEDIDO NO QUADRO. Em janela, o viewport escolhe por prioridade e
##    o EMPATE de prioridade é resolvido pela ordem de entrada: com o `Camera3D` tático montado depois
##    da ponte, sem a declaração explícita de `make_current()` a partida abriria em vista de topo. De
##    cabeça fria isso não é visível (o `is_current()` só acorda com chamada explícita e o quadro não
##    existe), então a lei é conferida aqui, lendo `get_viewport().get_camera_3d()` pelos dois lados do
##    TAB, com o TAB entregue na `_input` do jogo como o teclado o entrega: `pressed` e não `echo`.
## 2) ESCOLHA É AQUELE BLOCO, NÃO O VIZINHO. A régua de cabeça fria não sabe quantos pixels separam
##    dois blocos; aqui ela sabe, e é o número que a asserção imprime. Vizinho de boreste (treze
##    unidades) e vizinho de vante (sete), cada um tocado no próprio pixel projetado, devolvem o próprio
##    id. E água se mede pelo maior despejo livre do quadro, não pelo meio de dois vizinhos: a grade é
##    escalonada, e uma terceira candidata mora em cima desse meio (medido: 21 px) — testar ali acusaria
##    o desenho do tabuleiro em vez do olho.
## 3) SOBRE O EIXO, O ANDAR DE CIMA TAPA O DE BAIXO, E QUEM DECIDE É A DISTÂNCIA DO OLHO. Dois blocos na
##    mesma coluna projetam-se no MESMO pixel enquanto a coluna estiver no eixo óptico; fora dele a
##    parallaxia separa os andares, e a asserção mede os dois lados para a lei não virar conto. A prova
##    do desempate é dupla: com uma cota marcada, vence o de cima; trocadas as cotas, vence o outro. Sem
##    o desempate a asserção inverteria junto com a ordem da lista e não com o gesto.
## 4) O CLIQUE E A AGULHA: o ponto pedido volta no ponto pedido. Um pixel do quadro atravessa
##    `_ponto_sob_o_pixel` e o resultado, reprojetado, tem de voltar ao MESMO pixel — e o ponto tem de
##    estar no plano da ordem (`y` do foco), não no `y` zero do tabuleiro, porque a cota da esquadra é
##    da formação e um clique nunca decide andar de cima contra andar de baixo.
## 5) A RÉGUA DE PIXEL É CONTAs DE VERDADE. `_unidades_por_pixel_tatico()` é derivada de FOV, altura e
##    altura do quadro; aqui ela é conferida contra a distância em pixels de dois pontos do plano a
##    vinte unidades um do outro, e contra o enquadramento: no teto da roda os cento e vinte blocos
##    cabem no quadro, no piso dele cabe um punhado. Zoom que não muda a conta de blocos visíveis é
##    zoom que só cortou a moldura.
## 6) O ARRASTO NÃO É ORDEM, MEDIDO PELO CAMINHO DE INPUT. Prensa, varredura de quarenta pixels,
##    soltura sobre o pixel de um bloco: a seleção não se mexe e o foco andou contra o cursor. Uma
##    soltura sem varredura sobre o mesmo pixel seleciona aquele bloco. É a dobradiça de seis pixels
##    funcionando dentro de `_unhandled_input` real, com a projeção real.
##
## Uso (janela real, sem --headless):
##   godot --path . --quit-after 6000 -s res://tools/probes/comando_olho.gd

const Esquadra := preload("res://esquadra.gd")

const OUT := "D:/Downloads/tmp-userdata/frame/"
const BLOCOS_POR_LADO := 120
const TATICO_ALTURA_MIN := 24.0
const TATICO_ALTURA_MAX := 320.0
## O passo declarado da grade de blocos: boreste 13 u, vante 7 u. É a régua do vizinho.
const PASSO_BORESTE := 13.0
const PASSO_VANTE := 7.0
## Fração tolerada entre a régua derivada e a régua medida no quadro. Perspectiva: vinte unidades a
## partir do centro do quadro já não estão na coluna óptica, e a conta fechada é a do centro.
const FOLGA_REGUA := 0.05
## Erro de ida-e-volta aceito na agulha, em pixels de 1440x900. Sub-pixel é o que a projeção deve.
const FOLGA_AGULHA_PX := 0.75
## Erro de ida-e-volta aceito no plano de ordem, em unidades (= quilômetros pela cláusula).
const FOLGA_AGULHA_U := 0.05

var breaks := 0
var notes: Array[String] = []

func _assert(label: String, condition: bool, detail: String) -> void:
	if condition:
		notes.append("OK   %s — %s" % [label, detail])
	else:
		breaks += 1
		notes.append("QUEBRA %s — %s" % [label, detail])

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

## O TAB pelo caminho de verdade: `_input` é quem decide, e um TAB chamado direto em
## `_trocar_modo_camera()` deixaria de fora o `pressed and not echo` que o teclado real manda.
func _tab(jogo: Node3D) -> void:
	var tecla := InputEventKey.new()
	tecla.keycode = KEY_TAB
	tecla.pressed = true
	tecla.echo = false
	jogo._input(tecla)

func _nome_do_quadro(jogo: Node3D) -> String:
	var camera: Node = jogo.get_viewport().get_camera_3d()
	return String(camera.name) if is_instance_valid(camera) else "NENHUMA"

## Par de blocos vizinhos na grade, separado exatamente pelo passo declarado. Devolve [bloco_a,
## bloco_b] ou vazio se a grade não tiver o par — e a asserção que chama isso é a prova de que tem.
## O índice é pela chave do posto arredondada ao centésimo: a grade escreve posições exatas, e um
## laço duplo sobre cento e vinte blocos mediria a sonda, não o tabuleiro.
func _vizinho(jogo: Node3D, eixo: String) -> Array:
	var lista: Array = jogo.esquadra.lista_de("aliado")
	var postos := {}
	for b in lista:
		var p: Vector3 = b["pos"]
		postos["%.2f|%.2f|%.2f" % [p.x, p.y, p.z]] = b
	var passo := PASSO_BORESTE if eixo == "x" else PASSO_VANTE
	for b in lista:
		var p: Vector3 = b["pos"]
		var vizinho_posto := (p + Vector3(passo, 0.0, 0.0)) if eixo == "x" \
			else (p + Vector3(0.0, 0.0, passo))
		var chave := "%.2f|%.2f|%.2f" % [vizinho_posto.x, vizinho_posto.y, vizinho_posto.z]
		if postos.has(chave):
			return [b, postos[chave]]
	return []

## Quantos blocos de um lado caem dentro do quadro com o olho na altura pedida. Mexe na altura e na
## pose do olho; quem chama devolve a altura de antes, como a lei 5 faz logo abaixo.
func _dentro_do_quadro(jogo: Node3D, altura: float) -> int:
	jogo.tatico_altura = altura
	jogo._pintar_camera_tatica()
	var tamanho := Vector2(jogo.get_viewport().size)
	var conta := 0
	for b in jogo.esquadra.lista_de("aliado"):
		var onde: Vector2 = jogo.tatico_camera.unproject_position(b["pos"] as Vector3)
		if onde.x >= 0.0 and onde.y >= 0.0 and onde.x < tamanho.x and onde.y < tamanho.y:
			conta += 1
	return conta


## Põe o olho na altura pedida, deixa o quadro desenhar, fotografa e devolve quantos blocos aliados
## cabem no quadro nessa pose. A foto é o olho da lei: sem ela o número diria só o que a conta dele
## diz, e zoom que só corta moldura continua passando na conta.
func _olhar(jogo: Node3D, altura: float, foto: String) -> int:
	jogo.tatico_altura = altura
	jogo._pintar_camera_tatica()
	jogo._update_hud()
	await _frames(4)
	var conta := _dentro_do_quadro(jogo, altura)
	get_root().get_texture().get_image().save_png(OUT + foto)
	return conta


## Primeiro bloco aliado cujo pixel projetado cai no quadro com a margem pedida. A varredura de
## quarenta pixels tem de caber na tela, e um bloco fora do quadro deixaria a asserção provar a
## sonda em vez do gesto: `unproject_position` de um ponto fora do retângulo continua sendo conta.
func _bloco_no_quadro(jogo: Node3D, margem: float) -> Dictionary:
	var tamanho := Vector2(jogo.get_viewport().size)
	for b in jogo.esquadra.lista_de("aliado"):
		var onde: Vector2 = jogo.tatico_camera.unproject_position(b["pos"] as Vector3)
		if onde.x >= margem and onde.y >= margem and onde.x < tamanho.x - margem \
				and onde.y < tamanho.y - margem:
			return b
	return {}


func _initialize() -> void:
	print("SONDA-OLHO: comecando")
	var jogo: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(jogo)
	await _frames(3)
	# Congelado pelo instrumento da casa: a travessia entre o pixel lido e a ordem escrita tem de ser
	# a travessia de um campo parado, senão o bloco anda para baixo do cursor entre as duas linhas.
	jogo.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(2)
	jogo._pintar_massa(true)
	var tamanho := Vector2(jogo.get_viewport().size)
	var centro := tamanho * 0.5

	# ── 1. o dono do quadro, medido no quadro ────────────────────────────────────────────────
	_assert("a abertura é da ponte, e o TAB pelo teclado real passa o quadro ao mapa",
		_nome_do_quadro(jogo) == "BridgeCamera" and bool(jogo.ponte_camera.is_current()) \
			and not bool(jogo.tatico_camera.is_current()),
		"quadro de %s, viewport %s, modo %s" % [_nome_do_quadro(jogo), str(tamanho),
			jogo.campo_modo])
	get_root().get_texture().get_image().save_png(OUT + "olho_01_ponte.png")
	_tab(jogo)
	await _frames(3)
	_assert("em TATICO o dono do quadro é o mapa e a ponte perde o estado sozinha",
		_nome_do_quadro(jogo) == "TacticalCamera" and bool(jogo.tatico_camera.is_current()) \
			and not bool(jogo.ponte_camera.is_current()),
		"quadro de %s, modo %s" % [_nome_do_quadro(jogo), jogo.campo_modo])
	# O letreiro só é escrito em `_process`, e o campo está congelado: sem esta chamada o fotograma
	# diria "olho PONTE" sobre o mapa de topo e o olho conferiria a sonda, não o jogo.
	jogo._update_hud()
	get_root().get_texture().get_image().save_png(OUT + "olho_02_tatico.png")

	# ── 2. escolha é aquele bloco, não o vizinho ─────────────────────────────────────────────
	var par_x := _vizinho(jogo, "x")
	var par_z := _vizinho(jogo, "z")
	_assert("a grade tem vizinho de boreste a treze unidades e de vante a sete",
		par_x.size() == 2 and par_z.size() == 2,
		"par x %s, par z %s" % [str(not par_x.is_empty()), str(not par_z.is_empty())])
	var raio: float = jogo.RAIO_ESCOLHA_PX
	var separo_x := 0.0
	var acerto_x: Dictionary = {}
	if par_x.size() == 2:
		var a: Dictionary = par_x[0]
		var b: Dictionary = par_x[1]
		var px_a: Vector2 = jogo.tatico_camera.unproject_position(a["pos"] as Vector3)
		var px_b: Vector2 = jogo.tatico_camera.unproject_position(b["pos"] as Vector3)
		separo_x = px_a.distance_to(px_b)
		acerto_x = jogo._unidade_sob_o_pixel(px_a)
	_assert("treze unidades de boreste viram pixels demais para um toque confuso",
		separo_x > raio * 2.0 and int(acerto_x.get("id", -1)) == int(par_x[0]["id"]),
		"vizinhos a %.1f px (dois raios = %.1f px), toque no pixel de um devolve %s" % [
			separo_x, raio * 2.0, str(acerto_x.get("id", -1))])
	# Água não se escolhe no meio de dois vizinhos: a grade de treze por sete é escalonada, e uma
	# terceira candidata mora em cima do ponto médio — medir ali acusaria o desenho do tabuleiro, não
	# o olho. O que se mede é o MAIOR despejo livre do quadro: o pixel mais longe de toda candidata, e
	# é nele que se exige vazio. A folga medida entra na asserção, para o gate não passar por vazio.
	var projetadas: Array = []
	for c in jogo._candidatas_do_clique():
		projetadas.append(jogo.tatico_camera.unproject_position((c as Dictionary)["pos"] as Vector3))
	var px_agua := Vector2.ZERO
	var folga_agua := -1.0
	for fx in range(2, 11):
		for fy in range(2, 7):
			var candidato_px := Vector2(tamanho.x * fx / 10.0, tamanho.y * fy / 6.0)
			var folga := 1e9
			for q in projetadas:
				folga = minf(folga, candidato_px.distance_to(q as Vector2))
			if folga > folga_agua:
				folga_agua = folga
				px_agua = candidato_px
	var agua: Dictionary = jogo._unidade_sob_o_pixel(px_agua)
	_assert("o pixel de maior despejo livre é água, e água devolve vazio",
		folga_agua > raio and agua.is_empty(),
		"%d candidatas no quadro, maior folga %.1f px no pixel %s devolve %s" % [
			projetadas.size(), folga_agua, str(px_agua), str(agua)])
	var separo_z := 0.0
	if par_z.size() == 2:
		var c: Dictionary = par_z[0]
		var d: Dictionary = par_z[1]
		var px_c: Vector2 = jogo.tatico_camera.unproject_position(c["pos"] as Vector3)
		var px_d: Vector2 = jogo.tatico_camera.unproject_position(d["pos"] as Vector3)
		separo_z = px_c.distance_to(px_d)
		var marca_c: Dictionary = jogo._unidade_sob_o_pixel(px_c)
		_assert("sete unidades de vante viram pixels suficientes e o toque devolve o outro id",
			separo_z > raio and int(marca_c.get("id", -1)) == int(c["id"]),
			"vizinhos de vante a %.1f px (raio de escolha %.0f px), toque no pixel %s devolve %s" % [
				separo_z, raio, str(px_c), str(marca_c.get("id", -1))])

	# ── 3. o andar de cima tapa o de baixo, e o desempate é do olho ──────────────────────────
	# Sobre o eixo óptico a parallaxia é nula e dois andares da mesma coluna caem no MESMO pixel; fora
	# dele a perspectiva os separa (a asserção mede os dois lados, porque é a medida que diz onde a lei
	# vale). Sem o desempate por distância do olho, quem vence é a ordem da lista — e a lista não muda
	# quando o comandante troca os andares de lugar, então a prova é dupla: marcada uma cota, vence a
	# mais alta; trocadas as cotas, vence o outro bloco. As posições são postas à mão e devolvidas.
	if par_x.size() == 2:
		var em_cima: Dictionary = par_x[0]
		var em_baixo: Dictionary = par_x[1]
		var pos_cima_antes: Vector3 = em_cima["pos"]
		var pos_baixo_antes: Vector3 = em_baixo["pos"]
		var olho: Vector3 = jogo.tatico_camera.global_position
		var eixo := Vector3(olho.x, 0.0, olho.z)
		em_cima["pos"] = eixo + Vector3(0.0, 30.0, 0.0)
		em_baixo["pos"] = eixo + Vector3(0.0, 6.0, 0.0)
		var no_eixo: Vector2 = jogo.tatico_camera.unproject_position(eixo + Vector3(0.0, 18.0, 0.0))
		var cima_px: Vector2 = jogo.tatico_camera.unproject_position(em_cima["pos"] as Vector3)
		var baixo_px: Vector2 = jogo.tatico_camera.unproject_position(em_baixo["pos"] as Vector3)
		var separo_no_eixo := cima_px.distance_to(baixo_px)
		var coluna := Vector3(pos_cima_antes.x, 0.0, pos_cima_antes.z)
		var fora_cima: Vector2 = jogo.tatico_camera.unproject_position(coluna + Vector3(0.0, 30.0, 0.0))
		var fora_baixo: Vector2 = jogo.tatico_camera.unproject_position(coluna + Vector3(0.0, 6.0, 0.0))
		var separo_fora := fora_cima.distance_to(fora_baixo)
		var primeiro: Dictionary = jogo._unidade_sob_o_pixel(no_eixo)
		em_cima["pos"] = eixo + Vector3(0.0, 6.0, 0.0)
		em_baixo["pos"] = eixo + Vector3(0.0, 30.0, 0.0)
		var segundo: Dictionary = jogo._unidade_sob_o_pixel(no_eixo)
		em_cima["pos"] = pos_cima_antes
		em_baixo["pos"] = pos_baixo_antes
		_assert("na linha do eixo os dois andares somem no mesmo pixel e o desempate segue o olho",
			separo_no_eixo < float(jogo.ESCOLHA_DESEMPATE_PX) \
				and int(primeiro.get("id", -1)) == int(em_cima["id"]) \
				and int(segundo.get("id", -1)) == int(em_baixo["id"]),
			"pilha no eixo a %.2f px, pilha a %.1f u do eixo a %.1f px; com o andar de cima em %s e com as cotas trocadas em %s" % [
				separo_no_eixo, absf(coluna.x - olho.x), separo_fora,
				str(primeiro.get("id", -1)), str(segundo.get("id", -1))])

	# ── 4. a agulha: o ponto pedido volta no ponto pedido ────────────────────────────────────
	var plano := float(jogo.tatico_foco.y)
	var pior_px := 0.0
	var pior_y := 0.0
	for frac in [Vector2(0.5, 0.5), Vector2(0.28, 0.34), Vector2(0.72, 0.66)]:
		var pixel := Vector2(tamanho.x * frac.x, tamanho.y * frac.y)
		var tocado: Vector3 = jogo._ponto_sob_o_pixel(pixel)
		var devolta: Vector2 = jogo.tatico_camera.unproject_position(tocado)
		pior_px = maxf(pior_px, devolta.distance_to(pixel))
		pior_y = maxf(pior_y, absf(tocado.y - plano))
	_assert("clique e agulha: o pixel atravessa o plano de ordem e volta a ele",
		pior_px < FOLGA_AGULHA_PX and pior_y < 1e-3,
		"maior erro de ida e volta %.3f px, cota lida a %.4f u do plano do foco (quadro %s)" % [
			pior_px, pior_y, str(tamanho)])

	# ── 5. a régua de pixel e o enquadramento dos dois limites da roda ───────────────────────
	var regua := float(jogo._unidades_por_pixel_tatico())
	# Dez unidades para cada lado, CONVERTIDAS EM PIXELS pela régua (`10 / regua`), não multiplicadas:
	# regua é u/px, e multiplicar daria um par de pontos a 1,3 px um do outro — a medida leria a sonda.
	var meio_quadro := Vector2(10.0 / regua, 0.0)
	var a_meia: Vector3 = jogo._ponto_sob_o_pixel(centro + meio_quadro)
	var b_meia: Vector3 = jogo._ponto_sob_o_pixel(centro - meio_quadro)
	var px_a_meia: Vector2 = jogo.tatico_camera.unproject_position(a_meia)
	var px_b_meia: Vector2 = jogo.tatico_camera.unproject_position(b_meia)
	var separo_medido := px_a_meia.distance_to(px_b_meia)
	var regua_medida := 20.0 / maxf(separo_medido, 1e-6)
	_assert("vinte unidades de mundo medem os pixels que a régua promete",
		absf(regua_medida - regua) / regua < FOLGA_REGUA,
		"régua derivada %.5f u/px, régua medida no quadro %.5f u/px (20 u = %.1f px)" % [
			regua, regua_medida, separo_medido])
	var cheios := await _olhar(jogo, TATICO_ALTURA_MAX, "olho_03_teto.png")
	var apertados := await _olhar(jogo, TATICO_ALTURA_MIN, "olho_03_piso.png")
	jogo.tatico_altura = 110.0
	jogo._pintar_camera_tatica()
	await _frames(2)
	_assert("no teto da roda o mapa inteiro cabe no quadro e no piso só um punhado, mas um punhado existe",
		cheios == BLOCOS_POR_LADO and apertados > 0 and apertados < cheios,
		"%d dos %d blocos visíveis a %.0f u de altura, %d a %.0f u" % [cheios, BLOCOS_POR_LADO,
			TATICO_ALTURA_MAX, apertados, TATICO_ALTURA_MIN])

	# ── 6. o arrasto pelo caminho de input, sobre um bloco de verdade ────────────────────────
	var bloco: Dictionary = _bloco_no_quadro(jogo, raio + 60.0)
	_assert("o quadro tem um bloco com folga para a varredura de quarenta pixels",
		not bloco.is_empty(), "bloco escolhido: %s" % str(bloco.get("id", -1)))
	var foco_antes: Vector3 = jogo.tatico_foco
	jogo.esquadra.limpar_selecao()
	if not bloco.is_empty():
		var prensa := InputEventMouseButton.new()
		prensa.button_index = MOUSE_BUTTON_LEFT
		prensa.pressed = true
		prensa.global_position = jogo.tatico_camera.unproject_position(bloco["pos"] as Vector3)
		var varredura := InputEventMouseMotion.new()
		varredura.global_position = prensa.global_position + Vector2(40.0, 0.0)
		var soltura := InputEventMouseButton.new()
		soltura.button_index = MOUSE_BUTTON_LEFT
		soltura.pressed = false
		soltura.global_position = varredura.global_position
		jogo._unhandled_input(prensa)
		jogo._unhandled_input(varredura)
		jogo._unhandled_input(soltura)
		_assert("quarenta pixels de varredura sobre um bloco são olhar, não escolher",
			jogo.esquadra.contar_selecionados() == 0 and bool(jogo._arrasto_moveu) \
				and absf(float(jogo.tatico_foco.x) - (float(foco_antes.x) - 40.0 * regua)) < 1e-3,
			"%d selecionados, foco %s -> %s (régua %.5f u/px, esperado %.3f em x)" % [
				jogo.esquadra.contar_selecionados(), str(foco_antes), str(jogo.tatico_foco),
				regua, float(foco_antes.x) - 40.0 * regua])
		# O pixel é relido DEPOIS do arrasto: os quarenta pixels moveram o mapa sob o cursor, e tocar o
		# pixel velho cairia em água a quarenta pixels do bloco — a sonda acusaria o clique de surdo
		# quando quem andou foi o mapa.
		var pixel_novo: Vector2 = jogo.tatico_camera.unproject_position(bloco["pos"] as Vector3)
		var prensa2 := InputEventMouseButton.new()
		prensa2.button_index = MOUSE_BUTTON_LEFT
		prensa2.pressed = true
		prensa2.global_position = pixel_novo
		var soltura2 := InputEventMouseButton.new()
		soltura2.button_index = MOUSE_BUTTON_LEFT
		soltura2.pressed = false
		soltura2.global_position = pixel_novo
		jogo._unhandled_input(prensa2)
		jogo._unhandled_input(soltura2)
		var marcados: Array = jogo.esquadra.selecionados()
		_assert("a soltura sem varredura sobre o pixel do bloco escolhe aquele bloco",
			jogo.esquadra.contar_selecionados() == 1 and not marcados.is_empty() \
				and int(marcados[0]["id"]) == int(bloco["id"]),
			"%d selecionados, id marcado %s, bloco tocado %s" % [jogo.esquadra.contar_selecionados(),
				str(marcados[0].get("id", -1)) if not marcados.is_empty() else "vazio",
				str(bloco.get("id", -1))])

	print("SONDA-OLHO: veredito - quebras=%d - conferencias=%d" % [breaks, notes.size()])
	for nota in notes:
		print(nota)
	quit(1 if breaks > 0 else 0)
