extends SceneTree

## Sonda da física de voo por classe (fatia 2): o casco obedece a um posto, mas obedece com inércia.
##
## O desenho está em `docs/superpowers/specs/2026-10-23-comando-esquadra-e-escala-design.md` §3. A
## lei que estava escrita lá é a que esta sonda cobra: estado de voo por unidade (`vel` + `rumo` +
## `giro`), com `aceleracao` e `giro_maximo` por classe (pesada: ambos menores) e anisotropia de
## eixo — avante > través > ré. Antes disto, só a capitânia tinha anisotropia e os blocos andavam a
## velocidade instantânea: `move_toward` escrevia a posição e a velocidade saía *derivada* do
## deslocamento, o que significa que um encouraçado arrancava a 8,0 u/s no mesmo quadro em que um
## cruzador arrancava a 8,0 u/s, e uma meia-volta custava um quadro. Uma frota assim não tem classe
## alguma no manobrar — só no teto de marcha.
##
## 1) A FICHA DE CLASSE MANDA NO VOO, NÃO SÓ NA MARCHA. `CLASSES` ganha `aceleracao`, `giro_maximo`,
##    `traves` e `re` nos três degraus, o peso paga nos dois primeiros, e as chaves velhas (`armas`,
##    `velocidade`, `missoes`, `cacas`) continuam lá — a escada de classes é reversível dígito a
##    dígito e nada aqui compra casco novo.
## 2) PROA, TRAVÉS E RÉ SÃO TRÊS TETOS, MEDIDOS NA MESMA FICHA. O mesmo casco, do mesmo repouso, com
##    o mesmo comando de magnitude `teto` em três direções do próprio casco: a proa fecha mais
##    caminho que el través, que fecha mais que a ré, e a velocidade estacionária de cada eixo não
##    passa do teto daquele eixo. Contrafactual embutido: se o envelope for isotrópico (clampar a
##    magnitude em vez de clampar por eixo — o erro mais provável aqui), as três medidas saem
##    idênticas e a família inteira reprova.
## 3) GIRO LIMITADO: NADA DE ROTAR 180° EM UM QUADRO. Em todo quadro da meia-volta o `rumo` anda no
##    máximo `giro_maximo × delta`, e a meia-volta custa pelo menos o tempo do timão — o que a torna
##    manobra com custo, não animação. A guarda contra o falso positivo mora junto: o rumo tem de
##    CHEGAR perto de 180°, senão "não girou nada" passaria como "giro limitado".
## 4) ACELERAÇÃO LIMITADA, TETO PRESERVADO. Do repouso, o primeiro quadro anda `aceleracao × delta`,
##    o ramp é monótono e o estado estacionário continua sendo exatamente a marcha de sempre: a
##    inércia entra como tempo de resposta, nunca como buff ou nerf de velocidade máxima.
## 5) O TETO DO BLOCO CONTINUA SENDO MARCHA × MOTORES. A lei nova não troca a régua antiga: a maior
##    passada de um bloco a motor cheio é `MARCHA_DE_BLOCO / 60`, e o teto do bloco a 30% de motor é
##    a mesma fórmula, conferida medida.
## 6) MOTOR FERIDO PAGA EM TEMPO, NÃO EM SALTO. Duas montadas gêmeas, mesmo destino relativo, um
##    bloco com `MOTORES` a 30: ele chega, leva mais quadros, e jamais dá passo maior que o teto do
##    cheio — o contrário (o ferido chegar antes porque o destino foi resolvido por salto) é o bug
##    que esta família pega.
## 7) A TRAVESSIA E A SALVA SOB A NOVA LEI. O campo de aproximação é cruzado marchando (nunca
##    teleportado), a fachada converge até o contato sem nunca abrir, o tempo medido é IMPRESSO
##    porque é ele que o README jura, e no contato a salva ainda lança — o custo declarado da fatia é
##    o tempo de cada salva, não o engajamento.
## 8) NENHUM SORTEIO TOCADO, NENHUM CASCO ESCRITO. A travessia, as meias-voltas e os A/B de classe
##    correm com `rng` e `visual_rng` na semente cravada e a cauda de quarenta sorteios idêntica, e
##    nenhum `hp` de casco é escrito pela lei de voo.
## 9) A CAPITÂNIA CONTINUA NO MESMO PÉ. A anisotropia dela é a cláusula que a fatia 2 herda pronta:
##    avante > empuxo > ré nos três tetos declarados, lidos das constantes, não de conta de cabeça.
## 10) O JOGO ANDA PELA LEI NOVA. Wiring, não teoria: um casco parado que recebe ordem de navegação
##     não come o teto inteiro no primeiro quadro (a `veloc` do quadro 1 cabe em `aceleracao ×
##     delta`), carrega `rumo` e `giro` finitos, e ainda alcança o próprio teto em trânsito — se a
##     ponte continuasse chamando `move_toward` direto, o primeiro quadro comeria a marcha cheia.

