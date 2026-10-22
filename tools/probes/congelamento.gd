extends SceneTree

## Sonda do instrumento, não do jogo: o que «congelar o tabuleiro» significa numa prova, e por que a
## mesma linha de código congela num momento e não congela em outro.
##
## Toda sonda de inércia e toda corrida A/B deste repositório depende de pôr dois tabuleiros no
## MESMO ponto e largá-los de lá. Se o «tabuleiro parado» ainda anda, a divergência medida não é da
## mecânica testada — é do agendamento do próprio teste, e ela passa verde exatamente igual. Foi
## assim que a assinatura de dois jogos «idênticos» divergiu em 0,098 de motor do ALIADA 01: um dos
## tabuleiros rodava `main.gd::_process` enquanto o outro não deveria rodar nada.
##
## A lei medida aqui, e é ela que as outras sondas têm de obedecer:
##
## 1) DENTRO DE `_initialize`, `add_child` NÃO completa o `_ready`. `is_node_ready()` lê falso logo
##    depois da chamada e só vira verdadeiro passados alguns quadros. Nessa janela,
##    `set_process(false)` é engolido: o motor de script reinstala o processamento dele mesmo ao
##    entrar na árvore, `is_processing()` relê `true` no fim e o relógio anda.
## 2) COM O NÓ PRONTO, a mesma chamada segura: relógio, cadência, motor e os dois geradores ficam
##    dígito a dígito, e a bandeira lê `false`. Ou seja, `is_processing()` discrimina os dois casos
##    de `set_process` — é o instrumento certo para eles.
## 3) `process_mode = Node.PROCESS_MODE_DISABLED` segura em QUALQUER posição, antes ou depois do
##    `_ready`, e é por isso que ele é o congelamento da casa. A cilada é que a bandeira continua
##    lendo `true` num tabuleiro morto: `is_processing()` não é prova de congelamento por modo, só
##    o relógio é.
##
## O motor plantado é a asserção que não dá para fingir: reparo automático é fatura de `delta`, então
## um casco a 76,000 que acorda em 76,344 denuncia processo rodando mesmo sem ninguém ler o relógio.
## E o sorteio é da salva, não do quadro: quarenta quadros ociosos não movem gerador nenhum (medido).
## Por isso a prova de contaminação espera o `fire_clock` virar — é ali que a cauda do `rng` e do
## `visual_rng` anda, e é exatamente ela que uma corrida A/B compara.
##
## Fecha com a mesa: num tabuleiro morto o `_process` não vem, e a holografia é refeita por
## `_update_bridge` — chamado só de lá. A sonda move um casco à mão, cobra o blip velho, chama a
## ponte à mão e cobra o blip em dia sem sorteio nenhum. A conta de blips é das DUAS esquadras
## (`fleet` + `enemies`), não dos cascos vivos aliados: quem confunde as duas medidas reprova uma
## mesa que está correta.
##
## Uso: godot --headless --path . --quit-after 6000 -s res://tools/probes/congelamento.gd

## Motor plantado abaixo do teto de reparo: se ele subir, foi `delta`, não coincidência.
const MOTOR_PLANTADO := 76.0
## Casco a 500 num teto de 100 por esquadrão — o reparo automático sobe de qualquer lado.
const CASCA_PLANTADA := 500.0
const QUADROS := 40
## Teto de espera pela salva: 400 quadros a ~156 fps cobrem os 1,6 s de cadência com folga.
const QUADROS_LIMITE := 400
const PASSO_ESPERADO := 0.0
## Desvio de campo que a mesa tem de acompanhar: 3 u viram ~0,225 u de disco em `HOLO_ESCALA`.
const DESLOCADO := Vector3(0.0, 0.0, -3.0)

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

## Monta uma ponte, aplica a congelação no momento pedido e planta os números que a asserção lê.
## `antes` = ordem dada na janela de `_initialize`; `depois` = ordem dada com o nó pronto.
func _montar(por_modo: bool, antes: bool) -> Dictionary:
	var game: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	var pronto_no_chamado := game.is_node_ready()
	var pronto_no_congelamento := pronto_no_chamado
	if antes:
		_congelar(game, por_modo)
	await _frames(3)
	var pronto_tres_quadros := game.is_node_ready()
	if not antes:
		pronto_no_congelamento = game.is_node_ready()
		_congelar(game, por_modo)
	_plantar(game)
	return {"game": game, "pronto_no_chamado": pronto_no_chamado,
		"pronto_tres_quadros": pronto_tres_quadros,
		"pronto_no_congelamento": pronto_no_congelamento}

func _congelar(game: Node3D, por_modo: bool) -> void:
	if por_modo:
		game.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		game.set_process(false)

func _plantar(game: Node3D) -> void:
	for i in range(game.fleet.size()):
		game.fleet[i]["hp"] = CASCA_PLANTADA
		game.fleet[i]["engines"] = MOTOR_PLANTADO
		game.fleet[i]["weapons"] = 95.0
		game.fleet[i]["crew"] = 100.0
		game.fleet[i]["veloc"] = Vector3.ZERO

