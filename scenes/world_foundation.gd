extends Node2D
class_name WorldFoundation

signal world_initialized(world_rect: Rect2)
signal tile_stage_changed(coord: Vector2i, stage: int)
signal baseline_reset

const LevelHelpersRef = preload("res://scenes/level_helpers.gd")

const STAGE_DRY_COMPACTED := 0
const STAGE_RECOVERING := 1
const STAGE_SEMI_HEALTHY := 2
const STAGE_HEALTHY := 3
const CAM_LEFT_ACTION := "cam_left"
const CAM_RIGHT_ACTION := "cam_right"
const CAM_UP_ACTION := "cam_up"
const CAM_DOWN_ACTION := "cam_down"
const SOIL_BASE_MOISTURE_DELTA := -0.01
const SOIL_BASE_ORGANIC_DELTA := -0.004
const SOIL_BASE_COMPACTION_DELTA := 0.003
const SOIL_UNSUPPORTED_DECAY_MULTIPLIER := 2.0
const SOIL_MYCO_CORE_MOISTURE_DELTA := 0.045
const SOIL_MYCO_CORE_COMPACTION_DELTA := -0.02
const SOIL_MYCO_NEIGHBOR_MOISTURE_DELTA := 0.02
const SOIL_MYCO_NEIGHBOR_COMPACTION_DELTA := -0.01
const SOIL_LIVE_PLANT_MOISTURE_DELTA := -0.008
const SOIL_LIVE_PLANT_ORGANIC_DELTA := 0.001
const SOIL_RESIDUE_MOISTURE_DELTA := 0.015
const SOIL_RESIDUE_ORGANIC_DELTA := 0.03
const SOIL_SCORE_DRY_MAX := 0.30
const SOIL_SCORE_RECOVERING_MAX := 0.48
const SOIL_SCORE_SEMI_HEALTHY_MAX := 0.68
const DEFAULT_RESIDUE_LIFETIME_TICKS := 8
const SOIL_INFLUENCE_RADIUS := 4
const STORY_WORLD_COLUMNS := 26
const STORY_WORLD_ROWS := 27
const STORY_START_TILE := Vector2i(7, 13)
const STORY_VILLAGE_OFFSET_RIGHT_TILES := 9
const STORY_VILLAGE_RECT := Rect2i(STORY_START_TILE.x + STORY_VILLAGE_OFFSET_RIGHT_TILES, 9, 10, 10)
const STORY_HIDDEN_VILLAGE_RECT := Rect2i(STORY_VILLAGE_RECT.position + Vector2i(3, 0), Vector2i(7, 10))
const CHALLENGE_LAYOUT_CENTER_OFFSET_FROM_START_X := 2
const STORY_FOG_TICK_SECONDS := 0.25
const STORY_FOG_COLOR := Color(0.02, 0.03, 0.04, 0.62)
const HOTKEY_WORLD_DEBUG_OVERLAY := KEY_Z
const HOTKEY_WORLD_RESET_BASELINE := KEY_X
const HOTKEY_WORLD_EDIT_TILES := KEY_C
const HOTKEY_WORLD_TOGGLE_FOG := KEY_V
const DEFAULT_CAMERA_SMOOTHING_SPEED := 8.0

@export var columns: int = 48
@export var rows: int = 27
@export var tile_size: float = 64.0
@export var mode_id: String = ""
@export var scenario_id: String = ""
@export var soil_tick_seconds: float = 1.0
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
@export var story_fog_enabled: bool = true
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
var _camera_pan_suppressed_until_msec := 0
var _drag_hint_visible := false
var _drag_hint_coord := Vector2i(-1, -1)
var _drag_hint_secondary_visible := false
var _drag_hint_secondary_coord := Vector2i(-1, -1)
var _drag_hint_available := true
var _drag_hint_alpha := 1.0
var _drag_hint_fading := false
var _drag_hint_fade_elapsed := 0.0
var _drag_hint_fade_duration := 0.28
var _soil_tick_timer: Timer = null
var _fog_tick_timer: Timer = null
var _residue_records: Array = []
var _occupancy_by_tile: Dictionary = {}
var _footprint_by_agent: Dictionary = {}
var _influence_kernel: Array = []
var _revealed_tiles: PackedByteArray = PackedByteArray()
var _permanent_revealed_tiles: PackedByteArray = PackedByteArray()


func _ready() -> void:
	if str(Global.mode) == "story":
		columns = STORY_WORLD_COLUMNS
		rows = STORY_WORLD_ROWS
	_initialize_tile_data()
	_initialize_reveal_data()
	_build_influence_kernel(SOIL_INFLUENCE_RADIUS)
	_build_baseline_pattern()
	reset_to_baseline()
	_start_soil_tick()
	_start_fog_tick()
	_ensure_camera_pan_actions()
	_setup_camera()
	if get_viewport().has_signal("size_changed"):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	_sync_global_world_context()
	_update_debug_label()
	queue_redraw()
	emit_signal("world_initialized", get_world_rect())


func _exit_tree() -> void:
	if is_instance_valid(_fog_tick_timer):
		_fog_tick_timer.stop()
		_fog_tick_timer.queue_free()
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


func configure_dimensions(new_columns: int, new_rows: int) -> void:
	var safe_cols = maxi(new_columns, 1)
	var safe_rows = maxi(new_rows, 1)
	if safe_cols == columns and safe_rows == rows:
		return
	columns = safe_cols
	rows = safe_rows
	_initialize_tile_data()
	_initialize_reveal_data()
	_build_baseline_pattern()
	reset_to_baseline()
	_sync_global_world_context()
	_setup_camera()
	queue_redraw()
	emit_signal("world_initialized", get_world_rect())


func get_tile(coord: Vector2i) -> Dictionary:
	if not in_bounds(coord):
		return {}
	return _tiles[_index_for(coord)].duplicate(true)


func is_tile_occupied_cached(coord: Vector2i, ignore_agent: Variant = null) -> bool:
	Global.perf_count_tile_occupancy_query()
	if not in_bounds(coord):
		return false
	var occupants_variant = _occupancy_by_tile.get(coord, [])
	if typeof(occupants_variant) != TYPE_ARRAY:
		return false
	var occupants: Array = occupants_variant
	if occupants.is_empty():
		return false
	var cleaned: Array = []
	for agent in occupants:
		if not is_instance_valid(agent):
			continue
		if bool(agent.get("dead")):
			continue
		if is_instance_valid(ignore_agent) and agent == ignore_agent:
			cleaned.append(agent)
			continue
		cleaned.append(agent)
		_occupancy_by_tile[coord] = cleaned
		return true
	_occupancy_by_tile[coord] = cleaned
	return false


func get_tile_occupants_cached(coord: Vector2i, ignore_agent: Variant = null) -> Array:
	Global.perf_count_tile_occupancy_query()
	if not in_bounds(coord):
		return []
	var occupants_variant = _occupancy_by_tile.get(coord, [])
	if typeof(occupants_variant) != TYPE_ARRAY:
		return []
	var occupants: Array = occupants_variant
	if occupants.is_empty():
		return []
	var cleaned: Array = []
	for agent in occupants:
		if not is_instance_valid(agent):
			continue
		if bool(agent.get("dead")):
			continue
		if str(agent.get("type")) == "cloud":
			continue
		if is_instance_valid(ignore_agent) and agent == ignore_agent:
			continue
		cleaned.append(agent)
	_occupancy_by_tile[coord] = cleaned
	return cleaned


func register_agent_footprint(agent: Variant, coords: Array) -> void:
	if not is_instance_valid(agent):
		return
	unregister_agent_footprint(agent)
	var key = int(agent.get_instance_id())
	var normalized: Array = []
	for coord_variant in coords:
		var coord = Vector2i(coord_variant)
		if not in_bounds(coord):
			continue
		normalized.append(coord)
		_insert_tile_occupant(coord, agent)
	_footprint_by_agent[key] = normalized


func update_agent_footprint(agent: Variant, old_coords: Array, new_coords: Array) -> void:
	if not is_instance_valid(agent):
		return
	var old_map: Dictionary = {}
	var new_map: Dictionary = {}
	for coord_variant in old_coords:
		var coord = Vector2i(coord_variant)
		if in_bounds(coord):
			old_map[coord] = true
	for coord_variant in new_coords:
		var coord = Vector2i(coord_variant)
		if in_bounds(coord):
			new_map[coord] = true
	for coord_variant in old_map.keys():
		var coord = Vector2i(coord_variant)
		if new_map.has(coord):
			continue
		_remove_tile_occupant(coord, agent)
	for coord_variant in new_map.keys():
		var coord = Vector2i(coord_variant)
		if old_map.has(coord):
			continue
		_insert_tile_occupant(coord, agent)
	var key = int(agent.get_instance_id())
	_footprint_by_agent[key] = new_map.keys()


func unregister_agent_footprint(agent: Variant) -> void:
	if not is_instance_valid(agent):
		return
	var key = int(agent.get_instance_id())
	if not _footprint_by_agent.has(key):
		return
	var coords_variant = _footprint_by_agent[key]
	if typeof(coords_variant) == TYPE_ARRAY:
		for coord_variant in coords_variant:
			var coord = Vector2i(coord_variant)
			if in_bounds(coord):
				_remove_tile_occupant(coord, agent)
	_footprint_by_agent.erase(key)


func sync_agent_footprint(level_root: Node, agent: Variant) -> void:
	if not is_instance_valid(agent):
		return
	var new_coords = LevelHelpersRef.get_agent_occupied_tiles(level_root, agent)
	var key = int(agent.get_instance_id())
	var old_coords: Array = []
	if _footprint_by_agent.has(key):
		var old_variant = _footprint_by_agent[key]
		if typeof(old_variant) == TYPE_ARRAY:
			old_coords = old_variant
	update_agent_footprint(agent, old_coords, new_coords)


