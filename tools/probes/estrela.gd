extends SceneTree

## Sonda da estrela: o disco empurra, cega, e não cobra nada.
##
## O `tools/probes/cenarios.gd` já conferia o calor de arma e a cozida da corona. Esta peça é o
## resto do que o comandante pediu — «o sol pode emitir ventos solares e radiação» — e cobra as
## oito coisas que fazem dos dois uma mecânica e não um enfeite:
##
## 1) FIAÇÃO. O vento mora dentro do `if estrela_ativa` de `_aplicar_cenario`, a radiação dentro do
##    `_fator_radiacao`. Com o disco apagado o quadro de cenário não encosta em casco nenhum e a
##    varredura vale o raio inteiro até no centro do disco fictício. É o que deixa a cauda das sondas
##    vizinhas intacta.
## 2) A LEI. Um empurrão radial com peso `1 - d/alcance`: o mesmo peso linear do poço, no sentido
##    contrário. Concreto a 40 u: 3,0 × 0,5833 × 0,1 = 0,175 u no quadro. Fora do alcance nada; no
##    centro exato nada, porque não existe "para fora" sem direção.
## 3) O MAR DO VENTO. A lei é posicional, então cada quadro emagrece o passo seguinte: a correnteza
##    converge para o alcance e nunca o atravessa. A forma fechada espelhada em `pow` e a integração
##    quadro a quadro do jogo têm de dar o mesmo número em 600 quadros.
## 4) DESTROÇO É ÂNCORA. Baixado não é empurrado: o casco zero fica onde caiu, e o controle vivo no
##    mesmo raio anda. Sem esta guarda o vento reescreveria o relatório de perdas.
## 5) O VENTO NÃO FER NEM COBRA. hp, motores, armas, tripulação, `veloc` e o casco da ponte ficam
##    byte a byte, e o passo por quadro cabe em 0,3 u — dois cascos se aproximam a 0,6 u/s contra os
##    3,0 u/s que o abalroamento cobra. O vento nunca fere sozinho.
## 6) RADIAÇÃO CEGA A VARREDURA. Dentro de 120 u o raio da sonda é a metade do de fora: hostil a
##    7,0 u é lido no campo aberto e invisível sob a tempestade; a 4,0 u é lido nos dois lados, que é
##    a asserção que separa "encolheu" de "desligou". E a cegueira sobe até a ponte: no mesmo lance,
##    o seletor de alvo troca `CASCO %` por `NÃO IDENTIFICADO` — número de barra é conta, rótulo de
##    seletor é jogo.
## 7) PAINEL FIEL. A ficha da estrela anuncia os dois novos números e o campo aberto não fala de
##    vento que não existe.
## 8) CAUDA. Trinta segundos de vento sobre doze cascos mais a ponte, estrela apagada contra acesa:
##    os dois geradores não se movem e os quarenta sorteios seguintes são idênticos dígito a dígito.
##
## Os corpos são afastados da corona antes das seções 5 e 8: a estrela acesa cozinha quem está a
## menos de 30 u, e morte de casco mudaria o tabuleiro dos dois lados — a cauda deixaria de medir o
## vento e passaria a medir a cozida. É decisão de montagem, não de código.
##
## Uso: godot --headless --path . --quit-after 6000 -s res://tools/probes/estrela.gd

## Espelho das constantes de `main.gd` — a instância do jogo é não tipada e elas não são alcançáveis
## por ela (mesmo motivo em `tools/probes/cinturao.gd`). Se o número lá mudar, a asserção quebra: é
## de propósito, é assim que a sonda vira contrato.
const ESTRELA_POS := Vector3(0.0, 24.0, -74.0)
const ESTRELA_CALOR_RAIO := 70.0
const ESTRELA_CALOR_FATOR := 1.25
const ESTRELA_CORONA_RAIO := 30.0
const ESTRELA_VENTO_ALCANCE := 96.0
const ESTRELA_VENTO_ACEL := 3.0
const ESTRELA_RADIAO_RAIO := 120.0
const ESTRELA_RADIAO_VARREDURA := 0.5
const PROBE_SCAN_RADIUS := 9.0
const RAM_SPEED := 3.0
const PASSO := 0.1
## Sessenta segundos de vento. O passo analítico é `ACEL × PASSO / ALCANCE` = 0,003125 por quadro,
## então 600 quadros comem ~85% da distância que falta até o alcance: dá para ver a assíntota
## chegando sem esperar infinitos.
const QUADROS := 600
const CAUDA_QUADROS := 300
## O passo de um quadro a 40 u do disco: 3,0 × (1 − 40/96) × 0,1. Toda a sonda lê este número como
## régua, e ele é conferido contra a fórmula, não contra o gosto.
const PASSO_A_40 := 0.175
## A folga das medidas de passo. O empurrão é conta exata; quem arredonda é a coordenada: `Vector3`
## é float32, e o ulp em torno de 80 u vale 7,6e-6 — um quadro a 80 u lê 0,050003 u contra os
## 0,050000 da fórmula. 5e-5 é a resolução da posição, não margem para a lei errar: o erro que a
## lei comete de propósito (o do poço, puxar para dentro em vez de empurrar) é três ordens maior.
const FOLGA_POSICAO := 0.00005

