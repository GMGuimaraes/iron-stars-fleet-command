extends SceneTree

## Fotogramas reais da ponte para ajuste de pintura. Headless usa o renderizador dummy e devolve
## tela preta: neblina, exposição, glow e recorte da janela só se medem com PNG de verdade, e
## estes vinte e sete quadros são o material de leitura. Não mexe na economia nem no sorteio de
## combate — mas os quadros do meio montam cenário de verdade, e cenário engole e queima: por isso a
## sonda devolve os cascos a 100 antes de fotografar a estrela e diz isso na asserção. Os três
## quadros da trinca (11b, 11c, 11d) são a exceção declarada: eles congelam o `process` do jogo,
## carimbam o epicentro com uma ameaça posta à mão e medem a diferença pixel a pixel entre dois
## fotogramas do mesmo tabuleiro — é a única régua que existe para a pergunta «a fissura nasceu do
## lado certo do vidro, e nasceu uma vez só».
##
## Uso (janela real, sem --headless):
##   godot --path . --quit-after 4000 -s res://tools/probes/fotograma.gd
## O orçamento é em quadros e a ruína espera segundos reais: 4000 cobre a sequência inteira mesmo
## numa máquina que desenha a 144 Hz, e `quit()` fecha a sonda antes disso quando ela termina. O
## orçamento subiu de 2000 quando a aviação entrou: o quadro 05e espera a ida do caçado em tempo
## real, e numa janela a 144 Hz dois segundos de voo custam duzentos quadros, não cento e vinte.

const OUT := "D:/Downloads/tmp-userdata/frame/"
## Espelho de `main.gd` para o quadro da ruína: se a tabela de fases ou o teto de rolagem mudarem
## lá, o asserção aqui quebra — é de propósito, o mesmo motivo de `tools/probes/morte.gd`.
const FASES_DA_TABELA := 5
const TETO_ROLAGEM := 0.3
## Espelho do poço em `main.gd`: é aqui, e só aqui, que a pintura das 252 amostras pode ser conferida
## instância a instância. Sob `--headless` o `MultiMesh.set_instance_transform` é descartado sem erro
## e a leitura volta identidade; em janela os dois lados batem. Um `ang` trocado num laço de desenho
## não dá exceção — dá um céu torto, e é de desenho que esta sonda trata.
const POCO_POS := Vector3(0.0, 0.0, -78.0)
const POCO_HORIZONTE := 9.0
const POCO_ANEL_FOTON := 1.08
const POCO_DISCO_INTERNO := 1.55
const POCO_DISCO_EXTERNO := 3.80
const POCO_DISCO_FAIXAS := 3
const POCO_DISCO_AMOSTRAS := 44
const POCO_DISCO_INCLINACAO := 0.17
const POCO_ARCO_ALTO := 1.24
const POCO_ARCO_BAIXO := 1.06
const POCO_ARCO_AMOSTRAS := 40
const POCO_ARCO_LARGO := 3.10
const POCO_DOPPLER := 0.45
## Espelho de `main.gd`: se o alcance do canhão da capitânia mudar lá, o quadro 05f quebra aqui —
## mesmo motivo das constantes do poço acima.
const CAPITAL_ALCANCE := 60.0
## Espelhos do visor e da câmera, para o quadro da trinca poder prever o pixel do epicentro. Se a
## boca, a altura ou o FOV mudarem em `_build_bridge`, a projeção abaixo quebra — é de propósito: a
## fissura só aponta para a ameaça se a conta do quadro e a do jogo forem a mesma conta.
const VISOR_POS_Y := 1.3
const VISOR_POS_Z := -7.85
const VISOR_LARGURA := 13.2
const PONTE_FOV := 78.0
const TRINCA_FOLGA_UX := 0.32
## Ameaça usada para carimbar o epicentro: a 20 u de lado e 60 u à frente ela projeta o leque a
## ~22% da meia-tela do centro — longe do meio para não confundir com ruído, dentro da boca para
## não ser engolido pela parede do ombro. E fica mais perto que a estrela (77,8 u do rig na origem),
## então é ela quem ganha a escolha do `_ux_do_impacto`.
const FONTE_X := 20.0
const FONTE_Z := -60.0
## Casco dos dois quadros trincados: degrau 2 (de 25% a 49% de dano) com o alarme já aceso dos dois
## lados (`ALARME_CASCO` é 60), para que a única diferença entre os fotogramas seja o deslocamento.
const TRINCA_HP := 49.0
## Corte da diferença de luminância e passo da varredura. O leque aceso sob o alfa 0,05 do pão soma
## ~0,1 de luminância no pixel — dois terços de ordem acima deste corte, que serve para o halo de
## um terço (`_pinta`) também entrar na conta.
const CORTE_DELTA := 0.012
const PASSO_VARREDURA := 2
## Piso da janela circular usada na comparação de luz com o quadro limpo, em pixels. A janela real é
## o `raio_p90` medido do próprio leque — o corpo do desenho — porque o pior raio da mesma conta deu
## 236 px e não é o leque: é o `glow` do motor vazando pela borda de baixo do pão até o parapeito.
## Um leque miúdo demais para preencher a janela não apaga a asserção por acidente.
const RAIO_JANELA_MIN := 24.0
## Fração da janela que precisa acender entre o limpo e o trincado. É a régua de que a luz nova
## nasceu *daquele* lugar do vidro e não de um reflexo de passagem: um píxel solto aqui e ali não
## responde a pergunta, um quarto da clareira sim.
const FACA_ACESA := 0.25
## Distância aceita entre o epicentro previsto pela projeção e o centro medido no fotograma.
const TOL_EPICENTRO := 90.0
## Espelhos das rampas de `_tune_ship_look` para o quadro 05i. Se o topo de uma rampa mudar em
## `main.gd` e o número aqui não mudar junto, a asserção quebra — é de propósito: o quadro fotografa
## exatamente a conta que a salva cobra, e não uma impressão de brilho.
const TOPO_ENGINE := 3.0
const TOPO_FLARE := 0.58
const TOPO_GUN := 1.75
const TOPO_TRIP := 1.0
const PLUMA_MORTA := 0.45
const PLUMA_CHEIA := 1.5
## Casco do quadro de setor ferido: abaixo dos 55% da brasa e acima de zero, para o aço escurecer
## sem virar destroço (destroço tem contrato próprio, fotografado nos quadros 03 e 12/13).
const CASCO_FERIDO := 20.0

var breaks := 0
var notes: Array[String] = []

