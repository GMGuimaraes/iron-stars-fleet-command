extends SceneTree

## Sonda das superfícies: a textura é procedural, compartilhada e não mexe em número nenhum.
##
## O casco, a rocha, o painel da ponte e o planeta deixaram de ser cor sólida. Esta peça não
## julga gosto — julga as quatro leis que tornam a textura uma camada e não um segundo jogo:
##
## 1) A IMAGEM É UMA SÓ. Cada família é gerada uma vez e o cache devolve a MESMA `ImageTexture`
##    (identidade por `get_instance_id()`). Doze cascos com doze chapas de 128² seriam 12 recursos
##    no ar por partida, e o vazamento medido em `tools/probes/morte.gd` começaria exatamente assim.
## 2) NENHUM SORTEIO TOCADO. Gerar pixmap é função do índice do pixel. `rng` e `visual_rng` não se
##    movem nem uma casa, e a cauda de quarenta sorteios é a mesma lida na semente cravada, depois
##    de um acerto de cache e depois de gerar as oito superfícies do zero com o cache esvaziado. É a
##    mesma lei do céu em `MultiMesh` e da pintura de formação, e é a que as outras vinte e uma
##    sondas assumem quando cravam uma semente.
## 3) DETERMINISMO DE PIXMAP. Duas montadas independentes chegam no mesmo checksum de amostras.
##    Cravar o estado do gerador não bastaria: a textura poderia nascer de um `randf()` global e a
##    semente não ver. Aqui o pixmap é medido, não presumido.
## 4) O TOM CONTINUA DONO DO CASCO. A chapa é luminância perto de 1 e multiplica o `albedo_color`,
##    então `_tune_ship_look` escurece placa e aço juntos e a porta dos 55% da brasa não mudou de
##    lugar. A asserção é de cor E de identidade de textura antes e depois do dano.
##
## Vem junto o que a textura paga de contrato no resto da casa: nenhum nó novo na árvore (a conta
## de 22 filhos do jogo sem cenário e 64 da ponte foi medida aqui e é a mesma que `recomecar.gd`
## cobra, um a menos porque lá o cenário já está montado), planeta do fundo e
## planeta do `SISTEMA` com peles diferentes, e a face recém-fraturada da filha distinguish da
## matriz intemperizada — porque rachadura é evento, não variação de humidade.
##
## Uso: godot --headless --path . --quit-after 6000 -s res://tools/probes/superficies.gd

const Superficies := preload("res://superficies.gd")

## Espelho das constantes de `superficies.gd` (a instância do jogo é não tipada; mesmo motivo em
## `tools/probes/cinturao.gd`). Mudar o número lá quebra a asserção aqui: é de propósito.
const PASSO_METAL_ESPERADO := 128
const PASSO_ROCHA_ESPERADO := 64
const PASSO_PAINEL_ESPERADO := 128
const PLANETA_LARGURA_ESPERADA := 128
const PLANETA_ALTURA_ESPERADA := 64
const PLANETAS_ESPERADOS := 4
## Faixa de luminância da chapa: clara o bastante para o `albedo_color` continuar mandando, e com
## piso alto o bastante para o casco furado não virar buraco negro no Compatibility.
const CHAPA_CLARA_MIN := 0.5
const CHAPA_MEDIA_MIN := 0.7
const CHAPA_MEDIA_MAX := 1.0
## Amostra fixa do pixmap: 8×8 passos sobre a imagem. Não é a imagem inteira porque o custo é de
## leitura de recurso, não de dúvida — 64 amostras já não perdem um bloco de 16 px.
const AMOSTRA := 8
## Gabarito de uma montagem nova SEM cenário, medido nesta rodada em três montadas seguidas: 7 de
## ambiente (WorldEnvironment, dois sóis, três malhas do fundo, o MultiMesh das estrelas) + ponte +
## doze cascos + CanvasLayer + PonteSonora = 22. O 23 que `tools/probes/recomecar.gd` lê é esta
## mesma árvore com o `cenario_root` do cenário montado, que é filho único e entra um por cenário.
const FILHOS_DO_JOGO := 22
## Ponte montada SEM cenário: 125 filhos, inventariados um a um por posição nesta rodada. O gabarito
## é a medida, não uma soma esperada, e ela fecha com a partição por construtor: 72 do `_build_bridge`
## (soalho e teto, 20 de costado — três panos, duas janelas com verga e peitoril e o filete corrido
## de cada bordo —, 9 do anteparo de vante, 40 dos quatro postos com cinco teclas por bancada, mais
## o trilho), 33 de `_build_ponte_intima` (plinto, longarinas, meia-lua, três cavernames, bandejas e
## prumadas, asas de vante, coberta com duas frestas, armários com painel), 11 filhos diretos da mesa
## holográfica, 6 corpos da tripulação, duas luzes e a câmera. Eram 64 antes da ponte íntima e 128
## antes de a coberta encolher: o teto sobre a mesa perdeu uma fresta e as duas sanefas, que
## espelhavam aço metalizado debaixo da lâmpada e estouravam a ponte inteira em branco.
const FILHOS_DA_PONTE := 125
## Semente cravada das duas réguas de cauda. `rng` é `randomize()` na origem (main.gd) de propósito
## — cada partida acorda com sorteio diferente —, então o estado do gerador NÃO é comparável entre
## montadas; o que se compara aqui é a cauda a partir desta semente, lida três vezes.
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

