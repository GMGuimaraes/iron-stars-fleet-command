extends RefCounted
## Esquadra de blocos: a massa que navega em volta dos doze núcleos.
##
## Um bloco não é uma nave: são ~100 cascos voando em formação fechada, desenhados como a MESMA
## nave replicada numa grade de 4 × 3 × 2 = vinte e quatro casas — um paralelepípedo organizado.
## A tropa existe como `Dictionary` e como transformada autorgada num `MultiMesh`; não há nó por
## bloco nem nó por casa. Cento e vinte blocos por lado, vinte e quatro casas cada, dois
## `MultiMeshInstance3D` na cena: é assim que a batalha passa de doze cascos para dezenas de
## milhares de navios sem virar dezenas de milhares de draw calls.
##
## Atrito é a economia da massa: `navios` é recurso que se gasta. O impacto consome casas do topo
## para baixo, o bloco encolhe à vista, e o fogo devolvido sai proporcional ao que ainda restou.
## CASCO É o próprio `navios` — não existe segunda contabilidade para o mesmo casco; MOTORES,
## ARMAS e TRIPULAÇÃO são os outros três eixos, no mesmo pé dos quatro setores dos núcleos. Só o
## casco não se conserta: navio afundado não volta. TRIPULACAO a zero é rendição, uma vez só.
##
## Lei da casa, respeitada à letra: nada aqui toca `rng` nem `visual_rng`. A casa é o índice, o
## rumo sai da velocidade real e o setor escolhido é `(id + número da salva) % 4` — rotação, não
## sorteio. A prova está em `tools/probes/esquadra.gd`, que relê os dois geradores depois de
## duzentos quadros de massa e de cem trocas de salva.
##
## Lei da cena, respeitada à letra: a transformada é escrita AQUI e nunca lida de volta do
## `MultiMesh` — sob headless a leitura devolve identidade. O estado verdadeiro mora nas duas
## listas; a pintura é derivação pura, e um bloco parado com o mesmo número de casas não é
## repintado.

## Grade de casas do bloco. Quatro de boreste a bombordo, três camadas de altura, duas de
## profundidade: 24 é o que fecha o orçamento acordado (240 blocos × 24 = 5 760 instâncias) e é
## grosso o bastante para o atrito ser lido de longe.
const CASAS_X := 4
const CASAS_Y := 3
const CASAS_Z := 2
const CASAS := CASAS_X * CASAS_Y * CASAS_Z
## Passo entre casas: 1,6 u com a réplica a 0,25 (boca medida de 0,912 u) deixa 0,688 u de costura
## sem desfazer o volume — o bloco se lê como UM bloco, não como enxame.
const PASSO_CASA := 1.6
## Escala da réplica sobre a malha de cinco bilhetes. A boca é lida da caixa da malha escalada, não
## de conta de cabeça: **3,647 u de asa a asa × 0,25 fecha 0,912 u** dentro da casa de 1,6, com
## 0,688 u de folga entre duas fileiras — que é o que separa "bloco organizado" de "mancha" e o que
## a régua de vão de `tools/probes/massa_visivel.gd` confere no visor (casa 0,800 contra vão 0,036).
## O bloco não escala com o atrito: quem encolhe é o número de
## casas, única leitura honesta de "fileiras perdidas".
const ESCALA_REPLICA := 0.25

