extends Node3D

const BLUE := Color(0.12, 0.72, 1.0)
const RED := Color(1.0, 0.22, 0.18)
const GOLD := Color(1.0, 0.72, 0.28)
## A frota hostil avança até esta linha e para: engajamento à vista da ponte, não
## atravesso do tabuleiro.
const HOSTILE_ADVANCE_Z := -60.0
## Recuo tem fundo: na linha de reunião a esquadra se reorganiza em vez de sair do mapa.
const HOSTILE_RALLY_Z := -92.0
## Fundo da varredura: a sonda vai além do último casco hostil e volta, em vez de sumir para
## fora do campo de visão da ponte.
const PROBE_FAR_Z := -104.0
## Base da varredura, logo à frente da linha aliada: é para onde a sonda retorna.
const PROBE_NEAR_Z := -34.0
const PROBE_SPEED := 16.0
const PROBE_LIFE := 30.0
## Raio curto de propósito: com a linha hostil espaçada em 6 unidades, uma sonda confirma o
## próprio corredor e, no máximo, um vizinho. Cobertura total exige varredura de verdade.
const PROBE_SCAN_RADIUS := 9.0
## ---- Navegação e casco físico ----
## Campo grande de propósito: a capitânia precisa de mar para manobrar, e o cenário ocupa volume
## em vez de um plano. O limite é o que impede a frota de fugir do quadro em vez de resolver a
## batalha.
const MAP_X := 160.0
const MAP_Y := 90.0
const MAP_Z_NEAR := 40.0
const MAP_Z_FAR := -300.0
## Nó de casco em throttle cheio. Ré tem teto próprio porque cruzador não manobra de costas como
## rebocador: 60% do avanço, e ainda assim mais rápido que o motor de busca de um alvo.
const CAPITAL_SPEED := 22.0
const CAPITAL_REVERSE := -0.6
## Empuxo vetorial: subir e descer sem mudar a atitude do casco.
const CAPITAL_LIFT := 12.0
## Atitude limitada: sem teto de arfagem a ponte gira em parafuso e a mesa holográfica, que é
## filha do rig, perde o horizonte que o comandante usa para ler o quadro.
const PITCH_LIMIT := 0.62
const ROLL_LIMIT := 0.5
## Timão lido pelo InputMap, não por tecla votada. `Input.is_key_pressed` devolve o estado que
## só uma janela real preenche — em headless ele fica frio, e o jogador num layout AZERTY não
## manobra com W de jeito nenhum. Cada ação recebe DOIS eventos: o código digitado e a posição
## física do teclado, que é o que falta no build web (navegador nem sempre reporta o físico).
const VOO_ACOES := {
	"capital_avante": KEY_W,
	"capital_re": KEY_S,
	"capital_bombordo": KEY_A,
	"capital_estibordo": KEY_D,
	"capital_nariz_acima": KEY_UP,
	"capital_nariz_abaixo": KEY_DOWN,
	"capital_role_esquerda": KEY_Q,
	"capital_role_direita": KEY_E,
	"capital_empuxo_acima": KEY_R,
	"capital_empuxo_abaixo": KEY_V,
}
## Raio de manobra do casco: é perfil de tráfego, não a pintura (o billete mede ~4 unidades de
## boca). Com 2,4 dois postos precisam estar a 4,8 de distância, e é por isso que o passo de
## formação é 5,5 — posto mais fechado que isso colide antes de obedecer.
const HULL_RADIUS := 2.4
## Passo lateral de qualquer posto de formação: tem de ficar acima de 2 * HULL_RADIUS, senão a
## própria formação dispara o abalroamento que ela deveria evitar.
const FORMATION_STEP := 5.5
const CAPITAL_RADIUS := 6.0
## Abalroamento: abaixo desta velocidade de aproximação os cascos apenas se empurram.
const RAM_SPEED := 3.0
const RAM_DAMAGE := 1.9
const RAM_MAX_DAMAGE := 18.0
## Um par cobra um golpe por janela, não um por quadro: sem isto dois cascos encostados
## perderiam a tripulação inteira em dois segundos de contato.
const RAM_WINDOW := 1.5

## ---- Mesa holográfica ----
## Escala isótropa, ancorada no meio do campo de ação (entre as duas linhas). Uma mesa que
## alonga um eixo mente sobre distância, e é com ela que o comandante decide onde mandar a frota.
const HOLO_SCALE := 0.075
const HOLO_ANCHOR_Z := -60.0
## O disco tem borda: quem está fora da janela tática encosta no aro em vez de sumir da mesa.
const HOLO_RIM := 2.85
## Altitude é a única dimensão ampliada de propósito: na escala verdadeira o blip subiria 0,15
## e ninguém leria nada. 0,09 por unidade com teto lê a subida sem quebrar a planta.
const HOLO_ALT_SCALE := 0.09
const HOLO_ALT_CEIL := 0.8

## ---- Paleta da batalha (referência: Legend of the Galactic Heroes) ----
## O anime resolve naves de guerra com aço frio e só uma faixa de cor por nação; o que brilha
## é o escapamento e a arma, nunca o casco inteiro. Por isso `ACO` é neutro e `BLUE`/`RED`
## descem para a função de filete e de torreta.
const ACO := Color(0.34, 0.38, 0.44)
const ACO_ESCURO := Color(0.11, 0.13, 0.17)
const CARVAO := Color(0.05, 0.045, 0.055)
const BRASA := Color(0.72, 0.2, 0.05)
## Cor de escape: fria na linha aliada, quente na hostil. É a distância que se lê no visor.
const ESCOAMENTO_ALIADO := Color(0.34, 0.72, 1.0)
const ESCOAMENTO_HOSTIL := Color(1.0, 0.44, 0.16)
## Ouro de gala da capitânia — usado em filetes, no mastro e na moldura da ponte.
const HUD_OURO := Color(0.82, 0.68, 0.34)
## Offsets fixos da detonação: cinco billets, nenhuma sorteio. Sortear a explosão empurraria a
## cauda de `rng` igual sorteio de estrela — ver `visual_rng`.
const DETONACAO: Array[Vector3] = [Vector3(0, 0, 0), Vector3(1.1, 0.5, -0.7), Vector3(-1.2, -0.4, 0.6),
	Vector3(0.5, -1.0, 1.2), Vector3(-0.7, 0.9, -1.1)]
var paused := false
## Signed: positivo é avante, negativo é ré. O HUD lê em porcentagem com sinal.
var throttle := 0.0
## Casco da própria capitânia, que agora é um corpo no tabuleiro: encosta em alguém e leva.
var capital_hp := 100.0
## Velocidade real do rig no último quadro, medida por diferença de posição — é dela que sai a
## velocidade de aproximação do abalroamento.
var capital_velocity := Vector3.ZERO
## Última vez que cada par de cascos trocou golpe, chaveada pelo par de instance ids.
var ram_windows: Dictionary = {}
var fleet: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var battle_clock := 0.0
var fire_clock := 0.0
var status_label: Label
var report_label: Label
var pause_button: Button
var speed_label: Label
var command_label: Label
var bridge_rig: Node3D
var rng := RandomNumberGenerator.new()
## Gerador exclusivo da camada visual. Estrela, tracer ou detrito sorteado por `rng` empurraria
## a cauda de combate: cada sorteio a mais reescreve todo o dano da salva seguinte (é o que a
## corrida A/B de `tools/probes/sondas.gd` mede). Nada aqui consome `rng`.
var visual_rng := RandomNumberGenerator.new()
## Blips da mesa holográfica: `id do nó lógico` -> `MeshInstance3D`. A mesa espelha o tabuleiro
## real, então ela é construída a partir das listas vivas e não de um cadastro paralelo.
var holo_blips: Dictionary = {}
var holo_root: Node3D
## O blip dourado da capitânia mora fora de `holo_blips`: a mesa é construída a partir das listas
## de frota, e o rig de ponte não é unidade nenhuma — misturar os dois quebraria a conta de
## blips por casco vivo que `tools/probes/graficos.gd` confere.
var holo_capitania: MeshInstance3D
## Anel que gira sobre a mesa: o movimento é o que denuncia a pausa tática como pausa, não
## como jogo congelado.
var holo_anel: Node3D
## Os quatro materiais dos blips são criados uma vez. O blip troca de material, nunca ganha um
## novo por quadro — material novo em loop é exatamente como se vaza recurso no encerramento.
var mat_holo_aliado: StandardMaterial3D
var mat_holo_hostil: StandardMaterial3D
var mat_holo_presa: StandardMaterial3D
var mat_holo_morto: StandardMaterial3D
var selected_target := 0
var formation := "LINHA"
## Sondas táticas vivas: cada entrada é um nó visível que atravessa o tabuleiro varrendo
## cascos com o próprio corpo. Enquanto nenhuma sonda passa sobre um hull, ele continua
## "não identificado" na ponte — a informação é efeito de um objeto no mapa, não de um
## cronômetro. Nada aqui sorteia: ver a cauda de RNG em `_update_probes`.
var probes: Array[Dictionary] = []
## Cobertura da varredura, medida em contatos e não em tempo: `recon_progress` passou a ser
## 100 * recon_contacts / recon_total. Sem casco hostil vivo o par fica 0/0 e a barra em 0,
## porque não há linha a cobrir.
var recon_progress := 0.0
var recon_contacts := 0
var recon_total := 0
var reserve_mode := false
var selection_scope := "FROTA"
var target_selector: OptionButton
var protected_selector: OptionButton
var protected_unit_index := -1
var scope_selector: OptionButton
var subsystem_selector: OptionButton
var repair_selector: OptionButton
var position_x_input: SpinBox
var position_z_input: SpinBox
var move_x := 0.0
var move_z := -55.0
## Leitura da IA hostil, atualizada a cada salva: postura da frota, alvo concentrado e a
## frase que a ponte devolve ao comandante. Com `hostile_posture == "AVANÇAR"` a frota
## hostil se comporta como antes deste recurso — nenhuma fórmula paralela, só a decisão
## de quem escolhe alvo e posição.
var hostile_posture := "AVANÇAR"
var hostile_focus := -1
var tactical_note := "POSTURA HOSTIL: AVANÇAR"

