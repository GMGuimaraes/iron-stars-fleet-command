extends SceneTree

## Sonda da bateria de mísseis: o encouraçado que troca canhão por carga, e uma escada que desce
## exatamente pelo mesmo caminho por que subiu.
##
## O pedido do comandante foi «encouraçados que lançam mísseis». Míssil que só desenha um traço a
## mais no visor não atende ao pedido, então esta peça cobra as cinco consequências que fazem da
## classe uma classe e não uma pintura:
##
## 1) A ESCADA É REVERSÍVEL. A classe não soma estado: `armas`, `velocidade` e `missoes` são lidos
##    da tabela no instante em que a salva ou o quadro precisam deles, e promover e rebaixar andam
##    pelo mesmo laço, do índice 0 ao fim do cadastro. Subir dois degraus e descer dois devolve o
##    tabuleiro dígito a dígito — medido contra um jogo que nunca encostou no painel.
## 2) LINHA PURA NÃO MOVE NÚMERO. Com a escada em zero, multiplicar por 1,0 é exatamente não
##    multiplicar: `salva_contagem`, `rng.state` e `visual_rng.state` batem com o controle e
##    nenhum corpo de míssil nasce. Sem a guarda das cargas isto seria mais uma sonda aprovando
##    por ausência.
## 3) A BATERIA NÃO SORTEIA. O dano é conta fechada (posição, tabela, disco), então o gerador de
##    combate gasta os MESMOS sorteios com quatro encouraçados atirando e com linha pura. É a
##    asserção que separa canal novo de reroll disfarçado — e ela só vale com ninguém morrendo na
##    janela, porque casco perdido muda a quantidade de salvas hostis e, com ela, a conta de
##    sorteios. Por isso os cascos sobem a 500 antes da corrida.
## 4) VOO DE FORMA FECHADA, como as luas: `battle_clock − nascido` dividido pelo tempo de
##    travessia. Quarenta quadros de 0,1 s contra quatro de 1,0 s entregam o mesmo casco, o mesmo
##    contador e o mesmo ponto de detonação.
## 5) O DISCO ESCOLHE QUEM PAGA. Centro no ponto é dano cheio, 4,2 u é exatamente metade, 6,0 u é
##    zero e nem entra na conta. É o «espaço onde algumas naves podem ou não ser atingidas» que o
##    comandante pediu, resolvido por geometria e não por sorteio — e o mesmo disco que abre no
##    DISPERSAR abre o leque da bateria, porque o míssil usa os pontos da própria salva.
##
## E a barreira, que é a lei da casa: o míssil atravessa o tabuleiro em corda reta, mas a pedra é
## relida na CHEGADA, não no lançamento. Com o teto de deriva a 4,2 u/s, uma rocha anda até doze
## unidades enquanto a carga caminha — fixar o corredor no lançamento seria mentir sobre o
## cinturão. Medido nos dois lados: pedra na corda na chegada para o lance e racha; pedra que saiu
## da corda deixa o disco cair no casco. Planeta e lua param sem rachar, porque corpo inteiro não
## parte.
##
## Uso: godot --headless --path . --quit-after 6000 -s res://tools/probes/misseis.gd

## Espelho das constantes de `main.gd` — a instância do jogo é não tipada (mesmo motivo em
## `tools/probes/sistema.gd`). Mudar o número lá quebra a asserção aqui: é de propósito.
const HULL_RADIUS := 2.4
const FLECHAS_POR_SALVA := 3
const FOGO_RAIO := [4.5, 14.0, 28.0]
const MISSIL_VELOCIDADE := 18.0
const MISSIL_RAIO := 6.0
const MISSIL_FATOR := 2.2
const ENCORACADOS_TETO := 4
const ROCHA_INTEGRIDADE_POR_RAIO := 6.0
const PASSO := 0.1
## Tolerância de float32 lida de volta do motor: perto de 80 u o ulp é ~7,6e-6.
const FOLGA := 0.00005
## Nove grupos desde a escada de encouraçados; ARMAMENTO tem quatro botões porque são duas escadas
## de casco na mesma categoria — bateria e convés — cada uma com o degrau que sobe e o que desce, e
## não existe degrau de «escolher o navio»: a classe é do casco, não da ordem.
const NOMES_GRUPOS := ["ATAQUE", "POSTURA", "FORMAÇÕES", "MANOBRA", "ARMAMENTO", "REPAROS",
	"RECONHECIMENTO", "CENÁRIO", "TRILHA"]
const TAMANHOS := {"ATAQUE": 4, "POSTURA": 5, "FORMAÇÕES": 4, "MANOBRA": 3, "ARMAMENTO": 4,
	"REPAROS": 5, "RECONHECIMENTO": 1, "CENÁRIO": 5, "TRILHA": 4}

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

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _montar_jogo() -> Node3D:
	var game: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	# Congelar o `_process` do jogo ANTES dos três quadros: sem isto, cada montagem leva um tempo
	# real diferente de locomoção, de IA hostil e de `fire_clock`, e dois tabuleiros "idênticos"
	# largam de estados diferentes. É o que faz a prova A/B medir a escada em vez de medir o
	# agendamento do teste — e é por isso que a sonda chama cada função de jogo na mão.
	#
	# O congelamento é por `process_mode`, nunca por `set_process(false)`: dado dentro de
	# `_initialize`, esse `set_process` é engolido porque `add_child` ainda não completou o `_ready`,
	# o relógio continua andando e o reparo automático sobe o motor por `delta`. A lei é medida em
	# `tools/probes/congelamento.gd`. Como a mesa é refeita por `_update_bridge`, chamado só do
	# `_process`, a ponte também é chamada à mão uma vez por montagem.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(3)
	game._update_bridge(0.0)
	return game

