# Dano por casco e morte visível — design (lapidação 2)

Data: 2026-10-25. Projeto: Iron Stars Fleet Command (`D:/Downloads/IronStarsFleetCommand`).
Fatia do programa de comando: segunda da fila de lapidação aberta pelo comandante depois de
[`2026-10-23-comando-esquadra-e-escala-design.md`](2026-10-23-comando-esquadra-e-escala-design.md)
§5.7 (o mapinha de voo).

## 1. O pedido, e o que foi medido antes de desenhar

O pedido é este, ao pé da letra: *"Gostaria de ver de pouco em pouco as naves de cada bloco sendo
destruídas e também não só o visual dos fogos mas que os tiros causem dano real junto de suas
animações. A ideia de concentrar fogo em uma área parece obsoleta ao jogo de agora, o ganho deve
seguir o tiro individual, mas mantendo essa dispersão de acertar as naves mais próximas."*

Medido no código antes de qualquer decisão:

* O ledger é **um golpe por bloco**, resolvido de uma vez no fechamento da salva:
  `troca_salva()` monta `pares` (um por bloco que atira) e aplica um `_aplicar_golpe` por par, de
  `DANO_DE_BLOCO` 2,2 ([`esquadra.gd:1030-1108`](../../esquadra.gd), golpe em `:1090`, aplicação em
  `:1154`).
* O fogo por casco **já existe, mas não custa nada**: `tiros_da_salva()` ([`esquadra.gd:1129`](../../esquadra.gd))
  deriva um traço por casa viva do mesmo ledger, e a onda atrasa cada lance em
  `casa × PASSO_DA_ONDA` ([`main.gd:2121`](../../main.gd)). Vinte e quatro bocas atiram, um golpe paga.
* A casa **não é corpo**: `CASAS = CASAS_X 4 × CASAS_Y 3 × CASAS_Z 2 = 24` ([`esquadra.gd:50-53`](../../esquadra.gd)),
  `casas_vivas()` **deriva** quantas casas há a partir do agregado `navios`
  ([`esquadra.gd:522-526`](../../esquadra.gd)) e `pintar_cores()` dá às vinte e quatro casas a **mesma
  cor** ([`esquadra.gd:1348-1358`](../../esquadra.gd)). É por isso que o bloco afunda de uma vez: não há
  o que morrer em partes, porque a parte não tem estado.

## 2. As três decisões do comandante

Colhidas uma a uma antes de codar, e registradas aqui porque são elas, não gosto meu:

1. **Quando o número se move:** *"fecha na salva, morre na onda"*. O ledger continua decidindo tudo
   no fechamento — determinismo puro, zero `rng` na batalha — mas decide **casco a casco**; a onda de
   pintura aplica a morte quando o traço chega. Rejeitadas: resolver no impacto (introduziria estado
   pendente entre quadros e reescreveria as sondas de ledger) e a salva fechar no fim da onda (o
   tempo de voo viraria variável de jogo).
2. **O que significa concentrar:** *placa de escudo por casco*. Cada nave desenhada passa a ter a
   própria casca, então convergir lances na mesma placa arromba e afunda, e espalhar um lance por
   placa faz a casca comer tudo. Os dois botões continuam existindo, com lei nova; não aposentam.
3. **Quanto vale a placa:** *escala fiel — tudo dividido por 24*. Nenhum número de batalha se move
   (prova no §6), ao preço de as primeiras salvas de um engajamento não mostrarem morte nenhuma: é a
   fase em que as placas desnudam.

## 3. O modelo: a casa vira corpo

Cada bloco passa a carregar `casas: Array[Dictionary]`, `CASAS` entradas, cada uma com:

| Campo | Valor inicial | Papel |
|---|---|---|
| `vida` | `VIDA_DA_CASA := 100,0 / CASAS` = 4,1667 | o que resta da nave; zero apaga a casa |
| `placa` | `PLACA_DA_CASA := 4,4 / CASAS` = 0,18333 | casca daquela nave, mordida antes de `vida` |
| `morta_em` | `-1,0` | nº da salva em que a casa apagou, `-1` enquanto vive |

