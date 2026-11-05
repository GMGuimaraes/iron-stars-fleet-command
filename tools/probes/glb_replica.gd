extends SceneTree

## A outra metade do piloto da modelagem 3D assistida. O GLB existe, valida e é reproduzível a partir
## de `tools/gen3d/local/solution.mjs` — mas nada ainda jurava que ele BATE a réplica procedural
## dentro do motor. Esta sonda importa a cena, funde os nós dela numa `ArrayMesh` de uma superfície só
## e compara caixa crua, custo de vértices, materiais e vão projetado contra `malha_replica()` de
## `esquadra.gd`, no mesmo envelope.
##
## Por que fundir: `esquadra.gd:565-571` paga a conta da massa com UMA malha por time — 2 880 casas
## viram um `MultiMesh` e um lote. Um GLB de quatro malhas não entra na muralha como está. Se a fusão
## dele couber na mesma caixa e não custar mais vértices que a procedural, o casco desenhado troca
## desenho por desenho — não desenho por desempenho. É essa a pergunta que o comandante pagou para
## responder antes de importar seja o que for na cena.
##
## A resposta veio 2,19× acima do teto da muralha (236 triângulos desenhados contra os 108 da
## procedural), e o comandante escolheu PAPEL em vez de tesselação em 2026-11-04: a esquadra continua
## vestindo a procedural e o casco lavrado vive onde existe um corpo só — capitânia e planos de perto.
## Esta sonda então cobra as duas metades dessa frase: a caixa, os materiais e o vão do desenho, e a
## prova de que o desenho NÃO entrou na muralha. Cortar a régua de custo para caber seria apagar a
## conta, não medir melhor.
##
## Roda em `--headless` sem culpa, e é de propósito: aqui se lê geometria de recurso importado, não
## pixel. `ref3d_replica.gd` é a vizinha que precisa de janela real para os retratos; esta não precisa
## de nenhuma, porque as duas réguas — caixa e vão projetado — são conta de vértice, e conta de
## vértice é a mesma nos dois renderizadores.
##
## Não instancia `main.tscn`, não chama `rng` nem `visual_rng`: geometria de desenho não é conta de
## combate, e um quadro que engole economia não é quadro, é regressão.
##
## Uso:
##   godot --headless --path . --quit-after 4000 -s res://tools/probes/glb_replica.gd

const GLB := "res://assets/cascos/casco_replica.glb"

## Espelhos do cabeçalho de `esquadra.gd` (a caixa crua da réplica) e de `ESCALA_REPLICA`. Se a malha
## de cinco bilhetes mudar lá e o número aqui não mudar junto, a asserção quebra — é de propósito, o
## mesmo motivo dos espelhos em `ref3d_replica.gd:59-66`.
const CRU_LARGURA := 3.647
const CRU_ALTURA := 1.07
const CRU_COMPRIMENTO := 5.0
const ESCALA_ESPERADA := 0.25
## Tolerância da caixa: meio por cento do maior eixo, a mesma da vizinha. O loft do GLB e as caixas da
## procedural fecham nas MESMAS quinas por construção (costado ±1,8235, base −0,5, torre +0,57, proa
## −2,7, popa +2,3), então o que sobra é vírgula flutuante de vértice, não folga de gosto.
const TOL_CAIXA := 0.025
## Folga do vão projetado, RELATIVA ao vão da procedural. Diferente da caixa: aqui a régua não é a
## quina extrema, é a largura da silhueta em cada vista, e o GLB troca a face chata do costado por uma
## seção elíptica inscrita na mesma meia-boca. De frente as duas meias-bocas coincidem (a elipse está
## inscrita na caixa); numa diagonal, o canto duro da caixa varre um arco maior que a barriga da
## elipse, e o vão difere sem que face nenhuma saia da caixa medida — a régua dura das seis faces
## continua sendo a que segura o envelope. Medido na primeira corrida: pior caso o pique vante, 3,6%
## (0,147 u num vão de 4,127 u); a frente dá 3,5%. Com 5% sobra um ponto e meio de margem contra
## deriva, e silhueta de outra nave continua reprovando.
const TOL_VISTA_REL := 0.05
## A folha de um corpo solo: a outra malha importada da casa, cujo custo geométrico esta sonda MEDe em
## vez de copiar de doc. Não existe teto assinado aqui — o 108 da procedural continua sendo a régua da
## muralha, e a muralha continua procedural por decisão de 2026-11-04.
const GLB_DO_TRIPULANTE := "res://assets/tripulante.glb"
## O que o programa de modelagem emite e a cena tem de importar sem perda. Lidos de
## `qoder-gltf inspect --nodes`, não estimados: cinco nós de malha (corpo, proa, torre, duas asas),
## quatro malhas — o boreste É espelho e divide a malha do bombordo —, dois materiais.
const NOS_DE_MALHA := 5
const MALHAS := 4
const MATERIAIS := 2