## Quarenta sorteios do gerador de combate, na ordem em que saem. É a régua forte da lei de
## inércia: o estado do gerador pode coincidir e a cauda ainda divergir se o caminho chamar
## `randf()` escondido numa ramo que a medição de estado não percorre.
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

## Hash de amostragem do pixmap: soma ponderada dos canais vermelhos lidos numa grade fixa. Não é
## um hash criptográfico — é o suficiente para duas imagens que divergem em um bloco não baterem.
func _checksum(img: Image) -> int:
	if img == null:
		return -1
	var total := 0
	var passo_x := maxi(1, img.get_width() / AMOSTRA)
	var passo_y := maxi(1, img.get_height() / AMOSTRA)
	var no := 0
	for y in range(0, img.get_height(), passo_y):
		for x in range(0, img.get_width(), passo_x):
			no += 1
			total = (total + int(roundf(img.get_pixel(x, y).r * 1000.0)) * (no * 31)) % 1000000007
	return total

func _media(img: Image) -> float:
	var soma := 0.0
	var n := 0
	var passo := maxi(1, img.get_width() / 32)
	for y in range(0, img.get_height(), passo):
		for x in range(0, img.get_width(), passo):
			var c := img.get_pixel(x, y)
			soma += (c.r + c.g + c.b) / 3.0
			n += 1
	return soma / float(maxi(1, n))

## Piso lido pixel a pixel, sem amostragem: a junta de painel tem UM pixel de largura, e um passo
## de 4 px atravessaria o mapa inteiro sem nunca encostar nela.
func _minimo(img: Image) -> float:
	var menor := 2.0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			menor = minf(menor, img.get_pixel(x, y).r)
	return menor

func _material_casco(game, chave: String) -> StandardMaterial3D:
	var mats: Dictionary = (game.fleet[0]["node"] as Node3D).get_meta("mat")
	return mats[chave] as StandardMaterial3D