## Espelhos de ambiente: as duas sementes cravadas da casa e as cotas que a travessia precisa.
## Mudar o número em `main.gd`/`esquadra.gd`/`voo.gd` sem mudar o espelho aqui quebra a conferência
## de propósito — é assim que a sonda pega a régua órfã.
const Esquadra := preload("res://esquadra.gd")
const SEMENTE_RNG := 1234567890
const SEMENTE_VISUAL := 555
const DELTA := 1.0 / 60.0
## Quadros de rampa: dez segundos de tela, o bastante para o ramp mais lerdo da ficha fechar e ainda
## sobrar estado estacionário para medir. O encouraçado é o pior caso: 8,0 u/s a 1,6 u/s² são 5,0 s
## = 300 quadros, e com 240 ele nunca encostaria no próprio teto — a família do envelope leria um
## ramp incompleto como se fosse marcha cheia.
const QUADROS_DO_RAMP := 600
const QUADROS_DA_MARCHA := 600
const QUADROS_DA_TRAVESSIA := 3000
## Folga de flutuante para um teto de eixo: as magnitudes são soma de `vel * delta` em float32.
const FOLGA_TETO := 0.0001
## Folga da régua de passo, DERIVADA do instrumento e não escolhida. O passo é lido como diferença
## entre duas posições float32 cujo módulo chega a ~205 u (o recuo hostil da largada); com épsilon de
## 6e-8, uma subtração cancelada nesse tamanho erra `2 × 205 × 6e-8 = 2,5e-5 u`. Medido nesta casa:
## 0,100010 u de passo contra 0,100000 u de teto — erro de leitura, não de lei. Um `1e-6` aqui seria
## reprovar o float32 por ser float32.
const FOLGA_PASSO := 0.00003
## Resíduo de pouso, DERIVADO da lei e não escolhido: com freio de chegada (`raiz(2 · a · d)`) a
## distância só pode encolher enquanto `d > 2 · a · delta²`, que a `a = 3,2` e `delta = 1/60` dá
## 0,0018 u, mais um lag de aceleração de `a · delta² = 0,0009 u`. O teto assinado é uma ordem de
## grandeza acima da conta, e a asserção imprime o maior resto real.
const FOLGA_POUSO := 0.02
## Teto de marcha de um casco com ordem de navegação, espelho de `main.gd`.
const TETO_DE_MOVIMENTO := 8.0
## Rota de prova das famílias de marcha. Quarenta unidades é o máximo que um bloco aliado da
## primeira fileira pode avançar sem atravessar a fachada hostil já em contato, e é também o
## bastante para o ramp fechar de verdade: a `aceleracao` da ficha, o teto de 6 u/s do bloco chega
## em ~5,6 u de rota. Uma rota mais curta mediria o ramp em vez do teto; uma mais longa colocaria
## o bloco dentro do muro adverso.
const ROTA_DE_PROVA := 40.0
## Folga da fachada: a marcha fecha em `DISTANCIA_DE_CONTATO` com o último quadro a meio passo.
const FOLGA_CONTATO := 1.0
## Quantos quadros de vigília depois do pouso a sonda ainda roda: é a janela que mede "cumprida a
## ordem, ninguém escreve posição". Trinta quadros = meio segundo de tela parado.
const QUADROS_DA_VIGILIA := 30

## Raio de captura do pouso, lido de `voo.gd`. O espelho assinado é `FOLGA_POUSO`: se a lei decidir
## pousar fora dele, a sonda reprova em vez de engolir a régua. O sentinela é `-1`, não a própria
## folga: com a folga como padrão a asserção da família 1 seria tautologia na rodada vermelha (módulo
## ausente ⇒ captura = folga ⇒ «captura não passa da folga» verde por ausência de lei).
var captura := -1.0

var breaks := 0
var notes: Array[String] = []

## O módulo de voo lido em tempo de execução, não em `preload`: assim a primeira rodada (módulo
## ainda inexistente) reprova família por família com evidência, em vez de derrubar o arquivo
## inteiro num erro de parse — que é o vermelho inútil.
var Voo: GDScript = null

func _assert(label: String, condition: bool, detail: String) -> void:
	if condition:
		notes.append("OK   %s — %s" % [label, detail])
	else:
		breaks += 1
		notes.append("QUEBRA %s — %s" % [label, detail])

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

## Monta o jogo e congela pelo instrumento da casa: `process_mode`, nunca `set_process(false)`.
func _montar_jogo() -> Node3D:
	var game: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(3)
	game._update_bridge(0.0)
	game._update_hud()
	return game

## Constantes de script sem instanciar nada: a ficha de classe mora em `main.gd` e a ficha do bloco
## em `voo.gd`, e as duas são lidas do próprio mapa de constantes do arquivo.
static func _constantes(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho):
		return {}
	var script := load(caminho) as GDScript
	return {} if script == null else script.get_script_constant_map()

static func _faltam_na_ficha(ficha: Dictionary) -> String:
	var faltam: Array[String] = []
	for chave in ["aceleracao", "giro_maximo", "traves", "re"]:
		if not ficha.has(chave):
			faltam.append(chave)
	return ",".join(faltam)

## As duas linhas da largada, na cota média dos núcleos reais (a mesma régua de `esquadra.gd`): o
## que se mede aqui é locomoção, e a grade é função do índice, não do sorteio.
func _nucleos(aliada: bool) -> Array:
	var posicoes: Array = []
	for i in range(6):
		if aliada:
			posicoes.append(Vector3((float(i) - 2.5) * 5.0, 0.0, -38.0 - float(i % 2) * 5.0))
		else:
			posicoes.append(Vector3((float(i) - 2.5) * 6.0, 0.0, -82.0 - float(i % 2) * 7.0))
	return posicoes

func _nova_esquadra() -> Esquadra:
	var e := Esquadra.new()
	e.montar(_nucleos(true), _nucleos(false))
	return e

func _faixa_z(e: Esquadra, lado: String) -> Dictionary:
	var minimo := INF
	var maximo := -INF
	for b in e.lista_de(lado):
		if not bool(b["vivo"]):
			continue
		var z: float = (b["pos"] as Vector3).z
		minimo = minf(minimo, z)
		maximo = maxf(maximo, z)
	return {"min": minimo, "max": maximo}

func _fachadas(e: Esquadra) -> float:
	return float(_faixa_z(e, "aliado")["min"]) - float(_faixa_z(e, "hostil")["max"])

## Posições de um lado em espelho por `id` (a lista reordena em rendição; o par da passada tem de
## ser conferido pelo identificador, nunca pelo índice do vetor).
static func _espelho_por_id(lista: Array[Dictionary]) -> Dictionary:
	var espelho := {}
	for b in lista:
		espelho[int(b["id"])] = b["pos"] as Vector3
	return espelho

## Maior passo dado num quadro por um bloco vivo de um lado, contra o espelho do quadro anterior.
## É a régua do "nada teleporta": sob a lei nova o teto é a marcha; se alguém voltar a escrever
## posição por resolução direta, o passo dispara e a família reprova.
static func _maior_passo(espelho: Dictionary, lista: Array[Dictionary]) -> float:
	var maior := 0.0
	for b in lista:
		var id := int(b["id"])
		if not espelho.has(id):
			continue
		var d: float = (b["pos"] as Vector3).distance_to(espelho[id] as Vector3)
		maior = maxf(maior, d)
	return maior

func _initialize() -> void:
	print("SONDA-VOO: comecando")
	if FileAccess.file_exists("res://voo.gd"):
		Voo = load("res://voo.gd")
	_assert("existe um modulo de lei de voo (res://voo.gd)", Voo != null,
		"modulo carregado" if Voo != null else "arquivo ausente")

	var do_voo := _constantes("res://voo.gd")
	var do_jogo := _constantes("res://main.gd")
	var classes: Dictionary = do_jogo.get("CLASSES", {})
	var bloco_ficha: Dictionary = do_voo.get("FICHA_BLOCO", {})
	captura = float(do_voo.get("CAPTURA_DE_POUSO", -1.0))

	# ── 1. a ficha de classe manda no voo ───────────────────────────────────────────────────
	# Só entra na conta a classe que DEVE alguma chave: listar as três com colchetes vazios faria a
	# asserção reprovar justamente quando a ficha está completa (foi o que esta rodada pegou).
	var faltas := ""
	for classe in ["CRUZADOR", "BATALHA", "PORTAAVIOES"]:
		var deve: String = _faltam_na_ficha(classes.get(classe, {}))
		if deve != "":
			faltas += "%s[%s] " % [classe, deve]
	var detalhe_ficha := faltas.strip_edges()
	if detalhe_ficha == "":
		detalhe_ficha = "cruzador/encouracado/porta-avioes com as quatro chaves no mapa de constantes"
	_assert("as tres classes tem aceleracao, giro_maximo, traves e re", faltas == "", detalhe_ficha)
	var cruzador: Dictionary = classes.get("CRUZADOR", {})
	var batalha: Dictionary = classes.get("BATALHA", {})
	var porta: Dictionary = classes.get("PORTAAVIOES", {})
	var peso_paga := float(batalha.get("aceleracao", INF)) < float(cruzador.get("aceleracao", 0.0)) \
		and float(batalha.get("giro_maximo", INF)) < float(cruzador.get("giro_maximo", 0.0)) \
		and float(porta.get("aceleracao", INF)) < float(cruzador.get("aceleracao", 0.0)) \
		and float(porta.get("giro_maximo", INF)) < float(cruzador.get("giro_maximo", 0.0))
	_assert("o casco pesado acelera menos e gira menos que o cruzador", peso_paga,
		"aceleracao %0.2f/%0.2f/%0.2f // giro_maximo %0.2f/%0.2f/%0.2f (cruzador/encouracado/porta-avioes)" % [
			float(cruzador.get("aceleracao", 0.0)), float(batalha.get("aceleracao", 0.0)),
			float(porta.get("aceleracao", 0.0)), float(cruzador.get("giro_maximo", 0.0)),
			float(batalha.get("giro_maximo", 0.0)), float(porta.get("giro_maximo", 0.0))])
	var anisotropia_sana := not bloco_ficha.is_empty()
	for ficha in [cruzador, batalha, porta, bloco_ficha]:
		var re_f := float(ficha.get("re", 1.0))
		var traves_f := float(ficha.get("traves", 1.0))
		anisotropia_sana = anisotropia_sana and re_f > 0.0 and re_f < traves_f and traves_f < 1.0 \
			and float(ficha.get("aceleracao", 0.0)) > 0.0 \
			and float(ficha.get("giro_maximo", 0.0)) > 0.0
	_assert("em toda ficha: 0 < re < traves < 1 e aceleracao/giro positivos", anisotropia_sana,
		"cruzador re=%0.2f traves=%0.2f // batalha re=%0.2f traves=%0.2f // porta re=%0.2f traves=%0.2f // bloco re=%0.2f traves=%0.2f" % [
			float(cruzador.get("re", 0.0)), float(cruzador.get("traves", 0.0)),
			float(batalha.get("re", 0.0)), float(batalha.get("traves", 0.0)),
			float(porta.get("re", 0.0)), float(porta.get("traves", 0.0)),
			float(bloco_ficha.get("re", 0.0)), float(bloco_ficha.get("traves", 0.0))])
	var escada_viva := true
	for classe in ["CRUZADOR", "BATALHA", "PORTAAVIOES"]:
		var ficha: Dictionary = classes.get(classe, {})
		for chave in ["nome", "armas", "velocidade", "missoes", "cacas"]:
			escada_viva = escada_viva and ficha.has(chave)
	_assert("a ficha nova nao come as chaves da escada de classes", escada_viva,
		"nome/armas/velocidade/missoes/cacas presentes nos tres degraus")
	# A captura é a boca em que a lei desiste de perseguir e grava o posto. Se ela crescer além da
	# folga de pouso assinada, o resto medido em todas as famílias deixa de ser a régua da fatia 1.
	_assert("o raio de captura declarado nao passa da folga de pouso assinada",
			captura > 0.0 and captura <= FOLGA_POUSO,
			"CAPTURA_DE_POUSO %0.4f u contra a folga assinada de %0.4f u" % [captura, FOLGA_POUSO])

	if Voo == null:
		# Sem lei, as famílias que exercitam a lei não têm instrumento: reprova cada uma com o
		# motivo, em vez de imprimir zero e parecer que passou.
		for rotulo in ["proa/traves/re medidos na mesma ficha", "giro limitado",
				"aceleracao limitada com teto preservado", "teto do bloco = marcha x motores",
				"motor ferido paga em tempo, nao em salto", "travessia e salva sob a nova lei",
				"nenhum sorteio tocado", "o jogo anda pela lei nova"]:
			_assert(rotulo, false, "modulo de voo ausente")
		_fechar()
		return

	var nuc_a := _nucleos(true)
	var nuc_h := _nucleos(false)

	# ── 2. proa, través e ré: três tetos na mesma ficha ─────────────────────────────────────
	# Rumo 0 = proa em -z, través em +x. O comando tem magnitude `teto` nos três casos; o que muda
	# é só a direção dele nos eixos do próprio casco, e o curso é segurado para medir o envelope.
	var teto := 8.0
	var eixo := Voo.eixo(0.0) as Vector3
	var traves_eixo := Voo.traves(0.0) as Vector3
	var avante := _rodar_lei(teto, eixo * teto, cruzador)
	var traves := _rodar_lei(teto, traves_eixo * teto, cruzador)
	var re := _rodar_lei(teto, eixo * -teto, cruzador)
	_assert("a proa fecha mais rota que el través, que fecha mais que a ré",
		avante["rota"] > traves["rota"] + FOLGA_TETO \
			and traves["rota"] > re["rota"] + FOLGA_TETO,
		"%0.2f u avante / %0.2f u de traves / %0.2f u a re em %d quadros a teto %0.1f" % [
			avante["rota"], traves["rota"], re["rota"], QUADROS_DO_RAMP, teto])
	_assert("o estado estacionario de cada eixo nao passa do teto daquele eixo",
		float(avante["velocidade"]) <= teto + FOLGA_TETO \
			and float(traves["velocidade"]) <= teto * float(cruzador.get("traves", 1.0)) + FOLGA_TETO \
			and float(re["velocidade"]) <= teto * float(cruzador.get("re", 1.0)) + FOLGA_TETO,
		"%0.4f avante (teto %0.2f) / %0.4f traves (teto %0.4f) / %0.4f re (teto %0.4f)" % [
			avante["velocidade"], teto, traves["velocidade"], teto * float(cruzador.get("traves", 1.0)),
			re["velocidade"], teto * float(cruzador["re"])])
	# O mesmo par em casco pesado: o envelope é da classe, não um global que o cruzador empresta.
	var batalha_re := _rodar_lei(teto, eixo * -teto, batalha)
	var batalha_ramp := _ramp_lei(teto, batalha)
	var cruzador_ramp := _ramp_lei(teto, cruzador)
	_assert("o encouracado tem envelope proprio: re mais curta e ramp mais longo que o cruzador",
		float(batalha_re["velocidade"]) < float(re["velocidade"]) - FOLGA_TETO \
			and int(batalha_ramp["quadros_ate_teto"]) > int(cruzador_ramp["quadros_ate_teto"]),
		"re %0.4f vs %0.4f u/s // marcha cheia em %d quadros vs %d" % [
			batalha_re["velocidade"], re["velocidade"],
			batalha_ramp["quadros_ate_teto"], cruzador_ramp["quadros_ate_teto"]])

	# ── 3. giro limitado ────────────────────────────────────────────────────────────────────
	var giro_maximo := float(cruzador.get("giro_maximo", 1.0))
	var max_giro := 0.0
	var quadros_para_meia_volta := 0
	var estado := {"pos": Vector3.ZERO, "vel": Vector3.ZERO, "rumo": 0.0}
	for q in range(QUADROS_DA_MARCHA):
		var antes_rumo := float(estado["rumo"])
		# Comando de curso em meia-volta sem vetor de empuxo: é só o timão, para medir a atitude.
		estado = Voo.quadro(estado["pos"], estado["vel"], antes_rumo, Vector3.ZERO, PI,
			DELTA, 0.0, cruzador)
		var ganho := absf(wrapf(float(estado["rumo"]) - antes_rumo, -PI, PI))
		max_giro = maxf(max_giro, ganho)
		if quadros_para_meia_volta == 0 \
				and absf(wrapf(float(estado["rumo"]) - PI, -PI, PI)) < 0.0175:
			quadros_para_meia_volta = q + 1
	_assert("nenhum quadro gira mais que giro_maximo x delta",
		max_giro <= giro_maximo * DELTA + 1e-6,
		"maior giro de um quadro %0.6f rad contra o teto %0.6f rad (giro_maximo %0.2f rad/s)" % [
			max_giro, giro_maximo * DELTA, giro_maximo])
	var piso_meia_volta := (PI - 0.0175) / giro_maximo
	_assert("a meia-volta chega em 180 graus e custa o tempo do timao",
		quadros_para_meia_volta > 0 \
			and float(quadros_para_meia_volta) * DELTA >= piso_meia_volta - DELTA,
		"%d quadros = %0.2f s contra os %0.2f s de piso do giro" % [
			quadros_para_meia_volta, float(quadros_para_meia_volta) * DELTA, piso_meia_volta])
	# Contrafactual do peso: o encouraçado gira mais devagar que o cruzador na mesma manobra.
	var batalha_meia_volta := _tempo_de_meia_volta(batalha)
	_assert("a meia-volta do encouracado custa mais tempo que a do cruzador",
		batalha_meia_volta > float(quadros_para_meia_volta) * DELTA + DELTA,
		"%0.2f s de encouracado contra %0.2f s de cruzador" % [
			batalha_meia_volta, float(quadros_para_meia_volta) * DELTA])

	# ── 4. aceleração limitada, teto preservado ─────────────────────────────────────────────
	var aceleracao := float(cruzador.get("aceleracao", 1.0))
	var ramp := _ramp_lei(teto, cruzador)
	_assert("do repouso, o primeiro quadro anda aceleracao x delta e nao o teto",
		float(ramp["primeiro"]) <= aceleracao * DELTA + 1e-6,
		"%0.5f u/s no quadro 1 contra o teto de %0.5f u/s (aceleracao %0.2f u/s2)" % [
			ramp["primeiro"], aceleracao * DELTA, aceleracao])
	_assert("o ramp e monotonicos ate a marcha cheia", ramp["monotonicos"], ramp["motivo"])
	_assert("o estado estacionario continua sendo a marcha de sempre",
		absf(float(ramp["final"]) - teto) < FOLGA_TETO,
		"%0.4f u/s medidos contra o teto contratado de %0.2f u/s" % [ramp["final"], teto])
	_assert("o tempo ate a marcha cheia e o quociente teto/aceleracao",
		absf(float(ramp["quadros_ate_teto"]) * DELTA - teto / aceleracao) <= 2.0 * DELTA,
		"%d quadros = %0.2f s contra %0.2f s contratados" % [
			ramp["quadros_ate_teto"], float(ramp["quadros_ate_teto"]) * DELTA, teto / aceleracao])

	# ── 5. o teto do bloco continua sendo marcha x motores ─────────────────────────────────
	# Os dois blocos recebem o MESMO destino relativo, a 40 u de proa: rota suficiente para o ramp
	# fechar e o teto verdadeiro ser lido, e é por isso que a passada do primeiro quadro não serve
	# de régua aqui. Sem destino, o bloco nasce em cima do próprio posto e as duas medidas dariam
	# zero contra zero — asserção que não pode reprovar nada.
	var jogo: Node3D = await _montar_jogo()
	var corrida_cheia := _marchar_ate_posto(_nova_esquadra(), 7, nuc_a, nuc_h, 100.0)
	var corrida_ferida := _marchar_ate_posto(_nova_esquadra(), 7, nuc_a, nuc_h, 30.0)
	var marcha_cheia := Esquadra.MARCHA_DE_BLOCO
	var teto_ferido := Esquadra.MARCHA_DE_BLOCO * (0.35 + 0.30 * 0.65)
	_assert("a passada de estado estacionario de um bloco inteiro e o passo da marcha",
		absf(float(corrida_cheia["maior_passo"]) - marcha_cheia * DELTA) < 0.0005,
		"%0.5f u/quadro contra %0.5f u de MARCHA_DE_BLOCO/60" % [
			corrida_cheia["maior_passo"], marcha_cheia * DELTA])
	_assert("motor a 30%% tem teto proprio, lido da mesma formula de marcha",
		absf(float(corrida_ferida["maior_passo"]) - teto_ferido * DELTA) < 0.0005,
		"%0.5f u/quadro contra %0.5f u do teto de MOTORES 30" % [
			corrida_ferida["maior_passo"], teto_ferido * DELTA])
	_assert("a razao entre os dois tetos e a razao das marchas, nao uma coincidencia",
		absf(float(corrida_ferida["maior_passo"]) / float(corrida_cheia["maior_passo"]) \
			- teto_ferido / marcha_cheia) < 0.01,
		"razao medida %0.4f contra %0.4f contratada por 0,35 + 0,30 x 0,65" % [
			float(corrida_ferida["maior_passo"]) / float(corrida_cheia["maior_passo"]),
			teto_ferido / marcha_cheia])

	# ── 6. motor ferido paga em tempo, nao em salto ─────────────────────────────────────────
	_assert("os dois blocos chegam ao posto comandado dentro do numero fixo de quadros",
		int(corrida_cheia["pousou_em"]) > 0 and int(corrida_ferida["pousou_em"]) > 0,
		"cheio pousou no quadro %d, ferido no %d, cap de %d" % [
			corrida_cheia["pousou_em"], corrida_ferida["pousou_em"], QUADROS_DA_TRAVESSIA])
	_assert("o pouso e exatamente em cima do destino, como jurava a fatia 1",
		float(corrida_cheia["resto"]) <= 1e-6 and float(corrida_ferida["resto"]) <= 1e-6,
		"resto %0.6f u no cheio e %0.6f u no ferido, com captura de %0.4f u" % [
			corrida_cheia["resto"], corrida_ferida["resto"], captura])
	_assert("o bloco ferido leva mais quadros que o bloco inteiro",
		int(corrida_ferida["pousou_em"]) > int(corrida_cheia["pousou_em"]),
		"%d quadros com MOTORES 30 contra %d com 100, mesma rota de %0.1f u" % [
			corrida_ferida["pousou_em"], corrida_cheia["pousou_em"], ROTA_DE_PROVA])
	_assert("ferido jamais da passo maior que o teto do cheio",
		float(corrida_ferida["maior_passo"]) <= marcha_cheia * DELTA + FOLGA_PASSO,
		"maior passo do ferido %0.5f u contra %0.5f u" % [
			corrida_ferida["maior_passo"], marcha_cheia * DELTA])
	_assert("cumprida a ordem o bloco para: nenhuma escrita de posicao na vigilia do pouso",
		int(corrida_cheia["mexidos_depois"]) == 0 and int(corrida_ferida["mexidos_depois"]) == 0,
		"%d quadros com o bloco inteiro ainda se mexendo depois do pouso e %d com o ferido, numa vigilia de %d" % [
			corrida_cheia["mexidos_depois"], corrida_ferida["mexidos_depois"], QUADROS_DA_VIGILIA])

	# ── 7. travessia e salva sob a nova lei ─────────────────────────────────────────────────
	var e4 := _nova_esquadra()
	var fachada_inicial := _fachadas(e4)
	var lista4: Array[Dictionary] = e4.lista_de("aliado")
	var lista4_hostil: Array[Dictionary] = e4.lista_de("hostil")
	var q := 0
	var anterior := _fachadas(e4)
	var abriu := 0
	var passo_max := 0.0
	while _fachadas(e4) > Esquadra.DISTANCIA_DE_CONTATO + FOLGA_CONTATO and q < QUADROS_DA_TRAVESSIA:
		# Os dois lados em espelho: a muralha hostil também anda (segue a nossa estação, recuada), e
		# medir só a aliado deixaria o hostil livre para teleportar contra a própria régua.
		var antes_aliado := _espelho_por_id(lista4)
		var antes_hostil := _espelho_por_id(lista4_hostil)
		e4.passo(DELTA, nuc_a, nuc_h)
		passo_max = maxf(passo_max, _maior_passo(antes_aliado, lista4))
		passo_max = maxf(passo_max, _maior_passo(antes_hostil, lista4_hostil))
		if _fachadas(e4) > anterior + FOLGA_TETO:
			abriu += 1
		anterior = _fachadas(e4)
		q += 1
	_assert("a travessia fecha o campo de aproximacao marchando",
		q > 0 and q < QUADROS_DA_TRAVESSIA \
			and _fachadas(e4) <= Esquadra.DISTANCIA_DE_CONTATO + FOLGA_CONTATO,
		"de %0.1f u a %0.1f u em %d quadros = %0.1f s de tela" % [
			fachada_inicial, _fachadas(e4), q, float(q) * DELTA])
	_assert("a fachada nunca abre no meio da marcha", abriu == 0,
		"%d quadros em que a distancia entre fachadas cresceu" % abriu)
	_assert("nenhum bloco da passo acima do teto da marcha na travessia inteira",
		passo_max <= marcha_cheia * DELTA + FOLGA_PASSO,
		"maior passo %0.6f u contra %0.5f u, folga de leitura %0.5f u" % [
			passo_max, marcha_cheia * DELTA, FOLGA_PASSO])

	jogo.rng.seed = SEMENTE_RNG
	jogo.visual_rng.seed = SEMENTE_VISUAL
	var rng_antes := int(jogo.rng.state)
	var visual_antes := int(jogo.visual_rng.state)
	var cauda_semente: Array[int] = _cauda(jogo)
	jogo.rng.seed = SEMENTE_RNG
	jogo.visual_rng.seed = SEMENTE_VISUAL
	var hps_antes: Array[int] = []
	for lista in [jogo.fleet, jogo.enemies]:
		for unit in lista:
			hps_antes.append(int(roundf(float(unit["hp"]) * 1000.0)))
	var q_ponte := _marchar_na_ponte(jogo)
	var fogo_1: Dictionary = jogo.esquadra.troca_salva()
	var q_extra := 0
	while q_extra < 60:
		jogo._atualizar_esquadras(DELTA)
		q_extra += 1
	# O estado é lido ANTES da cauda: `_cauda` consome quarenta sorteios e, comparada depois, ela
	# mesma moveria a régua que se diz conferir.
	var rng_pos_voo := int(jogo.rng.state)
	var visual_pos_voo := int(jogo.visual_rng.state)
	var cauda_depois: Array[int] = _cauda(jogo)
	var cauda_igual := rng_pos_voo == rng_antes and visual_pos_voo == visual_antes
	for i in range(40):
		if cauda_semente[i] != cauda_depois[i]:
			cauda_igual = false
	_assert("%d quadros de travessia pela ponte nao movem os dois geradores" % q_ponte,
		cauda_igual,
		"rng %d -> %d // visual %d -> %d // cauda abre em %d nos dois lados" % [
			rng_antes, rng_pos_voo, visual_antes, visual_pos_voo, cauda_semente[0]])
	var hps_depois: Array[int] = []
	for lista in [jogo.fleet, jogo.enemies]:
		for unit in lista:
			hps_depois.append(int(roundf(float(unit["hp"]) * 1000.0)))
	_assert("a lei de voo nao escreve o hp de casco nenhum",
		hps_antes == hps_depois,
		"%d cascos conferidos, %d divergentes" % [hps_antes.size(),
			0 if hps_antes == hps_depois else hps_depois.size()])

	# ── 8. no contato a salva lanca e a formacao fecha o posto ──────────────────────────────
	var fogo_2: Dictionary = jogo.esquadra.troca_salva()
	_assert("no contato a salva ainda lanca contra a massa em posicao",
		q_ponte > 0 and int(fogo_1.get("lancados", 0)) > 0 \
			and int(fogo_2.get("lancados", 0)) > 0,
		"travessia da ponte em %d quadros (%0.1f s), %d lancos na primeira salva e %d na segunda" % [
			q_ponte, float(q_ponte) * DELTA, int(fogo_1.get("lancados", 0)),
			int(fogo_2.get("lancados", 0))])
	jogo._set_formation("LINHA")
	var q_formacao := 0
	while q_formacao < QUADROS_DA_MARCHA:
		jogo._update_fleet(DELTA)
		q_formacao += 1
	var resto := _resto_formacao(jogo)
	# O teto assinado é DERIVADO da lei, não chutado: um casco em perseguição pode no máximo dar o
	# passo de um quadro (`TETO_DE_MOVIMENTO × delta`, com mobilidade no seu teto de cruzador) antes
	# de entrar na captura, e o cenário (poço do buraco negro, colisão) ainda empurra depois da
	# ordem. Fechar a menos de "captura + um passo de quadro" é o que a lei deve; fechar mais longe
	# é a frota não Chegando. A velha `move_toward` também passava aqui — a régua é de fechamento,
	# não de preferência por uma das duas.
	var teto_de_um_quadro := TETO_DE_MOVIMENTO * DELTA
	var detalhe_formacao := "maior resto %0.6f u apos %d quadros de marcha sob a lei nova" % [resto, q_formacao]
	detalhe_formacao += ", contra captura %0.4f u + passo de um quadro %0.4f u" % [captura, teto_de_um_quadro]
	_assert("os cascos com ordem de navegacao fecham o posto da formacao",
		resto <= captura + teto_de_um_quadro + FOLGA_TETO, detalhe_formacao)

	# ── 9. a capitania continua no mesmo pe ─────────────────────────────────────────────────
	# A anisotropia dela é a cláusula que a fatia 2 herda pronta, lida das constantes e não de conta de
	# cabeça. `CAPITAL_REVERSE` é FATOR de acelerador (-0,6), não velocidade: a ré real é 0,6 da proa.
	# `CAPITAL_LIFT` é teto do EIXO VERTICAL, e compará-lo com a ré seria comparar dois eixos que nunca
	# competem — a asserção antiga (`avante > empuxo > re`, medida 22 / 12 / 13,2) jurava uma ordem
	# entre grandezas de naturezas diferentes. O que a fatia cobra é o que faz da capitânia um casco
	# anisotrópico: a proa manda mais que qualquer outro teto horizontal, e a ré é fração dela.
	var avante_cap := float(do_jogo.get("CAPITAL_SPEED", 0.0))
	var fator_re_cap := absf(float(do_jogo.get("CAPITAL_REVERSE", 0.0)))
	var re_cap := fator_re_cap * avante_cap
	var empuxo_cap := float(do_jogo.get("CAPITAL_LIFT", 0.0))
	_assert("na capitania a proa manda mais que a re e mais que o empuxo",
		avante_cap > re_cap and avante_cap > empuxo_cap and re_cap > 0.0 and empuxo_cap > 0.0,
		"avante %0.2f u/s / re %0.2f u/s (fator %0.2f) / empuxo %0.2f u/s no eixo vertical" % [
			avante_cap, re_cap, fator_re_cap, empuxo_cap])
	_assert("a re da capitania e fracao da proa, como o `re` da ficha de classe",
		fator_re_cap > 0.0 and fator_re_cap < 1.0,
		"CAPITAL_REVERSE %0.2f = %0.1f%% da marcha de avante" % [fator_re_cap, fator_re_cap * 100.0])

	# ── 10. o jogo anda pela lei nova ───────────────────────────────────────────────────────
	var casco: Dictionary = jogo.fleet[0]
	var node: Node3D = casco["node"]
	var ficha_casco: Dictionary = classes.get(String(casco.get("classe", "CRUZADOR")), cruzador)
	casco["veloc"] = Vector3.ZERO
	casco["rumo"] = 0.0
	casco["giro"] = 0.0
	casco["order"] = "MOVER"
	casco["destination"] = node.position + Vector3(0.0, 0.0, -ROTA_DE_PROVA)
	jogo._update_fleet(DELTA)
	var veloc_1: Vector3 = casco.get("veloc", Vector3.ZERO)
	var teto_casco := TETO_DE_MOVIMENTO * (0.25 + float(casco["engines"]) / 100.0 * 0.75) \
		* float(ficha_casco.get("velocidade", 1.0))
	_assert("cada casco carrega estado de voo finito depois de um quadro da ponte",
		casco.has("rumo") and casco.has("giro") \
			and is_finite(float(casco["rumo"])) and is_finite(float(casco["giro"])) \
			and absf(float(casco["rumo"])) <= PI + 0.001 \
			and is_finite(float(veloc_1.x)) and is_finite(float(veloc_1.z)),
		"rumo %0.4f rad, giro %0.4f rad/s, veloc %s" % [
			float(casco.get("rumo", 0.0)), float(casco.get("giro", 0.0)), veloc_1])
	_assert("o casco parado nao come o teto inteiro no primeiro quadro",
		veloc_1.length() <= float(ficha_casco.get("aceleracao", INF)) * DELTA + 1e-6,
		"%0.5f u/s no quadro 1 contra %0.5f u/s de ramp e %0.5f u/s de marcha cheia" % [
			veloc_1.length(), float(ficha_casco.get("aceleracao", 0.0)) * DELTA, teto_casco])
	var veloc_max := veloc_1.length()
	var q_transito := 0
	while q_transito < 900 and node.position.distance_to(casco["destination"] as Vector3) > captura:
		jogo._update_fleet(DELTA)
		veloc_max = maxf(veloc_max, float((casco.get("veloc", Vector3.ZERO) as Vector3).length()))
		q_transito += 1
	_assert("em transito o casco ainda alcanca o proprio teto de marcha",
		veloc_max >= teto_casco - 0.001,
		"maior |veloc| %0.4f u/s contra o teto %0.4f u/s em %d quadros de rota" % [
			veloc_max, teto_casco, q_transito])

	_fechar()

## Tempo, em segundos, de uma meia-volta sob a ficha dada, medido quadro a quadro pela lei.
func _tempo_de_meia_volta(ficha: Dictionary) -> float:
	var rumo := 0.0
	for q in range(QUADROS_DA_MARCHA):
		var estado: Dictionary = Voo.quadro(Vector3.ZERO, Vector3.ZERO, rumo, Vector3.ZERO, PI,
			DELTA, 0.0, ficha)
		rumo = float(estado["rumo"])
		if absf(wrapf(rumo - PI, -PI, PI)) < 0.0175:
			return float(q + 1) * DELTA
	return INF

## Roda a lei pura por `QUADROS_DO_RAMP` quadros com um comando de vetor fixo e devolve a rota
## fechada mais a velocidade estacionária.
func _rodar_lei(teto: float, vetor: Vector3, ficha: Dictionary) -> Dictionary:
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var rumo := 0.0
	var rota_fechada := 0.0
	var anterior := pos
	for q in range(QUADROS_DO_RAMP):
		var estado: Dictionary = Voo.quadro(pos, vel, rumo, vetor, NAN, DELTA, teto, ficha)
		pos = estado["pos"]
		vel = estado["vel"]
		rumo = estado["rumo"]
		rota_fechada += pos.distance_to(anterior)
		anterior = pos
	return {"rota": rota_fechada, "velocidade": vel.length(), "pos": pos, "rumo": rumo}

## Ramp de velocidade do repouso até o teto, com a proa segurada. Devolve a primeira passada, se o
## ramp é monótono, a velocidade final e em que quadro ela encosta no teto.
func _ramp_lei(teto: float, ficha: Dictionary) -> Dictionary:
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var rumo := 0.0
	var anterior_v := 0.0
	var primeiro := 0.0
	var monotonicos := true
	var motivo := "monotonico ate o fim"
	var quadro_do_teto := 0
	for q in range(QUADROS_DO_RAMP):
		var estado: Dictionary = Voo.quadro(pos, vel, rumo, Voo.eixo(rumo) * teto, NAN, DELTA, teto, ficha)
		pos = estado["pos"]
		vel = estado["vel"]
		rumo = estado["rumo"]
		var v: float = vel.length()
		if q == 0:
			primeiro = v
		elif v < anterior_v - 1e-6:
			monotonicos = false
			if motivo == "monotonico ate o fim":
				motivo = "queda no quadro %d: %0.5f -> %0.5f" % [q, anterior_v, v]
		if quadro_do_teto == 0 and v >= teto - FOLGA_TETO:
			quadro_do_teto = q + 1
		anterior_v = v
	return {"primeiro": primeiro, "monotonicos": monotonicos, "motivo": motivo,
		"final": anterior_v, "quadros_ate_teto": quadro_do_teto}

