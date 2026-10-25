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
##    (medido: 4) em diante os duzentos e quarenta pagam todo quadro, sem buraco no meio do
##    caminho. Medido: 23 160 + 23 160 escritas contra 24 000 de teto por lado. O relógio é impresso
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
##    pontas FORA da moldura do painel, a mesma roda não mudando nada sobre ela sem modificador, e
##    SHIFT/CTRL trazendo o olho de volta de qualquer lugar. Os três casos são a lei da porta (ver
##    `_roda_e_do_olho` em `main.gd`), e o letreiro da massa sendo `Label` — os 35 botões de
##    `menu.gd` não se mexem.
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
## 11) A CONTA DO TIRO FECHA COM O CORREDOR. No contato, o ledger é lido como `lancados +
##     obstruidos == armados`: dos duzentos e quarenta blocos vivos e armados dos dois lados, sessenta
##     cobram fogo e cento e oitenta ficam com a boca tapada pelo próprio aliado da frente — a muralha
##     tem quatro blocos amarrados em `z` e só o mais adiantado tem vante limpo. A asserção antiga
##     («todo bloco atira, ninguém segura fogo porque o fundo da muralha ficou fora de alcance») media
##     a lei de antes e é impressa aqui como contrafactual, não como régua. O alcance continua lido da
##     geometria (2 × fachada + contato + andar = 73 u), não de hábito, e a escolha de alvo é conferida
##     par a par contra a distância mínima REAL. O fogo local espalha (muitos alvos), a ordem da ponte
##     converge (um alvo só, o bloco mais próximo do ponto comandado, e quem não alcança não atira), e
##     a muralha hostil continua local porque a ordem é nossa. A fila `pares_da_ultima_salva` tem de
##     ter o tamanho exato do ledger: é ela que o desenho lê, e fila diferente de conta é tela mostrando
##     fogo que a conta não cobrou.
## 12) O LANCE DA MASSA TEM CANAL DE DESENHO, UM POR CASCO PINTADO. A queixa do comandante era de
##     tela, não de conta: com um traço por bloco, vinte e quatro naves cobravam fogo e a tela mostrava
##     um cano só por paralelepípedo. Desde aqui o cano É o casco desenhado — um lance por casa viva,
##     com atraso `casa × PASSO_DA_ONDA`, a leva inteira fechando dentro de uma cadência. A fila armada
##     tem de ser o espelho do ledger casa a casa (desenho mostrando fogo que a conta não cobrou é a
##     falha espelhada), o convergir da ordem converge o BLOCO visado e não um ponto único, nada pode
##     sorteiar, e o custo tem de continuar sendo UM nó reescrito por quadro — cinco mil setecentos e
##     sessenta escritas por quadro, não cinco mil setecentos e sessenta nós. O pulso apaga a fila no
##     impacto: traço pendurado é "todo mundo atirando o tempo todo". O que ela NÃO prova é pixel: sob
##     `--headless` o `set_instance_transform` é descartado e a leitura volta identidade, então o
##     acender do visor mora em `massa_visivel.gd`.
## 13) A MURALHA RESPIRA. O pedido era de nave andando durante a batalha, e a lei assinada é de
##     custódia de posto, não de vaga: cada bloco orbita o PRÓPRIO lugar na grade, em boreste e em
##     altura, com a fase do esquadrão — os vinte blocos de um esquadrão se movem como um corpo, então
##     a distância de formação e o ar da família 2 continuam os mesmos números de antes. Em `z` a
##     deriva não entra de propósito: é o eixo do contato, e a fachada que as famílias 2 e 10 assinam é
##     medida centro a centro. Quem recebe destino da ponte para no ponto e não balançar em volta dele.
## 14) O CORREDOR É GEOMETRIA, DADO NENHUM. A família 14 martela as três cláusulas da fatia 4:
##     obstrução no lado de quem atira (a caixa aliada MAIS ADIANTE que a entrada na caixa do visado
##     engole o lance — 180 das 240 bocas), absorção no lado de quem recebe (paga a PRIMEIRA caixa do
##     corredor, não a que a proximidade apontou: na salva comandada o visado é o bloco 120 e quem paga
##     é o 125, 6 `rebatidos`), e a laje contra laje sem sorteio — duas montadas gemeas fecham os
##     mesmos 60/180/0 na mesma ordem de pares. O `y` é arma de leitura: com a caixa rasa nos dois
##     eixos horizontais, o mesmo lance parava no bloco 195; com a caixa de três andares, para no 125,
##     que é quem o ledger cobrou. O custo é impresso: 240 leituras de caixa e 5 760 leituras de casa
##     por salva, nenhum dado chamado, e a cauda de `rng`/`visual_rng` atravessa as sessenta salvas
##     igual à semente cravada. O que a família NÃO prova é pixel — o corredor aceso no visor mora em
##     `massa_visivel.gd`.
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
## Espelhos de `main.gd` para a família 12: um traço por CASA desenhada nos dois lados, o passo da
## onda dentro do bloco e o pulso que fecha a fila. Mudar o número lá sem mudar aqui quebra a
## asserção de propósito.
const TRACOS_MAXIMOS := 5760
const TRACO_SEG := 0.55
const PASSO_ONDA := 0.012
const TRACO_PULSO := 0.012 * 23.0 + 0.55
## Espelhos da deriva de custódia (família 13). A folga não é afrouxamento: é o atraso com que o
## bloco persegue um posto que anda a ~0,4 u/s, medido e impresso na asserção.
const FOLGA_DERIVA := 0.35
## A folga com que `Esquadra.pintar` decide regravar um bloco: `esquadra.gd:925` compara a posição com
## a última pintada e só escreve quem passou de 0,01 u (é o `0.0001` do quadrado da distância). É a
## régua que separa a muralha que anda da muralha que respira: uma anda 0,05 u por quadro e paga todo
## quadro, outra anda 0,007 u e paga a cada dois.
const FOLGA_DE_PINTURA := 0.01
## Um ciclo inteiro da deriva (9,0 s a 60 quadros por segundo): é o tempo que a família 13 dá à
## muralha para percorrer a órbita antes de cobrar o teto, o piso e o eixo que não balança.
const QUADROS_DO_CICLO_DA_DERIVA := 540
## Aquecimento do leme para a família 13b: no contato os blocos ainda chegam com a proa do último
## resíduo de marcha, e girar 90° no timão do bloco custa `(PI/2) / giro_maximo` segundos = 188
## quadros. Cobrar antes disso seria medir o transitório, não a lei; 300 é o dobro do necessário.
const AQUECIMENTO_DA_PROA := 300
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
	# Precondition da fatia 3, declarada sem afrouxar nenhum número: esta sonda mede a aritmética
	# do canhão, e com a casca de pé todo lance abaixo de 20,0 morde nela em vez de chegar a `hp`.
	# Despido o tabuleiro, cada número daqui volta a ser o de antes, dígito a dígito — a muralha em
	# si é cobrada por `tools/probes/escudo.gd`, com a casca armada.
	for casca_lista in [game.fleet, game.enemies]:
		for casca_unidade in casca_lista:
			casca_unidade["escudo"] = 0.0
			casca_unidade["escudo_max"] = 0.0
			casca_unidade["escudo_cai"] = 0.0
	# Precondition da fatia 3, mesma razão dos cascos: a placa de 4,4 do bloco morde a salva de
	# casco antes de `navios`, então esta sonda despide a muralha na montagem. A placa é cobrada na
	# família 12 de `tools/probes/escudo.gd`.
	for casca_lado in ["aliado", "hostil"]:
		for casca_bloco in game.esquadra.lista_de(casca_lado):
			casca_bloco["escudo"] = 0.0
			casca_bloco["escudo_max"] = 0.0
			casca_bloco["escudo_cai"] = 0.0
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

## Precondition da fatia 3, mesma razão dos cascos: a placa de 4,4 morde o lance de casco antes de
## `navios`, então todo esquadrão desta sonda acorda despido e cada número volta a ser o de antes,
## dígito a dígito. A placa em si é cobrada na família 12 de `tools/probes/escudo.gd`.
func _nova_esquadra() -> Esquadra:
	var e := Esquadra.new()
	e.montar(_nucleos(true), _nucleos(false))
	for lado in ["aliado", "hostil"]:
		for bloco in e.lista_de(lado):
			bloco["escudo"] = 0.0
			bloco["escudo_max"] = 0.0
			bloco["escudo_cai"] = 0.0
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


## Casas vivas dos blocos que cobraram: é o esperado da fila de desenho desde que o cano passou a
## ser o CASCO — um lance por casa do bloco que atirou, não um lance por bloco.
static func _casas_esperadas(fila_pares: Array[Dictionary]) -> int:
	var n := 0
	for par in fila_pares:
		n += Esquadra.casas_vivas(par["origem"])
	return n


## Quantos lances estão no ar no instante `t` do pulso: o cano só dispara depois do próprio atraso,
## e morre um voo depois. É a régua da ONDA — sem ela, vinte e quatro lances simultâneos por bloco e
## vinte e quatro em fila reads iguais no papel.
static func _lances_no_ar(fila: Array[Dictionary], t: float) -> int:
	var n := 0
	for tr in fila:
		var atraso := float(tr["atraso"])
		if t > atraso and t < atraso + TRACO_SEG:
			n += 1
	return n


## Bocas distintas de um mesmo bloco origem. Um é o desenho antigo (o centro do paralelepípedo);
## vinte e quatro é a fileira, cada tiro saindo do casco em que o olho vê a nave.
static func _bocas_distintas(fila: Array[Dictionary], bloco: int) -> int:
	var vistos: Dictionary = {}
	for tr in fila:
		if int(tr["bloco"]) == bloco:
			vistos[str(tr["de"])] = true
	return vistos.size()


## Quantos BLOCOS hostis a fila de um lado toca. Com a mira por casco, "um destino só" deixou de ser
## a leitura da ordem concentrada: o que converge é o alvo-bloco, e dentro dele os vinte e quatro
## tiros se repartem nos cascos do bloco visado.
static func _blocos_alvo_distintos(fila: Array[Dictionary], aliado: bool) -> int:
	var vistos: Dictionary = {}
	for tr in fila:
		if bool(tr["aliado"]) == aliado:
			vistos[int(tr["alvo_bloco"])] = true
	return vistos.size()


## Posições pintadas das casas de um bloco, na ordem do desenho. É a régua que prova que a boca do
## cano É o casco: a fila do lance tem de dar exatamente estes pontos, e nenhum outro.
static func _casas_no_mundo(bloco: Dictionary) -> PackedStringArray:
	var rot := Basis.from_euler(Vector3(0.0, float(bloco["rumo"]), 0.0))
	var base: Vector3 = bloco["pos"]
	var partes: PackedStringArray = []
	for c in range(Esquadra.casas_vivas(bloco)):
		partes.append(str(base + (rot * Esquadra.casa_local(c))))
	partes.sort()
	return partes


static func _bocas_de_um_bloco(fila: Array[Dictionary], bloco: int) -> PackedStringArray:
	var partes: PackedStringArray = []
	for tr in fila:
		if int(tr["bloco"]) == bloco:
			partes.append(str(tr["de"]))
	partes.sort()
	return partes


## Quantos lances da fila têm atraso diferente da própria casa. É a onda lida no desenho: se o atraso
## viesse de outra fonte — um sorteio, a posição na fila, o número do bloco — vinte e quatro tiros por
## bloco sairiam juntos e a queixa do comandante continuaria de pé mesmo com a conta certa.
static func _casas_fora_da_onda(fila: Array[Dictionary], espelho: Array[Dictionary]) -> int:
	var comuns := mini(fila.size(), espelho.size())
	var fora := 0
	for i in range(comuns):
		if not is_equal_approx(float(fila[i]["atraso"]), \
				float(int(espelho[i]["casa"])) * PASSO_ONDA):
			fora += 1
	return fora + absi(fila.size() - espelho.size())


## Deriva esperada de um esquadrão no instante lido: os mesmos quatro números que `passo()` usa,
## refeitos aqui a partir das constantes publicadas — boreste com a fase do ANDAR, altura com a fase
## do ESQUADRÃO, nada em z. Espelho, não API nova: a sonda confere a lei, não a chama. `t` aberto é
## para a família 13b medir o passo que o próprio posto dá num quadro; sem ele, o espelho lê o
## relógio vivo do módulo, que é o uso de sempre.
static func _deriva_esperada(e: Esquadra, esq: int, t := NAN) -> Vector3:
	var rel := float(e.tempo) if is_nan(t) else t
	var base := rel * TAU / Esquadra.DERIVA_CICLO
	var andar := int(float(esq) / float(Esquadra.COLUNAS_NO_LADO))
	var fase_x := base + float(andar) * TAU / float(Esquadra.CAMADAS_NO_LADO)
	var fase_y := base + float(esq) * TAU / float(Esquadra.ESQUADROES_NO_LADO)
	return Vector3(cos(fase_x) * Esquadra.DERIVA_X, sin(fase_y * 0.5) * Esquadra.DERIVA_Y, 0.0)


## A muralha que respira, por eixo. Para cada bloco de linha vivo e sem ordem da ponte: o maior desvio
## contra o posto EXATO da grade (antes era zero — este é o número novo) e o maior erro contra o posto
## JÁ derivado (perseguição: tem de continuar pequeno).
static func _respiro(e: Esquadra, lado: String) -> Dictionary:
	var max_x := 0.0
	var max_y := 0.0
	var max_z := 0.0
	var perseg := 0.0
	var perseg_x := 0.0
	var perseg_y := 0.0
	var perseg_z := 0.0
	var vivos := 0
	for b in e.lista_de(lado):
		if not bool(b["vivo"]) or bool(b["com_destino"]):
			continue
		vivos += 1
		var esq := int(b["esquadrao"])
		var posto := Esquadra.posto_no_lado(esq, int(b["formacao"]), e.estacao(lado))
		var pos: Vector3 = b["pos"]
		var desvio := pos - posto
		max_x = maxf(max_x, absf(desvio.x))
		max_y = maxf(max_y, absf(desvio.y))
		max_z = maxf(max_z, absf(desvio.z))
		var alvo := posto + _deriva_esperada(e, esq)
		perseg = maxf(perseg, pos.distance_to(alvo))
		perseg_x = maxf(perseg_x, absf(pos.x - alvo.x))
		perseg_y = maxf(perseg_y, absf(pos.y - alvo.y))
		perseg_z = maxf(perseg_z, absf(pos.z - alvo.z))
	return {"vivos": vivos, "max_x": max_x, "max_y": max_y, "max_z": max_z,
		"perseg": perseg, "perseg_x": perseg_x, "perseg_y": perseg_y, "perseg_z": perseg_z}


## Respirar é o que se mede aqui, e formar é o que se preserva: duas asserções numa passada só.
## `ar_min` é o vão entre caixas do par mais junto do tabuleiro (a régua da família 2, que a deriva
## não pode baixar); `pior_x` é o maior erro de distância EM BORESTE entre dois blocos do MESMO andar,
## que tem de ficar zero porque o boreste é fase de andar — é exatamente a razão de a deriva ser
## dividida por eixo. `fileira` é a quantidade de pares que entraram nessa régua.
static func _ar_da_respiracao(e: Esquadra) -> Dictionary:
	var ar_min := INF
	var pior_x := 0.0
	var sobrepostos := 0
	var fileira := 0
	for lado in ["aliado", "hostil"]:
		var lista := e.lista_de(lado)
		for i in range(lista.size()):
			if not bool(lista[i]["vivo"]) or bool(lista[i]["com_destino"]):
				continue
			for j in range(i + 1, lista.size()):
				if not bool(lista[j]["vivo"]) or bool(lista[j]["com_destino"]):
					continue
				var pa: Vector3 = lista[i]["pos"]
				var pb: Vector3 = lista[j]["pos"]
				var ar := _ar_entre(pa, pb)
				if ar < 0.0:
					sobrepostos += 1
				ar_min = minf(ar_min, ar)
				var esq_a := int(lista[i]["esquadrao"])
				var esq_b := int(lista[j]["esquadrao"])
				if esq_a / Esquadra.COLUNAS_NO_LADO == esq_b / Esquadra.COLUNAS_NO_LADO:
					var oa := Esquadra.posto_no_lado(esq_a, int(lista[i]["formacao"]), e.estacao(lado))
					var ob := Esquadra.posto_no_lado(esq_b, int(lista[j]["formacao"]), e.estacao(lado))
					if absf(ob.x - oa.x) <= PASSO_X + FOLGA:
						fileira += 1
						pior_x = maxf(pior_x, absf(absf(pa.x - pb.x) - absf(ob.x - oa.x)))
	return {"ar_min": ar_min, "pior_x": pior_x, "sobrepostos": sobrepostos, "fileira": fileira}


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

	# ---- Regua da familia 14: o corredor da fatia 4, conferido por conta propria ----

## O teste de laje escrito pela sonda, sobre caixas lidas de `caixa_do_bloco`. Nao e copia com
## outro nome: e a ponta que pega indice de lista trocado, `exceto` esquecido e INF lido como
## zero -- tres erros que dariam o MESMO total de lances com pares diferentes.
static func _laje(intervalo: Array, o: float, d: float, lo: float, largura: float) -> Array:
	var t0: float = intervalo[0]
	var t1: float = intervalo[1]
	var hi := lo + largura
	if absf(d) <= 1e-9:
		if o < lo or o > hi:
			return [1.0, 0.0]
		return intervalo
	var entra := (lo - o) / d
	var sai := (hi - o) / d
	if entra > sai:
		var guarda := entra
		entra = sai
		sai = guarda
	return [maxf(t0, entra), minf(t1, sai)]


static func _t_entrada(origem: Vector3, trecho: Vector3, caixa: AABB) -> float:
	if caixa.size.x < 0.0 or caixa.size.y < 0.0 or caixa.size.z < 0.0:
		return INF
	var fundo := caixa.position
	var t: Array = [0.0, 1.0]
	t = _laje(t, origem.x, trecho.x, fundo.x, caixa.size.x)
	t = _laje(t, origem.y, trecho.y, fundo.y, caixa.size.y)
	t = _laje(t, origem.z, trecho.z, fundo.z, caixa.size.z)
	if float(t[0]) > float(t[1]):
		return INF
	return float(t[0])


## A escolha da sonda, sem o codigo da esquadra: o bloco vivo mais proximo que caiba no alcance,
## empate decidido por indice de lista (o `<` estrito). Devolve o bloco e o indice dele.
static func _alvo_da_sonda(bloco: Dictionary, alvos: Array[Dictionary]) -> Dictionary:
	var melhor: Dictionary = {}
	var indice := -1
	var melhor_d := INF
	for i in range(alvos.size()):
		var c: Dictionary = alvos[i]
		if not bool(c["vivo"]):
			continue
		var d: float = (c["pos"] as Vector3).distance_to(bloco["pos"])
		if d < melhor_d and d <= Esquadra.ALCANCE_DE_BLOCO:
			melhor_d = d
			melhor = c
			indice = i
	return {"alvo": melhor, "i": indice}


## Caixa esticada ate cobrir os dois andares: e a conta de DOIS EIXOS (boreste e profundidade),
## a que o paragrafo 5 do programa derruba. Com ela o ar vertical de 8,53 u entre andares deixa
## de existir, e qualquer lance que mude de andar e parado pela fileira da frente.
static func _caixa_rasa(caixa: AABB) -> AABB:
	return AABB(Vector3(caixa.position.x, -40.0, caixa.position.z),
		Vector3(caixa.size.x, 80.0, caixa.size.z))


static func _primeira_caixa(origem: Vector3, trecho: Vector3, caixas: Array,
		exceto: int) -> Dictionary:
	var melhor := -1
	var melhor_t := INF
	for i in range(caixas.size()):
		if i == exceto:
			continue
		var t := _t_entrada(origem, trecho, caixas[i])
		if t < melhor_t:
			melhor_t = t
			melhor = i
	return {"i": melhor, "t": melhor_t}


## A conta da sonda, bloco a bloco, sobre o retrato que a salva vai ler: refaz a escolha, refaz
## o corte nas duas margens e devolve o elenco que dispara, o pagador de cada lance e os tres
## contadores que o ledger tambem devolve.
static func _conta_do_corredor(e: Esquadra) -> Dictionary:
	var caixas := {"aliado": e._caixas_de("aliado"), "hostil": e._caixas_de("hostil")}
	var dispara: Array[int] = []
	var paga: Dictionary = {}
	var tapados := 0
	var rebatidos := 0
	for lado in ["aliado", "hostil"]:
		var outro := "hostil" if lado == "aliado" else "aliado"
		var lista: Array[Dictionary] = e.lista_de(lado)
		var alvos: Array[Dictionary] = e.lista_de(outro)
		for i in range(lista.size()):
			var b: Dictionary = lista[i]
			if not bool(b["vivo"]) or float(b["ARMAS"]) <= 0.0 or float(b["navios"]) <= 0.0:
				continue
			var escolhido := _alvo_da_sonda(b, alvos)
			var alvo: Dictionary = escolhido["alvo"]
			if alvo.is_empty():
				continue
			var origem: Vector3 = b["pos"]
			var trecho: Vector3 = (alvo["pos"] as Vector3) - origem
			var t_alvo := _t_entrada(origem, trecho, (caixas[outro] as Array)[int(escolhido["i"])])
			if t_alvo == INF:
				t_alvo = 1.0
			var na_frente := _primeira_caixa(origem, trecho, caixas[lado], i)
			var bate := _primeira_caixa(origem, trecho, caixas[outro], -1)
			var limpo: bool = (int(na_frente["i"]) == -1 or float(na_frente["t"]) >= t_alvo) \
					and int(bate["i"]) != -1 and float(bate["t"]) <= 1.0
			if not limpo:
				tapados += 1
				continue
			dispara.append(int(b["id"]))
			paga[int(b["id"])] = int((alvos[int(bate["i"])] as Dictionary)["id"])
			if int(bate["i"]) != int(escolhido["i"]):
				rebatidos += 1
	return {"dispara": dispara, "paga": paga, "lancados": dispara.size(),
		"tapados": tapados, "rebatidos": rebatidos}


## Coluna de boreste-andar: blocos a menos de 3,0 u um do outro em boreste e em altura. As
## colunas tem 13,0 u de passo, os andares 12,0 u, e a deriva de custodia desloca no maximo
## 0,6/0,45 u -- a tolerancia e um quarto do menor passo. Lida da POSICAO, nao do indice de
## formacao: se a grade mentir para a coluna, e a familia 14 que pega.
static func _colunas_de(lista: Array[Dictionary]) -> Array:
	var grupos: Array = []
	for b in lista:
		if not bool(b["vivo"]) or float(b["ARMAS"]) <= 0.0 or float(b["navios"]) <= 0.0:
			continue
		var p: Vector3 = b["pos"]
		var grupo: Dictionary = {}
		for g in grupos:
			var gp: Vector3 = g["pos"]
			if absf(gp.x - p.x) < 3.0 and absf(gp.y - p.y) < 3.0:
				grupo = g
				break
		if grupo.is_empty():
			grupo = {"pos": p, "membros": []}
			grupos.append(grupo)
		(grupo["membros"] as Array).append(b)
	return grupos


