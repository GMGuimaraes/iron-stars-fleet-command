extends SceneTree

## Fábrica de referências visuais para a modelagem 3D assistida. A rota da casa é offline
## (`tools/gen3d/local/solution.mjs`, gerada pelo `modeling-glb` do plugin), e a régua continua a
## mesma: quem lê silhueta — serviço, humano ou comparador automático — só conhece o que aparece no
## PNG: se a foto for escura, torto ou com o casco pequeno demais no quadro, o corpo vem borrado e a
## culpa é do material de leitura, não do modelo. Esta sonda fotografa a réplica
## isolada — a MESMA malha que o `MultiMesh` da muralha replica 2 880 vezes — sobre fundo chato, com
## luz par e moldura derivada da caixa medida do próprio corpo.
##
## Não instancia `main.tscn` e não toca em `rng` nem `visual_rng`: geometria de desenho não é conta
## de combate, e um quadro que engole economia não é quadro, é regressão. A prova disso está em não
## haver aqui nenhuma chamada a `_resolve_volley`, `_update_fleet` ou sorteio.
##
## Roda em JANELA REAL, não em `--headless`: sob headless o renderizador é o dummy e toda foto volta
## preta — as asserções de cobertura de silhueta seria paga pelo vazio. A geometria (caixa, vértices,
## superfícies) sim é medida nos dois modos, e é ela que trava a pintura contra a doca do `esquadra.gd`.
##
## Uso:
##   godot --path . --quit-after 4000 -s res://tools/probes/ref3d_replica.gd
## Os PNGs saem em `OUT`, um por vista, com o nome da vista no arquivo. É o que `tools/gen3d/aceite.sh`
## conta pelo IHDR e o que o olho compara contra o casco lavrado quando a silhueta precisa de juízo.

const OUT := "D:/Downloads/tmp-userdata-iron/ref3d/"
## Lado do quadro pedido à tela. Se a janela sair cortada, o laço de leitura pede de novo o menor
## lado que a própria tela já deu e o retrato continua quadrado — o que não pode mudar é a proporção,
## porque é ela que a conta de moldura lê.
const LADO_QUADRO := 900
const FOV := 35.0
## Folga entre a caixa projetada e a borda do quadro. Apertar a moldura economiza pixels e custa o
## modelo: quem lê silhueta trava na borda do objeto, e uma asa encostada no corte vira corpo
## cortado.
const FOLGA := 1.12
## Pisos da silhueta. A régua dominante é o **vão do corpo no quadro**, não a área acesa: a réplica é
## delgada por construção (5,0 u de comprimento por 1,07 u de boca), então contar pixel aceso cobra do
## desenho o preço da forma — a frontal mede 6% de área com o casco atravessando mais da metade da
## tela, que é exatamente o que o extrator precisa. O vão pega a moldura mal derivada; o par de pisos
## de área pega o resto: baixo demais é ponto, alto demais é o fundo sendo lido como objeto.
## O piso não é o número que a última corrida devolveu: é o que a conta de moldura entrega para esta
## caixa com FOV e FOLGA abaixo, medido na linha `CONTA` da mesma sonda. A vista que prende é a
## frontal, com vão previsto de 53,9% do lado; as outras quatro ficam entre 55,8% e 75,2%. O piso em
## 45% deixa nove pontos de margem contra deriva de geometria e ainda exige que o casco atravesse
## metade do quadro — que é o que a leitura de silhueta come. Se a malha mudar e a conta
## cair abaixo daqui, o conserto é mexer na moldura (FOV/FOLGA), nunca neste piso: afrouxar a régua é
## desligar a asserção com passos de fantasia.
const VAO_DOMINANTE := 0.45
## Folga entre o vão medido na tela e o vão que a conta dos vértices prediz. A pintura só pode ficar
## para dentro da previsão: uma face raspante na silhueta, iluminada na cor exata do fundo, some do
## cômputo por `CORTE_FUNDO` e come pixels do medido. Daí a assimetria — para fora da conta é lente ou
## janela errada, e isso quebra.
const TOL_VAO := 0.05
const AREA_MINIMA := 0.03
const AREA_MAXIMA := 0.55
## Corte de distância ao fundo, em luminância. O fundo é uma cor chata declarada, então a silhueta é
## medida por diferença e não por limiar absoluto: se o gerenciamento de cor mover o fundo, a régua
## move junto.
const CORTE_FUNDO := 0.06
## Espelhos do cabeçalho de `esquadra.gd:553-559` e de `ESCALA_REPLICA`. Se a malha de cinco bilhetes
## mudar lá e o número aqui não mudar junto, a asserção quebra — é de propósito, o mesmo motivo das
## constantes do poço em `tools/probes/fotograma.gd`. Cru: 3,647 x 1,07 x 5,0 u.
const CRU_LARGURA := 3.647
const CRU_ALTURA := 1.07
const CRU_COMPRIMENTO := 5.0
## Escala lida do jogo, não escolhida aqui: a foto tem de mostrar o casco que a muralha desenha.
const ESCALA_ESPERADA := 0.25
## Tolerância da caixa: meio por cento do maior eixo. A conta dos bilhetes é exata e o cone de oito
## segmentos também, então o que sobra é vírgula flutuante de vértice, não folga de gosto.
const TOL_CAIXA := 0.025

