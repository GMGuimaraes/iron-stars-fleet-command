# Comando por clique, escala espacial e esquadra com hierarquia — desenho

Data: 2026-10-23 · Estado: aprovado — implementação começou pela fatia 1 em 2026-10-24 ·
Caminho: architectural (novo subsistema de entrada + seis subsistemas de combate encadeados)

## 0. O que este documento é

Um **programa**, não uma tarefa. Oito fatias, cada uma com o próprio ciclo
design→sonda→README→push, porque elas se destravam em ordem e cada uma move números que o
README jura. Este arquivo é o mapa; a fatia 1 tem desenho completo aqui, as demais têm
decisão registrada + interface + o que elas custam às asserções existentes.

Nenhuma linha de `main.gd`, `esquadra.gd` ou das sondas é tocada por este documento.

## 1. Decisão 0 — a régua, e por que não é parsec

A geometria atual amarra as unidades: o alcance de tiro é **~5,5 × o comprimento de um casco**
(`CAPITAL_ALCANCE := 60.0` em `main.gd:77` contra casco de linha de 8,5 u cru na gramática
`lamina` — proa em z −5,32, popa em z +3,2 — e 10,1 u cru na `agulha`, ambos vezes o
`scale_factor` de 1,1 a 1,22 do cadastro, `main.gd:1599`). Proporção é naval, não astronômica, e
ela é o que decide a escala: qualquer fator escolhido torna ou o casco planetário, ou o alcance
intraduzível em luz.

**Adoptado: `U_PARA_KM := 1.0`** — 1 unidade de tabuleiro = 1 km, e as derivadas
`U_PARA_LUZ_MS := 1.0 / 299_792.458 * 1_000.0` ≈ 0,003 3356 ms-luz,
`UA_EM_U := 149_597_870.7` e `PARSEC_EM_U := 3.0857e13`, **declaradas e não usadas na tática**
(reservadas à camada estratégica, que ainda não existe). Consequências, todas conferíveis:

| grandeza medida hoje | valor em `u` | leitura com 1 u = 1 km |
|---|---|---|
| alcance da capitânia | 60,0 | 60 km = **0,20 ms-luz** |
| casco de linha | 9,4 a 12,4 | ~9 a 12 km (super-capital) |
| boca da réplica do bloco | 0,9118 | **912 m** |
| casa da grade | 1,6 | 1 600 m, folga de **688 m** entre cascos |
| piso do bloco | 6,4 × 3,2 | 6,4 km × 3,2 km com 100 cascos de ~1 km |
| campo da massa | x ±56, z −103..−23 | 112 km × 80 km |
| planeta do sistema | raio 15 em `(0, 22, −64)` | 15 000 km ≈ 2,4 raios terrestres |
| horizonte do poço | 9,0 | 9 000 km ≈ **3 000 massas solares** |

Com 1 u = 1 km o campo inteiro cabe em 4,3×10⁻⁶ UA: **segundo-luz e UA não são unidades
táticas, são unidades de viagem**. Para o comandante dizer "0,2 segundos-luz de alcance" a
proporção teria de ser ~1 000 cascos, o que significa esticar o campo de 60 u para ~30 000 u e
deixar o casco de ser desenhado em escala — é a camada estratégica, decisão adiada e registrada
em §8, não detalhe de rótulo.

**Regra de contrato:** `u` continua sendo a unidade citada no README e nas asserções — a escala
é uma **cláusula nova**, não uma reescrita dos dígitos publicados. O HUD e os textos de ordem
falam km e ms-luz; o código mede em `u`. A asserção que autoriza os dois é a identidade
`distancia_km == distancia_u * U_PARA_KM` sobre um par conhecido (60 u → 60 km → 0,20014 ms-luz),
mais a boca 912 m e a costura 688 m, que já são medidas pela sonda em `u`.

**Destinos relativos a marco**, que é o que o pedido chama de "ficar a 50 parsecs de um buraco
negro", viram: clique num marco (poço, estrela, planeta, cinturão) + raio em km → ordem
`"A 40 km do horizonte"`. O raio é relativo à posição do marco, não absoluta, e o marco é lido
do cadastro que já existe (`POCO_POS`, `ESTRELA_POS`, `SISTEMA_POS`, `main.gd:207/247/266`).

## 2. Fatia 1 — câmera tática, seleção por clique, destino por clique

### 2.1 Estado de câmera

`campo_modo: String` = `"PONTE"` (hoje) ou `"TATICO"`, alternado por tecla **TAB** e por botão.
TAB está livre: zero ocorrências de `KEY_TAB` em `main.gd` e zero em `project.godot`, e o handler
de entrada hoje só trata SPACE, ESC e roda (`main.gd:776-788`).

- `PONTE`: nada muda. `ponte_camera` filha do rig, FOV 78° → 14° pela roda
  (`PONTE_FOV`/`CAMPO_FOV`, `main.gd:423-424`), a capitânia no centro.
- `TATICO`: um `Camera3D` novo, **filho do jogo**, não do rig, apontado para `tatico_foco`
  a `tatico_altura`, com arrasto movendo o foco e a roda movendo `tatico_altura`. A roda só
  toca `campo_zoom` no modo `PONTE` — escopo de modo, não exceção.

Custo declarado: um nó filho a mais na árvore. Os gabaritos medidos `FILHOS_DO_JOGO` (24 em
`tools/probes/superficies.gd` e `tools/probes/graficos.gd`, 25 em `tools/probes/geoide.gd`) sobem
**para a medida nova, re-medida na rodada**, não para um número esperado. É exatamente a
cláusula que a fatia da massa teve de reconciliar antes.

Nada aqui é moldura sobre a cena: o mapa tático é a cena vista de outro olho, conforme a
restrição já dada (nada de janela emoldurada duplicando a arte).

### 2.2 Picking

`_unidade_sob_o_pixel(pixel)` projeta cada candidata com `unproject_position` e escolhe a mais
próxima dentro de `RAIO_ESCOLHA_PX`, com desempate por distância à câmera. Duas razões para
projeção em vez de raio-contra-plano: (a) a batalha tem `y` de verdade a partir desta fatia, e
um plano fixo é a limitação que o README já declara em `_pontos_de_impacto` (`main.gd:3765-3781`);
(b) os blocos não têm `Node3D` — só `pos` lógico (`esquadra.gd`, o dicionário devolvido por `_novo_bloco`) — e projetar `pos` não
exige criar 240 nós, o que seria o custo que a massa existe para evitar.

