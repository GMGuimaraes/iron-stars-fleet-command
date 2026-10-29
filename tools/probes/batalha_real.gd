extends SceneTree

## Sonda de batalha real: dirige o `_process` do jogo (a ponte inteira, com frota avançando,
## `fire_clock` e `_resolve_volley`) por um trecho de tempo virtual e lê o ledger da massa a cada
## salva. Responde «o tiro individual dá dano?» com a curva da partida, não com a cota de uma
## marcha sintética — a marcha sintética congelava os núcleos e media outra coisa. Foi desta
## porta que saíram os números publicados no README na lapidação 3: 123 salvas em 200 s de
## relógio virtual apagando 360 casas de 2 880 de cada lado, com 0 blocos afundados.
##
## O portão é a curva, não o saldo: a sonda jura que há dano por casa e que a cadência não
## quebrou, e confessa impresso que em fogo de linha nenhum bloco afunda — afundar é alavanca de
## saldo do comandante (`DANO_DE_BLOCO` e as ordens de área), não asserção de sonda.
##
## Uso: godot --headless --path . --quit-after 1800 -s res://tools/probes/batalha_real.gd

const Esquadra := preload("res://esquadra.gd")

const QUADROS := 12_000
const MARCA_A_CADA := 30
## Salvas esperadas no trecho: a cadência é de 1,6 s e o trecho tem 200 s, menos o tempo até o
## contato. O portão cobra a cadência viva (≥ 120), não o dígito exato da rodada.
const SALVAS_NO_TRECHO_MIN := 120
const LANCES_DA_SALVA_LOTADA := 1_440

var breaks := 0
var notes: Array[String] = []


func _assert(label: String, condition: bool, detail: String) -> void:
	if condition:
		notes.append("OK   %s — %s" % [label, detail])
	else:
		breaks += 1
		notes.append("QUEBRA %s — %s" % [label, detail])


func _initialize() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate()
	get_root().add_child(game)
	await _frames(3)
	var e: Esquadra = game.esquadra
	var blocos_a := e.vivos("aliado")
	var blocos_h := e.vivos("hostil")
	var casas_a := _casas_mortas(e, "aliado")
	var casas_h := _casas_mortas(e, "hostil")
	var ultima_salva := e.salva_numero
	var lances_maximos := 0
	var tempo_ate_contato := -1.0
	for f in range(QUADROS):
		game._process(1.0 / 60.0)
		if tempo_ate_contato < 0.0 and e.salva_numero > 0:
			tempo_ate_contato = game.battle_clock
		var s := e.salva_numero
		if s == ultima_salva:
			continue
		ultima_salva = s
		var tiros := e.tiros_da_salva().size()
		lances_maximos = maxi(lances_maximos, tiros)
		if s % MARCA_A_CADA == 0:
			var ch := _casas_mortas(e, "hostil")
			var ca := _casas_mortas(e, "aliado")
			var txt := "salva %d t=%.0fs: lances=%d pares=%d" % [s, game.battle_clock, tiros,
				e.pares_da_ultima_salva.size()]
			txt += " // hostil +%d casas (total %d/%d) %d/%d blocos %dc" % [ch - casas_h, ch,
				blocos_h * Esquadra.CASAS, e.vivos("hostil"), blocos_h, int(e.navios("hostil"))]
			txt += " | aliado +%d casas (total %d/%d) %d/%d blocos %dc" % [ca - casas_a, ca,
				blocos_a * Esquadra.CASAS, e.vivos("aliado"), blocos_a, int(e.navios("aliado"))]
			print(txt)
			casas_h = ch
			casas_a = ca
	var mortas_h := _casas_mortas(e, "hostil")
	var mortas_a := _casas_mortas(e, "aliado")
	var total_casas := blocos_h * Esquadra.CASAS
	print("RESUMO: primeira salva aos %.1f s virtuais; %d salvas em %.0f s; maior salva = %d lances" % [
		tempo_ate_contato, ultima_salva, QUADROS / 60.0, lances_maximos])
	print(("RESUMO: ao fim - hostil %d/%d blocos %d casas mortas de %d %dc | aliado %d/%d blocos " % [
		e.vivos("hostil"), blocos_h, mortas_h, total_casas, int(e.navios("hostil")),
		e.vivos("aliado"), blocos_a] \
		+ "%d casas mortas de %d %dc") % [mortas_a, blocos_a * Esquadra.CASAS,
			int(e.navios("aliado"))])
	_assert("o tiro individual dá dano na partida inteira, não só na marcha sintética",
		mortas_h > 0 and mortas_a > 0,
		("%d casas aliadas e %d hostis apagadas de %d em %d salvas lidas por `_process` da ponte" % [
			mortas_a, mortas_h, total_casas, ultima_salva]))
	_assert("a salva arma um cano por casa viva, não um risco por bloco",
		lances_maximos >= LANCES_DA_SALVA_LOTADA,
		"maior salva do trecho com %d lances, teto do lote em %d" % [
			lances_maximos, 2 * Esquadra.INSTANCIAS_POR_LADO])
	_assert("a cadência de 1,6 s continua viva com os dois lados atirando desencontrados",
		ultima_salva >= SALVAS_NO_TRECHO_MIN,
		("%d salvas em %.0f s de relógio virtual (a fase hostil de 0,5 s mora dentro do pulso de "
			+ "1,326 s, não no ciclo)") % [ultima_salva, QUADROS / 60.0])
	_assert("o fogo de linha não afunda bloco nenhum no trecho — confesso, não portado como vitória",
		e.vivos("aliado") == blocos_a and e.vivos("hostil") == blocos_h,
		("%d/%d blocos dos dois lados ainda na lista; o afundamento é alavanca de saldo do "
			+ "comandante, não asserção desta sonda") % [e.vivos("aliado"), e.vivos("hostil")])
	_assert("o ledger dos dois lados desce junto — sem lado invisível",
		mortas_a >= int(float(total_casas) * 0.05) and mortas_h >= int(float(total_casas) * 0.05) \
			and float(mortas_a) / float(maxi(mortas_h, 1)) >= 0.5 \
			and float(mortas_a) / float(maxi(mortas_h, 1)) <= 2.0,
		("aliado %d contra hostil %d casas apagadas (razão %.2f), navios %dc contra %dc" % [
			mortas_a, mortas_h, float(mortas_a) / float(maxi(mortas_h, 1)),
			int(e.navios("aliado")), int(e.navios("hostil"))]))
	for n in notes:
		print(n)
	print("SONDA-BATALHA-REAL: veredito - quebras=%d - conferencias=%d" % [breaks, notes.size()])
	quit()


static func _casas_mortas(e: Esquadra, lado: String) -> int:
	var n := 0
	for b in e.lista_de(lado):
		for c in range(Esquadra.CASAS):
			if not Esquadra.casa_viva(b, c):
				n += 1
	return n


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame
