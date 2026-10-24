extends SceneTree

## Sonda dos módulos: o ataque por subsistema passou a ter um endereço na tela, e a pintura deixou
## de prometer setor vivo onde a conta já matou aquele setor.
##
## O pedido foi «naves feitas em módulos para fazer sentido o ataque setorizado como motor, casco,
## etc.». A conta já era por subsistema (`_resolve_volley` cobra `engines`, `weapons` e `crew` em
## vez de `hp`); o que faltava era o lugar a que o nome do painel aponta. Esta sonda não julga
## beleza — julga as sete leis que fazem do módulo um endereço, e não um segundo jogo:
##
## 1) ENDEREÇO. Dentro do filho "Casco" de todo casco da esquadra há exatamente quatro nós, com os
##    nomes de `SETORES`, nesta ordem, e nenhum bilhete pendurado fora de gaveta. Vinte corpos,
##    quatro gavetas, zero órfão.
## 2) IDENTIDADE, NÃO GEOMETRIA. Cada módulo nasce com transform identidade, e a prova é forte: a
##    transformada GLOBAL do módulo é a do próprio "Casco". Reparentar mudou pai, nunca cota — é
##    isto que deixa a silhueta assinada por `tools/probes/graficos.gd` byte a byte a mesma.
## 3) A PARTIÇÃO FECHA. Nove bilhetes em `CASCO`, seis em `MOTORES`, quatro em `ARMAS`, um em
##    `TRIPULACAO` — em TODA gramática. O mastro dourado da capitânia cai na tripulação, dono da
##    torre, e é o único vinte e um do elenco.
## 4) UM MATERIAL, UM SETOR. Nenhum material escrito por `_tune_ship_look` mora em dois módulos:
##    `hull`/`trim`/`luz` são do casco, `engine`/`flare` dos motores, `gun` das armas, `trip` da
##    tripulação. `steel` atravessa casco e motores justamente porque nenhum setor o escreve, e é
##    medido como exceção honesta, não como brecha.
## 5) A PINTURA NÃO MENTE. Setor a zero lê zero: bocal apagado, pluma com alfa 0, canhão apagado,
##    torre de comando apagada. Os três pisos de brilho que existiam antes sobreviviam ao corte. O
##    topo de cada rampa é o MESMO número assinado antes da fatia (3,0 / 0,58 / 1,75 / 1,0), então a
##    100% o quadro continua o de sempre.
## 6) O MESMO NOME NOS DOIS LADOS. O seletor de subsistema do painel é `SETORES` na ordem de
##    `SETOR_PAINEL`, e cada rótulo escolhido derruba UM número da ficha — o que ele nomeia — com o
##    fator da casa (1,7 para motor e arma, 1,5 para tripulação, 1,0 para casco). Medido com a salva
##    resolvendo de verdade, no tabuleiro de `tools/probes/salva.gd`, não lendo o `if`.
## 7) NADA DISSO SORTEIA. `_make_ship` e `_tune_ship_look` não movem `rng` nem `visual_rng`, e a
##    cauda de quarenta sorteios é a mesma lida na semente cravada, com e sem o trabalho de módulo
##    no meio. É a régua de `tools/probes/superficies.gd`, e é a que as outras sondas assumem.
##
## Vem junto o que a fatia promete para os dois casos especiais: a presa incorporada veste a marca
## dourada na `TRIPULACAO`, em mais lugar nenhum, e o destroço apaga os quatro setores — inclusive
## o material novo da tripulação, que antes de existir esta fatia nem havia.
##
## Uso: godot --headless --path . --quit-after 6000 -s res://tools/probes/modulos.gd

## Espelho das constantes de `main.gd` (a instância do jogo é não tipada; mesmo motivo em
## `tools/probes/misseis.gd`). Mudar o número lá quebra a asserção aqui: é de propósito.
const SETORES_ESPERADOS: Array[String] = ["CASCO", "MOTORES", "ARMAS", "TRIPULACAO"]
const PAINEL_ESPERADO: Array[String] = ["CASCO", "MOTORES", "ARMAS", "TRIPULAÇÃO"]
const BILHETES_POR_SETOR := {"CASCO": 9, "MOTORES": 6, "ARMAS": 4, "TRIPULACAO": 1}
const BILHETES_DO_CASCO := 20
## Onde mora cada material do casco. `ESCRITOS` é o subconjunto que `_tune_ship_look` escreve todo
## quadro; os outros três (`trim`, `luz`, `steel`) são de criação e só mudam por ordem ou presa.
const MATERIAL_SETOR := {"hull": "CASCO", "trim": "CASCO", "luz": "CASCO",
	"engine": "MOTORES", "flare": "MOTORES", "gun": "ARMAS", "trip": "TRIPULACAO"}
const ESCRITOS: Array[String] = ["hull", "engine", "flare", "gun", "trip"]
## Os números que a rampa lê no fundo e no topo. O topo é o valor assinado pelas sondas ANTES da
## fatia: cortar os três pisos de brilho não podia escurecer um casco inteiro.
const TOPO_ENGINE := 3.0
const TOPO_FLARE := 0.58
const TOPO_GUN := 1.75
const TOPO_TRIP := 1.0
const PLUMA_MORTA := 0.45
const PLUMA_CHEIA := 1.5
## Empuxo de criação dos materiais que têm brilho de fábrica (`_material` com `glow`): 1,4. É o
## retrato antes do primeiro `_tune_ship_look` e a régua do "mudou" da seção 5.
const BRILHO_DE_FABRICA := 1.4
## Fatores de `_resolve_volley` por setor, e a régua de dano de `tools/probes/salva.gd`.
const FATOR_MOTOR := 1.7
const FATOR_TRIPULACAO := 1.5
const DANO_ALIADO_BASE := 2.5
const FATOR_ATACAR := 1.8
const FLECHAS_POR_SALVA := 3
const TIRO := Vector3(0.0, 0.0, -40.0)
const VISADA := Vector3(0.0, 0.0, -80.0)
const SEMENTE_VOLLEY := 71001
## Tolerância de float lido de volta do motor, na escala das contas de cadastro (até 100).
const FOLGA := 0.0001

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

