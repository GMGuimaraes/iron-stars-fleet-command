extends RefCounted
## Geometria procedural: o geoide das rochas do cinturão.
##
## A pedra era um tijolo com textura de rocha — seis faces planas e quinas vivas. Aqui ela nasce
## de um icosaedro subdivido com o raio de cada vértice puxado para dentro por hash do **índice do
## vértice**, a mesma lei do pixel que manda em `superficies.gd`: nenhum `rng` da casa é tocado, e
## duas montadas independentes chegam na MESMA silhueta, vértice a vértice, sem semente cravada.
##
## A forma é gerada uma vez por variante e guardada em `_cache`, como a placa de aço: as catorze
## pedras compartilham **três** malhas, e o que as separa é a escala do nó (o raio de cadastro), a
## rotação de largada e a variante tirada do índice. Catorze malhas no ar seriam catorze recursos
## por partida, e a sonda confere identidade por `get_instance_id()`, não igualdade de bytes.
##
## A lei que manda em tudo: o geoide é **inscrito** na esfera de colisão. Nenhum vértice passa de
## 1,0 u na malha unitária, então o nó escalado em `raio` nunca promete pedra onde a física não
## para o tiro. O tijolo antigo prometia: a meia-quina do box de `Vector3(raio*1,7, raio*1,3,
## raio*1,5)` chega a 0,85 × √3 = 1,472 raio do centro, e o corte do corredor é conta de 1,00. Um
## lance atravessando aquela quina era bloqueado no quadro e furava na conta — pintura mentindo
## sobre a física, a mesma proibição que já vale para a faixa de formação.


## Quantas silhuetas existem. Três segura a variedade no quadro do cinturão — com 14 pedras em
## cena nenhuma variante aparece menos de quatro vezes — sem embarcar 14 malhas.
const VARIANTES = 3
## Puxo mínimo do vértice, em fração do raio. Abaixo disso a pedra vira esponja e some do quadro;
## acima de 0,9 ela volta a ser bola e o geoide não justifica o nome.
const PUXO_MINIMO = 0.78
## Vezes que cada rosto do icosaedro se divide por quatro. 1 dá 80 rostos chatos sobre 42
## direções: cascalho legível de longe, sem virar bola com espinho.
const SUBDIVISOES = 1
## Eixos achatados por variante. Todos ≤ 1 de propósito: o achatamento vem antes da renormalização
## e um eixo > 1 estouraria a inscrição na esfera de colisão.
const ESTIRAMENTOS = [
	Vector3(0.97, 0.89, 0.94),
	Vector3(0.86, 0.98, 0.88),
	Vector3(0.93, 0.86, 0.99),
]
## Pesos da deformação: o grão de índice sozinho dá espinho, o lóbulo de baixa frequência dá
## batata. É a soma dos dois que lê asteróide.
const PESO_GRAO = 0.45
const PESO_LOBO = 0.55

static var _cache: Dictionary = {}


## A malha unitária da variante: centrada na origem, raio máximo 1,0 exato, sombreada em rosto
## chato — é a quina entre faces que segura a silhueta irregular no quadro distante.
static func geoide(variante: int) -> ArrayMesh:
	var chave := "geoide_%d" % (variante % VARIANTES)
	if not _cache.has(chave):
		_cache[chave] = _montar(variante % VARIANTES)
	return _cache[chave] as ArrayMesh


static func limpar_cache() -> void:
	_cache.clear()