var breaks := 0
var notes: Array[String] = []
## Rótulo do seletor de alvo colhido em cada varredura, por separação e por lado da estrela. A
## radiação só interessa se a cegueira aparecer na ponte: a barra ler %d contato(s) é o número, e
## `NÃO IDENTIFICADO` no seletor é o jogo.
var rotulos: Dictionary = {}

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

func _corpo(game, indice: int) -> Dictionary:
	return game._collision_bodies()[indice]

## O corpo do tabuleiro a uma distância radial escolhida do disco, na direção dada. As seções que
## precisam de geometria exata não podem depender de onde a formação nasceu.
func _colar_na_dado(game, indice: int, direcao: Vector3, distancia: float) -> Node3D:
	var node: Node3D = _corpo(game, indice)["node"]
	node.global_position = ESTRELA_POS + direcao.normalized() * distancia
	return node

## Afastar tudo da corona, mas dentro do alcance do vento, ao longo de raios determinísticos (o
## ângulo áureo do índice, o mesmo do cinturão). Ordem fixa = ordem de `_collision_bodies`: frota,
## hostis e por último a ponte. Nenhum sorteio na montagem.
func _afastar_da_corona(game) -> void:
	var corpos: Array = game._collision_bodies()
	for i in range(corpos.size()):
		var node: Node3D = (corpos[i] as Dictionary)["node"]
		var ang := float(i) * 2.39996
		var dir := Vector3(cos(ang), sin(ang * 0.7) * 0.25, sin(ang)).normalized()
		node.global_position = ESTRELA_POS + dir * (40.0 + float(i) * 3.0)

## Estado de combate de um casco em uma linha. Serve para provar que o vento não mexe em número.
func _assinatura_combate(unidade: Dictionary) -> String:
	return "%0.4f/%0.4f/%0.4f/%0.4f" % [float(unidade["hp"]), float(unidade["engines"]),
		float(unidade["weapons"]), float(unidade["crew"])]

## ---- 1. Fiação ----------------------------------------------------------------------------
## O «desligado não move número» da casa, na forma do vento. A medição é pareada — o MESMO casco no
## MESMO ponto, um lado sem estrela e o outro com — porque «não andou» com a estrela ligada seria
## verde por ausência.
func _secao_fiacao(game) -> void:
	game._montar_cenario("ABERTO")
	var casquito: Node3D = _colar_na_dado(game, 0, Vector3(0.0, 0.0, 1.0), 40.0)
	var onde_apagada: Vector3 = casquito.global_position
	game._aplicar_cenario(PASSO)
	var deriva_apagada := onde_apagada.distance_to(casquito.global_position)
	_assert("estrela apagada: o quadro de cenário não encosta no casco",
		not bool(game.estrela_ativa) and _igual(deriva_apagada, 0.0, 0.000001),
		"%0.6f u de deriva no quadro com estrela=%s" % [deriva_apagada, game.estrela_ativa])
	_assert("estrela apagada: a varredura vale o raio inteiro até no centro do disco",
		_igual(float(game._fator_radiacao(ESTRELA_POS)), 1.0, 0.000001)
		and _igual(float(game._fator_radiacao(ESTRELA_POS + Vector3(0.0, 0.0, 40.0))), 1.0, 0.000001),
		"fator no centro e a 40 u do disco apagado: 1,00 / 1,00")
	game._montar_cenario("ESTRELA")
	var casco: Node3D = _colar_na_dado(game, 0, Vector3(0.0, 0.0, 1.0), 40.0)
	var onde_acesa: Vector3 = casco.global_position
	game._aplicar_cenario(PASSO)
	var deriva_acesa := onde_acesa.distance_to(casco.global_position)
	_assert("estrela acesa: o mesmo casco no mesmo ponto anda um quadro de vento",
		bool(game.estrela_ativa) and _igual(deriva_acesa, PASSO_A_40, FOLGA_POSICAO),
		"%0.6f u no quadro a 40 u do disco (esperado %0.6f)" % [deriva_acesa, PASSO_A_40])
	_assert("o vento não mexe no que o calor já fazia: arma a 40 u bate 1,25",
		_igual(float(game._fator_calor(ESTRELA_POS + Vector3(0.0, 0.0, 40.0))),
			ESTRELA_CALOR_FATOR, 0.000001),
		"a 40 u do disco: %0.2f" % float(game._fator_calor(ESTRELA_POS + Vector3(0.0, 0.0, 40.0))))