func _igual(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol

## Monta o jogo e congela pelo instrumento da casa: `process_mode`, nunca `set_process(false)`.
func _montar_jogo() -> Node3D:
	var game: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(3)
	game._update_bridge(0.0)
	return game

func _alinhar(game) -> void:
	for i in range(game.fleet.size()):
		(game.fleet[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 5.0, 0.0, -38.0)
	for i in range(game.enemies.size()):
		(game.enemies[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 6.0, 0.0, -82.0)

## Ficha cheia em todo corpo, sem sorteio: a condição de validade das asserções de conta.
func _zerar(game) -> void:
	for list in [game.fleet, game.enemies]:
		for unit in list:
			unit["hp"] = 100.0
			unit["engines"] = 100.0
			unit["weapons"] = 100.0
			unit["crew"] = 100.0
			unit["veloc"] = Vector3.ZERO
	game.capital_hp = 100.0
	game.batalha_encerrada = false

## Bilhetes de um nó, descendo: os módulos são nós, então o andador tem de entrar neles. É o mesmo
## andador de `tools/probes/graficos.gd`, `misseis.gd`, `cacas.gd` e `fotograma.gd`.
func _bilhetes(no: Node) -> Array:
	var out: Array = []
	var pilha: Array[Node] = [no]
	while not pilha.is_empty():
		var atual: Node = pilha.pop_back()
		for filho in atual.get_children():
			if filho is MeshInstance3D:
				out.append(filho)
			else:
				pilha.append(filho)
	return out

func _modulo(casco: Node3D, setor: String) -> Node3D:
	return casco.get_node(NodePath(setor)) as Node3D

## Os doze cascos das duas esquadras, um lista só: a lei não distingue azul de vermelho.
func _cascos(game) -> Array:
	var out: Array = []
	for list in [game.fleet, game.enemies]:
		for unit in list:
			out.append(unit)
	return out

## Os quatro números da ficha, na MESMA ordem dos setores: hp, engines, weapons, crew.
func _ficha(unit) -> Array[float]:
	return [float(unit["hp"]), float(unit["engines"]), float(unit["weapons"]), float(unit["crew"])]

## Retrato instantâneo dos materiais de um casco: albedo, empuxo e emissão. Lido antes e depois de
## `_tune_ship_look` para separar quem obedece ao setor de quem só veste chapa.
func _retrato(mats: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for chave in mats:
		var mat: StandardMaterial3D = mats[chave]
		out[String(chave)] = [mat.albedo_color, mat.emission_energy_multiplier, mat.emission]
	return out

## Quarenta sorteios do gerador de combate, na ordem em que saem (mesma régua de
## `tools/probes/superficies.gd`).
func _cauda(game) -> Array[int]:
	var retirada: Array[int] = []
	for i in range(40):
		retirada.append(game.rng.randi())
	return retirada

func _rodar() -> void:
	# ── 1. Endereço: quatro gavetas dentro do Casco, nenhum bilhete solto ──────────────────────
	var g1: Node3D = await _montar_jogo()
	var so_quatro := true
	var nomes_ok := true
	var particoes_lidas: Dictionary = {}
	for unit in _cascos(g1):
		var ship: Node3D = unit["node"]
		var casco: Node3D = ship.get_node("Casco") as Node3D
		if casco.get_child_count() != SETORES_ESPERADOS.size():
			so_quatro = false
		var ordem: Array[String] = []
		for filho in casco.get_children():
			ordem.append(String(filho.name))
		if str(ordem) != str(SETORES_ESPERADOS):
			nomes_ok = false
		var particao: Array[String] = []
		for setor in SETORES_ESPERADOS:
			particao.append("%d" % _bilhetes(_modulo(casco, setor)).size())
		var leitura := "/".join(particao)
		particoes_lidas[leitura] = int(particoes_lidas.get(leitura, 0)) + 1
	_assert("todo casco da esquadra abre em exatamente quatro módulos", so_quatro,
		"%d cascos, nenhum bilhete pendurado fora de gaveta" % _cascos(g1).size())
	_assert("os módulos têm os nomes de `SETORES`, na ordem da lei", nomes_ok,
		"%s conferida em doze cascos" % str(SETORES_ESPERADOS))
	# Onze cascos de linha e uma capitânia: a única partição que sai do gabarito é a do mastro
	# dourado, que nasce com a torre e mora na mesma gaveta.
	_assert("onze cascos particionam 9/6/4/1 e o décimo segundo é a capitânia com o mastro",
		int(particoes_lidas.get("9/6/4/1", 0)) == 11
			and int(particoes_lidas.get("9/6/4/2", 0)) == 1,
		"%s" % str(particoes_lidas))

	# ── 2. Identidade, não geometria ──────────────────────────────────────────────────────────
	var identidade := true
	var globais_iguais := true
	var desvios: Array[String] = []
	var nos_conferidos := 0
	for unit in _cascos(g1):
		var ship2: Node3D = unit["node"]
		var casco2: Node3D = ship2.get_node("Casco") as Node3D
		for setor in SETORES_ESPERADOS:
			var gaveta: Node3D = _modulo(casco2, setor)
			nos_conferidos += 1
			if not (gaveta.position == Vector3.ZERO and gaveta.rotation == Vector3.ZERO
					and gaveta.scale == Vector3.ONE):
				identidade = false
			# A prova forte: se o módulo move qualquer coisa, a transformada global dele deixa de ser
			# a do Casco e a silhueta medida por `graficos.gd` teria mudado com a fatia.
			# A prova forte: a transformada GLOBAL do módulo é a do próprio Casco, com deriva e tudo.
			# Se o módulo movesse qualquer coisa, a silhueta assinada por `graficos.gd` teria mudado
			# com a fatia — e é isto que permite reparentar vinte bilhetes sem relembrar nenhum número.
			var gt_mod: Transform3D = gaveta.global_transform
			var gt_casco: Transform3D = casco2.global_transform
			var d: Vector3 = gt_mod.origin - gt_casco.origin
			if d.length() > FOLGA or gt_mod.basis != gt_casco.basis:
				globais_iguais = false
				desvios.append("%s %.6f" % [setor, d.length()])
	_assert("os quarenta e oito módulos nascem com transform identidade", identidade,
		"posição, rotação e escala lidos em %d nós de módulo" % nos_conferidos)
	_assert("a transformada global do módulo é a do próprio Casco", globais_iguais,
		"%d desvios acima de %s u" % [desvios.size(), str(FOLGA)])

	# ── 3. A partição por gramática, e o mastro na tripulação ─────────────────────────────────
	var gramaticas: Array[String] = []
	var particoes_por_gram: Dictionary = {}
	var capitania_lida := ""
	var capitania_ok := false
	for unit in _cascos(g1):
		var ship3: Node3D = unit["node"]
		var casco3: Node3D = ship3.get_node("Casco") as Node3D
		var total := 0
		var contagem: Dictionary = {}
		for setor in SETORES_ESPERADOS:
			var n := _bilhetes(_modulo(casco3, setor)).size()
			contagem[setor] = n
			total += n
		if String(unit.get("role", "")) == "COMANDO":
			capitania_lida = "%d bilhetes, TRIPULACAO %d" % [total, int(contagem["TRIPULACAO"])]
			capitania_ok = total == BILHETES_DO_CASCO + 1 and int(contagem["TRIPULACAO"]) == 2
		else:
			var nome_gram := String(ship3.get_meta("gramatica"))
			if not particoes_por_gram.has(nome_gram):
				particoes_por_gram[nome_gram] = contagem
				gramaticas.append(nome_gram)
	_assert("as quatro gramáticas convivem na linha conferida", gramaticas.size() == 4,
		"%s" % str(gramaticas))
	var particao_boa := true
	var detalhes: Array[String] = []
	for nome in particoes_por_gram:
		var c: Dictionary = particoes_por_gram[nome]
		for setor in SETORES_ESPERADOS:
			if int(c[setor]) != int(BILHETES_POR_SETOR[setor]):
				particao_boa = false
			detalhes.append("%s:%s=%d" % [nome, setor, int(c[setor])])
	_assert("cada gaveta tem o número de bilhetes que a lei anuncia", particao_boa,
		"%s" % ", ".join(detalhes))
	_assert("a capitânia é o único vinte e um, com o mastro dourado na tripulação", capitania_ok,
		"%s" % capitania_lida)

	# ── 4. Um material, um setor ──────────────────────────────────────────────────────────────
	var g4: Node3D = await _montar_jogo()
	var morada_unica := true
	var steel_solitario := 0
	var lidas := 0
	var quem_quebrou: Array[String] = []
	for unit in _cascos(g4):
		var ship4: Node3D = unit["node"]
		var mats: Dictionary = ship4.get_meta("mat")
		var casco4: Node3D = ship4.get_node("Casco") as Node3D
		# id do material -> módulos que o usam. É a lei falada em nome de módulo, não em id.
		var onde: Dictionary = {}
		for setor in SETORES_ESPERADOS:
			for billete in _bilhetes(_modulo(casco4, setor)):
				var mi: MeshInstance3D = billete
				var id: int = mi.material_override.get_instance_id()
				if not onde.has(id):
					onde[id] = []
				(onde[id] as Array).append(String(setor))
		for chave in MATERIAL_SETOR:
			var nome_chave := String(chave)
			var id_mat: int = (mats[nome_chave] as Material).get_instance_id()
			lidas += 1
			var usos: Array = onde.get(id_mat, [])
			var unicos: Array[String] = []
			for u in usos:
				if not unicos.has(String(u)):
					unicos.append(String(u))
			if unicos.size() != 1 or unicos[0] != String(MATERIAL_SETOR[nome_chave]):
				morada_unica = false
				quem_quebrou.append("%s em %s" % [nome_chave, str(unicos)])
		var id_steel: int = (mats["steel"] as Material).get_instance_id()
		var usos_steel: Array = onde.get(id_steel, [])
		var modulos_steel: Array[String] = []
		for u in usos_steel:
			if not modulos_steel.has(String(u)):
				modulos_steel.append(String(u))
		if modulos_steel.size() < 2:
			steel_solitario += 1
	_assert("nenhum material de setor mora em dois módulos", morada_unica,
		"%d materiais conferidos em doze cascos; quebras: %s" % [lidas,
		"nenhuma" if quem_quebrou.is_empty() else ", ".join(quem_quebrou)])
	_assert("o aço de chapa atravessa casco e motores porque nenhum setor o escreve",
		steel_solitario == 0, "%d cascos com steel preso a uma gaveta só" % steel_solitario)

	# ── 5. A pintura não mente ────────────────────────────────────────────────────────────────
	var g5: Node3D = await _montar_jogo()
	_zerar(g5)
	var unidade: Dictionary = g5.fleet[0]
	var ship5: Node3D = unidade["node"]
	var mats5: Dictionary = ship5.get_meta("mat")
	var antes := _retrato(mats5)
	unidade["engines"] = 0.0
	unidade["weapons"] = 0.0
	unidade["crew"] = 0.0
	g5._tune_ship_look(unidade)
	var mat_engine: StandardMaterial3D = mats5["engine"]
	var mat_flare: StandardMaterial3D = mats5["flare"]
	var mat_gun: StandardMaterial3D = mats5["gun"]
	var mat_trip: StandardMaterial3D = mats5["trip"]
	_assert("motor a zero apaga o bocal",
		_igual(mat_engine.emission_energy_multiplier, 0.0, FOLGA),
		"empuxo do bocal lido %.4f (o piso cortado era 0,2)" % mat_engine.emission_energy_multiplier)
	_assert("motor a zero some com a pluma", _igual(mat_flare.albedo_color.a, 0.0, FOLGA),
		"alfa da pluma lido %.4f" % mat_flare.albedo_color.a)
	var plumas_mortas := true
	var escala_pluma := 0.0
	for pluma in ship5.get_meta("plumas"):
		var q: MeshInstance3D = pluma
		escala_pluma = float(q.scale.x)
		if not _igual(escala_pluma, PLUMA_MORTA, FOLGA):
			plumas_mortas = false
	_assert("a pluma morta encolhe até o piso da rampa", plumas_mortas,
		"escala %.3f contra o piso anunciado %.3f" % [escala_pluma, PLUMA_MORTA])
	_assert("arma a zero apaga a torre de canhão",
		_igual(mat_gun.emission_energy_multiplier, 0.0, FOLGA),
		"empuxo da torre lido %.4f (o piso cortado era 0,15)" % mat_gun.emission_energy_multiplier)
	_assert("tripulação a zero apaga a torre de comando",
		_igual(mat_trip.emission_energy_multiplier, 0.0, FOLGA),
		"empuxo do comando lido %.4f" % mat_trip.emission_energy_multiplier)
	var depois := _retrato(mats5)
	var escritos_moveram := true
	var inocentes_tocados: Array[String] = []
	for chave in mats5:
		var nome_c := String(chave)
		var mudou: bool = (depois[nome_c][0] != antes[nome_c][0]) \
			or not _igual(float(depois[nome_c][1]), float(antes[nome_c][1]), FOLGA) \
			or (depois[nome_c][2] != antes[nome_c][2])
		if ESCRITOS.has(nome_c):
			if not mudou:
				escritos_moveram = false
		elif mudou:
			inocentes_tocados.append(nome_c)
	_assert("os cinco materiais de setor responderam ao corte", escritos_moveram,
		"%d escritos, nenhum ficou parado" % ESCRITOS.size())
	_assert("steel, trim e luz não se moveram: quem não tem setor não obedece",
		inocentes_tocados.is_empty(),
		"%d materiais fora da lei tocados" % inocentes_tocados.size())
	unidade["engines"] = 100.0
	unidade["weapons"] = 100.0
	unidade["crew"] = 100.0
	g5._tune_ship_look(unidade)
	var plumas_cheias := true
	for pluma in ship5.get_meta("plumas"):
		var qc: MeshInstance3D = pluma
		if not _igual(float(qc.scale.x), PLUMA_CHEIA, FOLGA):
			plumas_cheias = false
	_assert("o topo das quatro rampas é o número assinado antes da fatia",
		_igual(mat_engine.emission_energy_multiplier, TOPO_ENGINE, FOLGA)
			and _igual(mat_flare.albedo_color.a, TOPO_FLARE, FOLGA)
			and _igual(mat_gun.emission_energy_multiplier, TOPO_GUN, FOLGA)
			and _igual(mat_trip.emission_energy_multiplier, TOPO_TRIP, FOLGA)
			and plumas_cheias,
		"bocal %.2f, pluma %.2f, canhão %.2f, comando %.2f, escama %.2f" % [
			mat_engine.emission_energy_multiplier, mat_flare.albedo_color.a,
			mat_gun.emission_energy_multiplier, mat_trip.emission_energy_multiplier, PLUMA_CHEIA])
	_assert("o brilho de fábrica não é o que a mesa lê: a pintura manda no setor",
		_igual(float(antes["trip"][1]), BRILHO_DE_FABRICA, FOLGA)
			and _igual(float(depois["trip"][1]), 0.0, FOLGA),
		"torre de comando nasce em %.2f e a tripulação morta lê %.2f" % [
			float(antes["trip"][1]), float(depois["trip"][1])])

	# ── 6. Painel e módulos são a mesma lista ─────────────────────────────────────────────────
	var g6: Node3D = await _montar_jogo()
	var seletor: OptionButton = g6.subsystem_selector
	var rotulos: Array[String] = []
	for i in range(seletor.get_item_count()):
		rotulos.append(seletor.get_item_text(i))
	_assert("o seletor do painel é `SETORES` na ordem de `SETOR_PAINEL`",
		str(rotulos) == str(PAINEL_ESPERADO), "%s" % str(rotulos))
	_assert("painel e árvore têm o mesmo número de setores",
		seletor.get_item_count() == SETORES_ESPERADOS.size(),
		"%d itens no painel, %d gavetas no casco" % [seletor.get_item_count(),
			SETORES_ESPERADOS.size()])

	# ── 7. O rótulo escolhido derruba o número que ele nomeia ──────────────────────────────────
	var deltas: Array = []
	var feriram: Array[int] = []
	for indice in range(SETORES_ESPERADOS.size()):
		var game: Node3D = await _montar_jogo()
		_alinhar(game)
		_zerar(game)
		game.rng.seed = SEMENTE_VOLLEY
		# Tabuleiro da régua de `salva.gd`: uma atiradora sob ATACAR, um visado vivo, disco fechado.
		for i in range(game.fleet.size()):
			game.fleet[i]["weapons"] = 0.0
			game.fleet[i]["order"] = "LINHA"
		game.fleet[0]["weapons"] = 100.0
		game.fleet[0]["order"] = "ATACAR"
		(game.fleet[0]["node"] as Node3D).position = TIRO
		(game.enemies[0]["node"] as Node3D).position = VISADA
		game.selected_target = 0
		for i in range(1, game.enemies.size()):
			game.enemies[i]["hp"] = 0.0
		# O visado mantém os canhões cheios: a régua daqui mede o que a SALVA aliada tira do setor,
		# e `ARMAS` não tem número a cobrar num alvo já desarmado. A retaliação hostil cai sobre a
		# frota, que esta seção nunca lê.
		# Precondition da fatia 3, não número afrouxado: com a casca de pé o eixo CASCO não tem casco
		# a perder, e é exatamente isso que `tools/probes/escudo.gd` cobra em família própria. Aqui o
		# que se mede é o endereçamento de setor, então a chapa vai ao chão antes de atirar — do mesmo
		# jeito que se arma o canhão do visado: o instrumento declara o estado de que precisa.
		game.enemies[0]["escudo"] = 0.0
		game.enemies[0]["escudo_max"] = 0.0
		game.enemies[0]["escudo_cai"] = 0.0
		game.fogo_densidade = 0
		game.subsystem_selector.select(indice)
		var antes_ficha := _ficha(game.enemies[0])
		game._resolve_volley()
		var depois_ficha := _ficha(game.enemies[0])
		var linhas: Array[float] = []
		for k in range(4):
			linhas.append(antes_ficha[k] - depois_ficha[k])
		deltas.append(linhas)
		feriram.append(int(game.salva_contagem["aliados_feriram"]))
	var controle := true
	for f in feriram:
		if int(f) != FLECHAS_POR_SALVA:
			controle = false
	_assert("as três setas chegaram nos quatro casos (não é salva vazia)", controle,
		"feriram por rodada: %s" % str(feriram))
	var endereco_ok := true
	var endereco_lido: Array[String] = []
	for indice in range(SETORES_ESPERADOS.size()):
		var linha: Array = deltas[indice]
		var tocados: Array[int] = []
		for k in range(4):
			if float(linha[k]) > FOLGA:
				tocados.append(k)
		# `hp`, `engines`, `weapons`, `crew` já vêm na ordem dos setores: o esperado é o próprio índice.
		if tocados.size() != 1 or tocados[0] != indice:
			endereco_ok = false
		endereco_lido.append("%s->%s" % [PAINEL_ESPERADO[indice], str(tocados)])
	_assert("cada rótulo do painel derruba exatamente o número que ele nomeia", endereco_ok,
		"%s" % ", ".join(endereco_lido))
	var d_hp := float((deltas[0] as Array)[0])
	var d_eng := float((deltas[1] as Array)[1])
	var d_weap := float((deltas[2] as Array)[2])
	var d_crew := float((deltas[3] as Array)[3])
	_assert("o casco paga a régua inteira da salva",
		_igual(d_hp, DANO_ALIADO_BASE * FATOR_ATACAR, FOLGA),
		"%.4f de casco perdido contra %.3f da tabela" % [d_hp, DANO_ALIADO_BASE * FATOR_ATACAR])
	_assert("motor e arma cobram o mesmo 1,7 por lance",
		_igual(d_eng / d_hp, FATOR_MOTOR, FOLGA) and _igual(d_weap / d_hp, FATOR_MOTOR, FOLGA),
		"%.4f e %.4f contra o casco" % [d_eng / d_hp, d_weap / d_hp])
	_assert("tripulação cobra 1,5 por lance", _igual(d_crew / d_hp, FATOR_TRIPULACAO, FOLGA),
		"%.4f contra o casco" % (d_crew / d_hp))

	# ── 8. Nada disso sorteia ──────────────────────────────────────────────────────────────────
	var g8: Node3D = await _montar_jogo()
	g8.rng.seed = 60606
	g8.visual_rng.seed = 555
	var cauda_sem := _cauda(g8)
	var cauda_g8: Node3D = await _montar_jogo()
	cauda_g8.rng.seed = 60606
	cauda_g8.visual_rng.seed = 555
	var rng_inicial := int(cauda_g8.rng.state)
	var visual_inicial := int(cauda_g8.visual_rng.state)
	var casco_novo: Node3D = cauda_g8._make_ship(Vector3(0.0, 0.0, -60.0), Color(0.2, 0.5, 1.0),
		1.2, "SONDA MODULO", false, 3, 2)
	var modulo_novo_boa := _bilhetes(casco_novo.get_node("Casco") as Node3D).size() \
		== BILHETES_DO_CASCO
	for setor in SETORES_ESPERADOS:
		var m: Node3D = _modulo(casco_novo.get_node("Casco") as Node3D, setor)
		if m.get_child_count() != int(BILHETES_POR_SETOR[setor]):
			modulo_novo_boa = false
	for unit in _cascos(cauda_g8):
		for i in range(20):
			cauda_g8._tune_ship_look(unit)
	_assert("montar um casco e vestir os módulos não sorteia um dígito",
		int(cauda_g8.rng.state) == rng_inicial and int(cauda_g8.visual_rng.state) == visual_inicial,
		"depois de montar e retocar %d vezes: %d / %d" % [_cascos(cauda_g8).size() * 20,
			cauda_g8.rng.state, cauda_g8.visual_rng.state])
	_assert("o casco criado na sonda vem com as quatro gavetas já particionadas",
		modulo_novo_boa, "gramática %s com %d bilhetes" % [String(casco_novo.get_meta("gramatica")),
			_bilhetes(casco_novo.get_node("Casco") as Node3D).size()])
	var cauda_com := _cauda(cauda_g8)
	_assert("a cauda de quarenta sorteios é a mesma com o trabalho de módulo no meio",
		str(cauda_sem) == str(cauda_com),
		"%d sorteios lidos dos dois lados, na semente 60606" % cauda_com.size())

	# ── 9. A presa veste a tripulação; o destroço apaga os quatro ──────────────────────────────
	var g9: Node3D = await _montar_jogo()
	var ship9: Node3D = g9.enemies[1]["node"]
	var casco9: Node3D = ship9.get_node("Casco") as Node3D
	var antes_trip := _bilhetes(_modulo(casco9, "TRIPULACAO")).size()
	var antes_outros := 0
	for setor in ["CASCO", "MOTORES", "ARMAS"]:
		antes_outros += _bilhetes(_modulo(casco9, setor)).size()
	var trip_antes_mat: StandardMaterial3D = (ship9.get_meta("mat") as Dictionary)["trip"]
	var emissao_antes: Color = trip_antes_mat.emission
	g9._mark_as_prize(ship9)
	var depois_trip := _bilhetes(_modulo(casco9, "TRIPULACAO")).size()
	var depois_outros := 0
	for setor in ["CASCO", "MOTORES", "ARMAS"]:
		depois_outros += _bilhetes(_modulo(casco9, setor)).size()
	_assert("a marca dourada da presa entra na tripulação, e em mais lugar nenhum",
		depois_trip == antes_trip + 1 and depois_outros == antes_outros,
		"TRIPULACAO %d -> %d, outras gavetas %d -> %d" % [antes_trip, depois_trip,
			antes_outros, depois_outros])
	_assert("a torre de comando da incorporada acende em cor de aliança",
		trip_antes_mat.emission != emissao_antes,
		"emissão %s -> %s" % [str(emissao_antes), str(trip_antes_mat.emission)])

	var g10: Node3D = await _montar_jogo()
	_zerar(g10)
	var destroco: Dictionary = g10.fleet[2]
	var ship10: Node3D = destroco["node"]
	destroco["hp"] = 0.0
	destroco["engines"] = 0.0
	destroco["weapons"] = 0.0
	destroco["crew"] = 0.0
	g10._mark_wreck(ship10)
	var mats10: Dictionary = ship10.get_meta("mat")
	var apagados := true
	var lidos_ruina: Array[String] = []
	for chave in ESCRITOS:
		var mat: StandardMaterial3D = mats10[chave]
		var valor := mat.emission_energy_multiplier
		var nome_k := String(chave)
		var esperado := 0.14 if nome_k == "hull" else 0.0
		if not _igual(valor, esperado, FOLGA):
			apagados = false
		lidos_ruina.append("%s=%.2f" % [nome_k, valor])
	_assert("o destroço apaga os quatro setores, inclusive a tripulação", apagados,
		"%s (a brasa do casco fica em 0,14 por lei de `morte.gd`)" % ", ".join(lidos_ruina))
	_assert("a luz aditiva da proa também morre no afundamento",
		_igual((mats10["luz"] as StandardMaterial3D).albedo_color.a, 0.0, FOLGA),
		"alfa de proa lido %.4f" % (mats10["luz"] as StandardMaterial3D).albedo_color.a)
	_assert("e o casco morto não ganha nem perde bilhete em nenhuma gaveta",
		_bilhetes(ship10.get_node("Casco") as Node3D).size() == BILHETES_DO_CASCO,
		"%d bilhetes depois do afundamento"
			% _bilhetes(ship10.get_node("Casco") as Node3D).size())

	print("SONDA-MODULOS: veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	for nota in notes:
		print(nota)
	quit(1 if breaks > 0 else 0)

func _initialize() -> void:
	_rodar()
