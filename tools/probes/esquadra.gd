extends SceneTree

## Sonda da esquadra de blocos: a massa que o comandante vê quando roda o mouse.
##
## O pedido do jogador foi batalha com milhares de navios, e a resposta é contabilidade: um bloco
## vale ~100 cascos, vinte e quatro casas desenham o bloco, e a tela inteira custa dois `MultiMesh`.
## Uma sonda que só conferisse "apareceu alguma coisa" aprovaria um enxame desordenado tão bem quanto
## uma linha de batalha. O que ela cobra:
##
## 1) A CONTA FECHA. 4 × 3 × 2 = 24 casas; 5 × 4 = 20 blocos por esquadrão; 3 colunas × 2 andares = 6
##    esquadrões por lado; 120 blocos por lado, 240 no tabuleiro, 2 880 instâncias por `MultiMesh`,
##    5 760 desenhadas — e 24 000 cascos na largada, porque "milhares de navios" é número que se
##    mede, não adjetivo.
## 2) A GRADE NÃO SE ATRAVESSA E TEM AR. Nenhum piso de bloco sobrepõe outro do MESMO lado, nenhum
##    sobrepõe o do lado ADVERSO, e a fachada aliada fica toda atrás da traseira hostil. Foi assim que
##    os erros de layout apareceram: com passo 12 e esquadrões a 52 × 44 a profundidade do lado dava
##    ±40 u e as duas esquadras se sobrepunham no centro da linha; e com cada esquadrão ancorado no
##    SEU núcleo (5 u de distância entre cascos, passo de 13 × 7 na massa) as seis grades particulares
##    saíam deslocadas uma da outra e 36 pares de companheiros de linha se atravessavam. Uma grade por
##    lado é o que faz a formação ser lida como formação. O ar também é cobrado: o par de blocos mais
##    apertado do lado tem de deixar ≥ 2,4 u entre cascos, e com o passo antigo de 8 × 5 sobravam 0,7
##    u — muralha sem emenda entre blocos lê-se como uma peça só, não como fileiras de blocos.
## 3) O TOPO FECHA PRIMEIRO. A casa é ordenada camada por camada, de baixo para cima: sob atrito some
##    a camada de cima, nunca um buraco no meio. É a silhueta encolhendo que faz a lotação ser lida
##    de longe.
## 4) CASCO É RECURSO QUE SE GASTA E MATA. `_reparar` sobe os três eixos e não encosta em `navios`; a
##    zero o bloco morre uma vez só — cadáver não leva tiro, e sem essa guarda o segundo impacto
##    contava a mesma perda duas vezes.
## 5) RENDIÇÃO CRUZA UMA VEZ SÓ E O BANCO É TETO. Tripulação a zero muda o bloco de lado uma única
##    vez, com piso de tripulação. A lista do lado É o orçamento de instância (`índice × 24`, teto de
##    2 880): o afundado é despejado, o recém-chegado ganha posto de grade próprio (sem esta passada
##    dois blocos disputariam o mesmo ponto do chão) e a presa que não cabe em banco cheio morre no
##    campo em vez de escrever fora do `MultiMesh`. Qualquer apagamento corrige a lista para cima,
##    então o lado inteiro é marcado sujo, e a cauda órfã do lado que perdeu é apagada — sem isso
##    fica um bloco fantasma de 24 casas pendurado no campo.
## 6) DUAS MONTADAS GÊMEAS FECHAM O MESMO LEDGER. Marchadas até o contato, sessenta salvas em duas
##    instâncias com as mesmas âncoras devolvem `resumo()`, vivos, navios, perdas e presas idênticos:
##    a salva é um quadro conjunto, lido antes de qualquer escrita. A marcha é precondition: desde que
##    a largada ganhou campo de aproximação, salvas disparadas a 154 u não lançam contra nada, e
##    "ledger idêntico" sairia do zero — não da paridade.
## 7) NENHUM SORTEIO TOCADO. Duzentos quadros de massa, a travessia inteira, sessenta salvas e uma
##    repintura forçada não movem `rng` nem `visual_rng`, e a cauda de quarenta sorteios é a da
##    semente cravada — a mesma régua de `geoide.gd` e `superficies.gd`. E o ledger dos doze cascos não
##    ganha uma linha: nenhum `hp` de casco é escrito pela massa. A família confere também que a massa
##    QUEIMOU nesse intervalo, porque inércia medida sobre troca vazia não prova nada.
## 8) PARADO E INTEIRO NÃO CUSTA ESCRITA. A segunda pintura sem movimento devolve zero blocos
##    tocados; com um quadro de marcha devolve os duzentos e quarenta. Desde a fatia 2 a CONTA de
##    duzentos quadros deixou de ser 48 000: o portão de pintura só regrava quem andou mais de
##    0,01 u, e o bloco em arranque anda `a × delta²` = 0,0008 u no quadro um. O portão passou a ser
##    o regime — nenhum lado escreve mais de um por bloco por quadro, e do primeiro quadro pleno
##    (medido: 13) em diante os duzentos e quarenta pagam todo quadro, sem buraco no meio do
##    caminho. Medido: 23 070 + 23 160 escritas contra 24 000 de teto por lado. O relógio é impresso
##    como medida, não como lei: a mesma máquina deu 761, 918 e 1 287 ms para os mesmos duzentos
##    quadros em três rodadas seguidas — com ±35 % de ruído, nenhum número de `ms` pode ser assinado
##    aqui, e a asserção antiga (`custo_ms >= 0.0`) não podia reprovar nada.
## 9) A PONTE MOSTRA A MASSA E A RODA DÁ ZOOM. Dois nós `MultiMeshInstance3D` na cena, malha única
##    compartilhada, a caixa crua lida da própria malha (3,647 x 1,07 x 5,0) fechando a boca em
##    0,912 u dentro da casa de 3,2 — 2,288 u de costura no costado e 1,95 u de proa a popa, lidos do
##    `AABB` da malha nos dois eixos horizontais: é o número que decide se a fileira se lê como
##    fileira, e ele vem da malha, nunca do cabeçalho, `use_colors` +
##    `vertex_color_use_as_albedo` ligados (esquecer um dos dois é a massa inteira cinza), caixa de
##    desenho autorgada cobrindo o campo, a roda levando a FOV de 78° a 14° com aperto nas duas
##    pontas, e o letreiro da massa sendo `Label` — os 35 botões de `menu.gd` não se mexem.
## 10) A LARGADA TEM CAMPO E ELE É CRUZADO MARCHANDO. As duas fachadas nascem a 154,0 u uma da outra e
##     fecham no `DISTANCIA_DE_CONTATO` (40 u) sob a lei da massa: o bloco arranca a `a × delta²`
##     (0,00084 u no quadro um), anda meio teto no quadro 60 e teto cheio no quadro 120, e o maior
##     deslocamento de um quadro em todo o trânsito é esse teto — 0,1000 u. Campo cruzado acima disso
##     não é aproximação, é teleporte. Os 113,0 u custaram 1 210 quadros (20,2 s de tela) e são
##     MEDIDA impressa, não régua: com rampa de 2,0 s e freio de chegada em `raiz(2 · a · d)` a
##     travessia deixou de ser 114 ÷ 0,1. O recuo tem prova contrafactual — com a estação em zero a
##     grade sozinha deixa 24,0 u de fachada a fachada, MENOS que o próprio contato e longe de
##     qualquer travessia.
##     É a régua que desmente a conta de cabeça desta sessão: o campo não é comprado pelo ar entre
##     blocos, é comprado pelo recuo, e sem esta asserção "abrir o ar" passaria como se tivesse feito
##     a aproximação sozinha.
## 11) TODO BLOCO ATIRA, E ATIRA NO SEU VIZINHO. No contato, `lancados` é o número de blocos vivos e
##     armados dos dois lados — ninguém segura fogo porque o próprio fundo da muralha ficou fora de
##     alcance: o alcance é lido da geometria (2 × fachada + contato + andar = 73 u), não de hábito, e
##     a escolha de alvo é conferida par a par contra a distância mínima REAL. O fogo local espalha
##     (muitos alvos), a ordem da ponte converge (um alvo só, o bloco mais próximo do ponto comandado,
##     e quem não alcança não atira), e a muralha hostil continua local porque a ordem é nossa. A fila
##     `pares_da_ultima_salva` tem de ter o tamanho exato do ledger: é ela que o desenho lê, e fila
##     diferente de conta é tela mostrando fogo que a conta não cobrou.
## 12) O LANCE DA MASSA TEM CANAL DE DESENHO. A queixa do comandante era de tela, não de conta: sem
##     traço, os únicos disparos visíveis são os dos doze cascos e a salva "só acontece no centro".
##     Aqui a lei é o CANAL: um nó `MultiMeshInstance3D` com uma instância por bloco, a fila armada
##     do desenho igual ao ledger lance a lance, o convergir da ordem refletido nos pontos de destino
##     (um só `para` quando a ponte concentra, muitos quando solta), o jitter de boca sem sorteio, e
##     o pulso que apaga a fila no impacto — traço pendurado é "todo mundo atirando o tempo todo".
##     O que ela NÃO prova é pixel: sob `--headless` o `set_instance_transform` é descartado e a
##     leitura volta identidade, então o acender do visor mora em `massa_visivel.gd`.
##
## Uso: godot --headless --path . --quit-after 6000 -s res://tools/probes/esquadra.gd

const Esquadra := preload("res://esquadra.gd")
## A ficha da massa é a régua do arranque e do freio: sem ela, as duas réguas abaixo teriam de ser
## números chutados pela sonda em vez de lidos da lei que o jogo aplica.
const Voo := preload("res://voo.gd")

## Espelhos das constantes de `main.gd` e `esquadra.gd`: a instância do jogo é não tipada, e mudar o
## número lá sem mudar aqui quebra a asserção de propósito.
const MAP_X := 320.0
const MAP_Z_NEAR := 40.0
const MAP_Z_FAR := -600.0
const BLOCOS_POR_LADO := 120
const CASAS := 24
const INSTANCIAS_POR_LADO := 2880
const NAVIOS_NO_BLOCO := 100
## Piso do bloco em u: 4 casas de 3,2 em x mais a boca de 0,912, 2 casas de 3,2 em z mais os 1,25 de
## comprimento, 3 camadas de 1,6 em y mais os 0,27 de altura. É a régua das asserções de sobreposição
## e de ar — os três eixos, porque a muralha agora também empilha andar.
const PISO_X := 10.52
const PISO_Z := 4.45
const PISO_Y := 3.47
## Passo da grade que a sonda assinou — a malha é contínua entre esquadrões, não só dentro deles.
const PASSO_X := 13.0
const PASSO_Z := 7.0
## Largura de um esquadrão no lado e altura de um andar: as duas cotas do ponto comandado da
## família 11, que tem de cair DENTRO da muralha hostil para o teste ser de escolha, não de alcance.
const PASSO_ESQUADRAO_X := 65.0
const ANDAR := 6.0
## Ar mínimo entre os cascos mais próximos de dois blocos vizinhos do mesmo lado. Com o passo antigo
## de 8 × 5 isto aqui valia 0,7 u e a muralha não tinha emenda.
const AR_MINIMO := 2.4
const PONTE_FOV_LARGO := 78.0
const PONTE_FOV_FECHADO := 14.0
## Folga de coordenada: a grade é contagem exata, mas `move_toward` deixa resto de ponto flutuante.
const FOLGA := 0.1
## A travessia: 114,0 u de marcha (154,0 − 40,0) separam as duas fachadas. Desde a fatia 2 o
## caminho não é mais percorrido a passo cravado: o bloco arranca na `aceleracao` da ficha da massa
## (3,0 u/s², 2,0 s até os 6,0 u/s = 120 quadros) e freia nos últimos 6,0 u (`raiz(2 · a · d)`),
## então a conta de quadros deixou de ser divisão e passou a ser medida — o laço roda até o contato e
## imprime o tempo que custou, como já faz com o relógio da família 11. 1.500 é o teto de iteração,
## não uma régua. O teto de um QUADRO continua sendo o passo da marcha: campo cruzado de salto não é
## aproximação, é teleporte.
const QUADROS_DA_TRAVESSIA := 1500
const SALTO_MAXIMO := Esquadra.MARCHA_DE_BLOCO / 60.0
## Passo do primeiro quadro de um bloco, derivado da ficha: `vel` anda `a × delta` (0,05 u/s) e a
## posição anda `vel × delta`. É a digital do arranque — sem lei, o quadro um já daria 0,1000 u.
const PASSO_DO_ARRANQUE := float(Voo.FICHA_BLOCO["aceleracao"]) / 3600.0
## Folga de passo: a maior coordenada deste tabuleiro é ~154 u, onde um float32 vale ~1,9e-5 u por
## dígito e a diferença de duas posições come dois dígitos. É a mesma folga de
## `tools/probes/voo.gd`, para as duas sondas lerem passo com a mesma régua.
const FOLGA_PASSO := 0.00003
## Campo lido na largada, de fachada a fachada: os 130 u de recuo mais os 45 u de separação dos doze
## núcleos, menos o braço de cada muralha até sua fileira frontal (2 × 10,5 u de centro de casco).
## Conta que a família 10 mede e o README cita — é a régua do "espaço a ser cruzado".
const CAMPO_ESPERADO := 154.0
## Tolerância da fachada: é a resolução da leitura (centro do casco da última fileira, medido entre
## duas muralhas de doze núcleos), não folga de marcha — o pouso da lei grava o posto exato.
const FOLGA_CONTATO := 1.0
const QUADROS := 200
const SALVAS := 60
## Espelhos de `main.gd` para a família 12: um traço por bloco nos dois lados, e o voo que fecha a
## fila. Mudar o número lá sem mudar aqui quebra a asserção de propósito.
const TRACOS_MAXIMOS := 240
const TRACO_SEG := 0.55
const SEMENTE_RNG := 1234567890
const SEMENTE_VISUAL := 555

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

## Monta o jogo e congela pelo instrumento da casa: `process_mode`, nunca `set_process(false)`.
func _montar_jogo() -> Node3D:
	var game: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(3)
	game._update_bridge(0.0)
	game._update_hud()
	return game

func _cauda(jogo) -> Array[int]:
	var retirada: Array[int] = []
	for i in range(40):
		retirada.append(jogo.rng.randi())
	return retirada

## As duas linhas da largada, na cota média dos núcleos reais e sem a deriva de y que o
## `visual_rng` dá: o que se mede aqui é a grade, e a grade é função do índice.
func _nucleos(aliada: bool) -> Array:
	var posicoes: Array = []
	for i in range(6):
		if aliada:
			posicoes.append(Vector3((float(i) - 2.5) * 5.0, 0.0, -38.0 - float(i % 2) * 5.0))
		else:
			posicoes.append(Vector3((float(i) - 2.5) * 6.0, 0.0, -82.0 - float(i % 2) * 7.0))
	return posicoes

func _nova_esquadra() -> Esquadra:
	var e := Esquadra.new()
	e.montar(_nucleos(true), _nucleos(false))
	return e

func _novo_mm(e: Esquadra) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = e.malha_replica()
	mm.instance_count = Esquadra.INSTANCIAS_POR_LADO
	return mm

## Sobreposição de pisos: dois blocos ocupam o mesmo espaço se as caixas de 10,5 × 4,45 × 3,47 se
## cruzam nos TRÊS eixos. Ignorar y era correto enquanto a segunda dimensão do lado era profundidade;
## desde que os esquadrões se empilham em altura, dois blocos dividem a mesma coluna de boreste a 12 u
## de piso vertical, e uma régua de dois eixos lê isso como 120 sobreposições que não existem.
func _sobrepoe(a: Dictionary, b: Dictionary) -> bool:
	var pa: Vector3 = a["pos"]
	var pb: Vector3 = b["pos"]
	return absf(pa.x - pb.x) < PISO_X - FOLGA and absf(pa.z - pb.z) < PISO_Z - FOLGA \
		and absf(pa.y - pb.y) < PISO_Y - FOLGA


## Põe a massa em contato de linha antes de cobrar troca de salva. É precondition, não enfeite:
## desde que a largada ganhou campo de aproximação, o hostil nasce a 154,0 u de fachada e o alcance
## é 60 u, então sessenta salvas disparadas na monta não achavam alvo nenhum -- o "ledger idêntico
## das duas montadas" saía de zero lançamentos, não de paridade, e a asserção ficava aprovando o
## vazio. Marchar é o único caminho honesto até lá: é o `passo` do jogo, com os mesmos núcleos da
## monta, e o contador devolvido prova que houve travessia.
func _marchar_ate_contato(e: Esquadra, nuc_a: Array, nuc_h: Array) -> int:
	var q := 0
	while _fachadas(e) > Esquadra.DISTANCIA_DE_CONTATO + FOLGA_CONTATO \
			and q < QUADROS_DA_TRAVESSIA:
		e.passo(1.0 / 60.0, nuc_a, nuc_h)
		q += 1
	return q


## Idem a `_marchar_ate_contato`, mas pela porta da ponte: `_atualizar_esquadras` é o único `passo`
## que o jogo chama, e é ele — não a sonda — quem tem de fechar o campo. É puro pela mesma lei que a
## família 7 diz conferir: locomoção e pintura, sem sorteio e sem escrita em casco.
func _marchar_na_ponte(jogo) -> int:
	var q := 0
	while _fachadas(jogo.esquadra) > Esquadra.DISTANCIA_DE_CONTATO + FOLGA_CONTATO \
			and q < QUADROS_DA_TRAVESSIA:
		jogo._atualizar_esquadras(1.0 / 60.0)
		q += 1
	return q


## Blocos que TÊM de atirar: vivos, com arma e com navio. É o denominador da lei de engajamento --
## contar `lancados` contra 240 seria cobrar fogo de cadáver, e cadáver não atira (família 4).
func _armados(e: Esquadra) -> int:
	var n := 0
	for lado in ["aliado", "hostil"]:
		for b in e.lista_de(lado):
			if bool(b["vivo"]) and float(b["ARMAS"]) > 0.0 and float(b["navios"]) > 0.0:
				n += 1
	return n


## A distância do bloco até o inimigo VIVO mais próximo, sem o portão de alcance: é a régua contra a
## qual a escolha de alvo é conferida. Com o portão dentro da conta, um bloco fora de alcance sairia
## "correto" por não atirar, e a asserção aprovaria a omissão em vez da escolha.
static func _distancia_do_mais_proximo(bloco: Dictionary, lista: Array[Dictionary]) -> float:
	var melhor := INF
	for c in lista:
		if not bool(c["vivo"]) or int(c["id"]) == int(bloco["id"]):
			continue
		melhor = minf(melhor, (c["pos"] as Vector3).distance_to(bloco["pos"]))
	return melhor


## Idem em bloco (não em número), para a lei do alvo comandado: qual é o adversário mais próximo
## desta posição, medido sem alcance e sem portão nenhum.
static func _bloco_mais_proximo_de(pos: Vector3, lista: Array[Dictionary]) -> Dictionary:
	var melhor: Dictionary = {}
	var melhor_d := INF
	for c in lista:
		if not bool(c["vivo"]):
			continue
		var d: float = (c["pos"] as Vector3).distance_to(pos)
		if d < melhor_d:
			melhor_d = d
			melhor = c
	return melhor


## Quantos alvos distintos a salva tocou, e quantos lances tiveram os mesmos alvos do outro lado
## (o lado é "aliado" ou "hostil"): serve para a lei "fogo local espalha, fogo comandado converge".
func _alvos_distintos(pares: Array[Dictionary], lado: String) -> Dictionary:
	var vistos: Dictionary = {}
	var lancados := 0
	for p in pares:
		if String(p["lado"]) != lado:
			continue
		lancados += 1
		vistos[int((p["alvo"] as Dictionary)["id"])] = true
	return {"lancados": lancados, "distintos": vistos.size()}


## Faixa de x dos pontos de uma fila de traços: é a régua de que o fogo DESENHADO varre a largura da
## muralha, e não um feixe no meio do campo — a queixa original era de tela, e conta boa no meio
## continuaria sendo fogo só no centro.
static func _faixa_x_dos_pontos(fila: Array[Dictionary], chave: String) -> Dictionary:
	var minimo := INF
	var maximo := -INF
	for t in fila:
		var p: Vector3 = t[chave]
		minimo = minf(minimo, p.x)
		maximo = maxf(maximo, p.x)
	return {"min": minimo, "max": maximo}


## Quantos destinos distintos a fila do desenho carrega. Convergência comandada é UM; fogo de linha
## é muitos. Lido da fila própria do desenho, não do ledger: é ela que a tela vai pintar.
static func _pontos_distintos(fila: Array[Dictionary], aliado: bool) -> int:
	var vistos: Dictionary = {}
	for t in fila:
		if bool(t["aliado"]) == aliado:
			vistos[str(t["para"])] = true
	return vistos.size()


## Carimbo da fila inteira (origens e destinos): serve para a lei do jitter, que não pode sortear.
static func _selo_da_fila(fila: Array[Dictionary]) -> String:
	var partes: PackedStringArray = []
	for t in fila:
		partes.append("%s>%s|%s" % [str(t["de"]), str(t["para"]), str(bool(t["aliado"]))])
	return "|".join(partes)


func _faixa_z(e: Esquadra, lado: String) -> Dictionary:
	var minimo := INF
	var maximo := -INF
	for b in e.lista_de(lado):
		var z: float = (b["pos"] as Vector3).z
		minimo = minf(minimo, z)
		maximo = maxf(maximo, z)
	return {"min": minimo, "max": maximo}

## Idem em y: é a régua dos dois andares, a segunda dimensão do lado desde que o ar abriu.
func _faixa_y(e: Esquadra, lado: String) -> Dictionary:
	var minimo := INF
	var maximo := -INF
	for b in e.lista_de(lado):
		var y: float = (b["pos"] as Vector3).y
		minimo = minf(minimo, y)
		maximo = maxf(maximo, y)
	return {"min": minimo, "max": maximo}

## Vão de fachada a fachada, lido no centro do casco da última fileira de cada muralha. Positivo é
## campo ainda por cruzar; negativo é uma esquadra dentro da outra.
func _fachadas(e: Esquadra) -> float:
	return float(_faixa_z(e, "aliado")["min"]) - float(_faixa_z(e, "hostil")["max"])

## Ar entre caixas de blocos: o eixo em que eles se separam, descontado o piso. negativo é sobreposição.
static func _ar_entre(pa: Vector3, pb: Vector3) -> float:
	return maxf(absf(pa.x - pb.x) - PISO_X,
		maxf(absf(pa.z - pb.z) - PISO_Z, absf(pa.y - pb.y) - PISO_Y))