func _ready() -> void:
	rng.randomize()
	# Semente cravada de propósito: o céu e os fachos são os mesmos em toda partida, e nada do
	# que se vê depende do sorteio da batalha.
	visual_rng.seed = 20261020
	_registra_voo()
	_build_environment()
	_build_bridge()
	_build_fleets()
	_rebuild_holo()
	# Antes da primeira UI: sem isto a ponte abriria com 0/0 quando o tabuleiro já tem seis
	# cascos hostis a confirmar.
	_recompute_recon()
	_build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	# A mesa holográfica continua acesa na pausa tática: é exatamente ali que o comandante
	# precisa ler o tabuleiro. Nada aqui move casco, motor, arma nem tripulação.
	_update_bridge(delta)
	if paused:
		return
	battle_clock += delta
	fire_clock += delta
	_update_capital_ship(delta)
	_update_fleet(delta)
	_update_probes(delta)
	if fire_clock >= 1.6:
		fire_clock = 0.0
		_resolve_volley()
	if is_instance_valid(speed_label):
		# Velocidade com sinal: ré é marcha, não defeito, e a altitude entra porque o campo agora
		# tem três eixos e o comandante precisa ler em qual dele está.
		speed_label.text = "VELOCIDADE %+04d%%  //  SUBIDA %+04d  //  CASCO DA CAPITÂNIA %03d%%" % [
			int(throttle * 100.0), int(bridge_rig.position.y), int(capital_hp)]
	if is_instance_valid(report_label) and int(battle_clock) % 12 == 0 and fmod(battle_clock, 1.0) < delta:
		report_label.text = "RELATÓRIO: contato hostil confirmado. Frota em combate."
	_update_hud()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_toggle_pause()
		elif event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	# Céu quase preto com horizonte azul-frio: sem SSR e sem SDFI no Compatibility, é a
	# radiância do céu que dá ao aço do casco o degradê que uma luz ambiente chapada nunca deu.
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.004, 0.008, 0.02)
	sky_mat.sky_horizon_color = Color(0.055, 0.11, 0.22)
	sky_mat.ground_bottom_color = Color(0.004, 0.006, 0.012)
	sky_mat.ground_horizon_color = Color(0.04, 0.085, 0.17)
	sky_mat.sky_curve = 0.22
	sky_mat.ground_curve = 0.24
	sky_mat.ground_energy_multiplier = 0.6
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.background_sky = sky
	# O ambient é o único "reflexo" que o Compatibility tem de sobra: com o céu preto abaixo,
	# o aço pintado não recebia nada e o casco afundava no fundo do quadro.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	# Névoa rasa: a linha hostil a cem unidades afunda no escuro em vez de chegar à ponte com a
	# mesma nitidez da capitânia ao lado. Densidade baixa de propósito — céu alto some com mais.
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.09, 0.17)
	env.fog_density = 0.0013
	env.fog_sky_affect = 0.15
	# ACES + glow. No Compatibility o glow é a implementação simples (sem níveis nem `glow_map`),
	# e é dela que vivem os fachos de motor e os lances — por isso os emissivos são ligados
	# acima de 1,0 em energia: abaixo do limiar o bloom não pega nada.
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.25
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_strength = 0.55
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.3
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24, -36, 0)
	sun.light_color = Color(0.72, 0.84, 1.0)
	sun.light_energy = 1.55
	sun.shadow_enabled = false
	add_child(sun)
	# Contraluz frio vindo de trás da linha hostil: é o que separa a silhueta do céu.
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(14, 148, 0)
	rim.light_color = Color(0.35, 0.55, 0.95)
	rim.light_energy = 0.5
	rim.shadow_enabled = false
	add_child(rim)
	_build_backdrop()
	_build_starfield()

## O fundo do sistema: um planeta escuro com terminador e uma aurora aditiva no limbo, mais o
## disco de luz da estrela chave fora de quadro. Escala e leitura de profundidade, não decoração.
func _build_backdrop() -> void:
	var planet := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 22.0
	sphere.height = 44.0
	planet.mesh = sphere
	planet.position = Vector3(42, 8, -165)
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.09, 0.15, 0.26)
	pm.metallic = 0.05
	pm.roughness = 0.95
	pm.emission_enabled = true
	pm.emission = Color(0.008, 0.022, 0.05)
	pm.emission_energy_multiplier = 1.0
	planet.material_override = pm
	add_child(planet)
	# Aurora no limbo: um disco aditivo um pouco maior que o planeta, visto de frente.
	var haze := _flare(Vector3(42, 8, -164.0), 52.0, Color(0.1, 0.34, 0.62, 0.34), self)
	haze.rotation_degrees = Vector3.ZERO
	# A estrela do sistema fica fora do visor, mas o núcleo dela entra pela borda.
	_flare(Vector3(-118.0, 44.0, -190.0), 30.0, Color(0.85, 0.9, 1.0, 0.55), self)

## Campo de estrelas em um único MultiMesh. Antes eram 260 nós sortidos por `rng`, o que
## empurrava a cauda de combate antes de a primeira nave existir; agora é uma drawn call e o
## sorteio é do gerador visual, com semente cravada.
func _build_starfield() -> void:
	var stars := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var quad := PlaneMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	quad.material = mat
	mm.mesh = quad
	mm.instance_count = 900
	for i in range(mm.instance_count):
		var pos := Vector3(visual_rng.randf_range(-280.0, 280.0), visual_rng.randf_range(-150.0, 150.0),
			visual_rng.randf_range(-340.0, -55.0))
		var brilho := visual_rng.randf_range(0.2, 1.0)
		var tam := visual_rng.randf_range(0.3, 1.4)
		# Um em cada trinta e sete é largo e estoura no glow: são as que dão profundidade ao céu.
		if i % 37 == 0:
			tam *= 3.4
			brilho = minf(1.0, brilho * 1.6)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * tam), pos))
		mm.set_instance_color(i, Color(brilho, brilho * 1.05, brilho * 1.18))
	stars.multimesh = mm
	add_child(stars)

func _build_bridge() -> void:
	bridge_rig = Node3D.new()
	bridge_rig.name = "Capitânia - Ponte"
	add_child(bridge_rig)
	var piso := _material(Color(0.03, 0.045, 0.07), 0.62, 0.38)
	var casco_ponte := _material(Color(0.045, 0.062, 0.09), 0.5, 0.48)
	var trim := _material(Color(0.1, 0.14, 0.2), 0.55, 0.42)
	# Ouro é acento de filete, não luminária: a 0.45 de emissão ele competia com a holografia e a
	# ponte virava cenário de neon. LotGH usa o dourado na régua, discreto.
	var ouro := _material(HUD_OURO.darkened(0.62), 0.6, 0.34, HUD_OURO * 0.2)
	var tela := _material(Color(0.02, 0.06, 0.09), 0.2, 0.6, Color(0.03, 0.22, 0.34))
	# Costado, soalho e teto: sem eles a câmera flutua no vácuo em vez de estar dentro de um
	# navio. Tudo fecha no anteparo de vante, onde o visor se abre.
	_box(Vector3(0, -2.1, 2.2), Vector3(15, 0.5, 20), piso, bridge_rig)
	_box(Vector3(0, 5.4, 2.2), Vector3(15, 0.4, 20), casco_ponte, bridge_rig)
	for lado in [-1.0, 1.0]:
		_box(Vector3(lado * 7.4, 1.6, 2.2), Vector3(0.5, 8, 20), casco_ponte, bridge_rig)
		_box(Vector3(lado * 7.1, 3.4, 2.2), Vector3(0.14, 0.1, 19.4), ouro, bridge_rig)
	# Anteparo de vante com o visor escancarado: verga, peitoril e montantes, moldura em ouro.
	_box(Vector3(0, 4.65, -7.6), Vector3(15, 1.7, 0.55), casco_ponte, bridge_rig)
	_box(Vector3(0, -1.9, -7.6), Vector3(15, 1.4, 0.55), casco_ponte, bridge_rig)
	for lado in [-1.0, 1.0]:
		_box(Vector3(lado * 7.15, 1.5, -7.6), Vector3(0.9, 7.2, 0.55), casco_ponte, bridge_rig)
	_box(Vector3(0, 3.68, -7.75), Vector3(13.4, 0.13, 0.2), ouro, bridge_rig)
	_box(Vector3(0, -1.05, -7.75), Vector3(13.4, 0.13, 0.2), ouro, bridge_rig)
	for lado in [-1.0, 1.0]:
		_box(Vector3(lado * 2.3, 1.3, -7.7), Vector3(0.11, 4.7, 0.16), trim, bridge_rig)
	# O vidro quase não existe: só o brilho do canto, para a moldura segurar o quadro sem
	# esconder a batalha.
	var vidro := StandardMaterial3D.new()
	vidro.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vidro.albedo_color = Color(0.3, 0.55, 0.8, 0.05)
	vidro.metallic = 0.85
	vidro.roughness = 0.08
	vidro.cull_mode = BaseMaterial3D.CULL_DISABLED
	_box(Vector3(0, 1.3, -7.85), Vector3(13.2, 4.6, 0.05), vidro, bridge_rig)
	# Postos de trabalho em duas linhas de cada bordo: o console inclinado e a tela de leitura.
	for lado in [-1.0, 1.0]:
		for profundidade in [-0.8, -3.6]:
			var console := _box(Vector3(lado * 4.4, -0.85, profundidade), Vector3(3.4, 0.3, 2.1),
				trim, bridge_rig)
			console.rotation.x = -0.14
			_box(Vector3(lado * 4.4, -0.62, profundidade), Vector3(2.7, 0.04, 1.4), tela, bridge_rig)
			for tecla in range(5):
				_box(Vector3(lado * 4.4 + (float(tecla) - 2.0) * 0.44 * lado, -0.58, profundidade - 0.45),
					Vector3(0.16, 0.03, 0.5), _material(BLUE, 0.2, 0.3, BLUE * 0.4), bridge_rig)
	# trilho de comando abaixo do visor, onde a ponte apoia o olhar. A régua passa abaixo da
	# linha de vista da mesa: a 8 unidades de largura e y -1.1 ela fatiava a holografia ao meio
	# e escondia a segunda fila de blips, que é justamente a do inimigo.
	_box(Vector3(0, -1.66, -2.2), Vector3(6.6, 0.18, 0.35), ouro, bridge_rig)
	_build_holo_table()
	# Luz de trabalho: âmbar sobre os postos, fria sob a holografia. Sem sombra — o
	# Compatibility não shadowa, e ligar shadow aqui só imprimisse aviso por luz.
	var lampada := OmniLight3D.new()
	lampada.position = Vector3(0, 4.2, 1.5)
	lampada.light_color = Color(0.95, 0.72, 0.4)
	lampada.light_energy = 0.55
	lampada.omni_range = 14.0
	lampada.shadow_enabled = false
	bridge_rig.add_child(lampada)
	var fria := OmniLight3D.new()
	fria.position = Vector3(0, -0.6, -2.6)
	fria.light_color = Color(0.35, 0.8, 1.0)
	fria.light_energy = 0.5
	fria.omni_range = 8.0
	fria.shadow_enabled = false
	bridge_rig.add_child(fria)
	# Câmera atrás do trilho de comando: o parapeito entra no quadro como moldura inferior.
	var camera := Camera3D.new()
	camera.name = "BridgeCamera"
	camera.position = Vector3(0, 1.0, 3.0)
	camera.rotation_degrees = Vector3(-3, 0, 0)
	camera.fov = 78
	bridge_rig.add_child(camera)

## Mesa holográfica de ponte: disco, anéis e o cone do projetor. Os blips não são decoração —
## `_rebuild_holo` os monta a partir das listas vivas, então a mesa mostra exatamente a frota
## que o HUD conta.
func _build_holo_table() -> void:
	var base := _material(Color(0.04, 0.06, 0.085), 0.75, 0.35)
	_cylinder(Vector3(0, -1.52, -2.6), 3.05, 3.05, 0.14, base, bridge_rig, Vector3.ZERO, 24)
	for lado in [-1.0, 1.0]:
		_box(Vector3(lado * 2.6, -1.0, -1.4), Vector3(0.16, 1.1, 0.16), base, bridge_rig)
		_box(Vector3(lado * 2.6, -1.0, -3.8), Vector3(0.16, 1.1, 0.16), base, bridge_rig)
	var aro := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 2.95
	toro.outer_radius = 3.1
	aro.mesh = toro
	aro.position = Vector3(0, -1.44, -2.6)
	aro.material_override = _material(HUD_OURO.darkened(0.5), 0.8, 0.3, HUD_OURO * 0.6)
	bridge_rig.add_child(aro)
	holo_anel = Node3D.new()
	holo_anel.position = Vector3(0, -1.4, -2.6)
	bridge_rig.add_child(holo_anel)
	for raio in [1.0, 1.9, 2.75]:
		var anel := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = raio - 0.035
		torus.outer_radius = raio + 0.035
		anel.mesh = torus
		anel.material_override = _material(Color(0.1, 0.5, 0.7), 0.1, 0.4, Color(0.12, 0.62, 0.85))
		holo_anel.add_child(anel)
	# Cone do projetor: o volume de luz que sai do disco e segura os blips no ar.
	var cone := _cylinder(Vector3(0, -0.85, -2.6), 2.7, 0.35, 1.2, _glasm(Color(0.2, 0.62, 0.9, 0.07)),
		bridge_rig, Vector3.ZERO, 24)
	cone.rotation.x = PI
	holo_root = Node3D.new()
	holo_root.name = "Blips"
	holo_root.position = Vector3(0, -1.34, -2.6)
	bridge_rig.add_child(holo_root)
	mat_holo_aliado = _holo_mat(ESCOAMENTO_ALIADO)
	mat_holo_hostil = _holo_mat(Color(1.0, 0.34, 0.24))
	mat_holo_presa = _holo_mat(GOLD)
	mat_holo_morto = _holo_mat(Color(0.22, 0.24, 0.28))
	# O blip da capitânia é dourado e mora no rig, não na lista de blips: o rig não é unidade de
	# frota, e a conta de blip por casco vivo que `tools/probes/graficos.gd` confere tem de
	# continuar lendo só `fleet` + `enemies`.
	holo_capitania = _cylinder(holo_root.position + _holo_de(bridge_rig.position), 0.11, 0.0, 0.34,
		_holo_mat(HUD_OURO.lightened(0.25)), bridge_rig, Vector3.ZERO, 6)

