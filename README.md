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
- Abordar e capturar naves inimigas neutralizadas/danificadas.
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
- A IA inimiga deve avaliar condições, atacar alvos vulneráveis, proteger unidades importantes e recuar quando estiver em risco.
- Reconhecimento deve melhorar a informação tática disponível; abordagem deve exigir aproximação e um alvo vulnerável.

## Controles
- **W / S**: aumentar / reduzir velocidade da capitânia.
- **A / D**: girar a capitânia.
- **ESPAÇO**: pausa tática / retomar.
- **Painel esquerdo**: selecionar frota, esquadrões ou nave, selecionar alvo/subsistema e emitir ordens.

## Estado atual e limites
O projeto usa geometria procedural provisória. É um protótipo mecânico, não uma versão final. Já há seleção da frota/esquadrões/naves, ordens de movimento, ataque por subsistema, escolta, reserva, reconhecimento, prioridades de reparo e uma primeira captura por abordagem. Essas mecânicas são simplificações iniciais e ainda precisam de testes de equilíbrio e de interface. A IA tática avançada, a integração das naves capturadas como unidades controláveis, sondas visíveis, campanha, áudio e arte final continuam pendentes.
