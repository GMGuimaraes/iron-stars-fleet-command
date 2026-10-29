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
const FASE_HOSTIL_DA_SALVA := 0.5
const TRACO_PULSO_SEG := FASE_HOSTIL_DA_SALVA + PASSO_DA_ONDA * 23.0 + TRACO_DE_BLOCO_SEG
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
	# O contrafactual, agora como portão e não como frase: a derivação velha (`ceilf(navios ÷ 100 × 24)`)
	# existiu e ainda é o caminho dos dicionários nus, então ela é exercida sobre os vinte e três estados
	# inteiros de lotação e cobra a LISTA dos que erram. `>= 0` não reprovaria nada; isto reprova se a
	# aritmética do agregado se mover. Medido nesta casa: sete estados, e o pior é 23 corpos lidos 24
	# porque `23 × (100÷24) = 95,83333333333336`.
	var e_cf := _nova_esquadra()
	var bloco_cf: Dictionary = e_cf.blocos_hostis[0]
	var cf_errados: Array[int] = []
	var pior_23 := -1
	for k in range(1, Esquadra.CASAS):
		e_cf.fixar_lotacao(bloco_cf, float(Esquadra.VIDA_DA_CASA) * float(k))
		var corpo := Esquadra.casas_vivas(bloco_cf)
		var frac_cf := clampf(float(bloco_cf["navios"]) / float(Esquadra.NAVIOS_NO_BLOCO), 0.0, 1.0)
		var velho_cf := 0 if frac_cf <= 0.0 else maxi(1, int(ceilf(frac_cf * float(Esquadra.CASAS))))
		if velho_cf != corpo:
			cf_errados.append(k)
			if k == Esquadra.CASAS - 1:
				pior_23 = velho_cf
	_assert("a derivação antiga por `ceilf` erra exatamente os sete estados contados, nunca menos",
		cf_errados == [5, 6, 7, 20, 21, 22, 23] and pior_23 == Esquadra.CASAS,
			"%d estados fora do corpo: %s, e o estado 23 lido como %d (o agregado a 23 corpos e %.14f)" % [
				cf_errados.size(), str(cf_errados), pior_23, float(bloco_cf["navios"])])
	e_cf.fixar_lotacao(bloco_cf, float(Esquadra.NAVIOS_NO_BLOCO))
	print("SONDA-CASAS: ceilf velho leria fora do corpo %d vezes em %d blocos-casa de combate, e %d dos 23 estados inteiros: %s" % [ceilf_errados, conferidas, cf_errados.size(), str(cf_errados)])
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
	# de uma", e é o número que a mira mudou. Sob o índice disperso antigo a casa-alvo era bijeção, as
	# 24 casas de um bloco se desgastavam iguais, e a primeira morte de um bloco era o afundamento dele
	# — `afundados` subia junto com a primeira casa. Medido nesta casa com a mira por proximidade: 18
	# casas apagadas na mesma salva 5 e, ao fim das 400 salvas, 0 blocos afundados e 720 casas apagadas
	# (três por bloco em 240). A cascata saiu de dentro-do-bloco e passou a ser entre-blocos: cada
	# muralha cava a frente do próprio vizinho, e o quadro mostra furos, não sumiços.
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
	# ── C.3 metade de tela: a casa some quando o traço toca, não quando a salva fecha ──
	# É a lei do jogador: ver a nave apagar NA hora em que o fogo chega. O número do quadro é lido do
	# pulso desenhado em `main.gd`, e por isso esta metade monta a ponte em vez de contar a Esquadra
	# nua. O plano chamava esta metade de "C.2"; C.2 já era o bloco de paridade acima, então ela desceu
	# para C.3 e o desvio está registrado no plano.
	var jogo_c3: Node3D = await _montar_jogo()
	var eq_c3: Esquadra = jogo_c3.esquadra
	# População capturada antes da busca, pela mesma razão de C.1: quem afunda sai de `lista_de()` na
	# própria salva, e uma varredura pela lista diria "nenhum recado pendurado" sobre os cadáveres.
	var pop_c3: Array[Dictionary] = []
	for lado_c3 in ["aliado", "hostil"]:
		for bloco_c3 in eq_c3.lista_de(lado_c3):
			pop_c3.append(bloco_c3)
	_marchar_jogo(jogo_c3)
	# Pré-condição ainda construída, mas o MOTIVO mudou com a mira. Sob a dispersão bijetora antiga
	# cada casa viva recebia EXATAMENTE um lance por atacante por salva, as 24 casas de um bloco se
	# desgastavam iguais e a primeira morte coincidia com o afundamento — e bloco afundado sai de
	# `lista_de()` inteiro, sem quadro para medir, porque a lei do traço some junto. Desde que a mira
	# por proximidade virou lei de TODO lance (família D abaixo) C.1 mede o contrário: primeira casa
	# apagada na salva 5, 18 casas na mesma salva, afundados 0/0. A morte solitária passou a ser o
	# normal do combate. O corpo fraco continua armado pela porta de `_golpe_na_casa` que a família B
	# já usa por um motivo mais humilde: sem ele o índice da salva depende da semente do tabuleiro, e
	# esta asserção cobra um quadro exato.
	var fracas_c3 := _armar_morte_solitaria(eq_c3)
	_assert("a morte solitária foi armada num bloco que continua em jogo (pré-condição de C.3)",
		fracas_c3 > 0, "%d casa(s) a um lance de morrer, com as outras cheias" % fracas_c3)
	# A salva que apaga casa tem de ser PROCURADA, não suposta: na salva um nenhum corpo chega aos 35
	# lances, e o teto de 400 é a janela medida em C.1 (a marcha nua apaga a primeira na salva 5; aqui
	# o tabuleiro vem da semente do jogo e a morte é armada, então o índice exato muda e a janela não
	# pode encolher).
	var matou_c3: Array[Dictionary] = []
	var salva_da_morte := -1
	while matou_c3.is_empty() and eq_c3.salva_numero < 400:
		eq_c3.troca_salva()
		jogo_c3._armar_tracos()
		for tr_c3 in eq_c3.tiros_da_salva():
			if bool(tr_c3["matou"]):
				matou_c3.append(tr_c3)
		if not matou_c3.is_empty():
			salva_da_morte = int(eq_c3.salva_numero)
	_assert("existe salva que apaga casa em combate real (pré-condição do resto de C.3)",
		not matou_c3.is_empty(), "primeira morte na salva %d" % salva_da_morte)
	# O corpo medido precisa de um bloco AINDA EM JOGO: afundado, ele sai da lista e `pintar` escreve
	# zero casas nele, então o "antes" leria falso por um motivo que não é a lei desta asserção.
	var tra_c3: Dictionary = {}
	var vivos_c3 := 0
	# O quadro do toque sobe para o escopo da função: os números desta rodada, os mesmos que o README e
	# o spec citam, saem numa linha só no fim e precisam alcançá-lo.
	var quadro_do_toque := -1
	for tr2_c3 in matou_c3:
		if bool((tr2_c3["bate"] as Dictionary)["vivo"]):
			vivos_c3 += 1
			if tra_c3.is_empty():
				tra_c3 = tr2_c3
	# Os dois números são lidos, não inferidos: a asserção acima exige ao menos um bloco vivo, e o
	# detalhe abaixo dá a fração inteira. Medido: com a morte armada casa a casa, os dezoito traços
	# caem em dezoito blocos que seguem na lista, cada um com 23 casas cheias e uma a menos.
	_assert("a morte medida acontece num bloco que segue na lista (pré-condição de C.3)",
		not tra_c3.is_empty(), "%d traços mataram na salva %d // %d deles sobre bloco vivo" % [
			matou_c3.size(), salva_da_morte, vivos_c3])
	if not tra_c3.is_empty():
		var casa_c3: Dictionary = (tra_c3["bate"] as Dictionary)["casas"][int(tra_c3["casa_alvo"])]
		var atraso_c3 := float(int(tra_c3["casa"])) * PASSO_DA_ONDA + (
			0.0 if bool(tra_c3["aliado"]) else FASE_HOSTIL_DA_SALVA)
		var toque_c3 := int(ceilf((atraso_c3 + TRACO_DE_BLOCO_SEG) / (1.0 / 60.0)))
		quadro_do_toque = toque_c3
		var pendia_antes := bool(casa_c3["a_noticiar"])
		var pintada_antes := _casa_pintada(eq_c3, tra_c3)
		var pintada_depois := true
		var q_c3 := 0
		while q_c3 < 600:
			jogo_c3._atualizar_tracos(1.0 / 60.0)
			jogo_c3._pintar_massa(false)
			q_c3 += 1
			if q_c3 == toque_c3 + 1:
				pintada_depois = _casa_pintada(eq_c3, tra_c3)
		# O `+1` no "depois" é resolução de float, não folga de portão: `_traco_t` cresce somando
		# 1/60, e 33 somas podem parar um hair abaixo de 0,55. O toque ainda tem de ser o quadro
		# previsto, e o detalhe impresso diz em qual quadro a casa de fato saiu.
		_assert("a casa apagada está na tela antes do toque e sai dela no toque, e só depois",
			pendia_antes and pintada_antes and not pintada_depois,
			"toque no quadro %d // pendente antes=%s, pintada antes=%s, pintada depois=%s" % [
				toque_c3, str(pendia_antes), str(pintada_antes), str(pintada_depois)])
	var pendentes_c3 := 0
	for bloco_p3 in pop_c3:
		for corpo_p3 in bloco_p3["casas"]:
			if bool(corpo_p3["a_noticiar"]):
				pendentes_c3 += 1
	# Esta é a guarda do dono único do recado: apagado o ralo da salva, a notícia passa a ser dada só
	# pela onda, e todo traço que sai do ar sem tocar (pulso encerrado, persiana, salva nova) tem de
	# drenar — senão o corpo morto fica pintado para sempre com `a_noticiar` verdadeiro.
	_assert("nenhuma notícia de morte sobrevive ao pulso: sem dreno a casa fica pendurada na tela",
		pendentes_c3 == 0, "%d recados pendentes no fim do pulso da salva %d" % [
			pendentes_c3, salva_da_morte])
	jogo_c3.queue_free()
	# ── D. COMANDO: concentrar é escolha de casa, não dano de área ──
	# As três asserções comparam as duas montadas na SALVA UM, onde nenhum corpo mudou ainda: é o
	# único quadro em que os dois regimes são a mesma laje, e portanto o único em que "a ordem não
	# inventa tiro" quer dizer alguma coisa. Depois da salva um os dois ledgers divergem por
	# construção, e comparar `tiros_da_salva().size()` entre montadas aprovaria um número que não é
	# lei nenhuma.
	var largada_d := _nova_esquadra()
	var largada_c := _nova_esquadra()
	_marchar(largada_d)
	_marchar(largada_c)
	# A ordem é dada a três unidades acima do centro do bloco da frente: é o ponto que a ponte
	# tocaria, e `_vizinho_de` devolve o próprio bloco — a mira tem de convergir nele, não no vizinho.
	largada_c.mandar_fogo((largada_c.blocos_hostis[0]["pos"] as Vector3) + Vector3(0.0, 3.0, 0.0))
	var antes_d := _casas_da_largada(largada_d)
	var antes_c := _casas_da_largada(largada_c)
	largada_d.troca_salva()
	largada_c.troca_salva()
	_assert("a ordem não inventa nem esconde tiro: um traço por casa viva de cada bloco cobrado",
		_cobrados_e_tracos(largada_d, antes_d) and _cobrados_e_tracos(largada_c, antes_c),
		"%d traços no disperso contra %d no concentrado, cada um igual às casas cobradas do seu ledger" % [
			largada_d.tiros_da_salva().size(), largada_c.tiros_da_salva().size()])
	var distintos_d := _casas_alvo_distintas(largada_d)
	var distintos_c := _casas_alvo_distintas(largada_c)
	var pior_d := _max_casas_por_atacante(largada_d)
	var pior_c := _max_casas_por_atacante(largada_c)
	# Duas leis, e elas moram em níveis diferentes. A primeira é da CASA e não do comando: os vinte e
	# quatro canos de UM bloco pousam na casa da frente do alvo dele, com ordem e sem ordem. Foi isso
	# que substituiu o leque bijetor (`casa_alvo = (casa + id + salva) % vivas`, um lance por casa por
	# salva), que espelhava 1 440 lances sobre 720 casas vivas e devolvia a primeira morte na salva
	# 185 — duzentos e noventa e seis segundos de partida sem um corpo apagar na tela. Medido agora:
	# UM atacante, UMA casa, nos dois regimes, e a primeira morte na salva 5.
	_assert("os canos de um bloco convergem na casa da frente, com ou sem ordem (a lei da mira)",
		pior_d == 1 and pior_c == 1,
		"um atacante pousa em %d casa(s) distintas no fogo de linha contra %d no concentrado" % [
			pior_d, pior_c])
	# A segunda é do COMANDO, e mora no ALVO, não na casa: a ordem da ponte fecha os trinta atacantes
	# sobre uma frente só, e o campo inteiro enxuga das 30 casas-alvo distintas do fogo de linha para
	# as 5 do visado. É o que sobrou de sentido para CONCENTRAR depois que a mira virou lei de todo
	# lance — e é ela que a asserção seguinte cobra, em salvas.
	_assert("a ordem da ponte enxuga o CAMPO de alvos, não a escolha de casa dentro do alvo",
		distintos_c > 0 and distintos_c < distintos_d,
		"campo: %d casas-alvo distintas com a ordem contra %d no fogo de linha // por atacante: "
			% [distintos_c, distintos_d] + "%d contra %d" % [pior_c, pior_d])
	# O preço, em salvas: a primeira casa de um bloco apaga mais cedo sob a ordem da ponte. São as
	# duas montadas do mesmo tabuleiro, e é este o número que o comandante julga de olho.
	var dispersa := _nova_esquadra()
	var convergente := _nova_esquadra()
	_marchar(dispersa)
	_marchar(convergente)
	convergente.mandar_fogo((convergente.blocos_hostis[0]["pos"] as Vector3)
		+ Vector3(0.0, 3.0, 0.0))
	var salva_d := _salva_da_primeira_morte_aliada(dispersa)
	var salva_c := _salva_da_primeira_morte_aliada(convergente)
	_assert("concentrar fogo apaga a primeira casa antes de dispersar, no mesmo tabuleiro",
		salva_c > 0 and salva_d > 0 and salva_c < salva_d,
		"concentrado na salva %d, disperso na salva %d" % [salva_c, salva_d])
	# ── E. CAIXA: a casa que sai é a que levou o tiro, não a que a ordem escolheu ──
	# Contrafactual: matar casas do MEIO (andar de baixo, coluna da esquerda) tem de abrir a caixa por
	# um eixo que o `range(casas)` antigo jamais tocaria — ele só despia o topo.
	# Medido: a caixa é a UNIÃO das casas vivas (`caixa_do_bloco`, esquadra.gd:686-709), então uma casa
	# interior apagada não move volume nenhum. O que move é a coluna inteira de um eixo — e é ela que a
	# cobra. A casa do meio continua coberta pela asserção seguinte: apaga, sai da pintura, e as
	# demais ficam de pé.
	var e_e := _nova_esquadra()
	var b := e_e.blocos_aliados[3]
	var caixa_cheia := e_e.caixa_do_bloco(b)
	var alvo_c := 1 + Esquadra.CASAS_X * Esquadra.CASAS_Z   # uma casa do andar do meio
	var tiros_meio := 0
	for k in range(400):
		e_e._golpe_na_casa(b, alvo_c, Esquadra.TIRO_DE_CASA)
		tiros_meio = k + 1
		if not Esquadra.casa_viva(b, alvo_c):
			break
	_assert("a casa do meio apagada sai da listagem e as demais continuam de pé e pintáveis",
		not Esquadra.casa_viva(b, alvo_c)
			and Esquadra.casas_no_bloco(b) == Esquadra.CASAS - 1
			and Esquadra.casas_vivas_de(b).has(0),
		"casa %d apagada em %d tiros // %d casas vivas de %d" % [alvo_c, tiros_meio,
			Esquadra.casas_no_bloco(b), Esquadra.CASAS])
	var coluna: Array[int] = []
	var por_camada := Esquadra.CASAS_X * Esquadra.CASAS_Z
	for c in range(Esquadra.CASAS):
		if ((c % por_camada) % Esquadra.CASAS_X) == 0:   # a fileira mais à esquerda da malha
			coluna.append(c)
	for c in coluna:
		for k in range(400):
			e_e._golpe_na_casa(b, c, Esquadra.TIRO_DE_CASA)
			if not Esquadra.casa_viva(b, c):
				break
	var caixa_rala := e_e.caixa_do_bloco(b)
	_assert("a coluna da esquerda apagada abre a caixa no eixo X, sem tocar na altura",
		Esquadra.casas_no_bloco(b) == Esquadra.CASAS - coluna.size() - 1
			and caixa_rala.size.x < caixa_cheia.size.x
			and is_equal_approx(caixa_rala.size.y, caixa_cheia.size.y)
			and is_equal_approx(caixa_rala.size.z, caixa_cheia.size.z),
		"%d casas da coluna + a do meio apagadas de %d // caixa %s -> %s" % [coluna.size(),
			Esquadra.CASAS, str(caixa_cheia.size), str(caixa_rala.size)])
	# Os números que o README e a §10 do spec citam, impressos nesta rodada em vez de morar só na
	# frase de um portão que passou verde: cada um é o mesmo valor que a asserção acima conferiu.
	print("SONDA-CASAS: escala %d golpes de bloco = %d lances de casa" % [golpes, tiros])
	print("SONDA-CASAS: census %d casas apagadas, %d sem traco, %d traco sem morte" % [
		casas_apagadas, sem_traco, traco_sem_morte])
	print("SONDA-CASAS: fila da salva um - %d tracos contra %d casas cobradas em %d blocos" % [
		e_f.tiros_da_salva().size(), cobradas, e_f.pares_da_ultima_salva.size()])
	print("SONDA-CASAS: morte real na salva %d - %d tracos mataram, %d sobre bloco vivo, apaga no quadro %d" % [
		salva_da_morte, matou_c3.size(), vivos_c3, quadro_do_toque])
	print("SONDA-CASAS: mira por atacante - %d casa(s) concentrado contra %d disperso (campo %d contra %d); tracos da salva um %d disperso contra %d concentrado" % [
		pior_c, pior_d, distintos_c, distintos_d,
		largada_d.tiros_da_salva().size(), largada_c.tiros_da_salva().size()])
	print("SONDA-CASAS: primeira casa apagada - salva %d com a ordem contra %d sem ela" % [
		salva_c, salva_d])
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


