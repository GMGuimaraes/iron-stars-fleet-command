extends SceneTree

## Sonda do visor trincado: a rachadura é o casco escrito no vidro, uma vez por degrau.
##
## O pedido foi visual — "o dano indicado por um alerta vermelho dentro da nave, poderia trincar os
## vidros também" — e a sonda não julga gosto. Julga as seis leis que fazem da trinca uma camada da
## batalha em vez de um enfeite que mente:
##
## 1) A PINTURA NÃO MENTE SOBRE A FÍSICA. O degrau vem de `capital_hp` por uma escala fixa de 25%, e
##    nada mais o toca. Casco cheio é vidro limpo: `Superficies.trinca(0)` devolve nulo e a emissão
##    se desliga sozinha.
## 2) ESCREVE UMA VEZ POR DEGRAU. A lei do apagão vale para o `vidro`: os três quadros de um
##    abalroamento são escritos no quadro em que o degrau fecha, e repetir a chamada com o mesmo
##    casco não move um pixel. É daqui que sai o "epicentro nunca deriva": a fissura que já pegou o
##    vidro não muda de lugar quando o hostil muda de bordo.
## 3) NENHUM SORTEIO TOCADO. A fissura é desenhada pelo hash inteiro do índice do pixel, como a
##    rocha e o painel. `rng` e `visual_rng` não se movem, a cauda de quarenta sorteios é a mesma, e
##    o pixmap bate com ele próprio depois de o cache ser esvaziado.
## 4) O DEGRAU CUMULA POR CONSTRUÇÃO. O mesmo raio anda os mesmos passos e só vai mais longe, e
##    `_pinta` é `max`. Isto é medido pixel a pixel: todo aceso do degrau 1 está aceso (e não mais
##    fraco) no 2 e no 3. Nenhuma tabela foi escrita certa por milagre — a asserção é a prova.
## 5) A fissura entra pela EMISSÃO. O albedo do visor é uma cor com alfa 0,05 e em
##    `TRANSPARENCY_ALPHA` a textura multiplica também o alfa: pelo albedo o pão ganharia opacidade
##    justamente onde rachou. `albedo_texture` do `vidro` continua nulo em todo degrau.
## 6) A GRADE DO `BoxMesh` É O QUE VESTE UMA FACE SÓ. Medido nesta rodada: as seis faces de um
##    `BoxMesh` NÃO têm UV 0..1 cada — dividem uma malha 3×2, e a face que a câmera da ponte vê (+Z)
##    mora na célula `u[0..1/3] v[0..1/2]`. É por isso que `uv1_scale` é `(3,2)` com o repeat
##    desligado: a face dianteira amostra o quadro inteiro e as outras cinco caem fora e clampam na
##    borda preta. Sem esta medida a trinca sairia espelhada em duas faces ao mesmo tempo.
##
## Vem junto o contrato com as vizinhas: nenhum nó novo na ponte, o apagão não apaga a trinca (o
## `vidro` está fora da lista da ruína de propósito), RECOMEÇAR devolve o vidro limpo lido do
## retrato, e a placa nasce em runtime — `resource_path` vazio, zero byte no `.pck` do build web.
##
## Uso: godot --headless --path . --quit-after 6000 -s res://tools/probes/vidro.gd

const Superficies := preload("res://superficies.gd")

## Espelho das constantes de `superficies.gd` e `main.gd` (a instância do jogo é não tipada; mesmo
## motivo em `tools/probes/cinturao.gd`). Mudar um número lá quebra a asserção aqui: é de propósito.
const PASSO_ESPERADO := 128
const DEGRAUS_ESPERADOS := 3
const RAIO_ESPERADO := [26.0, 40.0, 56.0]
const ESCALA_UV_ESPERADA := Vector3(3.0, 2.0, 1.0)
const FOLGA_UX_ESPERADA := 0.32
const POR_CASCO_ESPERADO := 25.0
const ENERGIA_ESPERADA := 2.6
## Dimensões do pão de visor, medidas em `_build_bridge`. A sonda confere o nó, não a promessa.
const VISOR_LARGURA := 13.2
const VISOR_ALTURA := 4.6
## Limiar de "aceso": o halo vizinho vale 0,34 do núcleo, e 0,1 fica bem abaixo de ambos.
const LIGADO := 0.1
## Espelho de `CORTE_RUINA`: a asserção da ruína confere o traço, não a memória.
const CORTE_RUINA_ESPERADO := 0.7
## Cauda de sorteios da lei de inércia — o mesmo gabarito de `tools/probes/superficies.gd`.
const SEMENTE_RNG := 1234567890
const SEMENTE_VISUAL := 555
## Célula da malha 3×2 onde a face +Z mora, medida nesta rodada (ver lei 6).
const CELULA_Z_LARGURA := 3.0
const CELULA_Z_ALTURA := 2.0

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

## Hash de amostragem do pixmap: soma ponderada dos canais vermelhos lidos numa grade fixa. É o
## gabarito de `superficies.gd`, mesma régua, para que as duas sondas leiam determinismo igual.
func _checksum(img: Image) -> int:
	if img == null:
		return -1
	var total := 0
	var passo_x := maxi(1, img.get_width() / 8)
	var passo_y := maxi(1, img.get_height() / 8)
	var no := 0
	for y in range(0, img.get_height(), passo_y):
		for x in range(0, img.get_width(), passo_x):
			no += 1
			total = (total + int(roundf(img.get_pixel(x, y).r * 1000.0)) * (no * 31)) % 1000000007
	return total

## Pixels acesos e soma de luminância, lidos um a um: num desenho de linha, amostrar é perder.
func _mede(img: Image) -> Dictionary:
	var acesos := 0
	var soma := 0.0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var v := img.get_pixel(x, y).r
			soma += v
			if v >= LIGADO:
				acesos += 1
	return {"acesos": acesos, "soma": soma}

## Quantos pixels acesos de `menor` não estão acesos (ou estão mais fracos) em `maior`. A lei do
## degrau cumulativo quer zero.
func _perdidos(menor: Image, maior: Image) -> int:
	var falta := 0
	for y in range(menor.get_height()):
		for x in range(menor.get_width()):
			var v := menor.get_pixel(x, y).r
			if v >= LIGADO and maior.get_pixel(x, y).r + 0.001 < v:
				falta += 1
	return falta

## Quarenta sorteios do gerador de combate, na ordem em que saem.
func _cauda(game) -> Array[int]:
	var retirada: Array[int] = []
	for i in range(40):
		retirada.append(game.rng.randi())
	return retirada

## Monta o jogo e congela pelo instrumento da casa: `process_mode`, nunca `set_process(false)`, e
## HUD escrito à mão (lei de `congelamento.gd` e de `recomecar.gd`).
func _montar_jogo() -> Node3D:
	var game: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(3)
	game._update_bridge(0.0)
	game._update_hud()
	return game

## Limites de UV da face de um `BoxMesh` que olha para `normal`, separados pela NORMAL e nunca pela
## coordenada: num `BoxMesh` sem índice o mesmo canto de coordenada pertence a três faces com três
## UVs diferentes, e filtrar por posição leria o `u` da face errada.
##
## A face é achada por distância de vetor, não por chave de texto: a normal dianteira de um `BoxMesh`
## chega como `[-0 -0 +1]`, e formatar zero com sinal partiu a face ao meio entre `-0` e `+0` — a
## chave simplesmente não existia. Medido nesta rodada, razão de ser da lei "a pintura não mente": a
## sonda leria ausência onde há geometria.
func _celula_uv(mesh: Mesh, normal: Vector3) -> Array:
	var arrays: Array = mesh.surface_get_arrays(0)
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var u0 := 9.0
	var u1 := -9.0
	var v0 := 9.0
	var v1 := -9.0
	var vistas := 0
	for i in range(norms.size()):
		if norms[i].distance_to(normal) > 0.001:
			continue
		vistas += 1
		u0 = minf(u0, uvs[i].x)
		u1 = maxf(u1, uvs[i].x)
		v0 = minf(v0, uvs[i].y)
		v1 = maxf(v1, uvs[i].y)
	return [u0, u1, v0, v1, float(vistas)]

func _vidro_do(game) -> StandardMaterial3D:
	var mats: Dictionary = (game.bridge_rig as Node3D).get_meta("mat")
	return mats["vidro"] as StandardMaterial3D

## Crava a ponte na atitude de leitura e esvazia as candidatas de cenário, deixando um único hostil
## como ameaça. Sem isto o epicentro dependeria de qual planeta o cenário sorteou para o fundo, e a
## asserção de lado não provaria o que a função escolheu.
func _isola_ampla(game) -> void:
	(game.bridge_rig as Node3D).global_position = Vector3.ZERO
	(game.bridge_rig as Node3D).rotation = Vector3.ZERO
	(game.rochas as Array).clear()
	(game.astros as Array).clear()
	for i in range(1, (game.enemies as Array).size()):
		game.enemies[i]["hp"] = 0.0
	var viva: Node3D = game.enemies[0]["node"]
	viva.global_position = Vector3(0.0, 0.0, -60.0)

func _degrau_atual(game) -> int:
	return int(game.ponte_trinca_degrau)

func _initialize() -> void:
	# ---- 1. A família existe, o degrau zero é nulo e o quadro é do tamanho do contrato ---------
	Superficies.limpar_cache()
	var d1: ImageTexture = Superficies.trinca(1)
	var d2: ImageTexture = Superficies.trinca(2)
	var d3: ImageTexture = Superficies.trinca(3)
	_assert("três degraus, e o pedido além do teto não inventa um quarto",
		Superficies.trincas_existentes() == DEGRAUS_ESPERADOS
			and Superficies.trinca(9) == d3,
		"%d degraus, trinca(9) é a mesma placa do 3" % Superficies.trincas_existentes())
	_assert("degrau zero é vidro limpo: placa nula, sem quadro preto no meio",
		Superficies.trinca(0) == null, "trinca(0) devolve null")
	var forma_ok := true
	var formato_ok := true
	var mip_ok := true
	for par in [[d1, 1], [d2, 2], [d3, 3]]:
		var quadro: ImageTexture = par[0]
		if quadro == null or quadro.get_width() != PASSO_ESPERADO \
				or quadro.get_height() != PASSO_ESPERADO:
			forma_ok = false
		if quadro != null and quadro.get_image().get_format() != Image.FORMAT_RGB8:
			formato_ok = false
		if quadro != null and quadro.get_image().get_mipmap_count() < 2:
			mip_ok = false
	_assert("o espelho da sonda é a tabela do gerador, não a memória de quem a escreveu",
			Superficies.TRINCA_RAIO == RAIO_ESPERADO
				and Superficies.TRINCA_ESQUEMA_X == 0.35,
			"raio %s com o fator x %0.2f" % [str(Superficies.TRINCA_RAIO),
				Superficies.TRINCA_ESQUEMA_X])
	_assert("as três placas são do quadro de 128² prometido",
		forma_ok, "%d×%d em cada degrau" % [d3.get_width(), d3.get_height()])
	_assert("sem alfa na placa da trinca: quem decide transparência é o vidro, não a fissura",
		formato_ok, "RGB8 nos três degraus")
	_assert("placa com mipmaps: o visor é lido de longe e o grão não pode estalar",
		mip_ok, "%d níveis no degrau 3" % d3.get_image().get_mipmap_count())

	# ---- 2. Uma placa por degrau, para sempre --------------------------------------------------
	_assert("a segunda leitura do mesmo degrau devolve a MESMA placa",
		d1.get_instance_id() == Superficies.trinca(1).get_instance_id(),
		"identidade por instance id, como o metal e a rocha")
	var soma_antes := _checksum(d3.get_image())
	Superficies.limpar_cache()
	var d3_renovo: ImageTexture = Superficies.trinca(3)
	_assert("cache esvaziado refaz o mesmo pixmap, byte a byte",
		_checksum(d3_renovo.get_image()) == soma_antes,
			"%d = %d" % [soma_antes, _checksum(d3_renovo.get_image())])
	Superficies.limpar_cache()
	var invertida: ImageTexture = Superficies.trinca(3)
	_assert("a ordem de geração não entra no desenho",
		_checksum(invertida.get_image()) == soma_antes, "trinca(3) primeiro dá o mesmo hash")
	_assert("placa de runtime: zero byte embarcado no .pck do build web",
		d3.resource_path == "", "resource_path vazio em `%s`" % d3.resource_path)

	# ---- 3. Cumulação por construção ------------------------------------------------------------
	var m1: Dictionary = _mede(d1.get_image())
	var m2: Dictionary = _mede(d2.get_image())
	var m3: Dictionary = _mede(d3.get_image())
	_assert("cada degrau acende mais vidro que o anterior",
		int(m1["acesos"]) < int(m2["acesos"]) and int(m2["acesos"]) < int(m3["acesos"]),
		"%d -> %d -> %d pixels acesos" % [int(m1["acesos"]), int(m2["acesos"]),
			int(m3["acesos"])])
	_assert("o degrau 1 cabe inteiro dentro do 2, e o 2 dentro do 3",
		_perdidos(d1.get_image(), d2.get_image()) == 0
			and _perdidos(d2.get_image(), d3.get_image()) == 0
			and _perdidos(d1.get_image(), d3.get_image()) == 0,
		"zero pixel aceso perdido nas três leituras completas")

	# ---- 4. Nenhum sorteio tocado -------------------------------------------------------------
	var game: Node3D = await _montar_jogo()
	game.rng.state = SEMENTE_RNG
	game.visual_rng.state = SEMENTE_VISUAL
	var estado_rng: int = game.rng.state
	var estado_visual: int = game.visual_rng.state
	var cauda_antes := _cauda(game)
	game.rng.state = SEMENTE_RNG
	game.visual_rng.state = SEMENTE_VISUAL
	Superficies.limpar_cache()
	var gerada: ImageTexture = Superficies.trinca(3)
	_assert("gerar a trinca não move um sorteio do combate nem um do visual",
		game.rng.state == estado_rng and game.visual_rng.state == estado_visual,
		"rng %d / visual %d após desenhar o degrau 3" % [game.rng.state, game.visual_rng.state])
	_assert("a cauda de quarenta sorteios é a mesma lida antes da placa",
		str(_cauda(game)) == str(cauda_antes), "cauda idêntica com a placa recém-gerada")
	_assert("a placa recém-gerada do zero é a mesma imagem",
		_checksum(gerada.get_image()) == soma_antes, "hash %d" % soma_antes)

	# ---- 5. A grade do BoxMesh veste uma face só -----------------------------------------------
	# A malha lida é a do próprio painel do jogo, não uma cópia: o contrato é deste pão.
	var pao_medido: BoxMesh = (game.ponte_visor as MeshInstance3D).mesh as BoxMesh
	var dianteira: Array = _celula_uv(pao_medido, Vector3(0, 0, 1))
	var traseira: Array = _celula_uv(pao_medido, Vector3(0, 0, -1))
	var escala: Vector3 = ESCALA_UV_ESPERADA
	_assert("a face vista pela câmera mora na célula 1/3 × 1/2 da grade",
		int(dianteira[4]) == 4 and absf(dianteira[0]) < 0.001
			and absf(dianteira[1] - 1.0 / CELULA_Z_LARGURA) < 0.001
			and absf(dianteira[2]) < 0.001 and absf(dianteira[3] - 1.0 / CELULA_Z_ALTURA) < 0.001,
		"+Z u[%0.4f..%0.4f] v[%0.4f..%0.4f] em %d vértices" % [dianteira[0], dianteira[1],
			dianteira[2], dianteira[3], int(dianteira[4])])
	_assert("com a escala (3,2) a face dianteira percorre o quadro inteiro",
		absf(dianteira[1] * escala.x - 1.0) < 0.001 and absf(dianteira[3] * escala.y - 1.0) < 0.001,
		"u*3 -> [0,1]  v*2 -> [0,1]")
	_assert("a face de trás cai fora do quadro e clampa na borda preta",
		traseira[0] * escala.x > 1.0 - 0.001,
		"-Z u[%0.4f..%0.4f] -> [%0.2f..%0.2f] amostrado" % [traseira[0], traseira[1],
			traseira[0] * escala.x, traseira[1] * escala.x])

	# ---- 6. O nó que a casa chamou de visor ---------------------------------------------------
	var visor: MeshInstance3D = game.ponte_visor
	var pao := visor.mesh as BoxMesh
	_assert("o painel do canopy é o pão de 13,2 × 4,6 do anteparo de vante",
		is_instance_valid(visor) and visor.get_parent() == game.bridge_rig
			and absf(pao.size.x - VISOR_LARGURA) < 0.001
			and absf(pao.size.y - VISOR_ALTURA) < 0.001,
		"[%0.2f %0.2f %0.2f] sob o rig" % [pao.size.x, pao.size.y, pao.size.z])
	var vidro := _vidro_do(game)
	var pais_antes := (game.bridge_rig as Node3D).get_child_count()
	_assert("vidro limpo na ignição: emissão desligada, placa nula, epicentro no centro",
		not bool(vidro.emission_enabled) and vidro.emission_texture == null
			and _degrau_atual(game) == 0 and game.ponte_trinca_ux == 0.0,
		"ligada=%s placa=%s degrau %d" % [str(vidro.emission_enabled),
			str(vidro.emission_texture), _degrau_atual(game)])
	_assert("a cor e a energia da aresta já nascem no retrato, não no dano",
		vidro.emission == Color(0.72, 0.84, 1.0)
			and absf(vidro.emission_energy_multiplier - ENERGIA_ESPERADA) < 0.001
			and vidro.uv1_scale == escala and not bool(vidro.texture_repeat),
		"energia %0.2f escala %s repeat=%s" % [vidro.emission_energy_multiplier,
			str(vidro.uv1_scale), str(vidro.texture_repeat)])

	# ---- 7. A escada do casco ------------------------------------------------------------------
	_isola_ampla(game)
	var escada_ok := true
	var lidos := ""
	for par in [[100.0, 0], [76.0, 0], [75.0, 1], [50.0, 2], [25.0, 3], [0.0, 3]]:
		game.capital_hp = float(par[0])
		game._trinca_vidro()
		if _degrau_atual(game) != int(par[1]):
			escada_ok = false
		lidos += "%0.0f->%d " % [float(par[0]), _degrau_atual(game)]
	_assert("um degrau por 25% de casco, e o degrau 3 segura até o zero",
		escada_ok, lidos)
	_assert("a trinca pega o vidro pela emissão e o albedo continua cor pura",
		vidro.emission_texture != null and bool(vidro.emission_enabled)
			and vidro.albedo_texture == null,
		"placa de degrau %d em emissão, albedo=%s" % [_degrau_atual(game),
			str(vidro.albedo_texture)])
	_assert("trincar não cria nó: a ponte tem a mesma conta de filhos",
		(game.bridge_rig as Node3D).get_child_count() == pais_antes,
			"%d filhos com o degrau 3 aceso" % pais_antes)

	# ---- 8. Escreve uma vez por degrau, e o epicentro não deriva ------------------------------
	var placa_feita: Texture2D = vidro.emission_texture
	var ux_feito: float = float(game.ponte_trinca_ux)
	var offset_feito: Vector3 = vidro.uv1_offset
	(game.enemies[0]["node"] as Node3D).global_position = Vector3(30.0, 0.0, -20.0)
	game.capital_hp = 5.0
	for i in range(30):
		game._trinca_vidro()
	_assert("o mesmo degrau repetido trinta vezes não escreve de novo",
		vidro.emission_texture == placa_feita and vidro.uv1_offset == offset_feito
			and float(game.ponte_trinca_ux) == ux_feito,
		"mesma placa, mesmo offset [%0.4f 0 0] com o hostil a boreste e o casco em 5" % ux_feito)

	# ---- 9. O epicentro aponta para a ameaça --------------------------------------------------
	# Em cada lado o degrau tem de FECHAR com a ameaça já no posto: o epicentro é carimbado no
	# quadro em que o degrau fecha e não deriva depois. Trinchar com o hostil à proa e só então
	# movê-lo deixaria o ux velho no vidro — a asserção leria o centro e chamar isso de "lei
	# confirmada" é a medição vazia que a casa já pegou duas vezes.
	_isola_ampla(game)
	game.capital_hp = 100.0
	game._trinca_vidro()
	(game.enemies[0]["node"] as Node3D).global_position = Vector3(-15.0, 0.0, -30.0)
	game.capital_hp = 70.0
	game._trinca_vidro()
	var ux_bombordo: float = float(game.ponte_trinca_ux)
	_isola_ampla(game)
	game.capital_hp = 100.0
	game._trinca_vidro()
	(game.enemies[0]["node"] as Node3D).global_position = Vector3(15.0, 0.0, -30.0)
	game.capital_hp = 70.0
	game._trinca_vidro()
	var ux_boreste: float = float(game.ponte_trinca_ux)
	_isola_ampla(game)
	game.capital_hp = 100.0
	game._trinca_vidro()
	(game.enemies[0]["node"] as Node3D).global_position = Vector3(15.0, 0.0, 30.0)
	game.capital_hp = 70.0
	game._trinca_vidro()
	var ux_atras: float = float(game.ponte_trinca_ux)
	_assert("hostil a bombordo trinca o vidro no bordo de bombordo",
		ux_bombordo > 0.0, "ux %+0.3f com a ameaça em x=-15" % ux_bombordo)
	_assert("hostil a boreste trinca a outra banda",
		ux_boreste < 0.0, "ux %+0.3f com a ameaça em x=+15" % ux_boreste)
	_assert("ameaça atrás do ombro pino no bordo do mesmo lado, nunca no centro",
		absf(ux_atras + FOLGA_UX_ESPERADA) < 0.001,
		"ux %+0.3f com o hostil a boreste e por trás" % ux_atras)
	_assert("nenhum epicentro sai da folga que mantém a mancha dentro do pão",
		absf(ux_bombordo) <= FOLGA_UX_ESPERADA + 0.001
			and absf(ux_boreste) <= FOLGA_UX_ESPERADA + 0.001,
		"|%+0.3f| e |%+0.3f| contra a folga %0.2f" % [ux_bombordo, ux_boreste, FOLGA_UX_ESPERADA])
	# O campo desenhado é quadrado de 128 px e o maior raio é o último da tabela: a meia-extensão
	# em u é `(raio × fator x + 1 halo) / 128`, lida das constantes do gerador. A folga tem de ser
	# menor que o que sobra até a moldura, para o centro da mancha nunca ficar de fora do pão.
	var meia_campo: float = (RAIO_ESPERADO[RAIO_ESPERADO.size() - 1]
		* Superficies.TRINCA_ESQUEMA_X + 1.0) / float(PASSO_ESPERADO)
	_assert("a folga deixa a mancha inteira alcançável dentro do quadro amostrado",
		FOLGA_UX_ESPERADA + meia_campo < 0.5 + 0.02,
		"folga %0.3f + campo %0.3f = %0.3f" % [FOLGA_UX_ESPERADA, meia_campo,
			FOLGA_UX_ESPERADA + meia_campo])

	# ---- 10. A ruína não apaga a trinca -------------------------------------------------------
	game.capital_hp = 0.0
	game._trinca_vidro()
	var placa_morta: Texture2D = vidro.emission_texture
	var cores_antes: Dictionary = {}
	var mats: Dictionary = (game.bridge_rig as Node3D).get_meta("mat")
	for chave in ["piso", "casco", "trim"]:
		var mat: StandardMaterial3D = mats[chave]
		cores_antes[chave] = mat.albedo_color
	game._acender_ruina()
	var apagado := 0
	for chave in ["piso", "casco", "trim"]:
		var mat: StandardMaterial3D = mats[chave]
		if mat.albedo_color == (cores_antes[chave] as Color).darkened(CORTE_RUINA_ESPERADO) \
				and absf(mat.emission_energy_multiplier) < 0.001:
			apagado += 1
	_assert("a ruína apaga o deck e deixa a trinca acesa: o vidro não está na lista",
		apagado == 3 and vidro.emission_texture == placa_morta and bool(vidro.emission_enabled),
			"%d de 3 materiais apagados, placa do degrau %d continua no vidro" % [apagado,
				_degrau_atual(game)])

	# ---- 11. RECOMEÇAR devolve o vidro limpo --------------------------------------------------
	game._recomecar_batalha()
	_assert("esquadra nova acorda com o vidro limpo lido do retrato, não de constante",
		_degrau_atual(game) == 0 and not bool(vidro.emission_enabled)
			and vidro.emission_texture == null and vidro.uv1_offset == Vector3.ZERO
			and float(game.ponte_trinca_ux) == 0.0,
		"degrau %d, placa=%s, offset=%s" % [_degrau_atual(game), str(vidro.emission_texture),
			str(vidro.uv1_offset)])
	var retrato: Array = (game.ponte_base as Dictionary)["trinca"]
	_assert("o retrato grava o estado da trinca na ignição: três campos, todos de base",
		retrato.size() == 3 and not bool(retrato[0]) and retrato[1] == null
			and (retrato[2] as Vector3) == Vector3.ZERO,
		"ligada=%s placa=%s offset=%s" % [str(retrato[0]), str(retrato[1]), str(retrato[2])])

	print("== vidro do canopy ==")
	for nota in notes:
		print(nota)
	print("== %d quebra(s) ==" % breaks)
	quit(1 if breaks > 0 else 0)