func _alinhar(game) -> void:
	for i in range(game.fleet.size()):
		(game.fleet[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 5.0, 0.0, -38.0)
	for i in range(game.enemies.size()):
		(game.enemies[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 6.0, 0.0, -82.0)

## Blindagem de laboratório: 500 de casco em todo corpo. Não é truque de conveniência — é a
## condição de validade da asserção de RNG: morto um casco, muda o número de salvas hostis e, com
## ele, a quantidade de sorteios. Aí a cauda divergiria por estrutura, não pela bateria, e a
## medição não provaria nada.
func _blindar(game) -> void:
	for list in [game.fleet, game.enemies]:
		for unit in list:
			unit["hp"] = 500.0
			unit["engines"] = 100.0
			unit["weapons"] = 100.0
			unit["crew"] = 100.0
			unit["veloc"] = Vector3.ZERO
	game.capital_hp = 100.0
	game.batalha_encerrada = false

func _hostis_somados(game) -> float:
	var total := 0.0
	for unit in game.enemies:
		total += float(unit["hp"])
	return total

## Assinatura de combate dos dois lados da corrida: só números de cadstro, nenhum de pintura.
func _assinatura(game) -> String:
	var partes: Array[String] = []
	for list in [game.fleet, game.enemies]:
		for unit in list:
			var no: Node3D = unit["node"]
			partes.append("%s:%0.3f/%0.3f/%0.3f@%0.3f,%0.3f,%0.3f" % [unit["name"],
				float(unit["hp"]), float(unit["engines"]), float(unit["weapons"]),
				no.position.x, no.position.y, no.position.z])
	return "|".join(partes)

func _botoes(game, nome: String) -> Array[Button]:
	var lista: Array[Button] = []
	var corpo: Control = game.group_bodies[nome]
	for filho in corpo.get_children():
		if filho is Button:
			lista.append(filho as Button)
	return lista

func _botao(game, nome: String, texto: String) -> Button:
	for b in _botoes(game, nome):
		if String(b.text).find(texto) == 0:
			return b
	return null

## Quantos cascos do cadastro têm o nó de bateria montado — leitura de cena, não de dicionário.
func _baterias_na_cena(game) -> int:
	var total := 0
	for unit in game.fleet:
		var no: Node3D = unit["node"]
		if is_instance_valid(no) and no.get_node_or_null("Bateria") != null:
			total += 1
	return total

## Míssil de laboratório: corda e dano na mão, sem depender da salva para poder medir o disco e a
## barreira isolados. `nascido` fica no relógio corrente do jogo, exatamente como no lance real.
func _disparar(game, origem: Vector3, destino: Vector3, dano: float) -> Dictionary:
	var antes := int(game.misseis.size())
	game._lancar_missil(origem, destino, dano)
	if int(game.misseis.size()) == antes:
		return {}
	return game.misseis[game.misseis.size() - 1]

## Avança o relógio do jogo em passos e roda o voo, sem tocar frota, salva nem cenário: é o laço
## que a corrida de taxa de quadro usa para comparar 0,1 s com 1,0 s.
func _voar(game, passos: int, dt: float) -> void:
	for i in range(passos):
		game.battle_clock += dt
		game._atualizar_misseis()

## Avança até a última carga detonar, com teto. O passo de uma medição de disco tem de vir do
## comprimento da corda, não de um palpite: a corda de laboratório aqui tem ~102 u, tau de 5,7 s,
## e quarenta passos de 0,1 s liam o voo pela metade — o zero aparecia como «o disco não feriu».
## O teto existe para uma corda bloqueada por astro nunca mover o tabuleiro para sempre.
func _voar_ate_o_fim(game, teto: int, dt: float) -> void:
	for i in range(teto):
		if int(game.misseis.size()) == 0:
			return
		game.battle_clock += dt
		game._atualizar_misseis()

## ---- 1. Linha pura: a escada em zero não move um dígito ---------------------------------------
func _secao_inercia() -> void:
	var game: Node3D = await _montar_jogo()
	_alinhar(game)
	_blindar(game)
	game.rng.seed = 60606
	game.battle_clock = 0.0
	game.selected_target = 0
	_assert("a partida acorda em linha pura", int(game.encoracados) == 0 and int(game.misseis.size()) == 0,
		"escada %d, %d mísseis em voo" % [game.encoracados, game.misseis.size()])
	var classes_boas := true
	for unit in game.fleet:
		if String(unit.get("classe", "AUSENTE")) != "CRUZADOR":
			classes_boas = false
	_assert("todo casco do cadastro é cruzador", classes_boas and game.fleet.size() == 6,
		"%d cascos, todos CRUZADOR" % game.fleet.size())
	_assert("o cadastro de fora da escada lê cruzador",
		game._classe_de({}) == "CRUZADOR" and game._classe_de({"classe": "PORTA-AVIOES"}) == "CRUZADOR"
			and _igual(game._fator_classe({}, "armas"), 1.0, 0.0),
		"dicionário vazio e classe inexistente caem na linha")
	_assert("cruzador não tem carga de bateria",
		int(game._missoes_por_salva(game.fleet[0])) == 0, "0 cargas")
	_assert("nenhum casco tem bateria montada", _baterias_na_cena(game) == 0, "0 nós Bateria")
	# A prova de inércia não pode ser «a salva não sorteia»: a salva sorteia por projeto, e o
	# gerador anda em qualquer salva. O que se cobra é o par — um jogo que subiu e desceu a escada
	# pelo painel fecha a MESMA salva do mesmo seed com o mesmo consumo dos dois geradores, o mesmo
	# casco pago e o mesmo resumo que um jogo que nunca encostou no ARMAMENTO. O laço de classe
	# roda nos dois, lê a tabela e multiplica por 1,0, que é a única forma de a escada ser inerte
	# sem um `if` de exceção espalhado pelo código da salva.
	game._ajustar_encoracados(ENCORACADOS_TETO)
	game._ajustar_encoracados(-ENCORACADOS_TETO)
	_assert("ida e volta pela escada não deixa rastro nem silhueta",
		int(game.encoracados) == 0 and _baterias_na_cena(game) == 0
			and String(game.fleet[0]["classe"]) == "CRUZADOR",
		"escada %d, %d nós Bateria depois do ida e volta" % [game.encoracados, _baterias_na_cena(game)])
	var controle: Node3D = await _montar_jogo()
	_alinhar(controle)
	_blindar(controle)
	controle.rng.seed = 60606
	controle.battle_clock = 0.0
	controle.selected_target = 0
	var casco_a := _hostis_somados(game)
	var casco_b := _hostis_somados(controle)
	game._resolve_volley()
	controle._resolve_volley()
	_assert("a salva de linha pura não pôs míssil no tabuleiro",
		int(game.misseis.size()) == 0 and int(game.missil_contagem["lancados"]) == 0,
		"%d em voo, %d lançados" % [game.misseis.size(), game.missil_contagem["lancados"]])
	_assert("o resumo da salva não menciona bateria",
		String(game.salva_resumo).find("bateria") < 0, String(game.salva_resumo))
	var conta_zero := int(game.missil_contagem["detonados"]) == 0 \
		and int(game.missil_contagem["bloqueados"]) == 0 \
		and int(game.missil_contagem["cascos"]) == 0 \
		and _igual(float(game.missil_contagem["dano"]), 0.0, 0.0)
	_assert("a conta da bateria inteira fica em zero", conta_zero,
		"%s" % str(game.missil_contagem))
	var pago_a := casco_a - _hostis_somados(game)
	var pago_b := casco_b - _hostis_somados(controle)
	_assert("multiplicar por 1,0 é exatamente não multiplicar",
		int(game.rng.state) == int(controle.rng.state)
			and int(game.visual_rng.state) == int(controle.visual_rng.state)
			and _igual(pago_a, pago_b, 0.0)
			and String(game.salva_resumo) == String(controle.salva_resumo),
		"rng %d/%d, visual %d/%d, casco pago %0.3f/%0.3f" % [game.rng.state, controle.rng.state,
			game.visual_rng.state, controle.visual_rng.state, pago_a, pago_b])

## ---- 2. A escada sobe, e o gerador não sente --------------------------------------------------
func _secao_escada() -> void:
	var game: Node3D = await _montar_jogo()
	_alinhar(game)
	_blindar(game)
	game.rng.seed = 60606
	game.selected_target = 0
	var rng_inicial: int = game.rng.state
	var visual_inicial: int = game.visual_rng.state
	game._ajustar_encoracados(1)
	game._ajustar_encoracados(-1)
	_assert("subir e descer um degrau pelo painel não sorteia um dígito",
		int(game.rng.state) == rng_inicial and int(game.visual_rng.state) == visual_inicial,
		"depois de +1 e −1: %d / %d" % [game.rng.state, game.visual_rng.state])
	# Cadastro: a escada veste os cascos da FRENTE, na ordem do cadastro, e nada além deles.
	game.encoracados = 2
	game._aplicar_classes()
	var ordem_boa := true
	for i in range(game.fleet.size()):
		var esperado := "BATALHA" if i < 2 else "CRUZADOR"
		if String(game.fleet[i]["classe"]) != esperado:
			ordem_boa = false
	_assert("os dois primeiros cascos do cadastro viram linha de batalha", ordem_boa,
		"%s" % str([game.fleet[0]["classe"], game.fleet[1]["classe"], game.fleet[2]["classe"],
			game.fleet[5]["classe"]]))
	_assert("bateria monta o nó de silhueta", _baterias_na_cena(game) == 2, "2 nós Bateria")
	var corpo_bateria: Node3D = (game.fleet[0]["node"] as Node3D).get_node("Bateria")
	_assert("a bateria são dois blocos e seis tubos", corpo_bateria.get_child_count() == 8,
		"%d corpos na bateria" % corpo_bateria.get_child_count())
	var casco: Node3D = (game.fleet[0]["node"] as Node3D).get_node("Casco")
	_assert("o filho Casco continua com os vinte billetes de linha", casco.get_child_count() == 20,
		"%d billetes" % casco.get_child_count())
	var escala := (game.fleet[0]["node"] as Node3D).scale
	_assert("promover não escala o corpo", _igual(escala.x, 1.1, FOLGA) and _igual(escala.y, 1.1, FOLGA),
		"escala %s (raio de colisão é HULL_RADIUS, número de cadastro)" % str(escala))
	# Desce tudo: o quadro tem de voltar ao de antes, inclusive a silhueta.
	game.encoracados = 0
	game._aplicar_classes()
	await _frames(2)
	_assert("descer dois degraus devolve a linha inteira",
		_baterias_na_cena(game) == 0 and String(game.fleet[0]["classe"]) == "CRUZADOR",
		"%d nós Bateria depois de recolher" % _baterias_na_cena(game))
	_assert("e o multiplicador volta a ser exatamente um",
		_igual(game._fator_classe(game.fleet[0], "armas"), 1.0, 0.0)
			and _igual(game._fator_classe(game.fleet[0], "velocidade"), 1.0, 0.0)
			and int(game._missoes_por_salva(game.fleet[0])) == 0,
		"armas 1,0 marcha 1,0 cargas 0")
	# Sobe de novo e mede o preço na função nomeada, não em casco alheio.
	game.encoracados = 2
	game._aplicar_classes()
	var dano_cruzador := 2.5 * float(game.fleet[2]["weapons"]) / 100.0 * maxf(0.25, float(game.fleet[2]["crew"]) / 100.0)
	var dano_batalha: float = game._dano_de_canhao(game.fleet[0])
	_assert("a bateria come exatamente 0,6 do canhão",
		_igual(dano_batalha, dano_cruzador * 0.6, 0.0000001) and _igual(dano_cruzador, 2.5, FOLGA),
		"%0.4f contra %0.4f de fogo de linha" % [dano_batalha, dano_cruzador])
	_assert("cada encouraçado põe duas cargas na salva",
		int(game._missoes_por_salva(game.fleet[0])) == 2
			and int(game._missoes_por_salva(game.fleet[3])) == 0, "2 e 0 cargas")
	# Isolando a salva num casco só, o disco de 4,5 u e a ordem ATACAR: o que o alvo perde de casco
	# é a única régua que o jogador tem, e ela tem de bater com a função.
	for i in range(1, game.fleet.size()):
		game.fleet[i]["weapons"] = 0.0
	for i in range(1, game.enemies.size()):
		(game.enemies[i]["node"] as Node3D).position = Vector3(60.0 + float(i) * 30.0, 0.0, -82.0)
	game.fogo_densidade = 0
	game._give_order("ATACAR")
	game.battle_clock = 0.0
	var alvo_casco: float = game.enemies[0]["hp"]
	game._resolve_volley()
	var esperado := dano_batalha * 1.8
	var perdido := alvo_casco - float(game.enemies[0]["hp"])
	_assert("a salva do encouraçado fere o casco pela fórmula nomeada",
		_igual(perdido, esperado, 0.0001), "%0.4f de casco contra %0.4f previstos" % [perdido, esperado])
	_assert("e a mesma salva pôs duas cargas em voo",
		int(game.misseis.size()) == 2 and int(game.missil_contagem["lancados"]) == 2,
		"%d em voo, %d lançados" % [game.misseis.size(), game.missil_contagem["lancados"]])
	_assert("o canhão não abriu mais lances por causa da bateria",
		int(game.salva_contagem["aliados"]) == FLECHAS_POR_SALVA,
		"%d impactos de canhão" % int(game.salva_contagem["aliados"]))
	# O que se mede aqui é o voo, não a salva — a salva sorteia por projeto e o gerador anda em
	# qualquer salva. Fecha o estado dos geradores logo depois do lançamento, deixa as duas cargas
	# traversarem e cobra o mesmo estado, com a chegada provada por contador: sem a asserção de
	# detonação isto seria mais um verde por ausência.
	var rng_do_voo: int = game.rng.state
	var visual_do_voo: int = game.visual_rng.state
	var chegadas_antes := int(game.missil_contagem["detonados"]) \
		+ int(game.missil_contagem["bloqueados"])
	_voar_ate_o_fim(game, 80, PASSO)
	var chegadas := int(game.missil_contagem["detonados"]) + int(game.missil_contagem["bloqueados"]) \
		- chegadas_antes
	_assert("o voo não sorteou um dígito do combate nem do visual",
		int(game.rng.state) == rng_do_voo and int(game.visual_rng.state) == visual_do_voo
			and chegadas > 0 and int(game.misseis.size()) == 0,
		"rng %d para %d, visual %d para %d, %d cargas chegaram na travessia" % [rng_do_voo,
			game.rng.state, visual_do_voo, game.visual_rng.state, chegadas])

## ---- 3. O painel: nove grupos, trinta e cinco comandos, dois degraus --------------------------
func _secao_painel() -> void:
	var game: Node3D = await _montar_jogo()
	_alinhar(game)
	_blindar(game)
	_assert("nove grupos no painel", game.group_heads.size() == 9 and game.group_bodies.size() == 9,
		"%d cabeçalhos / %d corpos" % [game.group_heads.size(), game.group_bodies.size()])
	var faltam := ""
	for nome in NOMES_GRUPOS:
		if not game.group_bodies.has(nome):
			faltam += nome + " "
	_assert("os nove nomes pedidos existem", faltam == "", "faltando: [%s]" % faltam)
	var medido := ""
	var total := 0
	var tamanhos_ok := true
	for nome in NOMES_GRUPOS:
		var n := _botoes(game, nome).size()
		total += n
		medido += "%s=%d " % [nome, n]
		if n != int(TAMANHOS[nome]):
			tamanhos_ok = false
	_assert("cada grupo carrega os comandos que promete", tamanhos_ok, medido)
	_assert("trinta e cinco comandos agrupados", total == 35, "%d botões de comando" % total)
	_assert("ARMAMENTO nasce fechado", not (game.group_bodies["ARMAMENTO"] as Control).visible
		and (game.group_heads["ARMAMENTO"] as Button).text.substr(0, 1) == "▸", "▸ fechado")
	var mais := _botao(game, "ARMAMENTO", "ENCURRAÇADOS +1")
	var menos := _botao(game, "ARMAMENTO", "ENCURRAÇADOS −1")
	_assert("os dois degraus existem no corpo do grupo", mais != null and menos != null,
		"+1 e −1 à vista do corpo")
	(game.group_heads["ARMAMENTO"] as Button).pressed.emit()
	await _frames(2)
	_assert("clicar o cabeçalho abre o corpo dele e fecha FORMAÇÕES",
		(game.group_bodies["ARMAMENTO"] as Control).visible
			and not (game.group_bodies["FORMAÇÕES"] as Control).visible
			and (game.group_heads["FORMAÇÕES"] as Button).text.substr(0, 1) == "▸",
		"ARMAMENTO aberto, FORMAÇÕES com ▸")
	_assert("o corpo aberto tem os quatro botões de casco à vista",
		_botoes(game, "ARMAMENTO").size() == 4,
		"4 comandos abertos: bateria e convés, cada um com o seu +1 e o seu −1")
	# O degrau sobe pelo sinal do botão, não por chamada interna: é pelo sinal que o jogador alcança.
	mais.pressed.emit()
	_assert("um clique no +1 veste um casco pelo próprio sinal",
		int(game.encoracados) == 1 and String(game.fleet[0]["classe"]) == "BATALHA"
			and _baterias_na_cena(game) == 1,
		"escada %d, %d baterias" % [game.encoracados, _baterias_na_cena(game)])
	_assert("e a ponte anuncia o degrau em números",
		String(game.report_label.text).find("ARMAMENTO: 1 ENCURRAÇADO(S)") == 0,
		String(game.report_label.text))
	# A escada também tem de ser lida no estado permanente da ponte, não só na linha de relatório que
	# muda a cada clique: é a primeira linha do HUD que diz, no meio do fogo, quantos encouraçados
	# existem. E o preço de acrescentá-la é não ganhar uma linha — as sondas vizinhas contam cinco.
	var hud_do_degrau: PackedStringArray = String(game.command_label.text).split("\n")
	_assert("a primeira linha do HUD lê a bateria com o teto",
		hud_do_degrau.size() == 5 and hud_do_degrau[0].contains("ARMAMENTO: 1/%d ENCURRAÇADO(S)"
			% ENCORACADOS_TETO), hud_do_degrau[0])
	for i in range(3):
		mais.pressed.emit()
	_assert("a escada tem teto em quatro cascos", int(game.encoracados) == ENCORACADOS_TETO
		and _baterias_na_cena(game) == ENCORACADOS_TETO,
		"quatro cliques para cima, escada %d" % game.encoracados)
	var texto_teto := String(game.report_label.text)
	mais.pressed.emit()
	_assert("o quinto clique recusa sem mover a escada",
		int(game.encoracados) == ENCORACADOS_TETO
			and String(game.report_label.text) != texto_teto
			and String(game.report_label.text).find("a ponte não tem outro degrau") >= 0
			and _baterias_na_cena(game) == ENCORACADOS_TETO,
		"%s // texto do teto era: %s" % [String(game.report_label.text), texto_teto])
	for i in range(6):
		menos.pressed.emit()
	await _frames(2)
	_assert("a escada tem piso em linha pura", int(game.encoracados) == 0
		and _baterias_na_cena(game) == 0, "escada %d, %d baterias" % [game.encoracados,
			_baterias_na_cena(game)])
	_assert("descer recolhe a silhueta e devolve o cruzador",
		String(game.fleet[0]["classe"]) == "CRUZADOR", "classe %s" % game.fleet[0]["classe"])

## ---- 4. Voo de forma fechada e a invariância de taxa de quadro --------------------------------
func _secao_voo() -> void:
	var game_a: Node3D = await _montar_jogo()
	_alinhar(game_a)
	_blindar(game_a)
	game_a.rng.seed = 71717
	game_a.battle_clock = 0.0
	# A corda de laboratório âncora no centro do casco 0, 44 u na ré: assim o ponto de detonação é o
	# alvo e a régua de disco mede um corpo só. Os vizinhos de linha ficam a exatamente 6,0 u do
	# ponto — fator zero pela fórmula e fora da conta, que é o contrato da borda.
	var destino: Vector3 = (game_a.enemies[0]["node"] as Node3D).global_position
	var origem := destino + Vector3(0.0, 0.0, 44.0)
	var m: Dictionary = _disparar(game_a, origem, destino, 10.0)
	_assert("o disparar recusa corda de comprimento zero",
		_disparar(game_a, origem, origem, 10.0).is_empty() and int(game_a.misseis.size()) == 1,
		"origem igual ao destino: nenhum corpo a mais")
	var tau := float(m["tau"])
	_assert("o tempo de travessia é a corda dividida pela velocidade",
		_igual(tau, 44.0 / MISSIL_VELOCIDADE, 0.0001), "%0.4f s para 44 u a %0.0f u/s" % [tau, MISSIL_VELOCIDADE])
	_assert("e a carga caminha mais devagar que o abalroamento e mais rápido que a linha",
		MISSIL_VELOCIDADE > 8.0 and MISSIL_VELOCIDADE < 30.0,
		"%0.0f u/s contra 8 u/s de marcha e 30 u/s de teto de abalroamento" % MISSIL_VELOCIDADE)
	game_a.battle_clock = tau * 0.5
	game_a._atualizar_misseis()
	var meio: Vector3 = (m["no"] as Node3D).global_position
	_assert("meio do caminho é meio do caminho, lido da forma fechada",
		_igual(meio.distance_to(origem), 22.0, 0.0002), "%0.4f u percorridos" % meio.distance_to(origem))
	game_a.battle_clock = tau - 0.05
	game_a._atualizar_misseis()
	var atrasado: Vector3 = (m["no"] as Node3D).global_position
	_assert("voltar o relógio não manda a carga de volta nem para trás da origem",
		atrasado.z < -38.0 and _igual(atrasado.distance_to(destino), 0.9, 0.0002),
		"%0.4f u do alvo, fora da corda" % atrasado.distance_to(destino))
	game_a.battle_clock = tau + 0.01
	game_a._atualizar_misseis()
	var caiu_a := 500.0 - float(game_a.enemies[0]["hp"])
	_assert("a carga chegou, explodiu e saiu da lista",
		int(game_a.misseis.size()) == 0 and int(game_a.missil_contagem["detonados"]) == 1
			and int(game_a.missil_contagem["cascos"]) == 1,
		"%d em voo, %d detonados, %d bloqueados, %d cascos feridos" % [game_a.misseis.size(),
			game_a.missil_contagem["detonados"], game_a.missil_contagem["bloqueados"],
			game_a.missil_contagem["cascos"]])
	_assert("e o casco no centro do disco pagou o cheio",
		_igual(caiu_a, 10.0, 0.0001), "%0.4f de dano em um casco a 0,00 u do ponto" % caiu_a)
	# Lado B: quarenta quadros de 0,1 s contra quatro de 1,0 s, mesma corda, mesmo dano.
	var game_b: Node3D = await _montar_jogo()
	_alinhar(game_b)
	_blindar(game_b)
	game_b.rng.seed = 71717
	game_b.battle_clock = 0.0
	game_b._lancar_missil(origem, destino, 10.0)
	_voar(game_b, 40, PASSO)
	var game_c: Node3D = await _montar_jogo()
	_alinhar(game_c)
	_blindar(game_c)
	game_c.rng.seed = 71717
	game_c.battle_clock = 0.0
	game_c._lancar_missil(origem, destino, 10.0)
	_voar(game_c, 4, 1.0)
	_assert("quarenta quadros de 0,1 s e quatro de 1,0 s entregam o mesmo casco",
		_igual(float(game_b.enemies[0]["hp"]), float(game_c.enemies[0]["hp"]), 0.0)
			and _igual(float(game_b.enemies[0]["hp"]), game_a.enemies[0]["hp"], 0.0001),
		"%0.4f / %0.4f / %0.4f" % [game_b.enemies[0]["hp"], game_c.enemies[0]["hp"],
			game_a.enemies[0]["hp"]])
	_assert("e a mesma conta, com o voo encerrado dos dois lados",
		int(game_b.missil_contagem["detonados"]) == int(game_c.missil_contagem["detonados"])
			and int(game_b.misseis.size()) == 0 and int(game_c.misseis.size()) == 0,
		"%d detonações em 40 quadros, %d em 4" % [game_b.missil_contagem["detonados"],
			game_c.missil_contagem["detonados"]])
	_assert("o voo não consome gerador de combate em nenhuma das duas resoluções",
		int(game_b.rng.state) == int(game_c.rng.state) and int(game_b.rng.state) == int(game_c.rng.state),
		"rng %d dos dois lados" % game_b.rng.state)
	# A meia-trajetória tem de ser lida no meio, não só no fim: é a forma fechada, não um salto.
	var game_d: Node3D = await _montar_jogo()
	_alinhar(game_d)
	_blindar(game_d)
	game_d.battle_clock = 0.0
	var md: Dictionary = _disparar(game_d, origem, destino, 10.0)
	_voar(game_d, 22, PASSO)
	var no_meio: Vector3 = (md["no"] as Node3D).global_position
	_assert("no vigésimo segundo passo de 0,1 s a carga está em 2,2 s de corda",
		_igual(no_meio.distance_to(origem), 2.2 * MISSIL_VELOCIDADE, 0.0004),
		"%0.4f u de origem" % no_meio.distance_to(origem))

## ---- 5. O disco escolhe quem paga -------------------------------------------------------------
## Monta um caso de disco: o casco `alvo` com o centro a `dist` u do ponto de detonação, o resto da
## linha hostil a mais de 60 u do ponto, corda de 44 u livre de pedra (cenario ABERTO) e a carga de
## `dano` lançada de 44 u na ré. Devolve o que o jogo cobrou, medido no delta — não no acumulado.
## Com a esquadra alinhada a 6,0 u, todo ponto perto de um casco também toca o vizinho: a régua de
## falloff só é régua quando um corpo só está ao alcance da carga.
func _mede_disco(game, alvo: int, dist: float, dano: float) -> Dictionary:
	var ponto := Vector3(0.0, 0.0, -60.0)
	var cascos_antes := int(game.missil_contagem["cascos"])
	var bloqueados_antes := int(game.missil_contagem["bloqueados"])
	var casco_antes: float = float(game.enemies[alvo]["hp"])
	for i in range(game.enemies.size()):
		var no: Node3D = game.enemies[i]["node"]
		if i == alvo:
			no.position = ponto + Vector3(0.0, 0.0, -dist)
		else:
			no.position = ponto + Vector3(60.0 + float(i) * 40.0, 0.0, 0.0)
	_disparar(game, ponto + Vector3(0.0, 0.0, 44.0), ponto, dano)
	_voar_ate_o_fim(game, 80, PASSO)
	return {"pago": casco_antes - float(game.enemies[alvo]["hp"]),
		"cascos": int(game.missil_contagem["cascos"]) - cascos_antes,
		"bloqueados": int(game.missil_contagem["bloqueados"]) - bloqueados_antes,
		"em_voo": int(game.misseis.size())}

func _secao_disco() -> void:
	var game: Node3D = await _montar_jogo()
	_alinhar(game)
	_blindar(game)
	game._montar_cenario("ABERTO")
	game.battle_clock = 0.0
	var cheio := _mede_disco(game, 0, 0.0, 20.0)
	_assert("centro do disco é dano cheio",
		_igual(float(cheio["pago"]), 20.0, 0.0001) and int(cheio["cascos"]) == 1
			and int(cheio["em_voo"]) == 0 and int(cheio["bloqueados"]) == 0,
		"%0.3f de casco pago, %d cascos na conta, %d bloqueados, %d ainda em voo" % [
			cheio["pago"], cheio["cascos"], cheio["bloqueados"], cheio["em_voo"]])
	# 4,2 u do ponto: (4,2 − 2,4) / (6,0 − 2,4) = 0,5 exato pela fórmula do falloff.
	var meio := _mede_disco(game, 1, 4.2, 20.0)
	_assert("a 4,2 u do ponto o casco paga exatamente metade",
		_igual(float(meio["pago"]), 10.0, 0.0001) and int(meio["cascos"]) == 1
			and int(meio["bloqueados"]) == 0,
		"%0.4f de dano — a régua é 1 − (4,2−2,4)/(6,0−2,4), %d bloqueados" % [
			meio["pago"], meio["bloqueados"]])
	# Borda do disco: 6,0 u é fator zero, e «zero» aqui significa não entrar na conta.
	var borda := _mede_disco(game, 2, MISSIL_RAIO, 20.0)
	_assert("na borda do disco o casco não paga nada nem é contado",
		_igual(float(borda["pago"]), 0.0, 0.0) and int(borda["cascos"]) == 0
			and int(borda["em_voo"]) == 0,
		"%0.3f de casco pago e %d cascos na conta aos 6,0 u do ponto" % [
			borda["pago"], borda["cascos"]])

	# Dois cascos dentro do disco: o perto paga cheio, o longe paga o falloff — e a ordem de
	# cadastro decide quem é quem, sem sorteio.
	var game2: Node3D = await _montar_jogo()
	_alinhar(game2)
	_blindar(game2)
	game2._montar_cenario("ABERTO")
	game2.battle_clock = 0.0
	var a := (game2.enemies[0]["node"] as Node3D).global_position
	var b := (game2.enemies[1]["node"] as Node3D).global_position
	var ponto_duplo := Vector3((a.x + b.x) * 0.5, 0.0, a.z)
	_disparar(game2, Vector3(0.0, 0.0, 20.0), ponto_duplo, 30.0)
	_voar_ate_o_fim(game2, 100, PASSO)
	var d0 := 500.0 - float(game2.enemies[0]["hp"])
	var d1 := 500.0 - float(game2.enemies[1]["hp"])
	var dist0 := a.distance_to(ponto_duplo)
	var dist1 := b.distance_to(ponto_duplo)
	var esp0 := 30.0 * clampf(1.0 - (dist0 - HULL_RADIUS) / (MISSIL_RAIO - HULL_RADIUS), 0.0, 1.0)
	var esp1 := 30.0 * clampf(1.0 - (dist1 - HULL_RADIUS) / (MISSIL_RAIO - HULL_RADIUS), 0.0, 1.0)
	_assert("um disco paga dois cascos ao mesmo tempo", d0 > 0.0 and d1 > 0.0 and int(game2.missil_contagem["cascos"]) == 2,
		"%0.3f u do casco 0 e %0.3f u do casco 1" % [dist0, dist1])
	_assert("cada um paga a sua distância, conferida na mão",
		_igual(d0, esp0, 0.0001) and _igual(d1, esp1, 0.0001),
		"%0.4f contra %0.4f e %0.4f contra %0.4f" % [d0, esp0, d1, esp1])
	# Fora do disco: o casco que está a 20 u do ponto não aparece na conta de ninguém.
	var game3: Node3D = await _montar_jogo()
	_alinhar(game3)
	_blindar(game3)
	game3._montar_cenario("ABERTO")
	game3.battle_clock = 0.0
	var longe := (game3.enemies[3]["node"] as Node3D).global_position
	_disparar(game3, Vector3(0.0, 0.0, 20.0), longe + Vector3(20.0, 0.0, 0.0), 40.0)
	_voar_ate_o_fim(game3, 100, PASSO)
	_assert("fora do disco, fora do dano", _igual(float(game3.enemies[3]["hp"]), 500.0, 0.0)
		and _igual(float(game3.missil_contagem["dano"]), 0.0, 0.0)
			and int(game3.missil_contagem["detonados"]) == 1,
		"casco %0.1f, %0.1f de dano na conta, %d detonações fora do disco" % [game3.enemies[3]["hp"],
			game3.missil_contagem["dano"], game3.missil_contagem["detonados"]])

## ---- 6. A barreira relida na chegada ------------------------------------------------------------
func _secao_barreira() -> void:
	var game: Node3D = await _montar_jogo()
	_alinhar(game)
	_blindar(game)
	game.battle_clock = 0.0
	game._montar_cenario("ABERTO")
	var destino: Vector3 = (game.enemies[0]["node"] as Node3D).global_position
	var origem := Vector3(0.0, 0.0, -38.0)
	var rocha: Dictionary = game._nova_rocha((origem + destino) * 0.5, 3.2, Vector3.ZERO, 0, 0.0)
	var integridade_antes := float(rocha["integridade"])
	_assert("a pedra nasce com integridade de 6,0 por unidade de raio",
		_igual(integridade_antes, 3.2 * ROCHA_INTEGRIDADE_POR_RAIO, 0.0001),
		"%0.1f em raio %0.1f" % [integridade_antes, rocha["raio"]])
	var m: Dictionary = _disparar(game, origem, destino, 8.0)
	_assert("a corda do lançamento tem pedra no meio",
		not game._barreira_entre(origem, destino).is_empty() and int(m["id"]) > 0,
		"%d rochas, bloqueio confirmado pelo jogo" % game.rochas.size())
	_voar(game, 40, PASSO)
	_assert("a carga bate na rocha, não no casco",
		int(game.missil_contagem["bloqueados"]) == 1 and int(game.missil_contagem["detonados"]) == 0
			and _igual(float(game.enemies[0]["hp"]), 500.0, 0.0),
		"%d bloqueados, casco hostil %0.1f" % [game.missil_contagem["bloqueados"], game.enemies[0]["hp"]])
	_assert("e a pedra paga a integridade pelo golpe",
		_igual(float(rocha["integridade"]), integridade_antes - 8.0, 0.0001),
		"%0.1f depois de 8,0 de carga" % rocha["integridade"])
	# Agora a mesma corda com a pedra fora do caminho na hora da chegada: é a deriva que decide, e
	# é por isso que a barreira não pode ser congelada no lançamento.
	var game2: Node3D = await _montar_jogo()
	_alinhar(game2)
	_blindar(game2)
	game2.battle_clock = 0.0
	game2._montar_cenario("ABERTO")
	var destino2: Vector3 = (game2.enemies[0]["node"] as Node3D).global_position
	var rocha2: Dictionary = game2._nova_rocha((origem + destino2) * 0.5, 3.2, Vector3.ZERO, 0, 0.0)
	var m2: Dictionary = _disparar(game2, origem, destino2, 12.0)
	_assert("no lançamento a pedra barra a corda", not game2._barreira_entre(origem, destino2).is_empty(),
		"pedra a %0.1f u da origem" % origem.distance_to(rocha2["pos"]))
	rocha2["pos"] = (rocha2["pos"] as Vector3) + Vector3(30.0, 0.0, 0.0)
	_voar(game2, 40, PASSO)
	_assert("com a pedra fora da corda na chegada, o disco cai no casco",
		_igual(500.0 - float(game2.enemies[0]["hp"]), 12.0, 0.0001)
			and int(game2.missil_contagem["bloqueados"]) == 0
			and int(game2.missil_contagem["detonados"]) == 1,
		"casco %0.1f pago, %d bloqueados" % [500.0 - float(game2.enemies[0]["hp"]),
			game2.missil_contagem["bloqueados"]])
	# Carga fechada parte a pedra: 25 de dano contra 19,2 de integridade.
	var game3: Node3D = await _montar_jogo()
	_alinhar(game3)
	_blindar(game3)
	game3.battle_clock = 0.0
	game3._montar_cenario("ABERTO")
	var destino3: Vector3 = (game3.enemies[0]["node"] as Node3D).global_position
	game3._nova_rocha((origem + destino3) * 0.5, 3.2, Vector3.ZERO, 0, 0.0)
	_disparar(game3, origem, destino3, 25.0)
	_voar(game3, 40, PASSO)
	_assert("carga que fecha a integridade pare a pedra em duas filhas",
		int(game3.missil_contagem["rachadas"]) == 1 and int(game3.rochas.size()) == 2
			and int(game3.missil_contagem["bloqueados"]) == 1,
		"%d filhas, %d rachadas, %d bloqueados" % [game3.rochas.size(),
			game3.missil_contagem["rachadas"], game3.missil_contagem["bloqueados"]])
	# Astro não racha: a corda atravessa o CENTRO do corpo e para nele. Com o `_process` congelado,
	# `pos` é o tabuleiro de trabalho e a barreira é lida exatamente onde foi montada. O que se cobra
	# é a classe do bloqueio — astro, não pedra — e não o índice do astro, porque um corpo maior pode
	# interceptar a corda antes do escolhido e a lei medida é a mesma.
	var game4: Node3D = await _montar_jogo()
	_alinhar(game4)
	_blindar(game4)
	game4._montar_cenario("SISTEMA")
	game4.battle_clock = 0.0
	var planeta: Dictionary = game4.astros[0]
	var pp: Vector3 = planeta["pos"]
	var o4 := pp + Vector3(0.0, 0.0, 44.0)
	var d4 := pp + Vector3(0.0, 0.0, -44.0)
	var barra: Dictionary = game4._barreira_entre(o4, d4)
	var cascos_antes := int(game4.missil_contagem["cascos"])
	_disparar(game4, o4, d4, 20.0)
	_voar_ate_o_fim(game4, 80, PASSO)
	_assert("a corda pelo centro do planeta tem um astro no meio, não uma pedra",
		not barra.is_empty() and barra["pedra"].is_empty() and not barra["astro"].is_empty(),
		"bloqueio a t=%0.3f, raio %0.1f, %d astros e %d rochas em jogo" % [
			float(barra.get("t", -1.0)), float(barra.get("raio", -1.0)),
			game4.astros.size(), game4.rochas.size()])
	_assert("planeta para a carga sem rachar",
		int(game4.missil_contagem["bloqueados"]) == 1 and int(game4.missil_contagem["rachadas"]) == 0
			and int(game4.astros.size()) == 4 and int(game4.misseis.size()) == 0
			and int(game4.missil_contagem["cascos"]) == cascos_antes,
		"%d bloqueados, %d rachadas, %d astros inteiros, %d cascos feridos, %d em voo" % [
			game4.missil_contagem["bloqueados"], game4.missil_contagem["rachadas"],
			game4.astros.size(), int(game4.missil_contagem["cascos"]) - cascos_antes,
			game4.misseis.size()])
	_assert("o planeta do sistema não é pedra: a conta de rochas segue vazia",
		int(game4.rochas.size()) == 0 and _igual(float(planeta["raio"]), 15.0, 0.0001),
		"%d rochas, planeta de %0.1f u" % [game4.rochas.size(), planeta["raio"]])

## ---- 7. O leque da bateria obedece à densidade de fogo ----------------------------------------
func _secao_leque() -> void:
	var game: Node3D = await _montar_jogo()
	_alinhar(game)
	_blindar(game)
	game.rng.seed = 82828
	game.selected_target = 0
	game.encoracados = 1
	game._aplicar_classes()
	for i in range(1, game.fleet.size()):
		game.fleet[i]["weapons"] = 0.0
	game.battle_clock = 0.0
	game._give_order("ATACAR")
	game.fogo_densidade = 0
	game._resolve_volley()
	var concentrados: Array[Vector3] = []
	for m in game.misseis:
		concentrados.append(m["destino"])
	_assert("a bateria usa os pontos da própria salva",
		int(game.misseis.size()) == 2 and concentrados.size() == 2, "%d cargas em voo" % game.misseis.size())
	var alvo: Vector3 = (game.enemies[0]["node"] as Node3D).global_position
	var raio_0 := alvo.distance_to(concentrados[0])
	var raio_1 := alvo.distance_to(concentrados[1])
	_assert("no CONCENTRADO as duas cargas caem dentro do disco de 4,5 u",
		raio_0 <= FOGO_RAIO[0] + FOLGA and raio_1 <= FOGO_RAIO[0] + FOLGA,
		"%0.3f u e %0.3f u do centro do alvo" % [raio_0, raio_1])
	var game2: Node3D = await _montar_jogo()
	_alinhar(game2)
	_blindar(game2)
	game2.rng.seed = 82828
	game2.selected_target = 0
	game2.encoracados = 1
	game2._aplicar_classes()
	for i in range(1, game2.fleet.size()):
		game2.fleet[i]["weapons"] = 0.0
	game2.battle_clock = 0.0
	game2._give_order("ATACAR")
	game2.fogo_densidade = 2
	game2._resolve_volley()
	var alvo2: Vector3 = (game2.enemies[0]["node"] as Node3D).global_position
	var espalhado := 0.0
	for m in game2.misseis:
		espalhado = maxf(espalhado, alvo2.distance_to(m["destino"]))
	_assert("no DISPERSO o mesmo casco abre também o leque da bateria",
		_igual(espalhado, FOGO_RAIO[2] * 0.5, 0.0002),
		"carga mais afastada a %0.3f u, disco de %0.1f u" % [espalhado, FOGO_RAIO[2]])
	_assert("e a densidade não mudou o número de cargas nem de sorteios",
		int(game2.misseis.size()) == 2 and int(game2.rng.state) == int(game.rng.state),
		"rng %d dos dois lados" % game2.rng.state)

## ---- 8. A mesa não conta míssil como casco -----------------------------------------------------
func _secao_mesa() -> void:
	var game: Node3D = await _montar_jogo()
	_alinhar(game)
	_blindar(game)
	game.rng.seed = 93939
	game.selected_target = 0
	game.encoracados = 4
	game._aplicar_classes()
	game.battle_clock = 0.0
	game._montar_cenario("CINTURAO")
	game._resolve_volley()
	var vivos := 0
	for unit in game.fleet:
		if float(unit["hp"]) > 0.0:
			vivos += 1
	for unit in game.enemies:
		if float(unit["hp"]) > 0.0:
			vivos += 1
	_assert("doze cascos vivos, doze blips — com oito cargas em voo",
		int(game.misseis.size()) == 8 and int(game.holo_blips.size()) == vivos,
		"%d blips para %d cascos, %d mísseis" % [game.holo_blips.size(), vivos, game.misseis.size()])
	var marcas_antes := int(game.holo_cenario.size())
	_voar(game, 30, PASSO)
	_assert("detonação não ganha marca na mesa nem material novo por clarão",
		int(game.holo_cenario.size()) == marcas_antes,
		"%d marcas de cenário, mesmas de antes do voo" % game.holo_cenario.size())
	_assert("e a conta da bateria atravessa o cinturão com a fatura legível",
		String(game.salva_resumo).find("bateria:") >= 0, String(game.salva_resumo))

## ---- 9. A prova central: dois jogos, mesma semente, a cauda intacta ----------------------------
func _secao_ab() -> void:
	# Lado A: linha pura. Lado B: quatro encouraçados atirando oito salvas. A única diferença é a
	# classe, e o que se cobra é a frase do contrato: a bateria fere sem empurrar a cauda do
	# sorteio. Os cascos estão blindados a 500 justamente para ninguém morrer na janela — morto um
	# casco, muda a quantidade de salvas hostis e a divergência seria de estrutura, não de canal.
	# O fogo vai a CONCENTRADO nos dois lados porque o disco da bateria é o da salva: no DISPERSO a
	# carga cai no vazio por projeto e a corrida mediria o vazio, não o canal.
	var a: Node3D = await _montar_jogo()
	_alinhar(a)
	_blindar(a)
	a.rng.seed = 414141
	a.selected_target = 0
	a.battle_clock = 0.0
	a.fogo_densidade = 0
	var rng_a_antes: int = a.rng.state
	var visual_a_antes: int = a.visual_rng.state
	for k in range(8):
		a._resolve_volley()
		a.battle_clock += 0.2
		a._atualizar_misseis()
	_voar_ate_o_fim(a, 60, PASSO)
	var b: Node3D = await _montar_jogo()
	_alinhar(b)
	_blindar(b)
	b.rng.seed = 414141
	b.selected_target = 0
	b.battle_clock = 0.0
	b.fogo_densidade = 0
	b.encoracados = ENCORACADOS_TETO
	b._aplicar_classes()
	var rng_b_antes: int = b.rng.state
	var visual_b_antes: int = b.visual_rng.state
	for k in range(8):
		b._resolve_volley()
		b.battle_clock += 0.2
		b._atualizar_misseis()
	# Quita o voo antes de ler a divergência: com 0,2 s por salva, as cargas da última salva ainda
	# estariam no meio da corda e a bateria não apareceria na conta — foi exatamente assim que a
	# primeira versão desta corrida leu +18,4 (só o canhão comido) e chamou isso de veredito.
	_voar_ate_o_fim(b, 60, PASSO)
	# Mesma semente, mesmos dois geradores antes de a salva começar: a escada é lida na hora e não
	# anda no gerador, então o que difere é o que ela cobra, nunca o que ela sorteia.
	_assert("os dois jogos largam do mesmo estado de gerador",
		rng_a_antes == rng_b_antes and visual_a_antes == visual_b_antes,
		"rng %d e visual_rng %d dos dois lados" % [rng_a_antes, visual_a_antes])
	_assert("e chegam ao mesmo rng.state depois de oito salvas com bateria",
		int(a.rng.state) == int(b.rng.state), "rng %d nos dois tabuleiros" % a.rng.state)
	_assert("e ao mesmo visual_rng: a carga não sorteia nem a pintura",
		int(a.visual_rng.state) == int(b.visual_rng.state),
		"visual_rng %d nos dois tabuleiros" % a.visual_rng.state)
	var somados_a := _hostis_somados(a)
	var somados_b := _hostis_somados(b)
	_assert("mas os cascos hostil divergem — a bateria fez o que se pediu dela",
		somados_b < somados_a - 20.0, "%0.1f de casco pago a mais com quatro encouraçados (a %0.1f, b %0.1f)"
			% [somados_a - somados_b, somados_a, somados_b])
	_assert("a corrida não foi medida em tabuleiro vazio",
		int(b.missil_contagem["lancados"]) == 8 * ENCORACADOS_TETO * 2
			and int(b.missil_contagem["detonados"]) > 0
			and float(b.missil_contagem["dano"]) > 0.0
			and somados_a > 2000.0
			and int(a.missil_contagem["lancados"]) == 0,
		"B: %d lançados, %d detonados, %d bloqueados, %0.1f de dano // A: %d lançados, controle %0.1f" % [
			b.missil_contagem["lancados"], b.missil_contagem["detonados"],
			b.missil_contagem["bloqueados"], b.missil_contagem["dano"],
			a.missil_contagem["lancados"], somados_a])
	_assert("com carga em voo o resumo anuncia a bateria, e sem carga não",
		String(a.salva_resumo).find("bateria") < 0
			and String(b.salva_resumo).find("bateria:") >= 0,
		"A: %s" % String(b.salva_resumo))
	# A assinatura do Lado A tem de ser a de um jogo que nunca encostou na escada: a mesma
	# sequência de salvas em um terceiro tabuleiro, sem classe nenhuma, dá a mesma string.
	var c: Node3D = await _montar_jogo()
	_alinhar(c)
	_blindar(c)
	c.rng.seed = 414141
	c.selected_target = 0
	c.battle_clock = 0.0
	c.fogo_densidade = 0
	for k in range(8):
		c._resolve_volley()
		c.battle_clock += 0.2
		c._atualizar_misseis()
	_voar_ate_o_fim(c, 60, PASSO)
	_assert("linha pura e jogo que nunca viu a escada são o mesmo jogo",
		_assinatura(a) == _assinatura(c) and _assinatura(a).length() > 200,
		"assinaturas idênticas em %d caracteres // %s" % [_assinatura(a).length(),
			_diferencaassinatura(_assinatura(a), _assinatura(c))])

## Onde duas assinaturas de tabuleiro se separam. Sem isto a QUEBRA só diz «diferem» e a próxima
## rodada continua às cegas: a assinatura é por casco, na ordem das duas listas.
func _diferencaassinatura(x: String, y: String) -> String:
	var partes_x := x.split("|")
	var partes_y := y.split("|")
	for i in range(mini(partes_x.size(), partes_y.size())):
		if partes_x[i] != partes_y[i]:
			return "campo %d: [%s] contra [%s]" % [i, partes_x[i], partes_y[i]]
	return "%d campos contra %d, tamanhos %d e %d" % [partes_x.size(), partes_y.size(),
		x.length(), y.length()]

func _initialize() -> void:
	await _secao_inercia()
	await _secao_escada()
	await _secao_painel()
	await _secao_voo()
	await _secao_disco()
	await _secao_barreira()
	await _secao_leque()
	await _secao_mesa()
	await _secao_ab()
	for linha in notes:
		print(linha)
	print("SONDA-MISSEIS: veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	quit()
