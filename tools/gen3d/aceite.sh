#!/usr/bin/env bash
# Aceite executável da fatia 3D assistada (piloto: um casco).
#
# Cada linha CHECK:: abaixo é um critério que se mede sozinho, na forma
# CHECK::<alvo>::<esperado>::<comando>. O runner roda todos, compara o stdout com o esperado e só
# fecha verde se TODOS rodaram — um critério que não rodou não é aprovação, é buraco.
#
# O que esta bateria NÃO cobre, declarado: o GLB vindo do Meshy. Ele depende de MESHY_API_KEY e de
# crédito gasto, e a chave mora no ambiente do dono. O que dá para provar sem rede está aqui,
# incluindo o controle negativo que mostra que a asserção "sem chave não há rede" é medida e não
# alegação (check 4 grampeia `fetch` e prova que um programa com chave bate na porta).
#
# Uso:  bash tools/gen3d/aceite.sh          (roda os seis checks, ~2 min; o check 5 abre janela)
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT="${GODOT:-/c/Users/gmore/godot/godot}"
SCRATCH="D:/Downloads/tmp-userdata-iron"
PNGS="$SCRATCH/ref3d"
export APPDATA="D:/Downloads/tmp-userdata-iron"

# O stub que grampeia a rede: qualquer chamada de fetch estoura antes de sair da máquina.
mkdir -p "$SCRATCH"
STUB="$SCRATCH/gen3d-no-rede.mjs"
printf 'globalThis.fetch = () => { throw new Error("REDE_TENTADA"); };\n' > "$STUB"

# O CLI do plugin modeling-glb é resolvido pelo cache do Qoder, na versão mais alta instalada. Se o
# plugin sumir, o check 6 quebra com nome — não com um "ok" silencioso.
GLTF_CLI="$(ls -d "$HOME"/.qoder/plugins/cache/qoder-marketplace/modeling-glb/*/scripts/qoder-gltf.mjs \
	2>/dev/null | sort -V | tail -1)"

CHECKS=(
'CHECK::sonda_ref3d_em_dummy::quebras=0::cd "$REPO" && "$GODOT" --headless --path . --quit-after 4000 -s res://tools/probes/ref3d_replica.gd 2>&1 | grep -oE "quebras=[0-9]+" | tail -1'
'CHECK::paridade_uid_das_sondas::iguais::a=$(ls "$REPO"/tools/probes/*.gd | wc -l); b=$(ls "$REPO"/tools/probes/*.gd.uid | wc -l); [ "$a" = "$b" ] && echo iguais || echo "diferentes $a/$b"'
'CHECK::meshy_sem_chave_sai_2::exit=2::cd "$REPO" && env -u MESHY_API_KEY node --import "file:///$STUB" tools/gen3d/meshy.mjs --image "$PNGS/04_tres_quartos.png" --name piloto_replica >/dev/null 2>&1; echo "exit=$?"'
'CHECK::meshy_com_chave_tenta_rede::REDE_TENTADA::cd "$REPO" && MESHY_API_KEY=chave-de-teste node --import "file:///$STUB" tools/gen3d/meshy.mjs --image "$PNGS/04_tres_quartos.png" --name piloto_replica 2>&1 | grep -oE "REDE_TENTADA" | head -1'
'CHECK::cinco_pngs_de_900::5::cd "$REPO" && "$GODOT" --path . --quit-after 4000 -s res://tools/probes/ref3d_replica.gd >/dev/null 2>&1; node -e "const fs=require(\"fs\");let n=0;for(const f of fs.readdirSync(process.argv[1])){if(!f.endsWith(\".png\"))continue;const b=fs.readFileSync(process.argv[1]+\"/\"+f);if(b.readUInt32BE(16)===900&&b.readUInt32BE(20)===900)n++;}console.log(n)" "$(cygpath -w "$PNGS")"'
'CHECK::validador_gltf_no_glb_da_casa::valid=true::cd "$REPO" && { [ -n "$GLTF_CLI" ] || { echo plugin-ausente; exit 0; }; }; node "$GLTF_CLI" validate assets/tripulante.glb --pretty 2>/dev/null | node -e "let s=\"\";process.stdin.on(\"data\",d=>s+=d).on(\"end\",()=>{const j=JSON.parse(s);console.log(\"valid=\"+j.data.valid)})"'
)

falhas=0
rodados=0
total=${#CHECKS[@]}
for linha in "${CHECKS[@]}"; do
	resto="${linha#CHECK::}"
	alvo="${resto%%::*}"
	resto="${resto#*::}"
	esperado_valor="${resto%%::*}"
	comando="${resto#*::}"
	rodados=$((rodados + 1))
	real="$(eval "$comando" 2>&1 | tr -d "\r" | tail -1)"
	if [ "$real" = "$esperado_valor" ]; then
		echo "OK     $alvo -> $real"
	else
		falhas=$((falhas + 1))
		echo "QUEBRA $alvo -> esperado [$esperado_valor], medido [$real]"
	fi
done

# A âncora é o literal do array, não `^CHECK::`: as linhas têm tab e apóstrofo antes, e um grep que
# casa zero não é "nada mudou", é "a régua está cega" — foi exatamente o que a primeira corrida pegou.
linhas_script=$(grep -cE "^[[:space:]]*'CHECK::" "${BASH_SOURCE[0]}")
echo "ACEITE: fim • checks=$rodados • falhas=$falhas • linhas_no_script=$linhas_script"
[ "$rodados" -eq "$total" ] || { echo "ACEITE: nem todo check rodou"; exit 1; }
[ "$linhas_script" -eq "$rodados" ] || { echo "ACEITE: o script mudou de tamanho no meio da corrida"; exit 1; }
[ "$falhas" -eq 0 ] || exit 1
