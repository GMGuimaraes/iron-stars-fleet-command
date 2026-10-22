extends SceneTree

## Sonda da ponte sonora: a trilha clássica em laço e os efeitos abafados de vácuo.
##
## O pedido do comandante tem duas metades e cada uma falha de um jeito diferente.
##
## 1) «Música clássica durante a batalha»: o risco não é faltar música, é faltar LAÇO. Um
##    `AudioStreamWAV` importado comprimido entrega `data` como contêiner Ogg, e a conta
##    `loop_end = data.size() / 2` — que parece óbvia — devolvia 7,8 s para uma trilha de
##    38,4 s: a Ode à Alegria recomeçaria no meio da frase, todos os dias, sem um erro na
##    tela. Por isso a sonda cobra o laço pelo número de amostras que a duração anuncia, e
##    cobra o formato PCM que torna a conta conferível.
##    A casa agora tem TRÊS faixas (Beethoven e as duas transcrições do Novo Mundo de Dvořák,
##    58,18 s e 35,45 s) e um grupo TRILHA no painel para escolher entre elas. Isso multiplica a
##    superfície do mesmo defeito: o laço é recalculado a cada troca, então a sonda roda as três
##    faixas e confere cada `loop_end` contra o próprio arquivo — um `load()` que devolvesse a
##    faixa errada passaria na Ode à Alegria e quebraria o Largo em silêncio.
## 2) «Efeitos abafados porque no vácuo não há ar»: isto é uma alegação sobre FREQUÊNCIA, e
##    frequência não se prova por counter de player. A sonda lê os bytes do próprio WAV e
##    mede o brilho espectral (energia da primeira diferença sobre energia do sinal — o
##    declive que sobe conforme o agudo). E para a medida não virar superstição, ela
##    re-sintetiza em GDScript o laser ANTES do filtro e cobra que o arquivo embarcado tenha
##    brilho pelo menos quatro vezes menor que a própria forma crua.
##
## 3) «Toque no headless sem alto-falante»: o `Dummy` do `--headless` aceita o `play()` e
##    registra uma playback que o mixer, já encerrado, nunca libera. Medido: um
##    `AudioStreamPlaybackWAV` vazado segurando o `tema_batalha.wav`, impresso como
##    `1 resources still in use at exit` em toda corrida que terminava com a trilha tocando —
##    e nada disso acontece na janela, onde o driver é `WASAPI`. A sonda prende o driver medido
##    e cobra que a decisão de tocar continue contada mesmo sem playback pedido ao servidor.
##
## O resto é a inércia de sempre: nenhum método de áudio sorteia em `rng` (a cauda de
## combate é medida antes e depois de trezentas chamadas), a janela anti-spam transforma doze
## lances de uma salva em um apito, o alarme de fim de combate toca UMA vez embora a salva
## vitoriosa reentre no mesmo galho a cada 1,6 s, e `_exit_tree()` libera as streams — o
## portão deste repositório reprova `resources still in use at exit`.
##
## Headless não tem alto-falante. O que ela prova aqui é arquivo, laço, contadores e
## invariância; que a trilha está afinada e o abafamento soa como vácuo num par de fones é
## aprovação do comandante, e nada nesta sonda substitui isso.
##
## Uso: godot --headless --path . --quit-after 1800 -s res://tools/probes/audio.gd

const PASTA := "res://assets/audio/"
## Duração, amostragem e rms medidos por `tools/synth_audio.py` nos mesmos bytes que esta
## sonda lê: o número é porta de conferência, não alvo a acertar de memória.
const ARQUIVOS := {
	"tema_batalha.wav": {"sr": 32000, "dur": 38.40, "rms": 0.254},
	"novo_mundo.wav": {"sr": 32000, "dur": 58.18, "rms": 0.240},
	"novo_mundo_scherzo.wav": {"sr": 32000, "dur": 35.45, "rms": 0.249},
	"laser.wav": {"sr": 22050, "dur": 0.30, "rms": 0.292},
	"explosao.wav": {"sr": 22050, "dur": 1.15, "rms": 0.195},
	"impacto.wav": {"sr": 22050, "dur": 0.42, "rms": 0.155},
	"alarme.wav": {"sr": 22050, "dur": 0.90, "rms": 0.439},
}
## Teto de amostras por arquivo: a maior das três trilhas são 1,86 M de quadros (o Largo,
## 58,18 s em 32 kHz) e o GDScript percorre isso em fração de segundo, então a sonda mede o
## mesmo trecho que o gerador reportou, em vez de uma fatia dos primeiros segundos — fatia faria
## do rms uma grandeza diferente da comparada. Medido: cortar o Largo em 1,4 M dava rms 0,240
## contra 0,2401 do arquivo inteiro, o que passaria na tolerância por acaso, não por contrato.
const MEDIDA_MAX := 1900000
## PCM de 16 bits assinado — o valor da enumeração `Format` do `AudioStreamWAV` do motor. Em
## 4.7 o nome `FORMAT_PCM_16` não resolve na parse (`Cannot find member`), então o número cru
## entra aqui, com a convenção escrita: 0 = IMA ADPCM, 1 = PCM 16, 2 = PCM 8, 3 = float.
const FORMATO_PCM_16 := 1

var breaks := 0
var notes: Array[String] = []

func _assert(label: String, condition: bool, detail: String) -> void:
	if condition:
		notes.append("OK   %s — %s" % [label, detail])
	else:
		breaks += 1
		notes.append("QUEBRA %s — %s" % [label, detail])

func _igual(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _montar_jogo() -> Node3D:
	var game: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	await _frames(3)
	return game

## Lê o WAV cru (não o `.sample` importado) e devolve cabeçalho, nível e brilho.
## O arquivo do disco é o que `tools/synth_audio.py` escreveu: medir outro bytes seria
## conferir o importador, não o som.
func _mede_wav(caminho: String) -> Dictionary:
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null:
		return {}
	var bruto: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	if bruto.size() < 44:
		return {}
	var total_amostras := bruto.decode_u32(40) / 2
	var limite := mini(total_amostras - 202, MEDIDA_MAX)
	var soma := 0.0
	var diff := 0.0
	var pico := 0.0
	var clipados := 0
	for i in range(200, 200 + limite):
		var v := float(bruto.decode_s16(44 + i * 2))
		var w := float(bruto.decode_s16(44 + (i + 1) * 2))
		soma += v * v
		var d := w - v
		diff += d * d
		pico = maxf(pico, absf(v))
		if absf(v) >= 32766.0:
			clipados += 1
	if soma <= 0.0:
		return {}
	return {
		"rotulo": bruto.slice(0, 4).get_string_from_ascii() + bruto.slice(8, 12).get_string_from_ascii(),
		"fmt": bruto.slice(12, 16).get_string_from_ascii(),
		"codec": bruto.decode_u16(20),
		"canais": bruto.decode_u16(22),
		"sr": bruto.decode_u32(24),
		"bits": bruto.decode_u16(34),
		"marca": bruto.slice(36, 40).get_string_from_ascii(),
		"amostras": total_amostras,
		"dur": float(total_amostras) / float(bruto.decode_u32(24)),
		"brilho": diff / soma,
		"rms": sqrt(soma / float(limite)) / 32767.0,
		"pico": pico / 32767.0,
		"clipados": clipados,
	}

## O laser cru, re-sintetizado aqui (a mesma fórmula de `tools/synth_audio.py`, sem o
## passa-baixa). É o controle que impede a medição de brilho de virar superstição: sem ele,
## um número pequeno poderia significar "abafado" ou "a régua não vê agudo nenhum".
func _laser_cru() -> PackedFloat32Array:
	var sr := 22050.0
	var dur := 0.30
	var n := int(dur * sr)
	var saida := PackedFloat32Array()
	saida.resize(n)
	var f0 := 2100.0
	var f1 := 380.0
	for i in range(n):
		var t := float(i) / sr
		var freq := f0 * pow(f1 / f0, t / dur)
		var env := exp(-t / 0.075) * minf(1.0, t / 0.004)
		saida[i] = env * (sin(TAU * freq * t) + 0.28 * sin(TAU * freq * 2.0 * t))
	return saida

## Brilho de um buffer de GDScript, na mesma régua de `_mede_wav`.
func _brilho(dados: PackedFloat32Array) -> float:
	var soma := 0.0
	var diff := 0.0
	for i in range(200, dados.size() - 2):
		var v := dados[i]
		var d := dados[i + 1] - v
		soma += v * v
		diff += d * d
	if soma <= 0.0:
		return 0.0
	return diff / soma

func _initialize() -> void:
	# ---- 1. Os cinco arquivos, byte a byte -------------------------------------------
	var brilho_laser_cru := _brilho(_laser_cru())
	_assert("o controle cru tem agudo para medir", brilho_laser_cru > 0.10,
		"brilho do laser sem filtro = %.4f" % brilho_laser_cru)
	var medidos := {}
	for nome in ARQUIVOS:
		var m := _mede_wav(PASTA + nome)
		medidos[nome] = m
		var esp: Dictionary = ARQUIVOS[nome]
		if m.is_empty():
			_assert(nome, false, "arquivo ausente ou ilegível em res://assets/audio/")
			continue
		_assert(nome + ": cabeçalho RIFF/WAVE PCM mono de 16 bits",
			String(m["rotulo"]) == "RIFFWAVE" and String(m["fmt"]) == "fmt "
				and int(m["codec"]) == 1 and int(m["canais"]) == 1 and int(m["bits"]) == 16
				and String(m["marca"]) == "data",
			"codec=%d canais=%d bits=%d" % [int(m["codec"]), int(m["canais"]), int(m["bits"])])
		_assert(nome + ": amostragem e duração batem com a partitura",
			int(m["sr"]) == int(esp["sr"]) and _igual(float(m["dur"]), float(esp["dur"]), 0.01),
			"%d Hz, %.2f s (esperado %d Hz, %.2f s)" % [int(m["sr"]), float(m["dur"]),
				int(esp["sr"]), float(esp["dur"])])
		_assert(nome + ": nível sem estouro de escala",
			float(m["pico"]) < 0.95 and int(m["clipados"]) == 0,
			"pico %.3f, amostras clipadas %d" % [float(m["pico"]), int(m["clipados"])])
		_assert(nome + ": rms confere com o gerador",
			_igual(float(m["rms"]), float(esp["rms"]), 0.02),
			"rms %.3f (anunciado %.3f)" % [float(m["rms"]), float(esp["rms"])])
	# A meia-vida do abafamento: o arquivo embarcado contra a própria forma crua.
	var b_laser := float(medidos["laser.wav"]["brilho"])
	_assert("laser abafado: brilho embarcado cai abaixo de 1/4 do cru",
		b_laser < brilho_laser_cru / 4.0,
		"cru %.4f -> embarcado %.4f (razão %.2f)" % [brilho_laser_cru, b_laser, b_laser / brilho_laser_cru])
	_assert("detonação abafada: sem banda aguda perceptível",
		float(medidos["explosao.wav"]["brilho"]) < b_laser,
		"explosao %.4f < laser %.4f" % [float(medidos["explosao.wav"]["brilho"]), b_laser])
	# Detonação e abalroamento são os dois corpos graves da ponte. A medição derrubou a ordem que
	# este cabeçalho chutava (impacto mais grave que explosão): o gerador fecha a detonação em
	# 116 Hz de centro e o abalroamento em 146 Hz, então é a explosão o mais fundo dos dois. O que
	# importa para o vácuo não é o ranking entre eles, é nenhum dos dois ter banda aguda.
	var b_impacto := float(medidos["impacto.wav"]["brilho"])
	var b_explosao := float(medidos["explosao.wav"]["brilho"])
	_assert("detonação e abalroamento não têm agudo perceptível",
		b_explosao < 0.005 and b_impacto < 0.005,
		"explosao %.4f | impacto %.4f (piso 0,005; laser abafado %.4f)" % [b_explosao, b_impacto, b_laser])
	# A trilha NÃO passa pelo filtro — e a asserção que existia aqui («a trilha é mais brilhante
	# que os efeitos») foi reprovada pela medida: o barrido do laser embarcado (0,0142) e o alarme
	# (0,0306) são mais inclinados que a partitura (0,0096). A régua certa não é o ranking entre
	# sons, é cada arquivo contra a própria forma crua: o corte de 700 Hz em quatro polos tirou do
	# laser 12,5 vezes de inclinação e 62,9% -> 1,4% da energia acima de 1,2 kHz. O que a trilha
	# tem de provar é que conservou o agudo da própria escrita, sem filtro nenhum.
	var b_tema := float(medidos["tema_batalha.wav"]["brilho"])
	var b_alarme := float(medidos["alarme.wav"]["brilho"])
	_assert("a trilha clássica conserva o agudo da própria partitura (sem passa-baixa)",
		b_tema > b_explosao * 4.0 and b_tema > b_impacto * 4.0,
		"tema %.4f contra explosao %.4f e impacto %.4f | alarme %.4f, a exceção dentro da ponte" % [
			b_tema, b_explosao, b_impacto, b_alarme])
	# As duas faixas Dvořák também não passam pelo filtro — e a régua é a mesma: cada uma contra
	# os corpos graves da ponte, não uma contra a outra. O Scherzo é por natureza dez vezes mais
	# inclinado que o Largo (35,45 s de 3/4 em 132 bpm, registered de violino), e medir o brilho
	# das duas é o que prova que nenhuma das duas saiu da síntese abafada por engano.
	var b_largo := float(medidos["novo_mundo.wav"]["brilho"])
	var b_scherzo := float(medidos["novo_mundo_scherzo.wav"]["brilho"])
	_assert("as duas faixas do Novo Mundo conservam o agudo da própria escrita",
		b_largo > b_explosao * 4.0 and b_scherzo > b_explosao * 4.0,
		"largo %.4f | scherzo %.4f contra explosao %.4f e impacto %.4f" % [b_largo, b_scherzo,
			b_explosao, b_impacto])

	# ---- 2. O nó dentro da ponte ------------------------------------------------------
	var game: Node3D = await _montar_jogo()
	var audio = game.audio
	_assert("a ponte monta o nó sonoro", audio != null and String(audio.name) == "PonteSonora",
		"nome=%s" % (String(audio.name) if audio != null else "null"))
	if audio == null:
		for nota in notes:
			print("SONDA-AUDIO: " + nota)
		print("veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
		quit()
		return
	# Um player de trilha + VOZES por espécie. Contar nós é o que pega o player que nunca
	# foi criado: counter de efeito não vê canal faltando.
	_assert("treze players na cena (1 trilha + 4 espécies × 3 vozes)",
		audio.get_child_count() == 1 + 4 * 3, "%d filhos" % audio.get_child_count())
	_assert("a trilha abre tocando", bool(audio.trilha_ao_vivo()),
		"pedidos=%d soaram=%d" % [int(audio.pedidos["TRILHA"]), int(audio.soaram["TRILHA"])])
	audio.tocar_trilha()
	_assert("religar não reinicia a frase no meio",
		int(audio.pedidos["TRILHA"]) == 2 and int(audio.soaram["TRILHA"]) == 1,
		"pedidos=%d soaram=%d" % [int(audio.pedidos["TRILHA"]), int(audio.soaram["TRILHA"])])
	# ---- 2b. Onde não há alto-falante, não há playback ---------------------------------
	# O `Dummy` do headless aceita o `play()` e registra uma playback que o mixer, já morto no
	# encerramento, nunca libera: medida em 2026-10-20, isso dava `Leaked instance:
	# AudioStreamPlaybackWAV` segurando `tema_batalha.wav` e a linha
	# `1 resources still in use at exit` em toda corrida que saía com a trilha tocando. Na janela
	# (driver `WASAPI`, mesmo código) nada vaza. A asserção prende os dois lados: aqui o driver
	# é Dummy, então a ponte tem de decidir "toca" sem pedir playback ao servidor — e a decisão
	# continua contada, porque é ela que a sonda lê.
	var motor := String(audio._motor_de_saida())
	_assert("o motor de saída medido é o Dummy do headless", motor == "Dummy", "driver=[%s]" % motor)
	_assert("sem saída real a ponte não registra playback (e por isso não vaza stream)",
		not bool(audio._saida_real) and not audio.trilha_player.playing
			and bool(audio.trilha_ao_vivo()) and int(audio.soaram["TRILHA"]) == 1,
		"saida_real=%s playing=%s ao_vivo=%s soaram=%d" % [bool(audio._saida_real),
			audio.trilha_player.playing, bool(audio.trilha_ao_vivo()), int(audio.soaram["TRILHA"])])
	audio.efeito("LASER")
	_assert("o efeito também para no contador quando não há para onde empurrar amostra",
		int(audio.soaram["LASER"]) == 1
			and (audio.vozes["LASER"] as Array[AudioStreamPlayer])[0].playing == false,
		"soaram=%d, voz[0].playing=%s" % [int(audio.soaram["LASER"]),
			(audio.vozes["LASER"] as Array[AudioStreamPlayer])[0].playing])

	# ---- 3. Laço: a amostra final, não o meio do contêiner ----------------------------
	var stream: AudioStreamWAV = audio.trilha_stream
	var amostras_do_arquivo := int(medidos["tema_batalha.wav"]["amostras"])
	_assert("a trilha embarcada é PCM 16 bits mono em 32 kHz",
		stream.format == FORMATO_PCM_16 and stream.mix_rate == 32000
			and stream.stereo == false,
		"format=%d mix=%d stereo=%s" % [stream.format, stream.mix_rate, stream.stereo])
	_assert("duração da stream lida pelo motor igual à do arquivo",
		_igual(stream.get_length(), 38.40, 0.02), "%.3f s" % stream.get_length())
	# A fonte da verdade é o arquivo, lido em (1) — comparar `loop_end` com uma conta feita de
	# `loop_end` seria asserção vazia. É aqui que o bug do contêiner Ogg aparecia: a divisão
	# pelo tamanho do `data` dava 7,8 s de laço numa gravação de 38,4 s.
	_assert("laço até a última amostra do arquivo, não até o meio do contêiner",
		absi(stream.loop_end - amostras_do_arquivo) <= 1 and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
			and stream.loop_begin == 0,
		"loop_end=%d, última amostra do WAV=%d, começo=%d" % [stream.loop_end,
			amostras_do_arquivo, stream.loop_begin])

	# ---- 3b. Troca de faixa: as três trilhas montam a mesma ponte ----------------------
	# O grupo TRILHA do painel é escolha de gosto, e a conta que ele não pode mover é a do
	# combate. Duas coisas precisam cair aqui, e nenhuma das duas é vista pelas asserções de
	# cima: (a) cada uma das três faixas tem de chegar ao laço certo — o `loop_end` é recalculado
	# no `_carregar_trilha`, então um `load()` que devolvesse o arquivo errado ou um PCM comprimido
	# daria laço cortado numa das faixas sem tocar na Ode à Alegria que a sonda já conferiu;
	# (b) a troca tem de ser inerte para o `rng`, porque a cauda de combate é a invariância
	# central deste repositório e um `load()` que sorteasse seria um bug de gameplay, não de áudio.
	var estado_rng_antes: int = game.rng.state
	var estado_visual_antes: int = game.visual_rng.state
	var pedidos_da_troca := int(audio.pedidos["TRILHA"])
	var soaram_da_troca := int(audio.soaram["TRILHA"])
	var stream_alegria: AudioStreamWAV = audio.trilha_stream
	for troca in [["NOVO_MUNDO", "novo_mundo.wav"], ["SCHERZO", "novo_mundo_scherzo.wav"],
			["ALEGRIA", "tema_batalha.wav"]]:
		var id := String(troca[0])
		var arquivo := String(troca[1])
		pedidos_da_troca += 1
		soaram_da_troca += 1
		_assert("trocar para %s é aceito" % id, bool(audio.escolher_trilha(id)),
			"escolher_trilha devolveu falso")
		var nova: AudioStreamWAV = audio.trilha_stream
		var esp: Dictionary = medidos[arquivo]
		_assert("%s: a stream montada é a do arquivo escolhido" % id,
			String(audio.trilha_arquivo()) == "res://assets/audio/" + arquivo
				and nova == (load("res://assets/audio/" + arquivo) as AudioStreamWAV),
			"arquivo=%s" % audio.trilha_arquivo())
		_assert("%s: PCM 16 bits mono na amostragem da partitura" % id,
			nova.format == FORMATO_PCM_16 and nova.mix_rate == int(esp["sr"])
				and nova.stereo == false,
			"format=%d mix=%d stereo=%s" % [nova.format, nova.mix_rate, nova.stereo])
		# O laço de cada faixa conferido contra o próprio arquivo (a mesma régua da seção 3):
		# 58,18 s de Largo e 35,45 s de Scherzo são durações que nenhum valor emprestado da
		# Ode à Alegria cobriria.
		var amostras := int(esp["amostras"])
		_assert("%s: laço até a última amostra do próprio arquivo" % id,
			absi(nova.loop_end - amostras) <= 1 and nova.loop_mode == AudioStreamWAV.LOOP_FORWARD
				and nova.loop_begin == 0
				and _igual(nova.get_length(), float(esp["dur"]), 0.02),
			"loop_end=%d, última amostra=%d, %.3f s (anunciado %.2f s)" % [nova.loop_end,
				amostras, nova.get_length(), float(esp["dur"])])
		_assert("%s: como a trilha estava ao vivo, a faixa nova assume sem novo play" % id,
			bool(audio.trilha_ao_vivo()) and int(audio.pedidos["TRILHA"]) == pedidos_da_troca
				and int(audio.soaram["TRILHA"]) == soaram_da_troca,
			"ao_vivo=%s pedidos=%d soaram=%d" % [audio.trilha_ao_vivo(),
				int(audio.pedidos["TRILHA"]), int(audio.soaram["TRILHA"])])
	# Trocar de volta não duplica o recurso: o `load()` do motor devolve a mesma stream, e é isso
	# que permite ao comandante folhear as três faixas sem inchar a memória da ponte.
	_assert("voltar à Ode à Alegria reaproveita a mesma stream importada",
		audio.trilha_stream == stream_alegria, "instância trocou")
	# SILÊNCIO é ausência de stream, não um WAV de nada: se fosse um arquivo mudo, a ponte
	# continuaria segurando 3,7 MB de PCM e o `playing` ligado.
	audio.escolher_trilha("SILENCIO")
	_assert("silêncio larga a stream e para a trilha",
		audio.trilha_stream == null and audio.trilha_player.stream == null
			and not bool(audio.trilha_ao_vivo())
			and int(audio.pedidos["TRILHA"]) == pedidos_da_troca,
		"stream=%s ao_vivo=%s pedidos=%d" % [audio.trilha_stream, audio.trilha_ao_vivo(),
			int(audio.pedidos["TRILHA"])])
	# Id de faixa que não existe no catálogo: recusado sem mover nada — nem o catálogo, nem o
	# contador, nem a stream. A ponte muda de faixa por botão do painel, e um nome digitado errado
	# ali tem de ser um não, não um silêncio inesperado.
	var trilha_id_antes := String(audio.trilha_id)
	_assert("faixa inexistente é recusada sem estrago",
		not bool(audio.escolher_trilha("NAO_EXISTE"))
			and String(audio.trilha_id) == trilha_id_antes
			and int(audio.pedidos["TRILHA"]) == pedidos_da_troca
			and audio.trilha_stream == null,
		"id=%s pedidos=%d stream=%s" % [audio.trilha_id, int(audio.pedidos["TRILHA"]),
			audio.trilha_stream])
	# Escolher faixa com a ponte em silêncio não religa o play por cima da vontade do comandante:
	# carrega, fica pronto, mudo.
	audio.escolher_trilha("NOVO_MUNDO")
	_assert("escolher a faixa com a ponte muda carrega sem religar",
		audio.trilha_stream != null and not bool(audio.trilha_ao_vivo())
			and int(audio.pedidos["TRILHA"]) == pedidos_da_troca,
		"stream=%s ao_vivo=%s" % [audio.trilha_stream, audio.trilha_ao_vivo()])
	audio.tocar_trilha()
	pedidos_da_troca += 1
	soaram_da_troca += 1
	_assert("e um pedido de play assume a faixa escolhida",
		bool(audio.trilha_ao_vivo()) and String(audio.trilha_id) == "NOVO_MUNDO"
			and int(audio.pedidos["TRILHA"]) == pedidos_da_troca
			and int(audio.soaram["TRILHA"]) == soaram_da_troca,
		"ao_vivo=%s id=%s pedidos=%d soaram=%d" % [audio.trilha_ao_vivo(), audio.trilha_id,
			int(audio.pedidos["TRILHA"]), int(audio.soaram["TRILHA"])])
	audio.escolher_trilha("ALEGRIA")
	pedidos_da_troca += 1
	soaram_da_troca += 1
	_assert("a troca final conta um pedido e um som, como qualquer outra",
		int(audio.pedidos["TRILHA"]) == pedidos_da_troca
			and int(audio.soaram["TRILHA"]) == soaram_da_troca,
		"pedidos=%d (esperado %d), soaram=%d (esperado %d)" % [int(audio.pedidos["TRILHA"]),
			pedidos_da_troca, int(audio.soaram["TRILHA"]), soaram_da_troca])
	_assert("cinco pedidos de trilha entre as trocas não movem um dígito do rng nem do gerador do visual",
		int(game.rng.state) == estado_rng_antes and int(game.visual_rng.state) == estado_visual_antes,
		"rng %d -> %d | visual %d -> %d" % [estado_rng_antes, int(game.rng.state),
			estado_visual_antes, int(game.visual_rng.state)])

	# ---- 4. Pausa tática abaixa, não silencia -----------------------------------------
	var db_aberto := float(audio.trilha_player.volume_db)
	game._toggle_pause()
	var db_pausado := float(audio.trilha_player.volume_db)
	game._toggle_pause()
	_assert("pausar derruba a trilha e retomar devolve",
		_igual(db_aberto, -13.0, 0.01) and _igual(db_pausado, -21.0, 0.01)
			and _igual(float(audio.trilha_player.volume_db), -13.0, 0.01),
		"%.1f -> %.1f -> %.1f dB" % [db_aberto, db_pausado, float(audio.trilha_player.volume_db)])
	_assert("a trilha continua viva na pausa (abaixou, não parou)", bool(audio.trilha_ao_vivo()),
		"ao_vivo=%s" % bool(audio.trilha_ao_vivo()))

	# ---- 5. Anti-spam: doze lances não são doze apitos --------------------------------
	# Zerar o contador sem zerar a janela mede o filtro velho: a chamada de controle da
	# seção 2b acabou de tocar um LASER, e sem o `erase` os doze lances do mesmo quadro
	# viravam zero apitos — a sonda acusaria o jogo de mudo quando o mudo era a própria marca.
	for nome in ["LASER", "EXPLOSAO", "IMPACTO", "ALARME"]:
		audio.pedidos[nome] = 0
		audio.soaram[nome] = 0
		audio._ultimo_toque.erase(nome)
	for i in range(12):
		audio.efeito("LASER")
	_assert("doze lasers do mesmo quadro viram um apito",
		int(audio.pedidos["LASER"]) == 12 and int(audio.soaram["LASER"]) == 1,
		"pedidos=%d soaram=%d" % [int(audio.pedidos["LASER"]), int(audio.soaram["LASER"])])
	# A janela reabre: envelhece a marca em vez de dormir em tempo real, porque sonda que
	# espera o relógio do motor mede o que o `--quit-after` lhe der.
	audio._ultimo_toque["LASER"] = float(Time.get_ticks_msec()) / 1000.0 - 1.0
	audio.efeito("LASER")
	_assert("passada a janela, o próximo lance passa",
		int(audio.soaram["LASER"]) == 2, "soaram=%d" % int(audio.soaram["LASER"]))
	# Nome de efeito que não existe na tabela: pedir não pode criar canal nem mover contador.
	var soma_pedidos := int(audio.pedidos["LASER"]) + int(audio.pedidos["EXPLOSAO"]) \
		+ int(audio.pedidos["IMPACTO"]) + int(audio.pedidos["ALARME"])
	audio.efeito("NAO_EXISTE")
	_assert("efeito desconhecido é recusado sem estrago",
		audio.pedidos.has("NAO_EXISTE") == false
			and soma_pedidos == int(audio.pedidos["LASER"]) + int(audio.pedidos["EXPLOSAO"])
				+ int(audio.pedidos["IMPACTO"]) + int(audio.pedidos["ALARME"])
			and int(audio.vozes.size()) == 4,
		"pedidos das quatro espécies=%d, vozes=%d" % [soma_pedidos, int(audio.vozes.size())])

	# ---- 6. Áudio não sorteia: a cauda de combate é intocável --------------------------
	var estado_antes: int = game.rng.state
	for i in range(50):
		audio.efeito("LASER")
		audio.efeito("EXPLOSAO")
		audio.efeito("IMPACTO")
		audio.parar_trilha()
		audio.tocar_trilha()
		audio.abafar_trilha(i % 2 == 0)
	var estado_depois: int = game.rng.state
	_assert("trezentas chamadas de áudio (50 rodadas de seis) não movem um dígito do rng",
		estado_antes == estado_depois, "%d -> %d" % [estado_antes, estado_depois])
	var visual_antes: int = game.visual_rng.state
	audio.efeito("ALARME")
	_assert("o alarme também não consome o gerador do visual",
		visual_antes == game.visual_rng.state, "%d -> %d" % [visual_antes, game.visual_rng.state])

	# ---- 7. Fim de combate: o alarme toca uma vez --------------------------------------
	for nome in ["ALARME"]:
		audio.pedidos[nome] = 0
		audio.soaram[nome] = 0
	# A chamada de controle da seção 6 acabou de fechar a janela do alarme (1,2 s). Envelhece a
	# marca pelo mesmo motivo do LASER: sonda que espera o relógio do motor mede o que o
	# `--quit-after` lhe der. Sem isto a sonda acusaria o jogo de mudo, quando o mudo é o filtro.
	audio._ultimo_toque["ALARME"] = float(Time.get_ticks_msec()) / 1000.0 - 2.0
	audio.abafar_trilha(false)
	audio.tocar_trilha()
	game.capital_hp = 0.0
	game._resolve_volley()
	_assert("capitânia perdida derruba a trilha e soa o alarme",
		not bool(audio.trilha_ao_vivo()) and int(audio.soaram["ALARME"]) == 1,
		"ao_vivo=%s alarmes=%d" % [bool(audio.trilha_ao_vivo()), int(audio.soaram["ALARME"])])
	game._resolve_volley()
	game._resolve_volley()
	_assert("a salva seguinte reentra no mesmo galho e o alarme não vira metralhadora",
		int(audio.pedidos["ALARME"]) == 1 and int(audio.soaram["ALARME"]) == 1,
		"pedidos=%d soaram=%d (guarda `batalha_encerrada`)" % [int(audio.pedidos["ALARME"]),
			int(audio.soaram["ALARME"])])

	# ---- 8. Liberação: o portão reprova recurso ainda em uso ---------------------------
	var vozes_antes := int(audio.vozes.size())
	audio._exit_tree()
	var streams_solto := true
	for filho in audio.get_children():
		var voz := filho as AudioStreamPlayer
		if voz != null and voz.stream != null:
			streams_solto = false
	_assert("_exit_tree larga as streams antes do encerramento",
		vozes_antes == 4 and int(audio.vozes.size()) == 0 and audio.trilha_stream == null
			and audio.trilha_player.stream == null and streams_solto,
		"vozes %d -> %d, trilha_stream=%s, player.stream=%s" % [vozes_antes, int(audio.vozes.size()),
			audio.trilha_stream, audio.trilha_player.stream])
	_assert("sair da cena para a trilha sem erro", not bool(audio.trilha_ao_vivo()),
		"ao_vivo=%s" % bool(audio.trilha_ao_vivo()))

	game.free()
	for nota in notes:
		print("SONDA-AUDIO: " + nota)
	print("veredito • quebras=%d • conferências=%d" % [breaks, notes.size()])
	quit()