Candidatas: os 6 cascos aliadas de `fleet` (`main.gd:1596-1601`) mais a presa capturada que entra
nele em `main.gd:4671`, os 6 cascos hostis de `enemies` (`main.gd:1602-1609`), os 120 blocos de
cada lado, a capitânia, e os marcos de cenário. Mortos não são candidatos. `unproject_position`
exige matriz de câmera viva — é lei de janela, headless não prova (armadilha conhecida).

### 2.3 Seleção e ordem

- **Clique em aliado** seleciona o bloco (ou o casco nomeado). Clique no núcleo do esquadrão
  com modificador seleciona os 20 blocos do esquadrão (`BLOCOS_NO_ESQUADRAO`, constante de `esquadra.gd`).
- **Clique em hostil** fixa `selected_target` — hoje só o dropdown faz isso (`main.gd:2091-2093`).
- **Clique em água vazia** escreve destino. `_give_order` (`main.gd:4805-4852`) passa a tocar a
  esquadra: cada bloco recebe `destination: Vector3` e marcha até ele com o
  `move_toward` que já existe (`esquadra.gd`, a linha que escreve `b["pos"]`), em vez de só seguir `centro_aliado`.
- Os **SpinBox X/Z** (`main.gd:2107-2125`, X −80..80 passo 5, Z −160..20 passo 5) ficam como
  espelho numérico do destino, atualizados pelo clique. Arrancá-los quebraria as 55 conferências
  de `tools/probes/menu.gd` sem ganho nenhum; o que muda é que deixam de ser o único caminho.
- `selection_scope` (string de dropdown, `main.gd:684`) passa a ser derivado da seleção do
  clique, e não o contrário. Os 35 botões do painel não se mexem.
- O `y` entra pelo clique e pela ordem: a grade pinta `pos + offset_da_casa`, então o bloco
  sobe e desce sem tocar na partição de casas. Ordens dos cascos nomeados hoje só escrevem
  x/z (`main.gd:4829`); `destination` ganha componente y e o `move_toward` cuida do resto.

### 2.4 Teste da fatia 1

Sonda nova `tools/probes/comando.gd`, com família de dados (headless) e família de olho (janela):

1. Escala declarada: 60 u = 60 km = 0,20014 ms-luz; boca 912 m; costura 688 m; planeta 15 000 km.
2. Clique num bloco seleciona **aquele** id, não o vizinho a 8 u de passo (`PASSO_BLOCO_X`).
3. Destino por clique escreve `destination` com y e o bloco anda até lá; parado, não custa escrita.
4. Clique em morto não seleciona; clique em hostil não move aliado.
5. Marco relativo: ordem "a X km do poço" resolve para o ponto a X do `POCO_POS` medido.
6. **Inércia**: nenhum dos caminhos acima consome `rng`/`visual_rng`, e o ledger da massa
   (`resumo()`) não ganha linha — a lei que a fatia da massa já jura.
7. Modo tático não muda a FOV contratada da ponte; roda em `PONTE` continua 78°→14°.
8. Gabarito de filhos re-medido; os 35 botões de painel conferidos intactos.

Contrato a reescrever no mesmo commit: a asserção «so a roda manda no zoom» em `tools/probes/esquadra.gd` diz
«clique esquerdo nao moveu» o zoom — ela continua verdadeira e continua cobrada, só passa a
dizer «clique esquerdo nao moveu o zoom da ponte», porque o clique agora move *outra coisa*.

## 3. Fatia 2 — física de voo por classe

Hoje só a capitânia tem anisotropia (`CAPITAL_SPEED 22.0` avante contra `CAPITAL_REVERSE -0.6`,
`main.gd:31-32`, `CAPITAL_LIFT 12.0` em `:34`) e os blocos andam a velocidade instantânea, sem
taxa de giro (`MARCHA_DE_BLOCO 6.0 × mobilidade`, `esquadra.gd`: a constante e o `var marcha` que a usa). Cascos pesados hoje só
têm fator de classe na velocidade (`CLASSES`, `main.gd:102-106`), não em aceleração nem em giro,
e `hp`/`engines`/`weapons`/`crew` nascem todos em 100 (`main.gd:1601/1609`).

Desenho: estado de voo por unidade = `vel` + `rumo` + `giro`, com `aceleracao` e
`giro_maximo` por classe (pesada: ambos menores), e `velocidade_lateral < velocidade_avante`
com ré ainda menor. `CLASSES` ganha os três campos e para de ser só fator multiplicativo.
Custo: `movimento_tomado` vira integração em vez de `move_toward`, e isso move as asserções de
"formação custa tempo de locomoção" e o tempo de cada salva. Teste: A/B de tempo até o destino
por classe, giro limitado (nada de rotar 180° em um quadro), e a ré medindo menos que a proa.

**Fechada em 2026-10-24.** A lei mora em `res://voo.gd` (142 linhas, sete funções puras) e o
estado é `vel`/`rumo`/`giro` por unidade. Os três testes pedidos existem e são medidos: o tempo
até o destino por classe (cruzador **120 quadros** contra encouraçado **300** na mesma marcha
contratada, e meia-volta **235 quadros = 3,92 s** contra **8,93 s** de encouraçado), o giro limitado (nenhum quadro gira mais que
`giro_maximo × delta` — **0,013333 rad** contra **0,013333** do teto) e a ré menor que a proa
(**72,07 / 34,41 / 19,52 u** nos três eixos em seiscentos quadros, estado estacionário
**8,0000 / 3,6000 / 2,0000 u/s**). O custo profetizado venceu como profetizado: a formação de
48,62 u passou de 61 para **79 quadros** e a travessia da massa de **19,0 s** para **20,2 s**
(1 210 quadros) — números que as sondas de `formacao.gd` (46 conferências) e `esquadra.gd`
agora contam em vez de assumir. A inércia continua jurada: **1 210 quadros** deixam `rng` e
`visual_rng` byte a byte intactos e **0** dos 12 cascos tiveram `hp` escrito pela lei.

## 4. Fatia 3 — escudo com durabilidade

Não existe nenhuma camada além de `hp` no jogo (zero ocorrência de `shield`/`escudo`/`armadura`
como estado; a palavra só aparece em prosa de README). Desenho: `escudo` + `escudo_max` por
casco, agregado por bloco; o dano morde o escudo primeiro, o escudo **não conserta** no mesmo
ritmo do casco e tem colapso com janela de vulnerabilidade; a regeneração é constante declarada,
não sorteio (lei da casa). Sem escudo o bloco não muda de líder nem de doutrina. Custo: toda a
aritmética de `_dano_de_canhao` (`main.gd`, função homônima), `DANO_DE_BLOCO 2.2` (`esquadra.gd`, constante homônima) e as
rampas de setor; e as luminâncias dos quadros de casco podem mudar de novo.

**Fechada em 2026-10-24.** A lei mora numa folha própria, `res://escudo.gd` (5 597 caracteres,
quatro constantes declaradas — `ESCUDO_DE_CASCO 20,0`, `ESCUDO_REGENERA 1,2` u/s, `ESCUDO_JANELA
4,0` s, `ESCUDO_DE_BLOCO 4,4` — e zero gerador de sorteio). Quatro cláusulas ficaram **mais
estreitas do que o parágrafo acima previu**, e é isso que o portão cobra agora:

1. **A casca só intercepta projétil.** Dos caminhos de dano do jogo, apenas os cinco de fogo de
   canhão passam pelo nó único `_ferir_casco`. Abalroamento (**12** de impacto → casco **88**,
   casca **20** intacta), coroa do poço (**88 → 85**, casca intocada), o poço em si (casco **0**
   com a casca como estava) e o golpe de subsistema (**MOTORES 92,35** com casco e casca em paz)
   continuam pela porta velha — é a cláusula 4 do spec, agora com família de sonda própria.
2. **A placa do bloco não se recompõe nunca.** Ela entra como `escudo_max = 0,0`, que é a própria
   grafia da lei para «não recomponha»: **4,4 = exatamente duas salvas** de `DANO_DE_BLOCO 2,2`, e
   a terceira afoga **3,08 navios** (o fator velho da casa, `2,2 × 1,4`).
3. **A ponte não tem escudo**, e não é descuido: `capital_hp` é um **escalár**, não um dicionário,
   então não há onde pendurar a chapa. Registrado como aresta aberta, não como dívida escondida.
4. **Nenhuma arte de escudo** nesta fatia — só o texto do seletor (`CASCO 92% // ESCUDO 0%`) e a
   linha do relatório no colapso.

O que se mediu, em vez de se assumir: com a casca de pé o canhão real não arranha **um ponto** de
casco em **5 salvas** até o colapso, a mordida fecha em **20,0000** contra o teto de 20 e a salva
que derruba a casca escreve **1,344** de transbordo no mesmo golpe; em **12 salvas** contra o
tabuleiro inteiro, **0 violações em 144 amostras** de casco vivo. A janela queima em relógio de
quadro (16 quadros de 0,25 s e nenhum resíduo), a regeneração é constante nos dois lados (**1,200 u**
em 1 s de relógio da ponte hostil, sem oficina) e os dois relógios não se emprestam número: oito
segundos de conserto dão **+17,6** de casco e **+4,8** de casca. A inércia continuou jurada —
**rng** e **visual_rng** intocados pelas quatro chamadas da lei e duas montadas gêmeas fechando no
mesmo ledger de **262 bytes**, dígito a dígito.

O custo real, escrito: **doze sondas** passaram a declarar na montagem um tabuleiro **sem casca**
(uma linha por chave, nenhum número afrouxado), porque com a muralha de pé todo lance abaixo de
20,0 mordia nela em vez de chegar a `hp`. A sonda da lei, `tools/probes/escudo.gd`, fecha com
**55 conferências** e `quebras=0`.

## 4.5 Fatia 3.5 — o lance por casco desenhado e a muralha que respira

Fatiado à parte, antes da 4, porque o pedido veio do olho e não do roteiro: «cada nave do bloco tem
que atirar também, se o bloco tem 10 naves deve sair cada tiro de sua respectiva nave, em forma de
onda, a primeira atira depois a seguinte, tudo isso de forma rápida equivalendo a uma leva», e
ainda «fazer as naves se moverem durante a batalha». As duas frases viram duas leis, e a segunda
arrastou uma terceira que ninguém pediu.

**Lei 1 — um cano por casa desenhada, em onda.** O `MultiMesh` dos traços passou de 240 para
`TRACOS_DA_MASSA` = **5 760** instâncias (`INSTANCIAS_POR_LADO × 2`), e o atraso de cada lance é
`casa × PASSO_DA_ONDA` com `PASSO_DA_ONDA` = **0,012 s**: a onda fecha em **0,276 s** e somada aos
**0,55 s** de voo dá `TRACO_PULSO_SEG` = **0,826 s** de pulso dentro dos 1,6 s da cadência — leva,
não chuva, e o portão é o pulso morrer antes do próximo armar. *(Lapidação 3: a muralha hostil
passou a largar `FASE_HOSTIL_DA_SALVA` = **0,5 s** depois da nossa, porque os dois lados não precisam
atirar no mesmo instante; o pulso passou a **1,326 s** e o portão continua o mesmo. E a frase «a conta
não mudou» do parágrafo abaixo vale só para a rodada em que ela foi escrita: desde a lapidação 2 o
ledger cobra **tiro a tiro por casa**, não mais `DANO_DE_BLOCO` 2,2 por bloco, como registra
`2026-10-25-dano-por-casco-e-morte-visivel-design.md`.)* **A conta não mudou**: o ledger
continua cobrando um lance por bloco (`DANO_DE_BLOCO` 2,2, 240 blocos, mesma inércia de `rng` e
`visual_rng`); o que mudou é o desenho, que passou a ter um cano por casa. Prova lida: **5 760
traços armados para 5 760 casas vivas, contra os 240 blocos que cobraram na salva**, e o espelho
pintado contra o espelho da conta fecham no **mesmo selo de 385 528 caracteres** — com o jitter de
boca ainda função pura de `(id, salva, casa)`, porque sorteio aqui comeria o `visual_rng` dos doze
cascos. Concentrar pelo clique converge o desenho junto: **4 072 traços aliados sobre 1 bloco
visado** (16 destinos diferentes, porque nem todo bloco alcança o alvo único) contra **5 752 sobre
30 blocos** com a ordem solta. O preço continua sendo **um** nó: **293 760 escritas** em cinquenta
quadros mais a armação, que é `51 × 5 760` exato, contra os 5 760 nós que um nó por lance cobraria.

**Lei 2 — a muralha respira.** `DERIVA_X` **0,6 u** em boreste com a fase do **andar**, `DERIVA_Y`
**0,45 u** em altura com a fase do **esquadrão**, **zero em z**, ciclo `DERIVA_CICLO` = **9,0 s**.
Lido no meio de seis esquadrões defasados de 60°: pico **0,60 u de 0,6** em boreste, **0,46 u de
0,5** em altura, **0,000000 u** de componente em z nos seis vetores. Duas cláusulas pagas: quem
recebe destino da ponte **não respira** (para a **0,000 u** do ponto, dentro da boca de pouso de
0,02 u mais a folga de 0,35 u), e a respira **não fecha o ar entre cascos** (par mais junto
**2,48 u** sobre o piso de 2,40, **0 sobreposições** no ciclo). O custo é de escrita, e por isso tem
teto: **23 160 escritas hostis** em duzentos quadros contra **1 697,8 u andados ÷ 0,01 + 120**.

**Lei 3 — a proa fica com a linha, não com o resíduo.** Esta não foi pedida; foi a quebra que a lei
2 trouxe. O bloco perseguia o posto pela lei de voo, o posto desliza **de lado**, e o resíduo de
perseguição aponta para través: girar para ele deitava a muralha. No pixel, a boca do bloco caiu de
**630 px para 236 px** no mesmo grau de lente — a lei da roda reprovaria por um cláusula de rumo que
ninguém escreveu. A saída foi separar as duas doutrinas que `main.gd` já separa nos doze cascos
(`_pilotar` obedece destino absoluto, `_empuxar` guarda atitude comandada): `Voo.marchar` ganhou
`proa_comandada` (padrão `NAN`, todo chamador antigo intacto) e `Esquadra.rumo_da_linha(lado)` virou
a atitude de custódia. A família 13b cobra os dois lados e imprime o contrafactual no mesmo quadro:
maior desvio de proa **0,00 graus** aliado e **0,00 hostil** contra teto de **0,48 graus** (um
degrau do leme em um quadro), e **o curso que o resíduo mandaria guardar é 90,0 graus**.

**O que a fatia ensinou sobre instrumento, não sobre jogo.** Três das quatro quebras desta rodada
eram de sonda, e as três foram consertadas declarando precondition, nunca afrouxando régua:

1. **Congelar congela o desenho.** A seção de vão da `massa_visivel` congelou a batalha com 5 760
   canos no meio do voo, estacionados exatamente sobre a fresta: o vão leu **1,000** de luminância e
   a lei da emenda lida ia reprovar o desenho da salva em vez de reprovar a muralha. A seção agora
   apaga o nó dos traços durante a medição de silhueta, e a seção da salva rearma o nó.
2. **A rampa é cláusula da lei de pintura.** Com o `rumo` parado de girar, o «pleno todo quadro» que
   a família 8 cobrava deixou de existir: os primeiros **120 quadros** andam menos dos **0,01 u** da
   porta de sujeira, e isso é a física funcionando. A asserção passou a contar a rampa
   (`MARCHA_DE_BLOCO / aceleracao × 60`), imprime os parcos que caem dentro dela com o deslocamento
   de cada um e continua cobrando **0 parcos depois**: primeiro quadro pleno **4**, **4 parcos
   dentro da rampa, 0 depois**, **46 320 escritas** no total.
3. **O sujeito da régua tem de estar desenhado.** Escolhido só pelo maior z, o bloco medido pela
   sonda de janela caiu num dos **18 de 120** que a seção de batalha já tinha mordido — e casa sem
   navio é pintada com base nula sobre o centro do bloco, ou seja vazio. A mediana leu **0,036** de
   céu em vinte e uma de vinte e quatro amostras. O instrumento agora escolhe o bloco mais **lotado**
   e amarra a amostragem às casas que têm silhueta: **48 pares de 24 casas no ar, 102 blocos
   lotados na muralha**, e a régua voltou a ler **casa 0,795 contra vão 0,036 em 47 de 48 pares** —
   os mesmos dígitos que o README jurava antes da fatia, o que é a prova de que a lei não mudou.

Uma quarta foi pega fora das asserções, relendo o PNG: o `05g_chapa_de_fora` do `fotograma` estaciona
o casco em z −190 para escapar da parede da ponte, e esse z hoje é **dentro** do campo da massa. O
quadro acordou com um bloco hostil atravessado na moldura e a média subiu de **0,0133 para 0,2297** —
verde pago pelo brilho de outra pessoa. O posto de fotografia saiu do campo pelo y.

**Fechamento.** Bateria completa em **30 sondas com `quebras=0` e zero linha de erro**, e as três
sondas de olho em janela real também: `massa_visivel` **16 conferências** (49,8 fps com a massa
contra 50,7 sem, mediana de 3 pares A/B **+0,04 ms** contra teto de 8,0; **738 318 primitivas**
contra 116 236; **1,9 chamadas** para os 240 blocos; boca **105 px a 78° / 694 px a 14°**; salva
acendendo **351 de 720 colunas** e varrendo **x 114 a 1336 de 1440 px**), `fotograma` **95** e
`comando_olho` **13**. A sonda da lei, `tools/probes/esquadra.gd`, passou de 72 para **89
conferências**. Aprovação de timing e de leitura do quadro continua sendo do comandante, não da
sonda.

## 5. Fatia 4 — fogo por coluna, fogo amigo, alcance 3D

Escolhido: só o bloco mais adiantado de cada coluna dispara, os demais ficam obstruídos, e o que
passa bate no aliado atrás. Isso inverte uma cláusula escrita no comentário de
`_pontos_de_impacto` (`main.gd`, função homônima; «ignora o y de quem atira») e no README, e cobra a
reescrita honesta das duas coisas. Bloco e casa têm posição conhecida, então obstrução é teste
de segmento contra a caixa do bloco — geometria decide, nenhum sorteio é chamado aqui (mesma lei
da salva atual). Chegada por cima e por baixo e grupo vindo de outro canto entram aqui como
**origem do tiro**, não como IA nova.

**O que saiu medido, em três fatias.** A caixa do bloco cheio é lida dos próprios cascos pintados e
fecha **10,512 × 3,467 × 4,450 u** contra os pisos da grade (10,52 / 3,47 / 4,45), e ela **segue a
lotação**: meio bloco tem 12 casas e 1,867 u de altura — fecha o topo, não esburaca o meio — e bloco
morto devolve `size −1.0`, o «não existe» do AABB. É essa cláusula que faz o atrito **abrir**
corredor em vez de entupi-lo. No contato, a muralha atira por coluna: **60 lançados + 180 tapados
pelo aliado da frente = 240 blocos armados**, com **60** colunas lidas (30 aliadas + 30 hostis), todas
de 4 blocos de fundo, **0** fileiras da frente caladas sem corpo na frente e **0** blocos de trás
atirando por cima do próprio aliado. A fresta que o parágrafo pedia existe e é cobrada por caso: com
ordem da ponte, o lance do bloco visado (**id 120**, andar `y −5,78`) passa por fora da frente e cobra
do **id 125**, no mesmo andar — **6 rebatidos** na salva comandada — e quem perde estado é a caixa
**interceptada, não a apontada** (0 pagadores cobrados sem perder estado, 0 hostis fora do elenco
mudando de estado, sobre 120 blocos lidos antes e depois). O `y` é arma de alcance, provado por
contrafactual na mesma corrida: com a caixa rasa (andares colados — a lei que este parágrafo derruba)
o primeiro corpo na linha seria o bloco **195**; com a caixa de três andares é o **125**, que é quem o
ledger cobrou. Nada sorteia: **240 caixas** e **5 760 leituras de casa** por salva, e duas montadas
gemeas devolvem **60/180/0** uma contra a outra com os **60** pares na mesma ordem. O preço do lote não
mudou: o desenho continua um nó, agora com **1 440 traços** armados (24 casas × 60 blocos) em vez dos
5 760 de quando as vinte e quatro bocas dos duzentos e quarenta blocos armavam todas as salvas.

