extends SceneTree

## Sonda da salva em área: a chuva de flechas, o disco que obedece à ponte e o vão que cobra caro.
##
## O pedido do comandante foi literal: «o tiro não precisa ser todos focados em uma única nave,
## pode se parecer com a chuva de flechas em que elas atingem uma área, e o concentrar e dispersar
## fogo aumentam e diminuem esta área». Área de verdade tem consequência de verdade, então esta
## sonda cobra quatro coisas que um painel com botão bonito não prova sozinho:
##
## 1) O DISCO EXISTE GEOMETRICAMENTE. Cada navio põe FLECHAS_POR_SALVA pontos de impacto, o do
##    centro na mira e o da borda exatamente a FOGO_RAIO do degrau, todos deitados no PLANO DA MESA
##    (lateral e profundidade a partir do alvo). Espalhar para cima seria chover no nada: as
##    esquadras vivem em y ≈ 0, e o anel desenhado na mesa holográfica é plano. Se o "raio" for
##    enfeite de relatório, a asserção de distância quebra.
## 2) CONCENTRAR FOCA E DISPERSAR COBRE. A régua é um tabuleiro só, medido nos três degraus com a
##    mesma semente: um visado na mira e uma isca parada sobre a borda do disco largo. Estreito
##    empilha os três lances no visado e não toca a isca; largo dá uma terça parte a cada um e
##    alcança quem estava fora de alcance do estreito — cobrando, em ambos os casos, só o que cai
##    no vão. O meio-termo existe e tem preço próprio.
## 3) O VÃO É REAL. Impacto que não encontra casco a até HULL_RADIUS + FOGO_LETAL não fere ninguém
##    e aparece na conta como vão. Dano que não pode se perder não é dispersão, é o mesmo tiro com
##    nome diferente.
## 4) DENSIDADE NÃO É SORTEIO. A prova central: duas partidas na mesma semente, uma salva cada,
##    uma concentrada e outra dispersa. O `rng.state` tem de sair dígito por dígito igual, e o
##    casco somado, diferente. Se atirar menos lances quando o disco é estreito, a densidade estaria
##    relançando a batalha inteira — é exatamente o erro que o cinturão de asteroides já não pode
##    cometer (ver `tools/probes/cenarios.gd`).
##
## Cobramos ainda o lado que ninguém pediu e que quebra junto: a cobertura de escolta agora vale
## sobre quem LEVA o impacto, não sobre quem é visado; a densidade hostil vem da postura, não de um
## sorteio por salva; a mesa holográfica desenha o disco sem virar blip de casco; e os dois botões
## novos do painel mexem na densidade sem tocar na ordem de navio nenhum.
##
## Uso: godot --headless --path . --quit-after 1800 -s res://tools/probes/salva.gd

## Espelho das constantes de `main.gd`. Se o número aqui divergir do código, a asserção quebra: é
## de propósito, porque a régua da salva é contrato, não detalhe de implementação.
const HULL_RADIUS := 2.4
const FLECHAS_POR_SALVA := 3
const FOGO_RAIO := [4.5, 14.0, 28.0]
const FOGO_NOME := ["CONCENTRADO", "SETOR", "DISPERSO"]
const FOGO_LETAL := 3.2
const DANO_ALIADO_BASE := 2.5
const FATOR_ATACAR := 1.8
const DANO_HOSTIL_BASE := 1.3
const COBERTURA_ESCOLTA := 0.7
const HOLO_SCALE := 0.075
const HOLO_ANCHOR_Z := -60.0

## A linha de tiro das medições de disco: um atirador aliado em TIRO e o visado em VISADA, ao longo
## de -Z. É a única forma de calcular o disco fora do jogo e esperar que ele caia onde o jogo o põe.
const TIRO := Vector3(0.0, 0.0, -40.0)
const VISADA := Vector3(0.0, 0.0, -80.0)

var breaks := 0
var notes: Array[String] = []

func _assert(label: String, condition: bool, detail: String) -> void:
	if condition:
		notes.append("OK   %s — %s" % [label, detail])
	else:
		breaks += 1
		notes.append("QUEBRA %s — %s" % [label, detail])

