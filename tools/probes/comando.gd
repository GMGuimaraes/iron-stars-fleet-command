extends SceneTree

## Sonda do comando por clique (fatia 1): o que a ponte escreve quando o comandante toca o mapa.
##
## O pedido do jogador foi comando pela mão, não por formulário: "selecionar, dar destino e mudar
## alvo sem tirar o olho do tabuleiro". A resposta tem duas metades, e esta sonda só pode cobrar
## uma delas — a outra mora em `comando_olho.gd`. O que separa as duas é a matriz de câmera:
## `unproject_position` e `Plane.intersects_ray` precisam de um olho com projeção viva, e sob
## `--headless` o `dummy rasterizer` deixa a janela sem quadro. Então aqui entra o que é dado:
## escala declarada, seleção, destino, anel de marco, despacho de ordem, inércia, modo e painel.
##
## 1) A ESCALA É UMA CLÁUSULA, NÃO UMA REESCRITA. `U_PARA_KM = 1` e as derivadas entram declaradas;
##    o que se cobra é a IDENTIDADE nos pontos que o README já jura em `u`: alcance 60 u = 60 km =
##    0,20014 ms-luz, boca 912 m lida da malha (não do cabeçalho), costura da casa 688 m, planeta
##    15 000 km. E o contrafactual que fecha a discussão do parsec: a diagonal do tabuleiro inteiro
##    passa de três milissegundos-luz, e um parsec são 4,3 × 10¹⁰ tabuleiros — segundo-luz e UA são
##    unidades de viagem, não de tiro, e é por isso que `UA_EM_U` e `PARSEC_EM_U` não aparecem em
##    nenhum número tático.
## 2) SELEÇÃO É AQUELE id, NÃO O VIZINHO. O passo da grade é 13 × 7 u e dois andares dividem a mesma
##    coluna; um "clique aproximado" que marcasse o esquadrão inteiro por engano seria a muralha
##    inteira navegando por acidente. `selecionar_bloco` marca UM, `selecionar_esquadrao` marca os
##    vinte do próprio esquadrão, morto não é selecionável, e id hostil devolve vazio — sem erro de
##    chave, que é o que a guarda `is_empty()` nesta sonda pegou na primeira rodada.
## 3) DESTINO É TRANSLAÇÃO, NÃO COLAPSO. É a lei que separa "comando de frota" de "arrastar um
##    sprite": os vinte blocos recebem `ponto + (próprio posto − centro da seleção)`, e as EXTENSÕES
##    da caixa de posições não mudam um dedo. Dois cliques que empilhassem 120 blocos num posto do
##    chão dariam a muralha virando um pixel — contabilidade perfeita, formação destruída.
## 4) A MARCHA CHEGA E PARAR NÃO CUSTA ESCRITA. O destino é perseguido pelo mesmo `move_toward` da
##    formação, e `move_toward` devolve o próprio ponto quando o passo cobre a falta — fechado o
##    último centímetro, a posição é o destino EXATO. A travessia custa UMA escrita dos vinte (a
##    pintura que assenta o buffer depois do pouso) e a pintura do quadro seguinte devolve ZERO:
##    ordem cumprada não pode ser escrita que se repete no `MultiMesh` a cada quadro. Cobrar zero da
##    primeira seria exigir que o bloco aparecesse no quadro sem nunca ter sido desenhado ali. A
##    primeira versão desta família ainda parava a marcha a um décimo de unidade do pouso, que é
##    exatamente o passo de um quadro a `MARCHA_DE_BLOCO = 6`: as asserções de baixo mediam uma frota
##    ainda andando e chamavam aquilo de "parada". O contrafactual mora junto: os cem blocos SEM ordem
##    continuam no próprio posto e a régua não está medindo uma frota congelada — o carimbo de
##    "andou" é a distância percorrida, conferida.
## 5) A ORDEM RELATIVA FECHA O ANEL E NÃO TOCA NO ANDAR. "A 80 km do poço" resolve para o ponto a 80
##    u do marco na direção que o bloco JÁ TEM: fechada a marcha, a distância x/z de cada bloco ao
##    marco é o raio pedido, e o `y` é o que o bloco tinha. Bloco exatamente sobre o marco não tem
##    rumo próprio: o anel dele é o norte do tabuleiro, constante, e o destino tem de ser finito —
##    normalizar um vetor nulo é NaN escrito no `MultiMesh`.
## 6) O DESPACHO MANDA A ORDEM CERTA, E SÓ ELA. `_executar_ordem` é um dicionário puro (a resolução
##    de pixel é que é lei de janela), então cada ramo é conferido de cabeça fria: bloco aliado
##    seleciona, SHIFT seleciona o esquadrão, bloco hostil CONCENTRA FOGO sem mover um centímetro da
##    linha, casco nomeado despeja os blocos e vira a unidade do painel, hostil nomeado vira prioridade,
##    marco dá anel a quem está selecionado e iça o olho a quem não está. Os dois SpinBox são
##    ESPELHO do clique, com o clamp deles; a ordem é que não tem clamp — e é essa diferença que a
##    família cobra, porque um destino amarrado ao slider seria o mapa perdendo metade do alcance.
## 7) NENHUM SORTEIO TOCADO, E O LEDGER DOS DOZE NÃO GANHA LINHA. Todo o gesto acima — seleção,
##    destino, anel, fogo, soltar a linha, TAB, roda — roda sobre um campo que MARCHA, e ainda assim
##    não move `rng` nem `visual_rng`, não escreve `hp` de casco nenhum e devolve o mesmo `resumo()`
##    byte a byte. Inércia medida sobre campo parado não é inércia: por isso a mesma asserção que
##    cobra o esquadrão ordenado percorre dezenas de unidades cobra a muralha hostil fechando o
##    próprio campo de aproximação no mesmo relógio.
## 8) UM OLHO POR VEZ, E A PONTE CONTINUA SENDO A PONTE. O nó novo é filho DO JOGO, e o quadro é do
##    olho declarado: `_build_bridge` faz `make_current()` na própria câmera ANTES de o olho tático
##    entrar na árvore. Sem essa declaração as duas empatariam em prioridade e o empate é decidido
##    pela ordem de entrada — a partida abriria em vista de topo, com a sala fora do quadro, e só uma
##    sonda de cabeça fria pega isso porque em janela o enquadramento errado parece apenas "o mapa".
##    A troca por TAB é UM `make_current()`: o do olho que entra já tira o outro. Em TATICO a roda iça
##    a ALTURA e o `campo_zoom` não se mexe; de volta à PONTE a roda fecha a FOV contratada
##    (78° → 14°) e a altura içada fica onde estava. A roda tem porta e ela é do cursor, não do modo:
##    sobre a moldura do painel ela pertence à lista e nenhum dos dois eixos se move, e SHIFT ou CTRL
##    chamam o olho de volta de qualquer lugar — cobrado nos dois modos, com o ponto injetado lido do
##    `Rect2` do próprio painel porque o canto (0,0) por defeito ficava de fora dele por sorte.
##    A lente tática é fixa por construção: os dois
##    limites de altura mudam o `position`, nunca o `fov`. O arrasto anda CONTRA o cursor na conta exata
##    de `_unidades_por_pixel_tatico()` e nunca anda em `y`, e bate nos quatro cantos da caixa do olho
##    para o comandante nunca perder a esquadra por ter arrastado demais. A dobradiça de seis pixels
##    separa olhar de navegar: soltura depois de varredura não escreve ordem nenhuma — é o ramo do
##    clique que escreve, e ele fica de fora.
## 9) O PREÇO DECLARADO É MEDIDO, NÃO PROMETIDO. Um nó a mais na árvore: o gabarito de filhos é
##    re-medido aqui e nas três sondas que o assinavam, e os 36 comandos do painel conferidos pelo
##    mesmo contador de `menu.gd` — o clique não pediu botão novo, e um botão a mais obrigaria as
##    55 conferências daquela sonda a serem reescritas. O letreiro continua `Label` e passa a
##    anunciar o próprio modo, a contagem de seleção e a de destinos.
## 10) O RECOMEÇAR DEVOLVE O OLHO E A FORMAÇÃO. Modo, altura, foco, zoom, seleção, destino e fogo
##     concentrado voltam ao degrau de abertura na mesma passada: `campo_modo` é estado de câmera, e
##     uma partida nova aberta de cima mostraria a esquadra remontada dentro do enquadramento velho.
##
## Uso: godot --headless --path . --quit-after 6000 -s res://tools/probes/comando.gd

const Esquadra := preload("res://esquadra.gd")

## Espelhos das constantes de `main.gd`: a instância do jogo é não tipada, e mudar o número lá sem
## mudar aqui quebra a asserção de propósito.
const U_PARA_KM := 1.0
const U_PARA_LUZ_MS := 1000.0 / 299_792.458
const CAPITAL_ALCANCE := 60.0
const PONTE_FOV := 78.0
const CAMPO_FOV := 14.0
const TATICO_FOV := 55.0
const TATICO_ALTURA_INICIAL := 110.0
const TATICO_ALTURA_MIN := 24.0
const TATICO_ALTURA_MAX := 320.0
const TATICO_LIMITE_X := 90.0
const TATICO_LIMITE_Z_VANTE := 30.0
const TATICO_LIMITE_Z_FUNDO := -150.0
const ANEL_DE_MARCO := 80.0
const UA_EM_U := 149_597_870.7
const PARSEC_EM_U := 3.0857e13
const POCO_POS := Vector3(0.0, 0.0, -78.0)
const SISTEMA_PLANETA_RAIO := 15.0
const MAP_X := 320.0
const MAP_Z_NEAR := 40.0
const MAP_Z_FAR := -600.0
const BLOCOS_POR_LADO := 120
const BLOCOS_NO_ESQUADRAO := 20
const CASAS := 24
const NAVIOS_NO_BLOCO := 100
const BOTOES_DO_PAINEL := 36
## Os mesmos nove corpos de `menu.gd`: é dentro deles que moram os comandos, e só deles que este
## contador lê.
const NOMES_GRUPOS := ["ATAQUE", "POSTURA", "FORMAÇÕES", "MANOBRA", "ARMAMENTO", "REPAROS",
	"RECONHECIMENTO", "CENÁRIO", "TRILHA"]
## Gabarito de filhos DO JOGO re-medido nesta rodada, nesta montagem (sem cenário): 26 com o olho
## tático, onde `superficies.gd` lia 25 e `graficos.gd` 25. Com o `cenario_root` do cinturão a árvore
## é 27 — e era 26 antes do olho, valor que `geoide.gd` confere. É o preço declarado do nó novo, e a
## asserção existe para nenhuma fatia futura acrescentar um calado.
const FILHOS_DO_JOGO := 26
const FILHOS_COM_CENARIO := 27
const SEMENTE_RNG := 1234567890
const SEMENTE_VISUAL := 555
## Folgas: a marcha fecha em `move_toward` e o anel é conta de raiz quadrada em float32.
const FOLGA := 0.1
const FOLGA_ANEL := 0.05
## O passo de um quadro é `MARCHA_DE_BLOCO * 1 / 60 = 0,1` u no teto de motores — o mesmo número de
## `FOLGA`, e é por isso que parar a marcha "a um décimo" nunca foi parar: era faltar um quadro. O
## pouso se mede por três ordens abaixo do passo.
const POUSO_EXATO := 0.0001
const TETO_DE_QUADROS := 3000

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

## As duas linhas da largada, na cota de y zero: o que se mede aqui é grade e ordem, não a deriva de
## altura que o `visual_rng` dá aos núcleos reais.
func _nucleos(aliada: bool) -> Array:
	var posicoes: Array = []
	for i in range(6):
		if aliada:
			posicoes.append(Vector3((float(i) - 2.5) * 5.0, 0.0, -38.0 - float(i % 2) * 5.0))
		else:
			posicoes.append(Vector3((float(i) - 2.5) * 6.0, 0.0, -82.0 - float(i % 2) * 7.0))
	return posicoes

func _nova_esquadra() -> Esquadra:
	var e := Esquadra.new()
	e.montar(_nucleos(true), _nucleos(false))
	return e

func _novo_mm(e: Esquadra) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = e.malha_replica()
	mm.instance_count = Esquadra.INSTANCIAS_POR_LADO
	return mm

func _pos(bloco: Dictionary) -> Vector3:
	return bloco["pos"] as Vector3

func _dest(bloco: Dictionary) -> Vector3:
	return bloco["destino"] as Vector3

## Caixa de posições: as EXTENSÕES são a régua anti-colapso. Translação preserva as três; dois
## destinos iguais para vinte blocos encolheria tudo a zero.
func _extensos(posicoes: Array) -> Vector3:
	var minimo := Vector3(1e9, 1e9, 1e9)
	var maximo := Vector3(-1e9, -1e9, -1e9)
	for p in posicoes:
		minimo = minimo.min(p as Vector3)
		maximo = maximo.max(p as Vector3)
	return maximo - minimo

## Carimbo de posições com duas casas decimais: serve para "este ramo não moveu a linha".
func _selo(e: Esquadra, lado: String) -> String:
	var partes: PackedStringArray = []
	for b in e.lista_de(lado):
		var p := _pos(b)
		partes.append("%.2f,%.2f,%.2f" % [p.x, p.y, p.z])
	return "|".join(partes)

