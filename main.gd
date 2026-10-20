extends Node3D

const BLUE := Color(0.12, 0.72, 1.0)
const RED := Color(1.0, 0.22, 0.18)
const GOLD := Color(1.0, 0.72, 0.28)
var paused := false
var throttle := 0.0
var yaw_rate := 0.0
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
var selected_target := 0
var formation := "LINHA"
var recon_progress := 0.0
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

func _ready() -> void:
	rng.randomize()
	_build_environment()
	_build_bridge()
	_build_fleets()
	_build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	if paused:
		return
	battle_clock += delta
	fire_clock += delta
	_update_capital_ship(delta)
	_update_fleet(delta)
	if fire_clock >= 1.6:
		fire_clock = 0.0
		_resolve_volley()
	if is_instance_valid(speed_label):
		speed_label.text = "VELOCIDADE DA CAPITÂNIA  %03d%%" % int(50.0 + throttle * 50.0)
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
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.003, 0.008, 0.025)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.25, 0.42)
	env.ambient_light_energy = 0.5
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28, -32, 0)
	sun.light_color = Color(0.56, 0.72, 1.0)
	sun.light_energy = 0.65
	add_child(sun)
	# A distant planet provides scale and a memorable first view.
	var planet := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 18.0
	sphere.height = 36.0
	planet.mesh = sphere
	planet.position = Vector3(38, 10, -145)
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.10, 0.22, 0.42)
	pm.metallic = 0.2
	pm.roughness = 0.82
	pm.emission_enabled = true
	pm.emission = Color(0.015, 0.07, 0.16)
	pm.emission_energy_multiplier = 0.6
	planet.material_override = pm
	add_child(planet)
	# Procedural starfield: no external assets required.
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 0.12
	star_mesh.height = 0.24
	var star_mat := StandardMaterial3D.new()
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mat.albedo_color = Color(0.65, 0.82, 1.0)
	for i in range(260):
		var star := MeshInstance3D.new()
		star.mesh = star_mesh
		star.material_override = star_mat
		star.position = Vector3(rng.randf_range(-170, 170), rng.randf_range(-90, 90), rng.randf_range(-220, -45))
		star.scale = Vector3.ONE * rng.randf_range(0.35, 1.7)
		add_child(star)

func _build_bridge() -> void:
	bridge_rig = Node3D.new()
	bridge_rig.name = "Capitânia - Ponte"
	add_child(bridge_rig)
	var floor_mat := _material(Color(0.035, 0.055, 0.085), 0.72, 0.25)
	var trim_mat := _material(Color(0.08, 0.35, 0.48), 0.45, 0.2, Color(0.02, 0.24, 0.38))
	_box(Vector3(0, -2.1, 1), Vector3(15, 0.5, 22), floor_mat, bridge_rig)
	_box(Vector3(0, 5.2, -7), Vector3(15, 0.5, 0.7), floor_mat, bridge_rig)
	_box(Vector3(-7.1, 1.0, -7), Vector3(0.55, 7, 0.65), floor_mat, bridge_rig)
	_box(Vector3(7.1, 1.0, -7), Vector3(0.55, 7, 0.65), floor_mat, bridge_rig)
	_box(Vector3(0, 4.8, -7), Vector3(14.5, 0.16, 0.22), trim_mat, bridge_rig)
	# Sloped command consoles frame the tactical view.
	for side in [-1.0, 1.0]:
		var console := _box(Vector3(side * 3.6, -0.8, -0.4), Vector3(3.0, 0.32, 2.0), floor_mat, bridge_rig)
		console.rotation.x = -0.12
		_box(Vector3(side * 3.6, -0.61, -0.4), Vector3(2.3, 0.035, 1.25), trim_mat, bridge_rig)
		for i in range(4):
			_box(Vector3(side * 3.0 + i * side * 0.32, -0.57, -0.35), Vector3(0.12, 0.025, 0.45), _material(BLUE, 0.2, 0.1, BLUE), bridge_rig)
	# Camera sits behind the forward command rail.
	var camera := Camera3D.new()
	camera.name = "BridgeCamera"
	camera.position = Vector3(0, 1.0, 3.0)
	camera.rotation_degrees = Vector3(-3, 0, 0)
	camera.fov = 78
	bridge_rig.add_child(camera)
	_box(Vector3(0, -1.1, -2.2), Vector3(8, 0.18, 0.35), trim_mat, bridge_rig)

func _build_fleets() -> void:
	for i in range(6):
		var x := (float(i) - 2.5) * 5.0
		var z := -38.0 - (i % 2) * 5.0
		var ship := _make_ship(Vector3(x, rng.randf_range(-2, 2), z), BLUE, 1.0 + float(i % 3) * 0.12, "ALIADA %02d" % (i + 1))
		fleet.append({"node": ship, "order": "LINHA", "hp": 100.0, "max_hp": 100.0, "engines": 100.0, "weapons": 100.0, "crew": 100.0, "repair": 0.0, "repair_priority": "AUTO", "team": "friendly", "name": "ALIADA %02d" % (i + 1), "squadron": "ALFA" if i < 3 else "BETA"})
	for i in range(6):
		var x := (float(i) - 2.5) * 6.0
		var z := -82.0 - (i % 2) * 7.0
		var ship := _make_ship(Vector3(x, rng.randf_range(-3, 3), z), RED, 1.1, "HOSTIL %02d" % (i + 1))
		enemies.append({"node": ship, "order": "AVANÇAR", "hp": 100.0, "max_hp": 100.0, "engines": 100.0, "weapons": 100.0, "crew": 100.0, "repair": 0.0, "team": "enemy", "name": "HOSTIL %02d" % (i + 1), "squadron": "INIMIGO"})

func _make_ship(pos: Vector3, color: Color, scale_factor: float, ship_name: String) -> Node3D:
	var ship := Node3D.new()
	ship.position = pos
	ship.scale = Vector3.ONE * scale_factor
	add_child(ship)
	var hull_mat := _material(color.darkened(0.58), 0.62, 0.3)
	var edge_mat := _material(color, 0.25, 0.22, color * 0.55)
	_box(Vector3(0, 0, 0), Vector3(2.3, 0.7, 5.4), hull_mat, ship)
	_box(Vector3(0, 0.42, -0.65), Vector3(1.0, 0.3, 1.5), edge_mat, ship)
	_box(Vector3(0, 0.02, -3.0), Vector3(0.65, 0.42, 1.5), hull_mat, ship)
	_box(Vector3(-1.55, -0.05, 0.6), Vector3(1.0, 0.16, 2.7), edge_mat, ship)
	_box(Vector3(1.55, -0.05, 0.6), Vector3(1.0, 0.16, 2.7), edge_mat, ship)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 0.62, 0.0, 2.78), Vector3(0.32, 0.32, 0.15), _material(Color(0.15, 0.8, 1.0), 0.1, 0.1, Color(0.1, 0.7, 1.0)), ship)
	return ship

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 64
	top.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.035, 0.07, 0.92), Color(0.12, 0.55, 0.8)))
	layer.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 24)
	top.add_child(top_row)
	var title := Label.new()
	title.text = "I R O N   S T A R S   //   FLEET COMMAND"
	title.add_theme_color_override("font_color", Color(0.45, 0.82, 1.0))
	title.add_theme_font_size_override("font_size", 19)
	top_row.add_child(title)
	speed_label = Label.new()
	speed_label.text = "VELOCIDADE DA CAPITÂNIA  050%"
	speed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(speed_label)
	pause_button = _add_button(top_row, "PAUSAR [ESPAÇO]", _toggle_pause)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 94)
	panel.custom_minimum_size = Vector2(320, 620)
	panel.size = Vector2(320, 620)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.03, 0.07, 0.88), Color(0.1, 0.5, 0.75)))
	layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 600)
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
	for scope in ["FROTA", "ESQUADRÃO ALFA", "ESQUADRÃO BETA", "NAVE 1", "NAVE 2", "NAVE 3", "NAVE 4", "NAVE 5", "NAVE 6"]:
		scope_selector.add_item(scope)
	scope_selector.item_selected.connect(_on_scope_selected)
	col.add_child(scope_selector)
	var target_title := Label.new()
	target_title.text = "ALVO HOSTIL"
	col.add_child(target_title)
	target_selector = OptionButton.new()
	for enemy in enemies:
		target_selector.add_item(enemy["name"])
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
	protected_selector.add_item("CAPITÂNIA")
	for i in range(fleet.size()):
		protected_selector.add_item("ALIADA %02d" % (i + 1))
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
	_add_button(col, "FORMAÇÃO: CUNHA", func(): _set_formation("CUNHA"))
	var hint := Label.new()
	hint.text = "W/S velocidade  •  A/D rotação\nESPAÇO pausa tática"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.65, 0.78, 0.9))
	col.add_child(hint)
	var report_panel := PanelContainer.new()
	report_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	report_panel.offset_top = -58
	report_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.025, 0.05, 0.85), Color(0.12, 0.45, 0.65)))
	layer.add_child(report_panel)
	report_label = Label.new()
	report_label.text = "PONTE DE COMANDO ONLINE  //  Contatos hostis detectados à frente."
	report_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	report_panel.add_child(report_label)

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

func _update_capital_ship(delta: float) -> void:
	var turn := 0.0
	if Input.is_key_pressed(KEY_A):
		turn += 1.0
	if Input.is_key_pressed(KEY_D):
		turn -= 1.0
	if Input.is_key_pressed(KEY_W):
		throttle = minf(1.0, throttle + delta * 0.24)
	if Input.is_key_pressed(KEY_S):
		throttle = maxf(0.0, throttle - delta * 0.32)
	bridge_rig.rotation.y += turn * delta * 0.28
	bridge_rig.position += -bridge_rig.global_transform.basis.z * throttle * 5.0 * delta

func _update_fleet(delta: float) -> void:
	# Ambas as frotas agem continuamente; ordens mudam comportamento, não iniciam turnos.
	for i in range(fleet.size()):
		var ally: Dictionary = fleet[i]
		var ship: Node3D = ally["node"]
		if ally["hp"] <= 0.0 or not is_instance_valid(ship):
			continue
		var mobility: float = 0.25 + float(ally["engines"]) / 100.0 * 0.75
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
			var escort_destination := protect_position + Vector3((float(i) - 2.5) * 3.0, 0, 8.0 if protected_unit_index >= 0 else -12.0)
			ship.position = ship.position.lerp(escort_destination, minf(1.0, delta * 0.35))
		elif ally["order"] == "RESERVA":
			ship.position.z = move_toward(ship.position.z, -48.0, delta * 0.8)
		elif ally["order"] == "RECONHECER":
			ship.position.x = move_toward(ship.position.x, (float(i) - 2.5) * 9.0, delta * 1.8)
		elif ally["order"] == "ABORDAR" and selected_target < enemies.size() and enemies[selected_target]["hp"] > 0.0:
			var target: Node3D = enemies[selected_target]["node"]
			ship.position = ship.position.move_toward(target.position + Vector3((float(i) - 2.5) * 2.0, 0, 8.0), delta * 2.2 * mobility)
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
	for enemy in enemies:
		var foe: Node3D = enemy["node"]
		if enemy["hp"] <= 0.0 or not is_instance_valid(foe):
			continue
		if enemy["order"] == "AVANÇAR":
			foe.position.z += delta * 0.65 * (0.3 + float(enemy["engines"]) / 100.0)
		elif enemy["order"] == "RECUAR":
			foe.position.z -= delta * 0.45
		if enemy["hp"] < 35.0 and rng.randf() < delta * 0.08:
			enemy["order"] = "RECUAR"
	if _has_order("RECONHECER"):
		recon_progress = minf(100.0, recon_progress + delta * 2.0)

func _resolve_volley() -> void:
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
		_spawn_bolt((enemies[target_index]["node"] as Node3D).global_position, BLUE)
		if enemies[target_index]["hp"] <= 0.0:
			(enemies[target_index]["node"] as Node3D).visible = false
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
		var victim_index := -1
		var lowest_hp := 101.0
		for i in range(fleet.size()):
			if fleet[i]["hp"] > 0.0 and fleet[i]["order"] != "RESERVA" and float(fleet[i]["hp"]) < lowest_hp:
				lowest_hp = float(fleet[i]["hp"])
				victim_index = i
		if victim_index < 0:
			for i in range(fleet.size()):
				if fleet[i]["hp"] > 0.0:
					victim_index = i
					break
		if victim_index < 0:
			break
		var victim: Dictionary = fleet[victim_index]
		var damage := 1.3 * float(enemy["weapons"]) / 100.0 * maxf(0.25, float(enemy["crew"]) / 100.0)
		if victim["order"] == "ESCOLTAR":
			damage *= 0.7
		victim["hp"] = maxf(0.0, float(victim["hp"]) - damage)
		if rng.randf() < 0.12:
			victim["engines"] = maxf(0.0, float(victim["engines"]) - 4.0)
		elif rng.randf() < 0.1:
			victim["weapons"] = maxf(0.0, float(victim["weapons"]) - 5.0)
		elif rng.randf() < 0.08:
			victim["crew"] = maxf(0.0, float(victim["crew"]) - 3.0)
		if victim["hp"] <= 0.0:
			(victim["node"] as Node3D).visible = false
			report_label.text = "ALERTA // %s foi perdida." % victim["name"]
		fleet[victim_index] = victim

func _spawn_bolt(target: Vector3, color: Color) -> void:
	var bolt := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.56
	bolt.mesh = mesh
	bolt.material_override = _material(color, 0.0, 0.1, color)
	bolt.global_position = target + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), 3.0)
	add_child(bolt)
	var tween := create_tween()
	tween.tween_property(bolt, "global_position", target, 0.22)
	tween.tween_callback(bolt.queue_free)

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
			unit["destination"] = Vector3(move_x + (float(i) - 2.5) * 3.0, 0.0, move_z)
		fleet[i] = unit
	if order == "ATACAR":
		report_label.text = "%d unidade(s) atacando %s / %s. Combate contínuo." % [selected.size(), enemies[selected_target]["name"], subsystem_selector.get_item_text(subsystem_selector.selected)]
	elif order == "RECONHECER":
		report_label.text = "SONDAS LANÇADAS // reconhecimento em curso durante o combate."
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

func _has_order(order: String) -> bool:
	for item in fleet:
		if item["hp"] > 0.0 and item["order"] == order:
			return true
	return false

func _set_formation(new_formation: String) -> void:
	formation = new_formation
	for i in _selected_indices():
		var ship: Node3D = fleet[i]["node"]
		if formation == "LINHA":
			ship.position.x = (float(i) - 2.5) * 5.0
			ship.position.z = -38.0 - float(i % 2) * 5.0
		else:
			ship.position.x = (float(i) - 2.5) * 2.7
			ship.position.z = -38.0 - absf(float(i) - 2.5) * 4.5
		fleet[i]["formation"] = formation
	report_label.text = "FORMAÇÃO %s APLICADA A %s. Outras ordens permanecem ativas." % [formation, selection_scope]
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
		command_label.text = "FROTA: %d/6 NAVES | SELEÇÃO: %s\nFORMAÇÃO: %s | DANIFICADAS: %d\nRECONHECIMENTO: %d%%\nESTADO: %s // TEMPO REAL" % [living, selection_scope, formation, damaged, int(recon_progress), "PAUSADO" if paused else "EM COMBATE"]
	if is_instance_valid(target_selector):
		for i in range(enemies.size()):
			var state := "CAPTURADO" if enemies[i]["order"] == "CAPTURADO" else ("CASCO %d%%" % int(enemies[i]["hp"]) if recon_progress >= 20.0 else "CONTATO")
			target_selector.set_item_text(i, "%s [%s]" % [enemies[i]["name"], state])
