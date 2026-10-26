extends SceneTree

## Sonda da casa-corpo: a nave desenhada passou a ter vida e placa próprias, e o tiro individual
## cobra nelas. O que ela prova é a escala (nada se move somado sobre o bloco), a derivação (`navios`
## é conseqüência), a morte visível (nenhuma casa apaga sem traço), o comando (concentrar afunda casa
## mais cedo que dispersar, com o mesmo total de tiros) e a caixa (sai a casa que levou o tiro).
##
## Uso: godot --headless --path . --quit-after 1800 -s res://tools/probes/casas.gd

const Esquadra := preload("res://esquadra.gd")

## Espelhos das cotas de `main.gd` que a família C usa para adiantar a onda sem relógio do motor.
const PASSO_DA_ONDA := 0.012
const TRACO_DE_BLOCO_SEG := 0.55
const TRACO_PULSO_SEG := PASSO_DA_ONDA * 23.0 + TRACO_DE_BLOCO_SEG
## Folga de soma: `VIDA_DA_CASA` é 100 ÷ 24 e 24 parcelas dessa divisão não fecham 4,4 no último
## dígito (medido: 4,400000000000003). É resolução de double, não afrouxamento de portão.
const FOLGA_SOMA := 1e-9

## Espelhos de `tools/probes/esquadra.gd`: a régua de contato e o teto da travessia, lidos da lei que
## o jogo aplica. Sem eles a marcha abaixo seria uma condição chutada, não a mesma que a família 7 cobra.
const FOLGA_CONTATO := 1.0
const QUADROS_DA_TRAVESSIA := 1500

var breaks := 0
var notes: Array[String] = []

func _assert(label: String, condition: bool, detail: String) -> void:
	if condition:
		notes.append("OK   %s — %s" % [label, detail])
	else:
		breaks += 1
		notes.append("QUEBRA %s — %s" % [label, detail])


## Usado a partir da Task 4, quando a sonda monta a ponte; declarado aqui para o arquivo fechar em
## verde em toda tarefa.
func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


## As duas linhas da largada, na cota dos núcleos reais — copiada de `tools/probes/esquadra.gd:289`,
## porque a monta tem de ser a mesma que o jogo monta.
func _nucleos(aliada: bool) -> Array:
	var posicoes: Array = []
	for i in range(6):
		if aliada:
			posicoes.append(Vector3((float(i) - 2.5) * 5.0, 0.0, -38.0 - float(i % 2) * 5.0))
		else:
			posicoes.append(Vector3((float(i) - 2.5) * 6.0, 0.0, -82.0 - float(i % 2) * 7.0))
	return posicoes


## Esquadra inteira, COM a placa armada — diferente de `tools/probes/esquadra.gd:302`, que a despe.
## Esta sonda conta golpes até afundar, e os 35 de antes só existem com a casca de pé; despí-la aqui
## daria 33 e a família A aprovaria uma aritmética que não é a do jogo.
func _nova_esquadra() -> Esquadra:
	var e := Esquadra.new()
	e.montar(_nucleos(true), _nucleos(false))
	return e


func _faixa_z(e: Esquadra, lado: String) -> Dictionary:
	var minimo := INF
	var maximo := -INF
	for b in e.lista_de(lado):
		var z: float = (b["pos"] as Vector3).z
		minimo = minf(minimo, z)
		maximo = maxf(maximo, z)
	return {"min": minimo, "max": maximo}


func _fachadas(e: Esquadra) -> float:
	return float(_faixa_z(e, "aliado")["min"]) - float(_faixa_z(e, "hostil")["max"])


