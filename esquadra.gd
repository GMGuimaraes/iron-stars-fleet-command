extends RefCounted
## Esquadra de blocos: a massa que navega em volta dos doze núcleos.
##
## Um bloco não é uma nave: são ~100 cascos voando em formação fechada, desenhados como a MESMA
## nave replicada numa grade de 4 × 3 × 2 = vinte e quatro casas — um paralelepípedo organizado.
## A tropa existe como `Dictionary` e como transformada autorgada num `MultiMesh`; não há nó por
## bloco nem nó por casa. Cento e vinte blocos por lado, vinte e quatro casas cada, dois
## `MultiMeshInstance3D` na cena: é assim que a batalha passa de doze cascos para dezenas de
## milhares de navios sem virar dezenas de milhares de draw calls.
##
## Atrito é a economia da massa: `navios` é recurso que se gasta. O impacto consome casas do topo
## para baixo, o bloco encolhe à vista, e o fogo devolvido sai proporcional ao que ainda restou.
## CASCO É o próprio `navios` — não existe segunda contabilidade para o mesmo casco; MOTORES,
## ARMAS e TRIPULAÇÃO são os outros três eixos, no mesmo pé dos quatro setores dos núcleos. Só o
## casco não se conserta: navio afundado não volta. TRIPULACAO a zero é rendição, uma vez só.
##
## Lei da casa, respeitada à letra: nada aqui toca `rng` nem `visual_rng`. A casa é o índice, o
## rumo sai da velocidade real e o setor escolhido é `(id + número da salva) % 4` — rotação, não
## sorteio. A prova está em `tools/probes/esquadra.gd`, que relê os dois geradores depois de
## duzentos quadros de massa e de cem trocas de salva.
##
## Lei da cena, respeitada à letra: a transformada é escrita AQUI e nunca lida de volta do
## `MultiMesh` — sob headless a leitura devolve identidade. O estado verdadeiro mora nas duas
## listas; a pintura é derivação pura, e um bloco parado com o mesmo número de casas não é
## repintado.
##
## Lei da largada, respeitada à letra: as duas muralhas começam separadas por campo suficiente para
## ser cruzado, e o campo é geometria, não sorteio. A estação de cada lado segue os núcleos, o recuo
## hostil trava a fachada a `DISTANCIA_DE_CONTATO` da nossa, e os blocos chegam até a estação a
## `MARCHA_DE_BLOCO`. O campo não vem da grade: aberta a fenda entre blocos, os dois lados a
## recuo zero ainda nascem a 24,0 u de fachada a fachada — menos que o próprio contato, e longe de
## qualquer travessia. É o recuo que compra os 154 u da largada, e a asserção contrafactual
## (`tools/probes/esquadra.gd`, família 2) é o que impede a grade de ser creditada por eles.

## Lei de voo: cada bloco anda por integração (`vel` + `rumo` + `giro`), não por resolução de
## posição. A ficha é uma só para os 240 blocos — `Voo.FICHA_BLOCO` — porque o que manobra é a
## muralha, não o bloco individual, e folha de conta não toca `rng`.
const Voo := preload("res://voo.gd")

## Durabilidade da casca: o mesmo `Escudo.morder` dos casco individuais, com uma placa de
## esquadra no lugar do emissor de linha. O bloco nasce com `escudo_max` em zero porque a muralha
## não tem oficina flutuante por trás de cada casa — a placa segura as duas primeiras salvas de
## casco e depois o bloco fica exposto até afundar ou vencer. Nenhum `quadro` é chamado aqui, e é
## isso, não uma exceção na lei, que torna a regeneração impossível.
const Escudo := preload("res://escudo.gd")

## Grade de casas do bloco. Quatro de boreste a bombordo, três camadas de altura, duas de
## profundidade: 24 é o que fecha o orçamento acordado (240 blocos × 24 = 5 760 instâncias) e é
## grosso o bastante para o atrito ser lido de longe.
const CASAS_X := 4
const CASAS_Y := 3
const CASAS_Z := 2
const CASAS := CASAS_X * CASAS_Y * CASAS_Z
## Passo por eixo, e não um passo só. A replica nao e cubica: a caixa crua da malha e 3,647 de asa
## a asa x 1,07 de altura x 5,0 de proa a popa, e a 0,25 isso fecha **0,912 x 0,268 x 1,25 u**. Com
## passo unico de 1,6 restavam 0,688 u no costado mas só **0,35 u de proa a popa** -- dois cascos
## quase encostados no eixo que o olho le como profundidade, e era isso que fazia a largada parecer
## monte. 3,2 abre 2,29 no costado e 1,95 no comprimento; a camada fica em 1,6 porque o casco tem
## 0,27 de altura e ar vertical extra so afastaria o bloco sem nada a mostrar.
const PASSO_CASA_X := 3.2
const PASSO_CASA_Y := 1.6
const PASSO_CASA_Z := 3.2
## Escala da réplica sobre a malha de cinco bilhetes. A boca é lida da caixa da malha escalada, não
## de conta de cabeça: **3,647 u de asa a asa × 0,25 fecha 0,912 u** dentro da casa de 3,2, com
## 2,288 u de folga entre duas fileiras — que é o que separa "bloco organizado" de "mancha" e o que
## a régua de vão de `tools/probes/massa_visivel.gd` confere no visor.
## O bloco não escala com o atrito: quem encolhe é o número de
## casas, única leitura honesta de "fileiras perdidas".
const ESCALA_REPLICA := 0.25

## Grade do esquadrão: 5 × 4 blocos = 20. Passo separado em x e z porque o bloco não é quadrado: o
## piso do bloco fecha 10,5 × 4,45 u (centros de casa em (4−1)×3,2 e (2−1)×3,2, mais a boca e o
## comprimento da replica), e um passo único obrigaria o respiro de vante a ser o mesmo de boreste.
const COLUNAS_NO_ESQUADRAO := 5
const LINHAS_NO_ESQUADRAO := 4
const BLOCOS_NO_ESQUADRAO := COLUNAS_NO_ESQUADRAO * LINHAS_NO_ESQUADRAO
## 13 em x deixa 2,49 u de ar entre os cascos mais próximos de dois blocos vizinhos; 7 em z deixa
## 2,55 sobre o comprimento da réplica. É o ar que faz a muralha ler como fileiras de blocos em vez
## de parede contínua — e o que cabia nos 8 × 5 antigos era 0,7 u, quase nada.
const PASSO_BLOCO_X := 13.0
const PASSO_BLOCO_Z := 7.0
## Grade do lado: 3 × 2 esquadrões = 6. A segunda dimensão é **altura**, não profundidade: empilhar
## os esquadrões em y abre a muralha em dois andares (e dá a quem está em cima o alvo de quem está
## embaixo, que é o pedido) sem comer o fundo do tabuleiro, que é justamente o que as duas linhas
## precisam para ter campo entre elas. Campo de 15 blocos de boreste a bombordo por 4 de vante.
const COLUNAS_NO_LADO := 3
const CAMADAS_NO_LADO := 2
const ESQUADROES_NO_LADO := COLUNAS_NO_LADO * CAMADAS_NO_LADO
## Passo de CONTINUAÇÃO de grade em x: 65 = (5 − 1) × 13 + 13, então o bloco que fecha um esquadrão
## e o que abre o vizinho ficam à mesma distância dos colegas de dentro. Em y a regra é outra — os
## dois andares não se seguem dentro de uma fileira, apenas se sobrepõem — e 12 u abrem 8,5 u de ar
## entre os cascos do andar de cima e os de baixo, sobre os 3,47 que o bloco tem de altura.
## A profundidade do LADO sai (4 − 1) × 7 + 4,45 = 25,45 u, ±12,7 em torno do núcleo: com as duas
## linhas a ~45 u, as fachadas já não se atravessam, e sobra fundo de sobra para o campo de
## aproximação abaixo.
const PASSO_ESQUADRAO_X := 65.0
const PASSO_ESQUADRAO_Y := 12.0
## Fundo lido de uma muralha, de fachada a traseira, em unidades de tabuleiro: os centros dos
## blocos mais extremos (3 × 7) mais o vão entre as duas casas de proa e popa (1 × 3,2) = 24,2 u. É a
## caixa que a sonda confere contra o tabuleiro, não o braço que a aproximação usa para saber onde
## para -- para isso existe `FACHADA_DA_MURALHA`.
const FUNDO_DA_MURALHA := float((LINHAS_NO_ESQUADRAO - 1) * PASSO_BLOCO_Z) \
	+ float((CASAS_Z - 1) * PASSO_CASA_Z)
## Braço do centro da muralha até a fileira da frente, lido no CENTRO do casco: (4 − 1) × 7 ÷ 2 =
## 10,5 u. A fachada é esse centro, não a ponta do casco (a ponta vem da caixa da malha e é a sonda
## quem a lê), e as duas muralhas têm o mesmo braço: a estação hostil para quando os dois centros
## frontais chegam a `DISTANCIA_DE_CONTATO`, o que acontece a recuo −16,0 -- travessia de 154,0 u
## para 40,0 u medida na família 10 da sonda.
const FACHADA_DA_MURALHA := float(LINHAS_NO_ESQUADRAO - 1) * PASSO_BLOCO_Z / 2.0
const BLOCOS_NO_LADO := ESQUADROES_NO_LADO * BLOCOS_NO_ESQUADRAO
## Instâncias de um `MultiMesh` de lado: é a conta que o probe confere. Um lote só por time é o que
## impede a esquadra de custar uma chamada de desenho por casa; o preço real medido em janela está em
## `tools/probes/massa_visivel.gd` (11,9 chamadas para os 240 blocos, não as "duas" prometidas).
const INSTANCIAS_POR_LADO := BLOCOS_NO_LADO * CASAS

## Lotiação de um bloco, em cascos de linha. A casa vale ⌈100 / 24⌉ = 5 navios; a última pode
## valer menos e é ela que some primeiro.
const NAVIOS_NO_BLOCO := 100
## ---- A muralha que respira ----
## Amplitude da custódia de posto, em u por eixo, e o ciclo em segundos. As duas amplitudes são
## medidas no ar que existe: no boreste o vizinho mais próximo está a 13,0 u de centro a centro com
## 10,52 u de caixa (2,48 u de ar), na altura os dois andares estão a 12,0 u com 3,47 u de caixa
## (8,53 u de ar). Por isso o boreste respira por ANDAR e a altura por ESQUADRÃO:
##
## * em x, todos os blocos do mesmo andar têm a mesma fase, então a distância de fileira nunca muda —
##   um deslocamento por esquadrão fecharia o ar de 2,48 u na emenda entre formações (medido: 1,94 u,
##   e a lei do ar da família 2 da sonda reprova);
## * em y, os seis esquadrões respiram defasados de 60°, porque é aí que há folga: mesmo que os dois
##   andares se aproximem ao mesmo tempo, sobram 8,53 − 0,9 = 7,63 u de ar.
##
## Em `z` a deriva não entra de propósito: é o eixo do contato, e a fachada que as famílias 2 e 10
## assinam é medida centro a centro. O ciclo de 9 s dá ~0,4 u/s de ponta, um sexto da marcha de
## 6,0 u/s, para a deriva ler como vida de formatura e nunca como manobra: quem muda de ground é a
## ordem da ponte, nunca este sinusóide.
const DERIVA_X := 0.6
const DERIVA_Y := 0.45
const DERIVA_CICLO := 9.0
## O deslocamento de cada esquadrão neste instante, recalculado uma vez por `passo`. O componente em
## x só depende do andar, o em y depende do esquadrão — é a divisão acima aplicada.
var _derivas: Array[Vector3] = []
## Marcha da massa, em u/s: um bloco cruza a faixa do próprio esquadrão (32 u de largura) em cinco
## segundos, o bastante para a manobra ser lida no visor sem a linha virar formiga.
const MARCHA_DE_BLOCO := 6.0
## Dano de canhão de um bloco inteiro por salva, antes de escalar por navios e ARMAS. Um quinto
## do golpe de um casco de linha: vinte blocos equivalem a ~4 cascos de linha de fogo, e a
## contagem da massa chega ao mesmo fim da contagem dos núcleos em dezenas de salvas, não em duas.
const DANO_DE_BLOCO := 2.2
## Distância de FACHADA em que a muralha hostil para de avançar. Tem de ser maior que zero para
## bloco nenhum atravessar bloco, e o `ALCANCE_DE_BLOCO` é lido A PARTIR dela: a régua da geometria
## amarra os dois números, então mover o contato move o alcance e a muralha inteira continua
## atirando. É o freio da aproximação, não uma ordem do jogador.
const DISTANCIA_DE_CONTATO := 40.0
## Alcance de linha de batalha, LIDO DA GEOMETRIA DAS DUAS MURALHAS e não de hábito: no contato, o
## centro de uma muralha fica a `2 × FACHADA_DA_MURALHA + DISTANCIA_DE_CONTATO` = 61,0 u do centro
## da outra, e a retaguarda — a fileira mais afastada — herda exatamente essa conta. Um andar de
## desnível (`PASSO_ESQUADRAO_Y`, a segunda dimensão do lado) soma-se a ela quando o bloco só tem
## inimigo vivo no andar de cima, e é o teto honesto da régua: 73,0 u.
##
## Com o número de hábito, 60,0 u, a retaguarda ficava FORA do próprio alcance no contato: 60 dos
## 240 blocos armados não achavam alvo, e a tela perdia um quarto do fogo — exatamente a queixa de
## "não parece que todas as naves atiram ao mesmo tempo". Medido em `tools/probes/esquadra.gd`,
## família 11: 180 lances contra 240 blocos armados.
const ALCANCE_DE_BLOCO := 2.0 * FACHADA_DA_MURALHA + DISTANCIA_DE_CONTATO + PASSO_ESQUADRAO_Y
## Campo que a muralha hostil cruza na largada, em unidades de tabuleiro: para trás do centro dos
## próprios núcleos, ela nasce a esta distância e anda até o contato a `MARCHA_DE_BLOCO`. Com 130 u
## de recuo, a fachada começa a 154,0 u da nossa (medido em `tools/probes/esquadra.gd`, família 10)
## e o cruzamento leva 19,0 s de marcha visível -- o "espaço a ser atravessado" que a largada de
## 10 u não tinha. Não sorteia nada: é constante de cadastro, e a mesma em toda partida.
const CAMPO_DE_APROXIMACAO := 130.0
## Reparo dos três eixos que se consertam, por segundo. Casco fica de fora de propósito.
const REPARO := {"MOTORES": 1.1, "ARMAS": 0.9, "TRIPULACAO": 0.6}
## Os quatro eixos que uma salva pode cobrar, em rotação. `CASCO` é o valor de `navios`, não uma
## chave do dicionário — por isso a escrita dele tem caminho próprio em `_aplicar_golpe`.
const SETORES_DA_SALVA := ["CASCO", "MOTORES", "ARMAS", "TRIPULACAO"]
## Piso de tripulação de um bloco rendido: sem ele, o mesmo bloco voltaria a zero na salva
## seguinte e cruzaria o tabuleiro de lado a cada 1,6 s.
const TRIPULACAO_DE_PRESA := 24.0

var blocos_aliados: Array[Dictionary] = []
var blocos_hostis: Array[Dictionary] = []
## Âncora de cada lado: centro de massa dos núcleos vivos. A esquadra segue a linha; a linha não
## segue a esquadra — os doze cascos continuam mandando no próprio posicionamento.
var centro_aliado := Vector3.ZERO
var centro_hostil := Vector3.ZERO
## Recuo da muralha hostil em z, medido a partir do centro dos próprios núcleos: negativo é ficar
## para trás, longe da nossa linha. É o único número de posicionamento que a massa tem por si, e
## existe porque a grade, sozinha, não faz campo: a recuo zero as duas fachadas nascem a 24,0 u
## -- menos que `DISTANCIA_DE_CONTATO` e sem nada a cruzar. É este recuo, não o ar entre blocos,
## quem compra os 154 u da largada (a contrafactual está em `tools/probes/esquadra.gd`, família 2).
## Quem caminha são os BLOCOS, a `MARCHA_DE_BLOCO`, até o posto que esta estação dita: o recuo é
## alvo, teleporte de corpo não há.
var recuo_hostil := 0.0
## ---- A caixa que para um lance (fatia 4) ----
## meia-caixa da malha de uma réplica, escalada. Lida do próprio `ArrayMesh`, não cravada na
## calculadora: é a mesma malha que `pintar` escreve no `MultiMesh`, então a caixa que decide a
## obstrução e o casco que o olho vê têm de ser o mesmo corpo por construção.
var _meia_casco := Vector3.ZERO
## salva em curso: caixas dos dois lados, indexadas pela posição na lista do lado. Recalculadas
## uma vez por salva (não por par) porque é o único jeito de a varredura custar
## `BLOCOS_NO_LADO` caixas e não `BLOCOS_NO_LADO²`.
var _caixas := {"aliado": [], "hostil": []}
var salva_numero := 0
var perdas_aliadas := 0
var perdas_hostis := 0
var presas := 0
## Quantos blocos cruzaram para o outro lado NA SALVA que acabou de resolver: é o que
## `troca_salva` devolve, e é lido depois de `_prencher_rendicoes` consumir as marcas.
var _rendidas_na_ultima_salva := 0
## A fila de fogo da última salva, no formato que o desenho lê: `{"origem": Vector3, "alvo":
## Vector3, "lado": String}` por lance. É espelho do ledger, não uma segunda conta: se o tamanho
## divergir de `lancados`, a tela está mostrando fogo que a conta não cobrou -- ou escondendo fogo
## que cobrou. Quem escreve é `troca_salva`, e quem lê é `_armar_tracos_da_massa` em `main.gd`.
var pares_da_ultima_salva: Array[Dictionary] = []
## Relógio da muralha, em segundos de `passo()`. É o que alimenta a deriva de custódia: com a fase
## lida do tempo acumulado pelo próprio módulo, a sonda pode adiantar a muralha quadro a quadro sem
## depender do relógio do motor nem de sorteio. Zera junto com a batalha, senão a segunda partida
## começaria com os blocos espalhados na fase do fim da anterior.
var tempo := 0.0
## Ordem do comandante sobre a massa: quando a ponte concentra fogo, os blocos aliados largam o
## próprio vizinho e apontam todos para o bloco hostil mais próximo desta posição. É a única leitura
## que a massa faz do jogo dos doze cascos, e é leitura de ORDEM, nunca de estado: nenhum `hp`,
## nenhum índice de frota, nenhum sorteio entra aqui.
var fogo_concentrado := false
var alvo_comandado := Vector3.ZERO
## Quantas casas cada `MultiMesh` tem de fato escritas. A rendição encolhe uma lista, e a cauda que
## ela pintou fica órfã: sem este registro os vinte e quatro transformados do bloco que partiu
## continuariam no ar, um bloco fantasma pendurado na tela do lado que o perdeu. Sobrevive de
## propósito ao `montar()` — é a contagem da partida ANTERIOR que diz o que há para apagar.
var _casas_pintadas := {"aliado": 0, "hostil": 0}

## Ordem da casa dentro do bloco: camada por camada, de baixo para cima; dentro da camada, da
## boreste para a bombordo e de vante para trás. É esta ordem que faz o atrito FECHAR O TOPO do
## paralelepípedo em vez de esburacá-lo no meio — a silhueta encolhendo é a própria leitura da
## lotação restante.
static func casa_local(c: int) -> Vector3:
	var por_camada := CASAS_X * CASAS_Z
	var camada := int(float(c) / float(por_camada))
	var dentro := c % por_camada
	var ix := dentro % CASAS_X
	var iz := int(float(dentro) / float(CASAS_X))
	return Vector3(
		(float(ix) - float(CASAS_X - 1) / 2.0) * PASSO_CASA_X,
		(float(camada) - float(CASAS_Y - 1) / 2.0) * PASSO_CASA_Y,
		(float(iz) - float(CASAS_Z - 1) / 2.0) * PASSO_CASA_Z)


## Posto do bloco na grade do lado: posição do esquadrão no tabuleiro do lado mais o posto do
## bloco dentro do esquadrão. Aritmética pura de índice, sem sorteio e sem leitura de cena. A
## segunda dimensão do LADO é altura: `linha_esq` empilha o andar de cima sobre o de baixo, e o
## fundo do tabuleiro fica inteiro para o campo que as duas muralhas cruzam.
static func posto_no_lado(esq: int, indice: int, ancora: Vector3) -> Vector3:
	var coluna_esq := esq % COLUNAS_NO_LADO
	var camada_esq := int(float(esq) / float(COLUNAS_NO_LADO))
	var bc := indice % COLUNAS_NO_ESQUADRAO
	var br := int(float(indice) / float(COLUNAS_NO_ESQUADRAO))
	return ancora + Vector3(
		(float(coluna_esq) - float(COLUNAS_NO_LADO - 1) / 2.0) * PASSO_ESQUADRAO_X
			+ (float(bc) - float(COLUNAS_NO_ESQUADRAO - 1) / 2.0) * PASSO_BLOCO_X,
		(float(camada_esq) - float(CAMADAS_NO_LADO - 1) / 2.0) * PASSO_ESQUADRAO_Y,
		(float(br) - float(LINHAS_NO_ESQUADRAO - 1) / 2.0) * PASSO_BLOCO_Z)


## A proa da linha: o aliado olha para -z, o hostil para +z, e é a mesma convenção de `Voo.eixo`. É
## a atitude que um bloco em custódia de posto guarda enquanto desliza — a muralha respira de frente
## para o inimigo, não de través.
static func rumo_da_linha(lado: String) -> float:
	return 0.0 if lado == "aliado" else PI


func _novo_bloco(id: int, esq: int, indice: int, lado: String, pos: Vector3) -> Dictionary:
	return {"id": id, "esquadrao": esq, "formacao": indice, "lado": lado, "pos": pos,
		"vel": Vector3.ZERO, "rumo": rumo_da_linha(lado), "giro": 0.0,
		"navios": float(NAVIOS_NO_BLOCO),
		# Placa de esquadra: `escudo_max` em zero é a forma que a lei lê como "não recomponha".
		"escudo": Escudo.ESCUDO_DE_BLOCO, "escudo_max": 0.0, "escudo_cai": 0.0,
		"MOTORES": 100.0, "ARMAS": 100.0, "TRIPULACAO": 100.0, "vivo": true, "presa": false,
		"rendicao": false,
		# Ordem da ponte: o bloco persegue o posto do esquadrão enquanto `com_destino` é falso, e
		# persegue `destino` (ponto absoluto, com y) quando a ponte escreveu um. Os dois campos
		# andam juntos porque `Vector3.ZERO` é um destino legítimo — um falso com destino zero é a
		# muralha inteira navegando para a origem do mundo.
		"destino": Vector3.ZERO, "com_destino": false, "selecionado": false,
		"pintas": {"casas": -1, "pos": Vector3(1e9, 0.0, 0.0), "rumo": 1e9}}


## ---- A nave replicada ----
##
## Cinco bilhetes fundidos numa única `ArrayMesh`: espinha, proa em cone, popa, dorso e as duas
## asas. É a MESMA família de silhueta do cruzador de linha dos núcleos, compactada para caber na
## casa de 3,2 u — o bloco precisa de fileiras que se leiam como fileiras, e a malha crua mede
## 3,647 × 1,07 × 5,0 u, então um casco deste tamanho dentro de uma casa apertada viraria borrão
## sobreposto. Boca final **0,912 u** e comprimento **1,25 u**, lidos da caixa escalada, com
## **2,288 u** de folga no costado e **1,95 u** de proa a popa: o paralelepípedo continua sendo lido
## como um volume só, mas agora com costura nos dois eixos que o olho chama de profundidade.
##
## Fundir é o que paga a conta: com uma malha só por time, 2 880 casas viram UM `MultiMesh` e um
## lote. Com cinco primitivas separadas seriam cinco passadas de desenho por time — ainda barato, mas
## a lei da casa é a de `campo_estelar`: o céu inteiro cabe numa instância.
var _malha: ArrayMesh = null


func malha_replica() -> ArrayMesh:
	if _malha != null:
		return _malha
	var partes: Array = [
		[_caixa(Vector3(1.2, 0.5, 3.0)), Transform3D(Basis(), Vector3.ZERO)],
		[_cone(0.5, 0.06, 1.2), Transform3D(
			Basis.from_euler(Vector3(-PI / 2.0, 0.0, 0.0)), Vector3(0.0, 0.0, -2.1))],
		[_caixa(Vector3(1.5, 0.6, 0.8)), Transform3D(Basis(), Vector3(0.0, 0.02, 1.9))],
		[_caixa(Vector3(0.6, 0.3, 1.9)), Transform3D(Basis(), Vector3(0.0, 0.42, -0.4))],
	]
	for lado in [-1.0, 1.0]:
		partes.append([_caixa(Vector3(1.0, 0.12, 1.8)), Transform3D(
			Basis.from_euler(Vector3(0.0, lado * 0.42, 0.0)), Vector3(lado * 1.0, -0.02, 0.6))])
	var vertices := PackedVector3Array()
	var normais := PackedVector3Array()
	var uvs := PackedVector2Array()
	for parte in partes:
		_fundir(vertices, normais, uvs, parte[0], parte[1])
	var superficie: Array = []
	superficie.resize(Mesh.ARRAY_MAX)
	superficie[Mesh.ARRAY_VERTEX] = vertices
	superficie[Mesh.ARRAY_NORMAL] = normais
	superficie[Mesh.ARRAY_TEX_UV] = uvs
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, superficie)
	_malha = malha
	return malha


static func _caixa(size: Vector3) -> BoxMesh:
	var caixa := BoxMesh.new()
	caixa.size = size
	return caixa


## Cone de proa. Oito segmentos bastam para 1,2 u de comprimento lidos a 40 u da câmara, e é o
## mesmo `radial` dos cones de proa nos núcleos.
static func _cone(r_base: float, r_top: float, height: float) -> CylinderMesh:
	var cone := CylinderMesh.new()
	cone.bottom_radius = r_base
	cone.top_radius = r_top
	cone.height = height
	cone.rings = 1
	cone.radial_segments = 8
	return cone


## Copia uma primitiva para dentro dos arrays fundidos, aplicando a transformada em vértice e em
## normal. Índices são expandidos: a malha final é não-indexada, como a do geoide.
static func _fundir(vertices: PackedVector3Array, normais: PackedVector3Array,
		uvs: PackedVector2Array, malha: PrimitiveMesh, xf: Transform3D) -> void:
	var s := malha.surface_get_arrays(0)
	var v: PackedVector3Array = s[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = s[Mesh.ARRAY_NORMAL]
	var t: PackedVector2Array = s[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = s[Mesh.ARRAY_INDEX]
	var ordem := idx
	if ordem.is_empty():
		ordem = PackedInt32Array()
		for k in range(v.size()):
			ordem.append(k)
	var com_uv := t.size() == v.size()
	for k in ordem:
		vertices.append(xf * v[k])
		# Normal vai pela base e se renormaliza: com escala uniforme (é o caso) isso é exato, e
		# sem renormalizar a réplica perderia o degradê de metal que o Compatibility lê da difusa.
		normais.append((xf.basis * n[k]).normalized())
		if com_uv:
			uvs.append(t[k])
		else:
			uvs.append(Vector2.ZERO)


## Monta as duas massas. `nucleos_*` são as posições dos doze cascos de hoje: a muralha de um lado é
## ANCORADA NA ESTAÇÃO do lado — o centro de massa dos seus núcleos, mais o recuo que a lei da
## largada manda — e o esquadrão `i` ocupa a faixa `i` da muralha (coluna em boreste, andar em
## altura), na mesma ordem do casco `i`. Ancorar cada esquadrão no PRÓPRIO núcleo foi tentado e é
## mentira de grade: os cascos estão a ~5 u uns dos outros e o passo da massa é 13 × 7, então as seis
## grades particulares saíam deslocadas entre si e 36 pares de companheiros de linha se atravessavam
## (medido em `tools/probes/esquadra.gd`). Uma grade por lado é o que faz a formação ser lida como
## formação.
func montar(nucleos_aliados: Array, nucleos_hostis: Array) -> void:
	blocos_aliados.clear()
	blocos_hostis.clear()
	salva_numero = 0
	perdas_aliadas = 0
	perdas_hostis = 0
	presas = 0
	# A deriva morre com a batalha velha: sem isto a segunda partida começaria com cada esquadrão
	# na fase do fim da anterior, e o relógio da muralha não é estado que deva atravessar um RECOMEÇAR.
	tempo = 0.0
	_derivas = []
	# A ordem da ponte não herda de partida nenhuma, e a fila do desenho morre com a batalha velha:
	# remonta sem isto seria a tela mostrar lances de blocos que já não existem.
	fogo_concentrado = false
	alvo_comandado = Vector3.ZERO
	pares_da_ultima_salva = []
	centro_aliado = _centro_de(nucleos_aliados)
	centro_hostil = _centro_de(nucleos_hostis)
	recuo_hostil = -float(CAMPO_DE_APROXIMACAO)
	var id := 0
	for lado in ["aliado", "hostil"]:
		var lista := blocos_aliados if lado == "aliado" else blocos_hostis
		var ancora := estacao(lado)
		for esq in range(ESQUADROES_NO_LADO):
			for indice in range(BLOCOS_NO_ESQUADRAO):
				lista.append(_novo_bloco(id, esq, indice, lado,
					posto_no_lado(esq, indice, ancora)))
				id += 1


static func _centro_de(nucleos: Array) -> Vector3:
	if nucleos.is_empty():
		return Vector3.ZERO
	var soma := Vector3.ZERO
	for n in nucleos:
		soma += n
	return soma / float(nucleos.size())


func centros(lado: String) -> Vector3:
	return centro_aliado if lado == "aliado" else centro_hostil


## Ponto do tabuleiro ao qual a grade do lado está presa: o centro dos próprios núcleos para o
## aliado, que defende a própria linha, e o centro recuado para o hostil, que ainda está cruzando o
## campo. É a âncora real da muralha; `centros()` continua sendo a régua dos núcleos, que as sondas
## e o README citam.
func estacao(lado: String) -> Vector3:
	return centros(lado) + Vector3(0.0, 0.0, recuo_hostil if lado == "hostil" else 0.0)


## Para onde o recuo anda: o tanto de trás que põe a nossa fachada e a deles a
## `DISTANCIA_DE_CONTATO` uma da outra, nunca adiantado em relação aos próprios núcleos. As duas
## fachadas medem o mesmo braço a partir do centro de cada muralha (`FACHADA_DA_MURALHA`), por isso
## ele entra duas vezes na conta: usar o fundo inteiro no lugar do braço deixa a linha parada 3,2 u
## antes do contato, que é a quebra que a família 10 da sonda pegou na primeira rodada. Se a nossa
## linha recuar, o alvo recua junto; se ela avançar, a muralha encurta o campo até o contato.
func _recuo_alvo() -> float:
	var alvo := centro_aliado.z - 2.0 * FACHADA_DA_MURALHA - DISTANCIA_DE_CONTATO
	return minf(0.0, alvo - centro_hostil.z)


func lista_de(lado: String) -> Array[Dictionary]:
	return blocos_aliados if lado == "aliado" else blocos_hostis


## Casas vivas do bloco: o topo fecha primeiro. Sem navio não há casa, e zero casas é o que mata.
static func casas_vivas(bloco: Dictionary) -> int:
	var frac := clampf(float(bloco["navios"]) / float(NAVIOS_NO_BLOCO), 0.0, 1.0)
	if frac <= 0.0:
		return 0
	return maxi(1, int(ceilf(frac * float(CASAS))))


## ---- Linha de visada da massa ----

## A caixa de um bloco: o volume dos cascos VIVOS, na atitude do bloco, mais a meia-caixa da malha.
## É lida casa a casa porque a ordem das casas fecha o TOPO antes do meio (`casa_local`): um bloco
## que perdeu um terço da lotação perde também a cobertura que dava a quem está atrás dele, e é
## isso que faz a escudeira ralada abrir corredor para a fileira seguinte. Sem navio, sem caixa:
## `size` negativo é o "não existe" do `AABB`, e `_entrada_na_caixa` recusa volume assim.
func caixa_do_bloco(bloco: Dictionary) -> AABB:
	var casas := casas_vivas(bloco)
	if casas <= 0 or not bool(bloco["vivo"]):
		return AABB(Vector3.ZERO, Vector3(-1.0, -1.0, -1.0))
	if _meia_casco == Vector3.ZERO:
		_meia_casco = malha_replica().get_aabb().size * 0.5 * ESCALA_REPLICA
	var rot := Basis.from_euler(Vector3(0.0, float(bloco["rumo"]), 0.0))
	var minimo := Vector3.ONE * 1e9
	var maximo := Vector3.ONE * -1e9
	for c in range(casas):
		var local: Vector3 = rot * casa_local(c)
		minimo = Vector3(
			minf(minimo.x, local.x - _meia_casco.x),
			minf(minimo.y, local.y - _meia_casco.y),
			minf(minimo.z, local.z - _meia_casco.z))
		maximo = Vector3(
			maxf(maximo.x, local.x + _meia_casco.x),
			maxf(maximo.y, local.y + _meia_casco.y),
			maxf(maximo.z, local.z + _meia_casco.z))
	var centro: Vector3 = bloco["pos"]
	return AABB(centro + minimo, maximo - minimo)


## Em que ponto do trecho `origem → origem+trecho` a linha entra na caixa. Devolve INF quando a
## linha passa fora, e 0 quando a origem já está dentro dela. Método das lajes (slab): o corredor
## de um bloco é uma caixa, não uma esfera — com a esfera de `raio = 5,26` os vizinhos de boreste,
## a 2,48 u de ar, parariam lances que passam por fora de todo casco desenhado.
static func _entrada_na_caixa(origem: Vector3, trecho: Vector3, caixa: AABB) -> float:
	if caixa.size.x < 0.0 or caixa.size.y < 0.0 or caixa.size.z < 0.0:
		return INF
	var t0 := 0.0
	var t1 := 1.0
	for e in range(3):
		var o: float = origem[e]
		var d: float = trecho[e]
		var lo: float = caixa.position[e]
		var hi: float = lo + caixa.size[e]
		if absf(d) < 1e-9:
			if o < lo or o > hi:
				return INF
			continue
		var a := (lo - o) / d
		var b := (hi - o) / d
		if a > b:
			var troca := a
			a = b
			b = troca
		t0 = maxf(t0, a)
		t1 = minf(t1, b)
		if t0 > t1:
			return INF
	return t0


## A caixa mais à frente na linha de um lance, dentro de uma lista. Devolve o índice do bloco e o
## `t` da entrada; índice -1 quando nada atravessa o corredor antes do fim do trecho. Ordem de
## lista decide empate, nunca sorteio: a mesma montada gemea fecha o mesmo par.
func _absorvedor(origem: Vector3, trecho: Vector3, lado: String, exceto: int) -> Dictionary:
	var caixas: Array = _caixas[lado]
	var melhor := -1
	var melhor_t := INF
	for i in range(caixas.size()):
		if i == exceto:
			continue
		var t := _entrada_na_caixa(origem, trecho, caixas[i])
		if t < melhor_t:
			melhor_t = t
			melhor = i
	return {"i": melhor, "t": melhor_t}


## Um quadro de massa: cada bloco persegue o posto do seu esquadrão, e o posto persegue a estação do
## lado. Integração pela `Voo.marchar`, nunca teleportar — é a mesma lei que faz as formações dos doze
## cascos levarem tempo de locomoção, e é ela que faz o campo de aproximação ser cruzado marchando em
## vez de resolvido de uma vez: a estação da muralha hostil apenas segue a nossa linha, quem anda até
## ela são os blocos, a `MARCHA_DE_BLOCO` alcançada em ~2 s de ramp (3,0 u/s² para 6,0 u/s) e pouso
## gravado exato dentro de `Voo.CAPTURA_DE_POUSO`.
func passo(delta: float, nucleos_aliados: Array, nucleos_hostis: Array) -> void:
	centro_aliado = _centro_de(nucleos_aliados)
	centro_hostil = _centro_de(nucleos_hostis)
	recuo_hostil = _recuo_alvo()
	tempo += delta
	if _derivas.size() != ESQUADROES_NO_LADO:
		_derivas.resize(ESQUADROES_NO_LADO)
	for e in range(ESQUADROES_NO_LADO):
		var base := tempo * TAU / DERIVA_CICLO
		var andar := int(float(e) / float(COLUNAS_NO_LADO))
		var fase_x := base + float(andar) * TAU / float(CAMADAS_NO_LADO)
		var fase_y := base + float(e) * TAU / float(ESQUADROES_NO_LADO)
		_derivas[e] = Vector3(cos(fase_x) * DERIVA_X, sin(fase_y * 0.5) * DERIVA_Y, 0.0)
	for lado in ["aliado", "hostil"]:
		for b in lista_de(lado):
			if not bool(b["vivo"]):
				continue
			var posto := posto_no_lado(int(b["esquadrao"]), int(b["formacao"]), estacao(lado))
			# Ordem da ponte ganha do posto de formação: o bloco persegue o ponto que o comandante
			# apontou e segura lá, em vez de ser puxado de volta pela estação. Mesma lei para os dois
			# casos, então nem o posto nem o destino teleportam.
			if bool(b["com_destino"]):
				posto = b["destino"] as Vector3
			else:
				# Custódia de posto: o bloco nunca estaciona de vez, ele orbita o próprio lugar na
				# grade. Boreste com a fase do ANDAR e altura com a fase do ESQUADRÃO — a divisão está
				# escrita na régua de `DERIVA_X`: é o eixo em que os vizinhos têm só 2,48 u de ar, e
				# deslizá-los em fases diferentes fecharia a fileira na emenda entre formações. Uma
				# formação que se move como um corpo é o que faz a muralha ler como frota em vez de
				# nuvem de mosquitos. Em `z` a deriva não entra de propósito: é o eixo do contato, e a
				# lei de aproximação (`DISTANCIA_DE_CONTATO`, `FACHADA_DA_MURALHA`) é medida centro a
				# centro; balançar vante e trás mudaria a fachada que as sondas assinam.
				posto += _derivas[int(b["esquadrao"]) % _derivas.size()]
			var partida: Vector3 = b["pos"]
			var marcha := MARCHA_DE_BLOCO * (0.35 + float(b["MOTORES"]) / 100.0 * 0.65)
			# Proa comandada, só na custódia: o único resíduo que um bloco de linha persegue é o
			# deslize da própria respira — trinta centímetros de boreste — e girar para acompanhar
			# isso apresentaria o través ao inimigo e encolheria a silhueta do bloco no visor
			# (`massa_visivel.gd` mediu a boca cair de 630 px para 236 px no mesmo grau de lente).
			# Quem recebeu destino da ponte continua virando para o ponto apontado.
			var proa := NAN if bool(b["com_destino"]) else rumo_da_linha(lado)
			var voo := Voo.marchar(partida, b["vel"] as Vector3, float(b["rumo"]), posto,
				delta, marcha, Voo.FICHA_BLOCO, proa)
			b["pos"] = voo["pos"]
			b["vel"] = voo["vel"]
			b["rumo"] = voo["rumo"]
			b["giro"] = voo["giro"]
	_reparar(delta)


## Os três eixos que se consertam sobem até o teto, na taxa cravada. O casco fica de fora: é a
## diferença entre uma tropa que se recompõe e um recurso que se gasta.
func _reparar(delta: float) -> void:
	for lado in ["aliado", "hostil"]:
		for b in lista_de(lado):
			if not bool(b["vivo"]):
				continue
			for eixo in REPARO:
				b[eixo] = minf(100.0, float(b[eixo]) + float(REPARO[eixo]) * delta)


static func _mais_proximo(bloco: Dictionary, lista: Array[Dictionary]) -> Dictionary:
	var melhor: Dictionary = {}
	var melhor_d := INF
	for c in lista:
		if not bool(c["vivo"]):
			continue
		var d: float = (c["pos"] as Vector3).distance_to(bloco["pos"])
		if d < melhor_d and d <= ALCANCE_DE_BLOCO:
			melhor_d = d
			melhor = c
	return melhor


## O bloco vivo mais próximo de uma POSICAO, sem portão de alcance. É a leitura da ordem: o
## comandante aponta um ponto do tabuleiro e a massa escolhe o adversário daquele ponto — quem
## decide o alvo é a posição comandada, nunca a posição de quem atira.
static func _vizinho_de(pos: Vector3, lista: Array[Dictionary]) -> Dictionary:
	var melhor: Dictionary = {}
	var melhor_d := INF
	for c in lista:
		if not bool(c["vivo"]):
			continue
		var d: float = (c["pos"] as Vector3).distance_to(pos)
		if d < melhor_d:
			melhor_d = d
			melhor = c
	return melhor


## A lei de escolha do alvo. Regime de linha: cada bloco é uma frota e atira no próprio vizinho, e
## é isto que espalha a salva pela muralha inteira em vez de convergir para o centro do campo.
## Regime comandado — só nosso, só aliado: a ordem da ponte vale para todos os blocos, o alvo é o
## MESMO (`visado`, resolvido uma única vez por salva), e o preço é a retaguarda: quem não alcança
## o alvo único fica com as portas fechadas. A ordem é lida como ORDEM, nunca como estado dos doze
## cascos, senão o ledger da massa passaria a depender do painel da ponte.
static func _alvo_do_bloco(bloco: Dictionary, alvos: Array[Dictionary],
		visado: Dictionary, comandado: bool) -> Dictionary:
	if not comandado:
		return _mais_proximo(bloco, alvos)
	if visado.is_empty():
		return {}
	if (visado["pos"] as Vector3).distance_to(bloco["pos"]) > ALCANCE_DE_BLOCO:
		return {}
	return visado


## Ordem da ponte: a massa aliada larga o próprio vizinho e concentra no bloco hostil mais próximo
## desta posição. `soltar_fogo` devolve a esquadra ao regime de linha, um alvo por bloco.
func mandar_fogo(posicao: Vector3) -> void:
	fogo_concentrado = true
	alvo_comandado = posicao


func soltar_fogo() -> void:
	fogo_concentrado = false
	alvo_comandado = Vector3.ZERO


## ---- Ordem de movimento da ponte (fatia 1 do comando por clique) ----
##
## A esquadra sempre obedeceu só ao fogo. Aqui entra o outro ramo do comando: seleção e destino,
## escritos por clique no tabuleiro. Três leis mandam no desenho:
## * **Nada de nó novo.** O bloco é um `Dictionary`, e a seleção é um campo dele — selecionar 120
##   blocos criando 120 `Node3D` seria exatamente o custo que a massa existe para evitar.
## * **Destino é translação, não colapso.** `mandar_destino` move a *formação* inteira: cada bloco
##   recebe o ponto clicado somado ao deslocamento que ele já tinha contra o centro da seleção. Sem
##   isso, dois cliques empilhariam 120 blocos num único posto do chão e a muralha viraria um ponto.
## * **Ordem não sorteia.** Nenhum `randf` aqui, e o `y` entra pela mão do comandante: o destino é um
##   `Vector3` de três eixos, porque a segunda dimensão do lado é altura e um clique só em x/z não
##   manda o andar de cima descer.
func limpar_selecao() -> void:
	for b in blocos_aliados:
		b["selecionado"] = false


## Seleciona um bloco pelo id. O retorno é o bloco escolhido (vazio se o id não existe ou está
## morto), para o chamador ler a posição sem varrer a lista de novo.
func selecionar_bloco(id: int) -> Dictionary:
	for b in blocos_aliados:
		b["selecionado"] = (int(b["id"]) == id and bool(b["vivo"]))
	var alvo := _acha(id)
	# O `is_empty()` primeiro não é cerimônia: um id hostil nunca esteve nesta lista, e ler a chave
	# `selecionado` dum dicionário vazio é erro de runtime, não seleção recusada.
	return alvo if (not alvo.is_empty() and bool(alvo["selecionado"])) else {}


## Seleção de esquadrão: os vinte blocos (`BLOCOS_NO_ESQUADRAO`) do esquadrão do bloco tocado.
## É o clique com modificador, e ela continua sendo uma passada sobre a lista — não um intervalo
## de ids, porque a grade intercala os blocos de um esquadrão com os do vizinho.
func selecionar_esquadrao(id: int) -> int:
	var alvo := _acha(id)
	if alvo.is_empty():
		return 0
	var esq := int(alvo["esquadrao"])
	var marcados := 0
	for b in blocos_aliados:
		var pertence := int(b["esquadrao"]) == esq and bool(b["vivo"])
		b["selecionado"] = pertence
		marcados += 1 if pertence else 0
	return marcados


func _acha(id: int) -> Dictionary:
	for b in blocos_aliados:
		if int(b["id"]) == id:
			return b
	return {}


func selecionados() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in blocos_aliados:
		if bool(b["selecionado"]) and bool(b["vivo"]):
			out.append(b)
	return out


func bloco_por_id(id: int) -> Dictionary:
	return _acha(id)


## Quantos blocos vivos há na seleção — lido antes de escrever qualquer destino.
func contar_selecionados() -> int:
	return selecionados().size()


## Ordem "navegar para": a formação selecionada é transladada como um corpo até `ponto`. Devolve
## quantos blocos receberam o destino, que é o número que a sonda cobra no ledger.
func mandar_destino(ponto: Vector3) -> int:
	var lista := selecionados()
	if lista.is_empty():
		return 0
	var centro := Vector3.ZERO
	for b in lista:
		centro += b["pos"] as Vector3
	centro /= float(lista.size())
	var escritos := 0
	for b in lista:
		var desloc := (b["pos"] as Vector3) - centro
		b["destino"] = ponto + desloc
		b["com_destino"] = true
		escritos += 1
	return escritos


## Ordem "assumir o anel de raio `raio` em torno do marco": cada bloco selecionado recebe um posto
## sobre a circunferência, na *própria* direção atual contra o marco. É a ordem relativa que o
## pedido chama de "a X km do buraco negro", e ela é conferível: fechada a marcha, a distância de
## cada bloco ao marco é o raio pedido, no eixo x/z, para todo bloco da seleção.
func mandar_orbita(marco: Vector3, raio: float) -> int:
	var lista := selecionados()
	if lista.is_empty() or raio <= 0.0:
		return 0
	var escritos := 0
	for b in lista:
		var de_marco := (b["pos"] as Vector3) - marco
		var rumo := Vector3(de_marco.x, 0.0, de_marco.z)
		if rumo.length_squared() <= 0.0001:
			# Bloco exatamente sobre o marco não tem direção própria: o anel dele é o norte do
			# tabuleiro, constante e sorteado de ninguém.
			rumo = Vector3(0.0, 0.0, -1.0)
		b["destino"] = marco + (rumo.normalized() * raio) \
			+ Vector3(0.0, de_marco.y, 0.0)
		b["com_destino"] = true
		escritos += 1
	return escritos


## Retirar a ordem de movimento: os blocos voltam a perseguir o posto do próprio esquadrão. É o
## gesto "seguir a linha", e ele não escreve posição nenhuma — só troca o alvo do `move_toward`.
func soltar_destinos() -> int:
	var soltos := 0
	for b in blocos_aliados:
		if bool(b["com_destino"]):
			b["com_destino"] = false
			soltos += 1
	return soltos


## O estado da ordem, para o relatório e para a sonda: quantos blocos estão sob destino escrito.
func com_destino() -> int:
	var n := 0
	for b in blocos_aliados:
		if bool(b["com_destino"]) and bool(b["vivo"]):
			n += 1
	return n


## A troca de salvas da massa. Fecha o ledger do bloco sem encostar no ledger dos doze cascos: a
## contagem que as sondas dos núcleos assinam não ganha uma linha, e é por isso que a massa é um
## segundo corpo no tabuleiro, não um multiplicador dos doze canhões que já existem.
##
## A partir da fatia 4 a salva também atravessa um CORREDOR, e a geometria decide quem atira:
## * `obstruidos` — um lance que tem a caixa de um Aliado na frente antes de alcançar o alvo visado
##   não sai. É a lei da coluna: numa fileira de quatro blocos amarrados em z a 7,0 u centro a
##   centro, com 4,45 u de casco, só o mais adiantado tem vante limpo, e os três de trás ficam com
##   a boca de fogo tapada pelo aliado. Bloco ralado perde o topo, e com o topo perde a cobertura —
##   a escudeira que afileira de novo quando a frente afunda é a mesma caixa, lida casa a casa.
## * `rebatidos` — o golpe é pago na PRIMEIRA caixa do lado visado que a linha atravessa, não na
##   que o sorteio de proximidade apontou. É o «o que passa bate no aliado atrás» do pedido: um
##   lance que chega por cima ou por baixo do primeiro bloco — os dois andares têm 3,47 u de caixa
##   em 12,0 u de passo — entra pela fresta e acerta a fileira de trás da própria muralha inimiga.
## Nenhum dos dois canais sorteia: é laje contra laje, e duas montadas gemeas fecham os mesmos
## três dígitos de `obstruidos` e `rebatidos`.
func troca_salva() -> Dictionary:
	salva_numero += 1
	var lancados := 0
	var feridos := 0
	var afundados := 0
	var rendidos := 0
	var obstruidos := 0
	var rebatidos := 0
	# Os dois lados atiram sobre o retrato do QUADRO ANTERIOR: se o aliado resolvesse primeiro,
	# o hostil devolveria fogo contra uma massa que já encolheu, e a ordem do laço mudaria o
	# resultado. `destinos` é a fila de pares lida antes de qualquer escrita.
	_caixas["aliado"] = _caixas_de("aliado")
	_caixas["hostil"] = _caixas_de("hostil")
	var pares: Array[Dictionary] = []
	for lado in ["aliado", "hostil"]:
		var outro := "hostil" if lado == "aliado" else "aliado"
		var alvos := lista_de(outro)
		# A ordem da ponte alcança só a nossa muralha; a hostil continua com a lei de linha e por
		# isso o comando do jogador nunca muda o que o inimigo escolhe.
		var comandado: bool = (String(lado) == "aliado") and fogo_concentrado
		var visado := _vizinho_de(alvo_comandado, alvos) if comandado else {}
		var lista := lista_de(lado)
		for i in range(lista.size()):
			var b: Dictionary = lista[i]
			if not bool(b["vivo"]) or float(b["ARMAS"]) <= 0.0 or float(b["navios"]) <= 0.0:
				continue
			var alvo := _alvo_do_bloco(b, alvos, visado, comandado)
			if alvo.is_empty():
				continue
			var j := alvos.find(alvo)
			var origem: Vector3 = b["pos"]
			var trecho: Vector3 = (alvo["pos"] as Vector3) - origem
			# Onde a linha entra na caixa do bloco visado. É o marco contra o qual o aliado da
			# frente é medido: um corpo nosso MAIS ADIANTE que esse ponto tapa o lance; um corpo
			# nosso atrás do alvo não tem nada a ver com ele.
			var t_alvo := _entrada_na_caixa(origem, trecho, (_caixas[outro] as Array)[j])
			if t_alvo == INF:
				t_alvo = 1.0
			var na_frente := _absorvedor(origem, trecho, String(lado), i)
			if na_frente["i"] != -1 and float(na_frente["t"]) < t_alvo:
				obstruidos += 1
				continue
			# Primeira caixa do lado visado no corredor: pode ser o bloco apontado pela
			# proximidade, pode ser o que está na frente dele — e se for outro, é ele que paga.
			var bate := _absorvedor(origem, trecho, outro, -1)
			var k := int(bate["i"])
			if k == -1 or float(bate["t"]) > 1.0:
				obstruidos += 1
				continue
			if k != j:
				rebatidos += 1
			pares.append({"origem": b, "alvo": alvo, "bate": alvos[k], "lado": lado})
	# Espelho para o desenho: a mesma fila, na mesma ordem, com o lado de quem atira. É o único
	# canal que a tela tem para saber de onde para onde saiu cada lance da massa, e ela não pode
	# divergir do ledger nem por um par — `massa_visivel.gd` cobra os dois tamanhos iguais.
	pares_da_ultima_salva = pares
	for par in pares:
		lancados += 1
		var origem: Dictionary = par["origem"]
		var bate: Dictionary = par["bate"]
		var dano := DANO_DE_BLOCO * (float(origem["navios"]) / float(NAVIOS_NO_BLOCO)) \
			* (0.25 + float(origem["ARMAS"]) / 100.0 * 0.75)
		var eixo: String = SETORES_DA_SALVA[
			(int(origem["id"]) + salva_numero) % SETORES_DA_SALVA.size()]
		if _aplicar_golpe(bate, eixo, dano):
			afundados += 1
		else:
			feridos += 1
	# A contagem de rendições é feita DEPOIS de `_prencher_rendicoes`, que é quem consome a marca:
	# limpar `rendicao` aqui deixaria a mudança de lista sem nada para mover.
	_prencher_rendicoes()
	rendidos = _rendidas_na_ultima_salva
	return {"lancados": lancados, "feridos": feridos, "afundados": afundados,
		"rendidos": rendidos, "obstruidos": obstruidos, "rebatidos": rebatidos,
		"salva": salva_numero}


## As caixas de um lado, na ordem da lista e uma vez por salva. Bloco morto entra com caixa vazia
## de propósito: a lista é o índice, e um buraco no meio dela desalinharia o `i` de quem atira com
## a própria caixa.
func _caixas_de(lado: String) -> Array:
	var out: Array = []
	for b in lista_de(lado):
		out.append(caixa_do_bloco(b))
	return out


## A fila do desenho: um LANCE POR CASA viva de cada bloco que atirou. É a leitura visual da
## lotação — o bloco de cem navios tem vinte e quatro cascos desenhados, e vinte e quatro bocas de
## fogo: cada tiro sai do casco em que o olho vê a nave e aponta para UM casco do bloco visado, não
## para o centro dele. Não é uma segunda conta de dano: o ledger continua um golpe por bloco, em
## `troca_salva` acima, e esta fila é derivada dele na mesma ordem, casa a casa — então a sonda pode
## cobrar "um traço por casa viva de quem cobrou" sem que a tela jamais mostre fogo que a conta não
## cobrou, nem esconda fogo que cobrou. Aritmética pura de índice `(casa + id + salva) % casas_alvo`:
## sorteio aqui comeria um dado do `visual_rng` dos doze cascos e mudava toda a batalha.
func tiros_da_salva() -> Array[Dictionary]:
	var tiros: Array[Dictionary] = []
	for par in pares_da_ultima_salva:
		var origem: Dictionary = par["origem"]
		# O desenho segue o ledger, não a intenção: quem recebe o traço é o bloco que a caixa dele
		# interceptou no corredor, que pode ser o da frente do visado ou a fileira atrás dele.
		var alvo: Dictionary = par["bate"]
		var casas := casas_vivas(origem)
		# Bloco que afundou nesta mesma salva tem casa zero; o lance dele existe e tem de ir a algum
		# lugar, senão a fila deixaria de espelhar o ledger.
		var casas_alvo := maxi(1, casas_vivas(alvo))
		var rot := Basis.from_euler(Vector3(0.0, float(origem["rumo"]), 0.0))
		var rot_alvo := Basis.from_euler(Vector3(0.0, float(alvo["rumo"]), 0.0))
		var base: Vector3 = origem["pos"]
		var base_alvo: Vector3 = alvo["pos"]
		var id := int(origem["id"])
		for c in range(casas):
			tiros.append({"de": base + (rot * casa_local(c)),
				"para": base_alvo + (rot_alvo * casa_local((c + id + salva_numero) % casas_alvo)),
				"aliado": String(par["lado"]) == "aliado", "casa": c,
				"bloco": id, "alvo_bloco": int(alvo["id"])})
	return tiros


## Um golpe no eixo escolhido. Devolve `true` se o bloco afundou.
func _aplicar_golpe(alvo: Dictionary, eixo: String, dano: float) -> bool:
	# Cadáver não leva tiro: sem esta guarda o segundo impacto num bloco que acabou de afundar
	# tornava a entrar aqui, `navios` já estava em 0 e a perda era contada duas vezes — e um bloco
	# morto podia marcar rendição e cruzar o tabuleiro para o lado errado.
	if not bool(alvo["vivo"]):
		return false
	var lado := String(alvo["lado"])
	if eixo == "CASCO":
		# A placa morde o dano cru, o mesmo unidade que `main.gd` usa no canhão de linha: uma salva de
		# bloco em força cheia são 2,2 de dano, a placa é 4,4, então exatamente duas salvas passam por
		# cima de `navios` sem encostar num navio. O transbordo é que entra no fator 1,4 de navio.
		var transbordo := Escudo.morder(alvo, dano)
		alvo["navios"] = maxf(0.0, float(alvo["navios"]) - transbordo * 1.4)
		if float(alvo["navios"]) <= 0.0:
			alvo["vivo"] = false
			if lado == "aliado":
				perdas_aliadas += 1
			else:
				perdas_hostis += 1
			return true
	elif eixo == "TRIPULACAO":
		alvo[eixo] = maxf(0.0, float(alvo[eixo]) - dano * 1.1)
		if float(alvo[eixo]) <= 0.0 and not bool(alvo["presa"]):
			# A rendição não troca de lista no meio do laço — os índices que a pintura usa
			# mudariam sob os pés dela. Marca e fecha no fim, em `_prencher_rendicoes`.
			alvo["rendicao"] = true
	else:
		alvo[eixo] = maxf(0.0, float(alvo[eixo]) - dano * 1.3)
	return false


## Move os blocos rendidos de lado, uma única vez. Presa nova recebe o piso de tripulação e o
## carimbo `presa`, que é o que impede o vaivém de um mesmo bloco entre as duas linhas.
##
## O teto de instâncias é a razão pela qual esta função existe em duas partes. Cada lado tem
## `BLOCOS_NO_LADO` de casas no `MultiMesh`; sem despejar os afundados e sem conferir o teto, a
## primeira presa faria a lista receptora passar de cento e vinte e a pintura escreveria depois do
## fim da instância — o `MultiMesh` nem existe além daquele índice.
func _prencher_rendicoes() -> void:
	_rendidas_na_ultima_salva = 0
	var mudou := _expulsar_mortos() > 0
	for lado in ["aliado", "hostil"]:
		var velha := lista_de(lado)
		var nova := lista_de("hostil" if lado == "aliado" else "aliado")
		var viram: Array[Dictionary] = []
		for b in velha:
			if bool(b.get("rendicao", false)):
				viram.append(b)
		if viram.is_empty():
			continue
		for b in viram:
			velha.erase(b)
		mudou = true
		for b in viram:
			# Não há banco: a presa que não cabe no `MultiMesh` do receptor morre no campo em vez
			# de estourar a conta. É perda do lado que a perdeu, contada como afundamento.
			if nova.size() >= BLOCOS_NO_LADO:
				b["rendicao"] = false
				b["vivo"] = false
				if lado == "aliado":
					perdas_aliadas += 1
				else:
					perdas_hostis += 1
				continue
			b["lado"] = "hostil" if lado == "aliado" else "aliado"
			b["presa"] = true
			b["rendicao"] = false
			b["TRIPULACAO"] = TRIPULACAO_DE_PRESA
			b["pintas"]["casas"] = -1
			nova.append(b)
			presas += 1
			_rendidas_na_ultima_salva += 1
	# A base de instância é índice × CASAS. Qualquer apagamento corre a lista para cima, e o "limpo"
	# que cada bloco carrega passou a ser mentira — a linha sairia trocada de lugar na tela. É só
	# marcação suja; quem repinta é o próximo `pintar`.
	if mudou:
		for b in blocos_aliados:
			b["pintas"]["casas"] = -1
		for b in blocos_hostis:
			b["pintas"]["casas"] = -1
	_recrutar_postos()


## Recoloca os blocos sem posto. Toda rendição mexe com a lista, e a lista é a base do índice de
## instância enquanto `esquadrao`/`formacao` são a base da grade: sem esta passada, o bloco capturado
## chegaria com o posto do gêmeo que já mora no receptor e os dois passariam o resto da partida
## disputando o mesmo ponto do chão. Quem tem posto exclusivo não se mexe — só os sem-teto escolhem
## buraco, e escolhem o mais perto, em ordem de lista. Determinístico, sem sorteio e sem recomeçar a
## formação inteira a cada salva.
func _recrutar_postos() -> void:
	for lado in ["aliado", "hostil"]:
		var lista := lista_de(lado)
		var donos := {}
		var sem_teto: Array[Dictionary] = []
		for b in lista:
			var posto := int(b["esquadrao"]) * BLOCOS_NO_ESQUADRAO + int(b["formacao"])
			if donos.has(posto):
				sem_teto.append(b)
			else:
				donos[posto] = true
		if sem_teto.is_empty():
			continue
		var livres: Array[int] = []
		for p in range(BLOCOS_NO_LADO):
			if not donos.has(p):
				livres.append(p)
		var ancora := estacao(lado)
		for b in sem_teto:
			if livres.is_empty():
				break
			var escolhido := 0
			var menor_d := INF
			for k in livres.size():
				var p: int = livres[k]
				var d: float = (b["pos"] as Vector3).distance_squared_to(posto_no_lado(
					int(float(p) / float(BLOCOS_NO_ESQUADRAO)),
					p % BLOCOS_NO_ESQUADRAO, ancora))
				if d < menor_d:
					menor_d = d
					escolhido = k
			var posto: int = livres[escolhido]
			livres.remove_at(escolhido)
			b["esquadrao"] = int(float(posto) / float(BLOCOS_NO_ESQUADRAO))
			b["formacao"] = posto % BLOCOS_NO_ESQUADRAO


## Tira das duas listas todo bloco que afundou. A lista é a base de índice do `MultiMesh`: um
## cadáver que fica pendurado lá ocupa uma casa de instância e rouba do próximo sobrevivente o
## posto que a pintura dele vai escrever. O sumiço é a lei — um bloco morto continua morto, só
## para de sentar banco.
func _expulsar_mortos() -> int:
	var removidos := 0
	for lado in ["aliado", "hostil"]:
		var lista := lista_de(lado)
		var mortos: Array[Dictionary] = []
		for b in lista:
			if not bool(b["vivo"]):
				mortos.append(b)
		for b in mortos:
			lista.erase(b)
			removidos += 1
	return removidos


## Repinta o `MultiMesh` de um lado. Devolve quantos blocos foram de fato escritos, número que a
## sonda confere: parado e inteiro, o bloco não custa uma escrita.
func pintar(mm: MultiMesh, lado: String, forcar := false) -> int:
	var lista := lista_de(lado)
	var tocados := 0
	for i in range(lista.size()):
		var b: Dictionary = lista[i]
		var base := i * CASAS
		var casas := casas_vivas(b) if bool(b["vivo"]) else 0
		var pintado: Dictionary = b["pintas"]
		var sujo := forcar or casas != int(pintado["casas"]) \
			or (b["pos"] as Vector3).distance_squared_to(pintado["pos"]) > 0.0001 \
			or absf(float(b["rumo"]) - float(pintado["rumo"])) > 0.001
		if not sujo:
			continue
		tocados += 1
		pintado["casas"] = casas
		pintado["pos"] = b["pos"]
		pintado["rumo"] = float(b["rumo"])
		var origem: Vector3 = b["pos"]
		var rot := Basis.from_euler(Vector3(0.0, float(b["rumo"]), 0.0))
		var escala := Vector3.ONE * ESCALA_REPLICA
		var girada := rot.scaled(escala)
		for c in range(CASAS):
			if c < casas:
				mm.set_instance_transform(base + c,
					Transform3D(girada, origem + (rot * casa_local(c))))
			else:
				# Base nula é o "escondido" do MultiMesh: triângulo degenerado, nada rasteriza,
				# e o orçamento de instâncias não muda — a casa some sem o motor realocar nada.
				mm.set_instance_transform(base + c, Transform3D(Basis(), origem))
	# A lista encolheu (rendição, ou reset com menos blocos): a cauda que o lado pintou na última
	# vez não pertence a bloco nenhum agora, e ficar calado aqui deixa um bloco fantasma de 24
	# casas pendurado no campo. Apaga-se pela contagem antiga, não pela lista.
	var limite := lista.size() * CASAS
	var pintadas := int(_casas_pintadas[lado])
	if pintadas > limite:
		for k in range(limite, pintadas):
			mm.set_instance_transform(k, Transform3D(Basis(), Vector3.ZERO))
	_casas_pintadas[lado] = limite
	return tocados


## Cor por instância: cinza do atrito e da tripulação morta. É o único canal que pinta dano num
## `MultiMesh` sem material por casa, e só precisa ser reescrito quando a lotação muda.
func pintar_cores(mm: MultiMesh, lado: String, cor_viva: Color) -> void:
	var lista := lista_de(lado)
	for i in range(lista.size()):
		var b: Dictionary = lista[i]
		var base := i * CASAS
		var frac := clampf(float(b["navios"]) / float(NAVIOS_NO_BLOCO), 0.0, 1.0)
		var trip := clampf(float(b["TRIPULACAO"]) / 100.0, 0.0, 1.0)
		var cor := cor_viva.lerp(Color(0.16, 0.17, 0.2), (1.0 - frac) * 0.7)
		cor = cor.lerp(Color(0.28, 0.22, 0.15), (1.0 - trip) * 0.5)
		for c in range(CASAS):
			mm.set_instance_color(base + c, cor)


func vivos(lado: String) -> int:
	var n := 0
	for b in lista_de(lado):
		if bool(b["vivo"]):
			n += 1
	return n


## Cascos que a massa ainda representa — a conta que o jogador pediu como "milhares de naves".
func navios(lado: String) -> int:
	var n := 0
	for b in lista_de(lado):
		if bool(b["vivo"]):
			n += int(roundf(float(b["navios"])))
	return n


## Caixa de desenho dos dois lados, no tabuleiro de hoje. A sonda mede e o README cita; é ela que
## prova que a massa cabe no campo sem invadir a borda.
func extensao() -> Dictionary:
	var minimo := Vector3(1e9, 1e9, 1e9)
	var maximo := Vector3(-1e9, -1e9, -1e9)
	for lado in ["aliado", "hostil"]:
		for b in lista_de(lado):
			if not bool(b["vivo"]):
				continue
			minimo = minimo.min(b["pos"])
			maximo = maximo.max(b["pos"])
	if minimo.x > maximo.x:
		return {"vazio": true}
	return {"vazio": false, "min": minimo, "max": maximo,
		"largura": maximo.x - minimo.x, "fundo": maximo.z - minimo.z}


## Linha do letreiro de cima e veredito da sonda, no mesmo formato: a massa é lida em blocos e em
## cascos, porque "120 blocos" sem o total de navios não é a conta que o jogador pediu.
func resumo() -> String:
	return "MASSA %d/%d • %dc // hostil %d/%d • %dc // %d rend." % [
		vivos("aliado"), BLOCOS_NO_LADO, navios("aliado"),
		vivos("hostil"), BLOCOS_NO_LADO, navios("hostil"), presas]
