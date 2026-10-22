extends SceneTree

## Sonda dos cenários: a barreira que vale, o poço que engole, a estrela que aquece e o sistema que
## varre a linha.
##
## O pedido do comandante foi «diversas opções onde aplicas a estratégia», e opção falsa é a que
## existe só no painel. Então cada cenário é cobrado pela consequência que ele promete:
##
## 1) CINTURÃO: se a rocha não bloqueia lance, ela é decoração. A barreira tem de parar o tiro que
##    passa por dentro dela, e o preço de bater nela tem de cair no casco que bateu, não na pedra.
##    A prova central é esta: um lance absorvido muda o DANO e não muda o SORTEIO. Se bloquear
##    também pulasse o `rng.randf()` da retaliação, o cinturão seria um reroll disfarçado e toda a
##    cauda da batalha seguinte mudaria por acaso.
## 1b) CORRENTEZA (seções 3b a 3e): a pedra não é prego no mapa — ela deriva, muda de rumo ao se
##    chocar com a vizinha e racha em duas quando leva dano demais. As três contas são conferíveis
##    porque não sorteiam nada: o empuxo é função do `battle_clock` e da fase da pedra, o choque
##    troca só a componente normal da velocidade, e a fratura é geometria pura (raio × 0,62, eixo
##    perpendicular ao ângulo de chegada). A correnteza tem espelho reimplementado na sonda, quadro
##    a quadro, numa pedra SOZINHA longe das quinas — no cinto real as catorze pedras se acoplam e
##    um espelho exato seria reimplementar o tabuleiro. Do cinto real são cobradas as invariantes:
##    nenhuma pedra escapa da banda, nenhuma passa do teto de velocidade, nenhuma fica onde a
##    fórmula do leque a pôs, contato entre pedras DE FATO acontece, e o número de corpos e de
##    marcas fecha com o do leque.
##    FIXAÇÃO PELO CONSTRUTOR: rocha de teste nasce de `game._nova_rocha(...)`, nunca de um
##    dicionário artesanal. A sonda já injetou `{"no": null, "pos": ..., "raio": ...}` e o `main.gd`
##    pediu a chave `fase` no laço de deriva: a correnteza abortou no primeiro quadro, o cinturão
##    ficou congelado e TODAS as asserções do cinturão continuaram verdes — medida por ausência,
##    armadilha nº 1 com a cara da nº 7. O mesmo laço já pintou a marca em espaço errado: somava
##    `holo_root.position` em cima de `_holo_de(pos)` numa marca que é FILHA da mesa, e como nenhuma
##    asserção headless lê `marca.position`, o holograma sairia torto com o veredito verde. Hoje a
##    régua local é cobrada aqui e o corpo é cobrado em janela, em `tools/probes/fotograma.gd`.
##    E porque a pedra passou a ter integridade, o abalroamento também é conferido por ela: o casco
##    que bate perde 18,00 e a pedra não come um ponto de integridade — quem fere barreira é a salva.
## 2) POÇO: quem cruza o horizonte é perdido, e perdido sem pontos de vida intermediários — um poço
##    que fere devagar é uma parede com textura. O puxo, esse, tem de crescer conforme a aproximação
##    (é a única assinatura de gravidade conferível em três linhas), e destroço não volta a cair:
##    quem já afundou é marca no quadro, não corpo na correnteza.
## 2b) LENTE (seção 7b): o pedido de «se parecer com aquele do Interstellar» é visual, mas aqui é
##    cobrado por conta. A dobra empurra as estrelas de fundo para fora do raio de Einstein, então
##    a asserção que vale é a do céu: existia estrela DENTRO de 2E antes, não existe nenhuma depois,
##    as que saíram encostaram na casca de fora (o amontoado) e as que estavam fora da banda não
##    foram tocadas — transformação por transformação, não "alguma coisa mudou". O plano da lente é
##    cobrado de frente para o olho da ponte também a 210 u de bombordo: imagem lentificada é do
##    observador, não do mundo.
##    MEDIDOR, não medida: em headless o `MultiMesh.set_instance_transform` é descartado e a leitura
##    volta identidade, sem um erro sequer no log. A régua daqui é o espelho em RAM do jogo
##    (`estrelas_pintadas`). A pintura por amostra — disco, aro de fótons, arcos, e a conferência de
##    que o espelho bate com o MultiMesh — é cobrada em janela real, em `tools/probes/fotograma.gd`.
## 3) ESTRELA: calor de arma ≠ cozimento de casco. São dois raios diferentes, e a sonda confere que
##    quem está entre eles só ganha o multiplicador.
##
## E a margem que vale para os três: com o campo aberto nada disso existe. `rochas` vazio, nenhum
## ponto de perigo, `_fator_calor` devolvendo 1,0 em qualquer coordenada. É por isso que a inércia
## não é uma promessa de design, é a primeira família de asserções desta sonda.
##
## O painel também é cobrado: o sétimo grupo existe, os cinco botões executam por `pressed`, trocar
## de cenário desmonta o anterior (rocha dobrada empurraria o casco duas vezes no mesmo quadro) e a
## mesa holográfica mostra a barreira onde mostra os cascos — sem nunca virar blip de casco. A
## quinta opção (SISTEMA) tem a própria sonda, `tools/probes/sistema.gd`; daqui ela é cobrada só
## como painel e como desmonte: o botão existe, clicar acende a flag e trocar apaga tudo.
##
## Uso: godot --headless --path . --quit-after 1800 -s res://tools/probes/cenarios.gd

## Espelho das constantes de `main.gd` — a instância do jogo é não tipada (mesmo motivo em
## `tools/probes/menu.gd`). Se o número aqui divergir do código, a asserção quebra: é de propósito.
const MAP_X := 320.0
const MAP_Y := 180.0
const MAP_Z_NEAR := 40.0
const MAP_Z_FAR := -600.0
const HULL_RADIUS := 2.4
const CAPITAL_RADIUS := 6.0
const RAM_SPEED := 3.0
const RAM_WINDOW := 1.5
const ROCHA_QTDE := 14
const ROCHA_RAIO_BASE := 3.2
const ROCHA_RAIO_DEGRAU := 0.9
const ROCHA_LEQUE_X := 58.0
const ROCHA_Z_INICIAL := -24.0
const ROCHA_Z_PASSO := 4.0
const ROCHA_Y_LEQUE := 13.0
## Espelho da correnteza (#125): deriva, empuxo errático, teto, banda e preço da fratura.
const ROCHA_DERIVA := 2.4
const ROCHA_ERRATICIDADE := 0.9
const ROCHA_TAXA_ERRATICA := 0.35
const ROCHA_VETO_TETO := 4.2
const ROCHA_BANDA_X := 78.0
const ROCHA_BANDA_Y := 18.0
const ROCHA_BANDA_Z_FRENTE := -16.0
const ROCHA_BANDA_Z_FUNDO := -84.0
const ROCHA_INTEGRIDADE_POR_RAIO := 6.0
const ROCHA_FILHA_FRAC := 0.62
const ROCHA_FILHA_MIN := 1.6
const ROCHA_GERACAO_MAXIMA := 2
const ROCHA_LIMITE_CORPOS := 40
const POCO_POS := Vector3(0.0, 0.0, -78.0)
const POCO_ALCANCE := 46.0
const POCO_HORIZONTE := 9.0
const POCO_ANEL_FOTON := 1.08
const POCO_DISCO_INTERNO := 1.55
const POCO_DISCO_EXTERNO := 3.80
const POCO_DISCO_FAIXAS := 3
const POCO_DISCO_AMOSTRAS := 44
const POCO_DISCO_INCLINACAO := 0.17
const POCO_ARCO_ALTO := 1.24
const POCO_ARCO_BAIXO := 1.06
const POCO_ARCO_AMOSTRAS := 40
const POCO_ARCO_LARGO := 3.10
const POCO_DOPPLER := 0.45
const POCO_LENTE_EINSTEIN := 0.16
const POCO_LENTE_FLEXAO_TETO := 2.0
const POCO_LENTE_BANDA := 3.0
const ESTRELA_POS := Vector3(0.0, 24.0, -74.0)
const ESTRELA_CALOR_RAIO := 70.0
const ESTRELA_CALOR_FATOR := 1.25
const ESTRELA_CORONA_RAIO := 30.0
const ESTRELA_QUEIMA := 6.0
const PASSO := 0.1
const NOMES_GRUPOS := ["ATAQUE", "POSTURA", "FORMAÇÕES", "MANOBRA", "REPAROS", "RECONHECIMENTO",
	"CENÁRIO", "TRILHA"]
const NOMES_CENARIO := ["ABERTO", "CINTURAO", "POCO", "ESTRELA", "SISTEMA"]

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

## Só a linha hostil: é a saída da salva aliada, e medir os dois lados juntos deixaria a
## retaliação hostil — que também sente o calor — dentro da mesma régua.
func _hostis_somados(game) -> float:
	var total := 0.0
	for unit in game.enemies:
		total += float(unit["hp"])
	return total

func _botoes(game, nome: String) -> Array[Button]:
	var lista: Array[Button] = []
	var corpo: Control = game.group_bodies[nome]
	for filho in corpo.get_children():
		if filho is Button:
			lista.append(filho as Button)
	return lista

