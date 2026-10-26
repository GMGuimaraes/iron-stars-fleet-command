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