func _estado(game: Node3D) -> Dictionary:
	return {
		"clock": float(game.battle_clock),
		"fire": float(game.fire_clock),
		"motor": float(game.fleet[0]["engines"]),
		"casca": float(game.fleet[0]["hp"]),
		"rng": int(game.rng.state),
		"visual": int(game.visual_rng.state),
		"flag": bool(game.is_processing()),
	}

func _delta_clock(depois: Dictionary, antes: Dictionary) -> float:
	return float(depois["clock"]) - float(antes["clock"])

func _initialize() -> void:
	# ---- 1. A ordem dada na janela de `_initialize` não congela ------------------------------
	var a: Dictionary = await _montar(false, true)
	var jogo_a: Node3D = a["game"]
	_assert("`add_child` não completa `_ready` dentro de `_initialize`",
		not bool(a["pronto_no_chamado"]) and bool(a["pronto_tres_quadros"]),
		"is_node_ready()=%s logo após add_child, %s depois de 3 quadros"
			% [str(a["pronto_no_chamado"]), str(a["pronto_tres_quadros"])])
	var a_antes := _estado(jogo_a)
	await _frames(QUADROS)
	var a_depois := _estado(jogo_a)
	_assert("aí, `set_process(false)` é engolido: o relógio anda",
		_delta_clock(a_depois, a_antes) > 0.0,
		"battle_clock %0.4f -> %0.4f em %d quadros"
			% [a_antes["clock"], a_depois["clock"], QUADROS])
	_assert("a cadência da salva anda junto",
		float(a_depois["fire"]) > float(a_antes["fire"]),
		"fire_clock %0.4f -> %0.4f" % [a_antes["fire"], a_depois["fire"]])
	_assert("e o motor plantado sobe: é assim que um A/B «idêntico» diverge",
		float(a_depois["motor"]) > MOTOR_PLANTADO,
		"motor %0.4f -> %0.4f com casco a %0.1f"
			% [MOTOR_PLANTADO, a_depois["motor"], a_depois["casca"]])
	_assert("e a bandeira confirma a ordem perdida — ela lê `true`",
		bool(a_depois["flag"]),
		"is_processing()=%s depois de %d quadros de um `set_process(false)` ignorado"
			% [str(a_depois["flag"]), QUADROS])
	# Numa janela ociosa de 40 quadros nenhum dos dois geradores anda: o sorteio da casa é da salva,
	# não do quadro. Então a prova de que o tabuleiro «parado» contamina um A/B tem de esperar a
	# salva sair — e é ela que move a cauda que a corrida compara.
	var gen_antes := _estado(jogo_a)
	var fire_prev := float(jogo_a.fire_clock)
	var quadros_ate_salva := 0
	var salva_saiu := false
	while quadros_ate_salva < QUADROS_LIMITE:
		await process_frame
		quadros_ate_salva += 1
		var fire_now := float(jogo_a.fire_clock)
		if fire_now < fire_prev - 0.5:
			salva_saiu = true
			break
		fire_prev = fire_now
	var gen_depois := _estado(jogo_a)
	_assert("e a salva sai: o tabuleiro que o teste julgava parado dispara",
		salva_saiu,
		"fire_clock virou depois de %d quadros reais (limite %d)"
			% [quadros_ate_salva, QUADROS_LIMITE])
	_assert("e gasta os dois geradores — é assim que a cauda de um A/B diverge",
		int(gen_depois["rng"]) != int(gen_antes["rng"])
		and int(gen_depois["visual"]) != int(gen_antes["visual"]),
		"rng %d -> %d • visual %d -> %d" % [gen_antes["rng"], gen_depois["rng"],
			gen_antes["visual"], gen_depois["visual"]])

	# ---- 2. A mesma ordem, com o nó pronto, segura --------------------------------------------
	var b: Dictionary = await _montar(false, false)
	var jogo_b: Node3D = b["game"]
	_assert("com o nó pronto a ordem é a mesma linha e o destino é outro",
		bool(b["pronto_no_congelamento"]),
		"is_node_ready()=%s no momento do `set_process(false)`" % str(b["pronto_no_congelamento"]))
	var b_antes := _estado(jogo_b)
	await _frames(QUADROS)
	var b_depois := _estado(jogo_b)
	_assert("o relógio não anda um quadro",
		_delta_clock(b_depois, b_antes) <= PASSO_ESPERADO,
		"battle_clock %0.4f -> %0.4f em %d quadros"
			% [b_antes["clock"], b_depois["clock"], QUADROS])
	_assert("o motor plantado não sobe: reparo automático é fatura de delta",
		absf(float(b_depois["motor"]) - MOTOR_PLANTADO) <= PASSO_ESPERADO,
		"motor %0.4f -> %0.4f" % [MOTOR_PLANTADO, b_depois["motor"]])
	_assert("nenhum dos dois geradores anda",
		int(b_depois["rng"]) == int(b_antes["rng"])
		and int(b_depois["visual"]) == int(b_antes["visual"]),
		"rng %d / visual %d nos mesmos números" % [b_depois["rng"], b_depois["visual"]])
	# Mesmo orçamento de quadros do tabuleiro que disparou: é a comparação que um A/B precisa.
	await _frames(quadros_ate_salva)
	var b_salva := _estado(jogo_b)
	_assert("e no MESMO orçamento de quadros da salva o congelamento a sério não gasta um sorteio",
		int(b_salva["rng"]) == int(b_antes["rng"])
		and int(b_salva["visual"]) == int(b_antes["visual"])
		and _delta_clock(b_salva, b_antes) <= PASSO_ESPERADO,
		"%d quadros depois: rng %d / visual %d / clock %0.4f" % [quadros_ate_salva,
			b_salva["rng"], b_salva["visual"], b_salva["clock"]])
	_assert("e aqui `is_processing()` discrimina: lê `false`",
		not bool(b_depois["flag"]),
		"falso congelamento=%s contra congelamento a sério=%s — a mesma flag separa os dois `set_process`"
			% [str(a_depois["flag"]), str(b_depois["flag"])])

	# ---- 3. O congelamento da casa vale nas duas posições --------------------------------------
	var c: Dictionary = await _montar(true, true)
	var morto: Node3D = c["game"]
	var c_antes := _estado(morto)
	await _frames(QUADROS)
	var c_depois := _estado(morto)
	_assert("`process_mode DISABLED` dado antes do `_ready` segura",
		_delta_clock(c_depois, c_antes) <= PASSO_ESPERADO
		and absf(float(c_depois["motor"]) - MOTOR_PLANTADO) <= PASSO_ESPERADO,
		"battle_clock %0.4f -> %0.4f • motor %0.4f -> %0.4f"
			% [c_antes["clock"], c_depois["clock"], MOTOR_PLANTADO, c_depois["motor"]])
	var d: Dictionary = await _montar(true, false)
	var jogo_d: Node3D = d["game"]
	var d_antes := _estado(jogo_d)
	await _frames(QUADROS)
	var d_depois := _estado(jogo_d)
	_assert("dado com o nó pronto, segura igual — o modo não depende da prontidão",
		_delta_clock(d_depois, d_antes) <= PASSO_ESPERADO
		and absf(float(d_depois["motor"]) - MOTOR_PLANTADO) <= PASSO_ESPERADO,
		"battle_clock %0.4f -> %0.4f • motor %0.4f -> %0.4f"
			% [d_antes["clock"], d_depois["clock"], MOTOR_PLANTADO, d_depois["motor"]])
	_assert("mas a bandeira NÃO é instrumento do modo: lê `true` num tabuleiro morto",
		bool(c_depois["flag"]) and bool(d_depois["flag"]),
		"is_processing()=%s e %s com relógios parados — quem decide é o `battle_clock`"
			% [str(c_depois["flag"]), str(d_depois["flag"])])

	# ---- 4. A mesa do tabuleiro morto, refeita à mão -------------------------------------------
	var total: int = morto.fleet.size() + morto.enemies.size()
	_assert("a conta de blips é das duas esquadras, não dos cascos vivos aliados",
		int(morto.holo_blips.size()) == total,
		"%d blips para %d aliadas + %d hostis" % [morto.holo_blips.size(),
			morto.fleet.size(), morto.enemies.size()])
	var casco: Dictionary = morto.fleet[0]
	var nodo: Node3D = casco["node"]
	nodo.position += DESLOCADO
	var ping: MeshInstance3D = morto.holo_blips[nodo.get_instance_id()]
	var alvo: Vector3 = morto._holo_de(nodo.position)
	var velho := ping.position.distance_to(alvo)
	var rng_ponte_antes := int(morto.rng.state)
	var visual_ponte_antes := int(morto.visual_rng.state)
	morto._update_bridge(0.0)
	var novo := ping.position.distance_to(alvo)
	_assert("sem `_process`, o blip continua velho: a ponte não se refaz sozinha",
		velho > 0.1,
		"desvio %0.4f u de mesa depois de %0.1f u de campo" % [velho, DESLOCADO.z])
	_assert("e `_update_bridge(0.0)` chamado à mão põe o blip em dia",
		novo < 0.0001,
		"desvio %0.4f -> %0.4f u, mesmo ponto de `_holo_de`" % [velho, novo])
	_assert("e a chamada não sorteia um dígito de nada",
		int(morto.rng.state) == rng_ponte_antes
		and int(morto.visual_rng.state) == visual_ponte_antes,
		"rng %d / visual %d antes e depois de `_update_bridge`"
			% [int(morto.rng.state), int(morto.visual_rng.state)])
	_assert("nem o número de corpos da mesa muda com a ponte refeita",
		int(morto.holo_blips.size()) == total,
		"%d blips antes e depois, %d cascos nas duas listas" % [morto.holo_blips.size(), total])

	for linha in notes:
		print(linha)
	print("SONDA-CONGELAMENTO: veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	quit()