func rebuild_occupancy_cache(level_root: Node, agents_root: Node) -> void:
	_occupancy_by_tile.clear()
	_footprint_by_agent.clear()
	if not is_instance_valid(agents_root):
		return
	for agent in agents_root.get_children():
		if not is_instance_valid(agent):
			continue
		if bool(agent.get("dead")):
			continue
		if str(agent.get("type")) == "cloud":
			continue
		var coords = LevelHelpersRef.get_agent_occupied_tiles(level_root, agent)
		register_agent_footprint(agent, coords)


func can_place_myco_on_tile(coord: Vector2i) -> bool:
	if not in_bounds(coord):
		return false
	var tile = get_tile(coord)
	if tile.is_empty():
		return false
	return int(tile.get("stage", STAGE_DRY_COMPACTED)) >= STAGE_SEMI_HEALTHY


func register_residue(coord: Vector2i, biomass: float, lifetime_ticks: int = DEFAULT_RESIDUE_LIFETIME_TICKS, source_type: String = "") -> void:
	if not in_bounds(coord):
		return
	var safe_biomass = maxf(biomass, 0.0)
	var safe_ticks = maxi(lifetime_ticks, 1)
	if safe_biomass <= 0.0:
		return
	_residue_records.append({
		"tile_coord": coord,
		"biomass": safe_biomass,
		"ticks_remaining": safe_ticks,
		"source_type": source_type
	})


func get_tile_health_score(coord: Vector2i) -> float:
	if not in_bounds(coord):
		return 0.0
	var tile = get_tile(coord)
	if tile.is_empty():
		return 0.0
	return _compute_health_score(float(tile["moisture"]), float(tile["organic_matter"]), float(tile["compaction"]))


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


func is_tile_revealed(coord: Vector2i) -> bool:
	if not in_bounds(coord):
		return false
	if not _uses_story_fog():
		return true
	var idx = _index_for(coord)
	if idx < 0 or idx >= _revealed_tiles.size():
		return false
	return _revealed_tiles[idx] == 1


func is_world_pos_revealed(world_pos: Vector2) -> bool:
	var coord = world_to_tile(world_pos)
	return is_tile_revealed(coord)


func reveal_rect_permanent(rect: Rect2i, buffer_tiles: int = 0) -> void:
	if _permanent_revealed_tiles.size() != columns * rows:
		_initialize_reveal_data()
	var safe_buffer = maxi(buffer_tiles, 0)
	var min_x = rect.position.x - safe_buffer
	var min_y = rect.position.y - safe_buffer
	var max_x = rect.position.x + rect.size.x - 1 + safe_buffer
	var max_y = rect.position.y + rect.size.y - 1 + safe_buffer
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var coord = Vector2i(x, y)
			if not in_bounds(coord):
				continue
			var idx = _index_for(coord)
			if idx < 0 or idx >= _permanent_revealed_tiles.size():
				continue
			_permanent_revealed_tiles[idx] = 1
	_refresh_story_fog_map()


func clear_permanent_reveal() -> void:
	if _permanent_revealed_tiles.size() != columns * rows:
		_initialize_reveal_data()
	for idx in range(_permanent_revealed_tiles.size()):
		_permanent_revealed_tiles[idx] = 0
	_refresh_story_fog_map()


func reset_to_baseline() -> void:
	_residue_records.clear()
	if _permanent_revealed_tiles.size() != columns * rows:
		_initialize_reveal_data()
	for idx in range(_permanent_revealed_tiles.size()):
		_permanent_revealed_tiles[idx] = 0
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
	_refresh_story_fog_map()
	queue_redraw()
	baseline_reset.emit()
	_update_debug_label()


func set_drag_tile_hint(coord: Vector2i, available: bool, secondary_coord: Vector2i = Vector2i(-1, -1), show_secondary: bool = false) -> void:
	if not in_bounds(coord):
		clear_drag_tile_hint()
		return
	var secondary_visible = show_secondary and in_bounds(secondary_coord)
	var normalized_secondary = secondary_coord if secondary_visible else Vector2i(-1, -1)
	if _drag_hint_visible and _drag_hint_coord == coord and _drag_hint_available == available and _drag_hint_secondary_visible == secondary_visible and _drag_hint_secondary_coord == normalized_secondary and not _drag_hint_fading and _drag_hint_alpha >= 0.999:
		return
	_drag_hint_visible = true
	_drag_hint_coord = coord
	_drag_hint_secondary_visible = secondary_visible
	_drag_hint_secondary_coord = normalized_secondary
	_drag_hint_available = available
	_drag_hint_alpha = 1.0
	_drag_hint_fading = false
	_drag_hint_fade_elapsed = 0.0
	queue_redraw()


