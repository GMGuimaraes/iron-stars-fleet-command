#!/usr/bin/env node
// Cliente Meshy image-to-3D da casa: mastiga um PNG de referência (o material que a sonda
// `tools/probes/ref3d_replica.gd` fotografa) e devolve o GLB no diretório de cascos, com a linha de
// ledger que diz quanto custou.
//
// A chave só entra pelo ambiente (`MESHY_API_KEY`). Ela nunca é argumento, nunca é impressa, nunca é
// gravada em ledger nem em log: um token na linha de comando fica no histórico do shell e no log do
// CI, e um token no ledger fica no git para sempre. Sem chave o programa sai com código 2 antes de
// qualquer chamada de rede — é o portão que a bateria de aceite mede.
//
// Contrato medido em https://docs.meshy.ai/en/api/image-to-3d (2026-11-04):
//   POST /openapi/v1/image-to-3d  -> {"result": "<task_id>"}
//   GET  /openapi/v1/image-to-3d/:id -> {status, progress, model_urls:{glb,...}, consumed_credits}
//   status: PENDING | IN_PROGRESS | SUCCEEDED | FAILED | CANCELED
//   entrada: image_url aceita URL pública OU data URI base64 (JPG/PNG/WebP, <=20 MB, lado >=32 px)
//   origin_at: "bottom" (padrão) | "center" — aqui é "center" porque o casco do jogo é montado em
//   torno da própria caixa, e um modelo ancorado na barriga deslocaria o olho da muralha inteira.
// Campos que essa página NÃO tem (não inventar): prompt, mode, model_version, topology_quality,
// segmentation, image_buffer.

import { createHash } from "node:crypto";
import { readFileSync, writeFileSync, appendFileSync, mkdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const RAIZ = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const BASE = "https://api.meshy.ai";
const TETO_BYTES_IMAGEM = 20 * 1024 * 1024;
const LADO_MINIMO = 32;
const INTERVALO_POLL_MS = 5000;

function uso() {
  console.error([
    "uso: node tools/gen3d/meshy.mjs --image <png> --name <slug> [opções]",
    "  --out <dir>          destino do GLB (padrão <repo>/assets/cascos)",
    "  --ledger <arquivo>   JSONL de custos (padrão <out>/meshy-ledger.jsonl)",
    "  --polycount <n>      alvo de polígonos, 100..300000 (padrão 30000)",
    "  --texture            pedir material PBR (o serviço devolve sem textura por padrão)",
    "  --timeout-min <n>    teto do polling em minutos (padrão 12)",
    "  a chave vem de MESHY_API_KEY; sem ela o programa sai 2 sem tocar na rede",
  ].join("\n"));
}

function falhar(motivo, codigo) {
  console.error(`MESHY: ${motivo}`);
  process.exit(codigo);
}

function obter(argv) {
  const opcoes = {
    image: null,
    name: null,
    out: join(RAIZ, "assets", "cascos"),
    ledger: null,
    polycount: 30000,
    texture: false,
    timeoutMin: 12,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const bandeira = argv[i];
    const valor = () => {
      i += 1;
      if (i >= argv.length) throw new Error(`faltou valor para ${bandeira}`);
      return argv[i];
    };
    switch (bandeira) {
      case "--image": opcoes.image = valor(); break;
      case "--name": opcoes.name = valor(); break;
      case "--out": opcoes.out = valor(); break;
      case "--ledger": opcoes.ledger = valor(); break;
      case "--polycount": opcoes.polycount = Number(valor()); break;
      case "--texture": opcoes.texture = true; break;
      case "--timeout-min": opcoes.timeoutMin = Number(valor()); break;
      default: throw new Error(`bandeira desconhecida: ${bandeira}`);
    }
  }
  if (!opcoes.image || !opcoes.name) throw new Error("--image e --name são obrigatórios");
  if (!/^[a-z0-9][a-z0-9_-]{0,63}$/.test(opcoes.name)) {
    throw new Error("--name tem de ser um slug minúsculo (letra ou dígito no começo, até 64)");
  }
  if (!Number.isInteger(opcoes.polycount) || opcoes.polycount < 100 || opcoes.polycount > 300000) {
    throw new Error("--polycount fora do intervalo do serviço: 100..300000");
  }
  if (!(opcoes.timeoutMin > 0)) throw new Error("--timeout-min tem de ser um número positivo");
  return opcoes;
}

const sha256 = (bytes) => createHash("sha256").update(bytes).digest("hex");

async function pedir(caminho, chave, opcoes = {}) {
  const resposta = await fetch(`${BASE}${caminho}`, {
    ...opcoes,
    headers: { Authorization: `Bearer ${chave}`, ...(opcoes.headers || {}) },
    signal: AbortSignal.timeout(opcoes.timeoutMs ?? 60000),
  });
  const texto = await resposta.text();
  if (!resposta.ok) {
    // O corpo de erro do serviço não repete a chave, e mesmo assim nada aqui é despejado cru: um
    // eco de cabeçalho na mensagem seria o vazamento da vez seguinte.
    throw new Error(`${resposta.status} em ${caminho}: ${texto.slice(0, 400)}`);
  }
  return texto;
}

const lerJson = async (caminho, chave, opcoes) => JSON.parse(await pedir(caminho, chave, opcoes));

const esperar = (ms) => new Promise((acordar) => setTimeout(acordar, ms));

async function principal() {
  let opcoes;
  try {
    opcoes = obter(process.argv.slice(2));
  } catch (erro) {
    uso();
    falhar(erro.message, 2);
  }

  const chave = process.env.MESHY_API_KEY;
  if (!chave) {
    // Portão antes de qualquer rede: sem chave não existe chamada, não existe custo, não existe
    // arquivo. É o que a bateria de aceite confere com `exit=2` e nenhuma conexão aberta.
    falhar("MESHY_API_KEY ausente no ambiente — nenhuma chamada de rede foi feita", 2);
  }

  const imagem = resolve(opcoes.image);
  let bytes;
  try {
    bytes = readFileSync(imagem);
  } catch {
    falhar(`não dá para ler a imagem de referência: ${imagem}`, 2);
  }
  if (bytes.length > TETO_BYTES_IMAGEM) {
    falhar(`referência com ${bytes.length} bytes passa o teto de 20 MB do serviço`, 2);
  }
  // O lado mínimo é lido do IHDR do PNG (largura em bytes 16..19, altura em 20..23, big-endian): é a
  // única pré-condição que o serviço devolve como erro de tarefa, cara de descobrir depois de esperar.
  let largura = 0;
  let altura = 0;
  if (bytes.subarray(0, 8).toString("hex") === "89504e470d0a1a0a") {
    largura = bytes.readUInt32BE(16);
    altura = bytes.readUInt32BE(20);
    if (largura < LADO_MINIMO || altura < LADO_MINIMO) {
      falhar(`referência ${largura}x${altura} abaixo dos ${LADO_MINIMO} px de lado exigidos`, 2);
    }
  }

  const corpo = {
    image_url: `data:image/png;base64,${bytes.toString("base64")}`,
    target_formats: ["glb"],
    origin_at: "center",
    should_texture: opcoes.texture,
    target_polycount: opcoes.polycount,
  };

  console.log(`MESHY: referência ${imagem} ${largura}x${altura} ${bytes.length} bytes `
    + `sha256=${sha256(bytes).slice(0, 12)}`);
  const criado = await lerJson("/openapi/v1/image-to-3d", chave, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(corpo),
    timeoutMs: 120000,
  });
  const tarefa = criado?.result;
  if (typeof tarefa !== "string" || tarefa.length === 0) {
    falhar(`a resposta de criação não trouxe identificador de tarefa: ${JSON.stringify(criado)}`, 1);
  }
  console.log(`MESHY: tarefa ${tarefa} criada`);

  const tetoMs = opcoes.timeoutMin * 60000;
  const inicio = Date.now();
  let estado = null;
  for (;;) {
    estado = await lerJson(`/openapi/v1/image-to-3d/${tarefa}`, chave, { timeoutMs: 30000 });
    console.log(`MESHY: ${estado?.status} ${Number(estado?.progress ?? 0)}% `
      + `(${Math.round((Date.now() - inicio) / 1000)}s)`);
    if (estado?.status === "SUCCEEDED") break;
    if (estado?.status === "FAILED" || estado?.status === "CANCELED") {
      falhar(`tarefa ${tarefa} terminou em ${estado.status}: `
        + JSON.stringify(estado?.error ?? {}), 1);
    }
    if (Date.now() - inicio > tetoMs) {
      falhar(`tarefa ${tarefa} não fechou em ${opcoes.timeoutMin} min; ela segue no serviço e o `
        + "crédito já foi consumido — reconsulte pelo identificador antes de reenviar", 1);
    }
    await esperar(INTERVALO_POLL_MS);
  }

  const urlGlb = estado?.model_urls?.glb;
  if (typeof urlGlb !== "string" || urlGlb.length === 0) {
    falhar(`tarefa ${tarefa} deu SUCCEEDED sem URL de GLB: `
      + JSON.stringify(estado?.model_urls ?? {}), 1);
  }
  const respostaGlb = await fetch(urlGlb, { signal: AbortSignal.timeout(120000) });
  if (!respostaGlb.ok) falhar(`download do GLB falhou: ${respostaGlb.status}`, 1);
  const glb = Buffer.from(await respostaGlb.arrayBuffer());
  if (glb.length < 12 || glb.subarray(0, 4).toString("latin1") !== "glTF") {
    falhar(`o arquivo baixado não é um GLB (${glb.length} bytes, mágica `
      + `${glb.subarray(0, 4).toString("hex")})`, 1);
  }

  const destino = resolve(opcoes.out);
  mkdirSync(destino, { recursive: true });
  const caminhoGlb = join(destino, `${opcoes.name}.glb`);
  writeFileSync(caminhoGlb, glb);
  const ledger = resolve(opcoes.ledger ?? join(destino, "meshy-ledger.jsonl"));
  mkdirSync(dirname(ledger), { recursive: true });
  const linha = {
    ts: new Date().toISOString(),
    nome: opcoes.name,
    tarefa,
    creditos: estado?.consumed_credits ?? null,
    bytes_glb: glb.length,
    sha256_glb: sha256(glb),
    referencia: imagem,
    sha256_referencia: sha256(bytes),
    parametros: { polycount: opcoes.polycount, texture: opcoes.texture, origin_at: "center" },
  };
  appendFileSync(ledger, `${JSON.stringify(linha)}\n`);
  console.log(`MESHY: glb=${caminhoGlb} bytes=${glb.length} `
    + `sha256=${linha.sha256_glb.slice(0, 12)} creditos=${linha.creditos}`);
  console.log(`MESHY: ledger=${ledger}`);
}

principal().catch((erro) => falhar(erro?.message ?? String(erro), 1));
