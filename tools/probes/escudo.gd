extends SceneTree

## Sonda da durabilidade da casca (fatia 3): o canhão encontra primeiro o escudo, e só o que sobra
## encontra o casco.
##
## O desenho está em `docs/superpowers/specs/2026-10-23-comando-esquadra-e-escala-design.md` §4. A
## lei que estava escrita lá é a que esta sonda cobra, cláusula por cláusula: `(1)` o dano morde a
## casca e transborda para o casco, `(2)` o colapso abre uma janela de vulnerabilidade, `(3)` a
## casca se recompõe em constante declarada e não na fila da oficina, `(4)` fogo é o único canal
## interceptado — abalroamento, coroa e poço continuam escrevendo casco direto, `(5)` ataque de
## subsistema passa por cima da casca. Antes disto, `hp` era a única conta de dano e um cruzador com
## 100 de casco caía no mesmo lance em que caía um com 30: não havia nada entre o projétil e a
## chapa, e a massa de 240 blocos não tinha segunda camada a roer.
##
## Por que as cotas são essas e não outras, medidas na casa:
## - `ESCUDO_DE_CASCO 20,0` é oito vezes o dano-base do canhão de linha: `_dano_de_canhao` de um
##   cruzador com armas e tripulação cheios dá exatamente 2,5, e é essa régua (nove lances no oitavo
##   casco) que a casca assina. A família 7 conta no canhão real quantas *salvas* isso é, e a conta
##   não é 8/3: sob ATACAR o lance leva o fator 1,8 da ordem, as três setas pagam um terço cada e as
##   que caem no vão do disco não pagam casca nenhuma. O número de salvas é medido ali, não previsto.
## - `ESCUDO_REGENERA 1,2 u/s` é deliberadamente menor que um lance por intervalo de salva: a cadência
##   é 1,6 s e 1,2 × 1,6 = 1,92 < 2,50. Uma casca sob fogo contínuo nunca se recompõe o bastante para
##   absorver um lance inteiro — regenerar é o que acontece quando a batalha dá trégua, não o que
##   vence a batalha.
## - `ESCUDO_JANELA 4,0 s` é 2,5 × a cadência da salva: quem perde a casca leva pelo menos duas salvas
##   em carne viva antes de a regeneração encher alguma coisa de novo.
## - `ESCUDO_DE_BLOCO 4,4` é exatamente duas `DANO_DE_BLOCO` (2,2) e o bloco nasce com `escudo_max` em
##   zero: a placa da muralha segura as duas primeiras salvas de casco e depois o bloco fica exposto
##   até afundar. Não recomponha é consequência da lei (`teto <= 0`), não uma exceção escrita nela.
##
## O que fica FORA de propósito, e por isso tem família própria: os três canais que não são projétil
## (abalroamento, coroa, poço) e o ataque de subsistema. Cada um deles continua com os números velhos
## conferidos nesta sonda, porque a fatia inteira foi desenhada para não mover as sondas de cenário,
## de massa e de módulos — que são justamente as que medem esses quatro caminhos.
##
## Uso: godot --headless --path . --quit-after 1800 -s res://tools/probes/escudo.gd

const Esquadra := preload("res://esquadra.gd")

## Espelho de ambiente: a semente de salva e o tabuleiro de tiro copiados de
## `tools/probes/modulos.gd` — mesma atiradora, mesma visada, mesmo disco fechado — para que a conta
## de lances por salva seja a que o resto da casa já assina, com o controle de `aliados_feriram`.
const SEMENTE_VOLLEY := 71001
const DELTA := 1.0 / 60.0
## Passo de relógio das famílias de janela e de regeneração: 0,25 é exato em binário, então quatro
## quadros são exatamente um segundo e dezesseis deles esvaziam a janela de 4,0 s sem resíduo. Medir
## a constante com `1/60` acumularia 240 subtrações de um número não representável e a asserção
## precisaria de folga para um erro que não é da lei.
const QUADRO := 0.25
const TIRO := Vector3(0.0, 0.0, -40.0)
const VISADA := Vector3(0.0, 0.0, -80.0)
## Cadência da salva, espelho do literal em `main.gd` (`if fire_clock >= 1.6`). Assinada aqui porque
## a cota da regeneração é declarada em relação a ela, e a asserção que a usa é de comparação, não de
## conta: mudar o 1,6 da batalha sem mudar este número quebra a conferência de propósito.
const CADENCIA_DA_SALVA := 1.6
## Lance-base do canhão de linha, espelho de `_dano_de_canhao`. A família 7 mede o lance de verdade
## chamando a função; esta cota só serve à comparação da regeneração com um intervalo de salva.
const LANCE_BASE := 2.5
## Folga das contas que passam por `1/60` (a família de taxa em tempo de quadro) e das que só somam
## doubles exatos. A primeira é assinada em unidade de casco, não em proporção: um quadro de
## regeneração vale 0,02 u.
const FOLGA_REL := 0.0001
const FOLGA_QUADRO := 0.03
## Quantas salvas a família do portão roda antes de dar o veredito. Doze dá tempo de a frota inteira
## ter casca caída e casco furado em vários corpos enquanto outros ainda têm casca de pé — o
## contrafactual de que a asserção precisa: sem portão, todos estariam furados com a casca cheia.
const SALVAS_DO_PORTAO := 12

var breaks := 0
var notes: Array[String] = []

## A lei carregada em tempo de execução, não em `preload`: na primeira rodada, com o módulo ainda
## ausente, a sonda reprova família por família com evidência em vez de derrubar o arquivo inteiro
## num erro de parse.
var Escudo: GDScript = null

func _assert(label: String, condition: bool, detail: String) -> void:
	if condition:
		notes.append("OK   %s - %s" % [label, detail])
	else:
		breaks += 1
		notes.append("QUEBRA %s - %s" % [label, detail])

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _constantes(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho):
		return {}
	var script := load(caminho) as GDScript
	return {} if script == null else script.get_script_constant_map()

## Monta o jogo e congela pelo instrumento da casa: `process_mode`, nunca `set_process(false)`.
func _montar_jogo() -> Node3D:
	var game: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(3)
	game._update_bridge(0.0)
	game._update_hud()
	return game

## Tabuleiro de tiro de `modulos.gd`: uma atiradora sob ATACAR, um visado vivo, disco fechado, todo
## resto morto ou desarmado. É o único tabuleiro da casa em que se pode assinar "três setas por
## salva" sem contar com a sorte.
func _tabuleiro_de_tiro(game) -> void:
	for i in range(game.fleet.size()):
		var aliado: Dictionary = game.fleet[i]
		(aliado["node"] as Node3D).position = Vector3((float(i) - 2.5) * 5.0, 0.0, -38.0)
		aliado["hp"] = 100.0
		aliado["engines"] = 100.0
		aliado["weapons"] = 0.0
		aliado["crew"] = 100.0
		aliado["order"] = "LINHA"
	for i in range(game.enemies.size()):
		var hostil: Dictionary = game.enemies[i]
		(hostil["node"] as Node3D).position = Vector3((float(i) - 2.5) * 6.0, 0.0, -82.0)
		hostil["hp"] = 100.0
		hostil["engines"] = 100.0
		hostil["weapons"] = 100.0
		hostil["crew"] = 100.0
		hostil["seen"] = true
		if i > 0:
			hostil["hp"] = 0.0
	(game.enemies[0]["node"] as Node3D).position = VISADA
	(game.fleet[0]["node"] as Node3D).position = TIRO
	game.fleet[0]["weapons"] = 100.0
	game.fleet[0]["order"] = "ATACAR"
	game.selected_target = 0
	game.fogo_densidade = 0
	game.rng.seed = SEMENTE_VOLLEY
	game.capital_hp = 100.0
	game.batalha_encerrada = false

## Precondition escrita, não lei contornada: a família 9 precisa de uma casca hostil caída sem
## depender do canhão para isso — o que se quer medir ali é o relógio da regeneração do lado inimigo,
## não a mordaça. Escrever a chapa diretamente é o mesmo que `modulos.gd` faz ao armar as armas do
## visado: o instrumento declara o estado de que precisa.
func _sem_casca(unit: Dictionary) -> void:
	unit["escudo"] = 0.0
	unit["escudo_cai"] = 0.0

## Uma casca sintética, fora do jogo: a lei é folha e aceita qualquer bilhete com as três chaves.
func _casca(teto: float) -> Dictionary:
	return {"hp": 100.0, "escudo": teto, "escudo_max": teto, "escudo_cai": 0.0}

## O bilhete lê o casco de quem existe: um casco de linha tem `hp`, um bloco da massa tem `navios`,
## a ficha crua de `nasce` não tem casco nenhum. Insistir em `hp` não é rigor, é a sonda quebrando
## antes da lei.
func _bilhete(unit: Dictionary) -> String:
	var chapa := "casca %0.3f/%0.3f // janela %0.3f" % [float(unit["escudo"]),
		float(unit["escudo_max"]), float(unit["escudo_cai"])]
	if unit.has("hp"):
		return "casco %0.3f // %s" % [float(unit["hp"]), chapa]
	if unit.has("navios"):
		return "navios %0.2f // %s" % [float(unit["navios"]), chapa]
	return "ficha só de chapa // %s" % chapa

func _roda_lei(unit: Dictionary, n: int, passo: float) -> void:
	for i in range(n):
		Escudo.quadro(unit, passo)

func _roda_ponte(game, n: int, passo: float) -> void:
	for i in range(n):
		game._update_fleet(passo)

## O texto integral de um `.gd`, para a única varredura de fonte que esta sonda faz: a folha não pode
## conter gerador de número aleatório. É asserção de natureza de lei, não de número — um sorteio
## dentro de `morder` reescreveria a cauda de combate de todo mundo.
func _fonte(caminho: String) -> String:
	if not FileAccess.file_exists(caminho):
		return ""
	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	return "" if arquivo == null else arquivo.get_as_text()

func _initialize() -> void:
	print("SONDA-ESCUDO: comecando")
	if FileAccess.file_exists("res://escudo.gd"):
		Escudo = load("res://escudo.gd")
	_assert("existe uma folha de lei de escudo (res://escudo.gd)", Escudo != null,
		"modulo carregado" if Escudo != null else "arquivo ausente")
	if Escudo == null:
		_fechar()
		return

	var cotas := _constantes("res://escudo.gd")
	var jogo_cotas := _constantes("res://main.gd")
	var teto := float(cotas.get("ESCUDO_DE_CASCO", -1.0))
	var reg := float(cotas.get("ESCUDO_REGENERA", -1.0))
	var janela := float(cotas.get("ESCUDO_JANELA", -1.0))
	var placa := float(cotas.get("ESCUDO_DE_BLOCO", -1.0))
	var flechas := int(jogo_cotas.get("FLECHAS_POR_SALVA", 0))
	var dano_bloco := float(Esquadra.DANO_DE_BLOCO)

	# ── 1. as quatro cotas assinadas, lidas do mapa de constantes ─────────────────────────────
	_assert("a casca de linha, a constante, a janela e a placa valem o que o spec assinou",
		absf(teto - 20.0) < FOLGA_REL and absf(reg - 1.2) < FOLGA_REL
			and absf(janela - 4.0) < FOLGA_REL and absf(placa - 4.4) < FOLGA_REL,
		"cascos %0.1f // regen %0.2f u/s // janela %0.1f s // placa %0.1f" % [teto, reg, janela, placa])
	_assert("a placa do bloco é exatamente duas salvas de bloco, medida na cota do bloco",
		absf(placa - 2.0 * dano_bloco) < FOLGA_REL,
		"%0.2f = 2 x %0.2f de DANO_DE_BLOCO" % [placa, dano_bloco])
	_assert("a salva da casa tem três setas, o número que o cabeçalho da lei respira por lance",
		flechas == 3, "FLECHAS_POR_SALVA lido de `res://main.gd` = %d" % flechas)
	_assert("a regeneração de um intervalo de salva cabe dentro de um lance de canhão",
		absf(reg * CADENCIA_DA_SALVA - 1.92) < FOLGA_REL and reg * CADENCIA_DA_SALVA < LANCE_BASE,
		"%0.2f u/s x %0.2f s = %0.3f u contra %0.3f u do lance-base" % [reg, CADENCIA_DA_SALVA,
			reg * CADENCIA_DA_SALVA, LANCE_BASE])
	var chaves: Array[String] = []
	for chave in cotas:
		if String(chave).begins_with("ESCUDO_"):
			chaves.append(String(chave))
	chaves.sort()
	_assert("a folha declara só as quatro cotas, sem alavanca escondida", chaves.size() == 4,
		"%s" % str(chaves))
	var texto := _fonte("res://escudo.gd")
	_assert("a folha é aritmética pura: nenhum gerador mora em `res://escudo.gd`",
		texto.length() > 0 and not texto.contains("randf") and not texto.contains("randi")
			and not texto.contains("RandomNumberGenerator"),
		"%d caracteres de fonte, zero chamadas de sorteio" % texto.length())

	# ── 2. nasce cheia ────────────────────────────────────────────────────────────────────────
	var nasce: Dictionary = Escudo.nasce(teto)
	_assert("`nasce` enche a casca, grava o teto e não abre janela",
		absf(float(nasce["escudo"]) - teto) < FOLGA_REL
			and absf(float(nasce["escudo_max"]) - teto) < FOLGA_REL
			and float(nasce["escudo_cai"]) == 0.0, _bilhete(nasce))

	# ── 3. cláusula 1: morde primeiro, transborda depois ──────────────────────────────────────
	var cheio := _casca(teto)
	var sobra_um := float(Escudo.morder(cheio, 1.0))
	_assert("um lance menor que a casca some inteiro e não arranha o casco",
		sobra_um == 0.0 and absf(float(cheio["escudo"]) - (teto - 1.0)) < FOLGA_REL
			and absf(float(cheio["hp"]) - 100.0) < FOLGA_REL and float(cheio["escudo_cai"]) == 0.0,
		"transbordo %0.3f // %s" % [sobra_um, _bilhete(cheio)])
	var meio := _casca(3.0)
	var sobra_dois := float(Escudo.morder(meio, 8.0))
	_assert("o transbordo é a diferença exata: nem um centésimo do casco se perde em arredondamento",
		absf(sobra_dois - 5.0) < FOLGA_REL and float(meio["escudo"]) == 0.0
			and absf(float(meio["escudo_cai"]) - janela) < FOLGA_REL,
		"transbordo %0.3f // %s" % [sobra_dois, _bilhete(meio)])
	var exato := _casca(placa)
	var sobra_tres := float(Escudo.morder(exato, placa))
	_assert("lance igual à casca esvazia a casca sem tocar no casco (fronteira `<`, nao `<=`)",
		sobra_tres == 0.0 and float(exato["escudo"]) == 0.0
			and absf(float(exato["escudo_cai"]) - janela) < FOLGA_REL,
		"transbordo %0.3f // %s" % [sobra_tres, _bilhete(exato)])
	var cain := _casca(0.0)
	var sobra_quatro := float(Escudo.morder(cain, 7.0))
	_assert("quem já está sem casca leva o lance inteiro e não reabre a janela",
		absf(sobra_quatro - 7.0) < FOLGA_REL and float(cain["escudo_cai"]) == 0.0,
		"transbordo %0.3f // %s" % [sobra_quatro, _bilhete(cain)])
	var zero := _casca(teto)
	var sobra_zero := float(Escudo.morder(zero, 0.0))
	var negativo := float(Escudo.morder(zero, -4.0))
	_assert("dano zero ou negativo não arranha, não cura e não conta como colapso",
		sobra_zero == 0.0 and absf(negativo + 4.0) < FOLGA_REL
			and absf(float(zero["escudo"]) - teto) < FOLGA_REL and float(zero["escudo_cai"]) == 0.0,
		"transbordos %0.3f e %0.3f // %s" % [sobra_zero, negativo, _bilhete(zero)])

	# ── 4. cláusula 2: a janela existe, trava a regeneração e vence ────────────────────────────
	# Teto cheio e casca no chão: é o estado que um colapso deixa. Com teto zero a folha sairia pela
	# porta de `nao recomponha` e a janela nunca venceria — a primeira versão desta família montou
	# exatamente esse corpo e marcou quebra por um defeito da sonda, não da lei.
	var colapsado := _casca(teto)
	colapsado["escudo"] = 0.0
	colapsado["escudo_cai"] = janela
	_roda_lei(colapsado, int(roundf(janela / QUADRO)), QUADRO)
	_assert("nos quatro segundos de janela a casca não volta nem um ponto",
		float(colapsado["escudo"]) == 0.0 and float(colapsado["escudo_cai"]) == 0.0,
		"%s depois de %d quadros de %0.2f s (janela %0.1f s exata)" % [_bilhete(colapsado),
			int(roundf(janela / QUADRO)), QUADRO, janela])
	_roda_lei(colapsado, 10, QUADRO)
	_assert("vencida a janela a casca volta na constante: dois segundos e meio de tela, 3,0 u",
		absf(float(colapsado["escudo"]) - 3.0) < FOLGA_REL,
		"%s // desvio da conta %0.5f" % [_bilhete(colapsado), absf(float(colapsado["escudo"]) - 3.0)])
	var metade := _casca(teto)
	metade["escudo"] = 0.0
	metade["escudo_cai"] = janela
	_roda_lei(metade, 8, QUADRO)
	_assert("a janela queima em relógio de quadro, não em salto: dois segundos andados, dois restam",
		absf(float(metade["escudo_cai"]) - 2.0) < FOLGA_REL and float(metade["escudo"]) == 0.0,
		_bilhete(metade))

	# ── 5. cláusula 3: regenera em constante, para no teto, não escreve casco ──────────────────
	var ferida := _casca(teto)
	ferida["escudo"] = 2.0
	ferida["hp"] = 40.0
	_roda_lei(ferida, 750, QUADRO)
	_assert("a regeneração para exatamente no teto e nunca passa dele",
		absf(float(ferida["escudo"]) - teto) < FOLGA_REL, _bilhete(ferida))
	_assert("a casca enche sozinha e o casco não sobe com ela: `quadro` nao escreve `hp`",
		absf(float(ferida["hp"]) - 40.0) < FOLGA_REL, _bilhete(ferida))
	var sem_emissor := _casca(0.0)
	sem_emissor["escudo_max"] = 0.0
	_roda_lei(sem_emissor, 40, QUADRO)
	_assert("`escudo_max` zero é a forma que a lei le como nao recomponha",
		float(sem_emissor["escudo"]) == 0.0 and float(sem_emissor["escudo_cai"]) == 0.0,
		"%s depois de dez segundos de relógio" % _bilhete(sem_emissor))
	var por_segundo := _casca(teto)
	por_segundo["escudo"] = 0.0
	_roda_lei(por_segundo, 60, DELTA)
	_assert("a constante é por segundo, não por quadro: sessenta quadros de 1/60 valem 1,2 u",
		absf(float(por_segundo["escudo"]) - reg) < FOLGA_QUADRO,
		"%0.4f u contra %0.2f u (residuo de float lido, nao de lei)" % [float(por_segundo["escudo"]),
			reg])

	# ── 6. o portão no jogo verdadeiro ────────────────────────────────────────────────────────
	var g6: Node3D = await _montar_jogo()
	var alvo: Dictionary = g6.enemies[0]
	_assert("todo casco do jogo nasce com casca cheia, teto e janela zerada",
		absf(float(alvo["escudo"]) - teto) < FOLGA_REL
			and absf(float(alvo["escudo_max"]) - teto) < FOLGA_REL
			and float(alvo["escudo_cai"]) == 0.0, _bilhete(alvo))
	var optas := 0
	var orphan := ""
	for lista in [g6.fleet, g6.enemies]:
		for unit in lista:
			if not unit.has("escudo") or not unit.has("escudo_max") or not unit.has("escudo_cai"):
				optas += 1
				orphan = String(unit.get("name", "?"))
			elif float(unit["escudo"]) <= 0.0:
				optas += 1
				orphan = String(unit.get("name", "?"))
	_assert("não há casco órfão de casca nas duas frotas", optas == 0,
		"%d casco(s) aliado(s) + %d hostil(is), %d sem casca (%s)" % [g6.fleet.size(),
			g6.enemies.size(), optas, orphan])
	g6._ferir_casco(alvo, 5.0)
	_assert("o portão morde antes do casco: cinco de lance, cinco de casca, zero de casco",
		absf(float(alvo["escudo"]) - (teto - 5.0)) < FOLGA_REL
			and absf(float(alvo["hp"]) - 100.0) < FOLGA_REL, _bilhete(alvo))
	g6._ferir_casco(alvo, 20.0)
	var anuncio := String(g6.report_label.text)
	_assert("o transbordo é o que chega no casco, e o colapso é anunciado no relatório",
		absf(float(alvo["hp"]) - 95.0) < FOLGA_REL and float(alvo["escudo"]) == 0.0
			and anuncio.contains("ESCUDO COLAPSADO") and anuncio.contains("4 s"),
		"%s // relatorio le «%s»" % [_bilhete(alvo), anuncio])
	g6.report_label.text = "SENTINELA DA PONTE"
	g6._ferir_casco(alvo, 3.0)
	# A frase do colapso é de uma vez. Aqui a régua não é o conteúdo do texto, é a identidade: com a
	# casca já no chão, o golpe tem de escrever `hp` e não encostar no relatório. Comparar com
	# «nao contem ESCUDO COLAPSADO» seria a sonda exigindo que ela reescrevesse.
	_assert("a casca caída não reanuncia: o relatório não é reescrito no quadro seguinte",
		String(g6.report_label.text) == "SENTINELA DA PONTE"
			and absf(float(alvo["hp"]) - 92.0) < FOLGA_REL,
		"relatorio agora le «%s» // %s" % [String(g6.report_label.text), _bilhete(alvo)])
	alvo["seen"] = true
	g6._update_hud()
	_assert("a ponte lê a casca no seletor de alvo, junto com o casco",
		String(g6.target_selector.get_item_text(0)).contains("ESCUDO 0%"),
		"seletor le «%s»" % String(g6.target_selector.get_item_text(0)))
	var intacto: Dictionary = g6.enemies[1]
	intacto["seen"] = true
	g6._update_hud()
	_assert("casco são com casca cheia lê ESCUDO 100%: a régua não inventa vazio",
		String(g6.target_selector.get_item_text(1)).contains("CASCO 100% // ESCUDO 100%"),
		"seletor le «%s» // %s" % [String(g6.target_selector.get_item_text(1)), _bilhete(intacto)])

	# ── 7. quantos lances a casca segura, contado no canhão real ──────────────────────────────
	var g7: Node3D = await _montar_jogo()
	_tabuleiro_de_tiro(g7)
	var atiradora: Dictionary = g7.fleet[0]
	var visado: Dictionary = g7.enemies[0]
	var lance := float(g7._dano_de_canhao(atiradora))
	_assert("o canhão real entrega o lance que a cota jura ser (20 = 8 x 2,5)",
		absf(lance - LANCE_BASE) < FOLGA_REL and absf(teto / lance - 8.0) < FOLGA_REL,
		"lance %0.3f u, casca do casco %0.1f u = %0.1f lances" % [lance, teto, teto / lance])
	# A salva real não é o lance-base: sob ATACAR o dano da atiradora leva o fator 1,8 da ordem, o
	# disco abre em três setas de um terço cada e nem toda seta acha o casco de 2,4 u de raio. A
	# primeira versão desta família previu «duas salvas somem, a terceira fura» a partir de 3 x 2,5 e
	# marcou quebra por causa da própria aritmética chutada. O que se assina aqui é invariante, e o
	# número de salvas é medida impressa — é ele que o README cita, não uma conta de cabeça.
	var salvas_7 := 0
	var casco_frio := true
	var desceu_sempre := true
	var colapsou_em := -1
	var furo_colapso := 0.0
	var casca_antes_7 := float(visado["escudo"])
	var mordida_7 := 0.0
	while salvas_7 < SALVAS_DO_PORTAO and colapsou_em < 0:
		var casco_antes_7 := float(visado["hp"])
		g7._resolve_volley()
		salvas_7 += 1
		var casca_depois_7 := float(visado["escudo"])
		var salto := casca_antes_7 - casca_depois_7
		mordida_7 += salto
		if salto <= 0.0:
			desceu_sempre = false
		if casca_depois_7 > FOLGA_REL:
			if absf(float(visado["hp"]) - casco_antes_7) > FOLGA_REL:
				casco_frio = false
		else:
			colapsou_em = salvas_7
			furo_colapso = casco_antes_7 - float(visado["hp"])
		casca_antes_7 = casca_depois_7
	_assert("com a casca de pé o canhão real não arranha um ponto de casco",
		casco_frio and colapsou_em > 0,
		"%d salva(s) até o colapso; casco perdido antes dele: 0 // %s" % [colapsou_em,
			_bilhete(visado)])
	_assert("cada salva come casca de verdade: nenhum lance do canhão se evapora", desceu_sempre,
		"%d salva(s) comeram %0.3f u de casca até cair" % [salvas_7, mordida_7])
	_assert("a casca de linha morde exatamente o próprio teto antes de cair: nem um ponto a mais, "
			+ "nem a menos", absf(mordida_7 - teto) < FOLGA_REL,
		"mordida medida %0.4f contra teto %0.1f em %d salva(s)" % [mordida_7, teto, colapsou_em])
	_assert("a salva que derruba a casca escreve o transbordo no mesmo golpe", furo_colapso > 0.0,
		"casco perdido no golpe do colapso %0.3f // %s" % [furo_colapso, _bilhete(visado)])
	_assert("o colapso do canhão real chegou à ponte",
		String(g7.report_label.text).contains("ESCUDO COLAPSADO"),
		"relatorio le «%s»" % String(g7.report_label.text))

	# ── 8. o portão é o único portão: invariante sobre a batalha inteira ──────────────────────
	var g8: Node3D = await _montar_jogo()
	g8.rng.seed = SEMENTE_VOLLEY
	var furou_com_casca := 0
	var amostras := 0
	for s in range(SALVAS_DO_PORTAO):
		g8._resolve_volley()
		for list in [g8.fleet, g8.enemies]:
			for unit in list:
				if float(unit["hp"]) <= 0.0:
					continue
				amostras += 1
				if float(unit["hp"]) < 100.0 and float(unit["escudo"]) > FOLGA_REL:
					furou_com_casca += 1
	var cascos_furados := 0
	var cascas_no_chao := 0
	var cascas_de_pe := 0
	for list in [g8.fleet, g8.enemies]:
		for unit in list:
			if float(unit["hp"]) <= 0.0:
				continue
			if float(unit["hp"]) < 100.0:
				cascos_furados += 1
			if float(unit["escudo"]) <= FOLGA_REL:
				cascas_no_chao += 1
			else:
				cascas_de_pe += 1
	_assert("em %d salvas nenhum casco perdeu casco com a casca de pé" % SALVAS_DO_PORTAO,
		furou_com_casca == 0, "%d violação(ões) em %d amostras de casco vivo" % [furou_com_casca,
			amostras])
	_assert("a régua não é verde por falta de tiro: houve casco furado e houve casca caída",
		cascos_furados > 0 and cascas_no_chao > 0,
		"%d casco(s) furado(s), %d casca(s) no chão, %d ainda de pé" % [cascos_furados,
			cascas_no_chao, cascas_de_pe])

	# ── 9. dois relógios: REPAROS conserta o casco, a casca volta sozinha ──────────────────────
	var g9: Node3D = await _montar_jogo()
	var aliado: Dictionary = g9.fleet[0]
	aliado["repair_priority"] = "CASCO"
	aliado["crew"] = 100.0
	g9._ferir_casco(aliado, 60.0)
	var casco_0 := float(aliado["hp"])
	_assert("com 60 de lance o casco perde 40: os 20 primeiros ficaram na casca",
		absf(casco_0 - 60.0) < FOLGA_REL and float(aliado["escudo"]) == 0.0
			and absf(float(aliado["escudo_cai"]) - janela) < FOLGA_REL, _bilhete(aliado))
	_roda_ponte(g9, 8, QUADRO)
	var taxa_2s := float(aliado["hp"]) - casco_0
	_assert("nos dois primeiros segundos a oficina enche o casco e a casca continua em zero",
		absf(taxa_2s - 4.4) < FOLGA_REL and float(aliado["escudo"]) == 0.0,
		"casco +%0.3f em 2 s (taxa assinada 2,20 u/s) // %s" % [taxa_2s, _bilhete(aliado)])
	_roda_ponte(g9, 24, QUADRO)
	var casco_8s := float(aliado["hp"]) - casco_0
	var casca_8s := float(aliado["escudo"])
	_assert("oito segundos: casco +17,6 e casca +4,8 — dois relógios que não se emprestam número",
		absf(casco_8s - 17.6) < FOLGA_REL and absf(casca_8s - 4.8) < FOLGA_REL,
		"casco +%0.3f (2,20 u/s) // casca %0.3f (1,20 u/s só depois dos 4 s de janela)" % [casco_8s,
			casca_8s])
	var hostil_9: Dictionary = g9.enemies[0]
	_sem_casca(hostil_9)
	_roda_ponte(g9, 4, QUADRO)
	_assert("a muralha também respira: a casca hostil volta na mesma constante, sem oficina",
		absf(float(hostil_9["escudo"]) - reg) < FOLGA_REL,
		"%s depois de 1 s de relógio da ponte" % _bilhete(hostil_9))

	# ── 10. cláusula 4: abalroamento, coroa e poço passam por cima ─────────────────────────────
	var g10: Node3D = await _montar_jogo()
	var vitima: Dictionary = g10.enemies[0]
	var corpo := {}
	for entrada in g10._collision_bodies():
		if entrada["unidade"] != null and entrada["unidade"] == vitima:
			corpo = entrada
	_assert("a vítima tem corpo no tabuleiro de colisão", not corpo.is_empty(),
		"corpo %s" % str(corpo))
	g10._apply_impact(corpo, 12.0)
	_assert("abalroamento não paga casca: doze de impacto, doze de casco, casca intacta",
		absf(float(vitima["hp"]) - 88.0) < FOLGA_REL
			and absf(float(vitima["escudo"]) - teto) < FOLGA_REL, _bilhete(vitima))
	(g10.enemies[0]["node"] as Node3D).global_position = g10.ESTRELA_POS
	var casco_corona := float(vitima["hp"])
	g10._queimar_na_corona(0.5)
	_assert("a coroa cozinha o casco pela porta velha: queima não é projétil",
		float(vitima["hp"]) < casco_corona and absf(float(vitima["escudo"]) - teto) < FOLGA_REL,
		"casco %0.3f -> %0.3f // casca %0.3f intocada" % [casco_corona, float(vitima["hp"]),
			float(vitima["escudo"])])
	vitima["hp"] = 100.0
	g10._devorado_pelo_poco({"unidade": vitima})
	_assert("o poço não negocia com emissor nenhum: casco a zero, casca como estava",
		float(vitima["hp"]) == 0.0 and absf(float(vitima["escudo"]) - teto) < FOLGA_REL,
		"%s // abalroamento e coroa deixaram a casca em %0.3f" % [_bilhete(vitima), teto])

	# ── 11. cláusula 5: ataque de subsistema passa por cima da casca ───────────────────────────
	var g11: Node3D = await _montar_jogo()
	_tabuleiro_de_tiro(g11)
	var painel: OptionButton = g11.subsystem_selector
	var indice_motores := -1
	var indice_casco := -1
	for i in range(painel.get_item_count()):
		var rotulo := String(painel.get_item_text(i))
		if rotulo == "MOTORES":
			indice_motores = i
		elif rotulo == "CASCO":
			indice_casco = i
	painel.select(indice_motores)
	var alvo_11: Dictionary = g11.enemies[0]
	g11._resolve_volley()
	_assert("MOTORES derruba motor sem tocar na casca nem no casco",
		indice_motores >= 0 and float(alvo_11["engines"]) < 100.0
			and absf(float(alvo_11["escudo"]) - teto) < FOLGA_REL
			and absf(float(alvo_11["hp"]) - 100.0) < FOLGA_REL,
		"motor %0.2f // %s" % [float(alvo_11["engines"]), _bilhete(alvo_11)])
	var casca_11 := float(alvo_11["escudo"])
	var casco_11 := float(alvo_11["hp"])
	painel.select(indice_casco)
	g11._resolve_volley()
	_assert("o mesmo casco, no lance seguinte em CASCO, paga a casca antes de pagar o casco",
		indice_casco >= 0 and float(alvo_11["escudo"]) < casca_11
			and absf(float(alvo_11["hp"]) - casco_11) < FOLGA_REL,
		"casca %0.3f -> %0.3f // casco %0.3f -> %0.3f" % [casca_11, float(alvo_11["escudo"]),
			casco_11, float(alvo_11["hp"])])

	# ── 12. a placa do bloco: duas salvas, e nunca recomponha ──────────────────────────────────
	var g12: Node3D = await _montar_jogo()
	var blocos: Array[Dictionary] = g12.esquadra.lista_de("hostil")
	_assert("a esquadra hostil tem blocos para a régua da placa", not blocos.is_empty(),
		"%d bloco(s) hostil(is)" % blocos.size())
	var bloco: Dictionary = blocos[0]
	var navios_0 := float(bloco["navios"])
	_assert("todo bloco nasce com placa e com `escudo_max` zero escrito na ficha",
		absf(float(bloco["escudo"]) - placa) < FOLGA_REL
			and float(bloco.get("escudo_max", -1.0)) == 0.0
			and absf(navios_0 - float(Esquadra.NAVIOS_NO_BLOCO)) < FOLGA_REL,
		"navios %0.1f // placa %0.2f/%0.2f" % [navios_0, float(bloco["escudo"]),
			float(bloco["escudo_max"])])
	g12.esquadra._aplicar_golpe(bloco, "CASCO", dano_bloco)
	g12.esquadra._aplicar_golpe(bloco, "CASCO", dano_bloco)
	_assert("duas salvas de bloco em força cheia somem na placa sem afogar um navio",
		absf(float(bloco["navios"]) - navios_0) < FOLGA_REL and float(bloco["escudo"]) == 0.0
			and absf(float(bloco["escudo_cai"]) - janela) < FOLGA_REL,
		"navios %0.2f // %s" % [float(bloco["navios"]), _bilhete(bloco)])
	g12.esquadra._aplicar_golpe(bloco, "CASCO", dano_bloco)
	var perda := navios_0 - float(bloco["navios"])
	_assert("a terceira salva morde o navio: transbordo x 1,4, o fator velho da casa",
		absf(perda - dano_bloco * 1.4) < FOLGA_REL,
		"navios %0.2f -> %0.2f (perda %0.4f = %0.2f x 1,4)" % [navios_0, float(bloco["navios"]),
			perda, dano_bloco])
	_roda_ponte(g12, 40, QUADRO)
	_assert("a placa não se recompõe nunca: dez segundos de relógio da ponte e ela continua em zero",
		float(bloco["escudo"]) == 0.0, _bilhete(bloco))
	var navios_12 := float(bloco["navios"])
	var armas_12 := float(bloco["ARMAS"])
	g12.esquadra._aplicar_golpe(bloco, "ARMAS", dano_bloco)
	_assert("golpe de ARMAS no bloco passa por cima da placa e do navio",
		float(bloco["ARMAS"]) < armas_12 and absf(float(bloco["navios"]) - navios_12) < FOLGA_REL
			and float(bloco["escudo"]) == 0.0,
		"armas %0.2f -> %0.2f // navios %0.2f // %s" % [armas_12, float(bloco["ARMAS"]),
			float(bloco["navios"]), _bilhete(bloco)])
	var bloco_amigo: Dictionary = g12.esquadra.lista_de("aliado")[0]
	var navios_amigo := float(bloco_amigo["navios"])
	g12.esquadra._aplicar_golpe(bloco_amigo, "CASCO", dano_bloco)
	_assert("a placa é dos dois lados: o bloco aliado também come a primeira salva",
		absf(float(bloco_amigo["navios"]) - navios_amigo) < FOLGA_REL
			and absf(float(bloco_amigo["escudo"]) - (placa - dano_bloco)) < FOLGA_REL,
		"%s" % _bilhete(bloco_amigo))

	# ── 13. nenhum sorteio novo, e a lei é a mesma duas vezes ──────────────────────────────────
	var g13: Node3D = await _montar_jogo()
	var rng_antes := int(g13.rng.state)
	var visual_antes := int(g13.visual_rng.state)
	var unit_13: Dictionary = _casca(teto)
	Escudo.morder(unit_13, 9.0)
	Escudo.quadro(unit_13, 1.0)
	g13._ferir_casco(g13.enemies[0], 4.0)
	g13._update_hud()
	_assert("morder, regenerar e anunciar não consomem sorteio nenhum",
		int(g13.rng.state) == rng_antes and int(g13.visual_rng.state) == visual_antes,
		"rng %d e visual %d intocados pelas quatro chamadas" % [int(g13.rng.state),
			int(g13.visual_rng.state)])
	var assinatura_a: String = await _assinatura_da_batalha(SEMENTE_VOLLEY)
	var assinatura_b: String = await _assinatura_da_batalha(SEMENTE_VOLLEY)
	_assert("duas montadas gêmeas sob a lei nova fecham no mesmo ledger, dígito a dígito",
		assinatura_a == assinatura_b and assinatura_a != "",
		"%d salvas, %d bytes de ledger, %d casco(s) na conta" % [SALVAS_DO_PORTAO,
			assinatura_a.length(), assinatura_a.split("|", false).size()])

	# ── 14. a capitânia não tem casca porque não leva tiro ─────────────────────────────────────
	var g14: Node3D = await _montar_jogo()
	var corpos: Array[Dictionary] = g14._collision_bodies()
	var ultimo: Dictionary = corpos[corpos.size() - 1]
	var capital_14 := float(g14.capital_hp)
	var casca_antes_14 := float(g14.enemies[0]["escudo"])
	g14._resolve_volley()
	_assert("a ponte é corpo no campo sem bilhete de casco, e a salva não a move",
		ultimo["unidade"] == null and absf(float(g14.capital_hp) - capital_14) < FOLGA_REL,
		"ultimo corpo `unidade` = %s // capital_hp %0.2f -> %0.2f // casca do visado %0.2f -> %0.2f" % [
			str(ultimo["unidade"]), capital_14, float(g14.capital_hp), casca_antes_14,
			float(g14.enemies[0]["escudo"])])

	_fechar()

## Ledger das duas frotas depois de N salvas com semente cravada. É a comparação A/B da lei: qualquer
## caminho novo de dano que não passasse pelo portão, ou qualquer sorteio dentro dela, muda a string.
func _assinatura_da_batalha(semente: int) -> String:
	var game: Node3D = await _montar_jogo()
	game.rng.seed = semente
	for s in range(SALVAS_DO_PORTAO):
		game._resolve_volley()
	var partes: Array[String] = []
	for list in [game.fleet, game.enemies]:
		for unit in list:
			partes.append("%0.3f/%0.3f/%0.3f" % [float(unit["hp"]), float(unit["engines"]),
				float(unit["escudo"])])
	return "|".join(partes)

func _fechar() -> void:
	print("SONDA-ESCUDO: veredito - quebras=%d - conferencias=%d" % [breaks, notes.size()])
	for nota in notes:
		print(nota)
	quit(1 if breaks > 0 else 0)