`navios` **deixa de ser autoridade e passa a ser derivado**: no fim de cada salva, `navios` é a
**soma das vidas correntes** das vinte e quatro casas — mesma escala, mesma unidade, mesmo nome de
campo. Todo leitor atual continua lendo o mesmo número (os 21 usos dentro de `esquadra.gd` e os 33
fora dele: painel, `caixa_do_bloco`, fórmula de dano, fórmulas de física, sondas), e o que muda é a
direção da seta: `navios` passa a ser conseqüência de *quais* cascos morreram e de quanto cada um
restante agüenta.

O que a mudança garante, e o que ela deixa exatamente como está — as duas primeiras são asserção de
sonda:

* **A derivação antiga de `casas_vivas` vira leitura, e a medição derrubou o teorema.** Cada casa
  viva carrega `vida ∈ (0, VIDA_DA_CASA]`, e o desenho prometia que a soma das vivas caia em
  `(k−1, k]` múltiplos de `VIDA_DA_CASA`, de modo que `ceilf(frac × CASAS)` devolvesse `k`
  exatamente. Em double isso não fecha: `23 × (100 ÷ 24)` é **95,83333333333336** e o `ceilf` sobre
  ele devolve **24**, não 23. Dos vinte e três estados inteiros de lotação, **sete** — **5, 6, 7,
  20, 21, 22, 23** — seriam lidos uma casa acima do corpo, e nos **4 800** blocos-casa que a sonda
  percorre em combate a derivação teria errado **390** vezes (`tools/probes/casas.gd`, família B,
  que hoje cobra a lista exata e não um piso). `casas_vivas` mantém o contrato de retorno e passa a
  contar os corpos; a derivação pelo agregado fica apenas como caminho dos dicionários nus que as
  sondas antigas montam. A conseqüência prática é a que importava para a morte visível: o `ceilf`
  apontaria uma casa a mais do que o corpo tem, e o traço desenhado seria de quem não levou tiro.
* **A marca suja de pintura continua por bloco.** `pintas` é `{"casas": -1, "pos", "rumo"}`
  ([`esquadra.gd:349`](../../esquadra.gd)) — um inteiro que vale para as vinte e quatro casas, e
  `pintar_cores` já repinta o bloco inteiro quando ele suja. Com casa própria, a casa que apaga suja
  o bloco e o bloco repinta as vinte e quatro cores: é o que já acontece hoje, e não vira estado por
  casa. O que muda é de onde vem a cor de cada casa.
* **A caixa do bloco não muda de lei**: `caixa_do_bloco` já é lida casa a casa
  ([`esquadra.gd:536`](../../esquadra.gd)), então o topo que cai antes do meio, o corredor que abre
  para a fileira de trás e a escudeira ralada continuam funcionando — agora com o acréscimo de que a
  casa que sai da caixa é a que levou o tiro, e não a que o `ceilf` escolheu.

**Eixos de subsistema ficam no bloco.** `TRIPULACAO`, `ARMAS`, `MOTORES` continuam agregados do
bloco, e a rendição continua sendo do bloco: a tripulação de uma muralha é compartilhada e afundar
um casco não desmancha a cadeia de comando dele. Só `CASCO` desce para a casa. Isso mantém a lei 5
de `escudo.gd` (ataque de subsistema passa por cima da casca) e o seletor de subsistema do painel
exatamente como estão.

## 4. A lei do ledger: atribuição casa a casa, sem sorteio novo

`troca_salva()` mantém o esqueleto inteiro — retrato do quadro anterior, os dois lados atirando
sobre a mesma fotografia, `_alvo_do_bloco`, obstruído, rebatido, lei de coluna, rodízio de fileiras
no fim. O que muda é a unidade de trabalho, em um ponto só:

* hoje: `for par in pares: _aplicar_golpe(par["bate"], eixo, 2,2 × lotação × armas)`;
* passa: `for par in pares:` para cada **casa viva** de `par["origem"]`, um golpe de
  `TIRO_DE_CASA × (vida / VIDA_DA_CASA)`, com `TIRO_DE_CASA := DANO_DE_BLOCO / CASAS`, contra a casa
  de `par["bate"]` escolhida por `casa_alvo(casa_que_atira, bloco_origem, salva_numero,
  casas_alvo_vivas)`.

