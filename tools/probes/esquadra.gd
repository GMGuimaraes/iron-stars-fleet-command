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
##    tocados; com um quadro de marcha devolve os duzentos e quarenta, e em duzentos quadros de
##    marcha devolve quarenta e oito mil. O portão é essa CONTA, que é determinística. O relógio é
##    impresso como medida, não como lei: a mesma máquina deu 761, 918 e 1 287 ms para os mesmos
##    duzentos quadros em três rodadas seguidas — com ±35 % de ruído, nenhum número de `ms` pode
##    ser assinado aqui, e a asserção antiga (`custo_ms >= 0.0`) não podia reprovar nada.
## 9) A PONTE MOSTRA A MASSA E A RODA DÁ ZOOM. Dois nós `MultiMeshInstance3D` na cena, malha única
##    compartilhada, a caixa crua lida da própria malha (3,647 x 1,07 x 5,0) fechando a boca em
##    0,912 u dentro da casa de 3,2 — 2,288 u de costura no costado e 1,95 u de proa a popa, lidos do
##    `AABB` da malha nos dois eixos horizontais: é o número que decide se a fileira se lê como
##    fileira, e ele vem da malha, nunca do cabeçalho, `use_colors` +
##    `vertex_color_use_as_albedo` ligados (esquecer um dos dois é a massa inteira cinza), caixa de
##    desenho autorgada cobrindo o campo, a roda levando a FOV de 78° a 14° com aperto nas duas
##    pontas, e o letreiro da massa sendo `Label` — os 35 botões de `menu.gd` não se mexem.
## 10) A LARGADA TEM CAMPO E ELE É CRUZADO MARCHANDO. As duas fachadas nascem a 154,0 u uma da outra e
##     fecham exatamente em `DISTANCIA_DE_CONTATO` (40 u) sob `MARCHA_DE_BLOCO`: o maior deslocamento
##     de um bloco em um quadro é o passo da marcha, o vão nunca fica abaixo do contato, e a travessia
##     leva 19,0 s de tela. O recuo tem prova contrafactual — com a estação em zero a grade sozinha
##     deixa 24,0 u de fachada a fachada, MENOS que o próprio contato e longe de qualquer travessia.
##     É a régua que desmente a conta de cabeça desta sessão: o campo não é comprado pelo ar entre
##     blocos, é comprado pelo recuo, e sem esta asserção "abrir o ar" passaria como se tivesse feito
##     a aproximação sozinha.
##
## Uso: godot --headless --path . --quit-after 6000 -s res://tools/probes/esquadra.gd

const Esquadra := preload("res://esquadra.gd")

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
## Ar mínimo entre os cascos mais próximos de dois blocos vizinhos do mesmo lado. Com o passo antigo
## de 8 × 5 isto aqui valia 0,7 u e a muralha não tinha emenda.
const AR_MINIMO := 2.4
const PONTE_FOV_LARGO := 78.0
const PONTE_FOV_FECHADO := 14.0
## Folga de coordenada: a grade é contagem exata, mas `move_toward` deixa resto de ponto flutuante.
const FOLGA := 0.1
## A travessia: 114,0 u de marcha (154,0 − 40,0) a 6 u/s chegam ao contato em 1.140 quadros. 600 é
## "no meio do campo"; 1.200 é a conta já fechada, com folga. O teto de um quadro é o passo da
## marcha — campo cruzado de salto não é aproximação, é teleporte.
const QUADROS_A_MEIO := 600
const QUADROS_DA_TRAVESSIA := 1200
const SALTO_MAXIMO := Esquadra.MARCHA_DE_BLOCO / 60.0
## Campo lido na largada, de fachada a fachada: os 130 u de recuo mais os 45 u de separação dos doze
## núcleos, menos o braço de cada muralha até sua fileira frontal (2 × 10,5 u de centro de casco).
## Conta que a família 10 mede e o README cita — é a régua do "espaço a ser cruzado".
const CAMPO_ESPERADO := 154.0
## Tolerância da fachada: a marcha fecha em `move_toward` e o centro de casa não é régua exata.
const FOLGA_CONTATO := 1.0
const QUADROS := 200
const SALVAS := 60
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
	var inicio_ms := Time.get_ticks_msec()
	var w := 0
	while w < QUADROS:
		# O avanço vem ANTES do passo: com o primeiro quadro no mesmo pé da monta, a esquadra aliada
		# já está colada no próprio posto, nenhum bloco se move, e a régua devolve 47 880 em vez de
		# 48 000 — que é a contagem correta de uma frota que patinou um quadro, não de uma em marcha.
		custo_quadros -= 0.05
		var nuc_movidos: Array = []
		for n in nuc_a:
			nuc_movidos.append((n as Vector3) + Vector3(0.0, 0.0, custo_quadros))
		p.passo(1.0 / 60.0, nuc_movidos, nuc_h)
		escritas += p.pintar(mm_p, "aliado", false) + p.pintar(mm_q, "hostil", false)
		w += 1
	var custo_ms := float(Time.get_ticks_msec() - inicio_ms)
	var casas_por_quadro := 2 * INSTANCIAS_POR_LADO
	var casas_ms := float(QUADROS * casas_por_quadro) / maxf(custo_ms, 1.0)
	# O relógio saiu do portão, não do log. Três rodadas do MESMO código nesta máquina fecharam os
	# mesmos duzentos quadros em 761, 918 e 1 287 ms — ±35 % de ruído, com um `godot.exe` pendurado
	# de outra sessão comendo núcleo — e a asserção antiga (`custo_ms >= 0.0`) não podia reprovar
	# nada. O que é determinístico é a conta de escritas: marcha em curso tem de repintar os
	# duzentos e quarenta blocos em todo quadro, e é isso que a lei cobra. O `ms` continua impresso,
	# como medida, com o intervalo das rodadas escrito no README.
	_assert("%d quadros de marcha repintam os duzentos e quarenta blocos, sem excecao" % QUADROS,
		escritas == QUADROS * 2 * BLOCOS_POR_LADO,
			"%d escritas de bloco contra %d esperadas; %.3f ms por quadro (%d ms no total, %d casas/ms) - relógio impresso, nao portado" % [
				escritas, QUADROS * 2 * BLOCOS_POR_LADO, custo_ms / float(QUADROS), int(custo_ms),
				int(casas_ms)])

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
		"20 voltas para cima -> %.2f, 40 para baixo -> %.2f, clique esquerdo nao moveu (%.2f)" % [
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
	var salto_max := 0.0
	var menor_fachada := fachada
	var fachada_meio := 0.0
	var mf := 0
	while mf < QUADROS_DA_TRAVESSIA:
		var antes: Array = []
		for b in t.lista_de("hostil"):
			antes.append(b["pos"])
		t.passo(1.0 / 60.0, nuc_a, nuc_h)
		var ki := 0
		for b in t.lista_de("hostil"):
			salto_max = maxf(salto_max, (b["pos"] as Vector3).distance_to(antes[ki] as Vector3))
			ki += 1
		menor_fachada = minf(menor_fachada, _fachadas(t))
		if mf == QUADROS_A_MEIO:
			fachada_meio = _fachadas(t)
		mf += 1
	var segundos := float(QUADROS_DA_TRAVESSIA) / 60.0
	_assert("a marcha nao salta: o maior deslocamento de um bloco em um quadro e o passo da marcha",
		salto_max <= SALTO_MAXIMO + 0.0001,
		"%d quadros de travessia (~%.0f s de tela): maior passo de um bloco em %.4f u, teto %.4f u" % [
			QUADROS_DA_TRAVESSIA, segundos, salto_max, SALTO_MAXIMO])
	_assert("dez segundos de campo custam dez segundos de marcha: nao ha ease nem salto",
		absf((fachada - fachada_meio) - float(QUADROS_A_MEIO) * SALTO_MAXIMO) < 1.0 \
			and fachada_meio > Esquadra.DISTANCIA_DE_CONTATO,
		"apos %d quadros (%.0f s) a fachada anda %.1f u e ainda ha %.1f u por cruzar" % [
			QUADROS_A_MEIO, float(QUADROS_A_MEIO) / 60.0, fachada - fachada_meio, fachada_meio])
	_assert("a travessia para no contato: nunca encosta, nunca atravessa",
		absf(_fachadas(t) - Esquadra.DISTANCIA_DE_CONTATO) < FOLGA_CONTATO \
			and menor_fachada >= Esquadra.DISTANCIA_DE_CONTATO - FOLGA_CONTATO,
		"fachada final %.1f u (minima vista %.1f u, contato %.0f u, alcance %.0f u)" % [
			_fachadas(t), menor_fachada, Esquadra.DISTANCIA_DE_CONTATO, Esquadra.ALCANCE_DE_BLOCO])
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

	print("SONDA-ESQUADRA: veredito - quebras=%d - conferencias=%d" % [breaks, notes.size()])
	for nota in notes:
		print(nota)
	quit(1 if breaks > 0 else 0)
