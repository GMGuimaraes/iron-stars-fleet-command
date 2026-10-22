extends RefCounted
## Superfícies procedurais: as texturas de metal, rocha, painel e planeta, desenhadas pixel a
## pixel aqui dentro em vez de embarcadas como PNG.
##
## O desenho é função do índice do pixel, não de sorteio: nenhum `rng` da casa é tocado, e por
## isso a placa de um casco é byte a byte a mesma em duas montadas da mesma cena. É o que
## permite à sonda assinar o checksum de um pixmap e comparar os dois lados de uma corrida A/B
## sem cravar semente — a mesma lei que já vale para o céu em `MultiMesh` e para a pintura da
## formação.
##
## Cada família é gerada uma vez e guardada em `_cache`: doze cascos compartilham a MESMA
## `ImageTexture` (identidade conferida pela sonda), e o tom continua sendo do `albedo_color`,
## que multiplica a textura. É assim que o dano escurece a placa junto com o aço, sem que
## `_tune_ship_look` precise saber que existe textura.
##
## Tamanhos em potência de dois de propósito: o `Compatibility` pede isso para gerar mipmaps, e
## um tamanho ímpar não falha no parse — silencia o mipmap e o casco pisca quando a câmera anda.

## Lados da placa de aço. 128 é o que segura a junta de painel legível no close-up da ponte sem
## virar renda no quadro da linha inteira, a ~30 u.
const PASSO_METAL := 128
## A junta fecha o painel a cada 32 px: 4 painéis por lado, com rebite de 8 em 8.
const JUNTA_METAL := 32
const REBITE_METAL := 8
const PASSO_ROCHA := 64
const PASSO_PAINEL := 128
const PLANETA_LARGURA := 128
const PLANETA_ALTURA := 64
## Quantas famílias de planeta existem. O fundo e o cenário `SISTEMA` não podem vestir a mesma
## pele: duas bolas azuis iguais numa mesma partida é o olho que denuncia a montagem.
const PLANETA_VARIEDADES := 4
## 0 = matriz intemperizada, 1 = face recém-fraturada (mais clara, cratera menos gasta).
const ROCHA_VARIEDADES := 2

static var _cache: Dictionary = {}

## A textura do aço de casco: painéis em grade, junta escura com filete claro na borda de cima,
## rebite de quando em quando sobre a junta e mancha de solda no canto. A rugosidade acompanha:
## junta áspera, chapa polida.
static func metal() -> Dictionary:
	if not _cache.has("metal"):
		var albedo := Image.create_empty(PASSO_METAL, PASSO_METAL, false, Image.FORMAT_RGB8)
		var rug := Image.create_empty(PASSO_METAL, PASSO_METAL, false, Image.FORMAT_RGB8)
		for y in range(PASSO_METAL):
			for x in range(PASSO_METAL):
				var sx := x % JUNTA_METAL
				var sy := y % JUNTA_METAL
				var na_junta_x := sx < 1
				var na_junta_y := sy < 1
				var mancha := _octava(float(x) * 0.09, float(y) * 0.09, 11)
				var v := 0.84 + 0.16 * mancha
				if na_junta_x or na_junta_y:
					v = 0.52 + 0.06 * mancha
				elif sx == 1 or sy == 1:
					v = 0.97
				var no_rebite := (na_junta_x or na_junta_y) \
					and ((y if na_junta_x else x) % REBITE_METAL) < 2 \
					and ((x if na_junta_x else y) % REBITE_METAL) > 2
				if no_rebite:
					v = 1.0
				# Sutura do painel: uma linha de remache por eixo, a cada quatro juntas.
				if not (na_junta_x or na_junta_y) and x % (JUNTA_METAL * 4) == JUNTA_METAL * 2:
					v *= 0.88
				var brilho := clampf(v, 0.0, 1.0)
				albedo.set_pixel(x, y, Color(brilho, brilho, brilho))
				var asp := 0.34 + 0.3 * (1.0 - mancha)
				if na_junta_x or na_junta_y:
					asp = 0.94
				rug.set_pixel(x, y, Color(asp, asp, asp))
		_cache["metal"] = {"albedo": _final(albedo), "rugosidade": _final(rug)}
	return _cache["metal"]

