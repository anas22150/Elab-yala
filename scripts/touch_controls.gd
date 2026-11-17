extends Control

signal action_pressed(player_index: int)

const JOY_RADIUS := 88.0
const BUTTON_RADIUS := 48.0
var player_count := 4
var active_touches: Dictionary = {}
var vectors: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var touch_to_player: Dictionary = {}
var touch_origins: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func set_player_count(value: int) -> void:
	player_count = clampi(value, 2, 4)
	vectors = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	queue_redraw()

func _centers() -> Array[Vector2]:
	var s := size
	return [Vector2(112, s.y - 112), Vector2(s.x - 112, s.y - 112), Vector2(112, 112), Vector2(s.x - 112, 112)]

func _buttons() -> Array[Vector2]:
	var s := size
	return [Vector2(292, s.y - 112), Vector2(s.x - 292, s.y - 112), Vector2(292, 112), Vector2(s.x - 292, 112)]

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_handle_press(event.index, event.position)
		else:
			_handle_release(event.index)
	elif event is InputEventScreenDrag:
		_handle_drag(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_press(-1, event.position)
		else:
			_handle_release(-1)
	elif event is InputEventMouseMotion and active_touches.has(-1):
		_handle_drag(-1, event.position)

func _handle_press(touch_id: int, pos: Vector2) -> void:
	var buttons := _buttons()
	for i in range(player_count):
		if pos.distance_to(buttons[i]) <= BUTTON_RADIUS:
			action_pressed.emit(i)
			return
	var centers := _centers()
	var best := -1
	var best_distance := JOY_RADIUS * 1.5
	for i in range(player_count):
		var d := pos.distance_to(centers[i])
		if d < best_distance and not _player_has_touch(i):
			best = i
			best_distance = d
	if best >= 0:
		touch_to_player[touch_id] = best
		touch_origins[touch_id] = centers[best]
		_handle_drag(touch_id, pos)

func _handle_drag(touch_id: int, pos: Vector2) -> void:
	if not touch_to_player.has(touch_id):
		return
	var player_index: int = touch_to_player[touch_id]
	var origin: Vector2 = touch_origins[touch_id]
	var delta := pos - origin
	if delta.length() > JOY_RADIUS:
		delta = delta.normalized() * JOY_RADIUS
	vectors[player_index] = Vector2(delta.x, delta.y) / JOY_RADIUS
	queue_redraw()

func _handle_release(touch_id: int) -> void:
	if touch_to_player.has(touch_id):
		var player_index: int = touch_to_player[touch_id]
		vectors[player_index] = Vector2.ZERO
		touch_to_player.erase(touch_id)
		touch_origins.erase(touch_id)
		queue_redraw()
	elif touch_id == -1:
		active_touches.erase(-1)

func _player_has_touch(player_index: int) -> bool:
	return touch_to_player.values().has(player_index)

func get_vector(player_index: int) -> Vector2:
	return vectors[player_index] if player_index < player_count else Vector2.ZERO

func _draw() -> void:
	var centers := _centers()
	var buttons := _buttons()
	var colors := [Color(0.18, 0.78, 1.0, 0.42), Color(1.0, 0.38, 0.32, 0.42), Color(0.35, 0.95, 0.55, 0.42), Color(1.0, 0.76, 0.22, 0.42)]
	for i in range(player_count):
		var center := centers[i]
		var color: Color = colors[i]
		draw_circle(center, JOY_RADIUS, Color(0.02, 0.04, 0.08, 0.42))
		draw_arc(center, JOY_RADIUS, 0.0, TAU, 48, color, 4.0, true)
		var knob := center + vectors[i] * 42.0
		draw_circle(knob, 31.0, color)
		draw_circle(buttons[i], BUTTON_RADIUS, Color(0.06, 0.08, 0.13, 0.55))
		draw_arc(buttons[i], BUTTON_RADIUS, 0.0, TAU, 40, color, 4.0, true)
		draw_string(ThemeDB.fallback_font, buttons[i] + Vector2(-9, 9), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color.WHITE)
		draw_string(ThemeDB.fallback_font, center + Vector2(-9, -JOY_RADIUS - 12), "P%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