## O hash inteiro do índice: mesma entrada, mesma saída, em qualquer máquina e em qualquer rodada.
## É o que dispensa semente cravada na prova de silhueta — o `rng` da casa não passa por aqui.
static func _bruto(x: int, y: int, sal: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (sal * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(absi(h) % 100000) / 100000.0


## Os 12 vértices do icosaedro já projectados na esfera unitária: é a lista que se subdividi, e o
## passo seguinte depende dela estar centrada na origem.
static func _icosaedro() -> Array[Vector3]:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var bruto: Array[Vector3] = [
		Vector3(-1.0, t, 0.0), Vector3(1.0, t, 0.0), Vector3(-1.0, -t, 0.0), Vector3(1.0, -t, 0.0),
		Vector3(0.0, -1.0, t), Vector3(0.0, 1.0, t), Vector3(0.0, -1.0, -t), Vector3(0.0, 1.0, -t),
		Vector3(t, 0.0, -1.0), Vector3(t, 0.0, 1.0), Vector3(-t, 0.0, -1.0), Vector3(-t, 0.0, 1.0),
	]
	var verts: Array[Vector3] = []
	for v in bruto:
		verts.append(v.normalized())
	return verts


## Os 20 rostos do icosaedro sobre aquela lista. O enrolamento não é assumido: `_montar` confere
## rosto a rosto e inverte o que aponta para dentro, porque um icosaedro com metade das faces ao
## contrário renderiza buraco, não pedra.
static func _rostos() -> Array[Vector3i]:
	return [
		Vector3i(0, 11, 5), Vector3i(0, 5, 1), Vector3i(0, 1, 7), Vector3i(0, 7, 10),
		Vector3i(0, 10, 11), Vector3i(1, 5, 9), Vector3i(5, 11, 4), Vector3i(11, 10, 2),
		Vector3i(10, 7, 6), Vector3i(7, 1, 8), Vector3i(3, 9, 4), Vector3i(3, 4, 2),
		Vector3i(3, 2, 6), Vector3i(3, 6, 8), Vector3i(3, 8, 9), Vector3i(4, 9, 5),
		Vector3i(2, 4, 11), Vector3i(6, 2, 10), Vector3i(8, 6, 7), Vector3i(9, 8, 1),
	]


## Malha + rostos depois de `niveis` subdivisões, com o ponto médio de cada aresta projectado na
## esfera e nunca duplicado — é por essa chave de aresta que a superfície fica fechada.
static func _subdividir(niveis: int) -> Array:
	var verts := _icosaedro()
	var faces := _rostos()
	for nivel in range(niveis):
		var novos: Array[Vector3] = verts.duplicate()
		var arestas: Dictionary = {}
		var saida: Array[Vector3i] = []
		for face in faces:
			var a := _meio(novos, arestas, face.x, face.y)
			var b := _meio(novos, arestas, face.y, face.z)
			var c := _meio(novos, arestas, face.z, face.x)
			saida.append(Vector3i(face.x, a, c))
			saida.append(Vector3i(face.y, b, a))
			saida.append(Vector3i(face.z, c, b))
			saida.append(Vector3i(a, b, c))
		verts = novos
		faces = saida
	return [verts, faces]


static func _meio(verts: Array[Vector3], arestas: Dictionary, i: int, j: int) -> int:
	var chave := mini(i, j) * 1000 + maxi(i, j)
	if arestas.has(chave):
		return int(arestas[chave])
	var indice := verts.size()
	verts.append((verts[i] + verts[j]).normalized())
	arestas[chave] = indice
	return indice


## Três direções de lóbulo por variante: são o "batata" da pedra. Vêm do hash da variante, então
## a mesma variante sempre inchada nos mesmos três eixos em qualquer montada.
static func _eixos_lobo(variante: int) -> Array[Vector3]:
	var eixos: Array[Vector3] = []
	for k in range(3):
		var cru := Vector3(
			_bruto(k, variante, 17) * 2.0 - 1.0,
			_bruto(k, variante, 23) * 2.0 - 1.0,
			_bruto(k, variante, 29) * 2.0 - 1.0)
		eixos.append(cru.normalized() if cru.length_squared() > 1e-12 else Vector3.UP)
	return eixos


static func _montar(variante: int) -> ArrayMesh:
	var base := _subdividir(SUBDIVISOES)
	var dirs: Array[Vector3] = base[0]
	var faces: Array[Vector3i] = base[1]
	var eixos := _eixos_lobo(variante)
	var estira: Vector3 = ESTIRAMENTOS[variante]
	var puxados: Array[Vector3] = []
	var maior := 0.0
	for i in range(dirs.size()):
		var grao := _bruto(i, variante, 3) * 0.55 + _bruto(i * 7 + 3, variante, 11) * 0.45
		var lobo := 0.0
		for eixo in eixos:
			lobo += absf(dirs[i].dot(eixo))
		lobo /= float(eixos.size())
		var forma := clampf(PESO_GRAO * grao + PESO_LOBO * lobo, 0.0, 1.0)
		var ponto := dirs[i] * lerpf(PUXO_MINIMO, 1.0, forma) * estira
		maior = maxf(maior, ponto.length())
		puxados.append(ponto)
	# A inscrição é aqui, não num teto de asserção: dividir pelo maior vértice faz o maior valer
	# 1,0 exato e puxa todo o resto para dentro junto.
	var escala := 1.0 / maior
	var vertices := PackedVector3Array()
	var normais := PackedVector3Array()
	var uvs := PackedVector2Array()
	for face in faces:
		var v0 := puxados[face.x] * escala
		var v1 := puxados[face.y] * escala
		var v2 := puxados[face.z] * escala
		var normal := (v1 - v0).cross(v2 - v0)
		var centro := (v0 + v1 + v2) / 3.0
		if normal.dot(centro) < 0.0:
			var trocado := v1
			v1 = v2
			v2 = trocado
			normal = -normal
		for canto in [v0, v1, v2]:
			vertices.append(canto)
			normais.append(normal.normalized())
			uvs.append(_uv_de(canto))
	var superficie: Array = []
	superficie.resize(Mesh.ARRAY_MAX)
	superficie[Mesh.ARRAY_VERTEX] = vertices
	superficie[Mesh.ARRAY_NORMAL] = normais
	superficie[Mesh.ARRAY_TEX_UV] = uvs
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, superficie)
	return malha


## Pele em projeção equidistante, lida da direção do vértice e não da posição: é o que faz a
## textura de rocha cobrir a pedra inteira em vez de se acumular num canto. O seam em u = 0/1 é
## um rosto de 80 e a placa é grão de ruído — não se lê.
static func _uv_de(direcao: Vector3) -> Vector2:
	var d := direcao.normalized()
	return Vector2(
		0.5 + atan2(d.z, d.x) / TAU,
		0.5 - asin(clampf(d.y, -1.0, 1.0)) / PI)
