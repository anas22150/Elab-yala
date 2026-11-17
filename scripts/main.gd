extends Node3D

const TouchControls = preload("res://scripts/touch_controls.gd")
const PLAYER_COLORS := [Color(0.12, 0.68, 1.0), Color(1.0, 0.25, 0.22), Color(0.2, 0.88, 0.48), Color(1.0, 0.68, 0.12)]
const PLAYER_NAMES := ["BLUE", "RED", "GREEN", "GOLD"]
const ARENA_SIZE := 18.0

var players: Array[CharacterBody3D] = []
var scores: Array[int] = [0, 0, 0, 0]
var lives: Array[int] = [3, 3, 3, 3]
var player_count := 4
var selected_mode := 0
var time_left := 120.0
var game_running := false
var round_over := false
var pickups: Array[Area3D] = []
var hazards: Array[Node3D] = []
var hill_zone: Area3D
var camera: Camera3D
var hud_layer: CanvasLayer
var menu_panel: PanelContainer
var result_panel: PanelContainer
var score_label: Label
var timer_label: Label
var status_label: Label
var touch_controls
var count_label: Label
var mode_label: Label
var mode_names := ["GEM RUSH", "KING OF THE HILL", "SURVIVAL"]
var player_in_hill: Array[bool] = [false, false, false, false]
var hill_tick := 0.0
var spawn_tick := 0.0

func _ready() -> void:
	_setup_keyboard_controls()
	_build_world()
	_build_hud()
	_show_menu()

func _setup_keyboard_controls() -> void:
	var key_sets := [
		{"p1_left": KEY_A, "p1_right": KEY_D, "p1_up": KEY_W, "p1_down": KEY_S},
		{"p2_left": KEY_LEFT, "p2_right": KEY_RIGHT, "p2_up": KEY_UP, "p2_down": KEY_DOWN},
		{"p3_left": KEY_J, "p3_right": KEY_L, "p3_up": KEY_I, "p3_down": KEY_K},
		{"p4_left": KEY_F, "p4_right": KEY_H, "p4_up": KEY_T, "p4_down": KEY_G}
	]
	for key_set in key_sets:
		for action_name in key_set:
			if not InputMap.has_action(action_name):
				InputMap.add_action(action_name)
			var key_event := InputEventKey.new()
			key_event.physical_keycode = key_set[action_name]
			InputMap.action_add_event(action_name, key_event)

func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.025, 0.045, 0.12)
	sky_mat.sky_horizon_color = Color(0.12, 0.18, 0.3)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.78)
	env.ambient_light_energy = 0.8
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)

	var ground := StaticBody3D.new()
	ground.name = "ArenaFloor"
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(ARENA_SIZE, ARENA_SIZE)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.07, 0.12, 0.2)
	floor_mat.roughness = 0.82
	floor_mesh.material_override = floor_mat
	ground.add_child(floor_mesh)
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(ARENA_SIZE, 0.5, ARENA_SIZE)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.25
	ground.add_child(floor_collision)
	add_child(ground)

	_add_arena_trim()
	camera = Camera3D.new()
	camera.position = Vector3(0, 21, 17)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true
	camera.fov = 48
	add_child(camera)

func _add_arena_trim() -> void:
	for i in range(4):
		var wall := StaticBody3D.new()
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		if i < 2:
			box.size = Vector3(ARENA_SIZE + 1.0, 1.2, 0.45)
		else:
			box.size = Vector3(0.45, 1.2, ARENA_SIZE + 1.0)
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.08, 0.72, 0.95) if i % 2 == 0 else Color(0.55, 0.22, 0.95)
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 0.5
		mesh.material_override = mat
		wall.add_child(mesh)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		col.shape = shape
		wall.add_child(col)
		match i:
			0: wall.position = Vector3(0, 0.45, -ARENA_SIZE / 2)
			1: wall.position = Vector3(0, 0.45, ARENA_SIZE / 2)
			2: wall.position = Vector3(-ARENA_SIZE / 2, 0.45, 0)
			3: wall.position = Vector3(ARENA_SIZE / 2, 0.45, 0)
		add_child(wall)

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(root)

	var top := PanelContainer.new()
	top.position = Vector2(350, 12)
	top.size = Vector2(580, 76)
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.025, 0.04, 0.08, 0.88)
	top_style.corner_radius_top_left = 18
	top_style.corner_radius_top_right = 18
	top_style.corner_radius_bottom_left = 18
	top_style.corner_radius_bottom_right = 18
	top.add_theme_stylebox_override("panel", top_style)
	root.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(top_row)
	timer_label = _make_label("02:00", 30, Color.WHITE)
	timer_label.custom_minimum_size = Vector2(130, 54)
	top_row.add_child(timer_label)
	status_label = _make_label("GEM RUSH", 22, Color(0.3, 0.88, 1.0))
	status_label.custom_minimum_size = Vector2(300, 54)
	top_row.add_child(status_label)

	score_label = _make_label("", 18, Color.WHITE)
	score_label.position = Vector2(18, 14)
	score_label.size = Vector2(300, 170)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	root.add_child(score_label)

	touch_controls = TouchControls.new()
	touch_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch_controls.action_pressed.connect(_on_player_action)
	root.add_child(touch_controls)

	menu_panel = _make_center_panel(root, Vector2(560, 540))
	result_panel = _make_center_panel(root, Vector2(500, 340))
	result_panel.hide()

func _make_center_panel(parent: Control, panel_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size = panel_size
	panel.position = (get_viewport().get_visible_rect().size - panel_size) / 2.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.09, 0.97)
	style.border_color = Color(0.16, 0.7, 0.95, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(26)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _show_menu() -> void:
	game_running = false
	menu_panel.show()
	touch_controls.hide()
	result_panel.hide()
	for child in menu_panel.get_children():
		child.queue_free()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	menu_panel.add_child(column)
	var title := _make_label("PARTY LEGENDS 2", 38, Color(0.22, 0.85, 1.0))
	column.add_child(title)
	var subtitle := _make_label("LOCAL 3D PARTY • 2–4 PLAYERS", 17, Color(0.72, 0.82, 1.0))
	column.add_child(subtitle)
	column.add_child(_make_label("عدد اللاعبين", 20, Color.WHITE))
	var count_row := HBoxContainer.new()
	count_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(count_row)
	for count in [2, 3, 4]:
		var button := Button.new()
		button.text = "%d لاعبين" % count
		button.custom_minimum_size = Vector2(135, 48)
		button.pressed.connect(func():
			player_count = count
			count_label.text = "عدد اللاعبين: %d" % player_count
		)
		count_row.add_child(button)
	count_label = _make_label("عدد اللاعبين: %d" % player_count, 16, Color(0.45, 0.95, 0.7))
	column.add_child(count_label)
	column.add_child(_make_label("اختر نمط اللعب", 20, Color.WHITE))
	for mode in range(mode_names.size()):
		var mode_button := Button.new()
		mode_button.text = ["💎  GEM RUSH — اجمع الجواهر", "👑  KING OF THE HILL — سيطر على الوسط", "⚡  SURVIVAL — تجنّب المخاطر"][mode]
		mode_button.custom_minimum_size = Vector2(0, 48)
		mode_button.pressed.connect(func():
			selected_mode = mode
			_start_game()
		)
		column.add_child(mode_button)
	var note := _make_label("كل لاعب له عصا تحكم وزر خاص في ركنه من الشاشة", 14, Color(0.68, 0.76, 0.9))
	column.add_child(note)

func _start_game() -> void:
	menu_panel.hide()
	touch_controls.show()
	result_panel.hide()
	game_running = true
	round_over = false
	time_left = 120.0 if selected_mode != 2 else 90.0
	hill_tick = 0.0
	spawn_tick = 0.0
	scores = [0, 0, 0, 0]
	lives = [3, 3, 3, 3]
	player_in_hill = [false, false, false, false]
	status_label.text = mode_names[selected_mode]
	touch_controls.set_player_count(player_count)
	_clear_round_objects()
	_create_players()
	if selected_mode == 0:
		_spawn_gems(18)
	elif selected_mode == 1:
		_create_hill()
	else:
		_create_hazards()
	_update_scoreboard()

func _clear_round_objects() -> void:
	for p in players:
		if is_instance_valid(p): p.queue_free()
	players.clear()
	for item in pickups:
		if is_instance_valid(item): item.queue_free()
	pickups.clear()
	for hazard in hazards:
		if is_instance_valid(hazard): hazard.queue_free()
	hazards.clear()
	if is_instance_valid(hill_zone): hill_zone.queue_free()
	hill_zone = null

func _create_players() -> void:
	var spawn_positions := [Vector3(-5, 0.8, 5), Vector3(5, 0.8, 5), Vector3(-5, 0.8, -5), Vector3(5, 0.8, -5)]
	for i in range(player_count):
		var body := CharacterBody3D.new()
		body.name = "Player%d" % (i + 1)
		body.collision_layer = 1
		body.collision_mask = 3
		body.position = spawn_positions[i]
		body.floor_snap_length = 0.25
		body.set_meta("player_index", i)
		var collider := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.48
		capsule.height = 1.55
		collider.shape = capsule
		collider.position.y = 0.78
		body.add_child(collider)
		var mesh_instance := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.48
		mesh.height = 1.55
		mesh_instance.mesh = mesh
		mesh_instance.position.y = 0.78
		var mat := StandardMaterial3D.new()
		mat.albedo_color = PLAYER_COLORS[i]
		mat.metallic = 0.12
		mat.roughness = 0.28
		mat.emission_enabled = true
		mat.emission = PLAYER_COLORS[i] * 0.22
		mesh_instance.material_override = mat
		body.add_child(mesh_instance)
		var marker := MeshInstance3D.new()
		var marker_mesh := SphereMesh.new()
		marker_mesh.radius = 0.13
		marker_mesh.height = 0.26
		marker.mesh = marker_mesh
		marker.position = Vector3(0, 1.65, 0)
		var marker_mat := StandardMaterial3D.new()
		marker_mat.albedo_color = Color.WHITE
		marker_mat.emission_enabled = true
		marker_mat.emission = Color.WHITE
		marker.material_override = marker_mat
		body.add_child(marker)
		add_child(body)
		players.append(body)

func _spawn_gems(amount: int) -> void:
	for i in range(amount):
		var gem := Area3D.new()
		gem.name = "Gem"
		var mesh_instance := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.28
		mesh.height = 0.56
		mesh_instance.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.15, 0.95, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.8, 1.0)
		mat.emission_energy_multiplier = 1.8
		mesh_instance.material_override = mat
		gem.add_child(mesh_instance)
		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.72
		col.shape = shape
		gem.add_child(col)
		gem.position = Vector3(randf_range(-7.0, 7.0), 0.65, randf_range(-7.0, 7.0))
		gem.body_entered.connect(_on_gem_collected.bind(gem))
		add_child(gem)
		pickups.append(gem)

func _on_gem_collected(body: Node3D, gem: Area3D) -> void:
	if not game_running or not is_instance_valid(gem) or not body.has_meta("player_index"):
		return
	var idx: int = body.get_meta("player_index")
	scores[idx] += 1
	gem.queue_free()
	pickups.erase(gem)
	if scores[idx] >= 10:
		_end_round(idx)
	elif pickups.size() < 6:
		_spawn_gems(8)
	_update_scoreboard()

func _create_hill() -> void:
	hill_zone = Area3D.new()
	hill_zone.position = Vector3(0, 0.1, 0)
	var mesh_instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 2.25
	cylinder.bottom_radius = 2.25
	cylinder.height = 0.08
	mesh_instance.mesh = cylinder
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.72, 0.12, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.55, 0.05)
	mesh_instance.material_override = mat
	hill_zone.add_child(mesh_instance)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 2.25
	shape.height = 1.8
	col.shape = shape
	col.position.y = 0.9
	hill_zone.add_child(col)
	hill_zone.body_entered.connect(_on_hill_enter)
	hill_zone.body_exited.connect(_on_hill_exit)
	add_child(hill_zone)

func _on_hill_enter(body: Node3D) -> void:
	if body.has_meta("player_index"):
		player_in_hill[int(body.get_meta("player_index"))] = true

func _on_hill_exit(body: Node3D) -> void:
	if body.has_meta("player_index"):
		player_in_hill[int(body.get_meta("player_index"))] = false

func _create_hazards() -> void:
	for i in range(4):
		var hazard := RigidBody3D.new()
		hazard.name = "Hazard%d" % i
		hazard.position = Vector3(randf_range(-6, 6), 0.75, randf_range(-6, 6))
		hazard.gravity_scale = 0.0
		hazard.contact_monitor = true
		hazard.max_contacts_reported = 8
		hazard.linear_velocity = Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
		hazard.collision_layer = 2
		hazard.collision_mask = 1
		var mesh_instance := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.72
		mesh.height = 1.44
		mesh_instance.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.2, 0.12)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.08, 0.02)
		mesh_instance.material_override = mat
		hazard.add_child(mesh_instance)
		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.72
		col.shape = shape
		hazard.add_child(col)
		hazard.body_entered.connect(_on_hazard_hit.bind(hazard))
		add_child(hazard)
		hazards.append(hazard)

func _on_hazard_hit(body: Node3D, hazard: RigidBody3D) -> void:
	if not game_running or not body.has_meta("player_index"):
		return
	var idx: int = body.get_meta("player_index")
	if lives[idx] <= 0:
		return
	lives[idx] -= 1
	body.position = Vector3(randf_range(-5, 5), 1, randf_range(-5, 5))
	if lives[idx] <= 0:
		body.hide()
		body.set_physics_process(false)
	_update_scoreboard()
	var alive := 0
	var last := -1
	for i in range(player_count):
		if lives[i] > 0:
			alive += 1
			last = i
	if alive == 1:
		_end_round(last)

func _on_player_action(player_index: int) -> void:
	if not game_running or player_index >= players.size():
		return
	var body := players[player_index]
	if body.is_visible_in_tree() and body.is_on_floor():
		body.velocity.y = 9.0

func _physics_process(delta: float) -> void:
	if not game_running:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_finish_by_score()
	for i in range(players.size()):
		var body := players[i]
		if not is_instance_valid(body) or not body.visible:
			continue
		var input_vector := Vector2.ZERO
		if touch_controls:
			input_vector = touch_controls.get_vector(i)
		input_vector += _keyboard_vector(i)
		if input_vector.length() > 1.0:
			input_vector = input_vector.normalized()
		var direction := Vector3(input_vector.x, 0, input_vector.y)
		var speed := 7.0
		body.velocity.x = direction.x * speed
		body.velocity.z = direction.z * speed
		if not body.is_on_floor():
			body.velocity.y -= 24.0 * delta
		else:
			body.velocity.y = maxf(body.velocity.y, 0.0)
		body.move_and_slide()
		body.position.x = clampf(body.position.x, -8.5, 8.5)
		body.position.z = clampf(body.position.z, -8.5, 8.5)
	if selected_mode == 1:
		hill_tick += delta
		if hill_tick >= 1.0:
			hill_tick = 0.0
			for i in range(player_count):
				if player_in_hill[i]:
					scores[i] += 1
					if scores[i] >= 30:
						_end_round(i)
			_update_scoreboard()
	elif selected_mode == 2:
		for hazard in hazards:
			if is_instance_valid(hazard):
				if absf(hazard.position.x) > 8.0: hazard.linear_velocity.x *= -1.0
				if absf(hazard.position.z) > 8.0: hazard.linear_velocity.z *= -1.0
	_update_timer()

func _keyboard_vector(i: int) -> Vector2:
	match i:
		0: return Input.get_vector("p1_left", "p1_right", "p1_up", "p1_down")
		1: return Input.get_vector("p2_left", "p2_right", "p2_up", "p2_down")
		2: return Input.get_vector("p3_left", "p3_right", "p3_up", "p3_down")
		3: return Input.get_vector("p4_left", "p4_right", "p4_up", "p4_down")
	return Vector2.ZERO

func _update_timer() -> void:
	var total := int(ceil(time_left))
	timer_label.text = "%02d:%02d" % [total / 60, total % 60]

func _update_scoreboard() -> void:
	var lines := []
	for i in range(player_count):
		var extra := "  ♥ %d" % lives[i] if selected_mode == 2 else ""
		lines.append("P%d  %s   %d%s" % [i + 1, PLAYER_NAMES[i], scores[i], extra])
	score_label.text = "\n".join(lines)

func _finish_by_score() -> void:
	var best := -1
	var winner := 0
	for i in range(player_count):
		var value := scores[i]
		if selected_mode == 2:
			value = lives[i]
		if value > best:
			best = value
			winner = i
	_end_round(winner)

func _end_round(winner: int) -> void:
	if round_over:
		return
	round_over = true
	game_running = false
	for child in result_panel.get_children():
		child.queue_free()
	result_panel.show()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	result_panel.add_child(column)
	column.add_child(_make_label("🏆 ROUND FINISHED", 30, Color(1.0, 0.78, 0.2)))
	column.add_child(_make_label("PLAYER %d WINS!" % (winner + 1), 28, PLAYER_COLORS[winner]))
	column.add_child(_make_label("النتائج محفوظة لهذه الجولة", 16, Color(0.78, 0.85, 0.96)))
	var again := Button.new()
	again.text = "العب مرة أخرى"
	again.custom_minimum_size.y = 48
	again.pressed.connect(_start_game)
	column.add_child(again)
	var back := Button.new()
	back.text = "القائمة الرئيسية"
	back.custom_minimum_size.y = 48
	back.pressed.connect(_show_menu)
	column.add_child(back)