## ---- 2. A lei ------------------------------------------------------------------------------
## Três portas do empurrão, cada uma conferida no número: o peso linear, o corte no alcance e a
## guarda do centro. A direção é cobrada eixo a eixo, porque um vetor trocado de sinal (o do poço,
## que puxa para dentro) manteria a asserção de módulo verde.
func _secao_lei(game) -> void:
	game._montar_cenario("ESTRELA")
	for par in [[20.0, 2.375], [40.0, 1.75], [80.0, 0.5], [95.9, 0.003125]]:
		var distancia := float(par[0])
		var acelerado := float(par[1])
		var casco: Node3D = _colar_na_dado(game, 1, Vector3(1.0, 0.0, 0.0), distancia)
		var antes: Vector3 = casco.global_position
		game._empurrar_no_vento(PASSO)
		var passo_vetor: Vector3 = casco.global_position - antes
		var modulo := passo_vetor.length()
		_assert("a %0.1f u o peso linear dá o passo anunciado (%0.3f u/s)" % [distancia, acelerado],
			_igual(modulo, acelerado * PASSO, FOLGA_POSICAO),
			"%0.6f u no quadro (esperado %0.6f)" % [modulo, acelerado * PASSO])
		_assert("e o empurrão sai do disco reto, eixo a eixo, sem componente de tangente",
			_igual(passo_vetor.x, modulo, 0.000001)
			and _igual(passo_vetor.y, 0.0, 0.000001)
			and _igual(passo_vetor.z, 0.0, 0.000001),
			"passo (%0.6f, %0.6f, %0.6f) a %0.1f u na direção +x" % [passo_vetor.x, passo_vetor.y,
				passo_vetor.z, distancia])
	var fora: Node3D = _colar_na_dado(game, 2, Vector3(0.0, 1.0, 0.0), ESTRELA_VENTO_ALCANCE + 5.0)
	var fora_antes: Vector3 = fora.global_position
	game._empurrar_no_vento(PASSO)
	_assert("fora do alcance o vento não chega: a 101 u o casco fica onde está",
		_igual(fora_antes.distance_to(fora.global_position), 0.0, 0.000001),
		"deriva %0.6f u além da borda" % fora_antes.distance_to(fora.global_position))
	var exato: Node3D = _colar_na_dado(game, 3, Vector3(0.0, 0.0, 1.0), ESTRELA_VENTO_ALCANCE)
	var exato_antes: Vector3 = exato.global_position
	game._empurrar_no_vento(PASSO)
	_assert("no alcance exato a borda é fechada: peso zero é passo zero",
		_igual(exato_antes.distance_to(exato.global_position), 0.0, 0.000001),
		"deriva %0.6f u exatamente a 96 u" % exato_antes.distance_to(exato.global_position))
	var centro: Node3D = _colar_na_dado(game, 4, Vector3(0.0, 0.0, 1.0), 0.0)
	var centro_antes: Vector3 = centro.global_position
	game._empurrar_no_vento(PASSO)
	_assert("no centro do disco não há para onde empurrar: a guarda segura o quadro",
		_igual(centro_antes.distance_to(centro.global_position), 0.0, 0.000001),
		"deriva %0.6f u com o casco colado no centro" % centro_antes.distance_to(centro.global_position))

## ---- 3. O mar do vento ----------------------------------------------------------------------
## A lei é posicional, então a própria marcha emagrece o passo: a distância cresce sempre e assíntota
## no alcance. Forma fechada espelhada em `pow` conferida contra a integração quadro a quadro do
## jogo — se o empurrão fosse somado em `vel` em vez de em posição, este número desencontra.
func _secao_mar(game) -> void:
	game._montar_cenario("ESTRELA")
	var casco: Node3D = _colar_na_dado(game, 0, Vector3(0.0, 0.0, 1.0), 40.0)
	var d0 := casco.global_position.distance_to(ESTRELA_POS)
	var d_ultima := d0
	var passo_maximo := 0.0
	var caminho := 0.0
	var monotono := true
	var atravessou := false
	for quadro in range(QUADROS):
		var antes: Vector3 = casco.global_position
		game._empurrar_no_vento(PASSO)
		var agora := casco.global_position.distance_to(ESTRELA_POS)
		var passo := antes.distance_to(casco.global_position)
		caminho += passo
		passo_maximo = maxf(passo_maximo, passo)
		if agora < d_ultima - 0.000001:
			monotono = false
		if agora > ESTRELA_VENTO_ALCANCE:
			atravessou = true
		d_ultima = agora
	var fator := 1.0 - ESTRELA_VENTO_ACEL * PASSO / ESTRELA_VENTO_ALCANCE
	var esperado := ESTRELA_VENTO_ALCANCE - (ESTRELA_VENTO_ALCANCE - d0) * pow(fator, QUADROS)
	_assert("%d quadros de vento batem a forma fechada da lei" % QUADROS,
		_igual(d_ultima, esperado, 0.0005),
		"%0.4f u de distância final contra %0.4f u da conta em RAM" % [d_ultima, esperado])
	_assert("a marcha só afasta: nenhum casco é puxado de volta pelo próprio vento",
		monotono, "distância %0.4f -> %0.4f u em %d quadros" % [d0, d_ultima, QUADROS])
	_assert("e o alcance é assíntota, não parede: ninguém o atravessa",
		not atravessou and d_ultima < ESTRELA_VENTO_ALCANCE,
		"máxima %0.4f u contra a borda de %0.0f u" % [d_ultima, ESTRELA_VENTO_ALCANCE])
	_assert("o vento anda de verdade: sessenta segundos dão %0.2f u de correnteza" % caminho,
		caminho > 40.0 and _igual(caminho, d_ultima - d0, 0.001),
		"%0.2f u de caminho contra %0.2f u de deslocamento líquido: o casco escorrega, não vagueia" % [
			caminho, d_ultima - d0])
	_assert("o passo por quadro cabe no teto analítico: %0.4f u contra %0.3f" % [passo_maximo,
		ESTRELA_VENTO_ACEL * PASSO],
		passo_maximo <= ESTRELA_VENTO_ACEL * PASSO + 0.000001,
		"maior passo %0.6f u em %d quadros" % [passo_maximo, QUADROS])

## ---- 4. Destroço é âncora --------------------------------------------------------------------
## `_collision_bodies` marca de `imovel` por casco zero e o vento respeita a marca. O controle mora
## no mesmo raio, noutra distância: se o `continue` do destroço fosse o único caminho, os dois
## ficariam parados e a asserção do destroço estaria verde por ausência.
func _secao_ancora(game) -> void:
	game._montar_cenario("ESTRELA")
	var baixada: Dictionary = _corpo(game, 6)
	var viva: Dictionary = _corpo(game, 7)
	var node_baixada: Node3D = baixada["node"]
	var node_viva: Node3D = viva["node"]
	var unidade_baixada: Dictionary = baixada["unidade"]
	unidade_baixada["hp"] = 0.0
	game._mark_wreck(node_baixada)
	var radial := Vector3(0.0, 0.0, 1.0)
	node_baixada.global_position = ESTRELA_POS + radial * 40.0
	node_viva.global_position = ESTRELA_POS + radial * 80.0
	var onde_baixada: Vector3 = node_baixada.global_position
	var onde_viva: Vector3 = node_viva.global_position
	game._empurrar_no_vento(PASSO)
	var anda_baixada := onde_baixada.distance_to(node_baixada.global_position)
	var esperado_viva := ESTRELA_VENTO_ACEL * (1.0 - 80.0 / ESTRELA_VENTO_ALCANCE) * PASSO
	var anda_viva := onde_viva.distance_to(node_viva.global_position)
	_assert("baixado não é empurrado: o destroço continua onde caiu",
		_igual(anda_baixada, 0.0, 0.000001) and float(unidade_baixada["hp"]) <= 0.0,
		"%0.6f u de deriva num casco morto a 40 u do disco" % anda_baixada)
	_assert("a viva no mesmo quadro anda: o teste tem controle, não ausência",
		_igual(anda_viva, esperado_viva, FOLGA_POSICAO),
		"%0.6f u a 80 u (esperado %0.6f)" % [anda_viva, esperado_viva])
	unidade_baixada["hp"] = 100.0