func flash_drag_tile_hint(coord: Vector2i, available: bool = false, secondary_coord: Vector2i = Vector2i(-1, -1), show_secondary: bool = false, fade_duration: float = 0.32) -> void:
	set_drag_tile_hint(coord, available, secondary_coord, show_secondary)
	_drag_hint_fading = true
	_drag_hint_fade_elapsed = 0.0
	_drag_hint_fade_duration = maxf(fade_duration, 0.05)
	_drag_hint_alpha = 1.0
	queue_redraw()


func clear_drag_tile_hint() -> void:
	if not _drag_hint_visible:
		return
	_drag_hint_visible = false
	_drag_hint_coord = Vector2i(-1, -1)
	_drag_hint_secondary_visible = false
	_drag_hint_secondary_coord = Vector2i(-1, -1)
	_drag_hint_fading = false
	_drag_hint_fade_elapsed = 0.0
	_drag_hint_alpha = 1.0
	queue_redraw()


func _draw_drag_hint_tile(coord: Vector2i, hint_color: Color, alpha_scale: float) -> void:
	if not in_bounds(coord):
		return
	var hint_rect = Rect2(Vector2(coord.x * tile_size, coord.y * tile_size), Vector2(tile_size, tile_size))
	draw_rect(hint_rect, Color(hint_color, 0.16 * alpha_scale), true)
	draw_rect(hint_rect, Color(hint_color, hint_color.a * alpha_scale), false, 3.0, true)


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
		var hint_color = drag_hint_available_color if _drag_hint_available else drag_hint_blocked_color
		var alpha_scale = clampf(_drag_hint_alpha, 0.0, 1.0)
		_draw_drag_hint_tile(_drag_hint_coord, hint_color, alpha_scale)
		if _drag_hint_secondary_visible:
			_draw_drag_hint_tile(_drag_hint_secondary_coord, hint_color, alpha_scale)
	_draw_story_fog_overlay()
	if debug_overlay_enabled:
		draw_rect(Rect2(Vector2.ZERO, get_world_rect().size), Color(1, 1, 1, 0.9), false, 3.0, true)


func _clear_selection_for_camera_move() -> void:
	var level_root = get_parent()
	if not is_instance_valid(level_root):
		return
	var agents_root = level_root.get_node_or_null("Agents")
	LevelHelpersRef.clear_selection_and_bars(level_root, agents_root)
	LevelHelpersRef.suppress_hover_focus_until_pointer_moves(level_root)


