extends SceneTree

## Sonda do geoide: a pedra do cinturão é irregular, nasce de função do índice e não promete
## volume onde a física não para o tiro.
##
## A rocha era um `_box` de `Vector3(raio*1,7, raio*1,3, raio*1,5)`. Três leis ficaram de pé com o
## geoide e uma nova entrou no meio; é isso que esta sonda mede, e nenhuma delas julga gosto:
##
## 1) UMA MALHA POR VARIANTE, COMPARTIHADA. Três silhuetas para catorze pedras, montadas uma vez, e
##    a identidade é conferida por `get_instance_id()` — não por igualdade de bytes. Catorze malhas
##    no ar seriam catorze recursos por partida, e duas montadas da esquadra divide as mesmas três.
## 2) INSCRIÇÃO NA ESFERA DE COLISÃO (a lei nova). Nenhum vértice passa de 1,0 u na malha unitária,
##    o nó escala por `raio` e a esfera de raio `raio` é o que `_barreira_entre` usa. O tijolo antigo
##    mentia: a meia-quina do box chegava a 0,85 × √3 = 1,472 raio, e um lance atravessando aquela
##    quina era bloqueado no quadro e furava na conta. Aqui a silhueta mais externa COINCIDE com a
##    barreira, medida pedra a pedra.
## 3) DETERMINISMO DE SILHUETA. Duas montadas, com o cache esvaziado no meio, chegam no MESMO
##    checksum de vértices. Não basta cravar a semente — a forma poderia nascer de um `randf()`
##    global e a semente não ver; aqui a geometria é lida da malha e somada.
## 4) NENHUM SORTEIO TOCADO. `rng` e `visual_rng` não se movem, e a cauda de quarenta sorteios é a
##    mesma na semente cravada, depois de um acerto de cache e depois de gerar as três malhas do
##    zero. É a mesma régua de `tools/probes/superficies.gd`, e é a que as outras sondas assumem.
## 5) A IRREGULARIDADE É REAL. O piso é medido, não presumido: a pedra tem de ter faces, ter
##    espalhamento de raio e ter as três variantes diferentes entre si. Uma bola com espinho, ou três
##    cópias da mesma silhueta, passam verdes em 1) a 4) e quebram aqui.
## 6) A CONTA DA CENA NÃO MUDA. Um nó por pedra, uma marca por pedra, o mesmo gabarito de filhos do
##    cenário e da mesa — `tools/probes/cinturao.gd` continua cobrando 14 corpos e 14 marcas, e o
##    geoide não entra nessa conta.
##
## Uso: godot --headless --path . --quit-after 6000 -s res://tools/probes/geoide.gd

const Geometria := preload("res://geometria.gd")

## Espelho das constantes de `geometria.gd` (a instância do jogo é não tipada; mesmo motivo em
## `tools/probes/cinturao.gd`). Mudar o número lá quebra a asserção aqui: é de propósito.
const VARIANTES_ESPERADAS := 3
const PUXO_MINIMO_ESPERADO := 0.78
## Icosaedro com um nível de subdivisão: 20 × 4 faces sobre 42 direções.
const FACES_ESPERADAS := 80
const DIRECOES_ESPERADAS := 42
const ROCHAS_ESPERADAS := 14
## Tolerância de inscrição. `float` em GDScript é double e a transformada do nó é single: comparar
## o vértice com 1,0 exato daria falso para sempre (a lição do teto de rolagem em `morte.gd`).
const EPS_INSCRICAO := 1e-5
## Piso de espalhamento de raio, lido do menor para o maior vértice. 0,78 é o teto teórico do
## `PUXO_MINIMO`; o número abaixo é o que sobra depois da renormalização pelo maior vértice.
const ESPALHAMENTO_MINIMO := 0.14
## Amostra do checksum de vértices: 4096 por unidade. Assinatura de silhueta, não de bytes —
## 2,4e-4 u de resolução não perde um vértice movido e sobrevive ao ruído de ponto flutuante.
const PASSO_CHEKSUM := 4096.0
## Gabarito da árvore, medido com o geoide já ligado: 24 filhos de uma montagem nova sem cenário
## (vinte e dois da lei de `superficies.gd` mais os DOIS `MultiMeshInstance3D` da esquadra de blocos)
## mais o `cenario_root`, que é filho único. Dentro do `cenario_root` do cinturão há exatamente um nó
## por pedra (14) e zero no campo aberto — as marcas de mesa não moram aí, moram no `holo_root`, e
## são conferidas à parte.
const FILHOS_DO_JOGO := 25
const FILHOS_DO_CINTURAO := 14
const FILHOS_DO_ABERTO := 0
## Semente cravada das réguas de cauda, idêntica à de `superficies.gd` para as duas serem lidas
## juntas: `rng` é `randomize()` na origem de propósito, então o que se compara é a cauda.
const SEMENTE_RNG := 1234567890
const SEMENTE_VISUAL := 555

var breaks := 0
var notes: Array[String] = []

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

## Quarenta sorteios do gerador de combate, na ordem em que saem.
func _cauda(game) -> Array[int]:
	var retirada: Array[int] = []
	for i in range(40):
		retirada.append(game.rng.randi())
	return retirada

func _arrays(malha: ArrayMesh) -> Array:
	return malha.surface_get_arrays(0)

func _vertices(malha: ArrayMesh) -> PackedVector3Array:
	return _arrays(malha)[Mesh.ARRAY_VERTEX]

## Assinatura da silhueta: os vértices quantizados, somados com peso de posição. Duas malhas que
## diferem num único vértice não batem, e a mesma malha regerada bate com certeza.
func _checksum_vertices(malha: ArrayMesh) -> int:
	var verts := _vertices(malha)
	var total := 0
	var no := 0
	for v in verts:
		no += 1
		for eixo in [v.x, v.y, v.z]:
			var cru := int(roundf(float(eixo) * PASSO_CHEKSUM)) + 65536
			total = (total + cru * (no * 31)) % 1000000007
	return total

## Espalhamento lido do próprio array de vértices: 1 − (menor raio / maior raio). É a medida de
## "não é bola", e ela não vem das constantes — se o hash aplainar, o número cai aqui.
func _espalhamento(malha: ArrayMesh) -> Dictionary:
	var menor := 10.0
	var maior := 0.0
	for v in _vertices(malha):
		var r := v.length()
		menor = minf(menor, r)
		maior = maxf(maior, r)
	return {
		"min": menor,
		"max": maior,
		"espalhamento": 1.0 - menor / maxf(maior, 1e-9),
		"vertices": _vertices(malha).size(),
	}

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	# ── 1. Uma malha por variante ───────────────────────────────────────────────────────────
	var g0a: ArrayMesh = Geometria.geoide(0)
	var g0b: ArrayMesh = Geometria.geoide(0)
	var g3: ArrayMesh = Geometria.geoide(3)
	_assert("a variante repetida devolve a MESMA malha",
		g0a != null and g0a.get_instance_id() == g0b.get_instance_id(),
		"%d vs %d" % [g0a.get_instance_id(), g0b.get_instance_id()])
	_assert("o índice wraps pela variante anunciada",
		g3.get_instance_id() == g0a.get_instance_id()
			and Geometria.VARIANTES == VARIANTES_ESPERADAS,
		"geoide(3) == geoide(0), VARIANTES = %d" % Geometria.VARIANTES)
	var faces_lidas := 0
	for variante in range(VARIANTES_ESPERADAS):
		var malha := Geometria.geoide(variante)
		if malha.get_surface_count() == 1 \
				and malha.surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLES:
			faces_lidas += _vertices(malha).size() / 3
	_assert("as três variantes fecham em 80 faces chatos cada", faces_lidas == 240,
		"%d triângulos no total (3 x 80)" % faces_lidas)
	# Sombreamento chato é decisão de projeto: é a quina entre faces que lê asteróide à distância do
	# cinturão. Sem array de índice, o motor não compartilha vértice e não suaviza.
	var sem_indice := 0
	var com_uv := 0
	for variante in range(VARIANTES_ESPERADAS):
		var malha := Geometria.geoide(variante)
		if malha.surface_get_array_index_len(0) == 0:
			sem_indice += 1
		var arr := _arrays(malha)
		if (arr[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() == arr[Mesh.ARRAY_VERTEX].size():
			com_uv += 1
	_assert("faces chatas e pele em todo vértice",
		sem_indice == VARIANTES_ESPERADAS and com_uv == VARIANTES_ESPERADAS,
		"%d malhas sem índice, %d com UV por vértice" % [sem_indice, com_uv])

	# ── 2. Inscrição na esfera de colisão ───────────────────────────────────────────────────
	var fora_da_esfera := 0
	var pico_fora := 0.0
	var aabb_fora := 0
	for variante in range(VARIANTES_ESPERADAS):
		var malha := Geometria.geoide(variante)
		var maior := 0.0
		for v in _vertices(malha):
			var r := v.length()
			maior = maxf(maior, r)
			if r > 1.0 + EPS_INSCRICAO:
				fora_da_esfera += 1
		if maior < 1.0 - EPS_INSCRICAO:
			pico_fora += 1
		var caixa := malha.get_aabb()
		if caixa.size.x > 2.0 + EPS_INSCRICAO or caixa.size.y > 2.0 + EPS_INSCRICAO \
				or caixa.size.z > 2.0 + EPS_INSCRICAO:
			aabb_fora += 1
	_assert("nenhum vértice passa da esfera de colisão unitária", fora_da_esfera == 0,
		"%d vértices além de 1,0 u nas três malhas" % fora_da_esfera)
	_assert("o maior vértice de cada variante VALE 1,0 (inscrição apertada, não teto folgado)",
		pico_fora == 0, "%d variantes com pico abaixo de 1,0 u" % pico_fora)
	_assert("a caixa da malha cabe no diâmetro unitário", aabb_fora == 0,
		"%d caixas além de 2,0 u" % aabb_fora)
	# Degenerada é o outro modo de quebrar a inscrição: um rosto raso nasce normal zero e o motor
	# não tem para onde apontar a luz.
	var normais_ruins := 0
	for variante in range(VARIANTES_ESPERADAS):
		var normais: PackedVector3Array = _arrays(Geometria.geoide(variante))[Mesh.ARRAY_NORMAL]
		for n in normais:
			if not is_equal_approx(n.length(), 1.0) or n.length() < 1e-3:
				normais_ruins += 1
	_assert("toda face tem normal de unidade e nenhuma é rasa", normais_ruins == 0,
		"%d normais fora de 1,0 em %d faces" % [normais_ruins, faces_lidas])

	# ── 3. A pedra na cena, medida pedra a pedra ────────────────────────────────────────────
	var jogo := await _montar_jogo()
	jogo._montar_cenario("CINTURAO")
	_assert("o cinturão montou as catorze pedras", jogo.rochas.size() == ROCHAS_ESPERADAS,
		"%d corpos" % jogo.rochas.size())
	var silhuetas: Dictionary = {}
	var escala_errada := 0
	var silhueta_além_da_barreira := 0
	var sem_malha := 0
	for i in range(jogo.rochas.size()):
		var rocha: Dictionary = jogo.rochas[i]
		var no: MeshInstance3D = rocha["no"]
		var raio := float(rocha["raio"])
		var malha := no.mesh as ArrayMesh
		if malha == null:
			sem_malha += 1
			continue
		silhuetas[no.mesh.get_instance_id()] = true
		if not (is_equal_approx(no.scale.x, raio) and is_equal_approx(no.scale.y, raio)
				and is_equal_approx(no.scale.z, raio)):
			escala_errada += 1
		var maior := 0.0
		for v in _vertices(malha):
			maior = maxf(maior, v.length())
		# A régua da casa: o volume desenhado tem de caber na esfera que a barreira usa. O box
		# antigo estourava em 1,472 raio na quina — o tiro furava na conta e batia no quadro.
		if maior * raio > raio + 1e-3:
			silhueta_além_da_barreira += 1
	_assert("as catorze pedras vestem ArrayMesh com escala igual ao raio de cadastro",
		sem_malha == 0 and escala_errada == 0,
		"%d sem malha, %d com escala fora do raio" % [sem_malha, escala_errada])
	_assert("nenhuma silhueta passa da barreira que o tiro encontra",
		silhueta_além_da_barreira == 0,
		"%d de %d pedras desenhadas além do raio de colisão" % [silhueta_além_da_barreira,
			jogo.rochas.size()])
	_assert("catorze pedras, três malhas no ar", silhuetas.size() == VARIANTES_ESPERADAS,
		"%d identidades de malha em %d pedras" % [silhuetas.size(), jogo.rochas.size()])

	# ── 4. Determinismo de silhueta ─────────────────────────────────────────────────────────
	var somas: Array[int] = []
	for variante in range(VARIANTES_ESPERADAS):
		somas.append(_checksum_vertices(Geometria.geoide(variante)))
	# A régua forte atravessa o esvaziamento: a malha comparada abaixo foi GERADA de novo, do zero,
	# e não lida duas vezes do mesmo recurso (isso seria verde por identidade de ponteiro).
	Geometria.limpar_cache()
	var somas_regeradas: Array[int] = []
	for variante in range(VARIANTES_ESPERADAS):
		somas_regeradas.append(_checksum_vertices(Geometria.geoide(variante)))
	var bateram := 0
	for variante in range(VARIANTES_ESPERADAS):
		if somas[variante] == somas_regeradas[variante]:
			bateram += 1
	_assert("as três silhuetas regeradas do zero batem vértice a vértice",
		bateram == VARIANTES_ESPERADAS,
		"checksums %d / %d / %d" % [somas[0], somas[1], somas[2]])
	var jogo_b := await _montar_jogo()
	# O gerador de `jogo_b` nunca foi cravado por esta sonda: é dele que se lê a régua de inércia do
	# cenário, porque montar o cinturão sobre uma semente já mexida não provaria nada.
	var visual_antes_b := int(jogo_b.visual_rng.state)
	var base_antes_b := int(jogo_b.visual_base)
	jogo_b._montar_cenario("CINTURAO")
	var visual_depois_b := int(jogo_b.visual_rng.state)
	var base_depois_b := int(jogo_b.visual_base)
	# A segunda montada é criada DEPOIS do `limpar_cache()` acima, e é de propósito: o cache de
	# malha é do processo, então `jogo` (montado antes) segura as três silhuetas da época antiga e
	# compará-lo com `jogo_b` daria identidades diferentes por causa da limpeza, não por causa do
	# gerador. O que se compara aqui são duas montadas na MESMA época de cache.
	var jogo_c := await _montar_jogo()
	jogo_c._montar_cenario("CINTURAO")
	var compartilhadas := 0
	for i in range(jogo_b.rochas.size()):
		var a: MeshInstance3D = jogo_b.rochas[i]["no"]
		var c: MeshInstance3D = jogo_c.rochas[i]["no"]
		if a.mesh.get_instance_id() == c.mesh.get_instance_id():
			compartilhadas += 1
	_assert("duas montadas da esquadra dividem as mesmas três malhas",
		compartilhadas == ROCHAS_ESPERADAS,
		"%d de %d pedras com a mesma identidade" % [compartilhadas, ROCHAS_ESPERADAS])

	# ── 5. Nenhum sorteio tocado ────────────────────────────────────────────────────────────
	jogo.rng.seed = SEMENTE_RNG
	jogo.visual_rng.seed = SEMENTE_VISUAL
	var cauda_semente: Array[int] = _cauda(jogo)
	jogo.rng.seed = SEMENTE_RNG
	jogo.visual_rng.seed = SEMENTE_VISUAL
	var semente_rng := int(jogo.rng.state)
	var semente_visual := int(jogo.visual_rng.state)
	Geometria.geoide(1)
	_assert("pegar a malha pelo cache não move o gerador de combate",
		int(jogo.rng.state) == semente_rng, "%d -> %d" % [semente_rng, int(jogo.rng.state)])
	_assert("pegar a malha pelo cache não move o gerador visual",
		int(jogo.visual_rng.state) == semente_visual,
		"%d -> %d" % [semente_visual, int(jogo.visual_rng.state)])
	var cauda_cache: Array[int] = _cauda(jogo)
	jogo.rng.seed = SEMENTE_RNG
	jogo.visual_rng.seed = SEMENTE_VISUAL
	var gera_rng := int(jogo.rng.state)
	var gera_visual := int(jogo.visual_rng.state)
	Geometria.limpar_cache()
	for variante in range(VARIANTES_ESPERADAS):
		Geometria.geoide(variante)
	_assert("gerar as três malhas do zero não move o gerador de combate",
		int(jogo.rng.state) == gera_rng, "%d -> %d" % [gera_rng, int(jogo.rng.state)])
	_assert("gerar as três malhas do zero não move o gerador visual",
		int(jogo.visual_rng.state) == gera_visual,
		"%d -> %d" % [gera_visual, int(jogo.visual_rng.state)])
	var cauda_geracao: Array[int] = _cauda(jogo)
	var cauda_igual := true
	for i in range(40):
		if cauda_semente[i] != cauda_cache[i] or cauda_semente[i] != cauda_geracao[i]:
			cauda_igual = false
	_assert("a cauda de quarenta sorteios sobrevive ao geoide", cauda_igual,
		"semente/cache/geração abrem em %d / %d / %d" % [cauda_semente[0], cauda_cache[0],
			cauda_geracao[0]])

	# ── 6. A irregularidade é real ──────────────────────────────────────────────────────────
	# O piso é lido da malha, não da constante: se o hash aplainar ou se as variantes forem cópias,
	# as cinco seções acima ficam verdes e é aqui que a pedra volta a ser bola.
	var esp0: Dictionary = _espalhamento(Geometria.geoide(0))
	var esp1: Dictionary = _espalhamento(Geometria.geoide(1))
	var esp2: Dictionary = _espalhamento(Geometria.geoide(2))
	var minimo_esp := minf(esp0["espalhamento"], minf(esp1["espalhamento"], esp2["espalhamento"]))
	_assert("a pedra tem espalhamento de raio, não é bola",
		minimo_esp >= ESPALHAMENTO_MINIMO,
		"espalhamento %.3f / %.3f / %.3f (piso %.2f)" % [esp0["espalhamento"],
			esp1["espalhamento"], esp2["espalhamento"], ESPALHAMENTO_MINIMO])
	_assert("o puxo de dentro respeita o mínimo anunciado e o pico vale 1,0",
		esp0["min"] >= PUXO_MINIMO_ESPERADO - EPS_INSCRICAO
			and is_equal_approx(esp0["max"], 1.0),
		"raio lido de %.3f a %.3f, PUXO_MINIMO = %s" % [esp0["min"], esp0["max"],
			str(PUXO_MINIMO_ESPERADO)])
	_assert("as três silhuetas são pedras diferentes",
		somas_regeradas[0] != somas_regeradas[1] and somas_regeradas[1] != somas_regeradas[2]
			and somas_regeradas[0] != somas_regeradas[2],
		"checksums distintos: %d / %d / %d" % [somas_regeradas[0], somas_regeradas[1],
			somas_regeradas[2]])
	_assert("cada direção da esfera vira um vértice (42 por malha)",
		esp0["vertices"] == FACES_ESPERADAS * 3,
		"%d vértices não-indexados sobre %d direções" % [esp0["vertices"], DIRECOES_ESPERADAS])

	# ── 7. A conta da cena não muda ─────────────────────────────────────────────────────────
	var marcas := 0
	for i in range(jogo.rochas.size()):
		var rocha: Dictionary = jogo.rochas[i]
		if rocha["marca"] != null:
			marcas += 1
	_assert("uma marca de mesa por pedra continua no ar",
		marcas == jogo.rochas.size() and jogo.holo_cenario.size() == jogo.rochas.size(),
		"%d marcas, %d nós na mesa" % [marcas, jogo.holo_cenario.size()])
	# O gabarito é a medida, não uma soma presumida: o geoide troca a MALHA do nó, não o nó.
	var filho_cinturao := 0
	var filho_aberto := 0
	if is_instance_valid(jogo.cenario_root):
		filho_cinturao = jogo.cenario_root.get_child_count()
	jogo._montar_cenario("ABERTO")
	# O `await` não é enfeite: `_desmontar_cenario` usa `queue_free`, e ler o contador no mesmo
	# instante mediria as catorze pedras velhas ainda penduradas na árvore.
	await _frames(3)
	if is_instance_valid(jogo.cenario_root):
		filho_aberto = jogo.cenario_root.get_child_count()
	_assert("o cenário não ganhou nó com o geoide",
		filho_cinturao == FILHOS_DO_CINTURAO and filho_aberto == FILHOS_DO_ABERTO,
		"CINTURAO com %d filhos (gabarito %d), ABERTO com %d (gabarito %d)" % [
			filho_cinturao, FILHOS_DO_CINTURAO, filho_aberto, FILHOS_DO_ABERTO])
	_assert("o jogo continua com a mesma árvore de sempre",
		jogo.get_child_count() == FILHOS_DO_JOGO,
		"%d filhos na montagem com cenário aberto" % jogo.get_child_count())
	_assert("montar o cinturão não consome um sorteio da camada visual",
		visual_depois_b == visual_antes_b and base_depois_b == base_antes_b,
		"visual %d -> %d (base %d -> %d)" % [visual_antes_b, visual_depois_b,
			base_antes_b, base_depois_b])

	print("SONDA-GEOIDE: veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	for nota in notes:
		print(nota)
	quit(1 if breaks > 0 else 0)