## Grade do esquadrão: 5 × 4 blocos = 20. Passo separado em x e z porque o bloco não é quadrado: o
## piso do bloco fecha 6,4 × 3,2 u (4 × 2 casas de 1,6), e um passo único obrigaria o respiro de
## vante a ser o mesmo de boreste.
const COLUNAS_NO_ESQUADRAO := 5
const LINHAS_NO_ESQUADRAO := 4
const BLOCOS_NO_ESQUADRAO := COLUNAS_NO_ESQUADRAO * LINHAS_NO_ESQUADRAO
## 8 em x abre 1,6 u de costura entre blocos vizinhos; 5 em z abre 1,8 sobre os 3,2 do piso. É o
## mínimo que ainda deixa o bloco ler como bloco — e o que cabe na profundidade que a separação das
## duas linhas permite.
const PASSO_BLOCO_X := 8.0
const PASSO_BLOCO_Z := 5.0
## Grade do lado: 3 × 2 esquadrões = 6, um por faixa lateral — na mesma ordem de boreste dos seis
## núcleos. Campo de 15 × 8 blocos.
const COLUNAS_NO_LADO := 3
const LINHAS_NO_LADO := 2
const ESQUADROES_NO_LADO := COLUNAS_NO_LADO * LINHAS_NO_LADO
## Passo de CONTINUAÇÃO de grade, não de respiro: 40 = (5 − 1) × 8 + 8 e 20 = (4 − 1) × 5 + 5, então
## o bloco que fecha um esquadrão e o que abre o vizinho ficam à mesma distância dos colegas de
## dentro. Com 36 × 22 a costura entre esquadrões saía 4 u em x — menor que os 6,4 do piso, e dois
## blocos de esquadrões vizinhos se sobrepunham. A profundidade do LADO sai 20 + 15 = 35 u, ±17,5 em
## torno do núcleo: com as duas linhas a ~45 u uma da outra, as fachadas ficam a ~10 u e nenhum bloco
## aliado atravessa um hostil. O par antigo 52 × 44 dava ±40 de profundidade e fazia as duas esquadras
## se sobreporem no centro da linha.
const PASSO_ESQUADRAO_X := 40.0
const PASSO_ESQUADRAO_Z := 20.0
const BLOCOS_NO_LADO := ESQUADROES_NO_LADO * BLOCOS_NO_ESQUADRAO
## Instâncias de um `MultiMesh` de lado: é a conta que o probe confere. Um lote só por time é o que
## impede a esquadra de custar uma chamada de desenho por casa; o preço real medido em janela está em
## `tools/probes/massa_visivel.gd` (11,9 chamadas para os 240 blocos, não as "duas" prometidas).
const INSTANCIAS_POR_LADO := BLOCOS_NO_LADO * CASAS

## Lotiação de um bloco, em cascos de linha. A casa vale ⌈100 / 24⌉ = 5 navios; a última pode
## valer menos e é ela que some primeiro.
const NAVIOS_NO_BLOCO := 100
## Marcha da massa, em u/s: um bloco cruza a faixa do próprio esquadrão (32 u de largura) em cinco
## segundos, o bastante para a manobra ser lida no visor sem a linha virar formiga.
const MARCHA_DE_BLOCO := 6.0
## Dano de canhão de um bloco inteiro por salva, antes de escalar por navios e ARMAS. Um quinto
## do golpe de um casco de linha: vinte blocos equivalem a ~4 cascos de linha de fogo, e a
## contagem da massa chega ao mesmo fim da contagem dos núcleos em dezenas de salvas, não em duas.
const DANO_DE_BLOCO := 2.2
## Alcance de linha de batalha. É o que faz o atrito ser LOCAL: só a faixa que encosta a faixa do
## outro lado queima, e o bloco de retaguarda continua com as vinte casas — a vista que separa
## "batalha massiva" de "todo mundo morrendo junto".
const ALCANCE_DE_BLOCO := 60.0
## Reparo dos três eixos que se consertam, por segundo. Casco fica de fora de propósito.
const REPARO := {"MOTORES": 1.1, "ARMAS": 0.9, "TRIPULACAO": 0.6}
## Os quatro eixos que uma salva pode cobrar, em rotação. `CASCO` é o valor de `navios`, não uma
## chave do dicionário — por isso a escrita dele tem caminho próprio em `_aplicar_golpe`.
const SETORES_DA_SALVA := ["CASCO", "MOTORES", "ARMAS", "TRIPULACAO"]
## Piso de tripulação de um bloco rendido: sem ele, o mesmo bloco voltaria a zero na salva
## seguinte e cruzaria o tabuleiro de lado a cada 1,6 s.
const TRIPULACAO_DE_PRESA := 24.0

var blocos_aliados: Array[Dictionary] = []
var blocos_hostis: Array[Dictionary] = []
## Âncora de cada lado: centro de massa dos núcleos vivos. A esquadra segue a linha; a linha não
## segue a esquadra — os doze cascos continuam mandando no próprio posicionamento.
var centro_aliado := Vector3.ZERO
var centro_hostil := Vector3.ZERO
var salva_numero := 0
var perdas_aliadas := 0
var perdas_hostis := 0
var presas := 0
## Quantos blocos cruzaram para o outro lado NA SALVA que acabou de resolver: é o que
## `troca_salva` devolve, e é lido depois de `_prencher_rendicoes` consumir as marcas.
var _rendidas_na_ultima_salva := 0
## Quantas casas cada `MultiMesh` tem de fato escritas. A rendição encolhe uma lista, e a cauda que
## ela pintou fica órfã: sem este registro os vinte e quatro transformados do bloco que partiu
## continuariam no ar, um bloco fantasma pendurado na tela do lado que o perdeu. Sobrevive de
## propósito ao `montar()` — é a contagem da partida ANTERIOR que diz o que há para apagar.
var _casas_pintadas := {"aliado": 0, "hostil": 0}

