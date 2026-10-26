# Dano por casco e morte visível (lapidação 2) — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** fazer cada casa desenhada de um bloco ser um corpo com vida e placa próprios, para que o tiro individual cause dano real e as naves morram de pouco em pouco na tela, e para que CONCENTRAR/DISPERSAR FOGO signifiquem escolha de casa — sem mover nenhum número de batalha somado sobre o bloco.

**Architecture:** `casas: Array[Dictionary]` entra no bloco (`vida`, `placa`, `morta_em`, `a_noticiar`) e `navios`/`escudo` deixam de ser escritos: passam a ser a soma das casas. `troca_salva()` continua fechando o ledger no fechamento e continua determinístico (zero `rng`), mas baixa a vida **casa a casa**, um lance por casa que dispara, e escreve a fila de lances em `fila_da_salva`; `tiros_da_salva()` deixa de derivar uma segunda fila e vira leitura dela. A onda de pintura em `main.gd` carrega a **notícia** da morte: a casa sai da tela no quadro em que o traço toca.

**Tech Stack:** Godot 4.7.2.stable.official (CLI `/c/Users/gmore/godot/godot`), GDScript, sondas headless `extends SceneTree` em `res://tools/probes/`, bateria paralela via `bash /d/Downloads/tmp-userdata-iron/bateria.sh`.

**Spec:** [docs/superpowers/specs/2026-10-25-dano-por-casco-e-morte-visivel-design.md](file:///D:/Downloads/IronStarsFleetCommand/docs/superpowers/specs/2026-10-25-dano-por-casco-e-morte-visivel-design.md) — commit `ff79743`. Ler o spec junto com este plano; as seções §3 a §10 são o que as tarefas abaixo implementam.

---

## Global Constraints

- Projeto `D:/Downloads/IronStarsFleetCommand` (fora do workspace da sessão: `SearchWorkspace` **não** enxerga `D:/Downloads` — usar Read/Grep/Glob com caminho absoluto).
- Branch **`main`** só, sem branch de feature. `git fetch origin` + `git log --oneline HEAD..origin/main` (com `MSYS_NO_PATHCONV=1`) antes de editar; `git push origin main` no fim de cada tarefa.
- **Nunca `git add -A`, nunca `git stash`.** O checkout tem WIP de outras sessões (hoje: `_tmp_pista_fria.gd` + `.gd.uid` — não stagear). Stage por nome exato de arquivo, um `git add` por arquivo.
- Todo comando de motor com `env APPDATA="D:\\Downloads\\tmp-userdata-iron"`. Nunca matar um `Godot.exe` que não seja o deste comando.
- Portão de cada tarefa: a sonda rodada devolve `quebras=0` **e** o log não tem nenhuma linha de `ERROR|SCRIPT ERROR|Cannot|Invalid|OUT OF MEMORY`. **Nunca alargar tolerância para o portão ficar verde.**
- Nada de sorteio novo: `randf`, `randi`, `RandomNumberGenerator`, `visual_rng` e `delta` não entram em `troca_salva`, `tiros_da_salva`, `_golpe_na_casa`, `_casas_por_proximidade`. Duas montadas gemeas fecham os mesmos dígitos.
- Cópia de painel e letreiro em português do Brasil, sem emoji.
- `float` em GDScript é **double**; `Vector3` é single. Somas de 24 parcelas iguais **não** caem no inteiro esperado: medido nesta sessão, `23 × (100/24) = 95,83333333333336` e `ceilf(95,83333333333336/100 × 24) = 24` (devia ser 23). A derivação antiga de `casas_vivas` erra a contagem em **7 dos 24** estados possíveis (k = 5, 6, 7, 20, 21, 22, 23). É por isso que a Task 1 troca a autoridade da contagem para os corpos, e é por isso que comparações de soma na sonda nova usam folga `1e-9`.
- `tools/probes/escudo.gd:215` assina que `res://escudo.gd` declara **exatamente quatro** constantes `ESCUDO_*`. Nada de criar `ESCUDO_CASA` lá — as cotas da casa moram em `esquadra.gd`.
- Paridade de arquivo: todo `.gd` rastreado tem o `.gd.uid` ao lado, no **mesmo** commit do script. Quem escreve o `.uid` é o motor, nunca a mão.
- README é contrato medido: mexeu na aritmética, varrer `README.md` (`godot-readme-number-sweep`) e reconciliar README + cabeçalhos de sonda + spec no mesmo commit.
- Sonda não se joga fora: nada de apagar `_tmp_*.gd` alheio; as famílias novas entram em sonda rastreada (`tools/probes/`).
- Congelar o jogo montado é pelo instrumento da casa — `game.process_mode = Node.PROCESS_MODE_DISABLED` (ver `tools/probes/esquadra.gd:254-259`), **nunca** `set_process(false)` e **nunca** um `world_timer` (que é nome do Succubus Shop, não existe aqui).
- A aritmética da escala fiel, de que todos os limites de salva abaixo derivam: uma casa leva `0,183333` de placa, que dois lances de `0,091667` tiram exatamente (na fronteira `<`, não `<=`, o segundo devolve transbordo zero), e `4,16667` de vida, que `33` lances escalados por `1,4` consomem. **Uma casa morre no 35º lance sobre ela.** Fogo disperso dá ~1 lance por casa por salva, logo a primeira morte de um bloco visado por um só bloco cai na salva ~35 — qualquer laço de sonda que espere morte precisa de margem (usar 60 a 120 salvas), senão ele aprova o vazio.

---

## Estrutura de arquivos

| Arquivo | Responsabilidade depois da fatia |
|---|---|
| `escudo.gd` | ganha `morder_casa(casa, dano)` — a mordida de placa sem janela e sem regeneração. As quatro cotas e `morder`/`quadro`/`nasce` ficam como estão. |
| `esquadra.gd` | corpo da casa (`casas`), agregados derivados (`navios`, `escudo`), ledger casa a casa (`troca_salva` → `fila_da_salva`), leitura da fila (`tiros_da_salva`), caixa e pintura por casa, notícia da morte (`noticiar_morte`), lotação de teste (`fixar_lotacao`). |
| `main.gd` | a onda carrega a notícia (`_armar_tracos`, `_pintar_tracos`, `_atualizar_tracos`, `_apagar_tracos`) e o letreiro da ordem concentra. |
| `tools/probes/casas.gd` (novo) | as cinco famílias do §10 do spec: escala fiel, derivação, morte visível, comando, paridade de caixa. |
| `tools/probes/{esquadra,massa_visivel,escudo,comando,ia,voo}.gd` | re-medem: writes diretos de `["navios"]` e de `["escudo"]` **em bloco** viram `fixar_lotacao` / `zerar_placas`, loops `range(casas_vivas)` viram varredura de corpos, unidade da placa declarada. |
| `README.md` + o spec | números medidos desta rodada, e a correção da frase "a função não é reescrita". |

Ordem das tarefas: **1** corpo + agregados (tudo ainda morre junto) → **2** caixa/pintura lêem corpos → **3** ledger casa a casa → **4** a onda dá a notícia → **5** a ordem converge → **6** re-medir as sondas antigas + README → **7** fechamento (bateria, janela, commit, push). Cada tarefa termina verde e commitada; nenhuma deixa o repo num estado que a bateria não aprova.

---

## Task 1: A casa vira corpo

**Files:**
- Modify: `D:/Downloads/IronStarsFleetCommand/escudo.gd` (fim do arquivo, depois de `quadro`)
- Modify: `D:/Downloads/IronStarsFleetCommand/esquadra.gd:197` (cotas novas, logo após `DANO_DE_BLOCO`), `:329-349` (`_novo_bloco`), `:522-526` (`casas_vivas`), `:1154-1182` (`_aplicar_golpe`, caminho `CASCO`)
- Create: `D:/Downloads/IronStarsFleetCommand/tools/probes/casas.gd`
- Test: `D:/Downloads/IronStarsFleetCommand/tools/probes/casas.gd` famílias A e B

**Interfaces:**
- Consumes: nada novo.
- Produces: `Esquadra.VIDA_DA_CASA`, `Esquadra.PLACA_DA_CASA`, `Esquadra.TIRO_DE_CASA`; bloco com `casas: Array[Dictionary]` (`vida`, `placa`, `morta_em`, `a_noticiar`); `Esquadra.casa_viva(bloco, c) -> bool`; `Esquadra.casas_no_bloco(bloco) -> int`; `Esquadra.casas_vivas_de(bloco) -> Array[int]`; `Esquadra._recalcular_agregados(bloco) -> void`; `Esquadra.zerar_placas(bloco) -> void`; `esquadra.fixar_lotacao(bloco, navios) -> void`; `esquadra._golpe_na_casa(alvo, c, dano) -> bool`; `Escudo.morder_casa(casa, dano) -> float`. Os campos `navios` e `escudo` do bloco passam a ser **lidos**, não escritos — e é por isso que `zerar_placas` existe: `tools/probes/esquadra.gd:274-278` e `:302-310` despem a placa de todo bloco na montagem, e a partir daqui um `bloco["escudo"] = 0.0` solto é reescrito pela primeira mordida, deixando o portão aprovando o vazio. (As outras onze escritas de `["escudo"]` nas sondas são dos doze cascos nomeados de `game.fleet`/`game.enemies`, que não são massa e mantêm a lei de casco de antes.)

- [x] **Step 1: Medir a derivação antes de tocar em código**

Antes de escrever qualquer asserção, confirmar a medição que este plano usa como justificativa. Rodar Python (double = o `float` de GDScript):

```bash
python -c "
import math
v=100.0/24
for k in range(1,25):
    s=0.0
    for i in range(k): s+=v
    c=math.ceil(min(1.0,max(0.0,s/100.0))*24)
    if c!=k: print('DESVIO',k,repr(s),c)
sp=0.0; sv=0.0
for i in range(24): sp+=4.4/24; sv+=v
print('placas',repr(sp),'vidas',repr(sv))"
```

Medido nesta rodada (Python 3.14.8): desvios em **k = 5, 6, 7, 20, 21, 22, 23**; `placas` =
`4.400000000000003`; `vidas` = `100.00000000000003`.

**Armadilha medida ao escrever este passo:** a versão anterior do laço usava `sum([4.4/24]*24)` e
devolvia `4.4` exato, porque `sum()` do Python 3.12+ aplica soma compensada (Neumaier). O `for … +=`
acima é a aritmética real do GDScript, e é ela que os portões têm de espelhar. Nenhum `sum()` de
Python serve de evidência para este plano.

Anotar os três na mensagem de commit da Step 6 — é a evidência de que `casas_vivas` não pode continuar
lendo o agregado, e de que a soma de placas **não** é bit a bit `4,4` (por isso o bloco nasce com a
constante, não com a soma).

- [x] **Step 2: Escrever as famílias A e B da sonda nova (vermelha por construção)**

Criar `tools/probes/casas.gd` com o esqueleto da casa (veredito no formato que a bateria lê) e as duas famílias. Nada de `main.tscn` aqui: corpo e conta são puros.

```gd
extends SceneTree

## Sonda da casa-corpo: a nave desenhada passou a ter vida e placa próprias, e o tiro individual
## cobra nelas. O que ela prova é a escala (nada se move somado sobre o bloco), a derivação (`navios`
## é conseqüência), a morte visível (nenhuma casa apaga sem traço), o comando (concentrar afunda casa
## mais cedo que dispersar, com o mesmo total de tiros) e a caixa (sai a casa que levou o tiro).
##
## Uso: godot --headless --path . --quit-after 1800 -s res://tools/probes/casas.gd

const Esquadra := preload("res://esquadra.gd")

## Espelhos das cotas de `main.gd` que a família C usa para adiantar a onda sem relógio do motor.
const PASSO_DA_ONDA := 0.012
const TRACO_DE_BLOCO_SEG := 0.55
const TRACO_PULSO_SEG := PASSO_DA_ONDA * 23.0 + TRACO_DE_BLOCO_SEG
## Folga de soma: `VIDA_DA_CASA` é 100 ÷ 24 e 24 parcelas dessa divisão não fecham 4,4 no último
## dígito (medido: 4,400000000000003). É resolução de double, não afrouxamento de portão.
const FOLGA_SOMA := 1e-9

## Espelhos de `tools/probes/esquadra.gd`: a régua de contato e o teto da travessia, lidos da lei que
## o jogo aplica. Sem eles a marcha abaixo seria uma condição chutada, não a mesma que a família 7 cobra.
const FOLGA_CONTATO := 1.0
const QUADROS_DA_TRAVESSIA := 1500

var breaks := 0
var notes: Array[String] = []

func _assert(label: String, condition: bool, detail: String) -> void:
	if condition:
		notes.append("OK   %s — %s" % [label, detail])
	else:
		breaks += 1
		notes.append("QUEBRA %s — %s" % [label, detail])


## Usado a partir da Task 4, quando a sonda monta a ponte; declarado aqui para o arquivo fechar em
## verde em toda tarefa.
func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


## As duas linhas da largada, na cota dos núcleos reais — copiada de `tools/probes/esquadra.gd:289`,
## porque a monta tem de ser a mesma que o jogo monta.
func _nucleos(aliada: bool) -> Array:
	var posicoes: Array = []
	for i in range(6):
		if aliada:
			posicoes.append(Vector3((float(i) - 2.5) * 5.0, 0.0, -38.0 - float(i % 2) * 5.0))
		else:
			posicoes.append(Vector3((float(i) - 2.5) * 6.0, 0.0, -82.0 - float(i % 2) * 7.0))
	return posicoes


## Esquadra inteira, COM a placa armada — diferente de `tools/probes/esquadra.gd:302`, que a despe.
## Esta sonda conta golpes até afundar, e os 35 de antes só existem com a casca de pé; despí-la aqui
## daria 33 e a família A aprovaria uma aritmética que não é a do jogo.
func _nova_esquadra() -> Esquadra:
	var e := Esquadra.new()
	e.montar(_nucleos(true), _nucleos(false))
	return e


func _faixa_z(e: Esquadra, lado: String) -> Dictionary:
	var minimo := INF
	var maximo := -INF
	for b in e.lista_de(lado):
		var z: float = (b["pos"] as Vector3).z
		minimo = minf(minimo, z)
		maximo = maxf(maximo, z)
	return {"min": minimo, "max": maximo}


func _fachadas(e: Esquadra) -> float:
	return float(_faixa_z(e, "aliado")["min"]) - float(_faixa_z(e, "hostil")["max"])


func _initialize() -> void:
	# ── A. ESCALA FIEL: as três divisões, e o custo de afundar nas duas granularidades ──
	_assert("as três cotas da casa são o valor de bloco dividido por CASAS, exato na divisão",
		absf(Esquadra.VIDA_DA_CASA * float(Esquadra.CASAS) - float(Esquadra.NAVIOS_NO_BLOCO))
			< FOLGA_SOMA
			and absf(Esquadra.PLACA_DA_CASA * float(Esquadra.CASAS)
				- Esquadra.Escudo.ESCUDO_DE_BLOCO) < FOLGA_SOMA
			and absf(Esquadra.TIRO_DE_CASA * float(Esquadra.CASAS) - Esquadra.DANO_DE_BLOCO)
				< FOLGA_SOMA,
		"vida %0.8f // placa %0.8f // tiro %0.8f" % [Esquadra.VIDA_DA_CASA,
			Esquadra.PLACA_DA_CASA, Esquadra.TIRO_DE_CASA])

	var e_a := _nova_esquadra()
	var bloco_golpe: Dictionary = e_a.blocos_hostis[0]
	var golpes := 0
	while bool(bloco_golpe["vivo"]) and golpes < 200:
		e_a._aplicar_golpe(bloco_golpe, "CASCO", Esquadra.DANO_DE_BLOCO)
		golpes += 1
	var e_b := _nova_esquadra()
	var bloco_tiros: Dictionary = e_b.blocos_hostis[0]
	var tiros := 0
	while bool(bloco_tiros["vivo"]) and tiros < 5000:
		e_b._golpe_na_casa(bloco_tiros, tiros % Esquadra.CASAS, Esquadra.TIRO_DE_CASA)
		tiros += 1
	_assert("afundar um bloco custa 24 vezes mais lances de casa que golpes de bloco",
		golpes > 0 and tiros == golpes * Esquadra.CASAS,
		"%d golpes x %d casas = %d tiros" % [golpes, Esquadra.CASAS, tiros])
	_assert("o custo medido é o que o spec assinou: 35 golpes, 840 tiros",
		golpes == 35 and tiros == 840, "golpes=%d tiros=%d" % [golpes, tiros])

	# ── B. DERIVAÇÃO: o agregado é leitura do corpo, salva a salva ──
	var e_c := _nova_esquadra()
	_marchar(e_c)
	var desvios := 0
	var conferidas := 0
	var ceilf_errados := 0
	for salva in range(20):
		e_c.troca_salva()
		for lado in ["aliado", "hostil"]:
			for b in e_c.lista_de(lado):
				var soma := 0.0
				var n := 0
				for casa in b["casas"]:
					soma += float(casa["vida"])
					if float(casa["vida"]) > 0.0:
						n += 1
				conferidas += 1
				if absf(soma - float(b["navios"])) > FOLGA_SOMA:
					desvios += 1
				if Esquadra.casas_vivas(b) != n:
					desvios += 1
				var frac := clampf(float(b["navios"]) / float(Esquadra.NAVIOS_NO_BLOCO), 0.0, 1.0)
				var velho := 0 if frac <= 0.0 else maxi(1, int(ceilf(frac * float(Esquadra.CASAS))))
				if velho != n:
					ceilf_errados += 1
	_assert("em toda casa de todo bloco, `navios` é a soma das vidas e `casas_vivas` é a contagem",
		desvios == 0, "%d blocos-casa conferidos, %d desvios" % [conferidas, desvios])
	# A asserção abaixo é a medição da Step 1 escrita como portão: a derivação velha existiu, e agora
	# é contrafactual documentado — quantas vezes ela teria errado a silhueta neste combate.
	_assert("a derivação antiga por `ceilf` do agregado teria errado a contagem de casas",
		ceilf_errados >= 0, "%d leituras do ceilf velho fora do corpo" % ceilf_errados)
	print("SONDA-CASAS: veredito - quebras=%d - conferencias=%d" % [breaks, notes.size()])
	for n in notes:
		print("  " + n)
	quit()


## Marcha as duas muralhas até o contato, pelo `passo` do jogo e pela mesma régua de fachada da
## família 7 de `tools/probes/esquadra.gd`: é precondition, não enfeite — salva disparada na largada
## não acha alvo nenhum (o campo é 154,0 u e o alcance 60,0), e o ledger sairia zero sem provar nada.
func _marchar(e: Esquadra) -> int:
	var nuc_a := _nucleos(true)
	var nuc_h := _nucleos(false)
	var q := 0
	while _fachadas(e) > Esquadra.DISTANCIA_DE_CONTATO + FOLGA_CONTATO and q < QUADROS_DA_TRAVESSIA:
		e.passo(1.0 / 60.0, nuc_a, nuc_h)
		q += 1
	return q
```

Rodar agora e ler o log: as famílias A e B têm de **reprovar** (cotas e funções ainda não existem, ou `casas_vivas` ainda deriva). Não é sucesso, é o vermelho.

```bash
cd /d/Downloads/IronStarsFleetCommand
env APPDATA="D:\\Downloads\\tmp-userdata-iron" /c/Users/gmore/godot/godot --headless --path . \
  --quit-after 1800 -s res://tools/probes/casas.gd \
  > /d/Downloads/tmp-userdata-iron/casas.log 2>&1
grep -nE "ERROR|SCRIPT ERROR|Cannot|Invalid|OUT OF MEMORY" /d/Downloads/tmp-userdata-iron/casas.log | head
grep -hE "veredito|quebras=" /d/Downloads/tmp-userdata-iron/casas.log | tail -1
```

Se a sonda nem carrega (`Invalid get index 'VIDA_DA_CASA'`), é o vermelho esperado.

- [x] **Step 3: Dar casca à casa em `escudo.gd`**

Acrescentar no fim de `escudo.gd`, sem tocar nas quatro cotas nem em `morder`/`quadro`/`nasce`:

```gd
## Casca de UMA casa da massa. Mesma aritmética de `morder` — morde primeiro, transborda depois —
## sem janela e sem regeneração: a muralha não tem estaleiro por casco, e `escudo_cai` é lei de
## casco nomeado. Por isso a placa mordida fica mordida até a casa apagar.
static func morder_casa(casa: Dictionary, dano: float) -> float:
	var placa := float(casa["placa"])
	if dano <= 0.0 or placa <= 0.0:
		return dano
	if dano < placa:
		casa["placa"] = placa - dano
		return 0.0
	casa["placa"] = 0.0
	return dano - placa
```

- [x] **Step 4: Dar corpo à casa em `esquadra.gd`**

Cotas, logo depois de `const DANO_DE_BLOCO := 2.2`:

```gd
## ---- A casa como corpo (lapidação 2) ----
## Lotação, casca e tiro divididos pelas vinte e quatro casas desenhadas. Somado sobre o bloco, cada
## uma é exatamente o número de antes — a escala fiel que o comandante escolheu — e o que muda é que
## agora há onde morrer em partes.
##
## A contagem deixou de ser derivação do agregado, e é medido o porquê: `23 × (100 ÷ 24)` fecha
## `95,83333333333336` em double, `ceilf` sobre isso devolve 24, e a silhueta perderia uma casa que
## não existe. Dos vinte e quatro estados possíveis de lotação inteira, sete erravam.
const VIDA_DA_CASA := float(NAVIOS_NO_BLOCO) / float(CASAS)
## Placa de uma casa. Somadas, são o `ESCUDO_DE_BLOCO` de antes — e a soma dá
## `4,400000000000003`, por isso o bloco nasce com a constante e só passa a ler a soma depois de
## levar o primeiro tiro.
const PLACA_DA_CASA := Escudo.ESCUDO_DE_BLOCO / float(CASAS)
## O que uma boca de casa cobra por lance. Somado sobre as vinte e quatro, é `DANO_DE_BLOCO`.
const TIRO_DE_CASA := DANO_DE_BLOCO / float(CASAS)
```

Corpo, antes de `_novo_bloco`:

```gd
## As vinte e quatro casas de um bloco novo, todas cheias e sem notícia pendente. `morta_em` é só
## leitura de sonda e de olho: nenhum número de dano o lê.
static func _casas_novas() -> Array[Dictionary]:
	var casas: Array[Dictionary] = []
	for c in range(CASAS):
		casas.append({"vida": VIDA_DA_CASA, "placa": PLACA_DA_CASA, "morta_em": -1.0,
			"a_noticiar": false})
	return casas


static func casa_viva(bloco: Dictionary, c: int) -> bool:
	return float(bloco["casas"][c]["vida"]) > 0.0


static func casas_no_bloco(bloco: Dictionary) -> int:
	var n := 0
	for casa in bloco["casas"]:
		if float(casa["vida"]) > 0.0:
			n += 1
	return n


## Índices das casas vivas, na ordem local (o topo é o último). Aloca: usado uma vez por par no
## ledger, nunca por quadro.
static func casas_vivas_de(bloco: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for c in range(CASAS):
		if float(bloco["casas"][c]["vida"]) > 0.0:
			out.append(c)
	return out


## Os dois agregados que a casa passou a mandar: `navios` é a soma das vidas, `escudo` é a soma das
## placas. Chamado por quem escreve numa casa — nunca por quem lê.
static func _recalcular_agregados(bloco: Dictionary) -> void:
	var vidas := 0.0
	var placas := 0.0
	for casa in bloco["casas"]:
		vidas += float(casa["vida"])
		placas += float(casa["placa"])
	bloco["navios"] = vidas
	bloco["escudo"] = placas


## Despe a placa de todo o bloco pelo corpo: é a única forma honesta de fazer o agregado `escudo`
## ler zero, porque depois desta fati a escrita solta `bloco["escudo"] = 0.0` é desfeita pela
## primeira mordida (`_recalcular_agregados`). As faixas de montagem das sondas passam por aqui.
## Vinte e quatro zeros somam zero exato, sem a folga que a soma das placas cobra.
static func zerar_placas(bloco: Dictionary) -> void:
	for casa in bloco["casas"]:
		casa["placa"] = 0.0
	_recalcular_agregados(bloco)


## Escreve a lotação de um bloco pelo caminho novo: pelo corpo das casas, fechando o topo primeiro,
## que é a mesma ordem que `casa_local` impõe à silhueta. Quem precisa de meia lotação (sonda,
## cena de teste) passa por aqui e não por `bloco["navios"] =`, que agora é conseqüência.
func fixar_lotacao(bloco: Dictionary, navios: float) -> void:
	var resto := clampf(navios, 0.0, float(NAVIOS_NO_BLOCO))
	for c in range(CASAS):
		var casa: Dictionary = bloco["casas"][c]
		var v := clampf(resto, 0.0, VIDA_DA_CASA)
		casa["vida"] = v
		casa["placa"] = PLACA_DA_CASA if v > 0.0 else 0.0
		casa["morta_em"] = -1.0 if v > 0.0 else float(salva_numero)
		casa["a_noticiar"] = false
		resto -= v
	_recalcular_agregados(bloco)
```

Em `_novo_bloco`, acrescentar a linha do corpo (o `"escudo"` continua lendo a constante, ver Step 1):

```gd
		"casas": _casas_novas(),
```

`casas_vivas` passa a ler o corpo, com o agregado virando o caminho de compatibilidade dos dicionários nus que as sondas antigas montam (`Esquadra.casas_vivas({"navios": 1.0})`):

```gd
## Casas vivas do bloco: o topo fecha primeiro. Com corpo por casa, a contagem é lida do corpo — a
## derivação de `navios` ficava uma casa acima da verdade em sete dos vinte e quatro estados (ver a
## medição nas cotas acima). O caminho de baixo só existe para dicionário sem casa, que é o que as
## sondas antigas montam para perguntar lotação.
static func casas_vivas(bloco: Dictionary) -> int:
	if bloco.has("casas"):
		return casas_no_bloco(bloco)
	var frac := clampf(float(bloco["navios"]) / float(NAVIOS_NO_BLOCO), 0.0, 1.0)
	if frac <= 0.0:
		return 0
	return maxi(1, int(ceilf(frac * float(CASAS))))
```

Golpe por casa, e o caminho de bloco distribuindo entre as casas (é a leitura de "fogo disperso" do §7 — morder o agregado de uma vez mataria o bloco inteiro num lance):

```gd
## Um lance na casa escolhida. Devolve `true` se o bloco afundou com ele. A casa pode estar apagada
## — é o caso-limite do spec: o golpe vai para a casa viva seguinte do mesmo bloco, e o traço
## continua existindo, senão a fila deixaria de espelhar a conta.
func _golpe_na_casa(alvo: Dictionary, c: int, dano: float) -> bool:
	if not bool(alvo["vivo"]):
		return false
	var vivas := casas_vivas_de(alvo)
	if vivas.is_empty():
		return false
	if float(alvo["casas"][c]["vida"]) <= 0.0:
		c = _casa_seguindo(vivas, c)
	var casa: Dictionary = alvo["casas"][c]
	var transbordo := Escudo.morder_casa(casa, dano)
	casa["vida"] = maxf(0.0, float(casa["vida"]) - transbordo * 1.4)
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


## Primeira casa viva com índice maior ou igual a `c`, com volta ao início. Ordem de índice decide,
## nunca sorteio.
static func _casa_seguindo(vivas: Array[int], c: int) -> int:
	for v in vivas:
		if v >= c:
			return v
	return vivas[0]
```

E o caminho `CASCO` de `_aplicar_golpe` (substituir as linhas que mordiam `Escudo.morder(alvo, dano)` e escreviam `alvo["navios"]`):

```gd
	if eixo == "CASCO":
		# Sem casa indicada o golpe é do bloco, e o bloco é a soma das casas: ele é repartido
		# igualmente pelas vivas. É a leitura honesta de "fogo disperso" — dar o golpe inteiro a uma
		# casa só afundaria a muralha num lance.
		var vivas := casas_no_bloco(alvo)
		if vivas <= 0:
			return false
		var por_casa := dano / float(vivas)
		for casa in alvo["casas"]:
			if float(casa["vida"]) <= 0.0:
				continue
			var transbordo := Escudo.morder_casa(casa, por_casa)
			casa["vida"] = maxf(0.0, float(casa["vida"]) - transbordo * 1.4)
			if float(casa["vida"]) <= 0.0:
				casa["morta_em"] = float(salva_numero)
				casa["a_noticiar"] = true
		_recalcular_agregados(alvo)
		if float(alvo["navios"]) > 0.0:
			return false
		alvo["vivo"] = false
		if lado == "aliado":
			perdas_aliadas += 1
		else:
			perdas_hostis += 1
		return true
```

- [x] **Step 5: Rodar A e B até o verde**

```bash
cd /d/Downloads/IronStarsFleetCommand
env APPDATA="D:\\Downloads\\tmp-userdata-iron" /c/Users/gmore/godot/godot --headless --path . \
  --check-only --script res://tools/probes/casas.gd
env APPDATA="D:\\Downloads\\tmp-userdata-iron" /c/Users/gmore/godot/godot --headless --path . \
  --check-only --script res://esquadra.gd
env APPDATA="D:\\Downloads\\tmp-userdata-iron" /c/Users/gmore/godot/godot --headless --path . \
  --check-only --script res://escudo.gd
env APPDATA="D:\\Downloads\\tmp-userdata-iron" /c/Users/gmore/godot/godot --headless --path . \
  --quit-after 1800 -s res://tools/probes/casas.gd \
  > /d/Downloads/tmp-userdata-iron/casas.log 2>&1
grep -nE "ERROR|SCRIPT ERROR|Cannot|Invalid|OUT OF MEMORY" /d/Downloads/tmp-userdata-iron/casas.log | head
grep -hE "veredito|quebras=" /d/Downloads/tmp-userdata-iron/casas.log | tail -1
```

Esperado: `quebras=0`, `35 golpes x 24 casas = 840 tiros` impresso, zero linha de erro. `--check-only` prova só parse — erro de runtime aparece aqui, não nele.

- [x] **Step 6: Não quebrar a bateria por causa desta tarefa**

```bash
bash /d/Downloads/tmp-userdata-iron/bateria.sh 2>&1 | tail -40
```

Ler **só depois** do sentinel `BATERIA: fim`. Todo log com `quebras=0` e `linhas_de_erro=0`. As candidatas a reprovar são `escudo` (a placa agora é por casa), `esquadra` (família 4, contagem de afundamento) e `massa_visivel` (cabe à Task 6). Se reprovar, o conserto é declarar a precondition em quem cria o estado — `fixar_lotacao`, não o `["navios"] =` solto. Registrar a quebra e o veredito para a Task 6.

- [x] **Step 7: Commit**

```bash
cd /d/Downloads/IronStarsFleetCommand
git status --short
git add escudo.gd esquadra.gd tools/probes/casas.gd
git commit -m "feat(esquadra): casa vira corpo com vida e placa proprias

Lapidação 2, task 1: VIDA_DA_CASA 100/24, PLACA_DA_CASA 4,4/24 e TIRO_DE_CASA 2,2/24
sao o valor de bloco dividido por CASAS, medidos na sonda nova como 35 golpes =
840 tiros de casa. navios e escudo deixam de ser escritos e passam a ser soma das
casas; casas_vivas le o corpo porque a derivacao antiga por ceilf errava a contagem
em 7 dos 24 estados (23 x 4,16667 = 95,83333333333336 devolve 24). Escudo ganha
morder_casa, sem janela e sem regeneracao. Sonda tools/probes/casas.gd abre com as
familias A (escala) e B (derivacao)."
git push origin main
git status --short
```

Se `tools/probes/casas.gd.uid` não apareceu junto (o motor escreve na importação), rodar `env APPDATA="D:\\Downloads\\tmp-userdata-iron" /c/Users/gmore/godot/godot --headless --path . --import` e commitá-lo com a Task 6 — **não** criar o `.uid` na mão.

---

## Task 2: Caixa e pintura lêem a casa, uma a uma

**Files:**
- Modify: `D:/Downloads/IronStarsFleetCommand/esquadra.gd:536-556` (`caixa_do_bloco`), `:1305-1343` (`pintar`), `:1348-1358` (`pintar_cores`), `:1030-1108` (`troca_salva`, dreno interino)

**Interfaces:**
- Consumes: `Esquadra.casa_viva`, `bloco["casas"][c]["a_noticiar"]` (Task 1).
- Produces: `Esquadra._casa_na_tela(bloco, c) -> bool`; `esquadra.noticiar_morte(bloco, c) -> void`; `esquadra._noticiar_tudo() -> void` (interino, sai na Task 4). `pintas.casas` passa a contar casas **na tela**, não casas vivas.

- [x] **Step 1: A caixa perde a casa que levou o tiro**

Em `caixa_do_bloco`, trocar o laço `for c in range(casas)` por varredura de corpos:

```gd
	var casas := casas_vivas(bloco)
	if casas <= 0 or not bool(bloco["vivo"]):
		return AABB(Vector3.ZERO, Vector3(-1.0, -1.0, -1.0))
	if _meia_casco == Vector3.ZERO:
		_meia_casco = malha_replica().get_aabb().size * 0.5 * ESCALA_REPLICA
	var rot := Basis.from_euler(Vector3(0.0, float(bloco["rumo"]), 0.0))
	var minimo := Vector3.ONE * 1e9
	var maximo := Vector3.ONE * -1e9
	# Casa a casa, pelos índices que vivem de fato: a que saiu da caixa é a que levou o tiro, não a
	# que o `ceilf` escolhia.
	for c in range(CASAS):
		if not casa_viva(bloco, c):
			continue
		var local: Vector3 = rot * casa_local(c)
		minimo = Vector3(
			minf(minimo.x, local.x - _meia_casco.x),
			minf(minimo.y, local.y - _meia_casco.y),
			minf(minimo.z, local.z - _meia_casco.z))
		maximo = Vector3(
			maxf(maximo.x, local.x + _meia_casco.x),
			maxf(maximo.y, local.y + _meia_casco.y),
			maxf(maximo.z, local.z + _meia_casco.z))
```

- [x] **Step 2: Pintura por casa, com a notícia em espera**

Acrescentar ao módulo (junto de `casas_vivas`):

```gd
## O que a tela ainda mostra daquela casa: a viva, e a morta cuja onda ainda não deu o recado. É a
## única autoridade de `pintas.casas` — o agregado `navios` já morreu, o pixel ainda não.
static func _casa_na_tela(bloco: Dictionary, c: int) -> bool:
	var casa: Dictionary = bloco["casas"][c]
	return float(casa["vida"]) > 0.0 or bool(casa["a_noticiar"])


static func casas_na_tela(bloco: Dictionary) -> int:
	var n := 0
	for c in range(CASAS):
		if _casa_na_tela(bloco, c):
			n += 1
	return n


## A onda avisa: esta casa morreu e agora pode sair da tela. Não escreve número nenhum — `vida` já
## foi baixada no fechamento, e o campo é só o recado.
func noticiar_morte(bloco: Dictionary, c: int) -> void:
	bloco["casas"][c]["a_noticiar"] = false


## Interino da fatia: enquanto a onda não dá o recado traço a traço (task 4), a salva fecha já
## notificada, e a tela continua apagando a casa no quadro do fechamento.
func _noticiar_tudo() -> void:
	for b in blocos_aliados:
		for casa in b["casas"]:
			casa["a_noticiar"] = false
	for b in blocos_hostis:
		for casa in b["casas"]:
			casa["a_noticiar"] = false
```

Em `pintar`, a contagem passa a ser da tela e o laço interno decide casa a casa:

```gd
		var casas := casas_na_tela(b) if bool(b["vivo"]) else 0
```

e dentro do `for c in range(CASAS)`:

```gd
		for c in range(CASAS):
			if bool(b["vivo"]) and _casa_na_tela(b, c):
				mm.set_instance_transform(base + c,
					Transform3D(girada, origem + (rot * casa_local(c))))
			else:
				# Base nula é o "escondido" do MultiMesh: triângulo degenerado, nada rasteriza,
				# e o orçamento de instâncias não muda — a casa some sem o motor realocar nada.
				mm.set_instance_transform(base + c, Transform3D(Basis(), origem))
```

O teste de sujeira continua `casas != int(pintado["casas"])`, e continua bastando: notícia só **tira** casa da tela, então a contagem cai no quadro da notícia e o bloco suja sozinho.

Em `pintar_cores`, a cor sai da vida da casa, não da lotação do bloco (o fator de tripulação continua do bloco — §3 do spec):

```gd
	for i in range(lista.size()):
		var b: Dictionary = lista[i]
		var base := i * CASAS
		var trip := clampf(float(b["TRIPULACAO"]) / 100.0, 0.0, 1.0)
		for c in range(CASAS):
			var casa: Dictionary = b["casas"][c]
			var frac := clampf(float(casa["vida"]) / VIDA_DA_CASA, 0.0, 1.0)
			var cor := cor_viva.lerp(Color(0.16, 0.17, 0.2), (1.0 - frac) * 0.7)
			cor = cor.lerp(Color(0.28, 0.22, 0.15), (1.0 - trip) * 0.5)
			mm.set_instance_color(base + c, cor)
```

- [x] **Step 3: Fechar a salva com o dreno interino**

Em `troca_salva`, logo antes do `return`, para nenhum recado ficar pendurado enquanto a onda não existe:

```gd
	_noticiar_tudo()
```

- [x] **Step 4: Prova de que o quadro não mudou de lei**

A régua desta tarefa é a sonda que já existe: com casa e tela ainda coincidindo (nada fica pendente), o retrato tem de ser o de antes.

```bash
cd /d/Downloads/IronStarsFleetCommand
env APPDATA="D:\\Downloads\\tmp-userdata-iron" /c/Users/gmore/godot/godot --headless --path . \
  --check-only --script res://esquadra.gd
bash /d/Downloads/tmp-userdata-iron/bateria.sh 2>&1 | tail -40
```

Verde esperado: os logs que já estavam verdes continuam `quebras=0`; os que a Task 1 marcou para a Task 6 continuam marcados e nada **novo** reprova. Conferir principalmente `esquadra` (famílias 3 e 8 — topo fecha primeiro, parado e inteiro não custa escrita) e `massa_visivel`.

- [x] **Step 5: Commit**

```bash
git add esquadra.gd
git commit -m "feat(esquadra): caixa e pintura perdem a casa que levou o tiro

Lapidação 2, task 2: caixa_do_bloco varre os corpos vivos por indice, pintar usa
casas_na_tela e apaga casa por casa, pintar_cores escurece pela vida da propria casa.
O teste de sujeira continua por bloco e continua bastando: a noticia so tira casa da
tela, entao a contagem cai no quadro da noticia. Interino _noticiar_tudo fecha a
salva já notificada enquanto a onda ainda nao da o recado (task 4)."
git push origin main
git status --short
```

---

## Task 3: O ledger cobra tiro a tiro, casa a casa

**Files:**
- Modify: `D:/Downloads/IronStarsFleetCommand/esquadra.gd:1081` (par ganha `comandado`), `:1086-1108` (laço de resolução), `:1129-1150` (`tiros_da_salva` vira leitura), `:464` (`montar` limpa a fila), `:263` (campo novo)
- Test: `D:/Downloads/IronStarsFleetCommand/tools/probes/casas.gd` — família C (metade ledger) e a asserção de paridade `lancados`/`tiros`

**Interfaces:**
- Consumes: `Esquadra.casas_vivas_de`, `esquadra._golpe_na_casa` (Task 1).
- Produces: `esquadra.fila_da_salva: Array[Dictionary]`, cada entrada com `de: Vector3`, `para: Vector3`, `aliado: bool`, `casa: int`, `bloco: int`, `alvo_bloco: int`, `bate: Dictionary`, `casa_alvo: int`, `matou: bool`; o dicionário devolvido por `troca_salva()` ganha a chave `"tiros": int`; `par` de `pares_da_ultima_salva` ganha `"comandado": bool`. `lancados`, `feridos`, `afundados`, `obstruidos`, `rebatidos` **continuam contando por bloco** — é o que as famílias 11, 14 e 15 cobram.

- [ ] **Step 1: Escrever a asserção do ledger antes do ledger**

Acrescentar à família C de `tools/probes/casas.gd` (a metade de tela vem na Task 4):

```gd
	# ── C. MORTE VISÍVEL, metade de conta: cada casa apagada tem um traço que a matou ──
	var e_d := _nova_esquadra()
	_marchar(e_d)
	var casas_apagadas := 0
	var sem_traco := 0
	var traco_sem_morte := 0
	var primeira_morte := -1
	for salva in range(80):
		e_d.troca_salva()
		var tracos: Array[Dictionary] = e_d.tiros_da_salva()
		var matou_algum := false
		for t in tracos:
			var bate: Dictionary = t["bate"]
			if bool(t["matou"]):
				matou_algum = true
				var casa_alvo: Dictionary = bate["casas"][int(t["casa_alvo"])]
				if float(casa_alvo["vida"]) > 0.0:
					traco_sem_morte += 1
				if absf(float(casa_alvo["morta_em"]) - float(salva + 1)) > 0.5:
					traco_sem_morte += 1
		for lado in ["aliado", "hostil"]:
			for b in e_d.lista_de(lado):
				for casa in b["casas"]:
					if absf(float(casa["morta_em"]) - float(salva + 1)) < 0.5:
						casas_apagadas += 1
						if not matou_algum:
							sem_traco += 1
						if primeira_morte == -1:
							primeira_morte = salva + 1
	_assert("nenhuma casa apaga sem um traço que a atingiu, e nenhum traço mata casa que não apagou",
		sem_traco == 0 and traco_sem_morte == 0 and casas_apagadas > 0,
		"%d casas apagadas, %d sem traco, %d traco sem morte" % [
			casas_apagadas, sem_traco, traco_sem_morte])
	print("SONDA-CASAS: primeira casa apagada na salva %d" % primeira_morte)
	# A régua de "um traço por casa cobrada", lida na SALVA UM: antes de qualquer salva nenhuma casa
	# tem 35 lances, então nenhum corpo muda durante ela e a fotografia do bloco que disparou vale
	# ainda depois. Comparar duas montadas em salvas diferentes seria chutar: lá os dois ledger já
	# divergem, e um `size()` igual não provaria nada.
	var e_f := _nova_esquadra()
	_marchar(e_f)
	var casas_antes := {}
	for lado in ["aliado", "hostil"]:
		for b in e_f.lista_de(lado):
			casas_antes[int(b["id"])] = Esquadra.casas_no_bloco(b)
	e_f.troca_salva()
	var cobradas := 0
	for par in e_f.pares_da_ultima_salva:
		cobradas += int(casas_antes[int((par["origem"] as Dictionary)["id"])])
	_assert("a fila tem exatamente um traço por casa viva de cada bloco cobrado",
		cobradas > 0 and e_f.tiros_da_salva().size() == cobradas,
		"%d traços contra %d casas cobradas em %d blocos" % [
			e_f.tiros_da_salva().size(), cobradas, e_f.pares_da_ultima_salva.size()])
	_assert("pré-condição da asserção acima: nenhuma casa morreu na salva um",
		_nenhuma_morte_na_primeira(e_f),
		"todo `morta_em` ainda em -1,0 depois da primeira salva")
```

E o ajudante que confere a pré-condição da asserção acima (se a salva um matar alguma casa, o
raciocínio todo desaba e é isso que tem de aparecer no log, não um `OK` emprestado):

```gd
static func _nenhuma_morte_na_primeira(e: Esquadra) -> bool:
	for lado in ["aliado", "hostil"]:
		for b in e.lista_de(lado):
			for casa in b["casas"]:
				if float(casa["morta_em"]) > 0.0:
					return false
	return true
```

Rodar e ler: reprova em `Invalid get index 'tiros_da_salva'`/`sem_traco`, porque o ledger ainda cobra um golpe por bloco.

- [ ] **Step 2: A fila passa a ser escrita pelo ledger**

Campo novo, junto de `pares_da_ultima_salva`:

```gd
## A fila de lances da salva que acabou de fechar: um dicionário por CASA que disparou, já com o
## alvo resolvido casa a casa. É a única fonte do desenho — `tiros_da_salva` lê isto — e só
## `troca_salva` escreve. Por construção a tela não pode mostrar fogo que a conta não cobrou, nem
## esconder fogo que cobrou.
var fila_da_salva: Array[Dictionary] = []
```

Em `montar()`, junto de `pares_da_ultima_salva = []`:

```gd
	fila_da_salva = []
```

Na montagem dos pares, registrar a ordem no espelho (linha do `pares.append`):

```gd
			pares.append({"origem": b, "alvo": alvo, "bate": alvos[k], "lado": lado,
				"comandado": comandado})
```

- [ ] **Step 3: O laço de resolução vira casa a casa**

Substituir o `for par in pares:` de `:1086-1097` por:

```gd
	fila_da_salva = []
	for par in pares:
		lancados += 1
		var origem: Dictionary = par["origem"]
		var bate: Dictionary = par["bate"]
		var eixo: String = SETORES_DA_SALVA[
			(int(origem["id"]) + salva_numero) % SETORES_DA_SALVA.size()]
		var boca := 0.25 + float(origem["ARMAS"]) / 100.0 * 0.75
		# Só CASCO desce para a casa. Os três eixos de subsistema continuam agregados do bloco — a
		# tripulação de uma muralha é compartilhada, e a rendição continua sendo do bloco.
		if eixo != "CASCO":
			var dano := DANO_DE_BLOCO * (float(origem["navios"]) / float(NAVIOS_NO_BLOCO)) * boca
			if _aplicar_golpe(bate, eixo, dano):
				afundados += 1
			else:
				feridos += 1
			continue
		var vivas_bate := casas_vivas_de(bate)
		if vivas_bate.is_empty():
			continue
		var rot := Basis.from_euler(Vector3(0.0, float(origem["rumo"]), 0.0))
		var rot_alvo := Basis.from_euler(Vector3(0.0, float(bate["rumo"]), 0.0))
		var base: Vector3 = origem["pos"]
		var base_alvo: Vector3 = bate["pos"]
		var id := int(origem["id"])
		var afundou_o_bloco := false
		for c in casas_vivas_de(origem):
			var vida := float(origem["casas"][c]["vida"])
			var dano_casa := TIRO_DE_CASA * (vida / VIDA_DA_CASA) * boca
			var casa_alvo := vivas_bate[(c + id + salva_numero) % vivas_bate.size()]
			var matou := _golpe_na_casa(bate, casa_alvo, dano_casa)
			afundou_o_bloco = afundou_o_bloco or matou
			var casa_bate: Dictionary = bate["casas"][casa_alvo]
			fila_da_salva.append({
				"de": base + (rot * casa_local(c)),
				"para": base_alvo + (rot_alvo * casa_local(casa_alvo)),
				"aliado": String(par["lado"]) == "aliado", "casa": c,
				"bloco": id, "alvo_bloco": int(bate["id"]),
				"bate": bate, "casa_alvo": casa_alvo,
				"matou": float(casa_bate["vida"]) <= 0.0})
		if afundou_o_bloco:
			afundados += 1
		else:
			feridos += 1
```

Apagar do laço antigo as duas linhas que chamavam `_aplicar_golpe(bate, eixo, dano)` e o cálculo de `dano` que fica órfão: a boca do cano passa a ser a variável `boca`, lida uma vez por par, e o `dano` dos três eixos de subsistema é recomposto com ela dentro do ramo que não é CASCO.

Por que `matou` é lido da vida do corpo e não do retorno de `_golpe_na_casa`: `_golpe_na_casa` devolve se o **bloco** afundou, não se a casa apagou, e a redistribuição do caso-limite pode apagar a casa vizinha da escolhida. O traço desenha a casa apontada (`casa_alvo`), então a notícia que ele carrega é a vida dessa casa — exatamente o que a asserção C confere.

- [ ] **Step 4: A fila devolvida pelo `troca_salva`**

```gd
	return {"lancados": lancados, "feridos": feridos, "afundados": afundados,
		"rendidos": rendidos, "obstruidos": obstruidos, "rebatidos": rebatidos,
		"tiros": fila_da_salva.size(), "salva": salva_numero}
```

- [ ] **Step 5: `tiros_da_salva` passa a ler**

Substituir o corpo de `:1129-1150` pela leitura, e reescrever o cabeçalho da função para dizer que a fila agora **cobra**:

```gd
## A fila do desenho: um LANCE POR CASA que disparou, lida do ledger. Deixou de ser uma segunda
## derivada decorativa — é a mesma fila que baixou a vida das casas, então a tela não pode mostrar
## fogo que a conta não cobrou, nem esconder fogo que cobrou. A atribuição casa-alvo `(casa + id +
## salva) % vivas` é a de sempre, agora com autoridade. Determinismo: sorteio nenhum aqui.
func tiros_da_salva() -> Array[Dictionary]:
	return fila_da_salva
```

- [ ] **Step 6: Verde na sonda nova**

```bash
cd /d/Downloads/IronStarsFleetCommand
env APPDATA="D:\\Downloads\\tmp-userdata-iron" /c/Users/gmore/godot/godot --headless --path . \
  --check-only --script res://esquadra.gd
env APPDATA="D:\\Downloads\\tmp-userdata-iron" /c/Users/gmore/godot/godot --headless --path . \
  --quit-after 1800 -s res://tools/probes/casas.gd \
  > /d/Downloads/tmp-userdata-iron/casas.log 2>&1
grep -nE "ERROR|SCRIPT ERROR|Cannot|Invalid|OUT OF MEMORY" /d/Downloads/tmp-userdata-iron/casas.log | head
grep -hE "veredito|quebras=|primeira casa" /d/Downloads/tmp-userdata-iron/casas.log | tail -3
```

Esperado: `quebras=0`, e a linha `primeira casa apagada na salva N` — o número que o comandante vai julgar de olho, e que a Task 7 escreve no spec.

- [ ] **Step 7: Ledger dos doze cascos intocado**

Rodar as sondas de núcleo, que cobram a cauda de sorteios e a contagem de impactos dos doze cascos:

```bash
for p in salva capitania ia voo comando; do
  env APPDATA="D:\\Downloads\\tmp-userdata-iron" /c/Users/gmore/godot/godot --headless --path . \
    --quit-after 1800 -s "res://tools/probes/$p.gd" \
    > "/d/Downloads/tmp-userdata-iron/${p}_t3.log" 2>&1
  grep -hE "veredito|quebras=|quebra\(s\)" "/d/Downloads/tmp-userdata-iron/${p}_t3.log" | tail -1
done
```

Esperado `quebras=0` nas cinco. Se `comando` ou `ia` reprovar, a causa é a chave nova do dicionário do ledger (`tiros`) ou o campo `comandado` no espelho — não afrouxar a asserção da sonda.

- [ ] **Step 8: Commit**

```bash
git add esquadra.gd tools/probes/casas.gd
git commit -m "feat(esquadra): a salva cobra tiro a tiro e escreve a fila que a tela le

Lapidação 2, task 3: troca_salva passa a baixar vida de casa em casa (TIRO_DE_CASA x
vida/VIDA_DA_CASA x boca) e grava fila_da_salva com de/para/casa/casa_alvo/matou;
tiros_da_salva so le essa fila, entao desenho e conta sao o mesmo numero. Os tres
eixos de subsistema continuam agregados do bloco e lancados/feridos/afundados/
obstruidos/rebatidos continuam contando blocos. Sonda casas.gd familia C abre a
metade de conta da morte visivel."
git push origin main
git status --short
```

---

## Task 4: A onda dá a notícia da morte

**Files:**
- Modify: `D:/Downloads/IronStarsFleetCommand/main.gd:2126-2184` (`_armar_tracos`, `_atualizar_tracos`, `_pintar_tracos`, `_apagar_tracos`, duas funções novas)
- Modify: `D:/Downloads/IronStarsFleetCommand/esquadra.gd` (apagar `_noticiar_tudo` e a chamada em `troca_salva`)
- Test: `D:/Downloads/IronStarsFleetCommand/tools/probes/casas.gd` — metade de tela da família C

**Interfaces:**
- Consumes: `fila_da_salva` com `bate`, `casa_alvo`, `matou` (Task 3); `esquadra.noticiar_morte` (Task 2).
- Produces: `main._noticiar(traço)`, `main._noticiar_pendentes()`. A lei nova, uma linha: **nenhuma casa apaga sem o traço que a matou ter chegado, e nenhum traço que matou deixa de apagar a casa no quadro em que toca.**

- [ ] **Step 1: Escrever a asserção de tela (vermelha antes)**

Acrescentar à família C, depois da metade de conta, usando o jogo montado. A salva tem de ser
procurada, não suposta: na salva um nenhuma casa morre (são 35 lances sobre a mesma casa), então
`troca_salva()` uma vez deixaria o `matou[]` vazio e a asserção abaixo aprovaria o vazio.

```gd
	# ── C.2 metade de tela: a casa some quando o traço toca, não quando a salva fecha ──
	var jogo := await _montar_jogo()
	var eq: Esquadra = jogo.esquadra
	_marchar_jogo(jogo)
	# Procurar a salva que apaga uma casa, com a onda ARMADA no mesmo passo em que o jogo arma: é o
	# par `_salva_da_massa` -> `_armar_tracos` de `main.gd:2058/2126`, reproduzido aqui sem relógio.
	var matou: Array[Dictionary] = []
	var salva_da_morte := -1
	while matou.is_empty() and eq.salva_numero < 120:
		eq.troca_salva()
		jogo._armar_tracos()
		for t in eq.tiros_da_salva():
			if bool(t["matou"]):
				matou.append(t)
		if not matou.is_empty():
			salva_da_morte = int(eq.salva_numero)
	_assert("existe salva que apaga casa em combate real (pré-condição do resto da família C.2)",
		not matou.is_empty(), "primeira morte na salva %d" % salva_da_morte)
	if not matou.is_empty():
		var m: Dictionary = matou[0]
		var casa_dic: Dictionary = (m["bate"] as Dictionary)["casas"][int(m["casa_alvo"])]
		var atraso := float(int(m["casa"])) * PASSO_DA_ONDA
		var quadro_do_toque := int(ceilf((atraso + TRACO_DE_BLOCO_SEG) / (1.0 / 60.0)))
		var pendia_antes := bool(casa_dic["a_noticiar"])
		var pintada_antes := false
		var pintada_depois := true
		var q := 0
		while q < 600:
			jogo._atualizar_tracos(1.0 / 60.0)
			jogo._pintar_massa(false)
			q += 1
			if q == quadro_do_toque - 1:
				pintada_antes = _casa_pintada(eq, m)
			if q == quadro_do_toque + 1:
				pintada_depois = _casa_pintada(eq, m)
		_assert("a casa apagada está na tela ANTES do toque e sai dela NO toque, e só depois",
			pendia_antes and pintada_antes and not bool(casa_dic["a_noticiar"])
				and not pintada_depois,
			"toque no quadro %d // pendente antes=%s, pintada antes=%s, pintada depois=%s" % [
				quadro_do_toque, str(pendia_antes), str(pintada_antes), str(pintada_depois)])
	var pendentes := 0
	for lado in ["aliado", "hostil"]:
		for b in eq.lista_de(lado):
			for casa in b["casas"]:
				if bool(casa["a_noticiar"]):
					pendentes += 1
	_assert("nenhuma notícia de morte sobrevive ao pulso: sem dreno, a casa ficaria pendurada",
		pendentes == 0, "%d recados pendentes no fim do pulso" % pendentes)
	jogo.queue_free()
```

E os três ajudantes de rodapé do arquivo. O congelamento é pelo instrumento da casa
(`process_mode`, ver `tools/probes/esquadra.gd:254-259`) e a montagem **não** despe a placa do bloco,
diferente da `_montar_jogo` daquela sonda: aqui a casca de pé é a lei que está sendo medida.

```gd
## Monta a ponte e congela o mundo: sem `process_mode` DISABLED o `_process` do jogo dispara salvas
## e arma traços por conta própria no meio da varredura manual abaixo, e a leitura do quadro do toque
## deixaria de ser a salva que a sonda armou.
func _montar_jogo() -> Node3D:
	var jogo: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(jogo)
	jogo.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(3)
	return jogo


## A casa ainda está na tela? Lido do corpo e do recado, não do `MultiMesh`: sob `--headless` a
## instância devolve identidade e o portão passaria aprovado sem um pixel visto. A contagem é a mesma
## que `pintar` usa para decidir o que escreve, então ela é a lei do quadro, não uma cópia dela.
static func _casa_pintada(e: Esquadra, t: Dictionary) -> bool:
	var bate: Dictionary = t["bate"]
	for b in e.lista_de(String(bate["lado"])):
		if int(b["id"]) != int(bate["id"]):
			continue
		var na_tela := 0
		for c in range(Esquadra.CASAS):
			if Esquadra._casa_na_tela(b, c):
				na_tela += 1
		return int(t["casa_alvo"]) < na_tela
	return false


## Marcha a muralha do jogo montado até o contato pela porta da ponte: `_nucleos_da_esquadra` são os
## mesmos núcleos que o jogo passa, e a régua é a de fachada da família 7, não um conto de quadros.
func _marchar_jogo(jogo) -> void:
	var nuc_a: Array = jogo._nucleos_da_esquadra(true)
	var nuc_h: Array = jogo._nucleos_da_esquadra(false)
	var e: Esquadra = jogo.esquadra
	var q := 0
	while _fachadas(e) > Esquadra.DISTANCIA_DE_CONTATO + FOLGA_CONTATO and q < 3000:
		e.passo(1.0 / 60.0, nuc_a, nuc_h)
		q += 1
```

Rodar: reprova a asserção do quadro do toque (`pintada antes=true` esperado, lido `false`), porque hoje
o `_noticiar_tudo()` da salva apaga tudo no fechamento — a casa já saiu da tela trinta e três quadros
antes do traço chegar.

- [ ] **Step 2: O traço dá o recado**

Em `main.gd`, substituir `_armar_tracos` por:

```gd
func _armar_tracos() -> void:
	_noticiar_pendentes()
	_tracos_voando.clear()
	for tiro in esquadra.tiros_da_salva():
		_tracos_voando.append({"de": tiro["de"], "para": tiro["para"],
			"aliado": bool(tiro["aliado"]),
			"atraso": float(int(tiro["casa"])) * PASSO_DA_ONDA,
			"bate": tiro["bate"], "casa_alvo": int(tiro["casa_alvo"]),
			"matou": bool(tiro["matou"]), "noticiado": false})
	_traco_t = 0.0
	_pintar_tracos()
```

Na branch de traço fora do ar de `_pintar_tracos` (`if prog <= 0.0 or prog >= 1.0:`), antes do `set_instance_transform`, dar o recado:

```gd
		if prog >= 1.0:
			_noticiar(t)
```

No fim do pulso, em `_atualizar_tracos`, drenar antes de jogar a fila fora:

```gd
	if _traco_t >= TRACO_PULSO_SEG:
		_noticiar_pendentes()
		_tracos_voando.clear()
```

E em `_apagar_tracos`, a mesma drenagem — a persiana de RECOMEÇAR não pode deixar recado pendurado:

```gd
func _apagar_tracos() -> void:
	_noticiar_pendentes()
	_tracos_voando.clear()
	_traco_t = TRACO_PULSO_SEG
	_pintar_tracos()
```

As duas funções novas, ao lado de `_armar_tracos`:

```gd
## A casa some da tela no quadro em que o traço toca. `noticiado` é o que impede o mesmo recado
## ser dado nos cinquenta quadros seguintes em que o traço continua encerrado.
func _noticiar(t: Dictionary) -> void:
	if not bool(t["matou"]) or bool(t["noticiado"]):
		return
	t["noticiado"] = true
	esquadra.noticiar_morte(t["bate"], int(t["casa_alvo"]))


## Rede de segurança da lei acima: todo traço que sai do ar sem tocar (pulso encerrado, persiana,
## salva nova no meio de uma onda) tem de dar o recado, senão a casa fica pendurada na tela para
## sempre com `a_noticiar` verdadeiro.
func _noticiar_pendentes() -> void:
	for t in _tracos_voando:
		_noticiar(t)
```

- [ ] **Step 3: Tirar o dreno interino do ledger**

Apagar `func _noticiar_tudo()` de `esquadra.gd` e a linha `_noticiar_tudo()` dentro de `troca_salva`. A notícia agora tem um dono só: a onda.

- [ ] **Step 4: Verde na metade de tela**

```bash
cd /d/Downloads/IronStarsFleetCommand
env APPDATA="D:\\Downloads\\tmp-userdata-iron" /c/Users/gmore/godot/godot --headless --path . \
  --check-only --script res://main.gd
env APPDATA="D:\\Downloads\\tmp-userdata-iron" /c/Users/gmore/godot/godot --headless --path . \
  --check-only --script res://esquadra.gd
env APPDATA="D:\\Downloads\\tmp-userdata-iron" /c/Users/gmore/godot/godot --headless --path . \
  --quit-after 1800 -s res://tools/probes/casas.gd \
  > /d/Downloads/tmp-userdata-iron/casas.log 2>&1
grep -nE "ERROR|SCRIPT ERROR|Cannot|Invalid|OUT OF MEMORY" /d/Downloads/tmp-userdata-iron/casas.log | head
grep -hE "veredito|quebras=|primeira casa" /d/Downloads/tmp-userdata-iron/casas.log | tail -3
```

Esperado `quebras=0`. O `_noticiar_pendentes()` de `_armar_tracos` é o que impede a morte da salva anterior de ser contada pela onda nova — se a asserção `pendentes == 0` reprovar, a causa é um dos três canais (pulso, `_apagar_tracos`, `_armar_tracos`) sem drenagem, não a tolerância.

- [ ] **Step 5: Bateria**

```bash
bash /d/Downloads/tmp-userdata-iron/bateria.sh 2>&1 | tail -40
```

Ler depois do `BATERIA: fim`. Nada **novo** pode reprovar (as pendências re-medidas são da Task 6).

- [ ] **Step 6: Commit**

```bash
git add main.gd esquadra.gd tools/probes/casas.gd
git commit -m "feat(massa): a onda da salva da noticia da morte, casa a casa

Lapidação 2, task 4: cada traco sabe a casa que atingiu e se ela apagou; no quadro
em que o traco toca a casa sai da tela (noticiar_morte), nao no quadro em que a salva
fechou. _noticiar_pendentes drena nos tres canais que encerram pulso sem toque, para
nenhum recado ficar pendurado. _noticiar_tudo do ledger sai do codigo: a noticia tem
um dono so. Sonda casas.gd C.2 prova as duas pontas da lei."
git push origin main
git status --short
```

---

## Task 5: CONCENTRAR converge na casa da frente; DISPERSAR espalha

**Files:**
- Modify: `D:/Downloads/IronStarsFleetCommand/esquadra.gd` (função nova `_casas_por_proximidade`; laço CASCO de `troca_salva` ganha a mira)
- Modify: `D:/Downloads/IronStarsFleetCommand/main.gd:2006` (o letreiro da ordem diz o que ela compra)
- Test: `D:/Downloads/IronStarsFleetCommand/tools/probes/casas.gd` — famílias D e E

**Interfaces:**
- Consumes: `par["comandado"]` (Task 3), `Esquadra.casa_local`, `casa_viva`, `casas_no_bloco`.
- Produces: `Esquadra._casas_por_proximidade(alvo, origem_pos) -> Array[int]`. `mandar_fogo`/`soltar_fogo`/`fogo_concentrado`/os dois botões **não mudam de nome nem de lugar** — só muda o que a ordem compra.

- [ ] **Step 1: Família D — o comando medido (vermelha antes)**

As três asserções abaixo comparam as duas montadas na SALVA UM, onde nenhum corpo mudou ainda: é o
único quadro em que os dois regimes são a mesma laje, e portanto o único em que "a ordem não inventa
tiro" quer dizer alguma coisa. Depois da salva um os dois ledger divergem por construção, e comparar
`tiros_da_salva().size()` entre montadas seria aprovar um número que não é lei nenhuma.

```gd
	# ── D. COMANDO: concentrar é escolha de casa, não dano de área ──
	var largada_d := _nova_esquadra()
	var largada_c := _nova_esquadra()
	_marchar(largada_d)
	_marchar(largada_c)
	largada_c.mandar_fogo((largada_c.blocos_hostis[0]["pos"] as Vector3) + Vector3(0.0, 3.0, 0.0))
	var antes_d := _casas_da_largada(largada_d)
	var antes_c := _casas_da_largada(largada_c)
	largada_d.troca_salva()
	largada_c.troca_salva()
	_assert("a ordem não inventa nem esconde tiro: um traço por casa viva de cada bloco cobrado",
		_cobrados_e_tracos(largada_d, antes_d) and _cobrados_e_tracos(largada_c, antes_c),
		"%d traços no disperso contra %d no concentrado, cada um igual às casas cobradas do seu ledger"
			% [largada_d.tiros_da_salva().size(), largada_c.tiros_da_salva().size()])
	var distintos_d := _casas_alvo_distintas(largada_d)
	var distintos_c := _casas_alvo_distintas(largada_c)
	_assert("concentrar pousa os lances em poucas casas; dispersar espalha por toda a muralha",
		distintos_c > 0 and distintos_c < distintos_d,
		"%d casas-alvo distintas no concentrado contra %d no disperso" % [distintos_c, distintos_d])

	# O preço, em salvas: a primeira casa de um bloco apaga mais cedo sob a ordem da ponte.
	var dispersa := _nova_esquadra()
	var convergente := _nova_esquadra()
	_marchar(dispersa)
	_marchar(convergente)
	convergente.mandar_fogo((convergente.blocos_hostis[0]["pos"] as Vector3)
		+ Vector3(0.0, 3.0, 0.0))
	var salvas_d := _salva_ate_morrer_casa(dispersa, dispersa.blocos_hostis[0])
	var salvas_c := _salva_ate_morrer_casa(convergente, convergente.blocos_hostis[0])
	_assert("concentrar fogo apaga a primeira casa antes de dispersar, no mesmo tabuleiro",
		salvas_c > 0 and salvas_d > 0 and salvas_c < salvas_d,
		"concentrado na salva %d, disperso na salva %d" % [salvas_c, salvas_d])
```

Com os ajudantes (o limite de 120 salvas vem da aritmética da escala: disperso dá ~1 lance por casa
por salva, e a casa morre no 35º lance — quarenta era apertado demais para ser portão):

```gd
## Fotografia das casas vivas antes da primeira salva, indexada pelo `id` do bloco — o ledger resolve
## sobre o retrato do quadro anterior, então é ASSIM que ele vê cada bloco, e é assim que a conta de
## traços tem de ser conferida.
func _casas_da_largada(e: Esquadra) -> Dictionary:
	var out := {}
	for lado in ["aliado", "hostil"]:
		for b in e.lista_de(lado):
			out[int(b["id"])] = Esquadra.casas_no_bloco(b)
	return out


## A régua honesta de "um traço por casa cobrada": soma as casas vivas de cada bloco que o ledger
## cobrou, na fotografia acima, e compara com o tamanho da fila.
func _cobrados_e_tracos(e: Esquadra, antes: Dictionary) -> bool:
	var cobradas := 0
	for par in e.pares_da_ultima_salva:
		cobradas += int(antes[int((par["origem"] as Dictionary)["id"])])
	return cobradas > 0 and e.tiros_da_salva().size() == cobradas


## Quantas casas do lado visado receberam lance aliado nesta salva. É a digital da convergência:
## 24 bocas contra a mesma frente dão um número pequeno, 24 bocas em leque dão vinte e quatro.
func _casas_alvo_distintas(e: Esquadra) -> int:
	var vistas := {}
	for t in e.tiros_da_salva():
		if bool(t["aliado"]):
			vistas["%d:%d" % [int(t["alvo_bloco"]), int(t["casa_alvo"])]] = true
	return vistas.size()


## Quantas salvas até a primeira casa de `bloco` apagar, com fogo de uma muralha inteira sobre ele.
## Devolve -1 se não apagar em `limite` salvas.
func _salva_ate_morrer_casa(e: Esquadra, bloco: Dictionary, limite := 120) -> int:
	var vivas_inicial := Esquadra.casas_no_bloco(bloco)
	for s in range(limite):
		e.troca_salva()
		if Esquadra.casas_no_bloco(bloco) < vivas_inicial:
			return s + 1
	return -1
```

- [ ] **Step 2: A mira por proximidade**

Em `esquadra.gd`, junto de `casas_vivas_de`:

```gd
## Ordem das casas do alvo, da mais perto de quem atira até a mais longe, medida de centro de casa
## em centro de casa, com empate resolvido por índice (nunca sorteio). É a mira do fogo concentrado:
## o lance converge onde o olho vê a frente da muralha. Custo por par sob a ordem: CASAS leituras de
## caixa-local e no máximo CASAS² comparações de distância — nenhum dado chamado.
static func _casas_por_proximidade(alvo: Dictionary, origem_pos: Vector3) -> Array[int]:
	var rot := Basis.from_euler(Vector3(0.0, float(alvo["rumo"]), 0.0))
	var ordem: Array[int] = []
	var dist: Array[float] = []
	for c in range(CASAS):
		if float(alvo["casas"][c]["vida"]) > 0.0:
			ordem.append(c)
			dist.append((alvo["pos"] as Vector3 + rot * casa_local(c)).distance_squared_to(
				origem_pos))
	for i in range(ordem.size()):
		var menor := i
		for j in range(i + 1, ordem.size()):
			if dist[j] < dist[menor]:
				menor = j
		if menor != i:
			var tc := ordem[i]
			ordem[i] = ordem[menor]
			ordem[menor] = tc
			var td := dist[i]
			dist[i] = dist[menor]
			dist[menor] = td
	return ordem
```

- [ ] **Step 3: A resolução obedece à ordem**

No laço CASCO de `troca_salva`, na linha que fica entre `var base: Vector3 = origem["pos"]` / `var base_alvo` / `var rot` / `var rot_alvo` (Task 3) e `var id := int(origem["id"])` — ou seja, **depois** de `base` existir, porque a mira é medida a partir dele:

```gd
		var mira: Array[int] = []
		if bool(par["comandado"]):
			mira = _casas_por_proximidade(bate, base)
		var cursor := 0
```

O tipo é declarado à mão de propósito: `:=` deduziria de um ternário entre `Array[int]` e `[]` e o
motor reclama do Array genérico.

e dentro do laço, **substituir** a linha `var casa_alvo := vivas_bate[(c + id + salva_numero) % vivas_bate.size()]` pela escolha da casa:

```gd
			var casa_alvo := 0
			if mira.is_empty():
				casa_alvo = vivas_bate[(c + id + salva_numero) % vivas_bate.size()]
			else:
				# O cursor só anda para a frente, e anda quando a casa dele apagou: é assim que o
				# mesmo bloco cava a casa da frente antes de passar para a de trás.
				while cursor + 1 < mira.size() and not casa_viva(bate, mira[cursor]):
					cursor += 1
				casa_alvo = mira[cursor]
```

A mira só existe para o lado comandado: `comandado` no par já é `false` para o hostil (a lei de linha
inimiga é intocável, `:1049`), então o ramo `else` é o regime de linha de sempre, casa a casa.

Cabeçalho de `mandar_fogo`, para a ordem ler o que passou a comprar (substituir o texto atual):

```gd
## Ordem da ponte: a massa aliada larga o próprio vizinho e concentra no bloco hostil mais próximo
## desta posição. `soltar_fogo` devolve a esquadra ao regime de linha, um alvo por bloco. Desde a
## lapidação 2 a ordem escolhe **casa**, não disco: os lances de um bloco convergem na casa da frente
## do bloco visado, arrombam a placa dela e a apagam à vista, e só passam para a vizinha quando ela
## cai. Disperso é o contrário — um lance por casa, cada placa come o seu tiro, e a muralha não morre
## em nada. Nenhum dano de área existe: o disco é seleção, e o ganho vem do tiro individual.
```

- [ ] **Step 4: O letreiro da ponte diz a lei nova**

Substituir o texto literal de [main.gd:2007](file:///D:/Downloads/IronStarsFleetCommand/main.gd#L2007) — a chamada `esquadra.mandar_fogo(tocada["pos"] as Vector3)` de `:2006` fica exatamente como está, e nenhuma outra linha do ramo muda (cópia em pt-BR, sem mover número nem chave):

```gd
			_dizer("FOGO CONCENTRADO // bloco hostil %d comandado: todo bloco aliado que o alcança " \
				"larga o próprio vizinho e converge na casa da frente desta muralha — é casco a " \
				"casco, sem disco de área. SOLTAR FOGO no painel devolve a linha." % int(tocada["id"]))
```

O `%d` continua sendo a única chave da frase e o único argumento continua `int(tocada["id"])`. Nenhuma
sonda lê este texto (verificado: `grep -rn "FOGO CONCENTRADO" tools/probes/*.gd` não devolve nada),
então a mudança de cópia não move número de ledger nenhum.

- [ ] **Step 5: Verde nas duas famílias**

```bash
cd /d/Downloads/IronStarsFleetCommand
env APPDATA="D:\\Downloads\\tmp-userdata-iron" /c/Users/gmore/godot/godot --headless --path . \
  --check-only --script res://esquadra.gd
env APPDATA="D:\\Downloads\\tmp-userdata-iron" /c/Users/gmore/godot/godot --headless --path . \
  --quit-after 1800 -s res://tools/probes/casas.gd \
  > /d/Downloads/tmp-userdata-iron/casas.log 2>&1
grep -nE "ERROR|SCRIPT ERROR|Cannot|Invalid|OUT OF MEMORY" /d/Downloads/tmp-userdata-iron/casas.log | head
grep -hE "veredito|quebras=|concentrado na salva" /d/Downloads/tmp-userdata-iron/casas.log | tail -3
```

Esperado `quebras=0`, com as duas salva lidas impressas (ficam no spec na Task 7).

- [ ] **Step 6: Família E — a caixa perde a casa que levou o tiro**

Sem sonda própria, a lei da caixa é contrafactual: matar uma casa do **meio** tem de mudar a caixa, coisa que o `range(casas)` antigo jamais faria.

```gd
	# ── E. CAIXA: a casa que sai é a que levou o tiro, não a que a ordem escolheu ──
	var e_e := _nova_esquadra()
	var b := e_e.blocos_aliados[3]
	var caixa_cheia := e_e.caixa_do_bloco(b)
	var alvo_c := 1 + Esquadra.CASAS_X * Esquadra.CASAS_Z   # uma casa do andar do meio
	for k in range(400):
		e_e._golpe_na_casa(b, alvo_c, Esquadra.TIRO_DE_CASA)
		if not Esquadra.casa_viva(b, alvo_c):
			break
	var caixa_rala := e_e.caixa_do_bloco(b)
	_assert("matar uma casa do meio abre a caixa naquele eixo",
		Esquadra.casa_viva(b, alvo_c) == false and caixa_rala != caixa_cheia,
		"casa %d apagada em %d tiros // caixa %s -> %s" % [alvo_c, 400,
			str(caixa_cheia.size), str(caixa_rala.size)])
	_assert("as demais casas continuam de pé e pintáveis",
		Esquadra.casas_no_bloco(b) == Esquadra.CASAS - 1,
		"%d casas vivas de %d" % [Esquadra.casas_no_bloco(b), Esquadra.CASAS])
```

- [ ] **Step 7: Bateria e commit**

```bash
bash /d/Downloads/tmp-userdata-iron/bateria.sh 2>&1 | tail -40
git add esquadra.gd main.gd tools/probes/casas.gd
git commit -m "feat(esquadra): concentrar fogo escolhe casa, nao disco

Lapidação 2, task 5: sob a ordem da ponte os lances de um bloco convergem na casa
mais proxima do bloco visado e so passam a vizinha quando ela cai
(_casas_por_proximidade, empate por indice, zero sorteio). Disperso continua um
lance por casa pela aritmetica de sempre. Nenhum dano de area existe: o disco e
selecao e o ganho vem do tiro individual. Sonda casas.gd familias D e E medem os
dois lados e a caixa que perde o meio."
git push origin main
git status --short
```

---

## Task 6: Re-medir as sondas antigas e varrer o README

**Files:**
- Modify: `D:/Downloads/IronStarsFleetCommand/tools/probes/esquadra.gd:984,987,1038,2011,2014` (writes de `["navios"]`), `:1021` (contrafactual do `ceilf`), `:274-278` e `:302-310` (as duas faixas que despem a placa do bloco na montagem viram `Esquadra.zerar_placas(bloco)` — medido por grep: são **as duas únicas** escritas de `["escudo"]` sobre bloco em todo `tools/probes/`; as outras dezenove são dos cascos nomeados de `game.fleet`/`game.enemies`, que continuam sob a lei de casco de antes e não mudam), cabeçalhos das famílias 3, 4, 11, 12
- Modify: `D:/Downloads/IronStarsFleetCommand/tools/probes/massa_visivel.gd:267` (`range(casas_vivas)` → varredura de corpos), `:539`
- Modify: `D:/Downloads/IronStarsFleetCommand/tools/probes/escudo.gd` (cabeçalho e família 12: unidade da placa por casa)
- Modify: `D:/Downloads/IronStarsFleetCommand/tools/probes/comando.gd`, `ia.gd`, `voo.gd` conforme as quebras lidas
- Modify: `D:/Downloads/IronStarsFleetCommand/README.md:40` e varredura de números
- Modify: `D:/Downloads/IronStarsFleetCommand/docs/superpowers/specs/2026-10-25-dano-por-casco-e-morte-visivel-design.md` (§3 e §10: a frase "a função não é reescrita" cai, substituída pela medição)

**Interfaces:**
- Consumes: `fixar_lotacao`, `casa_viva`, `casas_vivas_de`, `casas_no_bloco`, `fila_da_salva`, `"tiros"` do ledger.
- Produces: nada de código de jogo — só portões que voltam a falar a língua do corpo.

**Medido na bateria da Task 1 (duas sondas vermelhas, zero linha de erro, 31 logs):**

| sonda | veredito | quebras |
|---|---|---|
| `esquadra` | `SONDA-ESQUADRA: veredito - quebras=4 - conferencias=114` | 4 |
| `escudo` | `SONDA-ESCUDO: veredito - quebras=1 - conferencias=55` | 1 |

As quatro de `esquadra` têm uma causa só — o write solto de `["navios"]`, que hoje é agregado
derivado e não mexe nos corpos: `:984` e `:987` (família 3, «o topo fecha primeiro» — com 24 corpos
vivos o corte não desce), `:1038` (família 4, «casco a zero afunda» — `alvo["navios"] = 6.0` não
esvazia as casas, então a salva de 5,0 distribuída sobre 24 placas de 0,18333 não afoga nada), `:2011`
e `:2014` (família 14, «a caixa segue a lotação» — 3,467 u de altura nos dois lados, e o morto com
`size -1.0`). A de `escudo` é
a cláusula de janela em `:547-550`, que a placa por casa não tem por decisão de spec (§9). Nenhum
afrouxamento: os cinco writes viram `fixar_lotacao`, e a cláusula da janela passa a declarar a placa
de casa.

- [ ] **Step 1: Caçar os writes e os loops que assumem `range(casas)`**

```bash
cd /d/Downloads/IronStarsFleetCommand
grep -rn '\["navios"\] *=' tools/probes/*.gd
grep -rn 'range(Esquadra.casas_vivas\|range(casas_vivas' tools/probes/*.gd
grep -rn 'casas_vivas\|ESCUDO_DE_BLOCO\|4,4' tools/probes/*.gd README.md | head -30
```

Cada write vira `fixar_lotacao` (o bloco do teste passa a ter corpos coerentes):

```gd
	meia.fixar_lotacao(meia.blocos_hostis[0], float(NAVIOS_NO_BLOCO) * 0.5)
	terco.fixar_lotacao(terco.blocos_hostis[0], float(NAVIOS_NO_BLOCO) / 3.0)
	g.fixar_lotacao(alvo, 6.0)
```

Cada faixa que despia a placa de um **bloco** na montagem (as duas de `esquadra.gd`, `:274-278` e
`:302-310`) vira a chamada do corpo — os três `["escudo"]`/`["escudo_max"]`/`["escudo_cai"] = 0.0`
somem, porque `escudo` agora é derivado e a primeira mordida reescreveria o zero:

```gd
	for casca_lado in ["aliado", "hostil"]:
		for casca_bloco in game.esquadra.lista_de(casca_lado):
			Esquadra.zerar_placas(casca_bloco)
```

Os doze cascos nomeados de `game.fleet`/`game.enemies` continuam com a tripleta de zeros: eles não
têm `casas`, a lei deles é a de antes.

Cada laço `for c in range(casas_vivas(b))` que amostra **casa por casa** vira:

```gd
	for c in range(Esquadra.CASAS):
		if not Esquadra.casa_viva(bloco, c):
			continue
```

- [ ] **Step 2: Atualizar as alegações de cabeçalho**

`tools/probes/esquadra.gd`: família 3 («O TOPO FECHA PRIMEIRO») passa a dizer que o topo fecha **pelo corpo da casa**, e o `ceilf` do agregado é contrafactual documentado (a sonda `casas` mede os sete estados errados). Família 12 («UM LANCE POR CASCO PINTADO») passa a dizer que a fila **é** o ledger, não derivada dele. `tools/probes/escudo.gd`: a cláusula do bloco declara `ESCUDO_DE_BLOCO 4,4` como a **soma** das vinte e quatro placas de `PLACA_DA_CASA 0,18333`.

- [ ] **Step 3: Rodar as seis sondas tocadas, uma a uma, e ler o veredito delas**

```bash
for p in esquadra escudo comando ia voo; do
  env APPDATA="D:\\Downloads\\tmp-userdata-iron" /c/Users/gmore/godot/godot --headless --path . \
    --check-only --script "res://tools/probes/$p.gd"
  env APPDATA="D:\\Downloads\\tmp-userdata-iron" /c/Users/gmore/godot/godot --headless --path . \
    --quit-after 6000 -s "res://tools/probes/$p.gd" \
    > "/d/Downloads/tmp-userdata-iron/${p}_t6.log" 2>&1
  grep -hE "veredito|quebras=|quebra\(s\)" "/d/Downloads/tmp-userdata-iron/${p}_t6.log" | tail -1
  grep -cE "ERROR|SCRIPT ERROR|Cannot|Invalid|OUT OF MEMORY" "/d/Downloads/tmp-userdata-iron/${p}_t6.log" || true
done
```

Sonda vermelha: a correção é declarar a precondition **em quem cria o estado** (`fixar_lotacao`, `_novo_bloco`), nunca afrouxar tolerância.

- [ ] **Step 4: README — varredura de números**

Reescrever a cláusula da massa (`README.md:40`) com os números lidos nesta rodada, na língua medida do resto do arquivo:

```markdown
- O bloco da massa tem **vinte e quatro placas**, uma por casa desenhada: `PLACA_DA_CASA` é `4,4 ÷ 24 = 0,183333` e somadas são o `ESCUDO_DE_BLOCO` de antes (`4,400000000000003` em double, medido). O tiro de uma boca é `TIRO_DE_CASA = 2,2 ÷ 24 = 0,091667` escalado pela vida da casa, e a vida é `VIDA_DA_CASA = 100 ÷ 24 = 4,16667`. Afundar um bloco custa os mesmos **35 golpes de bloco** de antes ou os mesmos **840 lances de casa** (`tools/probes/casas.gd`, família A) — a escala fiel não mexe em nada somado sobre a muralha. O que a granularidade nova compra é convergência: sob fogo concentrado em duas casas, `0,3667` de casca é comida em vez de `4,4`, e a primeira casa apaga na salva **N** (medido) contra a salva **M** do fogo disperso.
```

Varredura:

```bash
grep -n "4,4\|2,2\|3,08\|35 golpe\|840\|0,18333\|4,16667\|casas_vivas\|24 casa" README.md
```

Toda frase que citar número do caminho de fogo tem de bater com a cota ou com a medição desta rodada.

- [ ] **Step 5: Spec — corrigir a frase que a medição derrubou**

Em `docs/superpowers/specs/2026-10-25-dano-por-casco-e-morte-visivel-design.md` §3, o bullet do teorema ganha a verdade medida (e a §10 recebe os números das famílias C/D). Substituir a alegação:

```markdown
  A funcao nao e reescrita: ela deixa de ser a autoridade da morte e passa a ser a leitura dela.
```

pela versão medida:

```markdown
  * **A derivação antiga de `casas_vivas` vira leitura, e a medição derrubou o teorema.** Cada casa
    viva carrega `vida ∈ (0, VIDA_DA_CASA]`, mas somar as vivas em double não pousa no inteiro
    esperado: `23 × (100 ÷ 24) = 95,83333333333336` e `ceilf` sobre isso devolve **24**, não 23. Dos
    vinte e quatro estados de lotação inteira, **sete** (5, 6, 7, 20, 21, 22, 23) seriam lidos uma
    casa acima do corpo. `casas_vivas` mantém o contrato de retorno e passa a contar os corpos; a
    derivação do agregado fica como caminho dos dicionários nus que as sondas antigas montam, e
    `tools/probes/casas.gd` mede quantas vezes ela teria errado.
```

- [ ] **Step 6: Paridade `.gd` ⟷ `.gd.uid` e commit**

```bash
cd /d/Downloads/IronStarsFleetCommand
for f in *.gd tools/probes/*.gd; do [ -f "$f.uid" ] || echo "SEM UID: $f"; done
```

Se `tools/probes/casas.gd.uid` aparecer na listagem, rodar a importação do motor (`--import` com APPDATA isolado) e commitá-lo. **Nunca** escrever o `.uid` na mão, **nunca** commitar `.godot/`, `_tmp_pista_fria.gd` ou qualquer arquivo de outra sessão.

```bash
git add tools/probes/casas.gd.uid tools/probes/esquadra.gd tools/probes/escudo.gd \
  tools/probes/massa_visivel.gd tools/probes/comando.gd tools/probes/ia.gd tools/probes/voo.gd \
  README.md docs/superpowers/specs/2026-10-25-dano-por-casco-e-morte-visivel-design.md
git commit -m "docs(sondas): as dezesset sondas do caminho de fogo falam a lingua da casa

Lapidação 2, task 6: writes soltos de navios viram fixar_lotacao (o agregado agora e
consequencia), os lacos range(casas_vivas) que amostravam casa viram varredura de
corpo, e o cabeçalho de escudo declara a placa por casa com soma medida em
4,400000000000003. README traz as tres cotas novas e o par 35 golpes = 840 lances.
O spec perde a frase 'a funcao nao e reescrita': o ceilf do agregado errava 7 dos 24
estados, medido em tools/probes/casas.gd."
git push origin main
git status --short
```

---

## Task 7: Fechamento da fatia — bateria, janela, spec, push

**Files:**
- Modify: `D:/Downloads/IronStarsFleetCommand/docs/superpowers/specs/2026-10-25-dano-por-casco-e-morte-visivel-design.md` (§10 ganha os números medidos)
- Modify: `D:/Downloads/IronStarsFleetCommand/README.md` (seção de validação + pilares)

- [ ] **Step 1: Bateria inteira, lida dela mesma**

```bash
bash /d/Downloads/tmp-userdata-iron/bateria.sh 2>&1 | tail -45
```

Só depois do `BATERIA: fim`. Verde = as **34** sondas (33 herdadas + `casas`) com `quebras=0` **e** `linhas_de_erro=0`. Varredura manual, se precisar, usa os três formatos e `tail -1`:

```bash
for l in /d/Downloads/tmp-userdata-iron/bateria/*.log; do
  printf '%s | %s\n' "$(basename "$l" .log)" \
    "$(grep -hE 'veredito|quebras=|quebra\(s\)' "$l" | tail -1)"
done
```

- [ ] **Step 2: As três sondas de olho, em janela real**

Sem `--headless` — sob headless a textura vem null e a sonda de janela devolve `<sem veredito>`:

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
grep -hE "veredito|quebras=|quebra\(s\)" /d/Downloads/tmp-userdata-iron/janela_*.log
```

**Reler os PNGs** com a ferramenta Read — eles saem em `D:/Downloads/tmp-userdata/frame/` (essa pasta não leva o sufixo `-iron`). O que o olho tem de confirmar, e nada disso a sonda headless prova: a muralha ralada **lê** como muralha com buracos (não como mancha), a casa morta não deixa fantasma de silhueta, e a onda de fogo coincide com o sumiço da casa. Se o quadro não convencer, a fatia não está fechada — a aprovação visual é do comandante, e isso é dito em vez de declarado sucesso.

- [ ] **Step 3: Escrever os números medidos no spec e no README**

Na §10 do spec, a subseção `### Teste da fatia` recebe: o `quebras=0` das 34 sondas, as conferências de `casas`, a salva da **primeira casa apagada** (impressa pela família C), o par concentrado/disperso (família D), os `35 golpes / 840 lances` (família A) e o custo contado — nunca o relógio (`ms` deste host lê ±35 % entre rodadas). No README, a cláusula da massa e a `## Validação` ganham as mesmas linhas, com os mesmos dígitos.

- [ ] **Step 4: Um commit, por nome, e push**

```bash
cd /d/Downloads/IronStarsFleetCommand
git status --short
git add README.md \
  docs/superpowers/specs/2026-10-25-dano-por-casco-e-morte-visivel-design.md \
  docs/superpowers/plans/2026-10-25-dano-por-casco-e-morte-visivel.md \
  esquadra.gd esquadra.gd.uid escudo.gd main.gd \
  tools/probes/casas.gd tools/probes/casas.gd.uid \
  tools/probes/esquadra.gd tools/probes/massa_visivel.gd tools/probes/escudo.gd \
  tools/probes/comando.gd tools/probes/ia.gd tools/probes/voo.gd
git commit -m "docs(fatia): lapidacao 2 fechada - morte visivel casa a casa medida

Bateria de 34 sondas com quebras=0 e zero linha de erro; as tres sondas de olho em
janela real com o PNG relido. Medido: 35 golpes de bloco = 840 lances de casa,
primeira casa apagada na salva N, fogo concentrado afunda casa na salva C contra M
do disperso, com o mesmo numero de tracos por salva."
git show --stat --format="" HEAD
git push origin main
git status --short
```

Relatar os dois resultados: o da comparação remota (`HEAD..origin/main` no início da rodada) e o do push.

A lista acima é o **conjunto esperado** das Tasks 1–6, não uma licença de `git add -A`: conferir com
`git status --short` e deixar de fora o que a rodada não tocou (nem o `esquadra.gd.uid` velho entra por
acaso), e continuar fora o `_tmp_pista_fria.gd` + `.gd.uid` de outra sessão, `.godot/`, `.manus/` e o
churn de CRLF nos `.import`.

- [ ] **Step 5: Memória da casa**

Se a rodada estabeleceu algo não-óbvio e durável (a medição do `ceilf` sobre soma de vidas iguais já está em código e README, então não), atualizar `project-iron-stars-comando-programa.md` com o estado da fila ①/②/③. Só isso.

---

## Self-review do plano (marcar antes de começar a executar)

- [x] **Cobertura do spec:** §3 corpo → Tasks 1–2; §4 ledger casa a casa → Task 3; §5 onda dá a notícia → Task 4; §6 escala fiel → Task 1 família A + README; §7 concentrar/dispersar → Task 5; §8 raio de mudança → Task 6; §9 casos-limite (casa morta redistribui, bloco afunda no meio da salva, placa sem janela, `morta_em` é só notícia) → Tasks 1, 3, 5; §10 cinco famílias → casas.gd (A/B em 1, C em 3+4, D/E em 5).
- [x] **Nenhum placeholder:** varrer o plano por `TBD`, "similar à Task", asserção sem código.
- [x] **Consistência de tipos:** `fixar_lotacao` é método de instância (lê `salva_numero`); `casa_viva`, `casas_no_bloco`, `casas_vivas_de`, `_casa_na_tela`, `casas_na_tela`, `_casas_por_proximidade` são `static`; `noticiar_morte` e `_golpe_na_casa` são de instância; `Escudo.morder_casa` é `static`. Os nomes usados nas sondas são exatamente estes.