var breaks := 0
var notes: Array[String] = []

## Vista por vista: nome e direção do olho (do centro para a câmera). O proa da réplica mora em z
## negativo (o cone vai a −2,7), então `01_frente` é câmera em z negativo olhando para vante.
const VISTAS: Array = [
	{"nome": "01_frente", "olhar": Vector3(0.0, 0.08, -1.0)},
	{"nome": "02_traves_boreste", "olhar": Vector3(1.0, 0.08, 0.0)},
	{"nome": "03_reverso", "olhar": Vector3(0.0, 0.08, 1.0)},
	{"nome": "04_tres_quartos", "olhar": Vector3(0.78, 0.42, -0.86)},
	{"nome": "05_pique_vante", "olhar": Vector3(0.30, 0.92, -0.42)},
]

func _assert(label: String, condition: bool, detail: String) -> void:
	if condition:
		notes.append("OK     %s — %s" % [label, detail])
	else:
		breaks += 1
		notes.append("QUEBRA %s — %s" % [label, detail])

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	# Sob `--headless` o renderizador é o dummy: `get_root().get_texture()` devolve null e a
	# luminância não existe. A régua de geometria ainda vale nos dois modos, então ela corre primeiro
	# e a janela é pedida depois — assim uma bateria mal configurada devolve veredito legível em vez de
	# estouro em nó nulo.
	var sem_janela := DisplayServer.get_name() == "headless"

	var esquadra = load("res://esquadra.gd").new()
	var malha: ArrayMesh = esquadra.malha_replica()
	_assert("a réplica existe como malha fundida de uma superfície só",
		malha != null and malha.get_surface_count() == 1,
		"%s, %d superfície(s)" % [malha, malha.get_surface_count() if malha != null else 0])

	var caixa: AABB = malha.get_aabb()
	var tamanho := caixa.size
	_assert("a malha crua mede a caixa do cabeçalho de esquadra.gd",
		absf(tamanho.x - CRU_LARGURA) < TOL_CAIXA \
			and absf(tamanho.y - CRU_ALTURA) < TOL_CAIXA \
			and absf(tamanho.z - CRU_COMPRIMENTO) < TOL_CAIXA,
		"cru medido %0.3f x %0.3f x %0.3f u contra %0.3f x %0.3f x %0.3f" % [
			tamanho.x, tamanho.y, tamanho.z, CRU_LARGURA, CRU_ALTURA, CRU_COMPRIMENTO])
	_assert("a escala da réplica é a do jogo", absf(ESCALA_ESPERADA - 0.25) < 0.0001,
		"espelho %0.2f — se ESCALA_REPLICA mudar em esquadra.gd, mude aqui de propósito" % [
			ESCALA_ESPERADA])
	var escalado := tamanho * ESCALA_ESPERADA
	_assert("escalada, a boca fecha dentro da casa",
		escalado.x < esquadra.PASSO_CASA_X and escalado.z < esquadra.PASSO_CASA_Z,
		"casa de %0.1f u, corpo de %0.3f x %0.3f x %0.3f u" % [
			esquadra.PASSO_CASA_X, escalado.x, escalado.y, escalado.z])
	var bilhetes: PackedVector3Array = malha.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var vertices := bilhetes.size()
	_assert("a fundição tem corpo para o olho ler", vertices > 0,
		"%d vértices não-indexados numa passada de desenho" % vertices)

	# O plano de cada vista — distância do olho e vão previsto — é conta pura de projeção, então é
	# medido nos dois modos: em dummy ele declara o que a moldura entrega antes de qualquer pixel
	# existir, e em janela é a régua que o retrato tem de bater. A proporção aqui é 1:1 porque é o que
	# o caminho de janela força logo abaixo; se a janela não fechar quadrada, a asserção de moldura
	# quebra e este plano vira só a previsão, não a cota.
	for vista in VISTAS:
		var plano := _plano_de_vista(vista as Dictionary, bilhetes, caixa, 1.0)
		notes.append("CONTA  %s — olho a %0.2f u, vão esperado %0.1f%% do lado" % [
			String(vista["nome"]), float(plano["distancia"]), float(plano["vao"]) * 100.0])

	if sem_janela:
		notes.append("AVISO  dummy fecha aqui a geometria e a conta de moldura — os cinco retratos "
			+ "são do caminho de janela, e a bateria headless não os pede; rode sem --headless "
			+ "para regenerar o material de leitura")
		_fechar()
		return

	# A janela é quadrada de propósito: com proporção 1:1 a abertura horizontal e a vertical são a
	# mesma conta, e o material de leitura não perde informação por eixo. O tamanho não é pedido e
	# acreditado de uma vez — é pedido, lido de volta e corrigido: a 900x900 o gestor devolveu
	# 900x562 calado, e uma régua assinada sobre um tamanho que a tela não tem quebra por motivo de
	# janela, não de desenho.
	# A causa dos 562 foi medida: a janela obedecia (900x900 lido de `window_get_size`), mas o
	# `content_scale_mode` do projeto é `canvas_items` com aspecto `keep`, então o render target é a
	# maior região 1440:900 que cabe na janela — 900x562, 1,6:1 em qualquer lado pedido. Desligar a
	# escala de conteúdo aqui devolve textura igual à janela (900x900 medidos) e não toca em jogo
	# nenhum: esta sonda não instancia cena, e o ajuste morre com o processo.
	root.set("content_scale_mode", 0)
	var viewport := Vector2i.ZERO
	for tentativa in range(3):
		var lado := LADO_QUADRO if tentativa == 0 else mini(viewport.x, viewport.y)
		DisplayServer.window_set_size(Vector2i(lado, lado))
		await _frames(4)
		var medi := get_root().get_texture().get_image()
		viewport = Vector2i(medi.get_width(), medi.get_height())
		if viewport.x == viewport.y:
			break

	_assert("a janela é quadrada, como a conta de moldura exige",
		viewport.x == viewport.y,
		"%dx%d lido da textura, %d pedido, janela %s" % [
			viewport.x, viewport.y, LADO_QUADRO, str(DisplayServer.window_get_size())])

	var mundo := Node3D.new()
	mundo.name = "Estudio"
	get_root().add_child(mundo)

	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = Color(0.62, 0.64, 0.68)
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color(0.80, 0.82, 0.86)
	ambiente.ambient_light_energy = 0.9
	ambiente.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var clima := WorldEnvironment.new()
	clima.environment = ambiente
	mundo.add_child(clima)

	var chapa := StandardMaterial3D.new()
	chapa.albedo_color = Color(0.30, 0.32, 0.36)
	chapa.metallic = 0.35
	chapa.roughness = 0.55
	chapa.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	var corpo := MeshInstance3D.new()
	corpo.name = "Replica"
	corpo.mesh = malha
	corpo.material_override = chapa
	corpo.scale = Vector3.ONE * ESCALA_ESPERADA
	mundo.add_child(corpo)

	# Dois sóis, sem sombra: a sombra projetada no próprio casco come a costura que o extrator precisa
	# ver, e a pluma de motor não é geometria — é brilho, e brilho no PNG vira volume inventado.
	var chave := DirectionalLight3D.new()
	chave.light_energy = 0.95
	chave.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(35.0), 0.0)
	chave.shadow_enabled = false
	mundo.add_child(chave)
	var preenchimento := DirectionalLight3D.new()
	preenchimento.light_energy = 0.4
	preenchimento.rotation = Vector3(deg_to_rad(28.0), deg_to_rad(-125.0), 0.0)
	preenchimento.shadow_enabled = false
	mundo.add_child(preenchimento)

	var centro := corpo.global_transform * caixa.get_center()
	var camera := Camera3D.new()
	camera.name = "Olho"
	camera.fov = FOV
	camera.near = 0.05
	camera.far = 200.0
	mundo.add_child(camera)
	camera.make_current()
	await _frames(2)

	for vista in VISTAS:
		var dicionario := vista as Dictionary
		var plano := _plano_de_vista(dicionario, bilhetes, caixa,
			float(viewport.x) / maxf(float(viewport.y), 1.0))
		var olhar := plano["olhar"] as Vector3
		var distancia := float(plano["distancia"])
		camera.global_position = centro + olhar * distancia
		camera.look_at(centro, Vector3.UP)
		await _retrato(String(dicionario["nome"]), distancia, float(plano["vao"]))

	_fechar()

