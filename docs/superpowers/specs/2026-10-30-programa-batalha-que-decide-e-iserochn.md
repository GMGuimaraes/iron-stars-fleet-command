# Programa «batalha que decide + Fortaleza Iserlohn» — três fatias numa mesa só

**Data:** 2026-10-30. **Estado da árvore:** `main`, lapidação 4 em execução (Tarefa 4 voando, Tarefas
5 a 10 na fila). Este documento **não é spec de implementação** e não toca nenhum `.gd`: é a
decomposição que a regra da casa exige antes de uma spec, porque o pedido abaixo são três sub-projetos
com fronteiras, portões e decisões próprios. Cada um vai gerar `spec → aprovação do commander →
plano → execução`, na ordem deste documento.

## 0. O pedido, nas palavras do commander

> «o jogo esta bom, agora quero ver a destruição acontecendo, as tropas se desgastando aos poucos e a
> IA tomando decisões de formas independentes, tropas que estão vencendo avançando sobre tropas que
> estão perdendo, ver a fila de naves ficando com pontos mais fracos que poderão ser explorados
> estrategicamente, etc. Também corrija a colizão com o planeta do mapa, podendo afastalo, torne esse
> planeta a fortalesa iserlon, que deve possuir artilharia contra as naves também, e um canhão de
> energia poderoso que afeta tropas aliadas e inimigas, devendo ser usado com cuidado»

Escolha de fila já feita pelo commander nesta rodada: **«Terminar a 4, projetar a 5 já»** e **«os três,
num programa só»**.

## 1. O que já está a caminho, e por isso não é pedido novo

A lapidação 4 entrega, antes desta fatia nova começar, duas das quatro coisas acima:

- **Ponto fraco na fileira** — Tarefa 5 (`FATOR_DE_VAGA`, `postos_efetivos`, `_vaga_para`,
  `_espaco_aberto`): peça só avança para vaga, e a fileira morta abre buraco visível na muralha.
- **Desgaste que come corpo** — Tarefa 7 (`abater_peca`, «o poço come a peça»): 24 → 20 → 16 casas
  vivas, com o ledger de casas e a pintura seguindo.
- **A colisão do planeta medindo a muralha** — Tarefa 8 abre exatamente `main.gd`
  `_chocar_com_barreiras` e `_cobrar_contato`, mais `_aplicar_cenario`, `_empurrar_no_vento` e
  `_queimar_na_corona`. **Nenhuma fatia nova pode tocar essas duas funções antes do push da
  lapidação 4**, sob pena de dois escritores no mesmo corpo.

O que **não** está em lugar nenhum: autonomia de decisão por sub-bloco, canhão de recarga, artilharia
da fortaleza, e o ritmo de afundamento da linha.

## 2. Diagnóstico medido do «não vejo destruição» (não é lei faltando, é aritmética)

A lei do afundamento existe e está certa: `_golpe_na_casa` e `_aplicar_golpe` baixam
`bloco["vivo"] = false` quando `navios` chega a zero, e `troca_salva` já conta `afundados` no retorno.
Logo, «0 de 120 blocos afundam» não é um buraco de código — é o preço por lance contra a vida por casa.

Constantes lidas agora em `esquadra.gd` (`NAVIOS_NO_BLOCO` :125, `DANO_DE_BLOCO` :209,
`VIDA_DA_CASA` :218, `PLACA_DA_CASA` :222 com `Escudo.ESCUDO_DE_BLOCO` = 4,4 em `escudo.gd`:57,
`TIRO_DE_CASA` :224) e `CASAS` = 4×3×2 = 24 (`esquadra.gd`:50 e :53):

| Grandeza | Valor | Como se obtém |
|---|---|---|
| vida de uma casa | 4,1667 | `NAVIOS_NO_BLOCO` 100 ÷ `CASAS` 24 |
| placa de uma casa | 0,1833 | 4,4 ÷ 24 |
| dano de um lance na casa | 0,091667 | 2,2 ÷ 24 |
| **lances para apagar uma casa** | **≈ 47,5** | (4,1667 + 0,1833) ÷ 0,091667 |
| **lances para afundar um bloco** | **≈ 1 139** | 24 × 47,4545 (o valor exato da linha acima, sem o arredondamento) |

*Esta última linha é conta sobre as constantes, não medição: a placa é cobrada por
`Escudo.morder`, que pode morder de forma não-linear, e é a sonda da fatia A que devolve o valor real.
O que a conta autoriza a afirmar é a ordem de grandeza — três ordens acima do que o trecho medido
entrega.*

E o que a partida inteira realmente entrega, lido do log da última bateria
(`bateria/batalha_real.log`, linhas 3–13 — **não re-rodado nesta sessão**): 123 salvas em 200 s,
maior salva 1 440 lances, **360 casas mortas de 2 880 por lado**, `120/120 blocos` dos dois lados,
`navios` 10 479c contra 10 487c. Três casas apagadas por bloco, quando o bloco pede vinte e quatro no
mesmo corpo.

Os dois gargalos que essa conta nomeia, e que a **Fatia A** tem de medir em vez de supor:

1. **Fogo raso demais.** A lei de coluna (bolha de `obstruidos`, descrita no doc-comment de
   `troca_salva` em `esquadra.gd:1374-1378`, corpo em :1385) silencia três de cada quatro
   fileiras: o log mostra `pares=60` por salva, não 120. Só a frente da coluna tem boca limpa.
2. **Dano que se espalha e não converge.** Sem casa indicada o golpe é «repartido igualmente pelas
   vivas» (`_aplicar_golpe`, comentário em `esquadra.gd:1597-1599`), então os blocos descem juntos e
   nenhum chega a zero antes do fim do trecho.

Consequência honesta: afundar bloco é **decisão de saldo do commander**, escrita no spec de 2026-10-23
e no README, e nunca puxada. A Fatia A não «conserta» isso sozinha — ela mede, oferece a alavanca com
número, e o número escolhido é do commander.

## 3. As três fatias

### Fatia A — Desgaste e ponto fraco explorável
**O que é:** a muralha queimando de verdade, com um bloco afundando em campo e a linha ficando com
vãos que se veem e se exploram.
**Fronteira:** `esquadra.gd` (`DANO_DE_BLOCO` e vizinhas :209-224, `troca_salva`, `_aplicar_golpe`,
`_casas_por_proximidade`); o ledger por casa já existe e não muda de forma. **Não** toca
`_cobrar_contato`/`_chocar_com_barreiras` (são da T8 da lapidação 4) e **não** toca cena/`MultiMesh`.
**Consome da 4:** peça como unidade de dano (T7) e vaga-livre (T5) — sem isso, «ponto fraco» não tem
geometria onde morar.
**Portão:** `tools/probes/batalha_real.gd` re-medido com a asserção invertida — hoje ela **confessa**
`0 de 120`; a fatia A tem de devolver `afundados > 0` em 200 s sem quebrar as famílias 11-15, e o
README/spec varridos no mesmo commit (`godot-readme-number-sweep`).
**Decisão que fica com o commander:** quanto de afundamento por trecho de 200 s é «bom de ver» — a
escolha entre mexer em `DANO_DE_BLOCO`, em quantos pares engajam por salva, ou em convergir fogo no
corpo já ralado.

### Fatia C — Fortaleza Iserlohn (o planeta do mapa)
**O que é:** o planeta que já está no mapa (`SISTEMA_POS` (0, 22, −64) em `main.gd`:281,
`SISTEMA_PLANETA_RAIO` 15,0 em :282, montado por `_montar_sistema` `main.gd`:3392-3404 como astro de
velocidade zero na lista `astros`) vira fortaleza: artilharia que atira nas naves dos dois lados e um
canhão de energia de recarga, caro de usar porque fere aliado junto.
**Colisão — causa já achada, camada certa nomeada:** a lei está escrita e é razoável
(`_cobrar_contato` `main.gd`:3884-3922 empurra pelo normal e cobra abalroamento acima de `RAM_SPEED`
3,0). O defeito é o **objeto medido**: `_collision_bodies()` (`main.gd`:4186-4202) devolve só `fleet`,
`enemies` e `bridge_rig` — os 240 blocos da muralha (120 por lado) não são corpo de colisão com nada.
É a mesma falha de camada do poço da lapidação 4: *a cena mede o objeto velho.* A Tarefa 8 corrige a
grade do contato; esta fatia corrige o **que** existe depois do contato (empurrar para longe de verdade, sem grudar nem
atravessar) e o que a fortaleza cobra de quem encosta.
**Armas novas:** canhão de recarga e artilharia de planeta são emissores novos no ledger de salvas —
entram pela porta do `troca_salva` e pela lei de fogo amigo real já cravada no programa (fatia 4), não
por um caminho paralelo de dano.
**Portão:** sonda nova de fortaleza (família de recarga, família de fogo amigo, família de alcance) +
`fotograma`/`massa_visivel` em janela com PNG relido — aprovação de *aspecto* é do commander.
**Ambiguidade que trava o design, e é a primeira pergunta da spec:** «podendo afastá-lo» — (i) o
planeta/fortaleza **empurra** as naves para fora do casco (repulsão, sem grudar), (ii) o corpo do
planeta pode ser **deslocado** no tabuleiro, ou (iii) a frota pode **se afastar** do planeta por ordem
do comandante. São três leis diferentes e a spec não pode escolher no lugar do commander.