## ---- 5. O vento não fere nem cobra ------------------------------------------------------------
## Locomoção não é dano. Cada número de combate fica byte a byte, inclusive `veloc`: o vento desvia a
## posição e não entra na conta de empuxo do casco. A decisão é consciente e o preço dela é honesto
## — o abalroamento continua cobrando a velocidade que a ordem deu, e o passo de vento nunca chega
## perto dos %0.1f u/s de aproximação que ele exige.
func _secao_custo(game) -> void:
	game._montar_cenario("ESTRELA")
	_afastar_da_corona(game)
	var alvo: Dictionary = _corpo(game, 8)
	var node: Node3D = alvo["node"]
	var unidade: Dictionary = alvo["unidade"]
	var assinatura_antes := _assinatura_combate(unidade)
	unidade["veloc"] = Vector3(1.25, 0.0, -0.5)
	var veloc_antes: Vector3 = unidade["veloc"]
	var capital_hp_antes := float(game.capital_hp)
	var onde: Vector3 = node.global_position
	for quadro in range(10):
		game._empurrar_no_vento(1.0)
	_assert("dez segundos de vento não tiram um ponto de nada",
		_assinatura_combate(unidade) == assinatura_antes,
		"hp/motores/armas/tripulação %s -> %s" % [assinatura_antes, _assinatura_combate(unidade)])
	_assert("nem na ponte: o vento derrapa a capitânia sem cozinhar o casco",
		_igual(float(game.capital_hp), capital_hp_antes, 0.000001),
		"casco da ponte %0.2f%% antes e depois, com todos os corpos fora da corona" % capital_hp_antes)
	_assert("e o empuxo do casco não é reescrito pelo vento: desvio de posição, não de velocidade",
		veloc_antes.distance_to(unidade["veloc"]) < 0.000001,
		"veloc %s -> %s" % [veloc_antes, unidade["veloc"]])
	var deslocado := onde.distance_to(node.global_position)
	_assert("o tabuleiro anda mesmo: dez quadros de 1,0 s deram %0.2f u de deslocamento" % deslocado,
		deslocado > 1.0, "o casco saiu do ponto e nenhum número dele mudou")
	_assert("e o vento sozinho não pode abalroar: o teto de passo é um quinto do que o impacto cobra",
		ESTRELA_VENTO_ACEL * PASSO * 2.0 < RAM_SPEED,
		"dois cascos em raios vizinhos fecham no máximo %0.2f u/s contra %0.1f u/s exigidos" % [
			ESTRELA_VENTO_ACEL * PASSO * 2.0, RAM_SPEED])

