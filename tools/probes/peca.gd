extends SceneTree
## Sonda da lapidação 4: a peça de quatro cascos.
##
## O queixa do commander é de leitura — «o bloco parece bloco único» — e a causa medida é que o bloco
## tem UMA posição e as vinte e quatro casas são vinte e quatro deslocamentos rígidos dela. Esta sonda
## prova as coisas que tornam a subdivisão honesta: (A) a identidade da peça é a grade que já
## existe, byte a byte; (B) com a peça viva mas sem força, a pintura é a mesma expressão aritmética de
## antes (inércia provada por construção, não por screenshot); (C) a trela segura a excursão e o quadro
## zero da estação é o de hoje; (D) o ar de par de peça nunca fecha; (E) captura só em vaga; (F) a
## frase do commander — arrastar um núcleo não move a estação; (G) o poço come a peça, quatro casas, e
## 35 ≡ 840 continua de pé; (H) censo das leis medindo peça, com zero vetor fora do raio de cada lei;
## (S) a estrela esférica.
##
## Rodadas: A, B, C, D e a parte 1 da H já rodam (tarefas 1 a 4, mais as duas rodadas de fix da 3) — o
## censo abaixo as conta. E, F, G
## (a segunda metade da H é a do poço) e S são as famílias que as tarefas 5 a 9 ligam aqui, e o
## `CENSO_CONFERENCIAS` desta folha é o que roda hoje: quem acrescenta família acrescenta o censo no
## mesmo commit, senão é a asserção final que grita.
##
## Uso: godot --headless --path . --quit-after 1800 -s res://tools/probes/peca.gd

const Esquadra := preload("res://esquadra.gd")

## Folga de soma, espelho de `tools/probes/casas.gd`: `VIDA_DA_CASA` é 100 ÷ 24 e as parcelas somadas
## pelo `_recalcular_agregados` não fecham o produto exato no último dígito. É resolução de double,
## não afrouxamento de portão.
const FOLGA_SOMA := 1e-9

## As 24 casas do bloco como a grade rígida SEMPRE as escreveu, copiadas da aritmética de índice
## anterior à lapidação 4. É a única fonte de verdade da família A e da inércia da família B: as duas
## cobram contra ESTES vetores, nunca contra uma função do próprio módulo — comparar duas rotinas
## que podem estar erradas juntas é a asserção que não pode falhar.
const TABULA_CASA_LOCAL := [
	Vector3(-4.8, -1.6, -1.6), Vector3(-1.6, -1.6, -1.6), Vector3(1.6, -1.6, -1.6),
	Vector3(4.8, -1.6, -1.6), Vector3(-4.8, -1.6, 1.6), Vector3(-1.6, -1.6, 1.6),
	Vector3(1.6, -1.6, 1.6), Vector3(4.8, -1.6, 1.6), Vector3(-4.8, 0.0, -1.6),
	Vector3(-1.6, 0.0, -1.6), Vector3(1.6, 0.0, -1.6), Vector3(4.8, 0.0, -1.6),
	Vector3(-4.8, 0.0, 1.6), Vector3(-1.6, 0.0, 1.6), Vector3(1.6, 0.0, 1.6),
	Vector3(4.8, 0.0, 1.6), Vector3(-4.8, 1.6, -1.6), Vector3(-1.6, 1.6, -1.6),
	Vector3(1.6, 1.6, -1.6), Vector3(4.8, 1.6, -1.6), Vector3(-4.8, 1.6, 1.6),
	Vector3(-1.6, 1.6, 1.6), Vector3(1.6, 1.6, 1.6), Vector3(4.8, 1.6, 1.6)]

## Quantas conferências esta sonda tem de imprimir. É asserção (família final), não rodapé: uma
## família morta por SCRIPT ERROR encolhe a lista e deixa `quebras=0` — o RED da própria Tarefa 3
## mostrou exatamente isso com 5 no lugar de 7. Cadeia medida, por tarefa: 2 (T1, família A) → 5 (T2,
## +censo H) → 7 (T3, +inércia B) → 18 (T4, +voo/trela/ar) → 23 (rodada 1 do fix da T3) → 24 (rodada 2:
## os 24 centros pintados também no bloco hostil, onde `rumo = PI` não é identidade).
const CENSO_CONFERENCIAS := 24

var breaks := 0
var notes: Array[String] = []


func _assert(label: String, condition: bool, detail: String) -> void:
	if condition:
		notes.append("OK   %s — %s" % [label, detail])
	else:
		breaks += 1
		notes.append("QUEBRA %s — %s" % [label, detail])


func _initialize() -> void:
	_familia_identidade()
	_familia_censo()
	await _familia_inercia()
	await _familia_trela_e_ar()
	# O censo é asserção, não rodapé. Uma família que morre por SCRIPT ERROR dentro de `_initialize`
	# encolhe `notes` e deixa `quebras=0` — o portão passaria exatamente no caso em que a sonda não
	# rodou, e foi assim que o RED da Tarefa 3 devolveu 5 conferências no lugar de 7 sem um QUEBRA.
	var antes := notes.size()
	var censo := "%d conferências das famílias + esta = %d esperadas" % [antes, CENSO_CONFERENCIAS]
	_assert("Z censo: a sonda confere as suas %d asserções" % CENSO_CONFERENCIAS,
		antes + 1 == CENSO_CONFERENCIAS,
		censo + " (CENSO_CONFERENCIAS é o número que a rodada imprime, nunca o que a memória lembra)")
	for n in notes:
		print(n)
	print("SONDA-PECA: veredito - quebras=%d - conferencias=%d" % [breaks, notes.size()])
	quit()


## ── Família A: identidade ──
## A cota é a tabela literal `TABULA_CASA_LOCAL`, copiada à mão da definição de `casa_local` anterior
## a esta fatia. Se a soma nova divergir em qualquer ULP de qualquer casa, é esta tabela que grita —
## não uma comparação entre duas funções que podem estar erradas juntas.
func _familia_identidade() -> void:
	var esperada := TABULA_CASA_LOCAL
	var iguais := 0
	for c in range(Esquadra.CASAS):
		var p := Esquadra.peca_da_casa(c)
		var k := c % Esquadra.CASAS_DA_PECA
		var soma: Vector3 = Esquadra.peca_local(p) + Esquadra.casa_na_peca(k)
		if soma == esperada[c] and Esquadra.casa_local(c) == esperada[c]:
			iguais += 1
	_assert("A identidade: casa_local(c) == peca_local(p) + casa_na_peca(k) nas 24 casas",
		iguais == Esquadra.CASAS,
		("%d/24 vetores batem com a tabela literal; peça de c=%d e p=%d, casas de p=0 sao %s" % [
			iguais, 5, 1, str(Esquadra.casas_da_peca(0))]))
	_assert("A peça é a fileira de CASAS_X casas, e as 24 se particionam em 6 sem sobra",
		Esquadra.CASAS_DA_PECA == Esquadra.CASAS_X
			and Esquadra.PECAS_NO_BLOCO * Esquadra.CASAS_DA_PECA == Esquadra.CASAS
			and Esquadra.peca_da_casa(23) == Esquadra.PECAS_NO_BLOCO - 1,
		("PECAS_NO_BLOCO=%d x CASAS_DA_PECA=%d = %d casas, p(23)=%d" % [
			Esquadra.PECAS_NO_BLOCO, Esquadra.CASAS_DA_PECA,
			Esquadra.PECAS_NO_BLOCO * Esquadra.CASAS_DA_PECA, Esquadra.peca_da_casa(23)]))


## ── Família H (parte 1): censo da peça ──
func _familia_censo() -> void:
	var e := Esquadra.new()
	e.montar([Vector3.ZERO], [Vector3(0.0, 0.0, -130.0)])
	var pecas := e.pecas_na_cena()
	var soma_vivas := 0
	for lado in ["aliado", "hostil"]:
		for b in e.lista_de(lado):
			for p in range(Esquadra.PECAS_NO_BLOCO):
				if Esquadra.peca_viva(b, p):
					soma_vivas += 1
	_assert("H censo: cada bloco carrega PECAS_NO_BLOCO peças e a cena devolve as vivas",
		pecas.size() == Esquadra.BLOCOS_NO_LADO * 2 * Esquadra.PECAS_NO_BLOCO
			and soma_vivas == pecas.size(),
		("%d pecas na cena, %d vivas somadas bloco a bloco, %d x %d de 240 blocos x 6" % [
			pecas.size(), soma_vivas, Esquadra.BLOCOS_NO_LADO * 2, Esquadra.PECAS_NO_BLOCO]))
	# O número é MEDIDO, não derivado: quatro casas da fileira dão 3 vãos de PASSO_CASA_X = 3,2 u
	# (9,6 u de casco a casco) mais os 0,912 u de asa da réplica escalada, tudo sobre dois = 5,256 u.
	# Comparar a constante com a expressão que a define seria tautologia — a diferença sairia
	# identicamente zero e a porta nunca cairia. Aqui, mexer na grade ou na caixa do casco quebra.
	_assert("H raio: o raio de cadastro é a metade da fileira medida, asa a asa",
		absf(Esquadra.RAIO_DA_PECA - 5.256) < 0.001,
		("RAIO_DA_PECA=%.3f u contra a fileira medida: 9,6 u de cascos + 0,912 u de caixa, sobre 2" % [
			Esquadra.RAIO_DA_PECA]))
	# A peça morta sai do censo: apagar as quatro casas de p=1 de um bloco aliado tira uma peça do
	# mundo sem tirar o bloco. É o devoramento do poço medido por contagem, antes de existir poço.
	# A porta devolve o próprio buffer (é isso que a faz barata), então a contagem de antes é
	# snapshotada AQUI: segurar o array através de uma segunda chamada é segurar o número de depois.
	var n_antes := pecas.size()
	var b0: Dictionary = e.lista_de("aliado")[0]
	for c in Esquadra.casas_da_peca(1):
		b0["casas"][c]["vida"] = 0.0
	Esquadra._recalcular_agregados(b0)
	var depois := e.pecas_na_cena().size()
	# O `navios` é cobrado, não só impresso: a grade paga VIDA_DA_CASA = 100/24 = 4,1667 navios por
	# casa, então perder CASAS_DA_PECA casas custa 16,667 navios — não o «1/4 de 100 = 25» que o
	# rótulo antigo dizia. Com 20 casas vivas sobram exatamente 83,3333 no agregado.
	_assert("H censo: peça sem casa viva não senta banco na cena, e o bloco continua vivo",
		depois == n_antes - 1 and bool(b0["vivo"])
			and Esquadra.casas_vivas(b0) == Esquadra.CASAS - Esquadra.CASAS_DA_PECA
			and absf(float(b0["navios"])
				- float(Esquadra.CASAS - Esquadra.CASAS_DA_PECA) * Esquadra.VIDA_DA_CASA)
				< FOLGA_SOMA,
		(("cena caiu de %d para %d pecas; bloco com %d casas e navios %.4f "
			+ "(cai %d de %d casas → %.4f navios)") % [
			n_antes, depois, Esquadra.casas_vivas(b0), float(b0["navios"]),
			Esquadra.CASAS_DA_PECA, Esquadra.CASAS,
			float(Esquadra.CASAS_DA_PECA) * Esquadra.VIDA_DA_CASA]))


## ── Auxiliares da família B ──
## O AGRUPAMENTO que `pintar` compõe — `local_base` hoisted uma vez por peça (`peca_local_viva`) mais o
## resíduo de asa da casa — conferido casa a casa contra a tabela literal. Devolve quantos dos 24
## vetores de mundo batem byte a byte. É função separada porque a mesma régua corre nos dois lados:
## só o aliado tem `rot` = identidade, e é no hostil (`rumo = PI`) que a ordem das somas tem
## consequência de float32. É imitação deliberada do corpo de `pintar` (o contrato do hoist está no doc
## dele, em `esquadra.gd`), não chamada: chamar `pintar` exigiria ler o `MultiMesh`, e a medição de
## 31/10 acima prova que sob `--headless` a leitura devolve zero.
func _centros_contra_a_tabela(b: Dictionary) -> int:
	var rot := Basis.from_euler(Vector3(0.0, float(b["rumo"]), 0.0))
	var origem: Vector3 = b["pos"]
	var igual := 0
	for c in range(Esquadra.CASAS):
		var pintada: Vector3 = origem + rot * (Esquadra.peca_local_viva(b, Esquadra.peca_da_casa(c))
			+ Esquadra.casa_na_peca(c % Esquadra.CASAS_DA_PECA))
		if pintada == origem + rot * TABULA_CASA_LOCAL[c]:
			igual += 1
	return igual


## A pior diferença relativa de tamanho entre duas caixas, eixo a eixo (|Δtamanho| / tamanho). É
## relativa de propósito: o grão do float32 escala com a coordenada de mundo envolvida na subtração
## que o `AABB.merge` refaz, então só a razão sobre o tamanho é comparável entre cenários.
func _razao_de_ruido(a: AABB, h: AABB) -> float:
	var pior := 0.0
	for eixo in range(3):
		var t: float = a.size[eixo]
		if t <= 0.0:
			return INF
		pior = maxf(pior, absf(a.size[eixo] - h.size[eixo]) / t)
	return pior


## ── Família B: inércia ──
## O portão que a regra da casa (`godot-subdivision-inert-identity-proof`, passo 3) manda fechar. Esta
## folha cobra DUAS superfícies por asserção própria — PINTURA e CAIXA DE COLISÃO — e a terceira, a
## MIRA, pelo mesmo termo: ela lê `casa_local_viva`, a mesma expressão cobrada abaixo, então o risco que
## a regra nomeia («a mira ler a rígida enquanto a pintura lê a peça») está morto por construção. O
## COMPORTAMENTO da mira — a ordem de proximidade das 24 casas — não é cego: quem o assereciona é a
## sonda `tools/probes/casas.gd`, na lei da convergência dos canos (`casas.gd:364`), no enxugo de campo
## (`:372`) e no concentrar-vs-dispersar (`:386`). Dizer o contrário aqui seria a folha prometer um
## degrau a mais do que entrega.
##
## 1. Nenhuma superfície é lida do `MultiMesh`. Medido nesta casa em 31/10 com `_tmp_leitura_mm.gd`:
## sob `--headless` o motor NÃO devolve a transformada escrita — a pintura tocou os 120 blocos
## (`tocados=120`, 2 880 instâncias) e a instância 0 pediu `-95,652, -7,419, -52,600` e devolveu
## `0, 0, 0`. Cobrar "transformado lido == tabela" aqui seria um portão que passa porque os DOIS lados
## leem zero. A leitura de que o quadro mudou é do commander na janela (Tarefa 10).
## 2. Toda conta é cobrada contra `TABULA_CASA_LOCAL`, a tabela literal, e a família ainda prova que
## SABE FALHAR: com uma peça empurrada para fora do posto, as casas dela têm de deixar de bater.
func _familia_inercia() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate()
	# Precondition declarada no criador do estado, nunca na tolerância: `esquadra` nasce no construtor de
	# `main.gd`, e esta linha é a primeira coisa que ele recebe antes de entrar na árvore. Desde a
	# Tarefa 4 o default da alavanca é LIGADO (é a lei nova), e esta família cobra o regime contrário —
	# a muralha rígida, os 1 440 `desloc` em ZERO. Medir inércia com o voo rodando seria medir outra
	# coisa; desligar aqui é o que deixa a asserção cobrando os mesmos números de antes.
	game.esquadra.pecas_livres = false
	get_root().add_child(game)
	await _frames(3)
	var e: Esquadra = game.esquadra
	var zero := 0
	var total := 0
	for lado in ["aliado", "hostil"]:
		for b in e.lista_de(lado):
			for pc in b["pecas"]:
				total += 1
				if (pc["desloc"] as Vector3) == Vector3.ZERO:
					zero += 1
	# O censo pela constante do lado, não pelo 240 escrito à mão: a família H deste mesmo arquivo já
	# tem a fonte, e duas fontes para o mesmo número é como se descobre tarde que ele mudou.
	var censo := 2 * Esquadra.BLOCOS_NO_LADO * Esquadra.PECAS_NO_BLOCO
	_assert("B inercia: a cena montou o censo da muralha, contado pelas constantes do lado",
		total == censo,
		("%d pecas na cena contra 2 x BLOCOS_NO_LADO(%d) x PECAS_NO_BLOCO(%d) = %d" % [
			total, Esquadra.BLOCOS_NO_LADO, Esquadra.PECAS_NO_BLOCO, censo]))
	# A excursão é a asserção separada, com a alavanca como conjuncto seu: se a Tarefa 4 afrouxar o
	# default e alguém esquecer a precondition de cima, o que quebra é esta linha, e ela nomeia a
	# alavanca — não um censo que de repente depende de quantos blocos foram expelidos nos 3 quadros.
	_assert("B inercia: com a alavanca desligada, nenhuma peça da cena tem excursão",
		not e.pecas_livres and zero == total,
		("%d/%d pecas com desloc exatamente ZERO, alavanca=%s" % [zero, total, str(e.pecas_livres)]))
	# A pintura, cobrada pelo AGRUPAMENTO que `pintar` compõe (`local_base` hoisted por peça, mais o
	# resíduo da casa) contra a tabela literal. Não contra `casa_local`: esta folha chamou a si mesma
	# de `peca_local + casa_na_peca` na Tarefa 1, e comparar a expressão com ela mesma dá 24/24 por
	# construção, que é a asserção que não pode falhar. O hoist é contrato declarado no doc de `pintar`
	# (`esquadra.gd`), e esta régua é o leitor dele: mudou o agrupamento lá, muda aqui no mesmo commit.
	var b0: Dictionary = e.lista_de("aliado")[0]
	var origem: Vector3 = b0["pos"]
	var rot := Basis.from_euler(Vector3(0.0, float(b0["rumo"]), 0.0))
	var igual_a := _centros_contra_a_tabela(b0)
	_assert("B inercia: o agrupamento que a pintura compõe é a tabela literal nos 24 vetores de mundo",
		igual_a == Esquadra.CASAS,
		"%d/24 vetores byte-idênticos contra TABULA_CASA_LOCAL no bloco aliado 0 (rumo %s)" % [
			igual_a, str(b0["rumo"])])
	# O mesmo laço no lado hostil, que é o único onde a ressociação pode mover 1 ULP: lá o `rumo` é PI,
	# então `rot` não é identidade exata e a ordem das somas tem consequência de ponto flutuante. Sem
	# esta asserção, a pintura seria cobrada só no lado onde girar não faz nada — a razão de existir do
	# degrau da caixa logo abaixo, que nasceu justamente porque os dois blocos não fecham bit a bit.
	var bh: Dictionary = e.lista_de("hostil")[0]
	var igual_h := _centros_contra_a_tabela(bh)
	_assert("B inercia: o mesmo agrupamento bate a tabela no hostil, onde rumo = PI não é identidade",
		igual_h == Esquadra.CASAS,
		"%d/24 vetores byte-idênticos contra TABULA_CASA_LOCAL no bloco hostil 0 (rumo %s)" % [
			igual_h, str(bh["rumo"])])
	# A metade que faltava: a mesma conta, com uma peça fora do posto, TEM de deixar de bater. Empurrada
	# 0,5 u em boreste (dentro da trela de 1,2, então o clamp não interfere), as quatro casas de p=0
	# viram outras tantas divergências. Sem esta asserção, a de cima é indistinguível de álgebra de
	# mesa que passa por construção — foi exatamente assim que a revisão pegou a versão antiga.
	e.empurrar_peca(b0, 0, Vector3(0.5, 0.0, 0.0))
	var caiu := 0
	for c in Esquadra.casas_da_peca(0):
		var local_voada: Vector3 = Esquadra.peca_local_viva(b0, Esquadra.peca_da_casa(c))
		var pintada_voada: Vector3 = origem + rot * (local_voada
			+ Esquadra.casa_na_peca(c % Esquadra.CASAS_DA_PECA))
		if pintada_voada != origem + rot * TABULA_CASA_LOCAL[c]:
			caiu += 1
	# A sonda RESTAURA o posto aqui, e esta linha é escrita antes da asserção de baixo: o que ela prova
	# é só que a divergência apareceu (e, por tabela, que `desloc` entra no termo — se alguém tirar
	# `desloc` de `peca_local_viva`, `caiu` vira 0 e o RED vem buscar). Que a LEI DE VOO pousa a peça de
	# volta na vaga é a família C, e lá a medição é de verdade: 900 quadros de `passo` entre o empurrão
	# e a leitura (`peca.gd` «C voo»). Cobrar o devolvimento daqui seria ler ZERO logo depois de ter
	# escrito ZERO — um conjuncto que não pode falhar, e um detalhe impresso que atribuiria ao clamp da
	# trela uma restauração feita pela própria linha acima.
	(b0["pecas"][0] as Dictionary)["desloc"] = Vector3.ZERO
	_assert("B inercia: a asserção da pintura sabe falhar — peça fora do posto derruba as casas dela",
		caiu == Esquadra.CASAS_DA_PECA,
		("empurrão de 0,5 u em boreste mudou %d/%d casas de p=0 contra a tabela" % [
			caiu, Esquadra.CASAS_DA_PECA]))
	# A segunda superfície do degrau: a CAIXA de colisão. Cobrada aqui, e não de raspão na família D,
	# porque a regra da casa avisa: se um eixo ficar partido entre os dois lados, a igualdade passa a
	# depender de ruído de float32 e a FOLGA tem de ser declarada na asserção, com o número medido ao
	# lado. Medido nesta rodada, eixo a eixo: x = 0, y = 0, z = 1,525878906e-5 u. O valor É exatamente
	# 2⁻¹⁶, o grão do float32 para coordenadas entre 128 e 256 u, e a asserção imprime as posições dos
	# dois blocos para a banda ser conferível no log. A origem é a subtração de duas posições de mundo
	# grandes dentro do `uniao = uniao.merge(caixa)` de `caixa_do_bloco` (`esquadra.gd`, que refaz o
	# tamanho como `máx(fim) − mín(posição)`), e NÃO o `sin(PI)` do rumo hostil: 1,22e-16 vezes um
	# braço de 4,8 u dá 5,9e-16, três ordens abaixo do grão, e some na soma.
	# Por isso a folga é RELATIVA ao tamanho de cada eixo (1e-5) em vez de um absoluto: o piso de ruído
	# escala com a distância do bloco à origem, então um teto fixo quebraria por geometria de cenário
	# (posições acima de ~1 024 u têm grão de 1,2e-4 e passariam de um 1e-4 sozinho). Contra os
	# tamanhos publicados (10,51 × 3,467 × 4,45 u) a folga relativa vale 1,05e-4 / 3,47e-5 / 4,45e-5:
	# mais APERTADA que 1e-4 nos dois eixos curtos, e o resíduo medido fica a ~3× do teto do z.
	# O que quebraria de verdade: uma peça que entra na união de um lado e não do outro move a
	# extensão por um passo de grade — 1,6 u em y, 3,2 u em x/z, razão ~0,46 — quatro ordens acima.
	var caixa_a := e.caixa_do_bloco(b0)
	var cobertura := 0
	for c in range(Esquadra.CASAS):
		if caixa_a.has_point(origem + rot * Esquadra.casa_local_viva(b0, c)):
			cobertura += 1
	var caixa_h := e.caixa_do_bloco(bh)
	var pior := _razao_de_ruido(caixa_a, caixa_h)
	_assert("B inercia: a caixa do bloco cobre os 24 centros que a pintura escreve",
		cobertura == Esquadra.CASAS,
		("%d/24 centros dentro de %.2f x %.2f x %.2f u" % [
			cobertura, caixa_a.size.x, caixa_a.size.y, caixa_a.size.z]))
	_assert("B inercia: a caixa hostil só difere da aliada pelo grão de float32 da posição de mundo",
		pior < 1e-5,
		("pior razao de ruido entre eixos = %s do tamanho (teto 1e-5); pos aliada %s, hostil %s; "
			+ "dsize %s / %s / %s u, caixa aliada (%.4f, %.4f, %.4f)") % [
			pior, str((b0["pos"] as Vector3)), str((bh["pos"] as Vector3)),
			absf(caixa_a.size.x - caixa_h.size.x), absf(caixa_a.size.y - caixa_h.size.y),
			absf(caixa_a.size.z - caixa_h.size.z),
			caixa_a.size.x, caixa_a.size.y, caixa_a.size.z])
	game.queue_free()


## ── Família C (trela) e D (ar) ──
## A folga é ±1,2/0,6/0,9, e a tabela de ar publicada é de grade SEM excursão: com os dois vizinhos de
## grade no extremo oposto da trela os pisos analíticos caem para 0,088 (x) / 7,333 (y) / 0,750 (z) u —
## os três números que a asserção do piso imprime. Por isso D cobra duas asserções distintas e nenhuma
## delas afrouxa a antiga: o ar do par intra-bloco medido quadro a quadro tem de ser estritamente
## positivo (é a garantia da construção), e o piso entre blocos vizinhos com excursão extrema oposta
## também. A tabela publicada de ar continua sendo cobrada pela família 2 da sonda `esquadra.gd`, régua
## de bloco com `AR_MINIMO = 2,4`, que passa com a alavanca ligada porque nenhuma daquelas famílias
## empurra peça para fora da trela: onde nenhuma força age, a excursão é zero e o ar é o de grade.
func _familia_trela_e_ar() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	await _frames(3)
	var e: Esquadra = game.esquadra
	e.pecas_livres = true
	# O empurrão que dá material à folha: uma peça lançada para fora do posto pela porta da lei
	# (`empurrar_peca`, que já clampa na trela) é o único jeito de `pior` não ser o três-zero de um lote
	# que nunca integrou. É o caso que a nota da Tarefa 3 deixou pendurado: sem força nenhuma, o verde de
	# C é indistinguível de laço ausente.
	var bloco_empurrado: Dictionary = e.lista_de("aliado")[0]
	e.empurrar_peca(bloco_empurrado, 0, Vector3(2.0, 0.0, 0.0))
	var antes: Vector3 = (bloco_empurrado["pecas"][0] as Dictionary)["desloc"]
	var pior := Vector3(-1.0, -1.0, -1.0)
	var leitura := 0
	var ar_min := 1e9
	var onde := "nenhum par medido"
	for f in range(900):
		game._process(1.0 / 60.0)
		for lado in ["aliado", "hostil"]:
			for b in e.lista_de(lado):
				for p in range(Esquadra.PECAS_NO_BLOCO):
					var pc: Dictionary = b["pecas"][p]
					var d: Vector3 = pc["desloc"]
					var vaga: Vector3 = pc["vaga"]
					pior.x = maxf(pior.x, absf(d.x - vaga.x))
					pior.y = maxf(pior.y, absf(d.y - vaga.y))
					pior.z = maxf(pior.z, absf(d.z - vaga.z))
					leitura += 1
				# Os sete pares únicos de peça viva dentro do bloco (14 chamadas direcionadas de
				# `vizinhos_locais_da_peca`, filtradas em `q > p`): é aqui que o ar é apertado (1,332 u em y,
				# 1,950 u em z) e é aqui que a peça anda. Caixa de peça, não raio de esfera — a fileira tem
				# 10,5 u de asa e medir distância de centro com `RAIO_DA_PECA` daria negativo sempre.
				for p in range(Esquadra.PECAS_NO_BLOCO):
					if not Esquadra.peca_viva(b, p):
						continue
					var ca := e.caixa_da_peca(b, p)
					if not ca.has_volume():
						continue
					for q in Esquadra.vizinhos_locais_da_peca(p):
						if q <= p or not Esquadra.peca_viva(b, q):
							continue
						var cb := e.caixa_da_peca(b, q)
						if not cb.has_volume():
							continue
						var ar := _ar_entre_caixas(ca, cb)
						if ar < ar_min:
							ar_min = ar
							onde = "bloco %d p%d/p%d salva %d" % [int(b["id"]), p, q, e.salva_numero]
	# O caso carregado da Tarefa 3, e a premissa do verde abaixo: o posto perseguido com a vaga zerada é
	# um ponto FIXO da trela, então `pior=(0,0,0)` passa tanto com a lei rodando quanto sem ela. Dito e
	# medido aqui, não presumido.
	_assert("C trela: o três-zero é ponto fixo (apertar_na_trela(ZERO, ZERO) == ZERO)",
		Esquadra.apertar_na_trela(Vector3.ZERO, Vector3.ZERO) == Vector3.ZERO,
		("devolvido %s; é o posto que as 1 440 peças perseguem com a vaga zerada" % [
			str(Esquadra.apertar_na_trela(Vector3.ZERO, Vector3.ZERO))]))
	_assert("C trela: nenhuma excursão passou da folga em nenhum eixo em 900 quadros",
		pior.x <= Esquadra.FOLGA_DA_PECA.x + 0.0001
			and pior.y <= Esquadra.FOLGA_DA_PECA.y + 0.0001
			and pior.z <= Esquadra.FOLGA_DA_PECA.z + 0.0001,
		("max |desloc-vaga| = (%.3f, %.3f, %.3f) contra a folga (%.1f, %.1f, %.1f) em %d leituras" % [
			pior.x, pior.y, pior.z, Esquadra.FOLGA_DA_PECA.x, Esquadra.FOLGA_DA_PECA.y,
			Esquadra.FOLGA_DA_PECA.z, leitura]))
	var depois: Vector3 = (bloco_empurrado["pecas"][0] as Dictionary)["desloc"]
	# A outra metade do portão: a trela morde o empurrão de 2,0 u em 1,2 (o clamp da porta, eixo a eixo)
	# e o VOO devolve a peça ao posto exato — o que só acontece se `passo` chamar `_passo_das_pecas`. Sem
	# o laço a peça fica colada em 1,2 para sempre e esta asserção quebra: é ele que não deixa a família
	# C acima aprovar um voo que não existe.
	_assert("C voo: o empurrão bate na folga e a lei de voo pousa a peça de volta na vaga",
		absf(antes.x) == Esquadra.FOLGA_DA_PECA.x and depois == Vector3.ZERO,
		("empurrada a 2,0 u em boreste => desloc %.3f (trela %.1f); após os 900 quadros => %s" % [
			antes.x, Esquadra.FOLGA_DA_PECA.x, str(depois)]))
	_assert("D ar intra-bloco: o par de peça mais apertado do lote inteiro nunca fechou",
		ar_min > 0.0,
		("minimo medido %.3f u em %s, com a folga viva dos dois lados" % [ar_min, onde]))
	# O piso analítico entre BLOCOS vizinhos: o ar publicado menos as duas metades de folga, por eixo.
	# É conta sobre constantes, e os três números saem impressos — se algum fechar, a folga daquele eixo
	# está errada e é ela que se corrige, nunca o portão.
	var x := Esquadra.PASSO_BLOCO_X - 10.512 - 2.0 * Esquadra.FOLGA_DA_PECA.x
	var z := Esquadra.PASSO_BLOCO_Z - 4.450 - 2.0 * Esquadra.FOLGA_DA_PECA.z
	var y := Esquadra.PASSO_ESQUADRAO_Y - 3.467 - 2.0 * Esquadra.FOLGA_DA_PECA.y
	_assert("D ar entre blocos: com os dois vizinhos no extremo oposto da trela ainda sobra ar",
		x > 0.0 and z > 0.0 and y > 0.0,
		("pisos analíticos x=%.3f (de 2,488 publicado) z=%.3f (de 2,550) y=%.3f (de 8,533)" % [x, z, y]))
	# A segunda asserção prometida pelo desvio 1 da folha de plano: a TABELA PUBLICADA do §4, recontada
	# com a excursão zerada. É a régua que a família 2 de `esquadra.gd` já cobra em bloco; aqui ela é
	# coberta na escala de peça, e por isso é conta sobre as constantes da grade, não medida de quadro.
	# Os seis pares do §4, cada um `passo − caixa`, com o literal publicado ao lado: se a subdivisão
	# mexeu em passo ou caixa qualquer, é aqui que o número deixa de bater.
	var pares := [
		["casa-casa x (dentro da peça)", Esquadra.PASSO_CASA_X - 0.912, 2.288],
		["casa-casa z (dentro do bloco)", Esquadra.PASSO_CASA_Z - 1.25, 1.95],
		["casa-casa y (dentro do bloco)", Esquadra.PASSO_CASA_Y - 0.268, 1.332],
		["bloco-bloco x (na fileira)", Esquadra.PASSO_BLOCO_X - 10.512, 2.488],
		["fileira-fileira z", Esquadra.PASSO_BLOCO_Z - 4.45, 2.55],
		["andar-andar y", Esquadra.PASSO_ESQUADRAO_Y - 3.467, 8.533],
	]
	for par in pares:
		_assert("D tabela publicada: %s = %.3f u com a excursão zerada" % [par[0], par[2]],
			absf(float(par[1]) - float(par[2])) < 0.001,
			("recalcado %.4f contra o publicado %.4f" % [float(par[1]), float(par[2])]))
	game.queue_free()


## Distância entre duas AABBs de mundo: 0 se se encostam ou sobrepõem, senão a norma dos vãos por eixo.
func _ar_entre_caixas(a: AABB, b: AABB) -> float:
	var dx := maxf(0.0, maxf(b.position.x - (a.position.x + a.size.x),
		a.position.x - (b.position.x + b.size.x)))
	var dy := maxf(0.0, maxf(b.position.y - (a.position.y + a.size.y),
		a.position.y - (b.position.y + b.size.y)))
	var dz := maxf(0.0, maxf(b.position.z - (a.position.z + a.size.z),
		a.position.z - (b.position.z + b.size.z)))
	return Vector3(dx, dy, dz).length()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame
