extends SceneTree

## Sonda da tripulação de ponte: seis corpos trabalhando, nenhum deles uma unidade.
##
## O pedido do comandante foi «tripulantes na nave, sentados em outras mesas computadores ou
## hologramas operando». Tripulação é pintura — e pintura nesta ponte tem três formas de mentir,
## cada uma com asserção própria aqui:
##
## 1) Esconder o tabuleiro. O corpo que entra no disco da mesa holográfica cobre blip, e blip
##    coberto é leitura perdida no meio da batalha. Então a geometria é conferida posto a posto:
##    nenhum tripulante dentro do raio do disco, nenhum na frente do console que ele opera.
## 2) Virar unidade fantasma. Se o corpo entrasse em `fleet`, `enemies`, `_collision_bodies` ou
##    `holo_blips`, ele passaria a receber ordem, a ser chocado por rocha, a cair no poço e a
##    contar como casco. A conta continua 12 cascos, 13 corpos na física e 12 blips com seis
##    tripulantes no ar.
## 3) Mexer no que já era medido. A pose sai de `battle_clock` com fase por índice — zero sorteio —
##    e a prova é a corrida A/B: duzentos quadros de tripulação animada deixam `rng`, `visual_rng` e
##    a assinatura da salva idênticos ao jogo parado.
##
## Sobram duas margens de comportamento, ambas medidas: a pausa tática congela a tripulação junto
## com a batalha (o laço mora depois do `return` da pausa, não em `_update_bridge`), e o alarme do
## casco ferido escreve uma vez só no material compartilhado das telas — por flanco de estado, não
## por quadro. E a animação é absoluta (`base + seno`), não acumulada: um empurrão por frame faria o
## operador descer pelo soalho em dois minutos de combate, e a asserção do retorno à base existe
## exatamente para isso.
##
## Uso: godot --headless --path . --quit-after 1800 -s res://tools/probes/tripulacao.gd

## Espelho das constantes de `main.gd` — a instância do jogo é não tipada (mesmo motivo em
## `tools/probes/cenarios.gd`). Se o número aqui divergir do código, a asserção quebra: é de propósito.
const TRIPULANTES_SENTADOS := 4
const TRIPULANTES_EM_PE := 2
const BOB_TRONCO := 0.035
const TAP_MAO := 0.05
const FASE_POR_POSTO := 0.7
const ALARME_CASCO := 60.0
const INCLINACAO_ALARME := 0.13
const COR_TELA_CALMA := Color(0.03, 0.22, 0.34)
const COR_TELA_ALARME := Color(0.5, 0.07, 0.05)
## Raio do disco da mesa (`_build_holo_table`) e o centro dele em x/z — as duas medidas que separam
## "tripulante ao lado da mesa" de "tripulante em cima da mesa".
const MESA_RAIO := 3.05
const MESA_Z := -2.6
const PASSO := 0.1

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
	return game

## Distância do posto ao eixo da mesa, no plano x/z — a régua do "não tapa o tabuleiro".
func _fora_da_mesa(game) -> int:
	var dentro := 0
	for posto in game.tripulacao:
		var corpo: Node3D = posto["no"]
		var dx := corpo.global_position.x
		var dz := corpo.global_position.z - MESA_Z
		if sqrt(dx * dx + dz * dz) < MESA_RAIO:
			dentro += 1
	return dentro

func _pose_tronco(posto: Dictionary) -> float:
	var tronco: MeshInstance3D = posto["tronco"]
	return float(tronco.position.y)

func _initialize() -> void:
	var game: Node3D = await _montar_jogo()

	# ---- 1. A lista de corpos: seis postos, dois tipos, todos dentro da ponte -----------------
	_assert("seis tripulantes na ponte", int(game.tripulacao.size())
		== TRIPULANTES_SENTADOS + TRIPULANTES_EM_PE,
		"%d corpos" % game.tripulacao.size())
	var rotulos := ""
	var fora_do_rig := 0
	for i in range(game.tripulacao.size()):
		var corpo: Node3D = game.tripulacao[i]["no"]
		if not is_instance_valid(corpo):
			fora_do_rig += 1
			continue
		if corpo.get_parent() != game.bridge_rig:
			fora_do_rig += 1
		rotulos += String(corpo.name) + " "
	_assert("cada posto é filho da ponte e tem nome de tripulante", fora_do_rig == 0
		and rotulos.strip_edges() == "Tripulante 01 Tripulante 02 Tripulante 03 Tripulante 04 "
			+ "Tripulante 05 Tripulante 06", "[%s]" % rotulos.strip_edges())
	var sentados := 0
	var em_pe := 0
	var maos := 0
	var aneis := 0
	for posto in game.tripulacao:
		if bool(posto["em_pe"]):
			em_pe += 1
		else:
			sentados += 1
		if is_instance_valid(posto["mao"]):
			maos += 1
		if is_instance_valid(posto["anel"]):
			aneis += 1
	_assert("quatro sentados com mão no console, dois de pé com holograma na mão",
		sentados == TRIPULANTES_SENTADOS and em_pe == TRIPULANTES_EM_PE
			and maos == TRIPULANTES_SENTADOS and aneis == TRIPULANTES_EM_PE,
		"sentados=%d em_pe=%d maos=%d aneis=%d" % [sentados, em_pe, maos, aneis])
	_assert("nenhum corpo dentro do disco da mesa: tripulação não tapa blip",
		_fora_da_mesa(game) == 0,
		"mesa de raio %0.2f em z %0.1f, %d postos invadindo" % [MESA_RAIO, MESA_Z,
			_fora_da_mesa(game)])
	# O operador sentado fica a 3,5 do eixo e o console a 4,4: um posto do outro lado da bancada
	# faria o corpo flutuar sobre as teclas que ele mesmo aperta.
	var longe_demaism := 0
	for i in range(TRIPULANTES_SENTADOS):
		var corpo: Node3D = game.tripulacao[i]["no"]
		if absf(absf(corpo.global_position.x) - 3.5) > 0.001:
			longe_demaism += 1
	_assert("os sentados estão encostados na própria bancada (x 3,5, console em 4,4)",
		longe_demaism == 0, "%d postos fora do x pedido" % longe_demaism)

	# ---- 2. Tripulante não é unidade -----------------------------------------------------------
	var corpos_fisicos: int = game._collision_bodies().size()
	var blips: int = (game.holo_blips as Dictionary).size()
	var cascos := 0
	for lista in [game.fleet, game.enemies]:
		for unidade in lista:
			if is_instance_valid(unidade["node"]):
				cascos += 1
	_assert("doze cascos, treze corpos na física, doze blips: seis tripulantes invisíveis à conta",
		cascos == 12 and corpos_fisicos == 13 and blips == 12,
		"cascos=%d fisica=%d blips=%d" % [cascos, corpos_fisicos, blips])
	var no_blip := 0
	for posto in game.tripulacao:
		if (game.holo_blips as Dictionary).has((posto["no"] as Node3D).get_instance_id()):
			no_blip += 1
	_assert("nenhum tripulante tem blip na mesa", no_blip == 0, "%d com blip" % no_blip)

	# ---- 3. A pose mexe, obedece ao relógio e volta à base -------------------------------------
	game.battle_clock = 0.0
	game._update_tripulacao()
	var base_a := _pose_tronco(game.tripulacao[0])
	game.battle_clock = 0.6
	game._update_tripulacao()
	var meio_a := _pose_tronco(game.tripulacao[0])
	game.battle_clock = 0.0
	game._update_tripulacao()
	var volta_a := _pose_tronco(game.tripulacao[0])
	_assert("o tronco respira: dois instantes do relógio dão duas alturas",
		not _igual(base_a, meio_a, 0.000001), "y %0.5f -> %0.5f" % [base_a, meio_a])
	_assert("a pose é absoluta, não acumulada: no mesmo instante, o mesmo corpo",
		_igual(base_a, volta_a, 0.000001), "y %0.6f contra %0.6f na volta" % [base_a, volta_a])
	var pior := 0.0
	for t in range(0, 400):
		game.battle_clock = float(t) * 0.05
		game._update_tripulacao()
		for posto in game.tripulacao:
			pior = maxf(pior, absf(_pose_tronco(posto) - float(posto["base_tronco"])))
	_assert("quatrocentos quadros de pose não tiram o corpo da base mais que a amplitude",
		pior <= BOB_TRONCO + 0.000001, "desvio máximo medido %0.5f contra %0.3f de bob" % [pior,
			BOB_TRONCO])
	var mao_0: MeshInstance3D = game.tripulacao[0]["mao"]
	var mao_base := float(game.tripulacao[0]["base_mao"])
	game.battle_clock = 0.0
	game._update_tripulacao()
	var mao_z_0 := float(mao_0.position.z)
	game.battle_clock = 0.5
	game._update_tripulacao()
	_assert("a mão tecla no console e não passa do batente",
		not _igual(mao_z_0, float(mao_0.position.z), 0.000001)
			and absf(float(mao_0.position.z) - mao_base) <= TAP_MAO + 0.000001,
		"z %0.5f -> %0.5f, base %0.3f, teto %0.2f" % [mao_z_0, float(mao_0.position.z), mao_base,
			TAP_MAO])
	game.battle_clock = 2.0
	game._update_tripulacao()
	var anel: MeshInstance3D = game.tripulacao[4]["anel"]
	var giro_0 := float(anel.rotation.y)
	game.battle_clock = 4.0
	game._update_tripulacao()
	_assert("o holograma de leitura gira com o relógio da batalha",
		not _igual(giro_0, float(anel.rotation.y), 0.000001),
		"%0.4f -> %0.4f rad em 2 s" % [giro_0, float(anel.rotation.y)])
	# As fases têm de ser diferentes por posto: seis corpos respirando juntos é um clone, não tripulação.
	var fases := ""
	var repetidas := 0
	for posto in game.tripulacao:
		var f := float(posto["fase"])
		if fases.contains("%0.2f " % f):
			repetidas += 1
		fases += "%0.2f " % f
	_assert("cada posto tem a própria fase (senão é um clone em série)", repetidas == 0,
		"fases: %s" % fases.strip_edges())

	# ---- 4. A pausa congela a tripulação junto com a batalha ------------------------------------
	game.paused = true
	game.battle_clock = 10.0
	game._update_tripulacao()
	var congelada := _pose_tronco(game.tripulacao[1])
	for i in range(20):
		game._process(PASSO)
	var depois_pausa := _pose_tronco(game.tripulacao[1])
	game.paused = false
	for i in range(20):
		game._process(PASSO)
	var depois_viva := _pose_tronco(game.tripulacao[1])
	_assert("na pausa a ponte inteira para: nem um quadro de pose",
		_igual(congelada, depois_pausa, 0.000001),
		"y %0.6f -> %0.6f em vinte quadros pausados" % [congelada, depois_pausa])
	_assert("retomada, a tripulação volta a trabalhar",
		not _igual(depois_pausa, depois_viva, 0.000001),
		"y %0.6f -> %0.6f nos vinte quadros seguintes" % [depois_pausa, depois_viva])

	# ---- 5. Alarme: um flanco de estado, uma escrita na tela ------------------------------------
	game.capital_hp = 100.0
	game._update_tripulacao()
	var tela: StandardMaterial3D = game.ponte_telas
	_assert("com a capitânia inteira a tela é fria e ninguém se inclina",
		not bool(game.ponte_em_alarme)
			and (tela.emission as Color).is_equal_approx(COR_TELA_CALMA)
			and _igual(float((game.tripulacao[0]["tronco"] as MeshInstance3D).rotation.x), 0.0,
				0.000001),
		"alarme=%s emissão=%s" % [game.ponte_em_alarme, str(tela.emission)])
	game.capital_hp = 40.0
	game.battle_clock = 3.0
	game._update_tripulacao()
	var inclinada_sentada: float = float((game.tripulacao[0]["tronco"] as MeshInstance3D).rotation.x)
	var inclinada_em_pe: float = float((game.tripulacao[4]["tronco"] as MeshInstance3D).rotation.x)
	_assert("casco ferido põe a tela em vermelho e os sentados debruçados",
		bool(game.ponte_em_alarme) and (tela.emission as Color).is_equal_approx(COR_TELA_ALARME)
			and _igual(inclinada_sentada, INCLINACAO_ALARME, 0.000001)
			and _igual(inclinada_em_pe, 0.0, 0.000001),
		"sentado %0.3f rad, em pé %0.3f, emissão=%s" % [inclinada_sentada, inclinada_em_pe,
			str(tela.emission)])
	var escritas := 0
	for i in range(50):
		var antes: Color = tela.emission
		game._update_tripulacao()
		if not (antes as Color).is_equal_approx(tela.emission):
			escritas += 1
	_assert("cinquenta quadros em alarme escrevem a cor zero vezes: só no flanco", escritas == 0,
		"%d escritas em 50 quadros" % escritas)
	game.capital_hp = 100.0
	game._update_tripulacao()
	_assert("reparado, o alarme desliga e a inclinação some",
		not bool(game.ponte_em_alarme) and (tela.emission as Color).is_equal_approx(COR_TELA_CALMA)
			and _igual(float((game.tripulacao[0]["tronco"] as MeshInstance3D).rotation.x), 0.0,
				0.000001),
		"alarme=%s" % game.ponte_em_alarme)

	# ---- 6. A prova central: tripulação animada não mexe na batalha -----------------------------
	var a := await _montar_jogo()
	for i in range(a.fleet.size()):
		(a.fleet[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 5.0, 0.0, -38.0)
	for i in range(a.enemies.size()):
		(a.enemies[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 6.0, 0.0, -82.0)
	a.rng.seed = 424242
	var rng_antes_a: int = a.rng.state
	var visual_antes_a: int = a.visual_rng.state
	for i in range(200):
		a.battle_clock = float(i) * PASSO
		a._update_tripulacao()
	var rng_depois_a: int = a.rng.state
	var visual_depois_a: int = a.visual_rng.state
	a.rng.seed = 424242
	a._resolve_volley()
	var cascos_a := 0.0
	for lista in [a.fleet, a.enemies]:
		for unidade in lista:
			cascos_a += float(unidade["hp"])
	var estado_a: int = a.rng.state
	var b := await _montar_jogo()
	for i in range(b.fleet.size()):
		(b.fleet[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 5.0, 0.0, -38.0)
	for i in range(b.enemies.size()):
		(b.enemies[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 6.0, 0.0, -82.0)
	b.rng.seed = 424242
	var rng_antes_b: int = b.rng.state
	var visual_antes_b: int = b.visual_rng.state
	b.rng.seed = 424242
	b._resolve_volley()
	var cascos_b := 0.0
	for lista in [b.fleet, b.enemies]:
		for unidade in lista:
			cascos_b += float(unidade["hp"])
	var estado_b: int = b.rng.state
	_assert("duzentos quadros de tripulação não movem um dígito dos dois geradores",
		int(rng_antes_a) == int(rng_depois_a) and int(visual_antes_a) == int(visual_depois_a)
			and int(rng_antes_a) == int(rng_antes_b) and int(visual_antes_a) == int(visual_antes_b),
		"rng %d e visual %d dos dois lados" % [rng_antes_a, visual_antes_a])
	_assert("a salva sai idêntica com a ponte trabalhando ou parada",
		int(estado_a) == int(estado_b) and _igual(cascos_a, cascos_b, 0.0001),
		"rng %d e cascos %.1f nos dois jogos" % [estado_a, cascos_a])
	_assert("a medida não foi feita em batalha muda",
		cascos_b < 1200.0 - 0.001, "%.1f de casco ferido na salva de controle" % (1200.0 - cascos_b))
	a.queue_free()
	b.queue_free()
	await _frames(2)

	# ---- 7. Cenário nenhum engole tripulante -----------------------------------------------------
	game._montar_cenario("POCO")
	game.capital_hp = 100.0
	game.battle_clock = 0.0
	var pos_antes: Array[Vector3] = []
	for posto in game.tripulacao:
		pos_antes.append((posto["no"] as Node3D).global_position)
	for i in range(200):
		game._puxar_para_o_poco(PASSO)
		game._chocar_com_rochas()
		game._queimar_na_corona(PASSO)
	var andaram := 0
	for i in range(game.tripulacao.size()):
		if (pos_antes[i] as Vector3).distance_to((game.tripulacao[i]["no"] as Node3D).global_position) > 0.0001:
			andaram += 1
	_assert("poço, rocha e corona não alcançam a tripulação: ela não é corpo no campo",
		andaram == 0, "%d de 6 postos moveram-se sob os três perigos" % andaram)
	game._montar_cenario("ABERTO")

	notes.append("veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	for linha in notes:
		print("SONDA-TRIPULACAO: %s" % linha)
	game.queue_free()
	await _frames(2)
	quit()
