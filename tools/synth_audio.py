#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Sintetiza a trilha e os efeitos do Iron Stars em WAV de 16 bits.

Uso:  python tools/synth_audio.py

Existe por um motivo: o projeto não tem arte binária e não tem gravadora. A trilha
nasce de partitura em texto, então a melodia é auditável (o veredito imprime a
sequência de notas) e o re-gerar é reproduzível byte a byte — sem sorteio nenhum.

Timbre: senóides empilhadas (harmônicos com peso próprio) + envelope de corda.
Baixo e arpejo entram como marcha; a melodia é a Ode à Alegria (Beethoven, domínio
público) nas duas frases que abrem o tema, com uma variação própria em oitavas.
As outras duas faixas são transcrições conferidas do Mutopia Project (Dvořák,
Sinfonia n.9 "Do Novo Mundo": o Largo e o Scherzo) — ver o bloco `TRILHAS_NOVAS`.

Os efeitos são propositalmente abafados: um passa-baixa de um polo cravado em
SOFT_HZ modela o vácuo pedido — no espaço não há ar para levar o agudo. A trilha
não passa por ele: é a ponte de comando que ouve a própria música.

Sai tudo em assets/audio/, com o veredito medido no stdout (duração, RMS, pico,
centróide espectral). Os números do README vêm daqui, não de estimativa.
"""

import math
import os
import struct
import wave

SR_MUSICA = 32000
SR_FX = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")

BPM = 150.0
BATA = 60.0 / BPM          # 0,40 s por tempo: marcha
COMPASSO = 4 * BATA        # 1,6 s por compasso de 4/4

# Harmônicos de cada timbre: (multiplo, peso). A corda tem corpo em 1..5; o alaúde
# do arpejo morre em 3; o baixo quase não tem parcial — é o peito, não a nota.
STRING = ((1.0, 1.00), (2.0, 0.42), (3.0, 0.20), (4.0, 0.09), (5.0, 0.04))
PLUCK = ((1.0, 1.00), (2.0, 0.34), (3.0, 0.14))
BASS = ((1.0, 1.00), (2.0, 0.26))

ATAQUE = 0.018             # corda não começa do nada
CAUDA_STRING = 1.35        # constante de decaimento em segundos
CAUDA_PLUCK = 0.30
CAUDA_BASS = 0.55
VIBRATO_HZ = 5.2
VIBRATO_CENTS = 6.0        # corda afinada que oscila, não desafina

TAM_TABELA = 4096
MASCARA = TAM_TABELA - 1
MESA = [math.sin(2.0 * math.pi * i / TAM_TABELA) for i in range(TAM_TABELA)]
FATOR_FASE = TAM_TABELA / (2.0 * math.pi)   # radianos -> indice da tabela


def hz(degree):
    """Grau MIDI (A4 = 69, C4 = 60) para hertz, temperamento igual.

    A partitura inteira fala em graus MIDI. Esta fórmula já falou: com `degree - 9`
    ela lia 64 como 10.548 Hz em vez dos 330 Hz de Mi4, e a trilha saía cinco oitavas
    acima — acima de Nyquist, onde harmônico vira aliasing e a conta de centróide
    devolvia 9.880 Hz para um conjunto de cordas.
    """
    return 440.0 * (2.0 ** ((degree - 69) / 12.0))


def nome_nota(degree):
    """Nome da nota em ASCII de propósito: o stdout do Windows é cp1252 e 'Dó'
    impresso num pipe chega como mojibake no log da sonda.

    Tabela de bemóis porque a faixa Dvořák é toda em Réb maior: impressa em sustenido
    (Sol#4 em vez de Lab4) a sequência de notas deixa de ser conferível contra o score.
    """
    nomes = ("Do", "Reb", "Re", "Mib", "Mi", "Fa", "Solb", "Sol", "Lab", "La", "Sib", "Si")
    oitava = degree // 12 - 1
    return "%s%d" % (nomes[degree % 12], oitava)


def nota(alvo, t0, duracao, amplitude, harmônicos, cauda, sr, vibrato=False, fase=0.0):
    """Escreve uma nota em buf[alvo] já somada (aditivo). Retorno: nada.

    Usado o acumulador de fase com tabela de seno: em Python puro, math.sin por
    harmônico por amostra triplicava o tempo de geração da trilha, e a diferença
    audível é zero — a tabela tem 4096 pontos e a maior freqüência do conjunto
    (5º harmônico de Sol5) percorre bem menos de um ponto por amostra.
    """
    n = int(duracao * sr)
    base = int(t0 * sr)
    fase_k = [fase] * len(harmônicos)
    passo = [2.0 * math.pi * hz(alvo) * multiplo / sr for multiplo, _ in harmônicos]
    for i in range(n):
        t = float(i) / sr
        # envelope: ataque linear curto, depois exponencial até o fim da janela
        if t < ATAQUE:
            env = t / ATAQUE
        else:
            env = math.exp(-(t - ATAQUE) / cauda)
        mod = 1.0
        if vibrato:
            mod = 2.0 ** ((VIBRATO_CENTS / 100.0) * math.sin(2 * math.pi * VIBRATO_HZ * t) / 12.0)
        amostra = 0.0
        for k, (multiplo, peso) in enumerate(harmônicos):
            fase_k[k] += passo[k] * mod
            # a fase cresce sem limite: `int(...) and MASCARA` corta por módulo 4096
            # sem exigir fmod, que custaria mais que a própria tabela.
            amostra += peso * MESA[int(fase_k[k] * FATOR_FASE) & MASCARA]
        buf[base + i] += amplitude * env * amostra


buf = None


def alocar(segundos, sr):
    global buf
    n = int(segundos * sr) + sr  # um segundo de folga para as caudas
    buf = [0.0] * n
    return n


def dft_512_ponteiro():
    """Pré-computa cos/sen da DFT usada pela centróide e a janela de Hann.

    A janela não é enfeite: sem ela, um tom puro de 200 Hz num retângulo de 512
    amostras vaza para os vizinhos com lóbulos laterais que pesam mais quanto mais
    agudos são, e a centróide saía 1113 Hz para uma nota de 200. Hann derruba os
    lóbulos e a medida passa a responder pela nota.
    """
    global COS, SEN, HANN
    tam = 512
    meio = tam // 2
    COS = [[math.cos(2.0 * math.pi * k * i / tam) for i in range(tam)] for k in range(meio)]
    SEN = [[math.sin(2.0 * math.pi * k * i / tam) for i in range(tam)] for k in range(meio)]
    HANN = [0.5 - 0.5 * math.cos(2.0 * math.pi * i / (tam - 1)) for i in range(tam)]


def analise(sr, dados):
    """(centróide em Hz, fração de energia acima de 600 Hz, fração acima de 1200 Hz).

    As três juntas são o que a palavra "abafado" tem de significar. Centróide sozinha
    mente: um laser que varre de 2,1 kHz a 380 Hz tem centróide baixa porque passa mais
    tempo no grave, e continuaria estridente. Medir uma só fronteira também mente: o
    impacto nasce em 900 Hz, e um corte em 1,2 kHz daria "0% -> 0%" como se o filtro
    tivesse abafado algo que ele nem tocou.

    A fração é MEDIA POR ENERGIA (soma da banda aguda sobre a soma de toda a energia),
    não média das frações de cada janela. A média por janela foi o que esta ferramenta
    mediu primeiro, e ela escondeu o abafamento: no laser cru as janelas do fim são
    baixas e silenciosas (0% de agudo), e no filtrado a mesma normalização inverte a
    pirâmide de energia — a conta por janela devolveu "22,7% -> 20,8%" para um filtro
    que na verdade derrubou 62,1% -> 16,3%. Uma janela de 1% da energia do som não tem
    o direito de pesar o mesmo que uma de 10%.

    DFT direta de 512 pontos com Hann basta porque o valor é comparativo (cru contra
    filtrado, efeito contra trilha), não uma análise fina de espectro.
    """
    tam = 512
    meio = tam // 2
    # Janelas tantas quantas o trecho couber (até 16): medir uma fatia curta com 16
    # janelas sobrepostas leria fora do fim da lista.
    janelas = max(1, min(16, (len(dados) - tam) + 1))
    passo = max(1, (len(dados) - tam) // janelas)
    k_600 = int(600.0 * tam / sr)
    k_1200 = int(1200.0 * tam / sr)
    soma_centro = 0.0
    energia_total = 0.0
    energia_600 = 0.0
    energia_1200 = 0.0
    feitas = 0
    for j in range(janelas):
        inicio = j * passo
        if inicio + tam > len(dados):
            break
        feitas += 1
        recorte = [dados[inicio + i] * HANN[i] for i in range(tam)]
        mag_total = 0.0
        peso_total = 0.0
        energia = 0.0
        acima_600 = 0.0
        acima_1200 = 0.0
        for k in range(1, meio):
            cos_k = COS[k]
            sen_k = SEN[k]
            real = 0.0
            imag = 0.0
            for i in range(tam):
                v = recorte[i]
                real += v * cos_k[i]
                imag += v * sen_k[i]
            potencia = real * real + imag * imag
            mag = math.sqrt(potencia)
            mag_total += mag
            peso_total += mag * (k * sr / tam)
            energia += potencia
            if k >= k_600:
                acima_600 += potencia
            if k >= k_1200:
                acima_1200 += potencia
        if mag_total > 0.0:
            soma_centro += peso_total / mag_total
        energia_total += energia
        energia_600 += acima_600
        energia_1200 += acima_1200
    feitas = max(1, feitas)
    if energia_total <= 0.0:
        return soma_centro / feitas, 0.0, 0.0
    return (soma_centro / feitas, energia_600 / energia_total, energia_1200 / energia_total)


def passa_baixa(sr, dados, corte_hz, polos=1):
    """Um polo por passada: y += a * (x - y), com a = 1 - exp(-2π fc / fs).

    Cada passada acrescenta 6 dB/oitava: dois polos = 12, quatro = 24. A conta foi
    medida, não presumida — com um só polo o corte em 1,1 kHz mal tocava o laser, e o
    número que a sonda cobra hoje é o de quatro polos em 700 Hz. O polo único não tem
    ressonância nenhuma, então empilhar quatro só inclina a curva: nada aqui zumbe.
    """
    a = 1.0 - math.exp(-2.0 * math.pi * corte_hz / sr)
    saida = dados
    for _ in range(polos):
        y = 0.0
        nova = []
        for x in saida:
            y += a * (x - y)
            nova.append(y)
        saida = nova
    return saida


def normalizar(dados, pico=0.89):
    m = max(1e-9, max(abs(v) for v in dados))
    g = pico / m
    return [v * g for v in dados]


def rms(dados):
    return math.sqrt(sum(v * v for v in dados) / float(len(dados)))


def gravar(nome, sr, dados):
    caminho = os.path.join(OUT, nome)
    with wave.open(caminho, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(sr)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767.0)) for v in dados))
    return caminho


# ---- partitura -------------------------------------------------------------
# Dó maior, as duas frases que abrem a Ode à Alegria (Beethoven, op. 125), uma
# variação própria em oitavas e a volta. A terceira frase do original ficou de
# fora: transcrever de memória sai desafinado, e o laço não precisa dela.
# (grau MIDI, duração em segundos) — grau MIDI mesmo: 60 é Dó4. A semínima vale um
# tempo: R é a própria BATA, senão o compasso da melodia (4 x R) deixa de bater com
# o compasso do acompanhamento (COMPASSO) e as frases montam uma sobre a outra.
R = BATA
TEMA = [
    # c1: Freude, schoener
    [(64, R), (64, R), (65, R), (67, R)],
    # c2: Goetterfunken
    [(67, R), (65, R), (64, R), (62, R)],
    # c3: Toechter aus Ely-
    [(60, R), (60, R), (62, R), (64, R)],
    # c4: -sium  (pontuada: 1,5 + 0,5 + 2)
    [(64, 1.5 * R), (62, 0.5 * R), (62, 2.0 * R)],
    # c5 = c1
    [(64, R), (64, R), (65, R), (67, R)],
    # c6 = c2
    [(67, R), (65, R), (64, R), (62, R)],
    # c7: D E then
    [(60, R), (60, R), (62, R), (64, R)],
    # c8: -ium em Dó (fecha no repouso)
    [(62, 1.5 * R), (60, 0.5 * R), (60, 2.0 * R)],
]
# Harmonia por compasso: baixo (grau) e as três notas do arpejo interno.
HARMONIA = [
    (48, (60, 64, 67)),   # Do  (I)
    (55, (59, 62, 67)),   # Sol (V)
    (48, (60, 64, 67)),   # Do  (I)
    (55, (59, 62, 67)),   # Sol (V7 sem a 7ª: basta o tritone no interno? fica V)
    (48, (60, 64, 67)),   # Do  (I)
    (55, (59, 62, 67)),   # Sol (V)
    (43, (55, 60, 64)),   # Fa  (IV, baixo em Fa2)
    (48, (60, 64, 67)),   # Do  (I)
]
VARIACAO = [
    [(76, R), (76, R), (77, R), (79, R)],
    [(79, R), (77, R), (76, R), (74, R)],
    [(72, R), (72, R), (74, R), (76, R)],
    [(76, 1.5 * R), (74, 0.5 * R), (74, 2.0 * R)],
    [(64, R), (67, R), (72, R), (67, R)],
    [(64, R), (67, R), (72, R), (74, R)],
    [(72, R), (72, R), (74, R), (76, R)],
    [(76, 1.5 * R), (74, 0.5 * R), (74, 2.0 * R)],
]


def trilha():
    partes = [TEMA, VARIACAO, TEMA]
    compassos = []
    for p in partes:
        compassos.extend(p)
    total = len(compassos) * COMPASSO
    alocar(total + 1.0, SR_MUSICA)
    for i, compasso in enumerate(compassos):
        t0 = i * COMPASSO
        baixo, interno = HARMONIA[i % len(HARMONIA)]
        # baixo em marcha: tônica no 1, quinta no 3
        nota(baixo, t0, 0.9 * BATA, 0.34, BASS, CAUDA_BASS, SR_MUSICA)
        nota(baixo + 7, t0 + 2 * BATA, 0.9 * BATA, 0.26, BASS, CAUDA_BASS, SR_MUSICA)
        # arpejo em colcheias: quem dá movimento, não volume
        for k in range(8):
            nota(interno[k % 3], t0 + k * 0.5 * BATA, 0.55 * BATA, 0.085, PLUCK, CAUDA_PLUCK, SR_MUSICA)
        # contratempo da marcha: o mesmo tempo em colcheia, peso só no 2 e 4
        for k in (1, 3):
            nota(baixo + 12, t0 + k * BATA, 0.12 * BATA, 0.05, PLUCK, CAUDA_PLUCK, SR_MUSICA)
        # melodia por cima, com vibrato
        t = t0
        for grau, dur in compasso:
            nota(grau, t, dur * 0.98, 0.30, STRING, CAUDA_STRING, SR_MUSICA, vibrato=True)
            t += dur
    dados = buf[:int(total * SR_MUSICA)]
    # crossfade de laço: o que sobra da cauda final entra no começo, senão o loop
    # estala a cada 38 s e o comandante ouve a costura.
    cauda = buf[int(total * SR_MUSICA):int(total * SR_MUSICA) + int(0.5 * SR_MUSICA)]
    n = len(cauda)
    for i in range(n):
        dados[i] += cauda[i] * (1.0 - float(i) / float(n))
    return normalizar(dados, 0.86)


# ---- as outras duas faixas: Dvorak, Sinfonia n.9 "Do Novo Mundo" -----------
# Transcricoes conferidas nota a nota, não de memória. A fonte e o metodo:
#   https://www.mutopiaproject.org/ftp/DvorakA/O95/Sym9/Sym9-lys.zip
#   (partitura publica do Mutopia Project, dominio publico; arquivos LilyPond)
#   LARGO    = oboeIImL em woods.notesL.ily, 2o movimento. A parte esta gravada em
#              nota escrita com \transposition f (corne ingles em Fa): nota real =
#              nota escrita menos 1 quinta. A mesma frase foi conferida contra a
#              transcricao MusicXML em Do maior de "Goin' Home" baixada nesta sessao
#              as 12 primeiras compassos batem classe por classe (a quinta de DOb
#              sai como Si natural nos dois lados).
#   SCHERZO  = violinImS em strings.notesS.ily, 3o movimento. Compasso 3/4 conferido
#              barra a barra pela soma das duracoes (todo "|" do arquivo fecha em 3
#              tempos). A fonte nao declara \time, entao a soma e a prova.
# O que e transcricao e o que e reducao minha esta dito em cada tabela: a melodia e
# do score; a harmonia e reducao propria (o score completo tem as doze vozes de
# cordas, e embutir as doze aqui seria outro projeto, nao outra faixa).
#
# Formato: lista de compassos, cada um uma lista de (grau MIDI, duracao em tempos)
# ou (None, duracao) para repouso. Tempo = semiminima.
LARGO_TEMPO = 4

LARGO_TEMAS = [
    # c1-4: o tema do corne ingles (F4 pontuado, Lab4, Lab4, F4..., Reb4)
    [(65, .75), (68, .25), (68, 1.0), (65, .75), (63, .25), (61, 1.0)],
    [(63, .75), (65, .25), (68, .75), (65, .25), (63, 2.0)],
    [(65, .75), (68, .25), (68, 1.0), (65, .75), (63, .25), (61, 1.0)],
    [(63, .5), (65, .5), (63, .75), (61, .25), (61, 2.0)],
    # c5-8: a resposta, uma oitava e meia acima (Sib4, Reb5, Si=Reb5 de passagem)
    [(70, .75), (73, .25), (73, 1.0), (72, .5), (68, .5), (70, 1.0)],
    [(70, .5), (73, .5), (72, .5), (68, .5), (70, 2.0)],
    [(70, .75), (73, .25), (73, 1.0), (72, .5), (68, .5), (70, 1.0)],
    [(70, .5), (73, .5), (72, .5), (68, .5), (70, 2.0)],
    # c9-12: a volta do tema, fechando na tonica
    [(65, .75), (68, .25), (68, 1.0), (65, .5), (63, .5), (61, 1.0)],
    [(63, .75), (65, .25), (68, .75), (65, .25), (63, 2.0)],
    [(65, .75), (68, .25), (68, 1.0), (73, .75), (75, .25), (77, 1.0)],
    [(75, .75), (73, .25), (75, .5), (70, .5), (73, 2.0)],
    # c13-16: a reapresentacao do score (mesmo periodo, cauda diferente: o 2o
    # compasso sobe para Lab4 em vez de pousar em Mib4)
    [(65, .75), (68, .25), (68, 1.0), (65, .75), (63, .25), (61, 1.0)],
    [(63, .75), (65, .25), (68, .75), (65, .25), (63, .5), (68, 1.5)],
    [(65, .75), (68, .25), (68, 1.0), (73, .75), (75, .25), (77, 1.0)],
    [(75, .75), (73, .25), (75, .5), (70, .5), (73, 2.0)],
]
# Reducao propria, Reb maior: baixo + triade do coro de cordas.
_I = (49, (61, 65, 68))    # Reb  (I)
_V = (44, (60, 63, 68))    # Lab  (V)
_IV = (42, (58, 61, 66))   # Solb (IV)
LARGO_HARMONIA = [_I, _V, _I, _I, _I, _V, _I, _V, _I, _V, _IV, _I, _I, _V, _IV, _I]

SCHERZO_TEMPO = 3
SCHERZO_TEMAS = [
    # c1-9: o tema do 3o movimento (Si Sol Si Sol | Mi pausa Si Si Si | ...)
    [(83, 1.0), (79, .5), (83, .5), (79, 1.0)],
    [(76, .5), (None, .5), (83, .5), (83, .5), (83, 1.0)],
    [(76, 1.0), (76, 1.0), (None, 1.0)],
    [(None, 1.0), (78, 1.0), (81, 1.0)],
    [(79, .5), (78, .5), (76, 1.0), (None, 1.0)],
    [(None, 1.0), (83, .5), (83, .5), (83, 1.0)],
    [(76, 1.0), (76, 1.0), (None, 1.0)],
    [(None, 1.0), (78, 1.0), (81, 1.0)],
    [(79, .5), (78, .5), (76, 1.0), (None, 1.0)],
    # c10-13: a resposta (Sol Sol Mi Re Sol | Mi Re Si Mi Re Si)
    [(None, 1.0), (76, 1.0), (79, 1.0)],
    [(76, .5), (74, .5), (71, 1.0), (74, .5), (71, .5)],
    [(79, 1.0), (79, .5), (76, .5), (74, .5), (79, .5)],
    [(76, .5), (74, .5), (71, .5), (76, .5), (74, .5), (71, .5)],
]
_Em = (52, (55, 59, 64))    # Mi menor
_C = (48, (55, 60, 64))     # Do
_B7 = (47, (54, 59, 63))    # Si 7
_Am = (45, (52, 57, 60))    # La menor
# A e B tocam duas vezes: 26 compassos de 3/4 a 132 bpm sao ~35 s de laco, a mesma
# ordem de grandeza da marcha de Beethoven (38,4 s). Laço de 13 compassos repetiria
# o tema a cada 18 s no meio de uma batalha.
SCHERZO_TEMAS = SCHERZO_TEMAS + SCHERZO_TEMAS
SCHERZO_HARMONIA = (
    [_Em, _Em, _Em, _C, _Em, _Em, _Em, _C, _B7]
    + [_C, _Em, _Am, _Em]
)
SCHERZO_HARMONIA = SCHERZO_HARMONIA + SCHERZO_HARMONIA

TRILHAS_NOVAS = (
    {"arquivo": "novo_mundo.wav", "titulo": "Largo do Novo Mundo (Dvorak, op.95 II)",
     "bpm": 66.0, "tempos": LARGO_TEMPO, "tema": LARGO_TEMAS, "harmonia": LARGO_HARMONIA,
     "estilo": "coral"},
    {"arquivo": "novo_mundo_scherzo.wav", "titulo": "Scherzo do Novo Mundo (Dvorak, op.95 III)",
     "bpm": 132.0, "tempos": SCHERZO_TEMPO, "tema": SCHERZO_TEMAS, "harmonia": SCHERZO_HARMONIA,
     "estilo": "valsa"},
)


def tocar_classica(cfg):
    """Renderiza uma das faixas novas no andamento e compasso delas.

    A trilha do Beethoven fica com a funcao dela: o arquivo embarcado e medido pela
    sonda com rms e duracao cravados, e mexer no caminho que o gera para "generalizar"
    seria trocar contrato por elegancia. Esta funcao e o mesmo motor de soma com duas
    harmonias de accompanhamento e compasso variavel.
    """
    bata = 60.0 / cfg["bpm"]
    compasso = cfg["tempos"] * bata
    total = len(cfg["tema"]) * compasso
    alocar(total + 1.0, SR_MUSICA)
    for i, barra in enumerate(cfg["tema"]):
        t0 = i * compasso
        baixo, interno = cfg["harmonia"][i % len(cfg["harmonia"])]
        if cfg["estilo"] == "coral":
            # coro de cordas: triade sustentada e baixo longo, sem marcha. No Largo
            # quem move e a melodia; o fundo so segura a harmonia.
            nota(baixo, t0, compasso * 0.94, 0.20, BASS, 2.6, SR_MUSICA)
            for grau in interno:
                nota(grau, t0, compasso * 0.94, 0.075, STRING, 2.2, SR_MUSICA)
        else:
            # valsa em 3/4: baixo no 1, acorde picado no 2 e no 3.
            nota(baixo, t0, 0.8 * bata, 0.30, BASS, CAUDA_BASS, SR_MUSICA)
            for k in (1, 2):
                for grau in interno:
                    nota(grau, t0 + k * bata, 0.45 * bata, 0.070, PLUCK, CAUDA_PLUCK, SR_MUSICA)
        t = t0
        for grau, dur in barra:
            if grau is not None:
                nota(grau, t, dur * bata * 0.98, 0.30, STRING, CAUDA_STRING, SR_MUSICA, vibrato=True)
            t += dur * bata
    dados = buf[:int(total * SR_MUSICA)]
    cauda = buf[int(total * SR_MUSICA):int(total * SR_MUSICA) + int(0.5 * SR_MUSICA)]
    n = len(cauda)
    for i in range(n):
        dados[i] += cauda[i] * (1.0 - float(i) / float(n))
    return normalizar(dados, 0.86)


def fx_laser():
    global buf
    dur = 0.30
    sr = SR_FX
    n = int(dur * sr)
    dados = [0.0] * n
    f0, f1 = 2100.0, 380.0
    for i in range(n):
        t = float(i) / sr
        # varredura exponencial para baixo: é como o ouvido lê um disparo de plasma
        freq = f0 * ((f1 / f0) ** (t / dur))
        env = math.exp(-t / 0.075) * min(1.0, t / 0.004)
        v = math.sin(2 * math.pi * freq * t)
        v += 0.28 * math.sin(2 * math.pi * freq * 2.0 * t)
        dados[i] = env * v
    return dados


def fx_explosao():
    sr = SR_FX
    dur = 1.15
    n = int(dur * sr)
    dados = [0.0] * n
    # PRNG com semente cravada: o ruído é fixo, então o arquivo re-gerado é idêntico.
    estado = 123456789
    for i in range(n):
        t = float(i) / sr
        estado = (1103515245 * estado + 12345) & 0x7FFFFFFF
        ruido = (float(estado) / 1073741824.0) - 1.0
        # casca estalada nos primeiros 30 ms, miolo grave que rola até 1 s
        cascada = math.exp(-t / 0.030)
        corpo = math.exp(-t / 0.34)
        grave = math.sin(2 * math.pi * (58.0 * math.exp(-t / 0.5) + 26.0) * t)
        dados[i] = 0.62 * cascada * ruido + 0.70 * corpo * grave + 0.18 * corpo * ruido
    return dados


def fx_impacto():
    sr = SR_FX
    dur = 0.42
    n = int(dur * sr)
    dados = [0.0] * n
    for i in range(n):
        t = float(i) / sr
        metal = math.sin(2 * math.pi * 132.0 * t) + 0.5 * math.sin(2 * math.pi * 197.0 * t)
        dados[i] = math.exp(-t / 0.11) * metal + 0.22 * math.exp(-t / 0.012) * math.sin(2 * math.pi * 900.0 * t)
    return dados


def fx_alarme():
    sr = SR_FX
    dur = 0.9
    n = int(dur * sr)
    dados = [0.0] * n
    for i in range(n):
        t = float(i) / sr
        bloco = int(t / 0.22) % 2
        f = 660.0 if bloco == 0 else 500.0
        env = min(1.0, t / 0.01) * math.exp(-max(0.0, t - 0.7) / 0.1)
        dados[i] = env * (math.sin(2 * math.pi * f * t) + 0.3 * math.sin(2 * math.pi * f * 2.0 * t))
    return dados


def main():
    if not os.path.isdir(OUT):
        os.makedirs(OUT)
    dft_512_ponteiro()
    MEDIDA = 4096   # oito janelas de 512: uma só daria média de um instante, não do som
    linhas = []
    musica = trilha()
    c_mus, b600, b1200 = analise(SR_MUSICA, musica[2 * SR_MUSICA:2 * SR_MUSICA + MEDIDA])
    linhas.append(("tema_batalha.wav", SR_MUSICA, musica, c_mus, b1200, 0.86))
    print("%-16s crua:    centro %5.0f Hz | >600: %5.1f%%  >1200: %5.1f%%  (a trilha NAO passa por filtro)"
          % ("tema_batalha.wav", c_mus, 100.0 * b600, 100.0 * b1200))
    for cfg in TRILHAS_NOVAS:
        dados = tocar_classica(cfg)
        c, k600, k1200 = analise(SR_MUSICA, dados[2 * SR_MUSICA:2 * SR_MUSICA + MEDIDA])
        linhas.append((cfg["arquivo"], SR_MUSICA, dados, c, k1200, 0.86))
        print("%-22s %5.1f bpm  centro %5.0f Hz | >600: %5.1f%%  >1200: %5.1f%%  (%s)"
              % (cfg["arquivo"], cfg["bpm"], c, 100.0 * k600, 100.0 * k1200, cfg["titulo"]))
    # Cortes: o laser, a detonação e o abalroamento acontecem lá fora, no vácuo, e perdem a
    # casca aguda. Quatro polos (24 dB/oitava) porque dois ainda deixavam 16% da energia do
    # laser acima de 1,2 kHz — abafar de verdade é derrubar a banda, não só aplainá-la. O
    # corte da detonação sobe de 420 para 700 Hz por ouvido de bolso: com 420 a centróide
    # caía a 78 Hz e o estouro sumia dos alto-falantes pequenos de notebook, que não
    # reproduzem nada abaixo de ~100 Hz. Nove hertz de corpo a mais e o estalo continua em
    # 0,0%. O alarme toca dentro da ponte, ao ouvido da tripulação, e por isso segura o tom
    # de 660 Hz que o torna reconhecível como aviso.
    for nome, gerador, corte, polos in (("laser.wav", fx_laser, 700.0, 4),
                                        ("explosao.wav", fx_explosao, 700.0, 4),
                                        ("impacto.wav", fx_impacto, 240.0, 4),
                                        ("alarme.wav", fx_alarme, 1100.0, 2)):
        cru = normalizar(gerador())
        abafado = normalizar(passa_baixa(SR_FX, cru, corte, polos))
        # Medida do som inteiro (as 16 janelas se espalham por ele), não de uma fatia:
        # medir só os primeiros 186 ms de um laser de 300 ms ignoraria a cauda que o
        # filtro exatamente preserva.
        c_crua, k600_cru, k1200_cru = analise(SR_FX, cru[200:])
        c_abaf, k600_abf, k1200_abf = analise(SR_FX, abafado[200:])
        linhas.append((nome, SR_FX, abafado, c_abaf, k1200_abf, 0.8))
        print("%-16s abafou:  centro %5.0f -> %5.0f Hz | >600: %5.1f%% -> %4.1f%% | >1200: %5.1f%% -> %4.1f%% (corte %.0f Hz, %d polos)"
              % (nome, c_crua, c_abaf, 100.0 * k600_cru, 100.0 * k600_abf,
                 100.0 * k1200_cru, 100.0 * k1200_abf, corte, polos))
    for nome, sr, dados, centro, brilho, pico in linhas:
        dados = normalizar(dados, pico)
        caminho = gravar(nome, sr, dados)
        print("%-16s %6.2f s  centro %5.0f Hz  agudo %5.1f%%  rms %.3f  pico %.3f  %s" % (
            nome, len(dados) / float(sr), centro, 100.0 * brilho, rms(dados),
            max(abs(v) for v in dados), caminho))
    notas = []
    for compasso in TEMA:
        for grau, _ in compasso:
            notas.append(nome_nota(grau))
    print("tema (Ode a Alegria, C maior): " + " ".join(notas))
    for cfg in TRILHAS_NOVAS:
        notas = []
        for barra in cfg["tema"]:
            for grau, _ in barra:
                notas.append(nome_nota(grau) if grau is not None else "-")
        print("%s (%d compassos de %d tempos): %s" % (
            cfg["arquivo"], len(cfg["tema"]), cfg["tempos"], " ".join(notas)))
    print("afinacao: Mi4 = %.1f Hz, Do4 = %.1f Hz, Sol5 = %.1f Hz" % (hz(64), hz(60), hz(79)))


if __name__ == "__main__":
    main()
