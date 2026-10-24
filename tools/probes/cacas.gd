extends SceneTree

## Sonda do grupo aéreo: o porta-aviões que vende canhão por agulha, e uma escada que desce
## exatamente pelo mesmo caminho por que subiu.
##
## O pedido do comandante foi «carriers que lançam pequenas naves caças». Um caçado que só desenha
## um pontinho no visor não atende ao pedido, então esta peça cobra as seis consequências que fazem
## da classe uma classe e não uma pintura:
##
## 1) LINHA PURA NÃO MOVE NÚMERO. Com a escada em zero, nenhum caçado nasce, nenhum convés é
##    montado, nenhum sorteio acontece: a sequência de oito salvas de um jogo que subiu e desceu o
##    degrau é IDÊNTICA — `rng.state`, `visual_rng.state`, casco hostil somado e assinatura de
##    tabuleiro — à de um jogo que nunca encostou no ARMAMENTO.
## 2) A ESCADA É REVERSÍVEL E AS DUAS ESCADAS COEXISTEM. A bateria pega os cascos pela CABEÇA do
##    cadastro, a aviação pela CAUDA. Promover dois de cada deixa quatro silhuetas novas e dois
##    cruzadores puros no meio; recolher devolve o quadro dígito a dígito, sem que ninguém tenha
##    guardado um «antes».
## 3) A GUARDA DA ESCOLTA É DAS DUAS ESCADAS JUNTAS. `encoracados + porta_avioes` não pode comer a
##    esquadra inteira: sempre tem de sobrar ao menos um cruzador puro na linha. É por isso que um
##    `+1` legítimo pode ser recusado com degrau ainda livre no teto — e a ponte diz qual das duas
##    recusas cobrou, porque «teto» e «não há casco livre» se confundiriam na tela.
## 4) A AVIAÇÃO NÃO SORTEIA NO COMBATE. O lançamento e a travessia não tocam em gerador nenhum, e o
##    único sorteio do golpe são os dois traços do rastro, que saem de `visual_rng` (pintura) e nunca
##    de `rng` (conta). É isto que permite a corrida A/B: dois conveses lançando dezoito salvas
##    deixam a cauda do gerador de combate byte a byte idêntica à de linha pura, com casco pago a
##    mais. Do contrário a escada seria um reroll disfarçado.
## 5) O GOLPE É DE PONTO, NÃO DE DISCO. No centro da agulha o caçado cobra 100% e a 5,0 u também
##    cobra 100% — a 6,0 u não cobra nada, porque cascos só são reivindicados até `HULL_RADIUS +
##    FOGO_LETAL` = 5,6 u. No MESMO ponto, a carga de bateria pagaria 27,8%: é essa a diferença entre
##    estourar em disco e cair em cima de um casco, e é ela que faz o convés valer o canhão comido.
## 6) A TRAVESSIA É DE IDA E VOLTA, EM FORMA FECHADA. `tau = 2d/26` lido de `battle_clock`, nunca
##    somado por quadro: quarenta quadros de 0,1 s e quatro de 1,0 s ferem o mesmo casco, no mesmo
##    contador, e os dois geradores chegam ao mesmo estado. E o caçado pousa: `pousados + abatidos ==
##    lancados` e `feridos + no_vao + bloqueados == lancados`, as duas identidades que provam que
##    nenhum caçado se perdeu pelo caminho — nem foi contado em dois eixos.
##
## A barreira é a lei da casa, com uma diferença de classe: a pedra ABATE o caçado e não paga
## integridade nenhuma (míssil é ogiva, caçado é tripulante), enquanto planeta e lua apenas mandam
## ele de volta ao convés, inteiro. E a barreira é relida na CHEGADA, não no lançamento, porque com o
## cinturão à deriva uma pedra entra e sai do corredor enquanto o caça caminha.
##
## Uso: godot --headless --path . --quit-after 6000 -s res://tools/probes/cacas.gd

## Espelho das constantes de `main.gd` — a instância do jogo é não tipada (mesmo motivo em
## `tools/probes/misseis.gd`). Mudar o número lá quebra a asserção aqui: é de propósito.
const HULL_RADIUS := 2.4
const FOGO_LETAL := 3.2
const FLECHAS_POR_SALVA := 3
const FOGO_RAIO := [4.5, 14.0, 28.0]
const MISSIL_RAIO := 6.0
const ENCORACADOS_TETO := 4
const PORTAAVIOES_TETO := 2
const CACA_VELOCIDADE := 26.0
const CACA_FATOR := 0.6
const ROCHA_INTEGRIDADE_POR_RAIO := 6.0
const PASSO := 0.1
## Tolerância de float32 lida de volta do motor: perto de 80 u o ulp é ~7,6e-6.
const FOLGA := 0.00005
## Coordenada de cena ida e volta pelo `Vector3` de 32 bits: 1 mm de folga sobre uma corda de 46 u
## não esconde um erro de travessia, que seria de unidades inteiras.
const POS_FOLGA := 0.001
## Nove grupos desde a escada de encouraçados; ARMAMENTO tem quatro botões porque cada degrau sobe
## e desce, e não existe botão de «escolher o navio» — a classe é do casco, não da ordem.
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

## Bilhetes de um "Casco", descendo pelos quatro módulos de setor: desde a fatia dos módulos o
## corpo mudou de pai, não de cota, e a contagem tem de enxergar o nível de dentro.
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

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _montar_jogo() -> Node3D:
	var game: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	# Congelar o tabuleiro ANTES dos três quadros: sem isto, cada montagem leva um tempo real
	# diferente de locomoção, de IA hostil e de `fire_clock`, e dois tabuleiros «idênticos» largam de
	# estados diferentes. É o que faz a prova A/B medir a escada em vez de medir o agendamento do
	# teste — e é por isso que a sonda chama cada função de jogo na mão.
	#
	# O congelamento é por `process_mode`, nunca por `set_process(false)`: dado dentro de
	# `_initialize`, o `set_process(false)` é engolido porque `add_child` ainda não completou o
	# `_ready` — o motor reinstala o processamento dele mesmo ao entrar na árvore, e o relógio continua
	# andando (medido em `tools/probes/congelamento.gd`: `battle_clock` 0,167 → 0,424 em 40 quadros e
	# motor 76,000 → 76,340). O `process_mode` segura nas duas posições e trava os filhos junto.
	#
	# A mesa é refeita por `_update_bridge` — chamado só do `_process` — então a sonda passa a chamar
	# a ponte à mão, uma vez por montagem: `holo_blips` deixa de depender do relógio da máquina.
	# `_update_bridge` e `_rebuild_holo` não sorteiam dígito nenhum.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(3)
	game._update_bridge(0.0)
	# Precondition da fatia 3, declarada sem afrouxar nenhum número: esta sonda mede a aritmética
	# do canhão, e com a casca de pé todo lance abaixo de 20,0 morde nela em vez de chegar a `hp`.
	# Despido o tabuleiro, cada número daqui volta a ser o de antes, dígito a dígito — a muralha em
	# si é cobrada por `tools/probes/escudo.gd`, com a casca armada.
	for casca_lista in [game.fleet, game.enemies]:
		for casca_unidade in casca_lista:
			casca_unidade["escudo"] = 0.0
			casca_unidade["escudo_max"] = 0.0
			casca_unidade["escudo_cai"] = 0.0
	return game

