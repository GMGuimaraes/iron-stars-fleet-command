extends SceneTree

## Sonda da tripulação de ponte: seis corpos rigged trabalhando, nenhum deles uma unidade.
##
## O pedido do comandante foi «tripulantes na nave, sentados em outras mesas computadores ou
## hologramas operando», e depois «quero personagens completos, não formas geométricas». Desde
## `assets/tripulante.glb` o corpo é um esqueleto de dezenove juntas, e pintura com esqueleto tem
## quatro formas novas de mentir — cada uma com asserção própria aqui:
##
## 1) Prometer osso que não existe. Se o `.glb` perder uma junta no gerador, `find_bone` devolve -1
##    e a pose escrita no índice -1 não grita: o corpo fica parado fingindo que trabalha. Então a
##    sonda confere os dezessete ossos que a ponte anima, um por um, dentro do jogo montado.
## 2) Flutuar. A caixa antiga subia inteira no bob e o pé descolava do convés. Agora quem respira é
##    a `coluna`, e a asserção que fecha essa promessa é a do tornozelo: a altura do pé não muda um
##    milímetro ao longo de quatrocentos quadros de respiração.
## 3) Esconder o tabuleiro. O corpo que entra no disco da mesa holográfica cobre blip, e blip
##    coberto é leitura perdida no meio da batalha. A geometria é conferida posto a posto.
## 4) Virar unidade fantasma. Se o corpo entrasse em `fleet`, `enemies`, `_collision_bodies` ou
##    `holo_blips`, ele passaria a receber ordem, a ser chocado por rocha e a contar como casco. A
##    conta continua 12 cascos, 13 corpos na física e 12 blips com seis tripulantes no ar.
##
## Sobram duas margens de comportamento, ambas medidas: a pausa tática congela a tripulação junto
## com a batalha (o laço mora depois do `return` da pausa, não em `_update_bridge`), e o alarme do
## casco ferido escreve uma vez só no material compartilhado das telas — por flanco de estado, não
## por quadro. E a pose é absoluta (`repouso + seno` sobre a pose de cadastro), não acumulada: um
## empurrão por frame faria o operador descer pelo soalho em dois minutos de combate.
##
## Os números abaixo são cópias honestas de `main.gd` e `tripulante_rig.gd`, de propósito: se o
## gerador ou a pose mudarem, esta sonda quebra e obriga a releitura da cadeia — não silencia.
##
## Uso: godot --headless --path . --quit-after 6000 -s res://tools/probes/tripulacao.gd

## Ossos que a ponte anima, no cadastro do gerador. O `.glb` traz dezenove juntas e dezessete delas
## têm serviço na ponte.
const JUNTAS_DA_PONTE := ["quadril", "coluna", "peito", "pescoco", "cabeca", "braco_e",
	"antbraco_e", "mao_e", "braco_d", "antbraco_d", "mao_d", "coxa_e", "perna_e", "pe_e",
	"coxa_d", "perna_d", "pe_d"]