## Ordem da casa dentro do bloco: camada por camada, de baixo para cima; dentro da camada, da
## boreste para a bombordo e de vante para trás. É esta ordem que faz o atrito FECHAR O TOPO do
## paralelepípedo em vez de esburacá-lo no meio — a silhueta encolhendo é a própria leitura da
## lotação restante.
static func casa_local(c: int) -> Vector3:
	var por_camada := CASAS_X * CASAS_Z
	var camada := int(float(c) / float(por_camada))
	var dentro := c % por_camada
	var ix := dentro % CASAS_X
	var iz := int(float(dentro) / float(CASAS_X))
	return Vector3(
		(float(ix) - float(CASAS_X - 1) / 2.0) * PASSO_CASA,
		(float(camada) - float(CASAS_Y - 1) / 2.0) * PASSO_CASA,
		(float(iz) - float(CASAS_Z - 1) / 2.0) * PASSO_CASA)


## Posto do bloco na grade do lado: posição do esquadrão no tabuleiro do lado mais o posto do
## bloco dentro do esquadrão. Aritmética pura de índice, sem sorteio e sem leitura de cena.
static func posto_no_lado(esq: int, indice: int, ancora: Vector3) -> Vector3:
	var coluna_esq := esq % COLUNAS_NO_LADO
	var linha_esq := int(float(esq) / float(COLUNAS_NO_LADO))
	var bc := indice % COLUNAS_NO_ESQUADRAO
	var br := int(float(indice) / float(COLUNAS_NO_ESQUADRAO))
	return ancora + Vector3(
		(float(coluna_esq) - float(COLUNAS_NO_LADO - 1) / 2.0) * PASSO_ESQUADRAO_X
			+ (float(bc) - float(COLUNAS_NO_ESQUADRAO - 1) / 2.0) * PASSO_BLOCO_X,
		0.0,
		(float(linha_esq) - float(LINHAS_NO_LADO - 1) / 2.0) * PASSO_ESQUADRAO_Z
			+ (float(br) - float(LINHAS_NO_ESQUADRAO - 1) / 2.0) * PASSO_BLOCO_Z)


func _novo_bloco(id: int, esq: int, indice: int, lado: String, pos: Vector3) -> Dictionary:
	return {"id": id, "esquadrao": esq, "formacao": indice, "lado": lado, "pos": pos,
		"vel": Vector3.ZERO, "rumo": 0.0, "navios": float(NAVIOS_NO_BLOCO),
		"MOTORES": 100.0, "ARMAS": 100.0, "TRIPULACAO": 100.0, "vivo": true, "presa": false,
		"rendicao": false,
		"pintas": {"casas": -1, "pos": Vector3(1e9, 0.0, 0.0), "rumo": 1e9}}


## ---- A nave replicada ----
##
## Cinco bilhetes fundidos numa única `ArrayMesh`: espinha, proa em cone, popa, dorso e as duas
## asas. É a MESMA família de silhueta do cruzador de linha dos núcleos, compactada para caber na
## casa de 1,6 u — o bloco precisa de fileiras que se leiam como fileiras, e a malha crua mede
## 3,647 × 1,07 × 5,0 u, então um casco deste tamanho dentro de uma casa de 1,6 viraria borrão
## sobreposto. Boca final **0,912 u** lida da caixa escalada, folga de **0,688 u** para o
## vizinho, e o paralelepípedo continua sendo lido como um volume só.
##
## Fundir é o que paga a conta: com uma malha só por time, 2 880 casas viram UM `MultiMesh` e um
## lote. Com cinco primitivas separadas seriam cinco passadas de desenho por time — ainda barato, mas
## a lei da casa é a de `campo_estelar`: o céu inteiro cabe numa instância.
var _malha: ArrayMesh = null