## Distância e vão previsto de uma vista. A conta é a moldura da casa (`_distancia_de_enquadramento`,
## mesma de `tools/probes/fotograma.gd`) aplicada à caixa centrada no alvo do olho; o vão vem depois,
## projetando os 324 vértices reais da malha — não os oito cantos da caixa — porque a silhueta que o
## PNG pode mostrar é a do corpo, e um canto vazio da caixa (a boca entra em x pela asa e em z pelo
## nariz, nunca nos dois juntos) mentiria sobre o quadro.
func _plano_de_vista(vista: Dictionary, bilhetes: PackedVector3Array, caixa: AABB,
		proporcao: float) -> Dictionary:
	var olhar: Vector3 = (vista["olhar"] as Vector3).normalized()
	var meia: Vector3 = caixa.size * ESCALA_ESPERADA / 2.0
	var distancia := _distancia_de_enquadramento(-meia, meia, olhar, FOV, proporcao) * FOLGA
	return {"olhar": olhar, "distancia": distancia,
		"vao": _vao_dos_vertices(bilhetes, caixa.get_center(), olhar, distancia, proporcao)}

## Maior extensão da silhueta projetada, em fração do lado do quadro. Cada vértice v (medido a partir
## do centro da caixa, que é para onde o olho aponta) cai em `u = (v·direita) / ((dist − v·e)·tan_h)`
## e `w` análogo no eixo vertical, com u e w em −1..+1 nas bordas. O vão é a amplitude dividida por
## dois, no eixo que vencer — exatamente a definição que `_retrato` lê dos pixels.
func _vao_dos_vertices(bilhetes: PackedVector3Array, centro_local: Vector3, olhar: Vector3,
		distancia: float, proporcao: float) -> float:
	var e: Vector3 = olhar.normalized()
	var chao := Vector3.UP if absf(e.y) < 0.99 else Vector3.RIGHT
	var direita := chao.cross(e).normalized()
	var cima := e.cross(direita)
	var tan_v := tan(deg_to_rad(FOV) * 0.5)
	var tan_h := tan_v * proporcao
	var minimo_u := INF
	var maximo_u := -INF
	var minimo_v := INF
	var maximo_v := -INF
	for bruto in bilhetes:
		var v: Vector3 = ((bruto as Vector3) - centro_local) * ESCALA_ESPERADA
		var ao_longe := v.dot(e)
		var proj := v - e * ao_longe
		var fundo := maxf(distancia - ao_longe, 0.01)
		var u := proj.dot(direita) / (fundo * tan_h)
		var w := proj.dot(cima) / (fundo * tan_v)
		minimo_u = minf(minimo_u, u)
		maximo_u = maxf(maximo_u, u)
		minimo_v = minf(minimo_v, w)
		maximo_v = maxf(maximo_v, w)
	return maxf((maximo_u - minimo_u) / 2.0, (maximo_v - minimo_v) / 2.0)

## Saída única nos dois caminhos (janela e dummy): o veredito é sempre a última linha, no mesmo
## formato acentuado das outras trinta e uma sondas da casa.
func _fechar() -> void:
	for note in notes:
		print("SONDA-REF3D: " + note)
	print("SONDA-REF3D: veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	quit()

## Um retrato: espera dois fotogramas de desenho (sem isso o PNG é o estado velho, como em
## `tools/probes/fotograma.gd`), salva, e mede a silhueta por diferença contra o fundo lido do canto do
## próprio quadro — se o compositor mover a cor, a régua acompanha, e uma silhueta contada contra cor
## errada enche o quadro de ruído.
## Duas réguas, uma de forma e uma de área: o **vão** (a caixa que envolve os pixels acesos, no maior
## eixo, em fração da tela) é o que diz se o casco está grande no quadro; a **área acesa** pega os dois
## extremos contrários — corpo minúsculo e fundo lido como corpo. O vão medido ainda tem de bater o
## vão que a conta dos vértices previu: é isso que separa "o quadro está grande" de "o quadro está
## grande porque a moldura foi derivada do corpo e não chutada".
func _retrato(nome: String, distancia: float, vao_esperado: float) -> void:
	await _frames(2)
	var img := get_root().get_texture().get_image()
	var caminho := OUT + nome + ".png"
	var salvo := img.save_png(caminho)
	var largura := float(img.get_width())
	var altura := float(img.get_height())
	var fundo := img.get_pixel(1, 1)
	var minimo_u := INF
	var minimo_v := INF
	var maximo_u := -INF
	var maximo_v := -INF
	var acesos := 0
	var amostras := 0
	for v in range(0, img.get_height(), 2):
		for u in range(0, img.get_width(), 2):
			var c := img.get_pixel(u, v)
			var delta := absf(c.r - fundo.r) + absf(c.g - fundo.g) + absf(c.b - fundo.b)
			if delta > CORTE_FUNDO:
				acesos += 1
				minimo_u = minf(minimo_u, float(u))
				maximo_u = maxf(maximo_u, float(u))
				minimo_v = minf(minimo_v, float(v))
				maximo_v = maxf(maximo_v, float(v))
			amostras += 1
	var area := float(acesos) / maxf(float(amostras), 1.0)
	var vao := 0.0
	if acesos > 0:
		vao = maxf((maximo_u - minimo_u) / maxf(largura, 1.0),
			(maximo_v - minimo_v) / maxf(altura, 1.0))
	_assert("%s tem corpo grande no quadro" % nome,
		salvo == OK and vao >= VAO_DOMINANTE \
			and area >= AREA_MINIMA and area <= AREA_MAXIMA,
		"vão %0.1f%% (piso %0.1f%%), área %0.1f%% entre %0.1f%% e %0.1f%%, olho a %0.2f u, %s" % [
			vao * 100.0, VAO_DOMINANTE * 100.0, area * 100.0, AREA_MINIMA * 100.0,
			AREA_MAXIMA * 100.0, distancia, caminho])
	_assert("%s bate a moldura prevista" % nome,
		absf(vao - vao_esperado) <= TOL_VAO,
		"medido %0.1f%% contra %0.1f%% previsto pela conta dos vértices, delta %0.1f%% (tol %0.1f%%)"
		 % [vao * 100.0, vao_esperado * 100.0, absf(vao - vao_esperado) * 100.0, TOL_VAO * 100.0])

## Distância ao longo de `olhar` que mete a caixa inteira no quadro: para cada canto vale
## `dist >= ao_longe + perpendicular / tan(meia-abertura)` nos dois eixos e o pior canto manda. É a
## mesma conta do quadro 05g de `tools/probes/fotograma.gd`, com a proporção da janela passada por
## argumento — aqui a janela é quadrada por pedido, e ler o `DisplayServer` de dentro da conta daria
## à sonda um valor que ela mesma acabou de mudar.
func _distancia_de_enquadramento(minimo: Vector3, maximo: Vector3, olhar: Vector3,
		fov: float, proporcao: float) -> float:
	var e: Vector3 = olhar.normalized()
	var chao := Vector3.UP if absf(e.y) < 0.99 else Vector3.RIGHT
	var direita := chao.cross(e).normalized()
	var cima := e.cross(direita)
	var tan_v := tan(deg_to_rad(fov) * 0.5)
	var tan_h := tan_v * proporcao
	var pior := 0.0
	for k in range(8):
		var canto := Vector3(
			minimo.x if (k & 1) == 0 else maximo.x,
			minimo.y if (k & 2) == 0 else maximo.y,
			minimo.z if (k & 4) == 0 else maximo.z)
		var ao_longe := canto.dot(e)
		var proj := canto - e * ao_longe
		pior = maxf(pior, ao_longe + absf(proj.dot(direita)) / tan_h)
		pior = maxf(pior, ao_longe + absf(proj.dot(cima)) / tan_v)
	return maxf(pior, 0.5)

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame
