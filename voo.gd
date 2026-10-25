## Lei de voo de todo corpo que obedece a um posto: cascos de linha, hostis e blocos da massa.
##
## Antes desta folha existir, locomoção era `move_toward`: a ordem escrevia a posição e a velocidade
## saía *derivada* do deslocamento. Duas consequências que a esquadra inteira pagou: um encouraçado
## arrancava a 8,0 u/s no mesmo quadro em que um cruzador arrancava a 8,0 u/s, e uma meia-volta
## custava um quadro. Classe não aparecia no manobrar — só no teto de marcha, e o teto valia a partir
## do quadro zero. A capitânia já tinha anisotropia (`CAPITAL_SPEED` / `CAPITAL_REVERSE` /
## `CAPITAL_LIFT`), e era a única: o resto da frota era um disco de velocidade igual em todos os eixos.
##
## O que esta folha cobra, em uma passada por quadro:
##
## 1) ESTADO, NÃO RESOLUÇÃO. Quem anda carrega `vel` (u/s), `rumo` (rad) e `giro` (rad/s aplicado). A
##    posição sai de `pos + vel * delta`; nada escreve posição por diferença até um alvo.
## 2) TIMÃO COM VELOCIDADE ANGULAR. O casco gira para o curso comandado a no máximo
##    `giro_maximo × delta` por quadro. Uma meia-volta de cruzador custa 3,9 s e a de encouraçado
##    8,9 s — é manobra com preço, não animação. `rumo_alvo` NAN segura a atitude (empuxo sem leme).
## 3) ENVELOPE POR EIXO DO PRÓPRIO CASCO. O vetor comandado é resolvido nos eixos do casco e clampado
##    por eixo: proa até `teto`, ré até `teto × re`, través e empuxo até `teto × traves`, e a resultante
##    nunca passa de `teto`. Clampar só a magnitude (o engano mais provável) daria um disco outra vez,
##    e as três famílias que medem eixos reprovariam juntas.
## 4) ARRANQUE COM TEMPO. `vel` caminha até o alvo a `aceleracao × delta` por quadro. O estado
##    estacionário continua sendo exatamente o teto de sempre: inércia entra como tempo de resposta,
##    nunca como buff ou nerf de marcha máxima.
## 5) CHEGADA QUE FREIA E POUSA EM CIMA. `vetor_ate` limita a marcha por `raiz(2 · a · d)`, o casco
##    desacelera até o posto, e dentro de `CAPTURA_DE_POUSO` o posto é gravado exato com `vel` zerada.
##    É isso que preserva a contrato da fatia 1 — "pousa em cima do destino, resto 0,000000 u, parada
##    não custa escrita" — depois de trocar a resolução por integração. Sem o freio, o passo de
##    0,100 u de um bloco a marcha cheia passaria por cima de uma captura de 0,02 u e a formação
##    oscilaria em volta do posto para sempre.
##
## Números, e por que estes: a escala é 1 u = 1 km, então as marchas são as mesmas que o jogo já
## pagava (`teto` de casco com ordem de navegação = 8,0 u/s, marcha do bloco = 6,0 u/s) e o que esta
## folha acrescenta é o tempo de resposta. Cruzador a 4,0 u/s² reachinga a marcha cheia em 2,0 s —
## meio segundo de aceleração pareceria feitiço, dois segundos parecem peso. O encouraçado paga duas
## vezes nos dois eixos que o nome cobra: 1,6 u/s² (5,0 s para a marcha) e 0,35 rad/s de timão. O
## porta-aviões é grande mas não é blindado: 2,0 u/s² e 0,5 rad/s. `re` e `traves` são frações do
## teto do próprio casco, na ordem ré < través < proa sempre, e o bloco — vinte e quatro casas
## voando como um corpo só, com atrito interno — é o mais lerdo de todos em giro e o mais apertado em
## ré: 0,5 rad/s, `traves` 0,4, `re` 0,2, 3,0 u/s² para chegar aos 6,0 u/s em 2,0 s de tela.
##
## O que fica FORA de propósito: a malha dos doze cascos não gira com o `rumo` (ela nasce em
## `ship.rotation.y = PI` e as sondas de fotograma leem a silhueta assim). A anisotropia é de lei, não
## de desenho; virar a silhueta junto é trabalho de janela, com suas três sondas de olhos, e não
## entra aqui para não mover medida de quadro dentro de uma fatia de física. A capitânia também fica
## com o próprio rig: ela já tem inércia, rolagem e empuxo vertical, e trocá-la de lei dentro desta
## fatia seria mover dois instrumentos de uma vez.
##
## Uso: godot --headless --path . --quit-after 3000 -s res://tools/probes/voo.gd

## Ficha da massa: um bloco são ~100 cascos em formação fechada, e o conjunto inteiro gira como um
## corpo com atrito interno. Lerdão no timão e apertadíssimo de ré — é isso que faz a muralha hostil
## levar tempo para virar a linha, e é lido na tela, não no log.
const FICHA_BLOCO := {"aceleracao": 3.0, "giro_maximo": 0.5, "traves": 0.4, "re": 0.2}
## Boca de pouso: dentro dela o posto é gravado exato e a velocidade morre. Duas centésimas de
## unidade (200 m na escala) é invisível a 154 u de campo e suficiente para o freio entregar: a
## `a = 3,0 u/s²`, a marcha de 0,346 u/s dentro dessa boca dá 0,0058 u de passo por quadro — um
## terço da boca, então a aproximação converge em vez de saltar por cima do posto.
const CAPTURA_DE_POUSO := 0.02