func _igual(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol

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

func _ordens_aliadas(game) -> String:
	var saida := ""
	for unit in game.fleet:
		saida += String(unit["order"]) + ","
	return saida

func _botoes(game, nome: String) -> Array[Button]:
	var lista: Array[Button] = []
	var corpo: Control = game.group_bodies[nome]
	for filho in corpo.get_children():
		if filho is Button:
			lista.append(filho as Button)
	return lista

## Silencia a frota inteira e deixa UM casco armado e sob ordem de ataque, com a mira de tabuleiro
## limpa ao longo de -Z: atirador em TIRO, visado em VISADA. Sem isto, seis salvas sobrepostas não
## deixariam medir um único disco. As duas posições são as mesmas constantes que as seções usam para
## calcular o disco — calcular em torno de uma mira que não é onde o casco está mede o vão errado.
func _atirador_solitario(game, no_aliado: int, no_alvo: int) -> void:
	for i in range(game.fleet.size()):
		game.fleet[i]["weapons"] = 0.0
		game.fleet[i]["order"] = "LINHA"
	game.fleet[no_aliado]["weapons"] = 100.0
	game.fleet[no_aliado]["order"] = "ATACAR"
	(game.fleet[no_aliado]["node"] as Node3D).position = TIRO
	(game.enemies[no_alvo]["node"] as Node3D).position = VISADA
	game.selected_target = no_alvo

## Tabuleiro da régua de densidade: uma única atiradora aliada sob ATACAR, um visado no centro da
## mira e uma isca parada exatamente sobre a borda do disco largo (a FOGO_RAIO[2] da mira, no plano
## da mesa). Todo o resto está morto de propósito: é a única forma de ler o que um disco faz sem
## que os outros onze lances sobrepostos apaguem a medida. Devolve a conta já colhida.
func _regra_de_disco(game, degrau: int) -> Dictionary:
	_alinhar(game)
	_zerar(game)
	_atirador_solitario(game, 0, 0)
	for i in range(1, game.enemies.size()):
		game.enemies[i]["hp"] = 0.0
	game.enemies[0]["weapons"] = 0.0
	var borda: Array[Vector3] = game._pontos_de_impacto(TIRO, VISADA, 0, 2)
	var isca: Dictionary = game.enemies[1]
	(isca["node"] as Node3D).position = borda[FLECHAS_POR_SALVA - 1]
	isca["hp"] = 100.0
	isca["weapons"] = 0.0
	game.enemies[1] = isca
	game.rng.seed = 5150
	game.fogo_densidade = degrau
	game._resolve_volley()
	var visado := 100.0 - float(game.enemies[0]["hp"])
	var casco_isca := 100.0 - float(game.enemies[1]["hp"])
	return {
		"visado": visado,
		"isca": casco_isca,
		"tocados": (1 if visado > 0.0 else 0) + (1 if casco_isca > 0.0 else 0),
		"vao": int(game.salva_contagem["vaos"]),
		"lances": int(game.salva_contagem["aliados"]),
		"soma": visado + casco_isca,
	}


func _initialize() -> void:
	# ---- 1. A escada de densidade --------------------------------------------------------------
	var g := await _montar_jogo()
	_alinhar(g)
	_zerar(g)
	_assert("a escada tem três degraus e nenhum quarto",
		int(g.FLECHAS_POR_SALVA) == FLECHAS_POR_SALVA and g.FOGO_RAIO.size() == 3
			and g.FOGO_NOME.size() == 3,
		"%d degraus, raios %s" % [g.FOGO_RAIO.size(), str(g.FOGO_RAIO)])
	_assert("abre no degrau do meio: esquadra em linha não pilha fogo nem varre o nada",
		int(g.fogo_densidade) == 1, "degrau inicial %d (%s)" % [int(g.fogo_densidade),
			String(g.FOGO_NOME[int(g.fogo_densidade)])])
	g._ajustar_fogo(-1)
	_assert("concentrar desce um degrau e anuncia o raio novo",
		int(g.fogo_densidade) == 0 and String(g.report_label.text).contains("4.5 u"),
		"degrau %d, relatório: %s" % [int(g.fogo_densidade), String(g.report_label.text)])
	g._ajustar_fogo(-1)
	_assert("no fundo da escada o clique não afunda mais",
		int(g.fogo_densidade) == 0, "degrau continua %d" % int(g.fogo_densidade))
	g._ajustar_fogo(1)
	g._ajustar_fogo(1)
	g._ajustar_fogo(1)
	_assert("no topo da escada o clique não sobe mais", int(g.fogo_densidade) == 2,
		"degrau %d, disco de %.1f u" % [int(g.fogo_densidade), float(g.FOGO_RAIO[2])])
	_assert("o HUD devolve o degrau e o raio na linha da formação",
		String(g.command_label.text).split("\n")[1].contains("FOGO: DISPERSO (28.0 u)"),
		String(g.command_label.text).split("\n")[1])

	# ---- 2. O disco é geometria, não adjetivo --------------------------------------------------
	# Três pontos por salva, o do centro exatamente na mira e o da borda exatamente a FOGO_RAIO do
	# degrau. E o disco deita no plano da mesa: nada de leque para cima, onde nenhuma esquadra vive.
	var visada: Vector3 = VISADA
	var tiro: Vector3 = TIRO
	for degrau in range(3):
		var pontos: Array[Vector3] = g._pontos_de_impacto(tiro, visada, 3, degrau)
		var esperado: float = FOGO_RAIO[degrau]
		var no_centro := pontos.size() == FLECHAS_POR_SALVA and _igual(pontos[0].distance_to(visada), 0.0, 0.0001)
		var na_borda := no_centro and _igual(pontos[FLECHAS_POR_SALVA - 1].distance_to(visada), esperado, 0.0001)
		var no_plano := true
		var com_lado := false
		var com_fundo := false
		for ponto in pontos:
			# y igual ao da mira: o lance espalha para os lados e para a profundidade, nunca para
			# cima ou para baixo do plano onde a esquadra está.
			if absf(ponto.y - visada.y) > 0.0001:
				no_plano = false
			if absf(ponto.x - visada.x) > 0.0001:
				com_lado = true
			if absf(ponto.z - visada.z) > 0.0001:
				com_fundo = true
		_assert("degrau %d: %d impactos, o do centro na mira, o da borda a %.1f u, todos no plano da mesa" % [degrau, FLECHAS_POR_SALVA, esperado],
			na_borda and no_plano and com_lado and com_fundo,
			"distâncias %s" % str([pontos[0].distance_to(visada), pontos[1].distance_to(visada),
				pontos[2].distance_to(visada)]))
	var bordas: Array[Vector3] = []
	for no_casco in range(6):
		bordas.append(g._pontos_de_impacto(tiro, visada, no_casco, 2)[FLECHAS_POR_SALVA - 1])
	var distintos := true
	for i in range(bordas.size()):
		for j in range(i + 1, bordas.size()):
			if bordas[i].distance_squared_to(bordas[j]) < 0.000001:
				distintos = false
	_assert("cada casco tem o próprio giro no disco: a salva da esquadra não é um clone em série",
		distintos,
		"bordas em x %s" % str([bordas[0].x, bordas[1].x, bordas[2].x, bordas[3].x,
			bordas[4].x, bordas[5].x]))
	# Tiro na vertical: `direcao.cross(UP)` é nulo, então o disco cai no plano X-Y a partir do ALVO
	# (que é onde a mira está, não de onde o navio dispara). É a queda do eixo, medida de verdade.
	var mira_em_cima: Vector3 = visada + Vector3(0.0, -30.0, 0.0)
	var ponto_de_cima: Array[Vector3] = g._pontos_de_impacto(visada, mira_em_cima, 0, 2)
	_assert("tiro na vertical continua tendo disco (sem eixo paralelo a UP)",
		ponto_de_cima.size() == FLECHAS_POR_SALVA
			and _igual(ponto_de_cima[2].distance_to(mira_em_cima), FOGO_RAIO[2], 0.0001),
		"distância da borda %.3f" % ponto_de_cima[2].distance_to(mira_em_cima))
	var colado: Array[Vector3] = g._pontos_de_impacto(visada, visada, 0, 1)
	_assert("dois cascos colados não viram direção nula", colado.size() == FLECHAS_POR_SALVA
		and _igual(colado[0].distance_to(visada), 0.0, 0.0001),
		"%d pontos, o primeiro a %.3f u" % [colado.size(), colado[0].distance_to(visada)])

	# ---- 3. Concentrar: os três impactos no mesmo casco ----------------------------------------
	var c := await _montar_jogo()
	_alinhar(c)
	_zerar(c)
	c.rng.seed = 71001
	_atirador_solitario(c, 0, 0)
	for i in range(1, c.enemies.size()):
		c.enemies[i]["hp"] = 0.0
	c.enemies[0]["weapons"] = 0.0
	c.fogo_densidade = 0
	var alvo_c: Dictionary = c.enemies[0]
	var antes_c := float(alvo_c["hp"])
	c._resolve_volley()
	var perda_c := antes_c - float(alvo_c["hp"])
	var esperado_foco := DANO_ALIADO_BASE * FATOR_ATACAR
	_assert("fogo concentrado empilha os três lances no alvo: a régua velida, inteira",
		_igual(perda_c, esperado_foco, 0.0001),
		"%.3f de casco perdido, régua %.3f (2,5 x 1,8)" % [perda_c, esperado_foco])
	_assert("nada caiu no vão quando o disco cabe no casco",
		int(c.salva_contagem["aliados"]) == FLECHAS_POR_SALVA
			and int(c.salva_contagem["aliados_feriram"]) == FLECHAS_POR_SALVA
			and int(c.salva_contagem["vaos"]) == 0,
		"%d/%d feriram, %d no vão" % [int(c.salva_contagem["aliados_feriram"]),
			int(c.salva_contagem["aliados"]), int(c.salva_contagem["vaos"])])

	# ---- 4. Dispersar: um no alvo, um na isca, um no nada --------------------------------------
	var d := await _montar_jogo()
	_alinhar(d)
	_zerar(d)
	d.rng.seed = 71001
	_atirador_solitario(d, 0, 0)
	for i in range(1, d.enemies.size()):
		d.enemies[i]["hp"] = 0.0
	d.enemies[0]["weapons"] = 0.0
	d.fogo_densidade = 2
	var borda: Array[Vector3] = d._pontos_de_impacto(tiro, visada, 0, 2)
	var isca: Dictionary = d.enemies[1]
	(isca["node"] as Node3D).position = borda[FLECHAS_POR_SALVA - 1]
	isca["hp"] = 100.0
	isca["weapons"] = 0.0
	d.enemies[1] = isca
	var alvo_d: Dictionary = d.enemies[0]
	var antes_alvo := float(alvo_d["hp"])
	d._resolve_volley()
	var perda_alvo := antes_alvo - float(alvo_d["hp"])
	var perda_isca := 100.0 - float(d.enemies[1]["hp"])
	_assert("disco largo: o alvo fica com a terça parte do fogo",
		_igual(perda_alvo, esperado_foco / float(FLECHAS_POR_SALVA), 0.0001),
		"%.3f no visado contra %.3f concentrado" % [perda_alvo, perda_c])
	_assert("e a nave que estava na borda do disco leva o lance que o alvo perdeu",
		_igual(perda_isca, esperado_foco / float(FLECHAS_POR_SALVA), 0.0001),
		"%.3f na isca a %.1f u da mira" % [perda_isca, borda[2].distance_to(visada)])
	_assert("o terceiro lance caiu no espaço vazio e está na conta como vão",
		int(d.salva_contagem["vaos"]) >= 1,
		"%d/%d feriram, %d no vão, %d na pedra" % [int(d.salva_contagem["aliados_feriram"]),
			int(d.salva_contagem["aliados"]), int(d.salva_contagem["vaos"]),
			int(d.salva_contagem["pedras"])])
	_assert("a conta da salva fecha com os lances disparados",
		int(d.salva_contagem["aliados_feriram"]) + int(d.salva_contagem["vaos"])
			+ int(d.salva_contagem["pedras"]) == int(d.salva_contagem["aliados"]),
		"%d = %d + %d + %d" % [int(d.salva_contagem["aliados"]),
			int(d.salva_contagem["aliados_feriram"]), int(d.salva_contagem["vaos"]),
			int(d.salva_contagem["pedras"])])

	# ---- 5. Dois cascos a 30 u: um na borda, outro fora de qualquer disco ----------------------
	var e := await _montar_jogo()
	_alinhar(e)
	_zerar(e)
	e.rng.seed = 71001
	_atirador_solitario(e, 0, 0)
	for i in range(1, e.enemies.size()):
		e.enemies[i]["hp"] = 0.0
	e.enemies[0]["weapons"] = 0.0
	e.fogo_densidade = 2
	var borda_e: Array[Vector3] = e._pontos_de_impacto(tiro, visada, 0, 2)
	var fora: Dictionary = e.enemies[1]
	(fora["node"] as Node3D).position = visada + Vector3(30.0, 0.0, 0.0)
	fora["hp"] = 100.0
	fora["weapons"] = 0.0
	e.enemies[1] = fora
	e._resolve_volley()
	_assert("o que está fora do disco não é atingido em nenhuma densidade",
		float(e.enemies[1]["hp"]) == 100.0,
		"casco %.1f a 30 u da mira, disco de %.1f u" % [float(e.enemies[1]["hp"]), FOGO_RAIO[2]])

	# ---- 6. A régua do pedido: mesmo tabuleiro, três degraus ------------------------------------
	# Uma atiradora, um visado na mira e uma isca estacionada sobre a borda do disco de 28 u. Muda
	# só o degrau. É a pergunta do comandante medida crua: área estreita empilha dano num casco só;
	# área larga alcança quem estava fora de alcance do estreito - e paga por isso em lances que
	# caem no vão. Mesma semente, mesmas ordens, mesmos três lances disparados nos três degraus.
	var estreito := await _montar_jogo()
	var r0: Dictionary = _regra_de_disco(estreito, 0)
	var meio := await _montar_jogo()
	var r1 := _regra_de_disco(meio, 1)
	var largo := await _montar_jogo()
	var r2 := _regra_de_disco(largo, 2)
	_assert("CONCENTRADO empilha os três lances no visado: %.1f de casco, régua inteira" % FOGO_RAIO[0],
			_igual(float(r0["visado"]), DANO_ALIADO_BASE * FATOR_ATACAR, 0.0001)
				and _igual(float(r0["isca"]), 0.0, 0.0001) and int(r0["vao"]) == 0
				and int(r0["tocados"]) == 1,
			"visado %.3f, isca %.3f, %d no vão, %d casco(s) tocado(s)" % [float(r0["visado"]),
				float(r0["isca"]), int(r0["vao"]), int(r0["tocados"])])
	_assert("DISPERSO alcança a isca a 28 u: o degrau estreito jamais a tocaria",
			_igual(float(r2["isca"]), DANO_ALIADO_BASE * FATOR_ATACAR / float(FLECHAS_POR_SALVA), 0.0001)
				and _igual(float(r0["isca"]), 0.0, 0.0001) and int(r2["tocados"]) == 2,
			"isca perdeu %.3f no largo contra %.3f no estreito" % [float(r2["isca"]), float(r0["isca"])])
	_assert("e o disco largo cobra a franja: um dos três lances cai no vão",
			int(r2["vao"]) == 1 and _igual(float(r2["visado"]),
				DANO_ALIADO_BASE * FATOR_ATACAR / float(FLECHAS_POR_SALVA), 0.0001),
			"%d no vão, visado %.3f" % [int(r2["vao"]), float(r2["visado"])])
	_assert("o meio-termo existe e tem preço próprio: só o visado, uma terça parte, dois no vão",
			_igual(float(r1["visado"]), DANO_ALIADO_BASE * FATOR_ATACAR / float(FLECHAS_POR_SALVA), 0.0001)
				and int(r1["vao"]) == 2 and int(r1["tocados"]) == 1,
			"disco de %.1f u: visado %.3f, %d no vão" % [FOGO_RAIO[1], float(r1["visado"]), int(r1["vao"])])
	_assert("densidade não é gatilho: os três degraus disparam exatamente três lances",
			int(r0["lances"]) == FLECHAS_POR_SALVA and int(r1["lances"]) == FLECHAS_POR_SALVA
				and int(r2["lances"]) == FLECHAS_POR_SALVA,
			"%d / %d / %d lances" % [int(r0["lances"]), int(r1["lances"]), int(r2["lances"])])
	_assert("concentrar rende mais casco no alvo: a conta somada fecha em ordem decrescente",
			float(r0["soma"]) > float(r2["soma"]) and float(r2["soma"]) > float(r1["soma"]),
			"somado %.3f (estreito) > %.3f (largo) > %.3f (meio)" % [float(r0["soma"]),
				float(r2["soma"]), float(r1["soma"])])

	# ---- 7. A prova central: densidade muda dano, não sorteio ----------------------------------
	# Tabuleiro cheio, seis de cada lado, ordens como o jogo as monta, uma única salva, mesma
	# semente. Um casco que morresse no meio mudaria o número de atiradores e aí a cauda divergiria
	# por um motivo legítimo — por isso esta asserção é de uma salva, não de vinte.
	var a := await _montar_jogo()
	_alinhar(a)
	_zerar(a)
	a.rng.seed = 5150
	a.fogo_densidade = 0
	a._resolve_volley()
	var estado_a: int = a.rng.state
	var soma_a := _cascos_somados(a)
	var b := await _montar_jogo()
	_alinhar(b)
	_zerar(b)
	b.rng.seed = 5150
	b.fogo_densidade = 2
	b._resolve_volley()
	var estado_b: int = b.rng.state
	var soma_b := _cascos_somados(b)
	_assert("a mesma salva em dois degraus consome exatamente os mesmos sorteios",
		int(estado_a) == int(estado_b), "rng %d dos dois lados" % estado_a)
	_assert("e ainda assim os cascos somados saem diferentes (dano mudou, sorteio não)",
		absf(soma_a - soma_b) > 0.001, "%.3f contra %.3f de casco somado" % [soma_a, soma_b])
	_assert("o lances por salva não depende de quem acertou: seis atiradores de cada lado",
		int(a.salva_contagem["aliados"]) == int(b.salva_contagem["aliados"])
			and int(a.salva_contagem["hostis"]) == int(b.salva_contagem["hostis"]),
		"%d+%d contra %d+%d impactos" % [int(a.salva_contagem["aliados"]),
			int(a.salva_contagem["hostis"]), int(b.salva_contagem["aliados"]),
			int(b.salva_contagem["hostis"])])

	# ---- 8. Cobertura é de quem leva o impacto --------------------------------------------------
	# Antes o 0,7 da escolta caía sobre o casco VISADO, o que fazia escoltar um navio longe de tudo
	# valer mais do que estar na frente do tiro. Agora a régua é geométrica, então A e B mudam só a
	# ordem do casco que está na borda do disco hostil.
	var p := await _montar_jogo()
	_alinhar(p)
	_zerar(p)
	p.rng.seed = 20261020
	# Frota desarmada: quem mede a cobertura aqui é a esquadra hostil.
	for unit in p.fleet:
		unit["weapons"] = 0.0
	for i in range(1, p.enemies.size()):
		p.enemies[i]["weapons"] = 0.0
	p.fleet[2]["order"] = "ATACAR"
	p.fleet[3]["order"] = "LINHA"
	p._apply_hostile_tactics()
	var degrau_p := int(p._densidade_hostil())
	var foco_p: int = int(p.hostile_focus)
	var origem_p: Vector3 = (p.enemies[0]["node"] as Node3D).global_position
	var destino_p: Vector3 = (p.fleet[foco_p]["node"] as Node3D).global_position
	var pontos_p: Array[Vector3] = p._pontos_de_impacto(origem_p, destino_p, 0, degrau_p)
	(p.fleet[3]["node"] as Node3D).position = pontos_p[1]
	var antes_longo := 100.0 - float(p.fleet[2]["hp"])
	p._resolve_volley()
	var cobertura_linha := 100.0 - float(p.fleet[3]["hp"])
	var q := await _montar_jogo()
	_alinhar(q)
	_zerar(q)
	q.rng.seed = 20261020
	for unit in q.fleet:
		unit["weapons"] = 0.0
	for i in range(1, q.enemies.size()):
		q.enemies[i]["weapons"] = 0.0
	q.fleet[2]["order"] = "ATACAR"
	q.fleet[3]["order"] = "ESCOLTAR"
	q._apply_hostile_tactics()
	var pontos_q: Array[Vector3] = q._pontos_de_impacto(origem_p, destino_p, 0, int(q._densidade_hostil()))
	(q.fleet[3]["node"] as Node3D).position = pontos_q[1]
	q._resolve_volley()
	var cobertura_escolta := 100.0 - float(q.fleet[3]["hp"])
	_assert("o disco hostil tem centro, borda e ângulo estáveis entre duas partidas iguais",
		_igual(pontos_p[1].distance_to(destino_p), FOGO_RAIO[degrau_p] * 0.5, 0.0001)
			and pontos_p.size() == pontos_q.size(),
		"degrau hostil %d, borda %.1f u, ponto 1 a %.3f u da mira" % [degrau_p, FOGO_RAIO[degrau_p],
			pontos_p[1].distance_to(destino_p)])
	_assert("escoltar vale 0,7 sobre o casco que está no caminho do tiro",
		cobertura_linha > 0.001 and _igual(cobertura_escolta, cobertura_linha * COBERTURA_ESCOLTA, 0.0001),
		"%.4f de casco contra %.4f na mesma coordenada" % [cobertura_escolta, cobertura_linha])
	_assert("o visado continua levando o lance do centro em ambos os casos",
		float(p.fleet[2]["hp"]) < 100.0 and float(q.fleet[2]["hp"]) < 100.0,
		"foco %d em %.1f e %.1f de casco" % [foco_p, float(p.fleet[2]["hp"]), float(q.fleet[2]["hp"])])
	_assert("antes da mudança a medição estava em cima de um casco vivo de verdade",
		antes_longo == 0.0 and foco_p == 2,
		"foco %d, perda antes da salva %.1f" % [foco_p, antes_longo])

	# ---- 9. A densidade hostil vem da postura, não de sorteio -----------------------------------
	var h := await _montar_jogo()
	_alinhar(h)
	_zerar(h)
	h.rng.seed = 424242
	h._apply_hostile_tactics()
	_assert("forças iguais na linha de partida: quem avança varre área (degrau do meio)",
		String(h.hostile_posture) == "AVANÇAR" and int(h._densidade_hostil()) == 1,
		"%s -> degrau %d" % [String(h.hostile_posture), int(h._densidade_hostil())])
	h.enemies[0]["hp"] = 50.0
	h._apply_hostile_tactics()
	_assert("capitânia hostil ferida: quem cobre concentra o disco no casco que ameaça",
		String(h.hostile_posture) == "ESCOLTA" and int(h._densidade_hostil()) == 0,
		"%s -> degrau %d" % [String(h.hostile_posture), int(h._densidade_hostil())])
	h.enemies[0]["hp"] = 0.0
	h._apply_hostile_tactics()
	_assert("sem capitânia a esquadra debanda e atira largo, que é o desperdício de uma fuga",
		String(h.hostile_posture) == "RECUAR" and int(h._densidade_hostil()) == 2,
		"%s -> degrau %d" % [String(h.hostile_posture), int(h._densidade_hostil())])
	var sorteio_antes: int = h.rng.state
	h._densidade_hostil()
	h._densidade_hostil()
	_assert("ler a postura não gasta um dígito do gerador de combate",
		int(h.rng.state) == int(sorteio_antes), "rng %d antes e depois de duas leituras" % sorteio_antes)

	# ---- 10. A mesa desenha o disco sem virar blip -----------------------------------------------
	var m := await _montar_jogo()
	_alinhar(m)
	_zerar(m)
	m.rng.seed = 909090
	_assert("o aro do setor mora na ponte, não na lista de blips",
		is_instance_valid(m.holo_setor) and m.holo_setor.get_parent() == m.bridge_rig,
		"pai = %s" % str(m.holo_setor.get_parent()))
	_assert("um blip por casco vivo continua valendo com o disco desenhado",
		m.holo_root.get_child_count() == m.fleet.size() + m.enemies.size(),
		"%d filhos na mesa para %d cascos" % [int(m.holo_root.get_child_count()),
			m.fleet.size() + m.enemies.size()])
	# O motor pode aceitar a escrita do raio e ainda assim recusar o toro: interno igual ao externo
	# devolve erro e nenhuma geometria, com a propriedade lendo o número certo. Medir o corpo do nó
	# é o que separa "o raio foi escrito" de "o aro existe", e é a única asserção possível nos dois
	# sentidos da escada — a escrita errada só quebra no degrau em que encosta no default da malha.
	var caixa_aro: Vector3 = m.holo_setor.get_aabb().size
	_assert("o aro desenhado na ponte tem corpo de verdade",
		caixa_aro.length() > 0.0,
		"caixa %.3f × %.3f × %.3f no degrau %d (interno %.3f, externo %.3f)" % [
			caixa_aro.x, caixa_aro.y, caixa_aro.z, m.fogo_densidade,
			(m.holo_setor.mesh as TorusMesh).inner_radius,
			(m.holo_setor.mesh as TorusMesh).outer_radius])
	m.fogo_densidade = 0
	m._desenhar_setor_de_fogo()
	var caixa_apertada: Vector3 = m.holo_setor.get_aabb().size
	_assert("fechar o disco não derruba o aro: o corpo sobrevive ao degrau estreito",
		caixa_apertada.length() > 0.0,
		"caixa %.3f × %.3f × %.3f no degrau 0" % [caixa_apertada.x, caixa_apertada.y, caixa_apertada.z])
	m.fogo_densidade = 1
	m._desenhar_setor_de_fogo()
	var aro_m: TorusMesh = m.holo_setor.mesh as TorusMesh
	var borda_aperta: float = aro_m.outer_radius
	m.fogo_densidade = 2
	m._desenhar_setor_de_fogo()
	_assert("o aro na mesa cresce com o degrau pedido",
		aro_m.outer_radius > borda_aperta + 0.5,
		"aro %.3f para %.3f na escala da mesa" % [borda_aperta, aro_m.outer_radius])
	m.selected_target = 3
	m._on_target_selected(3)
	var esperado_m: Vector3 = m.holo_root.position + m._holo_de((m.enemies[3]["node"] as Node3D).global_position)
	_assert("escolher o alvo move o disco na mesa antes de qualquer salva",
		m.holo_setor.position.distance_to(esperado_m) < 0.0001,
		"aro em %s, mira em %s" % [str(m.holo_setor.position), str(esperado_m)])
	m._resolve_volley()
	_assert("a salva confirma o centro do disco no alvo comandado",
		m.setor_fogo_pos.distance_to((m.enemies[3]["node"] as Node3D).global_position) < 0.0001,
		"centro a %.3f u do alvo" % m.setor_fogo_pos.distance_to((m.enemies[3]["node"] as Node3D).global_position))

	# ---- 11. O painel entrega densidade, não ordem de navio --------------------------------------
	var pp := await _montar_jogo()
	_alinhar(pp)
	_zerar(pp)
	var botoes := _botoes(pp, "ATAQUE")
	_assert("o grupo ATAQUE passou a ter quatro botões: dois de ordem e dois de densidade",
		botoes.size() == 4, "%d botões" % botoes.size())
	var ordens_antes := _ordens_aliadas(pp)
	var degrau_inicial := int(pp.fogo_densidade)
	botoes[2].pressed.emit()
	_assert("CONCENTRAR FOGO desce um degrau sem tocar em ordem de navio nenhum",
		int(pp.fogo_densidade) == degrau_inicial - 1 and _ordens_aliadas(pp) == ordens_antes,
		"degrau %d -> %d, ordens intactas=%s" % [degrau_inicial, int(pp.fogo_densidade),
			str(_ordens_aliadas(pp) == ordens_antes)])
	botoes[3].pressed.emit()
	botoes[3].pressed.emit()
	_assert("DISPERSAR FOGO sobe degrau por clique e para no teto",
		int(pp.fogo_densidade) == 2, "degrau %d depois de dois cliques" % int(pp.fogo_densidade))
	var casco_antes := _cascos_somados(pp)
	botoes[2].pressed.emit()
	botoes[3].pressed.emit()
	_assert("mexer na densidade não move um ponto de casco: quem faz a conta é a salva",
		_igual(_cascos_somados(pp), casco_antes, 0.0001),
		"%.3f de casco somado antes e depois" % casco_antes)

	for game in [g, c, d, e, estreito, meio, largo, a, b, p, q, h, m, pp]:
		game.queue_free()
	await _frames(2)

	for line in notes:
		print("SONDA-SALVA: %s" % line)
	print("SONDA-SALVA: veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