func _holo_mat(cor: Color) -> StandardMaterial3D:
	# Emissão abaixo do limiar de bloom de propósito: o blip tem de ler como holograma colorido
	# da própria facção, não como lâmpada. A 1,6× o ACES estourava tudo em branco e a mesa
	# perdia a única informação que ela carrega — de que lado é o contato.
	return _material(cor.darkened(0.3), 0.0, 0.6, cor * 0.45)

func _glasm(cor: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = cor
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

## Posição de tabuleiro -> posição na mesa: o mesmo campo, na mesma proporção nos três eixos, com
## a altitude ampliada porque ela é a menor dimensão do combate. Quem sai da janela tática encosta
## no aro em vez de desaparecer da mesa.
func _holo_de(pos: Vector3) -> Vector3:
	var dx := pos.x * HOLO_SCALE
	var dz := (pos.z - HOLO_ANCHOR_Z) * HOLO_SCALE
	var raio := Vector2(dx, dz).length()
	if raio > HOLO_RIM:
		var fator := HOLO_RIM / raio
		dx *= fator
		dz *= fator
	return Vector3(dx, 0.1 + clampf(pos.y * HOLO_ALT_SCALE, -HOLO_ALT_CEIL, HOLO_ALT_CEIL), dz)

func _rebuild_holo() -> void:
	if not is_instance_valid(holo_root):
		return
	for blip in holo_blips.values():
		var ping: MeshInstance3D = blip
		if is_instance_valid(ping):
			ping.queue_free()
	holo_blips.clear()
	for grupo in [fleet, enemies]:
		for unit in grupo:
			var node: Node3D = unit["node"]
			if not is_instance_valid(node):
				continue
			var ping := _cylinder(_holo_de(node.position), 0.085, 0.0, 0.22, mat_holo_aliado,
				holo_root, Vector3.ZERO, 6)
			holo_blips[node.get_instance_id()] = ping

func _atualiza_blip(unit: Dictionary, aliada: bool) -> void:
	var node: Node3D = unit["node"]
	if not is_instance_valid(node) or not holo_blips.has(node.get_instance_id()):
		return
	var ping: MeshInstance3D = holo_blips[node.get_instance_id()]
	ping.position = _holo_de(node.position)
	if float(unit["hp"]) <= 0.0:
		ping.material_override = mat_holo_morto
	elif String(unit.get("squadron", "")) == "PRESA":
		ping.material_override = mat_holo_presa
	else:
		ping.material_override = mat_holo_aliado if aliada else mat_holo_hostil

## Acorda a ponte: anel girando e blip em dia com o tabuleiro. Roda também na pausa, porque a
## mesa existe para o comandante ler a batalha enquanto dá ordem.
func _update_bridge(_delta: float) -> void:
	if not is_instance_valid(holo_root):
		return
	holo_anel.rotation.y += _delta * 0.32
	for unit in fleet:
		_atualiza_blip(unit, true)
	for unit in enemies:
		_atualiza_blip(unit, false)
	# A capitânia também é corpo no campo, então também tem blip: o comandante precisa se ver na
	# mesa para não mandar a frota para cima da própria ponte.
	if is_instance_valid(holo_capitania):
		holo_capitania.position = holo_root.position + _holo_de(bridge_rig.position)

func _build_fleets() -> void:
	# A faixa de deslocamento inicial é pintura de formação, não sorteio de batalha: morava em
	# `rng`, e por isso a semente tinha de ser cravada depois de montar a frota — o que deixava a
	# posição de partida diferente entre duas rodadas com a mesma semente e impedia a sonda de
	# assinar um valor. Agora `rng` começa a salvar do zero, em toda partida.
	for i in range(6):
		var x := (float(i) - 2.5) * 5.0
		var z := -38.0 - (i % 2) * 5.0
		var ship := _make_ship(Vector3(x, visual_rng.randf_range(-2, 2), z), BLUE,
			1.1 + float(i % 3) * 0.06, "ALIADA %02d" % (i + 1))
		fleet.append({"node": ship, "order": "LINHA", "hp": 100.0, "max_hp": 100.0, "engines": 100.0, "weapons": 100.0, "crew": 100.0, "repair": 0.0, "repair_priority": "AUTO", "team": "friendly", "name": "ALIADA %02d" % (i + 1), "squadron": "ALFA" if i < 3 else "BETA"})
	for i in range(6):
		var x := (float(i) - 2.5) * 6.0
		var z := -82.0 - (i % 2) * 7.0
		var is_command := i == 0
		var ship := _make_ship(Vector3(x, visual_rng.randf_range(-3, 3), z), RED,
			1.55 if is_command else 1.3, "HOSTIL %02d" % (i + 1), is_command)
		enemies.append({"node": ship, "order": "AVANÇAR", "hp": 100.0, "max_hp": 100.0, "engines": 100.0, "weapons": 100.0, "crew": 100.0, "repair": 0.0, "team": "enemy", "name": "CAPITÂNIA HOSTIL" if is_command else "HOSTIL %02d" % (i + 1), "squadron": "INIMIGO", "role": "COMANDO" if is_command else "LINE"})

## Casco de linha em leitura Legend of the Galactic Heroes: aço neutro, um só filete de cor por
## nação, e o brilho guardado para motor e torre — nunca para o casco inteiro. Toda a geometria
## mora num filho "Casco": o nó raiz continua sendo a peça de xadrez que a sonda assina, e o
## balanço visual acontece no filho, sem mover um centímetro de tabuleiro.
func _make_ship(pos: Vector3, color: Color, scale_factor: float, ship_name: String,
		comando := false) -> Node3D:
	var ship := Node3D.new()
	ship.name = ship_name
	ship.position = pos
	ship.scale = Vector3.ONE * scale_factor
	add_child(ship)
	var casco := Node3D.new()
	casco.name = "Casco"
	ship.add_child(casco)
	var escape := ESCOAMENTO_HOSTIL if color == RED else ESCOAMENTO_ALIADO
	# Metal abaixo de 0.5 de propósito: no Compatibility a superfície metálica só brilha com
	# reflexão, e o nosso ambient é um céu quase preto. A 0.72 o casco não recebia o sol e a
	# linha inteira virava ponto de motor no escuro — o aço precisa de difusa para ter volume.
	var mat_hull := _material(ACO, 0.28, 0.62)
	var mat_steel := _material(ACO_ESCURO, 0.42, 0.5)
	var mat_trim := _material(color.darkened(0.35), 0.5, 0.3, color * 0.7)
	var mat_gun := _material(ACO_ESCURO.lightened(0.12), 0.8, 0.3, color * 0.4)
	var mat_engine := _material(escape.darkened(0.65), 0.6, 0.3, escape)
	var mat_flare := _glasm(Color(escape, 0.55))
	var mat_luz := _glasm(Color(escape, 0.75))
	var plumas: Array[MeshInstance3D] = []
	# Espinha comprida: é o volume que lê a nave como lâmina mesmo de fora do visor.
	_box(Vector3(0, 0, 0), Vector3(1.5, 0.66, 5.4), mat_hull, casco)
	# Proa em cone: sem caixa no nariz, a silhueta afila.
	_cylinder(Vector3(0, 0, -4.02), 0.74, 0.05, 2.6, mat_hull, casco, Vector3(-PI / 2, 0, 0), 8)
	_box(Vector3(0, 0.02, 2.5), Vector3(1.9, 0.78, 1.4), mat_steel, casco)
	_box(Vector3(0, 0.5, -0.8), Vector3(0.78, 0.34, 3.3), mat_steel, casco)
	# Torre de comando: na capitânia ela sobe e leva o mastro dourado, a silhueta que se
	# aprende a procurar no meio da linha.
	if comando:
		_box(Vector3(0, 1.05, 0.25), Vector3(0.7, 0.95, 1.45), mat_hull, casco)
		_box(Vector3(0, 1.75, 0.25), Vector3(0.16, 0.75, 0.16),
			_material(HUD_OURO.darkened(0.3), 0.6, 0.28, HUD_OURO * 0.5), casco)
	else:
		_box(Vector3(0, 0.86, 0.25), Vector3(0.62, 0.5, 1.15), mat_hull, casco)
	for lado in [-1.0, 1.0]:
		# Asa varrida para trás: o ângulo é o que separa cruzador de tijolo. A largura é a
		# conta: a linha fecha a 5 unidades de passo, então casco com envergadura acima de
		# ~4 unidades faz a frota se sobrepor e o tabuleiro vira uma mancha só.
		var asa := _box(Vector3(lado * 1.28, -0.02, 0.75), Vector3(1.5, 0.15, 2.6), mat_hull, casco)
		asa.rotation.y = lado * 0.42
		var filete := _box(Vector3(lado * 1.32, 0.09, 0.75), Vector3(1.42, 0.06, 0.34), mat_trim, casco)
		filete.rotation.y = lado * 0.42
		# Nacele gêmea, bocal fechado e pluma por trás do bocal.
		_cylinder(Vector3(lado * 1.72, 0.14, 1.5), 0.28, 0.2, 3.4, mat_steel, casco,
			Vector3(-PI / 2, 0, 0), 8)
		_cylinder(Vector3(lado * 1.72, 0.14, 3.35), 0.2, 0.17, 0.4, mat_engine, casco,
			Vector3(-PI / 2, 0, 0), 8)
		plumas.append(_quad(Vector3(lado * 1.72, 0.14, 3.9), 0.8, mat_flare, casco))
	# Torres por toda a dorsal: é a parte que acende com o `weapons` e apaga com ele.
	for z in [-1.9, -0.4, 1.1, 2.0]:
		_box(Vector3(0, 0.72, z), Vector3(0.4, 0.2, 0.6), mat_gun, casco)
	# Luz de proa: o mesmo billete da pluma, com material próprio para a presa reacender azul.
	_quad(Vector3(0, 0.0, -3.2), 0.3, mat_luz, casco)
	ship.set_meta("casco", casco)
	ship.set_meta("mat", {"hull": mat_hull, "steel": mat_steel, "trim": mat_trim,
		"gun": mat_gun, "engine": mat_engine, "flare": mat_flare, "luz": mat_luz})
	ship.set_meta("escape", escape)
	ship.set_meta("plumas", plumas)
	# O hostil encara a linha aliada: -Z é a proa de quem ataca, então a frota de fora gira
	# meia-volta em vez de virar as costas para a própria batalha.
	if color == RED:
		ship.rotation.y = PI
	return ship

## A leitura de dano é feita de material, não de geometria: o aço escurece e acende brasa com o
## casco, a pluma emagrece com o motor, a torre apaga com a arma e o filete com a tripulação.
## Roda só em casco vivo, mexe só em nós e recursos que já existem. Nenhum sorteio.
func _tune_ship_look(unit: Dictionary) -> void:
	var ship: Node3D = unit["node"]
	if not is_instance_valid(ship):
		return
	var mats: Dictionary = ship.get_meta("mat")
	var hull := clampf(float(unit["hp"]), 0.0, 100.0) / 100.0
	var engines := clampf(float(unit["engines"]), 0.0, 100.0) / 100.0
	var weapons := clampf(float(unit["weapons"]), 0.0, 100.0) / 100.0
	var crew := clampf(float(unit["crew"]), 0.0, 100.0) / 100.0
	var mat_hull: StandardMaterial3D = mats["hull"]
	mat_hull.albedo_color = ACO.lerp(CARVAO, (1.0 - hull) * 0.62)
	mat_hull.emission_enabled = true
	mat_hull.emission = BRASA
	# A brasa acende exatamente na porta dos 55% e sobe até o fundo do casco: a mesma porta que
	# `_resolve_volley` e `_give_order` já cobram (`hp > 55.0` recusa a abordagem). Ramp linear a
	# partir de 0 nesse ponto daria 0,0000 em 55% e 0,026 em 54% — invisível da ponte.
	mat_hull.emission_energy_multiplier = 0.0 if hull > 0.55 else 0.35 + (0.55 - hull) * 2.0
	var mat_engine: StandardMaterial3D = mats["engine"]
	mat_engine.emission_energy_multiplier = 0.2 + engines * engines * 2.8
	var mat_flare: StandardMaterial3D = mats["flare"]
	mat_flare.albedo_color = Color(ship.get_meta("escape"), 0.08 + engines * 0.5)
	for pluma in ship.get_meta("plumas"):
		var q: MeshInstance3D = pluma
		q.scale = Vector3(0.45 + engines * 1.05, 1.0, 0.45 + engines * 1.05)
	var mat_gun: StandardMaterial3D = mats["gun"]
	mat_gun.emission_energy_multiplier = 0.15 + weapons * 1.6
	var mat_trim: StandardMaterial3D = mats["trim"]
	mat_trim.emission_energy_multiplier = 0.1 + crew * 0.9
	# Balanço de deriva no filho "Casco": a peça de xadrez não se move, quem ondula é a
	# silhueta. `position` da raiz continua sendo a assinatura que as sondas conferem.
	var casco: Node3D = ship.get_meta("casco")
	casco.position.y = sin(battle_clock * 0.55 + ship.position.x * 0.35) * 0.1
	casco.rotation.z = sin(battle_clock * 0.33 + ship.position.z * 0.21) * 0.045

## Destroço que permanece no tabuleiro: casco carvão, brasa baixa, luzes mortas e a inclinação
## de quem perdeu propulsão. Some a leitura de vida, não a nave — esconder o corpo tirava a
## baixa do campo de visão da ponte.
func _mark_wreck(ship: Node3D) -> void:
	if not is_instance_valid(ship):
		return
	var mats: Dictionary = ship.get_meta("mat")
	for chave in mats:
		var mat: StandardMaterial3D = mats[chave]
		mat.emission_energy_multiplier = 0.0
	var mat_hull: StandardMaterial3D = mats["hull"]
	mat_hull.albedo_color = CARVAO
	mat_hull.emission = BRASA
	mat_hull.emission_energy_multiplier = 0.14
	# Billete aditivo não obedece a `emission_energy`: o que apaga a luz é o alfa.
	(mats["flare"] as StandardMaterial3D).albedo_color.a = 0.0
	(mats["luz"] as StandardMaterial3D).albedo_color.a = 0.0
	for pluma in ship.get_meta("plumas"):
		var q: MeshInstance3D = pluma
		q.scale = Vector3.ONE * 0.2
	var casco: Node3D = ship.get_meta("casco")
	casco.rotation.z = 0.42
	casco.rotation.x = -0.18
	_spawn_explosion(ship.position, ship.get_meta("escape"))

## Detonação em billets aditivos com deslocamentos fixos: cinco clarões que abrem e apagam em
## meio segundo. Nada aqui sorteia — é o que separa efeito visual de regressão de economia.
func _spawn_explosion(pos: Vector3, cor: Color) -> void:
	for i in range(DETONACAO.size()):
		var estouro := _flare(pos + DETONACAO[i], 1.4 + float(i) * 0.4, Color(cor, 0.85), self)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(estouro, "scale", Vector3.ONE * (3.2 + float(i) * 0.9), 0.5)
		tween.tween_property(estouro.material_override, "albedo_color:a", 0.0, 0.5)
		tween.chain().tween_callback(estouro.queue_free)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 64
	top.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.026, 0.042, 0.92), HUD_OURO.darkened(0.45)))
	layer.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 24)
	top.add_child(top_row)
	var title := Label.new()
	title.text = "I R O N   S T A R S   //   FLEET COMMAND"
	title.add_theme_color_override("font_color", HUD_OURO.lightened(0.35))
	title.add_theme_font_size_override("font_size", 19)
	top_row.add_child(title)
	speed_label = Label.new()
	speed_label.text = "VELOCIDADE +000%  //  SUBIDA +000  //  CASCO DA CAPITÂNIA 100%"
	speed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(speed_label)
	pause_button = _add_button(top_row, "PAUSAR [ESPAÇO]", _toggle_pause)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 94)
	panel.custom_minimum_size = Vector2(396, 620)
	panel.size = Vector2(396, 620)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.016, 0.024, 0.04, 0.9), Color(0.1, 0.42, 0.62)))
	layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(372, 600)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 280
	col.add_theme_constant_override("separation", 8)
	scroll.add_child(col)
	var head := Label.new()
	head.text = "HOLOGRAMA TÁTICO"
	head.add_theme_font_size_override("font_size", 18)
	head.add_theme_color_override("font_color", Color(0.35, 0.82, 1.0))
	col.add_child(head)
	command_label = Label.new()
	command_label.text = "FROTA: 6 NAVES | FORMAÇÃO: LINHA"
	command_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(command_label)
	var scope_title := Label.new()
	scope_title.text = "UNIDADES SOB COMANDO"
	col.add_child(scope_title)
	scope_selector = OptionButton.new()
	scope_selector.item_selected.connect(_on_scope_selected)
	col.add_child(scope_selector)
	var target_title := Label.new()
	target_title.text = "ALVO HOSTIL"
	col.add_child(target_title)
	target_selector = OptionButton.new()
	target_selector.item_selected.connect(_on_target_selected)
	col.add_child(target_selector)
	var subsystem_title := Label.new()
	subsystem_title.text = "SUBSISTEMA DO ALVO"
	col.add_child(subsystem_title)
	subsystem_selector = OptionButton.new()
	for subsystem in ["CASCO", "MOTORES", "ARMAS", "TRIPULAÇÃO"]:
		subsystem_selector.add_item(subsystem)
	col.add_child(subsystem_selector)
	var protect_title := Label.new()
	protect_title.text = "UNIDADE A PROTEGER / ESCOLTAR"
	col.add_child(protect_title)
	protected_selector = OptionButton.new()
	protected_selector.item_selected.connect(_on_protected_selected)
	col.add_child(protected_selector)
	var destination_title := Label.new()
	destination_title.text = "POSIÇÃO DE DESTINO (X / Z)"
	col.add_child(destination_title)
	var destination_row := HBoxContainer.new()
	position_x_input = SpinBox.new()
	position_x_input.min_value = -80
	position_x_input.max_value = 80
	position_x_input.step = 5
	position_x_input.value = 0
	position_x_input.prefix = "X "
	position_z_input = SpinBox.new()
	position_z_input.min_value = -160
	position_z_input.max_value = 20
	position_z_input.step = 5
	position_z_input.value = -65
	position_z_input.prefix = "Z "
	destination_row.add_child(position_x_input)
	destination_row.add_child(position_z_input)
	col.add_child(destination_row)
	_add_button(col, "ATACAR ALVO / SUBSISTEMA", func(): _give_order("ATACAR"))
	_add_button(col, "MOVER PARA POSIÇÃO", func(): _give_order("MOVER"))
	_add_button(col, "AVANÇAR", func(): _give_order("AVANÇAR"))
	_add_button(col, "MANTER POSIÇÃO", func(): _give_order("MANTER"))
	_add_button(col, "RECUAR", func(): _give_order("RECUAR"))
	_add_button(col, "CONCENTRAR FOGO", func(): _give_order("ATACAR"))
	_add_button(col, "ESCOLTAR CAPITÂNIA", func(): _give_order("ESCOLTAR"))
	_add_button(col, "SONDAS DE RECONHECIMENTO", func(): _give_order("RECONHECER"))
	_add_button(col, "RESERVA TÁTICA", func(): _give_order("RESERVA"))
	_add_button(col, "ABORDAR ALVO DANIFICADO", func(): _give_order("ABORDAR"))
	_add_button(col, "REPAROS: PRIORIDADE MOTORES", func(): _set_repair_priority("MOTORES"))
	_add_button(col, "REPAROS: PRIORIDADE ARMAS", func(): _set_repair_priority("ARMAS"))
	_add_button(col, "REPAROS: PRIORIDADE CASCO", func(): _set_repair_priority("CASCO"))
	_add_button(col, "REPAROS: PRIORIDADE TRIPULAÇÃO", func(): _set_repair_priority("TRIPULAÇÃO"))
	_add_button(col, "REPAROS: AUTOMÁTICOS", func(): _set_repair_priority("AUTO"))
	_add_button(col, "FORMAÇÃO: LINHA", func(): _set_formation("LINHA"))
	_add_button(col, "FORMAÇÃO: COLUNA", func(): _set_formation("COLUNA"))
	_add_button(col, "FORMAÇÃO: CUNHA", func(): _set_formation("CUNHA"))
	_add_button(col, "FORMAÇÃO: ANEL", func(): _set_formation("ANEL"))
	var hint := Label.new()
	hint.text = ("W avante  •  S ré (a ré tem teto)\nA / D guinada  •  ↑ / ↓ arfagem  •  "
		+ "Q / E rolagem\nR sobe  •  V desce  •  ESPAÇO pausa tática")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.65, 0.78, 0.9))
	col.add_child(hint)
	var report_panel := PanelContainer.new()
	report_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	report_panel.offset_top = -58
	report_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.026, 0.04, 0.88), HUD_OURO.darkened(0.5)))
	layer.add_child(report_panel)
	report_label = Label.new()
	report_label.text = "PONTE DE COMANDO ONLINE  //  Contatos hostis detectados à frente."
	report_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	report_panel.add_child(report_label)
	# Os três seletores leem a frota real; construir os itens por aqui mantém a lista
	# verdadeira quando uma presa é incorporada.
	_rebuild_selectors()

func _add_button(parent: Node, text_value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 36)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0))
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.035, 0.09, 0.15, 0.96), Color(0.12, 0.42, 0.62)))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.06, 0.2, 0.3, 1), Color(0.3, 0.75, 1.0)))
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _panel_style(bg: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _material(color: Color, metal: float = 0.2, rough: float = 0.45, glow: Color = Color.BLACK) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = rough
	if glow != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = glow
		mat.emission_energy_multiplier = 1.4
	return mat

func _box(pos: Vector3, size: Vector3, mat: Material, parent: Node = null) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = mat
	if parent == null:
		add_child(mesh_instance)
	else:
		parent.add_child(mesh_instance)
	return mesh_instance

## Prisma com os dois raios: é com ele que a proa afila e o bocal de motor fecha em disco.
## Em `_cylinder` o eixo local é +Y, então `rot = Vector3(-PI/2, 0, 0)` aponta o topo para -Z.
func _cylinder(pos: Vector3, r_base: float, r_top: float, height: float, mat: Material,
		parent: Node, rot: Vector3 = Vector3.ZERO, radial: int = 10) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = r_base
	mesh.top_radius = r_top
	mesh.height = height
	# A propriedade se chama `radial_segments`: o nome errado não falha no parse, aborta a
	# função em runtime e devolve Nil — a mesa holográfica inteira desapareceu assim por uma
	# rodada, com as três sondas de lógica passando verdes.
	mesh.rings = 2
	mesh.radial_segments = radial
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.rotation = rot
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	return mesh_instance

## Bilhete aditivo sempre de frente para a câmera: sem pós-processamento caro é assim que o
## motor, o lance e a explosão estouram no glow do Compatibility.
func _flare(pos: Vector3, size: float, color: Color, parent: Node) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(size, size)
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	return mesh_instance

## Mesmo billet de `_flare`, mas com o material vindo de fora: é assim que a pluma de cada
## motor queima sozinha (o material pertence à nave) sem criar material novo por quadro.
func _quad(pos: Vector3, size: float, mat: Material, parent: Node) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(size, size)
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	return mesh_instance

## Registra o timão no InputMap antes de qualquer UI. Fazer isso em código (e não no
## `project.godot`) mantém a tabela de teclas ao lado de quem a lê e poupa o arquivo de
## configuração de uma serialização `Object(InputEventKey,...)` que muda com o motor.
func _registra_voo() -> void:
	for acao: String in VOO_ACOES:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao, 0.0)
		var tecla := InputEventKey.new()
		tecla.keycode = VOO_ACOES[acao]
		InputMap.action_add_event(acao, tecla)
		var fisica := InputEventKey.new()
		fisica.physical_keycode = VOO_ACOES[acao]
		InputMap.action_add_event(acao, fisica)

