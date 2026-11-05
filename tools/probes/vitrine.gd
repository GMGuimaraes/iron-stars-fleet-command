extends SceneTree

## Sonda da vitrine: o primeiro casco lavrado por programa que existe como corpo numa cena do jogo.
##
## O comandante respondeu à conta de 236 contra 108 trocando o PAPEL, não a tesselação: a muralha de
## 2 880 cascos continua vestindo a procedural e o casco desenhado passa a viver onde há UM corpo só.
## O lugar escolhido foi a mesa holográfica da ponte — `holo_capitania` — porque é o único corpo do
## jogo que a lei de módulos não alcança: não tem ficha, não é unidade de frota e não entra na conta
## de blip por casco vivo. Esta sonda é o que prova que a escolha foi feita com a régua em dia, e não
## com a régua dobrada. Ela cobra quatro coisas:
##
## 1) O ARQUIVO BATE O PROGRAMA. Os números da primeira seção não são memória nem README: a caixa
##    crua, o número de nós de malha, os materiais e os bytes são medidos na cena que o importador
##    monta e comparados ao que `tools/gen3d/local/vitrine/solution.mjs` assinou no dry-run
##    (`expectBounds` e `budget`). Se o programa mudar sem a sonda mudar junto, quebra — é o contrato
##    dos espelhos, o mesmo de `glb_replica.gd:59-66`.
## 2) UMA MALHA, UM MATERIAL, UM CORPO. Os seis nós do GLB — cinco desenhos, porque a asa boreste é
##    `mirror` e instancia a malha da bombordo — viram UMA `ArrayMesh` de UMA superfície, não indexada:
##    248 triângulos desenhados × 3 = 744 bilhetes lidos DA CENA, contra os 236 únicos que o
##    `budget.maxTriangles` assina no arquivo. As normais têm de ser unitárias e uma por vértice (o
##    renderer é `gl_compatibility` e o metal é difusa com normal; normal torta é casco preto). Os três
##    materiais do desenho NÃO podem vazar para a cena: quem pinta a vitrine é o `material_override`
##    dourado, e é ele que a mesa lê.
## 3) A CENTRA E O ENVELOPE. `_cylinder` centraliza o corpo em `position`, e `manobra.gd:540` confere
##    exatamente essa posição — então a caixa local da vitrine tem de nascer centrada na origem, com o
##    tamanho escalado batendo `ESCALA_VITRINE`, dentro do aro `HOLO_RIM` e com a proa em −z como no
##    tabuleiro. Um casco certo de medidas e torto de centro mudaria de lugar na mesa sem quebra de
##    tamanho nenhum.
## 4) AS LEIS VIZINHAS CONTINUAM INTEIRAS. Este é o verdadeiro preço da fatia: a vitrine entrou numa
##    casa cercada por três asserções alheias (posição que segue o rig, apagão que esconde, restaurar
##    que devolve) e uma contagem (blip por casco vivo). Cada uma é re-medida aqui com o casco novo no
##    lugar, mais a inércia do desenho: `rng` e `visual_rng` intocados por colher geometria, malha
##    idêntica em duas colheitas, nenhum casco de frota vestindo a vitrine e a muralha continuando
##    procedural.
##
## Roda em `--headless`: as quatro réguas são conta de vértice e de nó, não pixel. A prova de que o
## casco lavrado SE PARECE com a silhueta do anime já foi paga por `ref3d_replica.gd` na procedural;
## esta sonda cuida de que ele exista, caiba e não pise em lei nenhuma.
##
## Uso:
##   godot --headless --path . --quit-after 1800 -s res://tools/probes/vitrine.gd

## ---- Espelhos do programa de modelagem (lidos do dry-run, não do gosto) ----
const VITRINE_GLB := "res://assets/cascos/capitania_vitrine.glb"
## Caixa crua assinada por `expectBounds`: 3,647058 × 1,6875 × 5,0000 u com proa em −z e mastro no topo.
const CRU_LARGURA := 3.647058
const CRU_ALTURA := 1.6875
const CRU_COMPRIMENTO := 5.0
## Nós de malha e malhas distintas: seis corpos na cena, cinco desenhos. A asa boreste é o `mirror`
## do programa e por isso INSTÂNCIA a malha da bombordo em vez de duplicar geometria — é essa
## diferença que as duas asserções abaixo cobram, e a razão pela qual o corpo desenhado paga 12
## triângulos a mais que o custo único declarado no arquivo.
const NOS_DE_MALHA := 6
const MALHAS_DISTINTAS := 5
## Custo ÚNICO (o que `budget.maxTriangles` crava no arquivo) e custo DESENHADO por casco (o que a
## cena paga, com a asa espelhada instanciada). Piloto tinha a mesma dupla: 224 assinados, 236
## desenhados, lidos por `glb_replica.gd`. Cortar a régua para fazer os dois números caberem na
## mesma asserção seria apagar a conta do espelho.
const TRIANGULOS_UNICOS := 236
const TRIANGULOS_DESENHADOS := 248
const MATERIAIS := 3
const BYTES := 15204
## Teto de byte é contrato: o `solution.mjs` crava `maxBytes` no medido, e um GLB que engordar sem o
## programa mudar é outro arquivo com o mesmo nome.
const TOL_CAIXA := 0.025

