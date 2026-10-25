extends SceneTree

## Sonda visual da massa: prova que o bloco aparece na tela e que ele se LEM como bloco.
##
## As leis numéricas moram em `tools/probes/esquadra.gd` e rodam em headless. Esta aqui não pode:
## sob `--headless` o renderizador é dummy, o `MultiMesh.set_instance_transform` é descartado sem
## erro e a leitura volta identidade — uma sonda de cabeça fria aprovaria uma massa invisível com o
## mesmo verde. O que ela cobra é desenho, e desenho só existe em janela real.
##
## 1) A MASSA ACENDE O VISOR. Dois quadros do MESMO tabuleiro, um com os dois corpos visíveis e um
##    sem: se apagar 5 760 cascos não muda nenhum pixel, a massa está fora da tela (culling, caixa
##    autorgada errada, material sem albedo de vértice) e nenhuma contabilidade salva isso.
## 2) O VAIO É LIDO ENTRE CASCOS. A régua não é "tem brilho no meio do quadro": é a luminância de
##    cada uma das vinte e quatro casas projetadas do bloco mais **lotado** da muralha contra a
##    luminância do ponto exato entre duas casas vizinhas. O sujeito é escolhido, não sorteado: um
##    bloco mordido tem casas escondidas, e a mediana de um amostrado assim cai no céu e reprova a
##    régua por culpa do atrito, não do alinhamento. Casa mais viva que vão, em mediana e nos dois
##    eixos, é o paralelepípedo organizado que o pedido pediu. Manchão sem costura — o enxame — passa
##    no item 1 e reprova aqui.
##    A mesma régua, uma escala acima: o ponto exato entre os centros de dois blocos vizinhos cai na
##    fresta de 2,48 u entre as duas silhuetas, e tem de ler escuro. É o ar que separa "fileiras de
##    blocos" de "parede contínua", e sem ele a muralha inteira é um só manchão grande.
## 3) O ZOOM DA RODA APROXIMA DE VERDADE. A 78° o bloco mede N pixels de boca; a 14° mede bem mais.
##    Zoom que não amplia a silhueta é zoom que só corta a moldura.
## 4) O CUSTO É MEDIDO, NÃO PROMETIDO. A primeira versão desta régua usava FPS e leu 60,0 com a
##    massa e 60,0 sem ela: sob vsync o contador do motor satura no teto do monitor — uma asserção
##    que não pode reprovar não é portão. Por isso o vsync é desligado durante a medição e devolvido
##    em seguida, e o tempo é lido no relógio de parede (`TIME_PROCESS` leu 24,96 ms numa janela que
##    entregava 115 fps, conta que não fecha). A segunda versão pedia sinal positivo a um par A/B só
##    e leu −0,19 ms num build bom: com 6,1 ms de quadro, o drift entre as duas janelas de 150
##    quadros é maior que o custo da massa, e a régua estava medindo o vento. Daqui em diante são
##    `PARES_AB` pares alternados e a MEDIANA dos deltas — o teto continua sendo o portão, e a banda
##    de ruído vai impressa na mensagem para ninguém ler 0,00 como "de graça".
## 5) A ESQUADRA INTEIRA É DESENHADA EM LOTE, NÃO BLOCO A BLOCO. Esta é a lei que paga o projeto:
##    240 blocos e 5 760 cascos desenhados por dois nós de `MultiMesh`. O contador do motor existe
##    (`Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, conferido nesta rodada — a conclusão anterior
##    de que o 4.7 não expunha draw call ao GDScript estava errada) e é lido com a massa no ar e com
##    ela apagada: a diferença é o preço real da esquadra, cena constante ao redor. Medida nesta
##    máquina: 3,9 chamadas por quadro para os 240 blocos (a cena inteira fecha em 442,6 contra
##    438,6 sem a massa), contra as 240 que um nó por bloco cobraria. O teto é essa comparação, não
##    uma conta de superfícies — a derivada das duas superfícies do casco deu 3 a 8 e a medida real
##    variou de 3,9 a 11,9 entre rodadas, o que faria um portão reprovar por barulho. Trinta e duas
##    acomoda a variação e ainda quebra alto se a esquadra deixar de ser lote. "Dois draw calls",
##    como prometiam os cabeçalhos antigos, é falso.
## 6) A SALVA É DESENHADA NO QUADRO INTEIRO, E UMA BOCA POR CASCO. O ledger de
##    `tools/probes/esquadra.gd` família 12 prova contabilidade; o que falta provar é pixel, e pixel
##    só existe aqui. A ponte olha o campo pelo eixo do voo, então um lance que anda em `z` quase não
##    muda de tamanho na tela: o que a lente vê é uma fila de pontos que encolhem, não um risco
##    comprido. A régua é coluna por coluna — o MAIOR ganho de luminância entre o quadro com o nó dos
##    traços ligado e o MESMO quadro congelado com ele desligado, a salva parada em 0,45 s do pulso.
##    Vinte e quatro canos por bloco acendem 5 760 pixels de boca, e o que se cobra é a largura da
##    faixa varrida e a densidade de colunas acesas: um punhado de traços no centro deixa as bordas
##    escuras, e as duas situações não se confundem nem por ruído. O preço continua sendo UM nó: as
##    primitivas do quadro sobem com a salva no ar e as chamadas de desenho, não.
##
## Uso (janela real, sem --headless):
##   godot --path . --quit-after 6000 -s res://tools/probes/massa_visivel.gd

const Esquadra := preload("res://esquadra.gd")

const OUT := "D:/Downloads/tmp-userdata/frame/"
## Janela de amostragem. Curta de propósito: a batalha muda de carga enquanto roda, e o que se quer
## é a diferença entre desenhar a massa e não desenhar, não a média da partida inteira.
const QUADROS_FPS := 150
## Quantos pares A/B (massa no ar / massa apagada) alimentam a régua de tempo. Um só par não separa
## custo de drift: ver a asserção de orçamento.
const PARES_AB := 3
## Largura da grade de casas do bloco e o passo por eixo, lidos do modulo: a régua de boca caminha em
## x e a de camadas em y, e os dois não são mais o mesmo número.
const CASAS_X := Esquadra.CASAS_X
const PASSO_X := Esquadra.PASSO_CASA_X
const PASSO_Y := Esquadra.PASSO_CASA_Y
## Piso de contraste: 0,02 de luminância é um oitavo do ganho que a trinca do visor precisa
## (`fotograma.gd` mede 0,138 -> 0,281) e está duas ordens acima do ruído de céu estrelado lido no
## quadro sem massa. Se a massa não acender nada, o número medido é ~0,000 e a asserção quebra.
const CONTRASTE_MINIMO := 0.02
## O vão não pode ser só escuro por azar: no quadro sem massa o mesmo par casa/vão é medido de novo,
## e a diferença entre os dois é ruído de céu. Um terço do contraste real é o teto desse ruído.
const RUIDO_MAXIMO := 3.0
## Boca esperada do bloco no visor, em fração da largura do quadro, nas duas pontas do zoom.
const BOCA_LARGO_MIN := 0.02
const BOCA_FECHADO_MIN := 0.18
## Orçamento por quadro: metade dos 16,6 ms de uma janela de 60 Hz. Metade porque a outra metade é o
## resto da cena — visor trincado, holograma, cenário e pós — que esta régua não mede.
const TETO_MS := 8.0
## Teto de chamadas de desenho para a esquadra inteira: uma ordem de grandeza abaixo do
## contrafactual. O número que esta lei protege não é "duas" — é "não um por bloco". Com um nó por
## bloco, duzentos e quarenta cascos custariam duzentas e quarenta chamadas; em dois `MultiMesh` a
## régua desta sessão leu entre 7,4 e 11,9, e a variação é do renderizador, que desenha o mesmo
## corpo em passadas que o GDScript não consulta (principal, sombra dos dois sóis, e o que mais o
## Compatibility fizer). Trinta e duas é o teto que acomoda essa variação e ainda quebra alto se a
## massa deixar de ser lote.
const DESENHOS_TETO := 32.0
## ---- Leis da salva desenhada (lei 6) ----
## Grade da varredura, em pixels. O traço tem 8 u de comprimento e 0,55 u de boca
## (`main.gd:TRACO_COMPRIMENTO`), a 60 u da lente: a boca são poucos pixels e a varredura não pode
## amostrar mais grosso que isso sem perder lance.
const PASSO_VARREDURA := 2
## Ganho de luminância que conta como pixel de traço. O céu estrelado, sozinho, não chega aqui: os
## dois quadros da régua são o MESMO tabuleiro congelado, com um nó ligado ou desligado.
const PISTA_MINIMA := 0.03
## Fração da largura do visor que os lances têm de varrer. É o número que responde à queixa: fogo só
## no centro deixa as bordas escuras e a varredura cai para um terço do quadro. O teto natural não é
## 1,0: o painel do holograma cobre o terço esquerdo da janela, e a régua mede o que o comandante vê.
const TRACO_VARREDURA_MIN := 0.45
## Fração das colunas varridas que precisa estar acesa. Cada traço cobre uma ou duas colunas da
## grade e os blocos de uma mesma vertical se sobrepõem em x, então o teto natural é bem abaixo de
## um por bloco; dez por cento é dezenas de lances lendo no quadro.
const TRACO_COLUNAS_MIN := 0.10
## Onde estacionar o pulso para a foto, EM SEGUNDOS — a unidade de `_traco_t` mudou com a onda
## interna. A última casa acende em 0,276 s e o primeiro lance morre em 0,55 s: 0,45 s é o meio
## dessa janela, o único instante em que os 5 760 canos estão no ar ao mesmo tempo.
const TRACO_T_DE_LEITURA := 0.45
## Distância da leitura, em u atrás do centro da muralha aliada. É a pose da ponte, não um drone:
## ver a asserção do enquadramento.
const DISTANCIA_DA_LEITURA := 60.0
## Teto de chamadas de desenho dos cinco mil setecentos e sessenta traços. UM nó por lance cobraria
## 5 760; em lote o que se paga é uma passada, mais o que o tonemapping quiser.
const TRACOS_DESENHOS_TETO := 12.0
## Primitivas mínimas que o nó dos traços acrescenta ao quadro: 5 760 instâncias de doze triângulos
## cada = 69 120, com vinte por cento de folga para o que o culler não submete. É o nó enviado ao
## renderizador, não o pixel — o pixel é a lei de cima.
const TRACO_PRIM_MIN := 55000.0
## Quantos segundos de marcha a sonda pode simular antes de desistir de chegar ao alcance.
const MARCHA_MAXIMA := 120

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

## Média de `n` quadros: ms de parede medidos no relógio do sistema e dois monitores do motor —
## chamadas de desenho e primitivas no quadro. É a régua que o vsync não cala; o FPS trava no teto
## do monitor e `TIME_PROCESS` leu 24,96 ms numa janela que entregava 115 fps, conta que não fecha,
## então o tempo aqui é parede, não opinião do motor.
func _medir_quadros(n: int) -> Dictionary:
	var inicio := Time.get_ticks_usec()
	var desenhos := 0.0
	var primitivas := 0.0
	for i in range(n):
		await process_frame
		desenhos += float(Performance.get_monitor(
			Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitivas += float(Performance.get_monitor(
			Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var q := maxf(float(n), 1.0)
	return {"ms": float(Time.get_ticks_usec() - inicio) / 1000.0 / q,
		"desenhos": desenhos / q, "primitivas": primitivas / q}

func _luz(img: Image, p: Vector2) -> float:
	var x := int(roundf(p.x))
	var y := int(roundf(p.y))
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return -1.0
	var c := img.get_pixel(x, y)
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

## Posição mundial de uma casa, recalculada exatamente como `Esquadra.pintar` escreve: origem + base
## girada pela casa local. É a Malha do MultiMesh, não uma aposta sobre onde ela "deveria" estar.
static func _casa_no_mundo(b: Dictionary, c: int) -> Vector3:
	var rot := Basis.from_euler(Vector3(0.0, float(b["rumo"]), 0.0))
	return (b["pos"] as Vector3) + rot * Esquadra.casa_local(c)

## O vizinho de boreste na grade do lado, achado pelo POSTO e nao pela posicao pintada. Desde a
## muralha que respira dois blocos de esquadroes vizinhos tem a mesma fase em boreste (a fase e do
## ANDAR) mas fases diferentes em altura, e uma busca por posicao atual perderia o par por causa de
## menos de um metro de deriva. A fresta medida continua a dos centros verdadeiros — o que muda e so
## a identificacao do par.
static func _vizinho_de_boreste(e, bloco: Dictionary) -> Dictionary:
	var ancora: Vector3 = e.estacao("aliado")
	var posto_a := Esquadra.posto_no_lado(int(bloco["esquadrao"]), int(bloco["formacao"]), ancora)
	var melhor: Dictionary = {}
	var menor_d := INF
	for b in e.lista_de("aliado"):
		if b == bloco:
			continue
		if Esquadra.casas_vivas(b) != Esquadra.CASAS:
			continue
		var d := Esquadra.posto_no_lado(int(b["esquadrao"]), int(b["formacao"]), ancora) - posto_a
		if absf(d.x - Esquadra.PASSO_BLOCO_X) < 0.01 and absf(d.y) < 0.01 and absf(d.z) < 0.01:
			var q: float = (b["pos"] as Vector3).distance_to(bloco["pos"] as Vector3)
			if q < menor_d:
				menor_d = q
				melhor = b
	return melhor

## Mediana de uma lista de luminâncias, com as amostras inválidas (-1, fora da tela) fora da conta.
static func _mediana(valores: Array[float]) -> float:
	var vive := []
	for v in valores:
		if v >= 0.0:
			vive.append(v)
	if vive.is_empty():
		return -1.0
	vive.sort()
	return float(vive[int(vive.size() / 2.0)])

## Mediana sem o filtro de amostra inválida: os pares de milissegundo podem ser negativos (é o ruído
## do drift), e a régua de luminância acima descarta justamente o que aqui é evidência.
static func _mediana_bruta(valores: Array[float]) -> float:
	var ordenado := valores.duplicate()
	ordenado.sort()
	return float(ordenado[int(ordenado.size() / 2.0)])

## Par casa/vão ao longo de um eixo da grade. `passo` é o deslocamento de uma casa até a vizinha; o
## vão é o ponto do meio, que é onde a réplica de 0,912 u de boca NÃO chega.
func _contraste(img: Image, camera: Camera3D, bloco: Dictionary, passo: Vector3) -> Dictionary:
	var casas: Array[float] = []
	var vaos: Array[float] = []
	var ganhos := 0
	var pares := 0
	for c in range(Esquadra.casas_vivas(bloco)):
		var mundo := _casa_no_mundo(bloco, c)
		# Cada casa é medida duas vezes, uma contra o vizinho de cada lado: em perspectiva uma das
		# faces pode ficar coberta, e o par que sobra ainda conta. Sem par fora da tela.
		for s in [1.0, -1.0]:
			var p_casa := camera.unproject_position(mundo)
			var p_vao := camera.unproject_position(mundo + passo * (s * 0.5))
			var lc := _luz(img, p_casa)
			var lv := _luz(img, p_vao)
			if lc < 0.0 or lv < 0.0:
				continue
			casas.append(lc)
			vaos.append(lv)
			pares += 1
			if lc > lv + 0.005:
				ganhos += 1
	return {"mediana_casa": _mediana(casas), "mediana_vao": _mediana(vaos), "pares": pares,
		"ganhos": ganhos}

## Largura do bloco em pixels do visor: projeta os dois cantos do piso e mede a distância. É a régua
## de que o zoom aproxima silhueta, não só corta moldura.
##
## A projeção é lida com a câmara ainda no grau do quadro medido: `unproject_position` usa a matriz
## viva do nó, não a que estava gravada no `Image` quando ele foi salvo. Na primeira rodada esta
## função rodou depois das duas capturas e devolveu 353 px para os dois lados — a régua estava cega,
## não a lente.
func _boca_px(camera: Camera3D, bloco: Dictionary) -> float:
	var rot := Basis.from_euler(Vector3(0.0, float(bloco["rumo"]), 0.0))
	var a := camera.unproject_position((bloco["pos"] as Vector3)
		+ rot * Esquadra.casa_local(0))
	var b := camera.unproject_position((bloco["pos"] as Vector3)
		+ rot * (Esquadra.casa_local(0) + Vector3(float(CASAS_X - 1) * PASSO_X, 0.0, 0.0)))
	var largura := float(get_root().size.x)
	if a.x < 0.0 or b.x < 0.0 or a.x > largura or b.x > largura:
		return -1.0
	return a.distance_to(b)

func _media_luz(img: Image) -> float:
	var soma := 0.0
	var n := 0
	for u in range(0, img.get_width(), 37):
		for v in range(0, img.get_height(), 37):
			var c := img.get_pixel(u, v)
			soma += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			n += 1
	return soma / maxf(float(n), 1.0)

func _salvar(img: Image, nome: String) -> void:
	var caminho := OUT + nome + ".png"
	img.save_png(caminho)

## Vão de z entre as duas fachadas: a frente aliada mais adiantada contra a frente hostil mais
## adiantada. É o que a marcha precisa fechar antes de a salva ter com quem falar.
static func _vao_das_fachadas(e) -> float:
	var aliado := INF
	var hostil := -INF
	for b in e.lista_de("aliado"):
		if bool(b["vivo"]):
			aliado = minf(aliado, float((b["pos"] as Vector3).z))
	for b in e.lista_de("hostil"):
		if bool(b["vivo"]):
			hostil = maxf(hostil, float((b["pos"] as Vector3).z))
	if aliado == INF or hostil == -INF:
		return INF
	return aliado - hostil

## A régua da salva: coluna por coluna, o maior ganho de luminância entre o quadro com traços e o
## quadro sem. Devolve quantas colunas acenderam e a faixa de x que elas cobrem, em fração do visor.
func _varredura(com: Image, sem: Image) -> Dictionary:
	var largura := com.get_width()
	var altura := com.get_height()
	var colunas := 0
	var total := 0
	var primeira := -1
	var ultima := -1
	var pico := 0.0
	for x in range(0, largura, PASSO_VARREDURA):
		total += 1
		var melhor := 0.0
		for y in range(0, altura, PASSO_VARREDURA):
			var ganho := _luz(com, Vector2(x, y)) - _luz(sem, Vector2(x, y))
			melhor = maxf(melhor, ganho)
		pico = maxf(pico, melhor)
		if melhor >= PISTA_MINIMA:
			colunas += 1
			if primeira < 0:
				primeira = x
			ultima = x
	var varredura := 0.0
	if primeira >= 0:
		varredura = float(ultima - primeira) / float(maxi(largura - 1, 1))
	return {"colunas": colunas, "total": total, "varredura": varredura, "pico": pico,
		"primeira": primeira, "ultima": ultima}

func _initialize() -> void:
	print("SONDA-MASSA-VISIVEL: comecando")
	DirAccess.make_dir_recursive_absolute(OUT)
	var jogo: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(jogo)
	await _frames(5)
	var cam: Camera3D = jogo.ponte_camera

	# ── 1. o custo real, medido em janela ────────────────────────────────────────────────────
	# A massa anda, atira e é repintada durante a janela inteira: é o quadro de batalha, não o de
	# vitrine. As duas janelas rodam na mesma máquina e na mesma sessão, com a cena ao redor
	# constante — entre elas só os dois nós da esquadra mudam de visibilidade.
	#
	# O vsync é desligado para a medição e devolvido em seguida, e isto não é cosmética: amarrada ao
	# teto do monitor, a régua lê a marcação do quadro e não o trabalho da cena. Na primeira rodada,
	# com vsync ligado, ela mediu 60,0 fps com os 5 760 cascos e 60,0 fps sem eles — instrumento
	# mudo, não resultado. Sem vsync, o que sai é o que a máquina entrega.
	#
	# O A/B é repetido `PARES_AB` vezes e o que vira régua é a MEDIANA dos pares, não um par só. A
	# primeira versão media uma dupla e exigia diferença não negativa: com a cena entregando ~6,1 ms
	# por quadro, o drift entre as duas janelas de 150 quadros é da ordem de 0,2 ms e o custo
	# verdadeiro da massa é menor que isso — a asserção reprovava por sinal de ruído, que é portão
	# quebrado. Alternando com/sem/com/sem, o drift que sobe num par desce no outro, e a mediana fica
	# onde a física está.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _frames(QUADROS_FPS)
	var ms_com: Array[float] = []
	var ms_sem: Array[float] = []
	var deltas: Array[float] = []
	var pr_com := 0.0
	var pr_sem := 0.0
	var dc_com := 0.0
	var dc_sem := 0.0
	for par in range(PARES_AB):
		var a := await _medir_quadros(QUADROS_FPS)
		jogo.massa_aliada.visible = false
		jogo.massa_hostil.visible = false
		var b := await _medir_quadros(QUADROS_FPS)
		jogo.massa_aliada.visible = true
		jogo.massa_hostil.visible = true
		ms_com.append(float(a["ms"]))
		ms_sem.append(float(b["ms"]))
		deltas.append(float(a["ms"]) - float(b["ms"]))
		pr_com += float(a["primitivas"])
		pr_sem += float(b["primitivas"])
		dc_com += float(a["desenhos"])
		dc_sem += float(b["desenhos"])
	var n_par := float(PARES_AB)
	var com := {"ms": _mediana_bruta(ms_com), "primitivas": pr_com / n_par,
		"desenhos": dc_com / n_par}
	var sem := {"ms": _mediana_bruta(ms_sem), "primitivas": pr_sem / n_par,
		"desenhos": dc_sem / n_par}
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	var custo_desenhos := float(com["desenhos"]) - float(sem["desenhos"])
	var custo_ms := _mediana_bruta(deltas)
	_assert("a janela ainda entrega taxa de jogo com a massa no ar, sem teto de monitor",
		float(com["ms"]) > 0.0 and 1000.0 / float(com["ms"]) >= 30.0,
		("%.1f fps de parede com %d blocos e %d casas por quadro (%.2f ms por quadro), contra "
			+ "%.1f fps sem a massa") % [1000.0 / float(com["ms"]), 2 * Esquadra.BLOCOS_NO_LADO,
			2 * Esquadra.INSTANCIAS_POR_LADO, com["ms"], 1000.0 / float(sem["ms"])])
	# O portão é o TETO, e a banda de ruído vai impressa junto: exigir sinal positivo num par único
	# de 150 quadros é perguntar ao drift quem mandou — com 6,1 ms de quadro e um custo de massa
	# menor que isso, a régua antiga reprovava um build bom. O piso largo (−2 ms) continua pegando
	# instrumento quebrado, que é o que um diferencial fortemente negativo significa.
	_assert("o tempo de quadro que a massa acrescenta cabe no orçamento de uma janela de 60 Hz",
		custo_ms <= TETO_MS and custo_ms > -2.0,
		("%d pares de %d quadros: %.2f ms por quadro com a massa contra %.2f sem ela (mediana "
			+ "+%.2f ms, pares de %+.2f a %+.2f ms), teto %.1f ms") % [
			PARES_AB, QUADROS_FPS, com["ms"], sem["ms"], custo_ms,
			deltas.min(), deltas.max(), TETO_MS])
	_assert("os 5 760 cascos entram de fato no quadro, medido em primitivas",
		float(com["primitivas"]) > float(sem["primitivas"]) * 1.5,
		"%.0f primitivas por quadro com a massa contra %.0f sem ela (x%.1f)" % [
			com["primitivas"], sem["primitivas"],
			float(com["primitivas"]) / maxf(float(sem["primitivas"]), 1.0)])
	# O teto vem do contrafactual (240 nós custariam 240 chamadas), não de uma conta de superfícies:
	# a contagem dos dois corpos entra na mensagem só como testemunho do lote.
	var superficies := int(jogo.massa_aliada.multimesh.mesh.get_surface_count()) \
		+ int(jogo.massa_hostil.multimesh.mesh.get_surface_count())
	_assert("a esquadra inteira é desenhada em lote, nao bloco a bloco",
		custo_desenhos >= 0.0 and custo_desenhos <= DESENHOS_TETO,
		("240 blocos em dois corpos de %d superficie(s) custam %.1f chamadas de desenho por quadro "
			+ "(%.1f na cena inteira, %.1f sem a massa); um nó por bloco custaria 240") % [
			superficies, custo_desenhos, com["desenhos"], sem["desenhos"]])

	# ── 2. pose de leitura: a ponte estaciona diante de um bloco ─────────────────────────────
	# Congelar por `process_mode` (nunca `set_process(false)`, que é a lei da casa) e mover o rig é
	# instrumento de sonda, não jogabilidade: o que se fotografa é o `MultiMesh` que o jogo já
	# pintou, visto pela câmera da ponte, com a FOV que a roda entrega.
	jogo.process_mode = Node.PROCESS_MODE_DISABLED
	# Precondition da fatia 3.5, declarada no instrumento e nao afrouxada na regua: a secao 1 rodou a
	# batalha viva, e com o lance por casa desenhada sao 5 760 canos no ar em cada pulso. Congelar o
	# jogo congela `_traco_t` junto, entao os tracos da ultima salva ficam estacionados no meio do
	# voo exatamente sobre a fresta entre dois blocos — a amostra do vao le 1,000 (branco puro), o
	# quadro de controle sem a massa acende igual, e a lei da emenda lida reprovaria o desenho da
	# salva em vez de reprovar a muralha. Apagar o nos dos tracos durante esta secao e o que devolve
	# a regua ao que ela mede: silhueta de casco e o ar entre cascos. A salva tem secao e leis
	# proprias (a 3 abaixo), e elas rearmam o nos.
	jogo.massa_tracos.visible = false
	# Precondition do SUJEITO, declarada aqui e nao na regua: a secao 1 deixou a muralha morderada
	# (painel `MASSA 120/120` conta bloco VIVO, e vivo com cinco casas ainda e vivo), e casa sem
	# navio e pintada com base nula exatamente sobre o centro do bloco — vazio. Escolhido pelo maior
	# z sem essa conta, o sujeito caiu num bloco morderado e a mediana das vinte e quatro casas le
	# ceu em vinte e uma amostras: a regua de costura ia reprovar o atrito em vez de reprovar o
	# desenho. O sujeito e o bloco mais LOTADO, desempatado pelo mais adiantado, e a amostragem
	# abaixo caminha so sobre as casas que tem silhueta no ar.
	var bloco: Dictionary = {}
	var casas_do_sujeito := 0
	var lotados := 0
	for b in jogo.esquadra.lista_de("aliado"):
		var c := Esquadra.casas_vivas(b)
		if c == Esquadra.CASAS:
			lotados += 1
		if bloco.is_empty() or c > casas_do_sujeito \
				or (c == casas_do_sujeito \
					and float((b["pos"] as Vector3).z) > float((bloco["pos"] as Vector3).z)):
			bloco = b
			casas_do_sujeito = c
	var alvo: Vector3 = bloco["pos"]
	jogo.bridge_rig.global_position = alvo + Vector3(0.0, 0.0, 46.0)
	jogo.bridge_rig.rotation = Vector3.ZERO
	jogo.campo_zoom = 0.0
	jogo._update_bridge(0.0)
	await _frames(4)
	var largo := get_root().get_texture().get_image()
	_salvar(largo, "massa_largo")
	var boca_largo := _boca_px(cam, bloco)
	var graus_largo := cam.fov
	jogo.campo_zoom = 1.0
	jogo._update_bridge(0.0)
	await _frames(4)
	var fechado := get_root().get_texture().get_image()
	_salvar(fechado, "massa_zoom")
	var boca_fechado := _boca_px(cam, bloco)
	var graus_fechado := cam.fov
	# O mesmo `Image` serve às duas leituras de vão: o quadro fechado é o que tem o bloco grande.
	var olho_x := Vector3(PASSO_X, 0.0, 0.0)
	var olho_y := Vector3(0.0, PASSO_Y, 0.0)
	var com_massa := _contraste(fechado, cam, bloco, olho_x)
	var com_massa_y := _contraste(fechado, cam, bloco, olho_y)
	jogo.massa_aliada.visible = false
	jogo.massa_hostil.visible = false
	await _frames(3)
	var sem_massa := get_root().get_texture().get_image()
	_salvar(sem_massa, "massa_apagada")
	jogo.massa_aliada.visible = true
	jogo.massa_hostil.visible = true
	jogo.massa_tracos.visible = true
	var sem_contraste := _contraste(sem_massa, cam, bloco, olho_x)
	_assert("o bloco está no visor: a projeção das vinte e quatro casas cai dentro da tela",
		com_massa["pares"] >= 20 and casas_do_sujeito == Esquadra.CASAS,
			("%d pares casa/vão projetados de %d casas no ar, sujeito lotado (existem %d blocos com as " % [
				com_massa["pares"], casas_do_sujeito, lotados])
				+ ("%d casas na muralha)" % Esquadra.CASAS))
	_assert("apagar a massa apaga pixels: ela está desenhada, nao apenas contada",
		absf(_media_luz(largo) - _media_luz(fechado)) >= 0.0
			and _media_luz(fechado) > _media_luz(sem_massa) + 0.002,
		"luminância média do quadro fechado %.4f contra %.4f sem a massa (quadro largo %.4f)" % [
			_media_luz(fechado), _media_luz(sem_massa), _media_luz(largo)])
	_assert("há vão escuro entre dois cascos vizinhos: o bloco é fileira, nao mancha",
		com_massa["mediana_casa"] - com_massa["mediana_vao"] >= CONTRASTE_MINIMO
			and com_massa["ganhos"] * 2 >= com_massa["pares"],
		"caso x: casa %.3f vs vao %.3f (ganho %.3f, %d/%d pares acima do vão), piso %.2f" % [
			com_massa["mediana_casa"], com_massa["mediana_vao"],
			com_massa["mediana_casa"] - com_massa["mediana_vao"], com_massa["ganhos"],
			com_massa["pares"], CONTRASTE_MINIMO])
	_assert("a mesma régua no eixo da altura: as camadas também têm costura",
		com_massa_y["mediana_casa"] - com_massa_y["mediana_vao"] >= CONTRASTE_MINIMO,
		"caso y: casa %.3f vs vao %.3f (ganho %.3f em %d pares)" % [
			com_massa_y["mediana_casa"], com_massa_y["mediana_vao"],
			com_massa_y["mediana_casa"] - com_massa_y["mediana_vao"], com_massa_y["pares"]])
	_assert("sem a massa no ar a mesma régua não acha contraste: a costura vem dos cascos",
		absf(sem_contraste["mediana_casa"] - sem_contraste["mediana_vao"])
			<= maxf(0.002, (com_massa["mediana_casa"] - com_massa["mediana_vao"]) / RUIDO_MAXIMO),
		"sem massa a diferença é %.4f, com massa é %.4f (teto %.4f)" % [
			absf(sem_contraste["mediana_casa"] - sem_contraste["mediana_vao"]),
			com_massa["mediana_casa"] - com_massa["mediana_vao"],
			maxf(0.002, (com_massa["mediana_casa"] - com_massa["mediana_vao"]) / RUIDO_MAXIMO)])
	# O ar entre BLOCOS, medido no pixel e nao no inventario: o ponto exato do meio entre o centro
	# deste bloco e o do vizinho de boreste cai na fresta entre as duas silhuetas — a casa extrema
	# para em 4,8 + meia boca 0,456 = 5,26 de um lado e 13 − 5,26 = 7,74 do outro, e o meio (6,5)
	# esta no vazio dos 2,48 u. Muralha sem emenda, pega continua, teria o mesmo ponto tao vivo
	# quanto uma casa. Com a respira, a distancia em boreste dentro do mesmo andar e literalmente
	# constante (a fase do boreste e do andar) — o que a sonda perde e o par identificado pela
	# posicao, nao a fresta.
	var vizinho := _vizinho_de_boreste(jogo.esquadra, bloco)
	var luz_vao := -1.0
	if not vizinho.is_empty():
		var meio := ((bloco["pos"] as Vector3) + (vizinho["pos"] as Vector3)) * 0.5
		luz_vao = _luz(fechado, cam.unproject_position(meio))
	_assert("a fresta entre dois blocos vizinhos e escura: a muralha tem emenda lida",
		not vizinho.is_empty() and luz_vao >= 0.0 \
			and com_massa["mediana_casa"] - luz_vao >= CONTRASTE_MINIMO,
			"vao entre blocos %.3f contra casa mediana %.3f (ganho %.3f, piso %.2f), vizinho lido a " % [
				luz_vao, com_massa["mediana_casa"], com_massa["mediana_casa"] - luz_vao,
				CONTRASTE_MINIMO]
				+ "%.2f u de centro a centro (posto nominal %.2f u)" % [
					(bloco["pos"] as Vector3).distance_to(vizinho["pos"] as Vector3),
					Esquadra.PASSO_BLOCO_X])
	_assert("a roda amplia a silhueta do bloco, nao só a moldura",
			boca_largo > img_boca_min(largo) and boca_fechado > boca_largo * 2.5
				and boca_fechado > float(fechado.get_width()) * BOCA_FECHADO_MIN,
			"boca do bloco %.0f px a %0.0f graus e %.0f px a %0.0f graus, quadro de %dx%d, proa do " % [
				boca_largo, graus_largo, boca_fechado, graus_fechado,
				largo.get_width(), largo.get_height()]
				+ "bloco medida %.1f graus (a linha manda %.0f)" % [
					rad_to_deg(float(bloco["rumo"])), rad_to_deg(Esquadra.rumo_da_linha("aliado"))])

	# ── 3. a salva desenhada: o quadro em que a muralha inteira atira ──────────────────────────
	# O portão tem de ser preparado, não assumido. No primeiro quadro as fachadas estão a 130 u uma
	# da outra e o alcance de 73 u não alcança nada: armar salva em campo vazio devolve zero pares e
	# um quadro escuro, e escuro por falta de alvo é indistinguível de escuro por traço invisível.
	# Então a sonda remonta a esquadra, anda as muralhas com `passo` (que marcha e não atira, não
	# gasta um casco) até o vão caber no alcance, arma a salva à mão e congela o pulso em 0,45 s — a
	# janela em que a onda já acendeu as vinte e quatro casas e o primeiro lance ainda não morreu.
	jogo._remontar_esquadras()
	var andados := 0
	while andados < MARCHA_MAXIMA:
		if _vao_das_fachadas(jogo.esquadra) <= Esquadra.DISTANCIA_DE_CONTATO + 1.0:
			break
		jogo._atualizar_esquadras(1.0)
		andados += 1
	var vao_final := _vao_das_fachadas(jogo.esquadra)
	# A leitura é feita da pose da ponte, não de um drone. Medido nesta rodada: a 133 u de recuo o
	# campo inteiro cabe no visor, cada bloco vira um ponto de dois pixels e a régua de colunas acha
	# quatro — ela aprovaria um fogo invisível só por estar longe. A 60 u, que é a distância a que o
	# comandante vê a muralha na partida, o traço de 0,55 u mede de três a seis pixels e é essa a
	# tela que as leis abaixo cobram. O deslocamento fixo entre o rig e a lente é descontado porque a
	# posição que manda no enquadramento é a da câmara, não a do nó.
	var desloc: Vector3 = cam.global_position - (jogo.bridge_rig as Node3D).global_position
	jogo.bridge_rig.rotation = Vector3.ZERO
	jogo.bridge_rig.global_position = (jogo.esquadra.centro_aliado as Vector3 \
		+ Vector3(0.0, 6.0, DISTANCIA_DA_LEITURA)) - desloc
	jogo.campo_zoom = 0.0
	jogo._update_bridge(0.0)
	jogo._salva_da_massa()
	jogo._traco_t = TRACO_T_DE_LEITURA
	jogo._pintar_tracos()
	await _frames(4)
	var com_tracos := get_root().get_texture().get_image()
	_salvar(com_tracos, "salva_voando")
	# Congelar o pulso no meio da janela viva (0,45 s, entre a última casa acender e o primeiro lance
	# morrer) é o que põe os 5 760 canos no ar de uma vez. `lances` nao e mais o tamanho da fila: a
	# fila agora e quatro casas por bloco cobrado, e a sonda le as duas contas separadas.
	var blocos_cobrados := int(jogo.esquadra.pares_da_ultima_salva.size())
	var tracos_armados := int(jogo._tracos_voando.size())
	var caros := await _medir_quadros(QUADROS_FPS)
	jogo.massa_tracos.visible = false
	await _frames(3)
	var sem_tracos := get_root().get_texture().get_image()
	_salvar(sem_tracos, "salva_apagada")
	var baratos := await _medir_quadros(QUADROS_FPS)
	jogo.massa_tracos.visible = true
	var fogo := _varredura(com_tracos, sem_tracos)
	var custo_primitivas := float(caros["primitivas"]) - float(baratos["primitivas"])
	var custo_desenhos_traco := float(caros["desenhos"]) - float(baratos["desenhos"])
	_assert("a marcha chegou ao alcance: sem par no ledger não ha o que desenhar",
		blocos_cobrados >= 200 and tracos_armados == blocos_cobrados * Esquadra.CASAS,
			"%d blocos cobraram e %d tracos armados (%d casas por bloco) depois de %d s de marcha, " % [
				blocos_cobrados, tracos_armados, Esquadra.CASAS, andados] \
				+ "vao das fachadas %.1f u contra alcance %.1f u" % [
					vao_final, Esquadra.ALCANCE_DE_BLOCO])
	_assert("apagar o nó dos traços apaga pixels: a salva está desenhada, nao apenas contada",
		float(fogo["colunas"]) >= float(fogo["total"]) * TRACO_COLUNAS_MIN
			and fogo["pico"] >= PISTA_MINIMA,
		"%d de %d colunas varridas acendem (%.1f%% do quadro), pico de ganho %.3f contra piso %.2f"
		% [fogo["colunas"], fogo["total"], 100.0 * float(fogo["colunas"]) / float(fogo["total"]),
			fogo["pico"], PISTA_MINIMA])
	_assert("o fogo varre a largura do visor, nao so o meio do campo",
		fogo["varredura"] >= TRACO_VARREDURA_MIN,
			"aceso de x=%d a x=%d num quadro de %d px (%.0f%% da largura), %d tracos no ar" % [
				fogo["primeira"], fogo["ultima"], com_tracos.get_width(),
				100.0 * float(fogo["varredura"]), tracos_armados])
	_assert("o nó dos traços é submetido ao renderizador com a salva no ar",
		custo_primitivas >= TRACO_PRIM_MIN,
			("%.0f primitivas por quadro com a salva no ar contra %.0f apagada (%+.0f por quadro, "
			+ "piso %.0f = 5 760 caixas de 12 triangulos)") % [caros["primitivas"],
				baratos["primitivas"], custo_primitivas, TRACO_PRIM_MIN])
	_assert("o preco de cinco mil setecentos e sessenta lances no ar e UMA passada de desenho",
		custo_desenhos_traco >= 0.0 and custo_desenhos_traco <= TRACOS_DESENHOS_TETO,
			("%.1f chamadas por quadro com a salva no ar contra %.1f com ela apagada; um no por "
			+ "lance cobraria 5 760") % [caros["desenhos"], baratos["desenhos"]])

	print("SONDA-MASSA-VISIVEL: veredito - quebras=%d - conferencias=%d" % [breaks, notes.size()])
	for nota in notes:
		print(nota)
	print(("SONDA-MASSA-VISIVEL: quadros salvos em %s (massa_largo, massa_zoom, massa_apagada, "
		+ "salva_voando, salva_apagada)") % OUT)
	quit(1 if breaks > 0 else 0)

static func img_boca_min(img: Image) -> float:
	return float(img.get_width()) * BOCA_LARGO_MIN