## Rocha de cinturão: corpo manchado, cratera com borda acesa e uma face de fratura clara.
## `variedade` 1 é a filha recém-rachada — mais limpa e mais clara, porque ainda não apanhou
## de micrometeorito.
static func rocha(variedade: int = 0) -> Dictionary:
	var chave := "rocha:%d" % int(variedade)
	if not _cache.has(chave):
		var limpo := int(variedade) == 1
		var albedo := Image.create_empty(PASSO_ROCHA, PASSO_ROCHA, false, Image.FORMAT_RGB8)
		var rug := Image.create_empty(PASSO_ROCHA, PASSO_ROCHA, false, Image.FORMAT_RGB8)
		var crateras: Array[Vector2] = []
		var raios: Array[float] = []
		for i in range(5):
			crateras.append(Vector2(8.0 + _bruto(i * 7, 3, 21) * 48.0,
				8.0 + _bruto(i * 11, 5, 29) * 48.0))
			raios.append(4.0 + _bruto(i, 9, 37) * 7.0)
		for y in range(PASSO_ROCHA):
			for x in range(PASSO_ROCHA):
				var mancha := _octava(float(x) * 0.14, float(y) * 0.14, 5)
				var fino := _octava(float(x) * 0.42, float(y) * 0.42, 71)
				var v := (0.58 if limpo else 0.46) + (0.42 if limpo else 0.54) * mancha \
					+ 0.08 * fino
				for c in range(crateras.size()):
					var d := Vector2(float(x), float(y)).distance_to(crateras[c])
					var raio := raios[c]
					if d < raio:
						v *= 0.62 + 0.28 * (d / raio)
					elif d < raio + 1.6:
						v *= 1.22
				# Face de fratura: um terço do mapa clareado por uma costura reta.
				if not limpo and y > PASSO_ROCHA * 0.66 and x > (y - PASSO_ROCHA * 0.66) * 2.2:
					v *= 1.18
				var cor := clampf(v, 0.0, 1.0)
				albedo.set_pixel(x, y, Color(cor, cor * 0.95, cor * 0.88))
				var asp := clampf(0.72 + 0.24 * (1.0 - mancha), 0.0, 1.0)
				rug.set_pixel(x, y, Color(asp, asp, asp))
		_cache[chave] = {"albedo": _final(albedo), "rugosidade": _final(rug)}
	return _cache[chave]

## Painel de ponte: soalho em losangos com junta rebitada e uma faixa de passagem. Escuro na
## base, claro no relevo — o `albedo_color` do deck já é quase tinta, e a textura só existe para
## o olho ler escala quando a câmera desce até o console.
static func painel() -> Dictionary:
	if not _cache.has("painel"):
		var albedo := Image.create_empty(PASSO_PAINEL, PASSO_PAINEL, false, Image.FORMAT_RGB8)
		for y in range(PASSO_PAINEL):
			for x in range(PASSO_PAINEL):
				var losango := absf(float((x % 32) - 16)) + absf(float((y % 32) - 16))
				var v := 0.8 + 0.2 * _octava(float(x) * 0.1, float(y) * 0.1, 91)
				if losango > 14.6:
					v = 0.55
				elif losango > 13.6:
					v = 0.99
				if y % PASSO_PAINEL < 3 or y % PASSO_PAINEL > PASSO_PAINEL - 4:
					v *= 1.1
				var cor := clampf(v, 0.0, 1.0)
				albedo.set_pixel(x, y, Color(cor, cor, cor))
		_cache["painel"] = {"albedo": _final(albedo), "rugosidade": null}
	return _cache["painel"]

## Planeta em faixas: latitude ondulada pelo próprio ruído, calota polar mais fria, dois
## ciclones e a pele de nuvem por cima. `variedade` troca a paleta e o número de faixas, que é
## o gancho do que vem: fases com planetas de textura e tamanho diferentes.
static func planeta(variedade: int) -> Dictionary:
	var va := int(variedade) % PLANETA_VARIEDADES
	var chave := "planeta:%d" % va
	if not _cache.has(chave):
		var albedo := Image.create_empty(PLANETA_LARGURA, PLANETA_ALTURA, false, Image.FORMAT_RGB8)
		var rug := Image.create_empty(PLANETA_LARGURA, PLANETA_ALTURA, false, Image.FORMAT_RGB8)
		var paleta: Array = [
			[Color(0.16, 0.28, 0.44), Color(0.3, 0.44, 0.56), Color(0.62, 0.66, 0.6)],
			[Color(0.34, 0.2, 0.14), Color(0.56, 0.4, 0.26), Color(0.74, 0.66, 0.52)],
			[Color(0.1, 0.26, 0.22), Color(0.24, 0.44, 0.34), Color(0.66, 0.74, 0.6)],
			[Color(0.3, 0.3, 0.36), Color(0.46, 0.48, 0.56), Color(0.68, 0.72, 0.8)],
		][va]
		var faixas := 5 + va * 2
		for y in range(PLANETA_ALTURA):
			for x in range(PLANETA_LARGURA):
				var ond := _octava(float(x) * 0.05, float(y) * 0.11, 130 + va) * 6.0
				var t := 0.5 + 0.5 * sin((float(y) + ond) / float(PLANETA_ALTURA) * TAU * float(faixas))
				var nuvem := _octava(float(x) * 0.08 + va * 17.0, float(y) * 0.13, 211)
				t = clampf(t * 0.78 + nuvem * 0.34, 0.0, 1.0)
				var cor: Color = paleta[0].lerp(paleta[1], t)
				# Calota polar: o mesmo corpo, mais frio nos dois polos.
				var polo := 1.0 - absf(float(y) / float(PLANETA_ALTURA - 1) * 2.0 - 1.0)
				if polo > 0.86:
					cor = cor.lerp(paleta[2], (polo - 0.86) / 0.14 * 0.8)
				for c in range(2):
					var centro := Vector2(float(c) * 46.0 + 22.0 + va * 9.0,
						float(PLANETA_ALTURA) * (0.38 + 0.24 * float(c)))
					var d := Vector2(float(x) - centro.x, (float(y) - centro.y) * 2.2).length()
					if d < 9.0:
						cor = cor.lerp(paleta[2], (1.0 - d / 9.0) * 0.55)
				albedo.set_pixel(x, y, cor)
				var asp := clampf(0.5 + 0.45 * nuvem, 0.0, 1.0)
				rug.set_pixel(x, y, Color(asp, asp, asp))
		_cache[chave] = {"albedo": _final(albedo), "rugosidade": _final(rug)}
	return _cache[chave]

## Quantas famílias de planeta existem — a sonda usa a constante, não um número escrito à mão.
static func planetas_existentes() -> int:
	return PLANETA_VARIEDADES

static func guardado_em(nome: String) -> bool:
	return _cache.has(nome)

static func limpar_cache() -> void:
	_cache.clear()

static func _final(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## Hash inteiro do pixel: mesma entrada, mesma saída, em qualquer máquina e em qualquer rodada.
## `int` de 64 bits segura o overflow sem truncar o que a máscara lê.
static func _bruto(x: int, y: int, sal: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (sal * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(absi(h) % 100000) / 100000.0

static func _ruido(x: float, y: float, sal: int) -> float:
	var xi := int(floor(x))
	var yi := int(floor(y))
	var fx := x - float(xi)
	var fy := y - float(yi)
	var u := fx * fx * (3.0 - 2.0 * fx)
	var v := fy * fy * (3.0 - 2.0 * fy)
	var a := _bruto(xi, yi, sal)
	var b := _bruto(xi + 1, yi, sal)
	var c := _bruto(xi, yi + 1, sal)
	var d := _bruto(xi + 1, yi + 1, sal)
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v)

## Três oitavas: largo para a mancha, médio para o relevo, fino para o grão.
static func _octava(x: float, y: float, sal: int) -> float:
	return _ruido(x, y, sal) * 0.55 + _ruido(x * 2.0, y * 2.0, sal + 7) * 0.28 \
		+ _ruido(x * 4.0, y * 4.0, sal + 13) * 0.17