func _alinhar(game) -> void:
	for i in range(game.fleet.size()):
		(game.fleet[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 5.0, 0.0, -38.0)
	for i in range(game.enemies.size()):
		(game.enemies[i]["node"] as Node3D).position = Vector3((float(i) - 2.5) * 6.0, 0.0, -82.0)

## Blindagem de laboratório: 500 de casco em todo corpo. Não é truque de conveniência — é a
## condição de validade da asserção de RNG: morto um casco, muda o número de salvas hostis e, com
## ele, a quantidade de sorteios. Aí a cauda divergiria por estrutura, não pela aviação, e a
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

## Assinatura de combate dos dois lados da corrida: só números de cadastro, nenhum de pintura.
func _assinatura(game) -> String:
	var partes: Array[String] = []
	for list in [game.fleet, game.enemies]:
		for unit in list:
			var no: Node3D = unit["node"]
			partes.append("%s:%0.3f/%0.3f/%0.3f/%0.3f@%0.3f,%0.3f,%0.3f" % [unit["name"],
				float(unit["hp"]), float(unit["engines"]), float(unit["weapons"]),
				float(unit["crew"]), no.position.x, no.position.y, no.position.z])
	return "|".join(partes)

## Onde duas assinaturas de tabuleiro se separam. Sem isto a QUEBRA só diz «diferem» e a próxima
## rodada continua às cegas: a assinatura é por casco, na ordem das duas listas. Todos os campos
## divergentes, não só o primeiro — uma cauda que empurra dois cascos precisa ser lida inteira.
func _diferencaassinatura(x: String, y: String) -> String:
	var partes_x := x.split("|")
	var partes_y := y.split("|")
	var partes: Array[String] = []
	for i in range(mini(partes_x.size(), partes_y.size())):
		if partes_x[i] != partes_y[i]:
			partes.append("campo %d: [%s] contra [%s]" % [i, partes_x[i], partes_y[i]])
	if partes.is_empty():
		return "%d campos contra %d, tamanhos %d e %d" % [partes_x.size(), partes_y.size(),
			x.length(), y.length()]
	return "; ".join(partes)

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

## Quantos cascos do cadastro têm o nó de convés montado — leitura de cena, não de dicionário.
func _conves_na_cena(game) -> int:
	var total := 0
	for unit in game.fleet:
		var no: Node3D = unit["node"]
		if is_instance_valid(no) and no.get_node_or_null("Conves") != null:
			total += 1
	return total

func _baterias_na_cena(game) -> int:
	var total := 0
	for unit in game.fleet:
		var no: Node3D = unit["node"]
		if is_instance_valid(no) and no.get_node_or_null("Bateria") != null:
			total += 1
	return total

## Um só casco reivindicável no tabuleiro: os vizinhos vão para fora do alcance de qualquer disco.
## Sem isto a régua de «quem está sob a agulha» mediria o vizinho — a esquadra hostil marcha a 6 u
## de intervalos, e um ponto a 5,0 u do alvo já cai dentro do raio de reivindicação do de lado.
func _isolar_hostis(game) -> void:
	for i in range(1, game.enemies.size()):
		(game.enemies[i]["node"] as Node3D).position = Vector3(120.0 + float(i) * 30.0, 0.0, -82.0)

## Caçado de laboratório: corda e dano na mão, sem depender da salva, para poder medir o ponto de
## impacto e a barreira isolados. `nascido` fica no relógio corrente do jogo, como no lance real.
func _disparar_caca(game, origem: Vector3, destino: Vector3, dano: float) -> Dictionary:
	var antes := int(game.cacas.size())
	game._lancar_caca(origem, destino, dano)
	if int(game.cacas.size()) == antes:
		return {}
	return game.cacas[game.cacas.size() - 1]

## Avança o relógio e roda os dois voos (mísseis e caçados) no mesmo quadro: é o laço que as
## corridas de taxa de quadro e as comparações de lei usam para medir as duas pontas do tabuleiro
## sem que uma delas chegue antes da outra por causa do teste.
func _voar_tudo(game, teto: int, dt: float) -> void:
	for i in range(teto):
		if int(game.cacas.size()) == 0 and int(game.misseis.size()) == 0:
			return
		game.battle_clock += dt
		game._atualizar_misseis()
		game._atualizar_cacas()

## As duas identidades da travessia, conferidas juntas e devolvidas em prosa. `lancados` é o topo da
## escada: todo caçado fecha em UM dos três desfechos de arremesso e OU volta ao convés OU morre na
## pedra. Somar as duas listas prova que nenhum caçado se perdeu — e que nenhum foi contado duas
## vezes, que é o erro que o `no_vao` do bloqueio por planeta cometia antes desta sonda existir.
func _identidades(game) -> String:
	var lancados := int(game.caca_contagem["lancados"])
	var arremesso := int(game.caca_contagem["feridos"]) + int(game.caca_contagem["no_vao"]) \
		+ int(game.caca_contagem["bloqueados"])
	var retorno := int(game.caca_contagem["pousados"]) + int(game.caca_contagem["abatidos"])
	if arremesso != lancados or retorno != lancados:
		return "QUEBRA identidade: %d lançados, %d desfechos, %d retornos" % [lancados, arremesso, retorno]
	return "identidades fechadas: %d lançados = %d desfechos = %d retornos" % [lancados, arremesso, retorno]

func _identidades_boas(game) -> bool:
	var lancados := int(game.caca_contagem["lancados"])
	var arremesso := int(game.caca_contagem["feridos"]) + int(game.caca_contagem["no_vao"]) \
		+ int(game.caca_contagem["bloqueados"])
	var retorno := int(game.caca_contagem["pousados"]) + int(game.caca_contagem["abatidos"])
	return arremesso == lancados and retorno == lancados

## ---- 1. Linha pura: a escada em zero não move um dígito ---------------------------------------
func _secao_inercia() -> void:
	var game: Node3D = await _montar_jogo()
	_alinhar(game)
	_blindar(game)
	game.rng.seed = 60606
	game.battle_clock = 0.0
	game.selected_target = 0
	_assert("a partida acorda sem convés", int(game.porta_avioes) == 0 and int(game.cacas.size()) == 0,
		"escada %d, %d caçados no ar" % [game.porta_avioes, game.cacas.size()])
	var classes_boas := true
	for unit in game.fleet:
		if String(unit.get("classe", "AUSENTE")) != "CRUZADOR":
			classes_boas = false
	_assert("todo casco do cadastro é cruzador", classes_boas and game.fleet.size() == 6,
		"%d cascos, todos CRUZADOR" % game.fleet.size())
	_assert("a porta da classe é a tabela, não o hyphen",
		game._classe_de({"classe": "PORTAAVIOES"}) == "PORTAAVIOES"
			and game._classe_de({"classe": "PORTA-AVIOES"}) == "CRUZADOR"
			and game._classe_de({}) == "CRUZADOR",
		"chave certa lê aviação, hyphen e dicionário vazio caem na linha")
	_assert("cruzador não tem agulha de aviação",
		int(game._cacas_por_salva(game.fleet[0])) == 0
			and _igual(game._fator_classe(game.fleet[0], "armas"), 1.0, 0.0)
			and _igual(game._fator_classe(game.fleet[0], "velocidade"), 1.0, 0.0),
		"0 agulhas, canhão 1,0, marcha 1,0")
	_assert("nenhum casco tem convés montado", _conves_na_cena(game) == 0, "0 nós Conves")
	var rng_inicial: int = game.rng.state
	var visual_inicial: int = game.visual_rng.state
	game._ajustar_porta_avioes(1)
	game._ajustar_porta_avioes(-1)
	_assert("subir e descer um degrau pelo painel não sorteia um dígito",
		int(game.rng.state) == rng_inicial and int(game.visual_rng.state) == visual_inicial,
		"depois de +1 e −1: %d / %d" % [game.rng.state, game.visual_rng.state])
	_assert("e devolve a linha inteira, silhueta inclusive",
		_conves_na_cena(game) == 0 and String(game.fleet[5]["classe"]) == "CRUZADOR"
			and int(game.porta_avioes) == 0,
		"%d nós Conves, classe do último casco %s" % [_conves_na_cena(game), game.fleet[5]["classe"]])
	# A prova de inércia não pode ser «a salva não sorteia»: a salva sorteia por projeto e o gerador
	# anda em qualquer salva. O que se cobra é o par — oito salvas num jogo que subiu e desceu a
	# escada, dígito a dígito contra um jogo que nunca encostou no ARMAMENTO.
	var a := game
	a.rng.seed = 51515
	a.selected_target = 0
	a.battle_clock = 0.0
	a.fogo_densidade = 0
	a._montar_cenario("ABERTO")
	a._give_order("ATACAR")
	for k in range(8):
		a._resolve_volley()
		a.battle_clock += 0.2
		a._atualizar_misseis()
		a._atualizar_cacas()
	_voar_tudo(a, 120, PASSO)
	var b: Node3D = await _montar_jogo()
	_alinhar(b)
	_blindar(b)
	b.rng.seed = 51515
	b.selected_target = 0
	b.battle_clock = 0.0
	b.fogo_densidade = 0
	b._montar_cenario("ABERTO")
	b._give_order("ATACAR")
	for k in range(8):
		b._resolve_volley()
		b.battle_clock += 0.2
		b._atualizar_misseis()
		b._atualizar_cacas()
	_voar_tudo(b, 120, PASSO)
	_assert("o jogo que viu e devolveu o convés é o jogo que nunca viu escada",
		int(a.rng.state) == int(b.rng.state) and int(a.visual_rng.state) == int(b.visual_rng.state)
			and _assinatura(a) == _assinatura(b) and _assinatura(a).length() > 200,
		"rng %d / %d, visual %d / %d // %s" % [a.rng.state, b.rng.state, a.visual_rng.state,
			b.visual_rng.state, _diferencaassinatura(_assinatura(a), _assinatura(b))])
	_assert("e nenhum caçado nasceu numa esquadra sem convés",
		int(a.caca_contagem["lancados"]) == 0 and int(a.cacas.size()) == 0
			and int(b.caca_contagem["lancados"]) == 0,
		"%d lançados no A, %d no B" % [a.caca_contagem["lancados"], b.caca_contagem["lancados"]])
	_assert("as duas identidades valem no vazio", _identidades_boas(a) and _identidades_boas(b),
		_identidades(a))

## ---- 2. A escada sobe pela cauda, e as duas escadas cabem na mesma esquadra -------------------
func _secao_escada() -> void:
	var game: Node3D = await _montar_jogo()
	_alinhar(game)
	_blindar(game)
	game.rng.seed = 60606
	var rng_inicial: int = game.rng.state
	var visual_inicial: int = game.visual_rng.state
	# Cada casco nasce com a própria escala de silhueta (`_make_ship` recebe `scale_factor`), então a
	# régua de «promover não escala o corpo» não pode ser um número absoluto: é a escala do MESMO
	# casco antes e depois de vestir convés.
	var escala_cauda := (game.fleet[5]["node"] as Node3D).scale
	game.encoracados = 2
	game.porta_avioes = 2
	game._aplicar_classes()
	_assert("subir duas escadas pelo cadastro não sorteia um dígito",
		int(game.rng.state) == rng_inicial and int(game.visual_rng.state) == visual_inicial,
		"depois de +2/+2 por `_aplicar_classes`: %d / %d" % [game.rng.state, game.visual_rng.state])
	var esperadas := ["BATALHA", "BATALHA", "CRUZADOR", "CRUZADOR", "PORTAAVIOES", "PORTAAVIOES"]
	var medidas: Array[String] = []
	for unit in game.fleet:
		medidas.append(String(unit["classe"]))
	_assert("a bateria veste a cabeça e o convés veste a cauda, sem se tocarem",
		str(medidas) == str(esperadas), "%s" % str(medidas))
	_assert("quatro silhuetas novas convivem na mesma linha",
		_baterias_na_cena(game) == 2 and _conves_na_cena(game) == 2,
		"%d nós Bateria, %d nós Conves" % [_baterias_na_cena(game), _conves_na_cena(game)])
	var casco: Node3D = (game.fleet[5]["node"] as Node3D)
	var conves: Node3D = casco.get_node("Conves")
	_assert("o convés são laje, filete, ilhota e três caçados em pé de pista",
		conves.get_child_count() == 6, "%d corpos no convés" % conves.get_child_count())
	_assert("promover não escala o corpo", (game.fleet[5]["node"] as Node3D).scale == escala_cauda,
		"escala %s antes e depois do convés (raio de colisão é HULL_RADIUS, número de cadastro)"
			% str(escala_cauda))
	# A casarola de casco não muda: o convés é nó irmão, não costura na silhueta de linha. A
	# contagem desce pelos quatro módulos de setor — o bilhete mudou de pai, não de cota.
	var billetes_conv := _bilhetes((game.fleet[5]["node"] as Node3D).get_node("Casco")).size()
	var billetes_cruz := _bilhetes((game.fleet[2]["node"] as Node3D).get_node("Casco")).size()
	_assert("e o casco promovido conserva os mesmos billetes do cruzador do meio",
		billetes_conv == billetes_cruz and billetes_conv == 20,
		"%d billetes nos dois" % billetes_conv)
	# O preço da classe medido na função nomeada, em dois cascos de cadastro igual.
	game.fleet[2]["weapons"] = 100.0
	game.fleet[2]["crew"] = 100.0
	game.fleet[5]["weapons"] = 100.0
	game.fleet[5]["crew"] = 100.0
	var dano_cruz := 2.5 * float(game.fleet[2]["weapons"]) / 100.0 * maxf(0.25, float(game.fleet[2]["crew"]) / 100.0)
	var dano_conv: float = game._dano_de_canhao(game.fleet[5])
	_assert("o convés come 0,6 do canhão que sobra depois da bateria",
		_igual(dano_conv, dano_cruz * 0.4, 0.0000001) and _igual(dano_cruz, 2.5, FOLGA),
		"%0.4f contra %0.4f de fogo de linha" % [dano_conv, dano_cruz])
	_assert("convés põe três agulhas na salva e nenhuma carga de bateria",
		int(game._cacas_por_salva(game.fleet[5])) == 3
			and int(game._missoes_por_salva(game.fleet[5])) == 0
			and int(game._cacas_por_salva(game.fleet[0])) == 0,
		"3 agulhas no convés, 0 cargas, 0 agulhas no encouraçado")
	_assert("marcha do convés é 0,75 e a do encouraçado 0,6",
		_igual(game._fator_classe(game.fleet[5], "velocidade"), 0.75, 0.0)
			and _igual(game._fator_classe(game.fleet[0], "velocidade"), 0.6, 0.0),
		"0,75 e 0,6")
	# Desce tudo: o quadro tem de voltar ao de antes, inclusive as duas silhuetas.
	game.encoracados = 0
	game.porta_avioes = 0
	game._aplicar_classes()
	await _frames(2)
	_assert("descer as duas escadas devolve a linha inteira",
		_conves_na_cena(game) == 0 and _baterias_na_cena(game) == 0
			and String(game.fleet[0]["classe"]) == "CRUZADOR"
			and String(game.fleet[5]["classe"]) == "CRUZADOR",
		"%d nós Conves e %d nós Bateria depois de recolher" % [_conves_na_cena(game),
			_baterias_na_cena(game)])
	_assert("e os multiplicadores voltam a ser exatamente um",
		_igual(game._fator_classe(game.fleet[0], "armas"), 1.0, 0.0)
			and _igual(game._fator_classe(game.fleet[5], "velocidade"), 1.0, 0.0)
			and int(game._cacas_por_salva(game.fleet[5])) == 0,
		"armas 1,0 marcha 1,0 agulhas 0")
	# A guarda da escolta, dos dois lados da conta. Seis cascos: a cabeça e a cauda podem somar
	# cinco, nunca seis — tem de sobrar um cruzador puro na linha.
	var g: Node3D = await _montar_jogo()
	_alinhar(g)
	_blindar(g)
	for i in range(4):
		g._ajustar_encoracados(1)
	_assert("quatro encouraçados cabem enquanto não há convés",
		int(g.encoracados) == 4 and int(g.porta_avioes) == 0, "escada %d, conveses %d"
			% [g.encoracados, g.porta_avioes])
	g._ajustar_porta_avioes(1)
	# Quatro baterias na cabeça (índices 0..3) e um convés na cauda (5): o casco do meio é o
	# cruzador puro que a guarda da escolta exige que sobre — é ele, não o vizinho do encouraçado,
	# que a asserção tem de ler.
	_assert("um convés ainda cabe com a bateria no teto: sobra um cruzador",
		int(g.porta_avioes) == 1 and String(g.fleet[5]["classe"]) == "PORTAAVIOES"
			and String(g.fleet[4]["classe"]) == "CRUZADOR",
		String(g.fleet[4]["classe"]) + " / " + String(g.fleet[5]["classe"]))
	var antes_da_recusa := String(g.report_label.text)
	g._ajustar_porta_avioes(1)
	_assert("o segundo convés é recusado com degrau livre no teto — é a escolta que cobra",
		int(g.porta_avioes) == 1 and _conves_na_cena(g) == 1
			and String(g.report_label.text).find("recusado") >= 0
			and String(g.report_label.text).find("deixariam 0 casco(s) na linha") >= 0,
		String(g.report_label.text))
	_assert("recusar não reescreve a classe de ninguém",
		String(g.fleet[5]["classe"]) == "PORTAAVIOES" and _baterias_na_cena(g) == 4,
		"%d conveses, %d baterias, texto anterior era: %s" % [_conves_na_cena(g),
			_baterias_na_cena(g), antes_da_recusa])
	# E a recusa simétrica: com dois conveses na cauda, a bateria não chega ao teto de quatro.
	var h: Node3D = await _montar_jogo()
	_alinhar(h)
	_blindar(h)
	h._ajustar_porta_avioes(1)
	h._ajustar_porta_avioes(1)
	for i in range(4):
		h._ajustar_encoracados(1)
	_assert("com dois conveses a bateria para em três cascos e o quarto é recusado",
		int(h.encoracados) == 3 and int(h.porta_avioes) == 2
			and String(h.report_label.text).find("recusado") >= 0
			and _baterias_na_cena(h) == 3,
		"escada %d, conveses %d // %s" % [h.encoracados, h.porta_avioes, h.report_label.text])
	_assert("e o casco do meio continua cruzador puro", String(h.fleet[3]["classe"]) == "CRUZADOR",
		"%s / %s / %s" % [h.fleet[3]["classe"], h.fleet[4]["classe"], h.fleet[5]["classe"]])
	# O preço de ler classe por posição: incorporar um casco empurra o convés para o fim do
	# cadastro, porque o último casco da linha é sempre o que vira aviação.
	var i2: Node3D = await _montar_jogo()
	_alinhar(i2)
	_blindar(i2)
	i2._ajustar_porta_avioes(1)
	var extra := Node3D.new()
	i2.add_child(extra)
	i2.fleet.append({"name": "SONDA-EXTRA", "node": extra, "classe": "CRUZADOR",
		"hp": 500.0, "weapons": 100.0, "crew": 100.0, "engines": 100.0, "veloc": Vector3.ZERO,
		"order": "ATACAR"})
	i2._aplicar_classes()
	_assert("um casco a mais no cadastro leva o convés junto: a classe é da posição",
		String(i2.fleet[6]["classe"]) == "PORTAAVIOES"
			and String(i2.fleet[5]["classe"]) == "CRUZADOR"
			and extra.get_node_or_null("Conves") != null
			and (i2.fleet[5]["node"] as Node3D).get_node_or_null("Conves") == null,
		"convés em %s, casco 5 virou %s" % [i2.fleet[6]["name"], i2.fleet[5]["classe"]])
	i2.fleet.pop_back()
	i2._aplicar_classes()
	_assert("e o convés volta ao casco que ficou por último quando a presa sai do cadastro",
		String(i2.fleet[5]["classe"]) == "PORTAAVIOES" and _conves_na_cena(i2) == 1,
		"%s, %d nós Conves" % [i2.fleet[5]["classe"], _conves_na_cena(i2)])
	extra.queue_free()

## ---- 3. O painel: nove grupos, trinta e cinco comandos, quatro degraus ------------------------
func _secao_painel() -> void:
	var game: Node3D = await _montar_jogo()
	_alinhar(game)
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
	var mais_bateria := _botao(game, "ARMAMENTO", "ENCURRAÇADOS +1")
	var menos_bateria := _botao(game, "ARMAMENTO", "ENCURRAÇADOS −1")
	var mais_conv := _botao(game, "ARMAMENTO", "PORTA-AVIÕES +1")
	var menos_conv := _botao(game, "ARMAMENTO", "PORTA-AVIÕES −1")
	_assert("os quatro degraus existem no corpo do grupo",
		mais_bateria != null and menos_bateria != null and mais_conv != null and menos_conv != null,
		"bateria e aviação, cada um com +1 e −1 à vista")
	(game.group_heads["ARMAMENTO"] as Button).pressed.emit()
	await _frames(2)
	_assert("clicar o cabeçalho abre o corpo dele e fecha FORMAÇÕES",
		(game.group_bodies["ARMAMENTO"] as Control).visible
			and not (game.group_bodies["FORMAÇÕES"] as Control).visible
			and (game.group_heads["FORMAÇÕES"] as Button).text.substr(0, 1) == "▸",
		"ARMAMENTO aberto, FORMAÇÕES com ▸")
	_assert("o corpo aberto tem os quatro botões à vista",
		_botoes(game, "ARMAMENTO").size() == 4, "4 comandos abertos")
	# O degrau sobe pelo sinal do botão, não por chamada interna: é pelo sinal que o jogador alcança.
	mais_conv.pressed.emit()
	_assert("um clique no +1 de aviação veste um casco pelo próprio sinal",
		int(game.porta_avioes) == 1 and String(game.fleet[5]["classe"]) == "PORTAAVIOES"
			and _conves_na_cena(game) == 1,
		"escada %d, %d conveses" % [game.porta_avioes, _conves_na_cena(game)])
	_assert("e a ponte anuncia o degrau em números",
		String(game.report_label.text).find("AVIAÇÃO: 1 PORTA-AVIÕES") == 0,
		String(game.report_label.text))
	_assert("o anúncio diz agulhas, velocidade, canhão comido e marcha",
		String(game.report_label.text).find("3 caça(s) por salva a 26 u/s, ida e volta") >= 0
			and String(game.report_label.text).find("canhão a 40%") >= 0
			and String(game.report_label.text).find("marcha a 75%") >= 0
			and String(game.report_label.text).find("golpe de 0.6 do próprio fogo por agulha") >= 0,
		String(game.report_label.text))
	var hud_do_conv: PackedStringArray = String(game.command_label.text).split("\n")
	_assert("a primeira linha do HUD lê as duas escadas e o ar, sem ganhar linha",
		hud_do_conv.size() == 5 and hud_do_conv[0].contains("ARMAMENTO: 0/%d ENCURRAÇADO(S) + 1/%d PORTA-AVIÕES"
			% [ENCORACADOS_TETO, PORTAAVIOES_TETO]) and hud_do_conv[0].contains("CAÇAS: 0 NO AR"),
		hud_do_conv[0])
	mais_conv.pressed.emit()
	mais_conv.pressed.emit()
	_assert("a escada tem teto em dois conveses",
		int(game.porta_avioes) == PORTAAVIOES_TETO and _conves_na_cena(game) == 2,
		"três cliques para cima, escada %d" % game.porta_avioes)
	var texto_teto := String(game.report_label.text)
	mais_conv.pressed.emit()
	# A frase não muda entre o teto e o quarto clique — e não deve: com a escada já no degrau 2, a
	# recusa do teto É a resposta. O que se cobra é a conta, não a novidade do texto: escada parada,
	# conveses parados e a ponte tendo dito por que.
	_assert("o quarto clique recusa sem mover a escada",
		int(game.porta_avioes) == PORTAAVIOES_TETO
			and String(game.report_label.text).find("a ponte não tem outro convés") >= 0
			and _conves_na_cena(game) == 2,
		"%s // texto do teto era: %s" % [String(game.report_label.text), texto_teto])
	for i in range(4):
		menos_conv.pressed.emit()
	await _frames(2)
	_assert("a escada tem piso em linha pura",
		int(game.porta_avioes) == 0 and _conves_na_cena(game) == 0,
		"escada %d, %d conveses" % [game.porta_avioes, _conves_na_cena(game)])
	_assert("descer recolhe a silhueta e devolve o cruzador",
		String(game.fleet[5]["classe"]) == "CRUZADOR", "classe %s" % game.fleet[5]["classe"])
	_assert("a bateria e a aviação andam por botões separados: subir convés não mexe em bateria",
		int(game.encoracados) == 0 and _baterias_na_cena(game) == 0,
		"escada %d, %d baterias" % [game.encoracados, _baterias_na_cena(game)])

## ---- 4. Travessia de forma fechada, e o golpe que não sorteia conta ---------------------------
func _secao_voo() -> void:
	var game: Node3D = await _montar_jogo()
	_alinhar(game)
	_blindar(game)
	game._montar_cenario("ABERTO")
	game.rng.seed = 71717
	game.battle_clock = 0.0
	var origem := Vector3(0.0, 0.0, -38.0)
	var destino: Vector3 = (game.enemies[0]["node"] as Node3D).global_position
	var dano := 7.0
	var c := _disparar_caca(game, origem, destino, dano)
	var corda := origem.distance_to(destino)
	var tau := 2.0 * corda / CACA_VELOCIDADE
	_assert("o caçado nasce com corpo, nome no ar e contador de lançamento",
		not c.is_empty() and int(game.cacas.size()) == 1
			and int(game.caca_contagem["lancados"]) == 1,
		"%d no ar, %d lançados" % [game.cacas.size(), game.caca_contagem["lancados"]])
	_assert("tau é a corda inteira em ida-e-volta, não a ida",
		_igual(float(c["tau"]), tau, FOLGA) and _igual(tau, 2.0 * tau * 0.5, 0.0),
		"corda %0.3f u, tau %0.4f s, meia-travessia %0.4f s" % [corda, tau, tau * 0.5])
	var no_do_voo: Node3D = c["no"]
	var rng_do_lance: int = game.rng.state
	var visual_do_lance: int = game.visual_rng.state
	# Ida: o caçado percorre a corda em lerp puro, e o contrato é nenhum sorteio no caminho. A
	# condição olha o PRÓXIMO passo, não o relógio corrente: com 0,1 s por passo e meia-corda em
	# 1,788 s, um laço que testa `battle_clock < tau/2` entra pela última vez com o relógio em 1,7 e
	# sai dele em 1,8 — cobrando o golpe dentro do laço da ida e chamando isso de «a ida não sorteia».
	var passos := 0
	while game.battle_clock + PASSO < 0.5 * tau - 0.000001 and passos < 500:
		game.battle_clock += PASSO
		game._atualizar_cacas()
		passos += 1
	var frac_ida: float = float(game.battle_clock) / tau
	_assert("a ida é lerp fechado em battle_clock, não soma por quadro",
		no_do_voo.global_position.distance_to(origem.lerp(destino, frac_ida * 2.0)) < POS_FOLGA
			and frac_ida < 0.5,
		"a %0.3f da corda (%d passos de 0,1 s), fração %0.4f" % [
			origem.distance_to(no_do_voo.global_position), passos, frac_ida])
	_assert("nem o lançamento nem a ida sorteiam um dígito do combate ou da pintura",
		int(game.rng.state) == rng_do_lance and int(game.visual_rng.state) == visual_do_lance,
		"rng %d, visual %d depois de %d quadros de voo" % [game.rng.state, game.visual_rng.state, passos])
	# O quadro do tiro: a meia-travessia é onde o caçado cobra, e cobra de uma vez.
	game.battle_clock += PASSO
	game._atualizar_cacas()
	_assert("no meio da corda o caçado cobra o casco e marca a meia-travessia",
		bool(c["bateu"]) and int(game.caca_contagem["feridos"]) == 1
			and _igual(500.0 - float(game.enemies[0]["hp"]), dano, 0.0000001),
		"bateu=%s, casco %0.4f pago de %0.2f prometidos" % [str(c["bateu"]),
			500.0 - float(game.enemies[0]["hp"]), dano])
	_assert("e o rastro do golpe sorteia na PINTURA, nunca no gerador de combate",
		int(game.rng.state) == rng_do_lance and int(game.visual_rng.state) != visual_do_lance,
		"rng parado em %d, visual andou para %d" % [game.rng.state, game.visual_rng.state])
	var rng_do_tiro: int = game.rng.state
	var visual_do_tiro: int = game.visual_rng.state
	# Retorno: a segunda metade da mesma forma fechada, até pousar.
	game.battle_clock += PASSO
	game._atualizar_cacas()
	var frac_volta := clampf((game.battle_clock - 0.0) / tau, 0.0, 1.0)
	_assert("o retorno é o lerp invertido da mesma corda",
		no_do_voo.global_position.distance_to(destino.lerp(origem, (frac_volta - 0.5) * 2.0)) < POS_FOLGA,
		"a %0.3f u do convés com fração %0.4f" % [
			origem.distance_to(no_do_voo.global_position), frac_volta])
	_assert("depois do tiro não há mais sorteio nenhum",
		int(game.rng.state) == rng_do_tiro and int(game.visual_rng.state) == visual_do_tiro,
		"rng %d / visual %d" % [game.rng.state, game.visual_rng.state])
	_voar_tudo(game, 200, PASSO)
	_assert("o caçado pousa no convés e sai da lista",
		int(game.cacas.size()) == 0 and int(game.caca_contagem["pousados"]) == 1
			and int(game.caca_contagem["abatidos"]) == 0,
		"%d no ar, %d pousados, %d abatidos" % [game.cacas.size(),
			game.caca_contagem["pousados"], game.caca_contagem["abatidos"]])
	_assert("as duas identidades da travessia fecham", _identidades_boas(game), _identidades(game))
	# Invariância de taxa de quadro: quarenta passos de 0,1 s contra quatro de 1,0 s na MESMA corda.
	var b: Node3D = await _montar_jogo()
	_alinhar(b)
	_blindar(b)
	b._montar_cenario("ABERTO")
	b.rng.seed = 71717
	b.battle_clock = 0.0
	var cb := _disparar_caca(b, origem, destino, dano)
	for k in range(4):
		b.battle_clock += 1.0
		b._atualizar_cacas()
	_voar_tudo(b, 12, 1.0)
	_assert("a travessia é a mesma em 4 passos de 1,0 s que em 40 de 0,1 s",
		int(b.caca_contagem["feridos"]) == 1 and int(b.caca_contagem["pousados"]) == 1
			and _igual(500.0 - float(b.enemies[0]["hp"]), dano, 0.0000001)
			and int(b.rng.state) == int(game.rng.state)
			and int(b.visual_rng.state) == int(game.visual_rng.state),
		"casco %0.4f, %d pousados, rng %d/%d, visual %d/%d" % [500.0 - float(b.enemies[0]["hp"]),
			b.caca_contagem["pousados"], b.rng.state, game.rng.state, b.visual_rng.state,
			game.visual_rng.state])
	_assert("a corda se fecha em quatro passos de 1,0 s porque tau é 2d/v, não número de quadros",
		int(b.cacas.size()) == 0 and float(b.battle_clock) >= float(cb["tau"]),
		"relógio %0.3f s contra tau %0.3f s, %d no ar" % [b.battle_clock, cb["tau"], b.cacas.size()])

## ---- 5. Golpe de ponto contra golpe de disco, no mesmo metro do tabuleiro ----------------------
func _secao_ponto() -> void:
	var game: Node3D = await _montar_jogo()
	_alinhar(game)
	_blindar(game)
	game._montar_cenario("ABERTO")
	_isolar_hostis(game)
	game.battle_clock = 0.0
	var origem := Vector3(0.0, 0.0, -38.0)
	var centro: Vector3 = (game.enemies[0]["node"] as Node3D).global_position
	var ponto := centro + Vector3(5.0, 0.0, 0.0)
	var dano := 9.0
	_disparar_caca(game, origem, ponto, dano)
	_voar_tudo(game, 200, PASSO)
	var casco_5 := 500.0 - float(game.enemies[0]["hp"])
	_assert("a 5,0 u do centro o caçado cobra o golpe inteiro",
		_igual(casco_5, dano, 0.0000001) and int(game.caca_contagem["feridos"]) == 1,
		"%0.4f de casco pago sobre %0.2f de agulha" % [casco_5, dano])
	# A mesma corda com uma carga de bateria: o disco divide o golpe pela geometria, o caçado não.
	var g2: Node3D = await _montar_jogo()
	_alinhar(g2)
	_blindar(g2)
	g2._montar_cenario("ABERTO")
	_isolar_hostis(g2)
	g2.battle_clock = 0.0
	var ponto2: Vector3 = (g2.enemies[0]["node"] as Node3D).global_position + Vector3(5.0, 0.0, 0.0)
	g2._lancar_missil(origem, ponto2, dano)
	_voar_tudo(g2, 200, PASSO)
	var casco_disco := 500.0 - float(g2.enemies[0]["hp"])
	var fator_disco := 1.0 - (5.0 - HULL_RADIUS) / (MISSIL_RAIO - HULL_RADIUS)
	_assert("no mesmo ponto a carga de bateria pagaria só %0.1f%% — as duas leis divergem" % [fator_disco * 100.0],
		_igual(casco_disco, dano * fator_disco, 0.000001) and not _igual(casco_disco, casco_5, 0.001),
		"disco %0.4f contra agulha %0.4f, fator %0.4f" % [casco_disco, casco_5, fator_disco])
	# Fora do alcance reivindicado, o caçado não fere ninguém e volta inteiro.
	var g3: Node3D = await _montar_jogo()
	_alinhar(g3)
	_blindar(g3)
	g3._montar_cenario("ABERTO")
	_isolar_hostis(g3)
	g3.battle_clock = 0.0
	var vazio: Vector3 = (g3.enemies[0]["node"] as Node3D).global_position + Vector3(6.0, 0.0, 0.0)
	_disparar_caca(g3, origem, vazio, dano)
	_voar_tudo(g3, 200, PASSO)
	_assert("a 6,0 u do centro não há casco reivindicado: o vão não fere e o caçado pousa",
		_igual(float(g3.enemies[0]["hp"]), 500.0, 0.0)
			and int(g3.caca_contagem["no_vao"]) == 1 and int(g3.caca_contagem["feridos"]) == 0
			and int(g3.caca_contagem["pousados"]) == 1,
		"casco %0.1f, %d no vão, %d pousados" % [g3.enemies[0]["hp"], g3.caca_contagem["no_vao"],
			g3.caca_contagem["pousados"]])
	_assert("o vão tem a boca do canhão: 5,6 u é HULL_RADIUS mais FOGO_LETAL, e a sonda lê os dois",
		_igual(HULL_RADIUS + FOGO_LETAL, 5.6, 0.0) and 5.0 < HULL_RADIUS + FOGO_LETAL
			and 6.0 > HULL_RADIUS + FOGO_LETAL,
		"%0.1f u de raio de reivindicação" % (HULL_RADIUS + FOGO_LETAL))
	_assert("as identidades valem com acerto, com vão e com pouso",
		_identidades_boas(game) and _identidades_boas(g3), "%s // %s" % [_identidades(game),
			_identidades(g3)])

## ---- 6. A barreira relida na chegada: pedra abate, astro devolve ------------------------------
func _secao_barreira() -> void:
	var game: Node3D = await _montar_jogo()
	_alinhar(game)
	_blindar(game)
	game._montar_cenario("ABERTO")
	game.battle_clock = 0.0
	var origem := Vector3(0.0, 0.0, -38.0)
	var destino: Vector3 = (game.enemies[0]["node"] as Node3D).global_position
	var rocha: Dictionary = game._nova_rocha((origem + destino) * 0.5, 3.2, Vector3.ZERO, 0, 0.0)
	var integridade_antes := float(rocha["integridade"])
	var c := _disparar_caca(game, origem, destino, 9.0)
	_assert("a corda do caçado tem pedra no meio",
		not c.is_empty() and not game._barreira_entre(origem, destino).is_empty(),
		"%d rochas, bloqueio confirmado pelo jogo" % game.rochas.size())
	_voar_tudo(game, 200, PASSO)
	_assert("a pedra ABATE o caçado: bloqueado e perdido, sem pouso",
		int(game.caca_contagem["bloqueados"]) == 1 and int(game.caca_contagem["abatidos"]) == 1
			and int(game.caca_contagem["pousados"]) == 0
			and int(game.caca_contagem["feridos"]) == 0 and int(game.cacas.size()) == 0
			and _igual(float(game.enemies[0]["hp"]), 500.0, 0.0),
		"%d bloqueados, %d abatidos, %d pousados, casco hostil %0.1f" % [
			game.caca_contagem["bloqueados"], game.caca_contagem["abatidos"],
			game.caca_contagem["pousados"], game.enemies[0]["hp"]])
	_assert("caçado não é ogiva: a pedra paga integridade ZERO pelo corpo que derrubou",
		_igual(float(rocha["integridade"]), integridade_antes, 0.0) and int(game.rochas.size()) == 1,
		"integridade %0.2f contra %0.2f de antes, %d rochas no tabuleiro" % [rocha["integridade"],
			integridade_antes, game.rochas.size()])
	_assert("as identidades fecham com um caçado perdido na pedra", _identidades_boas(game),
		_identidades(game))
	# A deriva manda: pedra que saiu da corda antes da chegada não derruba ninguém.
	var g2: Node3D = await _montar_jogo()
	_alinhar(g2)
	_blindar(g2)
	g2._montar_cenario("ABERTO")
	g2.battle_clock = 0.0
	var destino2: Vector3 = (g2.enemies[0]["node"] as Node3D).global_position
	var rocha2: Dictionary = g2._nova_rocha((origem + destino2) * 0.5, 3.2, Vector3.ZERO, 0, 0.0)
	var c2 := _disparar_caca(g2, origem, destino2, 11.0)
	_assert("no lançamento a pedra barra a corda", not c2.is_empty()
		and not g2._barreira_entre(origem, destino2).is_empty(),
		"pedra a %0.1f u da origem" % origem.distance_to(rocha2["pos"]))
	rocha2["pos"] = (rocha2["pos"] as Vector3) + Vector3(40.0, 0.0, 0.0)
	_voar_tudo(g2, 200, PASSO)
	_assert("com a pedra fora da corda na chegada, o caçado cai sobre o casco",
		_igual(500.0 - float(g2.enemies[0]["hp"]), 11.0, 0.0000001)
			and int(g2.caca_contagem["bloqueados"]) == 0
			and int(g2.caca_contagem["abatidos"]) == 0
			and int(g2.caca_contagem["feridos"]) == 1 and int(g2.caca_contagem["pousados"]) == 1,
		"casco %0.1f pago, %d bloqueados, %d abatidos, %d pousados" % [500.0 - float(g2.enemies[0]["hp"]),
			g2.caca_contagem["bloqueados"], g2.caca_contagem["abatidos"], g2.caca_contagem["pousados"]])
	# Astro inteiro: barra, não abate, e o caçado volta ao convés.
	var g3: Node3D = await _montar_jogo()
	_alinhar(g3)
	_blindar(g3)
	g3._montar_cenario("SISTEMA")
	g3.battle_clock = 0.0
	var pp: Vector3 = g3.astros[0]["pos"]
	var o3 := pp + Vector3(0.0, 0.0, 44.0)
	var d3 := pp + Vector3(0.0, 0.0, -44.0)
	var barra: Dictionary = g3._barreira_entre(o3, d3)
	_assert("a corda pelo centro do planeta tem um astro no meio, não uma pedra",
		not barra.is_empty() and barra["pedra"].is_empty() and not barra["astro"].is_empty(),
		"bloqueio a t=%0.3f, raio %0.1f, %d astros e %d rochas em jogo" % [float(barra.get("t", -1.0)),
			float(barra.get("raio", -1.0)), g3.astros.size(), g3.rochas.size()])
	var c3 := _disparar_caca(g3, o3, d3, 13.0)
	_voar_tudo(g3, 200, PASSO)
	_assert("planeta barra sem abater: bloqueado, nada de abatido, e o caçado pousa inteiro",
		not c3.is_empty() and int(g3.caca_contagem["bloqueados"]) == 1
			and int(g3.caca_contagem["abatidos"]) == 0 and int(g3.caca_contagem["no_vao"]) == 0
			and int(g3.caca_contagem["pousados"]) == 1,
		"%d bloqueados, %d abatidos, %d no vão, %d pousados" % [g3.caca_contagem["bloqueados"],
			g3.caca_contagem["abatidos"], g3.caca_contagem["no_vao"], g3.caca_contagem["pousados"]])
	_assert("e o planeta continua inteiro, sem rachadura nem marca nova",
		int(g3.rochas.size()) == 0 and int(g3.astros.size()) == 4,
		"%d rochas, %d astros" % [g3.rochas.size(), g3.astros.size()])
	_assert("a fatura de um bloqueio por astro é um caçado, não dois",
		_identidades_boas(g3), _identidades(g3))

## ---- 7. O convés pega a CAUDA do leque, a bateria pega a cabeça -------------------------------
func _secao_leque() -> void:
	var game: Node3D = await _montar_jogo()
	_alinhar(game)
	_blindar(game)
	game.rng.seed = 82828
	game.selected_target = 0
	game._montar_cenario("ABERTO")
	_isolar_hostis(game)
	game.encoracados = 0
	game.porta_avioes = 1
	game._aplicar_classes()
	for i in range(game.fleet.size() - 1):
		game.fleet[i]["weapons"] = 0.0
	game.battle_clock = 0.0
	game._give_order("ATACAR")
	game.fogo_densidade = 0
	game._resolve_volley()
	var no_conv: int = game.fleet.size() - 1
	var origem: Vector3 = (game.fleet[no_conv]["node"] as Node3D).global_position
	var alvo: Vector3 = (game.enemies[0]["node"] as Node3D).global_position
	var pontos: Array[Vector3] = game._pontos_de_impacto(origem, alvo, no_conv, 0)
	_assert("o convés põe três agulhas no ar e nenhum canhão a mais",
		int(game.cacas.size()) == 3 and int(game.caca_contagem["lancados"]) == 3,
		"%d no ar" % game.cacas.size())
	var ordem_boa := true
	var detalhes := ""
	for k in range(3):
		var dd: Vector3 = game.cacas[k]["destino"]
		var querido: Vector3 = pontos[pontos.size() - 1 - k]
		if dd.distance_to(querido) > POS_FOLGA:
			ordem_boa = false
		detalhes += "%0.3f " % origem.distance_to(dd)
	_assert("as agulhas são os pontos da própria salva, colhidos da CAUDA e em ordem invertida",
		ordem_boa, "%s // leque %d, convés no índice %d" % [detalhes, pontos.size(), no_conv])
	_assert("a agulha do centro cai exatamente sobre o setor comandado",
		_igual(alvo.distance_to(pontos[0]), 0.0, POS_FOLGA),
		"%0.4f u do centro no CONCENTRADO" % alvo.distance_to(pontos[0]))
	_assert("e a mais afastada fecha o disco de 4,5 u, cobrindo o leque inteiro",
		_igual(alvo.distance_to(pontos[2]), FOGO_RAIO[0], POS_FOLGA),
		"%0.3f u, disco de %0.1f u" % [alvo.distance_to(pontos[2]), FOGO_RAIO[0]])
	# A outra ponta do leque: a bateria do mesmo jogo, no mesmo cadastro, colhe a CABEÇA.
	var g2: Node3D = await _montar_jogo()
	_alinhar(g2)
	_blindar(g2)
	g2.rng.seed = 82828
	g2.selected_target = 0
	g2._montar_cenario("ABERTO")
	g2.encoracados = 1
	g2.porta_avioes = 0
	g2._aplicar_classes()
	for i in range(1, g2.fleet.size()):
		g2.fleet[i]["weapons"] = 0.0
	g2.battle_clock = 0.0
	g2._give_order("ATACAR")
	g2.fogo_densidade = 0
	g2._resolve_volley()
	var origem2: Vector3 = (g2.fleet[0]["node"] as Node3D).global_position
	var alvo2: Vector3 = (g2.enemies[0]["node"] as Node3D).global_position
	var pontos2: Array[Vector3] = g2._pontos_de_impacto(origem2, alvo2, 0, 0)
	var cabeca_boa := true
	for k in range(int(g2.misseis.size())):
		if (g2.misseis[k]["destino"] as Vector3).distance_to(pontos2[k]) > POS_FOLGA:
			cabeca_boa = false
	_assert("a bateria colhe a cabeça do mesmo leque, sem inverter nada",
		cabeca_boa and int(g2.misseis.size()) == 2 and int(g2.cacas.size()) == 0,
		"%d cargas nos índices 0 e 1, %d caçados num encouraçado" % [g2.misseis.size(),
			g2.cacas.size()])
	# DISPERSAR é uma alavanca de ponte, dois canais de dano: o convés herda o disco, não um
	# desenho próprio.
	var g3: Node3D = await _montar_jogo()
	_alinhar(g3)
	_blindar(g3)
	g3.rng.seed = 82828
	g3.selected_target = 0
	g3._montar_cenario("ABERTO")
	_isolar_hostis(g3)
	g3.encoracados = 0
	g3.porta_avioes = 1
	g3._aplicar_classes()
	for i in range(g3.fleet.size() - 1):
		g3.fleet[i]["weapons"] = 0.0
	g3.battle_clock = 0.0
	g3._give_order("ATACAR")
	g3.fogo_densidade = 2
	g3._resolve_volley()
	var alvo3: Vector3 = (g3.enemies[0]["node"] as Node3D).global_position
	var mais_longe := 0.0
	for c in g3.cacas:
		mais_longe = maxf(mais_longe, alvo3.distance_to(c["destino"]))
	_assert("no DISPERSO o mesmo casco abre também o leque da aviação",
		_igual(mais_longe, FOGO_RAIO[2], 0.001),
		"agulha mais afastada a %0.3f u, disco de %0.1f u" % [mais_longe, FOGO_RAIO[2]])
	_assert("e a densidade não mudou o número de agulhas nem de sorteios",
		int(g3.cacas.size()) == 3 and int(g3.rng.state) == int(game.rng.state),
		"rng %d dos dois lados" % g3.rng.state)
	# As duas pontas do leque cobram, e só com os vizinhos fora do tabuleiro dá para dizer «caiu no
	# vão» em vez de «caiu no vizinho»: a esquadra hostil marcha a 6 u de intervalos, então uma agulha
	# a 14 u do alvo ainda pousaria dentro do raio de reivindicação de outro casco e a medida diria
	# «feriu» onde o desenho dizia «espalhou».
	_voar_tudo(game, 300, PASSO)
	_voar_tudo(g3, 300, PASSO)
	_assert("no CONCENTRADO as três agulhas pousam sobre o mesmo casco",
		int(game.caca_contagem["feridos"]) == 3 and int(game.caca_contagem["no_vao"]) == 0,
		"%d feriram, %d no vão" % [game.caca_contagem["feridos"], game.caca_contagem["no_vao"]])
	_assert("no DISPERSO só a agulha do centro alcança: o leque largo fere menos por desenho",
		int(g3.caca_contagem["feridos"]) == 1 and int(g3.caca_contagem["no_vao"]) == 2,
		"DISPERSO: %d feriram, %d no vão // CONCENTRADO: %d feriram, %d no vão" % [
			g3.caca_contagem["feridos"], g3.caca_contagem["no_vao"],
			game.caca_contagem["feridos"], game.caca_contagem["no_vao"]])
	_assert("e as duas contas fecham as identidades da travessia",
		_identidades_boas(game) and _identidades_boas(g3),
		"%s // %s" % [_identidades(game), _identidades(g3)])

## ---- 8. A mesa não conta caçado como casco ----------------------------------------------------
func _secao_mesa() -> void:
	var game: Node3D = await _montar_jogo()
	_alinhar(game)
	_blindar(game)
	game.rng.seed = 93939
	game.selected_target = 0
	game._montar_cenario("ABERTO")
	game.encoracados = 0
	game.porta_avioes = PORTAAVIOES_TETO
	game._aplicar_classes()
	game.battle_clock = 0.0
	game._resolve_volley()
	var vivos := 0
	for unit in game.fleet:
		if float(unit["hp"]) > 0.0:
			vivos += 1
	for unit in game.enemies:
		if float(unit["hp"]) > 0.0:
			vivos += 1
	_assert("doze cascos vivos, doze blips — com seis caçados no ar",
		int(game.cacas.size()) == 6 and int(game.holo_blips.size()) == vivos,
		"%d blips para %d cascos, %d caçados em voo" % [game.holo_blips.size(), vivos,
			game.cacas.size()])
	var marcas_antes := int(game.holo_cenario.size())
	var nos_ar_antes := int(game.cacas.size())
	_voar_tudo(game, 200, PASSO)
	_assert("o golpe do grupo aéreo não ganha marca na mesa nem material novo por clarão",
		int(game.holo_cenario.size()) == marcas_antes,
		"%d marcas de cenário, mesmas de antes do voo" % game.holo_cenario.size())
	_assert("e a conta do convés atravessa o tabuleiro com a fatura legível",
		nos_ar_antes == 6 and String(game.salva_resumo).find("aviação:") >= 0
			and int(game.cacas.size()) == 0,
		String(game.salva_resumo))
	_assert("a linha da aviação só nasce depois do primeiro caçado lançado",
		String(game.salva_resumo).find("aviação:") >= 0, String(game.salva_resumo))

## ---- 9. A prova central: dois jogos, mesma semente, a cauda intacta ---------------------------
func _secao_ab() -> void:
	# Lado A: linha pura. Lado B: dois conveses lançando oito salvas. A única diferença é a classe,
	# e o que se cobra é a frase do contrato: o grupo aéreo fere sem empurrar a cauda do sorteio.
	# Os cascos estão blindados a 500 justamente para ninguém morrer na janela — morto um casco,
	# muda a quantidade de salvas hostis e a divergência seria de estrutura, não de aviação. O fogo
	# vai a CONCENTRADO nos dois lados porque as agulhas herdam o disco da salva: no DISPERSO elas
	# caem no vazio por projeto e a corrida mediria o vazio, não o canal.
	var a: Node3D = await _montar_jogo()
	_alinhar(a)
	_blindar(a)
	a.rng.seed = 414141
	a.selected_target = 0
	a.battle_clock = 0.0
	a.fogo_densidade = 0
	a._montar_cenario("ABERTO")
	a._give_order("ATACAR")
	var rng_a_antes: int = a.rng.state
	var visual_a_antes: int = a.visual_rng.state
	# A régua é lida no cadastro limpo, ANTES de a primeira salva: os dois canhões vêm de
	# `_dano_de_canhao` com arma e tripulação a 100, que é o estado com que os dois tabuleiros
	# largam. Ler depois da corrida cobrava a conta de cascos já feridos — foi assim que a primeira
	# versão desta corrida previu 23,112 contra 8,640 pagos e chamou a diferença de palpite.
	var canhao_cruz: float = float(a._dano_de_canhao(a.fleet[0])) * 1.8
	for k in range(8):
		a._resolve_volley()
		a.battle_clock += 0.2
		a._atualizar_misseis()
		a._atualizar_cacas()
	_voar_tudo(a, 120, PASSO)
	var b: Node3D = await _montar_jogo()
	_alinhar(b)
	_blindar(b)
	b.rng.seed = 414141
	b.selected_target = 0
	b.battle_clock = 0.0
	b.fogo_densidade = 0
	b._montar_cenario("ABERTO")
	b._give_order("ATACAR")
	b.porta_avioes = PORTAAVIOES_TETO
	b._aplicar_classes()
	var rng_b_antes: int = b.rng.state
	var visual_b_antes: int = b.visual_rng.state
	var canhao_conv: float = float(b._dano_de_canhao(b.fleet[5])) * 1.8
	for k in range(8):
		b._resolve_volley()
		b.battle_clock += 0.2
		b._atualizar_misseis()
		b._atualizar_cacas()
	_voar_tudo(b, 120, PASSO)
	_assert("os dois jogos largam do mesmo estado de gerador",
		rng_a_antes == rng_b_antes and visual_a_antes == visual_b_antes,
		"rng %d e visual_rng %d dos dois lados" % [rng_a_antes, visual_a_antes])
	_assert("e chegam ao MESMO rng.state depois de oito salvas com dois conveses lançando",
		int(a.rng.state) == int(b.rng.state),
		"rng %d nos dois tabuleiros — a aviação não empurra a cauda do combate" % a.rng.state)
	_assert("o gerador de pintura anda, e é o único direito dele: dois traços por golpe",
		int(b.visual_rng.state) != int(a.visual_rng.state),
		"visual_rng %d contra %d" % [b.visual_rng.state, a.visual_rng.state])
	var somados_a := _hostis_somados(a)
	var somados_b := _hostis_somados(b)
	# A régua não é um «bem menor»: é a conta fechada das duas classes, lida na função nomeada e no
	# cadastro limpo — cada salva troca um cruzador de 4,5 por um convés de 1,8 mais três agulhas de
	# 1,08, e são oito salvas por dois conveses.
	var agulha: float = canhao_conv * CACA_FATOR
	var esperado: float = 8.0 * float(PORTAAVIOES_TETO) * (canhao_conv + 3.0 * agulha - canhao_cruz)
	_assert("mas os cascos hostis divergem — e divergem pela conta, não por palpite",
		_igual(somados_a - somados_b, esperado, 0.004),
		"%0.4f pagos a mais contra %0.4f previstos (cruzador %0.4f, convés %0.4f, agulha %0.4f)" % [
			somados_a - somados_b, esperado, canhao_cruz, canhao_conv, agulha])
	_assert("a corrida não foi medida em tabuleiro vazio",
		int(b.caca_contagem["lancados"]) == 8 * PORTAAVIOES_TETO * 3
			and int(b.caca_contagem["feridos"]) > 0 and float(b.caca_contagem["dano"]) > 0.0
			and somados_a > 2000.0 and int(a.caca_contagem["lancados"]) == 0,
		"B: %d lançados, %d feriram, %d no vão, %d bloqueados, %d pousados, %0.1f de dano // A: %d lançados" % [
			b.caca_contagem["lancados"], b.caca_contagem["feridos"], b.caca_contagem["no_vao"],
			b.caca_contagem["bloqueados"], b.caca_contagem["pousados"], b.caca_contagem["dano"],
			a.caca_contagem["lancados"]])
	_assert("o dano registrado é exatamente a soma das agulhas cobradas",
		_igual(float(b.caca_contagem["dano"]), float(b.caca_contagem["feridos"]) * agulha, 0.0005)
			and int(b.caca_contagem["feridos"]) == 8 * PORTAAVIOES_TETO * 3,
		"%d agulhas cobraram %0.3f de %0.3f cada" % [b.caca_contagem["feridos"],
			b.caca_contagem["dano"], agulha])
	_assert("as duas identidades fecham na corrida inteira", _identidades_boas(b),
		_identidades(b))
	_assert("com caçado no ar o resumo anuncia a aviação, e sem caçado não",
		String(a.salva_resumo).find("aviação") < 0 and String(b.salva_resumo).find("aviação:") >= 0,
		"B: %s" % String(b.salva_resumo))
	# A assinatura do Lado A tem de ser a de um jogo que nunca encostou na escada: a mesma sequência
	# de salvas num terceiro tabuleiro, sem classe nenhuma, dá a mesma string.
	var c: Node3D = await _montar_jogo()
	_alinhar(c)
	_blindar(c)
	c.rng.seed = 414141
	c.selected_target = 0
	c.battle_clock = 0.0
	c.fogo_densidade = 0
	c._montar_cenario("ABERTO")
	c._give_order("ATACAR")
	for k in range(8):
		c._resolve_volley()
		c.battle_clock += 0.2
		c._atualizar_misseis()
		c._atualizar_cacas()
	_voar_tudo(c, 120, PASSO)
	_assert("linha pura e jogo que nunca viu a escada são o mesmo jogo",
		_assinatura(a) == _assinatura(c) and _assinatura(a).length() > 200,
		"assinaturas idênticas em %d caracteres // %s" % [_assinatura(a).length(),
			_diferencaassinatura(_assinatura(a), _assinatura(c))])

func _initialize() -> void:
	await _secao_inercia()
	await _secao_escada()
	await _secao_painel()
	await _secao_voo()
	await _secao_ponto()
	await _secao_barreira()
	await _secao_leque()
	await _secao_mesa()
	await _secao_ab()
	for linha in notes:
		print(linha)
	print("SONDA-CACAS: veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	quit()
