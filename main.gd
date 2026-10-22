extends Node3D

const BLUE := Color(0.12, 0.72, 1.0)
const RED := Color(1.0, 0.22, 0.18)
const GOLD := Color(1.0, 0.72, 0.28)
## A frota hostil avança até esta linha e para: engajamento à vista da ponte, não
## atravesso do tabuleiro.
const HOSTILE_ADVANCE_Z := -60.0
## Recuo tem fundo: na linha de reunião a esquadra se reorganiza em vez de sair do mapa.
const HOSTILE_RALLY_Z := -92.0
## Fundo da varredura: a sonda vai além do último casco hostil e volta, em vez de sumir para
## fora do campo de visão da ponte.
const PROBE_FAR_Z := -104.0
## Base da varredura, logo à frente da linha aliada: é para onde a sonda retorna.
const PROBE_NEAR_Z := -34.0
const PROBE_SPEED := 16.0
const PROBE_LIFE := 30.0
## Raio curto de propósito: com a linha hostil espaçada em 6 unidades, uma sonda confirma o
## próprio corredor e, no máximo, um vizinho. Cobertura total exige varredura de verdade.
const PROBE_SCAN_RADIUS := 9.0
## ---- Navegação e casco físico ----
## Campo grande de propósito: a capitânia precisa de mar para manobrar, e o cenário ocupa volume
## em vez de um plano. O limite é o que impede a frota de fugir do quadro em vez de resolver a
## batalha.
const MAP_X := 320.0
const MAP_Y := 180.0
const MAP_Z_NEAR := 40.0
const MAP_Z_FAR := -600.0
## Nó de casco em throttle cheio. Ré tem teto próprio porque cruzador não manobra de costas como
## rebocador: 60% do avanço, e ainda assim mais rápido que o motor de busca de um alvo.
const CAPITAL_SPEED := 22.0
const CAPITAL_REVERSE := -0.6
## Empuxo vetorial: subir e descer sem mudar a atitude do casco.
const CAPITAL_LIFT := 12.0
## Atitude limitada: sem teto de arfagem a ponte gira em parafuso e a mesa holográfica, que é
## filha do rig, perde o horizonte que o comandante usa para ler o quadro.
const PITCH_LIMIT := 0.62
const ROLL_LIMIT := 0.5
## Timão lido pelo InputMap, não por tecla votada. `Input.is_key_pressed` devolve o estado que
## só uma janela real preenche — em headless ele fica frio, e o jogador num layout AZERTY não
## manobra com W de jeito nenhum. Cada ação recebe DOIS eventos: o código digitado e a posição
## física do teclado, que é o que falta no build web (navegador nem sempre reporta o físico).
const VOO_ACOES := {
	"capital_avante": KEY_W,
	"capital_re": KEY_S,
	"capital_bombordo": KEY_A,
	"capital_estibordo": KEY_D,
	"capital_nariz_acima": KEY_UP,
	"capital_nariz_abaixo": KEY_DOWN,
	"capital_role_esquerda": KEY_Q,
	"capital_role_direita": KEY_E,
	"capital_empuxo_acima": KEY_R,
	"capital_empuxo_abaixo": KEY_V,
}
## Raio de manobra do casco: é perfil de tráfego, não a pintura (o billete mede ~4 unidades de
## boca). Com 2,4 dois postos precisam estar a 4,8 de distância, e é por isso que o passo de
## formação é 5,5 — posto mais fechado que isso colide antes de obedecer.
const HULL_RADIUS := 2.4
## Passo lateral de qualquer posto de formação: tem de ficar acima de 2 * HULL_RADIUS, senão a
## própria formação dispara o abalroamento que ela deveria evitar.
const FORMATION_STEP := 5.5
## Raio do anel de agrupamento: é o passo de formação, não um número menor. Agrupar o mais
## fechado que a física permite ainda deixa corda de 5,5 entre vizinhos — abaixo disso a ordem
## de "fechar" produziria um abalroamento em cadeia.
const AGRUPAR_RAIO := 5.5
## Dispersar abre para três vezes o passo: o suficiente para um lance concentrado não cobrir dois
## cascos de uma vez, sem espalhar a força para fora do alcance da própria salva.
const DISPERSAR_RAIO := 16.5
const CAPITAL_RADIUS := 6.0
## ---- Salva em área (a "chuva de flechas") ----
## Um navio que atira não manda um raio único contra um casco: manda uma salva de impactos
## espalhados sobre um disco perpendicular à linha de tiro. O disco é o setor, não o navio, e é
## por isso que a densidade de fogo é ordem de ponte e não ajuste de cada capitão.
const FLECHAS_POR_SALVA := 3
## Os três degraus de raio do disco, em metros de tabuleiro. A 4,5 u os três impactos caem todos
## dentro do alcance letal do mesmo casco (fogo concentrado); a 28 u só o impacto do centro está
## garantido e os outros dois varrem o tabuleiro — acasam outro casco ou caem no vazio.
const FOGO_RAIO := [4.5, 14.0, 28.0]
const FOGO_NOME := ["CONCENTRADO", "SETOR", "DISPERSO"]
## Alcance letal além do raio do casco: um impacto a até HULL_RADIUS + FOGO_LETAL do centro do
## casco é absorvido por ele. Abaixo disso a salva dispersa teria vãos de verdade.
const FOGO_LETAL := 3.2
## Abalroamento: abaixo desta velocidade de aproximação os cascos apenas se empurram.
const RAM_SPEED := 3.0
const RAM_DAMAGE := 1.9
const RAM_MAX_DAMAGE := 18.0
## Um par cobra um golpe por janela, não um por quadro: sem isto dois cascos encostados
## perderiam a tripulação inteira em dois segundos de contato.
const RAM_WINDOW := 1.5

## ---- Mesa holográfica ----
## Escala isótropa, ancorada no meio do campo de ação (entre as duas linhas). Uma mesa que
## alonga um eixo mente sobre distância, e é com ela que o comandante decide onde mandar a frota.
const HOLO_SCALE := 0.075
const HOLO_ANCHOR_Z := -60.0
## O disco tem borda: quem está fora da janela tática encosta no aro em vez de sumir da mesa.
const HOLO_RIM := 2.85
## Altitude é a única dimensão ampliada de propósito: na escala verdadeira o blip subiria 0,15
## e ninguém leria nada. 0,09 por unidade com teto lê a subida sem quebrar a planta.
const HOLO_ALT_SCALE := 0.09
const HOLO_ALT_CEIL := 0.8

## ---- Cenários: o obstáculo que se usa, não a decoração que se passa por cima ----
## Os três cenários são escolhas do comandante no painel, e o contrato deles é o mesmo: nenhum
## número se move com o campo aberto (o cenário padrão), cada um cobra um preço próprio e esse
## preço é conferível em geometria, não em sorteio. Nada aqui usa `rng`; o que muda a conta é a
## posição que o jogador escolheu ocupar.
const CENARIOS := ["ABERTO", "CINTURAO", "POCO", "ESTRELA"]
## Cinturão: rochas entre as duas linhas, em banda determinística. Determinística de propósito —
## se o cinturão saísse do `visual_rng`, cada partida mudaria o mapa e a sonda não teria com que
## conferir a barreira.
const ROCHA_QTDE := 14
## Raio de casco da rocha: entra na mesma conta de separação dos cascos, então uma fragata encosta
## e não atravessa.
const ROCHA_RAIO_BASE := 3.2
const ROCHA_RAIO_DEGRAU := 0.9
## Espalhado em leque: x varre a frente, z abre da linha aliada até a hostil, y dá volume ao
## cinturão (barreira em três eixos, não uma parede desenhada no plano).
const ROCHA_LEQUE_X := 58.0
const ROCHA_Z_INICIAL := -24.0
const ROCHA_Z_PASSO := 4.0
const ROCHA_Y_LEQUE := 13.0
## Deriva: o cinturão é correnteza, não parede. Cada pedra nasce com velocidade própria e sofre um
## empuxo senoidal lento, que a faz errar de rumo; no encontro com outra pedra ou com a borda da
## banda, o rumo muda de fato. Tudo é conta de índice e relógio, nunca sorteio: a sonda tem de
## conseguir prever a posição de cada pedra quadro a quadro sem rerrolar a partida, e uma pedra
## sorteada mudaria a cauda de `rng` de toda a batalha seguinte.
const ROCHA_DERIVA := 2.4
const ROCHA_ERRATICIDADE := 0.9
const ROCHA_TAXA_ERRATICA := 0.35
## Teto de velocidade: sem ele o empuxo acumulado transformaria o cinturão em cometas e a barreira
## deixaria de ser lida como obstáculo para virar borrão.
const ROCHA_VETO_TETO := 4.2
const ROCHA_GIRO := 0.22
## Banda do cinturão: o muro onde a pedra bate e volta. É a banda de batalha, não o campo inteiro —
## pedra que atravessa o mapa inteiro não é mais barreira, é cenário que se dissolve.
const ROCHA_BANDA_X := 78.0
const ROCHA_BANDA_Y := 18.0
const ROCHA_BANDA_Z_FRENTE := -16.0
const ROCHA_BANDA_Z_FUNDO := -84.0
## Fratura: o lance que a pedra absorve cobra integridade dela, e integridade zero racha a pedra em
## duas filhas de raio reduzido. Pedra miúda, geração velha ou tabuleiro cheio esmúça em vez de
## rachar — sem o teto, uma salva bem colocada faria o cinturão crescer até o laço pedra-a-pedra
## custar o quadro. É isso que tira o asteroide da categoria "parede infinita".
const ROCHA_INTEGRIDADE_POR_RAIO := 6.0
const ROCHA_FILHA_FRAC := 0.62
const ROCHA_FILHA_MIN := 1.6
const ROCHA_GERACAO_MAXIMA := 2
const ROCHA_LIMITE_CORPOS := 40
## Poço gravitacional: alcance é onde o puxo começa a ser sentido; horizonte é onde a nave já é
## perdida — não há motor do protótipo que saia de lá.
const POCO_POS := Vector3(0.0, 0.0, -78.0)
const POCO_ALCANCE := 46.0
const POCO_PUXO := 11.0
const POCO_HORIZONTE := 9.0
## Lente de Gargantua: o buraco negro do Interstellar não é um donut visto de cima. É uma sombra
## redonda com um fio de luz colado na borda, um disco fino atravessando o meio, e a imagem do lado
## de lá dobrada por CIMA e por BAIXO da sombra. Nada aqui mexe em casco, dano ou sorteio: os três
## números que mandam no poço (`POCO_ALCANCE`, `POCO_PUXO`, `POCO_HORIZONTE`) ficam exatamente como
## a sonda `tools/probes/cenarios.gd` já confere.
## Raios em unidades de horizonte — é assim que a sombra e o aro ficam sempre proporcionais.
const POCO_ANEL_FOTON := 1.08
const POCO_DISCO_INTERNO := 1.55
const POCO_DISCO_EXTERNO := 3.80
const POCO_DISCO_FAIXAS := 3
const POCO_DISCO_AMOSTRAS := 44
## Sem inclinação o disco é visto de gume puro e não aparece um pixel. 0,17 rad bastam para ler a
## face de cima sem quebrar o perfil fino da imagem.
const POCO_DISCO_INCLINACAO := 0.17
## O arco lentificado é uma elipse no plano do quadro: larga como o disco, alta como 1,24 sombra.
const POCO_ARCO_ALTO := 1.24
const POCO_ARCO_BAIXO := 1.06
const POCO_ARCO_AMOSTRAS := 40
const POCO_ARCO_LARGO := 3.10
## Feixe relativístico: o lado que vem para nós chega mais claro. 1 ± 0,45 sobre o ângulo, contado
## do índice da amostra — deterministicamente, sem um sorteio.
const POCO_DOPPLER := 0.45
## Lente sobre o céu de fundo. `POCO_LENTE_EINSTEIN` é o raio de Einstein em radianos de separação
## aparente; uma estrela a `sep` do centro aparenta estar a `sep + E²/sep`, tocado em 2E. O efeito
## é uma zona escura de 2E e um amontoado luminoso logo fora — é isso que olhos humanos leem como
## "aquilo dobrou o céu".
const POCO_LENTE_EINSTEIN := 0.16
const POCO_LENTE_FLEXAO_TETO := 2.0
const POCO_LENTE_BANDA := 3.0
## Margem do anel de acúmulo: nenhuma estrela termina antes de `2E * POCO_LENTE_ANEL`. O mínimo
## analítico de `sep + E²/sep` é exatamente 2E (em `sep = E`), e um miolo que encosta na borda por
## 1e-9 não é preto — a margem é o que separa um céu varrido de um empate de vírgula flutuante.
const POCO_LENTE_ANEL := 1.02
## Estrela ativa: dentro do raio de calor as armas disparam mais quentes (o dano sobe), dentro da
## corona o casco cozinha. É a única mecânica do slice que mexe em dano de salva, e mexe por
## posição, não por sorteio.
const ESTRELA_POS := Vector3(0.0, 24.0, -74.0)
const ESTRELA_CALOR_RAIO := 70.0
const ESTRELA_CALOR_FATOR := 1.25
const ESTRELA_CORONA_RAIO := 30.0
const ESTRELA_QUEIMA_POR_SEGUNDO := 6.0
## Vento solar: um empurrão para fora, posicional, com a mesma régua de peso do poço. Alcance maior
## que o do calor porque o vento não cozinha, só desvia.
const ESTRELA_VENTO_ALCANCE := 96.0
const ESTRELA_VENTO_ACEL := 3.0
## Radiação: não fere casco e não move número de combate — ela cega a varredura da sonda dentro
## deste raio, multiplicando o raio de scan que já existia.
const ESTRELA_RADIAO_RAIO := 120.0
const ESTRELA_RADIAO_VARREDURA := 0.5

## ---- Tripulação de ponte ----
## Seis corpos na ponte: quatro operadores sentados nos consoles de bordo e dois oficiais de pé nas
## asas do visor, com holograma de leitura na mão. Tripulante não é unidade — não entra em `fleet`
## nem em `enemies`, não tem casco, não é puxado por poço nem chocado por rocha, e a conta da mesa
## continua um blip por casco vivo. A pose sai do `battle_clock` com fase por índice: zero sorteio,
## e é por isso que a pausa tática congela a tripulação junto com a batalha.
const TRIPULANTES_SENTADOS := 4
const TRIPULANTES_EM_PE := 2
const BOB_TRONCO := 0.035
const TAP_MAO := 0.05
const FASE_POR_POSTO := 0.7
const ALARME_CASCO := 60.0
const INCLINACAO_ALARME := 0.13
const COR_TELA_CALMA := Color(0.03, 0.22, 0.34)
const COR_TELA_ALARME := Color(0.5, 0.07, 0.05)

## ---- Paleta da batalha (referência: Legend of the Galactic Heroes) ----
## O anime resolve naves de guerra com aço frio e só uma faixa de cor por nação; o que brilha
## é o escapamento e a arma, nunca o casco inteiro. Por isso `ACO` é neutro e `BLUE`/`RED`
## descem para a função de filete e de torreta.
const ACO := Color(0.34, 0.38, 0.44)
const ACO_ESCURO := Color(0.11, 0.13, 0.17)
const CARVAO := Color(0.05, 0.045, 0.055)
const BRASA := Color(0.72, 0.2, 0.05)
## Cor de escape: fria na linha aliada, quente na hostil. É a distância que se lê no visor.
const ESCOAMENTO_ALIADO := Color(0.34, 0.72, 1.0)
const ESCOAMENTO_HOSTIL := Color(1.0, 0.44, 0.16)
## Ouro de gala da capitânia — usado em filetes, no mastro e na moldura da ponte.
const HUD_OURO := Color(0.82, 0.68, 0.34)
## Offsets fixos da detonação: cinco billets, nenhuma sorteio. Sortear a explosão empurraria a
## cauda de `rng` igual sorteio de estrela — ver `visual_rng`.
const DETONACAO: Array[Vector3] = [Vector3(0, 0, 0), Vector3(1.1, 0.5, -0.7), Vector3(-1.2, -0.4, 0.6),
	Vector3(0.5, -1.0, 1.2), Vector3(-0.7, 0.9, -1.1)]
## ---- Ruína da ponte ----
## A capitânia do jogador não troca de cena nem desaparece quando o casco zera: o deck morre em
## fases dentro do próprio quadro, porque é dentro dele que a câmera está, e a batalha de Legend
## of the Galactic Heroes se julha na ponte de quem afunda, não no casco visto de fora. Os tempos
## e deslocamentos são cravados como os de `DETONACAO` — sorteio na hora da morte empurraria a
## cauda de `rng` — e a sequência anda no relógio que o chamador fornece em `delta`, não em
## `create_tween` de tempo real, porque uma morte que só existe em wall-clock é invisível para a
## sonda headless e nada daquilo poderia ser assinado no portão.
## `fora=true` nasce no mundo, filho da cena: é o estilhaço que se separa do casco e fica parado
## enquanto a ponte aderna — detrito colado ao rig seria a nave arrastando o próprio clarão.
const MORTE_FASES: Array[Dictionary] = [
	{"t": 0.00, "pos": Vector3(0.0, 3.2, -7.4), "fora": false, "size": 1.6, "som": "EXPLOSAO"},
	{"t": 0.40, "pos": Vector3(-6.6, 0.6, -1.8), "fora": false, "size": 1.3, "som": "EXPLOSAO"},
	{"t": 0.82, "pos": Vector3(2.4, 1.0, -13.0), "fora": true, "size": 3.4, "som": "EXPLOSAO"},
	{"t": 1.26, "pos": Vector3(5.4, -0.6, 0.6), "fora": false, "size": 1.3, "som": "EXPLOSAO"},
	{"t": 1.70, "pos": Vector3(0.0, -1.2, -2.6), "fora": false, "size": 1.0, "som": "IMPACTO"},
]
## Vida de cada clarão em segundos: abre, estica e apaga no relógio da ruína.
const MORTE_CLARAO_VIDA := 0.6
## Apagão da luz de trabalho: do valor lido na ignição a zero exato em `MORTE_APAGAO` segundos.
const MORTE_APAGAO := 0.55
## A luz fria não morre de uma vez — ela estoura com cada fase e depois apaga. O período e o pico
## são cravados porque a sonda assina o valor do `light_energy` quadro a quadro, e um estrobo
## sorteado seria a única fonte de aleatoriedade dentro de uma morte que não sorteia nada.
const MORTE_STROBO := 0.1
const MORTE_STROBO_PICO := 1.8
## Quanto o deck escurece na ignição: os materiais do soalho, do casco, do friso e do ouro perdem
## 70% da cor num único traço, porque a ponte sem energia não é um cenário em penumbra, é um
## cenário onde ninguém mais vai acender nada.
const CORTE_RUINA := 0.7
## Fim da sequência: depois daqui não há mais tremor nem fase, só a deriva fria de um casco sem
## reactor. Os tetos de atitude são assinados pela sonda como valores exatos, não aproximados.
const MORTE_DURACAO := 2.2
const MORTE_TILT_ROLAGEM := 0.3
const MORTE_TILT_ARFAGEM := -0.16
const MORTE_TILT_GUIRADA := 0.22
## Tremor de câmera: amplitude de meio palmo no primeiro quadro, extinta em `MORTE_TREMOR_FIM`.
## Mexe só na câmera filha, nunca no rig — a posição do rig é a assinatura que blip, mesa e
## abalroamento conferem, e um tremor nela seria o casco teleportando a cada quadro.
const MORTE_TREMOR := 0.11
const MORTE_TREMOR_FIM := 0.9
## Tela morta: sem energia não há leitura de ponte. É a cor do fim, não um alarme a mais — por
## isso ela é escrita uma vez na ignição, com a mesma disciplina do flanco de `ponte_em_alarme`.
const COR_TELA_MORTA := Color(0.012, 0.014, 0.02)
## Ponte sonora (trilha clássica + efeitos abafados de vácuo) montada como filho da cena, não
## como sistema global: headless não tem alto-falante, e é assim que a sonda consegue ler
## `pedidos` e `soaram` sem depender de saída de áudio.
const PonteSonora := preload("res://audio.gd")
var paused := false
## Signed: positivo é avante, negativo é ré. O HUD lê em porcentagem com sinal.
var throttle := 0.0
## Casco da própria capitânia, que agora é um corpo no tabuleiro: encosta em alguém e leva.
var capital_hp := 100.0
## Velocidade real do rig no último quadro, medida por diferença de posição — é dela que sai a
## velocidade de aproximação do abalroamento.
var capital_velocity := Vector3.ZERO
## Última vez que cada par de cascos trocou golpe, chaveada pelo par de instance ids.
var ram_windows: Dictionary = {}
var fleet: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var battle_clock := 0.0
var fire_clock := 0.0
## Nó da ponte sonora (`PonteSonora`). Os contadores de pedido e de efeito que passaram da
## janela anti-spam vivem nele, e é por eles que a sonda prova o som em headless.
var audio: PonteSonora
## A salva vitoriosa reentra no mesmo relatório a cada 1,6 s; sem esta guarda o alarme de
## fim de combate tocaria para sempre em laço depois da batalha.
var batalha_encerrada := false
var status_label: Label
var report_label: Label
var pause_button: Button
var speed_label: Label
var command_label: Label
var bridge_rig: Node3D
var rng := RandomNumberGenerator.new()
## Gerador exclusivo da camada visual. Estrela, tracer ou detrito sorteado por `rng` empurraria
## a cauda de combate: cada sorteio a mais reescreve todo o dano da salva seguinte (é o que a
## corrida A/B de `tools/probes/sondas.gd` mede). Nada aqui consome `rng`.
var visual_rng := RandomNumberGenerator.new()
## Blips da mesa holográfica: `id do nó lógico` -> `MeshInstance3D`. A mesa espelha o tabuleiro
## real, então ela é construída a partir das listas vivas e não de um cadastro paralelo.
var holo_blips: Dictionary = {}
var holo_root: Node3D
## O blip dourado da capitânia mora fora de `holo_blips`: a mesa é construída a partir das listas
## de frota, e o rig de ponte não é unidade nenhuma — misturar os dois quebraria a conta de
## blips por casco vivo que `tools/probes/graficos.gd` confere.
var holo_capitania: MeshInstance3D
## Anel que gira sobre a mesa: o movimento é o que denuncia a pausa tática como pausa, não
## como jogo congelado.
var holo_anel: Node3D
## Os quatro materiais dos blips são criados uma vez. O blip troca de material, nunca ganha um
## novo por quadro — material novo em loop é exatamente como se vaza recurso no encerramento.
var mat_holo_aliado: StandardMaterial3D
var mat_holo_hostil: StandardMaterial3D
var mat_holo_presa: StandardMaterial3D
var mat_holo_morto: StandardMaterial3D
var selected_target := 0
var formation := "LINHA"
## Densidade de fogo da ponte: índice em FOGO_RAIO. Começa no degrau do meio, que é o setor
## padrão de uma esquadra em linha — nem pilha de fogo num casco só, nem varredura perdida.
var fogo_densidade := 1
## A conta da última salva, devolvida ao comandante no HUD: foi assim que "concentrar" deixou de
## ser adjetivo e virou número conferível.
var salva_resumo := "0/0 impactos"
## A mesma conta do resumo, em números, para a sonda poder conferir sem reler string: quantos
## impactos a salva pôs no tabuleiro e para onde cada um deles foi.
var salva_contagem: Dictionary = {"aliados": 0, "aliados_feriram": 0, "hostis": 0, "hostis_feriram": 0,
	"vaos": 0, "pedras": 0}
## O anel do setor desenhado na mesa holográfica. Mora no rig, como o blip da capitânia, porque a
## conta de um blip por casco vivo não pode ler geometria de comando.
var holo_setor: MeshInstance3D
## Centro do disco de salva no tabuleiro, na última salva resolvida. No meio da janela tática até
## a primeira salva existir.
var setor_fogo_pos := Vector3(0.0, 0.0, HOLO_ANCHOR_Z)
## Sondas táticas vivas: cada entrada é um nó visível que atravessa o tabuleiro varrendo
## cascos com o próprio corpo. Enquanto nenhuma sonda passa sobre um hull, ele continua
## "não identificado" na ponte — a informação é efeito de um objeto no mapa, não de um
## cronômetro. Nada aqui sorteia: ver a cauda de RNG em `_update_probes`.
var probes: Array[Dictionary] = []
## Cobertura da varredura, medida em contatos e não em tempo: `recon_progress` passou a ser
## 100 * recon_contacts / recon_total. Sem casco hostil vivo o par fica 0/0 e a barra em 0,
## porque não há linha a cobrir.
var recon_progress := 0.0
var recon_contacts := 0
var recon_total := 0
var reserve_mode := false

## ---- Cenário em jogo ----
## `cenario_atual` é o nome escolhido no painel; com `"ABERTO"` as três coleções abaixo ficam
## vazias e os dois pontos de perigo ficam longe de tudo, que é o que faz a inércia do slice ser
## conferível: nenhum laço roda, nenhuma distância cai dentro de um raio.
var cenario_atual := "ABERTO"
## Cada rocha: {"no": MeshInstance3D, "marca": MeshInstance3D, "id": int, "pos": Vector3,
## "vel": Vector3, "fase": float, "raio": float, "integridade": float, "geracao": int}.
## `pos` é a fonte de verdade e o nó apenas a pinta — a barreira é lida por conta, não por
## `global_position` de cena, para a sonda poder conferir a mesma grandeza que a jogabilidade usa.
## `id` não é enfeite de depuração: a janela de abalroamento é chaveada por pedra, e com a pedra
## andando a chave geométrica (z arredondado) trocaria de nome a cada quadro, o que rearmaria o
## dano toda vez e transformaria o cinturão num moedor.
var rochas: Array[Dictionary] = []
var rocha_proxima_id := 0
## Materiais do cinturão, criados na primeira pedra e reaproveitados na fratura: sem o cache, cada
## rachadura compraria material novo e o tabuleiro incharia recurso no meio da batalha.
var rocha_material: Material
var rocha_marca_material: Material
var poco_ativo := false
var estrela_ativa := false
## Nós pintados do cenário, para `_montar_cenario` poder trocar de mapa sem deixar corpo velho
## no tabuleiro (e sem deixar recurso pendurado no encerramento).
var cenario_root: Node3D
var holo_cenario: Array[MeshInstance3D] = []
## A lente pintada: o disco de matéria e o conjunto de arcos lentificados. Ambos são um único
## MultiMesh — duzentos nós separados seriam duzentos draw calls no Compatibility por uma decoração
## que nunca colide. `poco_lente` é o nó que segura aro e arcos e que, a cada quadro, vira o plano
## para o olho da ponte: a imagem lentificada é do observador, não do mundo.
var poco_disco: MultiMeshInstance3D
var poco_lente: MultiMeshInstance3D
## Céu de fundo em estado vivo: a base crua de cada estrela e o que está pintado agora. A base é a
## transformada AUTORGADA pelo sorteio, nunca a leitura de volta do MultiMesh: sob renderizador sem
## janela o `set_instance_transform` é descartado em silêncio e a leitura devolve identidade, então
## quem depende do readback dobra um céu de estrelas todas em (0,0,0). Com a base própria, a lente
## pode ser conferida por sonda em qualquer driver e o undo da dobra não reconstrói o MultiMesh.
var campo_estelar: MultiMeshInstance3D
var estrelas_base: Array[Transform3D] = []
var estrelas_pintadas: Array[Transform3D] = []
## Quantas estrelas o céu emprestou para a lente no último quadro. Medido pela sonda: zero em
## campo aberto, e o teto da conta quando o poço está montado e a proa apontada para ele.
var estrelas_dobradas := 0
## Tripulação pintada na ponte: cada posto guarda o nó e as peças que se mexem, mais a posição
## crua delas. Sem a base guardada, a animação acumularia um empurrão por quadro e o operador
## desceria pelo soalho em dois minutos de batalha.
var tripulacao: Array[Dictionary] = []
## Material único das quatro telas de console: o alarme tinge uma vez, no flanco do estado, e não
## por quadro — escrever `emission` a cada frame é a ponte piscando para a GPU.
var ponte_telas: StandardMaterial3D
var ponte_em_alarme := false
## ---- Estado da ruína ----
## `ponte_condenada` é a guarda de idempotência: o casco pode zerar por salva, rocha, corona ou
## poço, e a sequência tem de rodar uma vez só não importa quantos caminhos bateram no zero.
## `morte_t` anda em segundos de relógio de jogo, e é por isso que a sonda pode avançar a morte
## quadro a quadro em passo cravado e assinar coordenada, luz e atitude.
var ponte_condenada := false
var ponte_sem_energia := false
var morte_t := 0.0
var morte_fase := 0
## Um billet por fase, criado no quadro da fase e liberado no quadro em que a vida dele vence.
## Sem esta lista o clarão ficaria pendurado no rig depois do apagão — e este repositório reprova
## recurso preso no encerramento.
var morte_claroes: Array = []
## Energia das duas luzes da ponte, lida na ignição para o fade começar de onde ela estava.
var ponte_luz_trabalho: OmniLight3D
var ponte_luz_fria: OmniLight3D
var ponte_energia_trabalho := 0.0
var ponte_energia_fria := 0.0
## Câmera da ponte e a posição crua dela: o tremor é um deslocamento local em cima desta base, e
## a asserção do fim é voltar para ela com exatidão de vírgula.
var ponte_camera: Camera3D
var ponte_camera_base := Vector3.ZERO
## Rumo no quadro da ignição: a guinada da ruína é medida em cima dele, porque a ponte pode adernar
## para bombordo ou para estibordo dependendo só de para onde o comandante olhava quando o casco
## fechou — e o teto assinado pela sonda é o acréscimo, não a bússola final.
var ponte_rumo_base := 0.0
## Taxa de cada adernamento, medida na ignição sobre a DISTÂNCIA REAL até o teto. Cobrir o teto na
## taxa `teto / MORTE_DURACAO` só fecha no tempo cravado se a partida for do zero: uma ponte que já
## aderna de -0,05 em rolagem tem 0,35 a percorrer, não 0,30, e chegaria depois do fim da sequência
## — o teto assinado pela sonda seria um número que nenhum quadro produziu.
var ponte_taxa_rolagem := 0.0
var ponte_taxa_arfagem := 0.0
var ponte_taxa_guinada := 0.0
var selection_scope := "FROTA"
var target_selector: OptionButton
var protected_selector: OptionButton
var protected_unit_index := -1
var scope_selector: OptionButton
var subsystem_selector: OptionButton
var repair_selector: OptionButton
var position_x_input: SpinBox
var position_z_input: SpinBox
var move_x := 0.0
var move_z := -55.0
## O painel é um acordeão, não uma lista de dezenove botões: um grupo aberto por vez, e o
## grupo aberto é o da última ordem que o comandante deu. Vinte botões vistos de uma vez transformam
## a ponte em formulário — a leitura rápida do quadro vale mais que o acesso simultâneo a tudo.
var group_heads: Dictionary = {}
var group_bodies: Dictionary = {}
var grupo_aberto := "FORMAÇÕES"
## O corpo do painel mora num `ScrollContainer`: abrir um grupo abaixo da dobra sem rolar até ele
## deixaria o comandante clicando num cabeçalho que não mostra o que abriu.
var painel_scroll: ScrollContainer
## Leitura da IA hostil, atualizada a cada salva: postura da frota, alvo concentrado e a
## frase que a ponte devolve ao comandante. Com `hostile_posture == "AVANÇAR"` a frota
## hostil se comporta como antes deste recurso — nenhuma fórmula paralela, só a decisão
## de quem escolhe alvo e posição.
var hostile_posture := "AVANÇAR"
var hostile_focus := -1
var tactical_note := "POSTURA HOSTIL: AVANÇAR"

func _ready() -> void:
	rng.randomize()
	# Semente cravada de propósito: o céu e os fachos são os mesmos em toda partida, e nada do
	# que se vê depende do sorteio da batalha.
	visual_rng.seed = 20261020
	_registra_voo()
	_build_environment()
	_build_bridge()
	_build_fleets()
	_rebuild_holo()
	# Antes da primeira UI: sem isto a ponte abriria com 0/0 quando o tabuleiro já tem seis
	# cascos hostis a confirmar.
	_recompute_recon()
	_build_ui()
	# A ponte só ganha som depois de montada: se a UI abortar, a trilha não fica tocando
	# num jogo quebrado — e `tocar_trilha()` é idempotente, então um segundo `_ready` não
	# reinicia a frase no meio.
	audio = PonteSonora.new()
	audio.name = "PonteSonora"
	add_child(audio)
	audio.tocar_trilha()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	# A mesa holográfica continua acesa na pausa tática: é exatamente ali que o comandante
	# precisa ler o tabuleiro. Nada aqui move casco, motor, arma nem tripulação.
	_update_bridge(delta)
	if paused:
		return
	battle_clock += delta
	fire_clock += delta
	# Com o casco em zero o timão morre junto com o reactor: nada mais lê teclado, o rig segue a
	# inércia do último quadro e a ruína toca as fases no relógio da batalha. A ignição é feita
	# dentro de `_atualizar_ruina` porque o casco pode zerar por salva, rocha, coroa ou poço, e os
	# quatro caminhos têm de morrer do mesmo jeito, uma vez só.
	if capital_hp <= 0.0:
		_atualizar_ruina(delta)
	else:
		_update_capital_ship(delta)
	_update_fleet(delta)
	_update_probes(delta)
	_update_tripulacao()
	if fire_clock >= 1.6:
		fire_clock = 0.0
		_resolve_volley()
	if is_instance_valid(speed_label):
		# Velocidade com sinal: ré é marcha, não defeito, e a altitude entra porque o campo agora
		# tem três eixos e o comandante precisa ler em qual dele está.
		speed_label.text = "VELOCIDADE %+04d%%  //  SUBIDA %+04d  //  CASCO DA CAPITÂNIA %03d%%" % [
			int(throttle * 100.0), int(bridge_rig.position.y), int(capital_hp)]
	if is_instance_valid(report_label) and not batalha_encerrada \
			and int(battle_clock) % 12 == 0 and fmod(battle_clock, 1.0) < delta:
		report_label.text = "RELATÓRIO: contato hostil confirmado. Frota em combate."
	_update_hud()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_toggle_pause()
		elif event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	# Céu quase preto com horizonte azul-frio: sem SSR e sem SDFI no Compatibility, é a
	# radiância do céu que dá ao aço do casco o degradê que uma luz ambiente chapada nunca deu.
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.004, 0.008, 0.02)
	sky_mat.sky_horizon_color = Color(0.055, 0.11, 0.22)
	sky_mat.ground_bottom_color = Color(0.004, 0.006, 0.012)
	sky_mat.ground_horizon_color = Color(0.04, 0.085, 0.17)
	sky_mat.sky_curve = 0.22
	sky_mat.ground_curve = 0.24
	sky_mat.ground_energy_multiplier = 0.6
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.background_sky = sky
	# O ambient é o único "reflexo" que o Compatibility tem de sobra: com o céu preto abaixo,
	# o aço pintado não recebia nada e o casco afundava no fundo do quadro.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	# Névoa rasa: a linha hostil a cem unidades afunda no escuro em vez de chegar à ponte com a
	# mesma nitidez da capitânia ao lado. Densidade baixa de propósito — céu alto some com mais.
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.09, 0.17)
	env.fog_density = 0.0013
	env.fog_sky_affect = 0.15
	# ACES + glow. No Compatibility o glow é a implementação simples (sem níveis nem `glow_map`),
	# e é dela que vivem os fachos de motor e os lances — por isso os emissivos são ligados
	# acima de 1,0 em energia: abaixo do limiar o bloom não pega nada.
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.25
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_strength = 0.55
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.3
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24, -36, 0)
	sun.light_color = Color(0.72, 0.84, 1.0)
	sun.light_energy = 1.55
	sun.shadow_enabled = false
	add_child(sun)
	# Contraluz frio vindo de trás da linha hostil: é o que separa a silhueta do céu.
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(14, 148, 0)
	rim.light_color = Color(0.35, 0.55, 0.95)
	rim.light_energy = 0.5
	rim.shadow_enabled = false
	add_child(rim)
	_build_backdrop()
	_build_starfield()

## O fundo do sistema: um planeta escuro com terminador e uma aurora aditiva no limbo, mais o
## disco de luz da estrela chave fora de quadro. Escala e leitura de profundidade, não decoração.
func _build_backdrop() -> void:
	var planet := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 22.0
	sphere.height = 44.0
	planet.mesh = sphere
	planet.position = Vector3(42, 8, -165)
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.09, 0.15, 0.26)
	pm.metallic = 0.05
	pm.roughness = 0.95
	pm.emission_enabled = true
	pm.emission = Color(0.008, 0.022, 0.05)
	pm.emission_energy_multiplier = 1.0
	planet.material_override = pm
	add_child(planet)
	# Aurora no limbo: um disco aditivo um pouco maior que o planeta, visto de frente.
	var haze := _flare(Vector3(42, 8, -164.0), 52.0, Color(0.1, 0.34, 0.62, 0.34), self)
	haze.rotation_degrees = Vector3.ZERO
	# A estrela do sistema fica fora do visor, mas o núcleo dela entra pela borda.
	_flare(Vector3(-118.0, 44.0, -190.0), 30.0, Color(0.85, 0.9, 1.0, 0.55), self)

## Campo de estrelas em um único MultiMesh. Antes eram 260 nós sortidos por `rng`, o que
## empurrava a cauda de combate antes de a primeira nave existir; agora é uma drawn call e o
## sorteio é do gerador visual, com semente cravada.
func _build_starfield() -> void:
	var stars := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var quad := PlaneMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	quad.material = mat
	mm.mesh = quad
	mm.instance_count = 900
	for i in range(mm.instance_count):
		var pos := Vector3(visual_rng.randf_range(-280.0, 280.0), visual_rng.randf_range(-150.0, 150.0),
			visual_rng.randf_range(-340.0, -55.0))
		var brilho := visual_rng.randf_range(0.2, 1.0)
		var tam := visual_rng.randf_range(0.3, 1.4)
		# Um em cada trinta e sete é largo e estoura no glow: são as que dão profundidade ao céu.
		if i % 37 == 0:
			tam *= 3.4
			brilho = minf(1.0, brilho * 1.6)
		var autorgada := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * tam), pos)
		mm.set_instance_transform(i, autorgada)
		mm.set_instance_color(i, Color(brilho, brilho * 1.05, brilho * 1.18))
		estrelas_base.append(autorgada)
		estrelas_pintadas.append(autorgada)
	stars.multimesh = mm
	add_child(stars)
	campo_estelar = stars

func _build_bridge() -> void:
	bridge_rig = Node3D.new()
	bridge_rig.name = "Capitânia - Ponte"
	add_child(bridge_rig)
	var piso := _material(Color(0.03, 0.045, 0.07), 0.62, 0.38)
	var casco_ponte := _material(Color(0.045, 0.062, 0.09), 0.5, 0.48)
	var trim := _material(Color(0.1, 0.14, 0.2), 0.55, 0.42)
	# Ouro é acento de filete, não luminária: a 0.45 de emissão ele competia com a holografia e a
	# ponte virava cenário de neon. LotGH usa o dourado na régua, discreto.
	var ouro := _material(HUD_OURO.darkened(0.62), 0.6, 0.34, HUD_OURO * 0.2)
	var tela := _material(Color(0.02, 0.06, 0.09), 0.2, 0.6, COR_TELA_CALMA)
	ponte_telas = tela
	# Costado, soalho e teto: sem eles a câmera flutua no vácuo em vez de estar dentro de um
	# navio. Tudo fecha no anteparo de vante, onde o visor se abre.
	_box(Vector3(0, -2.1, 2.2), Vector3(15, 0.5, 20), piso, bridge_rig)
	_box(Vector3(0, 5.4, 2.2), Vector3(15, 0.4, 20), casco_ponte, bridge_rig)
	for lado in [-1.0, 1.0]:
		_box(Vector3(lado * 7.4, 1.6, 2.2), Vector3(0.5, 8, 20), casco_ponte, bridge_rig)
		_box(Vector3(lado * 7.1, 3.4, 2.2), Vector3(0.14, 0.1, 19.4), ouro, bridge_rig)
	# Anteparo de vante com o visor escancarado: verga, peitoril e montantes, moldura em ouro.
	_box(Vector3(0, 4.65, -7.6), Vector3(15, 1.7, 0.55), casco_ponte, bridge_rig)
	_box(Vector3(0, -1.9, -7.6), Vector3(15, 1.4, 0.55), casco_ponte, bridge_rig)
	for lado in [-1.0, 1.0]:
		_box(Vector3(lado * 7.15, 1.5, -7.6), Vector3(0.9, 7.2, 0.55), casco_ponte, bridge_rig)
	_box(Vector3(0, 3.68, -7.75), Vector3(13.4, 0.13, 0.2), ouro, bridge_rig)
	_box(Vector3(0, -1.05, -7.75), Vector3(13.4, 0.13, 0.2), ouro, bridge_rig)
	for lado in [-1.0, 1.0]:
		_box(Vector3(lado * 2.3, 1.3, -7.7), Vector3(0.11, 4.7, 0.16), trim, bridge_rig)
	# O vidro quase não existe: só o brilho do canto, para a moldura segurar o quadro sem
	# esconder a batalha.
	var vidro := StandardMaterial3D.new()
	vidro.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vidro.albedo_color = Color(0.3, 0.55, 0.8, 0.05)
	vidro.metallic = 0.85
	vidro.roughness = 0.08
	vidro.cull_mode = BaseMaterial3D.CULL_DISABLED
	_box(Vector3(0, 1.3, -7.85), Vector3(13.2, 4.6, 0.05), vidro, bridge_rig)
	# Postos de trabalho em duas linhas de cada bordo: o console inclinado e a tela de leitura.
	for lado in [-1.0, 1.0]:
		for profundidade in [-0.8, -3.6]:
			var console := _box(Vector3(lado * 4.4, -0.85, profundidade), Vector3(3.4, 0.3, 2.1),
				trim, bridge_rig)
			console.rotation.x = -0.14
			_box(Vector3(lado * 4.4, -0.62, profundidade), Vector3(2.7, 0.04, 1.4), tela, bridge_rig)
			for tecla in range(5):
				_box(Vector3(lado * 4.4 + (float(tecla) - 2.0) * 0.44 * lado, -0.58, profundidade - 0.45),
					Vector3(0.16, 0.03, 0.5), _material(BLUE, 0.2, 0.3, BLUE * 0.4), bridge_rig)
	# trilho de comando abaixo do visor, onde a ponte apoia o olhar. A régua passa abaixo da
	# linha de vista da mesa: a 8 unidades de largura e y -1.1 ela fatiava a holografia ao meio
	# e escondia a segunda fila de blips, que é justamente a do inimigo.
	_box(Vector3(0, -1.66, -2.2), Vector3(6.6, 0.18, 0.35), ouro, bridge_rig)
	# Os materiais do deck ficam guardados no próprio rig: a ruína apaga a ponte escrevendo uma
	# vez em cada um deles, e precisa dos nós depois de `_build_bridge` ter voltado.
	bridge_rig.set_meta("mat", {"piso": piso, "casco": casco_ponte, "trim": trim, "ouro": ouro,
		"tela": tela, "vidro": vidro})
	_build_holo_table()
	# Luz de trabalho: âmbar sobre os postos, fria sob a holografia. Sem sombra — o
	# Compatibility não shadowa, e ligar shadow aqui só imprimisse aviso por luz.
	var lampada := OmniLight3D.new()
	lampada.name = "LuzTrabalho"
	lampada.position = Vector3(0, 4.2, 1.5)
	lampada.light_color = Color(0.95, 0.72, 0.4)
	lampada.light_energy = 0.55
	lampada.omni_range = 14.0
	lampada.shadow_enabled = false
	bridge_rig.add_child(lampada)
	ponte_luz_trabalho = lampada
	var fria := OmniLight3D.new()
	fria.name = "LuzFria"
	fria.position = Vector3(0, -0.6, -2.6)
	fria.light_color = Color(0.35, 0.8, 1.0)
	fria.light_energy = 0.5
	fria.omni_range = 8.0
	fria.shadow_enabled = false
	bridge_rig.add_child(fria)
	ponte_luz_fria = fria
	_build_tripulacao()
	# Câmera atrás do trilho de comando: o parapeito entra no quadro como moldura inferior.
	var camera := Camera3D.new()
	camera.name = "BridgeCamera"
	camera.position = Vector3(0, 1.0, 3.0)
	camera.rotation_degrees = Vector3(-3, 0, 0)
	camera.fov = 78
	bridge_rig.add_child(camera)
	ponte_camera = camera
	ponte_camera_base = camera.position

## Postos da tripulação: quatro operadores sentados nos consoles de bordo (x ±3,5, de frente para a
## própria bancada) e dois oficiais de pé nas asas do visor com holograma de leitura na mão. Os
## sentados ficam a 3,5 do eixo da mesa e os de pé a 6,6 — nenhum corpo dentro do disco de 3,05,
## porque tripulante cobrindo blip é a ponte escondendo o tabuleiro. Nada aqui sorteia: a fase vem
## do índice do posto, e é por isso que a pausa congela a ponte inteira junto com a batalha.
func _build_tripulacao() -> void:
	var uniforme := _material(Color(0.13, 0.16, 0.23), 0.3, 0.62)
	var filete := _material(HUD_OURO.darkened(0.58), 0.4, 0.5)
	var pele := _material(Color(0.44, 0.33, 0.28), 0.0, 0.78)
	var assento := _material(Color(0.055, 0.07, 0.1), 0.4, 0.6)
	var brilho := _glasm(Color(0.22, 0.66, 0.9, 0.5))
	var postos: Array[Dictionary] = [
		{"pos": Vector3(-3.5, 0.0, -0.8), "gira": PI / 2.0, "em_pe": false},
		{"pos": Vector3(-3.5, 0.0, -3.6), "gira": PI / 2.0, "em_pe": false},
		{"pos": Vector3(3.5, 0.0, -0.8), "gira": -PI / 2.0, "em_pe": false},
		{"pos": Vector3(3.5, 0.0, -3.6), "gira": -PI / 2.0, "em_pe": false},
		{"pos": Vector3(-5.5, 0.0, -6.1), "gira": 0.0, "em_pe": true},
		{"pos": Vector3(5.5, 0.0, -6.1), "gira": 0.0, "em_pe": true},
	]
	for i in range(postos.size()):
		var posto: Dictionary = postos[i]
		var ancorado: Vector3 = posto["pos"]
		var corpo := Node3D.new()
		corpo.name = "Tripulante %02d" % (i + 1)
		corpo.position = Vector3(ancorado.x, -1.85, ancorado.z)
		corpo.rotation.y = float(posto["gira"])
		bridge_rig.add_child(corpo)
		var em_pe := bool(posto["em_pe"])
		var tronco: MeshInstance3D
		var mao: MeshInstance3D = null
		var anel: MeshInstance3D = null
		if em_pe:
			_box(Vector3(0, 0.42, 0), Vector3(0.4, 0.84, 0.26), uniforme, corpo)
			tronco = _box(Vector3(0, 1.18, 0), Vector3(0.44, 0.7, 0.28), uniforme, corpo)
			_box(Vector3(0, 0.3, 0), Vector3(0.46, 0.06, 0.3), filete, tronco)
			_cabeca(tronco, pele, 0.5)
			for lado in [-1.0, 1.0]:
				_box(Vector3(lado * 0.26, -0.06, -0.22), Vector3(0.11, 0.11, 0.5), uniforme, tronco)
			# O holograma de leitura: pastilha na mão e o volume de luz subindo dela.
			_cylinder(Vector3(0, -0.12, -0.44), 0.16, 0.16, 0.04, filete, tronco, Vector3.ZERO, 12)
			var cone := _cylinder(Vector3(0, 0.12, -0.44), 0.05, 0.15, 0.42, brilho, tronco,
				Vector3.ZERO, 12)
			cone.rotation.x = PI
			anel = MeshInstance3D.new()
			var toro := TorusMesh.new()
			toro.inner_radius = 0.09
			toro.outer_radius = 0.12
			anel.mesh = toro
			anel.position = Vector3(0, 0.2, -0.44)
			anel.material_override = brilho
			tronco.add_child(anel)
		else:
			_box(Vector3(0, 0.28, 0.05), Vector3(0.16, 0.56, 0.16), assento, corpo)
			_box(Vector3(0, 0.6, 0.05), Vector3(0.52, 0.1, 0.52), assento, corpo)
			_box(Vector3(0, 1.0, 0.3), Vector3(0.5, 0.74, 0.1), assento, corpo)
			tronco = _box(Vector3(0, 1.06, -0.02), Vector3(0.44, 0.62, 0.28), uniforme, corpo)
			_box(Vector3(0, 0.26, -0.02), Vector3(0.46, 0.06, 0.3), filete, tronco)
			_cabeca(tronco, pele, 0.46)
			for lado in [-1.0, 1.0]:
				var braco := _box(Vector3(lado * 0.26, -0.04, -0.24), Vector3(0.11, 0.11, 0.52),
					uniforme, tronco)
				braco.rotation.x = 0.16
			mao = _box(Vector3(0.26, -0.12, -0.5), Vector3(0.1, 0.08, 0.14), pele, tronco)
		tripulacao.append({"no": corpo, "tronco": tronco, "mao": mao, "anel": anel,
			"em_pe": em_pe, "base_tronco": float(tronco.position.y),
			"base_mao": float(mao.position.z) if mao != null else 0.0,
			"fase": float(i) * FASE_POR_POSTO})


## Cabeça do tripulante: esfera filha do tronco, porque o bob do corpo tem de levar a cabeça junto
## — cabeça solta no nó raiz seria um crânio flutuando enquanto o operador respira.
func _cabeca(pai: Node3D, pele: Material, altura: float) -> MeshInstance3D:
	var cabeca := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.15
	esfera.height = 0.3
	esfera.radial_segments = 10
	esfera.rings = 6
	cabeca.mesh = esfera
	cabeca.position = Vector3(0, altura, -0.02)
	cabeca.material_override = pele
	pai.add_child(cabeca)
	return cabeca


## A pose da ponte. Tudo sai de `battle_clock`, que congela na pausa tática: o quadro para, a
## tripulação para. O alarme é lido no casco da capitânia e escrito UMA vez no material compartilhado
## das quatro telas — escrever `emission` por quadro seria a ponte piscando para a GPU.
func _update_tripulacao() -> void:
	# Sem energia a pose congela onde a morte pegou cada operador: os corpos ficam nos consoles,
	# a leitura do alarme deixa de escrever nas telas (é a tela MORTA que tem de permanecer no
	# material, não o vermelho voltando por cima) e nada na ponte se mexe por animação outra vez.
	if ponte_sem_energia:
		return
	var alerta := capital_hp < ALARME_CASCO
	if alerta != ponte_em_alarme:
		ponte_em_alarme = alerta
		if is_instance_valid(ponte_telas) and ponte_telas.emission_enabled:
			ponte_telas.emission = COR_TELA_ALARME if alerta else COR_TELA_CALMA
	for posto in tripulacao:
		var tronco: MeshInstance3D = posto["tronco"]
		if not is_instance_valid(tronco):
			continue
		var fase: float = float(posto["fase"])
		tronco.position.y = float(posto["base_tronco"]) + sin(battle_clock * 1.7 + fase) * BOB_TRONCO
		tronco.rotation.x = INCLINACAO_ALARME if (alerta and not bool(posto["em_pe"])) else 0.0
		var mao: MeshInstance3D = posto["mao"]
		if is_instance_valid(mao):
			mao.position.z = float(posto["base_mao"]) + sin(battle_clock * 3.1 + fase) * TAP_MAO
		var anel: MeshInstance3D = posto["anel"]
		if is_instance_valid(anel):
			anel.rotation.y = battle_clock * 0.8 + fase


## Mesa holográfica de ponte: disco, anéis e o cone do projetor. Os blips não são decoração —
## `_rebuild_holo` os monta a partir das listas vivas, então a mesa mostra exatamente a frota
## que o HUD conta.
func _build_holo_table() -> void:
	var base := _material(Color(0.04, 0.06, 0.085), 0.75, 0.35)
	_cylinder(Vector3(0, -1.52, -2.6), 3.05, 3.05, 0.14, base, bridge_rig, Vector3.ZERO, 24)
	for lado in [-1.0, 1.0]:
		_box(Vector3(lado * 2.6, -1.0, -1.4), Vector3(0.16, 1.1, 0.16), base, bridge_rig)
		_box(Vector3(lado * 2.6, -1.0, -3.8), Vector3(0.16, 1.1, 0.16), base, bridge_rig)
	var aro := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 2.95
	toro.outer_radius = 3.1
	aro.mesh = toro
	aro.position = Vector3(0, -1.44, -2.6)
	aro.material_override = _material(HUD_OURO.darkened(0.5), 0.8, 0.3, HUD_OURO * 0.6)
	bridge_rig.add_child(aro)
	holo_anel = Node3D.new()
	holo_anel.position = Vector3(0, -1.4, -2.6)
	bridge_rig.add_child(holo_anel)
	for raio in [1.0, 1.9, 2.75]:
		var anel := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = raio - 0.035
		torus.outer_radius = raio + 0.035
		anel.mesh = torus
		anel.material_override = _material(Color(0.1, 0.5, 0.7), 0.1, 0.4, Color(0.12, 0.62, 0.85))
		holo_anel.add_child(anel)
	# Cone do projetor: o volume de luz que sai do disco e segura os blips no ar.
	var cone := _cylinder(Vector3(0, -0.85, -2.6), 2.7, 0.35, 1.2, _glasm(Color(0.2, 0.62, 0.9, 0.07)),
		bridge_rig, Vector3.ZERO, 24)
	cone.rotation.x = PI
	holo_root = Node3D.new()
	holo_root.name = "Blips"
	holo_root.position = Vector3(0, -1.34, -2.6)
	bridge_rig.add_child(holo_root)
	mat_holo_aliado = _holo_mat(ESCOAMENTO_ALIADO)
	mat_holo_hostil = _holo_mat(Color(1.0, 0.34, 0.24))
	mat_holo_presa = _holo_mat(GOLD)
	mat_holo_morto = _holo_mat(Color(0.22, 0.24, 0.28))
	# O blip da capitânia é dourado e mora no rig, não na lista de blips: o rig não é unidade de
	# frota, e a conta de blip por casco vivo que `tools/probes/graficos.gd` confere tem de
	# continuar lendo só `fleet` + `enemies`.
	holo_capitania = _cylinder(holo_root.position + _holo_de(bridge_rig.position), 0.11, 0.0, 0.34,
		_holo_mat(HUD_OURO.lightened(0.25)), bridge_rig, Vector3.ZERO, 6)
	# O aro do setor de fogo é geometria de comando, não contato: mora no rig como o blip da
	# capitânia e é redesenhado a cada salva. A mesa continua lendo um blip por casco vivo.
	holo_setor = MeshInstance3D.new()
	var setor_aros := TorusMesh.new()
	setor_aros.ring_segments = 32
	setor_aros.rings = 8
	holo_setor.mesh = setor_aros
	holo_setor.material_override = _glasm(Color(0.9, 0.6, 0.18, 0.55))
	bridge_rig.add_child(holo_setor)
	_desenhar_setor_de_fogo()

## O disco desenhado na mesa é a densidade de fogo: o raio sai de FOGO_RAIO na escala da tabela e
## o centro é o alvo comandado. Sem ele, "concentrar" e "dispersar" seriam números no relatório.
func _desenhar_setor_de_fogo() -> void:
	if not is_instance_valid(holo_setor) or not is_instance_valid(holo_root):
		return
	var aros := holo_setor.mesh as TorusMesh
	var raio: float = FOGO_RAIO[fogo_densidade] * HOLO_SCALE
	var novo_interno := maxf(0.035, raio - 0.05)
	var novo_externo := raio + 0.05
	# O motor recusa um toro com raio interno igual ao externo, e cada escrita refaz o mesh na hora.
	# No aro recém-criado o externo ainda está no default 1,0, e o degrau do meio dá
	# exatamente 14,0 × 0,075 − 0,05 = 1,00: abrir pelo interno abortava a construção na ponte nova.
	# Quem escreve primeiro é sempre o lado que aumenta a folga.
	if novo_externo > aros.inner_radius:
		aros.outer_radius = novo_externo
		aros.inner_radius = novo_interno
	else:
		aros.inner_radius = novo_interno
		aros.outer_radius = novo_externo
	holo_setor.position = holo_root.position + _holo_de(setor_fogo_pos)

func _holo_mat(cor: Color) -> StandardMaterial3D:
	# Emissão abaixo do limiar de bloom de propósito: o blip tem de ler como holograma colorido
	# da própria facção, não como lâmpada. A 1,6× o ACES estourava tudo em branco e a mesa
	# perdia a única informação que ela carrega — de que lado é o contato.
	return _material(cor.darkened(0.3), 0.0, 0.6, cor * 0.45)

func _glasm(cor: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = cor
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

## Posição de tabuleiro -> posição na mesa: o mesmo campo, na mesma proporção nos três eixos, com
## a altitude ampliada porque ela é a menor dimensão do combate. Quem sai da janela tática encosta
## no aro em vez de desaparecer da mesa.
func _holo_de(pos: Vector3) -> Vector3:
	var dx := pos.x * HOLO_SCALE
	var dz := (pos.z - HOLO_ANCHOR_Z) * HOLO_SCALE
	var raio := Vector2(dx, dz).length()
	if raio > HOLO_RIM:
		var fator := HOLO_RIM / raio
		dx *= fator
		dz *= fator
	return Vector3(dx, 0.1 + clampf(pos.y * HOLO_ALT_SCALE, -HOLO_ALT_CEIL, HOLO_ALT_CEIL), dz)

func _rebuild_holo() -> void:
	if not is_instance_valid(holo_root):
		return
	for blip in holo_blips.values():
		var ping: MeshInstance3D = blip
		if is_instance_valid(ping):
			ping.queue_free()
	holo_blips.clear()
	for grupo in [fleet, enemies]:
		for unit in grupo:
			var node: Node3D = unit["node"]
			if not is_instance_valid(node):
				continue
			var ping := _cylinder(_holo_de(node.position), 0.085, 0.0, 0.22, mat_holo_aliado,
				holo_root, Vector3.ZERO, 6)
			holo_blips[node.get_instance_id()] = ping

func _atualiza_blip(unit: Dictionary, aliada: bool) -> void:
	var node: Node3D = unit["node"]
	if not is_instance_valid(node) or not holo_blips.has(node.get_instance_id()):
		return
	var ping: MeshInstance3D = holo_blips[node.get_instance_id()]
	ping.position = _holo_de(node.position)
	if float(unit["hp"]) <= 0.0:
		ping.material_override = mat_holo_morto
	elif String(unit.get("squadron", "")) == "PRESA":
		ping.material_override = mat_holo_presa
	else:
		ping.material_override = mat_holo_aliado if aliada else mat_holo_hostil

## Acorda a ponte: anel girando e blip em dia com o tabuleiro. Roda também na pausa, porque a
## mesa existe para o comandante ler a batalha enquanto dá ordem.
func _update_bridge(_delta: float) -> void:
	if not is_instance_valid(holo_root):
		return
	holo_anel.rotation.y += _delta * 0.32
	for unit in fleet:
		_atualiza_blip(unit, true)
	for unit in enemies:
		_atualiza_blip(unit, false)
	# A capitânia também é corpo no campo, então também tem blip: o comandante precisa se ver na
	# mesa para não mandar a frota para cima da própria ponte.
	if is_instance_valid(holo_capitania):
		holo_capitania.position = holo_root.position + _holo_de(bridge_rig.position)

func _build_fleets() -> void:
	# A faixa de deslocamento inicial é pintura de formação, não sorteio de batalha: morava em
	# `rng`, e por isso a semente tinha de ser cravada depois de montar a frota — o que deixava a
	# posição de partida diferente entre duas rodadas com a mesma semente e impedia a sonda de
	# assinar um valor. Agora `rng` começa a salvar do zero, em toda partida.
	for i in range(6):
		var x := (float(i) - 2.5) * 5.0
		var z := -38.0 - (i % 2) * 5.0
		var ship := _make_ship(Vector3(x, visual_rng.randf_range(-2, 2), z), BLUE,
			1.1 + float(i % 3) * 0.06, "ALIADA %02d" % (i + 1))
		fleet.append({"node": ship, "order": "LINHA", "hp": 100.0, "max_hp": 100.0, "engines": 100.0, "weapons": 100.0, "crew": 100.0, "repair": 0.0, "repair_priority": "AUTO", "team": "friendly", "name": "ALIADA %02d" % (i + 1), "squadron": "ALFA" if i < 3 else "BETA"})
	for i in range(6):
		var x := (float(i) - 2.5) * 6.0
		var z := -82.0 - (i % 2) * 7.0
		var is_command := i == 0
		var ship := _make_ship(Vector3(x, visual_rng.randf_range(-3, 3), z), RED,
			1.55 if is_command else 1.3, "HOSTIL %02d" % (i + 1), is_command)
		enemies.append({"node": ship, "order": "AVANÇAR", "hp": 100.0, "max_hp": 100.0, "engines": 100.0, "weapons": 100.0, "crew": 100.0, "repair": 0.0, "team": "enemy", "name": "CAPITÂNIA HOSTIL" if is_command else "HOSTIL %02d" % (i + 1), "squadron": "INIMIGO", "role": "COMANDO" if is_command else "LINE"})

## Casco de linha em leitura Legend of the Galactic Heroes: aço neutro, um só filete de cor por
## nação, e o brilho guardado para motor e torre — nunca para o casco inteiro. Toda a geometria
## mora num filho "Casco": o nó raiz continua sendo a peça de xadrez que a sonda assina, e o
## balanço visual acontece no filho, sem mover um centímetro de tabuleiro.
func _make_ship(pos: Vector3, color: Color, scale_factor: float, ship_name: String,
		comando := false) -> Node3D:
	var ship := Node3D.new()
	ship.name = ship_name
	ship.position = pos
	ship.scale = Vector3.ONE * scale_factor
	add_child(ship)
	var casco := Node3D.new()
	casco.name = "Casco"
	ship.add_child(casco)
	var escape := ESCOAMENTO_HOSTIL if color == RED else ESCOAMENTO_ALIADO
	# Metal abaixo de 0.5 de propósito: no Compatibility a superfície metálica só brilha com
	# reflexão, e o nosso ambient é um céu quase preto. A 0.72 o casco não recebia o sol e a
	# linha inteira virava ponto de motor no escuro — o aço precisa de difusa para ter volume.
	var mat_hull := _material(ACO, 0.28, 0.62)
	var mat_steel := _material(ACO_ESCURO, 0.42, 0.5)
	var mat_trim := _material(color.darkened(0.35), 0.5, 0.3, color * 0.7)
	var mat_gun := _material(ACO_ESCURO.lightened(0.12), 0.8, 0.3, color * 0.4)
	var mat_engine := _material(escape.darkened(0.65), 0.6, 0.3, escape)
	var mat_flare := _glasm(Color(escape, 0.55))
	var mat_luz := _glasm(Color(escape, 0.75))
	var plumas: Array[MeshInstance3D] = []
	# Espinha comprida: é o volume que lê a nave como lâmina mesmo de fora do visor.
	_box(Vector3(0, 0, 0), Vector3(1.5, 0.66, 5.4), mat_hull, casco)
	# Proa em cone: sem caixa no nariz, a silhueta afila.
	_cylinder(Vector3(0, 0, -4.02), 0.74, 0.05, 2.6, mat_hull, casco, Vector3(-PI / 2, 0, 0), 8)
	_box(Vector3(0, 0.02, 2.5), Vector3(1.9, 0.78, 1.4), mat_steel, casco)
	_box(Vector3(0, 0.5, -0.8), Vector3(0.78, 0.34, 3.3), mat_steel, casco)
	# Torre de comando: na capitânia ela sobe e leva o mastro dourado, a silhueta que se
	# aprende a procurar no meio da linha.
	if comando:
		_box(Vector3(0, 1.05, 0.25), Vector3(0.7, 0.95, 1.45), mat_hull, casco)
		_box(Vector3(0, 1.75, 0.25), Vector3(0.16, 0.75, 0.16),
			_material(HUD_OURO.darkened(0.3), 0.6, 0.28, HUD_OURO * 0.5), casco)
	else:
		_box(Vector3(0, 0.86, 0.25), Vector3(0.62, 0.5, 1.15), mat_hull, casco)
	for lado in [-1.0, 1.0]:
		# Asa varrida para trás: o ângulo é o que separa cruzador de tijolo. A largura é a
		# conta: a linha fecha a 5 unidades de passo, então casco com envergadura acima de
		# ~4 unidades faz a frota se sobrepor e o tabuleiro vira uma mancha só.
		var asa := _box(Vector3(lado * 1.28, -0.02, 0.75), Vector3(1.5, 0.15, 2.6), mat_hull, casco)
		asa.rotation.y = lado * 0.42
		var filete := _box(Vector3(lado * 1.32, 0.09, 0.75), Vector3(1.42, 0.06, 0.34), mat_trim, casco)
		filete.rotation.y = lado * 0.42
		# Nacele gêmea, bocal fechado e pluma por trás do bocal.
		_cylinder(Vector3(lado * 1.72, 0.14, 1.5), 0.28, 0.2, 3.4, mat_steel, casco,
			Vector3(-PI / 2, 0, 0), 8)
		_cylinder(Vector3(lado * 1.72, 0.14, 3.35), 0.2, 0.17, 0.4, mat_engine, casco,
			Vector3(-PI / 2, 0, 0), 8)
		plumas.append(_quad(Vector3(lado * 1.72, 0.14, 3.9), 0.8, mat_flare, casco))
	# Torres por toda a dorsal: é a parte que acende com o `weapons` e apaga com ele.
	for z in [-1.9, -0.4, 1.1, 2.0]:
		_box(Vector3(0, 0.72, z), Vector3(0.4, 0.2, 0.6), mat_gun, casco)
	# Luz de proa: o mesmo billete da pluma, com material próprio para a presa reacender azul.
	_quad(Vector3(0, 0.0, -3.2), 0.3, mat_luz, casco)
	ship.set_meta("casco", casco)
	ship.set_meta("mat", {"hull": mat_hull, "steel": mat_steel, "trim": mat_trim,
		"gun": mat_gun, "engine": mat_engine, "flare": mat_flare, "luz": mat_luz})
	ship.set_meta("escape", escape)
	ship.set_meta("plumas", plumas)
	# O hostil encara a linha aliada: -Z é a proa de quem ataca, então a frota de fora gira
	# meia-volta em vez de virar as costas para a própria batalha.
	if color == RED:
		ship.rotation.y = PI
	return ship

## A leitura de dano é feita de material, não de geometria: o aço escurece e acende brasa com o
## casco, a pluma emagrece com o motor, a torre apaga com a arma e o filete com a tripulação.
## Roda só em casco vivo, mexe só em nós e recursos que já existem. Nenhum sorteio.
func _tune_ship_look(unit: Dictionary) -> void:
	var ship: Node3D = unit["node"]
	if not is_instance_valid(ship):
		return
	var mats: Dictionary = ship.get_meta("mat")
	var hull := clampf(float(unit["hp"]), 0.0, 100.0) / 100.0
	var engines := clampf(float(unit["engines"]), 0.0, 100.0) / 100.0
	var weapons := clampf(float(unit["weapons"]), 0.0, 100.0) / 100.0
	var crew := clampf(float(unit["crew"]), 0.0, 100.0) / 100.0
	var mat_hull: StandardMaterial3D = mats["hull"]
	mat_hull.albedo_color = ACO.lerp(CARVAO, (1.0 - hull) * 0.62)
	mat_hull.emission_enabled = true
	mat_hull.emission = BRASA
	# A brasa acende exatamente na porta dos 55% e sobe até o fundo do casco: a mesma porta que
	# `_resolve_volley` e `_give_order` já cobram (`hp > 55.0` recusa a abordagem). Ramp linear a
	# partir de 0 nesse ponto daria 0,0000 em 55% e 0,026 em 54% — invisível da ponte.
	mat_hull.emission_energy_multiplier = 0.0 if hull > 0.55 else 0.35 + (0.55 - hull) * 2.0
	var mat_engine: StandardMaterial3D = mats["engine"]
	mat_engine.emission_energy_multiplier = 0.2 + engines * engines * 2.8
	var mat_flare: StandardMaterial3D = mats["flare"]
	mat_flare.albedo_color = Color(ship.get_meta("escape"), 0.08 + engines * 0.5)
	for pluma in ship.get_meta("plumas"):
		var q: MeshInstance3D = pluma
		q.scale = Vector3(0.45 + engines * 1.05, 1.0, 0.45 + engines * 1.05)
	var mat_gun: StandardMaterial3D = mats["gun"]
	mat_gun.emission_energy_multiplier = 0.15 + weapons * 1.6
	var mat_trim: StandardMaterial3D = mats["trim"]
	mat_trim.emission_energy_multiplier = 0.1 + crew * 0.9
	# Balanço de deriva no filho "Casco": a peça de xadrez não se move, quem ondula é a
	# silhueta. `position` da raiz continua sendo a assinatura que as sondas conferem.
	var casco: Node3D = ship.get_meta("casco")
	casco.position.y = sin(battle_clock * 0.55 + ship.position.x * 0.35) * 0.1
	casco.rotation.z = sin(battle_clock * 0.33 + ship.position.z * 0.21) * 0.045

## Destroço que permanece no tabuleiro: casco carvão, brasa baixa, luzes mortas e a inclinação
## de quem perdeu propulsão. Some a leitura de vida, não a nave — esconder o corpo tirava a
## baixa do campo de visão da ponte.
func _mark_wreck(ship: Node3D) -> void:
	if not is_instance_valid(ship):
		return
	var mats: Dictionary = ship.get_meta("mat")
	for chave in mats:
		var mat: StandardMaterial3D = mats[chave]
		mat.emission_energy_multiplier = 0.0
	var mat_hull: StandardMaterial3D = mats["hull"]
	mat_hull.albedo_color = CARVAO
	mat_hull.emission = BRASA
	mat_hull.emission_energy_multiplier = 0.14
	# Billete aditivo não obedece a `emission_energy`: o que apaga a luz é o alfa.
	(mats["flare"] as StandardMaterial3D).albedo_color.a = 0.0
	(mats["luz"] as StandardMaterial3D).albedo_color.a = 0.0
	for pluma in ship.get_meta("plumas"):
		var q: MeshInstance3D = pluma
		q.scale = Vector3.ONE * 0.2
	var casco: Node3D = ship.get_meta("casco")
	casco.rotation.z = 0.42
	casco.rotation.x = -0.18
	_spawn_explosion(ship.position, ship.get_meta("escape"))

## Detonação em billets aditivos com deslocamentos fixos: cinco clarões que abrem e apagam em
## meio segundo. Nada aqui sorteia — é o que separa efeito visual de regressão de economia.
func _spawn_explosion(pos: Vector3, cor: Color) -> void:
	# Um pedido por detonação, não cinco: os billets são o clarão, o ouvido não precisa
	# de cinco estouros para o mesmo casco que afunda.
	audio.efeito("EXPLOSAO")
	for i in range(DETONACAO.size()):
		var estouro := _flare(pos + DETONACAO[i], 1.4 + float(i) * 0.4, Color(cor, 0.85), self)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(estouro, "scale", Vector3.ONE * (3.2 + float(i) * 0.9), 0.5)
		tween.tween_property(estouro.material_override, "albedo_color:a", 0.0, 0.5)
		tween.chain().tween_callback(estouro.queue_free)

## ---- Ruína da ponte ----

## Ignição da morte: tudo o que é escrito UMA vez, no quadro em que o casco fecha. Telas, deck,
## holografia e as duas luzes mudam de estado aqui e não por quadro — a mesma disciplina do flanco
## de `ponte_em_alarme`, porque escrever material em loop é a ponte piscando para a GPU. O timão
## morre junto: `throttle` a zero é o que faz o HUD ler 0% num casco que ainda se move por inércia.
func _acender_ruina() -> void:
	ponte_condenada = true
	ponte_sem_energia = true
	throttle = 0.0
	ponte_rumo_base = bridge_rig.rotation.y
	# Cada adernamento rampa a distância que TEM pela frente, não o valor do teto: é o que faz
	# `MORTE_DURACAO` signifique a mesma coisa para uma ponte levelada e para uma já inclinada.
	ponte_taxa_rolagem = absf(MORTE_TILT_ROLAGEM - bridge_rig.rotation.z) / MORTE_DURACAO
	ponte_taxa_arfagem = absf(MORTE_TILT_ARFAGEM - bridge_rig.rotation.x) / MORTE_DURACAO
	ponte_taxa_guinada = absf(MORTE_TILT_GUIRADA) / MORTE_DURACAO
	if is_instance_valid(ponte_luz_trabalho):
		ponte_energia_trabalho = ponte_luz_trabalho.light_energy
	if is_instance_valid(ponte_luz_fria):
		ponte_energia_fria = ponte_luz_fria.light_energy
	if is_instance_valid(ponte_telas):
		ponte_telas.emission = COR_TELA_MORTA
		ponte_telas.emission_energy_multiplier = 0.0
	var mats: Dictionary = bridge_rig.get_meta("mat")
	for chave in ["piso", "casco", "trim", "ouro"]:
		var mat: StandardMaterial3D = mats[chave]
		mat.albedo_color = mat.albedo_color.darkened(CORTE_RUINA)
		mat.emission_energy_multiplier = 0.0
	# A holografia cai com o projetor. Esconder, nunca libertar: `holo_root` tem de continuar com a
	# mesma conta de filhos para as asserções de blip por casco vivo, e um `queue_free` na mesa
	# obrigaria cada sonda vizinha a aprender a lidar com uma ponte sem mesa.
	for nos in [holo_root, holo_anel, holo_capitania, holo_setor]:
		if is_instance_valid(nos):
			(nos as Node3D).visible = false
	# O alarme de fim de combate e a trilha cortada acontecem no quadro da morte, não até 1,6 s
	# depois na próxima salva — e `batalha_encerrada` passa a valer já aqui, que é o que impede o
	# relatório de rotina de por "contato hostil confirmado" em cima de um casco que acabou de afundar.
	_encerra_batalha()

## Um clarão de fase. Dentro do rig quando `fora` é falso — é o estouro visto de dentro da ponte,
## colado ao teto e aos costados; nascido na cena quando é o casco se descolando lá fora, porque
## detrito preso ao rig seria a própria nave arrastando o estilhaço enquanto aderna.
func _acende_clarao(fase: Dictionary) -> void:
	var de_dentro := not bool(fase["fora"])
	var onde: Vector3 = fase["pos"] if de_dentro \
		else bridge_rig.position + (fase["pos"] as Vector3)
	var pai: Node = bridge_rig if de_dentro else self
	var billet := _flare(onde, float(fase["size"]), Color(BRASA, 0.9), pai)
	morte_claroes.append({"no": billet, "nasc": morte_t})
	audio.efeito(String(fase["som"]))

## A ruína anda no relógio que o chamador entrega, não em `create_tween` de tempo real: é só assim
## uma sonda headless pode avançar a morte em passo cravado e assinar posição, luz, atitude e
## clarão quadro a quadro. Consome zero sorteios — nem de `rng`, nem de `visual_rng` — porque a
## morte da ponte não pode reescrever a cauda de combate de ninguém.
func _atualizar_ruina(delta: float) -> void:
	if not ponte_condenada:
		_acender_ruina()
	morte_t += delta
	while morte_fase < MORTE_FASES.size() and morte_t >= float(MORTE_FASES[morte_fase]["t"]):
		_acende_clarao(MORTE_FASES[morte_fase])
		morte_fase += 1
	var vivos: Array = []
	for entrada in morte_claroes:
		var billet: MeshInstance3D = entrada["no"]
		var idade := morte_t - float(entrada["nasc"])
		if not is_instance_valid(billet):
			continue
		if idade >= MORTE_CLARAO_VIDA:
			billet.queue_free()
			continue
		var progresso := idade / MORTE_CLARAO_VIDA
		billet.scale = Vector3.ONE * (1.0 + progresso * 3.0)
		(billet.material_override as StandardMaterial3D).albedo_color.a = 0.9 * (1.0 - progresso)
		vivos.append(entrada)
	morte_claroes = vivos
	if is_instance_valid(ponte_luz_trabalho):
		ponte_luz_trabalho.light_energy = ponte_energia_trabalho \
			* clampf(1.0 - morte_t / MORTE_APAGAO, 0.0, 1.0)
	if is_instance_valid(ponte_luz_fria):
		var ultima_fase := float(MORTE_FASES[MORTE_FASES.size() - 1]["t"])
		if morte_t >= ultima_fase:
			ponte_luz_fria.light_energy = 0.0
		else:
			ponte_luz_fria.light_energy = ponte_energia_fria \
				* (MORTE_STROBO_PICO if fmod(morte_t, MORTE_STROBO) < MORTE_STROBO * 0.4 else 0.05)
	# Tremor só na câmera filha. A posição do rig é a assinatura que blip, mesa e abalroamento
	# conferem; um tremor nela seria o casco teleportando a cada quadro.
	if is_instance_valid(ponte_camera):
		var amplitude := MORTE_TREMOR * clampf(1.0 - morte_t / MORTE_TREMOR_FIM, 0.0, 1.0)
		ponte_camera.position = ponte_camera_base + Vector3(
			sin(morte_t * 61.0), cos(morte_t * 47.0), sin(morte_t * 83.0) * 0.5) * amplitude
	# Os três adernamentos rampam na taxa cravada na ignição, então `move_toward` fecha em cima do
	# teto exato no fim da sequência e segura ali: um casco sem reactor não volta a içar.
	bridge_rig.rotation.z = move_toward(bridge_rig.rotation.z, MORTE_TILT_ROLAGEM,
		delta * ponte_taxa_rolagem)
	bridge_rig.rotation.x = move_toward(bridge_rig.rotation.x, MORTE_TILT_ARFAGEM,
		delta * ponte_taxa_arfagem)
	bridge_rig.rotation.y = move_toward(bridge_rig.rotation.y, ponte_rumo_base + MORTE_TILT_GUIRADA,
		delta * ponte_taxa_guinada)
	# Deriva fria: o casco conserva a última velocidade medida pelo timão e não tem motor para
	# refazê-la. Na borda do campo ele encosta e para, e a velocidade registrada fica sendo a
	# última leitura honesta — não um zero inventado pelo muro.
	var arrasto := bridge_rig.position + capital_velocity * delta
	arrasto.x = clampf(arrasto.x, -MAP_X, MAP_X)
	arrasto.y = clampf(arrasto.y, -MAP_Y, MAP_Y)
	arrasto.z = clampf(arrasto.z, MAP_Z_FAR, MAP_Z_NEAR)
	bridge_rig.position = arrasto

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 64
	top.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.026, 0.042, 0.92), HUD_OURO.darkened(0.45)))
	layer.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 24)
	top.add_child(top_row)
	var title := Label.new()
	title.text = "I R O N   S T A R S   //   FLEET COMMAND"
	title.add_theme_color_override("font_color", HUD_OURO.lightened(0.35))
	title.add_theme_font_size_override("font_size", 19)
	top_row.add_child(title)
	speed_label = Label.new()
	speed_label.text = "VELOCIDADE +000%  //  SUBIDA +000  //  CASCO DA CAPITÂNIA 100%"
	speed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(speed_label)
	pause_button = _add_button(top_row, "PAUSAR [ESPAÇO]", _toggle_pause)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 94)
	panel.custom_minimum_size = Vector2(396, 620)
	panel.size = Vector2(396, 620)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.016, 0.024, 0.04, 0.9), Color(0.1, 0.42, 0.62)))
	layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(372, 600)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	painel_scroll = scroll
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 280
	col.add_theme_constant_override("separation", 8)
	scroll.add_child(col)
	var head := Label.new()
	head.text = "HOLOGRAMA TÁTICO"
	head.add_theme_font_size_override("font_size", 18)
	head.add_theme_color_override("font_color", Color(0.35, 0.82, 1.0))
	col.add_child(head)
	command_label = Label.new()
	command_label.text = "FROTA: 6 NAVES | FORMAÇÃO: LINHA"
	command_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(command_label)
	var scope_title := Label.new()
	scope_title.text = "UNIDADES SOB COMANDO"
	col.add_child(scope_title)
	scope_selector = OptionButton.new()
	scope_selector.item_selected.connect(_on_scope_selected)
	col.add_child(scope_selector)
	var target_title := Label.new()
	target_title.text = "ALVO HOSTIL"
	col.add_child(target_title)
	target_selector = OptionButton.new()
	target_selector.item_selected.connect(_on_target_selected)
	col.add_child(target_selector)
	var subsystem_title := Label.new()
	subsystem_title.text = "SUBSISTEMA DO ALVO"
	col.add_child(subsystem_title)
	subsystem_selector = OptionButton.new()
	for subsystem in ["CASCO", "MOTORES", "ARMAS", "TRIPULAÇÃO"]:
		subsystem_selector.add_item(subsystem)
	col.add_child(subsystem_selector)
	var protect_title := Label.new()
	protect_title.text = "UNIDADE A PROTEGER / ESCOLTAR"
	col.add_child(protect_title)
	protected_selector = OptionButton.new()
	protected_selector.item_selected.connect(_on_protected_selected)
	col.add_child(protected_selector)
	var destination_title := Label.new()
	destination_title.text = "POSIÇÃO DE DESTINO (X / Z)"
	col.add_child(destination_title)
	var destination_row := HBoxContainer.new()
	position_x_input = SpinBox.new()
	position_x_input.min_value = -80
	position_x_input.max_value = 80
	position_x_input.step = 5
	position_x_input.value = 0
	position_x_input.prefix = "X "
	position_z_input = SpinBox.new()
	position_z_input.min_value = -160
	position_z_input.max_value = 20
	position_z_input.step = 5
	position_z_input.value = -65
	position_z_input.prefix = "Z "
	destination_row.add_child(position_x_input)
	destination_row.add_child(position_z_input)
	col.add_child(destination_row)
	# ---- Grupos recolhíveis. Um clique no cabeçalho abre a categoria; abrir uma fecha a outra.
	# O botão "CONCENTRAR FOGO" que existia aqui chamava exatamente o mesmo `_give_order("ATACAR")`
	# do botão de ataque, então era ruído de painel, não comando: saiu de cena com o agrupamento.
	# Voltou agora, mas como controle de densidade de verdade — ele mexe no disco de impacto, não na
	# ordem do navio.
	var grupo_ataque := _add_grupo(col, "ATAQUE")
	_add_button(grupo_ataque, "ATACAR ALVO / SUBSISTEMA", func(): _give_order("ATACAR"))
	_add_button(grupo_ataque, "ABORDAR ALVO DANIFICADO", func(): _give_order("ABORDAR"))
	_add_button(grupo_ataque, "CONCENTRAR FOGO — disco estreito", func(): _ajustar_fogo(-1))
	_add_button(grupo_ataque, "DISPERSAR FOGO — disco largo", func(): _ajustar_fogo(1))
	var grupo_postura := _add_grupo(col, "POSTURA")
	_add_button(grupo_postura, "AGRESSIVO: AVANÇAR", func(): _give_order("AVANÇAR"))
	_add_button(grupo_postura, "DEFENSIVO: RECUAR", func(): _give_order("RECUAR"))
	_add_button(grupo_postura, "MANTER POSIÇÃO", func(): _give_order("MANTER"))
	_add_button(grupo_postura, "ESCOLTAR CAPITÂNIA", func(): _give_order("ESCOLTAR"))
	_add_button(grupo_postura, "RESERVA TÁTICA", func(): _give_order("RESERVA"))
	var grupo_formacao := _add_grupo(col, "FORMAÇÕES")
	_add_button(grupo_formacao, "LINHA — fogo largo em duas fileiras", func(): _set_formation("LINHA"))
	_add_button(grupo_formacao, "COLUNA — passagem em fila", func(): _set_formation("COLUNA"))
	_add_button(grupo_formacao, "CUNHA — ápice adiantado", func(): _set_formation("CUNHA"))
	_add_button(grupo_formacao, "ANEL — fogo em todas as direções", func(): _set_formation("ANEL"))
	var grupo_manobra := _add_grupo(col, "MANOBRA")
	_add_button(grupo_manobra, "MOVER PARA POSIÇÃO", func(): _give_order("MOVER"))
	_add_button(grupo_manobra, "DISPERSAR TROPAS", func(): _give_order("DISPERSAR"))
	_add_button(grupo_manobra, "AGRUPAR TROPAS", func(): _give_order("AGRUPAR"))
	var grupo_reparo := _add_grupo(col, "REPAROS")
	_add_button(grupo_reparo, "PRIORIDADE MOTORES", func(): _set_repair_priority("MOTORES"))
	_add_button(grupo_reparo, "PRIORIDADE ARMAS", func(): _set_repair_priority("ARMAS"))
	_add_button(grupo_reparo, "PRIORIDADE CASCO", func(): _set_repair_priority("CASCO"))
	_add_button(grupo_reparo, "PRIORIDADE TRIPULAÇÃO", func(): _set_repair_priority("TRIPULAÇÃO"))
	_add_button(grupo_reparo, "AUTOMÁTICO EQUILIBRADO", func(): _set_repair_priority("AUTO"))
	var grupo_rec := _add_grupo(col, "RECONHECIMENTO")
	_add_button(grupo_rec, "SONDAS DE RECONHECIMENTO", func(): _give_order("RECONHECER"))
	var grupo_cenario := _add_grupo(col, "CENÁRIO")
	_add_button(grupo_cenario, "CAMPO ABERTO — sem obstáculo", func(): _montar_cenario("ABERTO"))
	_add_button(grupo_cenario, "CINTURÃO DE ASTEROIDES — barreira", func(): _montar_cenario("CINTURAO"))
	_add_button(grupo_cenario, "POÇO GRAVITACIONAL — não aproxime", func(): _montar_cenario("POCO"))
	_add_button(grupo_cenario, "ESTRELA ATIVA — armas quentes", func(): _montar_cenario("ESTRELA"))
	# Grupo TRILHA: o que toca na ponte é gosto do comandante, não tática. Os quatro botões
	# trocam o arquivo carregado no `PonteSonora` e não movem número nenhum do jogo — nem
	# casco, nem dano, nem um sorteio de `rng`. O "SILÊNCIO" existe porque no vácuo a
	# alternativa razoável a ouvir música é não ouvir nada, e um botão de mudo valeria mais
	# que uma discussão sobre qual das três faixas combina com a batalha.
	var grupo_trilha := _add_grupo(col, "TRILHA")
	_add_button(grupo_trilha, "SILÊNCIO — nenhuma faixa", func(): _escolher_trilha("SILENCIO"))
	_add_button(grupo_trilha, "ODE À ALEGRIA — Beethoven", func(): _escolher_trilha("ALEGRIA"))
	_add_button(grupo_trilha, "LARGO DO NOVO MUNDO — Dvorak", func(): _escolher_trilha("NOVO_MUNDO"))
	_add_button(grupo_trilha, "SCHERZO DO NOVO MUNDO — Dvorak", func(): _escolher_trilha("SCHERZO"))
	# O grupo aberto na abertura é escolhido aqui, não por `_toggle_grupo`, porque o relatório
	# ainda não existe nesta altura da montagem do painel.
	if group_bodies.has(grupo_aberto):
		(group_bodies[grupo_aberto] as Control).visible = true
		(group_heads[grupo_aberto] as Button).text = "▾  " + grupo_aberto
	var hint := Label.new()
	hint.text = ("W avante  •  S ré (a ré tem teto)\nA / D guinada  •  ↑ / ↓ arfagem  •  "
		+ "Q / E rolagem\nR sobe  •  V desce  •  ESPAÇO pausa tática")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.65, 0.78, 0.9))
	col.add_child(hint)
	var report_panel := PanelContainer.new()
	report_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	report_panel.offset_top = -58
	report_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.026, 0.04, 0.88), HUD_OURO.darkened(0.5)))
	layer.add_child(report_panel)
	report_label = Label.new()
	report_label.text = "PONTE DE COMANDO ONLINE  //  Contatos hostis detectados à frente."
	report_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	report_panel.add_child(report_label)
	# Os três seletores leem a frota real; construir os itens por aqui mantém a lista
	# verdadeira quando uma presa é incorporada.
	_rebuild_selectors()

func _add_button(parent: Node, text_value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 36)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0))
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.035, 0.09, 0.15, 0.96), Color(0.12, 0.42, 0.62)))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.06, 0.2, 0.3, 1), Color(0.3, 0.75, 1.0)))
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _panel_style(bg: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _material(color: Color, metal: float = 0.2, rough: float = 0.45, glow: Color = Color.BLACK) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = rough
	if glow != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = glow
		mat.emission_energy_multiplier = 1.4
	return mat

func _box(pos: Vector3, size: Vector3, mat: Material, parent: Node = null) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = mat
	if parent == null:
		add_child(mesh_instance)
	else:
		parent.add_child(mesh_instance)
	return mesh_instance

## Prisma com os dois raios: é com ele que a proa afila e o bocal de motor fecha em disco.
## Em `_cylinder` o eixo local é +Y, então `rot = Vector3(-PI/2, 0, 0)` aponta o topo para -Z.
func _cylinder(pos: Vector3, r_base: float, r_top: float, height: float, mat: Material,
		parent: Node, rot: Vector3 = Vector3.ZERO, radial: int = 10) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = r_base
	mesh.top_radius = r_top
	mesh.height = height
	# A propriedade se chama `radial_segments`: o nome errado não falha no parse, aborta a
	# função em runtime e devolve Nil — a mesa holográfica inteira desapareceu assim por uma
	# rodada, com as três sondas de lógica passando verdes.
	mesh.rings = 2
	mesh.radial_segments = radial
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.rotation = rot
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	return mesh_instance

## Bilhete aditivo sempre de frente para a câmera: sem pós-processamento caro é assim que o
## motor, o lance e a explosão estouram no glow do Compatibility.
func _flare(pos: Vector3, size: float, color: Color, parent: Node) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(size, size)
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	return mesh_instance

## Mesmo billet de `_flare`, mas com o material vindo de fora: é assim que a pluma de cada
## motor queima sozinha (o material pertence à nave) sem criar material novo por quadro.
func _quad(pos: Vector3, size: float, mat: Material, parent: Node) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(size, size)
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	return mesh_instance

## Registra o timão no InputMap antes de qualquer UI. Fazer isso em código (e não no
## `project.godot`) mantém a tabela de teclas ao lado de quem a lê e poupa o arquivo de
## configuração de uma serialização `Object(InputEventKey,...)` que muda com o motor.
func _registra_voo() -> void:
	for acao: String in VOO_ACOES:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao, 0.0)
		var tecla := InputEventKey.new()
		tecla.keycode = VOO_ACOES[acao]
		InputMap.action_add_event(acao, tecla)
		var fisica := InputEventKey.new()
		fisica.physical_keycode = VOO_ACOES[acao]
		InputMap.action_add_event(acao, fisica)

## ---- Cenários ----

## Troca o mapa no meio da batalha. Desmontar antes de montar é o que garante que uma rocha não
## conta duas vezes: sem isto, trocar de CINTURAO para CINTURAO dobraria as barreiras e o casco
## seria empurrado por duas pedras no mesmo ponto.
func _montar_cenario(nome: String) -> void:
	if not CENARIOS.has(nome):
		return
	_desmontar_cenario()
	cenario_atual = nome
	if nome == "CINTURAO":
		_montar_cinturao()
	elif nome == "POCO":
		_montar_poco()
	elif nome == "ESTRELA":
		_montar_estrela()
	_pintar_marcas_cenario()
	if is_instance_valid(report_label):
		report_label.text = _nota_cenario()


## Troca a faixa clássica da ponte. A escolha é de gosto: nenhum número do jogo se move aqui
## — a sonda do áudio confere que a cauda de `rng` fica idêntica antes e depois de um
## `escolher_trilha`. Se a trilha já estava tocando, a nova entra no lugar dela sem o
## comandante precisar pedir o play de novo; se estava parada, continua parada.
func _escolher_trilha(id: String) -> void:
	if not audio.escolher_trilha(id):
		return
	if is_instance_valid(report_label):
		report_label.text = "TRILHA: %s // %s" % [audio.trilha_nome(),
			"em laço na ponte" if audio.trilha_ao_vivo() else "em espera"]


func _desmontar_cenario() -> void:
	for marca in holo_cenario:
		if is_instance_valid(marca):
			marca.queue_free()
	holo_cenario.clear()
	rochas.clear()
	# O contador volta a zero com o mapa: sem isto a segunda montagem do cinturão da partida acordaria
	# com ids 15..28 e as janelas de abalroamento antigas continuariam travando dano em pedras novas.
	rocha_proxima_id = 0
	poco_ativo = false
	estrela_ativa = false
	_desdobrar_ceu()
	if is_instance_valid(cenario_root):
		for filho in cenario_root.get_children():
			filho.queue_free()
	poco_disco = null
	poco_lente = null


func _garantir_cenario_root() -> Node3D:
	if not is_instance_valid(cenario_root):
		cenario_root = Node3D.new()
		cenario_root.name = "Cenario"
		add_child(cenario_root)
	return cenario_root


## O cinturão: pedras em leque entre as duas linhas, em banda determinística. A ordem importa — a
## primeira rocha já nasce adiante da linha aliada e a última atrás da hostil, de modo que atravessar
## o centro é sempre uma escolha, nunca o único caminho. A velocidade também é de banda: direção no
## ângulo áureo do índice e módulo escalonado, sem um sorteio, porque a correnteza tem de ser
## conferível e a partida não pode acordar com um mapa diferente a cada carga.
func _montar_cinturao() -> void:
	for i in range(ROCHA_QTDE):
		var ang := float(i) * 2.39996
		var x := cos(ang) * ROCHA_LEQUE_X * (0.35 + 0.13 * float(i % 5))
		var y := sin(ang * 1.7) * ROCHA_Y_LEQUE
		var z := ROCHA_Z_INICIAL - float(i) * ROCHA_Z_PASSO
		var raio := ROCHA_RAIO_BASE + float(i % 4) * ROCHA_RAIO_DEGRAU
		var vel := Vector3(cos(ang * 0.6 + 1.1), sin(ang * 0.9) * 0.35, sin(ang * 0.6 + 1.1)) \
			* ROCHA_DERIVA * (0.55 + 0.15 * float(i % 4))
		_nova_rocha(Vector3(x, y, z), raio, vel, 0, ang)


## Corpo novo no cinturão: nó pintado na cena e marca na mesa, criados juntos porque as duas contas
## têm de fechar com `rochas.size()` no mesmo quadro. Os materiais são criados uma vez e
## reaproveitados — a fratura pode gerar dezenas de pedras numa batalha comprida.
func _nova_rocha(pos: Vector3, raio: float, vel: Vector3, geracao: int, fase: float) -> Dictionary:
	var raiz := _garantir_cenario_root()
	if rocha_material == null:
		rocha_material = _material(ACO_ESCURO, 0.3, 0.9)
		rocha_marca_material = _material(Color(0.32, 0.34, 0.38), 0.1, 0.9)
	var bloco := _box(pos, Vector3(raio * 1.7, raio * 1.3, raio * 1.5), rocha_material, raiz)
	bloco.rotation = Vector3(fase * 0.7, fase, fase * 0.31)
	rocha_proxima_id += 1
	# A marca só nasce se a mesa existir: as sondas montam cenário antes de a UI fechar, e um
	# `null` aqui é pedra sem holograma, não pedra ausente do tabuleiro.
	var marca: MeshInstance3D = null
	if is_instance_valid(holo_root):
		marca = _cylinder(_holo_de(pos), 0.06, 0.06, 0.14, rocha_marca_material, holo_root,
			Vector3.ZERO, 8)
	var rocha := {
		"no": bloco,
		"marca": marca,
		"id": rocha_proxima_id,
		"pos": pos,
		"vel": vel,
		"fase": fase,
		"raio": raio,
		"integridade": raio * ROCHA_INTEGRIDADE_POR_RAIO,
		"geracao": geracao,
	}
	rochas.append(rocha)
	if is_instance_valid(marca):
		holo_cenario.append(marca)
	return rocha


## A correnteza, quadro a quadro: empuxo errático, integração, quina de banda e o encontro entre
## pedras. Zero sorteio nos três — `battle_clock` e o índice mandam, e é por isso que a sonda pode
## recalcular a posição esperada de cada pedra sem espelhar gerador nenhum.
func _derivar_rochas(delta: float) -> void:
	if rochas.is_empty():
		return
	for rocha in rochas:
		var fase := float(rocha["fase"])
		# O empuxo gira no tempo com fase própria por pedra: é o que faz a trajetória errar de rumo
		# sem virar caminhada reta, e sem precisar de um número sorteado por quadro.
		var relogio := battle_clock * ROCHA_TAXA_ERRATICA + fase
		var empuxo := Vector3(sin(relogio), sin(relogio * 1.7) * 0.4, cos(relogio * 0.8)) \
			* ROCHA_ERRATICIDADE
		var vel: Vector3 = rocha["vel"] + empuxo * delta
		if vel.length() > ROCHA_VETO_TETO:
			vel = vel.normalized() * ROCHA_VETO_TETO
		var pos: Vector3 = rocha["pos"] + vel * delta
		# Quina de banda: a pedra bate e volta. Sem isto o cinturão atravessa o mapa e deixa de ser
		# barreira — correnteza que dissolve não cobra rota nenhuma.
		if pos.x < -ROCHA_BANDA_X or pos.x > ROCHA_BANDA_X:
			vel.x = -vel.x
			pos.x = clampf(pos.x, -ROCHA_BANDA_X, ROCHA_BANDA_X)
		if pos.y < -ROCHA_BANDA_Y or pos.y > ROCHA_BANDA_Y:
			vel.y = -vel.y
			pos.y = clampf(pos.y, -ROCHA_BANDA_Y, ROCHA_BANDA_Y)
		if pos.z < ROCHA_BANDA_Z_FUNDO or pos.z > ROCHA_BANDA_Z_FRENTE:
			vel.z = -vel.z
			pos.z = clampf(pos.z, ROCHA_BANDA_Z_FUNDO, ROCHA_BANDA_Z_FRENTE)
		rocha["vel"] = vel
		rocha["pos"] = pos
	# O teto é conta de fechar de quadro, não de integração. O corte lá em cima vale para o empuxo;
	# aqui ele vale para o impulso elástico, que pode jogar uma pedra miúda acima do que a correnteza
	# permite — e 4,2 u/s é o número que a ponte anuncia no painel, não uma média. Só se percorre o
	# cinturão quando o quadro de fato teve contato: em mar aberto a conta não roda.
	if _peder_rochas():
		for rocha_certa in rochas:
			var vel_certa: Vector3 = rocha_certa["vel"]
			if vel_certa.length() > ROCHA_VETO_TETO:
				rocha_certa["vel"] = vel_certa.normalized() * ROCHA_VETO_TETO
	for rocha in rochas:
		var no: MeshInstance3D = rocha["no"]
		var pos: Vector3 = rocha["pos"]
		if is_instance_valid(no):
			no.global_position = pos
			no.rotation += Vector3(0.0, ROCHA_GIRO * float(rocha["geracao"] + 1), ROCHA_GIRO * 0.5) \
				* delta
		var marca: MeshInstance3D = rocha["marca"]
		# Espaço local da mesa: a marca nasce filha de `holo_root` em `_holo_de(pos)`, então somar aqui
		# a posição da raia de novo desloca todas as marcas pelo offset do holograma a cada quadro.
		if is_instance_valid(marca) and is_instance_valid(holo_root):
			marca.position = _holo_de(pos)


## Pedra com pedra: quem se choca muda de rumo. Troca-se só a componente normal da velocidade, que é
## o termo que um choque realmente carrega; a tangencial fica, porque asteroide não tem freio. A
## separação posicional vem antes do impulso — sem ela as duas continuam sobrepostas no quadro
## seguinte e trocam de novo, o que produziria um trem de energia do nada.
##
## O retorno diz se alguma pedra encostou em outra neste quadro. Não é enfeite: é como o laço de
## deriva sabe quando o teto de velocidade precisa ser cobrado de novo, sem percorrer o cinturão
## inteiro em cada quadro de mar aberto.
func _peder_rochas() -> bool:
	var mudou := false
	for i in range(rochas.size()):
		for j in range(i + 1, rochas.size()):
			var a: Dictionary = rochas[i]
			var b: Dictionary = rochas[j]
			var entre: Vector3 = b["pos"] - a["pos"]
			var soma := float(a["raio"]) + float(b["raio"])
			var distancia := entre.length()
			if distancia >= soma or distancia < 0.0001:
				continue
			var normal := entre / distancia
			var sobra := (soma - distancia) * 0.5
			a["pos"] = a["pos"] - normal * sobra
			b["pos"] = b["pos"] + normal * sobra
			mudou = true
			var va: Vector3 = a["vel"]
			var vb: Vector3 = b["vel"]
			var aproxima := (vb - va).dot(normal)
			if aproxima >= 0.0:
				continue
			# Troca de componente normal ponderada pela área da seção: pedra grande não sai voando
			# porque uma miúda encostou nela.
			var ma := float(a["raio"]) * float(a["raio"])
			var mb := float(b["raio"]) * float(b["raio"])
			var novo_a := va + normal * (2.0 * mb / (ma + mb)) * aproxima
			var novo_b := vb - normal * (2.0 * ma / (ma + mb)) * aproxima
			a["vel"] = novo_a
			b["vel"] = novo_b
	return mudou


## Poço: a sombra, o disco de matéria caindo e a dobra do céu atrás dele. O aro luminoso continua
## sendo a régua do alcance — é ele que o comandante lê como "não passe daqui", e a distância a que
## o puxo começa a mover o casco. O resto é lente gravitacional: a imagem do lado de lá do disco
## dobra por cima e por baixo da sombra, e as estrelas de fundo são empurradas para fora do raio de
## Einstein, deixando um buraco escuro cercado de céu mais apertado. Nada disso tem corpo, dano ou
## sorteio — `POCO_ALCANCE`, `POCO_PUXO` e `POCO_HORIZONTE` mandam exatamente como antes.
func _montar_poco() -> void:
	var raiz := _garantir_cenario_root()
	poco_ativo = true
	# A sombra: um casco preto sem luz nenhuma, do tamanho exato do horizonte. Esferas com material
	# sombreado ficam cinza sob a luz da ponte, e uma sombra cinza não é um buraco negro.
	var sombra := StandardMaterial3D.new()
	sombra.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sombra.albedo_color = Color(0.0, 0.0, 0.0, 1.0)
	sombra.roughness = 1.0
	_esfera(POCO_POS, POCO_HORIZONTE, sombra, raiz, 32)
	_montar_disco_de_acrescao(raiz)
	_montar_arco_de_lente(raiz)
	# Dobrar o quadro já na montagem: o painel anuncia quantas estrelas saíram do miolo no mesmo
	# quadro em que o cenário entra, e não um quadro depois.
	_lentificar_quadro()


## Faixas concêntricas de matéria caindo, todas num só MultiMesh. O disco é inclinado 0,17 rad
## porque visto de gume puro ele não pinta um pixel; o brilho de cada amostra é cor de instância,
## nunca material novo por amostra. O feixe relativístico entra como `1 ± POCO_DOPPLER · cos`: um
## lado do disco chega mais claro que o outro, que é como se lê a rotação.
func _montar_disco_de_acrescao(raiz: Node3D) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _quadro_aditivo()
	var total := POCO_DISCO_FAIXAS * POCO_DISCO_AMOSTRAS
	mm.instance_count = total
	var incl := Basis(Vector3.RIGHT, POCO_DISCO_INCLINACAO)
	for faixa in range(POCO_DISCO_FAIXAS):
		var t := 0.0
		if POCO_DISCO_FAIXAS > 1:
			t = float(faixa) / float(POCO_DISCO_FAIXAS - 1)
		var raio := POCO_HORIZONTE * lerpf(POCO_DISCO_INTERNO, POCO_DISCO_EXTERNO, t)
		# A faixa de dentro é branca e fina; a de fora é brasa e larga. É a ordem da temperatura do
		# disco, não um capricho de cor.
		var cor := Color(1.0, lerpf(0.42, 0.86, 1.0 - t), lerpf(0.16, 0.62, 1.0 - t))
		for i in range(POCO_DISCO_AMOSTRAS):
			var ang := float(i) * TAU / float(POCO_DISCO_AMOSTRAS) + float(faixa) * 0.11
			var ponto := POCO_POS + incl * (Vector3(cos(ang), 0.0, sin(ang)) * raio)
			var feixe := 1.0 + POCO_DOPPLER * cos(ang)
			var tam := 1.5 + 1.9 * t
			mm.set_instance_transform(faixa * POCO_DISCO_AMOSTRAS + i,
				Transform3D(incl.scaled(Vector3(tam, tam, tam)), ponto))
			mm.set_instance_color(faixa * POCO_DISCO_AMOSTRAS + i,
				Color(cor.r * feixe, cor.g * feixe, cor.b * feixe, 0.72 - 0.16 * t))
	poco_disco = MultiMeshInstance3D.new()
	poco_disco.name = "DiscoDeAcrecao"
	poco_disco.multimesh = mm
	raiz.add_child(poco_disco)


## O aro de fótons e os dois arcos lentificados, num único MultiMesh preso a um nó que vira o plano
## para a câmera. A imagem lentificada é do observador, não do mundo: se o poço passar para a
## beirada do visor, o aro continua redondo em volta da sombra.
func _montar_arco_de_lente(raiz: Node3D) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _quadro_aditivo()
	mm.instance_count = POCO_ARCO_AMOSTRAS * 3
	# `PI/2` em torno de +X deita o plano do quadro (normal +Y) sobre o XY do nó, que é o plano do
	# visor depois de `look_at`.
	var deitado := Basis(Vector3.RIGHT, PI / 2.0)
	var no_arco := 0
	# 1) Aro de fótons: um fio colado na borda da sombra, o número mais perto do horizonte que a
	#    lente entrega. É a assinatura do buraco negro — sem ele a sombra é uma bola pintada.
	for i in range(POCO_ARCO_AMOSTRAS):
		var ang := float(i) * TAU / float(POCO_ARCO_AMOSTRAS)
		var raio := POCO_HORIZONTE * POCO_ANEL_FOTON
		var feixe := 1.0 + POCO_DOPPLER * 0.5 * cos(ang)
		mm.set_instance_transform(no_arco, Transform3D(deitado.scaled(Vector3(0.62, 0.62, 0.62)),
			Vector3(cos(ang), sin(ang), 0.0) * raio))
		mm.set_instance_color(no_arco, Color(1.0 * feixe, 0.82 * feixe, 0.55 * feixe, 0.9))
		no_arco += 1
	# 2) Cima e 3) baixo: a metade de lá do disco, dobrada por cima e por baixo da sombra. A de cima
	#    é mais aberta e mais clara; a de baixo afunda na própria luz do disco e perde meio brilho.
	for lado in range(2):
		var amplitude := POCO_HORIZONTE * (POCO_ARCO_ALTO if lado == 0 else POCO_ARCO_BAIXO)
		var sinal := 1.0 if lado == 0 else -1.0
		var base := 1.0 if lado == 0 else 0.55
		for i in range(POCO_ARCO_AMOSTRAS):
			var u := float(i) * PI / float(POCO_ARCO_AMOSTRAS - 1)
			var x := -POCO_ARCO_LARGO * POCO_HORIZONTE * cos(u)
			var y := sinal * amplitude * sin(u)
			var altura := sin(u)
			var feixe := 1.0 + POCO_DOPPLER * cos(u - PI / 2.0)
			var tam := 0.7 + 2.2 * altura
			mm.set_instance_transform(no_arco, Transform3D(deitado.scaled(Vector3(tam, tam, tam)),
				Vector3(x, y, 0.0)))
			mm.set_instance_color(no_arco,
				Color(base * feixe, base * 0.78 * feixe, base * 0.5 * feixe, 0.2 + 0.6 * altura))
			no_arco += 1
	poco_lente = MultiMeshInstance3D.new()
	poco_lente.name = "ArcoDeLente"
	poco_lente.multimesh = mm
	poco_lente.position = POCO_POS
	raiz.add_child(poco_lente)


## Billet plano aditivo usado pelos MultiMesh do poço. As cores vêm por instância, então é UM
## material para duzentas amostras: foi assim que o campo de estrelas deixou de ser 260 nós.
func _quadro_aditivo() -> PlaneMesh:
	var quadro := PlaneMesh.new()
	quadro.size = Vector2(1.0, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	quadro.material = mat
	return quadro


## Bola de raio cravado. A propriedade chama `radial_segments` e `rings`; errar o nome não falha no
## parse — aborta a função em runtime, devolve Nil e o cenário nasce incompleto.
func _esfera(pos: Vector3, raio: float, mat: Material, parent: Node,
	segmentos: int = 24) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = raio
	esfera.height = raio * 2.0
	esfera.radial_segments = segmentos
	esfera.rings = maxi(2, int(segmentos / 2.0))
	mesh_instance.mesh = esfera
	mesh_instance.position = pos
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	return mesh_instance


## Estrela: o disco incandescente, a coroa em anel e uma luz pontual. É o único cenário que mexe em
## dano, e mexe por posição de quem dispara — quem se aproxima para aquecer a arma também se expõe.
func _montar_estrela() -> void:
	var raiz := _garantir_cenario_root()
	estrela_ativa = true
	var fotosfera := Color(1.0, 0.8, 0.38)
	_cylinder(ESTRELA_POS, 13.0, 13.0, 1.4, _material(fotosfera, 0.0, 0.9, fotosfera), raiz,
		Vector3(PI / 2.0, 0, 0), 24)
	var coroa := _material(Color(1.0, 0.6, 0.2), 0.0, 0.9, Color(1.0, 0.55, 0.16))
	for i in range(20):
		var ang := float(i) * TAU / 20.0
		_box(ESTRELA_POS + Vector3(cos(ang) * ESTRELA_CALOR_RAIO * 0.42, sin(ang) * 3.0,
			sin(ang) * ESTRELA_CALOR_RAIO * 0.42), Vector3(3.0, 0.6, 3.0), coroa, raiz)
	var luz := OmniLight3D.new()
	luz.position = ESTRELA_POS
	luz.light_color = fotosfera
	luz.light_energy = 1.4
	luz.omni_range = ESTRELA_CALOR_RAIO
	luz.shadow_enabled = false
	raiz.add_child(luz)


## Marcas na mesa holográfica: o comandante tem de ver a barreira onde vê os cascos. Moram em
## `holo_cenario`, nunca em `holo_blips`, porque a conta de um blip por casco vivo é o contrato da
## mesa e rocha nenhuma é casco. A marca da pedra nasce com a pedra, em `_nova_rocha`, e anda com
## ela em `_derivar_rochas` — o que sobra aqui é o que não tem corpo próprio no tabuleiro.
func _pintar_marcas_cenario() -> void:
	if not is_instance_valid(holo_root):
		return
	if poco_ativo:
		var mat_poco := _material(Color(0.55, 0.2, 0.06), 0.0, 0.8, Color(0.9, 0.3, 0.06))
		holo_cenario.append(_cylinder(_holo_de(POCO_POS), 0.5, 0.5, 0.1, mat_poco, holo_root,
			Vector3.ZERO, 24))
	if estrela_ativa:
		var mat_estrela := _material(Color(1.0, 0.78, 0.34), 0.0, 0.8, Color(1.0, 0.7, 0.3))
		holo_cenario.append(_cylinder(_holo_de(ESTRELA_POS), 0.34, 0.34, 0.3, mat_estrela,
			holo_root, Vector3.ZERO, 16))


func _nota_cenario() -> String:
	var nota := ""
	match cenario_atual:
		"CINTURAO":
			nota = "CENÁRIO: CINTURÃO // %d rochas à deriva entre as linhas. " % rochas.size()
			nota += "Cada uma tem integridade de %0.0f por unidade de raio e muda de rumo até %0.1f u/s. " % [
				ROCHA_INTEGRIDADE_POR_RAIO, ROCHA_VETO_TETO]
			nota += "O lance que bate na pedra não chega ao casco: barreira serve de escudo. "
			nota += "Quem a fere o bastante racha em duas, e as filhas entram no tabuleiro."
		"POCO":
			nota = "CENÁRIO: POÇO // a %0.0f u o casco começa a cair, a %0.0f u não escapa. " % [
				POCO_ALCANCE, POCO_HORIZONTE]
			nota += "Quem cruza o horizonte é perdido, e o hostil obedece à mesma conta. "
			nota += "O céu atrás dele é dobrado: %d estrelas saíram do miolo." % estrelas_dobradas
		"ESTRELA":
			nota = "CENÁRIO: ESTRELA // arma a %0.0f u do disco bate %0.0f%% mais quente; " % [
				ESTRELA_CALOR_RAIO, (ESTRELA_CALOR_FATOR - 1.0) * 100.0]
			nota += "a %0.0f u o casco cozinha a %0.0f pontos por segundo. " % [
				ESTRELA_CORONA_RAIO, ESTRELA_QUEIMA_POR_SEGUNDO]
			nota += "O vento empurra para fora até %0.0f u e a radiação cega a sonda: " % [
				ESTRELA_VENTO_ALCANCE]
			nota += "varredura a %0.0f%% do alcance dentro de %0.0f u." % [
				ESTRELA_RADIAO_VARREDURA * 100.0, ESTRELA_RADIAO_RAIO]
		_:
			nota = "CENÁRIO: CAMPO ABERTO // nenhuma barreira, nenhum poço, nenhuma estrela."
	return nota


## Armas aquecidas: só a estrela ativa muda o multiplicador, e só para quem dispara de dentro do
## raio de calor. Fora dele é 1,0 — o que faz o campo aberto continuar conferível dígito a dígito.
func _fator_calor(de_pos: Vector3) -> float:
	if not estrela_ativa:
		return 1.0
	if de_pos.distance_to(ESTRELA_POS) > ESTRELA_CALOR_RAIO:
		return 1.0
	return ESTRELA_CALOR_FATOR


## Radiação: a tempestade de partículas do disco cega a varredura da sonda. É um multiplicador sobre
## o raio que a sonda já tinha, não uma conta nova — assim não existe fórmula paralela de
## reconhecimento. Não fere casco, não move ouro de combate, não sorteia nada: com a estrela apagada
## devolve 1,0 e o campo aberto continua conferível dígito a dígito.
func _fator_radiacao(de_pos: Vector3) -> float:
	if not estrela_ativa:
		return 1.0
	if de_pos.distance_to(ESTRELA_POS) > ESTRELA_RADIAO_RAIO:
		return 1.0
	return ESTRELA_RADIAO_VARREDURA


## Barreira é geometria de segmento, não projétil que voa: a salva resolve-se em um quadro e a
## rocha tem de valer nesse quadro. Devolve o ponto mais próximo dentro de um raio de pedra, ou
## vazio quando o corredor está limpo.
func _rocha_entre(origem: Vector3, destino: Vector3) -> Dictionary:
	var melhor := {}
	var melhor_t := INF
	for rocha in rochas:
		var centro: Vector3 = rocha["pos"]
		var trecho := destino - origem
		var comprimento := trecho.length_squared()
		if comprimento < 0.0001:
			continue
		var t := clampf((centro - origem).dot(trecho) / comprimento, 0.0, 1.0)
		var ponto := origem + trecho * t
		if ponto.distance_to(centro) > float(rocha["raio"]):
			continue
		if t < melhor_t:
			melhor_t = t
			melhor = {"pos": ponto, "raio": float(rocha["raio"]), "pedra": rocha}
	return melhor


## A pedra cobra o lance: o dano que ela absorveu tira integridade dela, e integridade zero racha.
## Duas filhas nascem no eixo perpendicular à linha do tiro — perpendicular de verdade, construído
## por produto vetorial com um eixo auxiliar constante, porque uma tangente escolhida na diagonal é
## o erro que já custou um céu torto nesta casa. Sem sorteio em nenhum caminho: o que decide a
## fratura é o ângulo de chegada e a geração da pedra, e a sonda confere os dois.
func _fraturar_rocha(rocha: Dictionary, dano: float, de_pos: Vector3) -> bool:
	if rocha.is_empty() or dano <= 0.0:
		return false
	rocha["integridade"] = float(rocha["integridade"]) - dano
	if float(rocha["integridade"]) > 0.0:
		return false
	var pos: Vector3 = rocha["pos"]
	var vel: Vector3 = rocha["vel"]
	var raio := float(rocha["raio"])
	var geracao := int(rocha["geracao"])
	var fase := float(rocha["fase"])
	var raio_filha := raio * ROCHA_FILHA_FRAC
	if geracao >= ROCHA_GERACAO_MAXIMA or raio_filha < ROCHA_FILHA_MIN \
			or rochas.size() + 1 > ROCHA_LIMITE_CORPOS:
		_remover_rocha(rocha)
		return true
	var ate := pos - de_pos
	var dir := Vector3(0.0, 0.0, 1.0) if ate.length_squared() < 0.0001 else ate / ate.length()
	var aux := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var u := dir.cross(aux).normalized()
	# Rodrigues num par ortonormal: `u` e `dir × u` são unitários e perpendiculares entre si, então
	# girar a fase da pedra nesse plano é rotação de verdade, não deriva de ângulo.
	var w := dir.cross(u)
	var angulo := fmod(fase, TAU)
	var eixo := u * cos(angulo) + w * sin(angulo)
	var separacao := raio * 0.5
	_remover_rocha(rocha)
	# `lado` vem de um Array de Variant, então precisa virar float antes da conta: Vector3 somado a
	# Variant perde o tipo e o parser não infere mais nada.
	for lado_bruto in [-1.0, 1.0]:
		var lado := float(lado_bruto)
		var filha_pos := pos + eixo * (separacao * lado)
		var filha_vel := vel + eixo * (ROCHA_DERIVA * 0.5 * lado)
		_nova_rocha(filha_pos, raio_filha, filha_vel, geracao + 1, fase + lado * 0.7)
	return true


## Pedra fora do tabuleiro: nó, marca e registro saem juntos. Deixar a marca para trás é o caminho
## pelo qual a mesa passaria a anunciar barreira onde já não tem nenhuma.
func _remover_rocha(rocha: Dictionary) -> void:
	var no: MeshInstance3D = rocha["no"]
	if is_instance_valid(no):
		no.queue_free()
	var marca: MeshInstance3D = rocha["marca"]
	if is_instance_valid(marca):
		marca.queue_free()
		holo_cenario.erase(marca)
	rochas.erase(rocha)


## O perigo age por posição, depois de cada casco ter obedecido à ordem e antes da separação
## casco-a-casco: assim a física de contato ainda tem a última palavra sobre sobreposição.
func _aplicar_cenario(delta: float) -> void:
	if poco_ativo:
		_puxar_para_o_poco(delta)
		_lentificar_quadro()
	if estrela_ativa:
		_empurrar_no_vento(delta)
		_queimar_na_corona(delta)
	if not rochas.is_empty():
		# A correnteza anda antes de cobrar quem encosta: o casco tem de ver a pedra onde ela está
		# neste quadro, não onde ela estava no anterior.
		_derivar_rochas(delta)
		_chocar_com_rochas()


func _puxar_para_o_poco(delta: float) -> void:
	for corpo in _collision_bodies():
		if bool(corpo["imovel"]):
			continue
		var node: Node3D = corpo["node"]
		var vetor := POCO_POS - node.global_position
		var distancia := vetor.length()
		if distancia > POCO_ALCANCE:
			continue
		if distancia <= POCO_HORIZONTE:
			_devorado_pelo_poco(corpo)
			continue
		var peso := 1.0 - distancia / POCO_ALCANCE
		node.global_position += vetor / distancia * POCO_PUXO * peso * delta


## O vento da estrela: empurra para fora, com o mesmo peso linear do poço (`1 - d/alcance`), só que
## no sentido inverso. Posicional e sem sorteio, exatamente como o poço — por isso roda dentro de
## `_aplicar_cenario` sem empurrar a cauda de `rng`. A ordem do quadro é o que faz dele uma conta de
## locomoção e não de teleporte: o casco obedece à ordem primeiro, o vento desvia depois, e a
## próxima correção de rumo já compensa o que o vento levou. Destroço não é empurrado (`imovel`):
## baixado tem de continuar onde caiu, porque o painel anuncia os caídos pela posição deles. A
## capitânia entra na conta — é o casco que o jogador sente derrapar. Sonda fica de fora: ela tem
## velocidade própria, e a estrela a alcança pela radiação, não pelo vento.
func _empurrar_no_vento(delta: float) -> void:
	for corpo in _collision_bodies():
		if bool(corpo["imovel"]):
			continue
		var node: Node3D = corpo["node"]
		var vetor := node.global_position - ESTRELA_POS
		var distancia := vetor.length()
		if distancia > ESTRELA_VENTO_ALCANCE:
			continue
		if distancia < 0.0001:
			# No centro exato do disco não existe direção "para fora": sem esta guarda o vetor
			# normalizado é conta sobre zero. A régua curta é a mesma da lente, que já se protege
			# de um olho colado no poço.
			continue
		var peso := 1.0 - distancia / ESTRELA_VENTO_ALCANCE
		node.global_position += vetor / distancia * ESTRELA_VENTO_ACEL * peso * delta


## A lente, quadro a quadro: o arco gira para encarar a ponte e o céu de fundo é dobrado em volta
## do poço. Zero sorteio — é conta pura sobre posição, e é por isso que pode rodar dentro de
## `_aplicar_cenario` sem empurrar a cauda de `rng` nem a de `visual_rng`.
func _lentificar_quadro() -> void:
	var olho: Vector3 = ponte_camera.global_position if is_instance_valid(ponte_camera) \
		else Vector3(0.0, 0.0, 0.0)
	if is_instance_valid(poco_lente):
		var ate_olho := olho - POCO_POS
		# `look_at` com alvo no próprio nó aborta em runtime; com a ponte encostada no centro do
		# poço o casco já foi devorado, mas a função ainda roda neste quadro.
		if ate_olho.length_squared() > 0.01:
			poco_lente.look_at(olho, Vector3.UP)
	if not is_instance_valid(campo_estelar) or campo_estelar.multimesh == null:
		return
	var ate_poco := POCO_POS - olho
	var distancia := ate_poco.length()
	if distancia < 0.01:
		_desdobrar_ceu()
		return
	var e := ate_poco / distancia
	var mm := campo_estelar.multimesh
	var banda := POCO_LENTE_BANDA * POCO_LENTE_EINSTEIN
	var dobradas := 0
	for i in range(estrelas_base.size()):
		var base: Transform3D = estrelas_base[i]
		var ate_estrela := base.origin - olho
		var alcance := ate_estrela.length()
		if alcance < 0.01:
			_pintar_estrela(i, mm, base)
			continue
		var dir := ate_estrela / alcance
		var cosseno := clampf(dir.dot(e), -1.0, 1.0)
		var sep := acos(cosseno)
		if sep >= banda:
			_pintar_estrela(i, mm, base)
			continue
		# A regra fraca da lente fina: a separação aparenta ser `sep + E²/sep`, tocada em 2E. É o
		# que esvazia o miolo e amontoa céu logo fora do raio de Einstein — a borda clara do disco
		# escuro que o olho lê como "aquilo dobrou o céu atrás de si". O AM-GM dá o mínimo exato em
		# 2E (para `sep = E`), e um miolo que encosta na borda por 1e-9 não é preto: o anel pede a
		# margem `POCO_LENTE_ANEL` para que a asserção mea um céu varrido, não um empate numérico.
		var flexao := minf(POCO_LENTE_EINSTEIN * POCO_LENTE_EINSTEIN / maxf(sep, 0.0001),
			POCO_LENTE_FLEXAO_TETO * POCO_LENTE_EINSTEIN)
		var sep_alvo := maxf(sep + flexao, POCO_LENTE_ANEL * 2.0 * POCO_LENTE_EINSTEIN)
		# Rodar no par ortonormal (direção do poço, perpendicular À DIREÇÃO DA ESTRELA). Somar a
		# flexão numa tangente perpendicular ao eixo do poço não é rotação: a base não é ortonormal
		# e o ângulo de saída perde ~0,006 rad — pouco no pixel, suficiente para deixar céu dentro
		# do miolo que a sonda jura varrido.
		var perpendicular := dir - e * cosseno
		var eixo_u: Vector3
		if perpendicular.length_squared() < 1.0e-9:
			# Estrela alinhada com o poço: sem plano de rotação escolhido, mas a lente real joga
			# exatamente esse caso no anel de Einstein. O eixo auxiliar é constante, nunca sorteado.
			var aux := Vector3.UP if absf(e.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
			eixo_u = e.cross(aux).normalized()
		else:
			eixo_u = perpendicular.normalized()
		var novo := e * cos(sep_alvo) + eixo_u * sin(sep_alvo)
		_pintar_estrela(i, mm, Transform3D(base.basis, olho + novo * alcance))
		dobradas += 1
	estrelas_dobradas = dobradas


## Uma estrela, dois lugares: o espelho em RAM (o que a sonda lê, e o que a conta da lente usa no
## quadro seguinte) e o MultiMesh (o que a tela desenha). Escrever só no MultiMesh deixaria a lente
## cega no driver sem janela, onde a escrita é descartada e a leitura volta identidade.
func _pintar_estrela(i: int, mm: MultiMesh, tr: Transform3D) -> void:
	if estrelas_pintadas.size() == estrelas_base.size():
		if estrelas_pintadas[i] != tr:
			estrelas_pintadas[i] = tr
			mm.set_instance_transform(i, tr)
	else:
		estrelas_pintadas.append(tr)
		mm.set_instance_transform(i, tr)


## Campo aberto, cinturão, estrela: o céu volta exatamente ao que era, estrela por estrela, e a
## contagem zera. Sem isto, trocar de mapa deixaria a dobra gravada no MultiMesh para sempre.
func _desdobrar_ceu() -> void:
	estrelas_dobradas = 0
	if not is_instance_valid(campo_estelar) or campo_estelar.multimesh == null:
		return
	var mm := campo_estelar.multimesh
	for i in range(estrelas_base.size()):
		_pintar_estrela(i, mm, estrelas_base[i])


## O poço não fere: engole. Sem dano gradual e sem sorteio — um casco dentro do horizonte já está
## perdido, e adiar isso em pontos de vida faria a morte depender de quantos quadros a pintura
## demora. O destroço fica onde a conta o viu pela última vez, marcado como perda.
func _devorado_pelo_poco(corpo: Dictionary) -> void:
	audio.efeito("EXPLOSAO")
	if corpo["unidade"] == null:
		if capital_hp <= 0.0:
			return
		capital_hp = 0.0
		if is_instance_valid(report_label):
			report_label.text = "POÇO // a capitânia cruzou o horizonte e não responde mais."
		return
	var unit: Dictionary = corpo["unidade"]
	if float(unit["hp"]) <= 0.0:
		return
	unit["hp"] = 0.0
	unit["weapons"] = 0.0
	unit["engines"] = 0.0
	unit["crew"] = 0.0
	_mark_wreck(unit["node"] as Node3D)
	if is_instance_valid(report_label):
		report_label.text = "POÇO // %s foi sugada: o horizonte não devolve casco." % String(unit["name"])


func _queimar_na_corona(delta: float) -> void:
	for corpo in _collision_bodies():
		if bool(corpo["imovel"]):
			continue
		var node: Node3D = corpo["node"]
		if node.global_position.distance_to(ESTRELA_POS) > ESTRELA_CORONA_RAIO:
			continue
		if corpo["unidade"] == null:
			# A ponte morta não continua cozinhando relatório: sem esta guarda cada quadro dentro
			# da coroa reescrevia a CORONA por cima do DERROTA que a salva já tinha declarado.
			if capital_hp <= 0.0:
				continue
			capital_hp = maxf(0.0, capital_hp - ESTRELA_QUEIMA_POR_SEGUNDO * delta)
			if capital_hp <= 0.0 and is_instance_valid(report_label):
				report_label.text = "CORONA // a capitânia cozinhou perto demais da estrela."
			continue
		var unit: Dictionary = corpo["unidade"]
		if float(unit["hp"]) <= 0.0:
			continue
		unit["hp"] = maxf(0.0, float(unit["hp"]) - ESTRELA_QUEIMA_POR_SEGUNDO * delta)
		unit["engines"] = maxf(0.0, float(unit["engines"]) - ESTRELA_QUEIMA_POR_SEGUNDO * delta * 0.5)
		if float(unit["hp"]) <= 0.0:
			_mark_wreck(unit["node"] as Node3D)
			if is_instance_valid(report_label):
				report_label.text = "CORONA // %s perdeu casco na Fornalha." % String(unit["name"])


## Rocha é âncora no que diz respeito ao casco: ela não perde pontos de vida no abalroamento e não
## afunda — o único que perde algo no encontro é o casco que nela bate, e é esse preço que faz do
## asteroide uma barreira. Da integridade ela só cobra dos lances (`_fraturar_rocha`). O que a deriva
## mudou é a conta de aproximação: quem fecha é a velocidade relativa, porque pedra que vem contra
## você a 2,4 u/s já não é o mesmo obstáculo de uma parada.
func _chocar_com_rochas() -> void:
	for corpo in _collision_bodies():
		if bool(corpo["imovel"]):
			continue
		var node: Node3D = corpo["node"]
		for rocha in rochas:
			var centro: Vector3 = rocha["pos"]
			var soma := float(corpo["raio"]) + float(rocha["raio"])
			var entre := node.global_position - centro
			var distancia := entre.length()
			if distancia >= soma:
				continue
			var normal := Vector3(0, 0, 1) if distancia < 0.001 else entre / distancia
			node.global_position = centro + normal * soma
			# O destroço continua separado da pedra — um casco afundado atravessando o cinturão
			# seria o mesmo corpo pintado em dois lugares — mas não cobra dano nem reescreve o
			# relatório: quem já perdeu a ponte não perde de novo a cada janela de abalroamento.
			if capital_hp <= 0.0 and corpo["unidade"] == null:
				continue
			var aproximacao := -(_body_velocity(corpo) - (rocha["vel"] as Vector3)).dot(normal)
			if aproximacao <= RAM_SPEED:
				continue
			# A chave é o id da pedra, não a coordenada: com a pedra andando, uma chave geométrica
			# mudaria de nome todo quadro e rearmaria a janela de 1,5 s sem parar — o cinturão
			# viraria moedor em vez de parede.
			var chave := "rocha:%d:%d" % [node.get_instance_id(), int(rocha["id"])]
			if battle_clock - float(ram_windows.get(chave, -RAM_WINDOW)) < RAM_WINDOW:
				continue
			ram_windows[chave] = battle_clock
			var dano := clampf((aproximacao - RAM_SPEED) * RAM_DAMAGE, 1.0, RAM_MAX_DAMAGE)
			if corpo["unidade"] == null:
				capital_hp = maxf(0.0, capital_hp - dano)
				audio.efeito("IMPACTO")
				if capital_hp <= 0.0 and is_instance_valid(report_label):
					report_label.text = "COLISÃO // a ponte abriu no cinturão."
			else:
				_apply_impact({"node": node, "unidade": corpo["unidade"], "raio": corpo["raio"],
					"hostil": corpo["hostil"], "imovel": false}, dano)


## Timão da capitânia em três eixos: guinada (A/D), arfagem (setas ↑/↓), rolagem (Q/E, que se
## autocorrige quando a mão sai do teclado para a mesa continuar legível), avante e ré (W/S, com a
## ré limitada) e empuxo vertical (R/V, sobe e desce sem mudar a atitude). Nada aqui sorteia: a
## posição do rig é leitura de teclado, e é por isso que a sonda de voo pode afirmar coordenada.
func _update_capital_ship(delta: float) -> void:
	var turn := 0.0
	if Input.is_action_pressed("capital_bombordo"):
		turn += 1.0
	if Input.is_action_pressed("capital_estibordo"):
		turn -= 1.0
	var pitch := 0.0
	if Input.is_action_pressed("capital_nariz_acima"):
		pitch += 1.0
	if Input.is_action_pressed("capital_nariz_abaixo"):
		pitch -= 1.0
	var roll := 0.0
	if Input.is_action_pressed("capital_role_esquerda"):
		roll += 1.0
	if Input.is_action_pressed("capital_role_direita"):
		roll -= 1.0
	var lift := 0.0
	if Input.is_action_pressed("capital_empuxo_acima"):
		lift += 1.0
	if Input.is_action_pressed("capital_empuxo_abaixo"):
		lift -= 1.0
	var avante := Input.is_action_pressed("capital_avante")
	var re := Input.is_action_pressed("capital_re")
	if avante:
		throttle = minf(1.0, throttle + delta * 0.5)
	if re:
		throttle = maxf(CAPITAL_REVERSE, throttle - delta * 0.6)
	# Sem mão no acelerador o casco perde velocidade aos poucos: manobra tem inércia, mas o
	# jogador nunca fica à deriva sem saber por quê.
	if not avante and not re:
		throttle = move_toward(throttle, 0.0, delta * 0.3)
	bridge_rig.rotation.y += turn * delta * 0.28
	bridge_rig.rotation.x = clampf(bridge_rig.rotation.x + pitch * delta * 0.5, -PITCH_LIMIT, PITCH_LIMIT)
	bridge_rig.rotation.z = clampf(move_toward(bridge_rig.rotation.z, roll * ROLL_LIMIT, delta * 0.9),
		-ROLL_LIMIT, ROLL_LIMIT)
	var anterior := bridge_rig.position
	# O rumo sai da transformada global do rig, então arfar aponta o empuxo para cima de verdade:
	# subir com o nariz erguido e subir com o vetor de proa são manobras diferentes na ponte.
	var rumo := -bridge_rig.global_transform.basis.z
	bridge_rig.position += (rumo * throttle * CAPITAL_SPEED + Vector3(0.0, lift * CAPITAL_LIFT, 0.0)) * delta
	bridge_rig.position.x = clampf(bridge_rig.position.x, -MAP_X, MAP_X)
	bridge_rig.position.y = clampf(bridge_rig.position.y, -MAP_Y, MAP_Y)
	bridge_rig.position.z = clampf(bridge_rig.position.z, MAP_Z_FAR, MAP_Z_NEAR)
	capital_velocity = (bridge_rig.position - anterior) / maxf(delta, 0.0001)

func _update_fleet(delta: float) -> void:
	# Ambas as frotas agem continuamente; ordens mudam comportamento, não iniciam turnos.
	for i in range(fleet.size()):
		var ally: Dictionary = fleet[i]
		var ship: Node3D = ally["node"]
		if ally["hp"] <= 0.0 or not is_instance_valid(ship):
			continue
		var mobility: float = 0.25 + float(ally["engines"]) / 100.0 * 0.75
		var partida := ship.position
		# MOVER, DISPERSAR e AGRUPAR compartilham o mesmo timão: todos escrevem `destination` e
		# nenhum teleporta. A diferença entre eles é só a geometria do posto, não a execução.
		var ordem := String(ally["order"])
		if (ordem == "MOVER" or ordem == "DISPERSAR" or ordem == "AGRUPAR") and ally.has("destination"):
			ship.position = ship.position.move_toward(ally["destination"], delta * 8.0 * mobility)
		elif ally["order"] == "AVANÇAR":
			ship.position.z -= delta * 1.2 * mobility
		elif ally["order"] == "RECUAR":
			ship.position.z += delta * 1.3 * mobility
		elif ally["order"] == "ESCOLTAR":
			var protect_position := Vector3.ZERO
			if protected_unit_index >= 0 and protected_unit_index < fleet.size():
				protect_position = (fleet[protected_unit_index]["node"] as Node3D).position
			var escort_destination := protect_position + Vector3((float(i) - 2.5) * FORMATION_STEP, 0, 8.0 if protected_unit_index >= 0 else -12.0)
			ship.position = ship.position.lerp(escort_destination, minf(1.0, delta * 0.35))
		elif ally["order"] == "RESERVA":
			ship.position.z = move_toward(ship.position.z, -48.0, delta * 0.8)
		elif ally["order"] == "RECONHECER":
			ship.position.x = move_toward(ship.position.x, (float(i) - 2.5) * 9.0, delta * 1.8)
		elif ally["order"] == "ABORDAR" and selected_target < enemies.size() and enemies[selected_target]["hp"] > 0.0:
			var target: Node3D = enemies[selected_target]["node"]
			ship.position = ship.position.move_toward(target.position + Vector3((float(i) - 2.5) * 2.0, 0, 8.0), delta * 2.2 * mobility)
		# Velocidade real do quadro, medida por diferença de posição: é o que o abalroamento lê
		# para separar encostar de bater, sem inventar um sorteio de impacto.
		ally["veloc"] = (ship.position - partida) / maxf(delta, 0.0001)
		# Automatic repair crews follow the commander priority, or balance repairs by default.
		var repair_rate := delta * (2.2 if float(ally["crew"]) > 25.0 else 1.0)
		var priority: String = ally.get("repair_priority", "AUTO")
		if priority == "MOTORES":
			ally["engines"] = minf(100.0, float(ally["engines"]) + repair_rate)
		elif priority == "ARMAS":
			ally["weapons"] = minf(100.0, float(ally["weapons"]) + repair_rate)
		elif priority == "CASCO":
			ally["hp"] = minf(100.0, float(ally["hp"]) + repair_rate)
		elif priority == "TRIPULAÇÃO":
			ally["crew"] = minf(100.0, float(ally["crew"]) + repair_rate)
		else:
			if ally["engines"] < 85.0:
				ally["engines"] = minf(100.0, float(ally["engines"]) + repair_rate * 0.6)
			if ally["weapons"] < 85.0:
				ally["weapons"] = minf(100.0, float(ally["weapons"]) + repair_rate * 0.6)
			if ally["hp"] < 100.0:
				ally["hp"] = minf(100.0, float(ally["hp"]) + repair_rate * 0.25)
			if ally["crew"] < 100.0:
				ally["crew"] = minf(100.0, float(ally["crew"]) + repair_rate * 0.2)
		fleet[i] = ally
		_tune_ship_look(ally)
	# A escolta hostil estaciona em torno da própria capitânia, então a âncora é lida uma
	# vez por quadro — não por nave.
	var hostile_anchor := Vector3.ZERO
	var hostile_command := _hostile_command_index()
	if hostile_command >= 0 and is_instance_valid(enemies[hostile_command]["node"]):
		hostile_anchor = (enemies[hostile_command]["node"] as Node3D).position
	for enemy in enemies:
		var foe: Node3D = enemy["node"]
		if enemy["hp"] <= 0.0 or not is_instance_valid(foe):
			continue
		var mobility: float = 0.25 + float(enemy["engines"]) / 100.0 * 0.75
		var partida := foe.position
		if enemy["order"] == "AVANÇAR":
			foe.position.z += delta * 0.85 * mobility
		elif enemy["order"] == "RECUAR":
			foe.position.z -= delta * 0.45 * mobility
		elif enemy["order"] == "ESCOLTAR":
			# Posto alternado pela IA (-3 / +3): duas escoltas no mesmo ponto se tapariam.
			var side: float = float(enemy.get("escort_offset", 3.0))
			foe.position = foe.position.move_toward(hostile_anchor + Vector3(side, 0.0, 7.0), delta * 1.1 * mobility)
		# Qualquer que seja a ordem, o casco hostil fica entre a linha de reunião e a de
		# avanço: a batalha não migra para fora da vista da ponte.
		foe.position.z = clampf(foe.position.z, HOSTILE_RALLY_Z, HOSTILE_ADVANCE_Z)
		enemy["veloc"] = (foe.position - partida) / maxf(delta, 0.0001)
		_tune_ship_look(enemy)
	# Por último o cenário e a física de contato: primeiro cada casco obedece à ordem, depois o
	# poço puxa / a corona queima / a rocha fere, e só então o campo cobra quem atravessou quem.
	# Inverter a ordem faria a separação ser sobrescrita pela ordem no mesmo quadro, e a colisão
	# viraria enfeite.
	_aplicar_cenario(delta)
	_resolve_collisions()

## Corpos que ocupam espaço: frota, hostis e a própria ponte. Destroço entra como âncora
## (`imovel`) porque baixar tem de continuar no quadro e não pode ser empurrado por quem vive.
func _collision_bodies() -> Array[Dictionary]:
	var bodies: Array[Dictionary] = []
	for unit in fleet:
		var node: Node3D = unit["node"]
		if not is_instance_valid(node):
			continue
		bodies.append({"node": node, "unidade": unit, "raio": HULL_RADIUS, "hostil": false,
			"imovel": float(unit["hp"]) <= 0.0})
	for unit in enemies:
		var node: Node3D = unit["node"]
		if not is_instance_valid(node):
			continue
		bodies.append({"node": node, "unidade": unit, "raio": HULL_RADIUS, "hostil": true,
			"imovel": float(unit["hp"]) <= 0.0})
	bodies.append({"node": bridge_rig, "unidade": null, "raio": CAPITAL_RADIUS, "hostil": false,
		"imovel": false})
	return bodies

func _resolve_collisions() -> void:
	var bodies := _collision_bodies()
	for a in range(bodies.size()):
		for b in range(a + 1, bodies.size()):
			_separate_pair(bodies[a], bodies[b])

## Separação posicional e dano de abalroamento. Empurra menos quem tem mais casco; um destroço é
## âncora e não sai do lugar. Nenhum sorteio aqui — impacto é geometria, e um `rng.randf()` de
## colisão reescreveria toda a cauda de dano da salva seguinte (ver `visual_rng`).
func _separate_pair(a: Dictionary, b: Dictionary) -> void:
	var node_a: Node3D = a["node"]
	var node_b: Node3D = b["node"]
	var entre_cascos := node_b.global_position - node_a.global_position
	var distancia := entre_cascos.length()
	var soma := float(a["raio"]) + float(b["raio"])
	if distancia >= soma:
		return
	# Dois cascos exatamente no mesmo ponto não têm normal: empurra em +Z, sem sorteio de eixo.
	var normal := Vector3(0, 0, 1) if distancia < 0.001 else entre_cascos / distancia
	var sobreposicao := soma - distancia
	if bool(a["imovel"]):
		node_b.global_position += normal * sobreposicao
	elif bool(b["imovel"]):
		node_a.global_position -= normal * sobreposicao
	else:
		# Peso distribuído pelo casco: o pequeno cede mais que o grande.
		var cessao_a := float(b["raio"]) / soma
		var cessao_b := float(a["raio"]) / soma
		node_a.global_position -= normal * sobreposicao * cessao_a
		node_b.global_position += normal * sobreposicao * cessao_b
	var vel_a := _body_velocity(a)
	var vel_b := _body_velocity(b)
	var aproximacao := (vel_a - vel_b).dot(normal)
	if aproximacao <= RAM_SPEED:
		return
	# Casco aliado contra casco aliado não cobra: separar é física, fere é combate. A formação que
	# acaba de ser mandada navegar atravessa a própria linha, e punir isso tiraria do jogador o
	# preço de uma manobra que ele não controla quadro a quadro. A ponte é exceção: quem segura o
	# timão é o comandante, e abalroar a própria frota custa.
	if not bool(a["hostil"]) and not bool(b["hostil"]) and a["unidade"] != null and b["unidade"] != null:
		return
	var chave := _pair_key(a, b)
	if battle_clock - float(ram_windows.get(chave, -RAM_WINDOW)) < RAM_WINDOW:
		return
	ram_windows[chave] = battle_clock
	var dano := clampf((aproximacao - RAM_SPEED) * RAM_DAMAGE, 1.0, RAM_MAX_DAMAGE)
	var nome_a := _body_name(a)
	var nome_b := _body_name(b)
	_apply_impact(a, dano)
	_apply_impact(b, dano)
	if is_instance_valid(report_label):
		report_label.text = "ESPERAMENTO // %s e %s trocaram casco no abalroamento (-%0.1f)." % [
			nome_a, nome_b, dano]

func _body_velocity(body: Dictionary) -> Vector3:
	if body["unidade"] == null:
		return capital_velocity
	if bool(body["imovel"]):
		return Vector3.ZERO
	return body["unidade"].get("veloc", Vector3.ZERO)

func _body_name(body: Dictionary) -> String:
	if body["unidade"] == null:
		return "CAPITÂNIA"
	return String(body["unidade"]["name"])

func _pair_key(a: Dictionary, b: Dictionary) -> String:
	var nodo_a: Node3D = a["node"]
	var nodo_b: Node3D = b["node"]
	var id_a := nodo_a.get_instance_id()
	var id_b := nodo_b.get_instance_id()
	return "%d:%d" % [mini(id_a, id_b), maxi(id_a, id_b)]

## O dano do impacto entra pelo casco, e afunda motor e arma porque nada em um cruzador absorve
## uma bordaada sem quebrar uma linha de eixo. Se o casco fecha ali, a marca de destroço é feita
## aqui — senão o corpo ficaria vivo na conta e pintado como perda.
func _apply_impact(body: Dictionary, dano: float) -> void:
	# O baque é o único efeito do abalroamento que se ouve: o casco range por dentro, e o
	# estouro vem depois, se o casco fechar.
	audio.efeito("IMPACTO")
	if body["unidade"] == null:
		if capital_hp <= 0.0:
			return
		capital_hp = maxf(0.0, capital_hp - dano)
		if capital_hp <= 0.0 and is_instance_valid(report_label):
			report_label.text = "PONTE DESTRUÍDA // a capitânia perdeu o comando da frota."
		return
	var unit: Dictionary = body["unidade"]
	if float(unit["hp"]) <= 0.0:
		return
	unit["hp"] = maxf(0.0, float(unit["hp"]) - dano)
	unit["engines"] = maxf(0.0, float(unit["engines"]) - dano * 0.5)
	unit["weapons"] = maxf(0.0, float(unit["weapons"]) - dano * 0.5)
	if float(unit["hp"]) <= 0.0:
		_mark_wreck(unit["node"] as Node3D)
		if is_instance_valid(report_label):
			report_label.text = "ABALROAMENTO // %s fechou no impacto." % String(unit["name"])

## Lança uma sonda por casco vivo selecionado que ainda não tenha outra em órbita. Não há
## custo em números: a moeda da sonda é a cobertura do tabuleiro, e o teto é um objeto por
## navio — por isso o segundo clique na mesma seleção não empilha nada.
func _launch_probes(indices: Array[int]) -> int:
	var launched := 0
	for i in indices:
		if float(fleet[i]["hp"]) <= 0.0 or not is_instance_valid(fleet[i]["node"]):
			continue
		var busy := false
		for probe in probes:
			if int(probe["from"]) == i:
				busy = true
				break
		if busy:
			continue
		var origin: Node3D = fleet[i]["node"]
		# Corredor determinístico: a sonda desce a linha no x do hostil da mesma ordem, então
		# cada navio cobre o seu próprio setor e a cobertura total exige a frota lançada.
		var lane_x := (float(i) - 2.5) * 6.0
		var node := _make_probe(origin.position + Vector3(0.0, 1.4, -3.0))
		probes.append({"node": node, "from": i, "lane_x": lane_x, "outbound": true,
			"waypoint": Vector3(lane_x, 0.0, PROBE_FAR_Z), "life": PROBE_LIFE,
			"launcher": String(fleet[i]["name"])})
		launched += 1
	return launched

func _make_probe(pos: Vector3) -> Node3D:
	var probe := Node3D.new()
	probe.position = pos
	add_child(probe)
	var glow := Color(0.35, 0.9, 1.0)
	_box(Vector3(0, 0, 0), Vector3(0.5, 0.5, 0.9), _material(glow.darkened(0.55), 0.5, 0.3, glow * 0.7), probe)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.15
	torus.outer_radius = 1.75
	ring.mesh = torus
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.material_override = _material(glow, 0.1, 0.2, glow * 0.55)
	probe.add_child(ring)
	return probe

## Varredura em si: a sonda é um corpo no tabuleiro, então o que ela confirma é o casco que
## ela fisicamente alcança. Nada aqui consome `rng` nem escreve em subsistema — só em
## `seen`, que é informação, não força de combate.
func _update_probes(delta: float) -> void:
	var i := probes.size() - 1
	while i >= 0:
		var probe: Dictionary = probes[i]
		var node: Node3D = probe["node"]
		probe["life"] = float(probe["life"]) - delta
		if float(probe["life"]) <= 0.0 or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			probes.remove_at(i)
			i -= 1
			continue
		var waypoint: Vector3 = probe["waypoint"]
		node.position = node.position.move_toward(waypoint, delta * PROBE_SPEED)
		if node.position.distance_to(waypoint) < 0.6:
			probe["outbound"] = not bool(probe["outbound"])
			probe["waypoint"] = Vector3(float(probe["lane_x"]), 0.0,
				PROBE_FAR_Z if bool(probe["outbound"]) else PROBE_NEAR_Z)
		_scan_with_probe(node)
		probes[i] = probe
		i -= 1
	_recompute_recon()

func _scan_with_probe(node: Node3D) -> void:
	# O raio é o da sonda multiplicado pela radiação do ponto onde ela está: perto demais do disco
	# a varredura enxerga a metade. Nenhum número de combate muda, nenhum sorteio é consumido.
	var raio := PROBE_SCAN_RADIUS * _fator_radiacao(node.global_position)
	for i in range(enemies.size()):
		var foe: Dictionary = enemies[i]
		if float(foe["hp"]) <= 0.0 or String(foe["order"]) == "CAPTURADO" or bool(foe.get("seen", false)):
			continue
		if not is_instance_valid(foe["node"]):
			continue
		if (foe["node"] as Node3D).global_position.distance_to(node.global_position) <= raio:
			foe["seen"] = true
			enemies[i] = foe

## Uma fórmula só para o reconhecimento: a barra da ponte é a fração da linha hostil viva que
## já foi encostada por uma sonda. Quem morre sai do denominador, quem é capturado também.
func _recompute_recon() -> void:
	var living := 0
	var known := 0
	for foe in enemies:
		if float(foe["hp"]) <= 0.0 or String(foe["order"]) == "CAPTURADO":
			continue
		living += 1
		if bool(foe.get("seen", false)):
			known += 1
	recon_total = living
	recon_contacts = known
	recon_progress = 0.0 if living == 0 else 100.0 * float(known) / float(living)

func _combat_power(unit: Dictionary) -> float:
	return float(unit["hp"]) * 0.5 + float(unit["weapons"]) * 0.3 + float(unit["engines"]) * 0.15 + float(unit["crew"]) * 0.05

func _hostile_command_index() -> int:
	for i in range(enemies.size()):
		if enemies[i].get("role", "") == "COMANDO":
			return i
	return -1

func _enemy_distance(index: int, anchor: Vector3) -> float:
	var node: Node3D = enemies[index]["node"]
	return node.global_position.distance_to(anchor)

## Função pura: lê o tabuleiro e devolve a decisão sem mover nada. É por ela que a sonda
## confere postura e alvo sem depender de frames nem do RNG.
func _assess_hostiles() -> Dictionary:
	var hostile_power := 0.0
	for enemy in enemies:
		if float(enemy["hp"]) > 0.0 and enemy["order"] != "CAPTURADO":
			hostile_power += _combat_power(enemy)
	var friendly_power := 0.0
	for ally in fleet:
		if float(ally["hp"]) > 0.0 and ally["order"] != "RESERVA":
			friendly_power += _combat_power(ally)
	var ratio := hostile_power / maxf(1.0, hostile_power + friendly_power)
	var command_index := _hostile_command_index()
	var command_alive := command_index >= 0 and float(enemies[command_index]["hp"]) > 0.0
	# Sem capitânia entre os vivos, a esquadra perde coesão: debandada, não manobra.
	var rout := not command_alive
	var command_hurt := command_alive and float(enemies[command_index]["hp"]) < 60.0
	var posture := "AVANÇAR"
	# 0.42 de força relativa = os hostis valem menos de ~72% do que a linha aliada. Forças
	# iguais dão 0.50 e ficam em AVANÇAR: sem essa margem a IA recuaria ainda na linha de
	# partida.
	if rout or ratio < 0.42:
		posture = "RECUAR"
	if command_hurt:
		posture = "ESCOLTA"
	return {
		"hostile_power": hostile_power,
		"friendly_power": friendly_power,
		"ratio": ratio,
		"posture": posture,
		"command_index": command_index,
		"command_hurt": command_hurt,
		"rout": rout,
	}

## Alvo vulnerável e que ameaça: casco baixo pesa mais, armamento pesado pesa junto, e
## quem está em reserva tática não é lido como alvo.
func _hostile_victim_index() -> int:
	var best := -1
	var best_value := -1.0
	for i in range(fleet.size()):
		var ally: Dictionary = fleet[i]
		if float(ally["hp"]) <= 0.0 or ally["order"] == "RESERVA":
			continue
		var value := (100.0 - float(ally["hp"])) + float(ally["weapons"]) * 0.3
		if ally["order"] == "ATACAR":
			value += 25.0
		if value > best_value:
			best_value = value
			best = i
	if best >= 0:
		return best
	for i in range(fleet.size()):
		if float(fleet[i]["hp"]) > 0.0:
			return i
	return -1

## Converte a leitura em ordens, uma vez por salva. Não toca em casco, armamento nem
## posição: só em `order`, e o resto do combate continua automático.
func _apply_hostile_tactics() -> void:
	var read := _assess_hostiles()
	var previous := hostile_posture
	hostile_posture = String(read["posture"])
	var base := hostile_posture if hostile_posture != "ESCOLTA" else "RECUAR"
	var living: Array[int] = []
	for i in range(enemies.size()):
		if float(enemies[i]["hp"]) > 0.0 and enemies[i]["order"] != "CAPTURADO":
			living.append(i)
	for i in living:
		var unit: Dictionary = enemies[i]
		unit["order"] = base
		enemies[i] = unit
	var guards := 0
	if hostile_posture == "ESCOLTA":
		var command_index := int(read["command_index"])
		var anchor: Vector3 = (enemies[command_index]["node"] as Node3D).global_position
		# Contra-medida lida do tabuleiro, não sorteada: quando a ponte concentra o disco em 4,5 u,
		# a guarda fecha por dentro. A ±3 os escoltas ficam fora do lance âncora e a capitânia apanha
		# sozinha; a ±2 os dois cascos entram no corredor do tiro e absorvem o que a postura deles
		# (ESCOLTA → densidade 0) já sabe que vem.
		var folga := 2.0 if fogo_densidade == 0 else 3.0
		var near := living.duplicate()
		near.sort_custom(func(a, b): return _enemy_distance(a, anchor) < _enemy_distance(b, anchor))
		for i in near:
			if i == command_index:
				continue
			var escort: Dictionary = enemies[i]
			escort["order"] = "ESCOLTAR"
			escort["escort_offset"] = -folga if guards == 0 else folga
			enemies[i] = escort
			guards += 1
			if guards >= 2:
				break
	hostile_focus = _hostile_victim_index()
	var focus_name := "nenhum contato aliado vivo"
	if hostile_focus >= 0:
		focus_name = String(fleet[hostile_focus]["name"])
	if bool(read["rout"]):
		tactical_note = "POSTURA HOSTIL: DEBACLA // capitânia sem casco; fogo residual em %s" % focus_name
	elif hostile_posture == "ESCOLTA":
		tactical_note = "POSTURA HOSTIL: ESCOLTA // %d casco(s) fechando em torno da capitânia; fogo em %s" % [guards, focus_name]
	else:
		tactical_note = "POSTURA HOSTIL: %s // %.0f%% de força relativa; fogo em %s" % [hostile_posture, float(read["ratio"]) * 100.0, focus_name]
	if previous != hostile_posture and is_instance_valid(report_label):
		report_label.text = "INTELIGÊNCIA // " + tactical_note

## Os pontos de impacto de uma salva. O disco é o plano da mesa de batalha — lateral e profundidade
## a partir da mira, nunca vertical: as esquadras vivem em y ≈ 0, então um leque aberto para cima
## jogaria metade da salva num lugar onde não existe casco nenhum. É o mesmo plano do anel desenhado
## na mesa holográfica, e é por isso que o alcance é geometricamente honesto. Os fracos vão do
## centro até a borda e o ângulo sai do índice do casco no ouro ângulo — geometria decide a
## esparrama, nenhum sorteio é chamado aqui.
func _pontos_de_impacto(origem: Vector3, alvo: Vector3, no_casco: int, densidade: int) -> Array[Vector3]:
	var direcao := alvo - origem
	if direcao.length_squared() < 0.0001:
		direcao = Vector3(0.0, 0.0, -1.0)
	direcao = direcao.normalized()
	var lado := direcao.cross(Vector3.UP)
	if lado.length_squared() < 0.0001:
		lado = Vector3.RIGHT
	lado = lado.normalized()
	var pontos: Array[Vector3] = []
	var degraus := maxi(1, FLECHAS_POR_SALVA - 1)
	for k in range(FLECHAS_POR_SALVA):
		var angulo := float(no_casco) * 2.39996 + float(k) * TAU / float(FLECHAS_POR_SALVA)
		var fracao := float(k) / float(degraus)
		var raio: float = FOGO_RAIO[densidade] * fracao
		pontos.append(alvo + (lado * cos(angulo) + direcao * sin(angulo)) * raio)
	return pontos


## Quem absorve um ponto de impacto: o casco vivo mais próximo, desde que o ponto caia sobre ele.
## Devolve -1 no vão da salva — é o preço de dispersar, e é também o que faz um cinturão denso
## valer mais que um campo aberto.
func _casco_em(ponto: Vector3, lista: Array[Dictionary]) -> int:
	var melhor := -1
	var melhor_d := HULL_RADIUS + FOGO_LETAL
	for i in range(lista.size()):
		if float(lista[i]["hp"]) <= 0.0 or String(lista[i]["order"]) == "CAPTURADO":
			continue
		var distancia: float = (lista[i]["node"] as Node3D).global_position.distance_to(ponto)
		if distancia < melhor_d:
			melhor_d = distancia
			melhor = i
	return melhor


## Hostil que encosta na capitânia da ponte: é a ameaça que fecha a batalha, então a linha aliada
## o põe acima de qualquer outro contato na escada de iniciativa.
func _hostil_da_ponte() -> int:
	var melhor := -1
	var melhor_d := INF
	for i in range(enemies.size()):
		if float(enemies[i]["hp"]) <= 0.0 or String(enemies[i]["order"]) == "CAPTURADO":
			continue
		var distancia: float = (enemies[i]["node"] as Node3D).global_position.distance_to(bridge_rig.global_position)
		if distancia < melhor_d:
			melhor_d = distancia
			melhor = i
	return melhor


## Escada de iniciativa da linha aliada. Quem não está sob ordem expressa de ataque escolhe o
## próprio alvo, e a escolha obedece a três pesos declaredos aqui (a sonda os mede um por um):
## o hostil que encosta na capitânia vale +14 (perder a ponte é perder a batalha, e 14 u é mais do
## que qualquer aproximação racional justifica trocar por ele); um casco no último quarto de arco
## vale +6,0 contra um intacto — terminar um trabalho custa menos que começar outro; e o resto é
## distância pura de quem atira. Deconfliction: um alvo já apontado por um casco não perde o
## segundo, mas a partir do terceiro a fila anda (-8,0 por lance excedente), que é o que impede a
## esquadra de formar uma fila para o mesmo número de série enquanto os outros viram alvo livre.
## Em CONCENTRADO a escada cede ao comando: o disco de 4,5 u existe justamente para jogar a frota
## inteira sobre o casco escolhido pela ponte. Leitura pura do tabuleiro — nenhum sorteio, e é por
## isso que a densidade mudou o *para onde* do dano, nunca o *quantos dados* rolados.
func _alvo_aliado_autonomo(no_aliado: int, foco: int, engajados: Dictionary) -> int:
	if fogo_densidade == 0:
		return foco
	if no_aliado < 0 or no_aliado >= fleet.size():
		return -1
	var pos: Vector3 = (fleet[no_aliado]["node"] as Node3D).global_position
	var ameaca := _hostil_da_ponte()
	var melhor := -1
	var melhor_valor := -INF
	for i in range(enemies.size()):
		if float(enemies[i]["hp"]) <= 0.0 or String(enemies[i]["order"]) == "CAPTURADO":
			continue
		var valor := -pos.distance_to((enemies[i]["node"] as Node3D).global_position)
		valor += (100.0 - float(enemies[i]["hp"])) * 0.06
		if i == ameaca:
			valor += 14.0
		var carga := int(engajados.get(i, 0))
		if carga >= 2:
			valor -= 8.0 * float(carga - 1)
		# `>` estrito: dois cascos no mesmo degrau da escada deixam o de índice menor no alvo,
		# que é o que torna a salva reproduzível de rodada para rodada.
		if valor > melhor_valor:
			melhor_valor = valor
			melhor = i
	return melhor


## Densidade de fogo hostil vem da postura, não de sorteio: quem avança varre área para abrir
## corredor, quem cobre a capitânia concentra no casco que a ameaça, quem debanda atira largo e
## desperdiça.
func _densidade_hostil() -> int:
	match hostile_posture:
		"ESCOLTA":
			return 0
		"AVANÇAR":
			return 1
		_:
			return 2


## Um clique, um degrau, e a escada tem piso e teto: mais baixo que CONCENTRADO não existe, e
## empurrar o disco para além de DISPERSO seria mentir sobre o alcance da própria salva.
func _ajustar_fogo(passo: int) -> void:
	var anterior := fogo_densidade
	fogo_densidade = clampi(fogo_densidade + passo, 0, FOGO_RAIO.size() - 1)
	if fogo_densidade == anterior:
		report_label.text = "FOGO %s // a ponte não tem outro degrau de densidade abaixo (ou acima) dele." % FOGO_NOME[fogo_densidade]
		_update_hud()
		return
	_desenhar_setor_de_fogo()
	report_label.text = "DENSIDADE DE FOGO: %s // disco de %.1f u; %d impacto(s) por navio a cada salva." % [
		FOGO_NOME[fogo_densidade], FOGO_RAIO[fogo_densidade], FLECHAS_POR_SALVA]
	_update_hud()


func _resolve_volley() -> void:
	# Primeiro incorpora as presas da salva anterior: a contagem de vitória abaixo lê
	# `enemies`, e uma presa que ainda consta como hostil adia a batalha para sempre.
	_integrate_captured_ships()
	# Depois a IA hostil relê o tabuleiro; a retaliação desta salva usa o alvo escolhido aqui.
	_apply_hostile_tactics()
	# Sem ponte não há salva: a capitânia é corpo no campo agora, e abalroar custa casco também
	# para quem comando.
	if capital_hp <= 0.0:
		report_label.text = "DERROTA // capitânia perdida: a frota ficou sem ponte de comando."
		_encerra_batalha()
		return
	var living_enemies := 0
	var living_allies := 0
	for enemy in enemies:
		if enemy["hp"] > 0.0 and enemy["order"] != "CAPTURADO":
			living_enemies += 1
	for ally in fleet:
		if ally["hp"] > 0.0:
			living_allies += 1
	if living_enemies == 0:
		report_label.text = "VITÓRIA TÁTICA // Frota hostil neutralizada."
		_encerra_batalha()
		return
	if living_allies == 0:
		report_label.text = "DERROTA // Frota aliada neutralizada."
		_encerra_batalha()
		return
	var focus_target := selected_target
	if focus_target < 0 or focus_target >= enemies.size() or enemies[focus_target]["hp"] <= 0.0 or enemies[focus_target]["order"] == "CAPTURADO":
		focus_target = -1
		for i in range(enemies.size()):
			if enemies[i]["hp"] > 0.0 and enemies[i]["order"] != "CAPTURADO":
				focus_target = i
				break
	# A ponte manda a salva para um setor, não para um casco: o centro do disco é o alvo comandado
	# e ele é desenhado na mesa antes de qualquer impacto existir.
	setor_fogo_pos = (enemies[focus_target]["node"] as Node3D).global_position
	# Cada casco vivo atira por conta própria e manda FLECHAS_POR_SALVA impactos sobre o disco.
	# Quem está sob ordem de ataque (ou fechando para abordar) obedece ao setor da ponte; o resto
	# da linha tem iniciativa e sobe a escada de alvo — é isto que separa uma esquadra de doze
	# torretas todas apontadas para o mesmo número de série.
	var engajados: Dictionary = {}
	var feridos := 0
	var nos_vaos := 0
	var nas_pedras := 0
	var rachadas := 0
	var impactos := 0
	for i in range(fleet.size()):
		var ally: Dictionary = fleet[i]
		if ally["hp"] <= 0.0 or ally["weapons"] <= 0.0:
			continue
		var ordem := String(ally["order"])
		var alvo_index := focus_target
		if ordem != "ATACAR" and ordem != "ABORDAR":
			alvo_index = _alvo_aliado_autonomo(i, focus_target, engajados)
		if alvo_index < 0:
			continue
		engajados[alvo_index] = int(engajados.get(alvo_index, 0)) + 1
		var damage := 2.5 * float(ally["weapons"]) / 100.0 * maxf(0.25, float(ally["crew"]) / 100.0)
		if ordem == "ATACAR":
			damage *= 1.8
		if ordem == "RESERVA":
			damage *= 0.35
		var origem := (ally["node"] as Node3D).global_position
		var destino := (enemies[alvo_index]["node"] as Node3D).global_position
		# Arma quente: o multiplicador entra pela posição de quem dispara, não por sorteio, e fora
		# do raio de calor é exatamente 1,0 — que é o que deixa o campo aberto inalterado.
		damage *= _fator_calor(origem)
		var por_flecha := damage / float(FLECHAS_POR_SALVA)
		var subsistema := subsystem_selector.get_item_text(subsystem_selector.selected) if ordem == "ATACAR" and is_instance_valid(subsystem_selector) else "CASCO"
		# A salva inteira tem sempre FLECHAS_POR_SALVA lances por navio, em qualquer densidade: o que
		# o disco muda é para onde o dano vai, nunca quantos sorteios a salva consome. Trocar o laço
		# por "só atirar o que acerta" faria da densidade de fogo um reroll disfarçado.
		for ponto in _pontos_de_impacto(origem, destino, i, fogo_densidade):
			impactos += 1
			var bloqueio := _rocha_entre(origem, ponto)
			# Pedra no corredor: o lance existe, vai até a rocha e não fere ninguém. Absorver dano não
			# muda quantos sorteios a salva consome — ver a cauda de RNG em `_resolve_volley`.
			_spawn_bolt((ponto if bloqueio.is_empty() else bloqueio["pos"]), BLUE, origem)
			if not bloqueio.is_empty():
				nas_pedras += 1
				# O que a pedra absorveu ela paga em integridade, nunca em sorteio: rachar é conta do
				# ângulo de chegada, e a cauda de `rng` da batalha tem de sair idêntica.
				if _fraturar_rocha(bloqueio["pedra"] as Dictionary, por_flecha, origem):
					rachadas += 1
				continue
			var atingido := _casco_em(ponto, enemies)
			if atingido < 0:
				nos_vaos += 1
				continue
			feridos += 1
			if subsistema == "MOTORES":
				enemies[atingido]["engines"] = maxf(0.0, float(enemies[atingido]["engines"]) - por_flecha * 1.7)
			elif subsistema == "ARMAS":
				enemies[atingido]["weapons"] = maxf(0.0, float(enemies[atingido]["weapons"]) - por_flecha * 1.7)
			elif subsistema == "TRIPULAÇÃO":
				enemies[atingido]["crew"] = maxf(0.0, float(enemies[atingido]["crew"]) - por_flecha * 1.5)
			else:
				enemies[atingido]["hp"] = maxf(0.0, float(enemies[atingido]["hp"]) - por_flecha)
			if enemies[atingido]["hp"] <= 0.0:
				_mark_wreck(enemies[atingido]["node"] as Node3D)
				report_label.text = "ALVO DESTRUÍDO // %s neutralizado." % enemies[atingido]["name"]
			elif float(enemies[atingido]["engines"]) <= 0.0:
				enemies[atingido]["order"] = "RECUAR"
	_desenhar_setor_de_fogo()
	# Boarding parties progress in real time after reaching a sufficiently damaged ship.
	for target_index in range(enemies.size()):
		var target_enemy: Dictionary = enemies[target_index]
		if target_enemy["hp"] <= 0.0 or target_enemy["hp"] > 55.0 or target_enemy["order"] == "CAPTURADO":
			continue
		for ally in fleet:
			if ally["hp"] <= 0.0 or ally["order"] != "ABORDAR":
				continue
			var boarding_ship: Node3D = ally["node"]
			var target_ship: Node3D = target_enemy["node"]
			if boarding_ship.global_position.distance_to(target_ship.global_position) <= 18.0:
				target_enemy["crew"] = maxf(0.0, float(target_enemy["crew"]) - 7.0)
				if target_enemy["crew"] <= 0.0:
					target_enemy["order"] = "CAPTURADO"
					target_enemy["weapons"] = 0.0
					target_enemy["team"] = "friendly"
					report_label.text = "NAVE CAPTURADA // %s agora está sob controle da frota." % target_enemy["name"]
				else:
					report_label.text = "ABORDAGEM // %s: resistência inimiga diminuindo." % target_enemy["name"]
				break
		enemies[target_index] = target_enemy
	# Hostile ships retaliate on their own and may damage specific systems. A esquadra hostil usa o
	# mesmo disco: a postura dela é que define a densidade, não um sorteio por salva.
	var densidade_hostil := _densidade_hostil()
	var hostis_feriram := 0
	var hostis_no_vao := 0
	var impactos_hostis := 0
	for e_index in range(enemies.size()):
		var enemy: Dictionary = enemies[e_index]
		if enemy["order"] == "CAPTURADO" or enemy["hp"] <= 0.0 or enemy["weapons"] <= 0.0:
			continue
		var victim_index := hostile_focus
		if victim_index < 0 or victim_index >= fleet.size() or float(fleet[victim_index]["hp"]) <= 0.0:
			victim_index = _hostile_victim_index()
		if victim_index < 0:
			break
		var damage := 1.3 * float(enemy["weapons"]) / 100.0 * maxf(0.25, float(enemy["crew"]) / 100.0)
		var origem := (enemy["node"] as Node3D).global_position
		var destino := (fleet[victim_index]["node"] as Node3D).global_position
		damage *= _fator_calor(origem)
		var por_flecha := damage / float(FLECHAS_POR_SALVA)
		var absorvente_foco := victim_index
		var feriu := false
		var pontos_hostis: Array[Vector3] = _pontos_de_impacto(origem, destino, e_index, densidade_hostil)
		for k in range(pontos_hostis.size()):
			impactos_hostis += 1
			var bloqueio := _rocha_entre(origem, pontos_hostis[k])
			_spawn_bolt((pontos_hostis[k] if bloqueio.is_empty() else bloqueio["pos"]), RED, origem, false)
			if not bloqueio.is_empty():
				hostis_no_vao += 1
				# A barreira serve dos dois lados, e cobra dos dois lados: a pedra que parou o lance
				# hostil também racha, pela mesma conta e sem sorteio.
				if _fraturar_rocha(bloqueio["pedra"] as Dictionary, por_flecha, origem):
					rachadas += 1
				continue
			var absorvente := _casco_em(pontos_hostis[k], fleet)
			if absorvente < 0:
				hostis_no_vao += 1
				continue
			# Cobertura é do casco atingido, não do visado: escoltar alguém só vale quando a escolta
			# está de fato no caminho da salva.
			var dano_flecha := por_flecha
			if String(fleet[absorvente]["order"]) == "ESCOLTAR":
				dano_flecha *= 0.7
			fleet[absorvente]["hp"] = maxf(0.0, float(fleet[absorvente]["hp"]) - dano_flecha)
			hostis_feriram += 1
			feriu = true
			if k == 0:
				absorvente_foco = absorvente
			if float(fleet[absorvente]["hp"]) <= 0.0:
				_mark_wreck(fleet[absorvente]["node"] as Node3D)
				report_label.text = "ALERTA // %s foi perdida." % String(fleet[absorvente]["name"])
		var victim: Dictionary = fleet[absorvente_foco]
		# A cadeia de sorteios é a mesma com ou sem rocha no corredor e com ou sem casco no disco:
		# o que a barreira e o vão levam é o dano, nunca o consumo do gerador. Trocar `if
		# rng.randf()` por uma conta pulada mudaria a cauda de toda a batalha seguinte.
		var absorvido := not feriu
		if rng.randf() < 0.12:
			if not absorvido:
				victim["engines"] = maxf(0.0, float(victim["engines"]) - 4.0)
		elif rng.randf() < 0.1:
			if not absorvido:
				victim["weapons"] = maxf(0.0, float(victim["weapons"]) - 5.0)
		elif rng.randf() < 0.08:
			if not absorvido:
				victim["crew"] = maxf(0.0, float(victim["crew"]) - 3.0)
		if victim["hp"] <= 0.0:
			_mark_wreck(victim["node"] as Node3D)
			report_label.text = "ALERTA // %s foi perdida." % victim["name"]
		fleet[absorvente_foco] = victim
	salva_resumo = "salva: %d/%d aliadas feriram, %d/%d hostis, %d cairam no vao // %d alvo(s) engajado(s)" % [
		feridos, impactos, hostis_feriram, impactos_hostis, nos_vaos + nas_pedras + hostis_no_vao,
		engajados.size()]
	salva_contagem = {"aliados": impactos, "aliados_feriram": feridos, "hostis": impactos_hostis,
		"hostis_feriram": hostis_feriram, "vaos": nos_vaos + hostis_no_vao, "pedras": nas_pedras}
	# A pedra é corpo no tabuleiro, então a fatura dela aparece no mesmo relatório que a dos cascos:
	# sem esta linha o comandante veria o cinturão encolher e rachar sem que a ponte anunciasse nada.
	if not rochas.is_empty():
		salva_resumo += " // cinturao: %d pedras, %d rachadas nesta salva" % [rochas.size(), rachadas]

## Uma presa só vira unidade quando sai de `enemies` e entra em `fleet`: enquanto fica na
## lista de hostis ela não recebe ordem nenhuma e o jogador assiste à captura de fora.
func _integrate_captured_ships() -> void:
	var gained := 0
	var i := enemies.size() - 1
	while i >= 0:
		if enemies[i]["order"] != "CAPTURADO":
			i -= 1
			continue
		var prize: Dictionary = enemies[i]
		enemies.remove_at(i)
		prize["team"] = "friendly"
		prize["order"] = "LINHA"
		prize["squadron"] = "PRESA"
		prize["repair_priority"] = "AUTO"
		prize["name"] = "PRESA %02d" % (fleet.size() + 1)
		fleet.append(prize)
		_mark_as_prize(prize["node"] as Node3D)
		gained += 1
		i -= 1
	if gained > 0:
		_rebuild_selectors()
		report_label.text = "INCORPORAÇÃO // %d presa(s) sob comando da frota; reparo automático em curso." % gained

## A incorporação é visual antes de ser burocrática: o filete vira azul, o escapamento esfria, a
## meia-volta aponta a proa para a própria linha e a marca dourada entra no filho "Casco", junto
## do resto do navio. Nenhum número muda aqui — só material e rotação do nó raiz.
func _mark_as_prize(ship: Node3D) -> void:
	var mats: Dictionary = ship.get_meta("mat")
	var mat_trim: StandardMaterial3D = mats["trim"]
	mat_trim.albedo_color = BLUE.darkened(0.35)
	mat_trim.emission = BLUE * 0.7
	var mat_gun: StandardMaterial3D = mats["gun"]
	mat_gun.emission = BLUE * 0.4
	var mat_engine: StandardMaterial3D = mats["engine"]
	mat_engine.emission = ESCOAMENTO_ALIADO
	(mats["luz"] as StandardMaterial3D).albedo_color = Color(BLUE, 0.75)
	# O material da pluma é reescrito todo quadro a partir desta chave: trocá-la é trocar a cor
	# do escapamento sem encostar em nenhum dos dois nós.
	ship.set_meta("escape", ESCOAMENTO_ALIADO)
	_box(Vector3(0, 0.95, 0.0), Vector3(0.55, 0.4, 0.55), _material(GOLD, 0.3, 0.25, GOLD * 0.8),
		ship.get_meta("casco"))
	ship.rotation.y = 0.0

## Escopo, alvo e escolta leem os arrays reais. add_item não reemite item_selected, então a
## escolha do comandante sobrevive à reconstrução enquanto o item correspondente existir.
func _rebuild_selectors() -> void:
	if is_instance_valid(scope_selector):
		var scopes: Array[String] = ["FROTA", "ESQUADRÃO ALFA", "ESQUADRÃO BETA"]
		for unit in fleet:
			if unit["squadron"] == "PRESA":
				scopes.append("ESQUADRÃO PRESA")
				break
		for n in range(1, fleet.size() + 1):
			scopes.append("NAVE %d" % n)
		scope_selector.clear()
		for scope in scopes:
			scope_selector.add_item(scope)
		var keep_scope := scopes.find(selection_scope)
		if keep_scope < 0:
			selection_scope = "FROTA"
			keep_scope = 0
		scope_selector.select(keep_scope)
	if is_instance_valid(target_selector):
		target_selector.clear()
		if enemies.is_empty():
			target_selector.add_item("SEM CONTATO HOSTIL")
			target_selector.select(0)
		else:
			for enemy in enemies:
				target_selector.add_item(enemy["name"])
			if selected_target >= enemies.size():
				selected_target = maxi(0, enemies.size() - 1)
			target_selector.select(selected_target)
	if is_instance_valid(protected_selector):
		var wanted := "CAPITÂNIA"
		if protected_selector.item_count > 0 and protected_selector.selected >= 0:
			wanted = protected_selector.get_item_text(protected_selector.selected)
		protected_selector.clear()
		protected_selector.add_item("CAPITÂNIA")
		for unit in fleet:
			protected_selector.add_item(unit["name"])
		var keep_prot := 0
		for idx in range(protected_selector.item_count):
			if protected_selector.get_item_text(idx) == wanted:
				keep_prot = idx
				break
		protected_selector.select(keep_prot)
		protected_unit_index = keep_prot - 1
	# A mesa holográfica lê as mesmas listas dos seletores: incorporar presa reemite os blips
	# pelo mesmo caminho que reemite os itens, sem cadastro paralelo.
	_rebuild_holo()

## O traço de fogo: um prisma fino e emissivo que corre do atirador ao alvo. A trilha aliada
## paga exatamente os dois sorteios de `rng` de sempre, na mesma ordem — é o orçamento que a
## cauda de combate cobra e que `tools/probes/sondas.gd` confere. O lance hostil sai de
## `visual_rng`, então inimigo passando a atirar na tela não reescreve um dano sequer.
func _spawn_bolt(destino: Vector3, cor: Color, origem: Vector3, cauda_de_combate := true) -> void:
	# O disparo se ouve no lançamento, não no impacto: é o traço saindo do bocal. A janela
	# anti-spam de `efeito()` é o que impede doze lances da mesma salva virarem doze apitos.
	audio.efeito("LASER")
	var dx := 0.0
	var dy := 0.0
	if cauda_de_combate:
		dx = rng.randf_range(-1, 1)
		dy = rng.randf_range(-1, 1)
	else:
		dx = visual_rng.randf_range(-1, 1)
		dy = visual_rng.randf_range(-1, 1)
	var saida := origem + Vector3(dx, dy, 0.0)
	var vetor := destino - saida
	var distancia := vetor.length()
	var lance := MeshInstance3D.new()
	var corpo := CylinderMesh.new()
	corpo.bottom_radius = 0.22
	corpo.top_radius = 0.06
	corpo.height = minf(maxf(distancia * 0.32, 2.2), 16.0)
	corpo.radial_segments = 4
	corpo.rings = 1
	lance.mesh = corpo
	lance.material_override = _material(cor, 0.0, 0.2, cor * 1.4)
	lance.material_override.emission_energy_multiplier = 2.4
	# No tree, no global transform: global_position lida antes de add_child devolve
	# Transform3D() e imprime um ERROR por salva (medido no smoke headless).
	add_child(lance)
	lance.global_position = saida
	# Direção nula faz look_at reclamar; dois cascos colados é um caso real de abordagem.
	if distancia > 0.001:
		lance.look_at(destino, Vector3.UP)
		# O eixo do prisma é +Y e `look_at` aponta -Z para o alvo: -90° em X alinha os dois.
		lance.rotate_x(-PI / 2)
	var tween := create_tween()
	tween.tween_property(lance, "global_position", destino, 0.22)
	tween.tween_callback(lance.queue_free)

func _give_order(order: String) -> void:
	var selected := _selected_indices()
	if selected.is_empty():
		report_label.text = "NENHUMA UNIDADE VIVA NA SELEÇÃO."
		return
	if order == "ABORDAR":
		if selected_target >= enemies.size() or enemies[selected_target]["hp"] > 55.0:
			report_label.text = "ABORDAGEM NEGADA // selecione um alvo danificado (55% de casco ou menos)."
			return
	if order == "MOVER":
		move_x = position_x_input.value if is_instance_valid(position_x_input) else 0.0
		move_z = position_z_input.value if is_instance_valid(position_z_input) else -65.0
	# Dispersar e agrupar são densidade, não desenho: o raio do anel vem da ordem, não da formação.
	var raio_anel := 0.0
	if order == "DISPERSAR":
		raio_anel = DISPERSAR_RAIO
	elif order == "AGRUPAR":
		raio_anel = AGRUPAR_RAIO
	var centro := _centro_selecao(selected) if raio_anel > 0.0 else Vector3.ZERO
	for k in range(selected.size()):
		var i: int = selected[k]
		var unit: Dictionary = fleet[i]
		unit["order"] = order
		if order == "MOVER":
			unit["destination"] = Vector3(move_x + (float(i) - 2.5) * FORMATION_STEP, 0.0, move_z)
		elif raio_anel > 0.0:
			unit["destination"] = _anel_posto(k, selected.size(), centro, raio_anel)
		fleet[i] = unit
	if order == "ATACAR":
		report_label.text = "%d unidade(s) atacando %s / %s. Combate contínuo." % [selected.size(), enemies[selected_target]["name"], subsystem_selector.get_item_text(subsystem_selector.selected)]
	elif order == "RECONHECER":
		var launched := _launch_probes(selected)
		if launched == 0:
			report_label.text = "SONDAS JÁ EM VARREDURA // %d sonda(s) no ar; lançar de novo não empilha." % probes.size()
		else:
			report_label.text = "SONDAS LANÇADAS // %d sonda(s) em varredura; %d/%d contato(s) confirmado(s)." % [launched, recon_contacts, recon_total]
	elif order == "ABORDAR":
		report_label.text = "ABORDAGEM INICIADA // unidades selecionadas aproximam-se de %s." % enemies[selected_target]["name"]
	elif order == "RESERVA":
		report_label.text = "RESERVA TÁTICA // unidades selecionadas preservam força e posição."
	elif order == "MOVER":
		report_label.text = "NAVEGAÇÃO TÁTICA // unidades selecionadas receberam posição de destino."
	elif order == "DISPERSAR" or order == "AGRUPAR":
		report_label.text = "%s EM EXECUÇÃO // %d casco(s) navegando para o anel de %.1f u." % [
			order, selected.size(), raio_anel]
	else:
		report_label.text = "ORDEM %s TRANSMITIDA A %d UNIDADE(S). A BATALHA CONTINUA." % [order, selected.size()]
	_update_hud()

func _selected_indices() -> Array[int]:
	var result: Array[int] = []
	for i in range(fleet.size()):
		var include_unit := false
		if selection_scope == "FROTA":
			include_unit = true
		elif selection_scope == "ESQUADRÃO ALFA":
			include_unit = fleet[i]["squadron"] == "ALFA"
		elif selection_scope == "ESQUADRÃO BETA":
			include_unit = fleet[i]["squadron"] == "BETA"
		elif selection_scope == "ESQUADRÃO PRESA":
			include_unit = fleet[i]["squadron"] == "PRESA"
		elif selection_scope.begins_with("NAVE "):
			include_unit = i == int(selection_scope.trim_prefix("NAVE ")) - 1
		if include_unit and fleet[i]["hp"] > 0.0:
			result.append(i)
	return result

func _on_scope_selected(index: int) -> void:
	selection_scope = scope_selector.get_item_text(index)
	report_label.text = "SELEÇÃO ATUAL: %s. Novas ordens afetarão somente esta seleção." % selection_scope
	_update_hud()

func _on_target_selected(index: int) -> void:
	selected_target = index
	# O setor comandado acompanha o alvo escolhido na hora: o disco aparece na mesa antes de a
	# primeira salva sair, porque o comandante decide densidade olhando para ele.
	if index >= 0 and index < enemies.size():
		setor_fogo_pos = (enemies[index]["node"] as Node3D).global_position
		_desenhar_setor_de_fogo()
	_update_hud()

func _on_protected_selected(index: int) -> void:
	protected_unit_index = index - 1
	report_label.text = "ESCOLTA CONFIGURADA // protegendo %s." % protected_selector.get_item_text(index)

func _set_repair_priority(priority: String) -> void:
	for i in _selected_indices():
		var unit: Dictionary = fleet[i]
		unit["repair_priority"] = priority
		fleet[i] = unit
	report_label.text = "PRIORIDADE DE REPARO: %s para %s. Reparos continuam automáticos." % [priority, selection_scope]

## Postos de formação, medidos a partir do CENTRO REAL da seleção. Cravar z = -38 (como fazia a
## versão antiga) teletransportava a frota de volta para uma linha do cadastro: a formação passou a
## ser uma ordem de navegação, executada na velocidade do próprio motor, e é por isso que o posto é
## um deslocamento em torno de onde os cascos realmente estão.
func _formacao_posto(posicao: int, total: int, centro: Vector3) -> Vector3:
	if total <= 0:
		return centro
	var meio := float(total - 1) / 2.0
	match formation:
		"COLUNA":
			# Um atrás do outro no eixo de avanço: a coluna é a formação de passagem, não de fogo.
			return centro + Vector3(0.0, 0.0, -float(posicao) * FORMATION_STEP)
		"ANEL":
			# Círculo fechado com passo garantido: o raio cresce com o número de cascos para que
			# vizinhos nunca fiquem a menos de 2 * HULL_RADIUS, senão a formação se abalroa sozinha.
			var raio := maxf(FORMATION_STEP, float(total) * FORMATION_STEP / (2.0 * PI))
			var angulo := float(posicao) / float(total) * TAU
			return centro + Vector3(cos(angulo) * raio, 0.0, sin(angulo) * raio)
		"CUNHA":
			# Ápice adiantado (-Z é a direção do inimigo), flancos varridos para trás. O protótipo
			# fazia o contrário — `-absf(i - meio)` — e o resultado era um cálice: as asas na frente
			# e o centro atrás, que é a formação de receber fogo, não de aplicá-lo.
			return centro + Vector3((float(posicao) - meio) * FORMATION_STEP, 0.0,
				-(meio - absf(float(posicao) - meio)) * FORMATION_STEP)
		_:
			# LINHA: leque lateral com alternância de profundidade, para dois cascos não taparem o
			# mesmo arco na mesa.
			return centro + Vector3((float(posicao) - meio) * FORMATION_STEP, 0.0,
				-float(posicao % 2) * FORMATION_STEP)

## Centro geométrico dos cascos vivos da seleção — a âncora da formação. Destroço fica de fora:
## corpo sem motor não entra em conta de manobra.
func _centro_selecao(selected: Array[int]) -> Vector3:
	var soma := Vector3.ZERO
	var vivos := 0
	for i in selected:
		var unit: Dictionary = fleet[i]
		if float(unit["hp"]) <= 0.0:
			continue
		soma += (unit["node"] as Node3D).position
		vivos += 1
	if vivos == 0:
		return Vector3.ZERO
	return soma / float(vivos)

## Formação é ordem de navegação, não alinhamento de cadastro: escreve o posto como destino e
## manda o casco andar até lá. O tempo de locomoção é o preço da manobra — uma linha que se refaz
## em um quadro não pode ser punida nem aproveitada taticamente.
func _set_formation(new_formation: String) -> void:
	var selected := _selected_indices()
	if selected.is_empty():
		report_label.text = "NENHUMA UNIDADE VIVA NA SELEÇÃO."
		return
	# A formação só é gravada depois da ordem ter para quem ir: cravar o rótulo antes faria o
	# painel anunciar "ANEL" enquanto nenhum casco se moveu, e painel que anuncia o que não
	# aconteceu deixa de ser leitura do campo para virar desejo do comandante.
	formation = new_formation
	var centro := _centro_selecao(selected)
	var postos := 0
	for k in range(selected.size()):
		var unit: Dictionary = fleet[selected[k]]
		if float(unit["hp"]) <= 0.0:
			continue
		unit["formation"] = new_formation
		unit["order"] = "MOVER"
		unit["destination"] = _formacao_posto(postos, selected.size(), centro)
		fleet[selected[k]] = unit
		postos += 1
	report_label.text = "FORMAÇÃO %s EM EXECUÇÃO // %d casco(s) navegando para os postos." % [
		new_formation, postos]
	_update_hud()

## Posto sobre um anel de raio dado — a mesma geometria do ANEL de formação, com o raio vindo por
## parâmetro. Agrupar e dispersar não são formações (não descrevem um desenho de fogo, descrevem
## densidade), então entram como ordem de navegação com anel próprio.
func _anel_posto(posicao: int, total: int, centro: Vector3, raio: float) -> Vector3:
	if total <= 1:
		return centro
	var angulo := float(posicao) / float(total) * TAU
	return centro + Vector3(cos(angulo) * raio, 0.0, sin(angulo) * raio)

## Abre e fecha um grupo do painel. Abrir um fecha o outro de propósito: com dois abertos a lista
## volta a ser longa, e o ponto do agrupamento é justamente não mostrar o que não foi pedido.
func _toggle_grupo(nome: String) -> void:
	if grupo_aberto == nome:
		_fecha_grupo(nome)
		grupo_aberto = ""
		report_label.text = "PAINEL RECOLHIDO // nenhuma categoria aberta."
		return
	if grupo_aberto != "" and group_bodies.has(grupo_aberto):
		_fecha_grupo(grupo_aberto)
	grupo_aberto = nome
	var corpo := group_bodies[nome] as Control
	corpo.visible = true
	(group_heads[nome] as Button).text = "▾  " + nome
	# `call_deferred` porque o corpo acabou de ficar visível: medir o retângulo dele antes do passe
	# de layout devolveria o tamanho velho (zero, para quem nunca foi mostrado) e a rolagem não
	# andaria um pixel.
	if is_instance_valid(painel_scroll):
		painel_scroll.ensure_control_visible.call_deferred(corpo)
	report_label.text = "PAINEL: %s. As ordens do grupo estão à vista." % nome

func _fecha_grupo(nome: String) -> void:
	(group_bodies[nome] as Control).visible = false
	(group_heads[nome] as Button).text = "▸  " + nome

## Cria o cabeçalho clicável e o corpo vazio do grupo; quem chama adiciona os botões no corpo.
func _add_grupo(pai: VBoxContainer, nome: String) -> VBoxContainer:
	var cabecalho := _add_button(pai, "▸  " + nome, func(): _toggle_grupo(nome))
	cabecalho.add_theme_color_override("font_color", Color(0.42, 0.86, 1.0))
	group_heads[nome] = cabecalho
	var corpo := VBoxContainer.new()
	corpo.add_theme_constant_override("separation", 6)
	corpo.visible = false
	pai.add_child(corpo)
	group_bodies[nome] = corpo
	return corpo

func _toggle_pause() -> void:
	paused = not paused
	pause_button.text = "RETOMAR" if paused else "PAUSAR [ESPAÇO]"
	report_label.text = "PAUSA TÁTICA // emita suas ordens." if paused else "BATALHA RETOMADA // executando ordens."
	# A trilha abaixa, não silencia: a pausa é leitura de mesa, não fim de combate.
	audio.abafar_trilha(paused)
	_update_hud()


## Fim de combate: o alarme fecha a cena e a trilha para. A guarda é necessária porque a salva
## vitoriosa reentra neste mesmo galho a cada 1,6 s enquanto o tabuleiro estiver morto, e um
## `efeito()` sem ela tocaria o alarme para sempre depois da batalha.
func _encerra_batalha() -> void:
	if batalha_encerrada:
		return
	batalha_encerrada = true
	audio.efeito("ALARME")
	audio.parar_trilha()

func _update_hud() -> void:
	if is_instance_valid(command_label):
		var living := 0
		var damaged := 0
		for item in fleet:
			if item["hp"] > 0.0:
				living += 1
				if item["engines"] < 70.0 or item["weapons"] < 70.0 or item["crew"] < 60.0:
					damaged += 1
		command_label.text = "FROTA: %d/%d NAVES | SELEÇÃO: %s\nFORMAÇÃO: %s | FOGO: %s (%.1f u) | DANIFICADAS: %d\nRECONHECIMENTO: %d%% // %d sonda(s) • %d/%d contato(s) confirmado(s)\nESTADO: %s // TEMPO REAL // ÚLTIMA SALVA: %s\n%s" % [living, fleet.size(), selection_scope, formation, FOGO_NOME[fogo_densidade], FOGO_RAIO[fogo_densidade], damaged, int(recon_progress), probes.size(), recon_contacts, recon_total, "PAUSADO" if paused else ("PONTE PERDIDA" if ponte_condenada else "EM COMBATE"), salva_resumo, tactical_note]
	if is_instance_valid(target_selector):
		for i in range(enemies.size()):
			# O casco só aparece para a ponte quando uma sonda encostou naquele hull: a
			# linha de baixa é o estado real do contato, não uma barra de tempo.
			var state := "CAPTURADO" if enemies[i]["order"] == "CAPTURADO" else ("CASCO %d%%" % int(enemies[i]["hp"]) if bool(enemies[i].get("seen", false)) else "NÃO IDENTIFICADO")
			target_selector.set_item_text(i, "%s [%s]" % [enemies[i]["name"], state])