## A rocha do cinturão, na fórmula de `main.gd` — conferida posição a posição, não "alguma pedra
## existe". Um `ang` trocado no laço mudaria o mapa inteiro sem dar erro.
func _posicao_esperada(i: int) -> Dictionary:
	var ang := float(i) * 2.39996
	var x := cos(ang) * ROCHA_LEQUE_X * (0.35 + 0.13 * float(i % 5))
	var y := sin(ang * 1.7) * ROCHA_Y_LEQUE
	var z := ROCHA_Z_INICIAL - float(i) * ROCHA_Z_PASSO
	return {"pos": Vector3(x, y, z), "raio": ROCHA_RAIO_BASE + float(i % 4) * ROCHA_RAIO_DEGRAU}

## A mesma linha de `_montar_cinturao()` para a velocidade de largada: direção no ângulo áureo do
## índice e módulo escalonado. É o espelho que prova que a correnteza nasce de fórmula, não de
## sorteio — se o `0.6` ou o `0.9` do código mudarem, a asserção quebra junto.
func _velocidade_esperada(i: int) -> Vector3:
	var ang := float(i) * 2.39996
	return Vector3(cos(ang * 0.6 + 1.1), sin(ang * 0.9) * 0.35, sin(ang * 0.6 + 1.1)) \
		* ROCHA_DERIVA * (0.55 + 0.15 * float(i % 4))

## A correnteza de `main.gd` reimplementada quadro a quadro: empuxo senoidal no relógio da batalha,
## teto de velocidade, integração de Euler e quina de banda nas três coordenadas. Ordem das contas
## é a do código, de propósito — inverter clamp e integração daria um espelho que aprova um bug.
func _deriva_esperada(pos: Vector3, vel: Vector3, fase: float, relogios: Array,
		dt: float) -> Dictionary:
	var p := pos
	var v := vel
	var toques := 0
	var xmax := absf(p.x)
	var ymax := absf(p.y)
	var zmin := p.z
	var zmax := p.z
	for bruto in relogios:
		var relogio := float(bruto) * ROCHA_TAXA_ERRATICA + fase
		var empuxo := Vector3(sin(relogio), sin(relogio * 1.7) * 0.4, cos(relogio * 0.8)) \
			* ROCHA_ERRATICIDADE
		v = v + empuxo * dt
		if v.length() > ROCHA_VETO_TETO:
			v = v.normalized() * ROCHA_VETO_TETO
		p = p + v * dt
		if p.x < -ROCHA_BANDA_X or p.x > ROCHA_BANDA_X:
			v.x = -v.x
			p.x = clampf(p.x, -ROCHA_BANDA_X, ROCHA_BANDA_X)
			toques += 1
		if p.y < -ROCHA_BANDA_Y or p.y > ROCHA_BANDA_Y:
			v.y = -v.y
			p.y = clampf(p.y, -ROCHA_BANDA_Y, ROCHA_BANDA_Y)
			toques += 1
		if p.z < ROCHA_BANDA_Z_FUNDO or p.z > ROCHA_BANDA_Z_FRENTE:
			v.z = -v.z
			p.z = clampf(p.z, ROCHA_BANDA_Z_FUNDO, ROCHA_BANDA_Z_FRENTE)
			toques += 1
		xmax = maxf(xmax, absf(p.x))
		ymax = maxf(ymax, absf(p.y))
		zmin = minf(zmin, p.z)
		zmax = maxf(zmax, p.z)
	return {"pos": p, "vel": v, "toques": toques, "xmax": xmax, "ymax": ymax,
		"zmin": zmin, "zmax": zmax}

## invariantes de contato: com o quadro fechado, nenhuma pedra pode estar dentro da soma de raios
## de outra. É a mesma régua do "sem sobreposição" dos cascos, aplicada ao cinturão.
func _sem_sobreposicao(game) -> bool:
	for i in range(game.rochas.size()):
		for j in range(i + 1, game.rochas.size()):
			var pa: Vector3 = game.rochas[i]["pos"]
			var pb: Vector3 = game.rochas[j]["pos"]
			if pa.distance_to(pb) < float(game.rochas[i]["raio"]) + float(game.rochas[j]["raio"]) - 0.0001:
				return false
	return true

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _montar_jogo() -> Node3D:
	var game: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	await _frames(3)
	return game

func _initialize() -> void:
	var game: Node3D = await _montar_jogo()
	_alinhar(game)
	_zerar(game)

	# ---- 1. O padrão é a ausência: campo aberto não tem cenário nenhum ----------------------
	_assert("a ponte abre em campo aberto", String(game.cenario_atual) == "ABERTO"
		and int(game.rochas.size()) == 0 and int(game.astros.size()) == 0
		and bool(game.poco_ativo) == false and bool(game.estrela_ativa) == false
		and bool(game.planeta_ativa) == false,
		"cenario=%s rochas=%d astros=%d poco=%s estrela=%s planeta=%s" % [game.cenario_atual,
			game.rochas.size(), game.astros.size(), game.poco_ativo, game.estrela_ativa,
			game.planeta_ativa])
	var calor_fora: float = game._fator_calor(POCO_POS)
	var calor_dentro: float = game._fator_calor(ESTRELA_POS)
	_assert("sem estrela o multiplicador é 1,0 em qualquer ponto do campo",
		_igual(float(calor_fora), 1.0, 0.000001) and _igual(float(calor_dentro), 1.0, 0.000001),
		"1,000 na boca do poço e 1,000 na fotosfera")
	_assert("sem rocha nenhum corredor é bloqueado",
		game._barreira_entre(Vector3(0, 0, -38), Vector3(0, 0, -82)).is_empty(),
		"%d rochas na conta" % game.rochas.size())
	_assert("a nota do campo aberto diz que não há nada no mapa",
		String(game._nota_cenario()).contains("nenhuma barreira"), game._nota_cenario())
	_assert("duzentas chamadas de cenário em campo aberto não movem um dígito",
		_prova_inercia(game), "rng e visual_rng intactos sob ABERTO")

	# ---- 2. O mapa é grande de verdade -------------------------------------------------------
	game.bridge_rig.position = Vector3(900.0, 900.0, -900.0)
	game._update_capital_ship(0.1)
	_assert("o campo novo fecha em x 320 / y 180 / z -600",
		_igual(game.bridge_rig.position.x, MAP_X, 0.0001)
			and _igual(game.bridge_rig.position.y, MAP_Y, 0.0001)
			and _igual(game.bridge_rig.position.z, MAP_Z_FAR, 0.0001),
		"x %0.2f y %0.2f z %0.2f" % [game.bridge_rig.position.x, game.bridge_rig.position.y,
			game.bridge_rig.position.z])
	game.bridge_rig.position = Vector3.ZERO
	_assert("o limite é mar de manobra, não vitrine: a banda de batalha cabe três vezes",
		absf(MAP_Z_FAR - MAP_Z_NEAR) > 3.0 * absf(-92.0 - MAP_Z_NEAR),
		"de %0.0f a %0.0f de ré contra 52 u de banda de batalha" % [MAP_Z_NEAR, MAP_Z_FAR])

	# ---- 3. Cinturão: a pedra é um lugar, não uma lista --------------------------------------
	var visual_antes: int = game.visual_rng.state
	game._montar_cenario("CINTURAO")
	_assert("montar o cinturão não sorteia um pixel",
		int(game.visual_rng.state) == visual_antes,
		"visual_rng %d -> %d" % [visual_antes, game.visual_rng.state])
	_assert("o cinturão tem catorze rochas", int(game.rochas.size()) == ROCHA_QTDE,
		"%d rochas" % game.rochas.size())
	var desencontros := ""
	for i in range(ROCHA_QTDE):
		var esperado := _posicao_esperada(i)
		var medida: Dictionary = game.rochas[i]
		var dp: Vector3 = esperado["pos"]
		var mp: Vector3 = medida["pos"]
		if not _igual(dp.x, mp.x, 0.0001) or not _igual(dp.y, mp.y, 0.0001) \
				or not _igual(dp.z, mp.z, 0.0001) \
				or not _igual(float(esperado["raio"]), float(medida["raio"]), 0.0001):
			desencontros += "%d " % i
	_assert("cada rocha está no lugar e do tamanho da fórmula", desencontros == "",
		"fora do esperado: [%s]" % desencontros)
	var faixa_z := ""
	var minimo_z := INF
	var maximo_z := -INF
	for rocha in game.rochas:
		minimo_z = minf(minimo_z, (rocha["pos"] as Vector3).z)
		maximo_z = maxf(maximo_z, (rocha["pos"] as Vector3).z)
	faixa_z = "%0.0f a %0.0f" % [maximo_z, minimo_z]
	_assert("a barreira veste o corredor entre as duas linhas",
		_igual(maximo_z, ROCHA_Z_INICIAL, 0.0001) and minimo_z < -70.0,
		"z da frente %s — aliada em -38, hostil em -82" % faixa_z)
	var raios := ""
	for i in range(4):
		raios += "%0.1f " % float(game.rochas[i]["raio"])
	_assert("o raio de casco da rocha entra na conta de separação",
		_igual(float(game.rochas[0]["raio"]), ROCHA_RAIO_BASE, 0.0001)
			and float(game.rochas[3]["raio"]) > float(game.rochas[0]["raio"]),
		"quatro primeiros raios: %s" % raios)
	var velocidades_fora := ""
	for i in range(ROCHA_QTDE):
		var medida_v: Vector3 = game.rochas[i]["vel"]
		if medida_v.distance_to(_velocidade_esperada(i)) > 0.0001:
			velocidades_fora += "%d " % i
	_assert("a velocidade de cada pedra vem da fórmula do leque, não de sorteio",
		velocidades_fora == "", "fora do espelho de largada: [%s]" % velocidades_fora)

	# ---- 3b. A pedra SOZINHA segue a integral espelhada do empuxo -----------------------------
	# O espelho fino mora aqui, numa pedra isolada: no cinto real as catorze se acoplam pelo choque
	# e um espelho exato seria reimplementar o tabuleiro inteiro. O empuxo não depende da posição,
	# só do relógio e da fase — então a trajetória é uma conta conferível passo a passo.
	game._desmontar_cenario()
	var clock_antes: float = float(game.battle_clock)
	var p0: Vector3 = _posicao_esperada(0)["pos"]
	var v0: Vector3 = _velocidade_esperada(0)
	var relogios: Array = []
	for s in range(40):
		relogios.append(clock_antes + float(s + 1) * PASSO)
	var espelho: Dictionary = _deriva_esperada(p0, v0, 0.0, relogios, PASSO)
	var pedra: Dictionary = game._nova_rocha(p0, float(_posicao_esperada(0)["raio"]), v0, 0, 0.0)
	for s in range(40):
		game.battle_clock = clock_antes + float(s + 1) * PASSO
		game._derivar_rochas(PASSO)
	var mp: Vector3 = pedra["pos"]
	var mv: Vector3 = pedra["vel"]
	var ep: Vector3 = espelho["pos"]
	var ev: Vector3 = espelho["vel"]
	_assert("a deriva é a integral espelhada do empuxo, posição e velocidade conferidas",
		_igual(mp.x, ep.x, 0.0005) and _igual(mp.y, ep.y, 0.0005) and _igual(mp.z, ep.z, 0.0005)
			and _igual(mv.x, ev.x, 0.0005) and _igual(mv.y, ev.y, 0.0005)
			and _igual(mv.z, ev.z, 0.0005),
		"40 passos de %0.1f s: %s contra %s; quinas tocadas %d, |x|max %0.1f, |y|max %0.1f, z %0.1f..%0.1f"
			% [PASSO, str(mp), str(ep), int(espelho["toques"]), float(espelho["xmax"]),
				float(espelho["ymax"]), float(espelho["zmin"]), float(espelho["zmax"])])
	_assert("a pedra andou de verdade: correnteza pintada não passa aqui",
		p0.distance_to(mp) > 1.0, "%0.2f u de percurso em 4 s" % p0.distance_to(mp))
	game.battle_clock = clock_antes

	# ---- 3c. O cinto real: sessenta segundos de mar, sem sorteio e sem fuga ---------------------
	game._montar_cenario("CINTURAO")
	var rng_mar: int = game.rng.state
	var visual_mar: int = game.visual_rng.state
	var clock_mar: float = float(game.battle_clock)
	var partida: Array = []
	for i in range(ROCHA_QTDE):
		partida.append(game.rochas[i]["pos"])
	var contatos := 0
	var passos := 600
	for s in range(passos):
		# Contato medido ANTES da resolução: depois, a própria conta já desempilhou as duas e a
		# asserção viraria "existe pedra" sem nunca ver o choque acontecer.
		for i in range(game.rochas.size()):
			for j in range(i + 1, game.rochas.size()):
				var pa: Vector3 = game.rochas[i]["pos"]
				var pb: Vector3 = game.rochas[j]["pos"]
				if pa.distance_to(pb) < float(game.rochas[i]["raio"]) + float(game.rochas[j]["raio"]):
					contatos += 1
		game.battle_clock = clock_mar + float(s + 1) * PASSO
		game._derivar_rochas(PASSO)
	game.battle_clock = clock_mar
	var fora_da_banda := 0
	var acima_do_teto := 0
	var paradas := 0
	var corpo_fora := 0
	var marca_fora := 0
	var giradas := 0
	for i in range(game.rochas.size()):
		var rocha: Dictionary = game.rochas[i]
		var pos: Vector3 = rocha["pos"]
		var vel: Vector3 = rocha["vel"]
		if absf(pos.x) > ROCHA_BANDA_X + 0.001 or absf(pos.y) > ROCHA_BANDA_Y + 0.001 \
				or pos.z < ROCHA_BANDA_Z_FUNDO - 0.001 or pos.z > ROCHA_BANDA_Z_FRENTE + 0.001:
			fora_da_banda += 1
		if vel.length() > ROCHA_VETO_TETO + 0.001:
			acima_do_teto += 1
		if (partida[i] as Vector3).distance_to(pos) < 0.5:
			paradas += 1
		if _velocidade_esperada(i).normalized().dot(vel.normalized()) > 0.999:
			giradas += 1
		var nodo: Node3D = rocha["no"]
		if not is_instance_valid(nodo) or nodo.global_position.distance_to(pos) > 0.001:
			corpo_fora += 1
		var marca: MeshInstance3D = rocha["marca"]
		if not is_instance_valid(marca):
			marca_fora += 1
		elif marca.position.distance_to(game._holo_de(pos)) > 0.001:
			marca_fora += 1
	_assert("a deriva não sorteia um dígito em sessenta segundos de mar",
		int(game.rng.state) == rng_mar and int(game.visual_rng.state) == visual_mar,
		"rng %d e visual %d intactos sob %d quadros" % [rng_mar, visual_mar, passos])
	_assert("o cinturão é barreira, não nuvem que dissolve: nenhuma pedra escapou da banda",
		fora_da_banda == 0, "%d de %d fora de |x| %0.0f, |y| %0.0f, z %0.0f..%0.0f" % [
			fora_da_banda, game.rochas.size(), ROCHA_BANDA_X, ROCHA_BANDA_Y,
			ROCHA_BANDA_Z_FUNDO, ROCHA_BANDA_Z_FRENTE])
	_assert("a correnteza tem teto de velocidade", acima_do_teto == 0,
		"%d pedras acima de %0.1f u/s" % [acima_do_teto, ROCHA_VETO_TETO])
	_assert("toda pedra saiu do ponto onde a fórmula do leque a pôs", paradas == 0,
		"%d de %d ainda na origem" % [paradas, game.rochas.size()])
	_assert("a correnteza muda o rumo de todas as pedras", giradas == 0,
		"%d de %d ainda na direção de largada" % [giradas, game.rochas.size()])
	_assert("o nó pintado na cena acompanha o dicionário, e a marca da mesa também",
		corpo_fora == 0 and marca_fora == 0,
		"%d corpos e %d marcas fora do lugar" % [corpo_fora, marca_fora])
	_assert("pedra com pedra acontece de verdade no cinturão", contatos > 0,
		"%d quadros com sobreposição pendente em %d" % [contatos, passos])
	_assert("nenhuma pedra sobrepõe outra quando o quadro fecha", _sem_sobreposicao(game),
		"todas as pares conferidas depois de %d quadros" % passos)
	_assert("deriva não cria nem destrói corpo nem marca",
		game.rochas.size() == ROCHA_QTDE and game.holo_cenario.size() == ROCHA_QTDE,
		"%d rochas e %d marcas" % [game.rochas.size(), game.holo_cenario.size()])

	# ---- 3d. Choque pedra com pedra: troca só a normal, a tangencial sobrevive ------------------
	# Lei conferida em tabuleiro de duas pedras, chamada direto em `_peder_rochas`: é o único jeito
	# de isolar o impulso dos empuxos que a integração do quadro misturaria na mesma conta.
	game._desmontar_cenario()
	var irma_a: Dictionary = game._nova_rocha(Vector3(-1.0, 5.0, -40.0), 2.0, Vector3(3.0, 1.0, 0.0), 0, 0.0)
	var irma_b: Dictionary = game._nova_rocha(Vector3(1.0, 5.0, -40.0), 2.0, Vector3(-3.0, 1.0, 0.0), 0, 0.0)
	game._peder_rochas()
	var va_a: Vector3 = irma_a["vel"]
	var va_b: Vector3 = irma_b["vel"]
	var sep_a: Vector3 = irma_a["pos"]
	var sep_b: Vector3 = irma_b["pos"]
	_assert("o choque desempilha as duas na hora: sobreposição vira separação",
		sep_a.distance_to(sep_b) >= 4.0 - 0.0001, "a %0.3f u, soma de raios 4,0"
			% sep_a.distance_to(sep_b))
	_assert("pedras iguais trocam a componente normal por inteiro",
		_igual(va_a.x, -3.0, 0.0001) and _igual(va_b.x, 3.0, 0.0001),
		"normal +3,0 -> %0.3f e -3,0 -> %0.3f" % [va_a.x, va_b.x])
	_assert("asteroide não tem freio: a tangencial sobrevive intacta",
		_igual(va_a.y, 1.0, 0.0001) and _igual(va_b.y, 1.0, 0.0001) and _igual(va_a.z, 0.0, 0.0001)
			and _igual(va_b.z, 0.0, 0.0001),
		"tangencial %0.3f e %0.3f, as duas no eixo y" % [va_a.y, va_b.y])
	game._desmontar_cenario()
	var grande: Dictionary = game._nova_rocha(Vector3(-2.0, 5.0, -40.0), 4.0, Vector3(2.0, 0.0, 0.0), 0, 0.0)
	var miuda: Dictionary = game._nova_rocha(Vector3(2.0, 5.0, -40.0), 1.0, Vector3.ZERO, 0, 0.0)
	game._peder_rochas()
	var vg: Vector3 = grande["vel"]
	var vm: Vector3 = miuda["vel"]
	# ma = 16, mb = 1, aproxima = -2 → a grande perde 4/17 = 0,2353 u/s e a miúda leva 64/17 = 3,7647.
	_assert("pedra grande não sai voando porque uma miúda encostou nela",
		_igual(vg.x, 30.0 / 17.0, 0.0001) and _igual(vm.x, 64.0 / 17.0, 0.0001)
			and _igual(vm.x - vg.x, 2.0, 0.0001),
		"a grande em %0.4f e a miúda em %0.4f: a velocidade de aproximação inverte exata"
			% [vg.x, vm.x])
	game._desmontar_cenario()
	var foge_a: Dictionary = game._nova_rocha(Vector3(-1.0, 5.0, -40.0), 2.0, Vector3(-5.0, 0.0, 0.0), 0, 0.0)
	var foge_b: Dictionary = game._nova_rocha(Vector3(1.0, 5.0, -40.0), 2.0, Vector3(5.0, 0.0, 0.0), 0, 0.0)
	game._peder_rochas()
	var fv_a: Vector3 = foge_a["vel"]
	var fv_b: Vector3 = foge_b["vel"]
	var fp_a: Vector3 = foge_a["pos"]
	var fp_b: Vector3 = foge_b["pos"]
	_assert("encostadas mas se afastando: só separa, não bomba velocidade do nada",
		_igual(fv_a.x, -5.0, 0.0001) and _igual(fv_b.x, 5.0, 0.0001)
			and fp_a.distance_to(fp_b) >= 4.0 - 0.0001,
		"%0.3f / %0.3f intactos e %0.3f u apartadas" % [fv_a.x, fv_b.x, fp_a.distance_to(fp_b)])

	# ---- 3e. Fratura: o lance cobrado em integridade, e a pedra vira duas ------------------------
	game._desmontar_cenario()
	var rng_fratura: int = game.rng.state
	var visual_fratura: int = game.visual_rng.state
	var mae: Dictionary = game._nova_rocha(Vector3(0.0, 0.0, -50.0), ROCHA_RAIO_BASE, Vector3.ZERO, 0, 0.0)
	var integridade_mae := float(mae["integridade"])
	_assert("a integridade nasce do raio: 6,0 por unidade de pedra",
		_igual(integridade_mae, ROCHA_RAIO_BASE * ROCHA_INTEGRIDADE_POR_RAIO, 0.0001),
		"pedra de %0.1f u entra com %0.1f de integridade" % [ROCHA_RAIO_BASE, integridade_mae])
	var aguentou: bool = game._fraturar_rocha(mae, 5.0, Vector3(0.0, 0.0, -20.0))
	_assert("metade do preço não parte nada: a pedra continua uma e do mesmo tamanho",
		not aguentou and game.rochas.size() == 1 and game.holo_cenario.size() == 1
			and _igual(float(mae["integridade"]), integridade_mae - 5.0, 0.0001)
			and _igual(float(mae["raio"]), ROCHA_RAIO_BASE, 0.0001),
		"integridade %0.1f -> %0.1f com %d corpos" % [integridade_mae, float(mae["integridade"]),
			game.rochas.size()])
	var rachou: bool = game._fraturar_rocha(mae, 999.0, Vector3(0.0, 0.0, -20.0))
	_assert("fechado o preço, a pedra racha em duas e a matriz sai do tabuleiro",
		rachou and game.rochas.size() == 2, "%d corpos no lugar da matriz" % game.rochas.size())
	if game.rochas.size() == 2:
		var f1: Dictionary = game.rochas[0]
		var f2: Dictionary = game.rochas[1]
		var meio_f: Vector3 = ((f1["pos"] as Vector3) + (f2["pos"] as Vector3)) * 0.5
		var linha: Vector3 = (f2["pos"] as Vector3) - (f1["pos"] as Vector3)
		var dir_chegada: Vector3 = (Vector3(0.0, 0.0, -50.0) - Vector3(0.0, 0.0, -20.0)).normalized()
		var raio_f := ROCHA_RAIO_BASE * ROCHA_FILHA_FRAC
		_assert("cada filha tem o raio da conta e a integridade que o raio manda",
			_igual(float(f1["raio"]), raio_f, 0.0001) and _igual(float(f2["raio"]), raio_f, 0.0001)
				and _igual(float(f1["integridade"]), raio_f * ROCHA_INTEGRIDADE_POR_RAIO, 0.0001)
				and int(f1["geracao"]) == 1 and int(f2["geracao"]) == 1,
			"filhas de %0.3f u (%0.1f de integridade, geração 1) contra matriz de %0.1f u"
				% [raio_f, raio_f * ROCHA_INTEGRIDADE_POR_RAIO, ROCHA_RAIO_BASE])
		_assert("as filhas nascem simétricas no centro da matriz e apartadas pelo raio dela",
			_igual(meio_f.x, 0.0, 0.0001) and _igual(meio_f.y, 0.0, 0.0001)
				and _igual(meio_f.z, -50.0, 0.0001)
				and _igual(linha.length(), ROCHA_RAIO_BASE, 0.0001),
			"meio em %s, corda de %0.3f u" % [str(meio_f), linha.length()])
		_assert("a rachadura abre perpendicular ao tiro: eixo sem componente na direção chegada",
			absf(linha.normalized().dot(dir_chegada)) < 0.0001,
			"cosseno %0.6f entre a corda das filhas e a linha do lance"
				% absf(linha.normalized().dot(dir_chegada)))
		_assert("cada metade sai empurrada para fora pela conta de separação",
			_igual(((f2["vel"] as Vector3) - (f1["vel"] as Vector3)).length(), ROCHA_DERIVA, 0.0001)
				and ((f1["vel"] as Vector3) + (f2["vel"] as Vector3)).length() < 0.0001,
			"afastamento de %0.3f u/s entre as duas, centro de massa parado"
				% ((f2["vel"] as Vector3) - (f1["vel"] as Vector3)).length())
		_assert("rachar pinta corpo e marca juntos: a mesa não fica com pedra fantasma",
			game.holo_cenario.size() == game.rochas.size()
				and is_instance_valid(f1["no"]) and is_instance_valid(f2["no"])
				and is_instance_valid(f1["marca"]) and is_instance_valid(f2["marca"]),
			"%d corpos e %d marcas na mesa" % [game.rochas.size(), game.holo_cenario.size()])
	game._desmontar_cenario()
	var velha: Dictionary = game._nova_rocha(Vector3(0.0, 0.0, -50.0), ROCHA_RAIO_BASE, Vector3.ZERO,
		ROCHA_GERACAO_MAXIMA, 0.0)
	var esmiucada: bool = game._fraturar_rocha(velha, 999.0, Vector3(0.0, 0.0, -20.0))
	_assert("no teto de geração a pedra esmiúça em vez de rachar",
		esmiucada and game.rochas.is_empty() and game.holo_cenario.is_empty(),
		"geração %d morreu com %d corpos e %d marcas no tabuleiro" % [ROCHA_GERACAO_MAXIMA,
			game.rochas.size(), game.holo_cenario.size()])
	game._desmontar_cenario()
	var nanica: Dictionary = game._nova_rocha(Vector3(0.0, 0.0, -50.0), 2.4, Vector3.ZERO, 0, 0.0)
	var virou_po: bool = game._fraturar_rocha(nanica, 999.0, Vector3(0.0, 0.0, -20.0))
	_assert("filha abaixo do raio mínimo não nasce: 2,4 u esmiúça em vez de parir pó",
		virou_po and game.rochas.is_empty(),
		"raio filha seria %0.3f contra o piso de %0.1f u" % [2.4 * ROCHA_FILHA_FRAC, ROCHA_FILHA_MIN])
	game._desmontar_cenario()
	var cheia: Array = []
	for i in range(ROCHA_LIMITE_CORPOS):
		cheia.append(game._nova_rocha(Vector3(-70.0 + float(i % 8) * 20.0,
			-15.0 + (float(i) / 8.0) * 7.0, -20.0 - float(i) * 1.4), ROCHA_RAIO_BASE,
			Vector3.ZERO, 0, float(i)))
	var no_teto: bool = game._fraturar_rocha(cheia[0], 999.0, Vector3(0.0, 0.0, -20.0))
	_assert("no teto de corpos a pedra esmiúça: o limite segura a moagem do mapa",
		no_teto and game.rochas.size() == ROCHA_LIMITE_CORPOS - 1
			and game.holo_cenario.size() == ROCHA_LIMITE_CORPOS - 1,
		"%d corpos e %d marcas depois de matar um com %d em jogo" % [game.rochas.size(),
			game.holo_cenario.size(), ROCHA_LIMITE_CORPOS])
	game._desmontar_cenario()
	var no_mesmo: Dictionary = game._nova_rocha(Vector3(0.0, 0.0, -50.0), ROCHA_RAIO_BASE,
		Vector3.ZERO, 0, 0.0)
	var coincidiu: bool = game._fraturar_rocha(no_mesmo, 999.0, Vector3(0.0, 0.0, -50.0))
	var finitas: bool = coincidiu and int(game.rochas.size()) == 2
	for rocha in game.rochas:
		finitas = finitas and (rocha["pos"] as Vector3).is_finite()
	_assert("lance que chega exatamente no centro da pedra não divide por zero", finitas,
		"%d filhas com posição finita no eixo degenerado" % game.rochas.size())
	_assert("rachar não sorteia um dígito nem um pixel",
		int(game.rng.state) == rng_fratura and int(game.visual_rng.state) == visual_fratura,
		"rng %d e visual %d intactos em toda a família de fratura" % [rng_fratura, visual_fratura])
	game._desmontar_cenario()
	game.battle_clock = clock_antes

	# ---- 4. Barreira que vale: o lance morre na pedra ---------------------------------------
	# Pedra ISOLADA: no cinturão real outras rochas também cruzam este corredor, e a asserção
	# aprovaria pelo obstáculo errado — foi exatamente assim que a primeira rodada quebrou.
	var origem: Vector3 = (game.fleet[0]["node"] as Node3D).position
	var destino: Vector3 = (game.enemies[0]["node"] as Node3D).position
	var meio := (origem + destino) * 0.5
	game._desmontar_cenario()
	# Fixatura pelo construtor do jogo, não por dicionário artesanal: a pedra do `main.gd` tem
	# `vel`, `fase`, `id`, `integridade` e `geracao`, e uma cópia incompleta aqui congela a
	# correnteza no primeiro `_process` sem quebrar nenhuma asserção de lógica.
	game._nova_rocha(meio, ROCHA_RAIO_BASE, Vector3.ZERO, 0, 0.0)
	var corte: Dictionary = game._barreira_entre(origem, destino)
	_assert("rocha no corredor bloqueia o lance", not corte.is_empty(),
		"ponto de contato a %0.2f u do centro da pedra" % (corte["pos"] as Vector3).distance_to(meio))
	game.rochas[0]["pos"] = meio + Vector3(0.0, ROCHA_RAIO_BASE + 4.0, 0.0)
	_assert("corredor a 4 u por fora da pedra está limpo",
		game._barreira_entre(origem, destino).is_empty(),
		"centro deslocado %0.1f u para cima do eixo do tiro" % (ROCHA_RAIO_BASE + 4.0))
	game.rochas[0]["pos"] = meio + Vector3(0.0, ROCHA_RAIO_BASE - 0.1, 0.0)
	var roçando: bool = not game._barreira_entre(origem, destino).is_empty()
	game.rochas[0]["pos"] = meio + Vector3(0.0, ROCHA_RAIO_BASE + 0.1, 0.0)
	_assert("o corte obedece ao raio: 0,1 u dentro bloqueia, 0,1 u fora fura",
		roçando and game._barreira_entre(origem, destino).is_empty(),
		"a %0.1f e a %0.1f u do eixo, pedra de %0.1f u" % [ROCHA_RAIO_BASE - 0.1,
			ROCHA_RAIO_BASE + 0.1, ROCHA_RAIO_BASE])
	_assert("origem e destino no mesmo ponto não inventam barreira",
		game._barreira_entre(origem, origem).is_empty(), "trecho de comprimento zero")
	game._nova_rocha(meio, ROCHA_RAIO_BASE, Vector3.ZERO, 0, 1.0)
	_assert("a barreira mais próxima vence a mais longe",
		_mais_perto_vence(game, origem, destino), "dois bloqueios no mesmo corredor")

	# ---- 5. Bloquear dano não mexe no sorteio ------------------------------------------------
	var a := await _montar_jogo()
	_alinhar(a)
	_zerar(a)
	a.rng.seed = 909090
	var estado_a: int = a.rng.state
	var cascos_a := _cascos_somados(a)
	a._resolve_volley()
	var depois_a: int = a.rng.state
	var cascos_depois_a := _cascos_somados(a)
	var b := await _montar_jogo()
	_alinhar(b)
	_zerar(b)
	b._montar_cenario("CINTURAO")
	b._desmontar_cenario()
	b._nova_rocha(((b.fleet[0]["node"] as Node3D).position
		+ (b.enemies[0]["node"] as Node3D).position) * 0.5, 6.0, Vector3.ZERO, 0, 0.0)
	b.rng.seed = 909090
	var estado_b: int = b.rng.state
	var cascos_b := _cascos_somados(b)
	b._resolve_volley()
	var depois_b: int = b.rng.state
	var cascos_depois_b := _cascos_somados(b)
	_assert("os dois tabuleiros largam do mesmo estado de gerador",
		int(estado_a) == int(estado_b) and int(cascos_a) == int(cascos_b),
		"rng %d, cascos %.1f dos dois lados" % [estado_a, cascos_a])
	_assert("a pedra absorve o dano da salva", cascos_depois_b > cascos_depois_a + 0.001,
		"cascos %.1f com barreira contra %.1f sem" % [cascos_depois_b, cascos_depois_a])
	_assert("absorver dano não muda quantos sorteios a salva consome",
		int(depois_a) == int(depois_b), "rng %d -> %d, igual nos dois lados" % [estado_a, depois_a])
	_assert("a medida não foi feita em tabuleiro vazio",
		cascos_depois_a < cascos_a - 0.001, "ferimento real de %.1f de casco sem barreira" % (
			cascos_a - cascos_depois_a))
	a.queue_free()
	b.queue_free()
	await _frames(2)

		# ---- 5b. Cinto real na salva: absorve, racha e continua sem mexer no sorteio ----------------
	# A barreira agora cobra integridade e pode parir duas pedras no lugar de uma. Fratura é corpo
	# novo no tabuleiro, mas não é conta de sorteio: a cauda do `rng` tem de sair idêntica à do
	# controle que nunca viu pedra — senão rachar seria um reroll disfarçado.
	var m := await _montar_jogo()
	_alinhar(m)
	_zerar(m)
	m._montar_cenario("CINTURAO")
	m.rng.seed = 909090
	m._resolve_volley()
	var depois_m := int(m.rng.state)
	var feridos_m := cascos_a - _cascos_somados(m)
	_assert("com o cinturão inteiro no corredor a cauda do sorteio é a do controle",
		depois_m == int(depois_a), "rng %d -> %d, igual ao tabuleiro sem pedra" % [909090, depois_m])
	_assert("a barreira real absorve a salva, e o que passa dela continua machucando",
		feridos_m > 0.001 and _cascos_somados(m) > cascos_depois_a + 0.001,
		"%.1f de casco ferido com o cinto contra %.1f no campo aberto" % [
			feridos_m, cascos_a - cascos_depois_a])
	var geracoes_no_mapa := false
	var corpos_max: int = int(m.rochas.size())
	for v in range(60):
		_zerar(m)
		m.rng.seed = 909090
		m._resolve_volley()
		corpos_max = maxi(corpos_max, int(m.rochas.size()))
		for rocha in m.rochas:
			if int(rocha["geracao"]) > 0:
				geracoes_no_mapa = true
	_assert("sessenta salvas no cinturão racham pedra de verdade: nasceram filhas",
		corpos_max > ROCHA_QTDE and geracoes_no_mapa,
		"tabuleiro chegou a %d corpos contra %d do leque, e há geração > 0 no mapa" % [
			corpos_max, ROCHA_QTDE])
	_assert("a fratura respeita o teto de corpos e fecha com a mesa",
		corpos_max <= ROCHA_LIMITE_CORPOS and m.rochas.size() <= ROCHA_LIMITE_CORPOS
			and int(m.holo_cenario.size()) == int(m.rochas.size()),
		"máximo %d corpos, %d no fim e %d marcas na mesa" % [corpos_max, m.rochas.size(),
			m.holo_cenario.size()])
	# A conta da salva mora em `salva_resumo` (o `report_label` é do cenário e do alerta de perda, e
	# era lido aqui no lugar errado: provava o texto do mapa, não a conta da barreira).
	var conta_salva := String(m.salva_resumo)
	_assert("a ponte anuncia a conta do cinturão na fatura da salva",
		conta_salva.contains("cinturao:") and conta_salva.contains(
			"%d pedras" % int(m.rochas.size())), conta_salva)
	m.queue_free()
	await _frames(2)

	# ---- 6. Quem bate na pedra perde casco; a pedra não perde nada --------------------------
	game._montar_cenario("CINTURAO")
	_zerar(game)
	_alinhar(game)
	var rocha: Dictionary = game.rochas[0]
	var centro_rocha: Vector3 = rocha["pos"]
	var vitima: Dictionary = game.fleet[0]
	var nodo_vitima: Node3D = vitima["node"]
	nodo_vitima.position = centro_rocha + Vector3(0.0, 0.0, float(rocha["raio"]) - 1.0)
	vitima["veloc"] = Vector3(0.0, 0.0, -30.0)
	var pos_rocha_antes: Vector3 = (rocha["no"] as Node3D).position if rocha["no"] != null else Vector3.INF
	var integridade_antes := float(rocha["integridade"])
	game._chocar_com_barreiras()
	_assert("bater no cinturão cobra casco", float(vitima["hp"]) < 100.0,
		"%s: %0.2f de casco após o choque" % [vitima["name"], float(vitima["hp"])])
	_assert("a rocha não cede nem afofa", (rocha["no"] as Node3D).position == pos_rocha_antes
		and (rocha["no"] as Node3D).global_position.distance_to(centro_rocha) < 0.0001,
		"pedra continua em %s" % str(centro_rocha))
	# Desde a fratura a pedra tem um número que um abalroamento poderia comer. Não come: só a salva
	# fere barreira, e sem esta asserção o README continuaria dizendo "a pedra não perde nada" com a
	# integridade derretendo em silêncio a cada casco que encosta.
	_assert("o abalroamento não come integridade: quem fere a pedra é a salva, não a quina",
		_igual(float(rocha["integridade"]), integridade_antes, 0.0001),
		"integridade %0.1f -> %0.1f depois de um choque a 30 u/s" % [integridade_antes,
			float(rocha["integridade"])])
	_assert("o casco fica exatamente encostado na pedra",
		_igual(nodo_vitima.global_position.distance_to(centro_rocha),
			HULL_RADIUS + float(rocha["raio"]), 0.001),
		"%0.3f contra %0.3f de soma de raios" % [nodo_vitima.global_position.distance_to(centro_rocha),
			HULL_RADIUS + float(rocha["raio"])])
	var casco_depois := float(vitima["hp"])
	game._chocar_com_barreiras()
	_assert("o segundo contato na mesma janela não cobra de novo",
		_igual(float(vitima["hp"]), casco_depois, 0.0001),
		"%0.2f -> %0.2f dentro da janela de %0.1f s" % [casco_depois, float(vitima["hp"]),
			RAM_WINDOW])
	# A ponte é o único aliado que fere a própria frota; contra pedra, quem paga é ela também.
	# O empuxo tem de ser AO LONGO da normal (a ponte está acima da rocha): velocidade lateral
	# daria `aproximacao` zero e a asserção aprovaria um cenário onde nada encosta.
	game.bridge_rig.position = centro_rocha + Vector3(0.0, float(rocha["raio"]) - 1.0, 0.0)
	game.capital_velocity = Vector3(0.0, -40.0, 0.0)
	var capitania_antes := float(game.capital_hp)
	game._chocar_com_barreiras()
	_assert("a capitânia abrindo no cinturão perde casco",
		float(game.capital_hp) < capitania_antes, "%0.2f -> %0.2f" % [capitania_antes,
			game.capital_hp])
	game.capital_velocity = Vector3.ZERO

	# ---- 7. Poço: puxo que cresce e horizonte que não negocia --------------------------------
	game._montar_cenario("POCO")
	_zerar(game)
	_assert("o poço acende a flag e apaga o cinturão",
		bool(game.poco_ativo) and int(game.rochas.size()) == 0
			and String(game.cenario_atual) == "POCO",
		"poco=%s rochas=%d" % [game.poco_ativo, game.rochas.size()])
	var rng_antes: int = game.rng.state
	var longe := (game.fleet[0]["node"] as Node3D)
	longe.position = POCO_POS + Vector3(POCO_ALCANCE + 6.0, 0.0, 0.0)
	var antes_longe := longe.position
	game._puxar_para_o_poco(PASSO)
	_assert("fora do alcance o casco não sente nada", longe.position == antes_longe,
		"a %0.0f u do centro, puxo nenhum" % (POCO_ALCANCE + 6.0))
	var midway := (game.fleet[1]["node"] as Node3D)
	midway.position = POCO_POS + Vector3(30.0, 0.0, 0.0)
	var antes_mid := midway.position
	game._puxar_para_o_poco(PASSO)
	# Medir o passo de cada casco na CHAMADA que o move: no empurrão seguinte o casco de 30 u
	# anda de novo, e acumular os dois dava ao mais longe um passo maior que o do mais perto.
	var passo_mid := antes_mid.distance_to(midway.position)
	var perto := (game.fleet[2]["node"] as Node3D)
	perto.position = POCO_POS + Vector3(15.0, 0.0, 0.0)
	var antes_perto := perto.position
	game._puxar_para_o_poco(PASSO)
	var passo_perto := antes_perto.distance_to(perto.position)
	_assert("o puxo cresce conforme o casco se aproxima", passo_perto > passo_mid + 0.001,
		"%0.4f u a 15 contra %0.4f u a 30" % [passo_perto, passo_mid])
	_assert("puxado, o casco anda para dentro e não para o lado",
		midway.position.distance_to(POCO_POS) < 30.0 - 0.001,
		"30 -> %0.4f u do centro" % midway.position.distance_to(POCO_POS))
	_assert("o puxo não sorteia nada", int(game.rng.state) == rng_antes,
		"rng %d intacto em três empurrões" % rng_antes)
	var dentro := (game.fleet[3]["node"] as Node3D)
	var unidade_dentro: Dictionary = game.fleet[3]
	dentro.position = POCO_POS + Vector3(POCO_HORIZONTE - 1.0, 0.0, 0.0)
	game._puxar_para_o_poco(PASSO)
	_assert("quem cruza o horizonte é perdido, não ferido",
		_igual(float(unidade_dentro["hp"]), 0.0, 0.0001)
			and _igual(float(unidade_dentro["engines"]), 0.0, 0.0001)
			and String(game.report_label.text).begins_with("POÇO"),
		"hp %0.1f // %s" % [float(unidade_dentro["hp"]), game.report_label.text])
	var ancora := dentro.position
	game._puxar_para_o_poco(PASSO)
	_assert("destroço não volta a cair: quem afundou é marca, não corpo",
		dentro.position == ancora, "a %0.2f u do centro, parado" % dentro.position.distance_to(POCO_POS))
	# O hostil obedece à mesma conta: é isto que faz do poço uma arma e não um susto só da ponte.
	for enemy in game.enemies:
		(enemy["node"] as Node3D).position = POCO_POS + Vector3(POCO_HORIZONTE - 2.0, 0.0, 0.0)
	game._puxar_para_o_poco(PASSO)
	var hostis_vivos := 0
	for enemy in game.enemies:
		if float(enemy["hp"]) > 0.0 and String(enemy["order"]) != "CAPTURADO":
			hostis_vivos += 1
	_assert("a linha hostil cai no mesmo horizonte", hostis_vivos == 0,
		"%d hostis vivos depois da travessia" % hostis_vivos)
	game._resolve_volley()
	_assert("poço usado como arma fecha a batalha",
		String(game.report_label.text).contains("VITÓRIA"), game.report_label.text)
	# E a ponte, que é o jogador: perdida a capitânia, o relatório é o de sempre.
	var c := await _montar_jogo()
	_zerar(c)
	c._montar_cenario("POCO")
	c.bridge_rig.position = POCO_POS + Vector3(POCO_HORIZONTE - 3.0, 0.0, 0.0)
	c._puxar_para_o_poco(PASSO)
	_assert("a capitânia no horizonte derruba a ponte",
		_igual(float(c.capital_hp), 0.0, 0.0001) and String(c.report_label.text).contains("capitânia"),
		"casco da ponte %0.1f // %s" % [c.capital_hp, c.report_label.text])
	c._resolve_volley()
	_assert("sem ponte a salva declara derrota", String(c.report_label.text).begins_with("DERROTA"),
		c.report_label.text)
	c.queue_free()
	await _frames(2)

	# ---- 7b. A lente dobra o céu — e o céu tinha estrelas dentro dela -----------------------
	# O pedido é visual («que se pareça com aquele do Interstellar»), mas a conta é a mesma de
	# sempre: uma dobra que não esvazia o miolo do quadro é um círculo pintado. Então a prova não
	# é "existe um nó redondo": é que existe céu DENTRO do raio de Einstein antes, que depois da
	# conta não existe mais nenhum, e que o que saiu não sumiu — encostou na borda de fora.
	game._montar_cenario("POCO")
	_zerar(game)
	game.bridge_rig.position = Vector3.ZERO
	game.capital_velocity = Vector3.ZERO
	await _frames(1)
	var olho: Vector3 = game.ponte_camera.global_position
	# A régua é o espelho em RAM do jogo (`estrelas_pintadas`), não a leitura do MultiMesh: sob o
	# driver sem janela o `set_instance_transform` é DESCARTADO em silêncio e a leitura devolve
	# identidade, então uma sonda headless que lê o MultiMesh mede o instrumento morto, não o céu.
	# Conferido por A/B no mesmo script: headless lê (0,0,0), janela lê o valor escrito. A pintura
	# por amostra do disco e do arco é verificada em janela real, em `tools/probes/fotograma.gd`.
	var pintadas: Array = game.estrelas_pintadas
	var cruas_dentro := 0
	var cruas_banda := 0
	var casca_crua := 0
	for i in range(game.estrelas_base.size()):
		var sep := _separacao(olho, (game.estrelas_base[i] as Transform3D).origin)
		if sep < 2.0 * POCO_LENTE_EINSTEIN:
			cruas_dentro += 1
		if sep < POCO_LENTE_BANDA * POCO_LENTE_EINSTEIN:
			cruas_banda += 1
		if sep >= 2.0 * POCO_LENTE_EINSTEIN and sep < 2.5 * POCO_LENTE_EINSTEIN:
			casca_crua += 1
	_assert("o céu cru tem estrelas dentro do raio de Einstein", cruas_dentro > 0,
		("%d estrelas dentro de 2E antes de qualquer conta — sem isso a asserção de baixo "
		+ "seria verdadeira por ausência (armadilha nº 1)") % cruas_dentro)
	var rng_lente: int = game.rng.state
	var visual_lente: int = game.visual_rng.state
	var cascos_lente := _cascos_somados(game)
	game._aplicar_cenario(0.0)
	var dobradas := 0
	var dentro_depois := 0
	var casca_depois := 0
	var intocadas_fora := 0
	var intocadas := 0
	for i in range(game.estrelas_base.size()):
		var atual: Transform3D = pintadas[i]
		var base: Transform3D = game.estrelas_base[i]
		var sep := _separacao(olho, atual.origin)
		if atual != base:
			dobradas += 1
			if sep < 2.0 * POCO_LENTE_EINSTEIN:
				dentro_depois += 1
			if sep >= 2.0 * POCO_LENTE_EINSTEIN and sep < 2.5 * POCO_LENTE_EINSTEIN:
				casca_depois += 1
		else:
			intocadas += 1
			if _separacao(olho, base.origin) < POCO_LENTE_BANDA * POCO_LENTE_EINSTEIN:
				intocadas_fora += 1
	_assert("a lente dobrou exatamente as estrelas da banda, nem mais nem menos",
		int(game.estrelas_dobradas) == dobradas and dobradas == cruas_banda \
			and intocadas_fora == 0,
		("%d dobradas contra %d na banda; %d do lado de fora ficaram intocadas (a ponte lê "
		+ "%d no contador do painel)") % [dobradas, cruas_banda, intocadas_fora,
			game.estrelas_dobradas])
	_assert("o miolo fica vazio: nenhuma estrela termina dentro de 2E", dentro_depois == 0,
		"%d estrelas dentro do raio de Einstein depois da conta, contra %d antes" % [dentro_depois,
			cruas_dentro])
	_assert("o céu que saiu não sumiu, encostou na borda de fora", casca_depois > casca_crua,
		"%d estrelas na casca 2E..2,5E contra %d no céu cru" % [casca_depois, casca_crua])
	_assert("dobrar o céu não sorteia um dígito nem move um casco",
		int(game.rng.state) == rng_lente and int(game.visual_rng.state) == visual_lente \
			and _igual(_cascos_somados(game), cascos_lente, 0.0001),
		"rng %d e visual %d intactos, cascos %0.1f dos dois lados" % [game.rng.state,
			game.visual_rng.state, cascos_lente])
	_assert("a nota do poço anuncia a dobra com o número da conta",
		String(game._nota_cenario()).contains("céu atrás dele é dobrado")
			and String(game._nota_cenario()).contains("9 u"),
		game._nota_cenario())
	# Geometria pintada: a lente é um nó só, de frente para o olho da ponte. Medir a conta de
	# instâncias é o que pega o laço que aborta em runtime e deixa metade do arco fora do quadro
	# (armadilha nº 7 — a mesa holográfica inteira desapareceu assim).
	_assert("o poço pinta três nós: sombra, disco e arco",
		is_instance_valid(game.cenario_root) and int(game.cenario_root.get_child_count()) == 3
			and is_instance_valid(game.poco_disco) and is_instance_valid(game.poco_lente),
		"%d filhos em Cenario" % game.cenario_root.get_child_count())
	var disco_mm: MultiMesh = game.poco_disco.multimesh
	var arco_mm: MultiMesh = game.poco_lente.multimesh
	_assert("o disco e o arco têm a conta de amostras da tabela",
		int(disco_mm.instance_count) == POCO_DISCO_FAIXAS * POCO_DISCO_AMOSTRAS
			and int(arco_mm.instance_count) == POCO_ARCO_AMOSTRAS * 3,
		"%d amostras de disco e %d de arco" % [disco_mm.instance_count, arco_mm.instance_count])
	# O que não se mede aqui: a posição e o tom de cada uma das 252 amostras pintadas. Em headless a
	# escrita por instância não chega ao buffer e a leitura volta identidade — cobrar isto nesta sonda
	# seria reprovar o céu por causa do instrumento. `tools/probes/fotograma.gd` roda em janela, lê o
	# MultiMesh de verdade e confere disco, aro de fótons e os dois arcos amostra a amostra.
	var eixo_lente: Vector3 = (game.poco_lente as Node3D).global_transform.basis.z
	var para_olho := (olho - POCO_POS).normalized()
	_assert("o plano da lente encara o olho da ponte",
		absf(eixo_lente.dot(para_olho)) > 0.9999,
		"cosseno %0.5f entre a normal do arco e a linha de visada" % eixo_lente.dot(para_olho))
	# Voar para o lado é o que separa uma lente de um decal: a imagem lentificada é do observador.
	game.bridge_rig.position = Vector3(210.0, 60.0, -20.0)
	await _frames(1)
	var outro_olho: Vector3 = game.ponte_camera.global_position
	var eixo_de_lado: Vector3 = (game.poco_lente as Node3D).global_transform.basis.z
	var para_olho_de_lado := (outro_olho - POCO_POS).normalized()
	_assert("a lente gira com a ponte: 210 u a bombordo ela continua de frente",
		absf(eixo_de_lado.dot(para_olho_de_lado)) > 0.9999,
		"cosseno %0.5f no lado, %0.5f de proa" % [eixo_de_lado.dot(para_olho_de_lado),
			eixo_lente.dot(para_olho)])
	var dobradas_de_lado := int(game.estrelas_dobradas)
	_assert("mudar de lado muda quantas estrelas a lente pega", dobradas_de_lado != cruas_banda,
		"%d estrelas na banda vistas de 210 u a bombordo contra %d de proa" % [dobradas_de_lado,
			cruas_banda])
	game.bridge_rig.position = Vector3.ZERO
	await _frames(1)
	game._montar_cenario("ABERTO")
	var voltadas := 0
	for i in range(game.estrelas_base.size()):
		if pintadas[i] == game.estrelas_base[i]:
			voltadas += 1
	_assert("saiu o poço, volta o céu: estrela por estrela, sem reconstruir nada",
		voltadas == int(game.estrelas_base.size()) and int(game.estrelas_dobradas) == 0,
		"%d de %d transformadas no lugar de antes, contador %d" % [voltadas,
			game.estrelas_base.size(), game.estrelas_dobradas])

	# ---- 8. Estrela: dois raios, duas consequências ------------------------------------------
	game._montar_cenario("ESTRELA")
	_zerar(game)
	_assert("a estrela acende e o poço apaga", bool(game.estrela_ativa) and not bool(game.poco_ativo),
		"estrela=%s poco=%s" % [game.estrela_ativa, game.poco_ativo])
	_assert("dentro do raio de calor a arma bate 25% mais quente",
		_igual(float(game._fator_calor(ESTRELA_POS + Vector3(0, 0, 40))), ESTRELA_CALOR_FATOR, 0.000001),
		"a 40 u do disco: %0.2f" % game._fator_calor(ESTRELA_POS + Vector3(0, 0, 40)))
	_assert("fora do raio de calor o multiplicador é exatamente 1,0",
		_igual(float(game._fator_calor(ESTRELA_POS + Vector3(0, 0, ESTRELA_CALOR_RAIO + 30.0))),
			1.0, 0.000001),
		"a %0.0f u: 1,00" % (ESTRELA_CALOR_RAIO + 30.0))
	var queima := (game.fleet[4]["node"] as Node3D)
	var unidade_queima: Dictionary = game.fleet[4]
	queima.position = ESTRELA_POS + Vector3(0.0, 0.0, 20.0)
	game._queimar_na_corona(1.0)
	_assert("dentro da corona o casco cozinha a seis pontos por segundo",
		_igual(float(unidade_queima["hp"]), 100.0 - ESTRELA_QUEIMA, 0.0001),
		"hp %0.2f depois de 1,0 s a 20 u do disco" % float(unidade_queima["hp"]))
	var assada := (game.fleet[5]["node"] as Node3D)
	var unidade_assada: Dictionary = game.fleet[5]
	assada.position = ESTRELA_POS + Vector3(0.0, 0.0, 40.0)
	game._queimar_na_corona(1.0)
	_assert("aquecer não é cozinhar: a 40 u só o multiplicador vale",
		_igual(float(unidade_assada["hp"]), 100.0, 0.0001),
		"hp %0.2f a 40 u, dentro do calor e fora da corona" % float(unidade_assada["hp"]))
	var ponte_antes := float(game.capital_hp)
	game.bridge_rig.position = ESTRELA_POS + Vector3(0.0, 0.0, 10.0)
	game._queimar_na_corona(1.0)
	_assert("a ponte na corona perde casco do mesmo jeito",
		float(game.capital_hp) < ponte_antes, "%0.2f -> %0.2f" % [ponte_antes, game.capital_hp])

	# ---- 9. Calor que muda a salva, sem mudar o sorteio ---------------------------------------
	# Os dois lados usam a MESMA geometria: o `_alinhar` inteiro cabe dentro dos 70 u de calor da
	# estrela, então o que muda de um lado para o outro é só a flag do mapa. Medir um único casco
	# mentiria — com o disco de salva, o lance âncora é um de três e o resto cai no vizinho. E
	# medir os cascos somados dos dois lados também mentiria: a retaliação hostil fere aliadas e
	# o calor delas entra na conta. Aqui é o dano que a linha aliada causou, só isso.
	var d := await _montar_jogo()
	_alinhar(d)
	_zerar(d)
	d.rng.seed = 31337
	var antes_d := _hostis_somados(d)
	d._resolve_volley()
	var perda_d := antes_d - _hostis_somados(d)
	var estado_d: int = d.rng.state
	var e := await _montar_jogo()
	_zerar(e)
	e._montar_cenario("ESTRELA")
	_alinhar(e)
	e.rng.seed = 31337
	var antes_e := _hostis_somados(e)
	e._resolve_volley()
	var perda_e := antes_e - _hostis_somados(e)
	var estado_e: int = e.rng.state
	_assert("a salva quente bate 25% mais", _igual(perda_e, perda_d * ESTRELA_CALOR_FATOR, 0.001),
		"%.3f de casco hostil contra %.3f no campo aberto (mesma geometria, só a flag do mapa muda)"
		% [perda_e, perda_d])
	_assert("o calor não compra sorteio extra", int(estado_d) == int(estado_e),
		"rng %d dos dois lados depois da salva" % estado_d)
	d.queue_free()
	e.queue_free()
	await _frames(2)

	# ---- 10. O painel entrega o cenário --------------------------------------------------------
	var corpos: Dictionary = game.group_bodies
	_assert("oito grupos no painel", corpos.size() == 8 and game.group_heads.size() == 8,
		"%d cabeçalhos / %d corpos" % [game.group_heads.size(), corpos.size()])
	var cenario_botoes := _botoes(game, "CENÁRIO")
	var rotulos := ""
	for botao in cenario_botoes:
		rotulos += botao.text + " | "
	_assert("o grupo CENÁRIO traz os cinco mapas", cenario_botoes.size() == 5,
		"%d botões: %s" % [cenario_botoes.size(), rotulos])
	var total := 0
	for nome in NOMES_GRUPOS:
		total += _botoes(game, nome).size()
	_assert("trinta e um comandos agrupados", total == 31, "%d botões em 8 grupos" % total)
	for botao in cenario_botoes:
		if botao.text.contains("CINTURÃO"):
			botao.pressed.emit()
	_assert("clicar no cinturão monta o cinturão", int(game.rochas.size()) == ROCHA_QTDE
		and String(game.report_label.text).begins_with("CENÁRIO: CINTURÃO"),
		game.report_label.text)
	for botao in cenario_botoes:
		if botao.text.contains("POÇO"):
			botao.pressed.emit()
	_assert("trocar de cenário desmonta o anterior (nada de rocha dobrada)",
		int(game.rochas.size()) == 0 and int(game.astros.size()) == 0 and bool(game.poco_ativo)
		and not bool(game.estrela_ativa) and not bool(game.planeta_ativa),
		"agora %d rochas, %d astros, poco=%s" % [game.rochas.size(), game.astros.size(),
			game.poco_ativo])
	await _frames(4)
	# Sombra + disco + arco = três nós. A lente inteira é um MultiMesh, então contar nós pega nó
	# órfão (`>= 1` aprovaria o cinturão ainda pendurado) sem aprovar duzentos billets soltos.
	_assert("os nós do cenário antigo saem de cena, não ficam pendurados",
		is_instance_valid(game.cenario_root) and game.cenario_root.get_child_count() == 3,
		"%d filhos em Cenario com o poço montado" % game.cenario_root.get_child_count())
	for botao in cenario_botoes:
		if botao.text.contains("SISTEMA"):
			botao.pressed.emit()
	_assert("clicar no sistema monta planeta mais três luas, e só",
		int(game.astros.size()) == 4 and bool(game.planeta_ativa) and not bool(game.poco_ativo)
			and int(game.rochas.size()) == 0,
		"%d astros, planeta=%s, %d rochas, %d filhos em Cenario" % [game.astros.size(),
			game.planeta_ativa, game.rochas.size(), game.cenario_root.get_child_count()])
	# O dedo que monta tem de ser o mesmo que a mesa lê: um `pressed` que chamasse outra função
	# deixaria a sonda de sistema exercitando um caminho que o jogador nunca pega.
	for botao in cenario_botoes:
		if botao.text.contains("CAMPO ABERTO"):
			botao.pressed.emit()
	await _frames(4)
	_assert("voltar ao campo aberto larga todos os nós",
		int(game.cenario_root.get_child_count()) == 0 and int(game.holo_cenario.size()) == 0,
		"%d filhos e %d marcas na mesa" % [game.cenario_root.get_child_count(),
			game.holo_cenario.size()])

	# ---- 11. A mesa lê a barreira onde lê os cascos -------------------------------------------
	game._montar_cenario("CINTURAO")
	var blips_cascos: int = (game.holo_blips as Dictionary).size()
	var cascos_vivos := 0
	for unit in game.fleet:
		if is_instance_valid(unit["node"]):
			cascos_vivos += 1
	for unit in game.enemies:
		if is_instance_valid(unit["node"]):
			cascos_vivos += 1
	_assert("rocha não vira blip de casco: a conta da mesa continua um blip por corpo no quadro",
		blips_cascos == cascos_vivos, "%d blips para %d cascos no quadro" % [blips_cascos, cascos_vivos])
	_assert("cada pedra tem marca na mesa", int(game.holo_cenario.size()) == ROCHA_QTDE,
		"%d marcas para %d rochas" % [game.holo_cenario.size(), game.rochas.size()])
	var fora := 0
	for i in range(game.rochas.size()):
		var marca: MeshInstance3D = game.holo_cenario[i]
		var esperado: Vector3 = game._holo_de(game.rochas[i]["pos"])
		if marca.position.distance_to(esperado) > 0.0001:
			fora += 1
	_assert("a marca holográfica bate com a posição real da pedra", fora == 0,
		"%d de %d marcas fora do lugar" % [fora, game.rochas.size()])
	game._montar_cenario("POCO")
	_assert("o poço tem uma marca na mesa", int(game.holo_cenario.size()) == 1,
		"%d marcas" % game.holo_cenario.size())
	game._montar_cenario("ESTRELA")
	_assert("a estrela tem uma marca na mesa", int(game.holo_cenario.size()) == 1,
		"%d marcas" % game.holo_cenario.size())
	game._montar_cenario("SISTEMA")
	# Quatro astros, quatro marcas, nenhum blip de casco a mais: rocha nenhuma é casco, e agora
	# astro nenhum é tampouco. A régua é a mesma do cinturão, widened para a lista nova.
	var blips_astros: int = (game.holo_blips as Dictionary).size()
	_assert("astro não vira blip de casco", blips_astros == cascos_vivos,
		"%d blips para %d cascos no quadro com o sistema montado" % [blips_astros, cascos_vivos])
	_assert("cada astro tem marca na mesa", int(game.holo_cenario.size()) == game.astros.size()
		and int(game.holo_cenario.size()) == 4,
		"%d marcas para %d astros" % [game.holo_cenario.size(), game.astros.size()])
	var astro_fora := ""
	for i in range(game.astros.size()):
		var marca_astro: MeshInstance3D = game.holo_cenario[i]
		if marca_astro.position.distance_to(game._holo_de(game.astros[i]["pos"])) > 0.0001:
			astro_fora += "%d " % i
	_assert("a marca do astro segue a posição real do astro", astro_fora == "",
		"fora do lugar: [%s]" % astro_fora)
	game._montar_cenario("ABERTO")
	_assert("o campo aberto não pinta marca nenhuma", int(game.holo_cenario.size()) == 0,
		"%d marcas" % game.holo_cenario.size())

	# ---- 12. Nota do painel: cada cenário diz o preço que cobra ------------------------------
	var notas := ""
	for nome in NOMES_CENARIO:
		game._montar_cenario(nome)
		notas += String(game.report_label.text) + "\n     "
	_assert("as cinco notas anunciam consequência, não enfeite",
		notas.contains("14 rochas") and notas.contains("46 u") and notas.contains("25% mais quente")
			and notas.contains("nenhuma barreira") and notas.contains("três luas em órbita"),
		"\n     %s" % notas)
	game._montar_cenario("ABERTO")

	notes.append("veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	for linha in notes:
		print("SONDA-CENARIOS: %s" % linha)
	game.queue_free()
	await _frames(2)
	quit()

## A pedra mais próxima do corredor é a que bloqueia: se a conta devolvesse a segunda, o lance
## morreria atrás de um obstáculo que já estava para trás. Uma asserção que valesse "qualquer
## pedra" aprovaria a errada — aqui o ponto devolvido tem de cair no lado de cá do meio do tiro.
func _mais_perto_vence(game, origem: Vector3, destino: Vector3) -> bool:
	var meio := (origem + destino) * 0.5
	game.rochas[0]["pos"] = meio + Vector3(0.0, 0.0, -6.0)
	game.rochas[1]["pos"] = meio + Vector3(0.0, 0.0, 12.0)
	var corte: Dictionary = game._barreira_entre(origem, destino)
	if corte.is_empty():
		return false
	return (corte["pos"] as Vector3).z > meio.z + 0.001

## Duzentas chamadas do laço de cenário em campo aberto: nenhum gerador se move.
func _prova_inercia(game) -> bool:
	var rng_antes: int = game.rng.state
	var visual_antes: int = game.visual_rng.state
	for i in range(200):
		game._aplicar_cenario(PASSO)
	return int(game.rng.state) == rng_antes and int(game.visual_rng.state) == visual_antes

## Separação aparente, em radianos, entre a direção de uma estrela e a direção do poço vistas do
## olho da ponte. É o ângulo da lente, não a distância do mundo: duas estrelas a 200 u e a 340 u do
## olho podem ter a mesma separação e a conta tem de tratá-las igual.
func _separacao(olho: Vector3, ponto: Vector3) -> float:
	var e := (POCO_POS - olho).normalized()
	var dir := (ponto - olho).normalized()
	return acos(clampf(dir.dot(e), -1.0, 1.0))