**A cláusula invertida foi reescrita nos dois lugares, não afrouxada.** O comentário de
`_pontos_de_impacto` (`main.gd`, função homônima) continua jurando «nunca vertical» — mas agora
escopado: a cláusula vale para a salva da **linha**, os doze cascos em `y ≈ 0`; a muralha não passa
por essa função e resolve caixa contra caixa nos três eixos em `Esquadra.troca_salva`, onde o `y` é
arma de alcance. O README foi varrido no mesmo commit.

**O corredor cobra um equilíbrio que a sonda não conserta.** Com três bocas em cada quatro caladas,
sessenta salvas entre duas montadas gemeas fecham **0 blocos afundados de cada lado** — onde a régua
de antes jurava **30 afundados** — e ainda queimam casco (**996** aliados e **990** hostis perdidos
dos 24 000; **22 020** vivos na ponte). As duas alavancas que devolvem dente ao fogo são do
comandante, não da sonda: cravar `DANO_DE_BLOCO` acima de **2,2**, ou pôr **rodízio de fileiras**
(a coluna da frente se reveza com as de trás entre salvas) para a muralha atirar com o que tem de
vivo. Nenhuma das duas foi implementada em silêncio.

**O que a fatia ensinou sobre instrumento, não sobre jogo.** Quatro das quebras desta rodada eram de
sonda, e as quatro foram consertadas declarando a lei nova ou confessando o rótulo — nunca afrouxando
régua:

1. **A asserção antiga era a lei antiga.** O cabeçalho da família 11 cobrava «TODO BLOCO ATIRA», e o
   verde passou a depender de reescrevê-la como conta fechada (`lancados + obstruidos == armados`,
   **60 + 180 = 240**) com a lei velha impressa como contrafactual. Afrouxar a tolerância de
   `lancados` teria aprovado o corredor sem nunca nomeá-lo.
2. **Dígito de família alheia também vence.** O cabeçalho da família 8 (preço da pintura) jurava
   **23 070 + 23 160** — os dois lados assimétricos, dígito de rodada anterior — e a rodada do
   corredor fecha **23 160 + 23 160 contra 24 000 de teto por lado**. O número do cabeçalho e o do
   README foram re-cravados do log da rodada, não da memória: uma asserção que passa continua podendo
   carregar a sua mensagem desatualizada.
3. **Rótulo também é asserção.** As duas frases da família 12 imprimiam a fila **dos dois lados**
   como se fosse aliada («1 bloco visado de quem atira aliado» sobre 1 056 traços). A conta estava
   certa e a frase mentia; o conserto foi o rótulo, não o número.
4. **A mensagem pode mentir sozinha.** O custo da `massa_visivel` saiu de uma rodada jurando
   «mediana **+-0,36 ms**»: um `+` literal colado num `%+.2f`. Instrumento que erra o sinal do próprio
   diferencial não pode ser portão de nada — format corrigido e a sonda re-rodada, para o que entra no
   commit ser a rodada que o código de hoje produziu.

**Fechamento.** Bateria completa em **30 sondas com `quebras=0` e zero linha de erro**, e as três
sondas de olho em janela real também: `massa_visivel` **16 conferências** (112,7 fps com a massa
contra 124,4 sem, mediana de 3 pares A/B **−0,03 ms** contra teto de 8,0; **738 339 primitivas**
contra 116 255; **2,2 chamadas** para os 240 blocos; boca **105 px a 78° / 694 px a 14°**; salva
acendendo **346 de 720 colunas (48,1 %)** e varrendo **x 116 a 1330 de 1 440 px — 84 %**; vão lido
**40,8 u** contra alcance **73,0 u** depois de **18 s** de marcha), `fotograma` **95** e
`comando_olho` **13**. Os cinco PNGs da sonda de massa foram reabertos: o par `salva_voando` /
`salva_apagada` mostra o visor atravessado de traços e a mesma moldura sem eles, e `massa_apagada` é
espaço vazio, só as estrelas. A sonda da lei, `tools/probes/esquadra.gd`, passou de 89 para **97
conferências**, com a família 14 nova. Aprovação de timing, de leitura do quadro e do equilíbrio do
fogo continua sendo do comandante, não da sonda.

## 5.5 A roda do mouse tem duas portas (correção pedida a olho, não fatia nova)

Defeito relatado pelo comandante: «a roda do mouse está dando zoom quando estou mexendo nos
comandos». A causa é a escolha feita na fatia 1: `_input` **não consome** a roda, para os
`ScrollContainer` do painel continuarem rolando. Consequência medida — os dois canais escrevem
no mesmo gesto, e quem içava a lente era o comandante que só queria ver o grupo de manobra.

Escolhido pelo jogador: **os dois juntos**. Fora da moldura do painel a roda é do olho, como
sempre foi; sobre a moldura a roda é da lista e `campo_zoom` e a altitude ficam onde estavam;
**SHIFT+roda ou CTRL+roda** chamam o olho de volta de qualquer lugar. O modificador destrava o
gesto, a direção continua sendo da roda — «aproximar» e «afastar» são dois sentidos do mesmo
atalho, não dois botões, que é por isso o pedido original («shift para zoom, control para
zoom-out») virou um só par. O escopo do efeito não se mexe: em **PONTE** a roda fecha a FOV
contratada (`campo_zoom` de 0 a 1 → 78° a 14°), em **TATICO** ela move a **altitude** do olho e
nunca o `campo_zoom`.

A porta é geografia, não modo: `painel` passou a ser guardado no nó de montagem e
`_roda_e_do_olho(event)` decide por `get_global_rect().has_point(event.global_position)`, com o
modificador vencendo a geografia. Leis cobradas por sonda, com a moldura **lida do próprio nó**
e não escrita à mão — painel em **x 24–420, y 94–714**, o ponto de dentro **(222, 404)** e o de
fora **(600, 124)**: roda simples fora leva o zoom de 0,40 ao **1,00** (teto), roda simples por
cima do painel não move **nada** (0,40 → 0,40), SHIFT com o cursor em cima do painel fecha a
lente em 1,00 e CTRL devolve ao 0,00. Em TATICO, a mesma trinca sobre o painel: altitude no
**piso 24,0 u**, **teto 320,0 u** com SHIFT, **piso 24,0 u** outra vez com CTRL.

A armadilha desta correção é de instrumento e custa registrar: as duas sondas injetavam
`InputEventMouseButton` com `global_position` **default (0,0)**, que cai **fora** da moldura do
painel. Sob a lei nova elas teriam continuado verdes provando o caso velho sem querer. Hoje o
ponto de cada teste é derivado do `Rect2` do painel e a asserção confere o retângulo antes de
confiar na medida. Contas da rodada: `tools/probes/esquadra.gd` **100** conferências (era 97) e
`tools/probes/comando.gd` **66** (era 63), cada uma com as três portas cobradas.

## 5.6 Fatia 4.5 — o rodízio de fileiras (a alavanca que devolve fogo ao corredor)

O pedido do comandante foi dois, e esta folha paga os dois: «cada nave do bloco tem que atirar
também … e também fazer as naves se moverem durante a batalha». O primeiro veio na fatia 3.5; o
segundo é aqui, e ele não é enfeite — a lei do corredor cala **três bocas em cada quatro** (60
lançados contra 240 armados), e a única alavanca que devolve fogo sem desmentir a geometria é
trocar **quem** segura o vante. Trocar por sorteio seria mentira na conta, porque um lance que
atravessa um aliado continuaria mentira na tela; tem de ser **manobra**: o bloco que ainda não
descarregou sai da retaguarda, sobe à pista, toma o vante, e as três da frente fecham fileira um
degrau para trás.

**A pista é o meio-andar, e foi escolha do jogador** entre as três faixas que a geometria deixa.
Em boreste o ar é **2,488 u** contra **10,512 u** de caixa; em vante é **2,550 u** contra
**4,450 u** — nenhum dos dois passa um bloco sem sobreposição, e as famílias 2 e 13 da sonda
provam isso quadro a quadro. O eixo com folga é o vertical: os dois andares estão a **12,0 u** de
centro a centro e a caixa tem **3,467 u**, então existe uma faixa de **5,066 u** (+3,467 a +8,533
em relação ao próprio andar) por onde um corpo passa sem tocar nem o andar de baixo nem o de cima.
O centro dela é a cota da pista: `PISTA_DO_RODIZIO = 6,0 u`. Os dois andares caem no **mesmo**
ponto do meio-andar — os esquadrões `e` e `e + COLUNAS_NO_LADO` têm o mesmo `x` e o mesmo `z` e só
diferem em `y` —, logo há **uma pista por lado**, e é por isso que o andar da vez **alterna**: dois
corpos no meio-andar seriam dois corpos no mesmo lugar.

**A margem não é a geometria pura**, e foi aqui que a conta de cabeça mentiu: 2,533 u teóricos
viram **1,023 u** medidos quadro a quadro pela família 15, porque a faixa come a respira de
custódia (±0,45 u por esquadrão, defasados) e o freio de chegada. O contrato é folga positiva:
**0 sobreposições sobre 5 179 quadros** com a pista em uso, contra os 3,467 u de altura da caixa.

**As duas metades do preço.** `RODIZIO_A_CADA = 4` é a *chamada* por cadência; `RODIZIO_JANELA = 8`
é a *libertação* por leitura de pista, e quem manda nela é a travessia, não o apetite. Medido: a
travessia mais longa fecha em **672 quadros = 7 salvas** (a janela seguinte cai na oitava salva,
e nenhuma travessia estoura as 8). Como a mesma coluna só pode ser rearmada quando o andar dela
volta a ter a vez, a coluna roda **uma casa a cada duas janelas**, e o ciclo completo custa
`2 × RODIZIO_JANELA × LINHAS_NO_ESQUADRAO` = **64 salvas ≈ 102,4 s**. Esta é a fatura certa, e ela
substitui as duas promessas erradas desta sessão: primeiro **25,6 s**, antes de qualquer medida;
depois **32 salvas ≈ 51,2 s**, com a janela ainda contada de cabeça. O painel hoje anuncia 64, e a sonda confere o letreiro contra a medida:
**16 salvas entre duas rodas do mesmo andar, volta inteira 64 salvas = 102,4 s**.

**O sentido é medida, não gosto.** A frente indo para a retaguarda corre vinte e uma unidades de
**RÉ**, a 1,2 u/s do bloco, e a sonda mediu a travessia em **1 440 quadros** (quinze salvas). Por
**proa** são os mesmos vinte e uma unidades a 6,0 u/s e o recuo caro vira três saltos de sete
feitos em paralelo: **672 quadros**. A lei de voo (`voo.gd`, `FICHA_BLOCO`) não foi tocada — o que
mudou foi para onde o destino aponta.

**Inocuidade com a alavanca desligada, provada quadro a quadro.** A ordem é opt-in e nasce
desligada, e o portão não é «o código não roda»: é a montada desligada rodando **de verdade** em
paralelo com a ligada. Medido: **0 quadros com bloco em trânsito** na montada OFF ao longo das 30
salvas (2 880 quadros) da janela da inocuidade, e as **três primeiras salvas** da montada ligada
são **digito a digito** as da desligada (cauda `60/180/0` = lançados / tapados / rebatidos) — a janela é a
quarta salva, e até lá o código novo não é chamado. A permutação também é cobrada por leitura, não
por fé: a sequência de blocos com vante limpo fecha **[15, 10, 5, 0]** e volta à baseline na
quarta janela do mesmo andar, com o conjunto de `formacao` da coluna invariado em
**[0, 5, 10, 15]** — a manobra troca o posto, não inventa posto.

**Estados e pouso.** `rodizio_fase` do bloco vale `ROD_NA_LINHA` (a lei antiga: persegue o posto
da grade e respira), `ROD_SUBINDO`, `ROD_PISTA`, `ROD_DESCENDO`; as três fileiras da frente não
entram em fase, só recebem o posto novo quando o fresco pousa na pista. `RODIZIO_POUSO = 0,37 u`
não é régua nova: é `Voo.CAPTURA_DE_POUSO` (0,02) mais a folga com que a sonda da muralha já assina
o pouso da marcha (0,35). O bloco em trânsito persegue a **cota** da pista, sem a deriva somada —
somar mais meio metro de custódia é fechar a margem que a família 15 acabou de medir.

### 5.6.1 Teste da fatia 4.5

`tools/probes/esquadra.gd` **114 conferências** (era 100), `quebras=0`, zero linha de erro, ~128 s
de parede. As famílias novas cobram, na ordem: a alavanca desligada não roda; as três primeiras
salvas gemeas; a janela reclama o andar inteiro (**15** blocos, nunca outro tamanho); os dois
andares se revezam (`0 1 0 1 0 1 0 1`); zero abalroamento com a folga atribuída ao bloco e à fase
que a sofreram; o trânsito cabe na janela liberada; a leitura de fase entrega uma janela a cada
**8** salvas sem perder chamada; o preço anunciado é o preço medido (**64 salvas = 102,4 s**); o
recuo entrega a fileira (bloco 15 → fase 0, **14** reclamações, janela nova em 8 salvas); a presa
que cruza de lado não leva a pista comigo (bloco 15 virou presa hostil já em fase 0, a pista
aliada ficou com **14** reclamações contra as 15 da janela, e a vaga do receptor se abriu). O
atrito é impresso, não jurado: `SONDA-ESQUADRA: atrito com a alavanca LIGADA apos 67 salvas -
MASSA 120/120 • 10116c // hostil 120/120 • 10125c // 0 rend. (aliados afundados=0, hostis
afundados=0, rendidos=0)` — **0 blocos afundados dos dois lados em 67 salvas de manobra ligada**.
A conta de dente é essa, e ela diz o que a alavanca faz: **não** multiplica o fogo por salva — o
mínimo de lançados por salva na montada ligada continua **60**, o teto do corredor —, ela gira
**quem** ocupa o teto. A aprovação do *aspecto* da manobra — se o olho lê a volta como manobra e não como
glitch — é do comandante na janela, não da sonda.

**A outra metade do pedido é pixel, e ela mora em `tools/probes/massa_visivel.gd` (20 conferências,
eram 16).** A sonda não escreve fase na mão: põe `salva_numero` no quarto passo e chama
`_rodizar_fileiras()`, que é exatamente o portão que o fecho de salva chama. A muralha anda em passos
de **1/60 s** porque `Voo.CAPTURA_DE_POUSO` é **0,02 u** e o salto a cobrir é de 3 u — com o passo de
0,5 s que a sonda usava antes, nenhum corpo pousa jamais. A travessia fecha em **168 quadros
(2,8 s de simulação)** e a leitura é feita do olho da ponte, **60 u** atrás do centro aliado, com
`campo_zoom` zero e a pose **gravada e devolvida** entre o quadro ligado e o desligado: comparar pixel
entre quadros de olhos diferentes é medir o vento. Três quadros saem gemeos por construção —
`rodizio_na_pista`, `rodizio_pista_apagada` (o MESMO tabuleiro com o corpo aliado apagado) e
`rodizio_desligado` (o mesmo tabuleiro remontado com a alavanca desligada). O que se cobra é
**retângulo projetado**, não ponto: a boca de cada bloco da pista vira um retângulo lido na
profundidade do próprio corpo (**39 px** de altura nesta rodada) e sua luminância média em Rec.709,
porque uma caixa de 9 px no centro do bloco caía no vão da malha das 24 casas e lia fundo —
**7 de 9** bocas acendem acima do fundo apagado e as mesmas **7** clareiam o próprio retângulo contra
o quadro desligado (maior diferença **+0,0491**, piso 0,0020), com **15** corpos na faixa de ±2,0 u
em torno do plano médio lido da própria muralha (**y 0,486 u**) contra **0** corpos na mesma faixa do
desligado. A régua de vão só vale no **mesmo plano de profundidade**: filtrados os vizinhos por
|Δz| ≤ **1,0 u** e medida a folga de **borda a borda**, o corpo da manobra fica a **30,0 px** limpos
de qualquer fila contra os **5,0 px** da respira projetada (0,45 u de deriva; a caixa projeta 38,6 px
a 60 u). A primeira versão comparava telas de profundidades diferentes e reprovava a manobra por
perspectiva — **19,5 px** contra uma caixa inteira. **Bateria da rodada: as 30 sondas headless com
`quebras=0` e zero linha de erro** mais **as três de janela** (`fotograma` 95, `massa_visivel` 20,
`comando_olho` 13), com os PNGs relidos. Dez sondas foram tocadas por esta fatia: `esquadra` e
`massa_visivel` ganharam as duas famílias novas, `menu` passou a cobrar o quarto botão de MANOBRA,
e as sete que contam os comandos do painel (`cacas`, `capitania`, `cenarios`, `comando`, `ia`,
`misseis`, `recomecar`) passaram de **35 para 36** pelo mesmo motivo — a régua seguiu o botão,
nenhum número de jogo foi afrouxado.

## 5.7 Lapidação 1 — o mapinha de voo (tecla pedida a olho, não fatia nova)

O pedido é de mão, não de doutrina: **A/D passam a ser traslação lateral e o giro vai para Q/R**.
Antes de codar foi medida a consequência: as duas teclas desalojadas são as da rolagem (Q/E) e as
do empuxo vertical (R/V), e seis eixos não cabem em cinco pares. A decisão foi oferecida ao
comandante, não adivinhada, e a escolhida foi **Z/X para rolagem e C/V para o vertical** — mantém
`V` significando «desce», não inverte nenhum gesto aprendido e deixa os seis eixos vivos (as
alternativas eram aposentar a rolagem ou deitá-la automática na curva).

Ficou assim, e só isto: `W`/`S` avante e ré, `Q`/`R` guinada, `A`/`D` través, `↑`/`↓` arfagem,
`Z`/`X` rolagem, `C`/`V` empuxo vertical. Os nomes das ações acompanharam a lei em vez de
acompanhar a tecla: o par de proa/bordo virou `capital_giro_esquerda` / `capital_giro_direita`, e
`capital_bombordo` / `capital_estibordo` ficaram onde sempre deveriam ter estado — traslação para
dentro de costado. `capital_role_*` e `capital_empuxo_*` mantêm nome e lógica, só trocam a tecla
física, inclusive a autocorreção do adernamento. Ninguém mais no repo lê esses nomes: `main.gd` é
quem registra (`_registra_voo`) e quem consulta (`_update_capital_ship`), e a única outra leitora é
a sonda do voo — o custo do renomear foi medir duas listas de rótulos.

*(Emenda da lapidação 3, 2026-10-28: o comandante pediu o giro de volta para a mão esquerda —*
**`Q`/`E`** *— e a troca coube porque a rolagem já tinha saído de `E` na decisão acima. `R` ficou*
*inteiramente desocupada: o `RECOMEÇAR` nunca teve tecla, e a frase que jurava o contrário já estava*
*corrigida no README. O que a régua conferiu é o mapinha, não a letra solta —*
`tools/probes/manobra.gd` *abre pelo* `InputMap` *e fecha* `quebras=0 • conferências=57`*, com os*
*seis eixos vivos e o gesto de deitar o casco na curva intacto.*

A lei do través é um termo no mesmo somatório que já soma empuxo e subida, em
`main.gd` (`_update_capital_ship`): `traves * lado * CAPITAL_TRAVES`, com `traves` lido de
`bridge_rig.global_transform.basis.x`. Não é o x do mundo de propósito — é o mesmo lugar de onde o
rumo já saía, então girar antes de ir para bombordo muda a direção da traslação, que é o
comportamento de quem manobra com o costado virado. `CAPITAL_TRAVES := 12,0` é o valor do
`CAPITAL_LIFT` por decisão declarada: deitar e subir custam o mesmo fôlego, e o comandante não
reaprende o casco ao trocar de eixo. Instantâneo como o vertical, sem estado novo: como
`capital_velocity` continua sendo a diferença real do quadro, a mesa holográfica lê o través sem
nenhuma contabilidade extra, e o `clampf` de `MAP_X` que já fechava o costado fecha o través sem
regra nova.

Nada mais se moveu: rampa de throttle, tetos de arfagem e rolagem, os três limites do campo e o
`delta` de medição ficam como estavam, e nenhum número da esquadra, da salva ou do ledger é tocado
por esta fatia. É por isso que a régua dela é a bateria inteira, não asserções novas espalhadas:
uma troca de tecla que reescrevesse a física seria visível nas outras vinte e nove sondas.

**Teste da lapidação.** `tools/probes/manobra.gd` foi de **54 para 57 conferências** e continua com
`quebras=0`. As três novas são a lei: **uma conferência de mapinha**, que lê as doze ações no
`InputMap` e cobra **código digitado e posição física** de cada uma contra o espelho
`TECLAS_DE_VOO` da sonda — é a primeira vez no repo que trocar uma tecla reprova por número, antes
isso era texto que ninguém lia; e **as duas do través**, que zeram a atitude do rig e cobram
`x` de **0,00 a −12,00** em dez passos de 0,1 s com `rotation.y` em **0,0000** e `z` parado, e a
volta por estibordo devolvendo os mesmos 12,00 (`−12,00 → 0,00`). O predicado «não virou» é o que
separa os dois gestos: sem ele, um través que também escrevesse guinada passaria contando curva
onde o comandante fez uma traslação.

**Bateria da rodada.** As **30 sondas headless** fecharam com `quebras=0` e **zero linha de erro**
em todas, com `manobra` em 57 e `menu` em 63 conferências — a ausência de baseline tolerada é o
que prova a afirmação do parágrafo acima de que nada mais se moveu. As três de olho foram rodadas
em janela real, sem `--headless`: `fotograma` **95** conferências, `massa_visivel` **20**,
`comando_olho` **13**, todas `quebras=0` e `linhas_de_erro=0`, e os quadros reabertos a olho
(`01_abertura`, `olho_01_ponte`, `olho_02_tatico`) sem regressão de raster. Uma honestidade sobre
o portão visual: a legenda nova está no rodapé da coluna do painel, abaixo da dobra do ScrollContainer,
então os PNGs provam que o mapinha não quebrou a ponte — não provam que ele se lê. Quem aprova o
gesto na mão é o jogador, e a tecla em si é texto conferido pela sonda, não pelo pixel.



## 6. Fatia 5 — doutrina e capitânia por esquadrão

Escolhido: almirante (jogador) → general → capitão de esquadrão. Sem ordem do jogador, cada
esquadrão segue **postura própria** (agressiva/defensiva/reserva) e um oficial hostil já faz
isso por salva (`README:341`, a IA hostil «escolhe postura a cada salva»). A novidade é o
**capitão como estado**: cada esquadrão tem uma capitânia de esquadra, e perdê-la não tira poder
de fogo (que vem de `navios`), tira coordenação — teto de manobra e de concentração de fogo
caem a um piso medido. Interface: `esquadra.gd` ganha por esquadrão `capitania_viva: bool` e
`postura`, e o dano a bloco passa a poder atingir a capitânia do esquadrão.

## 7. Fatias 6 a 8

- **6 — Iserlohn**: o planeta de raio 15 u em `(0, 22, −64)` (`main.gd:266-267`) é hoje parado,
  não destrutível, e apenas barreira que para lance sem pagar integridade. Vira fortaleza com
  canhão de recarga, que é a pendência literal do README («o canhão de recarga da fortaleza
  (ainda por fazer)»). Dobrar a tarefa aberta #135 aqui.
- **7 — fases, reforços e cercos**: não existe `reforco`/`onda` no código; as "FASE" de hoje são
  ângulo de lua, pose de tripulação e sequência de ruína. Pré-formação estratégica por fase +
  reforços chegando + cerco pelos flancos é o conteúdo que as tarefas abertas #136 e #138 pedem.
- **8 — mapa grande com não-explorado**: depende da fatia 1 (olho livre) e da camada estratégica
  de §8. Reconhecimento existe (`sondas táticas visíveis`), névoa não.

## 8. Decisão adiada, registrada

Camada estratégica em **parsec/ano-luz**, com viagem entre estrelas, portais e bases, e o campo
tático esticado para que o alcance seja segundos-luz de verdade. É o único caminho que faz
"50 parsecs de um buraco negro" ser literal. Não é esta rodada: ela muda a escala de tudo que o
README hoje jura (alcance, profundidade do lado, caixa do campo, escala da mesa), e exige uma
decisão de arte — o casco passa a ser marcador, não corpo. Volta a ser perguntada quando as
fatias 1 a 5 estiverem verdes.

## 9. Leis que nenhuma fatia deste programa pode quebrar

- Toda fatia fecha com a bateria headless em `quebras=0` e as sondas de olho em **janela real**;
  luminâncias de janela são medida da rodada, nunca contrato.
- `APPDATA` descartável em `D:/Downloads/tmp-userdata`; hash do user data real conferido antes e
  depois de qualquer rodada em janela.
- Comando novo não pode sorteio: `rng`/`visual_rng` inertes, ledger da massa sem linha nova.
- Custo de pintura é medido e impresso, não prometido.
- README, cabeçalho das sondas e este spec no **mesmo commit** da fatia; números velhos não
  sobrevivem à varredura de exaustão.
- Nada de moldura duplicando a arte da cena; nada de emoji no código; comentários em português
  **com acento**, como o resto da casa — a cláusula ASCII deste spec estava errada e a fatia 1
  fechou com a convenção real do repositório.