O fator `vida / VIDA_DA_CASA` é o que fecha a conta do §6: somado sobre as casas vivas, ele devolve
`DANO_DE_BLOCO × navios / NAVIOS_NO_BLOCO`, que é literalmente o fator de lotação de hoje. Sem ele,
uma casa destruída a 5 % continuaria atirando com a boca cheia e o bloco inteiro ficaria mais forte
conforme apanha — quantizado para cima. Com ele, casco abatido atira mais fraco, que é o que o
olho vê.

A função de escolha **não é nova**: é a aritmética de índice que `tiros_da_salva()` já usa para
pintar, `(c + id + salva_numero) % casas_alvo` ([`esquadra.gd:1147`](../../esquadra.gd)). A mudança
é o ledger passar a usar a atribuição que a pintura já usava, em vez de a pintura manter uma
atribuição decorativa que não custa nada. Conseqüência direta: `tiros_da_salva()` deixa de derivar
uma segunda fila e passa a **ler a fila que o ledger escreveu**, o que torna impossível, por
construção, a tela mostrar fogo que a conta não cobrou — e vice-versa.

Determinismo: nenhum `randf`, nenhum `visual_rng` tocado, nenhum `delta` lido. Duas montadas gemeas
fecham os mesmos dígitos, como já exige o comentário de `troca_salva`.

## 5. O tempo: fecha na salva, morre na onda

O golpe é decidido e a vida da casa é baixada no fechamento. O que a onda carrega é a **notícia**:
cada traço da fila sabe qual casa ele atingiu e se aquela casa apagou com ele, e a cor da casa muda
no quadro em que o traço toca, não no quadro em que a salva fechou.

* A casa apagada sai da cor (fica o cinza de morto de `pintar_cores`, agora por casa) e sai da caixa.
* O contrato do espelho sobrevive: `pares_da_ultima_salva` continua um par por bloco que atirou e
  `massa_visivel` continua cobrando os dois tamanhos iguais.
* Ganha uma asserção nova, que é a lei desta fatia em uma linha: **nenhuma casa apaga sem um traço
  que a atingiu, e nenhum traço que atingiu uma casa que apagou deixa de apagá-la na tela.**

O atraso máximo é o da onda inteira (`(CASAS-1) × PASSO_DA_ONDA`), já medido pela sonda do rodízio.
Entre o fechamento e o último traço, o painel mostra o agregado novo e a tela ainda não mostrou
todas as mortes: é o preço declarado da decisão 1, e é o mesmo atraso que o traço já tem hoje.

## 6. Os números, e até onde eles não se movem

Com a escala fiel, as três quantidades são o valor de bloco dividido por `CASAS`:

| Grandeza | Antes (bloco) | Depois (casa) | Somado sobre 24 casas |
|---|---|---|---|
| tiro de uma boca | 2,2 | 2,2 ÷ 24 = 0,091667 | 2,2 a lotação inteira |
| casca a arrombar | 4,4 | 4,4 ÷ 24 = 0,183333 | 4,4 |
| vida a esvaziar | 100 | 100 ÷ 24 = 4,16667 | 100 |

A divisão é exata nas três, e a lei de mordida é a mesma (`maxf(0, dano − casca)`, transbordo × 1,4
em `navios`), então o custo de afundar um bloco é o mesmo em tiros e em salvas:

* **hoje:** 2 golpes de 2,2 para desnudar a placa de 4,4, depois cada golpe derruba
  `2,2 × 1,4 = 3,08` de `navios`; `100 ÷ 3,08 = 32,47` → 33 golpes. **35 golpes de bloco.**
* **depois:** 2 tiros de 0,091667 para desnudar a placa de 0,183333, depois cada tiro derruba
  `0,091667 × 1,4 = 0,128333` de `vida`; `4,16667 ÷ 0,128333 = 32,47` → 33 tiros. **35 tiros por
  casa × 24 casas = 840 tiros = os mesmos 35 golpes de bloco.**

Onde os números **passam a se mover, de propósito**: a mordida da placa é não-linear por casa, e é
aí que o comando do §7 mora. Sob fogo uniformemente espalhado, as vinte e quatro placas são desnudadas
duas a duas e a casca total comida continua sendo 4,4, então o custo de afundar o bloco é o do quadro
acima, ao último dígito. Sob fogo concentrado em duas casas, só 0,3667 de casca são comidos em vez de
4,4 e o resto do mesmo tiro vira `vida` — o bloco morre mais cedo. Essa diferença **não existe hoje**
(um golpe de 2,2 contra uma placa de 4,4 não tem para onde convergir) e é exatamente o ganho que o
comandante pediu seguindo o tiro individual. A família 1 do §10 mede os dois lados.

O fator de lotação de quem atira também não se move, e é o `vida / VIDA_DA_CASA` do §4 que garante
isso: `Σ_casas_vivas TIRO_DE_CASA × vida_c / VIDA_DA_CASA = DANO_DE_BLOCO × navios / 100`, que é
literalmente a fórmula de hoje, termo a termo. O fator de `ARMAS` fica como está. Uma casa a 5 %
atira a 5 %, em vez de apagar a casa só quando ela morre e continuar atirando com a boca cheia até
lá — que era o desvio para cima que a quantização pura teria introduzido.

O que muda de unidade, e é dito em voz alta: `ESCUDO_DE_BLOCO 4,4` passa a ser a casca **somada**
das vinte e quatro placas, e a asserção da sonda `escudo` que lê `4,4 = 2 × DANO_DE_BLOCO`
([`tools/probes/escudo.gd:194-203`](../../tools/probes/escudo.gd)) muda de unidade sem mudar de
valor. E o `SETORES_DA_SALVA` ([`esquadra.gd:224`](../../esquadra.gd)) continua rodando um eixo por
(bloco que atira, salva), então só um em cada quatro lances de uma dada muralha entra em casa — o
que significa que a morte visível começa quando as placas desnudam, e a sonda mede em que salva isso
acontece em vez de eu chutar o número aqui.

## 7. CONCENTRAR e DISPERSAR sem disco de área

Os dois botões ficam onde estão e continuam escrevendo `fogo_concentrado` e o raio do disco
([`esquadra.gd:870-878`](../../esquadra.gd), [`main.gd:2735`](../../main.gd)). O que muda é o que a
ordem compra, e ela passa a comprar isso sozinha, sem código novo de efeito de área:

* **concentrado**: os lances convergem nas casas mais próximas do bloco visado → várias placas
  mordidas pelo mesmo tiro, placa arrombada, casco apagado à vista;
* **disperso**: um lance por casa → cada placa come o seu tiro e a muralha não morre em nada.

Nenhum dano de área existe ou passa a existir: não há raio que liquide casas vizinhas, não há
"disco que causa dano". O disco é **seleção de alvo**, como sempre foi, e o ganho vem do tiro
individual. A dispersão de acertar os navios mais próximos continua sendo a lei de `_alvo_do_bloco`
e da casa-alvo, intocada.

## 8. Raio de mudança medido

| Item | Contagem lida hoje |
|---|---|
| Sondas em `tools/probes/` | 34 — **31** rodam na bateria headless, 3 ficam na janela (`comando_olho`, `fotograma`, `massa_visivel`) |
| Sondas que chamam `troca_salva()` | 4 (`casas`, `esquadra`, `massa_visivel`, `voo`) |
| Leituras de `["navios"]` fora de `esquadra.gd` | 26 |
| Leituras de `navios` em `esquadra.gd` | 25 linhas |
| Chamadas de `casas_vivas` | 18 — o número não se moveu, e é a prova de que o contrato de retorno ficou de pé |
| Leitura de corpo (`casa_viva` 8, `casas_no_bloco` 10, `casas_vivas_de` 5) | 23 — o que a lei nova exigiu, somado por cima dos 18 |
| Escrita de `["navios"]` em `tools/probes/` | **0** — as faixas de montagem que escreviam o agregado hoje chamam `fixar_lotacao` / `zerar_placas` |
| Referências a `ESCUDO_DE_BLOCO` | 7 em `.gd` (o número continua sendo a soma das 24 placas) |

