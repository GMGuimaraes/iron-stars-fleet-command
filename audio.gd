extends Node
## Ponte sonora: trilha clássica em laço durante a batalha e efeitos abafados, porque
## no vácuo não há ar que leve o agudo até o ouvido.
##
## Os WAVs vêm de `tools/synth_audio.py`, não de gravação: a partitura é texto, o
## re-gerar é reproduzível byte a byte e o repositório não embarca binário opaco. O
## abafamento já vem assado no arquivo (passa-baixa de quatro polos na síntese, medido
## em 62,9% -> 1,4% de energia acima de 1,2 kHz no laser), então rodar não custa filtro
## nenhum e a medida do abafamento é conferível no próprio WAV.
##
## Uso no jogo: `main.gd` monta este nó em `_ready`, chama `tocar_trilha()`, troca a faixa
## pelo `escolher_trilha(id)` do grupo TRILHA, e cada
## evento da batalha (`_spawn_bolt`, `_spawn_explosion`, `_apply_impact`, fim de
## combate) pede `efeito(nome)`. O filtro anti-spam por espécie existe porque uma
## salva inteira são até doze lances: sem janela, doze lasers no mesmo quadro viram
## chiado, não uma salva.
##
## Headless não tem dispositivo de saída, então a sonda lê `pedidos` (quantas vezes
## cada espécie foi chamada e quantas passaram do filtro) e o arquivo (duração,
## amostragem, centróide). Que o som sai alto e afinado num par de fones é o que só
## o comandante prova no editor.

## Catálogo de trilhas. O comandante escolhe uma no grupo TRILHA do painel; o padrão é
## a marcha de Beethoven que o jogo sempre abriu. `SILENCIO` não tem arquivo de propósito:
## ponte em silêncio é ausência de stream, não um WAV de quatro segundos de nada.
## As duas faixas Dvořák são transcrições conferidas do score público do Mutopia Project
## (Sinfonia n.9 "Do Novo Mundo", op.95 — ver o bloco `TRILHAS_NOVAS` em
## `tools/synth_audio.py`); a melodia é do score, a harmonia é redução própria.
const TRILHAS := {
	"ALEGRIA": {"arquivo": "res://assets/audio/tema_batalha.wav", "nome": "ODE À ALEGRIA"},
	"NOVO_MUNDO": {"arquivo": "res://assets/audio/novo_mundo.wav", "nome": "LARGO DO NOVO MUNDO"},
	"SCHERZO": {"arquivo": "res://assets/audio/novo_mundo_scherzo.wav", "nome": "SCHERZO DO NOVO MUNDO"},
	"SILENCIO": {"arquivo": "", "nome": "SILÊNCIO"},
}
const TRILHA_PADRAO := "ALEGRIA"
## Volume da trilha em dB: a ponte ouve a música, não é concerto. -13 dB deixa a
## trilha em segundo plano sem sumir quando o combate esfria.
const TRILHA_DB := -13.0
## ... e abaixa mais 8 dB na pausa tática: o comandante congela o quadro para ler a
## mesa, e a trilha alta nessa hora é ruído por cima da leitura.
const PAUSA_ATENUACAO_DB := 8.0
const EFEITOS := {
	"LASER": {"arquivo": "res://assets/audio/laser.wav", "db": -9.0, "janela": 0.16},
	"EXPLOSAO": {"arquivo": "res://assets/audio/explosao.wav", "db": -5.0, "janela": 0.22},
	"IMPACTO": {"arquivo": "res://assets/audio/impacto.wav", "db": -6.0, "janela": 0.30},
	"ALARME": {"arquivo": "res://assets/audio/alarme.wav", "db": -7.0, "janela": 1.20},
}
## Vozes por efeito: com uma só, dois cascos afundando no mesmo quadro calavam um ao
## outro. Três chega para as doze naves do tabuleiro sem montar um canal por navio.
const VOZES := 3

## Contadores da sonda. `pedidos` conta quem chamou; `soaram` conta quem passou do
## filtro de janela — é a diferença entre "a salva teve doze lances" e "o ouvido
## recebeu doze apitos".
var pedidos := {"LASER": 0, "EXPLOSAO": 0, "IMPACTO": 0, "ALARME": 0, "TRILHA": 0}
var soaram := {"LASER": 0, "EXPLOSAO": 0, "IMPACTO": 0, "ALARME": 0, "TRILHA": 0}

var trilha_player: AudioStreamPlayer
var trilha_stream: AudioStreamWAV
var trilha_id := TRILHA_PADRAO
var vozes := {}
var _ultimo_toque := {}
var _trilha_ao_vivo := false
## Motor de saída medido no `_ready`. Vale falso sob `--headless`, onde o driver é `Dummy`
## (medido nesta máquina: `Dummy` na sonda, `WASAPI` na janela).
##
## O motivo de existir é um defeito que a cabeça não vê: `AudioStreamPlayer.play()` registra uma
## playback no servidor de áudio mesmo sem alto-falante nenhum, e essa playback só é liberada no
## `update()` do mixer — que no `Dummy` do encerramento nunca chega a rodar depois do `stop()`.
## O resultado medido em 2026-10-20 foi `Leaked instance: AudioStreamPlaybackWAV` segurando o
## `tema_batalha.wav`, impresso como `1 resources still in use at exit` em toda corrida headless
## que saía com a trilha tocando (na janela, com WASAPI, o mesmo código não vaza nada). Este
## repositório não tem linha de tolerância no portão, então a ponte não pede playback onde não há
## para onde empurrar amostra. Os contadores `pedidos`/`soaram` continuam contando a decisão — é
## a decisão que a sonda mede, não o diafragma.
var _saida_real := false


func _motor_de_saida() -> String:
	if not Engine.has_singleton("AudioServer"):
		return ""
	var servidor = Engine.get_singleton("AudioServer")
	if servidor == null or not servidor.has_method("get_driver_name"):
		return ""
	return String(servidor.call("get_driver_name"))


func _ready() -> void:
	_saida_real = _motor_de_saida() != "Dummy"
	trilha_player = AudioStreamPlayer.new()
	trilha_player.volume_db = TRILHA_DB
	add_child(trilha_player)
	_carregar_trilha()
	for nome in EFEITOS:
		var config: Dictionary = EFEITOS[nome]
		var stream: AudioStreamWAV = load(String(config["arquivo"])) as AudioStreamWAV
		var grupo: Array[AudioStreamPlayer] = []
		for i in range(VOZES):
			var voz := AudioStreamPlayer.new()
			voz.stream = stream
			voz.volume_db = float(config["db"])
			add_child(voz)
			grupo.append(voz)
		vozes[nome] = grupo


## Monta a stream da trilha escolhida no player. Existe separada porque a troca acontece
## com o nó já vivo: `_ready` carrega uma vez e `escolher_trilha` recarrega quantas vezes
## o comandante mudar de ideia.
##
## Só uma stream fica apontada no player de cada vez — as três faixas juntas são ~6 MB de
## PCM, e um player por faixa seria memória tocando em paralelo com a escolhida.
func _carregar_trilha() -> void:
	trilha_player.stream = null
	trilha_stream = null
	var arquivo := String((TRILHAS[trilha_id] as Dictionary)["arquivo"])
	if arquivo == "":
		return
	trilha_stream = load(arquivo) as AudioStreamWAV
	# Laço explícito até a última amostra: com `loop_end` em zero o motor não tem para onde
	# voltar e a trilha pararia no fim dos 38 s em vez de emendar. A conta é pela duração, não
	# por `data.size() / 2`: medido em 2026-10-20, com o import em modo comprimido o `data` é
	# um contêiner Ogg e a divisão devolvia `loop_end` de 7,8 s — a frase recomeçaria no meio.
	trilha_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	trilha_stream.loop_begin = 0
	trilha_stream.loop_end = int(round(trilha_stream.get_length() * float(trilha_stream.mix_rate)))
	trilha_player.stream = trilha_stream


## Troca a faixa da ponte. Devolve falso se o identificador não está no catálogo — e não
## move estado nenhum: ordem digitada errado no painel não pode deixar a ponte sem música.
## Se a trilha estava ao vivo, a nova emenda no lugar; se o combate acabou (e a trilha
## foi parada), a troca prepara a faixa sem religar o som da derrota.
func escolher_trilha(id: String) -> bool:
	if not TRILHAS.has(id):
		return false
	if id == trilha_id:
		return true
	var estava_ao_vivo := _trilha_ao_vivo
	parar_trilha()
	trilha_id = id
	_carregar_trilha()
	if estava_ao_vivo and id != "SILENCIO":
		tocar_trilha()
	return true


func trilha_nome() -> String:
	return String((TRILHAS[trilha_id] as Dictionary)["nome"])


func trilha_arquivo() -> String:
	return String((TRILHAS[trilha_id] as Dictionary)["arquivo"])


## Toca (ou religa) o tema da batalha. Idempotente: um segundo clique não reinicia a
## música no meio da frase.
func tocar_trilha() -> void:
	pedidos["TRILHA"] += 1
	if _trilha_ao_vivo:
		return
	soaram["TRILHA"] += 1
	_trilha_ao_vivo = true
	if _saida_real:
		trilha_player.play()


func parar_trilha() -> void:
	if not _trilha_ao_vivo:
		return
	_trilha_ao_vivo = false
	trilha_player.stop()


## Pausa tática não silencia a ponte: abaixa. A trilha continua correndo porque o
## tempo do mundo está congelado, não a batalha terminou.
func abafar_trilha(abaixar: bool) -> void:
	trilha_player.volume_db = TRILHA_DB - (PAUSA_ATENUACAO_DB if abaixar else 0.0)


func trilha_ao_vivo() -> bool:
	return _trilha_ao_vivo


## Efeito com janela por espécie. O relógio é o do motor (`get_ticks_msec`), não o
## `battle_clock`: na pausa tática o jogo congela e o áudio não, e é exatamente ali
## que o filtro precisa continuar valendo.
func efeito(nome: String) -> void:
	if not vozes.has(nome):
		return
	pedidos[nome] += 1
	var agora := float(Time.get_ticks_msec()) / 1000.0
	var janela := float((EFEITOS[nome] as Dictionary)["janela"])
	if _ultimo_toque.has(nome) and agora - float(_ultimo_toque[nome]) < janela:
		return
	_ultimo_toque[nome] = agora
	soaram[nome] += 1
	if not _saida_real:
		return
	var grupo: Array[AudioStreamPlayer] = vozes[nome]
	for voz in grupo:
		if not voz.playing:
			voz.play()
			return
	# Todas ocupadas: a mais antiga dá lugar à nova. Chiado contínuo é pior que uma
	# detonação trocada.
	grupo[0].stop()
	grupo[0].play()


## Libera os nós e as streams no encerramento. O portão deste repositório reprova
## qualquer `resources still in use at exit`, e uma stream segurada por um player
## vivo é exatamente o que produz essa linha.
func _exit_tree() -> void:
	parar_trilha()
	for nome in vozes:
		var grupo: Array[AudioStreamPlayer] = vozes[nome]
		for voz in grupo:
			if not is_instance_valid(voz):
				continue
			voz.stream = null
			voz.stop()
	vozes.clear()
	# A ordem de destruição do motor solta os filhos antes de o pai sair da árvore, então o
	# player da trilha pode já não existir aqui — e um `stop()` em objeto liberto é o erro
	# que o portão reprovaria no encerramento.
	if is_instance_valid(trilha_player):
		trilha_player.stream = null
	trilha_stream = null