## ---- 6. Radiação cega a varredura -------------------------------------------------------------
## A conta é a metade do raio que a sonda já tinha, então o teste é um hostil a 7,0 u: dentro dos
## 9,0 u do campo aberto e fora dos 4,5 u sob a tempestade. Os outros dois pontos da régua — 4,0 u,
## lido nos dois lados, e 20,0 u, perdido nos dois — impedem que «desligar a sonda» passe por
## «encolher a sonda».
func _secao_radiacao(game) -> void:
	game._montar_cenario("ESTRELA")
	var dentro := float(game._fator_radiacao(ESTRELA_POS + Vector3(0.0, 0.0, 40.0)))
	var borda := float(game._fator_radiacao(ESTRELA_POS
		+ Vector3(0.0, 0.0, ESTRELA_RADIAO_RAIO)))
	var fora := float(game._fator_radiacao(ESTRELA_POS
		+ Vector3(0.0, 0.0, ESTRELA_RADIAO_RAIO + 1.0)))
	_assert("a radiação tem borda: %0.1f dentro de %0.0f u e 1,0 fora" % [
		ESTRELA_RADIAO_VARREDURA, ESTRELA_RADIAO_RAIO],
		_igual(dentro, ESTRELA_RADIAO_VARREDURA, 0.000001)
		and _igual(borda, ESTRELA_RADIAO_VARREDURA, 0.000001)
		and _igual(fora, 1.0, 0.000001),
		"a 40 u, 120 u e 121 u do disco: %0.2f / %0.2f / %0.2f" % [dentro, borda, fora])
	for separacao in [4.0, 7.0, 20.0]:
		var distancia := float(separacao)
		var vistos_acesa := _medir_varredura(game, true, distancia)
		var vistos_apagada := _medir_varredura(game, false, distancia)
		if distancia < PROBE_SCAN_RADIUS * ESTRELA_RADIAO_VARREDURA:
			_assert("a %0.1f u a sonda lê nos dois lados: a tempestade encolhe, não apaga" % distancia,
				vistos_apagada == 1 and vistos_acesa == 1,
				"%d contato no campo aberto, %d sob a radiação" % [vistos_apagada, vistos_acesa])
		elif distancia <= PROBE_SCAN_RADIUS:
			_assert("a %0.1f u o hostil existe no campo aberto e some sob a tempestade" % distancia,
				vistos_apagada == 1 and vistos_acesa == 0,
				"%d contato sem estrela (raio 9,0), %d com a estrela (raio 4,5)" % [vistos_apagada,
					vistos_acesa])
		else:
			_assert("a %0.1f u ninguém lê em lado nenhum: a régua não inventou contato" % distancia,
				vistos_apagada == 0 and vistos_acesa == 0,
				"%d contato no campo aberto, %d sob a radiação" % [vistos_apagada, vistos_acesa])
	## A consequence na ponte: o mesmo hostil, na mesma separação, com e sem tempestade. Sem o
	## rótulo colhido dos dois lados a asserção seria verde por UI ausente — os dois lados têm de
	## existir, um tem de ler casco e o outro tem de dizer que não sabe.
	var sob := String(rotulos.get("7.0/acesa", ""))
	var sem := String(rotulos.get("7.0/aberta", ""))
	_assert("a cegueira vira jogo: sem leitura a ponte não anuncia o casco",
		not sob.is_empty() and not sem.is_empty() and sob.contains("NÃO IDENTIFICADO")
		and sem.contains("CASCO"),
		"sob a tempestade «%s», no campo aberto «%s»" % [sob, sem])

## Uma corrida de varredura: sonda a 40 u do disco e um hostil a `separacao` u da sonda. Devolve os
## contatos que a barra do painel registrou. A estrela entra por `_montar_cenario`, não por flag
## solta: a radiação tem de ser conferida pelo caminho que o jogo percorre.
func _medir_varredura(game, com_estrela: bool, separacao: float) -> int:
	game._montar_cenario("ESTRELA" if com_estrela else "ABERTO")
	var sondinha: Node3D = game._make_probe(ESTRELA_POS + Vector3(0.0, 0.0, 40.0))
	var hostil: Dictionary = game.enemies[0]
	var node_hostil: Node3D = hostil["node"]
	hostil["hp"] = 100.0
	hostil["seen"] = false
	game.enemies[0] = hostil
	node_hostil.global_position = sondinha.global_position + Vector3(0.0, 0.0, -separacao)
	var estado_antes := int(game.rng.state)
	game._scan_with_probe(sondinha)
	game._recompute_recon()
	game._update_hud()
	if is_instance_valid(game.target_selector):
		rotulos["%0.1f/%s" % [separacao, "acesa" if com_estrela else "aberta"]] = String(
			game.target_selector.get_item_text(0))
	var contatos := int(game.recon_contacts)
	var lido := bool(game.enemies[0].get("seen", false))
	_assert("a varredura não sorteia nada, com estrela ou sem",
		int(game.rng.state) == estado_antes and (contatos == 1) == lido,
		"rng %d intocado, %d contato(s) na barra contra lido=%s a %0.1f u" % [estado_antes,
			contatos, lido, separacao])
	sondinha.free()
	return contatos