func _marcar_esquadrao(e: Esquadra, esq: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in e.lista_de("aliado"):
		if int(b["esquadrao"]) == esq:
			out.append(b)
	return out

## Marcha pela esquadra nua até todo bloco selecionado estar EM CIMA do próprio destino, e não
## "perto dele": `move_toward` devolve o ponto exato quando o passo cobre a falta, então o pouso é
## uma igualdade e a régua que para a um décimo de unidade está parando no meio do último passo.
## Devolve os quadros gastos, que é a prova de que houve travessia e não partida colada.
func _marchar_ate_destinos(e: Esquadra, nuc_a: Array, nuc_h: Array,
  sem_respirar := false) -> int:
	var q := 0
	var longe := true
	while longe and q < TETO_DE_QUADROS:
		if sem_respirar:
			_quadro_sem_respirar(e, nuc_a, nuc_h)
		else:
			e.passo(1.0 / 60.0, nuc_a, nuc_h)
		longe = false
		for b in e.selecionados():
			if _pos(b).distance_to(_dest(b)) > POUSO_EXATO:
				longe = true
		q += 1
	return q

## Precondition da fatia 3.5, declarada no passo e não afrouxada na régua: esta sonda mede SEMÂNTICA
## de ordem — a quantos blocos a pintura atribui a ordem, e quão perto do posto o bloco volta sem
## ela. Com a muralha respirando, todo bloco vivo está sujo em todo quadro, "vinte e não cento e
## vinte" passa a ler 120 e "parado não custa escrita" passa a ler 120: a asserção reprovaria o
## desenho, não a lei. Congelar a fase cravando `tempo` antes do passo transforma a sinusóide num
## offset constante — o bloco pousa nele e para de se mexer — e os números cobrados voltam a ser os
## de antes da fatia. A respiração em si é assinada pela família 13 de `tools/probes/esquadra.gd`.
func _quadro_sem_respirar(e: Esquadra, nuc_a: Array, nuc_h: Array) -> void:
	e.tempo = 0.0
	e.passo(1.0 / 60.0, nuc_a, nuc_h)

## A deriva congelada pelo `_quadro_sem_respirar`: os mesmos quatro números que `passo()` usa, refeitos
## das constantes publicadas com o relógio na fase cravada acima. Espelho, não API nova — é contra
## esse posto que a lei do retorno cobra, porque é esse posto que a grade manda guardar.
func _posto_respirado(e: Esquadra, b: Dictionary) -> Vector3:
	var esq := int(b["esquadrao"])
	var base := e.tempo * TAU / Esquadra.DERIVA_CICLO
	var andar := int(float(esq) / float(Esquadra.COLUNAS_NO_LADO))
	var fase_x := base + float(andar) * TAU / float(Esquadra.CAMADAS_NO_LADO)
	var fase_y := base + float(esq) * TAU / float(Esquadra.ESQUADROES_NO_LADO)
	var deriva := Vector3(cos(fase_x) * Esquadra.DERIVA_X, sin(fase_y * 0.5) * Esquadra.DERIVA_Y, 0.0)
	return Esquadra.posto_no_lado(esq, int(b["formacao"]), e.estacao("aliado")) + deriva

## A maior distância percorrida por um bloco sob ordem: é o "andou" que a lei de inércia exige, e o
## "chegou" que a translação cobra contra o posto de formação.
func _maior_deslocamento(antes: Array, depois: Array) -> float:
	var maior := 0.0
	for i in range(depois.size()):
		maior = maxf(maior, (antes[i] as Vector3).distance_to(depois[i] as Vector3))
	return maior


func _initialize() -> void:
	print("SONDA-COMANDO: comecando")
	var nuc_a := _nucleos(true)
	var nuc_h := _nucleos(false)

	# ── 1. a escala e uma clausula, nao uma reescrita ───────────────────────────────────────
	var jogo := await _montar_jogo()
	var leitura_60 := String(jogo._ler_escala(CAPITAL_ALCANCE))
	_assert("um u vale um km: sessenta unidades de alcance viram sessenta quilometros",
		U_PARA_KM == 1.0 and leitura_60.contains("60.0 u") and leitura_60.contains("60.0 km") \
			and leitura_60.contains("0.20014 ms-luz"),
		"%s" % leitura_60)
	var luz_por_u: float = jogo.U_PARA_LUZ_MS
	_assert("a derivada nao e um numero de cabeca: mil metros sobre a velocidade da luz",
		absf(float(luz_por_u) - 1000.0 / 299_792.458) < 1e-9,
		"%.7f ms-luz por u, conferido contra 1000/299792.458" % float(luz_por_u))
	var aabb_replica: AABB = (jogo.massa_aliada.multimesh.mesh as ArrayMesh).get_aabb()
	var boca := aabb_replica.size.x * Esquadra.ESCALA_REPLICA
	_assert("a boca de novecientos e doze metros sai da malha, nao do cabecalho",
		absf(boca * U_PARA_KM * 1000.0 - 912.0) < 5.0,
		"caixa crua %.3f x %.2f x %.1f, escala %.2f: boca %.4f u = %.1f m" % [
			aabb_replica.size.x, aabb_replica.size.y, aabb_replica.size.z,
			Esquadra.ESCALA_REPLICA, boca, boca * 1000.0])
	var costura := Esquadra.PASSO_CASA_Y - boca
	_assert("a folga da casa de um metro e sessenta e seisocentos e oitenta milimetros",
		absf(costura * U_PARA_KM * 1000.0 - 688.0) < 5.0,
		"casa de %.1f u menos a boca de %.4f u = %.1f m de costura" % [
			Esquadra.PASSO_CASA_Y, boca, costura * 1000.0])
	_assert("o planeta do sistema e quinze mil kilometros de raio",
		String(jogo._ler_escala(SISTEMA_PLANETA_RAIO)).contains("15.0 km"),
		"%s" % jogo._ler_escala(SISTEMA_PLANETA_RAIO))
	var diagonal := Vector2(MAP_X, MAP_Z_NEAR - MAP_Z_FAR).length()
	_assert("o tabuleiro inteiro nao passa de tres milissegundos-luz: parsec e unidade de viagem",
		diagonal * U_PARA_LUZ_MS < 3.0 and PARSEC_EM_U / diagonal > 1.0e10 \
			and UA_EM_U / diagonal > 1.0e5,
		"%.1f u de diagonal = %.2f ms-luz; um parsec vale %.0f tabuleiros e uma UA %.0f" % [
			diagonal, diagonal * U_PARA_LUZ_MS, PARSEC_EM_U / diagonal, UA_EM_U / diagonal])

	# ── 2. selecao e aquele id, nao o vizinho ───────────────────────────────────────────────
	var e := _nova_esquadra()
	var esq0 := _marcar_esquadrao(e, 0)
	var id_alvo := int(esq0[7]["id"])
	var vizinhos: Array[int] = [int(esq0[6]["id"]), int(esq0[8]["id"])]
	var bloco := e.selecionar_bloco(id_alvo)
	_assert("tocar um bloco marca UM: nem o de boreste a treze unidades, nem o de bombordo",
		not bloco.is_empty() and e.contar_selecionados() == 1 \
			and int(e.selecionados()[0]["id"]) == id_alvo \
			and not bool(e.bloco_por_id(vizinhos[0])["selecionado"]) \
			and not bool(e.bloco_por_id(vizinhos[1])["selecionado"]),
		"id %d marcado, vizinhos %d e %d de fora, selecao = %d" % [id_alvo, vizinhos[0],
			vizinhos[1], e.contar_selecionados()])
	e.selecionar_bloco(int(esq0[12]["id"]))
	_assert("a seleção e una: o segundo toque despeja o primeiro",
		e.contar_selecionados() == 1 and int(e.selecionados()[0]["id"]) == int(esq0[12]["id"]),
		"id %d no lugar do %d" % [int(esq0[12]["id"]), id_alvo])
	e.limpar_selecao()
	_assert("limpar a selecao nao apaga bloco nenhum", e.contar_selecionados() == 0 \
		and e.vivos("aliado") == BLOCOS_POR_LADO,
		"%d marcados, %d vivos" % [e.contar_selecionados(), e.vivos("aliado")])
	var morto := int(esq0[3]["id"])
	e.bloco_por_id(morto)["vivo"] = false
	_assert("cadaver nao e candidato: o toque devolve vazio em vez de uma ordem sem dono",
		e.selecionar_bloco(morto).is_empty() and e.contar_selecionados() == 0,
		"id %d afundado, retorno vazio, selecao %d" % [morto, e.contar_selecionados()])
	var id_hostil := int(e.lista_de("hostil")[0]["id"])
	_assert("id hostil nao existe na lista aliada: recusa limpa, sem erro de chave",
		e.selecionar_bloco(id_hostil).is_empty() and e.selecionar_esquadrao(id_hostil) == 0,
		"hostil %d devolve vazio e zero marcados" % id_hostil)

	# ── 3. esquadrão inteiro pelo modificador ───────────────────────────────────────────────
	var e2 := _nova_esquadra()
	var alvo_esq := int(_marcar_esquadrao(e2, 4)[9]["id"])
	var marcados := e2.selecionar_esquadrao(alvo_esq)
	var so_do_esquadr := true
	for b in e2.selecionados():
		if int(b["esquadrao"]) != 4:
			so_do_esquadr = false
	_assert("SHIFT pega os vinte do proprio esquadrão, nao os cento e vinte",
		marcados == BLOCOS_NO_ESQUADRAO and e2.contar_selecionados() == BLOCOS_NO_ESQUADRAO \
			and so_do_esquadr,
		"%d marcados a partir do id %d, todos do esquadrão %d" % [marcados, alvo_esq, 4])
	e2.bloco_por_id(int(_marcar_esquadrao(e2, 4)[0]["id"]))["vivo"] = false
	e2.bloco_por_id(int(_marcar_esquadrao(e2, 4)[1]["id"]))["vivo"] = false
	_assert("esquadrão com afundados marca os vivos, e só eles",
		e2.selecionar_esquadrao(alvo_esq) == BLOCOS_NO_ESQUADRAO - 2,
		"%d marcados depois de dois afundados" % e2.contar_selecionados())

	# ── 4. destino e translacao, nao colapso; e parado nao custa escrita ─────────────────────
	var e3 := _nova_esquadra()
	e3.selecionar_esquadrao(0)
	var mm3 := _novo_mm(e3)
	var largada := e3.pintar(mm3, "aliado", true)
	var antes: Array = []
	for b in e3.selecionados():
		antes.append(_pos(b))
	var caixa_antes := _extensos(antes)
	var centro := Vector3.ZERO
	for p in antes:
		centro += p as Vector3
	centro /= float(antes.size())
	var ponto := e3.centros("aliado") + Vector3(40.0, 0.0, 30.0)
	var escritos := e3.mandar_destino(ponto)
	var depois_dest: Array = []
	var erro_translacao := 0.0
	for b in e3.selecionados():
		depois_dest.append(_dest(b))
		var esperado := ponto + (( _pos(b)) - centro)
		erro_translacao = maxf(erro_translacao, _dest(b).distance_to(esperado))
	var caixa_dest := _extensos(depois_dest)
	_assert("os vinte blocos recebem o ponto SOMADO ao proprio posto: a ordem e de translacao",
		escritos == BLOCOS_NO_ESQUADRAO and erro_translacao < 1e-3,
		"%d destinos escritos, maior erro de translacao %.6f u" % [escritos, erro_translacao])
	_assert("a formacao nao colapsa: a caixa dos vinte mantem as tres extensoes",
		caixa_dest.distance_to(caixa_antes) < 1e-3,
		"caixa %.2f x %.2f x %.2f antes e depois da ordem" % [caixa_antes.x, caixa_antes.y,
			caixa_antes.z])
	_assert("sob destino, o estado da ordem e conferivel: vinte blocos navegando por conta",
		e3.com_destino() == BLOCOS_NO_ESQUADRAO, "%d sob destino" % e3.com_destino())
	var andado_100 := 0.0
	for i in range(100):
		_quadro_sem_respirar(e3, nuc_a, nuc_h)
	# No meio da marcha a régua tem de cobrar os VINTE que andam — e não os cento e vinte: os cem
	# blocos sem ordem estão colados no próprio posto, e uma pintura que os repintasse a cada quadro
	# desmentiria a lei de cima com um número bonito.
	# O assentamento da fase congelada: cravar `tempo` não zera a deriva, ela vira um offset fixo de
	# até 0,6 u em boreste, e os cem blocos sem ordem andam esse offset nos primeiros quadros. Essa
	# pintura paga o deslocamento uma vez — por isso é conferido, não jogado fora — e a medida de
	# embaixo é o QUADRO SEGUINTE, quando a muralha já está colada no posto respirado por tabela e só
	# os vinte sob ordem ainda têm o que escrever.
	var assentamento := e3.pintar(mm3, "aliado", false)
	_quadro_sem_respirar(e3, nuc_a, nuc_h)
	var durante := e3.pintar(mm3, "aliado", false)
	for b in e3.selecionados():
		andado_100 = maxf(andado_100, _pos(b).distance_to(_dest(b)))
	var quadros := _marchar_ate_destinos(e3, nuc_a, nuc_h, true)
	var chegada: Array = []
	var pior := 0.0
	for b in e3.selecionados():
		chegada.append(_pos(b))
		pior = maxf(pior, _pos(b).distance_to(_dest(b)))
	var andado := _maior_deslocamento(antes, chegada)
	_assert("a marcha pousa em cima do destino, não a um passo dele",
		quadros < TETO_DE_QUADROS and pior <= POUSO_EXATO,
		"%d quadros, maior resto %.6f u, maior deslocamento %.1f u" % [quadros, pior, andado])
	# O contrafactual: o destino nao e o posto de formacao. Se a ordem mandasse o bloco para onde ele
	# ja estava, "chegou" e "andou" seriam a mesma asserção vazia.
	var posto := Esquadra.posto_no_lado(0, int(e3.selecionados()[0]["formacao"]),
		e3.estacao("aliado"))
	var longe_do_posto := _pos(e3.selecionados()[0]).distance_to(posto)
	_assert("o destino nao era o proprio posto: a muralha andou por ordem, nao por inercia",
		longe_do_posto > 20.0, "bloco a %.1f u do posto de formacao, %.1f u percorridos" % [
			longe_do_posto, andado])
	# Três quadros para fechar o último centímetro e UMA pintura para assentar o buffer: essa é a
	# última escrita da travessia e custa os vinte. A lei "parado não custa escrita" é a pintura
	# SEGUINTE, um quadro depois de nada ter andado — medir a primeira seria cobrar de uma frota que
	# ainda está sendo desenhada onde o olho nunca a viu.
	_quadro_sem_respirar(e3, nuc_a, nuc_h)
	_quadro_sem_respirar(e3, nuc_a, nuc_h)
	_quadro_sem_respirar(e3, nuc_a, nuc_h)
	var assentada := e3.pintar(mm3, "aliado", false)
	_quadro_sem_respirar(e3, nuc_a, nuc_h)
	var parado := e3.pintar(mm3, "aliado", false)
	_assert("a passada forcada da largada pinta os cento e vinte blocos do lado",
		largada == BLOCOS_POR_LADO, "%d tocados quando tudo e sujo de proposito" % largada)
	_assert("a fase congelada assenta a muralha uma única vez: os cento e vinte pagam o offset",
		assentamento == BLOCOS_POR_LADO,
			"%d tocados no primeiro quadro depois de cravar o relógio, quando os cem sem ordem andam " % [
				assentamento] \
				+ "o offset fixo da deriva e os vinte ainda estão em marcha")
	_assert("em marcha, a ordem custa exatamente os vinte que andam, nao os cento e vinte",
		durante == BLOCOS_NO_ESQUADRAO, "%d tocados com %d u ainda por percorrer" % [
			durante, andado_100])
	_assert("cumprida a ordem, parado nao custa escrita no MultiMesh",
		assentada == BLOCOS_NO_ESQUADRAO and parado == 0,
		"%d tocados na última escrita da travessia e %d na pintura do quadro seguinte" % [
			assentada, parado])
	var soltos := e3.soltar_destinos()
	_assert("soltar a linha limpa o estado da ordem em todos os vinte, de uma vez",
		soltos == BLOCOS_NO_ESQUADRAO and e3.com_destino() == 0,
		"%d liberados, %d sob destino" % [soltos, e3.com_destino()])
	var q2 := 0
	var longe := true
	while longe and q2 < TETO_DE_QUADROS:
		_quadro_sem_respirar(e3, nuc_a, nuc_h)
		longe = false
		for b in e3.lista_de("aliado"):
			if _pos(b).distance_to(_posto_respirado(e3, b)) > FOLGA:
				longe = true
		q2 += 1
	var volta_pior := 0.0
	var volta_pior_nua := 0.0
	for b in e3.lista_de("aliado"):
		var posto_livre := Esquadra.posto_no_lado(int(b["esquadrao"]), int(b["formacao"]),
			e3.estacao("aliado"))
		volta_pior = maxf(volta_pior, _pos(b).distance_to(_posto_respirado(e3, b)))
		volta_pior_nua = maxf(volta_pior_nua, _pos(b).distance_to(posto_livre))
	# O contrafactual da referência: se o posto respirado fosse a mesma coisa que o posto nu, esta
	# linha não teria o que contar. Ele conta — o resto nu é a própria deriva cravada, e a tolerância
	# FOLGA continua a mesma de antes da fatia: mudou o alvo da régua, não a folga.
	_assert("a grade recaptura quem estava sob ordem, e o posto que ela guarda é o respirado",
		q2 < TETO_DE_QUADROS and volta_pior < FOLGA,
			"maior resto de posto %.4f u em %d quadros de volta; contra o posto nu o mesmo resto e " % [
				volta_pior, q2] \
				+ "%.4f u, que é a deriva congelada, e a folga cobrada segue %.2f u" % [
					volta_pior_nua, FOLGA])

	# ── 5. a ordem relativa fecha o anel e nao toca no andar ────────────────────────────────
	var e4 := _nova_esquadra()
	e4.selecionar_esquadrao(2)
	var y_antes: Array = []
	for b in e4.selecionados():
		y_antes.append(_pos(b).y)
	var anel := e4.mandar_orbita(POCO_POS, ANEL_DE_MARCO)
	var nan_escrito := 0
	for b in e4.selecionados():
		if not _dest(b).is_finite():
			nan_escrito += 1
	_assert("anel de oitenta unidades escrito para os vinte, sem NaN",
		anel == BLOCOS_NO_ESQUADRAO and nan_escrito == 0,
		"%d destinos de anel, %d nao finitos" % [anel, nan_escrito])
	var q4 := _marchar_ate_destinos(e4, nuc_a, nuc_h)
	var raio_pior := 0.0
	var andar_pior := 0.0
	var i4 := 0
	for b in e4.selecionados():
		var radial := Vector2(_pos(b).x - POCO_POS.x, _pos(b).z - POCO_POS.z).length()
		raio_pior = maxf(raio_pior, absf(radial - ANEL_DE_MARCO))
		andar_pior = maxf(andar_pior, absf(_pos(b).y - float(y_antes[i4])))
		i4 += 1
	_assert("fechada a marcha, cada bloco esta a exatamente oitenta unidades do marco",
		q4 < TETO_DE_QUADROS and raio_pior < FOLGA_ANEL,
			"%d quadros, maior desvio de raio %.5f u" % [q4, raio_pior])
	_assert("a ordem relativa nao decide andar: o y de cada bloco e o que ele ja tinha",
		andar_pior < FOLGA, "maior desvio de altura %.5f u" % andar_pior)
	# Degenerado honesto: um bloco plantado em cima do marco nao tem rumo proprio. Aqui nasce o NaN
	# de `normalized()` sobre vetor nulo, e a lei e a constante do norte do tabuleiro.
	var e5 := _nova_esquadra()
	e5.selecionar_esquadrao(0)
	var em_cima := e5.selecionados()[0]
	em_cima["pos"] = POCO_POS + Vector3(0.0, 6.0, 0.0)
	var degenerado := e5.mandar_orbita(POCO_POS, ANEL_DE_MARCO)
	var d_cima := _dest(em_cima)
	_assert("bloco sobre o marco assume o norte do tabuleiro: rumo constante, jamais sorteado",
		degenerado == BLOCOS_NO_ESQUADRAO and d_cima.is_finite() \
			and absf(d_cima.x - POCO_POS.x) < 1e-4 and absf(d_cima.y - (POCO_POS.y + 6.0)) < 1e-4 \
			and absf(d_cima.z - (POCO_POS.z - ANEL_DE_MARCO)) < 1e-4,
		"destino %s (marco + norte de %.0f u, altura preservada)" % [str(d_cima), ANEL_DE_MARCO])
	_assert("raio zero nao e ordem: nada e escrito, nada anda",
		e5.mandar_orbita(POCO_POS, 0.0) == 0 and e5.mandar_destino(POCO_POS) == BLOCOS_NO_ESQUADRAO \
			and e5.soltar_destinos() == BLOCOS_NO_ESQUADRAO,
		"anel de raio zero devolve 0 e o resto continua conferindo")

	# ── 6. o despacho manda a ordem certa, e so ela ─────────────────────────────────────────
	var g := await _montar_jogo()
	g.esquadra.selecionar_bloco(5)
	g._executar_ordem({"tipo": "BLOCO", "lado": "aliado", "id": 5, "esquadrao": 0}, false)
	_assert("ramo bloco aliado: selecao de um, letreiro do painel dizendo qual",
		g.esquadra.contar_selecionados() == 1 \
			and int(g.esquadra.selecionados()[0]["id"]) == 5 \
			and String(g.report_label.text).contains("BLOCO 5"),
		"%s" % g.report_label.text)
	g._executar_ordem({"tipo": "BLOCO", "lado": "aliado", "id": 5, "esquadrao": 0}, true)
	_assert("ramo SHIFT: o esquadrão inteiro em seleção e o letreiro anunciando os vinte",
		g.esquadra.contar_selecionados() == BLOCOS_NO_ESQUADRAO \
			and String(g.report_label.text).contains("ESQUADRÃO"),
		"%s" % g.report_label.text)
	var selo_linha := _selo(g.esquadra, "aliado")
	g._executar_ordem({"tipo": "BLOCO", "lado": "hostil", "id": 137, "esquadrao": 0,
		"pos": Vector3(65.0, 6.0, -90.0)}, false)
	_assert("ramo bloco hostil: fogo concentrado no ponto tocado, sem mover a linha",
		bool(g.esquadra.fogo_concentrado) \
			and (g.esquadra.alvo_comandado as Vector3) == Vector3(65.0, 6.0, -90.0) \
			and _selo(g.esquadra, "aliado") == selo_linha \
			and String(g.report_label.text).contains("FOGO CONCENTRADO"),
		"alvo %s, %d blocos aliados sob destino depois do toque hostil" % [
			str(g.esquadra.alvo_comandado), g.esquadra.com_destino()])
	g.esquadra.soltar_fogo()
	g._executar_ordem({"tipo": "CASCO", "indice": 2, "nome": "Cross",
		"pos": Vector3.ZERO}, false)
	_assert("ramo casco nomeado: despeja os blocos e passa a ser a unidade do painel",
		String(g.selection_scope) == "NAVE 3" and g.esquadra.contar_selecionados() == 0 \
			and String(g.report_label.text).contains("SELEÇÃO"),
		"escopo %s, selecao da massa %d" % [g.selection_scope, g.esquadra.contar_selecionados()])
	g._executar_ordem({"tipo": "HOSTIL", "indice": 4, "nome": "Vanguard",
		"pos": Vector3.ZERO}, false)
	_assert("ramo hostil nomeado: prioridade da linha pelo mesmo girar do seletor",
		int(g.selected_target) == 4 and String(g.report_label.text).contains("ALVO"),
		"alvo %d, %s" % [g.selected_target, g.report_label.text])
	g.esquadra.selecionar_esquadrao(1)
	g._executar_ordem({"tipo": "MARCO", "nome": "POÇO", "pos": POCO_POS}, false)
	_assert("ramo marco com seleção: vinte blocos assumindo o anel pedido",
		g.esquadra.com_destino() == BLOCOS_NO_ESQUADRAO \
			and String(g.report_label.text).contains("anel") \
			and String(g.report_label.text).contains("80.0 km"),
		"%d sob destino; %s" % [g.esquadra.com_destino(), g.report_label.text])
	g.esquadra.soltar_destinos()
	g.esquadra.limpar_selecao()
	g.tatico_foco = Vector3(0.0, 0.0, -63.0)
	g._executar_ordem({"tipo": "MARCO", "nome": "ESTRELA",
		"pos": Vector3(0.0, 24.0, -74.0)}, false)
	_assert("ramo marco sem seleção: o olho é içado sobre o marco, nenhuma ordem escrita",
		g.esquadra.com_destino() == 0 and absf(g.tatico_foco.x - 0.0) < 1e-6 \
			and absf(g.tatico_foco.z + 74.0) < 1e-6 and String(g.report_label.text).contains("içado"),
		"foco %s, %d sob destino" % [str(g.tatico_foco), g.esquadra.com_destino()])
	var ponto_fora := Vector3(200.0, 0.0, -300.0)
	g.esquadra.selecionar_esquadrao(3)
	g._navegar_no_ponto(ponto_fora)
	var espelho_ok := absf(float(g.position_x_input.value) - 80.0) < 1e-4 \
		and absf(float(g.position_z_input.value) + 160.0) < 1e-4
	# A régua da ordem sem clamp é o BARICENTRO dos vinte destinos, não o máximo: a translação escreve
	# em cada bloco `ponto + (posto − centro)`, então dezoito dos vinte ficam a boreste ou a vante do
	# ponto pedido, e uma cláusula "todo destino tem de passar de 199 u" reprovaria a lei que quer
	# provar. O baricentro É o ponto pedido — se a ordem heredasse o clamp do painel ele viria (80,
	# −160), e aí a asserção quebra.
	var baricentro := Vector3.ZERO
	for b in g.esquadra.selecionados():
		baricentro += _dest(b)
	baricentro /= float(maxi(1, g.esquadra.contar_selecionados()))
	_assert("os SpinBox são espelho do clique com o clamp deles; a ordem é que não tem clamp",
		espelho_ok and baricentro.distance_to(ponto_fora) < 1e-3 \
			and g.esquadra.com_destino() == BLOCOS_NO_ESQUADRAO,
		"painel (%.0f, %.0f) clampado, baricentro dos destinos (%.1f, %.1f)" % [
			float(g.position_x_input.value), float(g.position_z_input.value), baricentro.x,
			baricentro.z])
	g.esquadra.soltar_destinos()
	g.esquadra.limpar_selecao()
	g.selection_scope = "FROTA"
	g._navegar_no_ponto(Vector3(10.0, 0.0, -70.0))
	_assert("clique em água vazia sem bloco na seleção é ordem dos cascos pelo caminho de sempre",
		String(g.report_label.text).contains("NAVEGAÇÃO TÁTICA") \
			and absf(float(g.move_x) - 10.0) < 1e-4 and absf(float(g.move_z) + 70.0) < 1e-4,
		"%s (move %.0f, %.0f)" % [g.report_label.text, g.move_x, g.move_z])

	# ── 7. nenhum sorteio tocado e o ledger dos doze nao ganha linha ─────────────────────────
	var j := await _montar_jogo()
	j.rng.seed = SEMENTE_RNG
	j.visual_rng.seed = SEMENTE_VISUAL
	var rng_antes := int(j.rng.state)
	var visual_antes := int(j.visual_rng.state)
	var cauda_semente: Array[int] = []
	for i in range(40):
		cauda_semente.append(j.rng.randi())
	j.rng.seed = SEMENTE_RNG
	j.visual_rng.seed = SEMENTE_VISUAL
	var hps_antes: Array[int] = []
	for lista in [j.fleet, j.enemies]:
		for unit in lista:
			hps_antes.append(int(roundf(float(unit["hp"]) * 1000.0)))
	var resumo_antes := String(j.esquadra.resumo())
	var hostil_antes: Array = []
	for b in j.esquadra.lista_de("hostil"):
		hostil_antes.append(_pos(b))
	# O campo tem de estar MARCHANDO enquanto o comando roda: inércia medida sobre esquadra parada é
	# contabilidade de nada (a mesma armadilha que a família 7 de `esquadra.gd` cobra, agora para o
	# caminho do clique). Aqui a prova de movimento é dupla: o esquadrão ordenado percorre dezenas de
	# unidades e a muralha hostil fecha o próprio campo de aproximação.
	j.esquadra.selecionar_esquadrao(2)
	var pos_largada: Array = []
	for b in j.esquadra.selecionados():
		pos_largada.append(_pos(b))
	j._executar_ordem({"tipo": "MARCO", "nome": "POÇO", "pos": POCO_POS}, false)
	var q := 0
	while q < 400:
		j._atualizar_esquadras(1.0 / 60.0)
		q += 1
	j._executar_ordem({"tipo": "BLOCO", "lado": "hostil", "id": 120, "esquadrao": 0,
		"pos": Vector3(0.0, 0.0, -90.0)}, false)
	j._executar_ordem({"tipo": "BLOCO", "lado": "aliado", "id": 40, "esquadrao": 2}, true)
	j._navegar_no_ponto(Vector3(30.0, 0.0, -20.0))
	j.esquadra.soltar_destinos()
	j._trocar_modo_camera()
	var roda := InputEventMouseButton.new()
	roda.button_index = MOUSE_BUTTON_WHEEL_UP
	roda.pressed = true
	# A roda agora tem geografia: sem modificador ela só manda no olho fora da moldura do painel.
	# Injetar o gesto no canto (0,0) por defeito faria esta família passar por acidente, então o
	# ponto vem lido do retângulo real do nó, do lado de fora dele.
	var caixa_painel: Rect2 = j.painel.get_global_rect()
	roda.global_position = Vector2(caixa_painel.end.x + 180.0, caixa_painel.position.y + 30.0)
	for i in range(10):
		j._input(roda)
	j._trocar_modo_camera()
	var pos_chegada: Array = []
	for b in j.esquadra.lista_de("aliado"):
		if int(b["esquadrao"]) == 2:
			pos_chegada.append(_pos(b))
	var andou := _maior_deslocamento(pos_largada, pos_chegada)
	var rng_pos_comando := int(j.rng.state)
	var cauda_depois: Array[int] = []
	for i in range(40):
		cauda_depois.append(j.rng.randi())
	var cauda_igual := rng_pos_comando == rng_antes
	for i in range(40):
		if cauda_semente[i] != cauda_depois[i]:
			cauda_igual = false
	# O estado comparado é o lido ANTES da cauda: os quarenta `randi()` da régua de stream avançam o
	# gerador por conta própria, e reler `j.rng.state` depois deles mede a sonda, não o comando. Na
	# primeira rodada esta asserção quebrou por isso, com o comando inocente.
	_assert("o comando inteiro nao move o gerador de combate", rng_pos_comando == rng_antes,
		"%d -> %d" % [rng_antes, rng_pos_comando])
	_assert("o comando inteiro nao move o gerador visual",
		int(j.visual_rng.state) == visual_antes, "%d -> %d" % [visual_antes,
			int(j.visual_rng.state)])
	_assert("a cauda de quarenta sorteios sobrevive ao clique", cauda_igual,
		"estado %d antes e %d depois de %d quadros mais anel, fogo, destino e dois TAB; cauda abre em %d nos dois lados" % [
			rng_antes, rng_pos_comando, q, cauda_semente[0]])
	var hps_depois: Array[int] = []
	for lista in [j.fleet, j.enemies]:
		for unit in lista:
			hps_depois.append(int(roundf(float(unit["hp"]) * 1000.0)))
	_assert("o clique nao escreve o hp de casco nenhum: o ledger dos doze nao ganha linha",
		hps_antes == hps_depois, "%d cascos conferidos, %d divergentes" % [hps_antes.size(),
			0 if hps_antes == hps_depois else hps_antes.size()])
	_assert("o resumo da massa e o mesmo byte a byte: selecao e destino nao afundam bloco",
		resumo_antes == String(j.esquadra.resumo()), "%s -> %s" % [resumo_antes,
			j.esquadra.resumo()])
	# A régua que diz que as quatro de cima mediram alguma coisa: sem marcha, a inércia seria aprovada
	# sobre uma batalha que não aconteceu. `navios` não serve de régua aqui — nenhuma salva roda nesta
	# família, então os vinte mil cascos ficam inteiros por construção e a asserção não poderia falhar.
	# A marcha é dupla: o esquadrão ordenado percorre dezenas de unidades e a muralha hostil fecha o
	# próprio campo de aproximação no mesmo relógio.
	var pos_hostil_depois: Array = []
	for b in j.esquadra.lista_de("hostil"):
		pos_hostil_depois.append(_pos(b))
	var fechou := _maior_deslocamento(hostil_antes, pos_hostil_depois)
	_assert("%d quadros de marcha de fato mexeram o campo: %.1f u do esquadrão ordenado, %.1f u da muralha" % [
		q, andou, fechou], andou > 20.0 and fechou > 10.0,
		"esquadrão 2 andou %.1f u e a muralha hostil fechou %.1f u" % [andou, fechou])

	# ── 8. um olho por vez, e a ponte continua sendo a ponte ─────────────────────────────────
	var o := await _montar_jogo()
	# O Godot 4 não tem `Camera3D.enabled`: quem manda no quadro é o viewport, e ele só tem UMA câmera
	# corrente, escolhida por prioridade — e o empate de prioridade é decidido pela ORDEM DE ENTRADA.
	# Como o olho tático entra depois da ponte, sem a declaração explícita de `make_current()` na
	# montagem da ponte a partida abria em vista de topo. Foi escrever `enabled` em `main.gd` o que
	# derrubou o `_ready` inteiro na primeira rodada desta sonda — o erro de runtime não aborta a
	# asserção, aborta a montagem, e sem sonda rodando nada disso chega a ser visto.
	var mao: Node = o.tatico_camera.get_parent()
	var dono_do_quadro: Node = o.get_viewport().get_camera_3d()
	# Lido antes da asserção: o detalhe é avaliado sempre, e `nome` sobre uma câmera nula abortaria a
	# sonda justamente no caso que ela existe para pegar.
	var nome_do_quadro := String(dono_do_quadro.name) if is_instance_valid(dono_do_quadro) else "NENHUMA"
	_assert("o olho tático e filho DO JOGO, nao esta no quadro e a ponte continua corrente na abertura",
		mao == o and not bool(o.tatico_camera.is_current()) and bool(o.ponte_camera.is_current()) \
			and String(o.tatico_camera.name) == "TacticalCamera" and o.campo_modo == "PONTE" \
			and nome_do_quadro == "BridgeCamera",
		"pai %s, tática corrente %s, ponte corrente %s, quadro de %s, modo %s" % [str(mao),
			str(o.tatico_camera.is_current()), str(o.ponte_camera.is_current()), nome_do_quadro,
			o.campo_modo])
	var fov_ponte_antes := float(o.ponte_camera.fov)
	o._trocar_modo_camera()
	var dono_depois_do_tab := String(o.get_viewport().get_camera_3d().name) \
		if is_instance_valid(o.get_viewport().get_camera_3d()) else "NENHUMA"
	_assert("em TATICO o quadro muda de dono uma vez só: o mapa entra e a ponte sai",
		o.campo_modo == "TATICO" and bool(o.tatico_camera.is_current()) \
			and not bool(o.ponte_camera.is_current()) and dono_depois_do_tab == "TacticalCamera",
		"modo %s, câmera do quadro %s" % [o.campo_modo, dono_depois_do_tab])
	# `_update_bridge` é a única mão que escreve a FOV da ponte, e ele não roda entre as duas linhas
	# de cima: a montagem ficou para trás e o `process_mode` está congelado. Conferir a lente aqui é
	# medir o TAB sozinho, sem o tick da ponte mascando a medida.
	_assert("o modo nao toca a FOV contratada da ponte",
		absf(float(o.ponte_camera.fov) - fov_ponte_antes) < 1e-4 \
			and absf(float(o.tatico_camera.fov) - TATICO_FOV) < 1e-4,
		"ponte %.1f° em TATICO, tática %.1f°" % [float(o.ponte_camera.fov),
			float(o.tatico_camera.fov)])
	var altura_largada := float(o.tatico_altura)
	var zoom_largada := float(o.campo_zoom)
	for i in range(30):
		o._input(roda)
	_assert("em TATICO a roda iça a ALTURA e o zoom da ponte fica onde estava",
		absf(float(o.tatico_altura) - TATICO_ALTURA_MAX) < 1e-6 \
			and absf(float(o.campo_zoom) - zoom_largada) < 1e-9 \
			and absf(float(o.tatico_camera.fov) - TATICO_FOV) < 1e-4,
		"altura %.0f (teto %.0f), zoom %.2f, lente %.1f°" % [float(o.tatico_altura),
			TATICO_ALTURA_MAX, o.campo_zoom, float(o.tatico_camera.fov)])
	var roda_baixa := InputEventMouseButton.new()
	roda_baixa.button_index = MOUSE_BUTTON_WHEEL_DOWN
	roda_baixa.pressed = true
	roda_baixa.global_position = roda.global_position
	for i in range(60):
		o._input(roda_baixa)
	_assert("a roda encosta nos dois limites de altura e nao passa",
		absf(float(o.tatico_altura) - TATICO_ALTURA_MIN) < 1e-6,
		"altura %.0f (piso %.0f)" % [float(o.tatico_altura), TATICO_ALTURA_MIN])
	# A porta do painel vale para os dois modos, e aqui ela é cobrada no sentido contrário ao do zoom:
	# rolada dentro da moldura, a roda do TATICO não iça o olho nenhum. Os dois positivos seguintes
	# são o atalho pedido pelo comandante — SHIFT iça e CTRL desce de qualquer lugar, inclusive por
	# cima da lista — e o CTRL também devolve o olho ao piso, para as asserções seguintes medirem a
	# mesma altura de antes do desvio.
	var painel_do_olho: Rect2 = o.painel.get_global_rect()
	var dentro_do_painel := painel_do_olho.position + painel_do_olho.size * 0.5
	var roda_painel := InputEventMouseButton.new()
	roda_painel.pressed = true
	roda_painel.button_index = MOUSE_BUTTON_WHEEL_UP
	roda_painel.global_position = dentro_do_painel
	var altura_na_moldura := float(o.tatico_altura)
	for i in range(20):
		o._input(roda_painel)
	_assert("sobre o painel a roda do TATICO também é da lista: o olho não iça",
		absf(float(o.tatico_altura) - altura_na_moldura) < 1e-9 \
			and painel_do_olho.has_point(dentro_do_painel) \
			and not painel_do_olho.has_point(roda.global_position),
		"pisando o piso, 20 voltas dentro da moldura x %.0f-%.0f y %.0f-%.0f devolveram altura %.0f" % [
			painel_do_olho.position.x, painel_do_olho.end.x, painel_do_olho.position.y,
			painel_do_olho.end.y, float(o.tatico_altura)])
	roda_painel.shift_pressed = true
	for i in range(20):
		o._input(roda_painel)
	var altura_shift := float(o.tatico_altura)
	roda_painel.shift_pressed = false
	roda_painel.ctrl_pressed = true
	roda_painel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	for i in range(60):
		o._input(roda_painel)
	_assert("SHIFT+roda sobre o painel iça o olho, CTRL+roda desce de volta ao piso",
		altura_shift > TATICO_ALTURA_MAX - 1e-6 \
			and absf(float(o.tatico_altura) - TATICO_ALTURA_MIN) < 1e-6,
		"com SHIFT dentro da moldura -> %.0f (teto %.0f); com CTRL e 60 voltas -> %.0f (piso %.0f)" % [
			altura_shift, TATICO_ALTURA_MAX, float(o.tatico_altura), TATICO_ALTURA_MIN])
	var altura_presa := float(o.tatico_altura)
	o._trocar_modo_camera()
	_assert("o segundo TAB devolve o olho para a sala", o.campo_modo == "PONTE" \
		and bool(o.ponte_camera.is_current()) and not bool(o.tatico_camera.is_current()),
		"modo %s" % o.campo_modo)
	for i in range(20):
		o._input(roda)
	_assert("de volta à PONTE a roda volta a andar no zoom e a altura içada fica parada",
		absf(float(o.campo_zoom) - 1.0) < 1e-6 and absf(float(o.tatico_altura) - altura_presa) < 1e-9,
		"zoom %.2f, altura %.0f (piso içado em TATICO e esquecido desde então)" % [
			o.campo_zoom, o.tatico_altura])
	o._update_bridge(0.0)
	_assert("o zoom cheio fecha a FOV contratada da ponte e a lente tática continua fixa",
		absf(float(o.ponte_camera.fov) - CAMPO_FOV) < 0.01 \
			and absf(float(o.tatico_camera.fov) - TATICO_FOV) < 1e-4,
		"ponte %.1f° (78° para 14° pelo zoom), tática %.1f°" % [float(o.ponte_camera.fov),
			float(o.tatico_camera.fov)])
	# A pose lê a altura do momento, e a altura do momento é o piso (24) deixado pela roda baixa.
	# Içar de volta antes de pintar é o que faz o número comparado ser o número plantado.
	o.tatico_altura = altura_largada
	o.tatico_foco = Vector3(0.0, 0.0, -63.0)
	o._pintar_camera_tatica()
	_assert("a pose do olho e foco + altura, olhando o tabuleiro de topo",
		(o.tatico_camera.position as Vector3).distance_to(
			o.tatico_foco + Vector3(0.0, altura_largada, 0.0)) < 1e-4 \
			and (o.tatico_camera.rotation_degrees as Vector3).distance_to(Vector3(-90.0, 0.0, 0.0)) < 1e-4,
		"posição %s, giro %.0f° (look_at sobre -Y não tem plano de rotação)" % [
			str(o.tatico_camera.position), o.tatico_camera.rotation_degrees.x])
	o._trocar_modo_camera()
	# A régua do arrasto, conferida DENTRO da caixa: com a lente a 110 u de altura o quadro de cabeça
	# fria mede ~1,79 u por pixel, e um desvio de cem pixels saturaria o limite de x antes de andar um
	# passo — a asserção mediria o clamp, não a conta. Dez pixels bastam, e o sinal é o do gesto:
	# cursor anda para a direita e para baixo, o mapa vem contra ele em x E em z. Na primeira rodada
	# esta sonda esperava `z` CRESCER com o cursor descendo, que é o enquadramento de um olho que
	# olhasse o campo de frente — não de topo, onde norte é cima do quadro.
	var foco_esq := Vector3(0.0, 0.0, -20.0)
	o.tatico_foco = foco_esq
	var regua := float(o._unidades_por_pixel_tatico())
	o._arrastar_tatico(Vector2(10.0, 6.0))
	var esperado := Vector3(foco_esq.x - 10.0 * regua, foco_esq.y, foco_esq.z - 6.0 * regua)
	_assert("arrastar puxa o mapa contra o cursor, na conta exata da régua, e nunca anda em y",
		o.tatico_foco.distance_to(esperado) < 1e-4 and absf(float(o.tatico_foco.y)) < 1e-9,
		"desvio (10, 6) -> %s, esperado %s, régua %.5f u/pixel" % [str(o.tatico_foco),
			str(esperado), regua])
	o.tatico_foco = Vector3(0.0, 0.0, 0.0)
	o._arrastar_tatico(Vector2(1.0e6, 1.0e6))
	_assert("arrasto gigante bate no fundo da caixa: o comandante nunca perde o mapa",
		absf(float(o.tatico_foco.x) + TATICO_LIMITE_X) < 1e-4 \
			and absf(float(o.tatico_foco.z) - TATICO_LIMITE_Z_FUNDO) < 1e-4,
		"foco %s, caixa x ±%.0f, z %.0f..%.0f" % [str(o.tatico_foco), TATICO_LIMITE_X,
			TATICO_LIMITE_Z_FUNDO, TATICO_LIMITE_Z_VANTE])
	o.tatico_foco = Vector3(0.0, 0.0, 0.0)
	o._arrastar_tatico(Vector2(-1.0e6, -1.0e6))
	_assert("e encosta nos mesmos dois cantos pelo gesto inverso",
		absf(float(o.tatico_foco.x) - TATICO_LIMITE_X) < 1e-4 \
			and absf(float(o.tatico_foco.z) - TATICO_LIMITE_Z_VANTE) < 1e-4,
		"foco %s" % str(o.tatico_foco))
	# A dobradiça dos seis pixels, dentro de `_unhandled_input`: prensa + varredura + soltura. É dado
	# de estado, não de projeção, por isso cabe na sonda de cabeça fria — o que ela prova é que a
	# soltura depois de arrastar NUNCA entra no ramo do clique. Como `_clicar_no_campo` é o único
	# caminho que escreve relatório ou seleção, um relatório parado e uma seleção parada depois da
	# soltura são a recusa da ordem, medida sem matriz de câmera.
	o.tatico_foco = Vector3(0.0, 0.0, -20.0)
	o._pintar_camera_tatica()
	var relatorio_do_arrasto := String(o.report_label.text)
	var selecao_do_arrasto := int(o.esquadra.contar_selecionados())
	var foco_antes_da_varredura: Vector3 = o.tatico_foco
	var prensa := InputEventMouseButton.new()
	prensa.button_index = MOUSE_BUTTON_LEFT
	prensa.pressed = true
	prensa.global_position = Vector2(100.0, 100.0)
	var varredura := InputEventMouseMotion.new()
	varredura.global_position = Vector2(130.0, 112.0)
	var soltura := InputEventMouseButton.new()
	soltura.button_index = MOUSE_BUTTON_LEFT
	soltura.pressed = false
	soltura.global_position = Vector2(130.0, 112.0)
	o._unhandled_input(prensa)
	o._unhandled_input(varredura)
	o._unhandled_input(soltura)
	# Trinta pixels de varredura: acima da folga de seis, então é arrasto; dentro da caixa, então o
	# número comparado é a régua e não o clamp — a mesma armadilha da asserção de cima.
	_assert("prensa e varredura de trinta pixels abrem o arrasto e o mapa andou contra o cursor",
		not bool(o._arrasto_ativo) and bool(o._arrasto_moveu) \
			and absf(float(o.tatico_foco.x) - (float(foco_antes_da_varredura.x) - 30.0 * regua)) < 1e-4 \
			and absf(float(o.tatico_foco.z) - (float(foco_antes_da_varredura.z) - 12.0 * regua)) < 1e-4 \
			and absf(float(o.tatico_foco.y)) < 1e-9,
			"moveu %s, foco %s -> %s, régua %.5f u/pixel" % [str(o._arrasto_moveu),
				str(foco_antes_da_varredura), str(o.tatico_foco), regua])
	_assert("soltura depois de arrastar não manda ordem: olhar não é navegar",
		not bool(o._arrasto_ativo) and String(o.report_label.text) == relatorio_do_arrasto \
			and int(o.esquadra.contar_selecionados()) == selecao_do_arrasto,
		"relatório [%s] e %d selecionados inteiros; foco em %s" % [String(o.report_label.text),
			o.esquadra.contar_selecionados(), str(o.tatico_foco)])

	# ── 9. o preco declarado e medido, nao prometido ──────────────────────────────────────────
	# O contador é o de `menu.gd`, não um BFS da árvore inteira: `CheckBox` e `CheckButton` herdam
	# de `Button`, então uma varredura por tipo contaria as alavancas de opção como se fossem ordens
	# e o gabarito de trinta e seis nunca fecharia.
	var botoes := 0
	for nome in NOMES_GRUPOS:
		for filho in (o.group_bodies[nome] as Control).get_children():
			if filho is Button:
				botoes += 1
	_assert("um nó a mais na árvore: o gabarito de filhos é re-medido, não adivinhado",
		int(o.get_child_count()) == FILHOS_DO_JOGO,
		"%d filhos nesta montagem sem cenário; com o `cenario_root` são %d, conferido por geoide.gd" % [
			o.get_child_count(), FILHOS_COM_CENARIO])
	_assert("os trinta e seis comandos do painel não se mexem", botoes == BOTOES_DO_PAINEL,
		"%d botões de comando nos nove corpos" % botoes)
	_assert("o letreiro continua Label e passa a anunciar o próprio modo",
		o.massa_label is Label and String(o.massa_label.text).contains("MASSA") \
			and String(o.massa_label.text).contains("[TAB]") \
			and String(o.massa_label.text).contains("olho"),
		"%s" % o.massa_label.text)
	o._update_hud()
	_assert("o HUD conta seleção e destino em tempo real",
		String(o.massa_label.text).contains("bloco(s) na seleção") \
			and String(o.massa_label.text).contains("sob destino"),
		"%s" % o.massa_label.text)

	# ── 10. o RECOMEÇAR devolve o olho e a formação ──────────────────────────────────────────
	# Estado armado antes da porta: se o RECOMEÇAR fosse medido sobre uma partida já limpa, cada
	# cláusula dele passaria por inércia. A pré-condição abaixo é a régua que diz que há o que resetar.
	if o.campo_modo != "TATICO":
		o._trocar_modo_camera()
	o.esquadra.selecionar_esquadrao(5)
	o._navegar_no_ponto(Vector3(20.0, 0.0, -40.0))
	o.esquadra.mandar_fogo(Vector3(10.0, 0.0, -90.0))
	o.campo_zoom = 0.6
	o.tatico_altura = TATICO_ALTURA_MIN
	o.tatico_foco = Vector3(50.0, 0.0, -100.0)
	_assert("o estado sujo está sujo de fato: olho aberto, vinte sob ordem, fogo concentrado",
		o.campo_modo == "TATICO" and bool(o.tatico_camera.is_current()) \
			and o.esquadra.contar_selecionados() == BLOCOS_NO_ESQUADRAO \
			and o.esquadra.com_destino() == BLOCOS_NO_ESQUADRAO \
			and bool(o.esquadra.fogo_concentrado) and absf(float(o.campo_zoom) - 0.6) < 1e-9,
		"modo %s, %d selecionados, %d sob destino, fogo %s, zoom %.1f" % [o.campo_modo,
			o.esquadra.contar_selecionados(), o.esquadra.com_destino(),
			str(o.esquadra.fogo_concentrado), o.campo_zoom])
	o._recomecar_batalha()
	_assert("RECOMEÇAR fecha o olho tático, a seleção, o destino e o fogo concentrado",
		o.campo_modo == "PONTE" and not bool(o.tatico_camera.is_current()) \
			and bool(o.ponte_camera.is_current()) and o.esquadra.contar_selecionados() == 0 \
			and o.esquadra.com_destino() == 0 and not bool(o.esquadra.fogo_concentrado) \
			and absf(float(o.campo_zoom)) < 1e-9 \
			and (o.tatico_foco as Vector3) == Vector3(0.0, 0.0, -63.0) \
			and absf(float(o.tatico_altura) - TATICO_ALTURA_INICIAL) < 1e-6 \
			and o.esquadra.vivos("aliado") == BLOCOS_POR_LADO,
		"modo %s, %d selecionados, %d sob destino, fogo %s, altura %.0f, %d+%d vivos" % [
			o.campo_modo, o.esquadra.contar_selecionados(), o.esquadra.com_destino(),
			str(o.esquadra.fogo_concentrado), o.tatico_altura, o.esquadra.vivos("aliado"),
			o.esquadra.vivos("hostil")])

	print("SONDA-COMANDO: veredito - quebras=%d - conferencias=%d" % [breaks, notes.size()])
	for nota in notes:
		print(nota)
	quit(1 if breaks > 0 else 0)
