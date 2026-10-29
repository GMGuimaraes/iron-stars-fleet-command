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
	_assert("H raio: o raio de cadastro é a metade da fileira medida, asa a asa",
		absf(Esquadra.RAIO_DA_PECA - (float(Esquadra.CASAS_DA_PECA - 1) * Esquadra.PASSO_CASA_X
			+ 0.912) / 2.0) < 0.001,
		("RAIO_DA_PECA=%.3f u para uma fileira de %.1f u de cascos + 0,912 de caixa" % [
			Esquadra.RAIO_DA_PECA, float(Esquadra.CASAS_DA_PECA - 1) * Esquadra.PASSO_CASA_X]))
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
	_assert("H censo: peça sem casa viva não senta banco na cena, e o bloco continua vivo",
		depois == n_antes - 1 and bool(b0["vivo"])
			and Esquadra.casas_vivas(b0) == Esquadra.CASAS - Esquadra.CASAS_DA_PECA,
		("cena caiu de %d para %d pecas; bloco com %d casas e navios %.4f (cai 1/4 de 100)" % [
			n_antes, depois, Esquadra.casas_vivas(b0), float(b0["navios"])]))