## Proa do casco no mundo. A convenção da casa é `rumo = atan2(x, -z)`: rumo zero olha para -z, que é
## para onde a esquadra aliada avança, e meio-círculo olha para +z, o da muralha hostil.
static func eixo(rumo: float) -> Vector3:
	return Vector3(sin(rumo), 0.0, -cos(rumo))


## Través a boreste de quem está no rumo dado.
static func traves(rumo: float) -> Vector3:
	return Vector3(cos(rumo), 0.0, sin(rumo))


## Curso do rumo de um vetor do mundo. Zero não é um vetor: quem chama segura a atitude nesse caso.
static func rumo_de(vetor: Vector3) -> float:
	if vetor.length_squared() <= 0.0:
		return NAN
	return atan2(vetor.x, -vetor.z)


## Leitura de ficha com piso: hostil sem classe declarada voa no envelope de cruzador, e ficha
## nenhuma pode produzir NAN por chave esquecida.
static func _num(ficha: Dictionary, chave: String, padrao: float) -> float:
	var v = ficha.get(chave, padrao)
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		return padrao
	var f := float(v)
	return padrao if not is_finite(f) else f


## Um quadro de voo. `vetor` é o comando em velocidade-alvo (o empuxo que a ordem pede, já na
## magnitude do teto daquela ordem); `rumo_alvo` é o curso para onde o leme aponta, ou NAN para
## segurar a atitude; `teto` é a marcha máxima daquela ordem, daquela mobilidade, daquela classe.
static func quadro(pos: Vector3, vel: Vector3, rumo: float, vetor: Vector3, rumo_alvo: float,
		delta: float, teto: float, ficha: Dictionary) -> Dictionary:
	# ── leme ──
	var novo_rumo := rumo
	var virado := 0.0
	if not is_nan(rumo_alvo):
		var teto_giro := _num(ficha, "giro_maximo", 0.5) * delta
		virado = clampf(wrapf(rumo_alvo - rumo, -PI, PI), -teto_giro, teto_giro)
		novo_rumo = wrapf(rumo + virado, -PI, PI)
	# ── envelope por eixo do casco ──
	var proa := eixo(novo_rumo)
	var boreste := traves(novo_rumo)
	var f_traves := _num(ficha, "traves", 0.4)
	var f_re := _num(ficha, "re", 0.2)
	var alvo := proa * clampf(vetor.dot(proa), -teto * f_re, teto) \
		+ boreste * clampf(vetor.dot(boreste), -teto * f_traves, teto * f_traves) \
		+ Vector3.UP * clampf(vetor.y, -teto * f_traves, teto * f_traves)
	var modulo := alvo.length()
	if modulo > teto and modulo > 0.0:
		alvo = alvo * (teto / modulo)
	# ── empuxo com tempo ──
	var novo_vel := vel.move_toward(alvo, _num(ficha, "aceleracao", 3.0) * delta)
	return {"pos": pos + novo_vel * delta, "vel": novo_vel, "rumo": novo_rumo,
		"giro": virado / maxf(delta, 0.0001)}


## Comando de aproximação: a direção do posto com a marcha limitada pelo freio de chegada. É o que
## impede a perseguição de virar pêndulo — `raiz(2 · a · d)` é a curva de desaceleração máxima,
## então o casco que vem a toda já entra na boca de pouso andando devagar.
static func vetor_ate(pos: Vector3, destino: Vector3, ficha: Dictionary, teto: float) -> Vector3:
	var desloc := destino - pos
	var d := desloc.length()
	if d <= 0.0:
		return Vector3.ZERO
	var freio := sqrt(2.0 * _num(ficha, "aceleracao", 3.0) * d)
	return desloc * (minf(teto, freio) / d)


## Perseguição de posto pela porta da lei: resolve o comando, gira para o curso, integra, e pousa em
## cima do destino quando entra na boca. Devolve o estado inteiro (`pos`, `vel`, `rumo`, `giro`) para
## quem precisa carregar os quatro no bloco ou no casco.
##
## `proa_comandada` é o curso que o leme deve guardar em vez do curso até o destino, e o padrão NAN
## deixa todos os chamadores antigos onde estavam. Serve a um caso só: um posto que anda devagar de
## lado faz o resíduo de perseguição apontar para través, e quem gira para ele larga a fachada da
## linha — a mesma distinção que `main.gd` já faz entre `_pilotar` (destino absoluto) e `_empuxar`
## (atitude comandada).
static func marchar(pos: Vector3, vel: Vector3, rumo: float, destino: Vector3, delta: float,
		teto: float, ficha: Dictionary, proa_comandada := NAN) -> Dictionary:
	var vetor := vetor_ate(pos, destino, ficha, teto)
	var curso := proa_comandada if not is_nan(proa_comandada) else rumo_de(vetor)
	var estado := quadro(pos, vel, rumo, vetor, curso, delta, teto, ficha)
	if (estado["pos"] as Vector3).distance_to(destino) <= CAPTURA_DE_POUSO:
		estado["pos"] = destino
		estado["vel"] = Vector3.ZERO
		# Parado, o casco segura o último ângulo: `rumo_de(ZERO)` seria virar para olhar o próprio
		# eixo nulo, que é a mesma armadilha que a lei velha tinha no `atan2` de deslocamento.
	return estado
