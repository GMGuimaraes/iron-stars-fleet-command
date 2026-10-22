extends SceneTree

## Recorta e amplia um pedaço de fotograma para leitura de silhueta.
##
## Os quadros de `tools/probes/fotograma.gd` saem em 1440x900 e a esquadra inteira cabe numa faixa
## de duzentos pixels do visor: a pergunta «o convés lê aviação contra o cruzador?» não responde em
## tela cheia, responde ampliada. Sem PIL nem ImageMagick neste host, o próprio Godot decodifica,
## recorta e reamplia em vizinho mais próximo — que é o único modo de ampliar sem inventar pixel.
##
## Os argumentos vêm depois de `--`, porque o motor reserva o que vem antes para si.
##
## Uso: godot --headless --path . -s res://tools/zoom_png.gd -- <src.png> <dst.png> <x> <y> <w> <h> <fator>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 7:
		print("USO: -s res://tools/zoom_png.gd -- src dst x y w h fator")
		quit(1)
		return
	var img := Image.load_from_file(String(args[0]))
	if img == null:
		print("QUEBRA: não leu %s" % args[0])
		quit(1)
		return
	var rect := Rect2i(int(args[2]), int(args[3]), int(args[4]), int(args[5]))
	var recorte := img.get_region(rect)
	var fator := int(args[6])
	recorte.resize(recorte.get_width() * fator, recorte.get_height() * fator,
		Image.INTERPOLATE_NEAREST)
	recorte.save_png(String(args[1]))
	print("OK %s -> %s recorte %dx%d ampliado %dx%d" % [args[0], args[1], int(args[4]),
		int(args[5]), recorte.get_width(), recorte.get_height()])
	quit()
