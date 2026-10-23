---
name: godot-readme-number-sweep
description: 'Varredura e reconciliacao de todo numero citado no README depois de uma fatia visual, para projeto Godot cujo README e contrato medido (ex.: Iron Stars em D:/Downloads/IronStarsFleetCommand). Usar quando uma fatia nova (moldura, mobilia, rig, vidro, setor) muda medidas ja publicadas, ao extrair do log do fotograma o par nome e luminancia media com grep mais sed sobre a linha inteira, ao reescrever digitos de rodadas anteriores guardando o historico onde a clausula diz que nao e contrato, ao corrigir a afirmacao ao redor do numero (queda que vira alta), ao conferir contagens estruturais (filhos do rig, materiais no registro, conferencias por sonda) e ao rodar o grep de exaustao pela lista de valores velhos antes do commit.'
---

# README number sweep (medida → README)

## Overview

Num projeto onde o README e contrato medido, uma fatia visual nao muda "um numero":
ela move dezenas de digitos espalhados em prosa, inclusive de rodadas anteriores, e
muda o *sentido* da frase junto do digito. A varredura existe para isso: extrair a
medida do log (nunca da memoria), reescrever cada digito, e provar por exaustao que
nenhum valor velho sobrou.

Ordem obrigatoria. Medir antes de editar; editar antes de provar; provar antes do commit.

## Quando usar

- Fatia nova tocada em visual/cena e o README cita luminancia, contagem ou proporcao dela.
- Pedido tipo "reconciliar o README com a medição", "atualizar as medidas do README".
- Fechamento de fatia, antes de commit/push (pareado com o portão headless da sessão).

## Quando nao usar

- Feature sem numero publicado no README (prosa sola nao e varredura).
- Projeto cujo README nao se propoe a medir nada — nao ha contrato a reconciliar.

## Fixos

| Item | Valor |
|---|---|
| Fonte de verdade | log do fotograma em arquivo, gerado nesta sessao |
| Formato da linha | `SONDA-FOTOGRAMA: OK   <quadro> tem imagem — luminância média <valor> em 1440x900, salvo em <caminho>/<quadro>.png` |
| Veredito | `SONDA-FOTOGRAMA: veredito • quebras=<n> • conferências=<n>` |
| APPDATA descartavel | `D:/Downloads/tmp-userdata` (o probe real sobrescreve o save do usuario) |
| Shell | Git Bash; padrao com travessao (`—`) e acento (`luminância`) sao literais |

## Passo 1 - regenerar o log, nao confiar no anterior

Rodar a bateria de sondas headless com `APPDATA` descartavel e `--check-only` antes do
smoke, gravando saida em arquivo. **Conferir a contagem de linhas e o veredito antes de
confiar em qualquer par**: log truncado por FATAL intermitente de texto no headless faz a
varredura parecer "nada mudou". Um log com `quebras>0` nao e contrato — consertar primeiro.

## Passo 2 - extrair o par quadro e valor com sed na linha inteira

```
grep -E "tem imagem" LOG | sed -E 's/.*OK +([0-9a-z_]+) tem imagem — luminância média ([0-9.]+).*/\1 \2/'
```

Medido com amostra sintetica de 4 linhas: a saida e `<quadro> <valor>` por linha.
Exemplo de saida (valores falsos, so o formato vale): `05i_cinco_setores 0.0189`.

**Por que nao `grep -oE`** (tambem medido nesta sessao): os dois padroes casam, mas cada
um devolve **uma coluna**, nao o par:

- `grep -oE '[0-9a-z_]+\.png'` → nomes, sem valor.
- `grep -oE 'luminância média [0-9.]+'` → valores, sem nome.

As colunas so coincidem por ordem enquanto toda linha do quadro tiver medida. Uma linha
`FALHA ... (sem luminancia)` desalinha as duas colunas e o join por posicao passa a
inventar par. O sed casa os dois grupos na **mesma** linha e e imune a isso.

**Armadilha do sed:** linha nao casada passa **crua** para a saida (provado — a linha de
`veredito` apareceu inteira no meio da tabela). Filtrar com `grep -E "tem imagem"` antes
e conferir se alguma saida comeca com `SONDA-FOTOGRAMA:`; se comeca, o padrao nao casou
e a tabela esta mentindo.

## Passo 3 - reescrever digito por digito, incluindo rodadas anteriores

Listar no README todo numero que a fatia toca (prosa, tabela, comentario-cabeca) e
reescrever com um `Edit` por valor — edicao em lote esconde qual digito nao bateu. Os
valores de rodadas anteriores tambem sao re-escritos se a medida atual os move.

Onde a clausula diz que aquele numero **nao e contrato** (registro de tentativa,
historico de rodada), guardar o valor velho em vez de apagar: a historia e parte do
contrato.

## Passo 4 - corrigir a afirmacao, nao so o digito

Para todo numero alterado, reler a frase ao redor e ajustar a palavra que descreve a
tendencia. Caso real desta varredura: um valor que era "queda" virou "alta" porque a
moldura ganhou mobilia — o digito trocado sem a frase deixa o README mentindo com o
numero certo.

## Passo 5 - contagens estruturais

Re-medir do log/codigo, nao da memoria: filhos do rig, materiais no registro,
conferencias por sonda, quebras no veredito. Sao os numeros que mudam sem ninguem
pedir (uma sonda nova soma conferencias sozinha).

## Passo 6 - grep de exaustao pela lista de valores velhos

Montar a lista dos valores substituidos e procurar todos:

```
grep -nE 'VELHO1|VELHO2|VELHO3' README.md || true
```

Tem que voltar vazio. **`grep -c` com zero ocorrencia sai com codigo 1** (medido) e
quebra corrente `&&` no Git Bash — usar `|| true` ou comando separado, senao a prova
"falha" exatamente quando passa.

## Passo 7 - mesmo commit

README e comentario-cabeca das sondas no mesmo commit: se so o README mexe, o portao da
proxima sessao reconcilia contra um contrato que nao existe no codigo.

Se o repo tem `.qoder/skills/`, espelhar a skill la no mesmo commit. Conferir com `Glob`
**antes** de falar em espelhamento pendente: a copia rastreada e convencao de repo
especifico, e a ausencia do diretorio nao e falha de espelhamento nenhuma — e um repo que
nao adotou a convencao.

## Prova de que a varredura funcionou

- Tabela do Passo 2 reimpressa depois dos edits bate linha a linha com o README.
- grep de exaustao (Passo 6) vazio.
- Teste negativo: plantar um valor velho no README e conferir que o Passo 6 o pega —
  so passa quem faz o teste negativo, senao o padrao pode simplesmente nao estar casando nada.