func _is_mouse_wheel_button(button_index: MouseButton) -> bool:
	return (
		button_index == MOUSE_BUTTON_WHEEL_UP
		or button_index == MOUSE_BUTTON_WHEEL_DOWN
		or button_index == MOUSE_BUTTON_WHEEL_LEFT
		or button_index == MOUSE_BUTTON_WHEEL_RIGHT
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == HOTKEY_WORLD_DEBUG_OVERLAY:
			debug_overlay_enabled = not debug_overlay_enabled
			queue_redraw()
			_update_debug_label()
		elif event.keycode == HOTKEY_WORLD_RESET_BASELINE:
			reset_to_baseline()
		elif event.keycode == HOTKEY_WORLD_EDIT_TILES:
			debug_edit_enabled = not debug_edit_enabled
			_update_debug_label()
		elif event.keycode == HOTKEY_WORLD_TOGGLE_FOG:
			story_fog_enabled = not story_fog_enabled
			_refresh_story_fog_map()
			_update_debug_label()

	if _is_camera_pan_input_suppressed() and _is_camera_pan_pointer_event(event):
		_cancel_camera_pan_drag_state()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		if event.pressed and _is_mouse_wheel_button(event.button_index):
			_clear_selection_for_camera_move()
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
	if _drag_hint_visible and _drag_hint_fading:
		_drag_hint_fade_elapsed += maxf(delta, 0.0)
		var fade_progress = clampf(_drag_hint_fade_elapsed / maxf(_drag_hint_fade_duration, 0.05), 0.0, 1.0)
		var next_alpha = 1.0 - fade_progress
		if absf(next_alpha - _drag_hint_alpha) > 0.001:
			_drag_hint_alpha = next_alpha
			queue_redraw()
		if fade_progress >= 1.0:
			clear_drag_tile_hint()
			return
	var followed = _follow_active_agent(delta)
	if not followed and _should_keyboard_pan():
		var pan_dir = _get_camera_pan_vector()
		if pan_dir != Vector2.ZERO:
			camera.global_position += pan_dir.normalized() * camera_pan_speed * delta
			_clamp_camera()
	if debug_overlay_enabled or debug_edit_enabled:
		_update_debug_label()


func _start_soil_tick() -> void:
	if is_instance_valid(_soil_tick_timer):
		_soil_tick_timer.stop()
		_soil_tick_timer.queue_free()
	_soil_tick_timer = Timer.new()
	_soil_tick_timer.one_shot = false
	_soil_tick_timer.autostart = true
	_soil_tick_timer.wait_time = maxf(soil_tick_seconds, 0.1)
	_soil_tick_timer.timeout.connect(_on_soil_tick_timeout)
	add_child(_soil_tick_timer)


func _start_fog_tick() -> void:
	if is_instance_valid(_fog_tick_timer):
		_fog_tick_timer.stop()
		_fog_tick_timer.queue_free()
	_fog_tick_timer = Timer.new()
	_fog_tick_timer.one_shot = false
	_fog_tick_timer.autostart = true
	_fog_tick_timer.wait_time = STORY_FOG_TICK_SECONDS
	_fog_tick_timer.timeout.connect(_refresh_story_fog_map)
	add_child(_fog_tick_timer)
	_refresh_story_fog_map()


func _uses_story_fog() -> bool:
	return str(Global.mode) == "story" and story_fog_enabled


func _initialize_reveal_data() -> void:
	var tile_count = maxi(columns * rows, 0)
	_revealed_tiles.resize(tile_count)
	_permanent_revealed_tiles.resize(tile_count)
	for idx in range(tile_count):
		_revealed_tiles[idx] = 0
		_permanent_revealed_tiles[idx] = 0


func _refresh_story_fog_map() -> void:
	if _revealed_tiles.size() != columns * rows or _permanent_revealed_tiles.size() != columns * rows:
		_initialize_reveal_data()
	if not _uses_story_fog():
		for idx in range(_revealed_tiles.size()):
			_revealed_tiles[idx] = 1
		queue_redraw()
		return

	for idx in range(_revealed_tiles.size()):
		_revealed_tiles[idx] = _permanent_revealed_tiles[idx]
	var agents_root = _get_agents_root()
	if is_instance_valid(agents_root):
		for agent in agents_root.get_children():
			if not is_instance_valid(agent):
				continue
			if bool(agent.get("dead")):
				continue
			if str(agent.get("type")) != "myco":
				continue
			var occupied_tiles = _get_agent_occupied_tiles_for_soil(agent)
			var buddy_radius = float(agent.get("buddy_radius"))
			if buddy_radius <= 0.0:
				buddy_radius = tile_size
			var reveal_radius_tiles = int(ceil(maxf(buddy_radius, tile_size) / maxf(tile_size, 1.0))) + 4
			reveal_radius_tiles = maxi(reveal_radius_tiles, SOIL_INFLUENCE_RADIUS + 1)
			for coord in occupied_tiles:
				_reveal_coord_radius(Vector2i(coord), reveal_radius_tiles)
	queue_redraw()


func _is_story_hidden_village_tile(coord: Vector2i) -> bool:
	if str(Global.mode) != "story":
		return false
	if bool(Global.village_revealed):
		return false
	return STORY_HIDDEN_VILLAGE_RECT.has_point(coord)


func _reveal_coord_radius(center: Vector2i, radius_tiles: int) -> void:
	for dy in range(-radius_tiles, radius_tiles + 1):
		for dx in range(-radius_tiles, radius_tiles + 1):
			if maxi(abs(dx), abs(dy)) > radius_tiles:
				continue
			var coord = center + Vector2i(dx, dy)
			if not in_bounds(coord):
				continue
			if _is_story_hidden_village_tile(coord):
				continue
			var idx = _index_for(coord)
			if idx >= 0 and idx < _revealed_tiles.size():
				_revealed_tiles[idx] = 1


func _draw_story_fog_overlay() -> void:
	if not _uses_story_fog():
		return
	for y in range(rows):
		for x in range(columns):
			var idx = _index_for(Vector2i(x, y))
			if idx < 0 or idx >= _revealed_tiles.size():
				continue
			if _revealed_tiles[idx] == 1:
				continue
			var rect = Rect2(Vector2(x * tile_size, y * tile_size), Vector2(tile_size, tile_size))
			draw_rect(rect, STORY_FOG_COLOR, true)


func _on_soil_tick_timeout() -> void:
	var tick_start_us = Time.get_ticks_usec()
	var residue_by_tile = _consume_residue_tick()
	var residue_influence: Dictionary = {}
	for coord_variant in residue_by_tile.keys():
		var coord = Vector2i(coord_variant)
		var biomass = float(residue_by_tile[coord_variant])
		_add_radial_influence(residue_influence, coord, biomass, SOIL_INFLUENCE_RADIUS)
	var influences = _collect_soil_influences()
	var myco_influence: Dictionary = influences["myco_influence"]
	var live_plants: Dictionary = influences["live_plants"]
	var stage_changes: Dictionary = {}
	var touched_tiles := 0
	var unsupported_decay_factor = maxf(SOIL_UNSUPPORTED_DECAY_MULTIPLIER - 1.0, 0.0)

	for y in range(rows):
		for x in range(columns):
			touched_tiles += 1
			var coord = Vector2i(x, y)
			var idx = _index_for(coord)
			var tile: Dictionary = _tiles[idx]

			var moisture = float(tile["moisture"]) + SOIL_BASE_MOISTURE_DELTA
			var compaction = float(tile["compaction"]) + SOIL_BASE_COMPACTION_DELTA
			var organic_matter = float(tile["organic_matter"]) + SOIL_BASE_ORGANIC_DELTA

			var myco_strength = minf(float(myco_influence.get(coord, 0.0)), 2.0)
			if myco_strength > 0.0:
				moisture += SOIL_MYCO_CORE_MOISTURE_DELTA * myco_strength
				compaction += SOIL_MYCO_CORE_COMPACTION_DELTA * myco_strength

			if live_plants.has(coord):
				moisture += SOIL_LIVE_PLANT_MOISTURE_DELTA
				organic_matter += SOIL_LIVE_PLANT_ORGANIC_DELTA

			var residue_strength = minf(float(residue_influence.get(coord, 0.0)), 3.0)
			if residue_strength > 0.0:
				moisture += SOIL_RESIDUE_MOISTURE_DELTA * residue_strength
				organic_matter += SOIL_RESIDUE_ORGANIC_DELTA * residue_strength

			var unsupported = myco_strength <= 0.0 and residue_strength <= 0.0
			if unsupported and unsupported_decay_factor > 0.0:
				moisture += SOIL_BASE_MOISTURE_DELTA * unsupported_decay_factor
				compaction += SOIL_BASE_COMPACTION_DELTA * unsupported_decay_factor
				organic_matter += SOIL_BASE_ORGANIC_DELTA * unsupported_decay_factor

			moisture = _clamp01(moisture)
			compaction = _clamp01(compaction)
			organic_matter = _clamp01(organic_matter)

			tile["moisture"] = moisture
			tile["compaction"] = compaction
			tile["organic_matter"] = organic_matter
			_tiles[idx] = tile

			var old_stage = int(tile["stage"])
			var new_stage = _stage_from_score(_compute_health_score(moisture, organic_matter, compaction))
			if new_stage != old_stage:
				if not stage_changes.has(new_stage):
					stage_changes[new_stage] = []
				stage_changes[new_stage].append(coord)

	_apply_stage_changes(stage_changes)
	Global.perf_set_soil_tiles_touched(touched_tiles)
	var tick_elapsed_ms = float(Time.get_ticks_usec() - tick_start_us) / 1000.0
	Global.perf_set_soil_tick_ms(tick_elapsed_ms)


func _consume_residue_tick() -> Dictionary:
	var per_tile: Dictionary = {}
	if _residue_records.is_empty():
		return per_tile

	var survivors: Array = []
	for record_variant in _residue_records:
		if typeof(record_variant) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = record_variant
		var coord = Vector2i(record.get("tile_coord", Vector2i(-1, -1)))
		var biomass = maxf(float(record.get("biomass", 0.0)), 0.0)
		var ticks_remaining = int(record.get("ticks_remaining", 0))
		if ticks_remaining <= 0 or biomass <= 0.0:
			continue
		if in_bounds(coord):
			per_tile[coord] = float(per_tile.get(coord, 0.0)) + biomass

		ticks_remaining -= 1
		if ticks_remaining > 0:
			record["ticks_remaining"] = ticks_remaining
			survivors.append(record)

	_residue_records = survivors
	return per_tile


func _collect_soil_influences() -> Dictionary:
	var myco_influence: Dictionary = {}
	var live_plants: Dictionary = {}
	var agents_root = _get_agents_root()
	if not is_instance_valid(agents_root):
		return {
			"myco_influence": myco_influence,
			"live_plants": live_plants
		}

	for agent in agents_root.get_children():
		if not _is_live_agent_for_soil(agent):
			continue
		var agent_type = str(agent.get("type"))
		var occupied_tiles = _get_agent_occupied_tiles_for_soil(agent)
		if occupied_tiles.is_empty():
			continue
		if agent_type == "myco":
			for coord in occupied_tiles:
				_add_radial_influence(myco_influence, coord, 1.0, SOIL_INFLUENCE_RADIUS)
		elif agent_type == "bean" or agent_type == "squash" or agent_type == "maize" or agent_type == "tree":
			for coord in occupied_tiles:
				live_plants[coord] = true

	return {
		"myco_influence": myco_influence,
		"live_plants": live_plants
	}


func _get_agents_root() -> Node:
	return get_node_or_null("../Agents")


func _is_live_agent_for_soil(agent: Node) -> bool:
	if not is_instance_valid(agent):
		return false
	if bool(agent.get("dead")):
		return false
	if str(agent.get("type")) == "cloud":
		return false
	# Village runtime actors (people, village baskets, bank) must never drive soil updates.
	if bool(agent.get_meta("story_village_actor", false)):
		return false
	return true


func _get_agent_occupied_tiles_for_soil(agent: Node) -> Array:
	var agent_type = str(agent.get("type"))
	if agent_type == "tree":
		return _get_tree_occupied_tiles_for_soil(agent)
	var coord = world_to_tile(agent.global_position)
	if not in_bounds(coord):
		return []
	return [coord]


func _get_tree_occupied_tiles_for_soil(agent: Node) -> Array:
	if not bool(Global.social_mode):
		var base_coord = world_to_tile(agent.global_position)
		if not in_bounds(base_coord):
			return []
		var covered: Array = [base_coord]
		var above_coord = base_coord + Vector2i(0, -1)
		if in_bounds(above_coord):
			covered.append(above_coord)
		return covered

	if not agent.has_node("Sprite2D"):
		var fallback_coord = world_to_tile(agent.global_position)
		if in_bounds(fallback_coord):
			return [fallback_coord]
		return []
	var sprite = agent.get_node("Sprite2D")
	if not (sprite is Node2D and sprite.has_method("get_rect")):
		var fallback_coord = world_to_tile(agent.global_position)
		if in_bounds(fallback_coord):
			return [fallback_coord]
		return []
	var rect: Rect2 = sprite.get_rect()
	var scale = sprite.scale
	var scaled_pos = Vector2(rect.position.x * scale.x, rect.position.y * scale.y)
	var scaled_size = Vector2(rect.size.x * scale.x, rect.size.y * scale.y)
	var min_local = Vector2(
		minf(scaled_pos.x, scaled_pos.x + scaled_size.x),
		minf(scaled_pos.y, scaled_pos.y + scaled_size.y)
	)
	var max_local = Vector2(
		maxf(scaled_pos.x, scaled_pos.x + scaled_size.x),
		maxf(scaled_pos.y, scaled_pos.y + scaled_size.y)
	)
	var bounds = Rect2(agent.global_position + min_local, max_local - min_local)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		var center_coord = world_to_tile(agent.global_position)
		if in_bounds(center_coord):
			return [center_coord]
		return []

	var world_min = bounds.position
	var world_max = bounds.position + bounds.size - Vector2(0.001, 0.001)
	var min_coord = world_to_tile(world_min)
	var max_coord = world_to_tile(world_max)
	var covered: Array = []
	for y in range(min_coord.y, max_coord.y + 1):
		for x in range(min_coord.x, max_coord.x + 1):
			var coord = Vector2i(x, y)
			if in_bounds(coord):
				covered.append(coord)
	return covered


func _compute_health_score(moisture: float, organic_matter: float, compaction: float) -> float:
	return (0.45 * moisture) + (0.35 * organic_matter) + (0.20 * (1.0 - compaction))


func _stage_from_score(score: float) -> int:
	if score < SOIL_SCORE_DRY_MAX:
		return STAGE_DRY_COMPACTED
	if score < SOIL_SCORE_RECOVERING_MAX:
		return STAGE_RECOVERING
	if score < SOIL_SCORE_SEMI_HEALTHY_MAX:
		return STAGE_SEMI_HEALTHY
	return STAGE_HEALTHY


func _apply_stage_changes(stage_changes: Dictionary) -> void:
	if stage_changes.is_empty():
		return
	var changed = false
	for stage_variant in stage_changes.keys():
		var stage = int(stage_variant)
		var coords: Array = stage_changes[stage_variant]
		for coord_variant in coords:
			var coord = Vector2i(coord_variant)
			if not in_bounds(coord):
				continue
			var idx = _index_for(coord)
			var tile: Dictionary = _tiles[idx]
			if int(tile["stage"]) == stage:
				continue
			tile["stage"] = stage
			_tiles[idx] = tile
			tile_stage_changed.emit(coord, stage)
			changed = true
	if changed:
		queue_redraw()
		_update_debug_label()


func _clamp01(value: float) -> float:
	return clampf(value, 0.0, 1.0)


func _insert_tile_occupant(coord: Vector2i, agent: Node) -> void:
	var occupants_variant = _occupancy_by_tile.get(coord, [])
	var occupants: Array = occupants_variant if typeof(occupants_variant) == TYPE_ARRAY else []
	if occupants.has(agent):
		_occupancy_by_tile[coord] = occupants
		return
	occupants.append(agent)
	_occupancy_by_tile[coord] = occupants


func _remove_tile_occupant(coord: Vector2i, agent: Node) -> void:
	if not _occupancy_by_tile.has(coord):
		return
	var occupants_variant = _occupancy_by_tile.get(coord, [])
	if typeof(occupants_variant) != TYPE_ARRAY:
		_occupancy_by_tile.erase(coord)
		return
	var occupants: Array = occupants_variant
	occupants.erase(agent)
	if occupants.is_empty():
		_occupancy_by_tile.erase(coord)
	else:
		_occupancy_by_tile[coord] = occupants


func _falloff_weight(distance: int) -> float:
	if distance <= 0:
		return 1.0
	if distance == 1:
		return 0.8
	if distance == 2:
		return 0.6
	if distance == 3:
		return 0.4
	if distance == 4:
		return 0.25
	return 0.0


func _build_influence_kernel(radius: int) -> void:
	_influence_kernel.clear()
	var capped_radius = maxi(radius, 0)
	for dy in range(-capped_radius, capped_radius + 1):
		for dx in range(-capped_radius, capped_radius + 1):
			var distance = maxi(abs(dx), abs(dy))
			if distance > capped_radius:
				continue
			var weight = _falloff_weight(distance)
			if weight <= 0.0:
				continue
			_influence_kernel.append({
				"offset": Vector2i(dx, dy),
				"weight": weight
			})


func _add_radial_influence(influence_map: Dictionary, origin: Vector2i, magnitude: float, radius: int = SOIL_INFLUENCE_RADIUS) -> void:
	if magnitude <= 0.0:
		return
	if radius != SOIL_INFLUENCE_RADIUS or _influence_kernel.is_empty():
		var capped_radius = maxi(radius, 0)
		for dy in range(-capped_radius, capped_radius + 1):
			for dx in range(-capped_radius, capped_radius + 1):
				var distance = maxi(abs(dx), abs(dy))
				if distance > capped_radius:
					continue
				var weight = _falloff_weight(distance)
				if weight <= 0.0:
					continue
				var coord = origin + Vector2i(dx, dy)
				if not in_bounds(coord):
					continue
				influence_map[coord] = float(influence_map.get(coord, 0.0)) + (magnitude * weight)
		return
	for entry_variant in _influence_kernel:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		var offset = Vector2i(entry.get("offset", Vector2i.ZERO))
		var weight = float(entry.get("weight", 0.0))
		if weight <= 0.0:
			continue
		var coord = origin + offset
		if not in_bounds(coord):
			continue
		influence_map[coord] = float(influence_map.get(coord, 0.0)) + (magnitude * weight)


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
	if _is_test_baseline_context():
		_build_test_baseline_pattern()
	else:
		_build_gameplay_baseline_pattern()


func _is_test_baseline_context() -> bool:
	return mode_id == "test" or scenario_id == "test"


func _build_test_baseline_pattern() -> void:
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


func _build_gameplay_baseline_pattern() -> void:
	var center = _get_gameplay_baseline_center()
	for y in range(rows):
		for x in range(columns):
			var coord_vec = Vector2(float(x), float(y))
			var dist = center.distance_to(coord_vec)
			var stage = STAGE_DRY_COMPACTED
			if dist <= 2.0:
				stage = STAGE_SEMI_HEALTHY
			elif dist <= 4.0:
				stage = STAGE_RECOVERING
			_baseline_stage[_index_for(Vector2i(x, y))] = stage


func _get_gameplay_baseline_center() -> Vector2:
	var center = Vector2((columns - 1) * 0.5, (rows - 1) * 0.5)
	if str(Global.mode) == "story":
		var story_x = clampi(STORY_START_TILE.x, 0, max(columns - 1, 0))
		var story_y = clampi(STORY_START_TILE.y, 0, max(rows - 1, 0))
		return Vector2(float(story_x), float(story_y))
	if Global.has_method("is_challenge_dual_village_mode") and bool(Global.is_challenge_dual_village_mode()):
		var start_x = floori(columns * 0.5) - CHALLENGE_LAYOUT_CENTER_OFFSET_FROM_START_X
		start_x = clampi(start_x, 0, max(columns - 1, 0))
		var start_y = clampi(STORY_START_TILE.y, 0, max(rows - 1, 0))
		return Vector2(float(start_x), float(start_y))
	return center


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
	camera.position_smoothing_speed = DEFAULT_CAMERA_SMOOTHING_SPEED
	camera.global_position = get_world_center()
	_clamp_camera()


func set_camera_smoothing_speed(speed: float) -> void:
	if not is_instance_valid(camera):
		return
	camera.position_smoothing_speed = maxf(speed, 0.1)


func reset_camera_smoothing_speed() -> void:
	set_camera_smoothing_speed(DEFAULT_CAMERA_SMOOTHING_SPEED)


func set_camera_world_center(world_pos: Vector2, immediate: bool = false) -> void:
	if not is_instance_valid(camera):
		return
	camera.global_position = world_pos
	_clamp_camera()
	if immediate:
		camera.reset_smoothing()


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
	if delta.length_squared() > 0.001:
		_clear_selection_for_camera_move()
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
	if _is_camera_pan_input_suppressed():
		return
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


func suppress_camera_pan_input(duration_sec: float = 0.30) -> void:
	_camera_pan_suppressed_until_msec = maxi(_camera_pan_suppressed_until_msec, Time.get_ticks_msec() + int(duration_sec * 1000.0))
	_cancel_camera_pan_drag_state()


func _cancel_camera_pan_drag_state() -> void:
	_desktop_dragging = false
	_desktop_drag_button = MOUSE_BUTTON_NONE
	_touch_drag_id = -1


func _is_camera_pan_input_suppressed() -> bool:
	return Time.get_ticks_msec() < _camera_pan_suppressed_until_msec


func _is_camera_pan_pointer_event(event: InputEvent) -> bool:
	return event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventPanGesture


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
		str("story_fog_enabled=", story_fog_enabled),
		str("edit=", debug_edit_enabled, "  overlay=", debug_overlay_enabled),
		"Z overlay | X reset | C edit | V fog"
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