## Timão da capitânia em três eixos: guinada (A/D), arfagem (setas ↑/↓), rolagem (Q/E, que se
## autocorrige quando a mão sai do teclado para a mesa continuar legível), avante e ré (W/S, com a
## ré limitada) e empuxo vertical (R/V, sobe e desce sem mudar a atitude). Nada aqui sorteia: a
## posição do rig é leitura de teclado, e é por isso que a sonda de voo pode afirmar coordenada.
func _update_capital_ship(delta: float) -> void:
	var turn := 0.0
	if Input.is_action_pressed("capital_bombordo"):
		turn += 1.0
	if Input.is_action_pressed("capital_estibordo"):
		turn -= 1.0
	var pitch := 0.0
	if Input.is_action_pressed("capital_nariz_acima"):
		pitch += 1.0
	if Input.is_action_pressed("capital_nariz_abaixo"):
		pitch -= 1.0
	var roll := 0.0
	if Input.is_action_pressed("capital_role_esquerda"):
		roll += 1.0
	if Input.is_action_pressed("capital_role_direita"):
		roll -= 1.0
	var lift := 0.0
	if Input.is_action_pressed("capital_empuxo_acima"):
		lift += 1.0
	if Input.is_action_pressed("capital_empuxo_abaixo"):
		lift -= 1.0
	var avante := Input.is_action_pressed("capital_avante")
	var re := Input.is_action_pressed("capital_re")
	if avante:
		throttle = minf(1.0, throttle + delta * 0.5)
	if re:
		throttle = maxf(CAPITAL_REVERSE, throttle - delta * 0.6)
	# Sem mão no acelerador o casco perde velocidade aos poucos: manobra tem inércia, mas o
	# jogador nunca fica à deriva sem saber por quê.
	if not avante and not re:
		throttle = move_toward(throttle, 0.0, delta * 0.3)
	bridge_rig.rotation.y += turn * delta * 0.28
	bridge_rig.rotation.x = clampf(bridge_rig.rotation.x + pitch * delta * 0.5, -PITCH_LIMIT, PITCH_LIMIT)
	bridge_rig.rotation.z = clampf(move_toward(bridge_rig.rotation.z, roll * ROLL_LIMIT, delta * 0.9),
		-ROLL_LIMIT, ROLL_LIMIT)
	var anterior := bridge_rig.position
	# O rumo sai da transformada global do rig, então arfar aponta o empuxo para cima de verdade:
	# subir com o nariz erguido e subir com o vetor de proa são manobras diferentes na ponte.
	var rumo := -bridge_rig.global_transform.basis.z
	bridge_rig.position += (rumo * throttle * CAPITAL_SPEED + Vector3(0.0, lift * CAPITAL_LIFT, 0.0)) * delta
	bridge_rig.position.x = clampf(bridge_rig.position.x, -MAP_X, MAP_X)
	bridge_rig.position.y = clampf(bridge_rig.position.y, -MAP_Y, MAP_Y)
	bridge_rig.position.z = clampf(bridge_rig.position.z, MAP_Z_FAR, MAP_Z_NEAR)
	capital_velocity = (bridge_rig.position - anterior) / maxf(delta, 0.0001)

func _update_fleet(delta: float) -> void:
	# Ambas as frotas agem continuamente; ordens mudam comportamento, não iniciam turnos.
	for i in range(fleet.size()):
		var ally: Dictionary = fleet[i]
		var ship: Node3D = ally["node"]
		if ally["hp"] <= 0.0 or not is_instance_valid(ship):
			continue
		var mobility: float = 0.25 + float(ally["engines"]) / 100.0 * 0.75
		var partida := ship.position
		if ally["order"] == "MOVER" and ally.has("destination"):
			ship.position = ship.position.move_toward(ally["destination"], delta * 8.0 * mobility)
		elif ally["order"] == "AVANÇAR":
			ship.position.z -= delta * 1.2 * mobility
		elif ally["order"] == "RECUAR":
			ship.position.z += delta * 1.3 * mobility
		elif ally["order"] == "ESCOLTAR":
			var protect_position := Vector3.ZERO
			if protected_unit_index >= 0 and protected_unit_index < fleet.size():
				protect_position = (fleet[protected_unit_index]["node"] as Node3D).position
			var escort_destination := protect_position + Vector3((float(i) - 2.5) * FORMATION_STEP, 0, 8.0 if protected_unit_index >= 0 else -12.0)
			ship.position = ship.position.lerp(escort_destination, minf(1.0, delta * 0.35))
		elif ally["order"] == "RESERVA":
			ship.position.z = move_toward(ship.position.z, -48.0, delta * 0.8)
		elif ally["order"] == "RECONHECER":
			ship.position.x = move_toward(ship.position.x, (float(i) - 2.5) * 9.0, delta * 1.8)
		elif ally["order"] == "ABORDAR" and selected_target < enemies.size() and enemies[selected_target]["hp"] > 0.0:
			var target: Node3D = enemies[selected_target]["node"]
			ship.position = ship.position.move_toward(target.position + Vector3((float(i) - 2.5) * 2.0, 0, 8.0), delta * 2.2 * mobility)
		# Velocidade real do quadro, medida por diferença de posição: é o que o abalroamento lê
		# para separar encostar de bater, sem inventar um sorteio de impacto.
		ally["veloc"] = (ship.position - partida) / maxf(delta, 0.0001)
		# Automatic repair crews follow the commander priority, or balance repairs by default.
		var repair_rate := delta * (2.2 if float(ally["crew"]) > 25.0 else 1.0)
		var priority: String = ally.get("repair_priority", "AUTO")
		if priority == "MOTORES":
			ally["engines"] = minf(100.0, float(ally["engines"]) + repair_rate)
		elif priority == "ARMAS":
			ally["weapons"] = minf(100.0, float(ally["weapons"]) + repair_rate)
		elif priority == "CASCO":
			ally["hp"] = minf(100.0, float(ally["hp"]) + repair_rate)
		elif priority == "TRIPULAÇÃO":
			ally["crew"] = minf(100.0, float(ally["crew"]) + repair_rate)
		else:
			if ally["engines"] < 85.0:
				ally["engines"] = minf(100.0, float(ally["engines"]) + repair_rate * 0.6)
			if ally["weapons"] < 85.0:
				ally["weapons"] = minf(100.0, float(ally["weapons"]) + repair_rate * 0.6)
			if ally["hp"] < 100.0:
				ally["hp"] = minf(100.0, float(ally["hp"]) + repair_rate * 0.25)
			if ally["crew"] < 100.0:
				ally["crew"] = minf(100.0, float(ally["crew"]) + repair_rate * 0.2)
		fleet[i] = ally
		_tune_ship_look(ally)
	# A escolta hostil estaciona em torno da própria capitânia, então a âncora é lida uma
	# vez por quadro — não por nave.
	var hostile_anchor := Vector3.ZERO
	var hostile_command := _hostile_command_index()
	if hostile_command >= 0 and is_instance_valid(enemies[hostile_command]["node"]):
		hostile_anchor = (enemies[hostile_command]["node"] as Node3D).position
	for enemy in enemies:
		var foe: Node3D = enemy["node"]
		if enemy["hp"] <= 0.0 or not is_instance_valid(foe):
			continue
		var mobility: float = 0.25 + float(enemy["engines"]) / 100.0 * 0.75
		var partida := foe.position
		if enemy["order"] == "AVANÇAR":
			foe.position.z += delta * 0.85 * mobility
		elif enemy["order"] == "RECUAR":
			foe.position.z -= delta * 0.45 * mobility
		elif enemy["order"] == "ESCOLTAR":
			# Posto alternado pela IA (-3 / +3): duas escoltas no mesmo ponto se tapariam.
			var side: float = float(enemy.get("escort_offset", 3.0))
			foe.position = foe.position.move_toward(hostile_anchor + Vector3(side, 0.0, 7.0), delta * 1.1 * mobility)
		# Qualquer que seja a ordem, o casco hostil fica entre a linha de reunião e a de
		# avanço: a batalha não migra para fora da vista da ponte.
		foe.position.z = clampf(foe.position.z, HOSTILE_RALLY_Z, HOSTILE_ADVANCE_Z)
		enemy["veloc"] = (foe.position - partida) / maxf(delta, 0.0001)
		_tune_ship_look(enemy)
	# Por último a física de contato: primeiro cada casco obedece à ordem, depois o campo cobra
	# quem atravessou quem. Inverter a ordem faria a separação ser sobrescrita pela ordem no
	# mesmo quadro, e a colisão viraria enfeite.
	_resolve_collisions()

## Corpos que ocupam espaço: frota, hostis e a própria ponte. Destroço entra como âncora
## (`imovel`) porque baixar tem de continuar no quadro e não pode ser empurrado por quem vive.
func _collision_bodies() -> Array[Dictionary]:
	var bodies: Array[Dictionary] = []
	for unit in fleet:
		var node: Node3D = unit["node"]
		if not is_instance_valid(node):
			continue
		bodies.append({"node": node, "unidade": unit, "raio": HULL_RADIUS, "hostil": false,
			"imovel": float(unit["hp"]) <= 0.0})
	for unit in enemies:
		var node: Node3D = unit["node"]
		if not is_instance_valid(node):
			continue
		bodies.append({"node": node, "unidade": unit, "raio": HULL_RADIUS, "hostil": true,
			"imovel": float(unit["hp"]) <= 0.0})
	bodies.append({"node": bridge_rig, "unidade": null, "raio": CAPITAL_RADIUS, "hostil": false,
		"imovel": false})
	return bodies

func _resolve_collisions() -> void:
	var bodies := _collision_bodies()
	for a in range(bodies.size()):
		for b in range(a + 1, bodies.size()):
			_separate_pair(bodies[a], bodies[b])

## Separação posicional e dano de abalroamento. Empurra menos quem tem mais casco; um destroço é
## âncora e não sai do lugar. Nenhum sorteio aqui — impacto é geometria, e um `rng.randf()` de
## colisão reescreveria toda a cauda de dano da salva seguinte (ver `visual_rng`).
func _separate_pair(a: Dictionary, b: Dictionary) -> void:
	var node_a: Node3D = a["node"]
	var node_b: Node3D = b["node"]
	var entre_cascos := node_b.global_position - node_a.global_position
	var distancia := entre_cascos.length()
	var soma := float(a["raio"]) + float(b["raio"])
	if distancia >= soma:
		return
	# Dois cascos exatamente no mesmo ponto não têm normal: empurra em +Z, sem sorteio de eixo.
	var normal := Vector3(0, 0, 1) if distancia < 0.001 else entre_cascos / distancia
	var sobreposicao := soma - distancia
	if bool(a["imovel"]):
		node_b.global_position += normal * sobreposicao
	elif bool(b["imovel"]):
		node_a.global_position -= normal * sobreposicao
	else:
		# Peso distribuído pelo casco: o pequeno cede mais que o grande.
		var cessao_a := float(b["raio"]) / soma
		var cessao_b := float(a["raio"]) / soma
		node_a.global_position -= normal * sobreposicao * cessao_a
		node_b.global_position += normal * sobreposicao * cessao_b
	var vel_a := _body_velocity(a)
	var vel_b := _body_velocity(b)
	var aproximacao := (vel_a - vel_b).dot(normal)
	if aproximacao <= RAM_SPEED:
		return
	# Casco aliado contra casco aliado não cobra: separar é física, fere é combate. A formação que
	# acaba de ser mandada navegar atravessa a própria linha, e punir isso tiraria do jogador o
	# preço de uma manobra que ele não controla quadro a quadro. A ponte é exceção: quem segura o
	# timão é o comandante, e abalroar a própria frota custa.
	if not bool(a["hostil"]) and not bool(b["hostil"]) and a["unidade"] != null and b["unidade"] != null:
		return
	var chave := _pair_key(a, b)
	if battle_clock - float(ram_windows.get(chave, -RAM_WINDOW)) < RAM_WINDOW:
		return
	ram_windows[chave] = battle_clock
	var dano := clampf((aproximacao - RAM_SPEED) * RAM_DAMAGE, 1.0, RAM_MAX_DAMAGE)
	var nome_a := _body_name(a)
	var nome_b := _body_name(b)
	_apply_impact(a, dano)
	_apply_impact(b, dano)
	if is_instance_valid(report_label):
		report_label.text = "ESPERAMENTO // %s e %s trocaram casco no abalroamento (-%0.1f)." % [
			nome_a, nome_b, dano]

func _body_velocity(body: Dictionary) -> Vector3:
	if body["unidade"] == null:
		return capital_velocity
	if bool(body["imovel"]):
		return Vector3.ZERO
	return body["unidade"].get("veloc", Vector3.ZERO)

func _body_name(body: Dictionary) -> String:
	if body["unidade"] == null:
		return "CAPITÂNIA"
	return String(body["unidade"]["name"])

func _pair_key(a: Dictionary, b: Dictionary) -> String:
	var nodo_a: Node3D = a["node"]
	var nodo_b: Node3D = b["node"]
	var id_a := nodo_a.get_instance_id()
	var id_b := nodo_b.get_instance_id()
	return "%d:%d" % [mini(id_a, id_b), maxi(id_a, id_b)]

## O dano do impacto entra pelo casco, e afunda motor e arma porque nada em um cruzador absorve
## uma bordaada sem quebrar uma linha de eixo. Se o casco fecha ali, a marca de destroço é feita
## aqui — senão o corpo ficaria vivo na conta e pintado como perda.
func _apply_impact(body: Dictionary, dano: float) -> void:
	if body["unidade"] == null:
		capital_hp = maxf(0.0, capital_hp - dano)
		if capital_hp <= 0.0 and is_instance_valid(report_label):
			report_label.text = "PONTE DESTRUÍDA // a capitânia perdeu o comando da frota."
		return
	var unit: Dictionary = body["unidade"]
	if float(unit["hp"]) <= 0.0:
		return
	unit["hp"] = maxf(0.0, float(unit["hp"]) - dano)
	unit["engines"] = maxf(0.0, float(unit["engines"]) - dano * 0.5)
	unit["weapons"] = maxf(0.0, float(unit["weapons"]) - dano * 0.5)
	if float(unit["hp"]) <= 0.0:
		_mark_wreck(unit["node"] as Node3D)
		if is_instance_valid(report_label):
			report_label.text = "ABALROAMENTO // %s fechou no impacto." % String(unit["name"])

## Lança uma sonda por casco vivo selecionado que ainda não tenha outra em órbita. Não há
## custo em números: a moeda da sonda é a cobertura do tabuleiro, e o teto é um objeto por
## navio — por isso o segundo clique na mesma seleção não empilha nada.
func _launch_probes(indices: Array[int]) -> int:
	var launched := 0
	for i in indices:
		if float(fleet[i]["hp"]) <= 0.0 or not is_instance_valid(fleet[i]["node"]):
			continue
		var busy := false
		for probe in probes:
			if int(probe["from"]) == i:
				busy = true
				break
		if busy:
			continue
		var origin: Node3D = fleet[i]["node"]
		# Corredor determinístico: a sonda desce a linha no x do hostil da mesma ordem, então
		# cada navio cobre o seu próprio setor e a cobertura total exige a frota lançada.
		var lane_x := (float(i) - 2.5) * 6.0
		var node := _make_probe(origin.position + Vector3(0.0, 1.4, -3.0))
		probes.append({"node": node, "from": i, "lane_x": lane_x, "outbound": true,
			"waypoint": Vector3(lane_x, 0.0, PROBE_FAR_Z), "life": PROBE_LIFE,
			"launcher": String(fleet[i]["name"])})
		launched += 1
	return launched

func _make_probe(pos: Vector3) -> Node3D:
	var probe := Node3D.new()
	probe.position = pos
	add_child(probe)
	var glow := Color(0.35, 0.9, 1.0)
	_box(Vector3(0, 0, 0), Vector3(0.5, 0.5, 0.9), _material(glow.darkened(0.55), 0.5, 0.3, glow * 0.7), probe)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.15
	torus.outer_radius = 1.75
	ring.mesh = torus
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.material_override = _material(glow, 0.1, 0.2, glow * 0.55)
	probe.add_child(ring)
	return probe

## Varredura em si: a sonda é um corpo no tabuleiro, então o que ela confirma é o casco que
## ela fisicamente alcança. Nada aqui consome `rng` nem escreve em subsistema — só em
## `seen`, que é informação, não força de combate.
func _update_probes(delta: float) -> void:
	var i := probes.size() - 1
	while i >= 0:
		var probe: Dictionary = probes[i]
		var node: Node3D = probe["node"]
		probe["life"] = float(probe["life"]) - delta
		if float(probe["life"]) <= 0.0 or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			probes.remove_at(i)
			i -= 1
			continue
		var waypoint: Vector3 = probe["waypoint"]
		node.position = node.position.move_toward(waypoint, delta * PROBE_SPEED)
		if node.position.distance_to(waypoint) < 0.6:
			probe["outbound"] = not bool(probe["outbound"])
			probe["waypoint"] = Vector3(float(probe["lane_x"]), 0.0,
				PROBE_FAR_Z if bool(probe["outbound"]) else PROBE_NEAR_Z)
		_scan_with_probe(node)
		probes[i] = probe
		i -= 1
	_recompute_recon()

func _scan_with_probe(node: Node3D) -> void:
	for i in range(enemies.size()):
		var foe: Dictionary = enemies[i]
		if float(foe["hp"]) <= 0.0 or String(foe["order"]) == "CAPTURADO" or bool(foe.get("seen", false)):
			continue
		if not is_instance_valid(foe["node"]):
			continue
		if (foe["node"] as Node3D).global_position.distance_to(node.global_position) <= PROBE_SCAN_RADIUS:
			foe["seen"] = true
			enemies[i] = foe

## Uma fórmula só para o reconhecimento: a barra da ponte é a fração da linha hostil viva que
## já foi encostada por uma sonda. Quem morre sai do denominador, quem é capturado também.
func _recompute_recon() -> void:
	var living := 0
	var known := 0
	for foe in enemies:
		if float(foe["hp"]) <= 0.0 or String(foe["order"]) == "CAPTURADO":
			continue
		living += 1
		if bool(foe.get("seen", false)):
			known += 1
	recon_total = living
	recon_contacts = known
	recon_progress = 0.0 if living == 0 else 100.0 * float(known) / float(living)

func _combat_power(unit: Dictionary) -> float:
	return float(unit["hp"]) * 0.5 + float(unit["weapons"]) * 0.3 + float(unit["engines"]) * 0.15 + float(unit["crew"]) * 0.05

func _hostile_command_index() -> int:
	for i in range(enemies.size()):
		if enemies[i].get("role", "") == "COMANDO":
			return i
	return -1

func _enemy_distance(index: int, anchor: Vector3) -> float:
	var node: Node3D = enemies[index]["node"]
	return node.global_position.distance_to(anchor)

## Função pura: lê o tabuleiro e devolve a decisão sem mover nada. É por ela que a sonda
## confere postura e alvo sem depender de frames nem do RNG.
func _assess_hostiles() -> Dictionary:
	var hostile_power := 0.0
	for enemy in enemies:
		if float(enemy["hp"]) > 0.0 and enemy["order"] != "CAPTURADO":
			hostile_power += _combat_power(enemy)
	var friendly_power := 0.0
	for ally in fleet:
		if float(ally["hp"]) > 0.0 and ally["order"] != "RESERVA":
			friendly_power += _combat_power(ally)
	var ratio := hostile_power / maxf(1.0, hostile_power + friendly_power)
	var command_index := _hostile_command_index()
	var command_alive := command_index >= 0 and float(enemies[command_index]["hp"]) > 0.0
	# Sem capitânia entre os vivos, a esquadra perde coesão: debandada, não manobra.
	var rout := not command_alive
	var command_hurt := command_alive and float(enemies[command_index]["hp"]) < 60.0
	var posture := "AVANÇAR"
	# 0.42 de força relativa = os hostis valem menos de ~72% do que a linha aliada. Forças
	# iguais dão 0.50 e ficam em AVANÇAR: sem essa margem a IA recuaria ainda na linha de
	# partida.
	if rout or ratio < 0.42:
		posture = "RECUAR"
	if command_hurt:
		posture = "ESCOLTA"
	return {
		"hostile_power": hostile_power,
		"friendly_power": friendly_power,
		"ratio": ratio,
		"posture": posture,
		"command_index": command_index,
		"command_hurt": command_hurt,
		"rout": rout,
	}

## Alvo vulnerável e que ameaça: casco baixo pesa mais, armamento pesado pesa junto, e
## quem está em reserva tática não é lido como alvo.
func _hostile_victim_index() -> int:
	var best := -1
	var best_value := -1.0
	for i in range(fleet.size()):
		var ally: Dictionary = fleet[i]
		if float(ally["hp"]) <= 0.0 or ally["order"] == "RESERVA":
			continue
		var value := (100.0 - float(ally["hp"])) + float(ally["weapons"]) * 0.3
		if ally["order"] == "ATACAR":
			value += 25.0
		if value > best_value:
			best_value = value
			best = i
	if best >= 0:
		return best
	for i in range(fleet.size()):
		if float(fleet[i]["hp"]) > 0.0:
			return i
	return -1

## Converte a leitura em ordens, uma vez por salva. Não toca em casco, armamento nem
## posição: só em `order`, e o resto do combate continua automático.
func _apply_hostile_tactics() -> void:
	var read := _assess_hostiles()
	var previous := hostile_posture
	hostile_posture = String(read["posture"])
	var base := hostile_posture if hostile_posture != "ESCOLTA" else "RECUAR"
	var living: Array[int] = []
	for i in range(enemies.size()):
		if float(enemies[i]["hp"]) > 0.0 and enemies[i]["order"] != "CAPTURADO":
			living.append(i)
	for i in living:
		var unit: Dictionary = enemies[i]
		unit["order"] = base
		enemies[i] = unit
	var guards := 0
	if hostile_posture == "ESCOLTA":
		var command_index := int(read["command_index"])
		var anchor: Vector3 = (enemies[command_index]["node"] as Node3D).global_position
		var near := living.duplicate()
		near.sort_custom(func(a, b): return _enemy_distance(a, anchor) < _enemy_distance(b, anchor))
		for i in near:
			if i == command_index:
				continue
			var escort: Dictionary = enemies[i]
			escort["order"] = "ESCOLTAR"
			escort["escort_offset"] = -3.0 if guards == 0 else 3.0
			enemies[i] = escort
			guards += 1
			if guards >= 2:
				break
	hostile_focus = _hostile_victim_index()
	var focus_name := "nenhum contato aliado vivo"
	if hostile_focus >= 0:
		focus_name = String(fleet[hostile_focus]["name"])
	if bool(read["rout"]):
		tactical_note = "POSTURA HOSTIL: DEBACLA // capitânia sem casco; fogo residual em %s" % focus_name
	elif hostile_posture == "ESCOLTA":
		tactical_note = "POSTURA HOSTIL: ESCOLTA // %d casco(s) fechando em torno da capitânia; fogo em %s" % [guards, focus_name]
	else:
		tactical_note = "POSTURA HOSTIL: %s // %.0f%% de força relativa; fogo em %s" % [hostile_posture, float(read["ratio"]) * 100.0, focus_name]
	if previous != hostile_posture and is_instance_valid(report_label):
		report_label.text = "INTELIGÊNCIA // " + tactical_note

func _resolve_volley() -> void:
	# Primeiro incorpora as presas da salva anterior: a contagem de vitória abaixo lê
	# `enemies`, e uma presa que ainda consta como hostil adia a batalha para sempre.
	_integrate_captured_ships()
	# Depois a IA hostil relê o tabuleiro; a retaliação desta salva usa o alvo escolhido aqui.
	_apply_hostile_tactics()
	# Sem ponte não há salva: a capitânia é corpo no campo agora, e abalroar custa casco também
	# para quem comando.
	if capital_hp <= 0.0:
		report_label.text = "DERROTA // capitânia perdida: a frota ficou sem ponte de comando."
		return
	var living_enemies := 0
	var living_allies := 0
	for enemy in enemies:
		if enemy["hp"] > 0.0 and enemy["order"] != "CAPTURADO":
			living_enemies += 1
	for ally in fleet:
		if ally["hp"] > 0.0:
			living_allies += 1
	if living_enemies == 0:
		report_label.text = "VITÓRIA TÁTICA // Frota hostil neutralizada."
		return
	if living_allies == 0:
		report_label.text = "DERROTA // Frota aliada neutralizada."
		return
	var focus_target := selected_target
	if focus_target < 0 or focus_target >= enemies.size() or enemies[focus_target]["hp"] <= 0.0 or enemies[focus_target]["order"] == "CAPTURADO":
		focus_target = -1
		for i in range(enemies.size()):
			if enemies[i]["hp"] > 0.0 and enemies[i]["order"] != "CAPTURADO":
				focus_target = i
				break
	# Each living ship fires automatically. Focus-fire orders multiply damage on one target.
	for i in range(fleet.size()):
		var ally: Dictionary = fleet[i]
		if ally["hp"] <= 0.0 or ally["weapons"] <= 0.0:
			continue
		var target_index := focus_target
		if ally["order"] != "ATACAR":
			for j in range(enemies.size()):
				if enemies[j]["hp"] > 0.0 and enemies[j]["order"] != "CAPTURADO":
					target_index = j
					break
		if target_index < 0:
			continue
		var damage := 2.5 * float(ally["weapons"]) / 100.0 * maxf(0.25, float(ally["crew"]) / 100.0)
		if ally["order"] == "ATACAR":
			damage *= 1.8
		if ally["order"] == "RESERVA":
			damage *= 0.35
		var subsystem := subsystem_selector.get_item_text(subsystem_selector.selected) if ally["order"] == "ATACAR" and is_instance_valid(subsystem_selector) else "CASCO"
		if subsystem == "MOTORES":
			enemies[target_index]["engines"] = maxf(0.0, float(enemies[target_index]["engines"]) - damage * 1.7)
		elif subsystem == "ARMAS":
			enemies[target_index]["weapons"] = maxf(0.0, float(enemies[target_index]["weapons"]) - damage * 1.7)
		elif subsystem == "TRIPULAÇÃO":
			enemies[target_index]["crew"] = maxf(0.0, float(enemies[target_index]["crew"]) - damage * 1.5)
		else:
			enemies[target_index]["hp"] = maxf(0.0, float(enemies[target_index]["hp"]) - damage)
		_spawn_bolt((enemies[target_index]["node"] as Node3D).global_position, BLUE,
			(ally["node"] as Node3D).global_position)
		if enemies[target_index]["hp"] <= 0.0:
			_mark_wreck(enemies[target_index]["node"] as Node3D)
			report_label.text = "ALVO DESTRUÍDO // %s neutralizado." % enemies[target_index]["name"]
		elif float(enemies[target_index]["engines"]) <= 0.0:
			enemies[target_index]["order"] = "RECUAR"
	# Boarding parties progress in real time after reaching a sufficiently damaged ship.
	for target_index in range(enemies.size()):
		var target_enemy: Dictionary = enemies[target_index]
		if target_enemy["hp"] <= 0.0 or target_enemy["hp"] > 55.0 or target_enemy["order"] == "CAPTURADO":
			continue
		for ally in fleet:
			if ally["hp"] <= 0.0 or ally["order"] != "ABORDAR":
				continue
			var boarding_ship: Node3D = ally["node"]
			var target_ship: Node3D = target_enemy["node"]
			if boarding_ship.global_position.distance_to(target_ship.global_position) <= 18.0:
				target_enemy["crew"] = maxf(0.0, float(target_enemy["crew"]) - 7.0)
				if target_enemy["crew"] <= 0.0:
					target_enemy["order"] = "CAPTURADO"
					target_enemy["weapons"] = 0.0
					target_enemy["team"] = "friendly"
					report_label.text = "NAVE CAPTURADA // %s agora está sob controle da frota." % target_enemy["name"]
				else:
					report_label.text = "ABORDAGEM // %s: resistência inimiga diminuindo." % target_enemy["name"]
				break
		enemies[target_index] = target_enemy
	# Hostile ships retaliate on their own and may damage specific systems.
	for enemy in enemies:
		if enemy["order"] == "CAPTURADO" or enemy["hp"] <= 0.0 or enemy["weapons"] <= 0.0:
			continue
		var victim_index := hostile_focus
		if victim_index < 0 or victim_index >= fleet.size() or float(fleet[victim_index]["hp"]) <= 0.0:
			victim_index = _hostile_victim_index()
		if victim_index < 0:
			break
		var victim: Dictionary = fleet[victim_index]
		var damage := 1.3 * float(enemy["weapons"]) / 100.0 * maxf(0.25, float(enemy["crew"]) / 100.0)
		if victim["order"] == "ESCOLTAR":
			damage *= 0.7
		victim["hp"] = maxf(0.0, float(victim["hp"]) - damage)
		_spawn_bolt((victim["node"] as Node3D).global_position, RED,
			(enemy["node"] as Node3D).global_position, false)
		if rng.randf() < 0.12:
			victim["engines"] = maxf(0.0, float(victim["engines"]) - 4.0)
		elif rng.randf() < 0.1:
			victim["weapons"] = maxf(0.0, float(victim["weapons"]) - 5.0)
		elif rng.randf() < 0.08:
			victim["crew"] = maxf(0.0, float(victim["crew"]) - 3.0)
		if victim["hp"] <= 0.0:
			_mark_wreck(victim["node"] as Node3D)
			report_label.text = "ALERTA // %s foi perdida." % victim["name"]
		fleet[victim_index] = victim

## Uma presa só vira unidade quando sai de `enemies` e entra em `fleet`: enquanto fica na
## lista de hostis ela não recebe ordem nenhuma e o jogador assiste à captura de fora.
func _integrate_captured_ships() -> void:
	var gained := 0
	var i := enemies.size() - 1
	while i >= 0:
		if enemies[i]["order"] != "CAPTURADO":
			i -= 1
			continue
		var prize: Dictionary = enemies[i]
		enemies.remove_at(i)
		prize["team"] = "friendly"
		prize["order"] = "LINHA"
		prize["squadron"] = "PRESA"
		prize["repair_priority"] = "AUTO"
		prize["name"] = "PRESA %02d" % (fleet.size() + 1)
		fleet.append(prize)
		_mark_as_prize(prize["node"] as Node3D)
		gained += 1
		i -= 1
	if gained > 0:
		_rebuild_selectors()
		report_label.text = "INCORPORAÇÃO // %d presa(s) sob comando da frota; reparo automático em curso." % gained

## A incorporação é visual antes de ser burocrática: o filete vira azul, o escapamento esfria, a
## meia-volta aponta a proa para a própria linha e a marca dourada entra no filho "Casco", junto
## do resto do navio. Nenhum número muda aqui — só material e rotação do nó raiz.
func _mark_as_prize(ship: Node3D) -> void:
	var mats: Dictionary = ship.get_meta("mat")
	var mat_trim: StandardMaterial3D = mats["trim"]
	mat_trim.albedo_color = BLUE.darkened(0.35)
	mat_trim.emission = BLUE * 0.7
	var mat_gun: StandardMaterial3D = mats["gun"]
	mat_gun.emission = BLUE * 0.4
	var mat_engine: StandardMaterial3D = mats["engine"]
	mat_engine.emission = ESCOAMENTO_ALIADO
	(mats["luz"] as StandardMaterial3D).albedo_color = Color(BLUE, 0.75)
	# O material da pluma é reescrito todo quadro a partir desta chave: trocá-la é trocar a cor
	# do escapamento sem encostar em nenhum dos dois nós.
	ship.set_meta("escape", ESCOAMENTO_ALIADO)
	_box(Vector3(0, 0.95, 0.0), Vector3(0.55, 0.4, 0.55), _material(GOLD, 0.3, 0.25, GOLD * 0.8),
		ship.get_meta("casco"))
	ship.rotation.y = 0.0

## Escopo, alvo e escolta leem os arrays reais. add_item não reemite item_selected, então a
## escolha do comandante sobrevive à reconstrução enquanto o item correspondente existir.
func _rebuild_selectors() -> void:
	if is_instance_valid(scope_selector):
		var scopes: Array[String] = ["FROTA", "ESQUADRÃO ALFA", "ESQUADRÃO BETA"]
		for unit in fleet:
			if unit["squadron"] == "PRESA":
				scopes.append("ESQUADRÃO PRESA")
				break
		for n in range(1, fleet.size() + 1):
			scopes.append("NAVE %d" % n)
		scope_selector.clear()
		for scope in scopes:
			scope_selector.add_item(scope)
		var keep_scope := scopes.find(selection_scope)
		if keep_scope < 0:
			selection_scope = "FROTA"
			keep_scope = 0
		scope_selector.select(keep_scope)
	if is_instance_valid(target_selector):
		target_selector.clear()
		if enemies.is_empty():
			target_selector.add_item("SEM CONTATO HOSTIL")
			target_selector.select(0)
		else:
			for enemy in enemies:
				target_selector.add_item(enemy["name"])
			if selected_target >= enemies.size():
				selected_target = maxi(0, enemies.size() - 1)
			target_selector.select(selected_target)
	if is_instance_valid(protected_selector):
		var wanted := "CAPITÂNIA"
		if protected_selector.item_count > 0 and protected_selector.selected >= 0:
			wanted = protected_selector.get_item_text(protected_selector.selected)
		protected_selector.clear()
		protected_selector.add_item("CAPITÂNIA")
		for unit in fleet:
			protected_selector.add_item(unit["name"])
		var keep_prot := 0
		for idx in range(protected_selector.item_count):
			if protected_selector.get_item_text(idx) == wanted:
				keep_prot = idx
				break
		protected_selector.select(keep_prot)
		protected_unit_index = keep_prot - 1
	# A mesa holográfica lê as mesmas listas dos seletores: incorporar presa reemite os blips
	# pelo mesmo caminho que reemite os itens, sem cadastro paralelo.
	_rebuild_holo()

## O traço de fogo: um prisma fino e emissivo que corre do atirador ao alvo. A trilha aliada
## paga exatamente os dois sorteios de `rng` de sempre, na mesma ordem — é o orçamento que a
## cauda de combate cobra e que `tools/probes/sondas.gd` confere. O lance hostil sai de
## `visual_rng`, então inimigo passando a atirar na tela não reescreve um dano sequer.
func _spawn_bolt(destino: Vector3, cor: Color, origem: Vector3, cauda_de_combate := true) -> void:
	var dx := 0.0
	var dy := 0.0
	if cauda_de_combate:
		dx = rng.randf_range(-1, 1)
		dy = rng.randf_range(-1, 1)
	else:
		dx = visual_rng.randf_range(-1, 1)
		dy = visual_rng.randf_range(-1, 1)
	var saida := origem + Vector3(dx, dy, 0.0)
	var vetor := destino - saida
	var distancia := vetor.length()
	var lance := MeshInstance3D.new()
	var corpo := CylinderMesh.new()
	corpo.bottom_radius = 0.22
	corpo.top_radius = 0.06
	corpo.height = minf(maxf(distancia * 0.32, 2.2), 16.0)
	corpo.radial_segments = 4
	corpo.rings = 1
	lance.mesh = corpo
	lance.material_override = _material(cor, 0.0, 0.2, cor * 1.4)
	lance.material_override.emission_energy_multiplier = 2.4
	# No tree, no global transform: global_position lida antes de add_child devolve
	# Transform3D() e imprime um ERROR por salva (medido no smoke headless).
	add_child(lance)
	lance.global_position = saida
	# Direção nula faz look_at reclamar; dois cascos colados é um caso real de abordagem.
	if distancia > 0.001:
		lance.look_at(destino, Vector3.UP)
		# O eixo do prisma é +Y e `look_at` aponta -Z para o alvo: -90° em X alinha os dois.
		lance.rotate_x(-PI / 2)
	var tween := create_tween()
	tween.tween_property(lance, "global_position", destino, 0.22)
	tween.tween_callback(lance.queue_free)

func _give_order(order: String) -> void:
	var selected := _selected_indices()
	if selected.is_empty():
		report_label.text = "NENHUMA UNIDADE VIVA NA SELEÇÃO."
		return
	if order == "ABORDAR":
		if selected_target >= enemies.size() or enemies[selected_target]["hp"] > 55.0:
			report_label.text = "ABORDAGEM NEGADA // selecione um alvo danificado (55% de casco ou menos)."
			return
	if order == "MOVER":
		move_x = position_x_input.value if is_instance_valid(position_x_input) else 0.0
		move_z = position_z_input.value if is_instance_valid(position_z_input) else -65.0
	for i in selected:
		var unit: Dictionary = fleet[i]
		unit["order"] = order
		if order == "MOVER":
			unit["destination"] = Vector3(move_x + (float(i) - 2.5) * FORMATION_STEP, 0.0, move_z)
		fleet[i] = unit
	if order == "ATACAR":
		report_label.text = "%d unidade(s) atacando %s / %s. Combate contínuo." % [selected.size(), enemies[selected_target]["name"], subsystem_selector.get_item_text(subsystem_selector.selected)]
	elif order == "RECONHECER":
		var launched := _launch_probes(selected)
		if launched == 0:
			report_label.text = "SONDAS JÁ EM VARREDURA // %d sonda(s) no ar; lançar de novo não empilha." % probes.size()
		else:
			report_label.text = "SONDAS LANÇADAS // %d sonda(s) em varredura; %d/%d contato(s) confirmado(s)." % [launched, recon_contacts, recon_total]
	elif order == "ABORDAR":
		report_label.text = "ABORDAGEM INICIADA // unidades selecionadas aproximam-se de %s." % enemies[selected_target]["name"]
	elif order == "RESERVA":
		report_label.text = "RESERVA TÁTICA // unidades selecionadas preservam força e posição."
	elif order == "MOVER":
		report_label.text = "NAVEGAÇÃO TÁTICA // unidades selecionadas receberam posição de destino."
	else:
		report_label.text = "ORDEM %s TRANSMITIDA A %d UNIDADE(S). A BATALHA CONTINUA." % [order, selected.size()]
	_update_hud()

func _selected_indices() -> Array[int]:
	var result: Array[int] = []
	for i in range(fleet.size()):
		var include_unit := false
		if selection_scope == "FROTA":
			include_unit = true
		elif selection_scope == "ESQUADRÃO ALFA":
			include_unit = fleet[i]["squadron"] == "ALFA"
		elif selection_scope == "ESQUADRÃO BETA":
			include_unit = fleet[i]["squadron"] == "BETA"
		elif selection_scope == "ESQUADRÃO PRESA":
			include_unit = fleet[i]["squadron"] == "PRESA"
		elif selection_scope.begins_with("NAVE "):
			include_unit = i == int(selection_scope.trim_prefix("NAVE ")) - 1
		if include_unit and fleet[i]["hp"] > 0.0:
			result.append(i)
	return result

func _on_scope_selected(index: int) -> void:
	selection_scope = scope_selector.get_item_text(index)
	report_label.text = "SELEÇÃO ATUAL: %s. Novas ordens afetarão somente esta seleção." % selection_scope
	_update_hud()

func _on_target_selected(index: int) -> void:
	selected_target = index
	_update_hud()

func _on_protected_selected(index: int) -> void:
	protected_unit_index = index - 1
	report_label.text = "ESCOLTA CONFIGURADA // protegendo %s." % protected_selector.get_item_text(index)

func _set_repair_priority(priority: String) -> void:
	for i in _selected_indices():
		var unit: Dictionary = fleet[i]
		unit["repair_priority"] = priority
		fleet[i] = unit
	report_label.text = "PRIORIDADE DE REPARO: %s para %s. Reparos continuam automáticos." % [priority, selection_scope]

## Postos de formação, medidos a partir do CENTRO REAL da seleção. Cravar z = -38 (como fazia a
## versão antiga) teletransportava a frota de volta para uma linha do cadastro: a formação passou a
## ser uma ordem de navegação, executada na velocidade do próprio motor, e é por isso que o posto é
## um deslocamento em torno de onde os cascos realmente estão.
func _formacao_posto(posicao: int, total: int, centro: Vector3) -> Vector3:
	if total <= 0:
		return centro
	var meio := float(total - 1) / 2.0
	match formation:
		"COLUNA":
			# Um atrás do outro no eixo de avanço: a coluna é a formação de passagem, não de fogo.
			return centro + Vector3(0.0, 0.0, -float(posicao) * FORMATION_STEP)
		"ANEL":
			# Círculo fechado com passo garantido: o raio cresce com o número de cascos para que
			# vizinhos nunca fiquem a menos de 2 * HULL_RADIUS, senão a formação se abalroa sozinha.
			var raio := maxf(FORMATION_STEP, float(total) * FORMATION_STEP / (2.0 * PI))
			var angulo := float(posicao) / float(total) * TAU
			return centro + Vector3(cos(angulo) * raio, 0.0, sin(angulo) * raio)
		"CUNHA":
			# Ápice adiantado (-Z é a direção do inimigo), flancos varridos para trás. O protótipo
			# fazia o contrário — `-absf(i - meio)` — e o resultado era um cálice: as asas na frente
			# e o centro atrás, que é a formação de receber fogo, não de aplicá-lo.
			return centro + Vector3((float(posicao) - meio) * FORMATION_STEP, 0.0,
				-(meio - absf(float(posicao) - meio)) * FORMATION_STEP)
		_:
			# LINHA: leque lateral com alternância de profundidade, para dois cascos não taparem o
			# mesmo arco na mesa.
			return centro + Vector3((float(posicao) - meio) * FORMATION_STEP, 0.0,
				-float(posicao % 2) * FORMATION_STEP)

## Centro geométrico dos cascos vivos da seleção — a âncora da formação. Destroço fica de fora:
## corpo sem motor não entra em conta de manobra.
func _centro_selecao(selected: Array[int]) -> Vector3:
	var soma := Vector3.ZERO
	var vivos := 0
	for i in selected:
		var unit: Dictionary = fleet[i]
		if float(unit["hp"]) <= 0.0:
			continue
		soma += (unit["node"] as Node3D).position
		vivos += 1
	if vivos == 0:
		return Vector3.ZERO
	return soma / float(vivos)

## Formação é ordem de navegação, não alinhamento de cadastro: escreve o posto como destino e
## manda o casco andar até lá. O tempo de locomoção é o preço da manobra — uma linha que se refaz
## em um quadro não pode ser punida nem aproveitada taticamente.
func _set_formation(new_formation: String) -> void:
	var selected := _selected_indices()
	if selected.is_empty():
		report_label.text = "NENHUMA UNIDADE VIVA NA SELEÇÃO."
		return
	# A formação só é gravada depois da ordem ter para quem ir: cravar o rótulo antes faria o
	# painel anunciar "ANEL" enquanto nenhum casco se moveu, e painel que anuncia o que não
	# aconteceu deixa de ser leitura do campo para virar desejo do comandante.
	formation = new_formation
	var centro := _centro_selecao(selected)
	var postos := 0
	for k in range(selected.size()):
		var unit: Dictionary = fleet[selected[k]]
		if float(unit["hp"]) <= 0.0:
			continue
		unit["formation"] = new_formation
		unit["order"] = "MOVER"
		unit["destination"] = _formacao_posto(postos, selected.size(), centro)
		fleet[selected[k]] = unit
		postos += 1
	report_label.text = "FORMAÇÃO %s EM EXECUÇÃO // %d casco(s) navegando para os postos." % [
		new_formation, postos]
	_update_hud()

func _toggle_pause() -> void:
	paused = not paused
	pause_button.text = "RETOMAR" if paused else "PAUSAR [ESPAÇO]"
	report_label.text = "PAUSA TÁTICA // emita suas ordens." if paused else "BATALHA RETOMADA // executando ordens."
	_update_hud()

func _update_hud() -> void:
	if is_instance_valid(command_label):
		var living := 0
		var damaged := 0
		for item in fleet:
			if item["hp"] > 0.0:
				living += 1
				if item["engines"] < 70.0 or item["weapons"] < 70.0 or item["crew"] < 60.0:
					damaged += 1
		command_label.text = "FROTA: %d/%d NAVES | SELEÇÃO: %s\nFORMAÇÃO: %s | DANIFICADAS: %d\nRECONHECIMENTO: %d%% // %d sonda(s) • %d/%d contato(s) confirmado(s)\nESTADO: %s // TEMPO REAL\n%s" % [living, fleet.size(), selection_scope, formation, damaged, int(recon_progress), probes.size(), recon_contacts, recon_total, "PAUSADO" if paused else "EM COMBATE", tactical_note]
	if is_instance_valid(target_selector):
		for i in range(enemies.size()):
			# O casco só aparece para a ponte quando uma sonda encostou naquele hull: a
			# linha de baixa é o estado real do contato, não uma barra de tempo.
			var state := "CAPTURADO" if enemies[i]["order"] == "CAPTURADO" else ("CASCO %d%%" % int(enemies[i]["hp"]) if bool(enemies[i].get("seen", false)) else "NÃO IDENTIFICADO")
			target_selector.set_item_text(i, "%s [%s]" % [enemies[i]["name"], state])