const JUNTAS_NO_ESQUELETO := 19
const TRIPULANTES_SENTADOS := 4
const TRIPULANTES_EM_PE := 2
## Pose de trabalho lida de `tripulante_rig.gd`, no espaço do corpo (soalho em y 0, frente em −z).
## É a promessa do cadastro, resolvida antes de qualquer quadro de animação: a ponte trabalha em
## cima dela, então a mão lida no ar só bate no alvo se a asserção usar a pose-base guardada no
## posto, não a pose do instante.
const MAO_BANCADA := Vector3(0.30, 0.97, -0.45)
const MAO_PAD := Vector3(0.24, 1.13, -0.40)
const PAD_ALTURA := 1.09
## Altura do tornozelo no cadastro: a palmilha dourada fica 0,08 acima da sola, e é por ela que o
## corpo sentado encosta o pé no convés em vez de flutuar com o tronco. O sentado fecha 0,3 mm
## acima porque a perna é escrita por DIREÇÕES (o comprimento do cadastro é honrado osso a osso,
## mas a conta não trava o pé no soalho) — resíduo medido, não bodies flutuando.
const TORNOZELO := 0.0801
const TORNOZELO_SENTADO := 0.0803
## Amplitudes lidas de `main.gd`.
const BOB_TRONCO := 0.035
const TAP_ALFA := 0.21
const ANTEBRACO := 0.24
## Arco da batida: a mão gira em torno do cotovelo por TAP_ALFA, então a corda varrida no ar é
## 2·L·sen(α/2) = 0,0503 m. Medida contra o COTOVELO, não contra o solo: o tronco respira junto e
## a altura do pulso carrega a respiração por cima da batida.
const TAP_ARCO := 2.0 * ANTEBRACO * sin(TAP_ALFA / 2.0)
const TAP_MINIMO := 0.02
const VARREDURA_CABECA := 0.14
const FASE_POR_POSTO := 0.7
const ALARME_CASCO := 60.0
const INCLINACAO_ALARME := 0.13
const COR_TELA_CALMA := Color(0.03, 0.22, 0.34)
const COR_TELA_ALARME := Color(0.5, 0.07, 0.05)
## Distância coluna→peito, lida da cadeia medida no motor (sentado 0,74→0,92, de pé 1,02→1,20). É a
## alavanca do debruçar: girar a coluna derruba o peito para vante por este braço.
const PEITO_ACIMA := 0.18
## Raio do disco da mesa (`_build_holo_table`) e o centro dele em x/z — as duas medidas que separam
## "tripulante ao lado da mesa" de "tripulante em cima da mesa".
const MESA_RAIO := 3.05
const MESA_Z := -2.6
const PASSO := 0.1
## Folga de leitura: coordenada de osso vem de malha e transform em `float` de 32 bits.
const FOLGA := 1e-4

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

## Posição do osso no espaço do posto (soalho em y 0, frente em −z): a pose global do esqueleto é
## lida no frame do esqueleto e trazida para o frame da âncora, que é o frame da ponte.
func _osso(posto: Dictionary, osso: String) -> Vector3:
	var esqueleto: Skeleton3D = posto["esqueleto"]
	var indice := int((posto["ossos"] as Dictionary)[osso])
	var no_arvore := esqueleto.global_transform * (esqueleto.get_bone_global_pose(indice).origin)
	return (posto["no"] as Node3D).to_local(no_arvore)

## Direção para onde o rosto aponta, no espaço do corpo: o −z do osso da cabeça depois da pose,
## lido no frame do posto — o x do olhar é a varredura, na árvore seria a rotação do posto em volta
## da mesa e o teto de `VARREDURA_CABECA` não significaria nada.
func _olhar(posto: Dictionary) -> Vector3:
	var esqueleto: Skeleton3D = posto["esqueleto"]
	var indice := int((posto["ossos"] as Dictionary)["cabeca"])
	var d := esqueleto.get_bone_global_pose(indice).basis * Vector3(0.0, 0.0, -1.0)
	var no: Node3D = posto["no"]
	return no.global_transform.affine_inverse().basis * (esqueleto.global_transform.basis * d)

## Altura global da coluna — a respiração, medida onde o olho vê.
func _pose_tronco(posto: Dictionary) -> float:
	return _osso(posto, "coluna").y

func _faltam_ossos(posto: Dictionary) -> int:
	var esqueleto: Skeleton3D = posto["esqueleto"]
	var faltando := 0
	for nome in JUNTAS_DA_PONTE:
		if esqueleto.find_bone(nome) < 0:
			faltando += 1
	return faltando