func malha_replica() -> ArrayMesh:
	if _malha != null:
		return _malha
	var partes: Array = [
		[_caixa(Vector3(1.2, 0.5, 3.0)), Transform3D(Basis(), Vector3.ZERO)],
		[_cone(0.5, 0.06, 1.2), Transform3D(
			Basis.from_euler(Vector3(-PI / 2.0, 0.0, 0.0)), Vector3(0.0, 0.0, -2.1))],
		[_caixa(Vector3(1.5, 0.6, 0.8)), Transform3D(Basis(), Vector3(0.0, 0.02, 1.9))],
		[_caixa(Vector3(0.6, 0.3, 1.9)), Transform3D(Basis(), Vector3(0.0, 0.42, -0.4))],
	]
	for lado in [-1.0, 1.0]:
		partes.append([_caixa(Vector3(1.0, 0.12, 1.8)), Transform3D(
			Basis.from_euler(Vector3(0.0, lado * 0.42, 0.0)), Vector3(lado * 1.0, -0.02, 0.6))])
	var vertices := PackedVector3Array()
	var normais := PackedVector3Array()
	var uvs := PackedVector2Array()
	for parte in partes:
		_fundir(vertices, normais, uvs, parte[0], parte[1])
	var superficie: Array = []
	superficie.resize(Mesh.ARRAY_MAX)
	superficie[Mesh.ARRAY_VERTEX] = vertices
	superficie[Mesh.ARRAY_NORMAL] = normais
	superficie[Mesh.ARRAY_TEX_UV] = uvs
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, superficie)
	_malha = malha
	return malha


static func _caixa(size: Vector3) -> BoxMesh:
	var caixa := BoxMesh.new()
	caixa.size = size
	return caixa


## Cone de proa. Oito segmentos bastam para 1,2 u de comprimento lidos a 40 u da câmara, e é o
## mesmo `radial` dos cones de proa nos núcleos.
static func _cone(r_base: float, r_top: float, height: float) -> CylinderMesh:
	var cone := CylinderMesh.new()
	cone.bottom_radius = r_base
	cone.top_radius = r_top
	cone.height = height
	cone.rings = 1
	cone.radial_segments = 8
	return cone


## Copia uma primitiva para dentro dos arrays fundidos, aplicando a transformada em vértice e em
## normal. Índices são expandidos: a malha final é não-indexada, como a do geoide.
static func _fundir(vertices: PackedVector3Array, normais: PackedVector3Array,
		uvs: PackedVector2Array, malha: PrimitiveMesh, xf: Transform3D) -> void:
	var s := malha.surface_get_arrays(0)
	var v: PackedVector3Array = s[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = s[Mesh.ARRAY_NORMAL]
	var t: PackedVector2Array = s[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = s[Mesh.ARRAY_INDEX]
	var ordem := idx
	if ordem.is_empty():
		ordem = PackedInt32Array()
		for k in range(v.size()):
			ordem.append(k)
	var com_uv := t.size() == v.size()
	for k in ordem:
		vertices.append(xf * v[k])
		# Normal vai pela base e se renormaliza: com escala uniforme (é o caso) isso é exato, e
		# sem renormalizar a réplica perderia o degradê de metal que o Compatibility lê da difusa.
		normais.append((xf.basis * n[k]).normalized())
		if com_uv:
			uvs.append(t[k])
		else:
			uvs.append(Vector2.ZERO)


## Monta as duas massas. `nucleos_*` são as posições dos doze cascos de hoje: a muralha de um lado é
## ANCORADA NO CENTRO DE MASSA dos seus núcleos, e o esquadrão `i` ocupa a faixa `i` da muralha, na
## mesma ordem de boreste do casco `i`. Ancorar cada esquadrão no PRÓPRIO núcleo foi tentado e é
## mentira de grade: os cascos estão a ~5 u uns dos outros e o passo da massa é 8 × 5, então as seis
## grades particulares saíam deslocadas entre si e 36 pares de companheiros de linha se atravessavam
## (medido em `tools/probes/esquadra.gd`). Uma grade por lado é o que faz a formação ser lida como
## formação.
func montar(nucleos_aliados: Array, nucleos_hostis: Array) -> void:
	blocos_aliados.clear()
	blocos_hostis.clear()
	salva_numero = 0
	perdas_aliadas = 0
	perdas_hostis = 0
	presas = 0
	centro_aliado = _centro_de(nucleos_aliados)
	centro_hostil = _centro_de(nucleos_hostis)
	var id := 0
	for lado in ["aliado", "hostil"]:
		var lista := blocos_aliados if lado == "aliado" else blocos_hostis
		var ancora := centros(lado)
		for esq in range(ESQUADROES_NO_LADO):
			for indice in range(BLOCOS_NO_ESQUADRAO):
				lista.append(_novo_bloco(id, esq, indice, lado,
					posto_no_lado(esq, indice, ancora)))
				id += 1


static func _centro_de(nucleos: Array) -> Vector3:
	if nucleos.is_empty():
		return Vector3.ZERO
	var soma := Vector3.ZERO
	for n in nucleos:
		soma += n
	return soma / float(nucleos.size())


func centros(lado: String) -> Vector3:
	return centro_aliado if lado == "aliado" else centro_hostil


func lista_de(lado: String) -> Array[Dictionary]:
	return blocos_aliados if lado == "aliado" else blocos_hostis


## Casas vivas do bloco: o topo fecha primeiro. Sem navio não há casa, e zero casas é o que mata.
static func casas_vivas(bloco: Dictionary) -> int:
	var frac := clampf(float(bloco["navios"]) / float(NAVIOS_NO_BLOCO), 0.0, 1.0)
	if frac <= 0.0:
		return 0
	return maxi(1, int(ceilf(frac * float(CASAS))))


## Um quadro de massa: cada bloco persegue o posto do seu esquadrão, e o posto persegue o núcleo.
## `move_toward`, nunca teleportar — é a mesma lei que faz as formações dos doze cascos levarem
## tempo de locomoção.
func passo(delta: float, nucleos_aliados: Array, nucleos_hostis: Array) -> void:
	centro_aliado = _centro_de(nucleos_aliados)
	centro_hostil = _centro_de(nucleos_hostis)
	for lado in ["aliado", "hostil"]:
		for b in lista_de(lado):
			if not bool(b["vivo"]):
				continue
			var posto := posto_no_lado(int(b["esquadrao"]), int(b["formacao"]), centros(lado))
			var partida: Vector3 = b["pos"]
			var marcha := MARCHA_DE_BLOCO * (0.35 + float(b["MOTORES"]) / 100.0 * 0.65)
			b["pos"] = (b["pos"] as Vector3).move_toward(posto, delta * marcha)
			b["vel"] = ((b["pos"] as Vector3) - partida) / maxf(delta, 0.0001)
			# Rumo só com deslocamento real: parado, o bloco segura o último ângulo em vez de
			# virar 90° para olhar o próprio eixo nulo.
			if (b["vel"] as Vector3).length_squared() > 0.0004:
				b["rumo"] = atan2(b["vel"].x, -b["vel"].z)
	_reparar(delta)


## Os três eixos que se consertam sobem até o teto, na taxa cravada. O casco fica de fora: é a
## diferença entre uma tropa que se recompõe e um recurso que se gasta.
func _reparar(delta: float) -> void:
	for lado in ["aliado", "hostil"]:
		for b in lista_de(lado):
			if not bool(b["vivo"]):
				continue
			for eixo in REPARO:
				b[eixo] = minf(100.0, float(b[eixo]) + float(REPARO[eixo]) * delta)


static func _mais_proximo(bloco: Dictionary, lista: Array[Dictionary]) -> Dictionary:
	var melhor: Dictionary = {}
	var melhor_d := INF
	for c in lista:
		if not bool(c["vivo"]):
			continue
		var d: float = (c["pos"] as Vector3).distance_to(bloco["pos"])
		if d < melhor_d and d <= ALCANCE_DE_BLOCO:
			melhor_d = d
			melhor = c
	return melhor


## A troca de salvas da massa. Fecha o ledger do bloco sem encostar no ledger dos doze cascos: a
## contagem que as sondas dos núcleos assinam não ganha uma linha, e é por isso que a massa é um
## segundo corpo no tabuleiro, não um multiplicador dos doze canhões que já existem.
func troca_salva() -> Dictionary:
	salva_numero += 1
	var lancados := 0
	var feridos := 0
	var afundados := 0
	var rendidos := 0
	# Os dois lados atiram sobre o retrato do QUADRO ANTERIOR: se o aliado resolvesse primeiro,
	# o hostil devolveria fogo contra uma massa que já encolheu, e a ordem do laço mudaria o
	# resultado. `destinos` é a fila de pares lida antes de qualquer escrita.
	var pares: Array[Dictionary] = []
	for lado in ["aliado", "hostil"]:
		var alvos := lista_de("hostil" if lado == "aliado" else "aliado")
		for b in lista_de(lado):
			if not bool(b["vivo"]) or float(b["ARMAS"]) <= 0.0 or float(b["navios"]) <= 0.0:
				continue
			var alvo := _mais_proximo(b, alvos)
			if not alvo.is_empty():
				pares.append({"origem": b, "alvo": alvo})
	for par in pares:
		lancados += 1
		var origem: Dictionary = par["origem"]
		var alvo: Dictionary = par["alvo"]
		var dano := DANO_DE_BLOCO * (float(origem["navios"]) / float(NAVIOS_NO_BLOCO)) \
			* (0.25 + float(origem["ARMAS"]) / 100.0 * 0.75)
		var eixo: String = SETORES_DA_SALVA[
			(int(origem["id"]) + salva_numero) % SETORES_DA_SALVA.size()]
		if _aplicar_golpe(alvo, eixo, dano):
			afundados += 1
		else:
			feridos += 1
	# A contagem de rendições é feita DEPOIS de `_prencher_rendicoes`, que é quem consome a marca:
	# limpar `rendicao` aqui deixaria a mudança de lista sem nada para mover.
	_prencher_rendicoes()
	rendidos = _rendidas_na_ultima_salva
	return {"lancados": lancados, "feridos": feridos, "afundados": afundados,
		"rendidos": rendidos, "salva": salva_numero}


## Um golpe no eixo escolhido. Devolve `true` se o bloco afundou.
func _aplicar_golpe(alvo: Dictionary, eixo: String, dano: float) -> bool:
	# Cadáver não leva tiro: sem esta guarda o segundo impacto num bloco que acabou de afundar
	# tornava a entrar aqui, `navios` já estava em 0 e a perda era contada duas vezes — e um bloco
	# morto podia marcar rendição e cruzar o tabuleiro para o lado errado.
	if not bool(alvo["vivo"]):
		return false
	var lado := String(alvo["lado"])
	if eixo == "CASCO":
		alvo["navios"] = maxf(0.0, float(alvo["navios"]) - dano * 1.4)
		if float(alvo["navios"]) <= 0.0:
			alvo["vivo"] = false
			if lado == "aliado":
				perdas_aliadas += 1
			else:
				perdas_hostis += 1
			return true
	elif eixo == "TRIPULACAO":
		alvo[eixo] = maxf(0.0, float(alvo[eixo]) - dano * 1.1)
		if float(alvo[eixo]) <= 0.0 and not bool(alvo["presa"]):
			# A rendição não troca de lista no meio do laço — os índices que a pintura usa
			# mudariam sob os pés dela. Marca e fecha no fim, em `_prencher_rendicoes`.
			alvo["rendicao"] = true
	else:
		alvo[eixo] = maxf(0.0, float(alvo[eixo]) - dano * 1.3)
	return false


## Move os blocos rendidos de lado, uma única vez. Presa nova recebe o piso de tripulação e o
## carimbo `presa`, que é o que impede o vaivém de um mesmo bloco entre as duas linhas.
##
## O teto de instâncias é a razão pela qual esta função existe em duas partes. Cada lado tem
## `BLOCOS_NO_LADO` de casas no `MultiMesh`; sem despejar os afundados e sem conferir o teto, a
## primeira presa faria a lista receptora passar de cento e vinte e a pintura escreveria depois do
## fim da instância — o `MultiMesh` nem existe além daquele índice.
func _prencher_rendicoes() -> void:
	_rendidas_na_ultima_salva = 0
	var mudou := _expulsar_mortos() > 0
	for lado in ["aliado", "hostil"]:
		var velha := lista_de(lado)
		var nova := lista_de("hostil" if lado == "aliado" else "aliado")
		var viram: Array[Dictionary] = []
		for b in velha:
			if bool(b.get("rendicao", false)):
				viram.append(b)
		if viram.is_empty():
			continue
		for b in viram:
			velha.erase(b)
		mudou = true
		for b in viram:
			# Não há banco: a presa que não cabe no `MultiMesh` do receptor morre no campo em vez
			# de estourar a conta. É perda do lado que a perdeu, contada como afundamento.
			if nova.size() >= BLOCOS_NO_LADO:
				b["rendicao"] = false
				b["vivo"] = false
				if lado == "aliado":
					perdas_aliadas += 1
				else:
					perdas_hostis += 1
				continue
			b["lado"] = "hostil" if lado == "aliado" else "aliado"
			b["presa"] = true
			b["rendicao"] = false
			b["TRIPULACAO"] = TRIPULACAO_DE_PRESA
			b["pintas"]["casas"] = -1
			nova.append(b)
			presas += 1
			_rendidas_na_ultima_salva += 1
	# A base de instância é índice × CASAS. Qualquer apagamento corre a lista para cima, e o "limpo"
	# que cada bloco carrega passou a ser mentira — a linha sairia trocada de lugar na tela. É só
	# marcação suja; quem repinta é o próximo `pintar`.
	if mudou:
		for b in blocos_aliados:
			b["pintas"]["casas"] = -1
		for b in blocos_hostis:
			b["pintas"]["casas"] = -1
	_recrutar_postos()


## Recoloca os blocos sem posto. Toda rendição mexe com a lista, e a lista é a base do índice de
## instância enquanto `esquadrao`/`formacao` são a base da grade: sem esta passada, o bloco capturado
## chegaria com o posto do gêmeo que já mora no receptor e os dois passariam o resto da partida
## disputando o mesmo ponto do chão. Quem tem posto exclusivo não se mexe — só os sem-teto escolhem
## buraco, e escolhem o mais perto, em ordem de lista. Determinístico, sem sorteio e sem recomeçar a
## formação inteira a cada salva.
func _recrutar_postos() -> void:
	for lado in ["aliado", "hostil"]:
		var lista := lista_de(lado)
		var donos := {}
		var sem_teto: Array[Dictionary] = []
		for b in lista:
			var posto := int(b["esquadrao"]) * BLOCOS_NO_ESQUADRAO + int(b["formacao"])
			if donos.has(posto):
				sem_teto.append(b)
			else:
				donos[posto] = true
		if sem_teto.is_empty():
			continue
		var livres: Array[int] = []
		for p in range(BLOCOS_NO_LADO):
			if not donos.has(p):
				livres.append(p)
		var ancora := centros(lado)
		for b in sem_teto:
			if livres.is_empty():
				break
			var escolhido := 0
			var menor_d := INF
			for k in livres.size():
				var p: int = livres[k]
				var d: float = (b["pos"] as Vector3).distance_squared_to(posto_no_lado(
					int(float(p) / float(BLOCOS_NO_ESQUADRAO)),
					p % BLOCOS_NO_ESQUADRAO, ancora))
				if d < menor_d:
					menor_d = d
					escolhido = k
			var posto: int = livres[escolhido]
			livres.remove_at(escolhido)
			b["esquadrao"] = int(float(posto) / float(BLOCOS_NO_ESQUADRAO))
			b["formacao"] = posto % BLOCOS_NO_ESQUADRAO


## Tira das duas listas todo bloco que afundou. A lista é a base de índice do `MultiMesh`: um
## cadáver que fica pendurado lá ocupa uma casa de instância e rouba do próximo sobrevivente o
## posto que a pintura dele vai escrever. O sumiço é a lei — um bloco morto continua morto, só
## para de sentar banco.
func _expulsar_mortos() -> int:
	var removidos := 0
	for lado in ["aliado", "hostil"]:
		var lista := lista_de(lado)
		var mortos: Array[Dictionary] = []
		for b in lista:
			if not bool(b["vivo"]):
				mortos.append(b)
		for b in mortos:
			lista.erase(b)
			removidos += 1
	return removidos


## Repinta o `MultiMesh` de um lado. Devolve quantos blocos foram de fato escritos, número que a
## sonda confere: parado e inteiro, o bloco não custa uma escrita.
func pintar(mm: MultiMesh, lado: String, forcar := false) -> int:
	var lista := lista_de(lado)
	var tocados := 0
	for i in range(lista.size()):
		var b: Dictionary = lista[i]
		var base := i * CASAS
		var casas := casas_vivas(b) if bool(b["vivo"]) else 0
		var pintado: Dictionary = b["pintas"]
		var sujo := forcar or casas != int(pintado["casas"]) \
			or (b["pos"] as Vector3).distance_squared_to(pintado["pos"]) > 0.0001 \
			or absf(float(b["rumo"]) - float(pintado["rumo"])) > 0.001
		if not sujo:
			continue
		tocados += 1
		pintado["casas"] = casas
		pintado["pos"] = b["pos"]
		pintado["rumo"] = float(b["rumo"])
		var origem: Vector3 = b["pos"]
		var rot := Basis.from_euler(Vector3(0.0, float(b["rumo"]), 0.0))
		var escala := Vector3.ONE * ESCALA_REPLICA
		var girada := rot.scaled(escala)
		for c in range(CASAS):
			if c < casas:
				mm.set_instance_transform(base + c,
					Transform3D(girada, origem + (rot * casa_local(c))))
			else:
				# Base nula é o "escondido" do MultiMesh: triângulo degenerado, nada rasteriza,
				# e o orçamento de instâncias não muda — a casa some sem o motor realocar nada.
				mm.set_instance_transform(base + c, Transform3D(Basis(), origem))
	# A lista encolheu (rendição, ou reset com menos blocos): a cauda que o lado pintou na última
	# vez não pertence a bloco nenhum agora, e ficar calado aqui deixa um bloco fantasma de 24
	# casas pendurado no campo. Apaga-se pela contagem antiga, não pela lista.
	var limite := lista.size() * CASAS
	var pintadas := int(_casas_pintadas[lado])
	if pintadas > limite:
		for k in range(limite, pintadas):
			mm.set_instance_transform(k, Transform3D(Basis(), Vector3.ZERO))
	_casas_pintadas[lado] = limite
	return tocados


## Cor por instância: cinza do atrito e da tripulação morta. É o único canal que pinta dano num
## `MultiMesh` sem material por casa, e só precisa ser reescrito quando a lotação muda.
func pintar_cores(mm: MultiMesh, lado: String, cor_viva: Color) -> void:
	var lista := lista_de(lado)
	for i in range(lista.size()):
		var b: Dictionary = lista[i]
		var base := i * CASAS
		var frac := clampf(float(b["navios"]) / float(NAVIOS_NO_BLOCO), 0.0, 1.0)
		var trip := clampf(float(b["TRIPULACAO"]) / 100.0, 0.0, 1.0)
		var cor := cor_viva.lerp(Color(0.16, 0.17, 0.2), (1.0 - frac) * 0.7)
		cor = cor.lerp(Color(0.28, 0.22, 0.15), (1.0 - trip) * 0.5)
		for c in range(CASAS):
			mm.set_instance_color(base + c, cor)


func vivos(lado: String) -> int:
	var n := 0
	for b in lista_de(lado):
		if bool(b["vivo"]):
			n += 1
	return n


## Cascos que a massa ainda representa — a conta que o jogador pediu como "milhares de naves".
func navios(lado: String) -> int:
	var n := 0
	for b in lista_de(lado):
		if bool(b["vivo"]):
			n += int(roundf(float(b["navios"])))
	return n


## Caixa de desenho dos dois lados, no tabuleiro de hoje. A sonda mede e o README cita; é ela que
## prova que a massa cabe no campo sem invadir a borda.
func extensao() -> Dictionary:
	var minimo := Vector3(1e9, 1e9, 1e9)
	var maximo := Vector3(-1e9, -1e9, -1e9)
	for lado in ["aliado", "hostil"]:
		for b in lista_de(lado):
			if not bool(b["vivo"]):
				continue
			minimo = minimo.min(b["pos"])
			maximo = maximo.max(b["pos"])
	if minimo.x > maximo.x:
		return {"vazio": true}
	return {"vazio": false, "min": minimo, "max": maximo,
		"largura": maximo.x - minimo.x, "fundo": maximo.z - minimo.z}


## Linha do letreiro de cima e veredito da sonda, no mesmo formato: a massa é lida em blocos e em
## cascos, porque "120 blocos" sem o total de navios não é a conta que o jogador pediu.
func resumo() -> String:
	return "MASSA %d/%d • %dc // hostil %d/%d • %dc // %d rend." % [
		vivos("aliado"), BLOCOS_NO_LADO, navios("aliado"),
		vivos("hostil"), BLOCOS_NO_LADO, navios("hostil"), presas]