## As cinco vistas de `ref3d_replica.gd:73-79`, copiadas e conferidas contra o arquivo-fonte abaixo.
## Não são gosto: são os olhos com que a fábrica de referência fotografa a réplica, então é com eles
## que a silhueta do GLB tem de bater a silhueta da procedural.
const VISTAS: Array = [
	{"nome": "01_frente", "olhar": Vector3(0.0, 0.08, -1.0)},
	{"nome": "02_traves_boreste", "olhar": Vector3(1.0, 0.08, 0.0)},
	{"nome": "03_reverso", "olhar": Vector3(0.0, 0.08, 1.0)},
	{"nome": "04_tres_quartos", "olhar": Vector3(0.78, 0.42, -0.86)},
	{"nome": "05_pique_vante", "olhar": Vector3(0.30, 0.92, -0.42)},
]

var breaks := 0
var notes: Array[String] = []

func _assert(label: String, condition: bool, detail: String) -> void:
	if condition:
		notes.append("OK     %s — %s" % [label, detail])
	else:
		breaks += 1
		notes.append("QUEBRA %s — %s" % [label, detail])

func _initialize() -> void:
	var esquadra = load("res://esquadra.gd").new()
	var procedural: ArrayMesh = esquadra.malha_replica()
	var caixa_proc: AABB = procedural.get_aabb()
	var bilhetes_proc: PackedVector3Array = \
		procedural.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]

	var recurso = load(GLB)
	_assert("o GLB importa como cena de nós 3D, não como malha solta", recurso is PackedScene,
		"%s" % [recurso])
	if not (recurso is PackedScene):
		_fechar()
		return

	var inst = (recurso as PackedScene).instantiate()
	var nos: Array = []
	_colher(inst, Transform3D(), nos)
	# A colheita já saiu da instância em valores (`xf` é transformada, `malha` é recurso contadado),
	# então o corpo pode morrer aqui: deixar Node3D vivo até o `quit()` é o que faz o `--headless`
	# imprimir RID leaked no fim e a rodada perder a régua de zero linha de erro.
	inst.free()
	_assert("a cena importada traz o corpo que o programa escreveu", nos.size() == NOS_DE_MALHA,
		"%d nó(s) de malha lidos contra %d do `solution.mjs`" % [nos.size(), NOS_DE_MALHA])
	for n in nos:
		# `%s` direto: `String(Objeto)` não é construtor no GDScript, e um `String(n["malha"])` aqui
		# aborta a sonda inteira com "Nonexistent 'String' constructor" no meio das asserções.
		notes.append("ARVORE %s — %s, %d triângulo(s) desenhado(s) por casco" % [
			n["nome"], _tipo_malha(n["malha"]), _triangulos(n["malha"])])

	# O boreste é espelho do bombordo e por isso deve dividir a MESMA malha: se a projeção do padrão
	# tivesse duplicado geometria, o custo de vértices da muralha subia 25% por uma simetria.
	# O nome importado é `casco_asa_boreste`, não a chave `casco.asa.boreste`: `part()` aceita `name`
	# e sai como HullBody/PortWing, mas `pattern()` não tem campo de nome, então o nó espelho chega
	# com a própria chave semântica — e o importador troca o ponto por underscore.
	var bombordo = _achar(nos, "PortWing")
	var boreste = _achar(nos, "casco_asa_boreste")
	_assert("a asa boreste é espelho de verdade: divide a malha da bombordo",
		bombordo != null and boreste != null \
			and bombordo["malha"] != null and bombordo["malha"] == boreste["malha"],
		"bombordo=%s boreste=%s (o nó espelho sai do programa com a chave semântica como nome)" % [
			bombordo["nome"] if bombordo != null else "<ausente>",
			boreste["nome"] if boreste != null else "<ausente>"])
	_assert("as duas asas fecham simétricas em x", bombordo != null and boreste != null \
			and absf(bombordo["xf"].origin.x + boreste["xf"].origin.x) < 1e-4 \
			and absf(boreste["xf"].origin.x - 1.0) < 1e-4,
		"bombordo x %0.4f, boreste x %0.4f u" % [
			bombordo["xf"].origin.x if bombordo != null else 0.0,
			boreste["xf"].origin.x if boreste != null else 0.0])
	var torre = _achar(nos, "BridgeTower")
	_assert("a torre está no andar da réplica", torre != null \
			and absf(torre["xf"].origin.y - 0.42) < 1e-4 \
			and absf(torre["xf"].origin.z + 0.4) < 1e-4,
		"y %0.4f, z %0.4f u contra 0,42 / −0,40 lidos de esquadra.gd" % [
			torre["xf"].origin.y if torre != null else 0.0,
			torre["xf"].origin.z if torre != null else 0.0])

	var fundido := _fundir(nos)
	var v_glb: PackedVector3Array = fundido["v"]
	var n_glb: PackedVector3Array = fundido["n"]
	_assert("a fusão dos nós cabe num único lote de desenho", fundido["superficies"] == NOS_DE_MALHA \
			and v_glb.size() > 0,
		"%d superfície(s) de origem viram um array só: %d bilhetes, %d triângulos desenhados por casco" \
			% [fundido["superficies"], v_glb.size(), fundido["tri"]])

	# Normais: o renderer do projeto é `gl_compatibility` e o metal da ponte é tudo difusa com normal.
	# Se o importador tivesse escrito normal nula, comprida ou faltando em metade dos bilhetes, a caixa
	# e o vão continuariam exatos e o casco viraria plástico preto na muralha.
	var normais_ok := n_glb.size() == v_glb.size()
	if normais_ok:
		for p in n_glb:
			if absf(p.length() - 1.0) > 1e-3:
				normais_ok = false
				break
	_assert("toda normal importada é unitária, uma por vértice", normais_ok,
		"%d normal(is) para %d vértice(s), comprimento 1 ± 1e-3" % [n_glb.size(), v_glb.size()])

	var caixa := AABB(fundido["min"] as Vector3,
		(fundido["max"] as Vector3) - (fundido["min"] as Vector3))
	_assert("a caixa crua do GLB mede a caixa do cabeçalho de esquadra.gd",
		absf(caixa.size.x - CRU_LARGURA) < TOL_CAIXA \
			and absf(caixa.size.y - CRU_ALTURA) < TOL_CAIXA \
			and absf(caixa.size.z - CRU_COMPRIMENTO) < TOL_CAIXA,
		"cru medido %0.3f x %0.3f x %0.3f u contra %0.3f x %0.3f x %0.3f" % [
			caixa.size.x, caixa.size.y, caixa.size.z, CRU_LARGURA, CRU_ALTURA, CRU_COMPRIMENTO])
	_assert("e bate a caixa da procedural eixo a eixo",
		absf(caixa.size.x - caixa_proc.size.x) < TOL_CAIXA \
			and absf(caixa.size.y - caixa_proc.size.y) < TOL_CAIXA \
			and absf(caixa.size.z - caixa_proc.size.z) < TOL_CAIXA,
		"GLB %0.4f x %0.4f x %0.4f contra procedural %0.4f x %0.4f x %0.4f u" % [
			caixa.size.x, caixa.size.y, caixa.size.z,
			caixa_proc.size.x, caixa_proc.size.y, caixa_proc.size.z])
	# Não basta o tamanho: se o GLB estivesse deslocado meio corpo para vante, a caixa teria o MESMO
	# volume e a muralha pintaria cada casa com a proa errada. As seis faces são a régua.
	# (Os dois trechos vêm colados dentro de parênteses antes do `%`: com `"a" + "b" % [x]` o formatador
	# só alcança o último literal, e o primeiro sai na tela com `%0.4f` escrito.)
	var faces := ("GLB [x %0.4f..%0.4f y %0.4f..%0.4f z %0.4f..%0.4f] contra procedural "
		+ "[x %0.4f..%0.4f y %0.4f..%0.4f z %0.4f..%0.4f] u") % [
		caixa.position.x, caixa.end.x, caixa.position.y, caixa.end.y,
		caixa.position.z, caixa.end.z,
		caixa_proc.position.x, caixa_proc.end.x, caixa_proc.position.y, caixa_proc.end.y,
		caixa_proc.position.z, caixa_proc.end.z]
	_assert("as seis faces batem, não só as medidas",
		absf(caixa.position.x - caixa_proc.position.x) < TOL_CAIXA \
			and absf(caixa.end.x - caixa_proc.end.x) < TOL_CAIXA \
			and absf(caixa.position.y - caixa_proc.position.y) < TOL_CAIXA \
			and absf(caixa.end.y - caixa_proc.end.y) < TOL_CAIXA \
			and absf(caixa.position.z - caixa_proc.position.z) < TOL_CAIXA \
			and absf(caixa.end.z - caixa_proc.end.z) < TOL_CAIXA,
		faces)

	var escalado := caixa.size * ESCALA_ESPERADA
	_assert("escalada a 0,25, o corpo fecha dentro da casa",
		escalado.x < esquadra.PASSO_CASA_X and escalado.z < esquadra.PASSO_CASA_Z,
		"casa de %0.1f x %0.1f u, corpo de %0.3f x %0.3f x %0.3f u" % [
			esquadra.PASSO_CASA_X, esquadra.PASSO_CASA_Z,
			escalado.x, escalado.y, escalado.z])
	_assert("a boca e o comprimento lidos da caixa são os da lei da grade",
		absf(escalado.x - 0.912) < 0.005 and absf(escalado.z - 1.25) < 0.005,
		"boca %0.3f u, comprimento %0.3f u contra 0,912 / 1,250 do cabeçalho" % [
			escalado.x, escalado.z])

	# A conta de desempenho da muralha: 2 880 cascos pintados por lado, um só lote por time. O triângulo é
	# a moeda — a procedural funde 108 e cada bilhete a mais no casco seria 2 880 a mais na passada. O
	# piloto mediu 236: 2,19×, 368 640 triângulos a mais num lado. Em 2026-11-04 o comandante respondeu à
	# régua com PAPEL, não com tesselação: a muralha continua vestindo a procedural e o casco lavrado
	# serve onde existe UM corpo só — a capitânia e os planos de perto. Duas asserções sustentam a
	# resposta e nenhuma apaga a conta. A primeira trava o papel — e desde 2026-11-04 ela trava os DOIS
	# cascos lavrados da casa: o piloto (`casco_replica.glb`, sem corpo em cena) e a vitrine da mesa
	# (`capitania_vitrine.glb`, corpo único em `holo_capitania`). A lei é da muralha, então mora aqui: se
	# alguém pendurar um deles na esquadra, esta sonda quebra junto com a dona do corpo. A segunda cobra
	# o teto de corpo solo, lido da outra malha da casa — os triângulos do tripulante rigged MEDIDOS
	# aqui, não copiados do README.
	_assert("a muralha continua vestindo a procedural: nenhum casco lavrado entra na esquadra",
		not _texto("res://esquadra.gd").contains("casco_replica") \
			and not _texto("res://esquadra.gd").contains("capitania_vitrine") \
			and not _texto("res://main.gd").contains("casco_replica") \
			and not _texto("res://main.tscn").contains("casco_replica") \
			and not _texto("res://main.tscn").contains("capitania_vitrine"),
		("esquadra e cena não citam `casco_replica` nem `capitania_vitrine`, e `main.gd` não cita o "
			+ "piloto — com %d triângulos por casco contra os %d da procedural (razão %0.3f, ou %0.0f "
			+ "triângulos a mais nos 2 880 de um lado) o papel deles é onde existe um corpo só") % [
				fundido["tri"], int(bilhetes_proc.size() / 3),
				float(fundido["tri"]) / float(int(bilhetes_proc.size() / 3)),
				float(fundido["tri"] - int(bilhetes_proc.size() / 3)) * 2880.0])
	var teto_corpo := _triangulos_do_tripulante()
	_assert("o casco desenhado cabe na folha de um corpo só", teto_corpo > 0 \
			and fundido["tri"] <= teto_corpo,
		("%d triângulos desenhados contra %d da outra malha da casa (`assets/tripulante.glb`, a folha "
			+ "que um corpo pago em cena já ocupa)") % [fundido["tri"], teto_corpo])

	var mats := _materiais(nos)
	_assert("a cena importa os dois materiais do programa, nem um a mais",
		mats.size() == MATERIAIS, "%d material(is) distinto(s) na cena" % mats.size())
	var mat_corpo = _material_de(bombordo)
	var mat_torre = _material_de(torre)
	_assert("os dois tons são dois tons: a torre lê mais escura que o casco",
		mat_corpo != null and mat_torre != null \
			and mat_torre.albedo_color.get_luminance() < mat_corpo.albedo_color.get_luminance(),
		"casco %0.4f e torre %0.4f de luminância, metal %0.2f / %0.2f" % [
			mat_corpo.albedo_color.get_luminance() if mat_corpo != null else -1.0,
			mat_torre.albedo_color.get_luminance() if mat_torre != null else -1.0,
			mat_corpo.metallic if mat_corpo != null else 0.0,
			mat_torre.metallic if mat_torre != null else 0.0])

	# Silhueta, eixo a eixo, nos cinco olhos da fábrica de referência. A caixa é conta de quinas; o vão
	# é conta de corpo — é aqui que um casco certo de medidas e torto de forma seria pego.
	for vista in VISTAS:
		var olhar: Vector3 = vista["olhar"]
		var v_g := _vao(v_glb, olhar)
		var v_p := _vao(bilhetes_proc, olhar)
		var delta := maxf(absf(v_g.x - v_p.x), absf(v_g.y - v_p.y))
		var regua := TOL_VISTA_REL * maxf(v_p.x, v_p.y)
		_assert("o vão de %s bate a procedural" % String(vista["nome"]), delta < regua,
			("GLB %0.3f x %0.3f u contra procedural %0.3f x %0.3f u; delta %0.4f u sobre folga "
				+ "%0.4f u (%0.1f%% do vão)") % [v_g.x, v_g.y, v_p.x, v_p.y, delta, regua,
					TOL_VISTA_REL * 100.0])

	# Os espelhos acima só valem enquanto a fonte não mudar. Um laço de texto é barato e é a única
	# forma de esta sonda avisar em vez de aprovar em silêncio uma malha nova.
	var fonte := _texto("res://esquadra.gd")
	_assert("os marcos espelhados de esquadra.gd continuam vivos na fonte",
		fonte.contains("Vector3(0.0, 0.42, -0.4)") \
			and fonte.contains("Vector3(lado * 1.0, -0.02, 0.6)") \
			and fonte.contains("Vector3(1.5, 0.6, 0.8)"),
		"torre, asas e popa lidas do arquivo: %d caracteres" % fonte.length())
	var vistas_irma := _texto("res://tools/probes/ref3d_replica.gd")
	_assert("as cinco vistas são as mesmas que ref3d_replica.gd fotografa",
		_vistas_batem(vistas_irma),
		"triplos lidos do bloco `const VISTAS` do arquivo-irmã e comparados a 1e-4")

	var bytes := _tamanho(GLB)
	notes.append("CONTA  GLB de %d bytes; fundido daria %d bilhetes não-indexados por lado da muralha" \
		% [bytes, v_glb.size()])
	# `quit()` acontece dentro desta função, com as locais ainda vivas: a casa exige zero linha de erro
	# na rodada, e malha viva no exit é exatamente uma linha de erro. As medidas já viraram número.
	procedural = null
	esquadra = null
	bombordo = null
	boreste = null
	torre = null
	mat_corpo = null
	mat_torre = null
	mats.clear()
	nos.clear()
	_fechar()

