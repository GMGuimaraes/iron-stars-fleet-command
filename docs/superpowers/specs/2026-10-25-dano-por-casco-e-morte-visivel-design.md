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

* **A derivação antiga de `casas_vivas` continua valendo, agora como teorema.** Cada casa viva
  carrega `vida ∈ (0, VIDA_DA_CASA]`, então a soma das vivas cai em `(k−1, k]` multiplicadas de
  `VIDA_DA_CASA`, onde `k` é a contagem de casas vivas, e o `ceilf(frac × CASAS)` de
  [`esquadra.gd:522-526`](../../esquadra.gd) devolve `k` exatamente. A função não é reescrita: ela
  deixa de ser a autoridade da morte e passa a ser a leitura dela.
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
| Sondas em `tools/probes/` | 33 |
| Sondas que chamam `troca_salva()` | 3 (`esquadra`, `massa_visivel`, `voo`) |
| Leituras de `["navios"]` fora de `esquadra.gd` | 33 |
| Leituras de `navios` em `esquadra.gd` | 21 |
| Chamadas de `casas_vivas` | 18 |
| Referências a `ESCUDO_DE_BLOCO` | 4 |

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

A régua é a bateria inteira (33 sondas) com `quebras=0` **e** zero linha de erro, mais as três de
olho em janela real com o PNG reaberto. O que é novo:

1. **Família da escala fiel.** As três divisões do §6 conferidas como constante, e o custo de
   afundar um bloco medido nas duas granularidades sob fogo uniformemente espalhado: 35 golpes de
   bloco ≡ 840 tiros de casa, na mesma semente, com os mesmos três dígitos de `navios` ao fim de
   cada salva. O outro lado da moeda é conferido na mesma família: concentrado em duas casas, o
   mesmo número de tiros afunda o bloco **antes** da salva 35, e a sonda grava em que salva.
2. **Família da derivação.** `casas_vivas(bloco) == ceilf(navios / 100 × CASAS)` depois de cada
   salva, num combate de vinte salvas, sem exceção — o teorema do §3 lido como portão.
3. **Família da morte visível.** Casa a casa, em ordem de traço: nenhuma casa apaga sem tiro que a
   atingiu, nenhum tiro que matou deixa de apagar a casa. Mede também **em que salva a primeira casa
   apaga**, que é o número que o comandante vai julgar de olho.
4. **Família do comando.** Concentrar afunda casa mais cedo que dispersar, com o mesmo total de
   tiros disparados — a prova de que o ganho vem do tiro individual e não de um efeito de área.
5. **Paridade com a lei de coluna e o rebatido** (famílias 14 e as de `esquadra`): mesmas caixas,
   mesmos `obstruidos`/`rebatidos` que hoje, porque a caixa agora perde casa por casa.

## 11. Fora de escopo, declarado

* Navio por navio como unidade de comando (a seleção continua por bloco).
* Arte nova de morte: a casa apagada é cor e caixa, sem destroço novo — destroço por casa é fatura
  de janela com as três sondas de olho, e entra como fatia própria se o comandante quiser.
* Mísseis e caças entrando na granularidade de casa: continuam batendo no bloco como hoje.
* A IA de estratégia por partida (item ③ da fila de lapidação), que é o próximo documento.