## Manda UM bloco ao ponto pelo `passo` do jogo e devolve a contagem da marcha: em que quadro ele
## pousou, o resto final, o maior passo dado e quantos quadros da vigília ele ainda se mexeu. A
## vigília é um número FIXO de quadros depois do pouso, não "até o laço cansar": se o laço parasse na
## própria condição de pouso, a asserção de resto seria tautologia e não régua.
func _marchar_ate_posto(e: Esquadra, indice: int, nuc_a: Array, nuc_h: Array,
		motores := 100.0, rota := ROTA_DE_PROVA) -> Dictionary:
	var lista: Array[Dictionary] = e.lista_de("aliado")
	var bloco := lista[indice]
	bloco["MOTORES"] = motores
	var ponto: Vector3 = (bloco["pos"] as Vector3) + Vector3(0.0, 0.0, -rota)
	bloco["com_destino"] = true
	bloco["destino"] = ponto
	var pousou_em := -1
	var maior := 0.0
	var mexidos_depois := 0
	var vigilia_ate := QUADROS_DA_TRAVESSIA
	var q := 0
	while q < QUADROS_DA_TRAVESSIA:
		var antes: Vector3 = bloco["pos"]
		# Controle, não lei: `_reparar` da esquadra sobe MOTORES a 1,1/s, e numa travessia de 40 u o
		# bloco ferido se curaria no meio da rota — a régua leria o motor cheio e chamaria de 30%. O
		# teto de marcha em função do motor é família 5; o reparo tem família própria em
		# `tools/probes/esquadra.gd` e não é trabalho daqui medir as duas leis de uma vez.
		bloco["MOTORES"] = motores
		e.passo(DELTA, nuc_a, nuc_h)
		var passo := (bloco["pos"] as Vector3).distance_to(antes)
		maior = maxf(maior, passo)
		q += 1
		if pousou_em < 0:
			if (bloco["pos"] as Vector3).distance_to(ponto) <= captura:
				pousou_em = q
				vigilia_ate = q + QUADROS_DA_VIGILIA
		elif q > vigilia_ate:
			break
		elif passo > 1e-7:
			mexidos_depois += 1
	return {"pousou_em": pousou_em, "resto": (bloco["pos"] as Vector3).distance_to(ponto),
		"maior_passo": maior, "mexidos_depois": mexidos_depois}

## Marcha pela porta da ponte: `_atualizar_esquadras` é o único `passo` que o jogo chama.
func _marchar_na_ponte(jogo) -> int:
	var q := 0
	while _fachadas(jogo.esquadra) > Esquadra.DISTANCIA_DE_CONTATO + FOLGA_CONTATO \
			and q < QUADROS_DA_TRAVESSIA:
		jogo._atualizar_esquadras(DELTA)
		q += 1
	return q

## Maior resto entre o posto da formação e o casco que DEVERIA estar lá: só conta ordem que escreve
## destino (MOVER / DISPERSAR / AGRUPAR), porque casco em AVANÇAR ou ESCOLTAR não tem posto absoluto
## a conferir — medir o resto dele seria medir a ordem que ele nunca recebeu.
func _resto_formacao(jogo) -> float:
	var maior := 0.0
	for unit in jogo.fleet:
		if float(unit["hp"]) <= 0.0 or not unit.has("destination"):
			continue
		var ordem := String(unit.get("order", ""))
		if ordem != "MOVER" and ordem != "DISPERSAR" and ordem != "AGRUPAR":
			continue
		var node: Node3D = unit["node"]
		if not is_instance_valid(node):
			continue
		maior = maxf(maior, node.position.distance_to(unit["destination"] as Vector3))
	return maior

func _cauda(jogo) -> Array[int]:
	var retirada: Array[int] = []
	for i in range(40):
		retirada.append(jogo.rng.randi())
	return retirada

func _fechar() -> void:
	print("SONDA-VOO: veredito - quebras=%d - conferencias=%d" % [breaks, notes.size()])
	for nota in notes:
		print(nota)
	quit(1 if breaks > 0 else 0)
