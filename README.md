# Iron Stars: Fleet Command

Protótipo em Godot 4.7.2. Jogo original de estratégia espacial em tempo real, com pausa tática e comando a partir da ponte da capitânia.

## Princípio central
A batalha nunca espera o jogador. Naves aliadas e inimigas detectam, manobram, atacam e sofrem danos continuamente. As ordens do comandante organizam e priorizam o comportamento da frota; não são turnos nem ações que congelam o combate. A pausa tática é opcional para dar tempo de analisar e emitir ordens.

## Especificação das mecânicas do protótipo

### Seleção de unidades
- Comandar a frota inteira.
- Comandar esquadrões/grupos.
- Selecionar naves específicas quando necessário.
- Uma ordem afeta somente a seleção atual, exceto quando o jogador seleciona explicitamente a frota inteira.

### Ordens essenciais
- Movimentar até uma posição.
- Atacar um alvo ou um subsistema específico.
- Manter posição e alterar formação.
- Recuar/fugir.
- Escoltar e proteger a capitânia ou outra unidade.
- Abordar e capturar naves inimigas neutralizadas/danificadas. A abordagem exige aproximação e casco do alvo em 55% ou menos; ao cair a tripulação inimiga, a nave deixa de ser hostil e entra na frota como unidade controlável (esquadrão PRESA), com armamentos zerados que a própria tripulação de reparo devolve.
- Manter naves em reserva tática.
- Reconhecimento e lançamento de sondas.

### Danos e reparos
- O combate e os danos são resolvidos automaticamente em tempo real.
- Casco, motores, armamentos e tripulação têm estados separados.
- Danos a motores reduzem mobilidade; danos às armas reduzem poder de fogo.
- Equipes de reparo trabalham automaticamente.
- O comandante define prioridade de reparo; sem prioridade explícita, a tripulação usa uma política automática equilibrada.

### IA e combate
- Naves aliadas e hostis continuam lutando sem ordens.
- Ordens mudam a seleção de alvos, movimento, formação e exposição ao risco.
- A IA inimiga deve avaliar condições, atacar alvos vulneráveis, proteger unidades importantes e recuar quando estiver em risco. Primeira forma entregue: a cada salva a frota hostil lê a força relativa das duas linhas e escolhe postura — `AVANÇAR` com forças equilibradas, `RECUAR` quando vale menos de 42% da força total do tabuleiro, `ESCOLTA` quando a própria capitânia cai abaixo de 60% de casco, e debandada quando a capitânia deixa de existir. Na escolta, os dois cascos mais próximos assumem postos alternados (-3 / +3) na frente da capitânia enquanto o grosso se recolhe. O fogo hostil cai inteiro sobre um único casco aliado, escolhido por casco baixo e armamento pesado, e a unidade em reserva tática não é lida como alvo. Toda a decisão é uma função pura sobre o estado: ela não consome sorteio e não mexe em casco, motores, armas nem tripulação.
- A linha hostil manobra dentro de um campo de batalha limitado: avanço para na linha de engajamento (z = -60) e a retirada tem fundo na linha de reunião (z = -92), de modo que o combate continua à vista da ponte em vez de migrar para fora do mapa.
- Reconhecimento deve melhorar a informação tática disponível; abordagem deve exigir aproximação e um alvo vulnerável. Entregue: `RECONHECER` lança uma sonda tática visível por casco vivo da seleção (teto de uma por casco — lançar de novo sobre uma varredura em curso não empilha) e a sonda atravessa o tabuleiro com o próprio corpo, indo até o fundo de varredura (z = -104) e voltando à base (z = -34) a 16 unidades por segundo, com vida de 30 s. Um casco é confirmado quando a sonda encosta nele: o raio de 9 unidades, curto de propósito, faz uma sonda solitária cobrir o próprio corredor e no máximo um vizinho, então cobertura total exige varredura de verdade. A cobertura deixou de ser cronômetro: `RECONHECIMENTO` agora é a fração de cascos vistos (`100 * contatos / cascos hostis vivos`), e o seletor de alvo mostra `CASCO n%` só de quem foi varrido — o resto continua `NÃO IDENTIFICADO`. O destroço sai do numerador e do denominador ao mesmo tempo, o conhecimento não some quando a sonda expira nem quando o lançador morre, e a varredura não move número nenhum: o corpo da sonda anda por constantes, sem sorteio, e a corrida A/B mede dano e estado do `RandomNumberGenerator` idênticos com e sem sondas no ar.
- O comandante lê a decisão da IA: o painel da ponte mostra a postura hostil, a força relativa e o casco sob fogo concentrado, e o relatório só fala quando a postura muda.

## Controles
- **W / S**: aumentar / reduzir velocidade da capitânia.
- **A / D**: girar a capitânia.
- **ESPAÇO**: pausa tática / retomar.
- **Painel esquerdo**: selecionar frota, esquadrões ou nave, selecionar alvo/subsistema e emitir ordens.

## Estado atual e limites
O projeto usa geometria procedural provisória. É um protótipo mecânico, não uma versão final. Já há seleção da frota/esquadrões/naves, ordens de movimento, ataque por subsistema, escolta, reserva, reconhecimento com sondas táticas visíveis no tabuleiro, prioridades de reparo, captura por abordagem com a presa incorporada como unidade controlável e uma IA hostil que escolhe postura a cada salva em vez de avançar sempre igual. Essas mecânicas são simplificações iniciais e ainda precisam de testes de equilíbrio e de interface. A IA tática avançou para a primeira forma (postura, escolta da capitânia, fogo concentrado), mas ainda não tem contramedidas: ela não reage a formação, não disputa um ponto do mapa nem arma emboscada. O reconhecimento ainda é leitura de ponte, não trava de fogo: um casco não varrido continua atacável, e a varredura só muda o que a ponte mostra. Campanha, áudio e arte final continuam pendentes.

O tamanho da frota não é mais fixo: os seletores de unidade, alvo e escolta e o HUD são reconstruídos a partir das listas reais quando uma presa é incorporada, e a batalha só termina depois que a incorporação retira o casco da lista de hostis.

## Validação
Cada mudança mecânica é provada por uma sonda headless antes do commit:

```
godot --headless --path . --quit-after 1800 -s res://tools/probes/sondas.gd
godot --headless --path . --quit-after 1800 -s res://tools/probes/tatica.gd
godot --headless --path . --quit-after 1800 -s res://tools/probes/captura.gd
```

`tools/probes/sondas.gd` confere 39 pontos da varredura — a ponte abre com 0 sonda no ar, denominador `0/6` e nenhum casco identificado (a conta é feita antes da primeira UI, não deixada em zero velho), `RECONHECER` lança exatamente uma sonda por casco vivo e o nó dela está na cena com corpo e anel, o segundo clique recusa sem empilhar, a sonda anda (z -41 → -57), fecha para o próprio corredor (Δx 2,50 → 1,87), fica dentro do mapa e conta a vida (29,0 dos 30). Uma sonda solitária confirma 2 de 6 (33,3% = fração exata de contatos) e o casco do outro lado da linha (x 3,0 contra corredor -15,0, raio 9,0) continua escuro; a frota inteira lança as 6 sondas e fecha 6/6 em 3 quadros. O destroço sai do numerador e do denominador juntos (5/5, nunca 6/5), o casco morto conserva a marca, a sonda sobrevive à morte de quem a lançou, a expiração tira as 6 do ar sem mover um contato, e `enemies` vazio dá `0/0` e 0% sem crash. A prova central é a corrida A/B: dois jogos na mesma semente e no mesmo tabuleiro alinhado, um com as 6 sondas e outro sem nenhuma, oito ciclos de movimento mais salva — casco somado 1023,5 dos dois lados e o estado do `RandomNumberGenerator` idêntico (`-3305389947420086964` nos dois), com a guarda de que a medição não foi feita em tabuleiro vazio. O contrato do HUD continua em cinco linhas, com a linha 3 lendo sondas e contatos. Veredito da última rodada: `quebras=0 • conferências=39`.

`tools/probes/tatica.gd` confere 40 pontos da leitura tática — paridade de forças continua em `AVANÇAR` (razão medida 0.500), capitânia ferida produz `ESCOLTA` com exatamente dois cascos em postos alternados (-3 / +3) que fecham de ≈17 para ≈5 unidades até o próprio posto, três cascos a menos derrubam a razão para 0.333 (hostil 300 contra aliado 600) e a postura para `RECUAR`, a capitânia perdida produz debandada, a reserva tática escapa da seleção de alvo, uma salva hostil inteira cai sobre um único casco (foco 0, uma aliada atingida), o avanço para em z = -60 e a retirada em z = -92, e o destroço conserva a última ordem mas não se move um centímetro. A distância exata da escolta varia de rodada porque o `spawn` ainda usa `rng.randomize()` antes de a sonda fixar a semente; a asserção é direcional (fechar distância), não um valor gravado. As duas asserções de pureza medem o estado do `RandomNumberGenerator` antes e depois de avaliar e aplicar: intacto, a IA não sorteia nada. Veredito da última rodada: `quebras=0 • conferências=40`.

`tools/probes/captura.gd` confere 23 pontos do ciclo de captura — o alvo abordado sai de `enemies` e entra em `fleet` como PRESA mantendo o mesmo nó da cena, obedece a uma ordem dada só ao seu esquadrão sem contaminar o ALFA, sai do fogo hostil, tem os armamentos devolvidos pelo reparo automático, e os três seletores e o HUD passam a contar `7/7` e depois `12` naves quando a batalha inteira termina por captura. Re-rodada depois da IA e das sondas: `quebras=0 • conferências=23`, sem regressão.

Jogo real sem sonda, `--quit-after 1200`: nenhuma linha de `ERROR`, nenhum vazamento de recurso no encerramento.

O protótipo ainda não grava progresso em disco, então as sondas não têm save a corromper; mesmo assim rodam com `APPDATA` apontando para um diretório descartável (`D:/Downloads/tmp-userdata`), que é onde aparece o `app_userdata/Iron Stars- Fleet Command` de teste.
