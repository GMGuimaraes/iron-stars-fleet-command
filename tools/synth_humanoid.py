#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Sintetiza o tripulante rigged do Iron Stars em GLB (glTF binário).

Uso:  python tools/synth_humanoid.py

Existe pelo mesmo motivo do `synth_audio.py`: o projeto não tem arte binária e não
tem modeladora nem maquina de render. O corpo nasce de descrição em texto, então a
malha é auditável (o veredito imprime juntas, triângulos e a caixa medida), o
re-gerar é reproduzível byte a byte, e o `.pck` do build web paga o preço de quem
mede — aqui, ~50 KB por personagem em vez de uma folha de sprites por pose.

Rig: 19 juntas em cadeia pura de translação (T-pose), deformação rígida — cada
vértice pesa 1,0 em exatamente uma junta. Isso é decisão, não atalho: com pele
suave, o braço dobrado no console arrastaria a caixa do ombro e a soldadura de um
uniforme quadrado mentiria. Rígido, o que o olho vê é a peça que a junta move.

A pose NÃO mora aqui. O arquivo traz o corpo em pose de cadastro; quem dobra os
braços é `_update_tripulacao`, lendo `battle_clock`, porque a pausa tática tem de
congelar a ponte inteira junto com a batalha — e um AnimationPlayer na cena seria
um relógio próprio, fora do quadro congelado.

Geometria: caixas de normal por face (o aço da casa é chapado, não liso) para
membros, elipsoide de 10 x 6 para o crânio e cilindro de 10 faces para o quepe.
Nada de textura: três materiais de cor pura, `farda`, `pele` e `ouro`, porque a
farda do oficial é lida pela silhueta e pelo filete, não por mapa.
"""

import json
import math
import os
import struct

CAMINHO_GLB = "assets/tripulante.glb"
# Posição do personagem na ponte: a malha é escrita em metros, pé no soalho (y=0),
# proa do corpo para -Z — o mesmo -Z que a esquadra usa como nariz.
RADIAL_CRANIO = 10
ANIS_CRANIO = 6
FACES_QUEPE = 10

FARDA = (0.13, 0.16, 0.23, 1.0)
PELE = (0.44, 0.33, 0.28, 1.0)
OURO = (0.62, 0.5, 0.22, 1.0)

# ── juntas ──────────────────────────────────────────────────────────────────────
# (nome, pai, translação LOCAL em relação ao pai). Cadeia só de translação: assim
# a matriz da pose de cadastro é uma translação pura e a inversa dela é a
# translação negada — zero inversão de 4x4 no gerador, zero chance de erro mudo.
JUNTAS = [
    ("quadril", None, (0.0, 0.92, 0.0)),
    ("coluna", "quadril", (0.0, 0.10, 0.0)),
    ("peito", "coluna", (0.0, 0.18, 0.0)),
    ("pescoco", "peito", (0.0, 0.18, 0.0)),
    ("cabeca", "pescoco", (0.0, 0.08, 0.0)),
    ("ombro_e", "peito", (0.17, 0.14, 0.0)),
    ("braco_e", "ombro_e", (0.09, -0.01, 0.0)),
    ("antbraco_e", "braco_e", (0.26, 0.0, 0.0)),
    ("mao_e", "antbraco_e", (0.24, 0.0, 0.0)),
    ("ombro_d", "peito", (-0.17, 0.14, 0.0)),
    ("braco_d", "ombro_d", (-0.09, -0.01, 0.0)),
    ("antbraco_d", "braco_d", (-0.26, 0.0, 0.0)),
    ("mao_d", "antbraco_d", (-0.24, 0.0, 0.0)),
    ("coxa_e", "quadril", (0.10, -0.02, 0.0)),
    ("perna_e", "coxa_e", (0.0, -0.42, 0.0)),
    ("pe_e", "perna_e", (0.0, -0.40, 0.0)),
    ("coxa_d", "quadril", (-0.10, -0.02, 0.0)),
    ("perna_d", "coxa_d", (0.0, -0.42, 0.0)),
    ("pe_d", "perna_d", (0.0, -0.40, 0.0)),
]
NOMES = [j[0] for j in JUNTAS]
PAI = {j[0]: j[1] for j in JUNTAS}
LOCAL = {j[0]: j[2] for j in JUNTAS}


def global_de(nome: str) -> tuple:
    """A translação global da junta na pose de cadastro: a soma da cadeia ao raiz."""
    x = y = z = 0.0
    no = nome
    while no is not None:
        lx, ly, lz = LOCAL[no]
        x += lx
        y += ly
        z += lz
        no = PAI[no]
    return (x, y, z)


# ── primitivas ──────────────────────────────────────────────────────────────────
def caixa(c, d):
    """Caixa de normal por face: 24 vértices, 12 triângulos. `c` é o centro,
    `d` o tamanho inteiro em cada eixo — a mesma linguagem de `_box` do jogo."""
    hx, hy, hz = d[0] / 2.0, d[1] / 2.0, d[2] / 2.0
    faces = [
        ((1, 0, 0), ((hx, -hy, -hz), (hx, hy, -hz), (hx, hy, hz), (hx, -hy, hz))),
        ((-1, 0, 0), ((-hx, -hy, hz), (-hx, hy, hz), (-hx, hy, -hz), (-hx, -hy, -hz))),
        ((0, 1, 0), ((-hx, hy, -hz), (-hx, hy, hz), (hx, hy, hz), (hx, hy, -hz))),
        ((0, -1, 0), ((-hx, -hy, hz), (-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz))),
        ((0, 0, 1), ((-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz))),
        ((0, 0, -1), ((hx, -hy, -hz), (-hx, -hy, -hz), (-hx, hy, -hz), (hx, hy, -hz))),
    ]
    verts, normais, idx = [], [], []
    base = 0
    for n, quadrado in faces:
        for (px, py, pz) in quadrado:
            verts.append((px + c[0], py + c[1], pz + c[2]))
            normais.append(n)
        idx += [base, base + 1, base + 2, base, base + 2, base + 3]
        base += 4
    return verts, normais, idx


def elipsoide(c, r, radial, anis):
    """Esfera achatada de normal lisa, com os dois polos fechados em leque."""
    verts, normais, idx = [], [], []
    for ia in range(anis + 1):
        t = math.pi * (float(ia) / anis)
        sy = -math.cos(t)
        sr = math.sin(t)
        anel = []
        for ir in range(radial):
            a = 2.0 * math.pi * (float(ir) / radial)
            nx, nz = math.cos(a) * sr, math.sin(a) * sr
            verts.append((c[0] + r[0] * nx, c[1] + r[1] * sy, c[2] + r[2] * nz))
            normais.append((nx, sy, nz))
            anel.append(len(verts) - 1)
        for ir in range(radial):
            prox = (ir + 1) % radial
            if ia > 0:
                idx += [anel[ir], anel[prox], anel[ir] - 1]
            if ia < anis - 1:
                idx += [anel[ir], anel[ir] + 1, anel[prox]]
    return verts, normais, idx


def cilindro(c, raio_topo, raio_base, altura, faces):
    """Tambor fechado nas duas bocas, normal por face nas laterais e nos discos."""
    verts, normais, idx = [], [], []
    meio = altura / 2.0
    for f in range(faces):
        a0 = 2.0 * math.pi * (float(f) / faces)
        a1 = 2.0 * math.pi * (float((f + 1) % faces) / faces)
        nx0, nz0, nx1, nz1 = math.cos(a0), math.sin(a0), math.cos(a1), math.sin(a1)
        base = len(verts)
        verts += [(c[0] + raio_topo * nx0, c[1] + meio, c[2] + raio_topo * nz0),
                  (c[0] + raio_topo * nx1, c[1] + meio, c[2] + raio_topo * nz1),
                  (c[0] + raio_base * nx1, c[1] - meio, c[2] + raio_base * nz1),
                  (c[0] + raio_base * nx0, c[1] - meio, c[2] + raio_base * nz0)]
        mnx, mnz = math.cos((a0 + a1) / 2.0), math.sin((a0 + a1) / 2.0)
        normais += [(mnx, 0.0, mnz)] * 4
        idx += [base, base + 1, base + 2, base, base + 2, base + 3]
    centro_topo = len(verts)
    verts.append((c[0], c[1] + meio, c[2]))
    normais.append((0.0, 1.0, 0.0))
    centro_base = len(verts)
    verts.append((c[0], c[1] - meio, c[2]))
    normais.append((0.0, -1.0, 0.0))
    for f in range(faces):
        a0 = 2.0 * math.pi * (float(f) / faces)
        a1 = 2.0 * math.pi * (float((f + 1) % faces) / faces)
        i0 = len(verts)
        verts += [(c[0] + raio_topo * math.cos(a0), c[1] + meio,
                   c[2] + raio_topo * math.sin(a0)),
                  (c[0] + raio_topo * math.cos(a1), c[1] + meio,
                   c[2] + raio_topo * math.sin(a1))]
        normais += [(0.0, 1.0, 0.0)] * 2
        verts.append((c[0] + raio_base * math.cos(a1), c[1] - meio,
                      c[2] + raio_base * math.sin(a1)))
        normais.append((0.0, -1.0, 0.0))
        verts.append((c[0] + raio_base * math.cos(a0), c[1] - meio,
                      c[2] + raio_base * math.sin(a0)))
        normais.append((0.0, -1.0, 0.0))
        idx += [centro_topo, i0, i0 + 1, centro_base, i0 + 2, i0 + 3]
    return verts, normais, idx


# ── as peças do corpo ───────────────────────────────────────────────────────────
# (peça, junta, material, primitiva, argumentos). Ordem é a do cadastro: mexer
# aqui muda o arquivo, e o veredito imprime a contagem para conferir.
PECAS = [
    ("bacia", "quadril", "farda", caixa, ((0.0, 0.92, 0.0), (0.28, 0.16, 0.19))),
    ("cinto", "quadril", "ouro", caixa, ((0.0, 0.995, 0.0), (0.30, 0.05, 0.21))),
    ("abdome", "coluna", "farda", caixa, ((0.0, 1.06, 0.0), (0.27, 0.16, 0.18))),
    ("torax", "peito", "farda", caixa, ((0.0, 1.26, 0.0), (0.34, 0.26, 0.20))),
    ("peito_ouro", "peito", "ouro", caixa, ((0.0, 1.155, -0.104), (0.30, 0.045, 0.01))),
    ("pescoco", "pescoco", "pele", caixa, ((0.0, 1.40, 0.0), (0.10, 0.08, 0.10))),
    ("cranio", "cabeca", "pele", elipsoide,
        ((0.0, 1.53, -0.005), (0.093, 0.108, 0.10), RADIAL_CRANIO, ANIS_CRANIO)),
    ("orelha_e", "cabeca", "pele", caixa, ((0.095, 1.52, 0.005), (0.02, 0.05, 0.035))),
    ("orelha_d", "cabeca", "pele", caixa, ((-0.095, 1.52, 0.005), (0.02, 0.05, 0.035))),
    ("roda_quepe", "cabeca", "farda",
        cilindro, ((0.0, 1.685, 0.0), 0.098, 0.108, 0.075, FACES_QUEPE)),
    ("tampa_quepe", "cabeca", "farda",
        cilindro, ((0.0, 1.726, 0.0), 0.092, 0.098, 0.012, FACES_QUEPE)),
    ("filete_quepe", "cabeca", "ouro", caixa, ((0.0, 1.652, 0.0), (0.216, 0.018, 0.216))),
    ("viseira", "cabeca", "farda", caixa, ((0.0, 1.642, -0.135), (0.17, 0.016, 0.11))),
    ("insignia", "cabeca", "ouro", caixa, ((0.0, 1.672, -0.098), (0.05, 0.035, 0.012))),
    ("epad_e", "ombro_e", "farda", caixa, ((0.175, 1.345, 0.0), (0.12, 0.075, 0.19))),
    ("epad_ouro_e", "ombro_e", "ouro", caixa, ((0.175, 1.385, 0.0), (0.125, 0.018, 0.195))),
    ("epad_d", "ombro_d", "farda", caixa, ((-0.175, 1.345, 0.0), (0.12, 0.075, 0.19))),
    ("epad_ouro_d", "ombro_d", "ouro", caixa, ((-0.175, 1.385, 0.0), (0.125, 0.018, 0.195))),
    ("braco_e", "braco_e", "farda", caixa, ((0.39, 1.33, 0.0), (0.24, 0.11, 0.11))),
    ("punho_ouro_e", "braco_e", "ouro", caixa, ((0.505, 1.33, 0.0), (0.014, 0.115, 0.115))),
    ("antbraco_e", "antbraco_e", "farda", caixa, ((0.64, 1.33, 0.0), (0.22, 0.10, 0.10))),
    ("mao_e", "mao_e", "pele", caixa, ((0.82, 1.33, -0.005), (0.14, 0.09, 0.11))),
    ("braco_d", "braco_d", "farda", caixa, ((-0.39, 1.33, 0.0), (0.24, 0.11, 0.11))),
    ("punho_ouro_d", "braco_d", "ouro", caixa, ((-0.505, 1.33, 0.0), (0.014, 0.115, 0.115))),
    ("antbraco_d", "antbraco_d", "farda", caixa, ((-0.64, 1.33, 0.0), (0.22, 0.10, 0.10))),
    ("mao_d", "mao_d", "pele", caixa, ((-0.82, 1.33, -0.005), (0.14, 0.09, 0.11))),
    ("coxa_e", "coxa_e", "farda", caixa, ((0.10, 0.69, 0.0), (0.16, 0.42, 0.17))),
    ("joelho_e", "perna_e", "farda", caixa, ((0.10, 0.475, -0.005), (0.145, 0.06, 0.175))),
    ("perna_e", "perna_e", "farda", caixa, ((0.10, 0.28, 0.0), (0.13, 0.40, 0.14))),
    ("bota_e", "pe_e", "farda", caixa, ((0.10, 0.065, -0.055), (0.135, 0.09, 0.27))),
    ("sola_e", "pe_e", "ouro", caixa, ((0.10, 0.010, -0.055), (0.14, 0.02, 0.28))),
    ("coxa_d", "coxa_d", "farda", caixa, ((-0.10, 0.69, 0.0), (0.16, 0.42, 0.17))),
    ("joelho_d", "perna_d", "farda", caixa, ((-0.10, 0.475, -0.005), (0.145, 0.06, 0.175))),
    ("perna_d", "perna_d", "farda", caixa, ((-0.10, 0.28, 0.0), (0.13, 0.40, 0.14))),
    ("bota_d", "pe_d", "farda", caixa, ((-0.10, 0.065, -0.055), (0.135, 0.09, 0.27))),
    ("sola_d", "pe_d", "ouro", caixa, ((-0.10, 0.010, -0.055), (0.14, 0.02, 0.28))),
]


def montar() -> dict:
    """Agrupa as peças por material e devolve o corpo pronto para virar binário."""
    por_material = {}
    for (nome, junta, mat, fn, args) in PECAS:
        verts, normais, idx = None, None, None
        if fn is caixa:
            verts, normais, idx = caixa(*args)
        elif fn is elipsoide:
            verts, normais, idx = elipsoide(*args)
        else:
            verts, normais, idx = cilindro(*args)
        bloco = por_material.setdefault(mat, {"pos": [], "nor": [], "jnt": [],
                                             "peso": [], "idx": [], "pecas": []})
        base = len(bloco["pos"])
        for v, n in zip(verts, normais):
            bloco["pos"].append(v)
            bloco["nor"].append(n)
            j = NOMES.index(junta)
            bloco["jnt"].append((j, 0, 0, 0))
            bloco["peso"].append((1.0, 0.0, 0.0, 0.0))
        bloco["pecas"].append(nome)
        bloco["idx"] += [base + i for i in idx]
    return por_material


def main() -> None:
    raiz = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(raiz)
    corpo = montar()

    binario = bytearray()
    views = []
    acessores = []

    def alinhado():
        while len(binario) % 4:
            binario.append(0)

    def view_de_flutuos(lista, alvo=None, alvo_alvo=None):
        alinhado()
        pos = len(binario)
        for v in lista:
            binario.extend(struct.pack("<%df" % len(v), *v))
        views.append({"buffer": 0, "byteOffset": pos, "byteLength": len(binario) - pos,
                      **({"target": alvo_alvo} if alvo_alvo else {}),
                      **({"byteStride": alvo} if alvo else {})})
        return len(views) - 1

    def view_de_inteiros(lista, alvo=None, alvo_alvo=None):
        alinhado()
        pos = len(binario)
        for v in lista:
            if isinstance(v, int):
                binario.extend(struct.pack("<H", v))
            else:
                binario.extend(struct.pack("<%dH" % len(v), *v))
        views.append({"buffer": 0, "byteOffset": pos, "byteLength": len(binario) - pos,
                      **({"target": alvo_alvo} if alvo_alvo else {}),
                      **({"byteStride": alvo} if alvo else {})})
        return len(views) - 1

    # As matrizes da pose de cadastro: translação pura, então a inversa é a
    # translação negada. Escrita coluna a coluna, como glTF pede.
    ibms = []
    for nome in NOMES:
        x, y, z = global_de(nome)
        ibms.append((1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0,
                     0.0, 0.0, 1.0, 0.0, -x, -y, -z, 1.0))
    view_ibm = view_de_flutuos(ibms)
    acessores.append({"bufferView": view_ibm, "componentType": 5126, "count": len(ibms),
                      "type": "MAT4"})
    aces_ibm = len(acessores) - 1

    primitivas = []
    for mat in ("farda", "pele", "ouro"):
        if mat not in corpo:
            continue
        bloco = corpo[mat]
        pos, nor, idx, jnt, peso = (bloco["pos"], bloco["nor"], bloco["idx"],
                                    bloco["jnt"], bloco["peso"])
        vmin = [min(v[k] for v in pos) for k in range(3)]
        vmax = [max(v[k] for v in pos) for k in range(3)]
        v_pos = view_de_flutuos(pos, alvo_alvo=34962)
        acessores.append({"bufferView": v_pos, "componentType": 5126, "count": len(pos),
                          "type": "VEC3", "min": vmin, "max": vmax})
        a_pos = len(acessores) - 1
        v_nor = view_de_flutuos(nor, alvo_alvo=34962)
        acessores.append({"bufferView": v_nor, "componentType": 5126, "count": len(nor),
                          "type": "VEC3"})
        a_nor = len(acessores) - 1
        v_idx = view_de_inteiros(idx, alvo_alvo=34963)
        acessores.append({"bufferView": v_idx, "componentType": 5123, "count": len(idx),
                          "type": "SCALAR"})
        a_idx = len(acessores) - 1
        v_jnt = view_de_inteiros(jnt, alvo=8, alvo_alvo=34962)
        acessores.append({"bufferView": v_jnt, "componentType": 5123, "count": len(jnt),
                          "type": "VEC4", "normalized": False})
        a_jnt = len(acessores) - 1
        v_peso = view_de_flutuos(peso, alvo=16, alvo_alvo=34962)
        acessores.append({"bufferView": v_peso, "componentType": 5126, "count": len(peso),
                          "type": "VEC4"})
        a_peso = len(acessores) - 1
        primitivas.append({
            "attributes": {"POSITION": a_pos, "NORMAL": a_nor,
                           "JOINTS_0": a_jnt, "WEIGHTS_0": a_peso},
            "indices": a_idx,
            "material": {"farda": 0, "pele": 1, "ouro": 2}[mat],
        })

    # Nós: raiz, depois as 19 juntas na ordem do cadastro, depois o corpo com a pele.
    filhos_de = {}
    for (nome, pai, _loc) in JUNTAS:
        if pai is not None:
            filhos_de.setdefault(pai, []).append(1 + NOMES.index(nome))
    nos = [{"name": "Tripulante", "children": [1, 1 + len(JUNTAS)]}]
    for (nome, pai, loc) in JUNTAS:
        no = {"name": nome, "translation": list(loc)}
        if nome in filhos_de:
            no["children"] = filhos_de[nome]
        nos.append(no)
    nos.append({"name": "Corpo", "mesh": 0, "skin": 0})

    materiais = []
    for cor in (FARDA, PELE, OURO):
        materiais.append({"pbrMetallicRoughness": {"baseColorFactor": list(cor),
                                                  "metallicFactor": 0.0,
                                                  "roughnessFactor": 0.7},
                          "doubleSided": False})

    gltf = {
        "asset": {"version": "2.0", "generator": "Iron Stars - tools/synth_humanoid.py"},
        "scene": 0,
        "scenes": [{"name": "Tripulante", "nodes": [0]}],
        "nodes": nos,
        "meshes": [{"name": "Corpo", "primitives": primitivas}],
        "skins": [{"name": "Rig do tripulante", "joints": list(range(1, 1 + len(JUNTAS))),
                   "skeleton": 1, "inverseBindMatrices": aces_ibm}],
        "materials": materiais,
        "accessors": acessores,
        "bufferViews": views,
        "buffers": [{"byteLength": len(binario)}],
    }

    json_bruto = json.dumps(gltf, separators=(",", ":"), ensure_ascii=True).encode("ascii")
    while len(json_bruto) % 4:
        json_bruto += b" "
    while len(binario) % 4:
        binario.append(0)

    corpo_total = 12 + 8 + len(json_bruto) + 8 + len(binario)
    cabecalho = struct.pack("<III", 0x46546C67, 2, corpo_total)
    bloco_json = struct.pack("<II", len(json_bruto), 0x4E4F534A) + json_bruto
    bloco_bin = struct.pack("<II", len(binario), 0x004E4942) + bytes(binario)
    glb = cabecalho + bloco_json + bloco_bin

    destino = os.path.join("assets", "tripulante.glb")
    os.makedirs("assets", exist_ok=True)
    with open(destino, "wb") as f:
        f.write(glb)

    # ── veredito medido, não estimado ───────────────────────────────────────────
    triangulo = sum(len(corpo[m]["idx"]) // 3 for m in corpo)
    vertice = sum(len(corpo[m]["pos"]) for m in corpo)
    # A caixa lida de TODOS os materiais, não só da farda: a palmilha de ouro afundava 15 mm
    # sob o soalho enquanto o relatório media só o uniforme e anunciava "pe no soalho". A
    # pintura do próprio gerador não pode mentir sobre a geometria que ele escreveu.
    todas = [v for m in corpo for v in corpo[m]["pos"]]
    alturas = sorted(v[1] for v in todas)
    caixa_y = (alturas[0], alturas[-1])
    print("SYNTH-HUMANOIDE: %s escrito byte a byte, sem sorteio" % destino)
    print("  tamanho:            %d bytes (%.1f KB)" % (len(glb), len(glb) / 1024.0))
    print("  cabecalho           magic=0x%08X versao=2 length=%d bate com o arquivo=%s"
          % (0x46546C67, corpo_total, corpo_total == len(glb)))
    print("  juntas:             %d (%s)" % (len(JUNTAS), ", ".join(NOMES)))
    print("  pecas:              %d em %d primitivas (farda/pele/ouro)"
          % (len(PECAS), len(primitivas)))
    print("  triangulos:         %d | vertices: %d | views: %d | acessores: %d"
          % (triangulo, vertice, len(views), len(acessores)))
    print("  caixa do corpo:     y de %.3f a %.3f m (pe no soalho, quepe no topo)"
          % caixa_y)
    print("  altura total:       %.3f m" % (caixa_y[1] - caixa_y[0]))
    print("  skin rigida:        %d pesos lidos, todos 1,0 em uma junta" % vertice)
    print("  binario:            %d bytes | json: %d bytes" % (len(binario), len(json_bruto)))
    max_x = max(abs(v[0]) for m in corpo for v in corpo[m]["pos"])
    print("  T-pose:            envergadura +- %.3f m da ponta do dedo ao eixo" % max_x)


if __name__ == "__main__":
    main()
