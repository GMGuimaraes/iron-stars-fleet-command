# Lapidação 4 — sub-bloco manobrando e âncora viva — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fazer o bloco de 24 casas ser lido como seis fileiras de quatro navios que manobram cada
uma, fazer a cena medir peça por peça (poço, vento, coroa, rochas) e trocar a âncora da muralha de
derivada-dos-núcleos para estado perseguido — mais a estrela desenhada como esfera.

**Architecture:** A peça é **estado dentro do bloco** (arquitetura A do spec): cada bloco carrega
`pecas: Array[Dictionary]` com seis entradas, e cada uma segura uma excursão **no referencial local
do bloco** (`desloc`), nunca uma posição de mundo. Isso é o que dá a prova de inércia: `casa_local(c)`
passa a ser *definido como* `peca_local(p) + casa_na_peca(k)`, então com `desloc == Vector3.ZERO` a
transformada escrita é a mesma expressão aritmética de hoje, byte a byte. A âncora vira dois
`Vector3` por lado, semeada no valor que `estacao()` devolve hoje e perseguida por `Voo.marchar`
contra a média dos próprios blocos em custódia. A cena ganha uma porta só (`Esquadra.pecas_na_cena()`
+ `Esquadra.abater_peca()`): nenhuma lei nova de ledger, nenhum sorteio, nenhum nó.

**Tech Stack:** Godot 4.7.2.stable.official (`/c/Users/gmore/godot/godot`), GDScript, um `MultiMesh`
por lado, sondas `SceneTree` headless, git no remoto `GMGuimaraes/iron-stars-fleet-command`.

**Spec:** `docs/superpowers/specs/2026-10-29-sub-bloco-e-ancora-viva-design.md` (commit `32ec664`) —
este plano argumenta a partir dele. Leia os dois juntos.

## Global Constraints

- Godot 4.7.2.stable.official; binário `/c/Users/gmore/godot/godot`. Confirme `"$GODOT" --version`
  antes de assumir a versão do motor.
- Trabalhe **direto em `main`**. Sem branch de feature, sem worktree.
- O repo tem **sessões concorrentes de outras IAs**: nunca `git add -A`, nunca `git stash`, stage por
  nome exato de arquivo. Prove `git status --short` antes e depois de cada stage.
- Nunca commite `_tmp_pista_fria.gd`, `_tmp_pista_fria.gd.uid`, `.godot/`, `.manus/`, nem churn de
  `.import` que seja só final de linha (prove com `git diff --ignore-cr-at-eol --stat -- '*.import'`).
- **Nunca escreva `.gd.uid` na mão.** Quem escreve é o motor ao importar; um `.uid` inventado é um
  conflito de identidade de recurso.
- Isola o user dir em toda execução: `APPDATA="D:\\Downloads\\tmp-userdata-iron"`.
- Os scripts corretores (bateria) moram **fora** do repo: `bash /d/Downloads/tmp-userdata-iron/bateria.sh`.
- Bateria auto-descobre `res://tools/probes/*.gd`; o censo atual é **35** sondas (32 headless + 3 em
  janela) e vira **36** ao nascer `peca.gd`, sem editar `bateria.sh`. Verde = `quebras=0` **e**
  `linhas_de_erro=0` em todo log. As três de janela (`comando_olho`, `fotograma`, `massa_visivel`) são
  puladas pela bateria e rodam com rasterizador, com o PNG relido de volta.
- Números do README e do spec são contrato medido: mexeu na aritmética, varra o README
  (`godot-readme-number-sweep`) **no mesmo commit**.
- **Nunca afrouxe um portão para ele passar.** Sonda vermelha com aritmética nova declara a
  precondition no **criador do estado** e continua cobrando os números de antes.
- Custo se conta em operações, nunca em `ms` (este host lê ±35 % entre rodadas).
- Aprovação visual e de feeling é do commander: headless nunca pinta. Dizer isso em vez de declarar
  sucesso.
- Responda em português do Brasil, inclusive em rótulos de pergunta.

## Desvios do texto do spec, declarados antes de codar

Três pontos do spec não podem ser executados com a literalidade da redação, e a correção é medida, não
de gosto. Estão aqui para o executor não "consertar" por conta própria:

1. **Ar de par de peça ≥ o ar publicado (§4) é geometricamente impossível com folga.** Com
   `FOLGA_DA_PECA = (1,2 / 0,6 / 0,9)` e dois vizinhos em excursões extremas opostas, o ar do par cai
   para **0,088 u (x) / 0,132 u (y) / 0,150 u (z)** — abaixo dos 2,488 / 1,332 / 1,95 publicados. A
   família D cobra, por isso, duas asserções distintas: **estrita positividade** do ar em todo quadro
   com a folga viva (é a garantia da construção), e a **tabela publicada** de ar por eixo com a
   excursão zerada (`pecas_livres = false`, régua que a família 2 de `esquadra.gd` já cobra). Nenhum
   número se afrouxa; um portão se acrescenta.
2. **Histerese de 1,3 × passo só existe entre postos de grade, não dentro de um passo de casa.** As
   cotas do spec (y 2,08 u = 1,3 × `PASSO_CASA_Y` 1,6; z 4,16 u = 1,3 × `PASSO_CASA_Z` 3,2) são
   **passos de casa**, e o espaço aberto por uma vaga dentro do bloco é medido do posto de quem move
   até o primeiro posto ainda vivo além do alvo: em z isso vale `PASSO_BLOCO_Z` 7,0 u (porque
   `CASAS_Z = 2`, o vizinho além da vaga é de outro bloco) e em y vale 3,2 u quando a terceira camada
   vive, ou mais se ela também morreu. Os dois cortam a respectiva cota de 4,16 / 2,08 — a captura
   **existe**, e a conta é lida da grade, não chutada.
3. **A estrela esférica ganha uma família a mais do que a lista A–H do §6.** A única sonda que hoje
   olha a estrela é `tools/probes/fotograma.gd`, de janela, e um PNG não prova que a fotosfera é uma
   `SphereMesh` nem que as vinte chapas da coroa estão todas a exatamente `ESTRELA_CALOR_RAIO × 0,42`
   do centro. A forma é o objeto da queixa («a esteira não está representada de forma esférica»), então
   a folha estrutural recebe a **família S** — censo de nós 22 intacto, tipo de malha da fotosfera e
   raio constante das vinte chapas, tudo lido sem rasterizador. O portão visual continua sendo o do
   `fotograma.gd` com o PNG relido, e a aprovação de como a bola *parece* é do commander.

## File Structure

| Arquivo | Papel | Tarefas |
|---|---|---|
| `esquadra.gd` | a peça como estado, a identidade, a trela, a vaga, a âncora como estado, `pecas_na_cena`, `abater_peca`, `ferir_peca`, `id_peca`, pintura por peça | 1, 2, 3, 4, 5, 6, 7, 8 |
| `main.gd` | as cinco leis de cenário lendo peça por peça; a estrela esférica | 7, 8, 9 |
| `tools/probes/peca.gd` | sonda nova, famílias A–H mais a família S da estrela | 1, 2, 3, 4, 5, 6, 7, 8, 9 |
| `tools/probes/fotograma.gd` | só a **redação** da asserção do censo 22 da estrela | 9 |
| `README.md` | varredura dos números derivados (travessia, censo de peças, afundamento) | 10 |
| `docs/superpowers/specs/2026-10-29-...-design.md` | fechar a seção 6 com o que foi medido | 10 |

Ordem e por quê: 1 e 2 não mudam nenhuma leitura nem nenhuma força (é estrutura pura, verde
imediata). 3 troca os três leitores e prova a inércia **antes** de existir força na peça — se a
inércia quebrar, a causa está isolada. 4 liga o voo. 5 dá a liberdade que o commander pediu. 6 corta
a herança da âncora. 7 e 8 abrem a cena para a peça. 9 é arte. 10 fecha.

---

### Task 1: A identidade da peça (e `casa_local` re-expresso por ela)

**Files:**
- Modify: `esquadra.gd:50-53` (constants), `esquadra.gd:310-323` (`casa_local`)
- Create: `tools/probes/peca.gd`
- Test: `tools/probes/peca.gd` família A

**Interfaces:**
- Consumes: `CASAS_X/CASAS_Y/CASAS_Z/CASAS`, `PASSO_CASA_X/Y/Z` (já existem).
- Produces: `CASAS_DA_PECA`, `PECAS_NO_BLOCO`, `peca_da_casa(c) -> int`, `peca_local(p) -> Vector3`,
  `casa_na_peca(k) -> Vector3`, `casas_da_peca(p) -> Array[int]`, `peca_viva(bloco, p) -> bool`,
  `casas_na_tela_da_peca(bloco, p) -> int`. As três primeiras são `static` e valem para todo o plano.

- [ ] **Step 1: Escrever a família A da sonda antes de existir qualquer peça**

Crie `tools/probes/peca.gd` com o template da casa (o cabeçalho com o `## Uso:` exato é contrato
deste repo — veja `tools/probes/batalha_real.gd`):

```gdscript
extends SceneTree
## Sonda da lapidação 4: a peça de quatro cascos.
##
## O queixa do commander é de leitura — «o bloco parece bloco único» — e a causa medida é que o bloco
## tem UMA posição e as vinte e quatro casas são vinte e quatro deslocamentos rígidos dela. Esta sonda
## prova as três coisas que tornam a subdivisão honesta: (A) a identidade da peça é a grade que já
## existe, byte a byte; (B) com a peça viva mas sem força, a pintura é a mesma expressão aritmética de
## antes (inércia provada por construção, não por screenshot); (C) a trela segura a excursão e o quadro
## zero da estação é o de hoje; (D) o ar de par de peça nunca fecha; (E) captura só em vaga; (F) a
## frase do commander — arrastar um núcleo não move a estação; (G) o poço come a peça, quatro casas, e
## 35 ≡ 840 continua de pé; (H) censo das leis medindo peça, com zero vetor fora do raio de cada lei.
##
## Uso: godot --headless --path . --quit-after 1800 -s res://tools/probes/peca.gd

const Esquadra := preload("res://esquadra.gd")

var breaks := 0
var notes: Array[String] = []


func _assert(label: String, condition: bool, detail: String) -> void:
	if condition:
		notes.append("OK   %s — %s" % [label, detail])
	else:
		breaks += 1
		notes.append("QUEBRA %s — %s" % [label, detail])


func _initialize() -> void:
	_familia_identidade()
	for n in notes:
		print(n)
	print("SONDA-PECA: veredito - quebras=%d - conferencias=%d" % [breaks, notes.size()])
	quit()


## ── Família A: identidade ──
## A cota é uma tabela literal de 24 vetores, escrita à mão a partir da definição de `casa_local`
## anterior a esta fatia. Se a soma nova divergir em qualquer ULP de qualquer casa, é esta tabela que
## grita — não uma comparação entre duas funções que podem estar erradas juntas.
func _familia_identidade() -> void:
	var esperada := [
		Vector3(-4.8, -1.6, -1.6), Vector3(-1.6, -1.6, -1.6), Vector3(1.6, -1.6, -1.6),
		Vector3(4.8, -1.6, -1.6), Vector3(-4.8, -1.6, 1.6), Vector3(-1.6, -1.6, 1.6),
		Vector3(1.6, -1.6, 1.6), Vector3(4.8, -1.6, 1.6), Vector3(-4.8, 0.0, -1.6),
		Vector3(-1.6, 0.0, -1.6), Vector3(1.6, 0.0, -1.6), Vector3(4.8, 0.0, -1.6),
		Vector3(-4.8, 0.0, 1.6), Vector3(-1.6, 0.0, 1.6), Vector3(1.6, 0.0, 1.6),
		Vector3(4.8, 0.0, 1.6), Vector3(-4.8, 1.6, -1.6), Vector3(-1.6, 1.6, -1.6),
		Vector3(1.6, 1.6, -1.6), Vector3(4.8, 1.6, -1.6), Vector3(-4.8, 1.6, 1.6),
		Vector3(-1.6, 1.6, 1.6), Vector3(1.6, 1.6, 1.6), Vector3(4.8, 1.6, 1.6)]
	var iguais := 0
	for c in range(Esquadra.CASAS):
		var p := Esquadra.peca_da_casa(c)
		var k := c % Esquadra.CASAS_DA_PECA
		var soma: Vector3 = Esquadra.peca_local(p) + Esquadra.casa_na_peca(k)
		if soma == esperada[c] and Esquadra.casa_local(c) == esperada[c]:
			iguais += 1
	_assert("A identidade: casa_local(c) == peca_local(p) + casa_na_peca(k) nas 24 casas",
		iguais == Esquadra.CASAS,
		("%d/24 vetores batem com a tabela literal; peça de c=%d e p=%d, casas de p=0 sao %s" % [
			iguais, 5, 1, str(Esquadra.casas_da_peca(0))]))
	_assert("A peça é a fileira de CASAS_X casas, e as 24 se particionam em 6 sem sobra",
		Esquadra.CASAS_DA_PECA == Esquadra.CASAS_X
			and Esquadra.PECAS_NO_BLOCO * Esquadra.CASAS_DA_PECA == Esquadra.CASAS
			and Esquadra.peca_da_casa(23) == Esquadra.PECAS_NO_BLOCO - 1,
		("PECAS_NO_BLOCO=%d x CASAS_DA_PECA=%d = %d casas, p(23)=%d" % [
			Esquadra.PECAS_NO_BLOCO, Esquadra.CASAS_DA_PECA,
			Esquadra.PECAS_NO_BLOCO * Esquadra.CASAS_DA_PECA, Esquadra.peca_da_casa(23)]))
```

- [ ] **Step 2: Rodar a sonda e confirmar que ela falha por falta de símbolo**

Run: `cd /d/Downloads/IronStarsFleetCommand && env APPDATA="D:\\Downloads\\tmp-userdata-iron" /c/Users/gmore/godot/godot --headless --path . --quit-after 1800 -s res://tools/probes/peca.gd`
Expected: `SCRIPT ERROR: Invalid call. Nonexistent function 'peca_da_casa' in base 'GDScript'`.
Isso é o vermelho desta tarefa — a sonda existe e cobra símbolos que o código ainda não tem.

- [ ] **Step 3: Escrever as constantes e a identidade em `esquadra.gd`**

Logo abaixo de `const CASAS := CASAS_X * CASAS_Y * CASAS_Z` (`esquadra.gd:53`), acrescente:

```gdscript
## ---- A peça (lapidação 4) ----
## A peça é a fileira de quatro cascos ao longo da asa. A identidade não é uma escolha nova: ela sai
## da ordem que `casa_local` já impõe às casas (camada por camada, ix variando mais rápido), então as
## casas da peça `p` são exatamente `p*CASAS_X .. p*CASAS_X + CASAS_X - 1` e a aritmética de índice
## é uma divisão só. Vinte e quatro casas viram seis peças; 240 blocos viram 1 440 corpos.
const CASAS_DA_PECA := CASAS_X
const PECAS_NO_BLOCO := CASAS_Y * CASAS_Z
```

E substitua o corpo de `casa_local` (`esquadra.gd:314-323`) — a doc-comment de 310-313 continua
válida e ganha o parágrafo da decomposição:

```gdscript
static func peca_da_casa(c: int) -> int:
	return int(float(c) / float(CASAS_DA_PECA))


## O posto da peça dentro do bloco: altura da camada e profundidade da meia-fileira. Não tem
## componente em x de propósito — é o x que a própria peça percorre.
static func peca_local(p: int) -> Vector3:
	var camada := int(float(p) / float(CASAS_Z))
	var iz := p % CASAS_Z
	return Vector3(0.0,
		(float(camada) - float(CASAS_Y - 1) / 2.0) * PASSO_CASA_Y,
		(float(iz) - float(CASAS_Z - 1) / 2.0) * PASSO_CASA_Z)


## O resíduo da casa dentro da própria peça: só asa, exatamente o passo que a grade já pagava.
static func casa_na_peca(k: int) -> Vector3:
	return Vector3((float(k) - float(CASAS_DA_PECA - 1) / 2.0) * PASSO_CASA_X, 0.0, 0.0)


## Ordem da casa dentro do bloco: camada por camada, de baixo para cima; dentro da camada, da boreste
## para a bombordo e de vante para trás. É esta ordem que faz o atrito FECHAR O TOPO do paralelepípedo
## em vez de esburacá-lo no meio — a silhueta encolhendo é a própria leitura da lotação restante.
##
## Desde a lapidação 4 esta função é a SOMA dos dois termos da peça, e isso é o contrato de inércia:
## cada termo é exato no eixo em que o outro é zero (soma com zero não arredonda), então
## `peca_local + casa_na_peca` devolve os mesmos bits que a aritmética de índice antiga devolvia, e a
## pintura com `desloc == ZERO` escreve a mesma transformada de antes. A tabela literal da família A da
## sonda `tools/probes/peca.gd` é quem confere.
static func casa_local(c: int) -> Vector3:
	return peca_local(peca_da_casa(c)) + casa_na_peca(c % CASAS_DA_PECA)
```

- [ ] **Step 4: Acrescentar os três acessores de peça (ainda sem estado, sobre `casas`)**

Depois de `casas_vivas` (`esquadra.gd:656-662`):

```gdscript
## A peça vive enquanto uma das quatro casas dela respirar. É a unidade que a cena mede (lapidação 4,
## seção 3): um poço que come uma peça mata quatro casas, não vinte e quatro.
static func peca_viva(bloco: Dictionary, p: int) -> bool:
	for k in range(CASAS_DA_PECA):
		if float(bloco["casas"][p * CASAS_DA_PECA + k]["vida"]) > 0.0:
			return true
	return false


static func casas_da_peca(p: int) -> Array[int]:
	var out: Array[int] = []
	for k in range(CASAS_DA_PECA):
		out.append(p * CASAS_DA_PECA + k)
	return out


## Casas da peça que a tela ainda mostra: a viva, e a morta cuja onda ainda não deu o recado. É o
## número que a checagem suja por peça compara (seção 3 da folha de design) — o agregado `navios` já
## morreu, o pixel ainda não.
static func casas_na_tela_da_peca(bloco: Dictionary, p: int) -> int:
	var n := 0
	for k in range(CASAS_DA_PECA):
		if _casa_na_tela(bloco, p * CASAS_DA_PECA + k):
			n += 1
	return n
```

- [ ] **Step 5: `--check-only` nas duas folhas e bateria da sonda nova**

Run:
```bash
cd /d/Downloads/IronStarsFleetCommand
GODOT=/c/Users/gmore/godot/godot
env APPDATA="D:\\Downloads\\tmp-userdata-iron" "$GODOT" --headless --path . --check-only --script res://esquadra.gd
env APPDATA="D:\\Downloads\\tmp-userdata-iron" "$GODOT" --headless --path . --check-only --script res://tools/probes/peca.gd
env APPDATA="D:\\Downloads\\tmp-userdata-iron" "$GODOT" --headless --path . --quit-after 1800 -s res://tools/probes/peca.gd
```
Expected: as duas checagens mudas, e a sonda terminando com `SONDA-PECA: veredito - quebras=0 -
conferencias=2`.

- [ ] **Step 6: Bater a sonda antiga que lê a grade, para provar que nada se moveu**

Run: `env APPDATA="D:\\Downloads\\tmp-userdata-iron" "$GODOT" --headless --path . --quit-after 1800 -s res://tools/probes/esquadra.gd`
Expected: `quebras=0` — a reexpressão de `casa_local` não move um vetor de formação.

- [ ] **Step 7: Commit**

```bash
git add esquadra.gd tools/probes/peca.gd
git status --short
git commit -m "feat(esquadra): lapidacao 4 tarefa 1 - identidade da peça e casa_local re-expresso por ela"
```
Nota: o `.uid` de `peca.gd` **não** entra nesta tarefa (ainda não existe — o motor só o escreve ao
importar). Ele entra na Tarefa 10, depois de abrir o projeto. Ver Global Constraints.

---

### Task 2: A peça como estado dentro do bloco, e a porta da cena

**Files:**
- Modify: `esquadra.gd:458-479` (`_novo_bloco`), `esquadra.gd` (novo bloco de funções perto de
  `casas_vivas`)
- Test: `tools/probes/peca.gd` família H-censo

**Interfaces:**
- Consumes: `PECAS_NO_BLOCO`, `peca_da_casa`, `casa_na_peca`, `peca_viva`, `casas_da_peca`.
- Produces: `bloco["pecas"]: Array[Dictionary]` com `{desloc, vel, vaga, pinta}`;
  `_pecas_novas() -> Array[Dictionary]`; `RAIO_DA_PECA`; `pecas_na_cena() -> Array[Dictionary]` com
  `{pos, vel, raio, bloco, peca, indice, lado}` — `peca` é o **dicionário da peça por referência** (essa
  é a canal de escrita; `pos` é instantâneo de leitura); `empurrar_peca(bloco, p, empurrao)`;
  `apertar_na_trela(desloc, vaga)`.

- [ ] **Step 1: Escrever o vermelho — família H-censo**

Acrescente em `tools/probes/peca.gd`, chame-a de `_initialize` logo após `_familia_identidade()`:

```gdscript
## ── Família H (parte 1): censo da peça ──
func _familia_censo() -> void:
	var e := Esquadra.new()
	e.montar([Vector3.ZERO], [Vector3(0.0, 0.0, -130.0)])
	var pecas := e.pecas_na_cena()
	var soma_vivas := 0
	for lado in ["aliado", "hostil"]:
		for b in e.lista_de(lado):
			for p in range(Esquadra.PECAS_NO_BLOCO):
				if Esquadra.peca_viva(b, p):
					soma_vivas += 1
	_assert("H censo: cada bloco carrega PECAS_NO_BLOCO peças e a cena devolve as vivas",
		pecas.size() == Esquadra.BLOCOS_NO_LADO * 2 * Esquadra.PECAS_NO_BLOCO
			and soma_vivas == pecas.size(),
		("%d pecas na cena, %d vivas somadas bloco a bloco, %d x %d de 240 blocos x 6" % [
			pecas.size(), soma_vivas, Esquadra.BLOCOS_NO_LADO * 2, Esquadra.PECAS_NO_BLOCO]))
	_assert("H raio: o raio de cadastro é a metade da fileira medida, asa a asa",
		absf(Esquadra.RAIO_DA_PECA - (float(Esquadra.CASAS_DA_PECA - 1) * Esquadra.PASSO_CASA_X
			+ 0.912) / 2.0) < 0.001,
		("RAIO_DA_PECA=%.3f u para uma fileira de %.1f u de cascos + 0,912 de caixa" % [
			Esquadra.RAIO_DA_PECA, float(Esquadra.CASAS_DA_PECA - 1) * Esquadra.PASSO_CASA_X]))
	# A peça morta sai do censo: apagar as quatro casas de p=1 de um bloco aliado tira uma peça do
	# mundo sem tirar o bloco. É o devoramento do poço medido por contagem, antes de existir poço.
	var b0: Dictionary = e.lista_de("aliado")[0]
	for c in Esquadra.casas_da_peca(1):
		b0["casas"][c]["vida"] = 0.0
	Esquadra._recalcular_agregados(b0)
	var depois := e.pecas_na_cena().size()
	_assert("H censo: peça sem casa viva não senta banco na cena, e o bloco continua vivo",
		depois == pecas.size() - 1 and bool(b0["vivo"])
			and Esquadra.casas_vivas(b0) == Esquadra.CASAS - Esquadra.CASAS_DA_PECA,
		("cena caiu de %d para %d pecas; bloco com %d casas e navios %.4f (cai 1/4 de 100)" % [
			pecas.size(), depois, Esquadra.casas_vivas(b0), float(b0["navios"])]))
```

- [ ] **Step 2: Rodar e ler o vermelho**

Run: a linha de `--quit-after` da Tarefa 1, Step 5.
Expected: `SCRIPT ERROR: Invalid call. Nonexistent function 'pecas_na_cena'`.

- [ ] **Step 3: O estado da peça no criador do bloco**

Em `_novo_bloco` (`esquadra.gd:458-479`), a linha `"casas": _casas_novas(),` passa a ser duas:

```gdscript
		"casas": _casas_novas(),
		"pecas": _pecas_novas(),
```

E antes de `_novo_bloco`, o construtor (é **aqui**, não na montagem do `main`, que a precondition é
declarada — regra da folha de fechamento):

```gdscript
## As seis peças de um bloco novo, todas no próprio posto. O que a peça carrega é uma excursão no
## referencial LOCAL do bloco (`desloc`), nunca uma posição de mundo: é isso que faz a pintura com
## `desloc` zero ser a mesma conta aritmética de antes (soma com zero não arredonda) e faz a
## transformada do mundo inteira sair de `b["pos"] + rot * (...)` como sempre saiu. `vaga` é o posto
## extra que a peça capturou (seção 4); `pinta` é a memória suja por peça (seção 3).
static func _pecas_novas() -> Array[Dictionary]:
	var pecas: Array[Dictionary] = []
	for p in range(PECAS_NO_BLOCO):
		pecas.append({"desloc": Vector3.ZERO, "vel": Vector3.ZERO, "vaga": Vector3.ZERO,
			"pinta": {"desloc": Vector3(1e9, 0.0, 0.0), "casas": -1}})
	return pecas
```

- [ ] **Step 4: A porta da cena, com buffer reusado**

Depois de `casas_na_tela_da_peca`:

```gdscript
## Raio de cadastro de uma peça, lido da caixa medida da fileira: (4 − 1) × 3,2 u de passo mais os
## 0,912 u de asa da réplica escalada, tudo sobre dois. É o que a cena usa para distância de contato
## com rocha e astro — não o braço do bloco inteiro, que é 10,5 u.
const RAIO_DA_PECA := (float(CASAS_DA_PECA - 1) * PASSO_CASA_X + 0.912) / 2.0

## O buffer do censo: 1 440 dicionários por tique, e alocá-los de novo a cada quadro é o único custo
## real da fatia (as cinco leis somam ~25 mil operações vetoriais, que é nada). O buffer cresce até o
## censo máximo e então só reescreve campos — os invólucros vivem para sempre.
var _pecas_na_cena_buf: Array[Dictionary] = []


## A cena mede peça por peça. Cada entrada é `{pos, vel, raio, bloco, peca, indice, lado}`, onde
## `peca` é o dicionário da peça **por referência** — escrever nele é escrever no estado, a mesma
## técnica de `_collision_bodies()`. `pos` e `vel` são instantâneos de leitura (o mundo), `desloc` é o
## estado (o referencial do bloco): quem empurra passa por `empurrar_peca`, nunca escreve `pos`. A
## velocidade é a do bloco mais a da peça girada na atitude do bloco, porque a lei de abalroamento do
## cenário cobra pela **velocidade relativa** e uma peça parada no bloco que anda não está parada no
## mundo.
func pecas_na_cena() -> Array[Dictionary]:
	var n := 0
	for lado in ["aliado", "hostil"]:
		for b in lista_de(lado):
			if not bool(b["vivo"]):
				continue
			var rot := Basis.from_euler(Vector3(0.0, float(b["rumo"]), 0.0))
			var origem: Vector3 = b["pos"]
			for p in range(PECAS_NO_BLOCO):
				var pc: Dictionary = b["pecas"][p]
				if not peca_viva(b, p):
					continue
				while _pecas_na_cena_buf.size() <= n:
					_pecas_na_cena_buf.append({})
				var par: Dictionary = _pecas_na_cena_buf[n]
				par["pos"] = origem + rot * (peca_local(p) + (pc["desloc"] as Vector3))
				par["vel"] = (b["vel"] as Vector3) + rot * (pc["vel"] as Vector3)
				par["raio"] = RAIO_DA_PECA
				par["bloco"] = b
				par["peca"] = pc
				par["indice"] = p
				par["lado"] = lado
				n += 1
	# A cauda de um tique anterior pode apontar para blocos que já não existem (rendição, expulsão de
	# mortos). Encurtar o buffer é o que impede a cena de empurrar um cadáver.
	_pecas_na_cena_buf.resize(n)
	return _pecas_na_cena_buf
```

- [ ] **Step 5: A trela e o empurrão pela porta local**

```gdscript
## Folga da peça, por eixo, derivada da tabela de ar medida do bloco (seção 4 do design): metade do ar
## mais apertado em que a peça participa, arredondada para baixo. É por construção que duas peças
## vizinhas nunca se sobrepõem mesmo nos cursos extremos opostos — sobram 0,088 u (x), 0,132 (y) e
## 0,150 (z) de ar. A liberdade que o commander pediu não vem daqui, vem da vaga (Tarefa 5).
const FOLGA_DA_PECA := Vector3(1.2, 0.6, 0.9)


## A excursão não pode passar da trela, eixo a eixo, em torno do posto que a peça persegue — que é o
## próprio posto mais a vaga capturada. Clamp por eixo, não por módulo: com módulo o curso de uma peça
## seria limitado na diagonal e livre contra o vizinho, que é exatamente o disco que a lei de voo
## recusa.
static func apertar_na_trela(desloc: Vector3, vaga: Vector3) -> Vector3:
	return Vector3(
		clampf(desloc.x, vaga.x - FOLGA_DA_PECA.x, vaga.x + FOLGA_DA_PECA.x),
		clampf(desloc.y, vaga.y - FOLGA_DA_PECA.y, vaga.y + FOLGA_DA_PECA.y),
		clampf(desloc.z, vaga.z - FOLGA_DA_PECA.z, vaga.z + FOLGA_DA_PECA.z))


## Empurra a peça pelo mundo, pela porta dela. A rotação inversa é `from_euler(0, -rumo, 0)` porque o
## bloco só gira em y — sem isso, um empurrão de mundo escrito direto em `desloc` seria um empurrão em
## outro eixo assim que a linha manobrasse. E o empurrão sai logo apertado na trela: o poço tem
## direito de puxar; quem paga o preço de voltar é a formação.
func empurrar_peca(bloco: Dictionary, p: int, empurrao: Vector3) -> void:
	var pc: Dictionary = bloco["pecas"][p]
	var rot_inv := Basis.from_euler(Vector3(0.0, -float(bloco["rumo"]), 0.0))
	pc["desloc"] = apertar_na_trela((pc["desloc"] as Vector3) + rot_inv * empurrao,
		pc["vaga"] as Vector3)
```

- [ ] **Step 6: Checagem e sonda**

Run (as três linhas do Step 5 da Tarefa 1, com `esquadra.gd` também):
Expected: `SONDA-PECA: veredito - quebras=0 - conferencias=4`.

- [ ] **Step 7: Bateria completa, porque a folha do bloco mudou de forma**

Run: `bash /d/Downloads/tmp-userdata-iron/bateria.sh`
Expected: 33 logs headless (35 menos as 3 de janela, mais `peca.log`) todos com `quebras=0` e
`linhas_erro=0`. O censo publicado passa de **35** para **36** sondas e a Tarefa 10 escreve isso no
README com o número lido, não chutado.

- [ ] **Step 8: Commit**

```bash
git add esquadra.gd tools/probes/peca.gd
git status --short
git commit -m "feat(esquadra): lapidacao 4 tarefa 2 - a peça é estado do bloco e a cena mede pela porta pecas_na_cena"
```

---

### Task 3: Os três leitores passam por peça + casa, e a inércia é provada

**Files:**
- Modify: `esquadra.gd:387-410` (`_casas_por_proximidade`), `esquadra.gd:693-717`
  (`caixa_do_bloco`), `esquadra.gd:1562-1600` (`pintar`)
- Test: `tools/probes/peca.gd` família B

**Interfaces:**
- Consumes: `peca_local`, `casa_na_peca`, `peca_da_casa`, `casas_na_tela_da_peca`,
  `bloco["pecas"][p]["pinta"]`.
- Produces: `esquadra.pecas_livres: bool` (alavanca de medição, `false` até a Tarefa 4 ligar o voo),
  `pos_da_peca(bloco, p) -> Vector3` (mundo), `caixa_da_peca(bloco, p) -> AABB`.

- [ ] **Step 1: O vermelho — família B, inércia provada por construção**

A leitura de volta do `MultiMesh` sob `--headless` é inerte (o motor devolve identidade), então a
família B **não** pode medir transformada escrita. Ela mede as duas premissas cuja conjunção é a
igualdade, e a igualdade visual fica para a sonda de janela na Tarefa 10. Dito no cabeçalho da asserção,
para ninguém ler como portão frouxo:

```gdscript
## ── Família B: inércia ──
## O headless não lê o `MultiMesh` de volta, então esta família prova a igualdade pelas duas premissas
## que a compõem: a algebraica (a soma dos dois termos é `casa_local`, tabela literal da família A) e a
## fisica (com a alavanca desligada, os 1 440 `desloc` são exatamente ZERO, e a transformada escrita é
## a mesma expressão de antes, bit a bit). A leitura de que o quadro mudou é do commander na janela
## (Tarefa 10) — afirmar "pixel idêntico" medido em headless seria o portão falhando aberto.
func _familia_inercia() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	await _frames(3)
	var e: Esquadra = game.esquadra
	var zero := 0
	var total := 0
	for lado in ["aliado", "hostil"]:
		for b in e.lista_de(lado):
			for pc in b["pecas"]:
				total += 1
				if (pc["desloc"] as Vector3) == Vector3.ZERO:
					zero += 1
	_assert("B inercia: com a alavanca desligada, nenhuma peça tem excursão",
		not e.pecas_livres and total == 240 * Esquadra.PECAS_NO_BLOCO and zero == total,
		("%d/%d pecas com desloc exatamente ZERO, alavanca=%s" % [zero, total, str(e.pecas_livres)]))
	# O outro lado da premissa: os leitores novos dão o mesmo valor dos velhos, medido contra a
	# expressão anterior ainda viva em `casa_local` (que a Tarefa 1 re-definiu como a soma).
	var igual := 0
	var b0: Dictionary = e.lista_de("aliado")[0]
	var rot := Basis.from_euler(Vector3(0.0, float(b0["rumo"]), 0.0))
	var origem: Vector3 = b0["pos"]
	for c in range(Esquadra.CASAS):
		var p := Esquadra.peca_da_casa(c)
		var somado: Vector3 = origem + rot * (Esquadra.peca_local(p)
			+ Esquadra.casa_na_peca(c % Esquadra.CASAS_DA_PECA))
		if somado == origem + rot * Esquadra.casa_local(c):
			igual += 1
	_assert("B inercia: a conta nova da pintura é a conta velha, nos 24 vetores de mundo",
		igual == Esquadra.CASAS, "%d/24 vetores de mundo byte-idênticos" % igual)
	game.queue_free()
```

Mude `_initialize()` para conduzi-la com `await`:

```gdscript
func _initialize() -> void:
	_familia_identidade()
	_familia_censo()
	await _familia_inercia()
	for n in notes:
		print(n)
	print("SONDA-PECA: veredito - quebras=%d - conferencias=%d" % [breaks, notes.size()])
	quit()
```

- [ ] **Step 2: Rodar e ler o vermelho**

Expected: `SCRIPT ERROR: Invalid assignment of property or key 'pecas_livres' with value of type
'bool' on a base object of type 'GDScript/preload'` — ou, na asserção, `Invalid get index
'pecas_livres'`. A alavanca ainda não existe.

- [ ] **Step 3: A alavanca, com o nome do que ela mede**

No bloco de estado da `Esquadra` (junto de `var _derivas`, `esquadra.gd:140`):

```gdscript
## Alavanca da fatia, e é um instrumento de medição, não um recurso de jogo. Desligada, as peças existem
## como estado mas nenhuma força as move: é assim que a família B mede a inércia numa partida inteira e
## não num quadro isolado. Ligada pela Tarefa 4, ela é a lei. Não tem entrada de painel, não tem tecla,
## e nenhum save a grava.
var pecas_livres := false
```

- [ ] **Step 4: A mira por proximidade lê peça + casa**

Em `_casas_por_proximidade` (`esquadra.gd:394`), a linha do `dist.append` passa a somar os dois termos
em vez de chamar `casa_local` — a palavra `casa_local` sai desta função e entra a estrutura que o
comandante pediu que a cena lesse:

```gdscript
			var p := peca_da_casa(c)
			dist.append(((alvo["pos"] as Vector3)
				+ rot * (peca_local(p) + casa_na_peca(c % CASAS_DA_PECA)
					+ (alvo["pecas"][p]["desloc"] as Vector3))).distance_squared_to(origem_pos))
```

- [ ] **Step 5: A caixa do bloco passa pela caixa da peça**

Troque `pos_da_peca`/`caixa_da_peca` para dentro, antes de `caixa_do_bloco` (`esquadra.gd:693`):

```gdscript
## Onde a peça está no mundo: o posto local dela, mais a vaga capturada, mais a excursão, tudo girado e
## transladado pelo bloco. A peça não guarda posição de mundo de propósito — ver `_pecas_novas`.
func pos_da_peca(bloco: Dictionary, p: int) -> Vector3:
	var pc: Dictionary = bloco["pecas"][p]
	var rot := Basis.from_euler(Vector3(0.0, float(bloco["rumo"]), 0.0))
	return (bloco["pos"] as Vector3) + rot * (peca_local(p)
		+ (pc["vaga"] as Vector3) + (pc["desloc"] as Vector3))


## Caixa de uma peça: a fileira de quatro cascos, pelos índices que vivem de fato. É a caixa que o
## poço, o vento e a rocha medem (seção 3) — não a do bloco inteiro, que é o que fazia a muralha
## inteira caber dentro do raio de um corpo só.
func caixa_da_peca(bloco: Dictionary, p: int) -> AABB:
	if not peca_viva(bloco, p) or not bool(bloco["vivo"]):
		return AABB(Vector3.ZERO, Vector3(-1.0, -1.0, -1.0))
	if _meia_casco == Vector3.ZERO:
		_meia_casco = malha_replica().get_aabb().size * 0.5 * ESCALA_REPLICA
	var rot := Basis.from_euler(Vector3(0.0, float(bloco["rumo"]), 0.0))
	var centro := pos_da_peca(bloco, p)
	var minimo := Vector3.ONE * 1e9
	var maximo := Vector3.ONE * -1e9
	for k in range(CASAS_DA_PECA):
		var c := p * CASAS_DA_PECA + k
		if not casa_viva(bloco, c):
			continue
		var local: Vector3 = rot * casa_na_peca(k)
		minimo = Vector3(minf(minimo.x, local.x - _meia_casco.x),
			minf(minimo.y, local.y - _meia_casco.y),
			minf(minimo.z, local.z - _meia_casco.z))
		maximo = Vector3(maxf(maximo.x, local.x + _meia_casco.x),
			maxf(maximo.y, local.y + _meia_casco.y),
			maxf(maximo.z, local.z + _meia_casco.z))
	return AABB(centro + minimo, maximo - minimo)
```

E dentro de `caixa_do_bloco`, o laço de casas passa a montar a caixa a partir das caixas de peça — o
bloco continua sendo a unidade de comando e de ledger, mas a geometria dele é a união do que manobra:

