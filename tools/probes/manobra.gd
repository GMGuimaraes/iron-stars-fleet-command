extends SceneTree

## Sonda da navegação e do casco físico. O que ela prova tem três camadas, e a terceira é a que
## costuma ser mentirosa:
##
## 1) O timão obedece em três eixos — avante, RÉ (com teto próprio), guinada, arfagem, rolagem
##    autocorrigida e empuxo vertical — e o campo é grande, com limites que fecham em coordenada
##    exata. Nada disso sorteia: `rng.state` tem de sair intacto de vinte quadros de manobra, e
##    é por isso que a posição da ponte pode ser afirmada com valor, não com ordem de grandeza.
## 2) Corpo não atravessa corpo. Separação posicional com peso distribuído pelo casco, destroço
##    como âncora imóvel, e o abalroamento cobra dos DOIS lados — com porta de velocidade
##    (encostar não fere), teto de dano e janela por par, que é o que impede um casco encostado
##    de perder a tripulação inteira em dois segundos.
## 3) A mesa holográfica é o campo, não um desenho do campo: escala isótropa em x e z (uma mesa
##    que alonga um eixo mente sobre distância), altitude mapeada, aro que segura quem está fora
##    da janela, e o blip dourado da capitânia seguindo o rig. O blip da ponte mora fora de
##    `holo_blips` de propósito, e a conta de 12 blips por casco vivo é a asserção que garante
##    isso.
##
## A guarda contra a armadilha do corredor vazio está na última seção: o mesmo A/B que prova que
## voar LONGE da linha não reescreve um dano também mede que voar DENTRO da linha reescreve. Sem
## o segundo lado, o primeiro seria verdade por ausência de contato.
##
## Uso: godot --headless --path . --quit-after 1800 -s res://tools/probes/manobra.gd

## Espelho das constantes de `main.gd`: a instância do jogo é não tipada e elas não são
## alcançáveis por ela (mesmo motivo em `tools/probes/graficos.gd`). Mudar uma aqui e não lá é
## exatamente o tipo de desvio que esta sonda reprova.
const MAP_X := 320.0
const MAP_Y := 180.0
const MAP_Z_FAR := -600.0
const CAPITAL_SPEED := 22.0
const CAPITAL_REVERSE := -0.6
const CAPITAL_LIFT := 12.0
const PITCH_LIMIT := 0.62
const ROLL_LIMIT := 0.5
const HULL_RADIUS := 2.4
const CAPITAL_RADIUS := 6.0
const RAM_SPEED := 3.0
const RAM_DAMAGE := 1.9
const RAM_MAX_DAMAGE := 18.0
const HOLO_SCALE := 0.075
const HOLO_RIM := 2.85
const HOLO_ALT_SCALE := 0.09

var breaks := 0
var notes: Array[String] = []

func _assert(label: String, condition: bool, detail: String) -> void:
	if condition:
		notes.append("OK   %s — %s" % [label, detail])
	else:
		breaks += 1
		notes.append("QUEBRA %s — %s" % [label, detail])

## O `is_equal_approx` do motor só aceita dois argumentos e a tolerância interna dele é apertada
## demais para comparar um valor lido do nó com um valor recalculado pela sonda. Toda asserção de
## coordenada usa esta, com a tolerância escrita na chamada: sem ela a sonda reprovaria por um
## último dígito de float, que não é defeito do jogo.
func _igual(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol

## Injeta a AÇÃO de voo, não a tecla. Medido nesta engine (4.7.2, headless): `Input
## .parse_input_event()` empurra o evento para a fila mas não preenche o estado que
## `is_action_pressed` lê — com W injetado o acelerador ficou em 0,000 e o casco não andou um
## centímetro. `Input.action_press` preenche, e é por ela que a manobra existe: o mesmo
## `InputMap` registrado em `_registra_voo()` é o que a tecla física do jogador atravessa numa
## janela real. Que a tecla chega à ação é o que só o editor prova, e a sonda não finge que provou.
func _teclar(acao: String, apertado: bool) -> void:
	if apertado:
		Input.action_press(acao)
	else:
		Input.action_release(acao)

func _soltar_tudo() -> void:
	for acao in ["capital_avante", "capital_re", "capital_bombordo", "capital_estibordo",
		"capital_nariz_acima", "capital_nariz_abaixo", "capital_role_esquerda",
		"capital_role_direita", "capital_empuxo_acima", "capital_empuxo_abaixo"]:
		_teclar(acao, false)

## Toda seção de voo abre e fecha a mesma ação por nome, e o nome é o que `_registra_voo` escreve:
## se a ação mudar de rótulo no jogo e não aqui, `action_press` de ação inexistente não liga nada e
## a sonda acorda com o casco parado — que é QUEBRA ruidosa, não verde mentiroso.
func _acoes_voo_existem() -> bool:
	for acao in ["capital_avante", "capital_re", "capital_bombordo", "capital_estibordo",
		"capital_nariz_acima", "capital_nariz_abaixo", "capital_role_esquerda",
		"capital_role_direita", "capital_empuxo_acima", "capital_empuxo_abaixo"]:
		if not InputMap.has_action(acao) or InputMap.action_get_events(acao).is_empty():
			return false
	return true

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

func _assinatura(game) -> String:
	var parts: Array[String] = []
	for list in [game.fleet, game.enemies]:
		for unit in list:
			var node: Node3D = unit["node"]
			parts.append("%s:%.2f/%.2f/%.2f/%.2f@%.2f,%.2f,%.2f" % [unit["name"],
				float(unit["hp"]), float(unit["engines"]), float(unit["weapons"]), float(unit["crew"]),
				node.position.x, node.position.y, node.position.z])
	return "|".join(parts)

func _soma_hostil(game) -> float:
	var total := 0.0
	for unit in game.enemies:
		total += float(unit["hp"])
	return total

func _viver(game, ciclos: int, passo: float) -> void:
	for i in range(ciclos):
		game._update_fleet(passo)
		game._resolve_volley()

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
	_soltar_tudo()

	# 1 — Linha de partida: a ponte é corpo, o casco dela tem medida e o campo é tridimensional.
	_assert("timão registrado no InputMap", _acoes_voo_existem(),
		"as dez ações de voo existem e cada uma tem evento de teclado")
	_assert("capitânia abre com casco cheio", is_equal_approx(float(game.capital_hp), 100.0),
		"casco %.1f" % float(game.capital_hp))
	_assert("rig abre na origem, parado", game.bridge_rig.position == Vector3.ZERO
		and is_equal_approx(float(game.throttle), 0.0),
		str(game.bridge_rig.position))
	var corpos: Array[Dictionary] = game._collision_bodies()
	_assert("corpos de colisão = 12 cascos + ponte", corpos.size() == 13,
		"%d corpos" % corpos.size())
	var ancoras := 0
	for corpo in corpos:
		if bool(corpo["imovel"]):
			ancoras += 1
	_assert("linha viva não tem âncora", ancoras == 0, "%d imóveis" % ancoras)

	# 2 — Avante. O teto de throttle é 1,0 e a marcha é -Z do rig sem guinada.
	_teclar("capital_avante", true)
	game._update_capital_ship(0.1)
	_assert("tecla injetada move o acelerador", float(game.throttle) > 0.0,
		"throttle %.3f após um quadro de W" % float(game.throttle))
	var z_partida: float = game.bridge_rig.position.z
	for i in range(40):
		game._update_capital_ship(0.1)
	_assert("W leva o throttle ao teto e para lá", is_equal_approx(float(game.throttle), 1.0),
		"throttle %.3f" % float(game.throttle))
	_assert("avante corre em -Z na velocidade pintada", game.bridge_rig.position.z < z_partida
		and absf(float(game.capital_velocity.z)) > CAPITAL_SPEED * 0.9,
		"z %.1f, velocidade %.1f u/s" % [game.bridge_rig.position.z, float(game.capital_velocity.z)])

	# 3 — Ré: tem teto próprio (cruzador não manobra de costas como rebocador) e anda para trás
	# de verdade, não apenas desacelera.
	_teclar("capital_avante", false)
	_teclar("capital_re", true)
	for i in range(40):
		game._update_capital_ship(0.1)
	_assert("S vira marcha à ré", float(game.throttle) < 0.0, "throttle %.3f" % float(game.throttle))
	_assert("ré para no teto sem ultrapassar", is_equal_approx(float(game.throttle), CAPITAL_REVERSE),
		"throttle %.3f com teto em %.2f" % [float(game.throttle), CAPITAL_REVERSE])
	var z_na_re: float = game.bridge_rig.position.z
	for i in range(10):
		game._update_capital_ship(0.1)
	_assert("ré empurra o casco para +Z", game.bridge_rig.position.z > z_na_re,
		"z %.2f -> %.2f" % [z_na_re, game.bridge_rig.position.z])

	# 4 — Sem mão no acelerador o casco perde velocidade e para no zero, sem passar para o
	# outro sinal sozinho.
	_teclar("capital_re", false)
	for i in range(40):
		game._update_capital_ship(0.1)
	_assert("inércia devolve o throttle ao neutro", is_equal_approx(float(game.throttle), 0.0),
		"throttle %.3f" % float(game.throttle))

	# 5 — Guinada e arfagem nos tetos, e arfagem com motor ligado vira subida REAL (o empuxo sai
	# da transformada do rig, não de um eixo fixo).
	_teclar("capital_bombordo", true)
	var yaw_antes := float(game.bridge_rig.rotation.y)
	for i in range(10):
		game._update_capital_ship(0.1)
	_assert("A abre a guinada para bombordo", float(game.bridge_rig.rotation.y) > yaw_antes,
		"yaw %.3f -> %.3f" % [yaw_antes, float(game.bridge_rig.rotation.y)])
	_teclar("capital_bombordo", false)
	_teclar("capital_estibordo", true)
	var yaw_direita := float(game.bridge_rig.rotation.y)
	for i in range(10):
		game._update_capital_ship(0.1)
	_assert("D fecha a guinada para estibordo", float(game.bridge_rig.rotation.y) < yaw_direita,
		"yaw %.3f -> %.3f" % [yaw_direita, float(game.bridge_rig.rotation.y)])
	_teclar("capital_estibordo", false)
	_teclar("capital_nariz_acima", true)
	for i in range(40):
		game._update_capital_ship(0.1)
	_assert("arfagem tem teto e para nele", is_equal_approx(float(game.bridge_rig.rotation.x), PITCH_LIMIT),
		"pitch %.3f com teto em %.2f" % [float(game.bridge_rig.rotation.x), PITCH_LIMIT])
	_teclar("capital_avante", true)
	game._update_capital_ship(0.1)
	_assert("nariz alto com motor sobe o casco", float(game.capital_velocity.y) > 0.0,
		"velocidade y %.2f u/s" % float(game.capital_velocity.y))
	_teclar("capital_nariz_acima", false)
	_teclar("capital_avante", false)

	# 6 — Empuxo vetorial: R sobe sem mudar atitude. Atitude é o que a mesa lê, então confundir
	# os dois faria o blip contar subida onde só houve arfagem.
	var pitch_fixado := float(game.bridge_rig.rotation.x)
	game.capital_velocity = Vector3.ZERO
	_teclar("capital_empuxo_acima", true)
	var y_antes: float = game.bridge_rig.position.y
	for i in range(10):
		game._update_capital_ship(0.1)
	_assert("R sobe sem tocar na atitude", is_equal_approx(float(game.bridge_rig.rotation.x), pitch_fixado)
		and game.bridge_rig.position.y > y_antes,
		"y %.2f -> %.2f, pitch %.3f" % [y_antes, game.bridge_rig.position.y, pitch_fixado])
	_teclar("capital_empuxo_acima", false)
	_teclar("capital_empuxo_abaixo", true)
	var y_topo: float = game.bridge_rig.position.y
	for i in range(10):
		game._update_capital_ship(0.1)
	_assert("V desce", game.bridge_rig.position.y < y_topo,
		"y %.2f -> %.2f" % [y_topo, game.bridge_rig.position.y])
	_teclar("capital_empuxo_abaixo", false)

	# 7 — Rolagem se autocorrige: o rig endireita sozinho quando a mão sai do teclado, senão a
	# mesa holográfica (filha do rig) ficaria torta o resto da batalha.
	_teclar("capital_role_esquerda", true)
	for i in range(20):
		game._update_capital_ship(0.1)
	_assert("rolagem tem teto", is_equal_approx(float(game.bridge_rig.rotation.z), ROLL_LIMIT),
		"roll %.3f" % float(game.bridge_rig.rotation.z))
	_teclar("capital_role_esquerda", false)
	for i in range(20):
		game._update_capital_ship(0.1)
	_assert("sem tecla o casco se endireita", absf(float(game.bridge_rig.rotation.z)) < 0.01,
		"roll %.4f após 2,0 s sem mão" % float(game.bridge_rig.rotation.z))

	# 8 — O campo é grande e fechado: teto de altitude, fundo do mapa e borda de costado, todos
	# em coordenada exata (sem sorteio, então afirmar valor é legítimo).
	_teclar("capital_empuxo_acima", true)
	for i in range(200):
		game._update_capital_ship(0.1)
	_assert("subida para no teto do campo", is_equal_approx(game.bridge_rig.position.y, MAP_Y),
		"y %.2f com teto em %.1f" % [game.bridge_rig.position.y, MAP_Y])
	_teclar("capital_empuxo_acima", false)
	game.bridge_rig.rotation = Vector3.ZERO
	game.bridge_rig.rotation.y = PI / 2.0
	_teclar("capital_avante", true)
	for i in range(200):
		game._update_capital_ship(0.1)
	_assert("costado fecha o mapa", is_equal_approx(absf(game.bridge_rig.position.x), MAP_X),
		"x %.2f com borda em %.1f" % [game.bridge_rig.position.x, MAP_X])
	game.bridge_rig.rotation.y = 0.0
	for i in range(400):
		game._update_capital_ship(0.1)
	_assert("fundo do mapa é o limite, não o vazio", is_equal_approx(game.bridge_rig.position.z, MAP_Z_FAR),
		"z %.2f com fundo em %.1f" % [game.bridge_rig.position.z, MAP_Z_FAR])

	# 9 — Pureza: vinte quadros de manobra não podem gastar um sorteio de combate.
	var semente_antes := int(game.rng.state)
	for i in range(20):
		game._update_capital_ship(0.1)
	_assert("manobrar não sorteia combate", int(game.rng.state) == semente_antes,
		"rng.state %d -> %d" % [semente_antes, int(game.rng.state)])
	_soltar_tudo()

	# 10 — Separação: dois cascos colados se soltam até encostarem nos raios, com o mesmo empurrão
	# para cada lado (mesmo raio) e sem um golpe de impacto.
	_alinhar(game)
	_zerar(game)
	var vivo_a: Node3D = game.fleet[0]["node"]
	var vivo_b: Node3D = game.fleet[1]["node"]
	vivo_a.position = Vector3(0.0, 0.0, -200.0)
	vivo_b.position = Vector3(0.0, 0.0, -197.0)
	var deslocado_a := vivo_a.position
	var deslocado_b := vivo_b.position
	game._resolve_collisions()
	var abertura := vivo_a.position.distance_to(vivo_b.position)
	_assert("cascos param encostados nos raios", _igual(abertura, 2.0 * HULL_RADIUS, 0.01),
		"distância %.3f (esperado %.1f)" % [abertura, 2.0 * HULL_RADIUS])
	_assert("iguais cedem igual", absf(vivo_a.position.distance_to(deslocado_a)
		- vivo_b.position.distance_to(deslocado_b)) < 0.001,
		"a %.3f, b %.3f" % [vivo_a.position.distance_to(deslocado_a), vivo_b.position.distance_to(deslocado_b)])
	_assert("encostar não fere", is_equal_approx(float(game.fleet[0]["hp"]), 100.0)
		and is_equal_approx(float(game.fleet[1]["hp"]), 100.0),
		"hp %.1f e %.1f sem velocidade de aproximação" % [float(game.fleet[0]["hp"]), float(game.fleet[1]["hp"])])

	# 10b — Aliado contra aliado é manobra, não combate: separa e não cobra, MESMO a 60 u/s de
	# fecho. A formação agora navega e atravessa a própria linha; sem esta asserção o jogador
	# pagaria casco por uma ordem que ele mesmo deu, e a exemptação seria invisível.
	_zerar(game)
	vivo_a.position = Vector3(0.0, 0.0, -200.0)
	vivo_b.position = Vector3(0.0, 0.0, -196.0)
	game.fleet[0]["veloc"] = Vector3(0.0, 0.0, 30.0)
	game.fleet[1]["veloc"] = Vector3(0.0, 0.0, -30.0)
	game.battle_clock = 480.0
	game._resolve_collisions()
	_assert("aliado encosta em aliado, separa e não fere", is_equal_approx(float(game.fleet[0]["hp"]), 100.0)
		and is_equal_approx(float(game.fleet[1]["hp"]), 100.0)
		and _igual(vivo_a.position.distance_to(vivo_b.position), 2.0 * HULL_RADIUS, 0.01),
		"hp %.1f e %.1f a 60 u/s de fecho, abertos para %.3f" % [float(game.fleet[0]["hp"]),
		float(game.fleet[1]["hp"]), vivo_a.position.distance_to(vivo_b.position)])

	# 11 — Abalroamento hostil cobra dos dois lados, com a MESMA conta, e satura no teto.
	_zerar(game)
	var presa: Node3D = game.enemies[0]["node"]
	vivo_a.position = Vector3(0.0, 0.0, -200.0)
	presa.position = Vector3(0.0, 0.0, -196.0)
	game.fleet[0]["veloc"] = Vector3(0.0, 0.0, 30.0)
	game.enemies[0]["veloc"] = Vector3(0.0, 0.0, -30.0)
	game.battle_clock = 500.0
	game._resolve_collisions()
	var perda_a := 100.0 - float(game.fleet[0]["hp"])
	var perda_b := 100.0 - float(game.enemies[0]["hp"])
	_assert("abalroamento fere os dois", perda_a > 0.0 and perda_b > 0.0,
		"-%.2f e -%.2f" % [perda_a, perda_b])
	_assert("o dano é simétrico", _igual(perda_a, perda_b, 0.001),
		"%.3f contra %.3f" % [perda_a, perda_b])
	_assert("dano de impacto não passa do teto", _igual(perda_a, RAM_MAX_DAMAGE, 0.01),
		"%.2f com teto em %.1f" % [perda_a, RAM_MAX_DAMAGE])
	_assert("motor e arma também sentem a bordaada", float(game.fleet[0]["engines"]) < 100.0
		and float(game.fleet[0]["weapons"]) < 100.0,
		"motor %.1f, arma %.1f" % [float(game.fleet[0]["engines"]), float(game.fleet[0]["weapons"])])

	# 12 — Fórmula abaixo do teto: aproximação de 8 u/s deve dar (8-3)*1,9 = 9,5 e não o teto.
	_zerar(game)
	var meio_a: Node3D = game.fleet[2]["node"]
	var meio_b: Node3D = game.enemies[1]["node"]
	meio_a.position = Vector3(0.0, 0.0, -220.0)
	meio_b.position = Vector3(0.0, 0.0, -216.5)
	game.fleet[2]["veloc"] = Vector3(0.0, 0.0, 5.0)
	game.enemies[1]["veloc"] = Vector3(0.0, 0.0, -3.0)
	game.battle_clock = 700.0
	game._resolve_collisions()
	var esperado := (8.0 - RAM_SPEED) * RAM_DAMAGE
	_assert("impacto leve cobra a fórmula, não o teto",
		_igual(100.0 - float(game.fleet[2]["hp"]), esperado, 0.01),
		"-%.2f contra %.2f previstos" % [100.0 - float(game.fleet[2]["hp"]), esperado])

	# 13 — Janela por par: o mesmo contato não vira metralhadora de dano. A sobreposição é
	# refeita de propósito, senão a asserção mediria a separação anterior e não a janela.
	var hp_janela := float(game.fleet[2]["hp"])
	meio_a.position = Vector3(0.0, 0.0, -220.0)
	meio_b.position = Vector3(0.0, 0.0, -216.5)
	game._resolve_collisions()
	_assert("segundo contato na janela não cobra", is_equal_approx(float(game.fleet[2]["hp"]), hp_janela),
		"hp %.2f -> %.2f sem avançar o relógio" % [hp_janela, float(game.fleet[2]["hp"])])
	meio_a.position = Vector3(0.0, 0.0, -220.0)
	meio_b.position = Vector3(0.0, 0.0, -216.5)
	game.battle_clock = 705.0
	game._resolve_collisions()
	_assert("fora da janela o par volta a cobrar", float(game.fleet[2]["hp"]) < hp_janela,
		"hp %.2f -> %.2f após 5 s" % [hp_janela, float(game.fleet[2]["hp"])])

	# 14 — Destroço é âncora: não sai do lugar, não leva dano novo e quem vive cede tudo.
	_zerar(game)
	var morto: Dictionary = game.fleet[4]
	var nodo_morto: Node3D = morto["node"]
	var nodo_vivo: Node3D = game.fleet[5]["node"]
	morto["hp"] = 0.0
	nodo_morto.position = Vector3(0.0, 0.0, -240.0)
	nodo_vivo.position = Vector3(0.0, 0.0, -243.0)
	var ancora := nodo_morto.position
	game._resolve_collisions()
	_assert("destroço não se move um centímetro", nodo_morto.position == ancora,
		str(nodo_morto.position))
	_assert("o casco vivo cede a sobreposição inteira",
		_igual(nodo_vivo.position.z, -240.0 - 2.0 * HULL_RADIUS, 0.01),
		"z %.3f" % nodo_vivo.position.z)
	_assert("âncora não leva dano de casco morto", is_equal_approx(float(morto["hp"]), 0.0),
		"hp %.1f" % float(morto["hp"]))
	var corpos_ancora: Array[Dictionary] = game._collision_bodies()
	var imoveis := 0
	for corpo in corpos_ancora:
		if bool(corpo["imovel"]):
			imoveis += 1
	_assert("casco baixado entra como âncora", imoveis == 1, "%d imóveis" % imoveis)

	# 15 — A ponte é corpo: abalroar a linha hostil fere o hostil E a capitânia, e a conta do
	# empurrão é ponderada pelo casco (o cruzador grande quase não cede).
	_zerar(game)
	_alinhar(game)
	morto["hp"] = 100.0
	var alvo: Node3D = game.enemies[2]["node"]
	var hp_hostil_antes := float(game.enemies[2]["hp"])
	game.bridge_rig.position = alvo.position + Vector3(0.0, 0.0, 6.0)
	game.capital_velocity = Vector3(0.0, 0.0, -30.0)
	game.battle_clock = 900.0
	var pos_hostil_antes := alvo.position
	var pos_ponte_antes: Vector3 = game.bridge_rig.position
	game._resolve_collisions()
	_assert("ponte e hostil feridos no mesmo golpe", float(game.enemies[2]["hp"]) < hp_hostil_antes
		and float(game.capital_hp) < 100.0,
		"hostil -%.2f, capitânia -%.2f" % [hp_hostil_antes - float(game.enemies[2]["hp"]),
		100.0 - float(game.capital_hp)])
	# Os dois deslocamentos saem das POSIÇÕES INICIAIS de cada corpo, não uma da outra: medir o
	# empurrão da ponte a partir do hostil já empurrado daria um número que nenhuma das duas
	# nações produziu. Sobreposição de 2,4 com raios 6,0 e 2,4 → o pequeno cede 2,4*6/8,4.
	var ponte: Node3D = game.bridge_rig
	var cede_hostil := alvo.position.distance_to(pos_hostil_antes)
	var cede_ponte := ponte.position.distance_to(pos_ponte_antes)
	_assert("empurrão ponderado: o pequeno cede mais", cede_hostil > cede_ponte
		and _igual(cede_hostil, 2.4 * CAPITAL_RADIUS / (CAPITAL_RADIUS + HULL_RADIUS), 0.02),
		"hostil %.3f contra ponte %.3f" % [cede_hostil, cede_ponte])
	game.capital_hp = 0.0
	_viver(game, 1, 0.2)
	_assert("sem ponte a salva declara derrota", String(game.report_label.text).contains("DERROTA"),
		String(game.report_label.text))
	game.capital_hp = 100.0
	game.capital_velocity = Vector3.ZERO

	# 16 — A mesa é o campo: isótropa, ancorada no meio da batalha, com altitude e aro.
	var na_linha: Vector3 = game._holo_de(Vector3(10.0, 0.0, -60.0))
	var na_frente: Vector3 = game._holo_de(Vector3(0.0, 0.0, -50.0))
	_assert("mesa isótropa em x e z", _igual(absf(na_linha.x), absf(na_frente.z), 0.0001),
		"x %.4f contra z %.4f para os mesmos 10 u" % [absf(na_linha.x), absf(na_frente.z)])
	_assert("ancoragem no campo de ação", _igual(na_linha.z, 0.0, 0.0001)
		and _igual(na_frente.x, 0.0, 0.0001),
		"centro lido em %.4f/%.4f" % [na_linha.z, na_frente.x])
	var subiu: Vector3 = game._holo_de(Vector3(0.0, 5.0, -60.0))
	_assert("altitude entra na mesa", _igual(subiu.y, 0.1 + 5.0 * HOLO_ALT_SCALE, 0.0001),
		"y %.3f (esperado %.3f)" % [subiu.y, 0.1 + 5.0 * HOLO_ALT_SCALE])
	var fora_do_campo: Vector3 = game._holo_de(Vector3(400.0, 0.0, -60.0))
	_assert("quem está fora encosta no aro",
		_igual(Vector2(fora_do_campo.x, fora_do_campo.z).length(), HOLO_RIM, 0.001),
		"raio %.3f com aro em %.2f" % [Vector2(fora_do_campo.x, fora_do_campo.z).length(), HOLO_RIM])

	# 17 — O blip obedece ao casco real, não ao cadastro: move o navio, acorda a mesa, confere.
	var unidade: Dictionary = game.fleet[2]
	var nodo_unidade: Node3D = unidade["node"]
	nodo_unidade.position = Vector3(-14.0, 6.0, -70.0)
	game._update_bridge(0.0)
	var blip: MeshInstance3D = game.holo_blips[nodo_unidade.get_instance_id()]
	_assert("blip replica o casco inclinado a altitude",
		blip.position == game._holo_de(nodo_unidade.position),
		"blip %s contra campo %s" % [str(blip.position), str(game._holo_de(nodo_unidade.position))])
	game.bridge_rig.position = Vector3(20.0, 18.0, -90.0)
	game._update_bridge(0.0)
	_assert("blip dourado segue a ponte", game.holo_capitania.position
		== game.holo_root.position + game._holo_de(game.bridge_rig.position),
		"capitânia %.2f/%.2f/%.2f" % [game.holo_capitania.position.x,
		game.holo_capitania.position.y, game.holo_capitania.position.z])
	_assert("ponte não infla a conta de blips", game.holo_blips.size() == 12
		and game.holo_root.get_child_count() == 12,
		"%d blips de frota no disco" % game.holo_blips.size())

	# 18 — Monte a frota não custa sorteio de batalha: a semente agora vale desde a primeira
	# salva, e é isso que permite às sondas assinarem coordenada em vez de ordem de grandeza.
	var fora: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	fora.rng.seed = 987654321
	var semente_spawn := int(fora.rng.state)
	fora._build_fleets()
	_assert("formar a linha não sorteia combate", int(fora.rng.state) == semente_spawn,
		"rng.state %d -> %d" % [semente_spawn, int(fora.rng.state)])
	fora.free()

	# 19 — A/B central: dois jogos na mesma semente e no mesmo tabuleiro alinhado, um com a ponte
	# voando longe da linha e outro com a ponte parada. Oito ciclos de movimento mais salva.
	var a: Node3D = await _montar_jogo()
	var b: Node3D = await _montar_jogo()
	a.rng.seed = 424242
	b.rng.seed = 424242
	_alinhar(a)
	_alinhar(b)
	_zerar(a)
	_zerar(b)
	a.bridge_rig.position = Vector3(120.0, 40.0, -140.0)
	for ciclo in range(8):
		a._update_capital_ship(0.25)
		a._update_fleet(1.0)
		a._resolve_volley()
		b._update_fleet(1.0)
		b._resolve_volley()
	# A iniciativa aliada (tools/probes/ia.gd) lê a capitânia como ameaça priorizada, então a posição
	# da ponte passou a ser ENTRADA tática: os dois tabuleiros divergem de propósito. O invariante que
	# continua valendo — e é o que a sonda de salva assina — é o consumo do gerador: a IA mudou PARA
	# ONDE a salva vai, nunca quantos dados ela rola.
	_assert("voar longe não muda quantos dados a batalha rola",
		int(a.rng.state) == int(b.rng.state),
		"rng %d contra %d em oito ciclos" % [int(a.rng.state), int(b.rng.state)])
	_assert("e a posição da ponte é entrada tática: a esquadra protege a própria capitânia",
		_assinatura(a) != _assinatura(b),
		"pontes a (%.0f,%.0f,%.0f) e (%.0f,%.0f,%.0f) — hostis somados %.1f contra %.1f de casco" % [
			a.bridge_rig.position.x, a.bridge_rig.position.y, a.bridge_rig.position.z,
			b.bridge_rig.position.x, b.bridge_rig.position.y, b.bridge_rig.position.z,
			_soma_hostil(a), _soma_hostil(b)])
	# A guarda: a mediação continua sensível ao contato físico. Se a ponte atravessar a linha, o casco
	# do hostil atingido tem de cair — sem isto, a linha acima seria verdade por ausência de contato.
	var a_hostil: Node3D = a.enemies[1]["node"]
	a.bridge_rig.position = a_hostil.position + Vector3(0.0, 0.0, 5.0)
	a.capital_velocity = Vector3(0.0, 0.0, -40.0)
	a.battle_clock += 10.0
	var casco_antes := float(a.enemies[1]["hp"])
	a._resolve_collisions()
	_assert("mergulhar na linha muda o tabuleiro",
		a_hostil.position != b.enemies[1]["node"].position or float(a.enemies[1]["hp"]) < casco_antes,
		"hostil 02: %.1f de casco antes do mergulho, %.1f depois; %.1f na esquadra que ficou parada"
		% [casco_antes, float(a.enemies[1]["hp"]), float(b.enemies[1]["hp"])])
	_assert("capitânia que mergulha leva no casco", float(a.capital_hp) < 100.0,
		"casco da ponte %.1f" % float(a.capital_hp))

	for nota in notes:
		print("SONDA-MANOBRA: " + nota)
	print("veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	quit()
