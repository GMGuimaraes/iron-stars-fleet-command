import { rename, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const runtimeSpecifier = process.env.QODER_GLTF_RUNTIME
  ? pathToFileURL(path.resolve(process.env.QODER_GLTF_RUNTIME)).href
  : '@phodal/modeling-glb';
const { createModelBundle, modelCreate, modelLoftProfiles } = await import(runtimeSpecifier);

// Replace only defineModel(). Keep the delivery block below intact.
// Define the primary mass, semantic root, expected bounds, and budgets before
// adding bounded groups of detail. The scaffold fails closed until authored so
// a sample object's geometry can never leak into the requested model.
const source = defineModel();

function defineModel() {
  // Segundo corpo lavrado da casa, e primeiro que entra em cena. O piloto (`../solution.mjs`) desenhou
  // a réplica de linha para responder a uma pergunta de custo — 236 triângulos contra os 108 da
  // procedural — e a resposta do comandante, medida em 2026-11-04, foi de PAPEL: a muralha de 2 880
  // cascos continua vestindo a procedural e o desenho lavrado vive onde existe UM corpo só. Este
  // programa é esse corpo: a capitânia da mesa holográfica da ponte.
  //
  // A diferença não é cosmética e é ela que paga o arquivo novo. Na cena, o casco da ponte tem um
  // mastro dourado sobre a torre que nenhuma gramática de linha tem — em `_make_ship` ele é a sexta
  // forma emitida e a única guardada por `if comando:`, e é a silhueta que o comandante aprende a
  // procurar no meio da linha.
  // Uma vitrine sem mastro seria um casco de linha pintado de ouro: mentiria sobre o que ela mostra.
  //
  // As cotas do casco são as MESMAS do piloto, conferidas nó a nó por `tools/probes/vitrine.gd`:
  // corpo, proa, torre e o par de asas. O mastro vem do tabuleiro para cá pela razão de comprimento
  // (o casco lavrado mede 5,000 u de proa a popa contra os 8,900 u do casco da ponte, fator 0,562):
  // secção 0,16 × 0,16 vira 0,090, comprimento 0,75 vira 0,421, e a folga de 0,35 acima da torre vira
  // 0,197. Daí o centro em y 0,977 e a quina de topo em 1,187 — a nova face extrema do corpo, e por
  // isso a única cota de `expectBounds` que muda.
  const PONTOS = 8;
  const seccao = (offset, a, b, cy) => ({
    offset,
    profile: Array.from({ length: PONTOS }, (_, i) => {
      const t = (i * 2 * Math.PI) / PONTOS;
      return { x: Number((a * Math.cos(t)).toFixed(4)), y: Number((cy + b * Math.sin(t)).toFixed(4)) };
    }),
  });

  // O runtime cobra `offset` estritamente crescente no eixo do loft, então as duas formas são lidas
  // da proa (-z) para a popa (+z).
  const corpo = modelLoftProfiles({
    sectionPlane: 'xy',
    loftAxis: 'z',
    sections: [
      seccao(-1.5, 0.6, 0.25, 0.0),
      seccao(0.3, 0.6, 0.25, 0.0),
      seccao(1.5, 0.75, 0.3, 0.02),
      seccao(2.3, 0.75, 0.3, 0.02),
    ],
  });

  const proa = modelLoftProfiles({
    sectionPlane: 'xy',
    loftAxis: 'z',
    sections: [
      seccao(-2.7, 0.06, 0.06, 0.0),
      seccao(-2.1, 0.5, 0.5, 0.0),
      seccao(-1.5, 0.6, 0.25, 0.0),
    ],
  });

  return modelCreate('capitânia da vitrine: casco lavrado do piloto mais o mastro dourado do tabuleiro')
    .appearance('casco.aco', { baseColor: '#5A6472', metallic: 0.8, roughness: 0.35 })
    .appearance('acabamento.torre', { baseColor: '#454E5C', metallic: 0.7, roughness: 0.45 })
    .appearance('acabamento.mastro', { baseColor: '#C8A24A', metallic: 0.9, roughness: 0.25 })
    .part('capitania.corpo', { geometry: corpo, appearance: 'casco.aco', name: 'HullBody' })
    .part('capitania.proa', { geometry: proa, appearance: 'casco.aco', name: 'HullBow' })
    .part('capitania.torre', {
      geometry: { type: 'primitive.beveled-box', size: [0.6, 0.3, 1.9], bevelRadius: 0.06, bevelSegments: 1 },
      appearance: 'acabamento.torre',
      name: 'BridgeTower',
      translation: [0, 0.42, -0.4],
    })
    .part('capitania.asa.bombordo', {
      // Caixa crua, sem chanfro: com `bevelRadius` a boca media 1,8119 em vez de 1,8235, porque o
      // extremo em x da asa rotacionada É a quina, e o chanfro come quina. A lição é do piloto e vale
      // igual aqui — a meia-boca é o que a moldura da sonda lê.
      geometry: { type: 'primitive.box', size: [1.0, 0.12, 1.8] },
      appearance: 'casco.aco',
      name: 'PortWing',
      translation: [-1.0, -0.02, 0.6],
      rotationRad: [0, -0.42, 0],
    })
    .pattern('capitania.asa.boreste', {
      type: 'mirror',
      source: 'capitania.asa.bombordo',
      axis: 'x',
    })
    .part('capitania.mastro', {
      // Mastro, não antena: no tabuleiro ele é uma caixa de 0,16 × 0,75 × 0,16 pendurada no módulo
      // `TRIPULACAO`, e é o único bilhete que distingue a capitânia de um cruzador. Sem ele, a vitrine
      // mostraria um casco de linha dourado e o comandante leria mentira na mesa.
      geometry: { type: 'primitive.box', size: [0.09, 0.421, 0.09] },
      appearance: 'acabamento.mastro',
      name: 'FlagMast',
      translation: [0, 0.977, -0.4],
    })
    .expectBounds({
      min: [-1.8235, -0.5, -2.7],
      max: [1.8235, 1.187, 2.3],
      tolerance: 0.005,
    })
    .budget({
      // O bilhete do mastro é a décima nona operação do programa — o mesmo `part()` do piloto mais um.
      // Cravado no medido, não no estimado: se alguém acrescentar detalhe, o teto reclama.
      maxOperations: 19,
      maxGeneratedInstances: 6,
      maxNodes: 6,
      maxVertices: 336,
      maxTriangles: 236,
      // Medido na segunda rodada: 15 204 bytes com o mastro, contra os 13 280 do piloto. Cravado no
      // byte exato — se o casco engordar, o portão reclama em vez de entrar no `.pck` em silêncio.
      maxBytes: 15204,
    });
}

const bundle = await createModelBundle(source.program());
await Promise.all([
  writeAtomic('program.gltf.json', JSON.stringify(bundle.program, null, 2) + '\n'),
  // O GLB é ativo do jogo e mora em `assets/`; os sidecars ficam ao lado da fonte, fora do `.pck`.
  writeAtomic('../../../../assets/cascos/capitania_vitrine.glb', bundle.artifact),
  writeAtomic('artifact.gltf-project.json', bundle.projectSidecar),
  writeAtomic('capability-report.json', JSON.stringify(bundle.capabilityReport, null, 2) + '\n'),
]);

process.stdout.write(JSON.stringify({
  status: 'committed',
  revision: bundle.inspection.revision,
  bounds: bundle.inspection.bounds,
  counts: bundle.validation.counts,
}) + '\n');

async function writeAtomic(filePath, data) {
  const absolute = path.resolve(filePath);
  const temporary = path.join(path.dirname(absolute), '.' + path.basename(absolute) + '.' + process.pid + '.tmp');
  await writeFile(temporary, data);
  await rename(temporary, absolute);
}
