extends SceneTree

## Sonda do cinturão: a correnteza tem casa própria.
##
## O `tools/probes/cenarios.gd` cobra o cenário inteiro — barreira, poço, estrela, painel. Esta
## peça é o cinturão sozinho, e cobra as seis coisas que a frase do comandante pediu: «os
## asteroides podem se mover erraticamente em alguma direção até se chocar e muda-la ou rachar em
## partes quando atingidos». Cada asserção mede um número, nunca uma presença:
##
## 1) A FÓRMULA É O MAPA. As 14 pedras nascem no ponto e na velocidade que o leque anuncia, com ids
##    1..14 e geração zero. Pedra sorteada faria a partida acordar com um mapa diferente a cada
##    carga e empurraria a cauda de `rng` de toda a batalha seguinte.
## 2) ERRÁTICO, NÃO ERRANTE. A banda (|x| 78, |y| 18, z −84..−16) é parede: nenhuma pedra escapa em
##    600 quadros, e a parede é BATIDA de verdade — «nenhuma escapou» com zero quadros encostando na
##    quina é verde por ausência (armadilha nº 1 da casa). O corpo sozinho, a 0,9 u da quina e
##    empurrado para fora, volta com o sinal da normal trocado.
## 3) TETO. 4,2 u/s é conta de FECHAR QUADRO, não de integrar: as três portas que criam velocidade —
##    o empuxo errático, o impulso elástico do choque e o chute das filhas — têm de aparecer aparadas
##    no fim do quadro. Foi aqui o bug real desta rodada: a serra ficava só antes da integração, o
##    choque arremessava a pedra miúda a 5,86 u/s e o `cenarios.gd` não via porque media o estado
##    final, não quadro a quadro. Esta peça percorre os 600 quadros e confere o módulo de cada pedra
##    em cada um.
## 4) SEM RESÍDUO DE CONTATO. O desempilamento posicional vem antes do impulso, então o par que se
##    encosta fecha em exatamente a soma dos raios, e nenhum quadro do mar termina com pedra
##    sobreposta. O par que já está se afastando mantém a velocidade: choque não pode virar freio.
## 5) IDS E GERAÇÕES FECHAM. id é único, cresce com o contador e volta a 1..14 na remontagem
##    (`_desmontar_cenario` zera o contador — sem isto a segunda montagem do cinturão acordaria com
##    ids 15..28 e as janelas de abalroamento antigas travariam dano em pedras novas). Filha herda
##    geração + 1; geração no teto, raio que daria filha miúda e tabuleiro cheio esmiúçam em vez de
##    rachar.
## 6) ZERO SORTEIO. `rng` e `visual_rng` não se movem em sessenta segundos de mar nem em trinta
##    fraturas, e a cauda de 40 sorteios de um tabuleiro que trabalhou o cinturão é idêntica à do
##    controle na mesma semente. Estado intacto é a régua fraca; os sorteios seguintes são a forte.
##
## A marca da mesa entra aqui porque foi ela o bug real da rodada: `_derivar_rochas` somava
## `holo_root.position` em cima de `_holo_de(pos)` numa marca que já é FILHA da mesa, e o holograma
## ia embora enquanto a lógica continuava verde — em `--headless` ninguém lê `marca.position` por
## acidente. A régua local é cobrada quadro a quadro nesta peça; o desenho é cobrado em janela, em
## `tools/probes/fotograma.gd`.
##
## Uso: godot --headless --path . --quit-after 6000 -s res://tools/probes/cinturao.gd

## Espelho das constantes de `main.gd` — a instância do jogo é não tipada e elas não são alcançáveis
## por ela (mesmo motivo em `tools/probes/formacao.gd`). Se o número lá mudar, a asserção quebra: é
## de propósito, é assim que a sonda vira contrato.
const ROCHA_QTDE := 14
const ROCHA_RAIO_BASE := 3.2
const ROCHA_RAIO_DEGRAU := 0.9
const ROCHA_LEQUE_X := 58.0
const ROCHA_Z_INICIAL := -24.0
const ROCHA_Z_PASSO := 4.0
const ROCHA_Y_LEQUE := 13.0
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
const PASSO := 0.1
## Sessenta segundos de mar no relógio da batalha: tempo suficiente para a pedra mais lenta cruzar a
## própria banda e para o empuxo errático trocar o rumo de todas — e curto o bastante para rodar em
## toda bateria sem virar teste de desempenho.
const QUADROS := 600
## Trinta segundos bastam para a cauda do sorteio: o que se cobra aqui é que o trabalho do cinturão
## não empurre o gerador, e 300 quadros já deram filhas no tabuleiro.
const CAUDA_QUADROS := 300

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

## A rocha do leque, na fórmula de `main.gd` — posição e raio. Um `ang` trocado no laço mudaria o
## mapa inteiro sem dar erro nenhum.
func _posicao_esperada(i: int) -> Dictionary:
	var ang := float(i) * 2.39996
	var x := cos(ang) * ROCHA_LEQUE_X * (0.35 + 0.13 * float(i % 5))
	var y := sin(ang * 1.7) * ROCHA_Y_LEQUE
	var z := ROCHA_Z_INICIAL - float(i) * ROCHA_Z_PASSO
	return {"pos": Vector3(x, y, z), "raio": ROCHA_RAIO_BASE + float(i % 4) * ROCHA_RAIO_DEGRAU}

## A velocidade de largada, linha a linha: direção no ângulo áureo do índice e módulo escalonado.
func _velocidade_esperada(i: int) -> Vector3:
	var ang := float(i) * 2.39996
	return Vector3(cos(ang * 0.6 + 1.1), sin(ang * 0.9) * 0.35, sin(ang * 0.6 + 1.1)) \
		* ROCHA_DERIVA * (0.55 + 0.15 * float(i % 4))

## Pares sobrepostos AGORA, na régua com folga de 1e-4: contato encostando-exato é contato resolvido,
## não resíduo. Contado antes e depois da resolução do quadro — a diferença entre as duas leituras é
## exatamente o trabalho que `_peder_rochas` fez.
func _pares_sobrepostos(game) -> int:
	var total := 0
	for i in range(game.rochas.size()):
		for j in range(i + 1, game.rochas.size()):
			var pa: Vector3 = game.rochas[i]["pos"]
			var pb: Vector3 = game.rochas[j]["pos"]
			var soma := float(game.rochas[i]["raio"]) + float(game.rochas[j]["raio"])
			if pa.distance_to(pb) < soma - 0.0001:
				total += 1
	return total

func _fora_da_banda(pos: Vector3, folga: float) -> bool:
	return absf(pos.x) > ROCHA_BANDA_X + folga or absf(pos.y) > ROCHA_BANDA_Y + folga \
		or pos.z < ROCHA_BANDA_Z_FUNDO - folga or pos.z > ROCHA_BANDA_Z_FRENTE + folga

func _encostada_na_quina(pos: Vector3) -> bool:
	return absf(pos.x) > ROCHA_BANDA_X - 0.05 or absf(pos.y) > ROCHA_BANDA_Y - 0.05 \
		or pos.z > ROCHA_BANDA_Z_FRENTE - 0.05 or pos.z < ROCHA_BANDA_Z_FUNDO + 0.05

## Varredura de invariantes do tabuleiro, chamada depois de cada família de fratura. Uma pedra só
## pode existir dentro da banda, abaixo do teto, com geração legal, raio acima do piso, id único, e
## com a marca correspondente na mesa.
func _varredura(game, rotulo: String) -> void:
	var banda := 0
	var teto := 0
	var geracao_alta := 0
	var raio_miudo := 0
	var repetidos := 0
	var marca_fora := 0
	var vistos := {}
	for i in range(game.rochas.size()):
		var rocha: Dictionary = game.rochas[i]
		var pos: Vector3 = rocha["pos"]
		var vel: Vector3 = rocha["vel"]
		var id_roteiro := int(rocha["id"])
		if _fora_da_banda(pos, 0.001):
			banda += 1
		if vel.length() > ROCHA_VETO_TETO + 0.001:
			teto += 1
		if int(rocha["geracao"]) > ROCHA_GERACAO_MAXIMA:
			geracao_alta += 1
		if float(rocha["raio"]) < ROCHA_FILHA_MIN - 0.0001:
			raio_miudo += 1
		if vistos.has(id_roteiro):
			repetidos += 1
		vistos[id_roteiro] = true
		var marca: MeshInstance3D = rocha["marca"]
		if not is_instance_valid(marca):
			marca_fora += 1
		elif marca.position.distance_to(game._holo_de(pos)) > 0.001:
			marca_fora += 1
	_assert("invariantes fecham em %s" % rotulo,
		banda == 0 and teto == 0 and geracao_alta == 0 and raio_miudo == 0 and repetidos == 0
			and marca_fora == 0 and int(game.rochas.size()) <= ROCHA_LIMITE_CORPOS
			and int(game.holo_cenario.size()) == int(game.rochas.size()),
		"%d corpos e %d marcas na mesa" % [game.rochas.size(), game.holo_cenario.size()] \
			+ ", %d fora da banda, %d acima do teto" % [banda, teto] \
			+ ", %d geração alta, %d raio miúdo, %d id repetido, %d marca desencontrada" % [
				geracao_alta, raio_miudo, repetidos, marca_fora])

## ---- 1. A fórmula é o mapa ------------------------------------------------------------
func _secao_leque(game) -> void:
	game._montar_cenario("CINTURAO")
	var pos_fora := 0
	var raio_fora := 0
	var vel_fora := 0
	var ger := 0
	var ids: Array[int] = []
	for i in range(game.rochas.size()):
		var rocha: Dictionary = game.rochas[i]
		var esp: Dictionary = _posicao_esperada(i)
		var destino: Vector3 = esp["pos"]
		var pos: Vector3 = rocha["pos"]
		var vel: Vector3 = rocha["vel"]
		if pos.distance_to(destino) > 0.001:
			pos_fora += 1
		if not _igual(float(rocha["raio"]), float(esp["raio"]), 0.001):
			raio_fora += 1
		if vel.distance_to(_velocidade_esperada(i)) > 0.001:
			vel_fora += 1
		if int(rocha["geracao"]) != 0:
			ger += 1
		ids.append(int(rocha["id"]))
	var numerada := ids.size() == ROCHA_QTDE
	for i in range(ids.size()):
		if int(ids[i]) != i + 1:
			numerada = false
	_assert("o leque pintado é o leque do dicionário: 14 corpos no ponto e no raio da fórmula",
		int(game.rochas.size()) == ROCHA_QTDE and pos_fora == 0 and raio_fora == 0,
		"%d corpos, %d fora do ponto, %d fora do raio" % [game.rochas.size(), pos_fora, raio_fora])
	_assert("a correnteza nasce de conta, não de sorteio: velocidade bate com o ângulo áureo",
		vel_fora == 0, "%d de %d fora da velocidade esperada" % [vel_fora, game.rochas.size()])
	_assert("a largada numera 1..14 em ordem e ninguém nasce já rachado",
		numerada and ger == 0, "primeiro id %d, último id %d, %d de geração > 0" % [
			ids[0], ids[ids.size() - 1], ger])

## ---- 2. A quina devolve: banda é parede, não abstrato ----------------------------------
func _secao_quina(game) -> void:
	game._montar_cenario("ABERTO")
	var pedra: Dictionary = game._nova_rocha(Vector3(ROCHA_BANDA_X - 0.9, 0.0, -50.0), 2.0,
		Vector3(3.0, 0.0, 0.0), 0, 0.5)
	var clock_antes: float = float(game.battle_clock)
	var vx_antes: float = (pedra["vel"] as Vector3).x
	var pos_x_anterior := 0.0
	var tocou := false
	var sinal_trocado := false
	for s in range(60):
		game.battle_clock = clock_antes + float(s + 1) * PASSO
		game._derivar_rochas(PASSO)
		var pos: Vector3 = pedra["pos"]
		var vel: Vector3 = pedra["vel"]
		pos_x_anterior = pos.x
		if pos.x >= ROCHA_BANDA_X - 0.05:
			tocou = true
			sinal_trocado = vx_antes > 0.0 and vel.x < 0.0
			break
	game.battle_clock = clock_antes
	var pos_final: Vector3 = pedra["pos"]
	_assert("uma pedra a 0,9 u da quina e empurrada para fora encosta de verdade", tocou,
		"x = %0.3f na banda de %0.0f, largada a %0.1f u/s" % [pos_final.x, ROCHA_BANDA_X, vx_antes])
	_assert("a quina inverte a normal: a pedra volta, não atravessa nem gruda na parede",
		sinal_trocado and absf(pos_final.x) <= ROCHA_BANDA_X + 0.0001,
		"vel.x %0.2f -> %0.2f, x preso em %0.3f" % [vx_antes, (pedra["vel"] as Vector3).x,
			pos_final.x])

## ---- 3. Teto de velocidade ------------------------------------------------------------
## Três portas despejam velocidade numa pedra, e antes desta rodada só a primeira era conferida: a
## largada absurda, que a integração corta ANTES do passo. As outras duas despejam depois do corte —
## o impulso elástico de `_peder_rochas`, que arremessa a miúda a 8,0 u/s quando a mãe anda a 5, e o
## chuto de `_fraturar_rocha`, que soma 1,2 u/s à filha. Foi elas que a varredura quadro a quadro
## desta sonda pegou: 5,86 u/s num cinturão de 600 quadros com a asserção de estado final verde. O
## conserto coloca a serra também no fechar do quadro, então cada caso abaixo é montado para acusar
## UM corte só: as pedras largam abaixo do teto, e o excesso aparece depois do pré-integração. O
## relógio fica cravado em zero de propósito: com `battle_clock` zero o empuxo só tem o termo
## `cos(0)` em z, e o corte é conferido sem a conta senoidal por dentro do número.
func _secao_teto(game) -> void:
	game._montar_cenario("ABERTO")
	var clock_antes: float = float(game.battle_clock)
	game.battle_clock = 0.0
	var cometa: Dictionary = game._nova_rocha(Vector3(0.0, 0.0, -50.0), 2.0,
		Vector3(40.0, 0.0, 12.0), 0, 0.0)
	var larga := (cometa["vel"] as Vector3).length()
	game._derivar_rochas(PASSO)
	var cortada := (cometa["vel"] as Vector3).length()
	_assert("pedra que nasce acima do teto é aparada antes de andar: 40 u/s viram 4,2 no primeiro quadro",
		larga > ROCHA_VETO_TETO * 2.0 and _igual(cortada, ROCHA_VETO_TETO, 0.0001),
		"%0.2f u/s -> %0.4f u/s (teto %0.1f)" % [larga, cortada, ROCHA_VETO_TETO])

	# Porta 2 — impulso elástico, medida CRUA primeiro: mãe 3,2 u de raio a 3,0 u/s encosta de frente
	# na miúda 1,6 que vem a −3,0, ambas ABAIXO do teto. Troca por raio² (10,24 / 2,56): a miúda sai a
	# −3,0 + (20,48 / 12,8) × 6,0 = 6,6 u/s e a mãe a 0,6 — momento 23,04 e energia 57,6 dos dois lados.
	game._montar_cenario("ABERTO")
	var mae_crua: Dictionary = game._nova_rocha(Vector3(-3.0, 0.0, -50.0), 3.2,
		Vector3(3.0, 0.0, 0.0), 0, 0.0)
	var miuda_crua: Dictionary = game._nova_rocha(Vector3(0.6, 0.0, -50.0), 1.6,
		Vector3(-3.0, 0.0, 0.0), 0, 0.0)
	game._peder_rochas()
	var vel_crua := (miuda_crua["vel"] as Vector3).length()
	var mae_crua_apos := (mae_crua["vel"] as Vector3).length()
	_assert("o choque arremessa a miúda acima do teto: a régua é a do código, não a do desejo",
		_igual(vel_crua, 6.6, 0.0001) and _igual(mae_crua_apos, 0.6, 0.0001),
		"miúda %0.4f u/s (esperado 6,6000), mãe %0.4f u/s (esperado 0,6000)" % [
			vel_crua, mae_crua_apos])

	# A mesma dupla atravessando o quadro: nada é aparado antes da integração, o excesso nasce no
	# meio do `_peder_rochas` interno e o fechar do quadro tem de devolvê-la ao teto.
	game._montar_cenario("ABERTO")
	var mae: Dictionary = game._nova_rocha(Vector3(-3.0, 0.0, -50.0), 3.2,
		Vector3(3.0, 0.0, 0.0), 0, 0.0)
	var rebimboca: Dictionary = game._nova_rocha(Vector3(0.6, 0.0, -50.0), 1.6,
		Vector3(-3.0, 0.0, 0.0), 0, 0.0)
	_assert("as duas largam abaixo do teto: o corte da integração não tem nada que aparar aqui",
		(mae["vel"] as Vector3).length() < ROCHA_VETO_TETO - 0.5
			and (rebimboca["vel"] as Vector3).length() < ROCHA_VETO_TETO - 0.5,
		"mãe %0.4f u/s, miúda %0.4f u/s" % [(mae["vel"] as Vector3).length(),
			(rebimboca["vel"] as Vector3).length()])
	game._derivar_rochas(PASSO)
	var vel_apos := (rebimboca["vel"] as Vector3).length()
	var vel_mae := (mae["vel"] as Vector3).length()
	_assert("e o fechar do quadro apareia o impulso: 6,6 u/s não atravessam o cinturão",
		_igual(vel_apos, ROCHA_VETO_TETO, 0.0001),
		"miúda a %0.4f u/s no fim do quadro (teto %0.1f)" % [vel_apos, ROCHA_VETO_TETO])
	_assert("o corte não varre o tabuleiro: quem ficou embaixo sai do quadro com a própria conta",
		_igual(vel_mae, 0.6, 0.02), "mãe a %0.4f u/s depois do choque (esperado 0,6)" % vel_mae)

	# Porta 3 — chuto da fratura: tiro vindo de z −20 numa pedra em z −50 com fase zero dá eixo
	# (1,0,0) por Rodrigues, então uma das filhas nasce a 4,2 + 1,2 = 5,4 u/s ainda dentro do quadro
	# em que a mãe foi removida.
	game._montar_cenario("ABERTO")
	var parturiente: Dictionary = game._nova_rocha(Vector3(0.0, 0.0, -50.0), 3.2,
		Vector3(ROCHA_VETO_TETO, 0.0, 0.0), 0, 0.0)
	var rachou_chuto: bool = bool(game._fraturar_rocha(parturiente,
		3.2 * ROCHA_INTEGRIDADE_POR_RAIO + 0.001, Vector3(0.0, 0.0, -20.0)))
	var mais_rapida := 0.0
	for rocha_chuta in game.rochas:
		mais_rapida = maxf(mais_rapida, (rocha_chuta["vel"] as Vector3).length())
	game._derivar_rochas(PASSO)
	var depois_chuto := 0.0
	for rocha_chuta in game.rochas:
		depois_chuto = maxf(depois_chuto, (rocha_chuta["vel"] as Vector3).length())
	_assert("a filha chutada para trás da mãe veloz nasce acima do teto", rachou_chuto
		and mais_rapida > ROCHA_VETO_TETO + 0.5, "%0.4f u/s na largada da fratura" % mais_rapida)
	_assert("e o primeiro quadro depois do parto devolve todas ao teto",
		_igual(depois_chuto, ROCHA_VETO_TETO, 0.0001), "%0.4f u/s no quadro seguinte" % depois_chuto)
	game.battle_clock = clock_antes

## ---- 4. Sessenta segundos de mar no cinto real -----------------------------------------
func _secao_mar(game) -> void:
	game._montar_cenario("CINTURAO")
	var rng_antes: int = game.rng.state
	var visual_antes: int = game.visual_rng.state
	var clock_antes: float = float(game.battle_clock)
	var partida: Array = []
	for i in range(game.rochas.size()):
		partida.append(game.rochas[i]["pos"])
	var banda := 0
	var teto := 0
	var rasantes := 0
	var no_teto := 0
	var choques := 0
	var residuo := 0
	var paradas := 0
	var giradas := 0
	var vel_max := 0.0
	var x_max := 0.0
	var y_max := 0.0
	var z_min := 0.0
	## O cinto inteiro mora em z negativo, então um `z_max` nascido em zero nunca é batido por
	## `maxf` e o detalhe impresso contaria range até 0,0 — leitura que faria o próximo leitor
	## caçar pedra fora da banda onde não há nenhuma.
	var z_max := -INF
	for s in range(QUADROS):
		choques += _pares_sobrepostos(game)
		game.battle_clock = clock_antes + float(s + 1) * PASSO
		game._derivar_rochas(PASSO)
		residuo += _pares_sobrepostos(game)
		for i in range(game.rochas.size()):
			var rocha: Dictionary = game.rochas[i]
			var pos: Vector3 = rocha["pos"]
			var vel: Vector3 = rocha["vel"]
			var modulo := vel.length()
			vel_max = maxf(vel_max, modulo)
			if _fora_da_banda(pos, 0.0001):
				banda += 1
			if modulo > ROCHA_VETO_TETO + 0.0001:
				teto += 1
			if modulo > ROCHA_VETO_TETO - 0.001:
				no_teto += 1
			if _encostada_na_quina(pos):
				rasantes += 1
			x_max = maxf(x_max, absf(pos.x))
			y_max = maxf(y_max, absf(pos.y))
			z_min = minf(z_min, pos.z)
			z_max = maxf(z_max, pos.z)
	game.battle_clock = clock_antes
	for i in range(game.rochas.size()):
		var corpo: Dictionary = game.rochas[i]
		if (partida[i] as Vector3).distance_to(corpo["pos"]) < 0.5:
			paradas += 1
		var vel_fim: Vector3 = corpo["vel"]
		if vel_fim.length_squared() > 0.0001 and _velocidade_esperada(i).normalized() \
				.dot(vel_fim.normalized()) > 0.999:
			giradas += 1
	var corpo_fora := 0
	var marca_fora := 0
	for i in range(game.rochas.size()):
		var rocha_fim: Dictionary = game.rochas[i]
		var pos_fim: Vector3 = rocha_fim["pos"]
		var no: Node3D = rocha_fim["no"]
		if not is_instance_valid(no) or no.global_position.distance_to(pos_fim) > 0.001:
			corpo_fora += 1
		var marca: MeshInstance3D = rocha_fim["marca"]
		if not is_instance_valid(marca):
			marca_fora += 1
		elif marca.position.distance_to(game._holo_de(pos_fim)) > 0.001:
			marca_fora += 1
	_assert("em %d quadros nenhuma pedra escapa da banda" % QUADROS, banda == 0,
		"%d leituras fora da banda" % banda + " (|x| %0.0f / |y| %0.0f / z %0.0f..%0.0f)" % [
			ROCHA_BANDA_X, ROCHA_BANDA_Y, ROCHA_BANDA_Z_FUNDO, ROCHA_BANDA_Z_FRENTE]
			+ "; máximos medidos x %0.2f, y %0.2f, z %0.2f..%0.2f" % [x_max, y_max, z_min, z_max])
	_assert("a banda é parede batida, não margem teórica: pedra encostou na quina", rasantes > 0,
		"%d quadros com pedra a 5 cm da quina em %d" % [rasantes, QUADROS])
	_assert("nenhuma pedra passa do teto de %0.1f u/s no mar inteiro" % ROCHA_VETO_TETO,
		teto == 0, "velocidade máxima medida %0.4f u/s, %d quadros colados no teto" % [
			vel_max, no_teto])
	_assert("o teto aperta de verdade no cinto real: pedra encostou nele", no_teto > 0,
		"%d leituras a menos de 0,001 u/s do teto em %d quadros" % [no_teto, QUADROS])
	_assert("o contato entre pedras acontece e não sobra resíduo nenhum",
		choques > 0 and residuo == 0, "%d quadros-pair sobrepostos antes da resolução" % choques
			+ ", %d depois" % residuo)
	_assert("correnteza move todo o cinturão: nenhuma pedra ficou no ponto do leque",
		paradas == 0 and giradas == 0, "%d paradas na origem, %d ainda na direção de largada" % [
			paradas, giradas])
	_assert("corpo pintado e marca da mesa acompanham o dicionário quadro a quadro",
		corpo_fora == 0 and marca_fora == 0, "%d corpos e %d marcas desencontradas" % [
			corpo_fora, marca_fora])
	_assert("deriva não cria nem destrói corpo nem marca",
		int(game.rochas.size()) == ROCHA_QTDE and int(game.holo_cenario.size()) == ROCHA_QTDE,
		"%d rochas e %d marcas" % [game.rochas.size(), game.holo_cenario.size()])
	_assert("sessenta segundos de mar não sorteiam um dígito",
		int(game.rng.state) == rng_antes and int(game.visual_rng.state) == visual_antes,
		"rng %d e visual %d intactos" % [rng_antes, visual_antes])

## ---- 5. O par que chega: desempilha, troca a normal, guarda a tangencial ----------------
func _secao_par_que_chega(game) -> void:
	game._montar_cenario("ABERTO")
	var a: Dictionary = game._nova_rocha(Vector3(-2.0, 0.0, -50.0), 3.0, Vector3(2.0, 1.5, 0.0), 0, 0.2)
	var b: Dictionary = game._nova_rocha(Vector3(2.0, 0.0, -50.0), 2.0, Vector3(-1.0, 0.7, 0.0), 0, 0.6)
	var pa_antes: Vector3 = a["pos"]
	var pb_antes: Vector3 = b["pos"]
	var va_antes: Vector3 = a["vel"]
	var vb_antes: Vector3 = b["vel"]
	game._peder_rochas()
	var pa: Vector3 = a["pos"]
	var pb: Vector3 = b["pos"]
	var va: Vector3 = a["vel"]
	var vb: Vector3 = b["vel"]
	var soma := 5.0
	var ma := 9.0
	var mb := 4.0
	var aproxima := (vb_antes - va_antes).dot(Vector3.RIGHT)
	var espera_a := va_antes.x + (2.0 * mb / (ma + mb)) * aproxima
	var espera_b := vb_antes.x - (2.0 * ma / (ma + mb)) * aproxima
	_assert("o par que se encosta fecha em exatamente a soma dos raios: zero resíduo",
		_igual(pa.distance_to(pb), soma, 0.0001), "distância %0.4f para soma %0.1f" % [
			pa.distance_to(pb), soma])
	_assert("o desempilamento empurrou as duas para fora, meio a meio",
		_igual(pa.x - pa_antes.x, -0.5, 0.0001) and _igual(pb.x - pb_antes.x, 0.5, 0.0001),
		"a foi de %0.3f a %0.3f, b de %0.3f a %0.3f" % [pa_antes.x, pa.x, pb_antes.x, pb.x])
	_assert("a troca de velocidade é a normal ponderada por raio², conferida no número",
		_igual(va.x, espera_a, 0.0001) and _igual(vb.x, espera_b, 0.0001),
		"vx a %0.4f -> %0.4f (esperado %0.4f), b %0.4f -> %0.4f (esperado %0.4f)" % [
			va_antes.x, va.x, espera_a, vb_antes.x, vb.x, espera_b])
	_assert("a tangencial sobrevive: asteroide não tem freio",
		_igual(va.y, va_antes.y, 0.0001) and _igual(vb.y, vb_antes.y, 0.0001),
		"vy intacto em %0.2f e %0.2f" % [va.y, vb.y])
	_assert("pedra grande não sai voando porque uma miúda encostou",
		absf(va.x - va_antes.x) < absf(vb.x - vb_antes.x) - 0.0001,
		"Δvx %0.3f contra %0.3f, na razão dos raios" % [absf(va.x - va_antes.x),
			absf(vb.x - vb_antes.x)])

## ---- 6. O par que já está se afastando: só separa, não empurra --------------------------
func _secao_par_que_afasta(game) -> void:
	game._montar_cenario("ABERTO")
	var a: Dictionary = game._nova_rocha(Vector3(-2.0, 0.0, -50.0), 3.0, Vector3(-2.0, 0.0, 0.0), 0, 0.2)
	var b: Dictionary = game._nova_rocha(Vector3(2.0, 0.0, -50.0), 2.0, Vector3(2.0, 0.0, 0.0), 0, 0.6)
	var va_antes: Vector3 = a["vel"]
	var vb_antes: Vector3 = b["vel"]
	game._peder_rochas()
	var pa: Vector3 = a["pos"]
	var pb: Vector3 = b["pos"]
	var va: Vector3 = a["vel"]
	var vb: Vector3 = b["vel"]
	_assert("par que se afasta continua com a mesma velocidade: choque não serve de freio",
		va.distance_to(va_antes) < 0.0001 and vb.distance_to(vb_antes) < 0.0001,
		"|%0.3f, %0.3f| contra |%0.3f, %0.3f|" % [va.x, va.y, vb.x, vb.y])
	_assert("e mesmo assim sai da sobreposição: posição não é prêmio de quem chegou primeiro",
		_igual(pa.distance_to(pb), 5.0, 0.0001), "distância final %0.4f" % pa.distance_to(pb))