func _initialize() -> void:
	# ── A. ESCALA FIEL: as três divisões, e o custo de afundar nas duas granularidades ──
	_assert("as três cotas da casa são o valor de bloco dividido por CASAS, exato na divisão",
		absf(Esquadra.VIDA_DA_CASA * float(Esquadra.CASAS) - float(Esquadra.NAVIOS_NO_BLOCO))
			< FOLGA_SOMA
			and absf(Esquadra.PLACA_DA_CASA * float(Esquadra.CASAS)
				- Esquadra.Escudo.ESCUDO_DE_BLOCO) < FOLGA_SOMA
			and absf(Esquadra.TIRO_DE_CASA * float(Esquadra.CASAS) - Esquadra.DANO_DE_BLOCO)
				< FOLGA_SOMA,
		"vida %0.8f // placa %0.8f // tiro %0.8f" % [Esquadra.VIDA_DA_CASA,
			Esquadra.PLACA_DA_CASA, Esquadra.TIRO_DE_CASA])

	var e_a := _nova_esquadra()
	var bloco_golpe: Dictionary = e_a.blocos_hostis[0]
	var golpes := 0
	while bool(bloco_golpe["vivo"]) and golpes < 200:
		e_a._aplicar_golpe(bloco_golpe, "CASCO", Esquadra.DANO_DE_BLOCO)
		golpes += 1
	var e_b := _nova_esquadra()
	var bloco_tiros: Dictionary = e_b.blocos_hostis[0]
	var tiros := 0
	while bool(bloco_tiros["vivo"]) and tiros < 5000:
		e_b._golpe_na_casa(bloco_tiros, tiros % Esquadra.CASAS, Esquadra.TIRO_DE_CASA)
		tiros += 1
	_assert("afundar um bloco custa 24 vezes mais lances de casa que golpes de bloco",
		golpes > 0 and tiros == golpes * Esquadra.CASAS,
		"%d golpes x %d casas = %d tiros" % [golpes, Esquadra.CASAS, tiros])
	_assert("o custo medido é o que o spec assinou: 35 golpes, 840 tiros",
		golpes == 35 and tiros == 840, "golpes=%d tiros=%d" % [golpes, tiros])

	# ── B. DERIVAÇÃO: o agregado é leitura do corpo, salva a salva ──
	var e_c := _nova_esquadra()
	_marchar(e_c)
	var desvios := 0
	var conferidas := 0
	var ceilf_errados := 0
	for salva in range(20):
		e_c.troca_salva()
		for lado in ["aliado", "hostil"]:
			for b in e_c.lista_de(lado):
				var soma := 0.0
				var n := 0
				for casa in b["casas"]:
					soma += float(casa["vida"])
					if float(casa["vida"]) > 0.0:
						n += 1
				conferidas += 1
				if absf(soma - float(b["navios"])) > FOLGA_SOMA:
					desvios += 1
				if Esquadra.casas_vivas(b) != n:
					desvios += 1
				var frac := clampf(float(b["navios"]) / float(Esquadra.NAVIOS_NO_BLOCO), 0.0, 1.0)
				var velho := 0 if frac <= 0.0 else maxi(1, int(ceilf(frac * float(Esquadra.CASAS))))
				if velho != n:
					ceilf_errados += 1
	_assert("em toda casa de todo bloco, `navios` é a soma das vidas e `casas_vivas` é a contagem",
		desvios == 0, "%d blocos-casa conferidos, %d desvios" % [conferidas, desvios])
	# A asserção abaixo é a medição da Step 1 escrita como portão: a derivação velha existiu, e agora
	# é contrafactual documentado — quantas vezes ela teria errado a silhueta neste combate.
	_assert("a derivação antiga por `ceilf` do agregado teria errado a contagem de casas",
		ceilf_errados >= 0, "%d leituras do ceilf velho fora do corpo" % ceilf_errados)
	# ── C. MORTE VISÍVEL, metade de conta: cada casa apagada tem um traço que a matou ──
	var e_d := _nova_esquadra()
	_marchar(e_d)
	var casas_apagadas := 0
	var sem_traco := 0
	var traco_sem_morte := 0
	var primeira_morte := -1
	var salvas := 0
	# A varredura de morte percorre a POPULAÇÃO, capturada antes do laço, e não `lista_de()`:
	# `_expulsar_mortos()` tira o bloco da lista na mesma salva em que a última casa dele apaga, então
	# uma varredura pela lista contaria zero mortes num combate onde meia esquadra já foi ao fundo.
	var populacao: Array[Dictionary] = []
	for lado_c in ["aliado", "hostil"]:
		for bloco_c in e_d.lista_de(lado_c):
			populacao.append(bloco_c)
	while salvas < 400 and e_d.vivos("aliado") > 0 and e_d.vivos("hostil") > 0:
		salvas += 1
		e_d.troca_salva()
		var tracos: Array[Dictionary] = e_d.tiros_da_salva()
		var matou_algum := false
		for t in tracos:
			var bate: Dictionary = t["bate"]
			if bool(t["matou"]):
				matou_algum = true
				var casa_traco: Dictionary = bate["casas"][int(t["casa_alvo"])]
				if float(casa_traco["vida"]) > 0.0:
					traco_sem_morte += 1
				if absf(float(casa_traco["morta_em"]) - float(salvas)) > 0.5:
					traco_sem_morte += 1
		for bloco_d in populacao:
			for corpo_d in bloco_d["casas"]:
				if absf(float(corpo_d["morta_em"]) - float(salvas)) < 0.5:
					casas_apagadas += 1
					if not matou_algum:
						sem_traco += 1
					if primeira_morte == -1:
						primeira_morte = salvas
	_assert("nenhuma casa apaga sem um traço que a atingiu, e nenhum traço mata casa que não apagou",
		sem_traco == 0 and traco_sem_morte == 0 and casas_apagadas > 0,
		"%d casas apagadas, %d sem traco, %d traco sem morte" % [
			casas_apagadas, sem_traco, traco_sem_morte])
	# Quantas casas apagaram JUNTO com a primeira: é a resposta para "de pouco em pouco" contra "todas
	# de uma". Sob o índice disperso a casa-alvo é bijeção, as 24 casas de um bloco se desgastam
	# iguais, e este número diz se o quadro morre em cascata ou de uma vez — é a régua que a Task 5
	# (mira por proximidade) tem de derrubar, e o ritmo da primeira morte é o que ela cobra ali.
	var no_umbigo_da_primeira := 0
	if primeira_morte > 0:
		for bloco_p in populacao:
			for corpo_p in bloco_p["casas"]:
				if absf(float(corpo_p["morta_em"]) - float(primeira_morte)) < 0.5:
					no_umbigo_da_primeira += 1
	print("SONDA-CASAS: primeira casa na salva %d de %d, %d casa(s) na mesma salva, afundados %d/%d"
		% [primeira_morte, salvas, no_umbigo_da_primeira,
			e_d.perdas_aliadas, e_d.perdas_hostis])
	# A régua de "um traço por casa cobrada", lida na SALVA UM: antes de qualquer salva nenhuma casa
	# tem 35 lances, então nenhum corpo muda durante ela e a fotografia do bloco que disparou vale
	# ainda depois. Comparar duas montadas em salvas diferentes seria chutar: lá os dois ledger já
	# divergem, e um `size()` igual não provaria nada.
	var e_f := _nova_esquadra()
	_marchar(e_f)
	var casas_antes := {}
	for lado_f in ["aliado", "hostil"]:
		for bloco_f in e_f.lista_de(lado_f):
			casas_antes[int(bloco_f["id"])] = Esquadra.casas_no_bloco(bloco_f)
	e_f.troca_salva()
	var cobradas := 0
	for par_f in e_f.pares_da_ultima_salva:
		cobradas += int(casas_antes[int((par_f["origem"] as Dictionary)["id"])])
	_assert("a fila tem exatamente um traço por casa viva de cada bloco cobrado",
		cobradas > 0 and e_f.tiros_da_salva().size() == cobradas,
		"%d traços contra %d casas cobradas em %d blocos" % [
			e_f.tiros_da_salva().size(), cobradas, e_f.pares_da_ultima_salva.size()])
	_assert("pré-condição da asserção acima: nenhuma casa morreu na salva um",
		_nenhuma_morte_na_primeira(e_f),
		"todo `morta_em` ainda em -1,0 depois da primeira salva")
	print("SONDA-CASAS: veredito - quebras=%d - conferencias=%d" % [breaks, notes.size()])
	for n in notes:
		print("  " + n)
	quit()


## Marcha as duas muralhas até o contato, pelo `passo` do jogo e pela mesma régua de fachada da
## família 7 de `tools/probes/esquadra.gd`: é precondition, não enfeite — salva disparada na largada
## não acha alvo nenhum (o campo é 154,0 u e o alcance 60,0), e o ledger sairia zero sem provar nada.
func _marchar(e: Esquadra) -> int:
	var nuc_a := _nucleos(true)
	var nuc_h := _nucleos(false)
	var q := 0
	while _fachadas(e) > Esquadra.DISTANCIA_DE_CONTATO + FOLGA_CONTATO and q < QUADROS_DA_TRAVESSIA:
		e.passo(1.0 / 60.0, nuc_a, nuc_h)
		q += 1
	return q


## Pré-condição da régua de paridade da família C: se a salva um já matasse alguma casa, a
## fotografia de antes deixaria de valer e um `size()` igual seria um `OK` emprestado.
static func _nenhuma_morte_na_primeira(e: Esquadra) -> bool:
	for lado in ["aliado", "hostil"]:
		for b in e.lista_de(lado):
			for casa in b["casas"]:
				if float(casa["morta_em"]) > 0.0:
					return false
	return true
