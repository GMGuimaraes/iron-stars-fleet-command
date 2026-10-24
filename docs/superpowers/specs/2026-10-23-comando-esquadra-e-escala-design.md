# Comando por clique, escala espacial e esquadra com hierarquia — desenho

Data: 2026-10-23 · Estado: aprovado para escrita, não aprovado para implementação ·
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
(b) os blocos não têm `Node3D` — só `pos` lógico (`esquadra.gd:196-201`) — e projetar `pos` não
exige criar 240 nós, o que seria o custo que a massa existe para evitar.

Candidatas: os 6 cascos aliadas de `fleet` (`main.gd:1596-1601`) mais a presa capturada que entra
nele em `main.gd:4671`, os 6 cascos hostis de `enemies` (`main.gd:1602-1609`), os 120 blocos de
cada lado, a capitânia, e os marcos de cenário. Mortos não são candidatos. `unproject_position`
exige matriz de câmera viva — é lei de janela, headless não prova (armadilha conhecida).

### 2.3 Seleção e ordem

- **Clique em aliado** seleciona o bloco (ou o casco nomeado). Clique no núcleo do esquadrão
  com modificador seleciona os 20 blocos do esquadrão (`BLOCOS_NO_ESQUADRAO`, `esquadra.gd:64`).
- **Clique em hostil** fixa `selected_target` — hoje só o dropdown faz isso (`main.gd:2091-2093`).
- **Clique em água vazia** escreve destino. `_give_order` (`main.gd:4805-4852`) passa a tocar a
  esquadra: cada bloco recebe `destination: Vector3` e marcha até ele com o
  `move_toward` que já existe (`esquadra.gd:382`), em vez de só seguir `centro_aliado`.
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

Contrato a reescrever no mesmo commit: a asserção `tools/probes/esquadra.gd:717-721` diz
«clique esquerdo nao moveu» o zoom — ela continua verdadeira e continua cobrada, só passa a
dizer «clique esquerdo nao moveu o zoom da ponte», porque o clique agora move *outra coisa*.

## 3. Fatia 2 — física de voo por classe

Hoje só a capitânia tem anisotropia (`CAPITAL_SPEED 22.0` avante contra `CAPITAL_REVERSE -0.6`,
`main.gd:31-32`, `CAPITAL_LIFT 12.0` em `:34`) e os blocos andam a velocidade instantânea, sem
taxa de giro (`MARCHA_DE_BLOCO 6.0 × mobilidade`, `esquadra.gd:109/381`). Cascos pesados hoje só
têm fator de classe na velocidade (`CLASSES`, `main.gd:102-106`), não em aceleração nem em giro,
e `hp`/`engines`/`weapons`/`crew` nascem todos em 100 (`main.gd:1601/1609`).

Desenho: estado de voo por unidade = `vel` + `rumo` + `giro`, com `aceleracao` e
`giro_maximo` por classe (pesada: ambos menores), e `velocidade_lateral < velocidade_avante`
com ré ainda menor. `CLASSES` ganha os três campos e para de ser só fator multiplicativo.
Custo: `movimento_tomado` vira integração em vez de `move_toward`, e isso move as asserções de
"formação custa tempo de locomoção" e o tempo de cada salva. Teste: A/B de tempo até o destino
por classe, giro limitado (nada de rotar 180° em um quadro), e a ré medindo menos que a proa.

## 4. Fatia 3 — escudo com durabilidade

Não existe nenhuma camada além de `hp` no jogo (zero ocorrência de `shield`/`escudo`/`armadura`
como estado; a palavra só aparece em prosa de README). Desenho: `escudo` + `escudo_max` por
casco, agregado por bloco; o dano morde o escudo primeiro, o escudo **não conserta** no mesmo
ritmo do casco e tem colapso com janela de vulnerabilidade; a regeneração é constante declarada,
não sorteio (lei da casa). Sem escudo o bloco não muda de líder nem de doutrina. Custo: toda a
aritmética de `_dano_de_canhao` (`main.gd:3826`), `DANO_DE_BLOCO 2.2` (`esquadra.gd:113`) e as
rampas de setor; e as luminâncias dos quadros de casco podem mudar de novo.

## 5. Fatia 4 — fogo por coluna, fogo amigo, alcance 3D

Escolhido: só o bloco mais adiantado de cada coluna dispara, os demais ficam obstruídos, e o que
passa bate no aliado atrás. Isso inverte uma cláusula escrita no comentário de
`_pontos_de_impacto` (`main.gd:3765-3781`, «ignora o y de quem atira») e no README, e cobra a
reescrita honesta das duas coisas. Bloco e casa têm posição conhecida, então obstrução é teste
de segmento contra a caixa do bloco — geometria decide, nenhum sorteio é chamado aqui (mesma lei
da salva atual). Chegada por cima e por baixo e grupo vindo de outro canto entram aqui como
**origem do tiro**, não como IA nova.

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
- Nada de moldura duplicando a arte da cena; nada de emoji no código; comentários ASCII nos `.gd`.