## ---- Espelhos de `main.gd` (a instância do jogo é não tipada; se o número mudar lá, quebra aqui) ----
const ESCALA_ESPERADA := 0.15
const HOLO_RIM := 2.85
const HUD_OURO := Color(0.82, 0.68, 0.34)
## O corpo escalado que a mesa deve mostrar: boca, altura e comprimento da caixa crua vezes a escala.
const ESC_LARGURA := 0.5470587
const ESC_ALTURA := 0.253125
const ESC_COMPRIMENTO := 0.75
## Folga da caixa escalada: meio por cento do eixo maior cru, já escalado — a mesma família de folga
## de `TOL_CAIXA`, transportada para a unidade em que o ruído nasce (vírgula flutuante de vértice).
const TOL_ESC := 0.00375
## Meio grau de posição é o que `manobra.gd:540` tolera para o blip que segue a ponte.
const TOL_POS := 1e-4

var breaks := 0
var notes: Array[String] = []

func _assert(label: String, condition: bool, detail: String) -> void:
	if condition:
		notes.append("OK     %s — %s" % [label, detail])
	else:
		breaks += 1
		notes.append("QUEBRA %s — %s" % [label, detail])

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _montar_jogo() -> Node3D:
	var game: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	await _frames(3)
	return game

func _initialize() -> void:
	# ---- 1. O arquivo bate o programa ---------------------------------------------------------
	var bytes := _tamanho(VITRINE_GLB)
	_assert("o GLB da vitrine existe com o byte assinado no `solution.mjs`", bytes == BYTES,
		"%d bytes contra %d do `budget.maxBytes`" % [bytes, BYTES])

	var recurso = load(VITRINE_GLB)
	_assert("importa como cena de nós 3D, não como malha solta", recurso is PackedScene,
		"%s" % [recurso])
	if not (recurso is PackedScene):
		_fechar()
		return

	var cru = _colher_e_fundir(recurso)
	_assert("a cena importada traz os seis corpos que o programa escreveu",
		cru["nos"] == NOS_DE_MALHA,
		"%d nó(s) de malha contra %d de `solution.mjs` (corpo, proa, torre, duas asas, mastro)" \
			% [cru["nos"], NOS_DE_MALHA])
	# O `mirror` do programa não duplica geometria: ele INSTÂNCIA a malha da bombordo. Por isso a cena
	# tem seis nós e cinco desenhos — e por isso o bilhete do espelho é o único corpo da casa com dois
	# nós vestindo a mesma `ArrayMesh`.
	var unicas: Array = _malhas_unicas(cru["nos_lista"])
	_assert("e são cinco desenhos: a asa boreste instância a malha da bombordo, não uma cópia",
		unicas.size() == MALHAS_DISTINTAS,
		"%d malha(s) distinta(s) entre %d nós — os 12 triângulos da caixa de asa aparecem uma vez" \
			% [unicas.size(), cru["nos"]])
	var tri_unicos := 0
	for malha_unica in unicas:
		tri_unicos += _triangulos_de(malha_unica)
	_assert("o custo ÚNICO do arquivo é o `budget.maxTriangles` do programa",
		tri_unicos == TRIANGULOS_UNICOS,
		"%d triângulos somados nas %d malhas distintas contra %d assinados no dry-run" \
			% [tri_unicos, unicas.size(), TRIANGULOS_UNICOS])
	var mats := _materiais_de(cru["nos_lista"])
	_assert("os três tons do desenho chegam à cena sem perda", mats.size() == MATERIAIS,
		"%d material(is) distinto(s) nas superfícies: casco, torre e mastro" % mats.size())
	var caixa_cru: AABB = cru["caixa"]
	_assert("a caixa crua colhida é a `expectBounds` do programa",
		absf(caixa_cru.size.x - CRU_LARGURA) < TOL_CAIXA \
			and absf(caixa_cru.size.y - CRU_ALTURA) < TOL_CAIXA \
			and absf(caixa_cru.size.z - CRU_COMPRIMENTO) < TOL_CAIXA,
		"cru medido %0.3f x %0.3f x %0.3f u contra %0.3f x %0.3f x %0.3f" % [
			caixa_cru.size.x, caixa_cru.size.y, caixa_cru.size.z,
			CRU_LARGURA, CRU_ALTURA, CRU_COMPRIMENTO])
	# O mastro é o que faz desta capitânia e não um casco de linha pintado de ouro: sem ele a face de
	# cima seria o teto da torre (0,57 u), não o topo do bilhete de TRIPULAÇÃO.
	_assert("e o mastro está no alto: a face de cima é o topo dele, não a torre",
		absf((caixa_cru.end.y - caixa_cru.position.y) - CRU_ALTURA) < TOL_CAIXA \
			and caixa_cru.end.y > 0.57 + 0.4,
		"de -0,500 (base do cone de proa) a %0.3f u, lido do loft + mastro" % caixa_cru.end.y)

	# ---- 2. A vitrine montada na cena ----------------------------------------------------------
	var game: Node3D = await _montar_jogo()
	var cap = game.holo_capitania
	_assert("a capitânia da mesa existe e é um corpo só", is_instance_valid(cap) \
			and cap is MeshInstance3D,
		"%s" % [cap])
	if not is_instance_valid(cap):
		_fechar()
		return
	_assert("morre no rig, não na lista de blips: o pai é a ponte", \
			cap.get_parent() == game.bridge_rig,
		"pai = %s (a conta de blip por casco vivo lê só `fleet` + `enemies`)" \
			% String((cap as Node).get_parent().name))

	var malha = (cap as MeshInstance3D).mesh
	_assert("a vitrine é uma `ArrayMesh` de UMA superfície", malha is ArrayMesh \
			and (malha as ArrayMesh).get_surface_count() == 1,
		"%s com %d superfície(s)" % [malha.get_class() if malha != null else "<nula>",
			(malha as ArrayMesh).get_surface_count() if malha is ArrayMesh else -1])
	if not (malha is ArrayMesh):
		_fechar()
		return
	var a: Array = (malha as ArrayMesh).surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	# O slot de índice de uma `ArrayMesh` não indexada é `Nil`, e atribuir `Nil` a um
	# `PackedInt32Array` tipado aborta a sonda no meio das asserções. É a régua: a vitrine É o lado
	# não indexado da conta, e o contrato de 744 bilhetes se lê por `v.size()`, não por `idx`.
	var bruto_idx = a[Mesh.ARRAY_INDEX]
	var idx: PackedInt32Array = bruto_idx if bruto_idx != null else PackedInt32Array()
	_assert("o custo DESENHADO lido DA CENA paga o espelho: 248 triângulos, não indexados",
		idx.is_empty() and v.size() == TRIANGULOS_DESENHADOS * 3,
		"%d bilhetes = %d desenhados x 3 (%d únicos + 12 da caixa de asa espelhada), índice %d" % [
			v.size(), TRIANGULOS_DESENHADOS, TRIANGULOS_UNICOS, idx.size()])
	_assert("toda normal é unitária, uma por vértice", n.size() == v.size() and _normais_boas(n),
		"%d normal(is) para %d vértice(s), comprimento 1 ± 1e-3" % [n.size(), v.size()])
	_assert("os três materiais do desenho não vazaram para a mesa: quem pinta é o override",
		(malha as ArrayMesh).surface_get_material(0) == null \
			and (cap as MeshInstance3D).material_override != null,
		"material da superfície %s, override %s" % [
			(malha as ArrayMesh).surface_get_material(0),
			str((cap as MeshInstance3D).material_override)])

	var caixa := _caixa_de(v)
	var centro := (caixa.position + caixa.end) * 0.5
	# `_cylinder` centraliza o corpo em `position`; se a fusão esquecesse o translamento para a
	# origem, o casco nasceria meio corpo acima do ponto que a ponte comanda e `manobra.gd:540`
	# continuaria verde — a posição do nó estaria certa, o corpo errado.
	_assert("a caixa local está centrada na origem", centro.length() < 0.002,
		centro_str(centro))
	_assert("o corpo escalado é a crua vezes `ESCALA_VITRINE`",
		absf(caixa.size.x - ESC_LARGURA) < TOL_ESC and absf(caixa.size.y - ESC_ALTURA) < TOL_ESC \
			and absf(caixa.size.z - ESC_COMPRIMENTO) < TOL_ESC,
		"medido %0.4f x %0.4f x %0.4f u contra %0.4f x %0.4f x %0.4f (escala %0.2f)" % [
			caixa.size.x, caixa.size.y, caixa.size.z,
			ESC_LARGURA, ESC_ALTURA, ESC_COMPRIMENTO, ESCALA_ESPERADA])
	_assert("a proa aponta para −z, o lado do inimigo na mesa",
		caixa.position.z < -0.37 and caixa.end.z > 0.37 \
			and absf(caixa.size.z - ESC_COMPRIMENTO) < TOL_ESC,
		"z de %0.4f a %0.4f u, centro em z %0.5f" % [caixa.position.z, caixa.end.z, centro.z])

	# ---- 3. Cabe na mesa, e é capitânia --------------------------------------------------------
	var meia_diagonal := maxf(caixa.size.x, caixa.size.z) * 0.5
	_assert("cabe dentro do aro com folga de mesa, não de gosto",
		meia_diagonal < HOLO_RIM * 0.5,
		"maior meia-extensão %0.3f u contra o aro de %0.2f u (folga %0.3f u)" % [
			meia_diagonal, HOLO_RIM, HOLO_RIM - meia_diagonal])
	_assert("lê como capitânia: maior que três blips de linha lado a lado",
		caixa.size.z > 3.0 * 0.085 * 2.0,
		"comprimento %0.3f u contra 0,170 u de boca de um blip de linha (raio 0,085)" % caixa.size.z)
	var ouro: Color = HUD_OURO.lightened(0.25)
	var mat := (cap as MeshInstance3D).material_override as StandardMaterial3D
	_assert("a pintura continua a do holograma dourado, nem um byte a mais",
		mat != null and absf(mat.albedo_color.r - ouro.darkened(0.3).r) < 1e-4 \
			and absf(mat.albedo_color.g - ouro.darkened(0.3).g) < 1e-4 \
			and absf(mat.albedo_color.b - ouro.darkened(0.3).b) < 1e-4 \
			and absf(mat.emission.r - (ouro * 0.45).r) < 1e-4,
		"albedo %s / emissão %s contra %s e %s (metal %0.1f)" % [mat.albedo_color, mat.emission,
			ouro.darkened(0.3), ouro * 0.45, mat.metallic])

	# ---- 4. As três leis vizinhas --------------------------------------------------------------
	var alvo: Vector3 = (game.holo_root as Node3D).position \
		+ game._holo_de((game.bridge_rig as Node3D).position)
	_assert("o corpo continua no ponto que a ponte comanda",
		cap.position.distance_to(alvo) < TOL_POS,
		"vitrine %.5f/%.5f/%.5f contra %.5f/%.5f/%.5f u" % [cap.position.x, cap.position.y,
			cap.position.z, alvo.x, alvo.y, alvo.z])
	var vivos := 0
	for grupo in [game.fleet, game.enemies]:
		for unidade in grupo:
			if is_instance_valid(unidade["node"]):
				vivos += 1
	_assert("um blip por casco vivo continua valendo com a vitrine na cena",
		int((game.holo_blips as Dictionary).size()) == vivos,
		"%d blips para %d cascos vivos (a vitrine não é contato)" % [
			int((game.holo_blips as Dictionary).size()), vivos])
	_assert("a vitrine não está na lista de blips",
		not (game.holo_blips as Dictionary).values().has(cap),
		"dict com %d chaves; o corpo dourado mora fora dele" % int((game.holo_blips as Dictionary).size()))
	var visivel_antes := (cap as Node3D).visible
	game._acender_ruina()
	_assert("o apagão esconde a vitrine junto com a mesa", not (cap as Node3D).visible,
		"antes=%s depois=%s" % [visivel_antes, (cap as Node3D).visible])
	game._restaurar_ponte_da_base()
	_assert("e o restaurar a devolve: a vitrine sobrevive ao ciclo da ponte",
		(cap as Node3D).visible and (cap as Node3D).visible == visivel_antes,
		"de volta a visible=%s, com a malha ainda montada (%d bilhetes)" % [
			(cap as Node3D).visible, v.size()])

	# ---- 5. O desenho é inerte -----------------------------------------------------------------
	var rng_antes := int(game.rng.state)
	var visual_antes := int(game.visual_rng.state)
	var segunda = game._malha_da_vitrine()
	var v2: PackedVector3Array = (segunda as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_assert("colher geometria não gasta um dígito de sorteio",
		int(game.rng.state) == rng_antes and int(game.visual_rng.state) == visual_antes,
		"rng %d -> %d | visual %d -> %d" % [rng_antes, int(game.rng.state),
			visual_antes, int(game.visual_rng.state)])
	_assert("e a segunda colheita é a mesma malha, dígito a dígito",
		_assinatura(v) == _assinatura(v2), "assinatura %s dos dois lados (%d bilhetes)" % [
			_assinatura(v), v.size()])
	var vestida := 0
	for grupo in [game.fleet, game.enemies]:
		for unidade in grupo:
			var no: Node3D = unidade["node"]
			if not is_instance_valid(no):
				continue
			for mi in _meshes_de(no):
				if mi == malha:
					vestida += 1
	_assert("nenhum casco de frota veste a vitrine: o tabuleiro continua procedural",
		vestida == 0, "%d malha(s) de cascos vivos compartilhando o corpo desenhado" % vestida)
	var esquadra = load("res://esquadra.gd").new()
	_assert("a malha da muralha é outra malha", esquadra.malha_replica() != malha,
		"procedural %s / vitrine %s (papéis separados desde 2026-11-04)" % [
			str(esquadra.malha_replica()), str(malha)])
	esquadra = null
	segunda = null

	# ---- 6. O papel: a vitrine não invadiu o tabuleiro -----------------------------------------
	var texto_esq := _texto("res://esquadra.gd")
	var texto_cena := _texto("res://main.tscn")
	var texto_main := _texto("res://main.gd")
	_assert("`esquadra.gd` não conhece a vitrine", not texto_esq.contains("capitania_vitrine"),
		"%d caracteres, zero citações ao GLB da mesa" % texto_esq.length())
	_assert("`main.tscn` não conhece a vitrine", not texto_cena.contains("capitania_vitrine"),
		"%d caracteres, o corpo nasce por código, não por cena salvo" % texto_cena.length())
	_assert("e `main.gd` cita o caminho uma única vez",
		_ocorrencias(texto_main, "res://assets/cascos/capitania_vitrine.glb") == 1,
		"%d vez(es) no arquivo — a constante `VITRINE_GLB`, nenhum `load()` com caminho solto" \
			% _ocorrencias(texto_main, "res://assets/cascos/capitania_vitrine.glb"))

	notes.append(("CONTA  GLB de %d bytes; vitrine de %d bilhetes não-indexados na mesa, "
		+ "caixa escalada %0.4f x %0.4f x %0.4f u dentro do aro de %0.2f u") % [
		bytes, v.size(), caixa.size.x, caixa.size.y, caixa.size.z, HOLO_RIM])

	# `quit()` dentro desta função, com as locais ainda vivas: a casa exige zero linha de erro na
	# rodada, e malha viva no encerramento é exatamente uma linha de erro. As medidas viraram número.
	cap = null
	malha = null
	mat = null
	game = null
	recurso = null
	_fechar()

## ---- Colheita do arquivo, independente do código sob teste ------------------------------------
## É a mesma régua de `glb_replica.gd:_colher`, escrita de novo aqui de propósito: a primeira seção
## desta sonda mede o que o importador entrega, e medir o GLB com a função de `main.gd` que estou
## testando seria aprovar o desenho com o próprio desenho.
func _colher_e_fundir(cena: PackedScene) -> Dictionary:
	var inst = cena.instantiate()
	var nos: Array = []
	_pegar(inst, Transform3D(), nos)
	inst.free()
	var v := PackedVector3Array()
	var minimo := Vector3(1e18, 1e18, 1e18)
	var maximo := Vector3(-1e18, -1e18, -1e18)
	for item in nos:
		var malha: Mesh = item["malha"]
		var xf: Transform3D = item["xf"]
		for s in range(malha.get_surface_count()):
			var arr: Array = malha.surface_get_arrays(s)
			var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bruto = arr[Mesh.ARRAY_INDEX]
			var ordem: PackedInt32Array = bruto if bruto != null else PackedInt32Array()
			if ordem.is_empty():
				ordem = PackedInt32Array()
				for k in vv.size():
					ordem.append(k)
			for k in ordem:
				var p := xf * vv[k]
				v.append(p)
				minimo = Vector3(minf(minimo.x, p.x), minf(minimo.y, p.y), minf(minimo.z, p.z))
				maximo = Vector3(maxf(maximo.x, p.x), maxf(maximo.y, p.y), maxf(maximo.z, p.z))
	return {"nos": nos.size(), "nos_lista": nos, "v": v,
		"caixa": AABB(minimo, maximo - minimo)}

func _pegar(node: Node, xf_pai: Transform3D, out: Array) -> void:
	var local := Transform3D()
	if node is Node3D:
		local = (node as Node3D).transform
	var comp := xf_pai * local
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append({"nome": String(node.name), "xf": comp, "malha": (node as MeshInstance3D).mesh})
	for filho in node.get_children():
		_pegar(filho, comp, out)

func _materiais_de(nos: Array) -> Array:
	var vistos: Array = []
	for item in nos:
		var malha: Mesh = item["malha"]
		for s in range(malha.get_surface_count()):
			var m = malha.surface_get_material(s)
			if m != null and not vistos.has(m):
				vistos.append(m)
	return vistos

## Malhas distintas, por objeto: é a conta que separa "seis nós" de "seis desenhos". Um `mirror` do
## programa aparece aqui uma vez só, porque ele instancia a malha em vez de gerar geometria nova.
func _malhas_unicas(nos: Array) -> Array:
	var vistas: Array = []
	for item in nos:
		var malha: Mesh = item["malha"]
		if not vistas.has(malha):
			vistas.append(malha)
	return vistas

## Triângulos de uma malha, pelo lado que ela cobrar: indexada conta o índice, não indexada conta
## terços de vértice. O importador do Godot entrega as primitivas do GLB indexadas; a vitrine fundida
## pela `main.gd` é que nasce não indexada.
func _triangulos_de(malha: Mesh) -> int:
	var total := 0
	for s in range(malha.get_surface_count()):
		var arr: Array = malha.surface_get_arrays(s)
		var bruto = arr[Mesh.ARRAY_INDEX]
		var ordem: PackedInt32Array = bruto if bruto != null else PackedInt32Array()
		if ordem.is_empty():
			var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			total += int(vv.size() / 3)
		else:
			total += int(ordem.size() / 3)
	return total

func _normais_boas(n: PackedVector3Array) -> bool:
	for p in n:
		if absf(p.length() - 1.0) > 1e-3:
			return false
	return true

func _caixa_de(v: PackedVector3Array) -> AABB:
	var minimo := Vector3(1e18, 1e18, 1e18)
	var maximo := Vector3(-1e18, -1e18, -1e18)
	for p in v:
		minimo = Vector3(minf(minimo.x, p.x), minf(minimo.y, p.y), minf(minimo.z, p.z))
		maximo = Vector3(maxf(maximo.x, p.x), maxf(maximo.y, p.y), maxf(maximo.z, p.z))
	return AABB(minimo, maximo - minimo)

## Assinatura de vértice: dobras de 1e-5 u — um quinto do grão de um float32 nesta ordem de tamanho —
## acumuladas em inteiro. É o que separa «a mesma malha» de «uma malha do mesmo tamanho».
func _assinatura(v: PackedVector3Array) -> String:
	var h := 0
	for p in v:
		for c in [p.x, p.y, p.z]:
			h = (h * 31 + int(round(float(c) * 100000.0))) & 0x7FFFFFFF
	return "%x/%d" % [h, v.size()]

func _meshes_de(no: Node) -> Array:
	var out: Array = []
	if no is MeshInstance3D and (no as MeshInstance3D).mesh != null:
		out.append((no as MeshInstance3D).mesh)
	for filho in no.get_children():
		out.append_array(_meshes_de(filho))
	return out

func _ocorrencias(texto: String, agulha: String) -> int:
	var n := 0
	var i := texto.find(agulha)
	while i >= 0:
		n += 1
		i = texto.find(agulha, i + agulha.length())
	return n

func centro_str(centro: Vector3) -> String:
	return "centro da caixa local em %.6f/%.6f/%.6f u (teto 0,002)" % [
		centro.x, centro.y, centro.z]

func _tamanho(caminho: String) -> int:
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null:
		return -1
	var n := f.get_length()
	f.close()
	return n

func _texto(caminho: String) -> String:
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t

func _fechar() -> void:
	for linha in notes:
		print("SONDA-VITRINE: %s" % linha)
	print("VEREDITO vitrine — quebras=%d • conferências=%d" % [breaks, notes.size()])
	quit(0 if breaks == 0 else 1)
