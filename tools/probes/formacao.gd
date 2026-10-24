extends SceneTree

## Sonda da formação que navega. Antes desta rodada, trocar de formação era um alinhamento de
## cadastro: `_set_formation` cravava z = -38 e a frota inteira reaparecia na linha do registro no
## mesmo quadro — sem custo, sem travessia, sem leitura possível. A formação agora é uma ORDEM de
## navegação: o posto vira destino e o casco anda até lá na velocidade do próprio motor. As camadas
## que esta sonda fecha:
##
## 1) A GEOMETRIA é legal antes de ser bonita: em toda formação, e em toda Pair de postos, a
##    distância faz 2 * HULL_RADIUS. Uma formação que se abalroa sozinha puniria o comandante por
##    obedecer, e o anel é a que mais fácil escorrega nisso conforme o número de cascos cresce.
## 2) O CENTRO é lido dos cascos vivos, não do cadastro: quem manobrou até z = -150 forma em
##    z = -150. É isto que faz a mesa holográfica ser o campo em vez de uma foto antiga dele.
## 3) O TEMPO é a manobra, e a manobra tem lei: o primeiro quadro anda `aceleracao × delta²`
##    (0,040 u), a marcha cravada de `8,0 × mobilidade` (0,800 u por quadro de 0,1 s) só vem depois
##    da rampa E de o casco ter virado o timão até o posto — nos dezenove quadros do giro o passo
##    ainda é 0,736, porque o empuxo se resolve nos eixos do casco e perde o cosseno. Motor ferido
##    anda a marcha dele por fórmula, não por sorteio: 0,320 contra 0,800, razão exata de 0,400, com
##    o eixo pinado em 20 porque a oficina repara 1,32 por segundo e uma janela de doze segundos
##    sararia o motor antes do fim da medição. Nenhum `rng` é tocado por ordem nem por deslocamento.
##    O instantâneo morreu: um quadro de cadastro não é uma travessia — a linha de 48,62 u fecha em
##    79 quadros (7,9 s), e não nos 61 (6,1 s) que a marcha instantânea cobraria.
## 4) O PAINEL é o trânsito, não só a chegada: no meio do trajeto o blip bate com `_holo_de` da
##    posição real do nó, casco por casco.
##
## Uso: godot --headless --path . --quit-after 1800 -s res://tools/probes/formacao.gd

## Espelho das constantes de `main.gd` — a instância do jogo é não tipada e elas não são
## alcançáveis por ela (mesmo motivo em `tools/probes/manobra.gd`).
const HULL_RADIUS := 2.4
const FORMATION_STEP := 5.5
const DIAMETRO_CASCO := 4.8
const VELOCIDADE_MOVER := 8.0
const PASSO := 0.1
## Espelho de `CLASSES["CRUZADOR"]["aceleracao"]`: é a régua do arranque, e a instância do jogo não
## alcança as constantes do script (mesmo motivo de `VELOCIDADE_MOVER` acima).
const ACELERACAO_CRUZADOR := 4.0
## Folga de passo, derivada e não chutada: a maior coordenada deste tabuleiro é ~60 u, um float32
## nessa ordem vale ~7,2e-6 por dígito, e a diferença de duas posições come dois dígitos. 3e-5 é a
## mesma régua de `tools/probes/voo.gd` (lá as coordenadas chegam a 205 u).
const FOLGA_PASSO := 0.00003

var breaks := 0
var notes: Array[String] = []

func _assert(label: String, condition: bool, detail: String) -> void:
	if condition:
		notes.append("OK   %s — %s" % [label, detail])
	else:
		breaks += 1
		notes.append("QUEBRA %s — %s" % [label, detail])

## Ver `tools/probes/manobra.gd`: o `is_equal_approx` do motor só aceita dois argumentos.
func _igual(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol

## Postos de `total` cascos na formação `forma`, medidos da origem — a geometria nua, sem
## depender de onde a frota está.
func _postos(game, forma: String, total: int) -> Array[Vector3]:
	game.formation = forma
	var lista: Array[Vector3] = []
	for k in range(total):
		var posto: Vector3 = game._formacao_posto(k, total, Vector3.ZERO)
		lista.append(posto)
	return lista

## Menor distância entre dois postos quaisquer: é o número que decide se a formação é voadora ou
## se é um abalroamento coletivo já na planta.
func _minimo(lista: Array[Vector3]) -> float:
	var menor := INF
	for a in range(lista.size()):
		for b in range(a + 1, lista.size()):
			menor = minf(menor, lista[a].distance_to(lista[b]))
	return menor

func _alinhar(game) -> void:
	for i in range(game.fleet.size()):
		(game.fleet[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 5.0, 0.0, -38.0)
	for i in range(game.enemies.size()):
		(game.enemies[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 6.0, 0.0, -82.0)

## Tabuleiro espalhado de propósito: postos longe o bastante para a travessia durar dezenas de
## quadros. Em tabuleiro apertado o "tempo de locomoção" seria invisível e a asserção verde por
## nada ter que andar.
func _espalhar(game) -> void:
	for i in range(game.fleet.size()):
		(game.fleet[i]["node"] as Node3D).position = Vector3(
			(float(i) - 2.5) * 24.0, 0.0, -40.0 + float(i % 2) * 30.0)

func _zerar(game) -> void:
	for side in [["aliado", game.fleet], ["hostil", game.enemies]]:
		for unit in side[1]:
			unit["hp"] = 100.0
			unit["engines"] = 100.0
			unit["weapons"] = 100.0
			unit["crew"] = 100.0
			unit["veloc"] = Vector3.ZERO
			# O estado da lei, não só o do cenário: sem zerar `vel`, a medição do arranque herdados o
			# embalo da família anterior e o primeiro quadro não seria um arranque. `rumo` volta à
			# atitude de largada de cada lado (a nossa para -z, a muralha para +z).
			unit["vel"] = Vector3.ZERO
			unit["rumo"] = 0.0 if String(side[0]) == "aliado" else PI
			unit["giro"] = 0.0

func _navega(game, quadros: int, com_colisao: bool) -> void:
	for i in range(quadros):
		game._update_fleet(PASSO)
		if com_colisao:
			game._resolve_collisions()

func _posicoes(game) -> Array[Vector3]:
	var lista: Array[Vector3] = []
	for i in range(game.fleet.size()):
		var node: Node3D = game.fleet[i]["node"]
		lista.append(node.position)
	return lista

func _faltam(game, i: int) -> float:
	var unit: Dictionary = game.fleet[i]
	var node: Node3D = unit["node"]
	if not unit.has("destination"):
		return INF
	return node.position.distance_to(unit["destination"])

## Pior rota entre os cascos que ainda têm ordem de navegar — é o relógio da travessia: a linha
## só fecha quando o último casco encosta no posto.
func _pior_rota(game) -> float:
	var pior := 0.0
	for i in range(game.fleet.size()):
		if String(game.fleet[i]["order"]) != "MOVER":
			continue
		pior = maxf(pior, _faltam(game, i))
	return pior

## Um quadro da lei medido como deslocamento real do nó — o passo do casco, não a redução de rota,
## que o timão ainda não alinhado desconta.
func _passo_de(game, i: int) -> float:
	var node: Node3D = game.fleet[i]["node"]
	var partida: Vector3 = node.position
	game._update_fleet(PASSO)
	return partida.distance_to(node.position)


## Maior passo de um casco em `quadros` de trânsito, medido cru (deslocamento do nó) e pela lei
## (`vel × delta`), com quantos quadros tiveram casco a menos de `2 × HULL_RADIUS` de outro e a
## menor distância entre cascos do trânsito. `_update_fleet` termina em `_aplicar_cenario` +
## `_resolve_collisions`, que também escrevem posição — por isso o `lei` ao lado do `cru`: quando os
## dois batem, o número veio da lei de voo e não da separação. `feridos` pino do motor quadro a
## quadro é o controle que deixa a janela medir a marcha de um motor FERIDO, não a de um motor sarado
## no meio do trânsito (`main.gd:3969-3988` repara a 1,32 por segundo em AUTO, e doze segundos de
## janela bastariam para um motor a 20 subir a 35).
func _medir(game, a: int, b: int, quadros: int, feridos: Dictionary = {}) -> Dictionary:
	var r: Dictionary = {"cru_a": 0.0, "cru_b": 0.0, "lei_a": 0.0, "lei_b": 0.0,
		"apertados": 0, "menor": INF}
	for q in range(quadros):
		for idx in feridos:
			game.fleet[int(idx)]["engines"] = float(feridos[idx])
		var na: Node3D = game.fleet[a]["node"]
		var nb: Node3D = game.fleet[b]["node"]
		var pa: Vector3 = na.position
		var pb: Vector3 = nb.position
		game._update_fleet(PASSO)
		r["cru_a"] = maxf(float(r["cru_a"]), pa.distance_to(na.position))
		r["cru_b"] = maxf(float(r["cru_b"]), pb.distance_to(nb.position))
		r["lei_a"] = maxf(float(r["lei_a"]), (game.fleet[a]["vel"] as Vector3).length() * PASSO)
		r["lei_b"] = maxf(float(r["lei_b"]), (game.fleet[b]["vel"] as Vector3).length() * PASSO)
		var aperto := false
		for i in range(game.fleet.size()):
			for j in range(i + 1, game.fleet.size()):
				var d: float = (game.fleet[i]["node"] as Node3D).position.distance_to(
					(game.fleet[j]["node"] as Node3D).position)
				r["menor"] = minf(float(r["menor"]), d)
				if d < 4.8:
					aperto = true
		if aperto:
			r["apertados"] = int(r["apertados"]) + 1
	return r

func _montar_jogo() -> Node3D:
	var game: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	await _frames(3)
	return game

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _initialize() -> void:
	var game: Node3D = await _montar_jogo()
	_alinhar(game)
	_zerar(game)
	game.rng.seed = 424242

	# 1 — LINHA: leque lateral. O passo é 5,5 e a alternância de profundidade abre o vizinho para
	# 7,78 — acima dos 4,8 que o casco exige.
	var linha := _postos(game, "LINHA", 6)
	_assert("linha abre leque de seis postos", linha.size() == 6
		and _igual(linha[0].x, -13.75, 0.001) and _igual(linha[5].x, 13.75, 0.001),
		"x de %.2f a %.2f" % [linha[0].x, linha[5].x])
	_assert("linha nunca se toca", _minimo(linha) >= DIAMETRO_CASCO,
		"menor distância entre postos %.3f contra casco %.3f" % [_minimo(linha), DIAMETRO_CASCO])
	_assert("linha alterna profundidade", _igual(linha[0].z, 0.0, 0.001)
		and _igual(linha[1].z, -5.5, 0.001), "z %.2f / %.2f" % [linha[0].z, linha[1].z])

	# 2 — COLUNA: um atrás do outro no eixo de avanço, sem deslocamento lateral nenhum.
	var coluna := _postos(game, "COLUNA", 6)
	var mesma_fileira := true
	for posto in coluna:
		if not _igual(posto.x, 0.0, 0.001):
			mesma_fileira = false
	_assert("coluna empilha no eixo de avanço", mesma_fileira
		and _igual(coluna[1].z - coluna[0].z, -5.5, 0.001),
		"z %.2f -> %.2f, x sempre %.2f" % [coluna[0].z, coluna[1].z, coluna[3].x])
	_assert("coluna não encosta", _minimo(coluna) >= DIAMETRO_CASCO,
		"menor distância %.3f" % _minimo(coluna))

	# 3 — CUNHA: o ápice é quem aponta para o inimigo (-Z), e os flancos são espelhados.
	var cunha := _postos(game, "CUNHA", 6)
	var mais_a_frente := 0
	var z_menor := INF
	for k in range(cunha.size()):
		if cunha[k].z < z_menor:
			z_menor = cunha[k].z
			mais_a_frente = k
	_assert("cunha aponta o ápice para o inimigo", mais_a_frente == 2 or mais_a_frente == 3,
		"posto %d é o mais adiantado, z %.3f" % [mais_a_frente, z_menor])
	_assert("cunha é espelhada", _igual(cunha[0].x, -cunha[5].x, 0.001)
		and _igual(cunha[0].z, cunha[5].z, 0.001),
		"flancos x %.2f / %.2f" % [cunha[0].x, cunha[5].x])
	_assert("cunha não encosta", _minimo(cunha) >= DIAMETRO_CASCO,
		"menor distância %.3f" % _minimo(cunha))

	# 4 — ANEL: círculo fechado. Aqui o perigo é o vizinho de esquina, não o oposto.
	var anel := _postos(game, "ANEL", 6)
	var raios_iguais := true
	for posto in anel:
		if not _igual(posto.length(), anel[0].length(), 0.001):
			raios_iguais = false
	_assert("anel é círculo, não espiral", raios_iguais,
		"raio %.3f em todos os seis postos" % anel[0].length())
	_assert("anel fecha sem encostar", anel[0].distance_to(anel[5]) >= DIAMETRO_CASCO
		and _minimo(anel) >= DIAMETRO_CASCO,
		"fechamento %.3f, menor %.3f" % [anel[0].distance_to(anel[5]), _minimo(anel)])

	# 5 — Anel grande: o raio cresce com o número de cascos justamente para a corda não fechar
	# abaixo do casco. Sem o `maxf`, 20 cascos formariam um anel que se abalroa sozinho.
	var anel20 := _postos(game, "ANEL", 20)
	_assert("anel de vinte mantém o passo", _minimo(anel20) >= DIAMETRO_CASCO,
		"menor corda %.3f com raio %.3f" % [_minimo(anel20), anel20[0].length()])
	_assert("anel grande cresce de verdade", anel20[0].length() > anel[0].length() * 2.5,
		"raio %.3f contra %.3f de seis cascos" % [anel20[0].length(), anel[0].length()])

	# 6 — O centro é lido dos cascos vivos: manobrar até longe e formar deve formar LONGE.
	_espalhar(game)
	var selection: Array[int] = game._selected_indices()
	var centro: Vector3 = game._centro_selecao(selection)
	var soma := Vector3.ZERO
	for node_pos in _posicoes(game):
		soma += node_pos
	_assert("centro da seleção é a média real dos cascos",
		centro.distance_to(soma / 6.0) < 0.0001, str(centro))
	game.selection_scope = "FROTA"
	game._set_formation("LINHA")
	var medio_dest := Vector3.ZERO
	for i in range(game.fleet.size()):
		medio_dest += game.fleet[i]["destination"]
	medio_dest /= 6.0
	# A âncora é o centro REAL, com no máximo um passo de folga: a LINHA alterna profundidade,
	# então a média dos postos cai meio passo à frente do centro — é a geometria do leque, não a
	# frota voltando para o cadastro. Exigir igualdade exata seria reprovar um desenho correto.
	_assert("a formação se ancora onde a frota está, não onde foi cadastrada",
		medio_dest.distance_to(centro) <= FORMATION_STEP,
		"média dos postos %.2f,%.2f a %.2f do centro %.2f,%.2f (um passo = %.1f)"
		% [medio_dest.x, medio_dest.z, medio_dest.distance_to(centro), centro.x, centro.z,
			FORMATION_STEP])
	_assert("posto nenhum volta para a linha do registro",
		not _igual(medio_dest.z, -38.0, 0.5), "z médio %.2f" % medio_dest.z)

	# 7 — Teleporte é proibido: dar a ordem não move um centímetro; quem move é o motor.
	var antes := _posicoes(game)
	game._set_formation("CUNHA")
	var depois := _posicoes(game)
	var igual := true
	for i in range(antes.size()):
		if antes[i] != depois[i]:
			igual = false
	_assert("dar a ordem não teletransporta casco nenhum", igual,
		"seis posições idênticas antes e depois da ordem")

	# 8 — Ordem não sorteia: formação é geometria, e um sorteio aqui reescreveria a cauda de
	# dano da salva seguinte.
	var rng_antes: int = game.rng.state
	game._set_formation("ANEL")
	_assert("formar não consome um sorteio", game.rng.state == rng_antes,
		"rng.state %d -> %d" % [rng_antes, game.rng.state])

	# 9 — A ordem chega escrita: MOVER + destino no dicionário, anúncio na ponte, rótulo no HUD.
	var com_ordem := 0
	var com_destino := 0
	for unit in game.fleet:
		if String(unit["order"]) == "MOVER":
			com_ordem += 1
		if unit.has("destination"):
			com_destino += 1
	_assert("toda seleção viva recebe ordem de navegação", com_ordem == 6 and com_destino == 6,
		"%d ordem MOVER, %d com destino" % [com_ordem, com_destino])
	_assert("a ponte anuncia a execução, não a conclusão",
		"EM EXECUÇÃO" in String(game.report_label.text) and "6 casco" in String(game.report_label.text),
		String(game.report_label.text))
	_assert("o rótulo da formação lê a ordem dada", String(game.formation) == "ANEL",
		"formation=%s" % String(game.formation))

	# 10 — Destroço não tem motor: fica de fora do centro, do posto e da conta anunciada.
	_alinhar(game)
	_zerar(game)
	game.fleet[2]["hp"] = 0.0
	game.fleet[2]["order"] = "PATRULHA"
	game.fleet[2].erase("destination")
	var morto: Node3D = game.fleet[2]["node"]
	# O destroço é estacionado longe da linha dos vivos: se ele entrar na média, o centro desloca
	# 10,3 unidades e a asserção pega. Alinhado com os vivos, o centro seria -38 de qualquer
	# maneira e o teste seria verde por construção, não por exclusão.
	morto.position = Vector3(0.0, 0.0, -100.0)
	var z_morto := morto.position.z
	game._set_formation("COLUNA")
	_assert("destroço não recebe posto", String(game.fleet[2]["order"]) == "PATRULHA"
		and not game.fleet[2].has("destination") and morto.position.z == z_morto,
		"ordem %s, z %.2f intocado" % [String(game.fleet[2]["order"]), morto.position.z])
	_assert("destroço não infla a conta da ponte", "5 casco(s) navegando" in String(game.report_label.text),
		String(game.report_label.text))
	var centro_sem_morto: Vector3 = game._centro_selecao(game._selected_indices())
	_assert("destroço não puxa o centro", _igual(centro_sem_morto.z, -38.0, 0.001),
		"centro z %.3f com o casco morto em z -100; com ele dentro seria -48,33"
		% centro_sem_morto.z)

	# 11 — Escopo é escopo: formar ALFA não move BETA um milímetro.
	_alinhar(game)
	_zerar(game)
	game.fleet[2]["hp"] = 100.0
	game.selection_scope = "ESQUADRÃO ALFA"
	for i in range(3, 6):
		game.fleet[i]["order"] = "DEFESA"
		game.fleet[i].erase("destination")
	game._set_formation("LINHA")
	var beta_parada := true
	for i in range(3, 6):
		if String(game.fleet[i]["order"]) != "DEFESA" or game.fleet[i].has("destination"):
			beta_parada = false
	_assert("esquadrão fora da seleção não recebe ordem", beta_parada,
		"BETA segue em DEFESA, sem destino")
	_assert("esquadrão selecionado forma inteiro", String(game.fleet[0]["order"]) == "MOVER"
		and String(game.fleet[2]["order"]) == "MOVER", "ALFA 01..03 em MOVER")

	# 12 — Guarda de seleção vazia: ordem recusada não muda o rótulo da frota. Uma ponte que
	# anuncia "ANEL" enquanto nenhum casco se moveu deixou de ser leitura do campo.
	_alinhar(game)
	_zerar(game)
	game.formation = "LINHA"
	game.selection_scope = "ESQUADRÃO PRESA"
	for i in range(game.fleet.size()):
		game.fleet[i]["hp"] = 100.0
	var sem_presa: Array[int] = game._selected_indices()
	game._set_formation("ANEL")
	_assert("nenhuma unidade viva recusa a ordem", sem_presa.is_empty()
		and "NENHUMA UNIDADE VIVA" in String(game.report_label.text),
		"%d selecionados" % sem_presa.size())
	_assert("ordem recusada não reescreve o painel", String(game.formation) == "LINHA",
		"formation continua %s depois de uma ordem sem destinatário" % String(game.formation))

	# 13 — O tempo é a manobra, e a manobra tem lei: o primeiro quadro anda a aceleração do casco
	# (0,040 u), a marcha cravada de 0,800 u só chega depois da rampa, vinte quadros ainda deixam
	# travessia e cento e vinte fecham o posto. Tudo por aritmética de voo, sem tolerância de sorteio.
	_espalhar(game)
	_zerar(game)
	game.selection_scope = "FROTA"
	game._set_formation("LINHA")
	var rota := _faltam(game, 0)
	var passo_um := _passo_de(game, 0)
	_assert("o arranque tem tempo: o primeiro quadro anda aceleracao x delta",
		_igual(passo_um, ACELERACAO_CRUZADOR * PASSO * PASSO, FOLGA_PASSO),
		"%.5f u no quadro um contra %.5f da rampa; sem lei seria %.3f" % [passo_um,
			ACELERACAO_CRUZADOR * PASSO * PASSO, VELOCIDADE_MOVER * PASSO])
	var med := _medir(game, 0, 1, 19)
	var passo_giro := maxf(float(med["cru_a"]), passo_um)
	# O timão é limitado, e é ele que segura a marcha: o posto fica a ~90° da atitude de largada, o
	# leme vira 0,8 rad/s, e enquanto o nariz não aponta o destino o empuxo comandado se resolve no
	# eixo do casco e perde o cosseno. Medir o teto nos dezenove quadros do turno mediria o leme, não
	# o motor — e passar por cima dele é a régua que aceita rotação instantânea.
	_assert("no virar do timao o passo fica abaixo da marcha cravada: o giro e limitado",
		passo_giro < VELOCIDADE_MOVER * PASSO - FOLGA_PASSO and float(med["apertados"]) == 0.0,
		"maior passo dos dezenove quadros %.5f contra %.5f do teto, menor par entre cascos %.3f" % [
			passo_giro, VELOCIDADE_MOVER * PASSO, float(med["menor"])])
	_assert("depois de vinte quadros ainda há travessia", _faltam(game, 0) > 20.0,
		"faltam %.2f unidades de rota" % _faltam(game, 0))
	var med2 := _medir(game, 0, 1, 100)
	var passo_max := maxf(passo_giro, float(med2["cru_a"]))
	# Alinhado o casco, a marcha cravada é a do cadastro: 8,0 × mobilidade e o passo do quadro é
	# `teto × delta`. O `cru` e o `lei` baterem é o que diz que o número veio da lei e não da
	# separação de cascos nem do poço do cenário, que também escrevem posição.
	_assert("a marcha cravada é a do motor: 8,0 x mobilidade",
		_igual(passo_max, VELOCIDADE_MOVER * PASSO, FOLGA_PASSO) \
			and _igual(float(med2["cru_a"]), float(med2["lei_a"]), FOLGA_PASSO),
		"maior passo %.5f (lei %.5f) contra %.5f do teto, rota %.2f u, %d quadros apertados, menor par %.3f" % [
			passo_max, float(med2["lei_a"]), VELOCIDADE_MOVER * PASSO, rota, int(med2["apertados"]),
			float(med2["menor"])])
	var chegaram := 0
	var pior := 0.0
	for i in range(game.fleet.size()):
		if String(game.fleet[i]["order"]) != "MOVER":
			continue
		pior = maxf(pior, _faltam(game, i))
		if _faltam(game, i) < 0.001:
			chegaram += 1
	_assert("o casco chega ao posto", chegaram == 6 and pior < 0.001,
		"%d/6 no posto, pior resíduo %.5f" % [chegaram, pior])
	# O preço da rampa pago em quadro, não em prosa: a marcha instantânea fecharia 48,62 u em 61
	# quadros, e o que a lei entrega é uma travessia mais longa porque os primeiros quadros andam
	# pouco (arranque) e os do timão andam 0,736. Contar até o último casco encostar é a única forma
	# de o README poder dizer quanto tempo a ordem custa.
	_espalhar(game)
	_zerar(game)
	game._set_formation("LINHA")
	var quadros_da_linha := 0
	while quadros_da_linha < 300 and _pior_rota(game) >= 0.001:
		quadros_da_linha += 1
		game._update_fleet(PASSO)
	_assert("a travessia da linha custa mais que a marcha instantânea",
		quadros_da_linha > 61 and quadros_da_linha < 300,
		"%d quadros (%.1f s) para fechar %.2f u de rota; sem rampa seriam 61" % [
			quadros_da_linha, quadros_da_linha * PASSO, rota])

	# 14 — Quem tem motor ferido anda na velocidade do motor, não na do roteiro: 0,32 u por quadro
	# com motor a 20% contra 0,80 do cheio, no regime permanente. A rampa é da classe e por isso os
	# dois cascos andariam iguais no primeiro quadro (0,040) — medir o quadro um mediria a rampa,
	# não o motor. E o motor tem de ser segurado FERIDO durante a janela inteira: a tripulação repara
	# o eixo a 1,32 por segundo em AUTO, doze segundos de trânsito bastariam para ele subir de 20 a
	# 35 e a razão medida não seria a do motor, seria a da oficina.
	_espalhar(game)
	_zerar(game)
	game._set_formation("COLUNA")
	game.fleet[1]["engines"] = 20.0
	# mobilidade = 0,25 + motores/100 * 0,75 -> 0,40 com motor a 20; 1,00 com motor cheio.
	var medidos: Dictionary = _medir(game, 0, 1, 120, {1: 20.0})
	var cheio := float(medidos["cru_a"])
	var ferido := float(medidos["cru_b"])
	_assert("motor cheio anda a marcha do cadastro",
		_igual(cheio, VELOCIDADE_MOVER * PASSO, FOLGA_PASSO),
		"cru %.5f, lei %.5f por quadro" % [cheio, float(medidos["lei_a"])])
	_assert("motor ferido anda a marcha dele",
		_igual(ferido, VELOCIDADE_MOVER * PASSO * 0.4, FOLGA_PASSO),
		"cru %.5f, lei %.5f contra %.5f do cheio - %d quadros apertados, menor par %.3f" % [
			ferido, float(medidos["lei_b"]), cheio, int(medidos["apertados"]),
			float(medidos["menor"])])
	_assert("a razão das marchas é a razão dos motores",
		_igual(ferido / cheio, 0.4, 0.0001), "%.3f" % (ferido / cheio))

	# 15 — Locomoção não sorteia: duzentos quadros de deslocamento não tocam no rng.
	var rng_rota: int = game.rng.state
	_navega(game, 200, false)
	_assert("navegar até o posto não sorteia nada", game.rng.state == rng_rota,
		"rng.state %d -> %d" % [rng_rota, game.rng.state])

	# 16 — Painel fiel em trânsito: no meio da rota, o blip bate com a posição REAL do nó, casco
	# por casco. É isto que faz a mesa ser o campo enquanto a manobra acontece, não depois.
	_espalhar(game)
	_zerar(game)
	game._set_formation("CUNHA")
	_navega(game, 12, false)
	var em_transito := 0
	var desvio_max := 0.0
	game._update_bridge(0.0)
	for i in range(game.fleet.size()):
		var node: Node3D = game.fleet[i]["node"]
		if _faltam(game, i) > 0.5:
			em_transito += 1
		var ping: MeshInstance3D = game.holo_blips[node.get_instance_id()]
		var real: Vector3 = game._holo_de(node.position)
		desvio_max = maxf(desvio_max, ping.position.distance_to(real))
	_assert("metade da frota ainda está voando nesta medição", em_transito >= 3,
		"%d cascos ainda fora do posto" % em_transito)
	_assert("o painel replica o trânsito, não a chegada", desvio_max < 0.0001,
		"maior desvio blip-vs-realidade %.6f" % desvio_max)
	var blip_0: Vector3 = game.holo_blips[
		(game.fleet[0]["node"] as Node3D).get_instance_id()].position
	_assert("posto fora do aro encosta no aro, sem sumir da mesa",
		Vector2(blip_0.x, blip_0.z).length() <= 2.8501, "blip a %.4f do centro da mesa"
		% Vector2(blip_0.x, blip_0.z).length())

	# 17 — Re-formar em trânsito é reescrever o destino, não puxar o casco para trás.
	var meio := _posicoes(game)
	var destino_antes: Vector3 = game.fleet[0]["destination"]
	var centro_antes: Vector3 = game._centro_selecao(game._selected_indices())
	game._set_formation("ANEL")
	var depois_meio := _posicoes(game)
	var parado_de_novo := true
	for i in range(meio.size()):
		if meio[i] != depois_meio[i]:
			parado_de_novo = false
	_assert("re-formar no meio da rota não teleporta", parado_de_novo,
		"posições idênticas ao reemitir a ordem")
	var destino_depois: Vector3 = game.fleet[0]["destination"]
	var centro_depois: Vector3 = game._centro_selecao(game._selected_indices())
	_assert("re-formar reancora no centro real de agora",
		centro_depois.distance_to(centro_antes) < 0.001,
		"centro %.2f,%.2f -> %.2f,%.2f" % [centro_antes.x, centro_antes.z,
			centro_depois.x, centro_depois.z])
	_assert("re-formar troca o destino do casco", destino_antes != destino_depois,
		"posto 01 %.2f,%.2f -> %.2f,%.2f" % [destino_antes.x, destino_antes.z,
			destino_depois.x, destino_depois.z])

	# 18 — Travessia com separação ligada: cascos que se cruzam se empurram, não se atravessem, e
	# obedecer uma ordem própria não custa casco a ninguém. É a outra metade do pedido: sem a
	# isenção aliada, o próprio comando de formação seria punido com dano de abalroamento.
	_espalhar(game)
	_zerar(game)
	game._set_formation("CUNHA")
	_navega(game, 140, true)
	var hp_aliado:int = 0
	var furou := 0
	var pos_finais := _posicoes(game)
	for unit in game.fleet:
		hp_aliado += int(unit["hp"])
	for a in range(pos_finais.size()):
		for b in range(a + 1, pos_finais.size()):
			if pos_finais[a].distance_to(pos_finais[b]) < DIAMETRO_CASCO - 0.001:
				furou += 1
	_assert("cruzar a própria formação não custa casco", hp_aliado == 600,
		"soma de casco aliado %d contra 600" % hp_aliado)
	_assert("aliado não atravessa aliado em trânsito", furou == 0,
		"%d pares abaixo do diâmetro do casco" % furou)
	var pior_fim := 0.0
	var no_posto := 0
	for i in range(game.fleet.size()):
		pior_fim = maxf(pior_fim, _faltam(game, i))
		if _faltam(game, i) < 0.05:
			no_posto += 1
	_assert("com separação ligada a formação ainda fecha", no_posto == 6 and pior_fim < 0.05,
		"%d/6 no posto, pior %.5f" % [no_posto, pior_fim])

	for nota in notes:
		print("SONDA-FORMACAO: " + nota)
	print("veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	quit()