## Caminha a cena procura o planeta do fundo: a esfera de raio 22 que `_build_backdrop` pendura
## direto no jogo. Não há variável para ele — e é exatamente por isso que a busca é por geometria.
func _planeta_do_fundo(game) -> MeshInstance3D:
	for filho in game.get_children():
		var mi := filho as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var esfera := mi.mesh as SphereMesh
		if esfera != null and is_equal_approx(esfera.radius, 22.0):
			return mi
	return null

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	# ── 1. A imagem é uma só ────────────────────────────────────────────────────────────────
	var chapa_a: Dictionary = Superficies.metal()
	var chapa_b: Dictionary = Superficies.metal()
	var tex_a: ImageTexture = chapa_a["albedo"]
	var tex_b: ImageTexture = chapa_b["albedo"]
	_assert("duas chamadas de metal devolvem a MESMA textura",
		tex_a != null and tex_a.get_instance_id() == tex_b.get_instance_id(),
		"%d vs %d" % [tex_a.get_instance_id(), tex_b.get_instance_id()])
	var img_metal: Image = tex_a.get_image()
	_assert("a chapa tem o tamanho anunciado em potência de dois",
		img_metal.get_width() == PASSO_METAL_ESPERADO and img_metal.get_height() == PASSO_METAL_ESPERADO,
		"%d x %d" % [img_metal.get_width(), img_metal.get_height()])
	# A régua é a cadeia lida DO IMAGE, não o `Texture2D.get_mipmap_count()`: em `--headless` o
	# rasterizador dummy responde 0 para qualquer textura, com cadeia ou sem (medido nesta rodada:
	# `get_mipmap_count=0` ao lado de `get_image().get_mipmap_count=7`). Cravar o do texture diria
	# que a chapa não tem mipmaps justamente porque ela tem.
	_assert("a chapa sobe mipmap (tamanho POT e cadeia no image)",
		img_metal.get_mipmap_count() > 1 and img_metal.has_mipmaps(),
		"%d níveis na cadeia lida do image" % img_metal.get_mipmap_count())
	var rocha0: Dictionary = Superficies.rocha(0)
	var rocha1: Dictionary = Superficies.rocha(1)
	var painel: Dictionary = Superficies.painel()
	var img_rocha: Image = (rocha0["albedo"] as ImageTexture).get_image()
	var img_painel: Image = (painel["albedo"] as ImageTexture).get_image()
	_assert("rocha e painel vêm nos tamanhos da casa",
		img_rocha.get_width() == PASSO_ROCHA_ESPERADO and img_painel.get_width() == PASSO_PAINEL_ESPERADO
			and img_painel.get_height() == PASSO_PAINEL_ESPERADO,
		"rocha %d, painel %d" % [img_rocha.get_width(), img_painel.get_width()])
	_assert("as três famílias são imagens diferentes",
		(rocha0["albedo"] as ImageTexture).get_instance_id()
			!= (painel["albedo"] as ImageTexture).get_instance_id()
			and (rocha0["albedo"] as ImageTexture).get_instance_id()
			!= tex_a.get_instance_id(),
		"metal %d, rocha %d, painel %d" % [tex_a.get_instance_id(),
			(rocha0["albedo"] as ImageTexture).get_instance_id(),
			(painel["albedo"] as ImageTexture).get_instance_id()])
	_assert("o painel de ponte não tem rugosidade falsa", painel["rugosidade"] == null,
		"deck lê a rugosidade do próprio material")
	# O catálogo contado, não presumido: oito superfícies e as imagens que cada uma realmente
	# embarca (placa e rochas trazem par próprio, painel e planeta não — painel mente rugosidade e
	# planeta tem rugosidade de nuvem). É o número que vai para o README.
	var familias: Array = [chapa_a, rocha0, rocha1, painel,
		Superficies.planeta(0), Superficies.planeta(1),
		Superficies.planeta(2), Superficies.planeta(3)]
	var imagens := 0
	var sem_albedo := 0
	for pele in familias:
		if pele["albedo"] != null:
			imagens += 1
		else:
			sem_albedo += 1
		if pele["rugosidade"] != null:
			imagens += 1
	_assert("o catálogo fecha em oito superfícies e quinze imagens",
		sem_albedo == 0 and imagens == 15, "%d superfícies, %d imagens" % [familias.size(), imagens])

	# ── 2. Nenhum sorteio tocado ────────────────────────────────────────────────────────────
	# Duas réguas e não uma. O cache de texturas é do PROCESSO, então chamar as quatro famílias
	# depois da seção 1 mede apenas um ACERTO de cache — e medição que não exercita o caminho não
	# prova o caminho (lei da casa, mesma que derrubou a corrida de 200 tiques com a prateleira
	# vazia). A terceira passada abaixo esvazia o cache e gera as oito superfícies de verdade, do zero,
	# com a semente cravada antes e a cauda relida depois.
	var jogo := await _montar_jogo()
	var visual_montagem := int(jogo.visual_rng.state)
	var base_montagem := int(jogo.visual_base)
	jogo.rng.seed = SEMENTE_RNG
	jogo.visual_rng.seed = SEMENTE_VISUAL
	var cauda_semente: Array[int] = _cauda(jogo)
	jogo.rng.seed = SEMENTE_RNG
	jogo.visual_rng.seed = SEMENTE_VISUAL
	var semente_rng := int(jogo.rng.state)
	var semente_visual := int(jogo.visual_rng.state)
	var chapa_x: Dictionary = Superficies.metal()
	var rocha_x: Dictionary = Superficies.rocha(1)
	var painel_x: Dictionary = Superficies.painel()
	var planeta_x: Dictionary = Superficies.planeta(2)
	_assert("vestir pelo cache não move o gerador de combate",
		int(jogo.rng.state) == semente_rng, "%d -> %d" % [semente_rng, int(jogo.rng.state)])
	_assert("vestir pelo cache não move o gerador visual",
		int(jogo.visual_rng.state) == semente_visual,
		"%d -> %d" % [semente_visual, int(jogo.visual_rng.state)])
	var cauda_cache: Array[int] = _cauda(jogo)
	jogo.rng.seed = SEMENTE_RNG
	jogo.visual_rng.seed = SEMENTE_VISUAL
	var gera_rng := int(jogo.rng.state)
	var gera_visual := int(jogo.visual_rng.state)
	Superficies.limpar_cache()
	Superficies.metal()
	Superficies.rocha(0)
	Superficies.rocha(1)
	Superficies.painel()
	for variedade in range(PLANETAS_ESPERADOS):
		Superficies.planeta(variedade)
	_assert("gerar as oito superfícies do zero não move o gerador de combate",
		int(jogo.rng.state) == gera_rng, "%d -> %d" % [gera_rng, int(jogo.rng.state)])
	_assert("gerar as oito superfícies do zero não move o gerador visual",
		int(jogo.visual_rng.state) == gera_visual,
		"%d -> %d" % [gera_visual, int(jogo.visual_rng.state)])
	var cauda_geracao: Array[int] = _cauda(jogo)
	var cauda_igual := true
	for i in range(40):
		if cauda_semente[i] != cauda_cache[i] or cauda_semente[i] != cauda_geracao[i]:
			cauda_igual = false
	_assert("a cauda de quarenta sorteios sobrevive à textura", cauda_igual,
		"semente/cache/geração abrem em %d / %d / %d" % [cauda_semente[0], cauda_cache[0],
			cauda_geracao[0]])
	_assert("as quatro famílias cabem no cache anunciado",
		Superficies.guardado_em("metal") and Superficies.guardado_em("rocha:0")
			and Superficies.guardado_em("rocha:1") and Superficies.guardado_em("painel")
			and Superficies.guardado_em("planeta:2"),
		"metal, rocha 0/1, painel, planeta 2")
	_assert("a textura reused não é recriada", chapa_x["albedo"] == chapa_a["albedo"]
		and rocha_x["albedo"] == rocha1["albedo"] and painel_x["albedo"] == painel["albedo"]
		and planeta_x["albedo"] != null, "cache acertou as quatro")

	# ── 3. Determinismo de pixmap ───────────────────────────────────────────────────────────
	# A régua forte é atravessar a seção 2, que esvaziou o cache: a chapa comparada aqui foi GERADA
	# de novo, do zero, e não lida duas vezes do mesmo recurso (isso seria verde por identidade de
	# ponteiro, não por função).
	var soma_metal := _checksum(img_metal)
	var soma_rocha := _checksum(img_rocha)
	var soma_painel := _checksum(img_painel)
	var planeta0: Dictionary = Superficies.planeta(0)
	var planeta0_de_novo: Dictionary = Superficies.planeta(0)
	var soma_planeta := _checksum((planeta0["albedo"] as ImageTexture).get_image())
	_assert("a chapa regerada do zero bate pixel a pixel com a primeira",
		soma_metal == _checksum((Superficies.metal()["albedo"] as ImageTexture).get_image())
			and soma_rocha == _checksum((Superficies.rocha(0)["albedo"] as ImageTexture).get_image())
			and soma_painel == _checksum((Superficies.painel()["albedo"] as ImageTexture).get_image()),
		"checksum %d (metal), %d (rocha), %d (painel)" % [soma_metal, soma_rocha, soma_painel])
	_assert("planeta chamado duas vezes devolve a mesma imagem",
		planeta0["albedo"].get_instance_id() == planeta0_de_novo["albedo"].get_instance_id()
			and soma_planeta == _checksum((planeta0_de_novo["albedo"] as ImageTexture).get_image()),
		"checksum %d" % soma_planeta)
	var jogo_b := await _montar_jogo()
	_assert("duas montadas independentes texturizam igual",
		_checksum(((jogo_b.fleet[0]["node"] as Node3D).get_meta("mat")["hull"]
			as StandardMaterial3D).albedo_texture.get_image()) == soma_metal,
		"chapa do casco lida na cena bate com o módulo")

	# ── 4. O casco veste chapa ──────────────────────────────────────────────────────────────
	var chapa_no_ar := 0
	var deslocos: Array[String] = []
	var identidades: Array[int] = []
	for grupo in [jogo.fleet, jogo.enemies]:
		for unidade in grupo:
			var mats: Dictionary = (unidade["node"] as Node3D).get_meta("mat")
			for chave in ["hull", "steel", "gun", "trip"]:
				var mat: StandardMaterial3D = mats[chave]
				if mat.albedo_texture != null:
					chapa_no_ar += 1
					identidades.append(mat.albedo_texture.get_instance_id())
			deslocos.append(str((mats["hull"] as StandardMaterial3D).uv1_offset))
	_assert("os doze cascos vestem chapa em hull, steel, gun e trip", chapa_no_ar == 48,
		"%d materiais texturizados de 48" % chapa_no_ar)
	var so_uma := true
	for id in identidades:
		if id != identidades[0]:
			so_uma = false
	_assert("a chapa do ar inteiro é UM recurso compartilhado", so_uma,
		"%d leituras, 1 identidade" % identidades.size())
	var deslocos_unicos: Dictionary = {}
	for d in deslocos:
		deslocos_unicos[d] = true
	_assert("cada casco descola a junta de painel do vizinho", deslocos_unicos.size() == 12,
		"%d deslocamentos diferentes em 12 cascos" % deslocos_unicos.size())
	var mat_hull := _material_casco(jogo, "hull")
	_assert("a rugosidade lê o canal verde (convenção ORM da casa)",
		mat_hull.roughness_texture != null
			and mat_hull.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_GREEN,
		"canal %d" % mat_hull.roughness_texture_channel)
	var media_chapa := _media(img_metal)
	_assert("a chapa é clara o bastante para o tom continuar dono",
		media_chapa >= CHAPA_MEDIA_MIN and media_chapa <= CHAPA_MEDIA_MAX
			and _minimo(img_metal) >= CHAPA_CLARA_MIN,
		"média %.3f, piso %.3f" % [media_chapa, _minimo(img_metal)])

	# ── 5. A fratura veste outra pele ───────────────────────────────────────────────────────
	jogo._montar_cenario("CINTURAO")
	var matriz_viva: MeshInstance3D = jogo.rochas[0]["no"]
	var filha: Dictionary = jogo._nova_rocha(Vector3(0.0, 0.0, -30.0), 2.0, Vector3.ZERO, 1, 0.5)
	var filha_no: MeshInstance3D = filha["no"]
	_assert("a matriz do cinturão está chapada de rocha",
		(matriz_viva.material_override as StandardMaterial3D).albedo_texture != null,
		"%d pixels de albedo" % img_rocha.get_width())
	_assert("a filha recém-rachada veste a face limpa",
		filha_no.material_override == jogo.rocha_filha_material
			and (filha_no.material_override as StandardMaterial3D).albedo_texture != null
			and (filha_no.material_override as StandardMaterial3D).albedo_texture.get_instance_id()
			!= (matriz_viva.material_override as StandardMaterial3D).albedo_texture.get_instance_id(),
		"geração 1 usa outra imagem")

	# ── 6. A ponte tem escala ───────────────────────────────────────────────────────────────
	var deck: Dictionary = jogo.bridge_rig.get_meta("mat")
	var com_placa := 0
	for chave in deck:
		var mat: StandardMaterial3D = deck[chave]
		if mat.albedo_texture != null:
			com_placa += 1
	_assert("soalho, anteparo e console saem texturizados",
		(deck["piso"] as StandardMaterial3D).albedo_texture != null
			and (deck["casco"] as StandardMaterial3D).albedo_texture != null
			and (deck["trim"] as StandardMaterial3D).albedo_texture != null,
		"piso/casco/trim com placa")
	_assert("tela, ouro e vidro continuam cores puras",
		(deck["tela"] as StandardMaterial3D).albedo_texture == null
			and (deck["ouro"] as StandardMaterial3D).albedo_texture == null
			and (deck["vidro"] as StandardMaterial3D).albedo_texture == null,
		"%d de %d materiais da ponte com placa" % [com_placa, deck.size()])

	# ── 7. Planetas com peles diferentes ────────────────────────────────────────────────────
	# O SISTEMA entra aqui e não antes: a seção 5 monta o cinturão, e montar cenário desmonta o
	# vizinho — `astros` estaria vazio e a asserção leria nulo em vez de medir o que devia.
	jogo._montar_cenario("SISTEMA")
	var fundo := _planeta_do_fundo(jogo)
	var planeta_ativo: MeshInstance3D = null
	for astro in jogo.astros:
		if int(astro["orbita"]) == -1:
			planeta_ativo = astro["no"]
	_assert("o fundo e o cenário montam os dois planetas pedidos",
		fundo != null and planeta_ativo != null and jogo.astros.size() == 4,
		"fundo=%s • planeta=%s • %d astros (planeta + 3 luas)" % [str(fundo != null),
			str(planeta_ativo != null), jogo.astros.size()])
	var mat_fundo: StandardMaterial3D = null if fundo == null else fundo.material_override
	var mat_sistema: StandardMaterial3D = null if planeta_ativo == null \
		else planeta_ativo.material_override
	_assert("o planeta do fundo veste uma faixa procedural",
		mat_fundo != null and mat_fundo.albedo_texture != null, "esfera de raio 22 com pele")
	_assert("planeta do fundo e planeta do SISTEMA não repetem pele",
		mat_fundo != null and mat_sistema != null
			and mat_fundo.albedo_texture.get_instance_id()
			!= mat_sistema.albedo_texture.get_instance_id(),
		"fundo veste planeta 0, cenário veste planeta 1")
	_assert("existem quatro famílias de planeta para as fases",
		Superficies.planetas_existentes() == PLANETAS_ESPERADOS
			and (Superficies.planeta(3)["albedo"] as ImageTexture).get_image().get_width()
			== PLANETA_LARGURA_ESPERADA
			and (Superficies.planeta(3)["albedo"] as ImageTexture).get_image().get_height()
			== PLANETA_ALTURA_ESPERADA,
		"%d variedades em %d x %d" % [Superficies.planetas_existentes(),
			(Superficies.planeta(3)["albedo"] as ImageTexture).get_image().get_width(),
			(Superficies.planeta(3)["albedo"] as ImageTexture).get_image().get_height()])
	var paleta_0 := _media((Superficies.planeta(0)["albedo"] as ImageTexture).get_image())
	var paleta_1 := _media((Superficies.planeta(1)["albedo"] as ImageTexture).get_image())
	var paleta_2 := _media((Superficies.planeta(2)["albedo"] as ImageTexture).get_image())
	_assert("as faixas mudam de fato entre variedades",
		absf(paleta_0 - paleta_1) > 0.02 and absf(paleta_1 - paleta_2) > 0.02,
		"medianas %.3f / %.3f / %.3f" % [paleta_0, paleta_1, paleta_2])
	var lua := null if jogo.astros.size() < 2 else (jogo.astros[1]["no"] as MeshInstance3D)
	_assert("a lua do sistema é craterada, não pintada de cinza liso",
		lua != null and lua.material_override == jogo.astro_lua_material
			and (jogo.astro_lua_material as StandardMaterial3D).albedo_texture != null,
		"mesma imagem da rocha intemperizada")

	# ── 8. O dano continua escurecendo tudo junto ───────────────────────────────────────────
	var unidade: Dictionary = jogo.fleet[0]
	var cor_anterior := (mats_de(jogo, 0)["hull"] as StandardMaterial3D).albedo_color
	var textura_anterior: Texture2D = (mats_de(jogo, 0)["hull"] as StandardMaterial3D).albedo_texture
	unidade["hp"] = 20.0
	jogo.fleet[0] = unidade
	jogo._tune_ship_look(unidade)
	var mat_dep := mats_de(jogo, 0)["hull"] as StandardMaterial3D
	_assert("casco furado afunda na chapa junto com o aço",
		mat_dep.albedo_color != cor_anterior and mat_dep.albedo_texture == textura_anterior
			and mat_dep.albedo_texture != null,
		"cor foi para %s, imagem continua a mesma" % mat_dep.albedo_color)
	_assert("a porta dos 55% da brasa continua no mesmo lugar",
		mat_dep.emission_energy_multiplier >= 0.3, "energia %.3f com casco a 20%%"
		% mat_dep.emission_energy_multiplier)

	# ── 9. Nada novo na árvore ──────────────────────────────────────────────────────────────
	# O gabarito é o de uma montagem nova sem cenário: 22 filhos no jogo, 125 na ponte, medido em três
	# montadas seguidas nesta rodada. Ele entra cravado porque o cache de texturas é do PROCESSO, não
	# da instância — não existe "um jogo sem textura" dentro desta sonda para comparar. Se a camada
	# visual tivesse criado um nó, esta asserção e a do recomeço quebram juntas.
	var jogo_c := await _montar_jogo()
	_assert("a camada visual criou zero nó no jogo",
		jogo_c.get_child_count() == FILHOS_DO_JOGO,
		"%d filhos na montagem nova com textura, mesmo número do gabarito"
		% jogo_c.get_child_count())
	_assert("a camada visual criou zero nó na ponte",
		jogo_c.bridge_rig.get_child_count() == FILHOS_DA_PONTE,
		"%d filhos na ponte" % jogo_c.bridge_rig.get_child_count())
	# A régua é a do gerador VISUAL, e não a do de combate: `rng.randomize()` em `_ready` é decisão
	# da casa (cada partida acorda com sorteio diferente), então igualar estado de combate entre
	# montadas seria reprovar o jogo por ele funcionar. O que tem de bater é o céu, os fachos e a
	# pintura de formação, todos cravados na semente de `main.gd`. A lei de que a textura não toca o
	# sorteio de combate está na seção 2, medida contra a semente.
	_assert("montar o jogo texturizado não empurrou a camada visual",
		int(jogo_c.visual_rng.state) == visual_montagem and int(jogo_c.visual_base) == base_montagem,
		"visual %d (base %d), montagem A %d (base %d)" % [int(jogo_c.visual_rng.state),
			int(jogo_c.visual_base), visual_montagem, base_montagem])

	print("SONDA-SUPERFICIES: veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	for nota in notes:
		print(nota)
	quit(1 if breaks > 0 else 0)

func mats_de(game, indice: int) -> Dictionary:
	return (game.fleet[indice]["node"] as Node3D).get_meta("mat")