func _assert(label: String, condition: bool, detail: String) -> void:
	if condition:
		notes.append("OK   %s — %s" % [label, detail])
	else:
		breaks += 1
		notes.append("QUEBRA %s — %s" % [label, detail])

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var game := (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	await _frames(8)
	_tabular(game)
	await _fotograma(game, "01_abertura")

	# 02 — batalha pintada: cascos em estados diferentes, para brasa e pluma aparecerem juntas.
	for i in range(game.enemies.size()):
		game.enemies[i]["hp"] = [100.0, 72.0, 55.0, 40.0, 22.0, 8.0][i % 6]
		game.enemies[i]["engines"] = 40.0
		game.enemies[i]["weapons"] = 80.0
	for i in range(game.fleet.size()):
		game.fleet[i]["hp"] = [100.0, 88.0, 61.0, 100.0, 47.0, 93.0][i % 6]
		game.fleet[i]["engines"] = [100.0, 55.0, 12.0, 100.0, 70.0, 30.0][i % 6]
	for i in range(40):
		game._update_fleet(0.1)
		game._update_probes(0.1)
		game._update_bridge(0.1)
	var antes_da_salva := game.get_child_count()
	game._resolve_volley()
	var lances := game.get_child_count() - antes_da_salva
	_assert("a salva desenhou lances", lances > 0, "%d filhos novos no jogo" % lances)
	await _fotograma(game, "02_salva")

	# 03 — destroço e captura lado a lado: carvão com brasa baixa ao lado de quem pegou filete azul.
	var morto: Dictionary = game.enemies[4]
	(morto["node"] as Node3D).global_position = Vector3(-8.0, 0.0, -70.0)
	morto["hp"] = 0.0
	game._mark_wreck(morto["node"] as Node3D)
	var presa: Dictionary = game.enemies[5]
	(presa["node"] as Node3D).global_position = Vector3(9.0, 0.0, -66.0)
	presa["hp"] = 30.0
	game._mark_as_prize(presa["node"] as Node3D)
	for i in range(20):
		game._update_fleet(0.1)
		game._update_bridge(0.1)
	await _fotograma(game, "03_destroco_e_captura")

	# 04 — aproximação: o mesmo tabuleiro pelo visor, para julgar silhueta sem HUD na frente.
	# A camada de UI é local do `_build_ui`, então a sonda a procura pelos filhos em vez de
	# exigir um membro novo no jogo só para tirar foto.
	for filho in game.get_children():
		if filho is CanvasLayer:
			filho.visible = false
	await _fotograma(game, "04_sem_hud")

	# 05 — close-up de casco: a silhueta tem de ler de perto também, com o HUD fora do caminho.
	var perto: Node3D = game.fleet[1]["node"]
	perto.position = Vector3(0.0, -1.2, -26.0)
	var hostil_perto: Node3D = game.enemies[2]["node"]
	hostil_perto.position = Vector3(4.5, -0.6, -34.0)
	await _fotograma(game, "05_casco_perto")

	# 05b, 05c — o encouraçado com bateria e a carga em voo. `tools/probes/misseis.gd` conta
	# lançamentos, mede o disco e confere a barreira; a pergunta do PNG é de silhueta: os dois blocos
	# de tubo com seis bocas de latão aparecem lateralmente no casco promovido, e a carga com rastro
	# é visível no meio da corda? O HUD continua fora do caminho (o quadro 04 o escondeu) porque
	# estas duas perguntas são de leitura de corpo. Os cascos voltam a 100 antes da salva: o quadro
	# 02 já feriu metade da linha, e aqui se julga pintura, não a fatura.
	for lista in [game.fleet, game.enemies]:
		for corpo in lista:
			corpo["hp"] = 100.0
	game.capital_hp = 100.0
	game.batalha_encerrada = false
	game._ajustar_encoracados(2)
	var baterias := 0
	for ally in game.fleet:
		if (ally["node"] as Node3D).get_node_or_null("Bateria") != null:
			baterias += 1
	_assert("promover dois degraus desenha bateria em exatamente dois cascos",
		int(game.encoracados) == 2 and baterias == 2,
		"%d degraus na escada, %d silhuetas de bateria na linha" % [game.encoracados, baterias])
	var encouracado: Node3D = game.fleet[0]["node"]
	# A câmera da ponte mora em z 3,0 e o quadro 05 fotografa a 29 u dela: a essa distância os tubos
	# de 0,13 u da bateria têm quatro pixels e a pergunta "o encouraçado se distingue do cruzador?"
	# fica sem resposta. Aqui o casco promovido é posto a 19 u do olho, onde a boca de latão passa de
	# nove pixels — e o vizinho não promovido vai ao lado, a mesma distância, para o quadro comparar
	# as duas silhuetas na mesma escala em vez de confiar na memória de quem desenhou.
	encouracado.position = Vector3(-2.6, 0.2, -16.0)
	(game.fleet[2]["node"] as Node3D).position = Vector3(2.6, 0.2, -16.0)
	await _fotograma(game, "05b_encoracado_bateria")
	game.selected_target = 0
	game._resolve_volley()
	_assert("há cargas no ar no quadro do voo",
		int(game.misseis.size()) > 0 and int(game.missil_contagem["lancados"]) > 0,
		"%d em voo, %d lançados" % [game.misseis.size(), game.missil_contagem["lancados"]])
	# A espera é por condição, não por contagem de quadros: em janela o `delta` é tempo real, e a
	# taxa da máquina não pode decidir se o rastro sai fotografado no meio da corda ou grudado na
	# boca de lançamento. `frac` 0,45 é o miolo do voo — nem na originação, nem já detonado.
	var quadros_do_voo := 0
	while _frac_do_voo(game) < 0.45 and int(game.misseis.size()) > 0 and quadros_do_voo < 400:
		await process_frame
		quadros_do_voo += 1
	_assert("o quadro pegou a carga no meio do caminho",
		int(game.misseis.size()) > 0 and _frac_do_voo(game) >= 0.45,
		"carga a %0.2f da corda depois de %d quadros reais, %d ainda no ar" % [
			_frac_do_voo(game), quadros_do_voo, game.misseis.size()])
	await _fotograma(game, "05c_missil_em_voo")

	# 05d, 05e — o convés do porta-aviões e a agulha no ar. `tools/probes/cacas.gd` conta lançamentos,
	# mede o ponto do golpe e fecha a conta da ida-e-volta; a pergunta do PNG é de silhueta, e ela é a
	# mesma do quadro 05b: a laje larga e baixa lê «aviação» contra um cruzador puro ao lado, e o caçado
	# de asa cruzada se vê no meio da corda? Os dois cascos promovidos no 05b voltam à linha porque a
	# câmera é uma só e o close-up agora é da cauda da esquadra.
	(game.fleet[0]["node"] as Node3D).position = Vector3(-12.5, 0.0, -38.0)
	(game.fleet[2]["node"] as Node3D).position = Vector3(-2.5, 0.0, -38.0)
	game._ajustar_porta_avioes(1)
	var conveses := 0
	for ally in game.fleet:
		if (ally["node"] as Node3D).get_node_or_null("Conves") != null:
			conveses += 1
	var cauda: int = game.fleet.size() - 1
	_assert("vestir um convés desenha laje em exatamente um casco, na cauda do cadastro",
		int(game.porta_avioes) == 1 and conveses == 1
			and String(game.fleet[cauda]["classe"]) == "PORTAAVIOES",
		"%d degrau de aviação, %d silhuetas de convés, cauda lida como %s" % [
			game.porta_avioes, conveses, game.fleet[cauda]["classe"]])
	var conves: Node3D = game.fleet[cauda]["node"]
	conves.position = Vector3(-2.6, 0.2, -16.0)
	(game.fleet[3]["node"] as Node3D).position = Vector3(2.6, 0.2, -16.0)
	await _fotograma(game, "05d_porta_avioes_conves")
	game.selected_target = 0
	game._resolve_volley()
	_assert("há caçados no ar no quadro do voo",
		int(game.cacas.size()) > 0 and int(game.caca_contagem["lancados"]) > 0,
		"%d em voo, %d lançados" % [game.cacas.size(), game.caca_contagem["lancados"]])
	# Fração 0,20 é o miolo da ida: como o ciclo é de ida-e-volta, 0,20 do ciclo é 0,40 da corda —
	# mar aberto entre as duas linhas. A primeira versão deste quadro esperou 0,34 e saiu cega: a
	# agulha já estava encostada na esquadra hostil, perdida entre os clarões dos cascos, e o PNG não
	# respondia a pergunta nenhuma. Antes do toque, porque depois dele o rastro é o do impacto.
	var quadros_da_ida := 0
	while _frac_da_ida(game) < 0.20 and int(game.cacas.size()) > 0 and quadros_da_ida < 400:
		await process_frame
		quadros_da_ida += 1
	_assert("o quadro pegou a agulha na ida, em mar aberto e antes do toque",
		int(game.cacas.size()) > 0 and _frac_da_ida(game) >= 0.20 and _frac_da_ida(game) < 0.5,
		"agulha a %0.2f da ida-e-volta (%0.2f da corda) depois de %d quadros reais, %d ainda no ar" % [
			_frac_da_ida(game), _frac_da_ida(game) * 2.0, quadros_da_ida, game.cacas.size()])
	await _fotograma(game, "05e_caca_em_voo")

	# 05f — a capitânia atirando. `capitania.gd` fecha a régua, o preço e o sorteio; a pergunta do PNG é
	# de quadro, e é a única que nenhuma sonda de lógica responde: com o parapeito no pé da tela, os três
	# lances dela saem da PONTE ou nascem atrás da câmera e ficam invisíveis? A ponte avança para dentro
	# dos 60 u e o alvo comandado fica a ~40 u: os cascos hostis ainda têm tamanho na tela quando o
	# traço deles cruza a frente do visor.
	(game.bridge_rig as Node3D).global_position = Vector3(0.0, 0.0, -45.0)
	game.selected_target = 0
	var alcance_ponte := float(game._capitania_alcance())
	var lancados_antes := int(game.capitania_contagem["lancados"])
	var olho: Vector3 = (game.bridge_rig as Node3D).global_position
	# A régua é de diferença, não de absoluto: os quadros 05c e 05e deixam carga e agulha em voo, e a
	# ponte estacionada em z −45 está exatamente no corredor por onde elas passam. Contar todo traço a
	# menos de 1,8 u do olho faria a moldura depender de quantos quadros reais a máquina levou para
	# achar o miolo do voo — a lei é «os lances *dela* nascem na frente do parapeito», e só o que a
	# própria salva criou entra na conta.
	var no_ar: Dictionary = {}
	for filho in game.get_children():
		if filho is MeshInstance3D:
			no_ar[filho.get_instance_id()] = true
	game._resolve_volley()
	var bocais := 0
	var estranhos: Array[String] = []
	for filho in game.get_children():
		if not (filho is MeshInstance3D):
			continue
		if not (filho as Node3D).global_position.distance_to(olho) < 1.8:
			continue
		if no_ar.has(filho.get_instance_id()):
			estranhos.append(String(filho.name))
		else:
			bocais += 1
	_assert("com a ponte a %0.1f u do alvo comandado, o canhão de linha dela dispara" % alcance_ponte,
		alcance_ponte <= CAPITAL_ALCANCE \
			and int(game.capitania_contagem["lancados"]) - lancados_antes == 3,
		"alcance %0.3f u contra o teto de %0.0f, %d lance(s) novos na conta da capitânia" % [
			alcance_ponte, CAPITAL_ALCANCE, game.capitania_contagem["lancados"] - lancados_antes])
	_assert("os lances dela nascem em cima do olho da ponte, à frente do parapeito", bocais == 3,
		"%d traço(s) novo(s) a menos de 1,8 u de (%s); %d já estava no ar [%s]" % [
			bocais, olho, estranhos.size(), ", ".join(estranhos)])
	await _fotograma(game, "05f_capitania_atira")

	# 05g — a chapa por fora, com o quadro derivado da própria chapa. Os quadros 05 e 05b julgam o
	# casco a 19 e 29 u pelo visor da ponte, e a essa distância a junta de 32 px da chapa tem menos de
	# um pixel: nenhuma foto existente dizia se o metal procedural que vestiu a ponte veste também o
	# lado de fora. O desloc deste quadro era `Vector3(1.9, 3.2, 1.4)` escrito à mão, calibrado sobre
	# o casco que existia antes das gramáticas; com quatro famílias na esquadra o mesmo número passou
	# a fotografar um palmo de chapa contra um quadro de espaço vazio. A distância vem agora da caixa
	# medida do próprio casco (bilhete a bilhete, porque `global_aabb` servido pelo renderizador volta
	# vazio) com 6% de folga, e a direção é de través de estibordo com um dedo de proa e 20° de picada.
	# O ângulo é medido, não escolhido de ouvido: a 16° de través o casco enche mais o quadro, a média
	# da tela cai a 0,0091 e o `05g` reprova no próprio portão de imagem — aço escuro sobre espaço
	# escuro, e quanto menos céu na moldura menos luz. A 32° a luminância volta — 0,0119 sem massa no
	# mundo, 0,0133 com as 5 760 réplicas acesas atrás do costado — com a junta de chapa lida na
	# crista e no flanco.
	var casco_foto: Node3D = game.fleet[2]["node"]
	var caixa_foto: Array = _caixa_do_casco(casco_foto)
	var olhar_ext := Vector3(0.80, 0.34, -0.50).normalized()
	var meia_foto: Vector3 = Vector3.ZERO
	var distancia_ext := 0.0
	if caixa_foto.size() == 2:
		meia_foto = (caixa_foto[1] - caixa_foto[0]) / 2.0
		distancia_ext = _distancia_de_enquadramento(caixa_foto[0], caixa_foto[1],
			olhar_ext, 55.0) * 1.06
	_assert("a moldura de %s vem da caixa do próprio casco" % String(casco_foto.get_meta("gramatica")),
		caixa_foto.size() == 2 and meia_foto.length() > 1.0 and distancia_ext > 1.0,
		"meia-caixa %s, olho a %0.2f u com 6%% de folga" % [_caixa_texto(caixa_foto), distancia_ext])
	# O casco sai da linha para água funda: com o olho agora a ~11 u dele, o quadro deixaria de ser
	# close-up de chapa e viria fotografando a parede de bombordo da própria ponte, que o quadro 05f
	# estacionou a 45 u. O posto volta exatamente onde estava, e nenhum outro quadro lê esta banda.
	var posto_foto: Vector3 = casco_foto.position
	casco_foto.position = Vector3(0.0, 0.0, -190.0)
	var camera_exterior := Camera3D.new()
	camera_exterior.name = "SondaCascoPerto"
	camera_exterior.fov = 55.0
	# O olho é filho do casco: a posição local passa na mesma escala do navio, então o enquadramento
	# derivado acima vale para qualquer `scale_factor` — inclusive o de um casco de fase futura.
	camera_exterior.position = olhar_ext * distancia_ext
	var horizonte := Vector2(camera_exterior.position.x, camera_exterior.position.z).length()
	camera_exterior.rotation = Vector3(
		-atan2(camera_exterior.position.y, horizonte),
		atan2(camera_exterior.position.x, camera_exterior.position.z), 0.0)
	casco_foto.add_child(camera_exterior)
	await _frames(1)
	camera_exterior.make_current()
	await _fotograma(game, "05g_chapa_de_fora")
	game.ponte_camera.make_current()
	camera_exterior.queue_free()
	casco_foto.position = posto_foto

	# 05h — as quatro famílias lado a lado. `tools/probes/graficos.gd` prova por caixa que cada
	# gramática tem silhueta própria, mas caixa é número: a pergunta do PNG é se o olho separa
	# `lamina`, `marrelo`, `agulha` e `portao` na mesma moldura, na mesma escala, sem depender da
	# memória de quem desenhou a tabela. Os quatro cascos da proa (índices 0..3, um por família)
	# saem da linha, formam uma faixa com folga medida entre bordas, e voltam exatamente onde
	# estavam: nenhuma outra moldura desta sonda lê a água funda onde a faixa é fotografada, e os
	# quadros seguintes continuam vendo a mesma esquadra de antes.
	var quarteto: Array[int] = [0, 1, 2, 3]
	var nomes: Array[String] = []
	var guarda: Array[Vector3] = []
	var caixas: Array = []
	var boca_max := 0.0
	for i in quarteto:
		var corpo: Node3D = game.fleet[i]["node"]
		guarda.append(corpo.position)
		var caixa_i: Array = _caixa_do_casco(corpo)
		caixas.append(caixa_i)
		nomes.append("%s %s" % [String(corpo.get_meta("gramatica")), _caixa_texto(caixa_i)])
		if caixa_i.size() == 2:
			var meia_i: Vector3 = (caixa_i[1] - caixa_i[0]) / 2.0
			boca_max = maxf(boca_max, meia_i.x * corpo.scale.x)
	var passo := 2.0 * boca_max + 2.2
	var faixa_z := -140.0
	var minimo_faixa := Vector3(INF, INF, INF)
	var maximo_faixa := Vector3(-INF, -INF, -INF)
	var medidos := 0
	for k in range(quarteto.size()):
		var casco_k: Node3D = game.fleet[quarteto[k]]["node"]
		casco_k.position = Vector3((float(k) - 1.5) * passo, 0.0, faixa_z)
		if caixas[k].size() == 2:
			var escala_k: Vector3 = casco_k.scale
			var canto_min: Vector3 = caixas[k][0]
			var canto_max: Vector3 = caixas[k][1]
			minimo_faixa = minimo_faixa.min(casco_k.position + canto_min * escala_k)
			maximo_faixa = maximo_faixa.max(casco_k.position + canto_max * escala_k)
			medidos += 1
	var centro := (minimo_faixa + maximo_faixa) / 2.0
	var meio_faixa: Vector3 = (maximo_faixa - minimo_faixa) / 2.0
	var olhar_faixa := Vector3(0.0, 0.26, -1.0).normalized()
	var distancia_faixa := 0.0
	if medidos == quarteto.size():
		distancia_faixa = _distancia_de_enquadramento(-meio_faixa, meio_faixa,
			olhar_faixa, 50.0) * 1.05
	_assert("a faixa das quatro famílias tem caixa e passo medidos",
		medidos == quarteto.size() and passo > 4.0 and distancia_faixa > 1.0,
		"%s | passo %0.2f u, olho a %0.2f u de (%s)" % [", ".join(nomes), passo,
			distancia_faixa, centro])
	# Sem caixa não há moldura que derivar: o quadro é pulado e a asserção acima reprova a faixa, em
	# vez de fotografar a ponte de sempre e passar por comparativo de silhueta.
	if distancia_faixa > 1.0:
		var camera_faixa := Camera3D.new()
		camera_faixa.name = "SondaQuatroGramaticas"
		camera_faixa.fov = 50.0
		var desloc_faixa: Vector3 = olhar_faixa * distancia_faixa
		camera_faixa.position = centro + desloc_faixa
		var horiz_faixa := Vector2(desloc_faixa.x, desloc_faixa.z).length()
		camera_faixa.rotation = Vector3(-atan2(desloc_faixa.y, horiz_faixa),
			atan2(desloc_faixa.x, desloc_faixa.z), 0.0)
		game.add_child(camera_faixa)
		await _frames(1)
		camera_faixa.make_current()
		await _fotograma(game, "05h_quatro_gramaticas")
		game.ponte_camera.make_current()
		camera_faixa.queue_free()
	for k in range(quarteto.size()):
		(game.fleet[quarteto[k]]["node"] as Node3D).position = guarda[k]

	# 05i — o ataque por setor fotografado setor por setor. `tools/probes/modulos.gd` prova por
	# número que cada subsistema tem gaveta dentro do casco e que é a gaveta que manda na tinta; a
	# pergunta do PNG é se o olho separa as quatro no mesmo quadro, sem HUD e sem legenda. Cinco
	# cascos da proa saem da linha para água funda: o primeiro inteiro, o segundo com o `CASCO` a
	# 20%, o terceiro sem `MOTORES`, o quarto sem `ARMAS`, o quinto sem `TRIPULAÇÃO`. A baixa entra
	# pelo número que a salva cobra, nunca pelo material escrito a mão — se a foto mentisse por
	# tinta, ela mentiria exatamente da forma que o pedido do comandante quer evitar.
	var cinco_setor: Array[int] = [0, 1, 2, 3, 4]
	var guarda_ficha: Array = []
	var guarda_posto: Array[Vector3] = []
	var caixas_setor: Array = []
	var boca_setor_max := 0.0
	for i in cinco_setor:
		var un_guarda: Dictionary = game.fleet[i]
		guarda_ficha.append([un_guarda["hp"], un_guarda["engines"], un_guarda["weapons"],
			un_guarda["crew"]])
		var corpo_guarda: Node3D = un_guarda["node"]
		guarda_posto.append(corpo_guarda.position)
		var caixa_s: Array = _caixa_do_casco(corpo_guarda)
		caixas_setor.append(caixa_s)
		if caixa_s.size() == 2:
			boca_setor_max = maxf(boca_setor_max,
				((caixa_s[1] - caixa_s[0]) / 2.0).x * corpo_guarda.scale.x)
	var passo_setor := 2.0 * boca_setor_max + 2.4
	var minimo_setor := Vector3(INF, INF, INF)
	var maximo_setor := Vector3(-INF, -INF, -INF)
	var medidos_setor := 0
	for k in range(cinco_setor.size()):
		var un_k: Dictionary = game.fleet[cinco_setor[k]]
		un_k["hp"] = CASCO_FERIDO if k == 1 else 100.0
		un_k["engines"] = 0.0 if k == 2 else 100.0
		un_k["weapons"] = 0.0 if k == 3 else 100.0
		un_k["crew"] = 0.0 if k == 4 else 100.0
		game._tune_ship_look(un_k)
		var corpo_k: Node3D = un_k["node"]
		corpo_k.position = Vector3((float(k) - 2.0) * passo_setor, 0.0, -140.0)
		if caixas_setor[k].size() == 2:
			var escala_k: Vector3 = corpo_k.scale
			minimo_setor = minimo_setor.min(corpo_k.position + caixas_setor[k][0] * escala_k)
			maximo_setor = maximo_setor.max(corpo_k.position + caixas_setor[k][1] * escala_k)
			medidos_setor += 1
	var centro_setor := (minimo_setor + maximo_setor) / 2.0
	var meia_setor: Vector3 = (maximo_setor - minimo_setor) / 2.0
	var olhar_setor := Vector3(0.0, 0.30, -1.0).normalized()
	var distancia_setor := 0.0
	if medidos_setor == cinco_setor.size():
		distancia_setor = _distancia_de_enquadramento(-meia_setor, meia_setor, olhar_setor, 46.0) * 1.05
	_assert("a faixa dos cinco setores tem caixa, passo e moldura medidos",
		medidos_setor == cinco_setor.size() and passo_setor > 4.0 and distancia_setor > 1.0,
		"passo %0.2f u, olho a %0.2f u de (%s), meia-caixa %s" % [passo_setor, distancia_setor,
			centro_setor, _caixa_texto([minimo_setor, maximo_setor])])
	# A leitura de tinta: para cada um dos cinco, só o material do setor baixado pode estar no piso.
	# `pluma` entra na régua porque é a única parte do quadro que muda de tamanho, não de brilho.
	var tinta_ok := true
	var tinta_lida: Array[String] = []
	for k in range(cinco_setor.size()):
		var corpo_t: Node3D = game.fleet[cinco_setor[k]]["node"]
		var mats_t: Dictionary = corpo_t.get_meta("mat")
		var eng_lido := float((mats_t["engine"] as StandardMaterial3D).emission_energy_multiplier)
		var flare_lido := float((mats_t["flare"] as StandardMaterial3D).albedo_color.a)
		var gun_lido := float((mats_t["gun"] as StandardMaterial3D).emission_energy_multiplier)
		var trip_lido := float((mats_t["trip"] as StandardMaterial3D).emission_energy_multiplier)
		var plumas_t: Array = corpo_t.get_meta("plumas")
		var pluma_lida := 0.0
		if plumas_t.size() > 0:
			pluma_lida = float((plumas_t[0] as MeshInstance3D).scale.x)
		var eng_querido := 0.0 if k == 2 else TOPO_ENGINE
		var flare_querido := 0.0 if k == 2 else TOPO_FLARE
		var gun_querido := 0.0 if k == 3 else TOPO_GUN
		var trip_querido := 0.0 if k == 4 else TOPO_TRIP
		var pluma_querida := PLUMA_MORTA if k == 2 else PLUMA_CHEIA
		var morna := (absf(eng_lido - eng_querido) < 0.005
			and absf(flare_lido - flare_querido) < 0.005
			and absf(gun_lido - gun_querido) < 0.005
			and absf(trip_lido - trip_querido) < 0.005
			and absf(pluma_lida - pluma_querida) < 0.005)
		if not morna:
			tinta_ok = false
		tinta_lida.append("casco%d[%0.2f/%0.2f/%0.2f/%0.2f/%0.2f]" % [k, eng_lido, flare_lido,
			gun_lido, trip_lido, pluma_lida])
	_assert("só a tinta do setor baixado cai ao piso, e as outras três ficam no topo da rampa",
		tinta_ok, "%s (topos %0.1f/%0.2f/%0.1f/%0.1f, pluma %0.2f→%0.2f)" % [", ".join(tinta_lida),
			TOPO_ENGINE, TOPO_FLARE, TOPO_GUN, TOPO_TRIP, PLUMA_MORTA, PLUMA_CHEIA])
	# O aço é do CASCO e de mais ninguém: os outros três setores mortos escurecem a própria gaveta,
	# nunca a chapa. A régua é luminância, porque `ACO`/`CARVAO` são tinta de `main.gd` e o que a
	# ponte lê é «o casco a 20% está mais preto que o casco inteiro».
	var aco0 := (game.fleet[0]["node"] as Node3D).get_meta("mat") as Dictionary
	var aco1 := (game.fleet[1]["node"] as Node3D).get_meta("mat") as Dictionary
	var c0: Color = (aco0["hull"] as StandardMaterial3D).albedo_color
	var c1: Color = (aco1["hull"] as StandardMaterial3D).albedo_color
	var visivel_ok := true
	var visivel_lido: Array[String] = []
	for k in range(2, cinco_setor.size()):
		var ck: Color = ((game.fleet[cinco_setor[k]]["node"] as Node3D).get_meta("mat")
			as Dictionary)["hull"].albedo_color
		if absf(ck.get_luminance() - c0.get_luminance()) > 0.001:
			visivel_ok = false
		visivel_lido.append("casco%d %0.3f" % [k, ck.get_luminance()])
	_assert("o aço escurece só com o CASCO baixado — motor, arma e tripulação mortos não encostam na chapa",
		c1.get_luminance() < c0.get_luminance() - 0.05 and visivel_ok,
		"inteiro %0.3f, ferido %0.3f, setores mortos %s" % [c0.get_luminance(), c1.get_luminance(),
			", ".join(visivel_lido)])
	# E a árvore por trás da foto: cada um dos cinco cascos abre nas quatro gavetas com os bilhetes
	# da lei, conferidos aqui (na moldura que o comando vê) e não só na sonda de lógica.
	var particoes := {}
	var cinco_lidos: Array[String] = []
	for k in cinco_setor:
		var corpo_p: Node3D = game.fleet[k]["node"]
		var leitura: Array[String] = []
		for gaveta in ["CASCO", "MOTORES", "ARMAS", "TRIPULACAO"]:
			var no_g: Node3D = (corpo_p.get_meta("modulos") as Dictionary)[gaveta]
			leitura.append("%d" % _bilhetes(no_g).size())
		var chave := "/".join(leitura)
		particoes[chave] = int(particoes.get(chave, 0)) + 1
		cinco_lidos.append(chave)
	_assert("os cinco cascos fotografados particionam 9/6/4/1 na árvore",
		int(particoes.get("9/6/4/1", 0)) == cinco_setor.size(), "%s" % ", ".join(cinco_lidos))
	if distancia_setor > 1.0:
		var camera_setor := Camera3D.new()
		camera_setor.name = "SondaCincoSetores"
		camera_setor.fov = 46.0
		var desloc_setor: Vector3 = olhar_setor * distancia_setor
		camera_setor.position = centro_setor + desloc_setor
		var horiz_setor := Vector2(desloc_setor.x, desloc_setor.z).length()
		camera_setor.rotation = Vector3(-atan2(desloc_setor.y, horiz_setor),
			atan2(desloc_setor.x, desloc_setor.z), 0.0)
		game.add_child(camera_setor)
		await _frames(1)
		camera_setor.make_current()
		await _fotograma(game, "05i_cinco_setores")
		game.ponte_camera.make_current()
		camera_setor.queue_free()
	# Devolução: a faixa volta com a ficha e o posto exatos de antes, e a tinta é reescrita pelo
	# mesmo `_tune_ship_look` de sempre — os quadros seguintes continuam vendo a esquadra que
	# encontraram, e `06` em diante não herda setor morto nenhum.
	var devolvido_ok := true
	var devolvido_lido: Array[String] = []
	for k in range(cinco_setor.size()):
		var un_d: Dictionary = game.fleet[cinco_setor[k]]
		un_d["hp"] = guarda_ficha[k][0]
		un_d["engines"] = guarda_ficha[k][1]
		un_d["weapons"] = guarda_ficha[k][2]
		un_d["crew"] = guarda_ficha[k][3]
		(un_d["node"] as Node3D).position = guarda_posto[k]
		game._tune_ship_look(un_d)
		var ficha_d := [un_d["hp"], un_d["engines"], un_d["weapons"], un_d["crew"]]
		if str(ficha_d) != str(guarda_ficha[k]) or not (un_d["node"] as Node3D).position.is_equal_approx(guarda_posto[k]):
			devolvido_ok = false
		devolvido_lido.append(str(ficha_d))
	_assert("a faixa devolve ficha e posto exatos de antes de o próximo quadro fotografar",
		devolvido_ok, "%s" % ", ".join(devolvido_lido))

	# 06 — painel em acordeão: a dobra é pintura, e sonda de lógica não mede se o grupo fechado
	# ainda cabe na janela. A camada de UI volta a ficar visível de propósito: os quadros 04 e 05 a
	# esconderam.
	for filho in game.get_children():
		if filho is CanvasLayer:
			filho.visible = true
	game._toggle_grupo("MANOBRA")
	await _fotograma(game, "06_painel_grupo_aberto")
	game._toggle_grupo("MANOBRA")
	await _fotograma(game, "07_painel_recolhido")

	# 08, 09, 10 — os três cenários novos pintados em janela real. A sonda de lógica (`tools/
	# probes/cenarios.gd`) já conta as rochas e confere o raio; aqui a pergunta é outra: a geometria
	# aparece na tela? Foi exatamente assim que a mesa holográfica sumiu uma rodada inteira — um
	# nome de propriedade errado num `CylinderMesh` não falha no parse, aborta a função em runtime
	# e devolve `Nil`, e todas as sondas de lógica continuaram verdes.
	game._montar_cenario("CINTURAO")
	await _frames(3)
	_assert("o cinturão tem corpo na cena", game.cenario_root.get_child_count() == 14
		and game.holo_cenario.size() == 14,
		"%d nós e %d marcas na mesa" % [game.cenario_root.get_child_count(),
			game.holo_cenario.size()])
	await _fotograma(game, "08_cinturao")
	# A correnteza agora roda em `_process`, então um quadro de espera no windowed move pedra de
	# verdade. É aqui que o bug da marca mora: no headless a contagem fecha e a lógica passa verde
	# mesmo com o holograma deslocado pelo offset da raiz, porque nada lê `marca.position`.
	var deriva_fora := 0
	var marca_fora := 0
	var matriz := 0
	var filhas := 0
	var miudo := 0
	for i in range(90):
		await process_frame
	for rocha in game.rochas:
		var pos_rocha: Vector3 = rocha["pos"]
		var nodo_rocha: Node3D = rocha["no"]
		if not is_instance_valid(nodo_rocha) or nodo_rocha.global_position.distance_to(pos_rocha) > 0.01:
			deriva_fora += 1
		var marca_rocha: MeshInstance3D = rocha["marca"]
		if not is_instance_valid(marca_rocha):
			marca_fora += 1
		elif marca_rocha.position.distance_to(game._holo_de(pos_rocha)) > 0.01:
			marca_fora += 1
		var geracao := int(rocha["geracao"])
		if geracao <= 0:
			matriz += 1
		elif geracao == 1:
			filhas += 1
		else:
			miudo += 1
	# A população não é mais o número 14: estes noventa quadros são batalha viva, e a salva que
	# fecha a integridade de uma pedra é a mecânica da fatia, não um defeito dela. O que vale é a
	# contabilidade da rachadura — cada matriz perdida devolve duas filhas, miúdo nenhum sobre
	# (geração 2 esmiúça sem deixar corpo) e o total bate com as partes. Cravar `== 14` reprovaria
	# o jogo por ele ter funcionado, e aprovaria por nada ter acontecido: as duas coisas que esta
	# casa não faz. Medido em cinco janelas desta fatia: duas acordaram com a pedra rachada (13 + 2)
	# e três com o leque inteiro (14 + 0), porque o `delta` de janela é tempo de parede.
	_assert("depois de noventa quadros voando, corpo e marca continuam colados no dicionário",
		deriva_fora == 0 and marca_fora == 0 and miudo == 0 and filhas % 2 == 0 \
			and matriz + filhas / 2 == 14 and int(game.rochas.size()) == matriz + filhas,
		"%d corpos e %d marcas fora do lugar, %d corpos no mapa (%d matriz + %d filha(s), %d miúdo)" % [
			deriva_fora, marca_fora, game.rochas.size(), matriz, filhas, miudo])
	await _fotograma(game, "08b_cinturao_a_deriva")

	game._montar_cenario("POCO")
	await _frames(3)
	_assert("o poço pinta três nós: sombra, disco e arco",
		game.cenario_root.get_child_count() == 3 and game.holo_cenario.size() == 1,
		"%d nós e %d marcas na mesa" % [game.cenario_root.get_child_count(),
			game.holo_cenario.size()])
	# Em janela a escrita por instância pega, então a régua volta a ser o MultiMesh — e a comparação
	# com o espelho em RAM é o que prova que os dois lados são o mesmo céu, não dois céus.
	var disco_mm: MultiMesh = game.poco_disco.multimesh
	var arco_mm: MultiMesh = game.poco_lente.multimesh
	_assert("disco e arco têm a conta de amostras da tabela",
		int(disco_mm.instance_count) == POCO_DISCO_FAIXAS * POCO_DISCO_AMOSTRAS
			and int(arco_mm.instance_count) == POCO_ARCO_AMOSTRAS * 3,
		"%d de disco e %d de arco" % [disco_mm.instance_count, arco_mm.instance_count])
	var fora_disco := 0
	for faixa in range(POCO_DISCO_FAIXAS):
		for i in range(POCO_DISCO_AMOSTRAS):
			var n := faixa * POCO_DISCO_AMOSTRAS + i
			var esperado := _ponto_disco(faixa, i)
			if _tr_errado(disco_mm.get_instance_transform(n), esperado["tr"]) \
					or _cor_errada(disco_mm.get_instance_color(n), esperado["cor"]):
				fora_disco += 1
	_assert("cada amostra do disco está no lugar, no tamanho e no tom da fórmula",
		fora_disco == 0, "%d de %d amostras fora do esperado" % [fora_disco,
			disco_mm.instance_count])
	var fora_arco := 0
	for i in range(POCO_ARCO_AMOSTRAS * 3):
		var quer := _ponto_arco(i)
		if _tr_errado(arco_mm.get_instance_transform(i), quer["tr"]) \
				or _cor_errada(arco_mm.get_instance_color(i), quer["cor"]):
			fora_arco += 1
	_assert("aro de fótons e os dois arcos dobrados batem com a tabela",
		fora_arco == 0, "%d de %d amostras fora do esperado" % [fora_arco,
			arco_mm.instance_count])
	var aro_ok := 0
	for i in range(POCO_ARCO_AMOSTRAS):
		if absf((arco_mm.get_instance_transform(i) as Transform3D).origin.length()
				- POCO_HORIZONTE * POCO_ANEL_FOTON) < 0.002:
			aro_ok += 1
	_assert("o aro de fótons está colado na sombra: os %d a %0.2f u do centro" % [
			POCO_ARCO_AMOSTRAS, POCO_HORIZONTE * POCO_ANEL_FOTON],
		aro_ok == POCO_ARCO_AMOSTRAS, "%d de %d no raio cravado" % [aro_ok, POCO_ARCO_AMOSTRAS])
	var pintadas: Array = game.estrelas_pintadas
	var fora_ceu := 0
	for i in range(pintadas.size()):
		if _tr_errado((game.campo_estelar as MultiMeshInstance3D).multimesh
				.get_instance_transform(i), pintadas[i]):
			fora_ceu += 1
	_assert("o céu pintado no MultiMesh é o mesmo céu do espelho em RAM",
		int(pintadas.size()) == 900 and fora_ceu == 0 and int(game.estrelas_dobradas) > 0,
		"%d de %d estrelas fora do espelho, %d dobradas pela lente" % [fora_ceu,
			pintadas.size(), game.estrelas_dobradas])
	await _fotograma(game, "09_poco")

	game._montar_cenario("ESTRELA")
	await _frames(3)
	_assert("a estrela tem corpo na cena (disco + 20 billets da coroa + luz)",
		game.cenario_root.get_child_count() == 22 and game.holo_cenario.size() == 1,
		"%d nós e %d marcas na mesa" % [game.cenario_root.get_child_count(),
			game.holo_cenario.size()])
	# A linha hostil mora dentro da corona (a ~25 u do disco) e o poço acabou de engolir metade
	# dela: para o quadro julgar pintura, e não a fatura do perigo, os cascos voltam a 100.
	for lista in [game.fleet, game.enemies]:
		for corpo in lista:
			corpo["hp"] = 100.0
	game.capital_hp = 100.0
	game.batalha_encerrada = false
	await _fotograma(game, "10_estrela")

	# 10b — o sistema planetário: planeta alto no plano, três luas e os três aros de órbita desenhados.
	# A conta de corpo, marca e posição é de `tools/probes/sistema.gd`; a pergunta do PNG é outra: se o
	# olho lê o aro inclinado e a lua em órbita, e se o planeta não virou bola branca estourada no meio
	# do campo. Nada aqui mexe nos cascos: o sistema não queima nem engole, só barra.
	game._montar_cenario("SISTEMA")
	await _frames(3)
	_assert("o sistema tem corpo na cena (planeta + limbo + três aros + três luas)",
		game.cenario_root.get_child_count() == 8 and game.holo_cenario.size() == 4,
		"%d nós e %d marcas na mesa" % [game.cenario_root.get_child_count(),
			game.holo_cenario.size()])
	game.battle_clock = 6.0
	game._orbitar_luas()
	await _fotograma(game, "10b_sistema")

	# 11 — tripulação em alarme: com a capitânia ferida, as quatro telas de console viram vermelhas
	# e os operadores sentados se debruçam. É pintura, e pintura só se julga em PNG — mas a contagem
	# dos seis corpos e o flanco do alarme são conferidos aqui, para o quadro não ser tela de fundo.
	game.capital_hp = 40.0
	await _frames(4)
	_assert("a ponte fotografada tem seis tripulantes e o alarme aceso",
		int(game.tripulacao.size()) == 6 and bool(game.ponte_em_alarme),
		"%d corpos, alarme=%s" % [game.tripulacao.size(), game.ponte_em_alarme])
	await _fotograma(game, "11_tripulacao_alarme")

	# 11e — o retrato do corpo rigged. O quadro 11 é o ponto de vista do comandante e o parapeito come
	# a borda do quadro: ele diz que a ponte ficou vermelha, não se o corpo tem osso. Aqui a lente
	# temporária entra no jogo (não na ponte, para o gabarito de filhos do rig não se mover), a camada
	# de UI sai de cena como no quadro 04, e as duas voltam no fim.
	# O alvo é o oficial de pé, não o operador sentado, e isso foi medido antes de ser escolhido: em
	# quatro lentes internas a bancada ficou entre a lente e quem tecla nela — a régua projetada dava
	# 407 px de corpo e o PNG devolvia mobília, porque altura projetada não vê oclusão. O oficial de
	# pé tem os 1,732 m livres, olha para o visor e segura o pad aceso.
	var camadas_ui: Array[Node] = []
	for filho in game.get_children():
		if filho is CanvasLayer and filho.visible:
			camadas_ui.append(filho)
			filho.visible = false
	# O relógio da batalha é cravado porque a pose vem dele: sem cravar, o retrato mudaria de fase a
	# cada corrida da sonda e o quadro deixaria de ser comparável. O valor volta no fim para os
	# quadros de míssil não nascerem atrasados.
	var relogio := float(game.battle_clock)
	game.battle_clock = 0.9
	game._update_tripulacao()
	var camera_corpo := Camera3D.new()
	camera_corpo.name = "SondaTripulacaoPerto"
	camera_corpo.fov = 50.0
	game.add_child(camera_corpo)
	await _frames(1)
	# Lida do próprio nó, não de uma coordenada digitada: com o casco adernado o posto não está onde
	# o cadastro o pôs. A lente vem de dentro e um pouco de ré, a 0,6 do convés — o único quadrante
	# da ponte que pega o oficial de corpo inteiro sem a asa dourada do visor atravessando o quepe.
	var posto: Dictionary = game.tripulacao[5]
	var ancorado: Vector3 = (posto["no"] as Node3D).global_position
	camera_corpo.position = ancorado + Vector3(-2.2, 0.6, 0.4)
	camera_corpo.look_at(ancorado + Vector3(0.0, 0.85, 0.0), Vector3.UP)
	camera_corpo.make_current()
	await _frames(1)
	# A guarda do retrato vazio não é «o corpo está adiante» — isso aprovaria um corpo a 179° do
	# centro da mira, e aprovou. São os dois ossos lidos por `unproject_position`: cabeça e pé têm de
	# cair dentro da tela, e a distância entre eles tem de ser metade do quadro para cima. Um corpo
	# que encolhe abaixo disso voltou a ser ponto, não pessoa, e o quadro deixaria de provar o #145.
	var esq: Skeleton3D = posto["esqueleto"]
	var osso_cabeca := int((posto["ossos"] as Dictionary)["cabeca"])
	var osso_pe := int((posto["ossos"] as Dictionary)["pe_e"])
	var topo: Vector3 = (esq.global_transform * esq.get_bone_global_pose(osso_cabeca)).origin
	topo.y += 0.16
	var sola: Vector3 = (esq.global_transform * esq.get_bone_global_pose(osso_pe)).origin
	var px_topo := camera_corpo.unproject_position(topo)
	var px_sola := camera_corpo.unproject_position(sola)
	var tela := get_root().get_visible_rect().size
	var altura_px := absf(px_topo.y - px_sola.y)
	var dentro := px_topo.x > 0.0 and px_sola.x > 0.0 and px_topo.x < float(tela.x) \
		and px_sola.x < float(tela.x) and px_topo.y > 0.0 and px_sola.y > 0.0 \
		and px_topo.y < float(tela.y) and px_sola.y < float(tela.y)
	_assert("o retrato fotografa o oficial de corpo inteiro, da viseira à sola, e ele é gente no quadro",
		dentro and altura_px >= 0.45 * float(tela.y),
		"%d px de corpo em %d px de tela (%.2f), topo (%d,%d) sola (%d,%d)" % [int(altura_px),
			int(tela.y), altura_px / float(tela.y), int(px_topo.x), int(px_topo.y),
			int(px_sola.x), int(px_sola.y)])
	await _fotograma(game, "11e_oficial_retrato")
	game.ponte_camera.make_current()
	camera_corpo.queue_free()
	game.battle_clock = relogio
	for camada in camadas_ui:
		camada.visible = true

	# 11b, 11c, 11d — o visor trincado fotografado contra ele mesmo. `tools/probes/vidro.gd` fecha
	# degrau, cache, RNG inerte e o sinal do `uv1_offset` por aritmética; a pergunta do PNG é a única
	# que nenhuma sonda de lógica responde, e ela é dupla:
	#
	# 1. o leque nasce do LADO da boca onde está a ameaça. Isso fixa a ordem da transformada de UV
	#    (`amostra = uv × escala + deslocamento`, epicentro em `-ux × largura`) e o sentido do eixo U
	#    da face medida — as duas coisas que um `offset` de sinal trocado faria nascer atrás do ombro
	#    errado sem que nenhum número de cabeçalho discordasse;
	# 2. o leque aparece UMA vez só. O pão é `CULL_DISABLED` (veste as duas faces) e a caixa tem seis
	#    faces com a grade de UV em três colunas por duas linhas; é essa grade que faz uma única face
	#    amostrar o quadro inteiro enquanto as outras cinco clampam na borda preta. Se a face de trás
	#    também amostrasse, os dois quadros trincados ficariam quase idênticos e a diferença sumiria.
	#
	# A régua é a diferença entre os DOIS quadros trincados, nunca contra o quadro limpo: entre o casco
	# cheio e o casco ferido a ponte também acende o alarme (corte em 60 u de casco) e inclina os seis
	# operadores, e essa luz não é do vidro. Bombordo e boreste compartilham o MESMO `capital_hp`, o
	# MESMO alarme, a MESMA tripulação e o MESMO tabuleiro congelado (`process_mode` desligado,
	# `_update_bridge(0.0)` chamado à mão); o único pixel que os separa é o deslocamento do epicentro.
	# O quadro limpo continua salvo para o olho conferir o antes, e é conferido só na janela do leque.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var rig_foto: Node3D = game.bridge_rig
	var posto_rig := rig_foto.global_position
	var giros_rig := rig_foto.global_rotation
	var fonte: Dictionary = game.enemies[0]
	var corpo_fonte: Node3D = fonte["node"]
	var posto_fonte := corpo_fonte.global_position
	var vida_fonte := float(fonte["hp"])
	var vidas_vizinhas: Array[float] = []
	var postos_vizinhos: Array[Vector3] = []
	for i in range(1, game.enemies.size()):
		vidas_vizinhas.append(float(game.enemies[i]["hp"]))
		postos_vizinhos.append((game.enemies[i]["node"] as Node3D).global_position)
		game.enemies[i]["hp"] = 0.0
	# O rig volta à origem com giro zero para a projeção analítica ser a do `_ux_do_impacto` do jogo,
	# que também trabalha no referencial do rig. A câmera é sentada no repouso: sem `process` rodando,
	# o trêmulo escrito por `_process` congelaria onde a última salva o deixou.
	rig_foto.global_position = Vector3.ZERO
	rig_foto.global_rotation = Vector3.ZERO
	game.ponte_camera.position = game.ponte_camera_base
	game.rochas.clear()
	game.astros.clear()
	fonte["hp"] = 100.0
	# O casco que carimba o epicentro fica invisível nos dois quadros: sem isso a diferença conteria a
	# silhueta dele, que por construção projeta no MESMO ponto da trinca, e o cluster deixaria de ser
	# do vidro. `_mais_proximo_vivo` lê posição e casco, nunca visibilidade.
	corpo_fonte.visible = false
	var visor: MeshInstance3D = game.ponte_visor
	var boca: BoxMesh = visor.mesh as BoxMesh
	_assert("a boca fotografada é a mesma que a sonda de lógica mede",
			boca != null and absf(boca.size.x - VISOR_LARGURA) < 0.001
				and visor.position.distance_to(Vector3(0.0, VISOR_POS_Y, VISOR_POS_Z)) < 0.001,
			"%0.2f u de boca em z %0.2f" % [boca.size.x, visor.position.z])
	game.capital_hp = 100.0
	game._update_bridge(0.0)
	await _fotograma(game, "11b_trinca_limpa")
	var ux_limpo: float = game.ponte_trinca_ux
	var degrau_limpo: int = game.ponte_trinca_degrau
	_assert("com o casco cheio o vidro acorda limpo de verdade — degrau zero, sem placa, sem offset",
			degrau_limpo == 0 and absf(ux_limpo) < 0.0001,
			"degrau %d, ux %0.4f" % [degrau_limpo, ux_limpo])

	corpo_fonte.global_position = Vector3(-FONTE_X, 0.0, FONTE_Z)
	game.capital_hp = TRINCA_HP
	game._update_bridge(0.0)
	var ux_bombordo: float = game.ponte_trinca_ux
	await _fotograma(game, "11c_trinca_bombordo")

	game.capital_hp = 100.0
	game._update_bridge(0.0)
	corpo_fonte.global_position = Vector3(FONTE_X, 0.0, FONTE_Z)
	game.capital_hp = TRINCA_HP
	game._update_bridge(0.0)
	var ux_boreste: float = game.ponte_trinca_ux
	await _fotograma(game, "11d_trinca_boreste")

	_assert("a ameaça a %0.0f u abre o epicentro antes do clamp da folga, espelhado de um lado ao outro" % FONTE_X,
			ux_bombordo > 0.0 and ux_boreste < 0.0
				and absf(ux_bombordo + ux_boreste) < 0.001
				and absf(ux_bombordo) < TRINCA_FOLGA_UX,
			"bombordo %0.4f, boreste %0.4f contra a folga %0.2f" % [ux_bombordo, ux_boreste,
				TRINCA_FOLGA_UX])
	var foto_limpa := Image.load_from_file(OUT + "11b_trinca_limpa.png")
	var foto_port := Image.load_from_file(OUT + "11c_trinca_bombordo.png")
	var foto_est := Image.load_from_file(OUT + "11d_trinca_boreste.png")
	_assert("os três fotogramas da trinca existem em disco",
			foto_limpa != null and foto_port != null and foto_est != null,
			"%s/%s/%s" % [foto_limpa != null, foto_port != null, foto_est != null])
	if foto_port != null and foto_est != null and foto_limpa != null:
		var meio := float(foto_est.get_width()) / 2.0
		var clusters: Dictionary = _trinca_na_tela(foto_port, foto_est, CORTE_DELTA)
		var a_boreste: Dictionary = clusters["pos"]
		var a_bombordo: Dictionary = clusters["neg"]
		var olho_fonte: Vector3 = Vector3(-ux_boreste * boca.size.x, visor.position.y,
			visor.position.z)
		var alvo_port: Vector3 = Vector3(-ux_bombordo * boca.size.x, visor.position.y,
			visor.position.z)
		var px_boreste := _pixel_da_ponte(game, olho_fonte, foto_est)
		var px_bombordo := _pixel_da_ponte(game, alvo_port, foto_port)
		# 1 e 2: luz nova existe, e cai do lado que a ameaça ocupa. O cluster positivo é o leque que
		# só o quadro de boreste tem; o negativo, o que só o de bombordo tem.
		_assert("o leque de boreste acende pixels à direita do meio, onde a ameaça estava",
				int(a_boreste["pixels"]) >= 40 and float(a_boreste["cx"]) > meio,
				"%d pixels a %0.0f px contra o meio em %0.0f" % [a_boreste["pixels"],
					a_boreste["cx"], meio])
		_assert("o leque de bombordo acende pixels à esquerda do meio, onde a ameaça estava",
				int(a_bombordo["pixels"]) >= 40 and float(a_bombordo["cx"]) < meio,
				"%d pixels a %0.0f px contra o meio em %0.0f" % [a_bombordo["pixels"],
					a_bombordo["cx"], meio])
		# 3: a previsão analítica (transformada real da câmera + `-ux × largura`) bate com o pixel
		# medido. É o portão da ordem da transformada: com o eixo U da face invertido, ou o `offset`
		# somado antes da escala, o cluster nasceria a centenas de pixels do previsto.
		var erro_est := absf(float(a_boreste["cx"]) - px_boreste.x)
		var erro_port := absf(float(a_bombordo["cx"]) - px_bombordo.x)
		_assert("o epicentro medido cai onde a projeção do vidro manda, nos dois lados",
				erro_est <= TOL_EPICENTRO and erro_port <= TOL_EPICENTRO,
				"erro %0.0f px a boreste e %0.0f px a bombordo, tolerância %0.0f px | previsto %0.0f/%0.0f, medido %0.0f/%0.0f" % [
					erro_est, erro_port, TOL_EPICENTRO, px_bombordo.x, px_boreste.x,
					a_bombordo["cx"], a_boreste["cx"]])
		# 4: um cluster só, e dentro do pão. A régua vem da cena, não de número escrito aqui: (a)
		# nenhum pixel do leque de boreste atravessa a linha do meio para a esquerda, nem o de
		# bombordo para a direita — é isso que descarta a segunda cópia do quadro vestindo a face de
		# trás; (b) o corpo do leque (o raio que cobre 90% dos pixels) cabe na meia-altura projetada
		# do próprio visor, porque fissura que nasce no vidro não pode ser maior que o vidro; (c) o
		# centro de cada leque cai dentro da boca projetada. O PIOR raio fica fora da asserção de
		# propósito: medido a 236 px ele não é geometria da rachadura, é o `glow` do motor vazando
		# pela borda de baixo do pão até o parapeito — luz do cenário, e o leque verdadeiro fecha em
		# ~50 px.
		var pao: Array[Vector2] = []
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				pao.append(_pixel_da_ponte(game, Vector3(visor.position.x + sx * boca.size.x * 0.5,
					visor.position.y + sy * boca.size.y * 0.5, visor.position.z), foto_est))
		var boca_px: Array[float] = [INF, -INF, INF, -INF]
		for p in pao:
			boca_px[0] = minf(boca_px[0], p.x)
			boca_px[1] = maxf(boca_px[1], p.x)
			boca_px[2] = minf(boca_px[2], p.y)
			boca_px[3] = maxf(boca_px[3], p.y)
		var meia_altura_px := (boca_px[3] - boca_px[2]) * 0.5
		_assert("o leque é um cluster só, sem cópia espelhada do outro lado da boca",
				float(a_boreste["min_x"]) > meio and float(a_bombordo["max_x"]) < meio
					and float(a_boreste["raio_p90"]) <= meia_altura_px
					and float(a_bombordo["raio_p90"]) <= meia_altura_px
					and float(a_boreste["cx"]) > boca_px[0] and float(a_boreste["cx"]) < boca_px[1]
					and float(a_bombordo["cx"]) > boca_px[0] and float(a_bombordo["cx"]) < boca_px[1],
				("corpo p90 %0.0f/%0.0f px contra meia-altura do pão %0.0f px | bordas %0.0f/%0.0f "
					+ "contra o meio %0.0f | pão projetado x[%0.0f..%0.0f] y[%0.0f..%0.0f] | cauda "
					+ "do glow a %0.0f/%0.0f px") % [a_boreste["raio_p90"], a_bombordo["raio_p90"],
						meia_altura_px, a_boreste["min_x"], a_bombordo["max_x"], meio,
						boca_px[0], boca_px[1], boca_px[2], boca_px[3],
						a_boreste["raio"], a_bombordo["raio"]])
		# 5: os dois lados têm a mesma força — é o mesmo quadro de pixels do mesmo degrau, só
		# espelhado pelo deslocamento. Assimetria aqui é a grade de UV vestindo faces diferentes.
		var proporcao := float(a_boreste["pixels"]) / maxf(float(a_bombordo["pixels"]), 1.0)
		_assert("os dois lados acendem a mesma conta de pixels", proporcao > 0.6
				and proporcao < 1.67, "%0.2f de boreste sobre bombordo (%d/%d)" % [
					proporcao, a_boreste["pixels"], a_bombordo["pixels"]])
		# 6: no quadro limpo aquele lugar do pão estava apagado, e no trincado acendeu. A janela é o
		# corpo medido do leque (não o pior raio, que é glow), e a régua é a fração da clareira que
		# muda de estado — não uma luminância de piso escrita à mão: a primeira versão desta asserção
		# cobria `antes < 0,12` e mediu 0,138, porque o pão limpo não é preto, é vidro de ponte com
		# luz de trabalho âmbar por trás. O que a fissura faz é subir aquele lugar de 0,138 a 0,281.
		var raio_janela := maxf(float(a_bombordo["raio_p90"]), RAIO_JANELA_MIN)
		var clareira := _luz_em_torno_de(foto_limpa, foto_port, px_bombordo, raio_janela,
			CORTE_DELTA)
		var faca := float(clareira["acensos"]) / maxf(float(clareira["amostras"]), 1.0)
		_assert("o mesmo lugar do pão estava apagado no limpo e acendeu no trincado",
				int(clareira["acensos"]) >= 30 and float(clareira["ganho"]) > 0.02
					and faca >= FACA_ACESA,
				("%d de %d pixels (fração %0.2f) acima do corte na janela de %0.0f px, luminância "
					+ "%0.3f virou %0.3f (ganho %0.3f)") % [clareira["acensos"], clareira["amostras"],
						faca, raio_janela, clareira["antes"], clareira["depois"],
						clareira["ganho"]])

	# Devolução do tabuleiro: a ruína fotografa a seguir é outro contrato e não lê rocha nem astro,
	# mas lê os cascos e o relógio — nada aqui deixa a esquadra em outro estado do que encontrou.
	corpo_fonte.visible = true
	corpo_fonte.global_position = posto_fonte
	fonte["hp"] = vida_fonte
	for i in range(1, game.enemies.size()):
		game.enemies[i]["hp"] = vidas_vizinhas[i - 1]
		(game.enemies[i]["node"] as Node3D).global_position = postos_vizinhos[i - 1]
	rig_foto.global_position = posto_rig
	rig_foto.global_rotation = giros_rig
	game.capital_hp = 40.0
	game._update_bridge(0.0)
	game.process_mode = Node.PROCESS_MODE_INHERIT

	# 12 e 13 — a ruína da capitânia fotografada em dois momentos do próprio relógio da morte: a
	# meia-sequência, com clarão aberto dentro do casco e estrobo na luz fria, e o fim dela, com os
	# três adernamentos nos tetos, o deck escurecido e a holografia apagada. `tools/probes/morte.gd`
	# conta fases, tetos e clarões com o relógio passo a passo; se a morte é legível na tela, só o PNG
	# diz — e é ela quem pega geometria ausente, que em GDScript não falha no parse e devolve `Nil`
	# em silêncio.
	# A espera é por condição e limitada por relógio de parede, não por contagem de quadros: em janela
	# o `delta` é o tempo real, e a taxa de quadros da máquina (60 ou 144 Hz) não pode decidir se o
	# quadro sai fotografado. Se o laço morto não andar, a asserção quebra com o número na mão.
	game.capital_hp = 0.0
	var inicio_do_clarao := Time.get_ticks_msec()
	var quadros_do_clarao := 0
	while float(game.morte_t) < 0.90 and Time.get_ticks_msec() - inicio_do_clarao < 6000:
		await process_frame
		quadros_do_clarao += 1
	_assert("a ponte morta roteia o laço real: a sequência anda em janela",
		bool(game.ponte_condenada) and float(game.morte_t) >= 0.90,
		"condenada=%s morte em %0.2f s depois de %d quadros reais" % [game.ponte_condenada,
			game.morte_t, quadros_do_clarao])
	_assert("no meio da ruína ainda há clarão no ar e a luz fria estroba",
		(game.morte_claroes as Array).size() > 0
			and float(game.ponte_luz_fria.light_energy) > 0.0,
		"%d clarões, fria %0.2f, trabalho %0.2f" % [(game.morte_claroes as Array).size(),
			game.ponte_luz_fria.light_energy, game.ponte_luz_trabalho.light_energy])
	await _fotograma(game, "12_ruina_claroes", false)
	var inicio_do_fim := Time.get_ticks_msec()
	var quadros_do_fim := 0
	while float(game.morte_t) < 2.75 and Time.get_ticks_msec() - inicio_do_fim < 6000:
		await process_frame
		quadros_do_fim += 1
	_assert("a ruína fecha os tetos e apaga tudo no quadro final",
		int(game.morte_fase) == FASES_DA_TABELA and (game.morte_claroes as Array).is_empty()
			and absf(float((game.bridge_rig as Node3D).rotation.z)) >= TETO_ROLAGEM - 0.01
			and float(game.ponte_luz_fria.light_energy) == 0.0,
		"fase=%d contra %d na tabela, %d clarões vivos, rolagem %0.3f contra o teto %0.2f, fria %0.2f, %d quadros" % [
			game.morte_fase, FASES_DA_TABELA, (game.morte_claroes as Array).size(),
			(game.bridge_rig as Node3D).rotation.z, TETO_ROLAGEM,
			game.ponte_luz_fria.light_energy, quadros_do_fim])
	await _fotograma(game, "13_ruina_extinta", false)

	for note in notes:
		print("SONDA-FOTOGRAMA: " + note)
	print("SONDA-FOTOGRAMA: veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	quit()

## Luminância média da tela. Espera dois fotogramas de desenho antes de ler a textura: sem isso
## o quadro sai byte-idêntico ao anterior e a leitura de pintura é feita sobre estado velho.
func _fotograma(game, nome: String, mesa_viva := true) -> void:
	await _frames(2)
	var img := get_root().get_texture().get_image()
	img.save_png(OUT + nome + ".png")
	var soma := 0.0
	var amostras := 0
	for u in range(0, img.get_width(), 37):
		for v in range(0, img.get_height(), 37):
			var c := img.get_pixel(u, v)
			soma += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			amostras += 1
	var media := soma / maxf(float(amostras), 1.0)
	_assert("%s tem imagem" % nome, media > 0.01,
		"luminância média %.4f em %dx%d, salvo em %s%s.png"
		% [media, img.get_width(), img.get_height(), OUT, nome])
	# A ponte é o `_build_bridge` do jogo; sem blips no ar o quadro não prova a mesa holográfica. Na
	# ruína a mesa some da vista de propósito — a asserção então cobra o oposto, senão o quadro novo
	# seria reprovado por um contrato que a própria morte assinou.
	_assert("%s tem mesa holográfica %s" % [nome, "viva" if mesa_viva else "apagada de propósito"],
		game.holo_blips.size() > 0 and (game.holo_root as Node3D).visible == mesa_viva,
		"%d blips, visível=%s" % [game.holo_blips.size(), (game.holo_root as Node3D).visible])

## Fração da corda em que a primeira carga em voo está agora — o relógio do próprio jogo, lido do
## mesmo jeito que `_atualizar_misseis` lê. É a régua do quadro 05c: com `frac` no miolo o rastro
## está desenhado sobre a mesa; com 0 a foto é boca de lançamento, com 1 é detonação.
func _frac_do_voo(game) -> float:
	if int(game.misseis.size()) == 0:
		return 0.0
	var missil: Dictionary = game.misseis[0]
	return clampf((float(game.battle_clock) - float(missil["nascido"]))
		/ maxf(float(missil["tau"]), 0.001), 0.0, 1.0)

## Fração da ida-e-volta em que o primeiro caçado no ar está agora — lida do mesmo relógio que
## `_atualizar_cacas` lê. É a régua do quadro 05e: abaixo de 0,5 o caçado ainda caminha para o alvo,
## então o rastro tem corda atrás de si e o golpe não abriu os dois traços do impacto.
func _frac_da_ida(game) -> float:
	if int(game.cacas.size()) == 0:
		return 0.0
	var caca: Dictionary = game.cacas[0]
	return clampf((float(game.battle_clock) - float(caca["nascido"]))
		/ maxf(float(caca["tau"]), 0.001), 0.0, 1.0)

## Bilhetes de um "Casco", descendo pelos quatro módulos de setor (mesmo andador de
## `tools/probes/graficos.gd`): o corpo mudou de pai, não de cota.
func _bilhetes(casco: Node3D) -> Array:
	var out: Array = []
	var pilha: Array[Node] = [casco]
	while not pilha.is_empty():
		var no: Node = pilha.pop_back()
		for filho in no.get_children():
			if filho is MeshInstance3D:
				out.append(filho)
			else:
				pilha.append(filho)
	return out

## Caixa do casco, bilhete a bilhete, na escala própria do navio. `global_aabb` é servido pelo
## renderizador e devolve caixa vazia sob `--headless`, então a medição é `mesh.get_aabb()` puxado
## pelo transform do nó dentro do `Casco` — o mesmo instrumento de `tools/probes/graficos.gd`. Desde
## a fatia dos módulos a descida atravessa `CASCO`/`MOTORES`/`ARMAS`/`TRIPULACAO`: o bilhete mudou
## de pai, não de cota, e o enquadramento tem de ver o mesmo casco de antes. Pluma e luz ficam de
## fora: são brilho, não volume, e entrariam na conta como silhueta que não existe.
## Devolve `[minimo, maximo]`, ou Array vazio quando nenhum bilhete foi medido — enquadramento
## nenhum se assina sobre caixa vazia.
func _caixa_do_casco(ship: Node3D) -> Array:
	var casco: Node3D = ship.get_meta("casco")
	var mats: Dictionary = ship.get_meta("mat")
	var minimo := Vector3(INF, INF, INF)
	var maximo := Vector3(-INF, -INF, -INF)
	var inverso: Transform3D = casco.global_transform.affine_inverse()
	var medidos := 0
	for billete in _bilhetes(casco):
		var mi := billete as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		if mi.material_override == mats["flare"] or mi.material_override == mats["luz"]:
			continue
		var caixa: AABB = mi.mesh.get_aabb()
		var base: Transform3D = inverso * mi.global_transform
		for k in range(8):
			var canto: Vector3 = base * Vector3(
				caixa.position.x if (k & 1) == 0 else caixa.end.x,
				caixa.position.y if (k & 2) == 0 else caixa.end.y,
				caixa.position.z if (k & 4) == 0 else caixa.end.z)
			minimo = minimo.min(canto)
			maximo = maximo.max(canto)
		medidos += 1
	if medidos == 0:
		return []
	return [minimo, maximo]

func _caixa_texto(caixa: Array) -> String:
	if caixa.size() != 2:
		return "nada medido"
	var meia: Vector3 = (caixa[1] - caixa[0]) / 2.0
	return "%0.2fx%0.2fx%0.2f" % [meia.x, meia.y, meia.z]

## Distância, ao longo de `olhar`, que mete a caixa inteira no quadro: para cada canto vale
## `dist >= ao_longe + perpendicular / tan(meia-abertura)` nos dois eixos, e o pior canto manda. É a
## conta que aposenta o desloc escrito à mão, que só servia ao casco que existia quando foi medido.
## A abertura horizontal sai da proporção real da janela — fingir 16:9 fixo estreitaria a moldura de
## propósito numa janela quadrada, e o quadro é lido na janela, não na tabela.
func _distancia_de_enquadramento(minimo: Vector3, maximo: Vector3, olhar: Vector3,
		fov: float) -> float:
	var e: Vector3 = olhar.normalized()
	var chao := Vector3.UP if absf(e.y) < 0.99 else Vector3.RIGHT
	var direita := chao.cross(e).normalized()
	var cima := e.cross(direita)
	var janela := DisplayServer.window_get_size()
	var proporcao := float(janela.x) / maxf(float(janela.y), 1.0)
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

## Retrato da trinca na tela: varre os dois fotogramas do MESMO tabuleiro e guarda os pixels cuja
## luminância mudou mais que `corte`, separados pelo sinal. `pos` é o que só existe no segundo
## quadro (o leque de boreste); `neg`, o que só existe no primeiro (o de bombordo). A varredura anda
## de dois em dois pixels: o leque tem ~110 px de diâmetro, e meia resolução não move o centro nem o
## raio — move o tempo, que em janela já é caro.
func _trinca_na_tela(a: Image, b: Image, corte: float) -> Dictionary:
	var w := b.get_width()
	var h := b.get_height()
	var pontos_pos: Array[Vector2] = []
	var pontos_neg: Array[Vector2] = []
	for v in range(0, h, PASSO_VARREDURA):
		for u in range(0, w, PASSO_VARREDURA):
			var ca: Color = a.get_pixel(u, v)
			var cb: Color = b.get_pixel(u, v)
			var la := 0.2126 * ca.r + 0.7152 * ca.g + 0.0722 * ca.b
			var lb := 0.2126 * cb.r + 0.7152 * cb.g + 0.0722 * cb.b
			var delta := lb - la
			if delta > corte:
				pontos_pos.append(Vector2(float(u), float(v)))
			elif delta < -corte:
				pontos_neg.append(Vector2(float(u), float(v)))
	return {"pos": _cluster(pontos_pos), "neg": _cluster(pontos_neg), "meio": float(w) / 2.0}

## Centro do conjunto (média simples das posições — é o centro do desenho, não o brilho dele), a
## caixa em X e Y, o pior raio medido a partir do centro e o raio que cobre noventa por cento dos
## pixels. O `raio` é o pior — e o pior, medido, é o vazão do `glow` sobre o parapeito, não o leque:
## no degrau 2 a conta deu corpo a ~50 px e cauda a 235 px. Por isso a asserção lê `raio_p90`, que é
## o leque, e guarda `raio` só para o número sair no log. Vazio devolve zeros: quem chama decide se
## a ausência é prova, e um cluster fantasma tem de aparecer como contagem, não como coordenada.
func _cluster(pontos: Array[Vector2]) -> Dictionary:
	if pontos.is_empty():
		return {"pixels": 0, "cx": 0.0, "cy": 0.0, "min_x": 0.0, "max_x": 0.0,
			"min_y": 0.0, "max_y": 0.0, "raio": 0.0, "raio_p90": 0.0}
	var sx := 0.0
	var sy := 0.0
	var minimo_x := INF
	var maximo_x := -INF
	var minimo_y := INF
	var maximo_y := -INF
	for p in pontos:
		sx += p.x
		sy += p.y
		minimo_x = minf(minimo_x, p.x)
		maximo_x = maxf(maximo_x, p.x)
		minimo_y = minf(minimo_y, p.y)
		maximo_y = maxf(maximo_y, p.y)
	var centro := Vector2(sx / float(pontos.size()), sy / float(pontos.size()))
	var raios: Array[float] = []
	for p in pontos:
		raios.append(p.distance_to(centro))
	raios.sort()
	var pior: float = raios[raios.size() - 1]
	var p90: float = raios[mini(int(raios.size() * 0.90), raios.size() - 1)]
	return {"pixels": pontos.size(), "cx": centro.x, "cy": centro.y, "min_x": minimo_x,
		"max_x": maximo_x, "min_y": minimo_y, "max_y": maximo_y, "raio": pior, "raio_p90": p90}

## Projecta um ponto do mundo no pixel da janela pela transformada REAL da câmera da ponte — origem
## incluida, porque com o `process` desligado o trêmulo congela onde a última salva o deixou, e a
## previsão tem de ser a da imagem salva, não a do repouso. A abertura horizontal sai da proporção do
## próprio quadro, como em `_distancia_de_enquadramento`: fingir 16:9 fixo deslocaria o epicentro
## previsto numa janela quadrada.
func _pixel_da_ponte(game, alvo: Vector3, tela: Image) -> Vector2:
	var camera: Camera3D = game.ponte_camera
	var t: Transform3D = camera.global_transform
	var desloc := alvo - t.origin
	var along := -desloc.dot(t.basis.z)
	var tan_v := tan(deg_to_rad(PONTE_FOV) * 0.5)
	var tan_h := tan_v * (float(tela.get_width()) / maxf(float(tela.get_height()), 1.0))
	var ndc := Vector2(desloc.dot(t.basis.x) / maxf(along * tan_h, 0.0001),
		desloc.dot(t.basis.y) / maxf(along * tan_v, 0.0001))
	return Vector2((ndc.x + 1.0) * 0.5 * float(tela.get_width()),
		(1.0 - ndc.y) * 0.5 * float(tela.get_height()))

## A mesma janela circular nos dois quadros: a luminância média de cada um, quantos pixels passam do
## corte no trincado e o ganho entre eles. É a prova de que a luz nova nasceu naquele lugar do pão —
## um alarme de console acendendo em outro ponto não entraria na conta.
func _luz_em_torno_de(limpa: Image, trincada: Image, alvo: Vector2, raio: float,
		corte: float) -> Dictionary:
	var acensos := 0
	var amostras := 0
	var soma_antes := 0.0
	var soma_depois := 0.0
	var quadrado := raio * raio
	var cx := int(round(alvo.x))
	var cy := int(round(alvo.y))
	for v in range(cy - int(raio), cy + int(raio) + 1):
		if v < 0 or v >= limpa.get_height():
			continue
		for u in range(cx - int(raio), cx + int(raio) + 1):
			if u < 0 or u >= limpa.get_width():
				continue
			if float((u - cx) * (u - cx) + (v - cy) * (v - cy)) > quadrado:
				continue
			var ca: Color = limpa.get_pixel(u, v)
			var cb: Color = trincada.get_pixel(u, v)
			var la := 0.2126 * ca.r + 0.7152 * ca.g + 0.0722 * ca.b
			var lb := 0.2126 * cb.r + 0.7152 * cb.g + 0.0722 * cb.b
			amostras += 1
			soma_antes += la
			soma_depois += lb
			if lb - la > corte:
				acensos += 1
	var n := maxf(float(amostras), 1.0)
	return {"acensos": acensos, "amostras": amostras, "antes": soma_antes / n,
		"depois": soma_depois / n, "ganho": (soma_depois - soma_antes) / n}

func _tabular(game) -> void:
	for i in range(game.fleet.size()):
		(game.fleet[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 5.0, 0.0, -38.0)
	for i in range(game.enemies.size()):
		(game.enemies[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 6.0, 0.0, -82.0)

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

## Espelho literal de `_montar_disco_de_acrescao`: um `ang` trocado no laço mudaria o disco inteiro
## sem dar erro de parse, e em pintura não há exceção que avise.
func _ponto_disco(faixa: int, i: int) -> Dictionary:
	var t := 0.0
	if POCO_DISCO_FAIXAS > 1:
		t = float(faixa) / float(POCO_DISCO_FAIXAS - 1)
	var raio := POCO_HORIZONTE * lerpf(POCO_DISCO_INTERNO, POCO_DISCO_EXTERNO, t)
	var ang := float(i) * TAU / float(POCO_DISCO_AMOSTRAS) + float(faixa) * 0.11
	var incl := Basis(Vector3.RIGHT, POCO_DISCO_INCLINACAO)
	var feixe := 1.0 + POCO_DOPPLER * cos(ang)
	var cor := Color(1.0, lerpf(0.42, 0.86, 1.0 - t), lerpf(0.16, 0.62, 1.0 - t))
	var tam := 1.5 + 1.9 * t
	return {"tr": Transform3D(incl.scaled(Vector3(tam, tam, tam)),
			POCO_POS + incl * (Vector3(cos(ang), 0.0, sin(ang)) * raio)),
		"cor": Color(cor.r * feixe, cor.g * feixe, cor.b * feixe, 0.72 - 0.16 * t)}

## Espelho de `_montar_arco_de_lente`: aro de fótons primeiro, depois o arco de cima e o de baixo,
## na mesma ordem em que as instâncias foram escritas.
func _ponto_arco(i: int) -> Dictionary:
	var deitado := Basis(Vector3.RIGHT, PI / 2.0)
	if i < POCO_ARCO_AMOSTRAS:
		var ang := float(i) * TAU / float(POCO_ARCO_AMOSTRAS)
		var feixe := 1.0 + POCO_DOPPLER * 0.5 * cos(ang)
		return {"tr": Transform3D(deitado.scaled(Vector3(0.62, 0.62, 0.62)),
				Vector3(cos(ang), sin(ang), 0.0) * POCO_HORIZONTE * POCO_ANEL_FOTON),
			"cor": Color(1.0 * feixe, 0.82 * feixe, 0.55 * feixe, 0.9)}
	var k := (i - POCO_ARCO_AMOSTRAS) % POCO_ARCO_AMOSTRAS
	var lado: int = int(float(i - POCO_ARCO_AMOSTRAS) / float(POCO_ARCO_AMOSTRAS))
	var amplitude := POCO_HORIZONTE * (POCO_ARCO_ALTO if lado == 0 else POCO_ARCO_BAIXO)
	var sinal := 1.0 if lado == 0 else -1.0
	var base := 1.0 if lado == 0 else 0.55
	var u := float(k) * PI / float(POCO_ARCO_AMOSTRAS - 1)
	var altura := sin(u)
	var feixe := 1.0 + POCO_DOPPLER * cos(u - PI / 2.0)
	var tam := 0.7 + 2.2 * altura
	return {"tr": Transform3D(deitado.scaled(Vector3(tam, tam, tam)),
			Vector3(-POCO_ARCO_LARGO * POCO_HORIZONTE * cos(u), sinal * amplitude * altura, 0.0)),
		"cor": Color(base * feixe, base * 0.78 * feixe, base * 0.5 * feixe, 0.2 + 0.6 * altura)}

## Transformada conferida inteira (origem e as três colunas da base), nunca um componente avulso
## contra uma constante: o MultiMesh devolve precisão simples e o espelho é dupla — conferir eixo a
## eixo contra o valor cru é a armadilha do arredondamento. Os nove números juntos, com tolerância.
func _tr_errado(escrito: Transform3D, esperado: Transform3D) -> bool:
	if escrito.origin.distance_to(esperado.origin) > 0.001:
		return true
	return escrito.basis.x.distance_to(esperado.basis.x) > 0.0005 \
		or escrito.basis.y.distance_to(esperado.basis.y) > 0.0005 \
		or escrito.basis.z.distance_to(esperado.basis.z) > 0.0005

func _cor_errada(escrita: Color, esperada: Color) -> bool:
	return absf(escrita.r - esperada.r) > 0.002 or absf(escrita.g - esperada.g) > 0.002 \
		or absf(escrita.b - esperada.b) > 0.002 or absf(escrita.a - esperada.a) > 0.002
