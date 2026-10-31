extends SceneTree
## Sonda da lapidação 4: a peça de quatro cascos.
##
## O queixa do commander é de leitura — «o bloco parece bloco único» — e a causa medida é que o bloco
## tem UMA posição e as vinte e quatro casas são vinte e quatro deslocamentos rígidos dela. Esta sonda
## prova as três coisas que tornam a subdivisão honesta: (A) a identidade da peça é a grade que já
## existe, byte a byte; (B) com a peça viva mas sem força, a pintura é a mesma expressão aritmética de
## antes (inércia provada por construção, não por screenshot); (C) a trela segura a excursão e o quadro
## zero da estação é o de hoje; (D) o ar de par de peça nunca fecha; (E) captura só em vaga; (F) a
## frase do commander — arrastar um núcleo não move a estação; (G) o poço come a peça, quatro casas, e
## 35 ≡ 840 continua de pé; (H) censo das leis medindo peça, com zero vetor fora do raio de cada lei.
##
## Uso: godot --headless --path . --quit-after 1800 -s res://tools/probes/peca.gd

const Esquadra := preload("res://esquadra.gd")

## Folga de soma, espelho de `tools/probes/casas.gd`: `VIDA_DA_CASA` é 100 ÷ 24 e as parcelas somadas
## pelo `_recalcular_agregados` não fecham o produto exato no último dígito. É resolução de double,
## não afrouxamento de portão.
const FOLGA_SOMA := 1e-9

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
	for n in notes:
		print(n)
	print("SONDA-PECA: veredito - quebras=%d - conferencias=%d" % [breaks, notes.size()])
	quit()


## ── Família A: identidade ──
## A cota é uma tabela literal de 24 vetores, escrita à mão a partir da definição de `casa_local`
## anterior a esta fatia. Se a soma nova divergir em qualquer ULP de qualquer casa, é esta tabela que
## grita — não uma comparação entre duas funções que podem estar erradas juntas.
func _familia_identidade() -> void:
	var esperada := [
		Vector3(-4.8, -1.6, -1.6), Vector3(-1.6, -1.6, -1.6), Vector3(1.6, -1.6, -1.6),
		Vector3(4.8, -1.6, -1.6), Vector3(-4.8, -1.6, 1.6), Vector3(-1.6, -1.6, 1.6),
		Vector3(1.6, -1.6, 1.6), Vector3(4.8, -1.6, 1.6), Vector3(-4.8, 0.0, -1.6),
		Vector3(-1.6, 0.0, -1.6), Vector3(1.6, 0.0, -1.6), Vector3(4.8, 0.0, -1.6),
		Vector3(-4.8, 0.0, 1.6), Vector3(-1.6, 0.0, 1.6), Vector3(1.6, 0.0, 1.6),
		Vector3(4.8, 0.0, 1.6), Vector3(-4.8, 1.6, -1.6), Vector3(-1.6, 1.6, -1.6),
		Vector3(1.6, 1.6, -1.6), Vector3(4.8, 1.6, -1.6), Vector3(-4.8, 1.6, 1.6),
		Vector3(-1.6, 1.6, 1.6), Vector3(1.6, 1.6, 1.6), Vector3(4.8, 1.6, 1.6)]
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


## ── Família B: inércia ──
## O headless não lê o `MultiMesh` de volta, então esta família prova a igualdade pelas duas premissas
## que a compõem: a algebraica (a soma dos dois termos é `casa_local`, tabela literal da família A) e a
## fisica (com a alavanca desligada, os 1 440 `desloc` são exatamente ZERO, e a transformada escrita é
## a mesma expressão de antes, bit a bit). A leitura de que o quadro mudou é do commander na janela
## (Tarefa 10) — afirmar "pixel idêntico" medido em headless seria o portão falhando aberto.
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
	_assert("B inercia: com a alavanca desligada, nenhuma peça tem excursão",
		not e.pecas_livres and total == 240 * Esquadra.PECAS_NO_BLOCO and zero == total,
		("%d/%d pecas com desloc exatamente ZERO, alavanca=%s" % [zero, total, str(e.pecas_livres)]))
	# O outro lado da premissa: os leitores novos dão o mesmo valor dos velhos, medido contra a
	# expressão anterior ainda viva em `casa_local` (que a Tarefa 1 re-definiu como a soma).
	var igual := 0
	var b0: Dictionary = e.lista_de("aliado")[0]
	var rot := Basis.from_euler(Vector3(0.0, float(b0["rumo"]), 0.0))
	var origem: Vector3 = b0["pos"]
	for c in range(Esquadra.CASAS):
		var p := Esquadra.peca_da_casa(c)
		var somado: Vector3 = origem + rot * (Esquadra.peca_local(p)
			+ Esquadra.casa_na_peca(c % Esquadra.CASAS_DA_PECA))
		if somado == origem + rot * Esquadra.casa_local(c):
			igual += 1
	_assert("B inercia: a conta nova da pintura é a conta velha, nos 24 vetores de mundo",
		igual == Esquadra.CASAS, "%d/24 vetores de mundo byte-idênticos" % igual)
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
				# Os quinze pares de peça viva dentro do bloco: é aqui que o ar é apertado (1,332 u em y,
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