Contado na Task 6, com o escopo declarado: cada linha da tabela é `grep -rn --include=*.gd` do
símbolo exato (`\b...\b` onde faz diferença), linha a linha, `.md` fora. O que se moveu desde a mesa
de desenho é o que a lei nova pediu: `troca_salva` ganhou a quarta chamada, a sonda `casas.gd`, e
nasceram 23 leituras de corpo por cima dos 18 `casas_vivas` que continuam no mesmo número — o
contrato de retorno não mudou, e é isso que a igualdade prova. As escritas de `["navios"]` dentro
das sondas zeraram: onde a montagem antes escrevia o agregado, hoje passa por `fixar_lotacao` ou
`zerar_placas`, que escrevem o corpo e deixam o agregado ser conseqüência. A linha
`["navios"]` fora de `esquadra.gd` (26) não é recomponível com as 33 originais, contadas na mesa de
desenho com outro recorte; o que vale daqui pra frente é o comando acima.

Arquivos tocados: `esquadra.gd` (modelo, ledger, `casas_vivas`, `pintar_cores`, `caixa_do_bloco`),
`escudo.gd` (morder por casa, sem janela de colapso por casa — ver §9), `main.gd` (onda carrega a
notícia da morte, painel), e as sondas `esquadra`, `massa_visivel`, `escudo`, `comando`, `ia`,
`voo`, mais a família nova. As famílias 11–15 das sondas (as da massa, do bloco e do escudo, lidas
em `tools/probes/`) re-medem, e o README — que é contrato medido e cita números do caminho de fogo —
passa pela varredura de números (`godot-readme-number-sweep`) no mesmo commit.

## 9. Casos-limite e erro

* **Casa morta não atira nem leva tiro.** Guarda análoga ao `if not bool(alvo["vivo"])` de
  `_aplicar_golpe` ([`esquadra.gd:1158`](../../esquadra.gd)): um golpe que chega numa casa já apagada
  é redistribuído para a casa viva seguinte do mesmo bloco, e o ledger conta isso como acerto no
  bloco — senão o segundo traço do mesmo par sumiria do ledger sem pagar, e a conta de
  `lancados` divergiria da de traços.
* **Bloco que afunda no meio da própria salva.** A última casa apaga com `navios` em zero e
  `vivo = false` exatamente como hoje; `perdas_hostis`/`perdas_aliadas` continuam contando **blocos**,
  não casas, para não mover o placar que o README cita.
* **Janela de colapso por casa.** `ESCUDO_JANELA 4,0` é lei de casco nomeado, com regeneração. A
  muralha não regenera (declarado em `escudo.gd:37-40`), então a placa da casa **não** abre janela:
  `placa` zerada fica zerada pelo resto da vida do bloco. Não existe reabastecimento de `navios` no
  repo — a única escrita do campo é a que derruba, em [`esquadra.gd:1166`](../../esquadra.gd) — e a
  placa herdada por rendição continua herdada, exatamente como o `escudo` do bloco continua hoje
  quando o bloco cruza de lado em `_prencher_rendicoes`. É a escolha que não inventa estado novo, e
  é o que a lei "casca gasta, não recarregada" já diz.
* **`morta_em` é só notícia.** A sonda de olho confere a cor da casa contra `morta_em`; o campo não
  entra em nenhuma conta de dano.

## 10. Teste da fatia

A régua é a bateria inteira — **34 sondas** em `tools/probes/`, **31** delas headless com
`quebras=0` **e** zero linha de erro, mais as **3** de olho (`comando_olho`, `fotograma`,
`massa_visivel`) em janela real com o PNG reaberto. O que é novo, e o que a sonda `casas.gd`
respondeu (18 conferências nas famílias A–E):

1. **Família da escala fiel — verde.** As três divisões do §6 conferidas como constante
   (`vida 4.16666667`, `placa 0.18333333`, `tiro 0.09166667`, exatas na divisão) e o custo de
   afundar um bloco medido nas duas granularidades: **35 golpes de bloco ≡ 840 lances de casa**, na
   mesma semente e com o mesmo ledger. A outra metade do item como ele foi escrito — "concentrado em
   duas casas, o mesmo número de tiros afunda o bloco **antes** da salva 35" — **não** é o que a
   lei faz e não entrou no portão: concentrar apaga as casas mira das e deixa as outras de pé, então
   o bloco converge a vida, não a morte mais rápida. O que a granularidade compra é a **casa** cair
   antes (família D: salva 3 contra 185), e isso é a família 4 abaixo, não esta.
