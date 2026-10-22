extends SceneTree

## Sonda da iniciativa dos cascos: a escada de alvo da linha aliada e a contra-medida da guarda
## hostil.
##
## O pedido do comandante foi «melhorar a IA das naves inimigas e aliadas». Uma IA que só existe no
## relatório não muda a batalha, então esta sonda mede a escada casco a casco, no tabuleiro, virando
## cada peso numa travessa de distância: o número procurado não é o peso escrito no código, é o ponto
## exato em que a decisão vira.
##
## 1) A ESCADA TEM ORDEM. Primeiro o hostil que encosta na capitânia da ponte (perder a ponte é
##    perder a batalha), depois o que está mais ferido (terminar um trabalho custa menos que começar
##    outro), depois o mais perto de quem atira. A ameaça vence um inimigo 5 u atrás do atirador até
##    13 u de vantagem e perde a partir de 15 u — que é o piso e o teto de +14, com o empate exato em
##    14 u devolvendo o casco de número menor.
## 2) O ARCO TEM PREÇO. Um casco no último quarto de arco (75 pontos perdidos) ganha 4 u de
##    distância e perde aos 5 u — que é a medida fina de 0,06 por ponto, não "sempre o mais ferido".
## 3) A FILA ANDA. Um alvo já apontado por um casco não perde o segundo lance; a partir do terceiro
##    ele perde a prioridade (-8 por lance excedente). Sem isto, doze cascos formariam fila para o
##    mesmo número de série enquanto os outros viram alvo livre — e a própria saturação da ameaça a
##    devolve para baixo quando a esquadra inteira já está em cima dela.
## 4) O COMANDO AINDA MANDA. Em CONCENTRADO a escada cede: a função devolve o alvo da ponte para
##    todo casco, mesmo com cinco lances nele. Sob ordem ATACAR/ABORDAR o setor da ponte também não é
##    discutido. E defunto não é alvo: casco a 0 e casco CAPTURADO estão fora da lista, tabuleiro
##    vazio devolve -1 sem crash.
## 5) O LADO DE LÁ TEM CONTRA-MEDIDA. Quando a ponte concentra o disco, a guarda hostil fecha por
##    dentro (±3 → ±2) e os dois escoltas entram no corredor do lance âncora. Medido no offset e na
##    distância real depois de duzentos e quarenta quadros de navegação — com a física de contato
##    empurrando os dois postos de volta, que é o preço honesto de fechar demais.
## 6) NADA DISSO É SORTEIO. A prova central: duzentas chamadas da escada não movem `rng` nem
##    `visual_rng`; e dois tabuleiros diferentes na mesma semente disparam exatamente o mesmo número
##    de lances, com `rng.state` dígito por dígito igual, engajando menos contatos e deixando mais
##    casco vivo. A IA mudou para onde o tiro vai, nunca quantos dados são rolados — o mesmo contrato
##    que a densidade de fogo assina em `tools/probes/salva.gd`.
##
## Uso: godot --headless --path . --quit-after 1800 -s res://tools/probes/ia.gd

const HULL_RADIUS := 2.4
const FLECHAS_POR_SALVA := 3
const FOGO_LETAL := 3.2
const QUADROS_DE_NAVEGACAO := 240
## Espelhos dos pesos de `main.gd`. Divergir daqui é quebrar a asserção de propósito: a escada é
## contrato do comandante, não detalhe de implementação.
const PESO_PONTE := 14.0
const PESO_ARCO := 0.06
const PESO_FILA := 8.0

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

func _montar_jogo() -> Node3D:
	var game: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	await _frames(3)
	game.paused = true
	return game

func _alinhar(game) -> void:
	for i in range(game.fleet.size()):
		(game.fleet[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 5.0, 0.0, -38.0)
	for i in range(game.enemies.size()):
		(game.enemies[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 6.0, 0.0, -82.0)

func _zerar(game) -> void:
	for list in [game.fleet, game.enemies]:
		for unit in list:
			unit["hp"] = 100.0
			unit["engines"] = 100.0
			unit["weapons"] = 100.0
			unit["crew"] = 100.0
			unit["veloc"] = Vector3.ZERO
	game.capital_hp = 100.0
	game.batalha_encerrada = false

func _cascos_somados(game) -> float:
	var total := 0.0
	for unit in game.fleet:
		total += float(unit["hp"])
	for unit in game.enemies:
		total += float(unit["hp"])
	return total

## A capitânia da ponte fica na origem do mundo até o acelerador mexer nela, então «perto da ponte» é
## perto da origem — e um tabuleiro alinhado põe toda a linha hostil a ~82 u dela.
func _ponte(game) -> Vector3:
	return (game.bridge_rig as Node3D).global_position

func _poe_hostil(game, no_alvo: int, p: Vector3) -> void:
	(game.enemies[no_alvo]["node"] as Node3D).global_position = p

func _poe_aliado(game, no_aliado: int, p: Vector3) -> void:
	(game.fleet[no_aliado]["node"] as Node3D).global_position = p

func _pos_hostil(game, no_alvo: int) -> Vector3:
	return (game.enemies[no_alvo]["node"] as Node3D).global_position

## Deixa vivos exatamente os índices pedidos — o resto a 0, fora da escada por casco morto.
func _mata_hostis_exceto(game, vivos: Array[int]) -> void:
	for i in range(game.enemies.size()):
		if not vivos.has(i):
			game.enemies[i]["hp"] = 0.0

## O número de alvos engajados que a ponte mostra ao comandante — é a frase que sai no relatório da
## salva, e é ela (não um dicionário interno) que prova que a esquadra espalhou.
func _alvos_engajados(game) -> int:
	var texto := String(game.salva_resumo)
	var p := texto.find("alvo(s) engajado(s)")
	if p < 0:
		return -1
	var fim := p
	while fim > 0 and texto[fim - 1] == " ":
		fim -= 1
	var ini := fim
	while ini > 0 and texto[ini - 1] >= "0" and texto[ini - 1] <= "9":
		ini -= 1
	if ini == fim:
		return -1
	return int(texto.substr(ini, fim - ini))


func _initialize() -> void:
	# ---- 1. A ameaça à ponte primeiro, com o peso virado em travessa --------------------------------
	var g := await _montar_jogo()
	_alinhar(g)
	_zerar(g)
	g.fogo_densidade = 1
	var ponte := _ponte(g)
	_mata_hostis_exceto(g, [0, 1])
	# hostil 1 a 12 u da ponte (a ameaça) e hostil 0 a D u DELE, com o atirador colado 5 u atrás do
	# hostil 0. Assim a distância de cada casco até quem atira difere exatamente de D, e o que se mede
	# é o peso puro: a ameaça vence enquanto +14 cobre D.
	_poe_hostil(g, 1, ponte + Vector3(0.0, 0.0, -12.0))
	_assert("a leitura de ameaça aponta o casco que encosta na capitânia",
		int(g._hostil_da_ponte()) == 1, "ameaça = hostil 1 a 12,0 u da ponte")
	for d in [1.0, 13.0, 14.0, 15.0]:
		_poe_hostil(g, 0, ponte + Vector3(0.0, 0.0, -12.0 - d))
		_poe_aliado(g, 0, ponte + Vector3(0.0, 0.0, -17.0 - d))
		var escolha := int(g._alvo_aliado_autonomo(0, 5, {}))
		var esperado := 1 if d < PESO_PONTE else 0
		_assert("a ameaça à ponte vence a diferença de distância até o peso dela, e depois perde",
			escolha == esperado,
			"ameaça %.0f u mais longe do atirador -> escolheu %d (esperado %d; peso +%.0f)" % [
				d, escolha, esperado, PESO_PONTE])
	# ---- 2. Terminar o trabalho, com o preço do arco medido -----------------------------------------
	_alinhar(g)
	_zerar(g)
	_mata_hostis_exceto(g, [0, 1, 2])
	# hostil 0 a 5 u da ponte (ameaça) mas a 33 u do atirador, que está a 3 u do hostil 1 e a
	# 3+E do hostil 2: aqui a escada é toda de distância + arco, e a travessa do 0,06 é E.
	_poe_hostil(g, 0, ponte + Vector3(0.0, 0.0, -5.0))
	_poe_hostil(g, 1, ponte + Vector3(0.0, 0.0, -41.0))
	_poe_hostil(g, 2, ponte + Vector3(0.0, 0.0, -41.0))
	_poe_aliado(g, 0, ponte + Vector3(0.0, 0.0, -38.0))
	var empate := int(g._alvo_aliado_autonomo(0, 5, {}))
	_assert("dois cascos no mesmo degrau deixam o de número menor no alvo (a salva é reproduzível)",
		empate == 1, "escolheu %d com hostil 1 e 2 colados a 3,0 u do atirador" % empate)
	for e in [4.0, 5.0]:
		g.enemies[2]["hp"] = 25.0
		_poe_hostil(g, 2, ponte + Vector3(0.0, 0.0, -41.0 - e))
		var virada := int(g._alvo_aliado_autonomo(0, 5, {}))
		var alvo_esperado := 2 if e < 75.0 * PESO_ARCO else 1
		_assert("um casco no último quarto de arco compra distância, e a compra tem teto",
			virada == alvo_esperado,
			"%.0f u a mais + %.0f pontos de arco perdido (%.1f u de compra) -> escolheu %d (esperado %d)" % [
				e, 75.0, 75.0 * PESO_ARCO, virada, alvo_esperado])
	# ---- 3. A fila anda: deconfliction --------------------------------------------------------------
	_poe_hostil(g, 2, ponte + Vector3(0.0, 0.0, -41.0))
	g.enemies[2]["hp"] = 100.0
	var um_sozinho := int(g._alvo_aliado_autonomo(0, 5, {1: 1}))
	_assert("um alvo já apontado por um casco não perde o segundo",
		um_sozinho == 1, "escolheu %d com carga 1 no hostil 1" % um_sozinho)
	var terceiro := int(g._alvo_aliado_autonomo(0, 5, {1: 2}))
	_assert("a partir do terceiro lance no mesmo casco a fila anda",
		terceiro == 2, "escolheu %d com carga 2 no hostil 1 (penalidade -%.0f)" % [terceiro, PESO_FILA])
	var saturado := int(g._alvo_aliado_autonomo(0, 5, {1: 5}))
	_assert("e cinco lances sobre ele não o seguram: a mira passa para o vizinho",
		saturado == 2, "escolheu %d com carga 5 no hostil 1 (-%.0f)" % [saturado, 4.0 * PESO_FILA])
	var ambos := int(g._alvo_aliado_autonomo(0, 5, {1: 3, 2: 3}))
	_assert("esgotados os dois contatos próximos, a ameaça à ponte volta para cima",
		ambos == 0, "escolheu %d com carga 3/3: -3-16 = -19 empata com a ameaça (-38+14) e o empate vai para o índice menor" % ambos)
	var ameaca_cansada := int(g._alvo_aliado_autonomo(0, 5, {0: 5}))
	_assert("nem a ameaça é intocável: cinco lances nela e a linha procura outro contato",
		ameaca_cansada == 1, "escolheu %d com carga 5 na ameaça" % ameaca_cansada)
	# ---- 4. Defunto não é alvo, tabuleiro vazio não trava -------------------------------------------
	g.enemies[0]["hp"] = 0.0
	g.enemies[1]["order"] = "CAPTURADO"
	var so_vivo := int(g._alvo_aliado_autonomo(0, 5, {}))
	_assert("casco a 0 e casco capturado estão fora da escada",
		so_vivo == 2, "escolheu %d com o 0 morto, o 1 capturado e só o 2 vivo" % so_vivo)
	for i in range(g.enemies.size()):
		g.enemies[i]["hp"] = 0.0
	_assert("tabuleiro sem hostil vivo devolve -1 em vez de mirar o nada",
		int(g._alvo_aliado_autonomo(0, 5, {})) == -1, "escada sem alvo")
	_assert("a leitura de ameaça também devolve -1 sem casco vivo",
		int(g._hostil_da_ponte()) == -1, "ponte sem contato")
	# ---- 5. CONCENTRADO atropela a escada, e a escada atropela o foco --------------------------------
	var gg := await _montar_jogo()
	_alinhar(gg)
	_zerar(gg)
	_mata_hostis_exceto(gg, [0, 1])
	var ponte_g := _ponte(gg)
	_poe_hostil(gg, 0, ponte_g + Vector3(0.0, 0.0, -5.0))
	_poe_hostil(gg, 1, ponte_g + Vector3(0.0, 0.0, -41.0))
	_poe_aliado(gg, 0, ponte_g + Vector3(0.0, 0.0, -38.0))
	gg.fogo_densidade = 0
	var concentrado := int(gg._alvo_aliado_autonomo(0, 0, {0: 5}))
	_assert("em CONCENTRADO a escada cede ao comando: o alvo da ponte, mesmo já saturado",
		concentrado == 0, "degrau 0 devolveu %d com foco 0, carga 5 e o hostil 1 a 3,0 u" % concentrado)
	gg.fogo_densidade = 1
	var iniciativa := int(gg._alvo_aliado_autonomo(0, 0, {}))
	_assert("no degrau do meio quem não está sob ordem de ataque escolhe o próprio contato",
		iniciativa == 1, "degrau 1 devolveu %d contra o foco 0 da ponte" % iniciativa)
	var cinco_no_perto := int(gg._alvo_aliado_autonomo(0, 0, {1: 5}))
	_assert("e a iniciativa também tem teto: saturado o casco perto, volta para a ameaça",
		cinco_no_perto == 0, "devolveu %d com carga 5 no hostil 1" % cinco_no_perto)
	_assert("um índice de casco fora da frota não mira nada",
		int(gg._alvo_aliado_autonomo(gg.fleet.size(), 0, {})) == -1, "casco inexistente -> -1")
	# ---- 6. A salva espalha com a escada e empilha em CONCENTRADO ------------------------------------
	_alinhar(gg)
	_zerar(gg)
	for unit in gg.fleet:
		unit["order"] = "LINHA"
	gg.rng.seed = 70707
	gg.fogo_densidade = 1
	gg.selected_target = 0
	gg._resolve_volley()
	var espalhado := _alvos_engajados(gg)
	var lidos_espalhado := String(gg.salva_resumo)
	var lances_espalhado := int(gg.salva_contagem["aliados"])
	_assert("a linha inteira em LINHA engaja mais de um contato só",
			espalhado > 1, "%s" % lidos_espalhado)
	_alinhar(gg)
	_zerar(gg)
	for unit in gg.fleet:
		unit["order"] = "LINHA"
	gg.rng.seed = 70707
	gg.fogo_densidade = 0
	gg.selected_target = 0
	gg._resolve_volley()
	var pilha := _alvos_engajados(gg)
	_assert("em CONCENTRADO a esquadra engaja um único contato",
		pilha == 1, "%d alvo(s) com disco de 4,5 u // %s" % [pilha, String(gg.salva_resumo)])
	_assert("e o número de lances não depende de para onde eles vão",
		lances_espalhado == FLECHAS_POR_SALVA * gg.fleet.size()
			and int(gg.salva_contagem["aliados"]) == lances_espalhado,
		"%d lances em linha e %d em concentrado para %d cascos" % [
			lances_espalhado, int(gg.salva_contagem["aliados"]), gg.fleet.size()])
	# ---- 7. Reserva atira no próprio alvo e cobra 0,35 -----------------------------------------------
	var gb := await _montar_jogo()
	_alinhar(gb)
	_zerar(gb)
	gb.fogo_densidade = 0
	for i in range(gb.fleet.size()):
		gb.fleet[i]["weapons"] = 0.0
		gb.fleet[i]["order"] = "LINHA"
	gb.selected_target = 0
	gb.fleet[0]["weapons"] = 100.0
	gb.rng.seed = 40404
	gb._resolve_volley()
	var linha_dano := 100.0 - float(gb.enemies[0]["hp"])
	_zerar(gb)
	# `_zerar` devolve armamento a todos: a segunda perna precisa do mesmo um-atirador-da-primeira,
	# senão a razão mede frota cheia contra reserva sola e não 0,35.
	for i in range(gb.fleet.size()):
		gb.fleet[i]["weapons"] = 0.0
		gb.fleet[i]["order"] = "LINHA"
	gb.fleet[0]["weapons"] = 100.0
	gb.fleet[0]["order"] = "RESERVA"
	gb.rng.seed = 40404
	gb._resolve_volley()
	var reserva_dano := 100.0 - float(gb.enemies[0]["hp"])
	var proporcao := reserva_dano / maxf(0.0001, linha_dano)
	_assert("a reserva tática bate no mesmo alvo por 0,35 do fogo",
		absf(proporcao - 0.35) < 0.0001,
		"%.3f contra %.3f de linha (razão %.4f)" % [reserva_dano, linha_dano, proporcao])
	# ---- 8. Contra-medida: a guarda fecha quando a ponte concentra -----------------------------------
	var gc := await _montar_jogo()
	var comando := int(gc._hostile_command_index())
	_alinhar(gc)
	_zerar(gc)
	gc.enemies[comando]["hp"] = 40.0
	gc.fogo_densidade = 1
	gc._apply_hostile_tactics()
	var folga_setor: Array[float] = []
	for i in range(gc.enemies.size()):
		if String(gc.enemies[i]["order"]) == "ESCOLTAR":
			folga_setor.append(float(gc.enemies[i]["escort_offset"]))
	var postura_setor := String(gc.hostile_posture)
	for quadro in range(QUADROS_DE_NAVEGACAO):
		gc._update_fleet(0.1)
	var ancorado_setor: Array[float] = []
	for i in range(gc.enemies.size()):
		if String(gc.enemies[i]["order"]) == "ESCOLTAR":
			ancorado_setor.append(_pos_hostil(gc, i).distance_to(_pos_hostil(gc, comando)))
	_alinhar(gc)
	_zerar(gc)
	gc.enemies[comando]["hp"] = 40.0
	gc.fogo_densidade = 0
	gc._apply_hostile_tactics()
	var postura_foco := String(gc.hostile_posture)
	var folga_foco: Array[float] = []
	for i in range(gc.enemies.size()):
		if String(gc.enemies[i]["order"]) == "ESCOLTAR":
			folga_foco.append(float(gc.enemies[i]["escort_offset"]))
	for quadro in range(QUADROS_DE_NAVEGACAO):
		gc._update_fleet(0.1)
	var ancorado_foco: Array[float] = []
	for i in range(gc.enemies.size()):
		if String(gc.enemies[i]["order"]) == "ESCOLTAR":
			ancorado_foco.append(_pos_hostil(gc, i).distance_to(_pos_hostil(gc, comando)))
	_assert("a capitânia ferida põe a esquadra em ESCOLTA nos dois lados da medida",
		postura_setor == "ESCOLTA" and postura_foco == "ESCOLTA",
		"posturas %s e %s com a capitânia a 40 de casco" % [postura_setor, postura_foco])
	_assert("com o disco da ponte largo, a guarda hostil fica a ±3",
		folga_setor.size() == 2 and absf(absf(folga_setor[0]) - 3.0) < 0.0001,
		"offsets %s" % str(folga_setor))
	_assert("e quando a ponte concentra, ela fecha para ±2",
		folga_foco.size() == 2 and absf(absf(folga_foco[0]) - 2.0) < 0.0001,
		"offsets %s com fogo_densidade 0" % str(folga_foco))
	var soma_setor := 0.0
	for v in ancorado_setor:
		soma_setor += v
	var soma_foco := 0.0
	for v in ancorado_foco:
		soma_foco += v
	_assert("o fechamento aparece na distância real dos escoltas à própria capitânia",
		soma_foco < soma_setor - 0.2,
		"%.3f u somados contra %.3f u depois de %d quadros de navegação" % [
			soma_foco, soma_setor, QUADROS_DE_NAVEGACAO])
	_assert("e o teto do fechamento é a separação de cascos: todo escolta fechado fica mais perto",
		ancorado_foco.size() == 2 and ancorado_setor.size() == 2
			and maxf(ancorado_foco[0], ancorado_foco[1]) < minf(ancorado_setor[0], ancorado_setor[1]),
		"fechados a %.3f e %.3f u contra largos a %.3f e %.3f u (separação mínima de cascos %.1f u)" % [
			ancorado_foco[0], ancorado_foco[1], ancorado_setor[0], ancorado_setor[1], 2.0 * HULL_RADIUS])
	# ---- 9. Nenhum dos pesos consome sorteio --------------------------------------------------------
	var gd := await _montar_jogo()
	_alinhar(gd)
	_zerar(gd)
	var sorteio_antes := int(gd.rng.state)
	var visual_antes := int(gd.visual_rng.state)
	for k in range(200):
		gd._alvo_aliado_autonomo(k % gd.fleet.size(), k % gd.enemies.size(), {0: k % 4})
		gd._hostil_da_ponte()
	_assert("duzentas leituras da escada não movem um dígito do gerador de combate",
		int(gd.rng.state) == sorteio_antes, "rng %d intacto" % sorteio_antes)
	_assert("nem do gerador visual",
		int(gd.visual_rng.state) == visual_antes, "visual_rng %d intacto" % visual_antes)
	# ---- 10. A prova central: dois tabuleiros, mesma semente, mesmos dados ---------------------------
	# Lado A puxa o hostil 3 para dentro da guarda da ponte, isolado da própria linha: a escada manda
	# a esquadra toda atrás dele e o disco de 14 u cai quase todo no vazio. Lado B é o mesmo tabuleiro
	# com o casco de volta à linha. A única diferença é onde a iniciativa aponta.
	var ge := await _montar_jogo()
	_alinhar(ge)
	_zerar(ge)
	ge.fogo_densidade = 1
	ge.rng.seed = 88808
	ge.selected_target = 0
	_poe_hostil(ge, 3, _ponte(ge) + Vector3(0.0, 0.0, -8.0))
	ge._resolve_volley()
	var amostra_a := {
		"rng": int(ge.rng.state),
		"lances": int(ge.salva_contagem["aliados"]),
		"hostis_lances": int(ge.salva_contagem["hostis"]),
		"cascos": _cascos_somados(ge),
		"feridos": int(ge.salva_contagem["aliados_feriram"]),
		"alvos": _alvos_engajados(ge),
	}
	var gf := await _montar_jogo()
	_alinhar(gf)
	_zerar(gf)
	gf.fogo_densidade = 1
	gf.rng.seed = 88808
	gf.selected_target = 0
	gf._resolve_volley()
	var amostra_b := {
		"rng": int(gf.rng.state),
		"lances": int(gf.salva_contagem["aliados"]),
		"hostis_lances": int(gf.salva_contagem["hostis"]),
		"cascos": _cascos_somados(gf),
		"feridos": int(gf.salva_contagem["aliados_feriram"]),
		"alvos": _alvos_engajados(gf),
	}
	_assert("a salva gasta exatamente os mesmos sorteios com a escada apontando para outro lado",
		int(amostra_a["rng"]) == int(amostra_b["rng"]), "rng.state %s dos dois lados" % str(amostra_a["rng"]))
	_assert("e dispara o mesmo número de lances dos dois lados",
		amostra_a["lances"] == amostra_b["lances"] and amostra_a["hostis_lances"] == amostra_b["hostis_lances"],
		"%s+%s contra %s+%s impactos" % [str(amostra_a["lances"]), str(amostra_a["hostis_lances"]),
			str(amostra_b["lances"]), str(amostra_b["hostis_lances"])])
	_assert("ameaça isolada faz a esquadra engajar menos contatos que a linha fechada",
		int(amostra_a["alvos"]) < int(amostra_b["alvos"]),
		"%s alvo(s) atrás do casco isolado contra %s na linha" % [str(amostra_a["alvos"]), str(amostra_b["alvos"])])
	_assert("ainda assim o casco somado sai diferente (a mira mudou, o sorteio não)",
		not is_equal_approx(float(amostra_a["cascos"]), float(amostra_b["cascos"])),
		"%s contra %s de casco somado, %s contra %s lances feriram" % [
			str(float(amostra_a["cascos"])), str(float(amostra_b["cascos"])),
			str(amostra_a["feridos"]), str(amostra_b["feridos"])])
	# ---- 11. O contrato antigo continua em pé -------------------------------------------------------
	var gm := await _montar_jogo()
	_alinhar(gm)
	_zerar(gm)
	gm._update_hud()
	var linhas_antes: PackedStringArray = String(gm.command_label.text).split("\n")
	var blips_antes := int(gm.holo_root.get_child_count())
	var total_botoes := 0
	for nome in gm.group_bodies:
		for filho in (gm.group_bodies[nome] as Control).get_children():
			if filho is Button:
				total_botoes += 1
	# Uma salva com a escada ligada não pode mexer em nada disso.
	gm.rng.seed = 88808
	gm.fogo_densidade = 1
	gm._resolve_volley()
	var linhas_depois: PackedStringArray = String(gm.command_label.text).split("\n")
	_assert("o HUD continua com exatamente cinco linhas", linhas_depois.size() == 5,
		"%d linhas depois da salva (%d antes)" % [linhas_depois.size(), linhas_antes.size()])
	_assert("a linha do reconhecimento continua sendo a do reconhecimento",
		linhas_depois[2].begins_with("RECONHECIMENTO:"), linhas_depois[2])
	_assert("a última linha continua sendo a leitura da postura hostil",
		linhas_depois[4].begins_with("POSTURA HOSTIL:"), linhas_depois[4])
	_assert("os trinta comandos continuam no painel", total_botoes == 30,
			"%d botões e primeira linha «%s»" % [total_botoes, linhas_antes[0]])
	_assert("o holograma não ganha nem perde um filho por causa da escada",
		int(gm.holo_root.get_child_count()) == blips_antes,
		"%d filhos antes e %d depois da salva" % [blips_antes, int(gm.holo_root.get_child_count())])

	print("SONDA-IA: " + "\nSONDA-IA: ".join(notes))
	print("SONDA-IA: veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	quit()
