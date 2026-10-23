extends SceneTree

## Sonda do tripulante rigged: o corpo que a ponte opera nasce de `tools/synth_humanoid.py`,
## é um GLB de verdade, e a pele rígida está ancorada na junta certa.
##
## A sonda nasceu julgando o ARQUIVO, antes de existir integração; desde que `tripulante_rig.gd`
## entrou na ponte ela julga os dois lados — as seis primeiras famílias são do GLB e a sétima confere
## que a ponte do jogo acorda com os seis corpos montados e que instanciá-los não encosta no sorteio.
## O que ela cobra:
##
## 1) É UMA CENA IMPORTÁVEL COM ESQUELETO. Um `Skeleton3D`, um `MeshInstance3D`, 19 juntas com os
##    nomes do cadastro, na ordem do cadastro, cada uma filha do osso que o gerador escolheu.
##    Nome de osso errado não falha no parse: falha em runtime, muda de pose para pose e devolve
##    sonda verde com personagem quebrado.
## 2) A PELE É RÍGIDA E TOTAL. Todo vértice pesa 1,0 em exatamente uma junta e 0,0 nas outras três,
##    e toda junta tem vértice obedecendo a ela. Peso quebrado entre juntas seria pele suave
##    disfarçada — e pele suave num uniforme de caixas arrasta a ombreira quando o braço dobra no
##    console. Junta morta é o avesso: um osso que o jogo pode girar e nada se mexe. O osso é lido
##    em `Mesh.ARRAY_BONES` e o peso em `Mesh.ARRAY_WEIGHTS`; quem perguntar por `ARRAY_CUSTOM0/1`
##    recebe vazio e declara, verde, um corpo sem pele — foi o que esta sonda fez na primeira rodada.
## 3) A JUNTA MORA NA PEÇA (a que autoriza o binário). Para cada junta, a origem GLOBAL do osso em
##    repouso cai dentro da caixa dos vértices que obedecem a ela, e a translação global do osso bate
##    com o cadastro metro a metro. IBM errada não dá erro: dá personagem dilacerado ou deslocado, e
##    é exatamente isso que esta asserção pega.
## 4) DOBRAR MOVE A CADEIA, NÃO O MUNDO. Girar o ombro faz cotovelo e mão descerem mantendo a
##    distância exata do cadastro (corpo rígido) e não encosta no quadril. A pose vem de
##    `battle_clock` no jogo, então a junta tem de responder sem animação nenhuma.
## 5) O CORPO TEM O TAMANHO DE UMA PESSOA. Altura lida da caixa malhada, pé no soalho, quepe no
##    topo, envergadura conferida contra a ponta do dedo.
## 6) O PREÇO DO BINÁRIO É MEDIDO. Cabeçalho glTF conferido (magic, versão, comprimento declarado
##    batendo com o comprimento real do arquivo) e o teto do orçamento da casa.
## 7) NENHUM SORTEIO TOCADO. Instanciar seis corpos não move `rng` nem `visual_rng`, e a cauda de
##    quarenta sorteios é a mesma da semente cravada — a mesma régua de `geoide.gd` e `superficies.gd`.
##
## Uso: godot --headless --path . --quit-after 6000 -s res://tools/probes/humanoide.gd

const CAMINHO_GLB := "res://assets/tripulante.glb"

## Espelho de `tools/synth_humanoid.py`. Mudar o cadastro lá sem mudar aqui quebra a asserção: é de
## propósito, é o que impede o gerador de evoluir sozinho e o jogo de importar outro corpo.
const JUNTAS_ESPERADAS := ["quadril", "coluna", "peito", "pescoco", "cabeca",
	"ombro_e", "braco_e", "antbraco_e", "mao_e", "ombro_d", "braco_d", "antbraco_d", "mao_d",
	"coxa_e", "perna_e", "pe_e", "coxa_d", "perna_d", "pe_d"]
const PAI_DE := {"quadril": "", "coluna": "quadril", "peito": "coluna", "pescoco": "peito",
	"cabeca": "pescoco", "ombro_e": "peito", "braco_e": "ombro_e", "antbraco_e": "braco_e",
	"mao_e": "antbraco_e", "ombro_d": "peito", "braco_d": "ombro_d", "antbraco_d": "braco_d",
	"mao_d": "antbraco_d", "coxa_e": "quadril", "perna_e": "coxa_e", "pe_e": "perna_e",
	"coxa_d": "quadril", "perna_d": "coxa_d", "pe_d": "perna_d"}
## Translação global de cadastro, osso a osso (metros, pé no soalho y=0, proa do corpo em −z).
const REPOUSO := {"quadril": Vector3(0.00, 0.92, 0.00), "coluna": Vector3(0.00, 1.02, 0.00),
	"peito": Vector3(0.00, 1.20, 0.00), "pescoco": Vector3(0.00, 1.38, 0.00),
	"cabeca": Vector3(0.00, 1.46, 0.00), "ombro_e": Vector3(0.17, 1.34, 0.00),
	"braco_e": Vector3(0.26, 1.33, 0.00), "antbraco_e": Vector3(0.52, 1.33, 0.00),
	"mao_e": Vector3(0.76, 1.33, 0.00), "ombro_d": Vector3(-0.17, 1.34, 0.00),
	"braco_d": Vector3(-0.26, 1.33, 0.00), "antbraco_d": Vector3(-0.52, 1.33, 0.00),
	"mao_d": Vector3(-0.76, 1.33, 0.00), "coxa_e": Vector3(0.10, 0.90, 0.00),
	"perna_e": Vector3(0.10, 0.48, 0.00), "pe_e": Vector3(0.10, 0.08, 0.00),
	"coxa_d": Vector3(-0.10, 0.90, 0.00), "perna_d": Vector3(-0.10, 0.48, 0.00),
	"pe_d": Vector3(-0.10, 0.08, 0.00)}
const TRIANGULOS_ESPERADOS := 586
const VERTICES_ESPERADOS := 1026
const SUPERFICIES_ESPERADAS := 3
## Distâncias da cadeia do braço lidas do cadastro — a régua da asserção de corpo rígido.
const BRACO_E_COTOVELO := 0.26
const BRACO_E_MAO := 0.50
## Teto de bytes do corpo. 57,4 KB medidos; o teto é a folha, não o número: o `.pck` do build web
## paga 200 MB de extrato na itch.io e um personagem não pode custar mais que uma faixa de áudio.
const TETO_BYTES := 131072
## Folga de ponto flutuante para coordenada lida de malha em `float` de 32 bits.
const FOLGA := 1e-4
## Folga da caixa de ancoragem: os vértices de um osso podem começar um palmo adiante da junta
## (o cotovelo mora no topo da peça do antebraço, não dentro dela).
const FOLGA_ANCORAGEM := 0.10
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

func _igual(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol

func _initialize() -> void:
	print("SONDA-HUMANOIDE: comecando")
	var cena := load(CAMINHO_GLB) as PackedScene
	_assert("o GLB importa como cena", cena != null, CAMINHO_GLB)
	if cena == null:
		_veredito()
		quit()
		return
	var corpo := cena.instantiate()
	get_root().add_child(corpo)
	# A árvore vem antes da medida. Numa sonda `SceneTree`, o `add_child` happens before the
	# engine registers the tree, so `is_inside_tree()` is false no mesmo frame; um `Skeleton3D`
	# fora da árvore guarda a pose que se escreve nele mas nunca recalcula o pose global, e a
	# asserção de cadeia ficaria muda — o mesmo instrumento mudo que quase aprovou o `ARMAS->[]`
	# de `modulos.gd`. Esperar antes de medir é o que separa "não responde" de "não sei perguntar".
	await _frames(2)
	var na_arvore := corpo.is_inside_tree()
	_assert("o corpo esta na arvore antes de qualquer medida de pose", na_arvore,
		"is_inside_tree() = %s apos 2 frames" % na_arvore)
	var esqueleto := _procurar(corpo, "Skeleton3D") as Skeleton3D
	var malha_no := _procurar(corpo, "MeshInstance3D") as MeshInstance3D
	_assert("a cena traz UM esqueleto e UM corpo malhado",
		esqueleto != null and malha_no != null,
		"%s / %s" % ["ok" if esqueleto != null else "sem esqueleto",
			"ok" if malha_no != null else "sem malha"])
	if esqueleto == null or malha_no == null:
		_veredito()
		quit()
		return

	# ── 1. o esqueleto é o cadastro ─────────────────────────────────────────────────────────
	var lidas: Array[String] = []
	for i in range(esqueleto.get_bone_count()):
		lidas.append(esqueleto.get_bone_name(i))
	_assert("as juntas têm os nomes do cadastro, na ordem do cadastro",
		str(lidas) == str(JUNTAS_ESPERADAS), "%d juntas: %s" % [lidas.size(), ", ".join(lidas)])
	var arvore_ok := true
	var arvore_lida: Array[String] = []
	for i in range(esqueleto.get_bone_count()):
		var nome := esqueleto.get_bone_name(i)
		var p := esqueleto.get_bone_parent(i)
		var nome_pai := "" if p < 0 else esqueleto.get_bone_name(p)
		if nome_pai != String(PAI_DE.get(nome, "?")):
			arvore_ok = false
		arvore_lida.append("%s<-%s" % [nome, "raiz" if nome_pai == "" else nome_pai])
	_assert("cada junta pende do osso que o gerador escolheu", arvore_ok,
		"%s" % ", ".join(arvore_lida))

	# ── 2. a malha, superficie a superficie ─────────────────────────────────────────────────
	var mesh := malha_no.mesh as ArrayMesh
	_assert("o corpo e uma ArrayMesh de tres primitivas",
		mesh != null and mesh.get_surface_count() == SUPERFICIES_ESPERADAS,
		"%d superficies" % (0 if mesh == null else mesh.get_surface_count()))
	if mesh == null:
		_veredito()
		quit()
		return
	var triangulos := 0
	var vertices := 0
	var sem_par := 0
	var peso_fora := 0
	var osso_fora := 0
	var caixa_total := AABB()
	var caixa_nova := true
	var por_junta: Dictionary = {}
	var fmt_lidos: Array[String] = []
	for s in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(s)
		var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var jnt = arr[Mesh.ARRAY_BONES]
		var pes = arr[Mesh.ARRAY_WEIGHTS]
		fmt_lidos.append("surf %d pos=%d jnt=%d pes=%d tri=%d" % [s, pos.size(),
			0 if jnt == null else jnt.size(), 0 if pes == null else pes.size(),
			mesh.surface_get_array_index_len(s) / 3])
		if pos == null:
			continue
		triangulos += mesh.surface_get_array_index_len(s) / 3
		var n := pos.size()
		vertices += n
		for i in range(n):
			var v := pos[i]
			caixa_total = (AABB(v, Vector3.ZERO) if caixa_nova
				else caixa_total.merge(AABB(v, Vector3.ZERO)))
			caixa_nova = false
			if jnt == null or pes == null or jnt.size() < (i * 4 + 4) or pes.size() < (i * 4 + 4):
				sem_par += 1
				continue
			var j0 := int(jnt[i * 4])
			var soma := 0.0
			var vivas := 0
			for k in range(4):
				var wk := float(pes[i * 4 + k])
				soma += wk
				if wk > 0.001:
					vivas += 1
			if vivas != 1 or not _igual(soma, 1.0, 0.01):
				peso_fora += 1
			if j0 < 0 or j0 >= esqueleto.get_bone_count():
				osso_fora += 1
				continue
			if por_junta.has(j0):
				por_junta[j0] = (por_junta[j0] as AABB).merge(AABB(v, Vector3.ZERO))
			else:
				por_junta[j0] = AABB(v, Vector3.ZERO)
	_assert("a malha bate com o cadastro do gerador",
		triangulos == TRIANGULOS_ESPERADOS and vertices == VERTICES_ESPERADOS,
		"%d triangulos / %d vertices contra %d / %d; %s" % [triangulos, vertices,
			TRIANGULOS_ESPERADOS, VERTICES_ESPERADOS, " | ".join(fmt_lidos)])
	_assert("todo vertice traz junta e peso", sem_par == 0,
		"%d vertices sem par de pele" % sem_par)
	_assert("a pele e rigida: 1,0 em uma junta so, zero nas outras tres",
		peso_fora == 0 and osso_fora == 0,
		"%d pesos quebrados, %d juntas fora do cadastro" % [peso_fora, osso_fora])
	var mortas: Array[String] = []
	for i in range(esqueleto.get_bone_count()):
		if not por_junta.has(i):
			mortas.append(esqueleto.get_bone_name(i))
	_assert("nenhuma junta morta: todo osso move pelo menos um vertice", mortas.is_empty(),
		"%s" % ("todas as %d juntas tem pele" % esqueleto.get_bone_count()
			if mortas.is_empty() else ", ".join(mortas)))

	# ── 5. o corpo tem o tamanho de uma pessoa ──────────────────────────────────────────────
	_assert("o corpo mede a altura de um oficial",
		caixa_total.size.y > 1.60 and caixa_total.size.y < 1.85,
		"%.3f m de pe a quepe, caixa y de %.3f a %.3f" % [caixa_total.size.y,
			caixa_total.position.y, caixa_total.end.y])
	_assert("pe no soalho, quepe no topo",
		_igual(caixa_total.position.y, 0.0, 0.01) and caixa_total.end.y > 1.60,
		"soalho em %.3f, topo em %.3f" % [caixa_total.position.y, caixa_total.end.y])
	var dedo := 0.0
	for s in range(mesh.get_surface_count()):
		var pos: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		if pos == null:
			continue
		for i in range(pos.size()):
			dedo = maxf(dedo, absf(pos[i].x))
	_assert("a T-pose abre a envergadura do cadastro", _igual(dedo, 0.890, 0.01),
		"ponta do dedo a %.3f m do eixo" % dedo)

	# ── 3. o osso mora na peça, e pousa no cadastro ─────────────────────────────────────────
	var ancoragem_ok := true
	var ancoragem_lida: Array[String] = []
	for i in range(esqueleto.get_bone_count()):
		# Repouso GLOBAL, não o `get_bone_rest()`: o origin daquele é a translação local em
		# relação ao pai, e compará-lo com vértices de malha (que moram no espaço do corpo
		# inteiro) aprovaria o osso raiz e reprovaria todos os outros por motivo de espaço, não
		# de geometria.
		var repous := esqueleto.get_bone_global_rest(i).origin
		if not por_junta.has(i):
			ancoragem_ok = false
			ancoragem_lida.append("%s SEM PELE" % esqueleto.get_bone_name(i))
			continue
		var caixa_j: AABB = (por_junta[i] as AABB).grow(FOLGA_ANCORAGEM)
		var dentro := caixa_j.has_point(repous)
		if not dentro:
			ancoragem_ok = false
		ancoragem_lida.append("%s@%.2f %s" % [esqueleto.get_bone_name(i), repous.y,
			"dentro" if dentro else "FORA"])
	_assert("cada osso em repouso cai dentro da caixa dos vertices que ele move",
		ancoragem_ok, "%s" % ", ".join(ancoragem_lida))
	var repouso_ok := true
	var repouso_lido: Array[String] = []
	for nome in REPOUSO.keys():
		var idx := esqueleto.find_bone(nome)
		if idx < 0:
			repouso_ok = false
			repouso_lido.append("%s AUSENTE" % nome)
			continue
		var g := esqueleto.get_bone_global_rest(idx).origin
		var e: Vector3 = REPOUSO[nome]
		if g.distance_to(e) > FOLGA:
			repouso_ok = false
		repouso_lido.append("%s %.3f,%.3f,%.3f%s" % [nome, g.x, g.y, g.z,
			"" if g.distance_to(e) <= FOLGA else " != " + str(e)])
	_assert("o esqueleto importado pousa onde o gerador escreveu, osso a osso", repouso_ok,
		"%s" % " | ".join(repouso_lido))

	# ── 4. dobrar move a cadeia, não o mundo ────────────────────────────────────────────────
	var ombro := esqueleto.find_bone("braco_e")
	var cotovelo := esqueleto.find_bone("antbraco_e")
	var mao := esqueleto.find_bone("mao_e")
	var quadril := esqueleto.find_bone("quadril")
	var base_ombro := esqueleto.get_bone_global_pose(ombro).origin
	var coto_antes := base_ombro.distance_to(esqueleto.get_bone_global_pose(cotovelo).origin)
	var mao_antes := base_ombro.distance_to(esqueleto.get_bone_global_pose(mao).origin)
	var quadril_antes := esqueleto.get_bone_global_pose(quadril).origin
	esqueleto.set_bone_pose_rotation(ombro, Quaternion(Vector3(0, 0, 1), -0.9))
	esqueleto.force_update_all_bone_transforms()
	var pos_cotovelo := esqueleto.get_bone_global_pose(cotovelo).origin
	var pos_mao := esqueleto.get_bone_global_pose(mao).origin
	var pos_quadril := esqueleto.get_bone_global_pose(quadril).origin
	var coto_depois := base_ombro.distance_to(pos_cotovelo)
	var mao_depois := base_ombro.distance_to(pos_mao)
	_assert("o braço e rigido: ombro-cotovelo e ombro-mao no comprimento do cadastro",
		_igual(coto_antes, BRACO_E_COTOVELO, FOLGA) and _igual(mao_antes, BRACO_E_MAO, FOLGA)
			and _igual(coto_depois, BRACO_E_COTOVELO, FOLGA)
			and _igual(mao_depois, BRACO_E_MAO, FOLGA),
		"antes %.3f / %.3f, depois do giro %.3f / %.3f, cadastro %.3f / %.3f" % [
			coto_antes, mao_antes, coto_depois, mao_depois,
			BRACO_E_COTOVELO, BRACO_E_MAO])
	_assert("girar o ombro leva antbraco e mao para baixo, juntos",
		pos_cotovelo.y < base_ombro.y - 0.10 and pos_mao.y < base_ombro.y - 0.20,
		"ombro y %.3f, cotovelo y %.3f, mao y %.3f apos -0,9 rad" % [base_ombro.y,
			pos_cotovelo.y, pos_mao.y])
	_assert("o giro do braco nao encosta no quadril",
		pos_quadril.distance_to(quadril_antes) < FOLGA,
		"quadril %.3f,%.3f,%.3f antes e depois" % [pos_quadril.x, pos_quadril.y, pos_quadril.z])
	esqueleto.set_bone_pose_rotation(ombro, Quaternion.IDENTITY)
	esqueleto.force_update_all_bone_transforms()
	_assert("a pose volta ao repouso sem deixar rastro",
		esqueleto.get_bone_global_pose(mao).origin.distance_to(
			esqueleto.get_bone_global_rest(mao).origin) < FOLGA,
		"mao devolvida a %.3f,%.3f,%.3f" % [
			esqueleto.get_bone_global_pose(mao).origin.x,
			esqueleto.get_bone_global_pose(mao).origin.y,
			esqueleto.get_bone_global_pose(mao).origin.z])

	# ── 6. o preço do binário ───────────────────────────────────────────────────────────────
	var f := FileAccess.open(CAMINHO_GLB, FileAccess.READ)
	_assert("o arquivo do tripulante abre para leitura", f != null, CAMINHO_GLB)
	var cabecalho := 0
	var versao := 0
	var declarado := 0
	var comprimento := 0
	var arquivo := PackedByteArray()
	if f != null:
		cabecalho = f.get_32()
		versao = f.get_32()
		declarado = f.get_32()
		comprimento = f.get_length()
		f.seek(0)
		arquivo = f.get_buffer(comprimento)
		f.close()
	_assert("o cabecalho glTF e o que o arquivo diz",
		cabecalho == 0x46546C67 and versao == 2 and declarado == arquivo.size()
			and comprimento == arquivo.size(),
		"magic 0x%08X versao %d declarado %d, length %d, bytes %d" % [cabecalho, versao,
			declarado, comprimento, arquivo.size()])
	_assert("o corpo cabe no orcamento do .pck",
		arquivo.size() <= TETO_BYTES,
		"%d bytes de %d (%.1f%% da folha)" % [arquivo.size(), TETO_BYTES,
			100.0 * float(arquivo.size()) / float(TETO_BYTES)])

	# ── 7. nada disso sorteia ──────────────────────────────────────────────────────────────
	var jogo := (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(jogo)
	await _frames(3)
	jogo.rng.seed = SEMENTE_RNG
	jogo.visual_rng.seed = SEMENTE_VISUAL
	var antes_rng := int(jogo.rng.state)
	var antes_visual := int(jogo.visual_rng.state)
	var cauda_antes := _cauda(jogo)
	var esqueletos_antes := _contar_esqueletos(jogo.bridge_rig)
	# Desde a tripulação de `tripulante_rig.gd` a ponte não chega vazia a esta sonda: os seis corpos
	# do cadastro já estão montados, e conferir isso aqui é o que impede o teste de abaixo ler os
	# ossos do jogo como se fossem os seis injetados pelo próprio teste.
	_assert("a ponte do jogo já vem com os seis corpos do cadastro montados",
		esqueletos_antes == 6,
		"%d Skeleton3D sob bridge_rig antes de injetar corpo" % esqueletos_antes)
	for i in range(6):
		var instancia := cena.instantiate()
		jogo.bridge_rig.add_child(instancia)
		var esc := _procurar(instancia, "Skeleton3D") as Skeleton3D
		if esc != null:
			esc.set_bone_pose_rotation(esc.find_bone("braco_e"),
				Quaternion(Vector3(0, 0, 1), -0.6))
	var depois_rng := int(jogo.rng.state)
	var depois_visual := int(jogo.visual_rng.state)
	var cauda_depois := _cauda(jogo)
	_assert("instanciar e dobrar seis corpos nao sorteia um digito",
		antes_rng == depois_rng and antes_visual == depois_visual,
		"rng %d -> %d, visual %d -> %d" % [antes_rng, depois_rng, antes_visual, depois_visual])
	_assert("a cauda de quarenta sorteios sobrevive ao rig",
		str(cauda_antes) == str(cauda_depois),
		"primeiro sorteio %d e ultimo %d dos dois lados" % [
			int(cauda_antes[0]), int(cauda_antes[cauda_antes.size() - 1])])
	var esqueletos_depois := _contar_esqueletos(jogo.bridge_rig)
	_assert("os seis corpos entraram na ponte com esqueleto proprio",
		esqueletos_depois - esqueletos_antes == 6,
		"%d -> %d Skeleton3D sob bridge_rig" % [esqueletos_antes, esqueletos_depois])

	_veredito()
	quit()

func _procurar(raiz: Node, classe: String) -> Node:
	for c in raiz.get_children():
		if c.get_class() == classe:
			return c
		var fundo := _procurar(c, classe)
		if fundo != null:
			return fundo
	return null

func _contar_esqueletos(raiz: Node) -> int:
	var total := 0
	for c in raiz.get_children():
		if c.get_class() == "Skeleton3D":
			total += 1
		total += _contar_esqueletos(c)
	return total

func _cauda(jogo: Node) -> Array:
	var saida: Array = []
	for i in range(40):
		saida.append(jogo.rng.randi())
	jogo.rng.seed = SEMENTE_RNG
	return saida

func _veredito() -> void:
	for n in notes:
		print("SONDA-HUMANOIDE: " + n)
	print("SONDA-HUMANOIDE: veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame
