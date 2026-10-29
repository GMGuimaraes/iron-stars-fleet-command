# Lapidação 4 — sub-bloco manobrando e âncora viva: design

**Data:** 2026-10-29
**Estado:** aprovado seção a seção pelo comandante; este documento é a transcrição medida das seis
seções, auto-revisado contra o `esquadra.gd` e o `main.gd` do commit `7f714bc`.
**Programa:** `docs/superpowers/specs/2026-10-23-comando-esquadra-e-escala-design.md` (comando por
clique, escala), `docs/superpowers/specs/2026-10-25-dano-por-casco-e-morte-visivel-design.md`
(lapidação 2 — a casa vira corpo).

## A frase do comandante, e as três causas medidas

> «O bloco de várias naves parece bloco único e não vários blocos com quantidades de naves que
> podem se mover livremente como peças de xadrez. Tanto que quando são sugados pelo buraco negro
> todas as naves são atingidas, mesmo as que não estão no raio de alcance do poço gravitacional. A
> estela solar também não está representada de forma esférica.»

Três queixas, três causas, todas lidas no código antes de desenhar qualquer coisa:

1. **Parece bloco único** porque o bloco tem UMA posição (`b["pos"]`, escrita em
   `esquadra.gd:961`) e as vinte e quatro casas são vinte e quatro deslocamentos rígidos dessa
   posição: `casa_local(c)` (`esquadra.gd:314-323`) é aritmética pura de índice e o
   `rot * casa_local(c)` do `pintar` (`esquadra.gd:1585`) nunca pergunta se aquela casa anda
   sozinha. O que é individual hoje é só a `vida` da casa. Não há lei de voo por casa, nem por
   grupo de casas.
2. **O poço atinge quem está fora do alcance** porque ele nunca mede a massa:
   `_collision_bodies()` (`main.gd:4186-4202`) devolve `fleet`, `enemies` e `bridge_rig`, e os 240
   blocos não estão nessa lista. `_puxar_para_o_poco` (`main.gd:3690-3703`) itera sobre esses
   ~26 corpos, com `if distancia > POCO_ALCANCE: continue`. A muralha entra no poço por uma porta
   inteiramente diferente: `estacao(lado)` (`esquadra.gd:633-634`) herda de `centros(lado)`
   (`esquadra.gd:625-626`), que é `_centro_de(nucleos)` — a média dos doze núcleos — re-derivada a
   cada tick em `passo` (`esquadra.gd:913-914`). Um núcleo arrastado 40 u move a estação, e
   a estação move os 120 postos (`esquadra.gd:929`), inclusive os blocos a mais de 46 u do poço. A
   queixa não é um bug de raio: é a ausência de qualquer medida corpo a corpo com a massa.
3. **A esteira não é esférica** nas LEIS já é: `_empurrar_no_vento` (`main.gd:3714-3729`) usa
   `node.global_position - ESTRELA_POS` em três eixos, `ESTRELA_RADIAO_RAIO` 120,0 e
   `ESTRELA_CORONA_RAIO` 30,0 são raios esféricos, e a `OmniLight3D` já tem
   `omni_range = ESTRELA_CALOR_RAIO` (`main.gd:3383`). O que é disco é a ARTE: `_montar_estrela`
   (`main.gd:3368-3386`) monta uma moeda (`_cylinder(ESTRELA_POS, 13.0, 13.0, 1.4, ...,
   Vector3(PI/2, 0, 0), 24)`, `main.gd:3372-3373`) e vinte billets de coroa num anel plano
   (`main.gd:3375-3378`, `sin(ang) * 3.0` é o único desvio fora do plano). O conserto é de cena,
   não de lei.

## Decisões do comandante (cravadas, não deduzidas)

| Pergunta | Resposta |
|---|---|
| Granularidade | **Sub-bloco manobrando** — o bloco de 24 casas se subdivide em 6 peças de 4 casas, cada uma com lei de voo, caixa e posição próprias. 240 corpos viram 1 440. |
| Cadeia de comando | **Sub-bloco livre, ordem no bloco** — seleção, SHIFT de esquadrão, painel, HUD e ordens continuam no bloco; a peça decide COMO chegar ao posto. |
| Âncora | **Média dos blocos vivos** — a estação passa a ser estado perseguido, não derivada dos núcleos a cada tick. |
| Folga | **Folga da boca do bloco (~13 u)** — aceita na pergunta, **reduzida por medida** na seção 4: 13 u isotrópico é geometricamente impossível no ar que existe. |
| Devoramento | **O poço come a peça** — as 4 casas da peça moram juntas; o bloco sobrevive com 20 casas. |

Arquitetura aprovada: **A — a peça é um estado dentro do bloco** (o bloco continua sendo a unidade
de comando, o ledger e a pintura; a peça é uma lista de seis dicionários dentro dele). As
alternativas rejeitadas foram B (a casa vira corpo autônomo: 5 760 leis de voo, ledger e seleção
mudam de dono) e C (peças como nós separados: quebraria o contrato de `INSTANCIAS_POR_LADO` e o
desenho da esquadra inteira em um único `MultiMesh` por lado).

---

## 1. O sub-bloco como estado dentro do bloco

Cada bloco ganha `pecas: Array[Dictionary]` com seis entradas `{pos, vel, rumo, giro}`, uma por
peça. A identidade da peça é um fato de índice, herdado de `casa_local` (`esquadra.gd:314-323`),
não uma escolha nova:

```
por_camada = CASAS_X * CASAS_Z = 8        # esquadra.gd:315
camada     = c / 8                        # 0, 1, 2   (CASAS_Y = 3)
dentro     = c % 8
ix         = dentro % CASAS_X             # 0..3
iz         = dentro / CASAS_X             # 0, 1      (CASAS_Z = 2)
p          = camada * CASAS_Z + iz        # 0..5  ← a peça
```

Daí a **descomposição por igualdade**, que é o que dá ao recurso a prova de inércia:

```
casa_local(c) == peca_local(p) + casa_na_peca(ix)
peca_local(p)   = (0, (camada - 1) * 1,6, (iz - 0,5) * 3,2)     # PASSO_CASA_Y, PASSO_CASA_Z
casa_na_peca(ix) = ((ix - 1,5) * 3,2, 0, 0)                      # PASSO_CASA_X
```

Os dois termos somam exatamente o vetor que `casa_local` devolve hoje — nenhum número de grade se
move. Uma peça é **quatro cascos em fila ao longo da asa**: `casa_na_peca` só anda em x, em
−4,8 / −1,6 / +1,6 / +4,8 u, e a extensão própria da peça em x é 9,6 + 0,912 = 10,512 u, que é a
boca do bloco inteiro (`esquadra.gd:153`). A peça é portanto a *fileira de quatro navios*, e a
formação de 24 casas são seis dessas empilhadas em duas camadas de altura e duas de profundidade.

Quem lê a casa passa a ler peça + casa-na-peça:

* `caixa_do_bloco` (`esquadra.gd:693-717`) — hoje itera `rot * casa_local(c)` sobre as casas vivas;
  passa a itera `pos_da_peca + rot_da_peca * casa_na_peca(ix)`.
* A mira por proximidade `_casas_por_proximidade` (`esquadra.gd:387-400`) — mesma troca, na mesma
  linha (`esquadra.gd:394`).
* `pintar` (`esquadra.gd:1562-1600`) — `mm.set_instance_transform` (`esquadra.gd:1585`) escreve a
  peça no lugar do bloco e a casa-na-peça no lugar da casa.

A integração: o bloco continua integrando primeiro, com a lei dele, intacta
(`esquadra.gd:959-964`). As peças integram num segundo laço, dentro do mesmo
`passo(delta, nucleos_aliados, nucleos_hostis)` (`esquadra.gd:912`), contra o posto derivado do
bloco. O bloco é a referência; a peça é o corpo que obedece.

O que NÃO muda de dono: ledger (`troca_salva` `esquadra.gd:1195`), seleção, SHIFT de esquadrão,
painel, HUD, os 240 blocos, os 120 por lado, os 5 760 cascos desenhados
(`INSTANCIAS_POR_LADO = BLOCOS_NO_LADO * CASAS` = 120 × 24, `esquadra.gd:114`), o censo de nós da
cena. A única granularidade nova do projeto é **o que a cena mede**: 1 440 corpos em vez de zero
(seção 3).

**Inércia provada, e é por isso que a igualdade importa:** com a folga zerada
(`FOLGA_DA_PECA = 0`), `pos_da_peca` é o sub-posto, `casa_na_peca` é o resíduo, e a soma
reproduz byte a byte o `casa_local` de hoje. Isso é a asserção B da seção 6, medida numa partida
inteira A/B, não uma promessa de design.

## 2. A âncora vira estado

`estacao(lado)` para de derivar de `centros()` e passa a ser um `Vector3` por lado, escrito por
integração:

1. **Semeada na largada** exatamente onde a grade nasce hoje. `montar` (`esquadra.gd:579`) já faz
   `centro_aliado = _centro_de(nucleos_aliados)` (`esquadra.gd:602`) e o recuo hostil sai de
   `_recuo_alvo()` (`esquadra.gd:643-645`), que lê `centro_aliado.z - 2 * FACHADA_DA_MURALHA -
   DISTANCIA_DE_CONTATO` contra `centro_hostil.z`, com `minf(0.0, ...)`. O quadro 0 é byte-idêntico
   ao de hoje, e é essa a asserção C da seção 6.
2. **Persegue a média dos próprios blocos vivos que estão sob custódia da grade** — ficando de
   fora os `com_destino` (`esquadra.gd:933`) e os que passam do limite da trela. É essa
   exclusão que fecha a conta: um bloco que recebeu ordem do comandante e um bloco em rodízio
   (`esquadra.gd:935-940`) saem da média, então a ordem não arrasta a muralha inteira.
3. **Anda com `Voo.marchar` capped a `MARCHA_DE_BLOCO` 6,0 u/s** (`esquadra.gd:143`). O ponto fixo
   é estável por construção: a média dos blocos que perseguem a estação é a estação, e um ponto
   fixo de uma média não pode fugir de si mesmo.

Consequência de comando: **o avanço hostil deixa de ser herança e vira alvo explícito.** Hoje o
hostil anda porque `estacao("hostil")` = `centros("hostil") + (0,0,recuo_hostil)`
(`esquadra.gd:633-634`) e `recuo_hostil` encolhe sozinho conforme os núcleos avançam. Amanhã a
estação hostil persegue a cota da coleira de contato — `estação_aliada.z - 2 * FACHADA_DA_MURALHA -
DISTANCIA_DE_CONTATO` — e nada mais. Risco declarado, não escondido: **a família 10 da sonda
precisa re-asserir a aproximação hostil, ou a muralha pára de marchar e o portão passa a provar um
jogo que não anda.** O número que ela mede hoje está na régua de `FACHADA_DA_MURALHA` 10,5
(`esquadra.gd:109`): travessia de 154,0 u para 40,0 u.

`centros()` continua existindo e continua sendo a régua dos núcleos, porque há leitores que querem
exatamente isso: `main.gd:1976` e `main.gd:2033` (leitura de escala do HUD),
`tools/probes/esquadra.gd:952` (`sep_nucleos`), `tools/probes/massa_visivel.gd:669` e `:763`
(estacionam a `bridge_rig` sobre `centro_aliado`). Nove chamadas a `estacao()` nas sondas
(`tools/probes/comando.gd:255,413,459`, `tools/probes/esquadra.gd:552,594,595,972,1880`,
`tools/probes/massa_visivel.gd:227`) passam a ler
estado em vez de derivada — valor igual na largada, divergente depois, e é essa divergência
controlada que o comandante pediu.

Pendente de verificação na implementação (não é surpresa, é tarefa): a IA de pontaria dos núcleos
aliados. Se ela mira em `centros`, ela mira o núcleo médio — que é o que faz hoje.

## 3. A cena mede peça por peça

A porta nova é um acesso: `Esquadra.pecas_na_cena()` devolve para as 1 440 peças vivas um
`{pos, raio, bloco, peca}` — `Dictionary` **por referência**, então escrever no dicionário é
escrever no estado; é a mesma técnica que `_collision_bodies()` (`main.gd:4186-4202`) usa hoje. Uma
peça sem nenhuma casa viva está morta e sai de `pecas_na_cena()` — via `casas_vivas(bloco)`
(`esquadra.gd:656-662`), que já existe.

| Lei | Hoje | Depois |
|---|---|---|
| Poço (`_puxar_para_o_poco`, `main.gd:3690`) | itera `_collision_bodies()`, ~26 corpos; a massa não entra | itera 1 440 peças, distância por peça, `POCO_ALCANCE` 46,0 / `POCO_PUXO` 11,0 **inalterados**, `continue` por peça |
| Horizonte (`main.gd:3699-3701`) | `_devorado_pelo_poco` (`main.gd:3822`) zera `unit["hp"]` inteiro (`main.gd:3834`) | `POCO_HORIZONTE` 9,0 devora **a peça**, pela porta nova `Esquadra.abater_peca(bloco, p, salva_numero)` |
| Vento (`_empurrar_no_vento`, `main.gd:3714`) | não toca a muralha | empurra a muralha (força nova; ver abaixo) |
| Corona (`_queimar_na_corona`, `main.gd:3843`) | drena `hp`/`engines` do corpo | cobra a `vida` da **casa**, não `MOTORES` |
| Rochas/astros (`_cobrar_contato`, `main.gd:3884`) | itera `_collision_bodies()`, ~26 corpos | itera peças, `raio` lido da caixa medida de fileira (10,5 u asa a asa) |

`abater_peca` escreve exatamente os mesmos campos que um tiro escreve — `vida`, `placa`, `morta_em`,
`a_noticiar` (`esquadra.gd:1374-1377`, `esquadra.gd:1420-1422`, e os mesmos quatro campos em
`_casas_novas` `esquadra.gd:351-356`) — e chama `_recalcular_agregados`. Nada de ledger novo: o
poço passa a matar pela porta pela qual um tiro mata. O bloco vive com 20 casas, `navios` — que é
derivado — cai ~16,67 (100 × 4/24).

`_resolve_collisions` (`main.gd:4204`) fica **intencionalmente** de fora: peça não abalroa
capital nesta fatia.

Custo contado, não estimado: 1 440 peças × as cinco leis acima ≈ **25 mil operações vetoriais por
tique** — que é nada. O risco real é o `pintar`: hoje a checagem suja é **por bloco**
(`esquadra.gd:1570-1580`: `casas` mudou, ou `pos` mudou mais que 0,0001 em distância², ou `rumo`
mais que 0,001), e com peças livres cada peça suja sujeita o bloco inteiro → 5 760 transformados
por tique nos piores quadros. Guarda proposta: checagem suja **por peça**, no mesmo sub-ulp, para
os 4 transformados das casas só reescreverem quando a própria peça andou.

Consequência a re-medir (constantes intactas, números derivados não): o vento começar a empurrar a
muralha mexe na fachada que a família 10 assina. `ESTRELA_VENTO_ALCANCE` 96,0,
`ESTRELA_VENTO_ACEL` 3,0, `DISTANCIA_DE_CONTATO` 40,0 e `CAMPO_DE_APROXIMACAO` 130,0 não se mexem;
quem for medido diferente depois é o *tempo* de travessia, e ele entra no README varrido no mesmo
commit (`godot-readme-number-sweep`).

## 4. Folga, ar e vizinhos — a tabela medida

A tabela abaixo é a geometria de hoje, recontada linha a linha no código:

| Par | passo | caixa | ar |
|---|---|---|---|
| casas dentro de uma peça, em x | `PASSO_CASA_X` 3,2 | 0,912 | **2,288 u** (`esquadra.gd:489`) |
| casa a casa em z dentro do bloco | `PASSO_CASA_Z` 3,2 | 1,25 | **1,95 u** (`esquadra.gd:489`) |
| casa a casa em y dentro do bloco | `PASSO_CASA_Y` 1,6 | 0,268 | **1,332 u** (caixa `0,912 × 0,268 × 1,25`, `esquadra.gd:55`) |
| bloco a bloco na fileira, em x | `PASSO_BLOCO_X` 13,0 | 10,512 | **2,488 u** (`esquadra.gd:152-153`) |
| fileira a fileira, em z | `PASSO_BLOCO_Z` 7,0 | 4,450 | **2,550 u** (`esquadra.gd:153`) |
| andar a andar, em y | `PASSO_ESQUADRAO_Y` 12,0 | 3,47 | **8,53 u** (`esquadra.gd:122-123`) |

O piso hoje imposto por portão é `AR_MINIMO := 2.4` (`tools/probes/esquadra.gd:169`), cobrado em
`tools/probes/esquadra.gd:944` e `:1934` — régua de bloco, não de peça.

**13 u isotrópico: rejeitado por aritmética, não por gosto.** 13,0 u é o próprio
`PASSO_BLOCO_X`, e a caixa do bloco já tem 10,512 u: duas peças vizinhas com ±13 u de folga
somariam 26 u de curso contra 2,488 u de ar. Aceitar a folga da pergunta como isotrópica era
declarar que a família 2 reprova no primeiro quadro. Disse isso antes de escrever a lei; o
comandante aprovou a substituição («pode fazer»).

**Alargar a grade: rejeitado.** Dobrar `PASSO_CASA_Y`/`PASSO_CASA_Z` engoliria os
`DISTANCIA_DE_CONTATO` 40,0 — a muralha de 240 blocos passaria a fundo de
`FUNDO_DA_MURALHA` (`esquadra.gd:102-103`: (4−1)×7 + (2−1)×3,2 = **24,2 u**) para o dobro, e
`FACHADA_DA_MURALHA` 10,5, o recuo do hostil e a família 10 seriam reescritos. Isso não é lapidar
o sub-bloco, é trocar a escala tática aprovada no spec do programa.

Os três reservatórios de espaço real que já existem, e é neles que a peça vive: os 40 u de contato,
os 130 u de campo de aproximação (`CAMPO_DE_APROXIMACAO`, `esquadra.gd:234`), e as vagas abertas
pela morte casa a casa.

**A folga da peça, derivada da tabela:** cada componente é metade do ar mais apertado do qual a
peça participa, arredondado para baixo — o que garante por construção que duas peças vizinhas
nunca se sobrepõem, mesmo nos cursos extremos opostos:

```
const FOLGA_DA_PECA := Vector3(1.2, 0.6, 0.9)
# x: 2,488 ÷ 2 = 1,244 → 1,2 (o par é o bloco vizinho da fileira ao lado)
# y: 1,332 ÷ 2 = 0,666 → 0,6 (o par é camada 0 contra camada 1, DENTRO do mesmo bloco)
# z: 1,95 ÷ 2 = 0,975 → 0,9 (o par é iz 0 contra iz 1, DENTRO do mesmo bloco)
```

Trela é a peça não poder se afastar do próprio sub-posto mais que `FOLGA_DA_PECA` por eixo, eixo a
eixo. Nota honesta: o ganho de liberdade com isso é pouco — meio passo de casa em y, três quartos
em z. **A liberdade que o comandante pediu não vem da folga, vem da vaga**: é a lei de captura que
segue.

**Captura para frente, só em vaga, com histerese de 1,3 × passo.** A peça avança para o sub-posto
do vizinho morto apenas quando o espaço aberto tem pelo menos 1,3 × o passo daquele eixo (y: 2,08 u;
z: 4,16 u), e só entra se o posto está vago. Precedente na casa, lido: é a escala de peça do
rodízio de fileiras (`PISTA_DO_RODIZIO` 6,0 `esquadra.gd:164`, `RODIZIO_POUSO` 0,37
`esquadra.gd:183`), cuja folga vertical real foi medida em **1,023 u** no pior dos 5 179 quadros em
que a pista esteve em uso, contra os **2,533 u** que a geometria sem deriva prometia
(`esquadra.gd:160-161`) — e o comentário diz por escrito que «o pior quadro é de um corpo já em
fase PISTA, não da subida» (`esquadra.gd:802`). A histerese é o mesmo cuidado, numa escala menor.

**Vizinhos derivados do índice, sem hash novo.** De `(esquadrao, formacao, p)` sai no máximo 8
vizinhos: 2 em z (camada ±1... mesma camada, iz trocado), 2 em y, 2 em x (blocos vizinhos da
mesma fileira), 2 em diagonal. 1 440 × 8 = **11 520 testes de par por tique**, lineares, sem
alocação. A família 2 sobe um degrau: de «ar entre blocos ≥ 2,4» para «mínimo medido sobre todos os
pares vizinhos de peça ≥ o ar publicado daquele eixo, em todo quadro» — o portão antigo continua
verde, e o novo é a lei do §4.

## 5. A estrela esférica — cena, sem mover lei

Troca limitada à arte, e declarada como tal:

* A moeda (`_cylinder(ESTRELA_POS, 13.0, 13.0, 1.4, ...)` `main.gd:3372-3373`) vira
  `_esfera(ESTRELA_POS, 13.0, ..., 32)` — o mesmo `raio` 13,0, o mesmo material, o helper que já
  existe (`main.gd:3351`) e que o poço já usa (`main.gd:3242`).
* Os **mesmos 20** billets de coroa (`main.gd:3375-3378`) ficam no MESMO raio de
  `ESTRELA_CALOR_RAIO × 0,42` = **29,4 u**, que é `ESTRELA_CORONA_RAIO` 30,0 menos 0,6 u — passam
  a distribuir-se sobre a esfera por latitude `acos(1 - 2*(i + 0,5)/20)` (escada equidistante de
  área, determinística, **sem rng**) com azimute em passo áureo, e são esticados ao longo do próprio
  eixo radial. O resultado é uma bola de espinhos: a esteira pintada como a lei já a trata.
* **Censo preservado: 22 nós.** Uma esfera + 20 jatos + 1 luz = 22, exatamente o número que
  `tools/probes/fotograma.gd:678` crava (`get_child_count() == 22 and holo_cenario.size() == 1`).
  O portão passa pelo número, e só a *redação* da asserção muda — a linha 677 da mesma sonda diz
  «a estrela tem corpo na cena (disco + 20 billets da coroa + luz)» e passa a dizer «esfera + 20
  jatos radiais + luz».
* Nenhuma constante de lei se move: `ESTRELA_CALOR_RAIO` 70,0, `ESTRELA_CALOR_FATOR` 1,25,
  `ESTRELA_CORONA_RAIO` 30,0, `ESTRELA_QUEIMA_POR_SEGUNDO` 6,0, `ESTRELA_VENTO_ALCANCE` 96,0,
  `ESTRELA_VENTO_ACEL` 3,0, `ESTRELA_RADIAO_RAIO` 120,0, `ESTRELA_RADIAO_VARREDURA` 0,5
  (`main.gd:262-274`) ficam byte-idênticas, e as sondas que as lêem (`estrela.gd`, `cenarios.gd`)
  têm de continuar verdes **sem edição**.

Consequência declarada: os billets de coroa passam a existir acima e abaixo do plano do campo —
hoje eles só vivem no plano. Recomendo contra recortar por faixa de latitude: a queixa do
comandante é justamente que a representação era plana onde a lei é esférica.

## 6. Teste

Sonda nova `tools/probes/peca.gd`, oito famílias:

| Família | Asserção |
|---|---|
| A identidade | `casa_local(c) == peca_local(p) + casa_na_peca(ix)` para os 24 `c` e as 6 `p` |
| B inércia | A/B de uma partida inteira com `FOLGA_DA_PECA = 0`: transformados de pintura byte-idênticos |
| C trela | excursão medida por eixo nunca passa `FOLGA_DA_PECA`; quadro 0 da estação byte-idêntico ao de hoje |
| D ar | mínimo medido sobre o conjunto de ≤ 8 vizinhos (~11 520 pares/tique) ≥ o ar publicado por eixo |
| E captura | zero capturas fora de vaga, com histerese 1,3 × passo do eixo |
| F frase do comandante | arrastar um núcleo 40 u → estação anda 0,00 u no tick, média dos blocos ≤ 0,33 u, **zero tração em bloco além de 46 u** |
| G devoramento | o poço come exatamente 4 casas por peça, `lancados` inalterado, 35 ≡ 840 ainda de pé |
| H censo | contagem de peças sentindo poço/vento/corona, com zero vetor fora do raio de cada lei |

As sete sondas que tocam essas leis de frente — `batalha_real`, `casas`, `cenarios`, `comando`,
`esquadra`, `estrela`, `massa_visivel` — mais `fotograma` e `comando_olho` descem um degrau:
**declaram a precondition no criador do estado** (`montar` `esquadra.gd:579` e o laço de peças),
nunca afrouxam a tolerância. É a regra medida na fatia 3, quando doze sondas foram «consertadas» na
montagem e voltaram vermelhas porque o estado era rearmado no construtor.

Fecho no ritual da casa (`godot-iron-stars-slice-closeout`): varredura dos veredictos nos três
formatos, paridade `.gd`/`.gd.uid` gerada por `--import` (nunca na mão), bateria de **35 → 36
sondas** (32 → 33 headless, 3 de janela com `SKIP` na `bateria.sh`), a trinca de olho rodando
**em janela** com o PNG relido de volta, README varrido na mesma rodada, UM commit por nome de
arquivo, nunca `git add -A` — há WIP de outra sessão no checkout (`_tmp_pista_fria.gd`).

**O veredito final é do olho do comandante na janela.** Headless nunca pinta: nada aqui autoriza
dizer que a batalha «parece várias naves» — só que a lei que a move é peça a peça.

## Perguntas que ficam abertas

1. A IA dos núcleos aliados mira por `centros()`? Se sim, a âncora viva não a afeta; se ela mirar a
   estação, a mudança é visível e precisa de aprovação separada.
2. A folga derivada (1,2 / 0,6 / 0,9 u) dá liberdade de voo, não de xadrez. A liberdade de xadrez
   vem das vagas e dos 40/130 u de campo. Se o comandante quiser peça atravessando a muralha, isso
   é troca de escala tática e é outro spec.
3. O equilíbrio devido segue na fila e é decisão do comandante: 0 de 120 blocos afundam em 200 s de
   fogo de linha (alavanca `DANO_DE_BLOCO` 2,2, `esquadra.gd:197`).