## Colhe nós de malha com a transformada composta até a raiz da instância, à mão. Fazer isso sem pôr o
## corpo na árvore é o que permite a sonda rodar em `--headless` sem depender de `NOTIFICATION_*`, e
## lê o que o importador escreveu, não o que a árvore resolveria depois.
func _colher(node: Node, xf_pai: Transform3D, out: Array) -> void:
	var local := Transform3D()
	if node is Node3D:
		local = (node as Node3D).transform
	var comp := xf_pai * local
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append({"nome": String(node.name), "xf": comp,
			"malha": (node as MeshInstance3D).mesh})
	for filho in node.get_children():
		_colher(filho, comp, out)

func _achar(nos: Array, nome: String) -> Variant:
	for n in nos:
		if String(n["nome"]) == nome:
			return n
	return null

## Funde os nós numa malha só, aplicando a transformada em vértice e em normal — o mesmo caminho de
## `_fundir` em `esquadra.gd`, pelo mesmo motivo: normal vai pela base e se renormaliza, senão o
## degradê de metal que a Compatibility lê da difusa se perde.
func _fundir(nos: Array) -> Dictionary:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var superfices := 0
	var triangulos := 0
	var minimo := Vector3(1e18, 1e18, 1e18)
	var maximo := Vector3(-1e18, -1e18, -1e18)
	for item in nos:
		var malha: Mesh = item["malha"]
		var xf: Transform3D = item["xf"]
		for s in range(malha.get_surface_count()):
			superfices += 1
			var a: Array = malha.surface_get_arrays(s)
			var vv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var nn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			var ordem := idx
			if ordem.is_empty():
				ordem = PackedInt32Array()
				for k in range(vv.size()):
					ordem.append(k)
			triangulos += ordem.size() / 3
			for k in ordem:
				var p := xf * vv[k]
				v.append(p)
				if nn.size() == vv.size():
					n.append((xf.basis * nn[k]).normalized())
				else:
					n.append(Vector3.UP)
				minimo = Vector3(minf(minimo.x, p.x), minf(minimo.y, p.y), minf(minimo.z, p.z))
				maximo = Vector3(maxf(maximo.x, p.x), maxf(maximo.y, p.y), maxf(maximo.z, p.z))
	return {"v": v, "n": n, "superficies": superfices, "tri": triangulos,
		"min": minimo, "max": maximo}

## Triângulos desenhados por uma malha importada — a moeda real da muralha. Contar vértices do GLB
## seria mentira: a cena é indexada, então os mesmos 108 triângulos da procedural aparecem aqui com
## muito menos bilhetes. O que a GPU mastiga é o triângulo, e é ele que se soma nos 2 880 cascos.
func _triangulos(malha: Mesh) -> int:
	var total := 0
	for s in range(malha.get_surface_count()):
		var a: Array = malha.surface_get_arrays(s)
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		if idx.is_empty():
			total += (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		else:
			total += idx.size() / 3
	return total

func _tipo_malha(malha: Mesh) -> String:
	return malha.get_class()

## Triângulos desenhados da outra malha importada da casa, medidos na cena que o motor monta — a folha
## que um corpo pago em cena já ocupa. O corpo do tripulante é uma `ArrayMesh` pendurada num
## `MeshInstance3D` dentro do `Skeleton3D`, então a mesma colheita desta sonda a alcança.
func _triangulos_do_tripulante() -> int:
	var cena = load(GLB_DO_TRIPULANTE)
	if not (cena is PackedScene):
		return 0
	var inst = (cena as PackedScene).instantiate()
	var nos: Array = []
	_colher(inst, Transform3D(), nos)
	var total := 0
	for n in nos:
		total += _triangulos(n["malha"])
	inst.free()
	return total

## Os materiais distintos realmente pendurados nas superfícies, não os declarados no arquivo. A
## regalia mora na malha (`surface_get_material`), não nos arrays: material não é item de `ArrayMesh`.
func _materiais(nos: Array) -> Array:
	var vistos: Array = []
	for item in nos:
		var malha: Mesh = item["malha"]
		for s in range(malha.get_surface_count()):
			var m = malha.surface_get_material(s)
			if m != null and not vistos.has(m):
				vistos.append(m)
	return vistos

func _material_de(item: Variant) -> StandardMaterial3D:
	if item == null:
		return null
	var malha: Mesh = item["malha"]
	if malha == null or malha.get_surface_count() == 0:
		return null
	return malha.surface_get_material(0) as StandardMaterial3D

## Vão projetado: as duas meias-larguras da silhueta no plano da vista, conta pura de vértice. É o
## número que a moldura de `ref3d_replica.gd` lê, aqui sem câmera e sem pixel.
func _vao(vertices: PackedVector3Array, olhar: Vector3) -> Vector2:
	var o := olhar.normalized()
	var apoio := Vector3.UP
	if absf(o.dot(apoio)) > 0.98:
		apoio = -Vector3.FORWARD
	var x := apoio.cross(o).normalized()
	var y := o.cross(x).normalized()
	var min_x := 1e18
	var max_x := -1e18
	var min_y := 1e18
	var max_y := -1e18
	for p in vertices:
		var px := p.dot(x)
		var py := p.dot(y)
		min_x = minf(min_x, px)
		max_x = maxf(max_x, px)
		min_y = minf(min_y, py)
		max_y = maxf(max_y, py)
	return Vector2(max_x - min_x, max_y - min_y)

## Comparação numérica, não de texto: nenhum formatador único reproduz `0.30` **e** `0.0` ao mesmo
## tempo (`%0.1f` dá `0.3`, `%0.2f` dá `0.00`), e uma asserção que quebrasse por vírgula flutuante de
## impressão não diria nada sobre a geometria. Lê o bloco `const VISTAS` do arquivo-irmã, refaz cada
## `Vector3(...)` em números e mede a distância ao vetor desta sonda.
func _vistas_batem(fonte: String) -> bool:
	var inicio := fonte.find("const VISTAS")
	if inicio < 0:
		return false
	var fim := fonte.find("\n]", inicio)
	if fim < 0:
		return false
	var partes := fonte.substr(inicio, fim - inicio).split("Vector3(")
	if partes.size() - 1 != VISTAS.size():
		return false
	for i in range(VISTAS.size()):
		var bruto: String = partes[i + 1]
		var fecha := bruto.find(")")
		if fecha < 0:
			return false
		var tokens := bruto.substr(0, fecha).split(",")
		if tokens.size() != 3:
			return false
		var lido := Vector3(float(tokens[0]), float(tokens[1]), float(tokens[2]))
		var meu: Vector3 = (VISTAS[i] as Dictionary)["olhar"]
		if lido.distance_to(meu) > 1e-4:
			return false
	return true

func _texto(caminho: String) -> String:
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t

func _tamanho(caminho: String) -> int:
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null:
		return -1
	var n := f.get_length()
	f.close()
	return n

func _fechar() -> void:
	for n in notes:
		print(n)
	print("VEREDITO glb_replica — quebras=%d • conferências=%d" % [breaks, notes.size()])
	quit(0 if breaks == 0 else 1)