## O ângulo que a coluna está segurando agora — a prova de que o alarme escreve no osso, não no
## nó do corpo. `get_angle` devolve a grandeza: a inclinação é −INCLINACAO_ALARME no eixo X.
func _angulo_coluna(posto: Dictionary) -> float:
	var esqueleto: Skeleton3D = posto["esqueleto"]
	var indice := int((posto["ossos"] as Dictionary)["coluna"])
	return esqueleto.get_bone_pose_rotation(indice).get_angle()

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
	# A prova de que a ponte não é mais caixa: dentro do posto montado tem o esqueleto do cadastro.
	var sem_esqueleto := 0
	var sem_osso := 0
	var juntas_lidas := 0
	for posto in game.tripulacao:
		if not is_instance_valid(posto["esqueleto"]):
			sem_esqueleto += 1
			continue
		juntas_lidas = (posto["esqueleto"] as Skeleton3D).get_bone_count()
		sem_osso += _faltam_ossos(posto)
	_assert("os seis postos são o rigged do cadastro, não caixas", sem_esqueleto == 0
		and juntas_lidas == JUNTAS_NO_ESQUELETO and sem_osso == 0,
		"%d postos sem esqueleto, %d juntas, %d ossos da ponte ausentes" % [sem_esqueleto,
			juntas_lidas, sem_osso])
	# Se a raiz do corpo não pousar na âncora, nada dos números de corpo abaixo vale: é esta a
	# asserção que autoriza ler a pose no frame do posto. E autoriza só se o quadro for o MESMO:
	# um giro entre a âncora e o esqueleto mandaria a mão para outro bordo sem mover um osso.
	var raiz_fora := 0
	for posto in game.tripulacao:
		var esqueleto: Skeleton3D = posto["esqueleto"]
		var quadro := (posto["no"] as Node3D).global_transform.affine_inverse() * esqueleto.global_transform
		if quadro.origin.length() > 0.001 or quadro.basis.get_rotation_quaternion().get_angle() > 1e-6:
			raiz_fora += 1
	_assert("o esqueleto pousa na âncora sem girar: o y 0 e o −z do cadastro são o convés do posto",
		raiz_fora == 0, "%d de 6 postos com quadro deslocado ou rodado" % raiz_fora)
	var sentados := 0
	var em_pe := 0
	var pad_errado := 0
	for posto in game.tripulacao:
		if bool(posto["em_pe"]):
			em_pe += 1
			if not is_instance_valid(posto["pad"]) or not is_instance_valid(posto["anel"]):
				pad_errado += 1
		else:
			sentados += 1
			if is_instance_valid(posto["pad"]) or is_instance_valid(posto["anel"]):
				pad_errado += 1
	_assert("quatro sentados e dois de pé, pad de leitura só nas mãos de quem está de pé",
		sentados == TRIPULANTES_SENTADOS and em_pe == TRIPULANTES_EM_PE and pad_errado == 0,
		"sentados=%d em_pe=%d pads fora=%d" % [sentados, em_pe, pad_errado])
	# Onde cada mão trabalha, no espaço do corpo. É esta a asserção que separa "o braço alcança a
	# bancada" de "o braço aponta mais ou menos para lá". A régua é a pose-BASE guardada no posto
	# pelo rig, resolvida antes do primeiro quadro: a pose do instante já carrega a respiração e a
	# batida, e cobrar 2 mm delas seria cobrar a animação do corpo inteiro.
	var mao_fora := 0
	var pior_mao := 0.0
	for posto in game.tripulacao:
		var meta: Vector3 = MAO_PAD if bool(posto["em_pe"]) else MAO_BANCADA
		for osso in ["mao_e", "mao_d"]:
			var lado := 1.0 if osso == "mao_e" else -1.0
			var esperado := Vector3(meta.x * lado, meta.y, meta.z)
			var erro: float = (posto["base_" + osso] as Vector3).distance_to(esperado)
			pior_mao = maxf(pior_mao, erro)
			if erro > 0.002:
				mao_fora += 1
	_assert("as doze mãos do rig caem no teclado e no pad, com no máximo 2 mm de erro",
		mao_fora == 0, "%d mãos fora do alvo, pior erro %0.4f m" % [mao_fora, pior_mao])
	# E com a ponte trabalhando a mão não abandona o posto: o teto é a soma honesta dos dois
	# movimentos que a animação tem direito de fazer — o tronco sobe (BOB) e o pulso tecla (arco).
	# Instante cravado, não herdado do `_process`: a medida tem de ser a mesma em toda corrida.
	game.paused = false
	game.capital_hp = 100.0
	game.battle_clock = 0.9
	game._update_tripulacao()
	var deriva := 0.0
	for posto in game.tripulacao:
		var meta2: Vector3 = MAO_PAD if bool(posto["em_pe"]) else MAO_BANCADA
		for osso in ["mao_e", "mao_d"]:
			var lado2 := 1.0 if osso == "mao_e" else -1.0
			deriva = maxf(deriva, _osso(posto, osso).distance_to(
				Vector3(meta2.x * lado2, meta2.y, meta2.z)))
	_assert("com a ponte em obra a mão não deriva do teclado além da respiração mais a batida",
		deriva <= BOB_TRONCO + TAP_ARCO + FOLGA and deriva > 0.005,
		"deriva máxima %0.4f m contra teto %0.4f m" % [deriva, BOB_TRONCO + TAP_ARCO])
	var pad_fora := 0
	var pad_cobre := 0
	for posto in game.tripulacao:
		if bool(posto["em_pe"]):
			var pad: Node3D = posto["pad"]
			if absf(pad.position.y - PAD_ALTURA) > BOB_TRONCO + FOLGA:
				pad_fora += 1
			if pad.position.y >= _osso(posto, "mao_e").y:
				pad_cobre += 1
	_assert("o pad de leitura respira com o oficial (y %0.2f ±%0.3f) e nunca sobe acima das mãos" % [
		PAD_ALTURA, BOB_TRONCO], pad_fora == 0 and pad_cobre == 0,
		"%d pads fora da altura, %d pads acima das mãos" % [pad_fora, pad_cobre])
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

	# ---- 3. A pose mexe, o pé não levanta, e tudo volta à base ---------------------------------
	game.paused = false
	game.capital_hp = 100.0
	game.battle_clock = 0.0
	game._update_tripulacao()
	var base_a := _pose_tronco(game.tripulacao[0])
	var mao_calma := _osso(game.tripulacao[0], "mao_e")
	var coto_calma := _osso(game.tripulacao[0], "antbraco_e")
	game.battle_clock = 0.6
	game._update_tripulacao()
	var meio_a := _pose_tronco(game.tripulacao[0])
	game.battle_clock = 0.0
	game._update_tripulacao()
	var volta_a := _pose_tronco(game.tripulacao[0])
	_assert("o tronco respira: dois instantes do relógio dão duas alturas de coluna",
		not _igual(base_a, meio_a, 0.000001), "y %0.5f -> %0.5f" % [base_a, meio_a])
	_assert("a pose é absoluta, não acumulada: no mesmo instante, o mesmo corpo",
		_igual(base_a, volta_a, 0.000001), "y %0.6f contra %0.6f na volta" % [base_a, volta_a])
	var pior_bob := 0.0
	var pior_pe := 0.0
	var pe_base: Array[Vector3] = []
	for posto in game.tripulacao:
		pe_base.append(_osso(posto, "pe_e"))
	for t in range(0, 400):
		game.battle_clock = float(t) * 0.05
		game._update_tripulacao()
		for i in range(game.tripulacao.size()):
			var posto: Dictionary = game.tripulacao[i]
			pior_bob = maxf(pior_bob, absf(_pose_tronco(posto) - float(posto["base_coluna"])))
			pior_pe = maxf(pior_pe, absf(_osso(posto, "pe_e").y - (pe_base[i] as Vector3).y))
	_assert("quatrocentos quadros de pose não tiram a coluna da base mais que a amplitude",
		pior_bob <= BOB_TRONCO + FOLGA and pior_bob > 0.02,
		"desvio máximo medido %0.5f contra %0.3f de bob" % [pior_bob, BOB_TRONCO])
	# A asserção que fecha a promessa feita à caixa: respirar é a coluna, o pé continua no convés.
	# É variação, não desvio absoluto: o sentado fecha a conta das direções 0,3 mm acima do solo e
	# isso é geometria da perna, não o corpo descolando a cada inspiração.
	_assert("a respiração não levanta o pé do convés: o tornozelo não se move em 400 quadros",
		pior_pe <= FOLGA, "tornozelo variou %0.6f m em 400 quadros" % pior_pe)
	_assert("o tornozelo do oficial de pé está na palmilha (0,0801 do cadastro)",
		_igual(pe_base[4].y, TORNOZELO, 0.001), "y lido %0.4f" % (pe_base[4] as Vector3).y)
	_assert("o tornozelo do sentado fecha a 0,0803 — resíduo da conta de direções, não corpo solto",
		_igual((pe_base[0] as Vector3).y, TORNOZELO_SENTADO, 0.001),
		"y lido %0.4f" % (pe_base[0] as Vector3).y)
	# Batida da mão no teclado, medida no braço: o vetor cotovelo→pulso gira TAP_ALFA e a corda vale
	# 2·L·sen(α/2). Medir a posição no solo somaria a respiração do tronco por cima da batida.
	game.battle_clock = (PI / 2.0) / 3.1
	game._update_tripulacao()
	var pulso_batendo := _osso(game.tripulacao[0], "mao_e") - _osso(game.tripulacao[0], "antbraco_e")
	var desvio := (mao_calma - coto_calma).distance_to(pulso_batendo)
	_assert("a mão tecla: a batida cheia gira o pulso no arco que a régua anuncia",
		desvio > TAP_MINIMO and desvio <= TAP_ARCO + FOLGA,
		"arco %0.4f m entre %0.2f e %0.4f" % [desvio, TAP_MINIMO, TAP_ARCO])
	game.battle_clock = 0.0
	game._update_tripulacao()
	_assert("voltado o relógio, a mão volta ao mesmo ponto do teclado",
		mao_calma.distance_to(_osso(game.tripulacao[0], "mao_e")) <= FOLGA,
		"voltou a %0.5f" % _osso(game.tripulacao[0], "mao_e").z)
	# Varredura de quem está de pé: o rosto muda de direção, o crânio não muda de lugar. O lugar é
	# medido contra o PESCOÇO, não contra o solo: o mesmo quadro que gira a cabeça também respira, e
	# a coluna levando o tronco ao ar levaria o crânio junto se a régua fosse absoluta. Os três
	# instantes saem da FASE do próprio posto — com fase 2,8 o relógio "meia-onda" da batida não é
	# meia-onda nenhuma, e a sonda leria o mesmo extremo duas vezes.
	var fase_pe := float(game.tripulacao[4]["fase"])
	var t_zero := (PI - fase_pe) / 0.35
	var t_bordo := ((PI / 2.0) - fase_pe + TAU) / 0.35
	var t_outro := ((3.0 * PI / 2.0) - fase_pe + TAU) / 0.35
	game.battle_clock = t_zero
	game._update_tripulacao()
	var olhar_frente := _olhar(game.tripulacao[4])
	var cabeca_0 := _osso(game.tripulacao[4], "cabeca") - _osso(game.tripulacao[4], "pescoco")
	game.battle_clock = t_bordo
	game._update_tripulacao()
	var olhar_um := _olhar(game.tripulacao[4])
	var cabeca_1 := _osso(game.tripulacao[4], "cabeca") - _osso(game.tripulacao[4], "pescoco")
	game.battle_clock = t_outro
	game._update_tripulacao()
	var olhar_dois := _olhar(game.tripulacao[4])
	var cabeca_2 := _osso(game.tripulacao[4], "cabeca") - _osso(game.tripulacao[4], "pescoco")
	_assert("no centro da varredura o cadastro olha para vante: o rosto mira o −z do corpo",
		absf(olhar_frente.x) <= FOLGA and olhar_frente.z < -0.99,
		"olhar %0.4f,%0.4f,%0.4f" % [olhar_frente.x, olhar_frente.y, olhar_frente.z])
	# Sin(0,14 rad) = 0,1395: o teto não é gosto, é o seno do ângulo que `main.gd` escreve. E o
	# bordo é o +y do pescoço girando o −z do rosto para o −x do corpo — a asserção pede os dois
	# lados com sinais contrários, não um lado com sinal chutado por quem escreveu a sonda.
	var teto := sin(VARREDURA_CABECA)
	_assert("o oficial de pé varre o visor: o rosto aponta para um bordo e para o outro",
		olhar_um.x * olhar_dois.x < 0.0
			and absf(olhar_um.x) > 0.09 and absf(olhar_dois.x) > 0.09
			and absf(olhar_um.x) <= teto + FOLGA and absf(olhar_dois.x) <= teto + FOLGA,
		"x do olhar %0.4f -> %0.4f -> %0.4f, teto %0.4f" % [olhar_frente.x, olhar_um.x,
			olhar_dois.x, teto])
	_assert("varrer com o pescoço não empurra a cabeça pelo ar: o osso fica no eixo",
		cabeca_0.distance_to(cabeca_1) <= FOLGA and cabeca_0.distance_to(cabeca_2) <= FOLGA,
		"cabeça andou %0.6f m e %0.6f m sobre o próprio pescoço" % [
			cabeca_0.distance_to(cabeca_1), cabeca_0.distance_to(cabeca_2)])
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

	# ---- 5. Alarme: um flanco de estado, uma escrita na tela, um debruçar para vante ------------
	game.battle_clock = 0.0
	game.capital_hp = 100.0
	game._update_tripulacao()
	var tela: StandardMaterial3D = game.ponte_telas
	var peito_calma := _osso(game.tripulacao[0], "peito")
	var coluna_calma := _osso(game.tripulacao[0], "coluna")
	var de_pe_calma := _osso(game.tripulacao[4], "peito")
	_assert("com a capitânia inteira a tela é fria e ninguém se debruça",
		not bool(game.ponte_em_alarme)
			and (tela.emission as Color).is_equal_approx(COR_TELA_CALMA)
			and _igual(_angulo_coluna(game.tripulacao[0]), 0.0, 0.000001),
		"alarme=%s emissão=%s" % [game.ponte_em_alarme, str(tela.emission)])
	game.capital_hp = 40.0
	game.battle_clock = 3.0
	game._update_tripulacao()
	var peito_alarme := _osso(game.tripulacao[0], "peito")
	var de_pe_alarme := _osso(game.tripulacao[4], "peito")
	# Debruçar é conta, não gosto: girar a coluna de INCLINACAO_ALARME em torno do próprio eixo X
	# derruba o peito, que está PEITO_ACIMA acima da junta, para o −z da bancada.
	var esperado := -sin(INCLINACAO_ALARME) * PEITO_ACIMA
	var medido := peito_alarme.z - peito_calma.z
	_assert("casco ferido põe a tela em vermelho e o sentado debruçado sobre o teclado",
		bool(game.ponte_em_alarme) and (tela.emission as Color).is_equal_approx(COR_TELA_ALARME)
			and _igual(_angulo_coluna(game.tripulacao[0]), INCLINACAO_ALARME, 0.000001)
			and _igual(medido, esperado, 0.002),
		"peito z %0.4f -> %0.4f (a conta pedia %0.4f), coluna %0.3f rad, emissão=%s" % [
			peito_calma.z, peito_alarme.z, esperado, _angulo_coluna(game.tripulacao[0]),
			str(tela.emission)])
	_assert("o oficial de pé não larga a asa do visor para se debruçar",
		_igual(de_pe_alarme.z, de_pe_calma.z, 0.000001),
		"de pé z %0.5f contra %0.5f" % [de_pe_calma.z, de_pe_alarme.z])
	_assert("o debruçar puxa o peito para baixo da coluna, não para trás",
		peito_alarme.z < coluna_calma.z - 0.02,
		"coluna z %0.4f contra peito z %0.4f" % [coluna_calma.z, peito_alarme.z])
	var escritas := 0
	for i in range(50):
		var antes: Color = tela.emission
		game._update_tripulacao()
		if not (antes as Color).is_equal_approx(tela.emission):
			escritas += 1
	_assert("cinquenta quadros em alarme escrevem a cor zero vezes: só no flanco", escritas == 0,
		"%d escritas em 50 quadros" % escritas)
	game.capital_hp = 100.0
	game.battle_clock = 0.0
	game._update_tripulacao()
	_assert("reparado, o alarme desliga e o tronco volta à vertical",
		not bool(game.ponte_em_alarme) and (tela.emission as Color).is_equal_approx(COR_TELA_CALMA)
			and _igual(_angulo_coluna(game.tripulacao[0]), 0.0, 0.000001),
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
		game._chocar_com_barreiras()
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