## Quem tem vante limpo na coluna: o aliado olha para -z (menor z na frente), o hostil para +z.
static func _mais_frente(a: Dictionary, b: Dictionary, aliada: bool) -> bool:
	var za: float = (a["pos"] as Vector3).z
	var zb: float = (b["pos"] as Vector3).z
	if aliada:
		return za < zb
	return za > zb


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
	var parcos_na_rampa := 0
	## Fim da rampa de arranque: `MARCHA_DE_BLOCO / aceleracao` em quadros. Antes dela o curso do
	## bloco é menor que a folga de pintura, e um quadro barato é a cláusula do módulo funcionando.
	var rampa_de_arranque := int(Esquadra.MARCHA_DE_BLOCO / float(Voo.FICHA_BLOCO["aceleracao"])
		* 60.0)
	var pos_anteriores := {}
	var parcos_lidos := ""
	var passo_max := 0.0
	var passo_max_h := 0.0
	var desvio_pintura := 0.0
	var curso_hostil := 0.0
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
		# Fim da rampa de arranque: o primeiro quadro em que a MARCHA paga os cento e vinte blocos que
		# ela empurra. A estação hostil desta janela é fixa, então quem ali só respira anda menos de
		# 0,01 u por quadro e regrava a cada dois quadros — cobrar o pleno dos dois lados era cobrar
		# uma frota que teleporta. O atraso de tela dessa muralha tem régua própria, logo abaixo.
		if tocou_a == BLOCOS_POR_LADO:
			if quadro_pleno < 0:
				quadro_pleno = w + 1
		elif quadro_pleno > 0:
			# Precondition da fatia 3.5, declarada aqui e nao afrouxada na folga: guardada a proa da
			# linha, o unico motivo que sobra para um quadro de arranque ser barato e o passo da
			# respira passar abaixo da folga de pintura — a clausula do modulo pulando a escrita. Isso
			# e a rampa funcionando, nao buraco no meio da marcha, entao o portao continua `paros == 0`
			# mas cobrado de onde a rampa termina. Os parcos da rampa vao contados e impressos com o
			# menor andar de cada um, para a diferenca ficar lida na janela e nao coberta por numero.
			if w + 1 > rampa_de_arranque:
				paros_depois += 1
			else:
				parcos_na_rampa += 1
			# Instrumento, nao tolerancia: os menores andares do quadro entre os blocos que a pintura
			# nao regravou. Separar 'a marcha parou' de 'a respira passa pelo ponto morto' so com o
			# numero que a folga de 0,01 u viu.
			if paros_depois + parcos_na_rampa <= 6:
				var menores: Array = []
				for ld2 in ["aliado", "hostil"]:
					for bk2 in p.lista_de(ld2):
						var ch2 := "%s#%d" % [String(ld2), int(bk2["id"])]
						var av2: Vector3 = pos_anteriores.get(ch2, Vector3.INF)
						if av2 == Vector3.INF:
							continue
						menores.append([av2.distance_to(bk2["pos"] as Vector3), ch2])
				menores.sort_custom(func(x2, y2): return float(x2[0]) < float(y2[0]))
				var cp2 := ""
				for mt2 in menores.slice(0, 5):
					cp2 += "%s %.5f u, " % [String(mt2[1]), float(mt2[0])]
				parcos_lidos += " | q%d a%d h%d: %s" % [w, tocou_a, tocou_h, cp2]
		for ld3 in ["aliado", "hostil"]:
			for bk3 in p.lista_de(ld3):
				var ch3 := "%s#%d" % [String(ld3), int(bk3["id"])]
				var pos3: Vector3 = bk3["pos"]
				var av3: Vector3 = pos_anteriores.get(ch3, pos3)
				var anda3 := av3.distance_to(pos3)
				passo_max = maxf(passo_max, anda3)
				if String(ld3) == "hostil":
					curso_hostil += anda3
					passo_max_h = maxf(passo_max_h, anda3)
				pos_anteriores[ch3] = pos3
				var pp3: Vector3 = (bk3["pintas"] as Dictionary)["pos"]
				desvio_pintura = maxf(desvio_pintura, pos3.distance_to(pp3))
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
	# escrever mais que um por bloco por quadro, e a partir do primeiro quadro pleno a MARCHA paga os
	# cento e vinte blocos da muralha que anda em todo quadro, sem buraco no meio do caminho. A
	# muralha hostil desta janela não anda — ela respira, a estação dela é fixa — e por isso não paga
	# o pleno: o que se cobra dela é a régua de atraso de tela e o teto de custo do caminho, logo
	# abaixo. Cobrar o pleno dos dois lados era cobrar uma frota que teleporta o traço.
	_assert("nenhum lado escreve mais que um por bloco em um quadro",
		escritas_aliado <= QUADROS * BLOCOS_POR_LADO \
			and escritas_hostil <= QUADROS * BLOCOS_POR_LADO,
			"%d + %d escritas contra %d de teto por lado" % [escritas_aliado, escritas_hostil,
				QUADROS * BLOCOS_POR_LADO])
	_assert("terminada a rampa, a marcha repinte os cento e vinte blocos da muralha que anda",
		quadro_pleno > 0 and quadro_pleno <= rampa_de_arranque and paros_depois == 0,
			("primeiro quadro pleno %d (rampa de %d quadros), %d parcos dentro da rampa e %d depois; " % [
				quadro_pleno, rampa_de_arranque, parcos_na_rampa, paros_depois])
				+ ("%d escritas no total; " % escritas) + parcos_lidos)
	# A régua que fica quando o pleno sai de cena: a TELA não pode atrasar da POSIÇÃO VERDADEIRA, e a
	# folha é a própria cláusula do módulo — `esquadra.gd:925` pula a escrita só quando o bloco já está a
	# menos de um centésimo do traço pintado. Um bloco que respira anda 0,007 u no quadro de ponta e
	# regrava a cada dois quadros; em nenhum instante o traço se afasta do mundo mais que a folga, e é
	# isso — não folga mais um passo — que a janela precisa provar.
	_assert("a pintura nunca fica mais que uma folga atras da muralha: a clausula do modulo em acao",
		desvio_pintura <= FOLGA_DE_PINTURA + FOLGA_PASSO,
			"maior atraso de tela %.5f u contra a folga de pintura %.2f u (margem %.5f); passo de um quadro: " % [
				desvio_pintura, FOLGA_DE_PINTURA, FOLGA_PASSO] \
				+ "aliado %.5f u, hostil %.5f u; hostil pagou %d escritas em %d quadros" % [
					passo_max, passo_max_h, escritas_hostil, QUADROS])
	# E o custo, agora com a origem: entre duas escritas de um bloco o caminho andado tem de passar da
	# folga, senao a segunda escrita nao teria motivo. Da soma dos caminhos sai o teto do lote parado.
	_assert("a muralha que so respira paga no maximo o caminho pela folga de pintura",
		escritas_hostil <= int(curso_hostil / FOLGA_DE_PINTURA) + BLOCOS_POR_LADO,
			"%d escritas hostis contra %.1f u andados / %.2f de folga + %d do primeiro quadro" % [
				escritas_hostil, curso_hostil, FOLGA_DE_PINTURA, BLOCOS_POR_LADO])
	_assert("%.3f ms por quadro de massa - medida impressa, nao portada" % (custo_ms / float(QUADROS)),
		true, "%d ms nos %d quadros, %d casas/ms; %d escritas de bloco contra %d de teto" % [
			int(custo_ms), QUADROS, int(casas_ms), escritas, QUADROS * 2 * BLOCOS_POR_LADO])

	# ── 9. a ponte mostra a massa, e a roda tem duas portas ────────────────────────────────────
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
	# A posição da roda é lida da moldura do painel, não chutada: a lei nova é de geografia, e uma
	# sonda que injeta o gesto no canto (0,0) por defeito passa por acaso — o defeito dela é exatamente
	# o lugar onde o painel não estava. CENTRO e FOLGA saem do retângulo real do nó.
	var caixa_painel: Rect2 = jogo.painel.get_global_rect()
	var dentro_do_painel := caixa_painel.position + caixa_painel.size * 0.5
	var fora_do_painel := Vector2(caixa_painel.end.x + 180.0, caixa_painel.position.y + 30.0)
	roda.global_position = fora_do_painel
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
	# ── a porta do painel, pedida pelo comandante em carne viva ────────────────────────────────
	# Rodar a lista e ver a ponte fechar a lente por cima do dedo é o defeito que esta família cobra.
	# O caso negativo é o que prova a porta: sem modificador, SOBRE a moldura, nem `campo_zoom` se
	# move. Os dois positivos seguintes são o atalho pedido — SHIFT e CTRL vencem a geografia, e a
	# direção continua sendo a da roda (SHIFT sobe, CTRL desce), porque "dois botões" sem sentido
	# próprio seria um terceiro gesto para a mesma lente.
	jogo.campo_zoom = 0.4
	var roda_painel := InputEventMouseButton.new()
	roda_painel.pressed = true
	roda_painel.global_position = dentro_do_painel
	roda_painel.button_index = MOUSE_BUTTON_WHEEL_UP
	for i in range(20):
		jogo._input(roda_painel)
	var zoom_sobre_painel := float(jogo.campo_zoom)
	roda_painel.shift_pressed = true
	for i in range(20):
		jogo._input(roda_painel)
	var zoom_shift := float(jogo.campo_zoom)
	roda_painel.shift_pressed = false
	roda_painel.ctrl_pressed = true
	roda_painel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	for i in range(40):
		jogo._input(roda_painel)
	var zoom_ctrl := float(jogo.campo_zoom)
	_assert("a roda leva a FOV da ponte de setenta e oito graus a quatorze",
		fov_larga > PONTE_FOV_LARGO - 0.01 and fov_fechada < PONTE_FOV_FECHADO + 0.01,
		"zoom 0 -> %.1f, zoom 1 -> %.1f, zoom 0,5 -> %.1f" % [fov_larga, fov_fechada, fov_meia])
	_assert("a roda fora do painel aperta nas duas pontas e so ela manda no zoom",
		is_equal_approx(aperto_topo, 1.0) and is_equal_approx(aperto_fundo, 0.0) \
			and is_equal_approx(float(jogo.campo_zoom), 0.0) \
			and caixa_painel.has_point(dentro_do_painel) \
			and not caixa_painel.has_point(fora_do_painel),
		"20 voltas para cima -> %.2f, 40 para baixo -> %.2f, o clique não mexe no zoom da ponte (%.2f), painel em x %.0f-%.0f y %.0f-%.0f com os dois pontos testados em (%.0f,%.0f) e (%.0f,%.0f)" % [
			aperto_topo, aperto_fundo, jogo.campo_zoom, caixa_painel.position.x,
			caixa_painel.end.x, caixa_painel.position.y, caixa_painel.end.y,
			dentro_do_painel.x, dentro_do_painel.y, fora_do_painel.x, fora_do_painel.y])
	_assert("sobre o painel a roda sem modificador é da lista: o zoom fica onde estava",
		is_equal_approx(zoom_sobre_painel, 0.4),
		"20 voltas para cima dentro da moldura devolveram %.2f (largada em 0,40)" % zoom_sobre_painel)
	_assert("SHIFT+roda sobre o painel vence a geografia e aproxima do mesmo jeito",
		is_equal_approx(zoom_shift, 1.0),
		"de 0,40 com SHIFT pressionado -> %.2f" % zoom_shift)
	_assert("CTRL+roda sobre o painel vence a geografia e afasta, na direção da roda",
		is_equal_approx(zoom_ctrl, 0.0),
		"do teto com CTRL pressionado e 40 voltas para baixo -> %.2f" % zoom_ctrl)
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
	# A precondition da fatia 4, declarada sem afrouxar nenhuma conta: o paragrafo 5 do programa
	# INVERTE a frase antiga. O alvo continua sendo o mais proximo (a lei de escolha nao mudou um
	# digito), mas entra na salva quem tem VANTE LIMPO, e quem tem o proprio aliado na frente fica
	# com a boca de fogo tapada. A regua velha nao desapareceu: volta como
	# `lancados + obstruidos == armados` -- ou dispara ou e tapado, e nada se perde no meio -- com o
	# numero de antes impresso no detalhe, para ninguem ler sessenta como "a muralha esqueceu de
	# atirar".
	_assert("no contato a muralha atira por coluna: todo bloco vivo e armado ou dispara ou e tapado pelo proprio aliado",
		lancados + int(fogo.get("obstruidos", 0)) == armados and lancados > 0 \
				and int(fogo.get("obstruidos", 0)) > 0,
			"%d lancados + %d tapados pelo corredor = %d blocos armados, %d quadros de travessia, " % [
				lancados, int(fogo.get("obstruidos", 0)), armados, q_fogo] \
			+ "fachada %.1f u, alcance %.1f u (a lei de antes cobrava os mesmos %d como lancados)" % [
				_fachadas(f), Esquadra.ALCANCE_DE_BLOCO, armados])
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

	# ── 12. o lance da massa tem canal de desenho, UM POR CASCO PINTADO ─────────────────────────
	# A lei aqui é o CANAL, não o pixel: sob `--headless` o `set_instance_transform` é descartado e a
	# leitura volta identidade, então acender o visor é pergunta de `massa_visivel.gd`. O que dá para
	# assinar de cabeça fria é que a fila armada espelha o ledger casa a casa, que um bloco que cobra
	# paga vinte e quatro bocas e não uma, que o atraso de cada lance é a casa dele e que a onda inteira
	# cabe numa cadência, que a ordem da ponte converge o BLOCO visado (não um ponto único), que o custo
	# é um nó reescrito por quadro, que nada sorteia e que o pulso apaga a fila no impacto.
	var q_ponte := _marchar_na_ponte(jogo)
	var tr_no: MultiMeshInstance3D = jogo.massa_tracos
	var tr_mm: MultiMesh = tr_no.multimesh
	var mat_tr: StandardMaterial3D = tr_no.material_override
	_assert("a salva da massa e um no com uma instancia por casa desenhada, luminoso por material",
		is_instance_valid(tr_no) and tr_mm.instance_count == TRACOS_MAXIMOS \
				and tr_mm.transform_format == MultiMesh.TRANSFORM_3D and tr_mm.use_colors \
				and mat_tr.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
				and mat_tr.vertex_color_use_as_albedo,
		"%d instancias para %d casas de %d blocos, unshaded + cor por instancia, travessia de %d quadros" % [
			tr_mm.instance_count, TRACOS_MAXIMOS, 2 * BLOCOS_POR_LADO, q_ponte])
	var caixas := 0
	for filho in jogo.get_children():
		if filho is MultiMeshInstance3D:
			caixas += 1
	_assert("o preco de cinco mil setecentos e sessenta lances visiveis e UM no a mais na cena",
		caixas == 4,
		"%d MultiMeshInstance3D na cena (ceu + dois corpos da massa + tracos)" % caixas)
	jogo.esquadra.soltar_fogo()
	jogo._salva_da_massa()
	var fila_mm: Array[Dictionary] = jogo._tracos_voando
	var espelho: Array[Dictionary] = jogo.esquadra.tiros_da_salva()
	var ledger_mm := int(jogo.esquadra.pares_da_ultima_salva.size())
	var casas_mm := _casas_esperadas(jogo.esquadra.pares_da_ultima_salva)
	_assert("o cano e o casco: quem cobra paga uma lance por casa viva, nao um por bloco",
		fila_mm.size() == casas_mm and casas_mm > ledger_mm and casas_mm > 0,
		"%d tracos armados para %d casas vivas, contra %d blocos que cobraram na salva %d" % [
			fila_mm.size(), casas_mm, ledger_mm, int(jogo.esquadra.salva_numero)])
	_assert("a fila pintada e o espelho da conta, lance a lance",
		_selo_da_fila(fila_mm) == _selo_da_fila(espelho),
		"%d lances com selo identico de %d caracteres entre desenho e conta" % [
			fila_mm.size(), _selo_da_fila(espelho).length()])
	_assert("o atraso de cada lance e a casa dele: a leva sai em fila, nao junto",
		_casas_fora_da_onda(fila_mm, espelho) == 0,
		"%d de %d lances com atraso diferente de casa x %.3f s" % [
			_casas_fora_da_onda(fila_mm, espelho), fila_mm.size(), PASSO_ONDA])
	var bloco_mm: Dictionary = jogo.esquadra.pares_da_ultima_salva[0]["origem"]
	_assert("a boca do cano e o proprio casco pintado: as bocas de um bloco sao as suas casas",
		_bocas_distintas(espelho, int(bloco_mm["id"])) == Esquadra.casas_vivas(bloco_mm) \
				and str(_bocas_de_um_bloco(espelho, int(bloco_mm["id"]))) \
					== str(_casas_no_mundo(bloco_mm)),
		"%d bocas distintas no bloco %d, iguais as %d casas pintadas dele" % [
			_bocas_distintas(espelho, int(bloco_mm["id"])), int(bloco_mm["id"]),
			Esquadra.casas_vivas(bloco_mm)])
	var destinos := _faixa_x_dos_pontos(fila_mm, "para")
	_assert("o fogo desenhado varre a largura da muralha hostil, nao o meio do campo",
			float(destinos["max"]) - float(destinos["min"]) > 150.0,
			"destinos entre x %.1f e %.1f u, %.1f u de largura coberta" % [
				destinos["min"], destinos["max"], float(destinos["max"]) - float(destinos["min"])])
	var onda_zero := _lances_no_ar(fila_mm, 0.0)
	var onda_meia := _lances_no_ar(fila_mm, 11.5 * PASSO_ONDA)
	var onda_cheia := _lances_no_ar(fila_mm, 23.0 * PASSO_ONDA + 0.001)
	_assert("dentro do bloco a salva e onda: nada no ar no zero, metade no meio, tudo no fim",
		onda_zero == 0 and onda_meia > 0 and onda_meia < fila_mm.size() \
				and onda_cheia == fila_mm.size(),
		"%d / %d / %d lances no ar em t = 0 / %.3f s / %.3f s de uma fila de %d" % [
			onda_zero, onda_meia, onda_cheia, 11.5 * PASSO_ONDA, 23.0 * PASSO_ONDA + 0.001,
			fila_mm.size()])
	_assert("a leva inteira cabe numa cadencia: onda mais voo fecham antes da salva seguinte",
		TRACO_PULSO < 1.6 and PASSO_ONDA > 0.0,
		"pulso de %.3f s (onda %.3f s + voo %.2f s) contra cadencia de 1,60 s" % [
			TRACO_PULSO, 23.0 * PASSO_ONDA, TRACO_SEG])
	var boca_estavel := _selo_da_fila(fila_mm)
	jogo._armar_tracos()
	_assert("nada sorteia: rearmar a mesma salva devolve os mesmos vinte e quatro canos por bloco",
		boca_estavel == _selo_da_fila(jogo._tracos_voando),
		"%d tracos rearmados com selo identico de %d caracteres" % [
			jogo._tracos_voando.size(), boca_estavel.length()])
	var fachada_j := _faixa_z(jogo.esquadra, "hostil")
	var visado_j := _bloco_mais_proximo_de(Vector3(PASSO_ESQUADRAO_X, ANDAR,
			float(fachada_j["max"])), jogo.esquadra.lista_de("hostil"))
	jogo.esquadra.mandar_fogo((visado_j["pos"] as Vector3) + Vector3(3.0, 0.0, 0.0))
	jogo._salva_da_massa()
	var conc_j: Array[Dictionary] = jogo.esquadra.tiros_da_salva()
	_assert("concentrando pela ponte, o desenho converge no bloco visado: um alvo, vinte e quatro bocas",
		_selo_da_fila(conc_j) == _selo_da_fila(jogo._tracos_voando) \
				and _blocos_alvo_distintos(conc_j, true) == 1 \
				and _pontos_distintos(conc_j, true) > 1,
		"%d tracos na fila dos dois lados, %d bloco visado de quem atira aliado, repartidos em %d casco de destino" % [
			int(conc_j.size()), _blocos_alvo_distintos(conc_j, true),
			_pontos_distintos(conc_j, true)])
	jogo.esquadra.soltar_fogo()
	jogo._salva_da_massa()
	var conc_s: Array[Dictionary] = jogo.esquadra.tiros_da_salva()
	_assert("soltando a ordem, o desenho volta a ter um bloco visado por bloco que atira",
		_selo_da_fila(conc_s) == _selo_da_fila(jogo._tracos_voando) \
				and _blocos_alvo_distintos(conc_s, true) > 1,
		"%d tracos na fila dos dois lados, %d blocos visados de quem atira aliado" % [
			int(conc_s.size()), _blocos_alvo_distintos(conc_s, true)])
	jogo._tracos_escritas = 0
	jogo._armar_tracos()
	var quadros_do_pulso := int(ceilf(TRACO_PULSO * 60.0))
	for kp in range(quadros_do_pulso):
		jogo._atualizar_tracos(1.0 / 60.0)
	_assert("o preco do lote e UM no reescrito por quadro: nada de no por lance",
		jogo._tracos_escritas == (quadros_do_pulso + 1) * TRACOS_MAXIMOS,
		"%d escritas em %d quadros mais a armacao = (%d + 1) x %d do lote" % [
			jogo._tracos_escritas, quadros_do_pulso, quadros_do_pulso, TRACOS_MAXIMOS])
	_assert("o traco morre no impacto: no fim do pulso nao ha lance novo no quadro",
		jogo._tracos_voando.is_empty() and float(jogo._traco_t) >= TRACO_PULSO,
		"fila zerada depois de %d quadros (%.2f s), relogio do pulso em %.3f s" % [
			quadros_do_pulso, float(quadros_do_pulso) / 60.0, float(jogo._traco_t)])
	jogo._armar_tracos()
	jogo._atualizar_tracos(TRACO_PULSO + 0.1)
	_assert("quadro escuro nao rearma sozinho: o pulso nao vira chuva continua",
		jogo._tracos_voando.is_empty() and float(jogo._traco_t) >= TRACO_PULSO,
		"um pulso inteiro depois de rearmar, %d tracos na fila" % jogo._tracos_voando.size())

	# ── 13. a muralha respira: o pouso deixou de ser parada ────────────────────────────────────────
	# O comandante pediu naves andando durante a batalha. A lei assinada aqui é de custódia de posto,
	# não de vaga: cada bloco ORBITA o próprio lugar na grade, e a fase é escolhida pelo ar que existe
	# em cada eixo. Em boreste só há 2,48 u entre um bloco e o vizinho, então a fase é do ANDAR: os
	# blocos de uma fileira deslizam juntos e a distância de fileira — a régua do ar da família 2 —
	# fica literalmente constante. Em altura há 8,53 u, e é aí que os seis esquadrões podem respirar
	# defasados de 60 graus. Em z a deriva não entra: é o eixo do contato, e a fachada que as
	# famílias 2 e 10 assinam é medida centro a centro. E quem recebe destino da ponte para no ponto,
	# em vez de balançar em volta dele.
	var pico_x := 0.0
	var pico_y := 0.0
	var z_da_deriva := 0.0
	var pior_espe_x := 0.0
	var pior_espe_y := 0.0
	var pior_perseg := 0.0
	var pior_px := 0.0
	var pior_py := 0.0
	var pior_pz := 0.0
	var estacao_z_min := INF
	var estacao_z_max := -INF
	var pior_ar := INF
	var pior_fileira := 0.0
	var sobreposicoes := 0
	var vivos_amostra := 0
	for kr in range(QUADROS_DO_CICLO_DA_DERIVA):
		jogo._atualizar_esquadras(1.0 / 60.0)
		var ra := _respiro(jogo.esquadra, "aliado")
		var rh := _respiro(jogo.esquadra, "hostil")
		vivos_amostra = int(ra["vivos"]) + int(rh["vivos"])
		pico_x = maxf(pico_x, maxf(float(ra["max_x"]), float(rh["max_x"])))
		pico_y = maxf(pico_y, maxf(float(ra["max_y"]), float(rh["max_y"])))
		pior_perseg = maxf(pior_perseg, maxf(float(ra["perseg"]), float(rh["perseg"])))
		pior_px = maxf(pior_px, maxf(float(ra["perseg_x"]), float(rh["perseg_x"])))
		pior_py = maxf(pior_py, maxf(float(ra["perseg_y"]), float(rh["perseg_y"])))
		pior_pz = maxf(pior_pz, maxf(float(ra["perseg_z"]), float(rh["perseg_z"])))
		# A estacao tambem anda nesta janela, e e ela - nao a respira - que move o eixo do contato.
		# Medir o curso da estacao em z e o que separa as duas causas.
		for ld4 in ["aliado", "hostil"]:
			var ez: float = (jogo.esquadra.estacao(ld4) as Vector3).z
			estacao_z_min = minf(estacao_z_min, ez)
			estacao_z_max = maxf(estacao_z_max, ez)
		# O vetor que o modulo montou neste quadro, conferido contra o espelho da sonda casa a casa:
		# boreste com a fase do andar, altura com a fase do esquadrao, z zerado por construcao.
		for ev in range(Esquadra.ESQUADROES_NO_LADO):
			var dv: Vector3 = jogo.esquadra._derivas[ev]
			var esp := _deriva_esperada(jogo.esquadra, ev)
			z_da_deriva = maxf(z_da_deriva, absf(dv.z))
			pior_espe_x = maxf(pior_espe_x, absf(dv.x - esp.x))
			pior_espe_y = maxf(pior_espe_y, absf(dv.y - esp.y))
		if kr % 30 == 0:
			var ar_r := _ar_da_respiracao(jogo.esquadra)
			pior_ar = minf(pior_ar, float(ar_r["ar_min"]))
			pior_fileira = maxf(pior_fileira, float(ar_r["pior_x"]))
			sobreposicoes += int(ar_r["sobrepostos"])
	# A cauda que a propria lei gera: quem persegue um posto que anda, sob o teto de aceleracao da
	# ficha, fica atras dele por `v_de_ponta / aceleracao`, e so isso. O numero teorico sai impresso
	# ao lado do medido para a diferenca ficar lida na janela, nao coberta por uma tolerancia.
	var vx_de_ponta := Esquadra.DERIVA_X * TAU / Esquadra.DERIVA_CICLO
	var vy_de_ponta := Esquadra.DERIVA_Y * TAU / Esquadra.DERIVA_CICLO * 0.5
	var acel := float(Voo.FICHA_BLOCO["aceleracao"])
	_assert("nenhum bloco de linha estaciona: persegue o posto do proprio andar em boreste e altura",
		pior_px <= vx_de_ponta / acel + FOLGA_DERIVA \
				and pior_py <= vy_de_ponta / acel + FOLGA_DERIVA \
				and vivos_amostra == 2 * BLOCOS_POR_LADO,
			"cauda lida %.3f u em boreste (teorica %.3f u) e %.3f u em altura (teorica %.3f u), folga %.2f, " % [
				pior_px, vx_de_ponta / acel, pior_py, vy_de_ponta / acel, FOLGA_DERIVA] \
				+ "total %.3f u sobre %d blocos vivos dos %d da partida" % [
					pior_perseg, vivos_amostra, 2 * BLOCOS_POR_LADO])
	_assert("a deriva tem teto por eixo: boreste nao passa de %.1f u, altura de %.1f u" % [
			Esquadra.DERIVA_X, Esquadra.DERIVA_Y],
		pico_x <= Esquadra.DERIVA_X + FOLGA_DERIVA \
				and pico_y <= Esquadra.DERIVA_Y + FOLGA_DERIVA,
		"pico do ciclo %.2f u em x (teto %.1f + folga %.2f), %.2f u em y (teto %.1f)" % [
			pico_x, Esquadra.DERIVA_X, FOLGA_DERIVA, pico_y, Esquadra.DERIVA_Y])
	_assert("respirar de verdade: no meio de seis esquadroes defasados de 60 graus o boreste ja chegou perto do teto",
		pico_x >= 0.9 * Esquadra.DERIVA_X and pico_y >= 0.9 * Esquadra.DERIVA_Y,
		"pico lido %.2f u de %.1f u em boreste e %.2f u de %.1f u em altura" % [
			pico_x, Esquadra.DERIVA_X, pico_y, Esquadra.DERIVA_Y])
	_assert("a respira nao mexe no eixo do contato: nenhum vetor de deriva tem boreste em z",
		z_da_deriva == 0.0 and pior_espe_x <= FOLGA and pior_espe_y <= FOLGA,
		"maior componente em z lido nos %d vetores do ciclo: %.6f u; e espelho por eixo bate no modulo " % [
			Esquadra.ESQUADROES_NO_LADO, z_da_deriva] \
			+ "em boreste %.6f u e em altura %.6f u" % [pior_espe_x, pior_espe_y])
	# O que sobra em z nao e deriva, e marcha: a estacao percorreu os %.1f u abaixo nesta janela, e um
	# bloco que persegue um posto que anda a v u/s fica atras dele por no maximo v / aceleracao. e a
	# conta da propria ficha, nao uma tolerancia escolhida aqui.
	var v_estacao_z := (estacao_z_max - estacao_z_min) / (float(QUADROS_DO_CICLO_DA_DERIVA) / 60.0)
	_assert("o atraso em z do ciclo e a cauda da marcha, nao a respira: v da estacao sobre a aceleracao da ficha",
		pior_pz <= v_estacao_z / acel + FOLGA_DERIVA,
			"cauda em z lida %.3f u contra %.3f u de v/a (estacao a %.2f u/s, ficha a %.1f u/s2) + folga %.2f" % [
				pior_pz, v_estacao_z / acel, v_estacao_z, acel, FOLGA_DERIVA])
	_assert("respirar nao fecha o ar entre cascos: a lei da familia 2 continua valendo no ciclo todo",
		sobreposicoes == 0 and pior_ar >= AR_MINIMO,
		"%.2f u de ar no par mais junto (piso da lei %.2f), %d sobreposicoes no ciclo" % [
			pior_ar, AR_MINIMO, sobreposicoes])
	_assert("o boreste e fase de andar: dentro de um andar a distancia de fileira nao muda nunca",
		pior_fileira <= FOLGA,
		"pior erro de distancia em x entre blocos do mesmo andar: %.4f u sobre a folga %.1f u" % [
			pior_fileira, FOLGA])
	var ordenado: Dictionary = jogo.esquadra.lista_de("aliado")[7]
	var ponto_da_ponte: Vector3 = (ordenado["pos"] as Vector3) + Vector3(9.0, 0.0, -6.0)
	ordenado["destino"] = ponto_da_ponte
	ordenado["com_destino"] = true
	for mq in range(QUADROS_DO_CICLO_DA_DERIVA):
		jogo._atualizar_esquadras(1.0 / 60.0)
	_assert("quem recebe destino da ponte para no ponto, e nao passa a respirar em volta dele",
		(ordenado["pos"] as Vector3).distance_to(ponto_da_ponte) \
				<= Voo.CAPTURA_DE_POUSO + FOLGA_DERIVA,
		"bloco %d a %.3f u do ponto comandado (captura de pouso %.2f u + folga %.2f u)" % [
			int(ordenado["id"]), (ordenado["pos"] as Vector3).distance_to(ponto_da_ponte),
			Voo.CAPTURA_DE_POUSO, FOLGA_DERIVA])
	ordenado["com_destino"] = false

	# ── 13b. com a estação parada, respirar não vira proa ──────────────────────────────────────
	# O regime que o olho da ponte pega e o ledger não pega: no contato a estação já não anda, e o
	# único resíduo entre o bloco e o próprio posto é o deslize de boreste da deriva — três centésimos
	# de unidade, quase puro lado. Se a proa sai do vetor de perseguição, o bloco gira para acompanhar
	# isso e apresenta o través ao inimigo: `massa_visivel.gd` leu a boca do MESMO bloco encolher de
	# 630 px para 236 px no mesmo grau de lente, e a fresta entre dois blocos virar branco. A lei não
	# é nova, é a que `main.gd` já grava para os doze cascos: destino absoluto manda o curso
	# (`_pilotar`), custódia de posto guarda a atitude da linha (`_empuxar`). Aqui ela entra para os
	# duzentos e quarenta blocos.
	var e_parada := _nova_esquadra()
	var nuc_par_a := _nucleos(true)
	var nuc_par_h := _nucleos(false)
	_marchar_ate_contato(e_parada, nuc_par_a, nuc_par_h)
	for aq in range(AQUECIMENTO_DA_PROA):
		e_parada.passo(1.0 / 60.0, nuc_par_a, nuc_par_h)
	var pior_proa := 0.0
	var pior_proa_h := 0.0
	var pior_residuo := 0.0
	for kq in range(QUADROS_DO_CICLO_DA_DERIVA):
		e_parada.passo(1.0 / 60.0, nuc_par_a, nuc_par_h)
		for lado_p in ["aliado", "hostil"]:
			for bp in e_parada.lista_de(lado_p):
				if not bool(bp["vivo"]):
					continue
				var desvio := absf(wrapf(float(bp["rumo"]) - Esquadra.rumo_da_linha(lado_p),
					-PI, PI))
				if lado_p == "aliado":
					pior_proa = maxf(pior_proa, desvio)
					# O contrafactual lido no mesmo quadro, sem segunda simulação. Com a estação
					# parada e a boca de pouso (0,02 u) engolindo o resto, o único resíduo que a lei
					# velha via entre o bloco e o posto é o passo que o próprio posto deu no quadro
					# — puro boreste, porque a deriva não tem componente em z. É o curso que o leme
					# obedecia, e é ele que deitava a muralha de través.
					var esq_p := int(bp["esquadrao"])
					var passo_posto := _deriva_esperada(e_parada, esq_p, e_parada.tempo) \
						- _deriva_esperada(e_parada, esq_p, e_parada.tempo - 1.0 / 60.0)
					if passo_posto.length_squared() > 1e-12:
						pior_residuo = maxf(pior_residuo,
							absf(wrapf(Voo.rumo_de(passo_posto), -PI, PI)))
				else:
					pior_proa_h = maxf(pior_proa_h, desvio)
	# O teto não é escolha desta sonda: é o passo do próprio leme num quadro. Guardada a atitude, o
	# leme não tem para onde girar, e a única coisa que ainda pode mover o `rumo` é um degrau de
	# `giro_maximo * delta`.
	var degrau_do_leme := float(Voo.FICHA_BLOCO["giro_maximo"]) / 60.0
	_assert("a estacao parada nao vira proa: quem respira de custodia guarda a fachada da linha",
		pior_proa <= degrau_do_leme and pior_proa_h <= degrau_do_leme,
			"maior desvio de proa lido no ciclo: %.2f graus aliado e %.2f graus hostil, teto %.2f " % [
				rad_to_deg(pior_proa), rad_to_deg(pior_proa_h), rad_to_deg(degrau_do_leme)] \
				+ "graus (um degrau do leme do bloco); o curso que o residuo mandaria seria %.1f graus" % [
					rad_to_deg(pior_residuo)])

	# ── 14. o corredor: a fileira da frente atira, e o que passa bate em quem esta atras ────────
	# A fatia 4 troca o portao do lance: de "esta no alcance?" para "tem vante limpo?". Quatro pontas,
	# cada uma capaz de falhar sozinha:
	# * A CAIXA. Sem ela nenhuma das outras e lida, e ela tem de sair do MESMO volume que a tela
	#   pinta: o piso assinado da grade (10,52 x 3,47 x 4,45 u) contra a caixa das casas vivas.
	# * A CONTA. A sonda refaz o corte bloco a bloco com laje escrita em casa (laje, nao esfera: com
	#   esfera de raio 5,26 os vizinhos de boreste, a 2,48 u de ar, parariam lances que passam por
	#   fora de todo casco desenhado) e confere elenco, silencio e PAGADOR contra o ledger.
	# * A COLUNA. A consequencia visivel: nas trinta colunas de boreste-andar de cada lado, fileiras a
	#   7,0 u com 4,45 u de casco, so a frente tem vante limpo. Cobra o conjunto EXATO das frentes --
	#   nem uma a mais (um bloco do meio atirando por cima do proprio aliado e o buraco na lei), nem
	#   uma a menos (uma frente calada sem corpo na frente e o ledger comendo fogo).
	# * A FRESTA. O "bate no aliado atras" do paragrafo 5, montado a regua: existe alvo comandado cujo
	#   lance cruza os 8,53 u de ar entre os dois andares, passa por fora da primeira caixa inimiga e
	#   cobra de quem esta atras dela. Com a conta de DOIS EIXOS o mesmo lance morre na frente -- e e
	#   isso que prova que o y nao e enfeite no alcance da massa.
	var e_cor := _nova_esquadra()
	_marchar_ate_contato(e_cor, _nucleos(true), _nucleos(false))
	var ca_a: Array[Dictionary] = e_cor.lista_de("aliado")
	var ca_h: Array[Dictionary] = e_cor.lista_de("hostil")
	var b_cheio: Dictionary = ca_a[0]
	var cx_cheio := e_cor.caixa_do_bloco(b_cheio)
	_assert("a caixa do bloco cheio e o piso assinado da grade, nos tres eixos",
		absf(cx_cheio.size.x - PISO_X) <= 0.02 and absf(cx_cheio.size.y - PISO_Y) <= 0.02 \
				and absf(cx_cheio.size.z - PISO_Z) <= 0.02,
			"caixa lida %.3f x %.3f x %.3f u contra pisos %.2f / %.2f / %.2f u, em %d casas, " % [
				cx_cheio.size.x, cx_cheio.size.y, cx_cheio.size.z, PISO_X, PISO_Y, PISO_Z,
				Esquadra.casas_vivas(b_cheio)] \
			+ "rumo %.1f graus (a caixa e o volume dos cascos pintados, nao uma vontade)" % [
				rad_to_deg(float(b_cheio["rumo"]))])
	var b_meio: Dictionary = ca_a[1]
	var navios_cheios := float(b_meio["navios"])
	b_meio["navios"] = float(NAVIOS_NO_BLOCO) * 0.5
	var cx_meio := e_cor.caixa_do_bloco(b_meio)
	var casas_meio := Esquadra.casas_vivas(b_meio)
	b_meio["navios"] = navios_cheios
	var b_morto: Dictionary = ca_a[2]
	b_morto["vivo"] = false
	var cx_morto := e_cor.caixa_do_bloco(b_morto)
	b_morto["vivo"] = true
	_assert("a caixa segue a lotacao: meio bloco perde o topo, morto nao tapa lance nenhum",
		casas_meio == 12 and absf(cx_meio.size.y - (PISO_Y - Esquadra.PASSO_CASA_Y)) <= 0.02 \
				and cx_morto.size.x < 0.0 and cx_morto.size.y < 0.0 and cx_morto.size.z < 0.0,
			"meio bloco: %d casas e %.3f u de altura contra %.3f u do cheio (fecha o topo, nao esburaca o " % [
				casas_meio, cx_meio.size.y, cx_cheio.size.y] \
			+ "meio); morto: size %.1f, que e o 'nao existe' do AABB" % [cx_morto.size.x])
	var leituras := 0
	for lado14a in ["aliado", "hostil"]:
		for b14a in e_cor.lista_de(lado14a):
			leituras += Esquadra.casas_vivas(b14a)
	var conta14 := _conta_do_corredor(e_cor)
	var salva14 := e_cor.troca_salva()
	var lancados14 := int(salva14.get("lancados", 0))
	var tapados14 := int(salva14.get("obstruidos", 0))
	var rebatidos14 := int(salva14.get("rebatidos", 0))
	var id_que_dispara: Dictionary = {}
	var dispara_conta: Array = conta14["dispara"]
	var paga_conta: Dictionary = conta14["paga"]
	var pagadores_trocados := 0
	for par14 in e_cor.pares_da_ultima_salva:
		var oid14 := int((par14["origem"] as Dictionary)["id"])
		id_que_dispara[oid14] = true
		if int(paga_conta.get(oid14, -1)) != int((par14["bate"] as Dictionary)["id"]):
			pagadores_trocados += 1
	var divergencias := pagadores_trocados
	for did14 in dispara_conta:
		if not id_que_dispara.has(did14):
			divergencias += 1
	for oid15 in id_que_dispara:
		if not dispara_conta.has(oid15):
			divergencias += 1
	_assert("o corredor da sonda e o corredor da esquadra: mesmo lance, mesmo silencio, mesmo pagador",
		divergencias == 0 and int(conta14["lancados"]) == lancados14 \
				and int(conta14["tapados"]) == tapados14 and int(conta14["rebatidos"]) == rebatidos14,
			"esquadra: %d lancados, %d tapados, %d rebatidos. sonda: %d, %d, %d, sobre %d blocos " % [
				lancados14, tapados14, rebatidos14, int(conta14["lancados"]), int(conta14["tapados"]),
				int(conta14["rebatidos"]), _armados(e_cor)] \
			+ "armados, com %d divergencias de elenco ou de pagador" % divergencias)
	var colunas_a := _colunas_de(ca_a)
	var colunas_h := _colunas_de(ca_h)
	var frente_calada := 0
	var costa_disparando := 0
	var fundos: Array[int] = []
	for lado14b in ["aliado", "hostil"]:
		var aliada14 := String(lado14b) == "aliado"
		var colunas_lado: Array = colunas_a if aliada14 else colunas_h
		for g14 in colunas_lado:
			var membros: Array = g14["membros"]
			fundos.append(membros.size())
			var ponta14: Dictionary = membros[0]
			for m14 in membros:
				if _mais_frente(m14 as Dictionary, ponta14, aliada14):
					ponta14 = m14 as Dictionary
			for m15 in membros:
				var dispara14 := id_que_dispara.has(int((m15 as Dictionary)["id"]))
				if (m15 as Dictionary) == ponta14 and not dispara14:
					frente_calada += 1
				if (m15 as Dictionary) != ponta14 and dispara14:
					costa_disparando += 1
	_assert("a lei da coluna e exata: uma boca de fogo por coluna de boreste-andar, sempre a da frente",
		frente_calada == 0 and costa_disparando == 0 \
				and colunas_a.size() + colunas_h.size() == 2 * BLOCOS_POR_LADO / Esquadra.LINHAS_NO_ESQUADRAO \
				and fundos.min() == Esquadra.LINHAS_NO_ESQUADRAO \
				and fundos.max() == Esquadra.LINHAS_NO_ESQUADRAO,
			"%d colunas lidas (%d aliadas + %d hostis), todas de %d blocos de fundo, %d lances na salva, " % [
				colunas_a.size() + colunas_h.size(), colunas_a.size(), colunas_h.size(),
				fundos.min(), lancados14] \
			+ "%d fileiras da frente caladas sem corpo na frente e %d blocos de tras atirando por cima " % [
				frente_calada, costa_disparando] \
			+ "do proprio aliado")

	# A fresta montada a regua: o atirador e a frente da coluna aliada mais a boreste, e o alvo e o
	# primeiro bloco hostil vivo e em alcance cuja primeira caixa na linha NAO e ele mesmo. A busca e
	# por indice de lista, sem sorteio, e o ledger e cobrado sobre o caso que ela escolheu.
	var e_fresta := _nova_esquadra()
	_marchar_ate_contato(e_fresta, _nucleos(true), _nucleos(false))
	var fl_h: Array[Dictionary] = e_fresta.lista_de("hostil")
	var cx_fresta: Array = e_fresta._caixas_de("hostil")
	var grupo_x0: Dictionary = {}
	var menor_x := INF
	for g15 in _colunas_de(e_fresta.lista_de("aliado")):
		if (g15["pos"] as Vector3).x < menor_x:
			menor_x = (g15["pos"] as Vector3).x
			grupo_x0 = g15
	var atirador: Dictionary = {}
	if not grupo_x0.is_empty():
		for m16 in (grupo_x0["membros"] as Array):
			if atirador.is_empty() or _mais_frente(m16 as Dictionary, atirador, true):
				atirador = m16 as Dictionary
	var fresta_h := -1
	var fresta_bate := -1
	if not atirador.is_empty():
		var origem14: Vector3 = atirador["pos"]
		for h14 in range(fl_h.size()):
			var vivo14: Dictionary = fl_h[h14]
			if not bool(vivo14["vivo"]):
				continue
			if (vivo14["pos"] as Vector3).distance_to(origem14) > Esquadra.ALCANCE_DE_BLOCO:
				continue
			var trecho14: Vector3 = (vivo14["pos"] as Vector3) - origem14
			var primeira14 := _primeira_caixa(origem14, trecho14, cx_fresta, -1)
			if int(primeira14["i"]) != -1 and int(primeira14["i"]) != h14 \
					and float(primeira14["t"]) <= 1.0:
				fresta_h = h14
				fresta_bate = int(primeira14["i"])
				break
	var salva15: Dictionary = {}
	var alvo_pelo_ledger := -1
	var paga_pelo_ledger := -1
	var cobrados_errados := 0
	var intactos_movidos := 0
	var rasa_bate := -1
	var alvo_id14 := -1
	var bate_id14 := -1
	var y_alvo14 := 0.0
	var y_bate14 := 0.0
	if fresta_h >= 0 and fresta_bate >= 0:
		alvo_id14 = int(fl_h[fresta_h]["id"])
		bate_id14 = int(fl_h[fresta_bate]["id"])
		y_alvo14 = (fl_h[fresta_h]["pos"] as Vector3).y
		y_bate14 = (fl_h[fresta_bate]["pos"] as Vector3).y
		e_fresta.mandar_fogo(fl_h[fresta_h]["pos"] as Vector3)
		var antes14: Dictionary = {}
		for hb14 in fl_h:
			antes14[int(hb14["id"])] = float(hb14["navios"]) + float(hb14["MOTORES"]) \
					+ float(hb14["ARMAS"]) + float(hb14["TRIPULACAO"])
		salva15 = e_fresta.troca_salva()
		var pagos14: Dictionary = {}
		for par15 in e_fresta.pares_da_ultima_salva:
			pagos14[int((par15["bate"] as Dictionary)["id"])] = true
			if int((par15["origem"] as Dictionary)["id"]) == int(atirador["id"]):
				alvo_pelo_ledger = int((par15["alvo"] as Dictionary)["id"])
				paga_pelo_ledger = int((par15["bate"] as Dictionary)["id"])
		for hb15 in fl_h:
			var era14 := float(antes14.get(int(hb15["id"]), -1.0))
			var agora14 := float(hb15["navios"]) + float(hb15["MOTORES"]) + float(hb15["ARMAS"]) \
					+ float(hb15["TRIPULACAO"])
			if era14 < 0.0:
				continue
			if pagos14.has(int(hb15["id"])) and agora14 >= era14:
				cobrados_errados += 1
			if not pagos14.has(int(hb15["id"])) and agora14 != era14:
				intactos_movidos += 1
		var origem15: Vector3 = atirador["pos"]
		var trecho15: Vector3 = (fl_h[fresta_h]["pos"] as Vector3) - origem15
		var rasa_t := INF
		for k14 in range(cx_fresta.size()):
			var tr14 := _t_entrada(origem15, trecho15, _caixa_rasa(cx_fresta[k14]))
			if tr14 < rasa_t:
				rasa_t = tr14
				rasa_bate = k14
	_assert("a fresta existe: ha ordem da ponte cujo lance passa por fora da frente e cobra de quem esta atras",
		fresta_h >= 0 and fresta_bate != fresta_h and alvo_pelo_ledger == alvo_id14 \
				and paga_pelo_ledger == bate_id14 and int(salva15.get("rebatidos", 0)) > 0,
			"visado id %d no andar y=%.2f, pagador id %d no andar y=%.2f, %d rebatidos na salva comandada, " % [
				alvo_id14, y_alvo14, bate_id14, y_bate14, int(salva15.get("rebatidos", 0))] \
			+ "alvo lido do ledger=%d e pagador=%d (busca da sonda: indice %d, que e o %d da lista)" % [
				alvo_pelo_ledger, paga_pelo_ledger, fresta_h, fresta_bate])
	_assert("quem paga e a caixa interceptada, nao a apontada: o ledger cobra o pagador e mais ninguem",
		fresta_h >= 0 and cobrados_errados == 0 and intactos_movidos == 0,
			"%d pagadores cobrados sem perder estado e %d hostis fora do elenco de pagadores que mudaram " % [
				cobrados_errados, intactos_movidos] \
			+ "de estado, sobre %d blocos hostis lidos antes e depois da salva" % fl_h.size())
	_assert("o y e arma do alcance: a conta de dois eixos parava o mesmo lance na fileira da frente",
		fresta_h >= 0 and rasa_bate >= 0 and rasa_bate != fresta_bate,
			"com a caixa rasa (andares colados, a lei que o paragrafo 5 derruba) o primeiro corpo na " \
			+ "linha e o bloco %d; com a caixa de verdade e o bloco %d, que e quem o ledger cobrou" % [
				int(fl_h[rasa_bate]["id"]) if rasa_bate >= 0 else -1, bate_id14])
	var gemea_a := _nova_esquadra()
	var gemea_b := _nova_esquadra()
	_marchar_ate_contato(gemea_a, _nucleos(true), _nucleos(false))
	_marchar_ate_contato(gemea_b, _nucleos(true), _nucleos(false))
	var s_a := gemea_a.troca_salva()
	var s_b := gemea_b.troca_salva()
	var ids_a: Array[int] = []
	var ids_b: Array[int] = []
	for pa14 in gemea_a.pares_da_ultima_salva:
		ids_a.append(int((pa14["origem"] as Dictionary)["id"]))
	for pb14 in gemea_b.pares_da_ultima_salva:
		ids_b.append(int((pb14["origem"] as Dictionary)["id"]))
	_assert("o corredor e geometria pura: custo em leituras de casa e duas montadas gemeas iguais",
		leituras == 2 * BLOCOS_POR_LADO * CASAS and ids_a == ids_b \
				and int(s_a.get("lancados", 0)) == int(s_b.get("lancados", 0)) \
				and int(s_a.get("obstruidos", 0)) == int(s_b.get("obstruidos", 0)) \
				and int(s_a.get("rebatidos", 0)) == int(s_b.get("rebatidos", 0)),
			"a salva le %d caixas e %d leituras de casa (2 x %d blocos x %d casas) sem um dado sorteado; " % [
				2 * BLOCOS_POR_LADO, leituras, BLOCOS_POR_LADO, CASAS] \
			+ "gemeas: %d/%d/%d contra %d/%d/%d lancados-tapados-rebatidos, %d pares na mesma ordem" % [
				int(s_a.get("lancados", 0)), int(s_a.get("obstruidos", 0)), int(s_a.get("rebatidos", 0)),
				int(s_b.get("lancados", 0)), int(s_b.get("obstruidos", 0)), int(s_b.get("rebatidos", 0)),
				ids_a.size()])

	print("SONDA-ESQUADRA: veredito - quebras=%d - conferencias=%d" % [breaks, notes.size()])
	for nota in notes:
		print(nota)
	quit(1 if breaks > 0 else 0)
