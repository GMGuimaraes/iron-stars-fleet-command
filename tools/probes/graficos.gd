extends SceneTree

## Sonda da camada visual (referência Legend of the Galactic Heroes). Ela não mede beleza —
## beleza se mede no editor, com o olho. O que ela mede é a fronteira que a pintura tem de
## respeitar: a ponte ganhou céu, mesa holográfica, casco de aço com brasa, lance e destroço, e
## nada disso pode tocar um número da batalha. As asserções são de três tipos: (1) a geometria
## foi REALMENTE montada — um construtor que aborta em erro de runtime some com o nó e as sondas
## de lógica continuam verdes, e foi exatamente assim que a mesa holográfica inteira
## desapareceu por uma rodada; (2) a camada visual não consome `rng`, e o traço aliado custa
## exatamente os dois sorteios de sempre; (3) o material que conta como leitura de dano acende
## na porta certa (55% de abordagem), o nó raiz continua parado enquanto a silhueta ondula, e o
## destroço fica visível e imóvel. A prova central é a corrida A/B de dois jogos na mesma
## semente: mesma assinatura, mesmo `rng.state` — e o céu estrelado idêntico entre os dois,
## porque a estrela sai de `visual_rng` com semente cravada.
##
## Uso: godot --headless --path . --quit-after 1800 -s res://tools/probes/graficos.gd

## As constantes de main.gd vêm por extenso: a instância do jogo é não tipada e elas não são
## alcançáveis por ela (mesmo motivo em `tools/probes/sondas.gd`).
const ACO := Color(0.34, 0.38, 0.44)
const CARVAO := Color(0.05, 0.045, 0.055)
const BLUE := Color(0.12, 0.72, 1.0)
const RED := Color(1.0, 0.22, 0.18)
const ESCOAMENTO_ALIADO := Color(0.34, 0.72, 1.0)

var breaks := 0
var notes: Array[String] = []

func _assert(label: String, condition: bool, detail: String) -> void:
	if condition:
		notes.append("OK   %s — %s" % [label, detail])
	else:
		breaks += 1
		notes.append("QUEBRA %s — %s" % [label, detail])

## Distância entre cores somada por canal: sem depender de método algum de `Color`, para a
## asserção não mudar de ideia junto com a versão do motor.
func _distancia_cor(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)

## Assinatura inclui `rotation.y` da raiz: a meia-volta do hostil é escrita no nó lógico, então
## é exatamente o tipo de coisa que uma pintura pode estragar e uma assinatura de posição não vê.
func _assinatura(game) -> String:
	var parts: Array[String] = []
	for list in [game.fleet, game.enemies]:
		for unit in list:
			var node: Node3D = unit["node"]
			parts.append("%s:%.2f/%.2f/%.2f/%.2f@%.2f,%.2f,%.2f|rot%.2f" % [unit["name"],
				float(unit["hp"]), float(unit["engines"]), float(unit["weapons"]), float(unit["crew"]),
				node.position.x, node.position.y, node.position.z, node.rotation.y])
	return "|".join(parts)

func _alinhar(game) -> void:
	for i in range(game.fleet.size()):
		(game.fleet[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 5.0, 0.0, -38.0)
	for i in range(game.enemies.size()):
		(game.enemies[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 6.0, 0.0, -82.0)

func _zerar(game) -> void:
	for list in [game.fleet, game.enemies]:
		for unit in list:
			unit["hp"] = 100.0
			unit["engines"] = 100.0
			unit["weapons"] = 100.0
			unit["crew"] = 100.0

func _montar_jogo() -> Node3D:
	var game: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	await _frames(3)
	return game

func _casco_of(unit: Dictionary) -> Node3D:
	var ship: Node3D = unit["node"]
	return ship.get_meta("casco")

func _mat(unit: Dictionary, chave: String) -> StandardMaterial3D:
	var ship: Node3D = unit["node"]
	var mats: Dictionary = ship.get_meta("mat")
	return mats[chave]

func _starfield(game) -> MultiMeshInstance3D:
	for child in game.get_children():
		if child is MultiMeshInstance3D:
			return child
	return null

func _somar_casco(game) -> float:
	var total := 0.0
	for list in [game.fleet, game.enemies]:
		for unit in list:
			total += float(unit["hp"])
	return total

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _initialize() -> void:
	var game: Node3D = await _montar_jogo()
	_alinhar(game)
	_zerar(game)

	# 1 — A geometria existe. Sem este bloco o resto da sonda mede ausência.
	var casco: Node3D = _casco_of(game.fleet[0])
	_assert("nave tem filho Casco", is_instance_valid(casco) and casco.name == "Casco",
		"nome=%s" % str(casco.name))
	_assert("nave de linha montada por inteiro", casco.get_child_count() >= 20,
		"%d billetes (esperado >= 20)" % casco.get_child_count())
	var capitania: Node3D = _casco_of(game.enemies[0])
	_assert("capitânia hostil leva mastro a mais", capitania.get_child_count() > casco.get_child_count(),
		"%d contra %d da linha" % [capitania.get_child_count(), casco.get_child_count()])
	var vivos := 0
	for list in [game.fleet, game.enemies]:
		for unit in list:
			if float(unit["hp"]) > 0.0:
				vivos += 1
	_assert("mesa holográfica espelha o tabuleiro", game.holo_blips.size() == vivos
		and game.holo_root.get_child_count() == vivos,
		"%d blips para %d cascos vivos" % [game.holo_blips.size(), vivos])
	var ceu := _starfield(game)
	_assert("estrelas cabem num único MultiMesh", ceu != null and ceu.multimesh.instance_count == 900,
		"instance_count=%d" % (0 if ceu == null else ceu.multimesh.instance_count))
	_assert("ponte tem anel e mesa válidos", is_instance_valid(game.holo_anel)
		and is_instance_valid(game.holo_root) and is_instance_valid(game.bridge_rig),
		"holo_anel, holo_root e bridge_rig presentes")
	_assert("motor da linha é bicomponente", _mat(game.fleet[0], "engine") != null
		and _mat(game.fleet[0], "flare") != null, "mats engine+flare por nave")

	# 2 — O céu não custa batalha: antes eram 1.040 sorteios de `rng` antes de a primeira nave
	# existir; hoje é `visual_rng` com semente cravada.
	var fora: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	fora.rng.seed = 987654321
	var sem_ceu := int(fora.rng.state)
	fora._build_environment()
	_assert("construir o céu não sorteia combate", int(fora.rng.state) == sem_ceu,
		"rng.state %d -> %d" % [sem_ceu, int(fora.rng.state)])
	fora.free()

	# 3 — A camada visual inteira é inerte para o RNG de batalha.
	var antes_visual := int(game.rng.state)
	for unit in game.fleet:
		game._tune_ship_look(unit)
	for unit in game.enemies:
		game._tune_ship_look(unit)
	game._rebuild_holo()
	game._update_bridge(0.016)
	game._spawn_bolt(Vector3(0, 0, -60), BLUE, Vector3(0, 0, -38), false)
	game._spawn_explosion(Vector3(0, 0, -60), ESCOAMENTO_ALIADO)
	_assert("camada visual não sorteia", int(game.rng.state) == antes_visual,
		"rng.state %d -> %d" % [antes_visual, int(game.rng.state)])

	# 4 — Orçamento de sorteio do traço: a salva aliada paga exatamente dois `randf_range(-1,1)`.
	var s0 := int(game.rng.state)
	game._spawn_bolt(Vector3(0, 0, -70), BLUE, Vector3(0, 0, -38))
	var s1 := int(game.rng.state)
	var espelho := RandomNumberGenerator.new()
	espelho.state = s0
	espelho.randf_range(-1, 1)
	espelho.randf_range(-1, 1)
	_assert("traço aliado custa exatamente 2 sorteios", int(espelho.state) == s1,
		"espelho=%d real=%d" % [int(espelho.state), s1])

	# 5 — O lance hostil anda no gerador visual, nunca no de combate.
	var rv0 := int(game.rng.state)
	var vv0 := int(game.visual_rng.state)
	game._spawn_bolt(Vector3(0, 0, -38), RED, Vector3(0, 0, -70), false)
	_assert("lance hostil não empurra a cauda de combate", int(game.rng.state) == rv0,
		"rng.state %d -> %d" % [rv0, int(game.rng.state)])
	_assert("lance hostil consome o gerador visual", int(game.visual_rng.state) != vv0,
		"visual_rng %d -> %d" % [vv0, int(game.visual_rng.state)])

	# 6 — A brasa acende na porta da abordagem e só ali. A porta é a mesma que `_give_order`
	# cobra (`hp > 55.0` recusa a captura), então 55 em cheio tem de estar aceso.
	var alvo: Dictionary = game.enemies[1]
	var mat_hull := _mat(alvo, "hull")
	alvo["hp"] = 100.0
	game._tune_ship_look(alvo)
	var intacto: Color = mat_hull.albedo_color
	alvo["hp"] = 56.0
	game._tune_ship_look(alvo)
	var energia_56 := mat_hull.emission_energy_multiplier
	alvo["hp"] = 55.0
	game._tune_ship_look(alvo)
	var energia_55 := mat_hull.emission_energy_multiplier
	_assert("casco a 56% ainda não pega brasa", energia_56 <= 0.0001, "energia %.4f" % energia_56)
	_assert("casco a 55% acende (porta de abordagem)", energia_55 >= 0.3, "energia %.4f" % energia_55)
	alvo["hp"] = 10.0
	game._tune_ship_look(alvo)
	_assert("a brasa desce com o casco que afunda",
		mat_hull.emission_energy_multiplier > energia_55, "energia %.4f -> %.4f"
		% [energia_55, mat_hull.emission_energy_multiplier])
	_assert("intacto é aço, não cor de nação", absf(intacto.r - ACO.r) < 0.02,
		"albedo %.3f/%.3f/%.3f" % [intacto.r, intacto.g, intacto.b])
	_assert("casco furado afunda no carvão", _distancia_cor(mat_hull.albedo_color, CARVAO)
		< _distancia_cor(intacto, CARVAO), "queimado=%.3f intacto=%.3f"
		% [_distancia_cor(mat_hull.albedo_color, CARVAO), _distancia_cor(intacto, CARVAO)])
	alvo["hp"] = 100.0
	game._tune_ship_look(alvo)

	# 7 — Motor e armamento viram leitura óptica.
	var aliada: Dictionary = game.fleet[0]
	aliada["engines"] = 100.0
	game._tune_ship_look(aliada)
	var mat_flare := _mat(aliada, "flare")
	var mat_bocal := _mat(aliada, "engine")
	var alfa_cheio := mat_flare.albedo_color.a
	var bocal_cheio := mat_bocal.emission_energy_multiplier
	aliada["engines"] = 0.0
	game._tune_ship_look(aliada)
	_assert("pluma encolhe com o motor", alfa_cheio > mat_flare.albedo_color.a,
		"alfa %.3f -> %.3f" % [alfa_cheio, mat_flare.albedo_color.a])
	_assert("bocal apaga com o motor", bocal_cheio > mat_bocal.emission_energy_multiplier,
		"energia %.2f -> %.2f" % [bocal_cheio, mat_bocal.emission_energy_multiplier])
	aliada["engines"] = 100.0
	aliada["weapons"] = 100.0
	game._tune_ship_look(aliada)
	var mat_gun := _mat(aliada, "gun")
	var torre_acesa := mat_gun.emission_energy_multiplier
	aliada["weapons"] = 0.0
	game._tune_ship_look(aliada)
	_assert("torre apaga sem armamento", torre_acesa > mat_gun.emission_energy_multiplier,
		"energia %.2f -> %.2f" % [torre_acesa, mat_gun.emission_energy_multiplier])
	aliada["weapons"] = 100.0
	game._tune_ship_look(aliada)

	# 8 — A peça de xadrez não se move: quem ondula é o filho.
	var raiz: Node3D = aliada["node"]
	var pos_raiz := raiz.position
	var filha: Node3D = _casco_of(aliada)
	var y_inicial := filha.position.y
	# A medição é a excursão máxima, não a última amostra: o ciclo fecha quase no mesmo ponto de
	# partida e comparar só o fim com o início lê como "não mexeu" exatamente quando mexeu.
	var excursao_maxima := 0.0
	var giro_maximo := 0.0
	for i in range(60):
		game.battle_clock = float(i) * 0.17
		game._tune_ship_look(aliada)
		excursao_maxima = maxf(excursao_maxima, absf(filha.position.y - y_inicial))
		giro_maximo = maxf(giro_maximo, absf(filha.rotation.z))
	_assert("raiz parada sob a animação visual", raiz.position == pos_raiz,
		"%s -> %s" % [str(pos_raiz), str(raiz.position)])
	_assert("silhueta ondula de fato", excursao_maxima > 0.05,
		"excursão do filho %.4f (amplitude pintada 0,1)" % excursao_maxima)
	_assert("silhueta aderna de fato", giro_maximo > 0.02, "rolagem %.4f" % giro_maximo)
	game.battle_clock = 0.0

	# 9 — Meia-volta: o hostil encara a linha; a presa reorienta e esfria o escapamento.
	var hostil: Node3D = game.enemies[2]["node"]
	_assert("hostil aponta a proa para a própria batalha", is_equal_approx(hostil.rotation.y, PI),
		"rotation.y=%.4f" % hostil.rotation.y)
	var presa: Dictionary = game.enemies[2]
	game._mark_as_prize(hostil)
	_assert("presa gira para a linha aliada", is_equal_approx(hostil.rotation.y, 0.0),
		"rotation.y=%.4f" % hostil.rotation.y)
	_assert("presa esfria o próprio escapamento",
		hostil.get_meta("escape") == ESCOAMENTO_ALIADO, "escape=%s" % str(hostil.get_meta("escape")))
	_assert("filete da presa vira azul", _mat(presa, "trim").albedo_color == BLUE.darkened(0.35),
		"albedo=%s" % str(_mat(presa, "trim").albedo_color))
	_assert("presa leva a marca dourada no Casco", _casco_of(presa).get_child_count() > 20,
		"%d billetes depois da incorporação" % _casco_of(presa).get_child_count())

	# 10 — Destroço: some a luz, não a nave; e o corpo morto continua parado.
	var alvo_morte: Dictionary = game.enemies[3]
	var casco_morto: Node3D = alvo_morte["node"]
	var pos_morta := casco_morto.position
	alvo_morte["hp"] = 0.0
	game._mark_wreck(casco_morto)
	_assert("destroço continua visível na ponte", casco_morto.visible,
		"visible=%s" % str(casco_morto.visible))
	_assert("destroço é carvão", _mat(alvo_morte, "hull").albedo_color == CARVAO,
		"albedo=%s" % str(_mat(alvo_morte, "hull").albedo_color))
	_assert("destroço apagou a pluma", is_zero_approx(_mat(alvo_morte, "flare").albedo_color.a),
		"alfa=%.3f" % _mat(alvo_morte, "flare").albedo_color.a)
	for i in range(20):
		game._update_fleet(0.1)
	_assert("destroço não anda um centímetro", casco_morto.position == pos_morta,
		"%s -> %s" % [str(pos_morta), str(casco_morto.position)])

	# 11 — A mesa não fabrica material por quadro.
	var id_material: int = game.mat_holo_aliado.get_instance_id()
	for i in range(3):
		game._update_bridge(0.016)
	_assert("blip reusa o mesmo material", game.mat_holo_aliado.get_instance_id() == id_material,
		"id %d -> %d" % [id_material, game.mat_holo_aliado.get_instance_id()])
	_assert("blip continua com o casco morto no ar", game.holo_blips.size() == 12,
		"%d blips" % game.holo_blips.size())

	# 12 — Prova central: dois jogos, mesma semente, a mesma batalha com a pintura nova.
	var a: Node3D = await _montar_jogo()
	var b: Node3D = await _montar_jogo()
	a.rng.seed = 20261020
	b.rng.seed = 20261020
	_alinhar(a)
	_alinhar(b)
	_zerar(a)
	_zerar(b)
	for cycle in range(8):
		a._update_fleet(0.1)
		b._update_fleet(0.1)
		a._update_probes(0.1)
		b._update_probes(0.1)
		a._resolve_volley()
		b._resolve_volley()
	_assert("a pintura não moveu número de combate", _assinatura(a) == _assinatura(b),
		"assinaturas idênticas em %d caracteres" % _assinatura(a).length())
	_assert("cauda de RNG intacta com a camada visual", int(a.rng.state) == int(b.rng.state),
		"A=%d B=%d" % [int(a.rng.state), int(b.rng.state)])
	_assert("rotação da capitânia hostil igual nos dois lados",
		(a.enemies[0]["node"] as Node3D).rotation.y == (b.enemies[0]["node"] as Node3D).rotation.y,
		"rot A=%.4f B=%.4f" % [(a.enemies[0]["node"] as Node3D).rotation.y,
			(b.enemies[0]["node"] as Node3D).rotation.y])
	var ceus_a := _starfield(a)
	var ceus_b := _starfield(b)
	_assert("céu estrelado determinístico entre os dois jogos", ceus_a != null and ceus_b != null
		and ceus_a.multimesh.get_instance_transform(0) == ceus_b.multimesh.get_instance_transform(0)
		and ceus_a.multimesh.get_instance_color(7) == ceus_b.multimesh.get_instance_color(7),
		"transform(0) e color(7) idênticos")
	_assert("a corrida A/B não foi medida em tabuleiro vazio", _assinatura(a).length() > 100
		and _somar_casco(a) > 0.0, "soma de cascos %.1f" % _somar_casco(a))

	for line in notes:
		print("SONDA-GRAFICOS: %s" % line)
	print("SONDA-GRAFICOS: veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	quit()
