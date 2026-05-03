extends Node2D
class_name WorldFoundation

signal world_initialized(world_rect: Rect2)
signal tile_stage_changed(coord: Vector2i, stage: int)
signal baseline_reset

const STAGE_DRY_COMPACTED := 0
const STAGE_RECOVERING := 1
const STAGE_SEMI_HEALTHY := 2
const STAGE_HEALTHY := 3
const CAM_LEFT_ACTION := "cam_left"
const CAM_RIGHT_ACTION := "cam_right"
const CAM_UP_ACTION := "cam_up"
const CAM_DOWN_ACTION := "cam_down"

@export var columns: int = 48
@export var rows: int = 27
@export var tile_size: float = 64.0
@export var mode_id: String = ""
@export var scenario_id: String = ""
@export var camera_pan_speed: float = 900.0
@export var follow_response_speed: float = 10.0
@export var follow_deadzone_ratio: Vector2 = Vector2(0.28, 0.22)
@export var enable_pan_gesture: bool = true
@export var pan_gesture_scale: float = 1.0
@export var drag_pan_button: MouseButton = MOUSE_BUTTON_RIGHT
@export var allow_left_drag_pan: bool = true
@export var enable_touch_pan: bool = true
@export var debug_overlay_enabled: bool = false
@export var debug_edit_enabled: bool = false
@export var drag_hint_available_color: Color = Color(0.20, 0.95, 0.35, 0.95)
@export var drag_hint_blocked_color: Color = Color(0.95, 0.20, 0.20, 0.95)

@onready var camera: Camera2D = $Camera2D
@onready var debug_label: Label = $DebugCanvas/DebugLabel

var _tiles: Array = []
var _baseline_stage: PackedInt32Array = PackedInt32Array()
var _desktop_dragging := false
var _desktop_drag_last := Vector2.ZERO
var _desktop_drag_button: MouseButton = MOUSE_BUTTON_NONE
var _touch_drag_id: int = -1
var _touch_drag_last := Vector2.ZERO
var _drag_hint_visible := false
var _drag_hint_coord := Vector2i(-1, -1)
var _drag_hint_available := true


func _ready() -> void:
	_initialize_tile_data()
	_build_baseline_pattern()
	reset_to_baseline()
	_ensure_camera_pan_actions()
	_setup_camera()
	if get_viewport().has_signal("size_changed"):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	_sync_global_world_context()
	_update_debug_label()
	queue_redraw()
	emit_signal("world_initialized", get_world_rect())


func _exit_tree() -> void:
	if Global.world_bounds_enabled:
		Global.clear_world_context()


func set_context(new_mode_id: String, new_scenario_id: String) -> void:
	mode_id = new_mode_id
	scenario_id = new_scenario_id
	_sync_global_world_context()
	_update_debug_label()


func get_world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(columns * tile_size, rows * tile_size))


func get_world_center() -> Vector2:
	var rect = get_world_rect()
	return rect.position + rect.size * 0.5


func get_tile(coord: Vector2i) -> Dictionary:
	if not in_bounds(coord):
		return {}
	return _tiles[_index_for(coord)].duplicate(true)


func set_stage(coord: Vector2i, stage: int) -> void:
	if not in_bounds(coord):
		return
	var clamped_stage = clampi(stage, STAGE_DRY_COMPACTED, STAGE_HEALTHY)
	var idx = _index_for(coord)
	var tile: Dictionary = _tiles[idx]
	if int(tile["stage"]) == clamped_stage:
		return
	tile["stage"] = clamped_stage
	_tiles[idx] = tile
	queue_redraw()
	tile_stage_changed.emit(coord, clamped_stage)
	_update_debug_label(coord)


func set_tiles_stage(coords: Array, stage: int) -> void:
	var changed := false
	var clamped_stage = clampi(stage, STAGE_DRY_COMPACTED, STAGE_HEALTHY)
	for coord_variant in coords:
		var coord = Vector2i(coord_variant)
		if not in_bounds(coord):
			continue
		var idx = _index_for(coord)
		var tile: Dictionary = _tiles[idx]
		if int(tile["stage"]) == clamped_stage:
			continue
		tile["stage"] = clamped_stage
		_tiles[idx] = tile
		tile_stage_changed.emit(coord, clamped_stage)
		changed = true
	if changed:
		queue_redraw()
	_update_debug_label()


func world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(floor(world_pos.x / tile_size), floor(world_pos.y / tile_size))


func tile_to_world_center(coord: Vector2i) -> Vector2:
	return Vector2((coord.x + 0.5) * tile_size, (coord.y + 0.5) * tile_size)


func in_bounds(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.y >= 0 and coord.x < columns and coord.y < rows


func reset_to_baseline() -> void:
	for y in range(rows):
		for x in range(columns):
			var coord = Vector2i(x, y)
			var idx = _index_for(coord)
			var stage = int(_baseline_stage[idx])
			var defaults = _stage_defaults(stage)
			var tile = {
				"stage": stage,
				"moisture": defaults["moisture"],
				"compaction": defaults["compaction"],
				"organic_matter": defaults["organic_matter"],
				"flags": 0
			}
			_tiles[idx] = tile
	queue_redraw()
	baseline_reset.emit()
	_update_debug_label()


func set_drag_tile_hint(coord: Vector2i, available: bool) -> void:
	if not in_bounds(coord):
		clear_drag_tile_hint()
		return
	if _drag_hint_visible and _drag_hint_coord == coord and _drag_hint_available == available:
		return
	_drag_hint_visible = true
	_drag_hint_coord = coord
	_drag_hint_available = available
	queue_redraw()


func clear_drag_tile_hint() -> void:
	if not _drag_hint_visible:
		return
	_drag_hint_visible = false
	_drag_hint_coord = Vector2i(-1, -1)
	queue_redraw()


func _draw() -> void:
	for y in range(rows):
		for x in range(columns):
			var coord = Vector2i(x, y)
			var idx = _index_for(coord)
			var stage = int(_tiles[idx]["stage"])
			var rect = Rect2(Vector2(x * tile_size, y * tile_size), Vector2(tile_size, tile_size))
			draw_rect(rect, _stage_color(stage), true)
			_draw_stage_detail(rect, stage)
			if debug_overlay_enabled:
				draw_rect(rect, Color(0, 0, 0, 0.15), false, 1.0, true)
				var font = ThemeDB.fallback_font
				if font != null:
					draw_string(font, rect.position + Vector2(4, 13), str(coord.x, ",", coord.y), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0, 0, 0, 0.9))
					draw_string(font, rect.position + Vector2(4, 26), str("S", stage), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0, 0, 0, 0.9))
	if _drag_hint_visible and in_bounds(_drag_hint_coord):
		var hint_rect = Rect2(Vector2(_drag_hint_coord.x * tile_size, _drag_hint_coord.y * tile_size), Vector2(tile_size, tile_size))
		var hint_color = drag_hint_available_color if _drag_hint_available else drag_hint_blocked_color
		draw_rect(hint_rect, Color(hint_color, 0.16), true)
		draw_rect(hint_rect, hint_color, false, 3.0, true)
	if debug_overlay_enabled:
		draw_rect(Rect2(Vector2.ZERO, get_world_rect().size), Color(1, 1, 1, 0.9), false, 3.0, true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			debug_overlay_enabled = not debug_overlay_enabled
			queue_redraw()
			_update_debug_label()
		elif event.keycode == KEY_F2:
			reset_to_baseline()
		elif event.keycode == KEY_F3:
			debug_edit_enabled = not debug_edit_enabled
			_update_debug_label()

	if event is InputEventMouseButton:
		if event.button_index == drag_pan_button:
			if event.pressed:
				_try_start_desktop_pan(event.button_index, event.position)
			else:
				_stop_desktop_pan(event.button_index)
		elif allow_left_drag_pan and drag_pan_button != MOUSE_BUTTON_LEFT and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_try_start_desktop_pan(event.button_index, event.position)
			else:
				_stop_desktop_pan(event.button_index)

	if debug_edit_enabled and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not _is_pointer_over_ui(event.position):
			_cycle_stage_at_world_pos(Global.screen_to_world(self, event.position))

	if enable_touch_pan:
		if event is InputEventScreenTouch:
			if event.pressed and _touch_drag_id == -1 and not _is_pointer_over_ui(event.position):
				_touch_drag_id = event.index
				_touch_drag_last = event.position
			elif not event.pressed and event.index == _touch_drag_id:
				_touch_drag_id = -1
		if event is InputEventScreenDrag and event.index == _touch_drag_id and not Global.is_dragging:
			var delta = event.position - _touch_drag_last
			_touch_drag_last = event.position
			_pan_camera_by_screen_delta(delta)
	if enable_pan_gesture and event is InputEventPanGesture and not Global.is_dragging:
		var pointer_pos = get_viewport().get_mouse_position()
		if not _is_pointer_over_ui(pointer_pos):
			_pan_camera_by_screen_delta(event.delta * pan_gesture_scale)

	if event is InputEventMouseMotion:
		if _desktop_dragging and not Global.is_dragging:
			var delta = event.position - _desktop_drag_last
			_desktop_drag_last = event.position
			_pan_camera_by_screen_delta(delta)
		if debug_overlay_enabled or debug_edit_enabled:
			_update_debug_label()


func _process(delta: float) -> void:
	var followed = _follow_active_agent(delta)
	if not followed and _should_keyboard_pan():
		var pan_dir = _get_camera_pan_vector()
		if pan_dir != Vector2.ZERO:
			camera.global_position += pan_dir.normalized() * camera_pan_speed * delta
			_clamp_camera()
	if debug_overlay_enabled or debug_edit_enabled:
		_update_debug_label()


func _initialize_tile_data() -> void:
	var total = columns * rows
	_tiles.resize(total)
	_baseline_stage.resize(total)
	for idx in range(total):
		_tiles[idx] = {
			"stage": STAGE_DRY_COMPACTED,
			"moisture": 0.12,
			"compaction": 0.9,
			"organic_matter": 0.08,
			"flags": 0
		}
		_baseline_stage[idx] = STAGE_DRY_COMPACTED


func _build_baseline_pattern() -> void:
	var half_cols = columns / 2
	var half_rows = rows / 2
	for y in range(rows):
		for x in range(columns):
			var stage = STAGE_DRY_COMPACTED
			if x >= half_cols and y < half_rows:
				stage = STAGE_RECOVERING
			elif x < half_cols and y >= half_rows:
				stage = STAGE_SEMI_HEALTHY
			elif x >= half_cols and y >= half_rows:
				stage = STAGE_HEALTHY
			_baseline_stage[_index_for(Vector2i(x, y))] = stage

	for x in range(columns):
		var y_diag = int(round(float(x) / max(float(columns - 1), 1.0) * float(rows - 1)))
		for offset in range(-1, 2):
			var yy = y_diag + offset
			if yy >= 0 and yy < rows:
				var mixed_stage = int(posmod(x + yy, 4))
				_baseline_stage[_index_for(Vector2i(x, yy))] = mixed_stage


func _stage_defaults(stage: int) -> Dictionary:
	match stage:
		STAGE_DRY_COMPACTED:
			return {"moisture": 0.12, "compaction": 0.9, "organic_matter": 0.08}
		STAGE_RECOVERING:
			return {"moisture": 0.3, "compaction": 0.68, "organic_matter": 0.24}
		STAGE_SEMI_HEALTHY:
			return {"moisture": 0.52, "compaction": 0.45, "organic_matter": 0.46}
		_:
			return {"moisture": 0.72, "compaction": 0.24, "organic_matter": 0.68}


func _stage_color(stage: int) -> Color:
	match stage:
		STAGE_DRY_COMPACTED:
			return Color(0.56, 0.47, 0.39, 1.0)
		STAGE_RECOVERING:
			return Color(0.44, 0.40, 0.31, 1.0)
		STAGE_SEMI_HEALTHY:
			return Color(0.33, 0.37, 0.27, 1.0)
		_:
			return Color(0.23, 0.34, 0.21, 1.0)


func _draw_stage_detail(rect: Rect2, stage: int) -> void:
	if stage == STAGE_DRY_COMPACTED:
		draw_line(rect.position + Vector2(6, 8), rect.position + rect.size - Vector2(6, 8), Color(0.45, 0.35, 0.26, 0.65), 1.4)
		draw_line(rect.position + Vector2(14, rect.size.y - 9), rect.position + Vector2(rect.size.x - 12, 9), Color(0.47, 0.37, 0.27, 0.5), 1.0)
	elif stage == STAGE_RECOVERING:
		draw_circle(rect.position + rect.size * 0.5, tile_size * 0.08, Color(0.63, 0.67, 0.44, 0.5))
	elif stage == STAGE_SEMI_HEALTHY:
		draw_circle(rect.position + rect.size * 0.33, tile_size * 0.07, Color(0.63, 0.76, 0.57, 0.45))
		draw_circle(rect.position + rect.size * 0.67, tile_size * 0.07, Color(0.60, 0.74, 0.55, 0.45))
	else:
		draw_circle(rect.position + rect.size * 0.5, tile_size * 0.12, Color(0.64, 0.84, 0.66, 0.45))


func _setup_camera() -> void:
	camera.enabled = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.global_position = get_world_center()
	_clamp_camera()


func _on_viewport_size_changed() -> void:
	_clamp_camera()


func _clamp_camera() -> void:
	var rect = get_world_rect()
	var view_size = get_viewport().get_visible_rect().size
	var half = view_size * 0.5
	var min_x = rect.position.x + half.x
	var max_x = rect.position.x + rect.size.x - half.x
	var min_y = rect.position.y + half.y
	var max_y = rect.position.y + rect.size.y - half.y

	if min_x > max_x:
		camera.global_position.x = rect.position.x + rect.size.x * 0.5
	else:
		camera.global_position.x = clampf(camera.global_position.x, min_x, max_x)
	if min_y > max_y:
		camera.global_position.y = rect.position.y + rect.size.y * 0.5
	else:
		camera.global_position.y = clampf(camera.global_position.y, min_y, max_y)


func _pan_camera_by_screen_delta(delta: Vector2) -> void:
	camera.global_position -= delta
	_clamp_camera()


func _follow_active_agent(delta: float) -> bool:
	var active_agent = Global.active_agent
	if not is_instance_valid(active_agent):
		return false
	if bool(active_agent.get("dead")):
		return false
	if not _is_active_agent_user_moving(active_agent):
		return false

	var view_size = get_viewport().get_visible_rect().size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return false

	var center = view_size * 0.5
	var safe_ratio = Vector2(
		clampf(follow_deadzone_ratio.x, 0.05, 0.49),
		clampf(follow_deadzone_ratio.y, 0.05, 0.49)
	)
	var deadzone_half = Vector2(view_size.x * safe_ratio.x, view_size.y * safe_ratio.y)
	var focus_screen = Global.world_to_screen(self, active_agent.global_position)
	var shift_screen = Vector2.ZERO

	if focus_screen.x < center.x - deadzone_half.x:
		shift_screen.x = focus_screen.x - (center.x - deadzone_half.x)
	elif focus_screen.x > center.x + deadzone_half.x:
		shift_screen.x = focus_screen.x - (center.x + deadzone_half.x)

	if focus_screen.y < center.y - deadzone_half.y:
		shift_screen.y = focus_screen.y - (center.y - deadzone_half.y)
	elif focus_screen.y > center.y + deadzone_half.y:
		shift_screen.y = focus_screen.y - (center.y + deadzone_half.y)

	if shift_screen.length_squared() < 0.25:
		return false

	var target_pos = camera.global_position + shift_screen
	var t = min(1.0, follow_response_speed * delta)
	camera.global_position = camera.global_position.lerp(target_pos, t)
	_clamp_camera()
	return true


func _is_active_agent_user_moving(active_agent: Node) -> bool:
	if Global.is_dragging:
		return true
	var drag_flag = active_agent.get("is_dragging")
	if typeof(drag_flag) == TYPE_BOOL and drag_flag:
		return true
	return Input.get_vector("left", "right", "up", "down") != Vector2.ZERO


func _should_keyboard_pan() -> bool:
	return not Global.is_dragging


func _get_camera_pan_vector() -> Vector2:
	var pan = Input.get_vector(CAM_LEFT_ACTION, CAM_RIGHT_ACTION, CAM_UP_ACTION, CAM_DOWN_ACTION)
	if Input.is_key_pressed(KEY_SHIFT):
		pan += Input.get_vector("left", "right", "up", "down")
	return pan.limit_length()


func _ensure_camera_pan_actions() -> void:
	var key_map = {
		CAM_LEFT_ACTION: [KEY_A],
		CAM_RIGHT_ACTION: [KEY_D],
		CAM_UP_ACTION: [KEY_W],
		CAM_DOWN_ACTION: [KEY_S]
	}
	for action in key_map.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode in key_map[action]:
			var key = int(keycode)
			if _action_has_key(action, key):
				continue
			var input_event := InputEventKey.new()
			input_event.physical_keycode = key
			InputMap.action_add_event(action, input_event)


func _action_has_key(action: String, keycode: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			if int(event.physical_keycode) == keycode or int(event.keycode) == keycode:
				return true
	return false


func _try_start_desktop_pan(button: MouseButton, screen_pos: Vector2) -> void:
	if Global.is_dragging:
		return
	if _is_pointer_over_ui(screen_pos):
		return
	if button == MOUSE_BUTTON_LEFT and debug_edit_enabled:
		return
	_desktop_dragging = true
	_desktop_drag_button = button
	_desktop_drag_last = screen_pos


func _stop_desktop_pan(button: MouseButton) -> void:
	if _desktop_dragging and _desktop_drag_button == button:
		_desktop_dragging = false
		_desktop_drag_button = MOUSE_BUTTON_NONE


func _sync_global_world_context() -> void:
	var resolved_mode = mode_id if mode_id != "" else Global.mode
	var resolved_scenario = scenario_id if scenario_id != "" else ("people" if Global.social_mode else "plants")
	Global.set_world_context(get_world_rect(), resolved_mode, resolved_scenario)


func _index_for(coord: Vector2i) -> int:
	return coord.y * columns + coord.x


func _cycle_stage_at_world_pos(world_pos: Vector2) -> void:
	var coord = world_to_tile(world_pos)
	if not in_bounds(coord):
		return
	var tile = get_tile(coord)
	if tile.is_empty():
		return
	var next_stage = int(posmod(int(tile["stage"]) + 1, 4))
	set_stage(coord, next_stage)


func _update_debug_label(coord_hint: Vector2i = Vector2i(-1, -1)) -> void:
	if not is_instance_valid(debug_label):
		return
	var show = debug_overlay_enabled or debug_edit_enabled
	debug_label.visible = show
	if not show:
		return

	var hover_coord = coord_hint
	if hover_coord.x < 0 or hover_coord.y < 0:
		hover_coord = world_to_tile(get_global_mouse_position())

	var hover_text = "out"
	if in_bounds(hover_coord):
		var tile = get_tile(hover_coord)
		hover_text = str(hover_coord, " stage=", tile.get("stage", "?"))

	var rect = get_world_rect()
	var lines = [
		"WorldFoundation",
		str("mode_id=", mode_id if mode_id != "" else Global.mode),
		str("scenario_id=", scenario_id if scenario_id != "" else ("people" if Global.social_mode else "plants")),
		str("grid=", columns, "x", rows, " tile=", tile_size),
		str("world_rect=", rect),
		str("hover=", hover_text),
		str("edit=", debug_edit_enabled, "  overlay=", debug_overlay_enabled),
		"F1 overlay | F2 reset | F3 edit"
	]
	debug_label.text = "\n".join(lines)


func _is_pointer_over_ui(screen_pos: Vector2) -> bool:
	for ui in get_tree().get_nodes_in_group("ui"):
		if not is_instance_valid(ui):
			continue
		if ui.has_node("MarginContainer"):
			var panel = ui.get_node("MarginContainer")
			if is_instance_valid(panel) and panel.get_global_rect().has_point(screen_pos):
				return true
		if ui.has_node("RestartContainer"):
			var restart = ui.get_node("RestartContainer")
			if is_instance_valid(restart) and restart.visible and restart.get_global_rect().has_point(screen_pos):
				return true
		if ui.has_node("TutorialMarginContainer1"):
			var tutorial_box = ui.get_node("TutorialMarginContainer1")
			if is_instance_valid(tutorial_box) and tutorial_box.visible and tutorial_box.get_global_rect().has_point(screen_pos):
				return true
	return false