## ---- 7. Painel ---------------------------------------------------------------------------------
## O número que a ponte anuncia é o que a lei usa. Sem esta asserção o comandante lê 96 u e o casco
## sente outro alcance, e nada no engine reclama.
func _secao_painel(game) -> void:
	game._montar_cenario("ESTRELA")
	var nota_estrela: String = String(game._nota_cenario())
	_assert("a ficha da estrela entrega o vento e a radiação",
		nota_estrela.find("vento") >= 0 and nota_estrela.find("radia") >= 0
		and nota_estrela.find("96") >= 0 and nota_estrela.find("120") >= 0
		and nota_estrela.find("50%") >= 0,
		"%s" % nota_estrela)
	game._montar_cenario("ABERTO")
	var nota_aberta: String = String(game._nota_cenario())
	_assert("o campo aberto não mente sobre o que não está lá",
		nota_aberta.find("vento") < 0 and nota_aberta.find("radia") < 0,
		"%s" % nota_aberta)

## ---- 8. Cauda de sorteio ------------------------------------------------------------------------
## Doze cascos e a ponte andados por trinta segundos de vento, num lado com a estrela e no outro sem:
## os dois geradores não se movem e as duas caudas são idênticas. É a prova de que o vento é conta de
## posição — se alguém botar um `randf()` dentro do empurrão, é aqui que ele pega.
func _secao_cauda() -> void:
	var a := await _montar_jogo()
	var b := await _montar_jogo()
	a.rng.seed = 70707
	a.visual_rng.seed = 70707
	b.rng.seed = 70707
	b.visual_rng.seed = 70707
	a._montar_cenario("ABERTO")
	b._montar_cenario("ESTRELA")
	_afastar_da_corona(a)
	_afastar_da_corona(b)
	var estado_a := int(a.rng.state)
	var estado_b := int(b.rng.state)
	var visual_a := int(a.visual_rng.state)
	var visual_b := int(b.visual_rng.state)
	for quadro in range(CAUDA_QUADROS):
		a._aplicar_cenario(PASSO)
		b._aplicar_cenario(PASSO)
	var movidos := 0
	var corpos_a: Array = a._collision_bodies()
	var corpos_b: Array = b._collision_bodies()
	for i in range(corpos_a.size()):
		var pos_a: Vector3 = (corpos_a[i] as Dictionary)["node"].global_position
		var pos_b: Vector3 = (corpos_b[i] as Dictionary)["node"].global_position
		if pos_a.distance_to(pos_b) > 0.001:
			movidos += 1
	_assert("o vento andou o tabuleiro inteiro: a cauda não é verde por imobilidade",
		movidos == corpos_a.size(), "%d de %d corpos em ponto diferente do controle" % [movidos,
			corpos_a.size()])
	_assert("%d quadros de vento não empurram nenhum gerador" % CAUDA_QUADROS,
		int(a.rng.state) == estado_a and int(b.rng.state) == estado_b
		and int(a.visual_rng.state) == visual_a and int(b.visual_rng.state) == visual_b,
		"rng %d / visual_rng %d dos dois lados, antes e depois do laço" % [estado_a, visual_a])
	var cauda_a := ""
	var cauda_b := ""
	var cauda_visual_a := ""
	var cauda_visual_b := ""
	for d in range(40):
		cauda_a += "%d;" % int(a.rng.randi())
	for d in range(40):
		cauda_b += "%d;" % int(b.rng.randi())
	for d in range(40):
		cauda_visual_a += "%0.6f;" % float(a.visual_rng.randf())
	for d in range(40):
		cauda_visual_b += "%0.6f;" % float(b.visual_rng.randf())
	_assert("quarenta sorteios depois são idênticos dígito a dígito",
		cauda_a == cauda_b, "cauda %s" % cauda_a.substr(0, 42))
	_assert("nem o gerador do desenho se move: a estrela não gasta enfeite",
		cauda_visual_a == cauda_visual_b, "visual %s" % cauda_visual_a.substr(0, 42))
	a.queue_free()
	b.queue_free()
	await _frames(2)

func _initialize() -> void:
	var game: Node3D = await _montar_jogo()
	_secao_fiacao(game)
	_secao_lei(game)
	_secao_mar(game)
	_secao_ancora(game)
	_secao_custo(game)
	_secao_radiacao(game)
	_secao_painel(game)
	await _secao_cauda()
	notes.append("veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	for linha in notes:
		print("SONDA-ESTRELA: %s" % linha)
	game.queue_free()
	await _frames(2)
	quit()