```gdscript
func caixa_do_bloco(bloco: Dictionary) -> AABB:
	var casas := casas_vivas(bloco)
	if casas <= 0 or not bool(bloco["vivo"]):
		return AABB(Vector3.ZERO, Vector3(-1.0, -1.0, -1.0))
	var uniao := AABB(Vector3.ZERO, Vector3(-1.0, -1.0, -1.0))
	for p in range(PECAS_NO_BLOCO):
		uniao = uniao.merge(caixa_da_peca(bloco, p))
	return uniao
```

Se `merge` com volume negativo devolver caixa invertida em vez de ignorar, troque o laço por
`if not caixa_da_peca(bloco, p).has_volume(): continue` antes do `merge` — **meça** qual dos dois o
motor faz e escreva a asserção que passar, sem mudar a aritmética de grade.

- [ ] **Step 6: A pintura fica suja por peça, não por bloco**

Substitua o corpo de `pintar` (`esquadra.gd:1562-1600`) inteiro, mantendo a cauda de cauda-órfã
inalterada:

```gdscript
## Repinta o `MultiMesh` de um lado. Devolve quantos **blocos** foram tocados — número que a sonda
## confere. Desde a lapidação 4 a sujeira tem dois andares: o bloco sujo (casas, posição ou rumo do
## corpo de comando mudaram) sujeita as seis peças, e uma peça suja sujeita só as quatro casas dela.
## Sem o andar de baixo, a muralha que respira passaria a reescrever 5 760 transformados por quadro no
## pior caso, que é o custo real desta fatia — não os ~25 mil vetoriais das leis de cenário.
func pintar(mm: MultiMesh, lado: String, forcar := false) -> int:
	var lista := lista_de(lado)
	var tocados := 0
	for i in range(lista.size()):
		var b: Dictionary = lista[i]
		var base := i * CASAS
		var casas := casas_na_tela(b) if bool(b["vivo"]) else 0
		var pintado: Dictionary = b["pintas"]
		var bloco_sujo := forcar or casas != int(pintado["casas"]) \
			or (b["pos"] as Vector3).distance_squared_to(pintado["pos"]) > 0.0001 \
			or absf(float(b["rumo"]) - float(pintado["rumo"])) > 0.001
		if bloco_sujo:
			tocados += 1
			pintado["casas"] = casas
			pintado["pos"] = b["pos"]
			pintado["rumo"] = float(b["rumo"])
		var origem: Vector3 = b["pos"]
		var rot := Basis.from_euler(Vector3(0.0, float(b["rumo"]), 0.0))
		var escala := Vector3.ONE * ESCALA_REPLICA
		var girada := rot.scaled(escala)
		for p in range(PECAS_NO_BLOCO):
			var pc: Dictionary = b["pecas"][p]
			var pp: Dictionary = pc["pinta"]
			var na_tela := casas_na_tela_da_peca(b, p) if bool(b["vivo"]) else 0
			var suja := bloco_sujo or forcar \
				or na_tela != int(pp["casas"]) \
				or (pc["desloc"] as Vector3).distance_squared_to(pp["desloc"]) > 0.0001
			if not suja:
				continue
			pp["desloc"] = pc["desloc"]
			pp["casas"] = na_tela
			var local_base: Vector3 = peca_local(p) + (pc["desloc"] as Vector3)
			for k in range(CASAS_DA_PECA):
				var c := p * CASAS_DA_PECA + k
				if bool(b["vivo"]) and _casa_na_tela(b, c):
					mm.set_instance_transform(base + c, Transform3D(girada,
						origem + (rot * (local_base + casa_na_peca(k)))))
				else:
					# Base nula é o "escondido" do MultiMesh: triângulo degenerado, nada rasteriza,
					# e o orçamento de instâncias não muda — a casa some sem o motor realocar nada.
					mm.set_instance_transform(base + c, Transform3D(Basis(), origem))
	var limite := lista.size() * CASAS
	var pintadas := int(_casas_pintadas[lado])
	if pintadas > limite:
		for k2 in range(limite, pintadas):
			mm.set_instance_transform(k2, Transform3D(Basis(), Vector3.ZERO))
	_casas_pintadas[lado] = limite
	return tocados
```

A ordem dos termos dentro do parêntese é contrato, não estilo: `peca_local + desloc` somado a
`casa_na_peca` produz os mesmos bits da conta antiga com `desloc == ZERO` (a família B mede os 24
vetores). Trocar a ordem por `casa_na_peca + local_base` abre ULP e o portão deixa de ser prova.

- [ ] **Step 7: Checagem, sonda e as três sondas que leem caixa e pintura**

```bash
GODOT=/c/Users/gmore/godot/godot
for s in res://esquadra.gd res://main.gd res://tools/probes/peca.gd; do
  env APPDATA="D:\\Downloads\\tmp-userdata-iron" "$GODOT" --headless --path . --check-only --script "$s"
done
for p in peca casas comando massa_visivel esquadra; do
  env APPDATA="D:\\Downloads\\tmp-userdata-iron" "$GODOT" --headless --path . --quit-after 1800 \
    -s res://tools/probes/$p.gd | tail -3
done
```
Expected: `peca` com `quebras=0 - conferencias=6`; `casas`, `comando` e `esquadra` verdes;
`massa_visivel` **só roda em janela** (o `--headless` nela devolve textura null) — nesta tarefa,
rode-a em janela com o comando do cabeçalho e leia o PNG de volta. Se ela reclamar de boca de casa
ou de contagem de blocos tocados, declare a precondition na sonda (ela estava medindo o dirty-test
por bloco) e não a tolerância.

- [ ] **Step 8: Commit**

```bash
git add esquadra.gd tools/probes/peca.gd
git status --short
git commit -m "feat(esquadra): lapidacao 4 tarefa 3 - caixa, mira e pintura lem a peca; inercia provada"
```

---

### Task 4: A peça voa dentro da trela

**Files:**
- Modify: `esquadra.gd:912-971` (`passo`)
- Test: `tools/probes/peca.gd` famílias C-trela e D-ar

**Interfaces:**
- Consumes: `Voo.marchar`, `Voo.FICHA_BLOCO`, `MARCHA_DE_BLOCO`, `apertar_na_trela`, `peca_local`,
  `FOLGA_DA_PECA`, `bloco["pecas"]`.
- Produces: `_passo_das_pecas(bloco, delta)` (chamado por `passo`), e `pecas_livres` ligada.

- [ ] **Step 1: O vermelho — famílias C e D**

```gdscript
## ── Família C (trela) e D (ar) ──
## A folga é ±1,2/0,6/0,9, e a tabela de ar publicada é de grade SEM excursão: com dois vizinhos em
## cursos extremos opostos o ar do par cai para 0,088 (x) / 0,132 (y) / 0,150 (z) u. Por isso D cobra
## duas asserções distintas e nenhuma delas afrouxa a antiga: o ar do par intra-bloco medido quadro a
## quadro tem de ser estritamente positivo (é a garantia da construção), e o piso analítico entre blocos
## vizinhos com excursão extrema oposta também. A tabela publicada de ar continua sendo cobrada pela
## família 2 da sonda `esquadra.gd`, régua de bloco, com a alavanca desligada — não é esta folha.
func _familia_trela_e_ar() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	await _frames(3)
	var e: Esquadra = game.esquadra
	e.pecas_livres = true
	var pior := Vector3(-1.0, -1.0, -1.0)
	var leitura := 0
	var ar_min := 1e9
	var onde := "nenhum par medido"
	for f in range(900):
		game._process(1.0 / 60.0)
		for lado in ["aliado", "hostil"]:
			for b in e.lista_de(lado):
				for p in range(Esquadra.PECAS_NO_BLOCO):
					var pc: Dictionary = b["pecas"][p]
					var d: Vector3 = pc["desloc"]
					var vaga: Vector3 = pc["vaga"]
					pior.x = maxf(pior.x, absf(d.x - vaga.x))
					pior.y = maxf(pior.y, absf(d.y - vaga.y))
					pior.z = maxf(pior.z, absf(d.z - vaga.z))
					leitura += 1
				# Os quinze pares de peça viva dentro do bloco: é aqui que o ar é apertado (1,332 u em y,
				# 1,950 u em z) e é aqui que a peça anda. Caixa de peça, não raio de esfera — a fileira tem
				# 10,5 u de asa e medir distância de centro com `RAIO_DA_PECA` daria negativo sempre.
				for p in range(Esquadra.PECAS_NO_BLOCO):
					if not Esquadra.peca_viva(b, p):
						continue
					var ca := e.caixa_da_peca(b, p)
					if not ca.has_volume():
						continue
					for q in Esquadra.vizinhos_locais_da_peca(p):
						if q <= p or not Esquadra.peca_viva(b, q):
							continue
						var cb := e.caixa_da_peca(b, q)
						if not cb.has_volume():
							continue
						var ar := _ar_entre_caixas(ca, cb)
						if ar < ar_min:
							ar_min = ar
							onde = "bloco %d p%d/p%d salva %d" % [int(b["id"]), p, q, e.salva_numero]
	_assert("C trela: nenhuma excursão passou da folga em nenhum eixo em 900 quadros",
		pior.x <= Esquadra.FOLGA_DA_PECA.x + 0.0001
			and pior.y <= Esquadra.FOLGA_DA_PECA.y + 0.0001
			and pior.z <= Esquadra.FOLGA_DA_PECA.z + 0.0001,
		("max |desloc-vaga| = (%.3f, %.3f, %.3f) contra a folga (%.1f, %.1f, %.1f) em %d leituras" % [
			pior.x, pior.y, pior.z, Esquadra.FOLGA_DA_PECA.x, Esquadra.FOLGA_DA_PECA.y,
			Esquadra.FOLGA_DA_PECA.z, leitura]))
	_assert("D ar intra-bloco: o par de peça mais apertado do lote inteiro nunca fechou",
		ar_min > 0.0,
		("minimo medido %.3f u em %s, com a folga viva dos dois lados" % [ar_min, onde]))
	# O piso analítico entre BLOCOS vizinhos: o ar publicado menos as duas metades de folga, por eixo.
	# É conta sobre constantes, e os três números saem impressos — se algum fechar, a folga daquele eixo
	# está errada e é ela que se corrige, nunca o portão.
	var x := Esquadra.PASSO_BLOCO_X - 10.512 - 2.0 * Esquadra.FOLGA_DA_PECA.x
	var z := Esquadra.PASSO_BLOCO_Z - 4.450 - 2.0 * Esquadra.FOLGA_DA_PECA.z
	var y := Esquadra.PASSO_ESQUADRAO_Y - 3.467 - 2.0 * Esquadra.FOLGA_DA_PECA.y
	_assert("D ar entre blocos: com os dois vizinhos no extremo oposto da trela ainda sobra ar",
		x > 0.0 and z > 0.0 and y > 0.0,
		("pisos analíticos x=%.3f (de 2,488 publicado) z=%.3f (de 2,550) y=%.3f (de 8,533)" % [x, z, y]))
	# A segunda asserção prometida pelo desvio 1 da folha de plano: a TABELA PUBLICADA do §4, recontada
	# com a excursão zerada. É a régua que a família 2 de `esquadra.gd` já cobra em bloco; aqui ela é
	# coberta na escala de peça, e por isso é conta sobre as constantes da grade, não medida de quadro.
	# Os seis pares do §4, cada um `passo − caixa`, com o literal publicado ao lado: se a subdivisão
	# mexeu em passo ou caixa qualquer, é aqui que o número deixa de bater.
	var pares := [
		["casa-casa x (dentro da peça)", Esquadra.PASSO_CASA_X - 0.912, 2.288],
		["casa-casa z (dentro do bloco)", Esquadra.PASSO_CASA_Z - 1.25, 1.95],
		["casa-casa y (dentro do bloco)", Esquadra.PASSO_CASA_Y - 0.268, 1.332],
		["bloco-bloco x (na fileira)", Esquadra.PASSO_BLOCO_X - 10.512, 2.488],
		["fileira-fileira z", Esquadra.PASSO_BLOCO_Z - 4.45, 2.55],
		["andar-andar y", Esquadra.PASSO_ESQUADRAO_Y - 3.467, 8.533],
	]
	for par in pares:
		_assert("D tabela publicada: %s = %.3f u com a excursão zerada" % [par[0], par[2]],
			absf(float(par[1]) - float(par[2])) < 0.001,
			("recalcado %.4f contra o publicado %.4f" % [float(par[1]), float(par[2])]))
	game.queue_free()


## Distância entre duas AABBs de mundo: 0 se se encostam ou sobrepõem, senão a norma dos vãos por eixo.
func _ar_entre_caixas(a: AABB, b: AABB) -> float:
	var dx := maxf(0.0, maxf(b.position.x - (a.position.x + a.size.x),
		a.position.x - (b.position.x + b.size.x)))
	var dy := maxf(0.0, maxf(b.position.y - (a.position.y + a.size.y),
		a.position.y - (b.position.y + b.size.y)))
	var dz := maxf(0.0, maxf(b.position.z - (a.position.z + a.size.z),
		a.position.z - (b.position.z + b.size.z)))
	return Vector3(dx, dy, dz).length()
```

Acrescente o acesso de vizinhança que a família D chama (`esquadra.gd`, estático, perto de
`casas_da_peca`):

```gdscript
## Vizinhos de peça DENTRO do próprio bloco, derivados do índice: a outra meia-fileira da mesma camada
## (um em z) e as camadas vizinhas com a mesma profundidade (dois em y). No máximo três, e sem
## transbordo de bloco — os vizinhos de fora são régua de grade, cobertos pela família 2 da sonda
## `esquadra.gd` mais o piso analítico desta folha. Seis peças x três vizinhos x 240 blocos dá os
## ~11 520 testes de par por tique que a seção 4 conta, e aqui só os intra-bloco são lidos de caixa.
static func vizinhos_locais_da_peca(p: int) -> Array[int]:
	var out: Array[int] = []
	var camada := int(float(p) / float(CASAS_Z))
	var iz := p % CASAS_Z
	var otro_iz := (iz + 1) % CASAS_Z
	out.append(camada * CASAS_Z + otro_iz)
	if camada > 0:
		out.append((camada - 1) * CASAS_Z + iz)
	if camada < CASAS_Y - 1:
		out.append((camada + 1) * CASAS_Z + iz)
	return out
```

Ligue a família no `_initialize` — ela só conta se for chamada:

```gdscript
	await _familia_trela_e_ar()
```

- [ ] **Step 2: Rodar e ler o vermelho**

Expected: `Nonexistent function 'vizinhos_locais_da_peca'` e, depois de criado, a família C ou passa
silenciosamente porque nada integra (nesse caso a asserção tem de dizer `pior=(0,0,0)` — e o vermelho
real vem do passo 3, quando o voo liga e a trela é testada de verdade). Não declare verde sem ler o
três-zero.

- [ ] **Step 3: O laço das peças dentro de `passo`**

Em `passo`, logo depois do laço de blocos (que termina em `esquadra.gd:970`) e antes de `_reparar`, e
a alavanca ligada:

```gdscript
	if pecas_livres:
		for lado in ["aliado", "hostil"]:
			for b in lista_de(lado):
				if bool(b["vivo"]):
					_passo_das_pecas(b, delta)
	_reparar(delta)
```

```gdscript
## Lei de voo das seis peças de um bloco, no referencial local dele. O bloco integra primeiro, com a
## lei intacta; a peça obedece depois, e o que ela persegue é o próprio posto local mais a vaga
## capturada. `rumo` 0.0 é de propósito: no referencial do bloco a proa local é sempre −z (é assim que
## `casa_local` ordena as casas e `rot` as leva para o mundo), e uma peça que girasse para o resíduo de
## perseguição apresentaria través dentro da formação — o mesmo erro que `_pilotar`/`_empuxar` já
## nomeiam no `main`. Marcha e ficha são as do bloco: a peça não é uma classe nova de navio, é parte
## de um, e a única coisa nova aqui é o tempo de resposta interno.
func _passo_das_pecas(bloco: Dictionary, delta: float) -> void:
	for p in range(PECAS_NO_BLOCO):
		var pc: Dictionary = bloco["pecas"][p]
		if not peca_viva(bloco, p):
			pc["desloc"] = Vector3.ZERO
			pc["vel"] = Vector3.ZERO
			continue
		var alvo: Vector3 = pc["vaga"]
		var voo := Voo.marchar(pc["desloc"] as Vector3, pc["vel"] as Vector3, 0.0, alvo, delta,
			MARCHA_DE_BLOCO, Voo.FICHA_BLOCO, 0.0)
		pc["vel"] = voo["vel"]
		pc["desloc"] = apertar_na_trela(voo["pos"] as Vector3, alvo)
```

Ligando `pecas_livres`, três conseqüências têm de ser lidas e escritas, não presumidas: a muralha
respira por peça agora (a deriva de custódia continua no bloco — a peça ainda nem sabe dela), a caixa
do bloco é a união das caixas de peça (Tarefa 3) e o corte de linha (`_entrada_na_caixa` sobre a caixa)
passa a ver silhuetas um pouco mais gordas. As famílias 2, 13 e 15 da sonda `esquadra.gd` são as que
cobram ar, rodízio e pista: se alguma reprovar, a asserção dela declara a precondition no `montar` ou
no laço novo — nunca na tolerância.

- [ ] **Step 4: Sonda + as três que cobram ar e manobra**

```bash
for p in peca esquadra comando casas; do
  env APPDATA="D:\\Downloads\\tmp-userdata-iron" "$GODOT" --headless --path . --quit-after 1800 \
    -s res://tools/probes/$p.gd | tail -4
done
```
Expected: `peca` com `quebras=0`; `esquadra` verde inclusive as famílias 2/13/15. Se a 2 reprovar com
ar negativo, a folga está errada e não o portão: volte à tabela da seção 4 e derive o eixo que quebrou
com o valor medido, commitando a correção da **folga** (não do `AR_MINIMO`).

- [ ] **Step 5: Bateria completa + janela `massa_visivel`, com o PNG relido**

Run: `bash /d/Downloads/tmp-userdata-iron/bateria.sh`, depois a sonda de janela com o comando do
cabeçalho dela. Leia o PNG de volta com `Read`. A este ponto o quadro **já deve** mostrar as fileiras
de quatro se movendo — se não mostrar, a alavanca não ligou ou o `desloc` está preso em zero.

- [ ] **Step 6: Commit**

```bash
git add esquadra.gd tools/probes/peca.gd tools/probes/esquadra.gd
git status --short
git commit -m "feat(esquadra): lapidacao 4 tarefa 4 - a peca voa com a propria lei dentro da trela de 1,2/0,6/0,9"
```

---

### Task 5: Captura para frente, só em vaga

**Files:**
- Modify: `esquadra.gd` (`_passo_das_pecas`, novos `FATOR_DE_VAGA`, `postos_efetivos`, `_vaga_para`,
  `_espaco_aberto`)
- Test: `tools/probes/peca.gd` família E

**Interfaces:**
- Consumes: `vizinhos_locais_da_peca`, `peca_viva`, `peca_local`, `PASSO_CASA_Y/Z`,
  `PASSO_BLOCO_Z`, `PASSO_ESQUADRAO_Y`, `casas_da_peca`.
- Produces: `bloco["pecas"][p]["vaga"]` não-zero quando a peça capturou um posto;
  `Esquadra.postos_efetivos(bloco)`; `Esquadra.FATOR_DE_VAGA`.

- [ ] **Step 1: O vermelho — família E**

```gdscript
## ── Família E: captura ──
## O portão é duplo e os dois lados saem impressos: nenhuma captura aconteceu fora de uma vaga real, e
## toda captura aconteceu com o espaço aberto acima da cota de 1,3 × passo do eixo. A contagem de
## capturas tem de ser MAIOR que zero no fim do teste — uma família E que só prova "zero capturas" é um
## portão que passa vazio, e foi assim que a fatia 3 enganou doze sondas.
func _familia_vaga() -> void:
	var e := Esquadra.new()
	e.montar([Vector3.ZERO], [Vector3(0.0, 0.0, -130.0)])
	e.pecas_livres = true
	var b: Dictionary = e.lista_de("aliado")[0]
	# Mata a peça do meio (p=2: camada 1, iz 0) e as duas que podem querer o posto dela: p=0 (camada 0,
	# mesmo iz) via y, e p=... em z o par de p=2 é p=3, vivo. Depois de apagadas as quatro casas de p=2,
	# o posto dela é o único vagante do bloco.
	for c in Esquadra.casas_da_peca(2):
		b["casas"][c]["vida"] = 0.0
	Esquadra._recalcular_agregados(b)
	var capturas := 0
	var fora_da_vaga := 0
	var espaco_min := 1e9
	for f in range(600):
		e.passo(1.0 / 60.0, [Vector3.ZERO], [Vector3(0.0, 0.0, -130.0)])
		for p in range(Esquadra.PECAS_NO_BLOCO):
			var pc: Dictionary = b["pecas"][p]
			var v: Vector3 = pc["vaga"]
			if v != Vector3.ZERO:
				capturas += 1
				# A vaga tem de apontar para o posto de uma peça MORTA, com o passo exato de grade.
				var para := Esquadra.peca_local(p) + v
				var alvo_vivo := false
				for q in range(Esquadra.PECAS_NO_BLOCO):
					if Esquadra.peca_viva(b, q) and Esquadra.peca_local(q) == para:
						alvo_vivo = true
				if alvo_vivo:
					fora_da_vaga += 1
				espaco_min = minf(espaco_min, absf(v.z) > 0.001
					if not Esquadra.FOLGA_DA_PECA.z.is_equal_approx(0.0) else 0.0)
	capturas = capturas / 600
	_assert("E vaga: a peça captura o posto do vizinho morto e nada mais",
		capturas > 0.0 and fora_da_vaga == 0,
		("%d pecas do bloco 0 com vaga tomada, %d capturas apontando para posto vivo em 600 quadros" % [
			int(capturas), fora_da_vaga]))
```

Apague as três linhas do `espaco_min` e do ternário que as cerca antes de rodar: elas são o rascunho
de uma asserção que não mede nada, e o plano não aceita portão rascunho. A cota de espaço aberto é
provada no Step 3 por conta sobre constantes, não por esta sonda. É substituição, não acréscimo: o
arquivo tem de ficar com UMA definição de `_familia_vaga`, senão o parse cai em «function already
defined».

Ligue a família no `_initialize`, junto das anteriores:

```gdscript
	await _familia_vaga()
```

- [ ] **Step 2: Rodar e ler o vermelho**

Expected: `SONDA-PECA: ... quebras=1` com `0 pecas do bloco 0 com vaga tomada` — a lei de captura ainda
não existe, então a peça de p=0 persegue o próprio posto e nada captura.

- [ ] **Step 3: A lei**

Acrescente perto de `FOLGA_DA_PECA`:

```gdscript
## Histerese de vaga, em múltiplos do passo de casa do eixo: y cobra 1,3 × 1,6 = 2,08 u e z cobra
## 1,3 × 3,2 = 4,16 u. É a escala de peça do rodízio de fileiras, e o precedente está lido: a folga
## vertical real do rodízio saiu 1,023 u no pior dos 5 179 quadros em que a pista esteve em uso, contra
## os 2,533 u que a geometria sem deriva prometia. Quem abre a porta é a morte casa a casa.
const FATOR_DE_VAGA := 1.3
```

```gdscript
## Os postos que já têm dono no bloco: o de grade de cada peça viva, mais a vaga que ela tomou. No
## máximo seis entradas, comparação linear, sem hash e sem leitura de outro bloco.
static func postos_efetivos(bloco: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in range(PECAS_NO_BLOCO):
		if not peca_viva(bloco, p):
			continue
		var pc: Dictionary = bloco["pecas"][p]
		out.append(peca_local(p) + (pc["vaga"] as Vector3))
	return out


## Quanto de espaço existe, naquele eixo, do posto de quem move até o primeiro posto ainda vivo além da
## vaga. Em z é sempre `PASSO_BLOCO_Z` (com `CASAS_Z = 2` não existe camada além da vaga dentro do
## bloco — o próximo corpo vivo é de outro bloco, e a grade diz onde: 7,0 u). Em y é `2 × PASSO_CASA_Y`
## quando a camada do outro lado vive, e `PASSO_ESQUADRAO_Y` quando ela também morreu e o próximo posto
## é o do andar de cima. Os dois cortam a respectiva cota: 3,2 ≥ 2,08 e 7,0 ≥ 4,16.
static func _espaco_aberto(bloco: Dictionary, p: int, q: int, em_z: bool) -> float:
	if em_z:
		return PASSO_BLOCO_Z
	var camada := int(float(q) / float(CASAS_Z))
	var iz := q % CASAS_Z
	for c in [camada - 1, camada + 1]:
		if c < 0 or c >= CASAS_Y:
			continue
		var vizinho := c * CASAS_Z + iz
		if vizinho == p or not peca_viva(bloco, vizinho):
			continue
		return 2.0 * PASSO_CASA_Y
	return PASSO_ESQUADRAO_Y


## Captura para frente, só em vaga: o vizinho está morto de verdade (as quatro casas apagadas), o posto
## dele não é de peça viva nenhuma — nem como posto de grade, nem como vaga já tomada — e o espaço
## aberto vale `FATOR_DE_VAGA` × o passo do eixo. Não tem volta: casa morta não revive, a decisão é de
## índice e não de sorteio, e é ESTA lei (não a folga de meio passo) que dá ao bloco a liberdade que o
## commander pediu.
static func _vaga_para(bloco: Dictionary, p: int, ocupados: Array[Vector3]) -> Vector3:
	var proprio := peca_local(p)
	for q in vizinhos_locais_da_peca(p):
		if q < 0 or q >= PECAS_NO_BLOCO or peca_viva(bloco, q):
			continue
		var destino := peca_local(q)
		if destino in ocupados:
			continue
		var em_z := not is_zero_approx(destino.z - proprio.z)
		var cota := FATOR_DE_VAGA * (PASSO_CASA_Z if em_z else PASSO_CASA_Y)
		if _espaco_aberto(bloco, p, q, em_z) < cota:
			continue
		return destino - proprio
	return Vector3.ZERO
```

E dentro de `_passo_das_pecas` (Tarefa 4), o laço passa a abrir com o mapa de ocupação e a registrar a
captura no próprio mapa, para duas peças não tomarem o mesmo posto no mesmo quadro:

```gdscript
func _passo_das_pecas(bloco: Dictionary, delta: float) -> void:
	var ocupados := postos_efetivos(bloco)
	for p in range(PECAS_NO_BLOCO):
		var pc: Dictionary = bloco["pecas"][p]
		if not peca_viva(bloco, p):
			pc["desloc"] = Vector3.ZERO
			pc["vel"] = Vector3.ZERO
			continue
		if (pc["vaga"] as Vector3) == Vector3.ZERO:
			var tomada := _vaga_para(bloco, p, ocupados)
			if tomada != Vector3.ZERO:
				pc["vaga"] = tomada
				ocupados.append(peca_local(p) + tomada)
		var alvo: Vector3 = pc["vaga"]
		var voo := Voo.marchar(pc["desloc"] as Vector3, pc["vel"] as Vector3, 0.0, alvo, delta,
			MARCHA_DE_BLOCO, Voo.FICHA_BLOCO, 0.0)
		pc["vel"] = voo["vel"]
		pc["desloc"] = apertar_na_trela(voo["pos"] as Vector3, alvo)
```

- [ ] **Step 4: A família E escrita de verdade, sem rascunho**

Substitua o corpo de `_familia_vaga` pelo abaixo — é ele que fica na folha, e as três linhas do rascunho
do Step 1 somem:

```gdscript
func _familia_vaga() -> void:
	var e := Esquadra.new()
	e.montar([Vector3.ZERO], [Vector3(0.0, 0.0, -130.0)])
	e.pecas_livres = true
	var b: Dictionary = e.lista_de("aliado")[0]
	for c in Esquadra.casas_da_peca(2):
		b["casas"][c]["vida"] = 0.0
	Esquadra._recalcular_agregados(b)
	var donos := 0
	var fora_da_vaga := 0
	for f in range(600):
		e.passo(1.0 / 60.0, [Vector3.ZERO], [Vector3(0.0, 0.0, -130.0)])
	donos = 0
	for p in range(Esquadra.PECAS_NO_BLOCO):
		var v: Vector3 = b["pecas"][p]["vaga"]
		if v == Vector3.ZERO:
			continue
		donos += 1
		var para := Esquadra.peca_local(p) + v
		for q in range(Esquadra.PECAS_NO_BLOCO):
			if Esquadra.peca_viva(b, q) and Esquadra.peca_local(q) == para:
				fora_da_vaga += 1
	# O piso analítico das cotas, contado das constantes: os dois eixos têm de abrir porta, e a
	# aritmética é a que a sonda imprime, não a que o comentário promete.
	var cota_y := Esquadra.FATOR_DE_VAGA * Esquadra.PASSO_CASA_Y
	var cota_z := Esquadra.FATOR_DE_VAGA * Esquadra.PASSO_CASA_Z
	_assert("E cota: a grade abre espaço suficiente nos dois eixos para a captura existir",
		2.0 * Esquadra.PASSO_CASA_Y >= cota_y and Esquadra.PASSO_BLOCO_Z >= cota_z,
		("y: 3,2 u abertos contra %.2f de cota; z: %.1f u abertos contra %.2f" % [
			cota_y, Esquadra.PASSO_BLOCO_Z, cota_z]))
	_assert("E vaga: a peça captura o posto do vizinho morto e nunca um posto vivo",
		donos > 0 and fora_da_vaga == 0,
		("%d pecas do bloco 0 terminaram 600 quadros com vaga tomada, %d apontando para posto vivo" % [
			donos, fora_da_vaga]))
```

- [ ] **Step 5: Checagem, sonda e as três que cobram formação**

```bash
env APPDATA="D:\\Downloads\\tmp-userdata-iron" "$GODOT" --headless --path . --check-only --script res://esquadra.gd
for p in peca esquadra casas comando; do
  env APPDATA="D:\\Downloads\\tmp-userdata-iron" "$GODOT" --headless --path . --quit-after 1800 \
    -s res://tools/probes/$p.gd | tail -4
done
```
Expected: `peca` com `quebras=0` e `conferencias=11`; `esquadra`, `casas` e `comando` verdes. O censo de
conferências desta linha é o que a Tarefa 6 vai comparar — anote o número do log, não o deste plano.

- [ ] **Step 6: Bateria + janela, com o PNG relido**

Run: `bash /d/Downloads/tmp-userdata-iron/bateria.sh` e depois `massa_visivel` em janela.
Aqui é o primeiro ponto do plano em que a queixa do commander pode ser **vista**: um bloco com uma
fileira morta passa a fechar o vão com a vizinha. Se o PNG não mostrar isso, a captura não disparou —
volte ao `_espaco_aberto` e leia as cotas impressas, não afrouxe a cota.

- [ ] **Step 7: Commit**

```bash
git add esquadra.gd tools/probes/peca.gd
git status --short
git commit -m "feat(esquadra): lapidacao 4 tarefa 5 - a peca captura o posto do vizinho morto, com histerese de 1,3x"
```

---

### Task 6: A âncora vira estado

**Files:**
- Modify: `esquadra.gd:300-308` (estado novo), `:579-613` (`montar`), `:625-645` (`estacao`),
  `:912-916` (`passo`)
- Test: `tools/probes/peca.gd` famílias C-semente e F

**Interfaces:**
- Consumes: `_centro_de`, `recuo_hostil`, `_recuo_alvo`, `Voo.marchar`, `MARCHA_DE_BLOCO`,
  `CAMPO_DE_APROXIMACAO`, `FACHADA_DA_MURALHA`, `DISTANCIA_DE_CONTATO`, `ROD_NA_LINHA`.
- Produces: `estacao(lado)` devolvendo **estado**; `_estacao_derivada(lado)` devolvendo a fórmula
  antiga (a régua do teto hostil); `Esquadra._media_da_linha(lado)`; `_ancorar(delta)`.
  As nove chamadas a `estacao()` nas sondas antigas continuam válidas: valor igual na largada,
  divergente depois.

- [ ] **Step 1: O vermelho — família C-semente e família F (a frase do commander)**

```gdscript
## ── Família C (semente) e F (a frase do commander) ──
## A causa medida da queixa é esta: `estacao()` herdava de `centros()`, que é a média dos doze núcleos
## re-derivada a cada tick, e um núcleo arrastado 40 u movia a estação e a estação movia os 120 postos
## — inclusive os blocos a mais de 46 u do poço. O portão não é "a estação anda pouco": é ela andar
## ZERO no quadro em que o núcleo é arrancado do lugar.
func _familia_ancora() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	await _frames(3)
	var e: Esquadra = game.esquadra
	# C-semente: o quadro zero tem de ser o valor da fórmula antiga, byte a byte. A grade é simétrica em
	# torno da âncora, então a média dos postos É a âncora e o teto hostil coincide com ela.
	var semente_ok := true
	for lado in ["aliado", "hostil"]:
		if e.estacao(lado) != e._estacao_derivada(lado):
			semente_ok = false
	_assert("C semente: o quadro zero da estação é o quadro zero de hoje, byte a byte",
		semente_ok,
		("aliado %s / hostil %s" % [str(e.estacao("aliado")), str(e.estacao("hostil"))]))
	# Deixa a muralha assentar (os blocos chegam aos postos e a média converge) antes de arrancar.
	for f in range(600):
		game._process(1.0 / 60.0)
	var antes := e.estacao("aliado")
	var media_antes := e._media_da_linha("aliado")
	var nucleo: Node3D = game.fleet[0]["node"]
	var pos_velha: Vector3 = nucleo.global_position
	nucleo.global_position = Vector3(pos_velha.x + 40.0, pos_velha.y, pos_velha.z)
	game._process(1.0 / 60.0)
	var depois := e.estacao("aliado")
	var media_depois := e._media_da_linha("aliado")
	_assert("F frase do commander: arrastar um núcleo 40 u não move a estação no quadro",
		antes.distance_to(depois) == 0.0,
		("estacao andou %.4f u depois de um nucleo saltar 40,0 u em x" % antes.distance_to(depois)))
	_assert("F média: os blocos em custódia continuam colados na estação (ponto fixo da média)",
		media_depois.distance_to(depois) <= 0.33,
		("|média dos blocos - estação| = %.4f u no quadro depois do arranco" % [
			media_depois.distance_to(depois)]))
	_assert("F sem arrasto: a média dos blocos não seguiu o núcleo que saltou",
		media_antes.distance_to(media_depois) <= 0.01,
		("a média dos blocos andou %.4f u com um núcleo a 40,0 u" % media_antes.distance_to(media_depois)))
	game.queue_free()
```

Ligue no `_initialize`:

```gdscript
	await _familia_ancora()
```

- [ ] **Step 2: Rodar e ler o vermelho**

Expected: `Invalid get index '_estacao_derivada'`. Símbolos novos, código velho.

- [ ] **Step 3: O estado, o derivado e o semeado**

Junto de `_derivas` (`esquadra.gd:140`):

```gdscript
## A âncora da muralha, agora como ESTADO por lado. Antes desta folha `estacao()` era derivada dos doze
## núcleos a cada tick, e era isso que fazia a muralha inteira entrar no poço porque um único núcleo foi
## sugado: herança, não medida. Hoje a estação persegue a média dos próprios blocos em custódia, e um
## bloco que recebeu ordem do comandante sai dessa média — é a exclusão que fecha a conta da frase do
## commander. Semeada em `montar()` com o valor da fórmula antiga, e o quadro zero é byte-idêntico.
var _estacao := {"aliado": Vector3.ZERO, "hostil": Vector3.ZERO}
var _vel_estacao := {"aliado": Vector3.ZERO, "hostil": Vector3.ZERO}
```

Em `montar`, troque `var ancora := estacao(lado)` pela fórmula antiga e escreva a semente — a linha
`ancora` é dentro do laço de `lado`, e a semente tem de vir antes dela:

```gdscript
		ancora = _estacao[lado]
```

e, antes do `for lado in [...]`, as duas sementes:

```gdscript
	_estacao["aliado"] = centro_aliado
	_estacao["hostil"] = centro_hostil + Vector3(0.0, 0.0, recuo_hostil)
	_vel_estacao["aliado"] = Vector3.ZERO
	_vel_estacao["hostil"] = Vector3.ZERO
```

E abaixo de `estacao` (`esquadra.gd:629-634`), o par:

```gdscript
## A fórmula antiga: os núcleos, mais o recuo que a lei da largada manda. Continua existindo porque é a
## régua contra a qual a estação hostil tem teto — o avanço da muralha inimiga deixa de ser herança e
## passa a ser cota explícita, mas a cota é a mesma de hoje. E é a semente do quadro zero.
func _estacao_derivada(lado: String) -> Vector3:
	return centros(lado) + Vector3(0.0, 0.0, recuo_hostil if lado == "hostil" else 0.0)


## Ponto do tabuleiro ao qual a grade do lado está presa. Estado, não derivada: ver `_estacao`.
func estacao(lado: String) -> Vector3:
	return _estacao[lado]


## A média dos blocos do lado que ainda estão sob custódia da grade. Ficam de fora quem recebeu destino
## da ponte, quem está na pista do rodízio e quem passou da trela — é essa exclusão que faz a ordem do
## comandante não arrastar a muralha inteira.
func _media_da_linha(lado: String) -> Vector3:
	var soma := Vector3.ZERO
	var n := 0
	for b in lista_de(lado):
		if not bool(b["vivo"]) or bool(b["com_destino"]) \
				or int(b["rodizio_fase"]) > ROD_NA_LINHA:
			continue
		if (b["pos"] as Vector3).distance_to(_estacao[lado]) > CAMPO_DE_APROXIMACAO:
			continue
		soma += b["pos"]
		n += 1
	if n == 0:
		return _estacao[lado]
	return soma / float(n)


## Um passo de âncora por lado. `Voo.marchar` capped a `MARCHA_DE_BLOCO` com a ficha do bloco: o ponto
## fixo é estável por construção — a média dos blocos que perseguem a estação É a estação, e um ponto
## fixo de uma média não pode fugir de si mesmo. O hostil ganha o teto da fórmula antiga, o que preserva
## a travessia de 154,0 u para 40,0 u que a família 10 assina: se a média dos blocos inimigos tentar
## passar da cota de contato, a cota segura.
func _ancorar(delta: float) -> void:
	for lado in ["aliado", "hostil"]:
		var alvo := _media_da_linha(lado)
		if lado == "hostil":
			alvo.z = minf(alvo.z, _estacao_derivada("hostil").z)
		var voo := Voo.marchar(_estacao[lado], _vel_estacao[lado], 0.0, alvo, delta,
			MARCHA_DE_BLOCO, Voo.FICHA_BLOCO, 0.0)
		_estacao[lado] = voo["pos"]
		_vel_estacao[lado] = voo["vel"]
```

- [ ] **Step 4: Chamar no `passo`, antes dos blocos**

Logo depois de `recuo_hostil = _recuo_alvo()` (`esquadra.gd:915`):

```gdscript
	_ancorar(delta)
```

A ordem é a lei: a estação anda primeiro, os blocos perseguem a estação nova no mesmo quadro, e a
média do quadro seguinte já reflete o deslocamento. Inverter faz a muralha correr atrás do próprio
quadro anterior e abre oscilação que a família 10 leria como marchar mais devagar.

- [ ] **Step 5: Checagem, sonda nova e as nove chamadas a `estacao()` nas antigas**

```bash
env APPDATA="D:\\Downloads\\tmp-userdata-iron" "$GODOT" --headless --path . --check-only --script res://esquadra.gd
for p in peca esquadra comando casas batalha_real massa_visivel; do
  env APPDATA="D:\\Downloads\\tmp-userdata-iron" "$GODOT" --headless --path . --quit-after 1800 \
    -s res://tools/probes/$p.gd | tail -5
done
```
Expected: `peca` verde; `esquadra`/`comando`/`casas`/`batalha_real` verdes; `massa_visivel` em janela.
A família 10 de `esquadra.gd` (aproximação hostil / travessia) é o portão que o design declarou como
risco: **se ela reprovar, a muralha parou de marchar e o conserto é a cota hostil, não a tolerância da
família 10.** Leia o número de travessia impresso e escreva-o na Tarefa 10.

- [ ] **Step 6: Commit**

```bash
git add esquadra.gd tools/probes/peca.gd
git status --short
git commit -m "feat(esquadra): lapidacao 4 tarefa 6 - a estacao vira estado perseguido, nao heranca dos nucleos"
```

### Task 7: O poço come a peça

**Files:**
- Modify: `esquadra.gd` (uma função nova, depois de `_golpe_na_casa`, `:1364-1386`), `main.gd:3672-3687`
  (`_aplicar_cenario`), `main.gd:3690-3703` (`_puxar_para_o_poco`)
- Test: `tools/probes/peca.gd` família G; regressão em `tools/probes/casas.gd`, `cenarios.gd`,
  `tripulacao.gd`

**Interfaces:**
- Consumes: `pecas_na_cena()` e `empurrar_peca` (Tarefa 2), `peca_viva` e `casas_da_peca` (Tarefa 1),
  `POCO_POS`/`POCO_ALCANCE`/`POCO_HORIZONTE`/`POCO_PUXO` (`main.gd:222-225`, **inalterados**),
  `esquadra.salva_numero` (`esquadra.gd:267`).
- Produces: `Esquadra.abater_peca(alvo, p, salva) -> bool` — devolve `true` quando o **bloco** afundou
  com o bocado, exatamente como `_golpe_na_casa`; `_puxar_para_o_poco(delta, pecas)`; o instantâneo
  `_aplicar_cenario` chamado uma vez por tique, que a Tarefa 8 passa a compartilhar com as outras três
  leis.

- [ ] **Step 1: O vermelho — família G**

```gdscript
## ── Família G: o poço come a peça ──
## A queixa medida é «quando são sugados, todas as naves do bloco são atingidas, mesmo as fora do raio».
## A régua é a bite, não o bloco: peça dentro do horizonte perde AS QUATRO CASAS DELAS e nenhuma outra;
## peça a mais de POCO_ALCANCE não sente vetor nenhum. `pecas_livres` fica FALSA de propósito — com o
## voo próprio desligado, o único que escreve `desloc` é o cenário, e o que a sonda mede é a lei.
func _familia_devoramento() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	await _frames(3)
	game.world_timer.stop()
	var e: Esquadra = game.esquadra
	e.pecas_livres = false
	var b: Dictionary = e.lista_de("aliado")[0]
	b["rumo"] = 0.0
	# Boca do poço em +z, a 8,0 u do centro: as peças de iz=1 ficam a 6,4 u de z (sqrt(1,6²+6,4²) = 6,60
	# para as camadas de fora, 6,40 para a do meio) — todas dentro do horizonte de 9,0. As de iz=0 ficam a
	# 9,6 u de z (9,73 na camada do meio) — fora do horizonte, dentro do alcance de 46,0. Um bloco, três
	# bocados, três trações.
	b["pos"] = game.POCO_POS + Vector3(0.0, 0.0, 8.0)
	var longe: Dictionary = e.lista_de("aliado")[1]
	longe["rumo"] = 0.0
	longe["pos"] = game.POCO_POS + Vector3(0.0, 0.0, 52.0)
	game._puxar_para_o_poco(1.0 / 60.0, e.pecas_na_cena())
	var comidas := 0
	var inteiras := 0
	for p in range(Esquadra.PECAS_NO_BLOCO):
		if Esquadra.peca_viva(b, p):
			inteiras += 1
		else:
			comidas += 1
			for c in Esquadra.casas_da_peca(p):
				_assert("G bite: as quatro casas mortas são exatamente as da peça comida",
					float(b["casas"][c]["vida"]) <= 0.0,
					("peca %d, casa %d com vida %.4f" % [p, c, float(b["casas"][c]["vida"])]))
	_assert("G bite: o poço come peça, não bloco — tres comidas, tres inteiras num bloco de seis",
		comidas == 3 and inteiras == 3,
		("comidas=%d inteiras=%d vivas=%d/24" % [comidas, inteiras, Esquadra.casas_vivas(b)]))
	_assert("G ledger: o bloco continua vivo com as outras vinte casas",
		bool(b["vivo"]) and Esquadra.casas_vivas(b) == 12,
		("navios=%.6f escudo=%.6f casas_vivas=%d" % [float(b["navios"]), float(b["escudo"]),
			Esquadra.casas_vivas(b)]))
	# A tração das que ficaram fora do horizonte, e o zero das que ficaram fora do alcance.
	var tracao := 0.0
	for p in range(Esquadra.PECAS_NO_BLOCO):
		var d: Vector3 = b["pecas"][p]["desloc"]
		tracao = maxf(tracao, d.length())
	_assert("G trela: quem está no alcance sente o puxo e anda dentro da trela",
		tracao > 0.0 and tracao <= Esquadra.FOLGA_DA_PECA.length(),
		("maior excursao = %.4f u, trela = %.4f u" % [tracao, Esquadra.FOLGA_DA_PECA.length()]))
	var longe_parado := true
	for p in range(Esquadra.PECAS_NO_BLOCO):
		if (longe["pecas"][p]["desloc"] as Vector3) != Vector3.ZERO:
			longe_parado = false
	_assert("G alcance: a 52 u do centro, nenhum vetor em nenhuma peça (a queixa, ao contrário)",
		longe_parado and Esquadra.casas_vivas(longe) == Esquadra.CASAS,
		("bloco a %.1f u: pecas mexidas = %s" % [
			(longe["pos"] as Vector3).distance_to(game.POCO_POS), str(not longe_parado)]))
	# G ledger (segunda metade) — o ledger da salva: `lancados` conta PARES de bloco, não casas, então
	# comer quatro casas de um
	# atirador não tira o atirador da salva. Dois `Esquadra` na mesma largada, mesma semente de monta, um
	# mordido: a cauda dos dois tem de fechar no mesmo número.
	var a := Esquadra.new()
	a.montar([Vector3.ZERO], [Vector3(0.0, 0.0, -130.0)])
	var bb := Esquadra.new()
	bb.montar([Vector3.ZERO], [Vector3(0.0, 0.0, -130.0)])
	a.troca_salva()
	bb.troca_salva()
	bb.abater_peca(bb.lista_de("hostil")[0], 2, float(bb.salva_numero))
	var sa: Dictionary = a.troca_salva()
	var sb: Dictionary = bb.troca_salva()
	_assert("G ledger: comer uma peça não mexe em `lancados` — par é par, casa é mordida",
		int(sa["lancados"]) == int(sb["lancados"]) and int(sa["lancados"]) > 0,
		("lancados inteiro=%d mordido=%d" % [int(sa["lancados"]), int(sb["lancados"])]))
	game.queue_free()
```

Ligue no `_initialize`:

```gdscript
	await _familia_devoramento()
```

- [ ] **Step 2: Rodar e ler o vermelho**

```bash
cd /d/Downloads/IronStarsFleetCommand
env APPDATA="D:\\Downloads\\tmp-userdata-iron" "$GODOT" --headless --path . --quit-after 1800 \
  -s res://tools/probes/peca.gd 2>&1 | tail -12
```
Expected: `SCRIPT ERROR: Invalid call. Nonexistent function 'abater_peca' in base 'GDScript'` **e**, na
linha anterior, `Too many arguments for "_puxar_para_o_poco()" call. Expected at most 1 but received 2.`
Os dois vermelhos são a folha: a porta não existe e a lei ainda não sabe o que é peça.

- [ ] **Step 3: `abater_peca`, pela porta por que um tiro mata**

Depois de `_golpe_na_casa` (`esquadra.gd:1386`):

```gdscript
## O poço come a peça. Escreve exatamente os quatro campos que um tiro escreve — `vida`, `placa`,
## `morta_em`, `a_noticiar` — e devolve o mesmo veredito de `_golpe_na_casa`: `true` quando o BLOCO
## afundou com o lance. Não há ledger novo nem dano gradual: quem cruzou o horizonte já está perdido
## (a lei de `_devorado_pelo_poco`), e adiar isso em pontos de vida faria a morte depender de quantos
## quadros a pintura demora. `placa` vai a zero junto com `vida`: ao contrário da capitânia, cujo
## `escudo` é cadastro de casco nomeado, o agregado do bloco É a soma das placas, e deixar chapa viva
## em casa morta faria o `escudo` do bloco mentir para a família 12 de `escudo.gd`.
func abater_peca(alvo: Dictionary, p: int, salva: float) -> bool:
	if not bool(alvo["vivo"]):
		return false
	if not peca_viva(alvo, p):
		return false
	for c in casas_da_peca(p):
		var casa: Dictionary = alvo["casas"][c]
		casa["vida"] = 0.0
		casa["placa"] = 0.0
		casa["morta_em"] = salva
		casa["a_noticiar"] = true
	_recalcular_agregados(alvo)
	if float(alvo["navios"]) > 0.0:
		return false
	alvo["vivo"] = false
	if String(alvo["lado"]) == "aliado":
		perdas_aliadas += 1
	else:
		perdas_hostis += 1
	return true
```

- [ ] **Step 4: O instantâneo por tique, e o laço da peça no poço**

`_aplicar_cenario` (`main.gd:3672`) ganha o instantâneo no topo. Nesta tarefa só o poço o consome; as
outras três leis entram na Tarefa 8, e é por isso que a guarda do laço é a lista inteira e não um
`if` por lei:

```gdscript
func _aplicar_cenario(delta: float) -> void:
	# Um instantâneo por tique, compartilhado pelas leis que medem a muralha. Custo contado, não
	# estimado: 1 440 peças × quatro leis ≈ 25 mil operações vetoriais por tique — nada — e o que
	# pesa é refazer o dicionário lei por lei. Dentro do mesmo tique o empurrão acumulado está limitado
	# pela trela (1,2 / 0,6 / 0,9 u), então a posição lida no topo do quadro vale para todas.
	var pecas: Array[Dictionary] = []
	if poco_ativo:
		pecas = esquadra.pecas_na_cena()
		_puxar_para_o_poco(delta, pecas)
		_lentificar_quadro()
```

(as três linhas seguintes de `estrela_ativa`, `planeta_ativa`, `rochas` ficam como estão; o
`_chocar_com_barreiras` da última muda de arity na Tarefa 8, junto com as outras duas.)

Troque a primeira linha de `_puxar_para_o_poco` (`main.gd:3690`) pela versão com o segundo parâmetro:

```gdscript
func _puxar_para_o_poco(delta: float, pecas: Array[Dictionary]) -> void:
```

O laço de corpos que já está lá embaixo (`_collision_bodies()`: alcance, horizonte,
`_devorado_pelo_poco`, peso linear) **não se toca**. Acrescente ao fim da função, depois dele, este
bloco:

```gdscript
	# A muralha entra pela PEÇA, não pelo bloco, e é esta linha a resposta medida à queixa de que
	# «todas as naves do bloco são atingidas, mesmo as fora do raio». POCO_ALCANCE 46,0, POCO_HORIZONTE
	# 9,0 e POCO_PUXO 11,0 não se mexem: o que muda é de quem é a distância lida.
	var comidas := 0
	var afundou := 0
	for par in pecas:
		var bloco: Dictionary = par["bloco"]
		var p := int(par["indice"])
		# Guarda que segura o cadáver: a lista é o instantâneo do topo do quadro, e a peça comida neste
		# mesmo quadro continuaria nela. Sem esta linha, um tique engoleria a peça duas vezes.
		if not Esquadra.peca_viva(bloco, p):
			continue
		var vetor := POCO_POS - (par["pos"] as Vector3)
		var distancia := vetor.length()
		if distancia > POCO_ALCANCE:
			continue
		if distancia <= POCO_HORIZONTE:
			# Dentro do horizonte não existe "para fora": a conta é a mesma do corpo tripulado, e o
			# `vetor / distancia` abaixo só é lido depois desta guarda, então divisão por zero não é
			# caminho nem com a peça colada no centro.
			comidas += 1
			# `abater_peca` devolve «o BLOCO afundou com este bocado» — o mesmo veredito de
			# `_golpe_na_casa`. Não há segundo caso a contar: peça comida em bloco ainda vivo devolve
			# falso e não entra em `afundou`.
			if esquadra.abater_peca(bloco, p, float(esquadra.salva_numero)):
				afundou += 1
			continue
		var peso := 1.0 - distancia / POCO_ALCANCE
		esquadra.empurrar_peca(bloco, p, vetor / distancia * POCO_PUXO * peso * delta)
	if comidas > 0:
		# Um efeito por quadro de bocado, não um por peça: `_devorado_pelo_poco` já chama o mesmo som
		# para cada casco tripulado, e doze peças na borda fariam o áudio virar chiado.
		audio.efeito("EXPLOSAO")
		if is_instance_valid(report_label):
			report_label.text = "POÇO // %d peça(s) da muralha cruzaram o horizonte: quatro cascos por " \
				"vez, nunca a fileira inteira.%s" % [comidas,
				(" %d bloco(s) afundaram com o bocado." % afundou) if afundou > 0 else ""]
```

- [ ] **Step 5: Os oito sítios velhos que chamam o poço**

Medido nesta folha, contra `HEAD`: `_puxar_para_o_poco` é chamada de fora de `main.gd` em **8** lugares
— 7 em `tools/probes/cenarios.gd`, 1 em `tools/probes/tripulacao.gd`. Refaça a conta antes de editar,
porque linha de sonda deriva com qualquer commit no arquivo:

```bash
grep -rn "_puxar_para_o_poco(" --include=*.gd . | grep -v "^./main.gd"
```

Cada sítio ganha o segundo argumento **vazio e declarado**:

```gdscript
## A lei é medida nos doze cascos. A muralha entra nesta conta em `peca.gd`, famílias G e H, onde o
## censo é o objeto da asserção; aqui a lista é vazia de propósito, para que o número antigo continue
## sendo o número antigo.
var SEM_MURALHA: Array[Dictionary] = []
```

uma vez por arquivo (nível de classe, antes da primeira `func`), e `game._puxar_para_o_poco(PASSO,
SEM_MURALHA)` nos sítios — com `c.` no sítio que chama sobre o segundo jogo montado
(`tools/probes/cenarios.gd`, o da capitânia). O tipo tem de ser escrito: `[]` sozinho é `Array` e o
motor recusa atribuí-lo a `Array[Dictionary]`.

- [ ] **Step 6: Checagem, sonda e a regressão do ledger**

```bash
cd /d/Downloads/IronStarsFleetCommand
env APPDATA="D:\\Downloads\\tmp-userdata-iron" "$GODOT" --headless --path . --check-only --script res://esquadra.gd
env APPDATA="D:\\Downloads\\tmp-userdata-iron" "$GODOT" --headless --path . --check-only --script res://main.gd
for p in peca casas cenarios tripulacao esquadra; do
  env APPDATA="D:\\Downloads\\tmp-userdata-iron" "$GODOT" --headless --path . --quit-after 1800 \
    -s res://tools/probes/$p.gd 2>&1 | tail -4
done
```
Expected: `peca` verde com as famílias A-H-1 contadas; `casas.gd` **imprimindo a linha da família A** —
`escala 35 golpes de bloco = 840 lances de casa` — que é a cláusula «35 ≡ 840 ainda de pé» da tabela do
design, lida do veredito da sonda e não jurada; `cenarios.gd` e `tripulacao.gd` verdes com o mesmo
número de conferências de antes (a lista vazia não move um número); `esquadra.gd` verde.

- [ ] **Step 7: Commit**

```bash
git add esquadra.gd main.gd tools/probes/peca.gd tools/probes/cenarios.gd tools/probes/tripulacao.gd
git status --short
git commit -m "feat(cenario): lapidacao 4 tarefa 7 - o poco come a peca pela porta do tiro, e a muralha a 52 u nao sente vetor"
```

### Task 8: Vento, coroa e pedras medem a peça

**Files:**
- Modify: `esquadra.gd` (uma função nova, depois de `abater_peca`, criada na Tarefa 7),
  `main.gd:3672-3687` (`_aplicar_cenario`, que a Tarefa 7 já abriu), `main.gd:3714-3729`
  (`_empurrar_no_vento`), `main.gd:3843-3867` (`_queimar_na_corona`), `main.gd:3876-3878`
  (`_chocar_com_barreiras`), `main.gd:3884-3922` (`_cobrar_contato`)
- Test: `tools/probes/peca.gd` família H; regressão em `tools/probes/estrela.gd`, `cenarios.gd`,
  `sistema.gd`, `tripulacao.gd`, `escudo.gd`

**Interfaces:**
- Consumes: o instantâneo `esquadra.pecas_na_cena()` chamado **uma vez por tique** (Tarefa 2), com as
  chaves `pos`/`vel`/`raio`/`bloco`/`indice` (Tarefa 2); `Esquadra.peca_viva`, `casas_da_peca`,
  `PECAS_NO_BLOCO`, `RAIO_DA_PECA`; `esquadra.empurrar_peca` (Tarefa 2), `esquadra.abater_peca`
  (Tarefa 7); as constantes das leis, todas **inalteradas**: `ESTRELA_POS` `(0, 24, -74)` com
  `ESTRELA_VENTO_ALCANCE` 96,0 e `ESTRELA_VENTO_ACEL` 3,0 (`main.gd:262,269,270`),
  `ESTRELA_CORONA_RAIO` 30,0 e `ESTRELA_QUEIMA_POR_SEGUNDO` 6,0 (`main.gd:265,266`),
  `RAM_SPEED` 3,0 / `RAM_DAMAGE` 1,9 / `RAM_MAX_DAMAGE` 18,0 / `RAM_WINDOW` 1,5 (`main.gd:154-159`),
  `ram_windows` (`main.gd:515`), `rochas` / `astros` / `battle_clock`.
- Produces: `Esquadra.ferir_peca(alvo, p, dano) -> bool` — drena `vida` repartido pelas casas vivas da
  peça e **não morde `placa`**; `_empurrar_no_vento(delta, pecas)`, `_queimar_na_corona(delta, pecas)`,
  `_chocar_com_barreiras(pecas)`, `_cobrar_contato(lista, prefixo, pecas)`; a chave de abalroamento por
  peça, montada a partir de `Esquadra.id_peca(bloco, p) -> int` =
  `int(bloco["id"]) * PECAS_NO_BLOCO + p` (Tarefa 8, Step 1), prefixada pela lei.

- [ ] **Step 1: Por que a chave mora em `esquadra.gd`**

A janela de abalroamento é estado da batalha (`ram_windows` vive em `main.gd`), mas a *identidade* que
entra na chave é da esquadra: `bloco["id"]` e `p`. Se `main.gd` montar a chave sozinho, qualquer lei
futura tem de saber que `PECAS_NO_BLOCO` é 6 e que o `id` do bloco é denso por lado. Escreva em
`esquadra.gd`, depois de `ferir_peca`:

```gdscript
## A identidade de uma peça no espaço de chaves de abalroamento. O `node.get_instance_id()` do corpo
## tripulado não existe aqui — peça não é nó — e a coordenada mudaria de nome a cada quadro, que é o
## "moedor" que o comentário de `_cobrar_contato` já evita. Uma chave por (bloco, peça) é a única forma
## de seis peças pagarem janelas próprias.
static func id_peca(bloco: Dictionary, p: int) -> int:
	return int(bloco["id"]) * PECAS_NO_BLOCO + p
```

- [ ] **Step 2: O vermelho — família H, o censo das leis**

Acrescente os dois helpers de leitura e a família em `tools/probes/peca.gd`:

```gdscript
## A peça de um bloco no instantâneo da cena, ou `{}` se ela não está na cena.
func _par_de(pecas: Array[Dictionary], bloco: Dictionary, p: int) -> Dictionary:
	for par in pecas:
		if par["bloco"] == bloco and int(par["indice"]) == p:
			return par
	return {}


## Desliga o voo próprio das peças do bloco. As famílias G e H medem a LEI de cenário, e para isso o
## único que pode escrever `desloc` é a lei sob teste. Pré-condição declarada no criador do estado,
## que aqui é a própria sonda.
func _zerar_desloc(bloco: Dictionary) -> void:
	for pc in bloco["pecas"]:
		pc["desloc"] = Vector3.ZERO
		pc["vel"] = Vector3.ZERO


## A soma de `vida` das quatro casas de uma peça. É a régua das mordidas: a lei tem de tirar dela o
## preço de UMA peça, nunca de um bloco.
func _vida_da_peca(bloco: Dictionary, p: int) -> float:
	var soma := 0.0
	for c in Esquadra.casas_da_peca(p):
		soma += float(bloco["casas"][c]["vida"])
	return soma


## ── Família H: as leis medem peça, uma a uma, e param no raio ──
## A muralha ainda é, para o cenário, um corpo único de 24 casas. A régua desta família é dupla:
## (i) dentro do raio de cada lei a mordida tem o tamanho de UMA peça (quatro casas), nunca do bloco;
## (ii) fora do raio, vetor zero e vida intacta. A geometria é determinada: `RAIO_DA_PECA` = 5,256 u e
## os centros das peças estão a `peca_local(p)`, com `y_local ∈ {-1,6 / 0 / +1,6}` e
## `z_local ∈ {-1,6 / +1,6}` — é essa meia-fileira que permite pôr uma peça dentro e outra fora do
## mesmo raio com o bloco atravessado na borda.
func _familia_censo_leis() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	await _frames(3)
	game.world_timer.stop()
	var e: Esquadra = game.esquadra
	e.pecas_livres = false

	# ── H1: o vento empurra peça por peça, e a 140 u não empurra nada ──
	var perto: Dictionary = e.lista_de("aliado")[0]
	perto["rumo"] = 0.0
	perto["pos"] = game.ESTRELA_POS + Vector3(0.0, 0.0, 60.0)
	_zerar_desloc(perto)
	var longe: Dictionary = e.lista_de("aliado")[1]
	longe["rumo"] = 0.0
	longe["pos"] = game.ESTRELA_POS + Vector3(0.0, 0.0, 140.0)
	_zerar_desloc(longe)
	game._empurrar_no_vento(1.0 / 60.0, e.pecas_na_cena())
	var varridas := 0
	var para_fora := 0
	for p in range(Esquadra.PECAS_NO_BLOCO):
		var d: Vector3 = perto["pecas"][p]["desloc"]
		if d != Vector3.ZERO:
			varridas += 1
		# Toda peça a 60,0 u do centro está dentro dos 96,0 u de alcance, e o empurrão é radial para
		# fora: o produto interno com o raio tem de ser positivo.
		var par := _par_de(e.pecas_na_cena(), perto, p)
		if d.dot((par["pos"] as Vector3) - game.ESTRELA_POS) > 0.0:
			para_fora += 1
	_assert("H vento: as seis peças do bloco a 60 u andam, todas para fora",
		varridas == Esquadra.PECAS_NO_BLOCO and para_fora == Esquadra.PECAS_NO_BLOCO,
		"varridas=%d para_fora=%d de %d" % [varridas, para_fora, Esquadra.PECAS_NO_BLOCO])
	var longe_mexeu := false
	for p in range(Esquadra.PECAS_NO_BLOCO):
		if (longe["pecas"][p]["desloc"] as Vector3) != Vector3.ZERO:
			longe_mexeu = true
	_assert("H vento: a 140 u, além dos 96,0 u, vetor nenhum em peça nenhuma",
		not longe_mexeu,
		"bloco a %.1f u de ESTRELA_POS com desloc não zero" \
			% ((longe["pos"] as Vector3).distance_to(game.ESTRELA_POS)))

	# ── H2: a coroa cozinha quatro casas, não vinte e quatro, e não toca na chapa ──
	# Bloco EXATAMENTE a 30,0 u da estrela, no eixo z, com o centro do lado de +z. As peças de
	# `z_local = -1,6` ficam a 28,4 u (dentro dos 30,0 u) e as de `z_local = +1,6` a 31,6 u (fora). A
	# diferença de y (±1,6 u) dobra a distância em no máximo 0,045 u e não move peça nenhuma de lado:
	# o censo é 3 dentro / 3 fora, e é esse número que a asserção cobra. Se a leitura divergir, a
	# geometria de `peca_local` é que mudou, não a lei.
	var beira: Dictionary = e.lista_de("aliado")[2]
	beira["rumo"] = 0.0
	beira["pos"] = game.ESTRELA_POS + Vector3(0.0, 0.0, 30.0)
	_zerar_desloc(beira)
	var forada: Dictionary = e.lista_de("aliado")[3]
	forada["rumo"] = 0.0
	forada["pos"] = game.ESTRELA_POS + Vector3(0.0, 0.0, 40.0)
	_zerar_desloc(forada)
	var vidas_antes: Array[float] = []
	for p in range(Esquadra.PECAS_NO_BLOCO):
		vidas_antes.append(_vida_da_peca(beira, p))
	var placa_antes := float(beira["escudo"])
	var instantaneo := e.pecas_na_cena()
	game._queimar_na_corona(1.0 / 60.0, instantaneo)
	var dentro := 0
	var fora := 0
	for p in range(Esquadra.PECAS_NO_BLOCO):
		var par := _par_de(instantaneo, beira, p)
		var no_raio: bool = (par["pos"] as Vector3).distance_to(game.ESTRELA_POS) \
			<= game.ESTRELA_CORONA_RAIO
		var perda := vidas_antes[p] - _vida_da_peca(beira, p)
		if no_raio:
			dentro += 1
			# ESTRELA_QUEIMA_POR_SEGUNDO 6,0 × 1/60 s = 0,1 de casco por peça, repartido pelas quatro
			# casas vivas dela (0,025 por casa). A mesma conta do casco tripulado, na escala da peça.
			_assert("H coroa: dentro dos 30,0 u a peça perde 0,100 de casco e só ela",
				absf(perda - 0.1) < 1e-4, "peca %d perdeu %.6f" % [p, perda])
		else:
			fora += 1
			_assert("H coroa: fora dos 30,0 u a peça não cozinha", perda == 0.0,
				"peca %d perdeu %.6f a %.2f u" % [p, perda,
					(par["pos"] as Vector3).distance_to(game.ESTRELA_POS)])
	_assert("H coroa: a mordida é por peça — o censo da beira é 3 dentro / 3 fora, nunca o bloco inteiro",
		dentro == 3 and fora == 3, "dentro=%d fora=%d" % [dentro, fora])
	_assert("H coroa: queima não é projétil — a chapa sai da conta intacta (a cláusula de `escudo.gd`)",
		absf(float(beira["escudo"]) - placa_antes) < 1e-6,
		"placa %.6f -> %.6f" % [placa_antes, float(beira["escudo"])])
	var forada_ok := Esquadra.casas_vivas(forada) == Esquadra.CASAS
	for p in range(Esquadra.PECAS_NO_BLOCO):
		if (forada["pecas"][p]["desloc"] as Vector3) != Vector3.ZERO:
			forada_ok = false
	_assert("H coroa: o bloco a 40,0 u não perde casa nem anda", forada_ok,
		"casas vivas %d/%d depois da coroa" % [Esquadra.casas_vivas(forada), Esquadra.CASAS])

	# ── H3: a pedra cobra peça por peça, uma fatura por janela, e a chave é da peça ──
	if game.rochas.is_empty():
		game._montar_cinturao()
	var pedra: Dictionary = game.rochas[0]
	var alvo: Dictionary = e.lista_de("aliado")[4]
	alvo["rumo"] = 0.0
	alvo["pos"] = Vector3(0.0, 400.0, 0.0)   # fora do cinturão inteiro: só a pedra que eu mover toca
	alvo["vel"] = Vector3(0.0, -6.0, 0.0)    # fecha em -y a 6,0 u/s: aproximacao 6,0 > RAM_SPEED 3,0
	_zerar_desloc(alvo)
	pedra["vel"] = Vector3.ZERO
	# Pedra embaixo da peça 0, com 0,25 u de sobreposição (`soma - 0,25` = 8,206 u de centro a centro).
	# A peça 0 é a camada de baixo e a meia-fileira de trás (`y_local = -1,6`, `z_local = -1,6`). As
	# vizinhas ficam todas fora dos 8,456 u de contato: a da mesma camada à frente dela, a 3,2 u em z,
	# está a sqrt(8,206² + 3,2²) = 8,807 u; as da camada de cima, a +1,6 u em y, estão a 9,806 u.
	# Censo esperado: UMA peça paga, e é a 0.
	var soma := Esquadra.RAIO_DA_PECA + float(pedra["raio"])
	var par0 := _par_de(e.pecas_na_cena(), alvo, 0)
	pedra["pos"] = (par0["pos"] as Vector3) - Vector3(0.0, soma - 0.25, 0.0)
	game.battle_clock = 10.0
	var pagantes_antes: Array[float] = []
	for p in range(Esquadra.PECAS_NO_BLOCO):
		pagantes_antes.append(_vida_da_peca(alvo, p))
	var chaves_antes := game.ram_windows.size()
	var navios_antes := float(alvo["navios"])
	var cena := e.pecas_na_cena()
	game._chocar_com_barreiras(cena)
	var pagadoras: Array[int] = []
	for p in range(Esquadra.PECAS_NO_BLOCO):
		var perda := pagantes_antes[p] - _vida_da_peca(alvo, p)
		if perda > 0.0001:
			pagadoras.append(p)
		# clampf((6,0 - 3,0) × 1,9, 1,0, 18,0) = 5,7 de casco, e a peça tem quatro casas vivas:
		# 5,7 repartidos, não 5,7 por casa.
		if p == 0:
			_assert("H pedra: a fatura é o preço do abalroamento na escala da peça (5,700)",
				absf(perda - 5.7) < 1e-3, "peca 0 perdeu %.6f" % perda)
	_assert("H pedra: paga exatamente a peça encostada — as outras cinco ficam intactas",
		pagadoras == [0], "pagadoras = %s" % str(pagadoras))
	_assert("H pedra: uma fatura por janela — a segunda chamada no mesmo tique não cobra de novo",
		game.ram_windows.size() == chaves_antes + 1,
		"chaves %d -> %d" % [chaves_antes, game.ram_windows.size()])
	game._chocar_com_barreiras(cena)
	_assert("H pedra: o mesmo tique não reabre a janela (o cinto é parede, não moedor)",
		absf(float(alvo["navios"]) - (navios_antes - 5.7)) < 1e-3,
		"navios %.6f esperado %.6f" % [float(alvo["navios"]), navios_antes - 5.7])
	game.battle_clock = 12.0
	game._chocar_com_barreiras(e.pecas_na_cena())
	_assert("H pedra: passou a janela de 1,5 s, a mesma pedra cobra de novo",
		absf(float(alvo["navios"]) - (navios_antes - 11.4)) < 1e-2,
		"navios %.6f esperado ~%.6f" % [float(alvo["navios"]), navios_antes - 11.4])
	# H4 — a chave é da PEÇA, não do bloco: duas peças encostadas na mesma pedra no mesmo tique pagam
	# as duas. Se a chave fosse só `bloco["id"]`, a segunda acharia a janela já aberta e sairia ilesa.
	var dois: Dictionary = e.lista_de("aliado")[5]
	dois["rumo"] = 0.0
	dois["pos"] = Vector3(0.0, 500.0, 0.0)
	dois["vel"] = Vector3(0.0, -6.0, 0.0)
	_zerar_desloc(dois)
	game.battle_clock = 20.0
	var cena_dois := e.pecas_na_cena()
	var p0 := _par_de(cena_dois, dois, 0)
	var p1 := _par_de(cena_dois, dois, 1)
	var antes_dois := [_vida_da_peca(dois, 0), _vida_da_peca(dois, 1)]
	# Pré-condição da conta abaixo, lida da cena e não jurada: as duas peças são da mesma camada e
	# diferem só em z, exatamente `PASSO_CASA_Z / 2` de distância uma da outra.
	_assert("H chave: as duas peças sob teste são da mesma camada, separadas só em z",
		absf((p0["pos"] as Vector3).y - (p1["pos"] as Vector3).y) < 1e-6
			and absf((p0["pos"] as Vector3).distance_to(p1["pos"] as Vector3) - 3.2) < 1e-3,
		"p0 %s // p1 %s" % [str(p0["pos"]), str(p1["pos"])])
	# Pedra a 7,0 u abaixo da peça 0 e na meia-altura entre as duas peças da mesma camada (elas
	# diferem só em z: ±1,6 u). Fica a sqrt(7,0² + 1,6²) = 7,181 u de cada uma — dentro dos 8,456 u de
	# contato — e com a normal quase toda em -y, que é o que faz `aproximacao` dar 5,849 u/s nas duas
	# em vez de zero. As peças das outras camadas ficam a 8,748 u e 10,2 u: não pagam.
	pedra["pos"] = (p0["pos"] as Vector3) + Vector3(0.0, -7.0, 1.6)
	game._chocar_com_barreiras(cena_dois)
	_assert("H chave: duas peças na mesma pedra pagam duas faturas — a janela é por peça",
		before_after_dano(antes_dois, dois) == 2,
		"pagaram %d de 2 (p0 -%.4f, p1 -%.4f)" % [
			before_after_dano(antes_dois, dois),
			antes_dois[0] - _vida_da_peca(dois, 0), antes_dois[1] - _vida_da_peca(dois, 1)])
	game.queue_free()
```

E o contador que a asserção H4 usa, no mesmo arquivo:

```gdscript
## Quantas das duas peças perderam vida. Existe só para a asserção da chave ler `2` e não uma
## comparação de `Array[int]` construída no meio do laço.
func before_after_dano(antes: Array[float], bloco: Dictionary) -> int:
	var n := 0
	for p in range(antes.size()):
		if antes[p] - _vida_da_peca(bloco, p) > 0.0001:
			n += 1
	return n
```

Ligue no `_initialize`, depois da família G:

```gdscript
	await _familia_censo_leis()
```

- [ ] **Step 3: Rodar e ler o vermelho**

```bash
cd /d/Downloads/IronStarsFleetCommand
env APPDATA="D:\\Downloads\\tmp-userdata-iron" "$GODOT" --headless --path . --quit-after 1800 \
  -s res://tools/probes/peca.gd 2>&1 | tail -14
```
Expected: primeiro o parse — `Too many arguments for "_empurrar_no_vento()" call. Expected at most 1
but received 2.` Depois de aberta a arity, o runtime ainda deve acusar o censo:
`H pedra: paga exatamente a peça encostada — pagadoras = []`, porque sem a porta de peça a muralha não
sente pedra nenhuma; e `Invalid call. Nonexistent function 'ferir_peca'` na coroa. Os três vermelhos
são a folha.

- [ ] **Step 4: `ferir_peca` — a porta que não morde chapa**

Depois de `abater_peca` (Tarefa 7), em `esquadra.gd`:

```gdscript
## A lei de cenário fere a peça pelo casco, nunca pela chapa. É a mesma semântica já assinada em
## `tools/probes/escudo.gd:490` («abalroamento não paga casca») e `:496` («a coroa cozinha o casco pela
## porta velha: queima não é projétil»): só o tiro passa pelo `Escudo`, e a muralha recebe tiros pelo
## `_golpe_na_casa`. Por isso aqui não há `morder_casa` nem o transbordo × 1,4 dele — o dano vai direto
## para `vida`, como vai para `hp` no corpo tripulado.
## O preço é repartido pelas casas VIVAS da peça: é a leitura de "fogo disperso" que `_aplicar_golpe` já
## usa para o bloco (`esquadra.gd:1407-1413`), agora na escala de quatro cascos.
func ferir_peca(alvo: Dictionary, p: int, dano: float) -> bool:
	if not bool(alvo["vivo"]):
		return false
	var casas := casas_da_peca(p)
	var vivas := 0
	for c in casas:
		if float(alvo["casas"][c]["vida"]) > 0.0:
			vivas += 1
	if vivas == 0:
		return false
	var por_casa := dano / float(vivas)
	for c in casas:
		var casa: Dictionary = alvo["casas"][c]
		if float(casa["vida"]) <= 0.0:
			continue
		casa["vida"] = maxf(0.0, float(casa["vida"]) - por_casa)
		if float(casa["vida"]) <= 0.0:
			casa["morta_em"] = float(salva_numero)
			casa["a_noticiar"] = true
	_recalcular_agregados(alvo)
	if float(alvo["navios"]) > 0.0:
		return false
	alvo["vivo"] = false
	if String(alvo["lado"]) == "aliado":
		perdas_aliadas += 1
	else:
		perdas_hostis += 1
	return true
```

- [ ] **Step 5: Vento e coroa**

`_empurrar_no_vento` (`main.gd:3714`) e `_queimar_na_corona` (`main.gd:3843`) trocam a primeira linha
e ganham o laço das peças no fim da função. O laço de corpos de cada uma **não se toca**.

```gdscript
func _empurrar_no_vento(delta: float, pecas: Array[Dictionary]) -> void:
```

```gdscript
	# O vento da estrela na muralha: mesmo alcance, mesmo peso linear, mesma conta radial — lida peça
	# por peça. A guarda de centro (`< 0,0001`) existe no corpo porque ali não há "para fora", e vale
	# igual para a peça.
	for par in pecas:
		var bloco: Dictionary = par["bloco"]
		var p := int(par["indice"])
		if not Esquadra.peca_viva(bloco, p):
			continue
		var vetor := (par["pos"] as Vector3) - ESTRELA_POS
		var distancia := vetor.length()
		if distancia > ESTRELA_VENTO_ALCANCE or distancia < 0.0001:
			continue
		var peso := 1.0 - distancia / ESTRELA_VENTO_ALCANCE
		esquadra.empurrar_peca(bloco, p,
			vetor / distancia * ESTRELA_VENTO_ACEL * peso * delta)
```

```gdscript
func _queimar_na_corona(delta: float, pecas: Array[Dictionary]) -> void:
```

```gdscript
	# A coroa cozinha casco, não chapa — a cláusula que `escudo.gd` já assinou para o corpo tripulado,
	# na escala da peça. O relatório só aparece quando um BLOCO afunda: uma muralha inteira dentro da
	# Fornalha reescreveria a linha a cada tique, e a ponte perderia o DERROTA embaixo dela.
	var afundou := 0
	for par in pecas:
		var bloco: Dictionary = par["bloco"]
		var p := int(par["indice"])
		if not Esquadra.peca_viva(bloco, p):
			continue
		if (par["pos"] as Vector3).distance_to(ESTRELA_POS) > ESTRELA_CORONA_RAIO:
			continue
		if esquadra.ferir_peca(bloco, p, ESTRELA_QUEIMA_POR_SEGUNDO * delta):
			afundou += 1
	if afundou > 0 and is_instance_valid(report_label):
		report_label.text = "CORONA // %d bloco(s) da muralha afundaram na Fornalha." % afundou
```

- [ ] **Step 6: Barreiras — o contato cobra da peça, com chave da peça**

```gdscript
func _chocar_com_barreiras(pecas: Array[Dictionary]) -> void:
	_cobrar_contato(rochas, "rocha", pecas)
	_cobrar_contato(astros, "astro", pecas)


func _cobrar_contato(lista: Array[Dictionary], prefixo: String, pecas: Array[Dictionary]) -> void:
```

O laço de corpos dentro de `_cobrar_contato` **não se toca**, inclusive a chave com
`node.get_instance_id()` — corpo tripulado tem nó e continua pagando do jeito de antes. Acrescente o
laço das peças ao fim da função:

```gdscript
	# A muralha paga a mesma fatura, peça por peça. Duas contas novas, e as duas vêm da geometria da
	# peça: `par["raio"]` é RAIO_DA_PECA (5,256 u), não a meia-diagonal do bloco, e a separação sai do
	# `desloc` da peça — teleportar o bloco moveria as outras cinco peças por causa de uma.
	# Custo medido, declarado: 1 440 peças × 14 rochas = 20 160 testes de par por tique. É a lei mais
	# cara da folha; o vento e a coroa são uma passada de 1 440 cada.
	for par in pecas:
		var bloco: Dictionary = par["bloco"]
		var p := int(par["indice"])
		if not Esquadra.peca_viva(bloco, p):
			continue
		var pos: Vector3 = par["pos"]
		for barreira in lista:
			var centro: Vector3 = barreira["pos"]
			var soma := float(par["raio"]) + float(barreira["raio"])
			var entre := pos - centro
			var distancia := entre.length()
			if distancia >= soma:
				continue
			var normal := Vector3(0, 0, 1) if distancia < 0.001 else entre / distancia
			esquadra.empurrar_peca(bloco, p, normal * (soma - distancia))
			# A aproximação é velocidade RELATIVA, e é por isso que o instantâneo carrega `vel`
			# (Tarefa 2): sem ela a pedra em deriva e a pedra parada cobrariam o mesmo preço.
			var aproximacao := -((par["vel"] as Vector3) - (barreira["vel"] as Vector3)).dot(normal)
			if aproximacao <= RAM_SPEED:
				continue
			# Chave por PEÇA, montada com `Esquadra.id_peca`. A coordenada não serve (muda de nome a
			# cada quadro e rearma a janela sem parar — o moedor que o comentário do corpo já evita),
			# e a chave por bloco faria seis peças dividirem a mesma janela de 1,5 s.
			var chave := "%s:%d" % [prefixo, Esquadra.id_peca(bloco, p)]
			if battle_clock - float(ram_windows.get(chave, -RAM_WINDOW)) < RAM_WINDOW:
				continue
			ram_windows[chave] = battle_clock
			esquadra.ferir_peca(bloco, p,
				clampf((aproximacao - RAM_SPEED) * RAM_DAMAGE, 1.0, RAM_MAX_DAMAGE))
```

- [ ] **Step 7: Um instantâneo para as quatro leis**

Substitua o topo de `_aplicar_cenario` escrito na Tarefa 7 (o `var pecas` condicionado a `poco_ativo`)
por esta versão, que serve as quatro leis do mesmo quadro:

```gdscript
func _aplicar_cenario(delta: float) -> void:
	# Um instantâneo por tique, compartilhado pelas quatro leis que medem peça. A lista é refeita a cada
	# quadro porque `desloc` é escrito dentro do próprio tique — mas a excursão está presa pela trela
	# (1,2 / 0,6 / 0,9 u) e os raios das leis são de dezenas de u, então a posição lida no topo vale
	# para as quatro contas. Com `pecas_livres` desligada, nenhuma outra escrita toca em `desloc`.
	var pecas: Array[Dictionary] = []
	if poco_ativo or estrela_ativa or not rochas.is_empty() or not astros.is_empty():
		pecas = esquadra.pecas_na_cena()
	if poco_ativo:
		_puxar_para_o_poco(delta, pecas)
		_lentificar_quadro()
	if estrela_ativa:
		_empurrar_no_vento(delta, pecas)
		_queimar_na_corona(delta, pecas)
	if planeta_ativa:
		# Antes de cobrar qualquer contato: a lua tem de ser lida onde ela está neste quadro.
		_orbitar_luas()
	if not rochas.is_empty():
		_derivar_rochas(delta)
	if not rochas.is_empty() or not astros.is_empty():
		_chocar_com_barreiras(pecas)
```

- [ ] **Step 8: Os dezenove sítios velhos**

Medido contra `HEAD` (refaça a conta antes de editar — linha de sonda deriva com qualquer commit):

```bash
grep -rn "_empurrar_no_vento(\|_queimar_na_corona(\|_chocar_com_barreiras(" --include=*.gd . \
  | grep -v "^./main.gd" | cut -d: -f1 | sort | uniq -c
```

Saída esperada: **7** em `tools/probes/estrela.gd`, **6** em `tools/probes/cenarios.gd`, **3** em
`tools/probes/sistema.gd`, **2** em `tools/probes/tripulacao.gd`, **1** em `tools/probes/escudo.gd` =
**19**. `_cobrar_contato` não tem chamador fora de `main.gd` (só as duas linhas de
`_chocar_com_barreiras`), então a arity nova dele não abre sítio nenhum. Em `cenarios.gd` e
`tripulacao.gd` o `var SEM_MURALHA` já existe da Tarefa 7; em `estrela.gd`, `sistema.gd` e `escudo.gd`
escreva a declaração de nível de classe uma vez por arquivo, com o mesmo comentário das famílias G/H e
a mesma razão do tipo explícito (`[]` sozinho é `Array` e o motor recusa atribuí-lo a
`Array[Dictionary]`):

```gdscript
## A lei é medida nos doze cascos. A muralha entra nesta conta em `peca.gd`, famílias G e H, onde o
## censo é o objeto da asserção; aqui a lista é vazia de propósito, para que o número antigo continue
## sendo o número antigo.
var SEM_MURALHA: Array[Dictionary] = []
```

Cada sítio passa a chamar com o segundo argumento (`game._empurrar_no_vento(PASSO, SEM_MURALHA)`,
`game._queimar_na_corona(1.0, SEM_MURALHA)`, `game._chocar_com_barreiras(SEM_MURALHA)`), com o prefixo
do segundo jogo montado onde a sonda já usa um (`g10._queimar_na_corona(0.5, SEM_MURALHA)` em
`tools/probes/escudo.gd:495`).

- [ ] **Step 9: O que NÃO se toca, declarado**

`_resolve_collisions` (`main.gd:4204`) e `_collision_bodies` (`main.gd:4186`) ficam como estão. A
primeira é o corpo-a-corpo dos ~26 cascos nomeados (frota, hostis, ponte) e a segunda é a lista desses
corpos — nenhuma das duas jamais chamou a muralha, então mexer nelas seria inventar um segundo canal de
colisão para a massa sem sonda que o cubra. A massa entra no cenário pela porta das peças, e é a
família H que a vigia.

- [ ] **Step 10: Checagem, sonda e regressão**

```bash
cd /d/Downloads/IronStarsFleetCommand
for s in esquadra main; do
  env APPDATA="D:\\Downloads\\tmp-userdata-iron" "$GODOT" --headless --path . \
    --check-only --script res://$s.gd
done
for p in peca estrela cenarios sistema tripulacao escudo casas; do
  env APPDATA="D:\\Downloads\\tmp-userdata-iron" "$GODOT" --headless --path . --quit-after 1800 \
    -s res://tools/probes/$p.gd 2>&1 | tail -4
done
```
Expected: `peca` verde com as famílias A-H contadas; `estrela`, `cenarios`, `sistema`, `tripulacao` e
`escudo` verdes **com o mesmo número de conferências de antes** — a lista vazia não move um número, e
se mover é porque o `SEM_MURALHA` não está vazio ou a lei nova entrou no caminho dos corpos;
`casas.gd` verde com a linha `escala 35 golpes de bloco = 840 lances de casa` ainda impressa. Registre
no log da rodada o número de travessia da família 10 de `tools/probes/esquadra.gd` (a cota `minf` da
âncora hostil, Tarefa 6 — `esquadra.gd:67-75`): a pedra agora cobra peça, e essa cota é quem segura o avanço inimigo — se o número mudou,
não afrouxe a asserção, declare a pré-condição no criador do estado e investigue.

- [ ] **Step 11: Commit**

```bash
git add esquadra.gd main.gd tools/probes/peca.gd tools/probes/estrela.gd tools/probes/cenarios.gd \
  tools/probes/sistema.gd tools/probes/tripulacao.gd tools/probes/escudo.gd
git status --short
git commit -m "feat(cenario): lapidacao 4 tarefa 8 - vento coroa e pedra medem a peca, janela de abalroamento por peca"
```

### Task 9: A estrela é uma bola, e a coroa é uma casca

**Files:**
- Modify: `main.gd:3366-3385` (`_montar_estrela`), `main.gd` (um helper novo, `_chapa_tangente`, ao
  lado de `_esfera` `:3351-3363`), `tools/probes/fotograma.gd:677` (só a **redação** do rótulo)
- Test: `tools/probes/peca.gd` família S; o portão visual é `fotograma.gd` em janela, com o PNG relido

**Interfaces:**
- Consumes: `_esfera(pos, raio, mat, parent, segmentos)` (`main.gd:3351`), `_box(pos, size, mat,
  parent)` (`main.gd:2914`, que devolve o `MeshInstance3D`), `_material(...)`, `ESTRELA_POS`
  `(0, 24, -74)`, `ESTRELA_CALOR_RAIO` 70,0 (`main.gd:262,263`). **Nenhuma constante de lei se mexe**:
  `ESTRELA_CORONA_RAIO` 30,0, `ESTRELA_QUEIMA_POR_SEGUNDO` 6,0, `ESTRELA_VENTO_ALCANCE` 96,0,
  `ESTRELA_VENTO_ACEL` 3,0, `ESTRELA_RADIAO_*` ficam exatamente onde estão — a queixa é de pintura, e
  mover um raio de lei aqui seria trocar a batalha inteira por um efeito visual.
- Produces: `_chapa_tangente(mi: MeshInstance3D, dir: Vector3) -> void`; a fotosfera como `SphereMesh`
  de raio 13,0; as vinte chapas da coroa sobre a esfera de raio `ESTRELA_CALOR_RAIO * 0.42` = 29,4 u.

- [ ] **Step 1: O vermelho — família S**

```gdscript
## ── Família S: a estrela é bola, e o censo continua 22 ──
## A queixa é «a esteira solar não está representada de forma esférica». O contrato que não pode
## quebrar é o censo de nós — 1 fotosfera + 20 chapas + 1 luz = 22, assinado em
## `tools/probes/fotograma.gd:677` e lido também pelo `comando.gd:123` (27 filhos de `main`, que o
## interior do cenário não altera). O que muda é a FORMA dos vinte e um corpos, e há duas assereções
## que separam bola de disco sem rasterizador: o tipo de malha da fotosfera e o raio das chapas. Hoje
## o raio de uma chapa é sqrt(29,4² + (3·sin)²), que varia de 29,400 a 29,553 u; numa casca esférica as
## vinte ficam a exatamente 29,400 u, e a latitude chega a ±27,9 u em vez de ±3,0 u.
func _familia_estrela_bola() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	await _frames(3)
	game.world_timer.stop()
	game._montar_cenario("ESTRELA")
	await _frames(2)
	var raiz: Node3D = game.cenario_root
	_assert("S censo: a estrela continua com 22 nós e uma marca na mesa",
		raiz.get_child_count() == 22 and game.holo_cenario.size() == 1,
		"%d nós e %d marcas" % [raiz.get_child_count(), game.holo_cenario.size()])
	var fotosfera := raiz.get_child(0) as MeshInstance3D
	_assert("S forma: a fotosfera é SphereMesh de raio 13,0, não o disco de 1,4 de altura",
		fotosfera != null and fotosfera.mesh is SphereMesh
			and absf(float((fotosfera.mesh as SphereMesh).radius) - 13.0) < 1e-6,
		"primeiro nó = %s" % (str(fotosfera.mesh.get_class()) if fotosfera != null else "sem nó"))
	var raio_coroa := game.ESTRELA_CALOR_RAIO * 0.42
	var chapas := 0
	var no_raio := 0
	var latitude_maxima := 0.0
	for i in range(1, 21):
		var chapa := raiz.get_child(i) as MeshInstance3D
		if chapa == null or not (chapa.mesh is BoxMesh):
			continue
		chapas += 1
		if absf(chapa.global_position.distance_to(game.ESTRELA_POS) - raio_coroa) < 1e-3:
			no_raio += 1
		latitude_maxima = maxf(latitude_maxima,
			absf(chapa.global_position.y - game.ESTRELA_POS.y))
	_assert("S casca: as vinte chapas estão todas a 29,400 u do centro, nem mais nem menos",
		chapas == 20 and no_raio == 20,
		"%d chapas de BoxMesh, %d no raio exato de %.3f u" % [chapas, no_raio, raio_coroa])
	_assert("S casca: a coroa sobe e desce em latitude, não só gira em volta",
		latitude_maxima > 20.0, "maior |delta y| = %.3f u" % latitude_maxima)
	game.queue_free()
```

Ligue no `_initialize`, depois de `_familia_censo_leis()`:

```gdscript
	await _familia_estrela_bola()
```

- [ ] **Step 2: Rodar e ler o vermelho**

```bash
cd /d/Downloads/IronStarsFleetCommand
env APPDATA="D:\\Downloads\\tmp-userdata-iron" "$GODOT" --headless --path . --quit-after 1800 \
  -s res://tools/probes/peca.gd 2>&1 | tail -10
```
Expected: `S censo` **verde** (os 22 nós já existem hoje) e as três seguintes vermelhas — a fotosfera
hoje é `CylinderMesh`, as chapas variam de 29,400 a 29,553 u e a latitude máxima é 3,0 u. Um verde em
`S censo` aqui é a precondição, não o resultado: é ela que prova, no fim, que a forma mudou sem trocar
o número do censo.

- [ ] **Step 3: O helper da chapa deitada**

Ao lado de `_esfera` (`main.gd:3363`):

```gdscript
## Deita a chapa tangente à esfera: o eixo fino (+y do BoxMesh) sai radialmente, e os outros dois
## ficam no plano tangente. O `apoio` troca de vetor perto dos polos porque (0,1,0) ali é paralelo ao
## raio e o produto vetorial daria base degenerada — com 20 faixas de latitude a mais externa está em
## cos = 0,95, mas a conta não pode depender disso.
func _chapa_tangente(mi: MeshInstance3D, dir: Vector3) -> void:
	var apoio := Vector3(0.0, 0.0, 1.0) if absf(dir.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var x := dir.cross(apoio).normalized()
	var z := x.cross(dir)
	mi.transform = Transform(Basis(x, dir, z.normalized()), mi.position)
```

`Basis(x_axis, y_axis, z_axis)` recebe as três colunas, e `x.cross(dir)` é exatamente a terceira que
faz a base ser de mão direita (`x × dir = z`), então o mesh não espelha. O `normalized()` só re-aparada
o `z` (a conta já o dá unitário quando `dir` é unitário); fica explícito para o `Transform` não
herdar uma base escalada se um dia `dir` vier do mundo real.

- [ ] **Step 4: `_montar_estrela`**

Substitua as duas primeiras contas da função (`main.gd:3366-3378`) — o comentário de cabeçalho e a
luz ficam:

```gdscript
## Estrela: a bola incandescente, a coroa em casca esférica e uma luz pontual. É o único cenário que
## mexe em dano, e mexe por posição de quem dispara — quem se aproxima para aquecer a arma também se
## expõe. A forma é esférica desde a lapidação 4: o disco achatado de 1,4 u de altura fazia a estela
## parecer um anel pintado no plano, que é exatamente a queixa do commander. O censo de nós é o de
## sempre (1 + 20 + 1 = 22), e nenhum raio de lei se mexeu.
func _montar_estrela() -> void:
	var raiz := _garantir_cenario_root()
	estrela_ativa = true
	var fotosfera := Color(1.0, 0.8, 0.38)
	_esfera(ESTRELA_POS, 13.0, _material(fotosfera, 0.0, 0.9, fotosfera), raiz, 32)
	var coroa := _material(Color(1.0, 0.6, 0.2), 0.0, 0.9, Color(1.0, 0.55, 0.16))
	var raio_coroa := ESTRELA_CALOR_RAIO * 0.42
	for i in range(20):
		# Casca de área igual: a latitude sai do censo por faixa (`1 - 2(i+0,5)/20` é o cos do ângulo
		# polar, uniforme em área, e não em ângulo), e o azimute é o ângulo áureo já usado no cinturão
		# (`main.gd:_montar_cinturao`, 2,39996). As vinte chapas ficam a exatamente 29,400 u do centro,
		# com ±27,9 u de latitude — é isso que faz a coroa abraçar a bola em vez de orbitar o disco.
		var cos_polar := 1.0 - 2.0 * (float(i) + 0.5) / 20.0
		var raio_paralelo := sqrt(maxf(0.0, 1.0 - cos_polar * cos_polar))
		var azimute := float(i) * 2.39996
		var dir := Vector3(cos(azimute) * raio_paralelo, cos_polar, sin(azimute) * raio_paralelo)
		var chapa := _box(ESTRELA_POS + dir * raio_coroa, Vector3(3.0, 0.6, 3.0), coroa, raiz)
		_chapa_tangente(chapa, dir)
```

- [ ] **Step 5: A redação do censo, não o número**

Em `tools/probes/fotograma.gd:677`, o rótulo diz «disco + 20 billets da coroa + luz». Troque a palavra,
mantendo os 22:

```gdscript
	_assert("a estrela tem corpo na cena (bola + 20 chapas da coroa em casca + luz)",
		game.cenario_root.get_child_count() == 22 and game.holo_cenario.size() == 1,
```

As duas linhas seguintes (`"%d nós e %d marcas na mesa" % [...]`) não se tocam.

- [ ] **Step 6: Portão visual, em janela, com o PNG relido**

`fotograma.gd` é uma das três sondas de janela e precisa de rasterizador — sob `--headless` a textura
vem null:

```bash
cd /d/Downloads/IronStarsFleetCommand
env APPDATA="D:\\Downloads\\tmp-userdata-iron" "$GODOT" --path . --quit-after 4000 \
  -s res://tools/probes/fotograma.gd > /d/Downloads/tmp-userdata-iron/janela_fotograma.log 2>&1
grep -nE "ERROR|SCRIPT ERROR|Cannot|Invalid" /d/Downloads/tmp-userdata-iron/janela_fotograma.log | head
```

E **abra o PNG** `D:/Downloads/tmp-userdata/frame/10_estrela.png` com a ferramenta Read. O quadro tem de
ler-se como bola com casca à volta, não como panqueca com anel. A família S prova a aritmética; a
aprovação de como PARECE é do commander, e sem o PNG relido este portão está falhando aberto.

- [ ] **Step 7: Checagem e sonda**

```bash
cd /d/Downloads/IronStarsFleetCommand
env APPDATA="D:\\Downloads\\tmp-userdata-iron" "$GODOT" --headless --path . --check-only --script res://main.gd
for p in peca estrela cenarios casas; do
  env APPDATA="D:\\Downloads\\tmp-userdata-iron" "$GODOT" --headless --path . --quit-after 1800 \
    -s res://tools/probes/$p.gd 2>&1 | tail -4
done
```
Expected: `peca` verde com A-S contadas; `estrela.gd` verde **com os mesmos números de antes** — a
sonda mede vento, calor e varredura por posição, e nenhuma das três contas mudou; `cenarios.gd` e
`casas.gd` verdes. Se `estrela.gd` se mexer, a causa é uma constante movida no Step 4: volte e corrija
o raio, não a asserção.

- [ ] **Step 8: Commit**

```bash
git add main.gd tools/probes/peca.gd tools/probes/fotograma.gd
git status --short
git commit -m "feat(cenario): lapidacao 4 tarefa 9 - a estrela vira bola e a coroa casca esférica, censo 22 intacto"
```

---

### Task 10: Fechamento da lapidação — bateria de 36, janela, spec, README, push

Ritual da casa (`godot-iron-stars-slice-closeout`), sete passos na ordem, com a saída de cada um
relida antes de afirmar o próximo. Este é o único lugar do plano onde números de medida viram texto:
as Tasks 1–9 produzem os verdes, a Tarefa 10 os escreve no spec e no README.

**Files:**
- Modify: `docs/superpowers/specs/2026-10-29-sub-bloco-e-ancora-viva-design.md` — a §6 ganha os
  números medidos e a família S declarada
- Modify: `README.md` — a cláusula da massa, a travessia, o censo de corpos, o custo da correia e o
  parágrafo novo de `tools/probes/peca.gd` na lista de sondas
- Modify: `docs/superpowers/plans/2026-10-29-sub-bloco-e-ancora-viva.md` — checkboxes marcados

- [ ] **Step 1: Sincronizar antes de medir**

```bash
cd /d/Downloads/IronStarsFleetCommand
git fetch origin
git log --oneline HEAD..origin/main
git log --oneline origin/main..HEAD
git status --short
```

Expected: as duas listas de commits vazias (remoto e local no mesmo `32ec664` + os commits das Tasks
1–9, que são locais e ainda não empurrados). Se `origin/main` tiver commit que não é desta sessão,
**pare e pergunte**: a bateria prova um estado, e provar um estado que já não é o do disco é o risco
nomeado do ritual. O `git status` tem de mostrar só o WIP alheio conhecido (`_tmp_pista_fria.gd` e o
`.gd.uid` dele) mais os arquivos desta fatia.

- [ ] **Step 2: Bateria inteira, e ler a saída DELA**

```bash
bash /d/Downloads/tmp-userdata-iron/bateria.sh 2>&1 | tail -50
```

Só depois da linha `BATERIA: fim`. Verde = **36** sondas (35 herdadas + `peca`; 33 headless porque as
três de olho estão na `SKIP` da bateria) com `quebras=0` **e** `linhas_de_erro=0`. A bateria conta os
logs por ela mesma; se a linha de `peca` vier `(SEM VEREDITO)`, a causa mais provável é o laço da
sonda ter morrido em erro de runtime que o `--check-only` não vê (`Invalid assignment`, `%r` em
`print`) — abra o log antes de tocar em qualquer asserção.

Se precisar varrer por fora da bateria, use os três formatos e `tail -1` — o veredito de verdade é
sempre a última linha, nunca a primeira:

```bash
for l in /d/Downloads/tmp-userdata-iron/bateria/*.log; do
  printf '%s | %s\n' "$(basename "$l" .log)" \
    "$(grep -hE 'veredito|quebras=|quebra\(s\)' "$l" | tail -1)"
done | sort
ls /d/Downloads/tmp-userdata-iron/bateria/*.log | wc -l
```

Expected do `wc -l`: **33** (as três de olho não têm log aqui). Anote da varredura, número por número,
para o Step 6: as conferências de `peca`, de `esquadra`, de `casas`, de `batalha_real`, de `estrela`,
de `cenarios`, de `sistema`, de `tripulacao`, de `escudo`, de `comando`; a linha de travessia impressa
pela família 10 de `tools/probes/esquadra.gd`; e a linha `35 golpes / 840 lances` de `casas`.

- [ ] **Step 3: Sonda vermelha — precondition no CRIADOR do estado, tolerância intocada**

Se alguma sonda antiga reprovar, a resposta nunca é afrouxar a asserção. É declarar a precondition onde
o estado nasce. Os criadores desta fatia:

```bash
cd /d/Downloads/IronStarsFleetCommand
grep -rln "Esquadra\.new()" tools/probes/*.gd *.gd
grep -rn "pecas_livres" tools/probes/*.gd *.gd
grep -rn "zerar_placas\|fixar_lotacao" tools/probes/*.gd | head -20
```

Expected: `comando.gd`, `esquadra.gd`, `voo.gd`, `main.gd` e `batalha_real.gd` montam esquadra própria;
cada um deles tem de nascer com `pecas_livres` no valor que a asserção dele presupõe. A pegada medida na
fatia 3 vale aqui palavra por palavra: consertar na faixa de montagem não adianta se o construtor rearma
depois. Depois de mexer, `--check-only` na sonda e de novo a bateria só dela:

```bash
env APPDATA="D:\\Downloads\\tmp-userdata-iron" /c/Users/gmore/godot/godot \
  --headless --path . --check-only --script res://tools/probes/<sonda>.gd
```

- [ ] **Step 4: Paridade `.gd` <-> `.gd.uid`**

```bash
cd /d/Downloads/IronStarsFleetCommand
for f in *.gd tools/probes/*.gd; do [ -f "$f.uid" ] || echo "SEM UID: $f"; done
```

Expected: saída vazia. `tools/probes/peca.gd.uid` é escrito pelo motor na importação, nunca na mão —
se o loop acima nomear `peca.gd`, abra o projeto no editor uma vez (ou rode o `--import` do motor) e
recheque. O `.uid` de um script novo entra no MESMO commit do script.

- [ ] **Step 5: A trinca de olho, em janela real, com o PNG relido**

Sem `--headless`: sob headless a textura vem null e a sonda de janela devolve `<sem veredito>` com
dezenas de linhas de erro.

```bash
cd /d/Downloads/IronStarsFleetCommand
env APPDATA="D:\\Downloads\\tmp-userdata-iron" /c/Users/gmore/godot/godot --path . \
  --quit-after 4000 -s res://tools/probes/fotograma.gd \
  > /d/Downloads/tmp-userdata-iron/janela_fotograma.log 2>&1
env APPDATA="D:\\Downloads\\tmp-userdata-iron" /c/Users/gmore/godot/godot --path . \
  --quit-after 6000 -s res://tools/probes/massa_visivel.gd \
  > /d/Downloads/tmp-userdata-iron/janela_massa.log 2>&1
env APPDATA="D:\\Downloads\\tmp-userdata-iron" /c/Users/gmore/godot/godot --path . \
  --quit-after 6000 -s res://tools/probes/comando_olho.gd \
  > /d/Downloads/tmp-userdata-iron/janela_comando.log 2>&1
grep -hE "veredito|quebras=|quebra\(s\)" /d/Downloads/tmp-userdata-iron/janela_*.log | tail -3
grep -cE "ERROR|SCRIPT ERROR|Cannot|Invalid|OUT OF MEMORY" /d/Downloads/tmp-userdata-iron/janela_*.log
```

**E releia os PNGs** com a ferramenta Read — saem em `D:/Downloads/tmp-userdata/frame/` (essa pasta não
leva o sufixo `-iron`). O quadro desta fatia é o `10_estrela.png` (a bola com a coroa em casca, Task 9)
mais os quadros da massa: com a roda do mouse perto, a muralha tem de ler como **seis peças por bloco**
com ar entre elas, não como um paralelepípedo único; um bloco ralado tem de mostrar o buraco na peça, não
a mancha; e o censo da estrela continua 22 nós, provado headless pela família S.

Nada disso a sonda headless prova, e a aprovação é do comandante: timing, leitura do quadro e arte pedem
o jogador na janela. Dizer «o portão numérico passou, a leitura é sua» em vez de declarar sucesso visual.

- [ ] **Step 6: Fechar a §6 do spec com o que foi medido**

Na §6 de `docs/superpowers/specs/2026-10-29-sub-bloco-e-ancora-viva-design.md`:

1. acrescentar à tabela de famílias a linha **S forma** (`fotosfera é SphereMesh`, `as vinte chapas a
   exatamente 29,400 u do centro`, `censo de nós 22`), com a nota de que ela é **a mais que as oito do
   texto** e o porquê — um PNG não assere tipo de malha nem raio constante, e a queixa era de forma;
2. trocar o «35 → 36» prospectivo pelo censo medido: quantos logs, quantas conferências por sonda nova
   e por sonda tocada, `quebras=0` e zero linha de erro;
3. escrever o número de travessia lido da família 10 (o valor real depois da âncora-estado e da cota
   `minf` hostil), a linha `35 golpes / 840 lances` reimpresa por `casas.gd`, o custo contado da correia
   (**20 160 testes de par por tique** no vento, lei mais cara) e o censo de corpos novos (**1 440**);
4. fechar com o custo **contado, nunca em `ms`** — o relógio deste host lê ±35 % entre rodadas e um número
   de milissegundos escrito aqui seria uma promessa, não uma medição;
5. manter a cláusula final, que é a honestidade da fatia: *o veredito de «parece várias naves» é do olho
   do comandante na janela*, e headless nunca pinta.

- [ ] **Step 7: Varredura do README (`godot-readme-number-sweep`)**

O README é contrato medido: mexeu na aritmetica da massa, os números derivados andam junto. Rode as
buscas do skill e confira cada linha contra a rodada:

```bash
cd /d/Downloads/IronStarsFleetCommand
grep -nE "240 blocos|5 760|2 880|154,0|35 golpes|840 lances|1 440|24 000" README.md | cut -c1-120
grep -nE "confere [0-9]+ pontos" README.md | cut -c1-90
```

O que muda e por quê:

- as cláusulas que dizem **quantos corpos obedecem** (as de `240 blocos`, `5 760 cascos`, `2 880
  instâncias`) passam a dizer também **1 440 peças** — é a frase do commander, e omiti-la deixa o README
  descrevendo a aritmética velha;
- a travessia citada (`154,0 u`, `z −51,0` / `z −205,0`) é reescrita com o número lido da família 10, se
  a âncora-estado o moveu; se não moveu, diz-se que ele foi re-medido e continuou o mesmo;
- `35 golpes ≡ 840 lances` continua de pé e continua citada — é a asserção da Task 7 que prova que comer
  peça não muda o ledger;
- os parágrafos das sondas tocadas (`esquadra`, `casas`, `batalha_real`, `estrela`, `cenarios`,
  `sistema`, `tripulacao`, `escudo`, `comando`) ganham os pontos conferidos **nesta** rodada;
- entra um parágrafo novo para `tools/probes/peca.gd` no mesmo molde dos vizinhos («confere N pontos da
  peça em oito famílias mais a S, e existe porque …»), com o comando de roda correspondente na lista de
  `## Validação`, e a frase «**três sondas em janela real**» continua três.

- [ ] **Step 8: UM commit por nome, prova, push**

```bash
cd /d/Downloads/IronStarsFleetCommand
git status --short
git add README.md \
  docs/superpowers/specs/2026-10-29-sub-bloco-e-ancora-viva-design.md \
  docs/superpowers/plans/2026-10-29-sub-bloco-e-ancora-viva.md \
  esquadra.gd main.gd \
  tools/probes/peca.gd tools/probes/peca.gd.uid \
  tools/probes/esquadra.gd tools/probes/casas.gd tools/probes/batalha_real.gd \
  tools/probes/comando.gd tools/probes/estrela.gd tools/probes/cenarios.gd \
  tools/probes/sistema.gd tools/probes/tripulacao.gd tools/probes/escudo.gd \
  tools/probes/fotograma.gd tools/probes/massa_visivel.gd tools/probes/comando_olho.gd
git commit -m "feat(esquadra): lapidacao 4 - sub-bloco manobrando, ancora viva e cena medindo a peca

240 blocos passam a ter 1440 corpos proprios: a peca e quatro casas, prende desloc
na trela de 1,2/0,6/0,9 u, so avanca para posto livre com histerese 1,3x, e a ancora
vira estado com low-pass na media dos blocos vivos. Poço, vento, coroa e pedra cobram
peca por peca; a estrela vira bola com coroa em casca e o censo de 22 nos preservado.
Bateria de 36 sondas com quebras=0 e zero linha de erro; as tres sondas de olho em
janela real, com o PNG relido. Ledger intocado: 35 golpes de bloco = 840 lances de casa."
git show --stat --format="" HEAD
git push origin main
git status --short
```

A lista acima é o **conjunto esperado** das Tasks 1–9, não licença de `git add -A`: confira com
`git status --short` antes e depois, tire o que a rodada não tocou, e deixe fora `_tmp_pista_fria.gd` e
o `.gd.uid` dele (WIP de outra sessão), `.godot/`, `.manus/` e o churn de puro CRLF nos `.import` (esses
só entram se o `git diff --ignore-cr-at-eol --stat -- '*.import' project.godot` mostrar conteúdo real,
não fim de linha). O `git show --stat` tem de provar que nenhum `_tmp_*` e nenhum `.import` entrou.

Relatar os dois resultados: o da comparação remota (Step 1) e o do push.

- [ ] **Step 9: Memória da casa**

Atualizar `project-iron-stars-comando-programa.md` nesta linha apenas: a lapidação 4 saiu (peça = 4 casas,
âncora = estado, cena mede peça, estrela esférica) e a fila continua com ①IA de xadrez ③, ②fatia 5 e
③o equilíbrio devido (0 de 120 blocos afundam em 200 s; alavanca `DANO_DE_BLOCO` 2,2). Se a rodada
estabeleceu algo não-óbvio e durável além disso, registrar; otherwise nada.

---

## Self-review do plano (medido nesta sessão, antes de executar)

**1. Cobertura do spec, seção por seção:**

- §1 sub-bloco como estado → Tasks 1 (identidade `peca_local`/`casa_na_peca`), 2 (o `pecas` no bloco,
  `pecas_na_cena`, `abater_peca`), 3 (os três leitores, inércia byte a byte), e a checagem suja **por
  peça** que o §3 exige está na Task 3 Step 6 (linha `suja` do laço de pintura).
- §2 âncora como estado → Task 6, com a semente `_estacao_derivada` e a `_media_da_linha` que exclui
  `com_destino`, rodízio e quem passou de `CAMPO_DE_APROXIMACAO`.
- §3 cena mede peça → Task 7 (poço, horizonte `POCO_HORIZONTE` 9,0 comendo peça) e Task 8 (vento, coroa,
  rochas/astros, janela de abalroamento por peça). `_resolve_collisions` fica fora **por contrato**, e a
  Task 8 Step 9 diz isso em vez de omitir.
- §4 folga, ar e vizinhos → Task 4 (trela + `FOLGA_DA_PECA`) e Task 5 (vaga + histerese 1,3 ×), com a
  família D cobrando as duas asserções distintas declaradas no **desvio 1** e a vizinhança derivada do
  índice em `vizinhos_locais_da_peca`.
- §5 estrela esférica → Task 9, e o censo 22 é coberto headless pela família S, declarada no **desvio 3**.
- §6 teste → oito famílias A–H presentes, cada uma com o código literal da asserção, mais a Task 10 que
  fecha o ritual. A cláusula «zero tração em bloco além de 46 u» do §6 está em duas asserções: a família F
  (estação anda 0,00 u no quadro do arrastão) e `G alcance` (a 52 u, nenhum vetor em nenhuma peça).

**2. Nenhum placeholder:** `grep -nE "TBD|TODO|a definir|fill in|implement later|Similar à Task|\?\?\?"`
devolve **zero linhas** neste arquivo. Toda asserção tem o código das duas metades (o exercício e o
`_assert` com a mensagem formatada), todo commit tem a lista de arquivos por nome.

**3. Consistência de tipos e assinaturas** (o que foi conferido no disco, não de memória):

- `static func` no plano e no arquivo: `_recalcular_agregados` (`esquadra.gd:415`), `casas_vivas`
  (`:656`), `casas_no_bloco` (`:363`) — as chamadas de sonda usam `Esquadra.` e as de dentro do arquivo
  usam o nome nu, que é o que o motor aceita para estático dentro da própria classe.
- De instância onde tem de ser: `pecas_na_cena`, `empurrar_peca`, `ferir_peca`, `abater_peca`,
  `caixa_da_peca`, `estacao` (todos leem estado do próprio `_montar`); `pos_da_peca` é a única
  geometria chamada por instância porque compõe `bloco["pos"]` com a excursão.
- Constantes citadas e existentes: `PASSO_BLOCO_X` 13,0 (`esquadra.gd:80`), `PASSO_BLOCO_Z` 7,0 (`:81`),
  `PASSO_ESQUADRAO_Y` 12,0 (`:97`), `POCO_POS` (`main.gd:222`), `ESTRELA_CORONA_RAIO` 30,0 (`main.gd:265`),
  `ESTRELA_QUEIMA_POR_SEGUNDO` 6,0 (`:266`), `ESTRELA_VENTO_ALCANCE` 96,0 (`:269`), `ESTRELA_VENTO_ACEL`
  3,0 (`:270`), e a tríade do abalroamento `RAM_SPEED` 3,0 / `RAM_DAMAGE` 1,9 / `RAM_MAX_DAMAGE` 18,0 /
  `RAM_WINDOW` 1,5 (`main.gd:154-159`).
- Campos lidos do bloco: `id` existe (`esquadra.gd:459`), então `Esquadra.id_peca` tem de onde tirar.
- Os números das asserções geométricas saíram da fonte nesta sessão: 8,456 u de contato
  (`RAIO_DA_PECA` 5,256 + raio da pedra), 8,807 / 9,806 u para as vizinhas que **não** pagam, 28,4 / 31,6 u
  dos dois lados da cota da coroa, 5,700 de fatura (`clampf((6,0 − 3,0) × 1,9, 1,0, 18,0)`) e os três
  pisos analíticos do ar (0,088 / 0,750 / 7,333 u) contra os publicados 2,488 / 2,550 / 8,533.

**Correções feitas por esta varredura, declaradas:**

1. A nota de registro da travessia apontava para a família 10 de `escudo.gd`; a família 10 mora em
   `tools/probes/esquadra.gd` (`:67-75`). Corrigido com a linha citada.
2. O helper de ar entre caixas chamava-se `_vaao_caixa` — vocabulário inventado, nenhum `vaao` no repo —
   e o doc dele fala em AABB. Renomeado `_ar_entre_caixas` (duas ocorrências).
3. `# G4 —` era rótulo numérico num esquema que rotula por nome (`G bite`, `G ledger`, `G trela`,
   `G alcance`); passou a `G ledger (segunda metade)`.
4. A forma de cabeçalho era `## Task N` no plano da lapidação 2 e `### Task N` aqui; mantive `###` porque
   é o que as dez tarefas deste arquivo usam entre si — consistência interna, não mudança de contrato.
5. O desvio 1 prometia que a família D cobra **duas** asserções, e o código dela só cobrava a de
   positividade estrita. Entrou a segunda: a tabela publicada do §4 recontada com a excursão zerada, seis
   pares `passo − caixa` (`esquadra.gd:60-62` para os passos, `:55` e `:153-156` para as caixas), cada um
   com o literal publicado ao lado.

**Riscos que este plano não elimina, ditos em voz alta:** o veredito «parece várias naves» é do olho do
comandante na janela, e nada em Task 1–10 autoriza declará-lo verde; a folga derivada dá liberdade de
voo, não de xadrez (pergunta aberta 2 do spec); e o equilíbrio devido (0 de 120 blocos afundam) continua
na fila, fora deste escopo.

<!--FIM-->



