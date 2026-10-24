## Lei de escudo de todo casco que leva tiro: cascos de linha, hostis, capitânia e blocos da massa.
##
## Até esta folha existir, `hp` era a única armadura do jogo: o dano entrava e o casco caía no mesmo
## número, lance a lance, e não havia nada entre a bala e o navio. Numa esquadra de vinte mil cascos
## isso cobra um preço de leitura: fogo disperso e fogo concentrado afundam no mesmo ritmo, porque o
## que existe é uma régua só.
##
## O escudo é a segunda régua, e a lei é esta, em uma passada por quadro:
##
## 1) MORDE PRIMEIRO, TRANSBORDA DEPOIS. Um lance de canhão, de bateria ou de aviação acha a casca
##    antes do casco. O que sobra do transbordo entra em `hp` no mesmo golpe — sem segundo sorteio,
##    sem espera, sem "próxima salva". A conta é `maxf(0, dano - casca)`.
## 2) COLAPSO ABRE JANELA. Quando a casca zera, o casco fica `escudo_cai` segundos exposto, e nesse
##    tempo a regeneração não roda. É a janela que faz a salva concentrada valer mais que a mesma
##    salva espalhada: quem desnuda a casca de um casco tem quatro segundos para matá-lo antes de a
##    casca começar a voltar.
## 3) REGENERA EM CONSTANTE, NÃO EM SORTEIO, E NÃO NA OFICINA. A casca volta a `ESCUDO_REGENERA`
##    unidades por segundo, por conta própria. Ela não entra na fila de `REPAROS`, não obedece à
##    prioridade de setor e não usa a taxa da oficina: casco consertado é trabalho, casca de escudo é
##    o emissor respirando. Por isso o escudo **não** conserta no ritmo do casco — `1,2` u/s contra
##    os `0,55` u/s de `hp` que a oficina AUTO entrega a um cruzador de tripulação inteira.
## 4) SEGURA FOGO, NÃO SEGURA MASSA NEM MAPA. Abalroamento, corona da estrela e poço gravitacional
##    escrevem o casco por fora desta lei. Um casco de vinte mil toneladas atravessando o seu não é
##    projétil, e calor de fotosfera não escolhe alvo — as duas coisas já eram contrato medido antes
##    do escudo nascer e continuam exatamente com os números de antes. É também o que faz o
##    abalroamento continuar sendo a única forma de fechar uma conta contra um casco blindado.
## 5) ATAQUE DE SUBSISTEMA PASSA POR CIMA. `MOTORES`, `ARMAS` e `TRIPULACAO` não mordem a casca: a
##    mira apontada para uma bocal de motor cobra o bocal, escudo ou não. É o escudo quem dá motivo
##    novo para o seletor de subsistema existir — com casca armada, matar é caro e cegar é barato.
##
## Números, e por que estes: a casca de um casco de linha é `20,0` — um quinto do casco de `100`, e
## oito salvas de um cruzador de artilharia inteira (`_dano_de_canhao` a 2,5 por salva). A janela de
## colapso é `4,0` s, dois ciclos e meio do `fire_clock` de 1,6 s: curta o bastante para o casco
## desnudado ainda morrer no mesmo engajamento, longa o bastante para a tríade "desnudar → matar" ser
## jogável. A regeneração é `1,2` u/s: um intervalo de salva devolve `1,92` e a salva de um único
## canhão cobra `2,5` — logo um casco vigiado por um atirador só ainda sangra devagar, dois ou mais
## nunca deixam a casca voltar, e a escolha de densidade de fogo passa a ter consequência. O bloco da
## massa é o caso extremo deliberado: casca de `4,4` — exatamente duas salvas de bloco armado cheio
## (`DANO_DE_BLOCO` 2,2 × 2) — e **sem regeneração**, porque dentro de um bloco não há estaleiro nem
## tempo: a casca da muralha é gasta, não recarregada.
##
## O que fica FORA de propósito: pintura. A casca é número de painel e de conta, não halo — nenhum
## material novo, nenhum nó novo, e o apagão da ruína, a lista de materiais e o gabarito de filhos da
## ponte continuam os mesmos. Escalhar a silhueta com a casca armada é fatura de janela, com suas três
## sondas de olho, e não entra aqui.
##
## Uso: godot --headless --path . --quit-after 1800 -s res://tools/probes/escudo.gd

## Casca de um casco de linha, em unidades de dano. Um quinto do `hp` de cadastro.
const ESCUDO_DE_CASCO := 20.0
## Respiração do emissor: unidades de casca por segundo, constante declarada, nenhum sorteio e
## nenhuma ligação com a fila de reparo.
const ESCUDO_REGENERA := 1.2
## Vulnerabilidade depois do colapso, em segundos. Durante a janela a regeneração não roda.
const ESCUDO_JANELA := 4.0
## Casca de um bloco da massa: duas salvas de bloco armado cheio, e sem regeneração.
const ESCUDO_DE_BLOCO := 4.4


## O estado de casca de um corpo novo. Nasce cheio: um casco que entra em batalha já sem escudo não
## prova lei nenhuma, só a ausência dela.
static func nasce(teto: float) -> Dictionary:
	return {"escudo": teto, "escudo_max": teto, "escudo_cai": 0.0}


## Morde `dano` na casca de `unit` e devolve o transbordo — o que a lei manda para o casco. Sem casca
## armada, o transbordo é o dano inteiro, que é exatamente "não multiplicar".
static func morder(unit: Dictionary, dano: float) -> float:
	var casca := float(unit.get("escudo", 0.0))
	if dano <= 0.0 or casca <= 0.0:
		return dano
	if dano < casca:
		unit["escudo"] = casca - dano
		return 0.0
	unit["escudo"] = 0.0
	unit["escudo_cai"] = ESCUDO_JANELA
	return dano - casca


## Um quadro da casca: queima a janela de vulnerabilidade e, com ela fechada, devolve regeneração até
## o teto do corpo. Corpos sem casca (massa) saem pela porta do `escudo_max` zerado.
static func quadro(unit: Dictionary, delta: float) -> void:
	var teto := float(unit.get("escudo_max", 0.0))
	var janela := float(unit.get("escudo_cai", 0.0))
	if janela > 0.0:
		unit["escudo_cai"] = maxf(0.0, janela - delta)
		return
	if teto <= 0.0:
		return
	var casca := float(unit.get("escudo", 0.0))
	if casca < teto:
		unit["escudo"] = minf(teto, casca + ESCUDO_REGENERA * delta)