## Monta a ponte e congela o mundo pelo instrumento da casa (`process_mode`, nunca `set_process`): sem
## o congelamento, o `_process` do jogo arma traços por conta própria no meio da varredura manual de
## C.3 e a leitura do quadro do toque deixaria de ser a salva que a sonda armou. Diferente de
## `tools/probes/esquadra.gd:255`, esta montagem NÃO despe placa nem escudo — aqui a casca de pé é
## justamente a lei sendo medida.
func _montar_jogo() -> Node3D:
	var jogo: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(jogo)
	jogo.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(3)
	return jogo


## Marcha a muralha do jogo montado até o contato pela porta da ponte: `_nucleos_da_esquadra` são os
## mesmos núcleos que o jogo passa, e a régua é a de fachada da família 7, não um conto de quadros.
func _marchar_jogo(jogo) -> void:
	var nuc_a: Array = jogo._nucleos_da_esquadra(true)
	var nuc_h: Array = jogo._nucleos_da_esquadra(false)
	var e: Esquadra = jogo.esquadra
	var q := 0
	while _fachadas(e) > Esquadra.DISTANCIA_DE_CONTATO + FOLGA_CONTATO and q < QUADROS_DA_TRAVESSIA:
		e.passo(1.0 / 60.0, nuc_a, nuc_h)
		q += 1


## A casa ainda está na tela? Lido da régua com que `pintar` decide o que escreve
## (`Esquadra._casa_na_tela`, `esquadra.gd:628`), não do `MultiMesh`: sob `--headless` a instância
## devolve transformada identidade e o portão passaria aprovado sem um pixel visto. E é lida PELO
## ÍNDICE DO CORPO, não por contagem: `pintar` escreve `base + c` casa a casa e nunca compacta a fila,
## então "a casa 19 está desenhada" não é "há 20 casas desenhadas".
static func _casa_pintada(e: Esquadra, t: Dictionary) -> bool:
	var bate: Dictionary = t["bate"]
	for b in e.lista_de(String(bate["lado"])):
		if int(b["id"]) == int(bate["id"]):
			return Esquadra._casa_na_tela(b, int(t["casa_alvo"]))
	return false


## Arma a morte solitária que C.3 precisa ver: a casa do meio de cada bloco fica a UM LANCE MÍNIMO
## de morrer, e as outras 23 continuam cheias, então o bloco sobrevive à própria morte. O golpe é
## cobrado pela porta de produção (`_golpe_na_casa`), com dano menor que o limiar, para que nenhuma
## casa atravesse zero durante a armação — atravessar não seria só sujar a medida: `_golpe_na_casa`
## redistribui o lance de casa morta para a vizinha viva (`_casa_seguindo`), e uma vizinha apagada
## na armação trocaria a cascata de 24 por uma de 23.
## O limiar é `TIRO_DE_CASA × 0,25 × 1,4`: a boca mínima do cano (`0.25 + ARMAS/100 × 0.75` com
## `ARMAS` zero) e o fator de transbordo depois da placa, que a armação gasta casa a casa.
func _armar_morte_solitaria(e: Esquadra) -> int:
	var limiar := Esquadra.TIRO_DE_CASA * 0.25 * 1.4
	var passo := limiar * 0.5
	var meio := int(Esquadra.CASAS / 2)
	var armadas := 0
	for lado_a in ["aliado", "hostil"]:
		for bloco_a in e.lista_de(lado_a):
			var casa_a: Dictionary = bloco_a["casas"][meio]
			var golpes_a := 0
			while float(casa_a["vida"]) > limiar and golpes_a < 4000:
				e._golpe_na_casa(bloco_a, meio, passo)
				golpes_a += 1
			var vida_final := float(casa_a["vida"])
			var intacto := Esquadra.casas_no_bloco(bloco_a) == Esquadra.CASAS
			if vida_final > 0.0 and vida_final <= limiar and bool(bloco_a["vivo"]) and intacto:
				armadas += 1
	return armadas


## Fotografia das casas vivas antes da primeira salva, indexada pelo `id` do bloco. O ledger resolve
## sobre o retrato do quadro anterior, então é ASSIM que ele vê cada bloco, e é assim que a conta de
## traços tem de ser conferida — conferir depois da salva seria contar corpos que o fogo já mudou.
func _casas_da_largada(e: Esquadra) -> Dictionary:
	var out := {}
	for lado_f in ["aliado", "hostil"]:
		for b_f in e.lista_de(lado_f):
			out[int(b_f["id"])] = Esquadra.casas_no_bloco(b_f)
	return out


## A régua honesta de "um traço por casa cobrada": soma as casas vivas de cada bloco que o ledger
## cobrou, na fotografia acima, e compara com o tamanho da fila. `> 0` é o guarda do vazio: uma salva
## que não cobra nada tem fila zero e bateria zero, e aprovaria a igualdade por não provar nada.
func _cobrados_e_tracos(e: Esquadra, antes: Dictionary) -> bool:
	var cobradas := 0
	for par in e.pares_da_ultima_salva:
		cobradas += int(antes[int((par["origem"] as Dictionary)["id"])])
	return cobradas > 0 and e.tiros_da_salva().size() == cobradas


## Quantas casas do lado visado receberam lance aliado nesta salva, somando a muralha inteira. É a
## digital do COMANDO: trinta atacantes sobre uma frente só dão um número pequeno, trinta atacantes
## cada um no vizinho mais próximo dão um por atacante. A chave é (bloco, casa) e não só a casa: dois
## blocos visados com a mesma casa apagada são duas mortes na tela, não uma.
func _casas_alvo_distintas(e: Esquadra) -> int:
	var vistas := {}
	for t in e.tiros_da_salva():
		if bool(t["aliado"]):
			vistas["%d:%d" % [int(t["alvo_bloco"]), int(t["casa_alvo"])]] = true
	return vistas.size()


## Quantas casas distintas UM bloco atacante espalha os próprios lances — o pior caso da muralha.
## É a medida da mira, e a lei hoje é uma só: os vinte e quatro canos de um bloco pousam na casa da
## frente do alvo e só passam à vizinha quando aquela apaga, de modo que o número honesto é 1 nos
## dois regimes. O antigo índice disperso (`casa_alvo = (casa + id + salva) % vivas`) dava 24 por
## atacante, e é contra essa digital que a asserção da família D ainda se apoia: a mira deixou de ser
## prêmio do comando para virar lei da casa.
func _max_casas_por_atacante(e: Esquadra) -> int:
	var por_bloco := {}
	for t in e.tiros_da_salva():
		if not bool(t["aliado"]):
			continue
		var origem := int(t["bloco"])
		if not por_bloco.has(origem):
			por_bloco[origem] = {}
		por_bloco[origem]["%d:%d" % [int(t["alvo_bloco"]), int(t["casa_alvo"])]] = true
	var pior := 0
	for atacante in por_bloco:
		pior = maxi(pior, (por_bloco[atacante] as Dictionary).size())
	return pior


## Em que salva a montada apaga a PRIMEIRA casa de qualquer bloco hostil, contando só pelos lances
## que ela mesma mandou (`aliado && matou` no ledger). Devolve -1 se não apagar em `limite` salvas.
## O teto de 400 não encolhe embora a medida de hoje esteja longe dele (fogo de linha na salva 5,
## com a ordem da ponte na 3): ele foi escrito contra o índice disperso, que assinava a primeira
## morte da marcha inteira na salva 185 porque boca < 1 e a placa come lances antes da vida. Um teto
## calibrado na medição desta rodada aprovaria por acidente se a mira voltasse a ser leque.
## Esta régua substitui o instrumento que o plano desenhava (olhar um bloco fixo, `blocos_hostis[0]`):
## medido por `_tmp_mira.gd`, esse bloco recebe ZERO lances aliados nas 400 salvas do regime de linha
## (`no_alvo=0`, 60 pares de alvo contra os 30 do visado) porque quem alcança atira no vizinho mais
## próximo, não no bloco 0. Cobrar a morte dele era cobrar uma casa que ninguém mira.
func _salva_da_primeira_morte_aliada(e: Esquadra, limite := 400) -> int:
	for s in range(limite):
		e.troca_salva()
		for t in e.tiros_da_salva():
			if bool(t["aliado"]) and bool(t["matou"]):
				return s + 1
	return -1