func _initialize() -> void:
	print("SONDA-ESQUADRA: comecando")

	# ── 1. a conta fecha ────────────────────────────────────────────────────────────────────
	var e := _nova_esquadra()
	_assert("o bloco e um paralelepipedo de vinte e quatro casas",
		Esquadra.CASAS == CASAS and Esquadra.CASAS_X * Esquadra.CASAS_Y * Esquadra.CASAS_Z == CASAS,
		"%d x %d x %d = %d" % [Esquadra.CASAS_X, Esquadra.CASAS_Y, Esquadra.CASAS_Z, Esquadra.CASAS])
	_assert("o lado tem cento e vinte blocos, o tabuleiro duzentos e quarenta",
		e.blocos_aliados.size() == BLOCOS_POR_LADO and e.blocos_hostis.size() == BLOCOS_POR_LADO
			and Esquadra.BLOCOS_NO_ESQUADRAO == 20 and Esquadra.ESQUADROES_NO_LADO == 6,
		"%d + %d blocos de %d casas" % [e.blocos_aliados.size(), e.blocos_hostis.size(), CASAS])
	_assert("um MultiMesh por lado custa duas mil e oitocentas e oitenta instancias num so corpo",
		Esquadra.INSTANCIAS_POR_LADO == INSTANCIAS_POR_LADO
			and 2 * Esquadra.INSTANCIAS_POR_LADO == 5760,
		"%d por lado, %d na tela inteira" % [Esquadra.INSTANCIAS_POR_LADO,
			2 * Esquadra.INSTANCIAS_POR_LADO])
	var ids: Dictionary = {}
	var lote_errado := 0
	for lado in ["aliado", "hostil"]:
		for b in e.lista_de(lado):
			ids[int(b["id"])] = true
			if String(b["lado"]) != lado or float(b["navios"]) != float(NAVIOS_NO_BLOCO) \
					or not bool(b["vivo"]) or int(b["pintas"]["casas"]) != -1:
				lote_errado += 1
	_assert("cada bloco nasce uma vez, do lado certo, cheio e marcado sujo",
		ids.size() == 2 * BLOCOS_POR_LADO and lote_errado == 0,
		"%d ids unicos, %d fora do gabarito" % [ids.size(), lote_errado])
	_assert("a largada passa dos vinte mil navios, que e o numero pedido",
		e.navios("aliado") + e.navios("hostil") >= 20000,
		"%d aliado + %d hostil = %d cascos" % [e.navios("aliado"), e.navios("hostil"),
			e.navios("aliado") + e.navios("hostil")])

	# ── 2. a grade nao se atravessa, e tem ar ───────────────────────────────────────────────
	var propria := 0
	var alheia := 0
	var minimo_centro := INF
	var ar_min := INF
	for lado in ["aliado", "hostil"]:
		var lista := e.lista_de(lado)
		for i in range(lista.size()):
			for j in range(i + 1, lista.size()):
				if _sobrepoe(lista[i], lista[j]):
					propria += 1
				var pa: Vector3 = lista[i]["pos"]
				var pb: Vector3 = lista[j]["pos"]
				minimo_centro = minf(minimo_centro, pa.distance_to(pb))
				ar_min = minf(ar_min, _ar_entre(pa, pb))
	for a in e.blocos_aliados:
		for b in e.blocos_hostis:
			if _sobrepoe(a, b):
				alheia += 1
	var faixa_a := _faixa_z(e, "aliado")
	var faixa_h := _faixa_z(e, "hostil")
	var ext := e.extensao()
	var dentro := (ext["min"] as Vector3).x >= -MAP_X and (ext["max"] as Vector3).x <= MAP_X \
		and (ext["min"] as Vector3).z >= MAP_Z_FAR and (ext["max"] as Vector3).z <= MAP_Z_NEAR
	_assert("nenhum bloco sobrepoe o piso de um companheiro de linha", propria == 0,
		"%d sobreposigoes no mesmo lado, centro mais proximo a %.2f u (passo %.0f x %.0f)" % [
			propria, minimo_centro, PASSO_X, PASSO_Z])
	_assert("o par de blocos mais apertado do lado ainda deixa ar entre cascos",
		ar_min >= AR_MINIMO,
		"%.2f u de ar no par mais junto (piso %.2f x %.2f x %.2f dentro do passo %.0f x %.0f); com o passo antigo de 8 x 5 o ar era 0,7 u" % [
			ar_min, PISO_X, PISO_Z, PISO_Y, PASSO_X, PASSO_Z])
	var folga_linhas := float(faixa_a["min"]) - float(faixa_h["max"])
	_assert("nenhum bloco aliado atravessa um hostil", alheia == 0,
		"%d sobreposicoes entre os lados; fachada aliada em z %.1f, traseira hostil em z %.1f, %s de %.1f u" % [
			alheia, faixa_a["min"], faixa_h["max"],
			"folga" if folga_linhas > 0.0 else "CRUZADAS", absf(folga_linhas)])
	var sep_nucleos := absf((e.centros("aliado") as Vector3).z - (e.centros("hostil") as Vector3).z)
	var fundo_lado := float(faixa_a["max"]) - float(faixa_a["min"])
	# A segunda dimensão do LADO mudou de eixo: os dois grupos de esquadrões não se seguem mais em
	# profundidade, se empilham em altura. É o que devolve fundo de tabuleiro para o campo.
	var andar := _faixa_y(e, "aliado")
	_assert("o lado e tres colunas de dois andares, nao duas fileiras de fundo",
		Esquadra.COLUNAS_NO_LADO * Esquadra.CAMADAS_NO_LADO == 6 \
			and absf(float(andar["max"]) - float(andar["min"]) - Esquadra.PASSO_ESQUADRAO_Y) < FOLGA \
			and fundo_lado <= Esquadra.FUNDO_DA_MURALHA,
		"andares a %.1f u de separacao, lado com %.1f u de fundo contra %.1f u de muralha (linhas a %.1f u)" % [
			float(andar["max"]) - float(andar["min"]), fundo_lado, Esquadra.FUNDO_DA_MURALHA,
			sep_nucleos])
	# O contrafactual do recuo: a grade, sozinha, NAO faz campo. Sem estacao recuada as fachadas
	# nascem a ~24 u — menos que o proprio contato — e o pedido ("um espaco grande a ser cruzado")
	# voltaria a ser um acaso de layout, pago com muro contra muro.
	var cf := _nova_esquadra()
	cf.recuo_hostil = 0.0
	for lado_cf in ["aliado", "hostil"]:
		for b in cf.lista_de(lado_cf):
			b["pos"] = Esquadra.posto_no_lado(int(b["esquadrao"]), int(b["formacao"]),
				cf.estacao(lado_cf))
	var fachada_cf := _fachadas(cf)
	_assert("sem a estacao recuada nao ha campo nenhum, so grade colada",
		fachada_cf < Esquadra.DISTANCIA_DE_CONTATO,
		"recuo zero deixa fachada a fachada em %.1f u, contra %.0f u de contato e %.0f u de campo na largada" % [
			fachada_cf, Esquadra.DISTANCIA_DE_CONTATO, CAMPO_ESPERADO])
	_assert("o campo inteiro cabe no tabuleiro de hoje", dentro,
		"largura %.0f u, fundo %.0f u, de x %.0f a %.0f e z %.0f a %.0f" % [ext["largura"],
			ext["fundo"], (ext["min"] as Vector3).x, (ext["max"] as Vector3).x,
			(ext["min"] as Vector3).z, (ext["max"] as Vector3).z])

	# ── 3. o topo fecha primeiro ────────────────────────────────────────────────────────────
	var ordem_ok := true
	for c in range(1, CASAS):
		if Esquadra.casa_local(c).y < Esquadra.casa_local(c - 1).y - 0.0001:
			ordem_ok = false
	var meia := _nova_esquadra()
	meia.blocos_hostis[0]["navios"] = float(NAVIOS_NO_BLOCO) * 0.5
	var casas_meia := Esquadra.casas_vivas(meia.blocos_hostis[0])
	var terco := _nova_esquadra()
	terco.blocos_hostis[0]["navios"] = float(NAVIOS_NO_BLOCO) / 3.0
	var casas_terco := Esquadra.casas_vivas(terco.blocos_hostis[0])
	var pintadas_max_y := -INF
	var escondidas_min_y := INF
	for c in range(CASAS):
		var y := Esquadra.casa_local(c).y
		if c < casas_terco:
			pintadas_max_y = maxf(pintadas_max_y, y)
		else:
			escondidas_min_y = minf(escondidas_min_y, y)
	var meia_pintada_max_y := -INF
	var meia_escondida_min_y := INF
	for c in range(CASAS):
		var y := Esquadra.casa_local(c).y
		if c < casas_meia:
			meia_pintada_max_y = maxf(meia_pintada_max_y, y)
		else:
			meia_escondida_min_y = minf(meia_escondida_min_y, y)
	_assert("a ordem da casa e camada por camada, de baixo para cima", ordem_ok
		and Esquadra.casa_local(0).y < 0.0 and Esquadra.casa_local(CASAS - 1).y > 0.0,
		"casa 0 em y %.2f, casa 23 em y %.2f" % [Esquadra.casa_local(0).y,
			Esquadra.casa_local(CASAS - 1).y])
	# Uma camada tem oito casas, então o corte rigoroso se mede em um terço (oito casas). Na metade
	# (doze) o corte cai NO MEIO da camada 1: ai a lei não é "toda pintada abaixo de toda escondida",
	# é "nenhuma escondida abaixo de uma pintada" — buraco embaixo de casa viva seria o enxame.
	_assert("sobrando um terco, o que sumiu foi o topo: nenhuma escondida fica abaixo",
		casas_terco == 8 and pintadas_max_y < escondidas_min_y,
		"%d casas pintadas ate y %.2f, escondidas de y %.2f para cima" % [casas_terco,
			pintadas_max_y, escondidas_min_y])
	_assert("com metade fora, o corte cai dentro de uma camada mas nunca inverte",
		casas_meia == 12 and meia_pintada_max_y <= meia_escondida_min_y,
		"%d casas pintadas ate y %.2f, escondidas a partir de y %.2f" % [casas_meia,
			meia_pintada_max_y, meia_escondida_min_y])
	_assert("um casco ainda vivo nunca pinta zero casas",
		Esquadra.casas_vivas({"navios": 1.0}) == 1, "navios = 1 -> 1 casa")

	# ── 4. casco e recurso que se gasta e mata ──────────────────────────────────────────────
	var g := _nova_esquadra()
	var alvo: Dictionary = g.blocos_hostis[5]
	alvo["MOTORES"] = 40.0
	alvo["ARMAS"] = 40.0
	alvo["TRIPULACAO"] = 40.0
	var navios_antes := float(alvo["navios"])
	g._reparar(1.0)
	_assert("o reparo sobe motores, armas e tripulacao e nao encosta no casco",
		absf(float(alvo["MOTORES"]) - 41.1) < 0.001 and absf(float(alvo["ARMAS"]) - 40.9) < 0.001 \
			and absf(float(alvo["TRIPULACAO"]) - 40.6) < 0.001
			and float(alvo["navios"]) == navios_antes,
		"MOTORES %.1f, ARMAS %.1f, TRIPULACAO %.1f, navios intactos em %.0f" % [alvo["MOTORES"],
			alvo["ARMAS"], alvo["TRIPULACAO"], alvo["navios"]])
	var perdas_antes := int(g.perdas_hostis)
	alvo["navios"] = 6.0
	var afundou := g._aplicar_golpe(alvo, "CASCO", 5.0)
	var re_petardo := g._aplicar_golpe(alvo, "CASCO", 5.0)
	var segunda_perda := int(g.perdas_hostis) - perdas_antes
	g._aplicar_golpe(alvo, "TRIPULACAO", 200.0)
	_assert("casco a zero afunda o bloco e a conta de perdas cobra uma vez so",
		afundou and not re_petardo and not bool(alvo["vivo"]) and segunda_perda == 1
			and not bool(alvo["rendicao"]),
		"afundou=%s, tiro em cadavez=%s, perdas=+%d, cadaver rende-se=%s" % [afundou, re_petardo,
			segunda_perda, alvo["rendicao"]])

	# ── 5. rendicao cruza uma vez so, e o banco e o teto ────────────────────────────────────
	var r := _nova_esquadra()
	# O `MultiMesh` de um lado tem DUAS MIL E OITOCENTAS E OITENTA casas e o índice é
	# `posição_na_lista × 24`: a lista do lado é o teto. Abrir buraco afundando um aliado é o que faz
	# a travessia ser exercida no caminho real — sem o despejo do morto, a chegada estouraria a
	# instância e o headless encheria o log de erro.
	var buraco: Dictionary = r.blocos_aliados[3]
	r._aplicar_golpe(buraco, "CASCO", 200.0)
	r._prencher_rendicoes()
	_assert("o bloco afundado sai da lista e devolve o banco ao lado",
		not r.blocos_aliados.has(buraco) and r.blocos_aliados.size() == BLOCOS_POR_LADO - 1
			and not bool(buraco["vivo"]),
		"aliado tem %d assentos (era %d) e o afundado ainda esta na lista=%s" % [
			r.blocos_aliados.size(), BLOCOS_POR_LADO, r.blocos_aliados.has(buraco)])
	var presa: Dictionary = r.blocos_hostis[7]
	r._aplicar_golpe(presa, "TRIPULACAO", 200.0)
	r._prencher_rendicoes()
	var piso_presa := float(presa["TRIPULACAO"])
	var na_alianca := r.blocos_aliados.has(presa)
	var invalidou := true
	for b in r.blocos_aliados:
		if int(b["pintas"]["casas"]) != -1:
			invalidou = false
	var posto_livre := 0
	var postos: Dictionary = {}
	for b in r.blocos_aliados:
		var posto := int(b["esquadrao"]) * Esquadra.BLOCOS_NO_ESQUADRAO + int(b["formacao"])
		if postos.has(posto):
			posto_livre += 1
		else:
			postos[posto] = true
	var volta := false
	r._aplicar_golpe(presa, "TRIPULACAO", 200.0)
	r._prencher_rendicoes()
	volta = r.blocos_hostis.has(presa)
	_assert("tripulacao a zero muda o bloco de lado, com piso de tripulacao",
		na_alianca and bool(presa["presa"]) and absf(piso_presa
			- Esquadra.TRIPULACAO_DE_PRESA) < 0.001 and int(r.presas) == 1,
		"presa no lado aliado=%s, TRIPULACAO=%.0f lido antes do segundo tiro, presas=%d" % [
			na_alianca, piso_presa, r.presas])
	_assert("o recem-chegado ganha posto proprio: nenhuma casa da grade duplicada",
		posto_livre == 0 and r.blocos_aliados.size() == BLOCOS_POR_LADO,
		"%d postos repetidos entre %d aliados" % [posto_livre, r.blocos_aliados.size()])
	_assert("o lado que recebeu fica inteiro marcado sujo: indice novo, pintura nova", invalidou,
		"%d blocos aliados, todos com casas = -1" % r.blocos_aliados.size())
	# Banco cheio: o lado receptor nao tem mais instancia nenhuma, e a recusa e contada como
	# afundamento do lado que perdeu. Sem esta guarda a pintura escreveria depois do fim do
	# MultiMesh — o erro que o headless denunciou.
	var recusou_antes := int(r.perdas_hostis)
	var recusa: Dictionary = r.blocos_hostis[9]
	r._aplicar_golpe(recusa, "TRIPULACAO", 200.0)
	r._prencher_rendicoes()
	_assert("presa sem banco nao estoura a instancia: morre no campo, contada como perda",
		not r.blocos_aliados.has(recusa) and not bool(recusa["vivo"]) \
			and int(r.perdas_hostis) == recusou_antes + 1 \
			and r.blocos_aliados.size() <= BLOCOS_POR_LADO,
		"recusada virou perda=%d, aliado segue em %d assentos, hostil em %d" % [
			int(r.perdas_hostis) - recusou_antes, r.blocos_aliados.size(),
			r.blocos_hostis.size()])
	var mm_a := _novo_mm(r)
	var mm_h := _novo_mm(r)
	var primeira := r.pintar(mm_a, "aliado", true)
	var segunda := r.pintar(mm_h, "hostil", true)
	var cauda_h := int(r._casas_pintadas["hostil"])
	_assert("a cauda orfa do lado que perdeu e apagada e a contagem encolhe",
		segunda == r.blocos_hostis.size() and cauda_h == r.blocos_hostis.size() * CASAS,
		"hostil pinta %d blocos e passa a %d casas escritas (a lista cheia seria %d)" % [
			segunda, cauda_h, BLOCOS_POR_LADO * CASAS])
	_assert("um bloco rendido nao volta a cruzar o tabuleiro", not volta and int(r.presas) == 1,
		"voltou ao lado hostil=%s, presas=%d" % [volta, r.presas])
	_assert("a pintura forcada cobre o tabuleiro inteiro, com a presaja no lado novo",
		primeira == BLOCOS_POR_LADO and segunda <= BLOCOS_POR_LADO - 1,
		"aliado %d + hostil %d = %d tocados" % [primeira, segunda, primeira + segunda])

	# ── 6. duas montadas gemeas fecham o mesmo ledger ───────────────────────────────────────
	var nuc_a := _nucleos(true)
	var nuc_h := _nucleos(false)
	var x := _nova_esquadra()
	var y := _nova_esquadra()
	var quadros_x := _marchar_ate_contato(x, nuc_a, nuc_h)
	var quadros_y := _marchar_ate_contato(y, nuc_a, nuc_h)
	# Lida imediatamente após a marcha: depois das sessenta salvas a fileira da frente já afundou, e
	# a régua de fachada passa a medir o vazio que ela deixou (54 u, não 40). Não é erro — é outra
	# grandeza, e a asserção de travessia quer a de chegada.
	var fachada_chegada := _fachadas(x)
	var k := 0
	var ultima_fogo: Dictionary = {}
	while k < SALVAS:
		x.passo(1.0 / 60.0, nuc_a, nuc_h)
		y.passo(1.0 / 60.0, nuc_a, nuc_h)
		ultima_fogo = x.troca_salva()
		y.troca_salva()
		k += 1
	# A travessia tem de acontecer nas duas montadas do mesmo jeito -- é a paridade do instrumento,
	# e é o que impede a asserção de baixo de ser aprovada por um lado que andou e outro que ficou.
	_assert("as duas montadas cruzam o campo no mesmo quadro", quadros_x == quadros_y \
			and quadros_x > 0, "%d quadros de marcha ate o contato nas duas, fachada de chegada em %.1f u" % [
				quadros_x, fachada_chegada])
	# Sem esta, a família inteira seria contabilidade de vazio: `lancados` é o número de pares que
	# efetivamente tinham alvo a 60 u, e zero lançamentos não prova paridade nenhuma.
	_assert("depois da travessia a salva encontra alvo: a troca nao e fogo contra o vazio",
		int(ultima_fogo.get("lancados", 0)) > 0,
			"%d lancados na ultima salva, salva numero %d, fachada %.1f u apos %d afundados aliados" % [
				int(ultima_fogo.get("lancados", 0)), int(ultima_fogo.get("salva", 0)),
				_fachadas(x), int(x.perdas_aliadas)])
	_assert("%d salvas em duas montadas gemeas fecham ledger identico" % SALVAS,
		x.resumo() == y.resumo() and int(x.perdas_aliadas) == int(y.perdas_aliadas) \
			and int(x.perdas_hostis) == int(y.perdas_hostis) and int(x.presas) == int(y.presas) \
			and x.navios("aliado") == y.navios("aliado") and x.navios("hostil") == y.navios("hostil"),
		"%s" % x.resumo())
	var duplicados := 0
	var vistos: Dictionary = {}
	for lado in ["aliado", "hostil"]:
		for b in x.lista_de(lado):
			if vistos.has(int(b["id"])):
				duplicados += 1
			vistos[int(b["id"])] = true
	# Depois de sessenta salvas a conta que não pode estourar é a de assentos: `pintar` escreve em
	# `indice × 24`, e a instância para em 2 880. Um lado com cento e vinte e um blocos não é "um
	# bloco a mais", é escrita fora do buffer.
	_assert("um bloco existe em uma lista, e uma lista so", duplicados == 0
			and x.blocos_aliados.size() <= BLOCOS_POR_LADO \
			and x.blocos_hostis.size() <= BLOCOS_POR_LADO,
		"%d ids unicos em %d assentos ali + %d hostil (teto %d por lado)" % [vistos.size(),
			x.blocos_aliados.size(), x.blocos_hostis.size(), BLOCOS_POR_LADO])
	print("SONDA-ESQUADRA: atrito medido apos %d salvas - %s" % [SALVAS, x.resumo()])
	print("SONDA-ESQUADRA: perdas - aliados afundados=%d, hostis afundados=%d, rendidos=%d" % [
		int(x.perdas_aliadas), int(x.perdas_hostis), int(x.presas)])

	# ── 7. nenhum sorteio tocado (na ponte) ─────────────────────────────────────────────────
	var jogo := await _montar_jogo()
	jogo.rng.seed = SEMENTE_RNG
	jogo.visual_rng.seed = SEMENTE_VISUAL
	var rng_antes := int(jogo.rng.state)
	var visual_antes := int(jogo.visual_rng.state)
	var cauda_semente: Array[int] = _cauda(jogo)
	jogo.rng.seed = SEMENTE_RNG
	jogo.visual_rng.seed = SEMENTE_VISUAL
	var hps_antes: Array[int] = []
	for lista in [jogo.fleet, jogo.enemies]:
		for unit in lista:
			hps_antes.append(int(roundf(float(unit["hp"]) * 1000.0)))
	var q := 0
	while q < QUADROS:
		jogo._atualizar_esquadras(1.0 / 60.0)
		q += 1
	# A travessia antes do tiro, também na ponte: com o campo de aproximação da largada, sessenta
	# salvas lançadas contra uma muralha a 154 u de fachada não acham alvo nenhum, e a asserção de
	# "nenhum sorteio tocado" passaria dígito por dígito com a massa apagada. Inércia provada sobre
	# troca vazia não inércia — é contabilidade de nada.
	var q_marcha := _marchar_na_ponte(jogo)
	var s := 0
	while s < SALVAS:
		jogo._salva_da_massa()
		s += 1
	jogo._pintar_massa(true)
	_assert("%d quadros de massa mais %d de travessia nao movem o gerador de combate" % [
		QUADROS, q_marcha],
		int(jogo.rng.state) == rng_antes, "%d -> %d" % [rng_antes, int(jogo.rng.state)])
	_assert("%d quadros de massa mais %d de travessia nao movem o gerador visual" % [
		QUADROS, q_marcha],
		int(jogo.visual_rng.state) == visual_antes, "%d -> %d" % [visual_antes,
			int(jogo.visual_rng.state)])
	# O estado é lido ANTES da cauda: `_cauda` consome quarenta sorteios e, comparada depois, ela
	# mesma moveria a régua que se diz conferir.
	var rng_pos_massa := int(jogo.rng.state)
	var cauda_depois: Array[int] = _cauda(jogo)
	var cauda_igual := rng_pos_massa == rng_antes
	for i in range(40):
		if cauda_semente[i] != cauda_depois[i]:
			cauda_igual = false
	_assert("a cauda de quarenta sorteios sobrevive a massa", cauda_igual,
		"estado %d antes e %d depois de %d quadros, %d de travessia e %d salvas; cauda abre em %d nos dois lados" % [
			rng_antes, rng_pos_massa, QUADROS, q_marcha, SALVAS, cauda_semente[0]])
	var hps_depois: Array[int] = []
	for lista in [jogo.fleet, jogo.enemies]:
		for unit in lista:
			hps_depois.append(int(roundf(float(unit["hp"]) * 1000.0)))
	var casco_mexido := hps_antes != hps_depois
	_assert("a massa nao escreve o hp de casco nenhum: o ledger dos doze nao ganha linha",
		not casco_mexido, "%d cascos conferidos, %d divergentes" % [hps_antes.size(),
			0 if not casco_mexido else hps_antes.size()])
	# A régua que diz que as três de cima mediram alguma coisa: se a travessia não fechou o campo, os
	# doze mil navios continuam intactos e a inércia é aprovada sobre uma batalha que não aconteceu.
	var vivos_ponte := int(jogo.esquadra.navios("aliado")) + int(jogo.esquadra.navios("hostil"))
	_assert("na ponte a troca queima de verdade depois de %d quadros de travessia" % q_marcha,
		vivos_ponte < 2 * BLOCOS_POR_LADO * Esquadra.NAVIOS_NO_BLOCO,
			"%d navios vivos de %d, fachada %.1f u, %d aliados e %d hostis afundados, %d rendidos" % [
				vivos_ponte, 2 * BLOCOS_POR_LADO * Esquadra.NAVIOS_NO_BLOCO,
				_fachadas(jogo.esquadra), int(jogo.esquadra.perdas_aliadas),
				int(jogo.esquadra.perdas_hostis), int(jogo.esquadra.presas)])

	# ── 8. parado e inteiro nao custa escrita (+ custo medido) ──────────────────────────────
	var p := _nova_esquadra()
	var mm_p := _novo_mm(p)
	var mm_q := _novo_mm(p)
	p.passo(1.0 / 60.0, nuc_a, nuc_h)
	var andavo := p.pintar(mm_p, "aliado", false) + p.pintar(mm_q, "hostil", false)
	var parado := p.pintar(mm_p, "aliado", false) + p.pintar(mm_q, "hostil", false)
	_assert("um quadro de massa custa os duzentos e quarenta blocos repintados",
		andavo == 2 * BLOCOS_POR_LADO, "%d tocados" % andavo)
	_assert("parado e inteiro, o bloco nao custa uma escrita", parado == 0,
		"%d tocados na segunda pintura, sem movimento no meio" % parado)
	# A linha avance 0,05 u por quadro: com âncora fixa os blocos chegam no posto e o laço para de
	# escrever, e o número medido seria o de uma frota ancorada, não o de uma batalha em marcha.
	var custo_quadros := 0.0
	var escritas := 0
	var escritas_aliado := 0
	var escritas_hostil := 0
	var quadro_pleno := -1
	var paros_depois := 0
	var inicio_ms := Time.get_ticks_msec()
	var w := 0
	while w < QUADROS:
		# O avanço vem ANTES do passo: com o primeiro quadro no mesmo pé da monta, a esquadra aliada
		# já está colada no próprio posto, nenhum bloco se move, e a régua lê o vazio em vez de ler
		# a marcha.
		custo_quadros -= 0.05
		var nuc_movidos: Array = []
		for n in nuc_a:
			nuc_movidos.append((n as Vector3) + Vector3(0.0, 0.0, custo_quadros))
		p.passo(1.0 / 60.0, nuc_movidos, nuc_h)
		var tocou_a := p.pintar(mm_p, "aliado", false)
		var tocou_h := p.pintar(mm_q, "hostil", false)
		escritas += tocou_a + tocou_h
		escritas_aliado += tocou_a
		escritas_hostil += tocou_h
		# O primeiro quadro em que a marcha paga os duzentos e quarenta é o fim da rampa: antes dele
		# o passo do bloco é menor que a folga de pintura (`esquadra.gd` só regrava quem andou mais
		# de 0,01 u), então um quadro de arranque baratinho é a lei funcionando, não uma frota parada.
		if tocou_a == BLOCOS_POR_LADO and tocou_h == BLOCOS_POR_LADO:
			if quadro_pleno < 0:
				quadro_pleno = w + 1
		elif quadro_pleno > 0:
			paros_depois += 1
		w += 1
	var custo_ms := float(Time.get_ticks_msec() - inicio_ms)
	var casas_por_quadro := 2 * INSTANCIAS_POR_LADO
	var casas_ms := float(QUADROS * casas_por_quadro) / maxf(custo_ms, 1.0)
	# O relógio saiu do portão, não do log. Três rodadas do MESMO código nesta máquina fecharam os
	# mesmos duzentos quadros em 761, 918 e 1 287 ms — ±35 % de ruído, com um `godot.exe` pendurado
	# de outra sessão comendo núcleo — e a asserção antiga (`custo_ms >= 0.0`) não podia reprovar
	# nada. O que é determinístico é a conta de escritas, e ela mudou de forma com a lei: um bloco
	# que anda menos de 0,01 u num quadro não regrava, então os primeiros quadros do arranque são
	# baratos por construção. O portão passa a ser o regime, não a soma: nenhum dos dois lados pode
	# escrever mais que um por bloco por quadro, e a partir do primeiro quadro pleno a marcha paga
	# os duzentos e quarenta em todo quadro, sem buraco no meio do caminho.
	_assert("nenhum lado escreve mais que um por bloco em um quadro",
		escritas_aliado <= QUADROS * BLOCOS_POR_LADO \
			and escritas_hostil <= QUADROS * BLOCOS_POR_LADO,
			"%d + %d escritas contra %d de teto por lado" % [escritas_aliado, escritas_hostil,
				QUADROS * BLOCOS_POR_LADO])
	_assert("do quadro %d em diante a marcha repinte os duzentos e quarenta blocos todo quadro" % quadro_pleno,
		quadro_pleno > 0 and quadro_pleno <= int(Esquadra.MARCHA_DE_BLOCO
			/ float(Voo.FICHA_BLOCO["aceleracao"]) * 60.0) and paros_depois == 0,
			"primeiro quadro pleno %d (rampa de %d quadros), %d quadros parcos depois dele, %d escritas no total" % [
				quadro_pleno, int(Esquadra.MARCHA_DE_BLOCO / float(Voo.FICHA_BLOCO["aceleracao"]) * 60.0),
				paros_depois, escritas])
	_assert("%.3f ms por quadro de massa - medida impressa, nao portada" % (custo_ms / float(QUADROS)),
		true, "%d ms nos %d quadros, %d casas/ms; %d escritas de bloco contra %d de teto" % [
			int(custo_ms), QUADROS, int(casas_ms), escritas, QUADROS * 2 * BLOCOS_POR_LADO])

	# ── 9. a ponte mostra a massa e a roda da zoom ──────────────────────────────────────────
	var no_a: MultiMeshInstance3D = jogo.massa_aliada
	var no_h: MultiMeshInstance3D = jogo.massa_hostil
	var na_cena := 0
	for filho in jogo.get_children():
		if filho is MultiMeshInstance3D:
			na_cena += 1
	_assert("a massa inteira custa dois nos, nao duzentos e quarenta",
		is_instance_valid(no_a) and is_instance_valid(no_h) and no_a.name == "Esquadra Aliada" \
			and no_h.name == "Esquadra Hostil",
		"%d MultiMeshInstance3D na cena (ceu + dois corpos da massa)" % na_cena)
	var mm1: MultiMesh = no_a.multimesh
	var mm2: MultiMesh = no_h.multimesh
	_assert("cada corpo traz as suas vinte e oito centenas e oitenta casas em transformar 3D",
		mm1.instance_count == INSTANCIAS_POR_LADO and mm2.instance_count == INSTANCIAS_POR_LADO \
			and mm1.transform_format == MultiMesh.TRANSFORM_3D,
		"%d + %d instancias" % [mm1.instance_count, mm2.instance_count])
	_assert("cor por instancia precisa dos dois flags ligados, nao de um",
		mm1.use_colors and mm2.use_colors \
			and (no_a.material_override as StandardMaterial3D).vertex_color_use_as_albedo \
			and (no_h.material_override as StandardMaterial3D).vertex_color_use_as_albedo,
		"use_colors + vertex_color_use_as_albedo nos dois lados")
	var caixa := no_a.custom_aabb
	var campo: Dictionary = jogo.esquadra.extensao()
	_assert("a caixa de desenho autorgada cobre o campo inteiro",
		caixa.has_point(campo["min"]) and caixa.has_point(campo["max"]),
		"aabb %s e %s cobre min %s / max %s" % [caixa.position, caixa.size,
			campo["min"], campo["max"]])
	_assert("os dois corpos dividem a MESMA malha de replica",
		mm1.mesh.get_instance_id() == mm2.mesh.get_instance_id() \
			and mm1.mesh.get_surface_count() == 1,
		"malha de %d vertices nao indexados, uma superficie" % [
			(mm1.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()])
	# A caixa e medida na malha, nao copiada do cabecalho: e ela que decide se a fileira tem costura.
	# Boca maior que o passo fecha o vao entre casas e a massa vira manchao, com a contagem de
	# instancias intacta e o olho reprovando.
	var aabb_replica: AABB = (mm1.mesh as ArrayMesh).get_aabb()
	var boca := aabb_replica.size.x * Esquadra.ESCALA_REPLICA
	var comprimento := aabb_replica.size.z * Esquadra.ESCALA_REPLICA
	_assert("a replica fecha dentro da casa nos dois eixos, com costura lida, nao com vontade",
		aabb_replica.size.distance_to(Vector3(3.647, 1.07, 5.0)) < 0.01 \
			and boca < Esquadra.PASSO_CASA_X and absf(boca - 0.912) < 0.005 \
			and comprimento < Esquadra.PASSO_CASA_Z and absf(comprimento - 1.25) < 0.005,
		"caixa crua %.3f x %.2f x %.1f, escala %.2f: boca %.4f u na casa de %.1f (costura %.4f u), comprimento %.3f u na casa de %.1f (costura %.3f u)" % [
			aabb_replica.size.x, aabb_replica.size.y, aabb_replica.size.z,
			Esquadra.ESCALA_REPLICA, boca, Esquadra.PASSO_CASA_X,
			Esquadra.PASSO_CASA_X - boca, comprimento, Esquadra.PASSO_CASA_Z,
			Esquadra.PASSO_CASA_Z - comprimento])
	jogo.campo_zoom = 0.0
	jogo._update_bridge(0.0)
	var fov_larga := float(jogo.ponte_camera.fov)
	jogo.campo_zoom = 1.0
	jogo._update_bridge(0.0)
	var fov_fechada := float(jogo.ponte_camera.fov)
	jogo.campo_zoom = 0.5
	jogo._update_bridge(0.0)
	var fov_meia := float(jogo.ponte_camera.fov)
	jogo.campo_zoom = 0.0
	var roda := InputEventMouseButton.new()
	roda.button_index = MOUSE_BUTTON_WHEEL_UP
	roda.pressed = true
	for i in range(20):
		jogo._input(roda)
	var aperto_topo := float(jogo.campo_zoom)
	roda.button_index = MOUSE_BUTTON_WHEEL_DOWN
	for i in range(40):
		jogo._input(roda)
	var aperto_fundo := float(jogo.campo_zoom)
	var clique := InputEventMouseButton.new()
	clique.button_index = MOUSE_BUTTON_LEFT
	clique.pressed = true
	jogo._input(clique)
	_assert("a roda leva a FOV da ponte de setenta e oito graus a quatorze",
		fov_larga > PONTE_FOV_LARGO - 0.01 and fov_fechada < PONTE_FOV_FECHADO + 0.01,
		"zoom 0 -> %.1f, zoom 1 -> %.1f, zoom 0,5 -> %.1f" % [fov_larga, fov_fechada, fov_meia])
	_assert("a roda aperta nas duas pontas e so a roda manda no zoom",
		is_equal_approx(aperto_topo, 1.0) and is_equal_approx(aperto_fundo, 0.0) \
			and is_equal_approx(float(jogo.campo_zoom), 0.0),
		"20 voltas para cima -> %.2f, 40 para baixo -> %.2f, o clique não mexe no zoom da ponte (%.2f)" % [
			aperto_topo, aperto_fundo, jogo.campo_zoom])
	_assert("o letreiro da massa e um Label: os 35 botoes de menu.gd nao se mexem",
		jogo.massa_label is Label and String(jogo.massa_label.text).contains("MASSA"),
		"%s" % jogo.massa_label.text)
	jogo._recomecar_batalha()
	_assert("o RECOMEAR remonta a massa do zero e devolve o zoom",
		int(jogo.esquadra.salva_numero) == 0 and is_equal_approx(float(jogo.campo_zoom), 0.0) \
			and jogo.esquadra.vivos("aliado") == BLOCOS_POR_LADO \
			and jogo.esquadra.vivos("hostil") == BLOCOS_POR_LADO,
		"salva %d, zoom %.2f, %d + %d blocos vivos" % [jogo.esquadra.salva_numero, jogo.campo_zoom,
			jogo.esquadra.vivos("aliado"), jogo.esquadra.vivos("hostil")])

	# ── 10. o campo de aproximacao e cruzado marchando ───────────────────────────────────────
	# A régua é de fachada, lida no centro do casco da última fileira dos dois lados, e o laço roda
	# SEM salvas: aqui se mede locomoção, não atrito. O recuo é alvo — quem anda é bloco.
	var t := _nova_esquadra()
	var fachada := _fachadas(t)
	var recuo_largada := float(t.recuo_hostil)
	var recuo_alvo := float(t._recuo_alvo())
	_assert("a largada abre campo de aproximacao entre as duas fachadas",
		absf(fachada - CAMPO_ESPERADO) < FOLGA_CONTATO \
			and absf(recuo_largada + float(Esquadra.CAMPO_DE_APROXIMACAO)) < 0.001,
		"fachada a fachada em %.1f u na largada, com a muralha hostil a %.0f u dos proprios nucleos" % [
			fachada, recuo_largada])
	# O laço agora PARA no contato: desde a fatia 2 o tempo de travessia não é mais 114 ÷ 0,1, porque
	# a rampa de 2,0 s come 6,0 u dos primeiros 120 quadros e o freio de chegada limita a marcha nos
	# últimos `teto²/(2a)` = 6,0 u. O que continua sendo régua é o passo de UM quadro, medido no
	# bloco, e o tempo que a travessia custa é medida impressa — como o relógio da família 11.
	var salto_max := 0.0
	var menor_fachada := fachada
	var passo_1 := 0.0
	var passo_60 := 0.0
	var passo_120 := 0.0
	var quadro_do_teto := -1
	var mf := 0
	while mf < QUADROS_DA_TRAVESSIA and menor_fachada > Esquadra.DISTANCIA_DE_CONTATO + FOLGA_CONTATO:
		var antes: Array = []
		for b in t.lista_de("hostil"):
			antes.append(b["pos"])
		t.passo(1.0 / 60.0, nuc_a, nuc_h)
		mf += 1
		var ki := 0
		for b in t.lista_de("hostil"):
			var passo := (b["pos"] as Vector3).distance_to(antes[ki] as Vector3)
			salto_max = maxf(salto_max, passo)
			# O bloco 0 é o da fileira: é dele que se lê a rampa, porque é o único que nunca teve
			# razão para mudar de curso no meio da travessia.
			if ki == 0:
				if mf == 1:
					passo_1 = passo
				elif mf == 60:
					passo_60 = passo
				elif mf == 120:
					passo_120 = passo
				if quadro_do_teto < 0 and passo >= SALTO_MAXIMO - FOLGA_PASSO:
					quadro_do_teto = mf
			ki += 1
		menor_fachada = minf(menor_fachada, _fachadas(t))
	_assert("a marcha nao salta: o maior deslocamento de um bloco em um quadro e o passo da marcha",
		salto_max <= SALTO_MAXIMO + FOLGA_PASSO,
		"%d quadros (%.1f s de tela) para cruzar as %.1f u: maior passo de um bloco em %.4f u, teto %.4f u" % [
			mf, float(mf) / 60.0, fachada - menor_fachada, salto_max, SALTO_MAXIMO])
	# A rampa é lei, não desenho: `vel` anda `a × delta` por quadro e a posição anda `vel × delta`,
	# então o quadro 1 vale `a × delta²`, o 60 meia marcha e o 120 a marcha inteira. Três pontos e o
	# instante em que a reta para de crescer: sem a lei, o quadro um já daria o passo do teto.
	_assert("o arranque da massa e linear e dura 2,0 s: a x delta² no quadro 1, meio teto no 60, teto no 120",
		absf(passo_1 - PASSO_DO_ARRANQUE) < FOLGA_PASSO \
			and absf(passo_60 - SALTO_MAXIMO * 0.5) < FOLGA_PASSO \
			and absf(passo_120 - SALTO_MAXIMO) < FOLGA_PASSO and quadro_do_teto == 120,
		"quadro 1 anda %.5f u (arranque %.5f), quadro 60 anda %.5f u (meio teto %.5f), quadro 120 anda %.5f u, teto em %d" % [
			passo_1, PASSO_DO_ARRANQUE, passo_60,
			SALTO_MAXIMO * 0.5, passo_120, quadro_do_teto])
	_assert("a travessia para no contato: nunca encosta, nunca atravessa",
			absf(_fachadas(t) - Esquadra.DISTANCIA_DE_CONTATO) < FOLGA_CONTATO \
				and menor_fachada >= Esquadra.DISTANCIA_DE_CONTATO - FOLGA_CONTATO,
		"fachada final %.1f u em %d quadros (minima vista %.1f u, contato %.0f u, alcance %.0f u)" % [
			_fachadas(t), mf, menor_fachada, Esquadra.DISTANCIA_DE_CONTATO,
			Esquadra.ALCANCE_DE_BLOCO])
	# A estacao segue a linha: a muralha hostil recua com a nossa se a nossa recuar, e para nos
	# proprios nucleos se a nossa avancar demais — `minf(0, ...)` é o teto dela.
	var nuc_atras: Array = []
	for n in nuc_a:
		nuc_atras.append((n as Vector3) + Vector3(0.0, 0.0, -30.0))
	t.passo(1.0 / 60.0, nuc_atras, nuc_h)
	var recuo_atras := float(t._recuo_alvo())
	var nuc_frente: Array = []
	for n in nuc_a:
		nuc_frente.append((n as Vector3) + Vector3(0.0, 0.0, 60.0))
	t.passo(1.0 / 60.0, nuc_frente, nuc_h)
	_assert("a muralha hostil segue a nossa linha, e nunca passa dos proprios nucleos",
		absf(recuo_atras - (recuo_alvo - 30.0)) < 0.01 and absf(float(t._recuo_alvo())) < 0.001,
		"linha nossa recuada 30 u -> recuo %.1f u; avancada 60 u -> recuo %.1f u (alvo de largada %.1f u)" % [
			recuo_atras, t._recuo_alvo(), recuo_alvo])

	# ── 11. cada bloco atira, e atira no bloco inimigo mais próximo ───────────────────────────
	# O pedido do comandante foi literal: «todas as naves atirando ao mesmo tempo, cada bloco é uma
	# frota que age independentemente; todas devem atirar no bloco inimigo mais próximo, a menos que
	# eu dê a ordem de mudar o alvo». Três pontas, cada uma capaz de falhar sozinha: o ENGAJAMENTO (o
	# alcance cobre a retaguarda da própria muralha no contato?), a ESCOLHA (o alvo é o bloco mais
	# próximo de QUEM ATIRA, não um ponto comum no centro) e a ORDEM (concentrar converge, soltar
	# volta a espalhar). A régua de escolha é conferida contra a distância mínima REAL, lida sem
	# portão de alcance: com o portão dentro da conta, um bloco fora de alcance sairia "correto" por
	# não atirar, e a asserção aprovaria a omissão em vez da escolha.
	var f := _nova_esquadra()
	var q_fogo := _marchar_ate_contato(f, nuc_a, nuc_h)
	var armados := _armados(f)
	var fogo := f.troca_salva()
	var lancados := int(fogo.get("lancados", 0))
	_assert("no contato a muralha inteira atira: todo bloco vivo e armado encontra alvo",
		lancados == armados,
		"%d lancados contra %d blocos armados, %d quadros de travessia, fachada %.1f u, alcance %.1f u" % [
			lancados, armados, q_fogo, _fachadas(f), Esquadra.ALCANCE_DE_BLOCO])
	var fila := f.pares_da_ultima_salva
	_assert("a fila entregue ao desenho tem o tamanho exato do ledger", fila.size() == lancados,
		"%d pares na fila contra %d lances cobrados" % [fila.size(), lancados])
	var fora := 0
	var pior_desvio := 0.0
	for par in fila:
		var origem: Dictionary = par["origem"]
		var atingido: Dictionary = par["alvo"]
		var do_lado := String(origem["lado"])
		var minimo := _distancia_do_mais_proximo(origem,
				f.lista_de("hostil" if do_lado == "aliado" else "aliado"))
		var alcance_lance := (atingido["pos"] as Vector3).distance_to(origem["pos"])
		pior_desvio = maxf(pior_desvio, alcance_lance - minimo)
		if alcance_lance - minimo > 0.0001:
			fora += 1
	_assert("cada bloco escolhe o inimigo mais proximo dele, nao um ponto comum",
		fora == 0 and lancados > 0,
		"%d lances fora do proprio minimo, maior desvio %.4f u, %d lances na salva" % [
			fora, pior_desvio, lancados])
	var locais := _alvos_distintos(fila, "aliado")
	_assert("o fogo local espalha: a salva aliada toca muitos blocos, nao um",
		int(locais["distintos"]) > 1,
		"%d lances aliados tocando %d alvos hostis distintos" % [
			int(locais["lancados"]), int(locais["distintos"])])
	# A ordem da ponte: um ponto do tabuleiro que NÃO é centro de bloco nenhum, três unidades a
	# boreste da fachada hostil. Se a escolha fosse lida do centro do tabuleiro, este comando não
	# moveria nada -- e é exatamente assim que a asserção de baixo desmente o fogo "ao centro".
	var fachada_h := _faixa_z(f, "hostil")
	var ponta := _bloco_mais_proximo_de(Vector3(PASSO_ESQUADRAO_X, ANDAR,
			float(fachada_h["max"])), f.lista_de("hostil"))
	var alvo_ordem := (ponta["pos"] as Vector3) + Vector3(3.0, 0.0, 0.0)
	f.mandar_fogo(alvo_ordem)
	var armados_agora := _armados(f)
	var concentrado := f.troca_salva()
	var fila_ordem := f.pares_da_ultima_salva
	var c_locais := _alvos_distintos(fila_ordem, "aliado")
	var c_hostil := _alvos_distintos(fila_ordem, "hostil")
	# O índice tem guarda: o texto de detalhe de `_assert` é avaliado mesmo quando a condição passa,
	# e um `[0]` sobre fila vazia derrubava a sonda antes do veredito — que é justamente o estado
	# dela enquanto a lei de escolha não existir.
	var visado := -1
	if not fila_ordem.is_empty():
		visado = int((fila_ordem[0]["alvo"] as Dictionary)["id"])
	_assert("concentrando fogo, todo bloco aliado em alcance aponta para o MESMO bloco",
		int(c_locais["distintos"]) == 1 and int(c_locais["lancados"]) > 1,
		"%d lances aliados, %d alvo; visado=%d esperado=%d no ponto (%.1f, %.1f, %.1f)" % [
			int(c_locais["lancados"]), int(c_locais["distintos"]), visado, int(ponta["id"]),
			alvo_ordem.x, alvo_ordem.y, alvo_ordem.z])
	_assert("a ordem e nossa, nao do inimigo: a muralha hostil continua atirando no proprio vizinho",
		int(c_hostil["distintos"]) > 1,
		"%d lances hostis tocando %d alvos aliados distintos" % [
			int(c_hostil["lancados"]), int(c_hostil["distintos"])])
	_assert("concentrar cobra preco: bloco fora de alcance do alvo unico nao atira",
		int(concentrado.get("lancados", 0)) < armados_agora,
		"%d lancados concentrados contra %d blocos armados (fogo local dava %d)" % [
			int(concentrado.get("lancados", 0)), armados_agora, lancados])
	f.soltar_fogo()
	var solto := f.troca_salva()
	var s_locais := _alvos_distintos(f.pares_da_ultima_salva, "aliado")
	_assert("soltando a ordem, o fogo volta a ser um alvo por bloco",
		int(s_locais["distintos"]) > 1,
		"%d lances aliados voltando a %d alvos distintos, salva numero %d" % [
			int(s_locais["lancados"]), int(s_locais["distintos"]), int(solto.get("salva", 0))])
	_assert("o alcance e lido da geometria das duas muralhas, nao de habito",
		is_equal_approx(Esquadra.ALCANCE_DE_BLOCO, 2.0 * Esquadra.FACHADA_DA_MURALHA \
				+ Esquadra.DISTANCIA_DE_CONTATO + Esquadra.PASSO_ESQUADRAO_Y),
		"alcance %.1f u = 2 x fachada %.1f + contato %.1f + andar %.1f" % [
			Esquadra.ALCANCE_DE_BLOCO, Esquadra.FACHADA_DA_MURALHA, Esquadra.DISTANCIA_DE_CONTATO,
			Esquadra.PASSO_ESQUADRAO_Y])

	# ── 12. o lance da massa tem canal de desenho ────────────────────────────────────────────
	# A lei aqui é o CANAL, não o pixel: sob `--headless` o `set_instance_transform` é descartado e a
	# leitura volta identidade, então acender o visor é pergunta de `massa_visivel.gd`. O que dá para
	# assinar de cabeça fria é que a fila armada espelha o ledger lance a lance, que ela varre a
	# largura da muralha (não o meio do campo), que a ordem da ponte converge também no desenho, que o
	# jitter não sorteia e que o pulso apaga a fila no impacto.
	var q_ponte := _marchar_na_ponte(jogo)
	var tr_no: MultiMeshInstance3D = jogo.massa_tracos
	var tr_mm: MultiMesh = tr_no.multimesh
	var mat_tr: StandardMaterial3D = tr_no.material_override
	_assert("a salva da massa e um no com uma instancia por bloco, luminoso por material",
		is_instance_valid(tr_no) and tr_mm.instance_count == TRACOS_MAXIMOS \
				and tr_mm.transform_format == MultiMesh.TRANSFORM_3D and tr_mm.use_colors \
				and mat_tr.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
				and mat_tr.vertex_color_use_as_albedo,
		"%d instancias para %d blocos, unshaded + cor por instancia, travessia de %d quadros" % [
			tr_mm.instance_count, 2 * BLOCOS_POR_LADO, q_ponte])
	var caixas := 0
	for filho in jogo.get_children():
		if filho is MultiMeshInstance3D:
			caixas += 1
	_assert("o preco de duzentos e quarenta lances visiveis e UM no a mais na cena", caixas == 4,
		"%d MultiMeshInstance3D na cena (ceu + dois corpos da massa + tracos)" % caixas)
	jogo.esquadra.soltar_fogo()
	jogo._salva_da_massa()
	var fila_mm: Array[Dictionary] = jogo._tracos_voando
	var ledger_mm := int(jogo.esquadra.pares_da_ultima_salva.size())
	_assert("todo lance cobrado tem um traco e todo traco tem um lance",
		fila_mm.size() == ledger_mm and fila_mm.size() > 0,
		"%d tracos armados contra %d pares do ledger na salva %d" % [
			fila_mm.size(), ledger_mm, int(jogo.esquadra.salva_numero)])
	var destinos := _faixa_x_dos_pontos(fila_mm, "para")
	_assert("o fogo desenhado varre a largura da muralha hostil, nao o meio do campo",
			float(destinos["max"]) - float(destinos["min"]) > 150.0,
			"destinos entre x %.1f e %.1f u, %.1f u de largura coberta" % [
				destinos["min"], destinos["max"], float(destinos["max"]) - float(destinos["min"])])
	var boca_estavel := _selo_da_fila(fila_mm)
	jogo._armar_tracos()
	_assert("o jitter de boca nao sorteia: rearmar a mesma fila devolve os mesmos pontos",
		boca_estavel == _selo_da_fila(jogo._tracos_voando),
		"%d tracos rearmados com selo identico de %d caracteres" % [
			jogo._tracos_voando.size(), boca_estavel.length()])
	var fachada_j := _faixa_z(jogo.esquadra, "hostil")
	var visado_j := _bloco_mais_proximo_de(Vector3(PASSO_ESQUADRAO_X, ANDAR,
			float(fachada_j["max"])), jogo.esquadra.lista_de("hostil"))
	jogo.esquadra.mandar_fogo((visado_j["pos"] as Vector3) + Vector3(3.0, 0.0, 0.0))
	jogo._salva_da_massa()
	_assert("concentrando pela ponte, o desenho converge: um destino so para a muralha aliada",
		_pontos_distintos(jogo._tracos_voando, true) == 1 \
				and int(jogo._tracos_voando.size()) > 1,
		"%d tracos aliados, %d destino; o hostil segue com %d" % [
			int(jogo._tracos_voando.size()), _pontos_distintos(jogo._tracos_voando, true),
			_pontos_distintos(jogo._tracos_voando, false)])
	jogo.esquadra.soltar_fogo()
	jogo._salva_da_massa()
	_assert("soltando a ordem, o desenho volta a ter um rumo por bloco",
		_pontos_distintos(jogo._tracos_voando, true) > 1,
		"%d tracos aliados espalhados em %d destinos" % [
			int(jogo._tracos_voando.size()), _pontos_distintos(jogo._tracos_voando, true)])
	jogo._atualizar_tracos(TRACO_SEG + 0.1)
	_assert("o traco morre no impacto: sem salva nova nao ha lance novo no quadro",
		jogo._tracos_voando.is_empty() and float(jogo._traco_t) >= 1.0,
		"fila zerada apos %.2f s de voo, progresso %.2f" % [TRACO_SEG, float(jogo._traco_t)])
	jogo._atualizar_tracos(1.0)
	_assert("quadro escuro nao rearma sozinho: o pulso nao vira chuva continua",
		jogo._tracos_voando.is_empty() and float(jogo._traco_t) >= 1.0,
		"um segundo depois, %d tracos na fila" % jogo._tracos_voando.size())

	print("SONDA-ESQUADRA: veredito - quebras=%d - conferencias=%d" % [breaks, notes.size()])
	for nota in notes:
		print(nota)
	quit(1 if breaks > 0 else 0)
