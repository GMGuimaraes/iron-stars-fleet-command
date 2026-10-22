extends SceneTree

## Sonda do painel em grupos e das duas ordens de densidade (DISPERSAR / AGRUPAR).
##
## O pedido do comandante foi «menos poluição»: o painel tinha dezenove botões de ordem empilhados,
## sempre todos à vista, e dois deles faziam a mesma coisa. Agora são trinta e um comandos em oito
## categorias, uma aberta por vez — a sétima (CENÁRIO) entrou depois, com os quatro mapas, e ganhou
## o quinto (SISTEMA) na rodada das luas; a oitava
## (TRILHA) com as quatro faixas da ponte, e o grupo
## ATAQUE ganhou os dois degraus de densidade do disco de salva. Isso
## é pintura — mas pintura que esconde comando, e painel que esconde sem dizer o que escondeu
## deixa de ser instrumento. Então esta sonda mede as duas margens:
##
## 1) A ACESSIBILIDADE: o grupo fechado não pode sumir com a ordem. Cada cabeçalho, emitido pelo
##    próprio sinal `pressed`, abre o corpo; cada botão do corpo, emitido pelo próprio sinal,
##    executa a ordem. O teste atravessa a cadeia inteira por sinal, sem chamar função interna,
##    porque é pelo sinal que o jogador alcança o comando.
## 2) A GEOMETRIA DAS ORDENS NOVAS: dispersar e agrupar são densidade, e densidade tem um piso
##    físico — um anel "fechado" que coloca dois cascos a 4,0 u de distância é um abalroamento em
##    cadeia, punindo quem obedece. O raio de agrupar (5,5) e o de dispersar (16,5) saem medidos,
##    não chutados.
##
## O resto é a inércia de sempre: nenhuma ordem nova sorteia um `rng`, nenhuma teletransporta, o
## tempo de locomoção se paga em quadros de motor e o blip do painel continua sendo a posição real
## do casco no meio do trânsito.
##
## Uso: godot --headless --path . --quit-after 1800 -s res://tools/probes/menu.gd

## Espelho das constantes de `main.gd` — a instância do jogo é não tipada (mesmo motivo em
## `tools/probes/formacao.gd`).
const HULL_RADIUS := 2.4
const FORMATION_STEP := 5.5
const DIAMETRO_CASCO := 4.8
const AGRUPAR_RAIO := 5.5
const DISPERSAR_RAIO := 16.5
const VELOCIDADE_MOVER := 8.0
const PASSO := 0.1

const NOMES_GRUPOS := ["ATAQUE", "POSTURA", "FORMAÇÕES", "MANOBRA", "REPAROS", "RECONHECIMENTO",
	"CENÁRIO", "TRILHA"]
const TAMANHOS := {"ATAQUE": 4, "POSTURA": 5, "FORMAÇÕES": 4, "MANOBRA": 3, "REPAROS": 5,
	"RECONHECIMENTO": 1, "CENÁRIO": 5, "TRILHA": 4}

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

## Menor distância entre dois postos quaisquer.
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

## Tabuleiro espalhado: postos longe o bastante para a travessia durar dezenas de quadros e para
## os seis caminhos se cruzarem — é no cruzamento que a separação aliada é provada.
func _espalhar(game) -> void:
	for i in range(game.fleet.size()):
		(game.fleet[i]["node"] as Node3D).position = Vector3(
			(float(i) - 2.5) * 24.0, 0.0, -40.0 + float(i % 2) * 30.0)

func _zerar(game) -> void:
	for list in [game.fleet, game.enemies]:
		for unit in list:
			unit["hp"] = 100.0
			unit["engines"] = 100.0
			unit["weapons"] = 100.0
			unit["crew"] = 100.0
			unit["veloc"] = Vector3.ZERO

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

## Destinos da seleção atual, na ordem dos índices selecionados.
func _destinos(game) -> Array[Vector3]:
	var lista: Array[Vector3] = []
	var sel: Array[int] = game._selected_indices()
	for i in sel:
		var unit: Dictionary = game.fleet[i]
		if unit.has("destination"):
			lista.append(unit["destination"])
	return lista

func _faltam(game, i: int) -> float:
	var unit: Dictionary = game.fleet[i]
	var node: Node3D = unit["node"]
	if not unit.has("destination"):
		return INF
	return node.position.distance_to(unit["destination"])

## Botões de comando de um corpo de grupo (os cabeçalhos não contam: são do corpo de cima).
func _botoes(game, nome: String) -> Array[Button]:
	var lista: Array[Button] = []
	var corpo: Control = game.group_bodies[nome]
	for filho in corpo.get_children():
		if filho is Button:
			lista.append(filho as Button)
	return lista

## Quantos botões de comando estão à vista agora (corpo aberto) — a medida de poluição.
func _a_vista(game) -> int:
	var total := 0
	for nome in NOMES_GRUPOS:
		var corpo: Control = game.group_bodies[nome]
		if corpo.visible:
			total += _botoes(game, nome).size()
	return total

## Marca do cabeçalho: ▾ aberto, ▸ fechado.
func _marca(game, nome: String) -> String:
	return (game.group_heads[nome] as Button).text.substr(0, 1)

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

	# 1 — A lista de grupos: oito categorias, cada uma com cabeçalho e corpo, com o tamanho que o
	# painel anuncia. Um grupo digitado com nome errado some da UI sem dar erro de parse.
	var cabecalhos: Dictionary = game.group_heads
	var corpos: Dictionary = game.group_bodies
	_assert("oito grupos no painel", cabecalhos.size() == 8 and corpos.size() == 8,
		"%d cabeçalhos / %d corpos" % [cabecalhos.size(), corpos.size()])
	var faltam := ""
	for nome in NOMES_GRUPOS:
		if not cabecalhos.has(nome) or not corpos.has(nome):
			faltam += nome + " "
	_assert("os oito nomes pedidos existem", faltam == "", "faltando: [%s]" % faltam)
	var tamanhos_ok := true
	var medido := ""
	for nome in NOMES_GRUPOS:
		var n := _botoes(game, nome).size()
		medido += "%s=%d " % [nome, n]
		if n != int(TAMANHOS[nome]):
			tamanhos_ok = false
	_assert("cada grupo carrega os comandos que promete", tamanhos_ok, medido)
	var total_botoes := 0
	for nome in NOMES_GRUPOS:
		total_botoes += _botoes(game, nome).size()
	_assert("trinta e um comandos agrupados", total_botoes == 31,
		"%d botões de comando em 8 grupos" % total_botoes)

	# 2 — Menos poluição: o que se vê é um grupo, não a lista toda. Este era o número da rodada
	# anterior, medido no `main.gd` de antes do acordeão: dezenove botões de ordem sempre à vista.
	_assert("abre com um único grupo à vista", _a_vista(game) == 4,
		"%d botões visíveis contra 4 do grupo FORMAÇÕES" % _a_vista(game))
	_assert("o grupo aberto na abertura é FORMAÇÕES", String(game.grupo_aberto) == "FORMAÇÕES"
		and (game.group_bodies["FORMAÇÕES"] as Control).visible,
		"grupo_aberto=%s" % game.grupo_aberto)
	var marcas := ""
	for nome in NOMES_GRUPOS:
		marcas += "%s:%s " % [nome, _marca(game, nome)]
	_assert("cabeçalho aberto usa ▾ e fechado usa ▸",
		_marca(game, "FORMAÇÕES") == "▾" and _marca(game, "ATAQUE") == "▸", marcas)

	# 3 — Abrir um fecha o outro: é isto que mantém o painel curto.
	(game.group_heads["MANOBRA"] as Button).pressed.emit()
	_assert("clicar MANOBRA abre o corpo dela",
		(game.group_bodies["MANOBRA"] as Control).visible
		and String(game.grupo_aberto) == "MANOBRA",
		"visível=%s aberto=%s" % [str((game.group_bodies["MANOBRA"] as Control).visible),
			game.grupo_aberto])
	_assert("abrir MANOBRA fecha FORMAÇÕES",
		not (game.group_bodies["FORMAÇÕES"] as Control).visible
		and _marca(game, "FORMAÇÕES") == "▸",
		"marca de FORMAÇÕES: %s" % _marca(game, "FORMAÇÕES"))
	_assert("ainda um grupo só à vista depois do clique", _a_vista(game) == 3,
		"%d botões visíveis contra 3 do grupo MANOBRA" % _a_vista(game))
	_assert("o relatório anuncia o que abriu",
		str(game.report_label.text).contains("PAINEL: MANOBRA"),
		str(game.report_label.text))

	# 4 — Clicar de novo recolhe tudo: o painel pode ficar menor que um grupo.
	(game.group_heads["MANOBRA"] as Button).pressed.emit()
	var abertos := 0
	for nome in NOMES_GRUPOS:
		if (game.group_bodies[nome] as Control).visible:
			abertos += 1
	_assert("segundo clique recolhe o painel", abertos == 0 and String(game.grupo_aberto) == "",
		"%d corpos abertos, grupo_aberto=[%s]" % [abertos, game.grupo_aberto])
	_assert("o relatório diz que nada está aberto",
		str(game.report_label.text).contains("PAINEL RECOLHIDO"), str(game.report_label.text))
	(game.group_heads["REPAROS"] as Button).pressed.emit()
	_assert("recolhido, um clique volta a abrir", _a_vista(game) == 5
		and String(game.grupo_aberto) == "REPAROS",
		"%d à vista, aberto=%s" % [_a_vista(game), game.grupo_aberto])

	# 4b — Rolagem: abrir um grupo que mora abaixo da dobra tem de trazer o corpo para a vista,
	# senão o comandante clica num cabeçalho e nada acontece na tela. Dois quadros porque a rolagem
	# é `call_deferred` — antes do passe de layout o retângulo do corpo ainda é o de escondido.
	await _frames(2)
	var scroll: ScrollContainer = game.painel_scroll
	var corpo_aberto: Control = game.group_bodies["REPAROS"]
	var rect_corpo := corpo_aberto.get_global_rect()
	var rect_janela := scroll.get_global_rect()
	_assert("o grupo aberto cai dentro da janela do painel", is_instance_valid(scroll)
		and rect_corpo.position.y >= rect_janela.position.y - 0.5
		and rect_corpo.end.y <= rect_janela.end.y + 0.5,
		"corpo %.0f→%.0f dentro de %.0f→%.0f, rolagem em %.0f" % [rect_corpo.position.y,
			rect_corpo.end.y, rect_janela.position.y, rect_janela.end.y, scroll.scroll_vertical])

	# 5 — A cadeia inteira por sinal: abrir o grupo pelo cabeçalho e dar a ordem pelo botão, sem
	# chamar função interna. Grupo fechado é botão invisível, e invisível não se clica.
	var corpo_reparos: VBoxContainer = game.group_bodies["REPAROS"]
	var botao_armas: Button = corpo_reparos.get_children()[1] as Button
	botao_armas.pressed.emit()
	_assert("o botão do corpo executa a ordem",
		String(game.fleet[0]["repair_priority"]) == "ARMAS",
		"prioridade da unidade 0: %s" % game.fleet[0]["repair_priority"])
	var sem_amar := 0
	for nome in NOMES_GRUPOS:
		for b in _botoes(game, nome):
			if b.pressed.get_connections().is_empty():
				sem_amar += 1
	_assert("todo botão de comando tem ligação no pressed", sem_amar == 0,
		"%d botões órfãos" % sem_amar)

	# 6 — Sem comando duplicado: o antigo "CONCENTRAR FOGO" chamava o mesmo ATACAR.
	var rotulos: Array[String] = []
	var duplicados := ""
	for nome in NOMES_GRUPOS:
		for b in _botoes(game, nome):
			if rotulos.has(b.text):
				duplicados += b.text + " "
			rotulos.append(b.text)
	_assert("nenhum rótulo de comando se repete", duplicados == "", "[%s]" % duplicados)
	# 6 — O antigo "CONCENTRAR FOGO" chamava o mesmo ATACAR do botão ao lado. O nome voltou, mas
	# como controle de densidade: manda no disco de impacto, não na ordem do navio. Quem manda
	# atacar continua sendo um botão só.
	var botoes_de_atacar := 0
	for b in _botoes(game, "ATAQUE"):
		if String(b.text).begins_with("ATACAR ALVO"):
			botoes_de_atacar += 1
	_assert("o comando ATACAR tem um único botão", botoes_de_atacar == 1,
		"%d botões que chamam ATACAR no grupo ATAQUE" % botoes_de_atacar)
	_assert("a densidade voltou como comando próprio de disco",
		rotulos.has("CONCENTRAR FOGO — disco estreito") and rotulos.has("DISPERSAR FOGO — disco largo"),
		"%d rótulos únicos" % rotulos.size())
	var ordens_antes := ""
	for unit in game.fleet:
		ordens_antes += String(unit["order"]) + " "
	var densidade_antes := int(game.fogo_densidade)
	var sorteio_antes := int(game.rng.state)
	for b in _botoes(game, "ATAQUE"):
		if b.text == "CONCENTRAR FOGO — disco estreito":
			b.pressed.emit()
	var ordens_depois := ""
	for unit in game.fleet:
		ordens_depois += String(unit["order"]) + " "
	_assert("concentrar mexe no disco, não na ordem dos cascos",
		int(game.fogo_densidade) == densidade_antes - 1 and ordens_depois == ordens_antes,
		"densidade %d -> %d, ordens iguais: %s" % [densidade_antes, int(game.fogo_densidade),
		str(ordens_depois == ordens_antes)])
	_assert("densidade de fogo não sorteia", int(game.rng.state) == sorteio_antes,
		"rng.state %d" % int(game.rng.state))
	_assert("o degrau fica escrito no relatório",
		String(game.report_label.text).begins_with("DENSIDADE DE FOGO: CONCENTRADO"),
		game.report_label.text)
	game.fogo_densidade = densidade_antes
	game._desenhar_setor_de_fogo()

	# 7 — DISPERSAR: anel largo em torno do centro REAL da seleção.
	game.selection_scope = "FROTA"
	_espalhar(game)
	var centro: Vector3 = game._centro_selecao(game._selected_indices())
	var estado_rng: int = game.rng.state
	game._give_order("DISPERSAR")
	var destinos := _destinos(game)
	_assert("dispersar escreve destino para os seis", destinos.size() == 6,
		"%d destinos" % destinos.size())
	var pior_raio := 0.0
	for d in destinos:
		pior_raio = maxf(pior_raio, absf(d.distance_to(centro) - DISPERSAR_RAIO))
	_assert("o anel de dispersar tem o raio de 16,5 u", pior_raio < 0.001,
		"maior diferença de raio %.5f" % pior_raio)
	_assert("dispersar afasta mais que o passo de formação",
		_minimo(destinos) >= DIAMETRO_CASCO, "menor par %.3f contra casco %.3f" % [
			_minimo(destinos), DIAMETRO_CASCO])
	_assert("dispersar é ordem, não formação", String(game.formation) == "LINHA",
		"rótulo de formação continua %s" % game.formation)
	_assert("o relatório diz o raio assumido",
		str(game.report_label.text).contains("16.5") and str(game.report_label.text).begins_with(
			"DISPERSAR EM EXECUÇÃO"), str(game.report_label.text))
	_assert("o centro dispersado é o do tabuleiro espalhado",
		_is_centro_esperado(centro), "centro %.2f, %.2f, %.2f" % [centro.x, centro.y, centro.z])

	# 8 — Zero sorteio: ordem e trânsito não tocam o `rng` do combate.
	_assert("dar a ordem não sorteia", int(game.rng.state) == int(estado_rng),
		"rng.state %s -> %s" % [str(estado_rng), str(game.rng.state)])
	_navega(game, 200, false)
	_assert("duzentos quadros de trânsito não sorteiam",
		int(game.rng.state) == int(estado_rng), "rng.state %s" % str(game.rng.state))

	# 9 — AGRUPAR: o piso físico. Fechar tropas é encostar cascos, e encostar é abalroar.
	game._give_order("AGRUPAR")
	var apertados := _destinos(game)
	var centro_aperto: Vector3 = game._centro_selecao(game._selected_indices())
	var pior_aperto := 0.0
	for d in apertados:
		pior_aperto = maxf(pior_aperto, absf(d.distance_to(centro_aperto) - AGRUPAR_RAIO))
	_assert("o anel de agrupar tem o raio de 5,5 u", pior_aperto < 0.001,
		"maior diferença %.5f" % pior_aperto)
	_assert("agrupar nunca pede posto que se abalroa", _minimo(apertados) >= DIAMETRO_CASCO,
		"menor par %.3f contra diâmetro %.3f" % [_minimo(apertados), DIAMETRO_CASCO])
	_assert("agrupar parte do centro real, não do cadastro",
		centro_aperto.distance_to(centro) < 2.0,
		"centro andou %.3f u no trânsito" % centro_aperto.distance_to(centro))

	# 10 — O custo em tempo, e o no-teleport na hora da ordem.
	_espalhar(game)
	var antes := _posicoes(game)
	game._give_order("DISPERSAR")
	var iguais := 0
	for i in range(6):
		if antes[i] == _posicoes(game)[i]:
			iguais += 1
	_assert("a ordem não teletransporta ninguém", iguais == 6,
		"%d/6 cascos parados no quadro da ordem" % iguais)
	var passo_real := 0.0
	var partida := (game.fleet[0]["node"] as Node3D).position
	game._update_fleet(PASSO)
	passo_real = partida.distance_to((game.fleet[0]["node"] as Node3D).position)
	_assert("um quadro de motor anda 0,80 u no dispersar", _igual(passo_real, 0.8, 0.0001),
		"%.4f u no quadro" % passo_real)
	_navega(game, 20, false)
	var em_transito := 0
	for i in range(6):
		if _faltam(game, i) > 0.05:
			em_transito += 1
	_assert("vinte quadros depois ainda há quem esteja a caminho", em_transito == 6,
		"%d/6 em trânsito" % em_transito)
	_navega(game, 180, false)
	var no_posto := 0
	var pior_fim := 0.0
	for i in range(6):
		pior_fim = maxf(pior_fim, _faltam(game, i))
		if _faltam(game, i) < 0.05:
			no_posto += 1
	_assert("duzentos quadros fecham o anel", no_posto == 6 and pior_fim < 0.05,
		"%d/6 no posto, pior resíduo %.5f" % [no_posto, pior_fim])

	# 11 — Fidelidade do painel no meio do trânsito: o blip é a posição real, casco a casco.
	# `_update_bridge` é quem refresca a mesa — `_update_fleet` move o casco e não toca no blip,
	# então medir sem a ponte rodando mede o painel do quadro anterior (o desvio de 1,65 u que esta
	# sonda deu na primeira rodada era exatamente isso: sonda errada, não jogo errado).
	_espalhar(game)
	game._give_order("DISPERSAR")
	_navega(game, 25, false)
	game._update_bridge(0.0)
	var desvio_max := 0.0
	var blips_vivos := 0
	var holo: Dictionary = game.holo_blips
	for i in range(game.fleet.size()):
		var node: Node3D = game.fleet[i]["node"]
		if not holo.has(node.get_instance_id()):
			continue
		blips_vivos += 1
		var ping: MeshInstance3D = holo[node.get_instance_id()]
		var real: Vector3 = game._holo_de(node.position)
		desvio_max = maxf(desvio_max, ping.position.distance_to(real))
	_assert("seis blips para seis cascos vivos", blips_vivos == 6, "%d blips" % blips_vivos)
	_assert("o painel replica o dispersar em trânsito", desvio_max < 0.0001,
		"maior desvio blip-vs-realidade %.6f" % desvio_max)

	# 12 — Cruzar o próprio anel com separação ligada: obedecer não pode custar casco.
	_espalhar(game)
	game._give_order("DISPERSAR")
	_navega(game, 220, true)
	var hp_aliado := 0
	var furou := 0
	var pos_finais := _posicoes(game)
	for unit in game.fleet:
		hp_aliado += int(unit["hp"])
	for a in range(pos_finais.size()):
		for b in range(a + 1, pos_finais.size()):
			if pos_finais[a].distance_to(pos_finais[b]) < DIAMETRO_CASCO - 0.001:
				furou += 1
	_assert("dispersar com separação não fere aliado", hp_aliado == 600,
		"soma de casco aliado %d contra 600" % hp_aliado)
	_assert("seis cascos cruzando o anel não se atravessam", furou == 0,
		"%d pares abaixo do diâmetro" % furou)

	# 13 — Escopo: dispersar o ALFA não mexe no BETA.
	_alinhar(game)
	for unit in game.fleet:
		unit.erase("destination")
		unit["order"] = "MANTER"
	game.selection_scope = "ESQUADRÃO ALFA"
	game._give_order("DISPERSAR")
	var so_alfa := true
	for i in range(6):
		var tem: bool = game.fleet[i].has("destination")
		if tem != (i < 3):
			so_alfa = false
	_assert("o anel só veste o esquadrão selecionado", so_alfa,
		"ALFA 0-2 com destino, BETA 3-5 sem")
	var centro_alfa: Vector3 = game._centro_selecao(game._selected_indices())
	_assert("o centro é o da seleção, não o da frota", _igual(centro_alfa.x, -7.5, 0.001)
		and _igual(centro_alfa.z, -38.0, 0.001),
		"centro ALFA %.3f, %.3f contra -7,500 / -38,000 (a frota inteira daria x 0,000)" % [
			centro_alfa.x, centro_alfa.z])
	game.selection_scope = "FROTA"

	# 14 — Ordem nova desliga o destino velho: o timão é a ordem, não a presença do número.
	game._give_order("AVANÇAR")
	var adiante := (game.fleet[0]["node"] as Node3D).position
	var z_antes := adiante.z
	var x_antes := adiante.x
	_assert("a nova ordem reescreve a ordem da unidade",
		String(game.fleet[0]["order"]) == "AVANÇAR", str(game.fleet[0]["order"]))
	game._update_fleet(PASSO)
	var depois := (game.fleet[0]["node"] as Node3D).position
	_assert("com a ordem trocada o destino velho fica guardado",
		absf(depois.z - (z_antes - 0.12)) < 0.0001 and _igual(depois.x, x_antes, 0.0001),
		"z %.4f -> %.4f (avançar) com x parado" % [z_antes, depois.z])

	# 15 — Seleção unitária: um casco não tem anel, tem o próprio centro. Divide por zero na
	# mesma fórmula que os seis passam.
	game.selection_scope = "NAVE 2"
	var posto_solo: Vector3 = game._anel_posto(0, 1, Vector3(3.0, 0.0, -40.0), DISPERSAR_RAIO)
	_assert("um casco em anel vira o próprio centro", posto_solo == Vector3(3.0, 0.0, -40.0),
		str(posto_solo))
	game._give_order("AGRUPAR")
	var solo: Dictionary = game.fleet[1]
	var corpo_solo: Node3D = game.fleet[1]["node"]
	# Centro de uma seleção de um casco é o próprio casco — o destino tem de ser onde ele já está,
	# e não o Vector3(2,5, -38) que a sonda chutou na primeira rodada (a seção 14 já tinha movido o
	# casco 0,12 u para ré, e um número cravado aqui mediria a sonda, não o jogo).
	_assert("a ordem unitária fecha em destino único",
		solo.has("destination") and (solo["destination"] as Vector3) == corpo_solo.position,
		"destino %s sobre o casco %s" % [str(solo.get("destination")), str(corpo_solo.position)])
	game.selection_scope = "FROTA"

	# 16 — Destroço fora da conta: corpo sem motor não entra no anel nem puxa o centro.
	_alinhar(game)
	for unit in game.fleet:
		unit.erase("destination")
		unit["order"] = "MANTER"
	game.fleet[2]["order"] = "LINHA"
	game.fleet[2]["hp"] = 0.0
	var centro_vivos: Vector3 = game._centro_selecao(game._selected_indices())
	game._give_order("DISPERSAR")
	var ordem_morta: String = String(game.fleet[2]["order"])
	var destino_morto: bool = game.fleet[2].has("destination")
	var com_destino := 0
	for i in range(6):
		if game.fleet[i].has("destination") and String(game.fleet[i]["order"]) == "DISPERSAR":
			com_destino += 1
	_assert("cinco vivos formam o anel, o destroço não", com_destino == 5,
		"%d cascos com destino de dispersar" % com_destino)
	_assert("o destroço conserva a ordem que tinha", ordem_morta == "LINHA"
		and not destino_morto, "%s / destino=%s" % [ordem_morta, str(destino_morto)])
	_assert("o centro ignora o casco morto", _igual(centro_vivos.z, -38.0, 0.001)
		and _igual(centro_vivos.x, 0.5, 0.001),
		"centro %.3f, %.3f contra 0,500 / -38,000" % [centro_vivos.x, centro_vivos.z])
	game.fleet[2]["hp"] = 100.0

	# 17 — Prova central: dois jogos na mesma semente, um manobrando densidade e outro parado. O que
	# tem de fechar igual é o COMBATE (casco, motor, arma, tripulação e o estado do `rng`), não a
	# posição — posição é justamente o que a ordem muda, e comparar posição aqui seria provar que
	# dispersar não dispersa.
	var a: Node3D = await _montar_jogo()
	_alinhar(a)
	_zerar(a)
	a.rng.seed = 909090
	a.selection_scope = "FROTA"
	var b: Node3D = await _montar_jogo()
	_alinhar(b)
	_zerar(b)
	b.rng.seed = 909090
	b.selection_scope = "FROTA"
	for ciclo in range(8):
		a._give_order("DISPERSAR")
		a._update_fleet(0.5)
		a._resolve_collisions()
		a._give_order("AGRUPAR")
		a._update_fleet(0.5)
		a._resolve_collisions()
		b._update_fleet(0.5)
		b._resolve_collisions()
	var sig_a := _assinatura_combate(a)
	var sig_b := _assinatura_combate(b)
	_assert("A/B: as ordens de densidade não mexem no resultado do combate",
		sig_a == sig_b and int(a.rng.state) == int(b.rng.state),
		"estados %s / %s" % [str(a.rng.state), str(b.rng.state)])
	_assert("A/B: a manobra aconteceu — os dois tabuleiros divergem em posição",
		_posicoes(a) != _posicoes(b), "cascos somados %.1f em cada lado" % _soma_casco(a))
	# A guarda de que a assinatura de combate é sensível: um abalroamento de verdade muda o número.
	var guarda: Node3D = await _montar_jogo()
	_alinhar(guarda)
	_zerar(guarda)
	guarda.rng.seed = 909090
	for ciclo in range(8):
		guarda._update_fleet(0.5)
		guarda._resolve_collisions()
	var guarda_antes := _assinatura_combate(guarda)
	# Geometria de encontro, no mesmo molde de `tools/probes/manobra.gd`: dois cascos a 4,0 u de
	# distância (somam 4,8) correndo um contra o outro. Colocá-los NO MESMO ponto forçaria a normal
	# +Z e inverteria o sinal de `aproximacao` — foi assim que a primeira rodada não cobrou nada.
	var casco_a: Node3D = guarda.fleet[0]["node"]
	var casco_b: Node3D = guarda.enemies[1]["node"]
	casco_a.position = casco_b.position + Vector3(0.0, 0.0, -4.0)
	guarda.fleet[0]["veloc"] = Vector3(0.0, 0.0, 30.0)
	guarda.enemies[1]["veloc"] = Vector3(0.0, 0.0, -30.0)
	guarda.battle_clock = 600.0
	guarda._resolve_collisions()
	_assert("A/B: a medida é sensível — abalroar muda a assinatura de combate",
		_assinatura_combate(guarda) != guarda_antes,
		"casco do hostil 02 caiu para %.1f" % float(guarda.enemies[1]["hp"]))
	_assert("A/B: a medição não foi em tabuleiro vazio",
		_soma_casco(a) > 900.0 and sig_a.length() > 200,
		"cascos somados %.1f, assinatura de %d caracteres" % [_soma_casco(a), sig_a.length()])

	a.free()
	b.free()
	guarda.free()
	game.free()

	for nota in notes:
		print("SONDA-MENU: " + nota)
	print("veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	quit()

## Centro esperado do tabuleiro espalhado: x soma-zero e z médio -25 (metade em -40, metade em
## -10, porque `-40 + 30` sobe em vez de descer) — se a ordem ancorar no cadastro (-38) em vez dos
## cascos, este número denuncia.
func _is_centro_esperado(centro: Vector3) -> bool:
	return _igual(centro.x, 0.0, 0.001) and _igual(centro.z, -25.0, 0.001)

## Assinatura de COMBATE: casco, motor, arma e tripulação de cada unidade, sem posição. É o número
## que a ordem de manobra tem de deixar intacto — posição muda de propósito, e por isso a posição
## fica de fora daqui e é asserida à parte.
func _assinatura_combate(game) -> String:
	var partes: Array[String] = []
	for list in [game.fleet, game.enemies]:
		for unit in list:
			partes.append("%s:%.2f/%.2f/%.2f/%.2f" % [unit["name"], float(unit["hp"]),
				float(unit["engines"]), float(unit["weapons"]), float(unit["crew"])])
	return "|".join(partes)

func _soma_casco(game) -> float:
	var soma := 0.0
	for list in [game.fleet, game.enemies]:
		for unit in list:
			soma += float(unit["hp"])
	return soma
