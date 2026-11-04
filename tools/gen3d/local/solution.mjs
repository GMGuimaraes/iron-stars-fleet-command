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
  // O alvo é a réplica que o `MultiMesh` da muralha replica 2 880 vezes (esquadra.gd:579). A caixa
  // crua medida dela é 3,6476 × 1,07 × 5,000 u, com proa em -z, e é ESSA caixa que manda na casa de
  // 3,2 u: boca 0,912 u e comprimento 1,25 u escalados, 2,288 u de folga no costado. Mudar a caixa
  // mudaria a lei da grade, então o piloto nasce dentro dela e só melhora a superfície.
  //
  // Os 1,07 u de altura não são simétricos: vão de -0,50 (a base do cone de proa, que é mais alta que
  // a espinha) a +0,57 (a torre). Reproduzir isso é o que faz `expectBounds` pegar eixo errado.
  const PONTOS = 8;
  const seccao = (offset, a, b, cy) => ({
    offset,
    profile: Array.from({ length: PONTOS }, (_, i) => {
      const t = (i * 2 * Math.PI) / PONTOS;
      return { x: Number((a * Math.cos(t)).toFixed(4)), y: Number((cy + b * Math.sin(t)).toFixed(4)) };
    }),
  });

  // O runtime cobra `offset` estritamente crescente no eixo do loft, então as duas formas são lidas
  // da proa (-z) para a popa (+z), contrário da ordem em que foram desenhadas.
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

  // A proa fecha em três estações: a agulha, o ombro (a base do cone antigo, r 0,5) e o encontro com
  // o corpo.
  const proa = modelLoftProfiles({
    sectionPlane: 'xy',
    loftAxis: 'z',
    sections: [
      seccao(-2.7, 0.06, 0.06, 0.0),
      seccao(-2.1, 0.5, 0.5, 0.0),
      seccao(-1.5, 0.6, 0.25, 0.0),
    ],
  });

  return modelCreate('casco piloto da muralha: mesmo envelope da réplica, superfície lavrada')
    .appearance('casco.aco', { baseColor: '#5A6472', metallic: 0.8, roughness: 0.35 })
    .appearance('acabamento.torre', { baseColor: '#454E5C', metallic: 0.7, roughness: 0.45 })
    .part('casco.corpo', { geometry: corpo, appearance: 'casco.aco', name: 'HullBody' })
    .part('casco.proa', { geometry: proa, appearance: 'casco.aco', name: 'HullBow' })
    .part('casco.torre', {
      geometry: { type: 'primitive.beveled-box', size: [0.6, 0.3, 1.9], bevelRadius: 0.06, bevelSegments: 1 },
      appearance: 'acabamento.torre',
      name: 'BridgeTower',
      translation: [0, 0.42, -0.4],
    })
    .part('casco.asa.bombordo', {
      // Caixa crua, sem chanfro: com `bevelRadius` a boca media 1,8119 em vez de 1,8235, porque o
      // extremo em x da asa rotacionada É a quina, e o chanfro come quina. Na torre o chanfro fica,
      // já que lá o extremo é face e não quina.
      geometry: { type: 'primitive.box', size: [1.0, 0.12, 1.8] },
      appearance: 'casco.aco',
      name: 'PortWing',
      translation: [-1.0, -0.02, 0.6],
      rotationRad: [0, -0.42, 0],
    })
    .pattern('casco.asa.boreste', {
      type: 'mirror',
      source: 'casco.asa.bombordo',
      axis: 'x',
    })
    .expectBounds({
      min: [-1.8235, -0.5, -2.7],
      max: [1.8235, 0.57, 2.3],
      tolerance: 0.005,
    })
    .budget({
      maxOperations: 15,
      maxGeneratedInstances: 5,
      maxNodes: 5,
      maxVertices: 312,
      maxTriangles: 224,
      maxBytes: 13280,
    });
}

const bundle = await createModelBundle(source.program());
await Promise.all([
  writeAtomic('program.gltf.json', JSON.stringify(bundle.program, null, 2) + '\n'),
  // O GLB é ativo do jogo e mora em `assets/`; os quatro sidecars ficam ao lado da fonte, para não
  // entrarem no .pck.
  writeAtomic('../../../assets/cascos/casco_replica.glb', bundle.artifact),
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