## ---- 7. Ids, gerações e as três portas que esmiúçam -------------------------------------
func _secao_fratura(game) -> void:
	game._montar_cenario("CINTURAO")
	var pai: Dictionary = game.rochas[3]
	var id_pai := int(pai["id"])
	var pos_pai: Vector3 = pai["pos"]
	var raio_pai := float(pai["raio"])
	var integridade_pai := float(pai["integridade"])
	var no_pai: Node3D = pai["no"]
	var marca_pai: MeshInstance3D = pai["marca"]
	var ultimo_id := int(game.rochas[game.rochas.size() - 1]["id"])
	var tiro := pos_pai + Vector3(0.0, 0.0, 18.0)
	var total_antes := int(game.rochas.size())
	var meiu: bool = bool(game._fraturar_rocha(pai, integridade_pai * 0.5, tiro))
	_assert("metade da integridade sangra e não parte: a pedra continua uma só",
		not meiu and int(game.rochas.size()) == total_antes
			and _igual(float(pai["integridade"]), integridade_pai * 0.5, 0.0001),
		"integridade %0.2f -> %0.2f, %d corpos" % [integridade_pai, float(pai["integridade"]),
			game.rochas.size()])
	var rachou: bool = bool(game._fraturar_rocha(pai, integridade_pai * 0.5 + 0.001, tiro))
	var total_fim := int(game.rochas.size())
	var f1: Dictionary = game.rochas[total_fim - 2]
	var f2: Dictionary = game.rochas[total_fim - 1]
	var p1: Vector3 = f1["pos"]
	var p2: Vector3 = f2["pos"]
	var corda := p2 - p1
	var eixo_tiro := (tiro - pos_pai).normalized()
	_assert("integridade zero racha em duas: a pedra some e duas filhas nascem",
		rachou and total_fim == total_antes + 1 and int(pai["id"]) not in _ids(game),
		"%d -> %d corpos" % [total_antes, total_fim])
	_assert("as filhas herdam geração + 1, raio reduzido pelo fracionário e ids novos do contador",
		int(f1["geracao"]) == 1 and int(f2["geracao"]) == 1
			and _igual(float(f1["raio"]), raio_pai * ROCHA_FILHA_FRAC, 0.0001)
			and _igual(float(f2["raio"]), raio_pai * ROCHA_FILHA_FRAC, 0.0001)
			and int(f1["id"]) == ultimo_id + 1 and int(f2["id"]) == ultimo_id + 2,
		"gerações %d e %d, raio %0.3f (de %0.2f × %0.2f), ids %d e %d após %d" % [
			f1["geracao"], f2["geracao"], float(f1["raio"]), raio_pai, ROCHA_FILHA_FRAC,
			f1["id"], f2["id"], ultimo_id])
	_assert("a separação das filhas é meio raio de cada lado, no eixo perpendicular ao tiro",
		_igual(corda.length(), raio_pai, 0.0001) and absf(corda.normalized().dot(eixo_tiro)) < 0.0001,
		"corda de %0.3f u e cosseno %0.6f com a linha do tiro" % [corda.length(),
			corda.normalized().dot(eixo_tiro)])
	_assert("empuxo da fratura é metade da deriva, para fora, e simétrico",
		_igual((f2["vel"] as Vector3).distance_to((f1["vel"] as Vector3)), ROCHA_DERIVA, 0.0001),
		"filhas abrem a %0.1f u/s uma da outra" % (ROCHA_DERIVA * 0.5 * 2.0))
	await _frames(2)
	_assert("rachar libera a geometria velha: nó e marca da mãe saem da cena e da mesa",
		not is_instance_valid(no_pai) and not is_instance_valid(marca_pai)
			and int(game.holo_cenario.size()) == total_fim,
		"mãe %d: nó %s, marca %s, %d marcas na mesa para %d corpos" % [id_pai,
			"livre" if not is_instance_valid(no_pai) else "vivo",
			"livre" if not is_instance_valid(marca_pai) else "viva",
			game.holo_cenario.size(), game.rochas.size()])
	_varredura(game, "depois da rachadura no cinto real")

	# Cascata: a filha grande ainda pode rachar uma vez; a neta para na porta de geração.
	var filha_grande: Dictionary = f1
	var rachou_neta: bool = bool(game._fraturar_rocha(filha_grande,
		float(filha_grande["integridade"]) + 0.001, tiro))
	var netas := 0
	for rocha in game.rochas:
		if int(rocha["geracao"]) == 2:
			netas += 1
	_assert("a filha de raio suficiente racha de novo e a neta chega à geração 2",
		rachou_neta and netas == 2, "%d corpos de geração 2 no mapa" % netas)
	var neta: Dictionary = game.rochas[game.rochas.size() - 1]
	var total_neta := int(game.rochas.size())
	var esmiucou: bool = bool(game._fraturar_rocha(neta, float(neta["integridade"]) + 0.001, tiro))
	_assert("geração no teto esmiúça em vez de rachar: corpo a menos, filha nenhuma",
		esmiucou and int(game.rochas.size()) == total_neta - 1,
		"%d -> %d corpos depois de ferir uma geração %d" % [total_neta, game.rochas.size(),
			neta["geracao"]])
	_varredura(game, "depois da porta de geração")

	# Porta do raio: pedra miúda demais para parir filha válida some sozinha.
	game._montar_cenario("ABERTO")
	var aneao: Dictionary = game._nova_rocha(Vector3(0.0, 0.0, -50.0), 2.2, Vector3.ZERO, 1, 0.4)
	var total_aneao := int(game.rochas.size())
	var partiu: bool = bool(game._fraturar_rocha(aneao, float(aneao["integridade"]) + 0.001,
		Vector3(0.0, 0.0, -20.0)))
	_assert("raio que daria filha abaixo do piso esmiúça: 2,2 × 0,62 = 1,364 não vira corpo",
		partiu and int(game.rochas.size()) == total_aneao - 1,
		"%d -> %d corpos" % [total_aneao, game.rochas.size()])

	# Porta do tabuleiro cheio.
	game._montar_cenario("ABERTO")
	var k := 0
	while int(game.rochas.size()) < ROCHA_LIMITE_CORPOS:
		game._nova_rocha(Vector3(0.0, 0.0, -20.0 - float(k) * 0.4), 2.0, Vector3.ZERO, 0,
			float(k) * 0.1)
		k += 1
	var cheinho: Dictionary = game._nova_rocha(Vector3(30.0, 0.0, -50.0), 6.0, Vector3.ZERO, 0, 0.0)
	var cheio := int(game.rochas.size())
	var virou: bool = bool(game._fraturar_rocha(cheinho, float(cheinho["integridade"]) + 0.001,
		Vector3(30.0, 0.0, -20.0)))
	_assert("tabuleiro no teto de corpos esmiúça em vez de crescer: a fratura tem preço",
		virou and cheio >= ROCHA_LIMITE_CORPOS and int(game.rochas.size()) == cheio - 1,
		"tabuleiro em %d corpos caiu para %d" % [cheio, game.rochas.size()])
	_assert("nenhuma conta acima do teto de corpos em nenhum caminho",
		int(game.rochas.size()) <= ROCHA_LIMITE_CORPOS,
		"%d corpos, teto %d" % [game.rochas.size(), ROCHA_LIMITE_CORPOS])
	_varredura(game, "depois das três portas")

	# A remontagem zera o contador: sem isto as janelas de abalroamento antigas travariam dano em
	# pedras novas.
	game._montar_cenario("CINTURAO")
	var ids: Array[int] = []
	for i in range(game.rochas.size()):
		ids.append(int(game.rochas[i]["id"]))
	var voltou := ids.size() == ROCHA_QTDE
	for i in range(ids.size()):
		if int(ids[i]) != i + 1:
			voltou = false
	_assert("a remontagem do mapa zera o contador: ids voltam a 1..14, não seguem em 15..28",
		voltou, "primeiro id %d, último id %d" % [ids[0], ids[ids.size() - 1]])

func _ids(game) -> Array:
	var lista: Array = []
	for rocha in game.rochas:
		lista.append(int(rocha["id"]))
	return lista

## ---- 8. A cauda do sorteio: o cinturão que trabalhou não rerrola a partida --------------
func _secao_cauda() -> void:
	var a := await _montar_jogo()
	var b := await _montar_jogo()
	a.rng.seed = 70707
	a.visual_rng.seed = 70707
	b.rng.seed = 70707
	b.visual_rng.seed = 70707
	var estado_a: int = a.rng.state
	var estado_b: int = b.rng.state
	b._montar_cenario("CINTURAO")
	var clock_b: float = float(b.battle_clock)
	var rachaduras := 0
	for s in range(CAUDA_QUADROS):
		b.battle_clock = clock_b + float(s + 1) * PASSO
		b._derivar_rochas(PASSO)
	for k in range(30):
		if b.rochas.is_empty():
			break
		var pedra: Dictionary = b.rochas[k % b.rochas.size()]
		if bool(b._fraturar_rocha(pedra, float(pedra["integridade"]) + 0.001,
				Vector3(0.0, 0.0, -20.0))):
			rachaduras += 1
	b.battle_clock = clock_b
	var cauda_a := ""
	var cauda_b := ""
	for d in range(40):
		cauda_a += "%d;" % int(a.rng.randi())
	for d in range(40):
		cauda_b += "%d;" % int(b.rng.randi())
	var visual_a := ""
	var visual_b := ""
	for d in range(40):
		visual_a += "%0.6f;" % float(a.visual_rng.randf())
	for d in range(40):
		visual_b += "%0.6f;" % float(b.visual_rng.randf())
	_assert("os dois tabuleiros largam do mesmo estado de gerador",
		int(estado_a) == int(estado_b), "rng %d dos dois lados" % estado_a)
	_assert("%d quadros de mar e trinta tentativas de fratura não empurram a cauda do sorteio" % CAUDA_QUADROS,
		cauda_a == cauda_b,
		"%d corpos no cinturão trabalhado e 40 sorteios idênticos ao controle" % b.rochas.size())
	_assert("a medida não foi feita em tabuleiro parado: o cinturão da cauda rachou de verdade",
		rachaduras > 0, "%d de 30 ferimentos fecharam em rachadura ou esmiúça" % rachaduras)
	_assert("nem o gerador do desenho se move: o cinturão não gasta enfeite",
		visual_a == visual_b, "40 amostras visuais iguais")
	a.queue_free()
	b.queue_free()
	await _frames(2)

func _initialize() -> void:
	var game: Node3D = await _montar_jogo()
	_secao_leque(game)
	_secao_quina(game)
	_secao_teto(game)
	_secao_mar(game)
	_secao_par_que_chega(game)
	_secao_par_que_afasta(game)
	await _secao_fratura(game)
	await _secao_cauda()
	notes.append("veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	for linha in notes:
		print("SONDA-CINTURAO: %s" % linha)
	game.queue_free()
	await _frames(2)
	quit()