### Fatia B — Autonomia e iniciativa (IA que decide)
**O que é:** «a IA tomando decisões de forma independente» e «tropas que estão vencendo avançando
sobre tropas que estão perdendo».
**Estado real, medido:** IA hostil **já existe e já escolhe postura a cada salva** — a leitura dela
mora no doc-comment do estado `hostile_posture` (`main.gd`:829), a densidade de fogo vem da postura
(`main.gd`:5055)
e o painel anuncia a mudança (`README.md`:52). Mas ela decide sobre as **doze cascos velhos** — o
`fleet`/`enemies` dentro de `_update_fleet` (`main.gd:4130-4170`, corpo de :4051 a :4185, com
`HOSTILE_ADVANCE_Z`) — não sobre a muralha de blocos nem sobre peças. A fila atrasada do programa
tem nome e está aberta: **#165** «doutrina e capitânia por esquadrão» — que é §6 da spec de 2026-10-23
(`:574-582`: cada esquadrão com `postura` própria, dano a bloco podendo atingir a capitânia do
esquadrão) — e **#166** «escolta e perseguição hostis».
**Dependência declarada, não descoberta depois:** a IA precisa do modelo de desgaste da Fatia A como
substrato — decisão autônoma sem noção de «quem está perdendo» só decide *para onde*, não *a quem*.
Foi assim que a fila ②→③ do programa de 2026-10-23 foi arbitrada, e vale igual aqui.
**Fronteira:** `esquadra.gd` (estado de doutrina por esquadrão, leitura de força relativa por peça) e
os servos de eixo de `main.gd` (escolta, reserva, perseguição) estendidos à granularidade nova. Sem
entrada de painel nova além das que a doutrina exigir, porque a cadeia de comando do commander é
**ordem no bloco, decisão na peça**.
**Portão:** sonda de estratégia por partida (RNG da casa proibido em lei de desenho: postura tem de
vir de estado medido, não de sorteio) + `batalha_real` mostrando avanço desigual entre lados.

## 4. Ordem proposta, e o porquê em uma linha cada

1. **A — desgaste.** É o que o commander pediu primeiro na frase, é aritmética medível hoje, e é o
   substrato de B.
2. **C — Iserlohn.** Não depende de A; depende só da T8 da lapidação 4 ter fechado o contato com a
   muralha. É o mais visível e o mais delimitado.
3. **B — autonomia.** Começa depois de A, porque cada decisão nova tem de ter um estado de desgaste
   para ler.

## 5. Constraints herdadas, que não se renegociam aqui

`main` only, sem branch nem worktree; nunca `git add -A`/`.`/`stash`, stage por nome exato e `git
status --short` provado antes e depois; nunca commitar `_tmp_pista_fria.gd*`, `.godot/`, `.manus/` ou
churn puro de CRLF em `.import`; nunca escrever `.gd.uid` na mão; `APPDATA="D:\\Downloads\\tmp-userdata-iron"`
em todo comando de motor; rodadores de bateria fora do repo; portão nunca afrouxado — premissa nova se
declara **no criador do estado**; número publicado é contrato (README e spec re-varridos no mesmo
commit); custo contado em operações, nunca em `ms`; aprovação de *aspecto* e *ritmo* é do commander,
porque headless não pinta; implementador nunca despacha subagente; commit novo, nunca `--amend`; push
só no fechamento da fatia.

## 6. O que este documento **não** decide

Nenhum número de saldo, nenhuma tolerância, nenhuma forma de fortaleza. As três perguntas de escopo
que cada spec responde na primeira seção: a alavanca de afundamento escolhida (A), o sentido de
«afastar» (C), e o que «vencer» quer dizer em estado legível pela IA (B).