2. **Família da derivação — o teorema caiu, o portão ficou.** `casas_vivas(bloco) ==
   ceilf(navios / 100 × CASAS)` foi conferido em **4 800** blocos-casa de combate: **0** desvios
   sobre o corpo, mas a derivação antiga teria errado **390** vezes, e a asserção hoje cobra a lista
   exata dos sete estados inteiros em que ela mente (5, 6, 7, 20, 21, 22, 23) em vez de um piso.
   Um portão que não pode falhar não é portão — foi a primeira versão desta família.
3. **Família da morte visível — verde.** Nas **2 880** casas apagadas do census, **0** apagaram sem
   traço que as atingiu e **0** traços mataram casa que não apagou; a fila tem exatamente um traço
   por casa viva de cada bloco cobrado (**1 440 traços contra 1 440 casas**). A primeira morte em
   combate real cai na **salva 1**, com **18** traços matando sobre bloco que segue na lista, e o
   traço chega antes da notícia: tocado no **quadro 39** do pulso, a casa está na tela antes do
   toque e fora depois, e **0** recados sobrevivem ao fim do pulso.
4. **Família do comando — verde, com o instrumento trocado no caminho.** "Concentrar afunda casa
   mais cedo que dispersar" media o campo inteiro (`720` casas de destino no disperso contra `72` no
   concentrado) e **aprovava sem a mira**, porque a ordem da ponte já concentra blocos-alvo. O portão
   passou a ser a digital **por atacante**: um bloco dispara 24 canos e sob a ordem eles pousam na
   **mesma** casa — `1` contra `24` sem a ordem, campo `5` contra `720`, `1 440` traços no disperso
   contra `864` no concentrado, cada um igual às casas cobradas do próprio ledger. No mesmo
   tabuleiro, a primeira casa apaga na **salva 3** com a ordem e na **salva 185** sem ela.
5. **Paridade com a lei de coluna e o rebatido — verde.** Mesmas caixas, mesmos `obstruidos` e
   `rebatidos`: a família 14 de `tools/probes/esquadra.gd` lê a caixa cheia em
   **10,512 × 3,467 × 4,450 u**, meio bloco com **12 casas e 1,867 u** de altura e um terço com
   **8 casas e 0,267 u** — cada camada extincta custa um passo de **1,6 u** e o morto devolve
   `size −1,0`. E a caixa agora perde **por eixo**: apagar uma casa do meio não move volume nenhum
   (a união continua a mesma), enquanto derrubar a coluna da esquerda abre **10,512 → 7,312 u** em
   x sem tocar na altura — o caso que o `range(casas)` antigo jamais produziria, porque ele só
   despia o topo.
6. **A régua foi contada, não assinada.** `tools/probes/` tem **34** sondas; a bateria headless
   escreveu **31** logs e os **31** fecharam `quebras=0` com **zero** linha de erro. As **3** de olho
   rodaram em janela real e devolveram `quebras=0` sobre **95** (`fotograma`), **20** (`massa_visivel`)
   e **13** (`comando_olho`) conferências, com os PNGs relidos: `massa_zoom` mostra as vinte e quatro
   casas de cada bloco como degraus separados nas duas muralhas, `massa_apagada` devolve campo vazio
   sem fantasma de silhueta, `massa_largo` mantém a muralha legível pela lente de 78° da ponte. O custo
   é lido em escritas e lances, nunca em `ms` — o relógio deste host lê ±35 % entre rodadas. A
   aprovação estética continua sendo do comandante: o que a sonda jura é a contagem, não o quadro.

## 11. Fora de escopo, declarado

* Navio por navio como unidade de comando (a seleção continua por bloco).
* Arte nova de morte: a casa apagada é cor e caixa, sem destroço novo — destroço por casa é fatura
  de janela com as três sondas de olho, e entra como fatia própria se o comandante quiser.
* Mísseis e caças entrando na granularidade de casa: continuam batendo no bloco como hoje.
* A IA de estratégia por partida (item ③ da fila de lapidação), que é o próximo documento.
