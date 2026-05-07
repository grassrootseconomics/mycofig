extends Control
class_name MiniMapPanel

signal camera_pan_requested(world_pos: Vector2)

const LevelHelpersRef = preload("res://scenes/level_helpers.gd")
const BG_COLOR := Color(0.04, 0.08, 0.12, 0.92)
const BORDER_COLOR := Color(0.80, 0.88, 0.95, 0.92)
const CAMERA_COLOR := Color(1.0, 1.0, 1.0, 0.88)
const VILLAGE_MARKER_COLOR := Color(1.0, 0.95, 0.35, 0.95)
const VILLAGE_MARKER_TEXT_SIZE := 11
const VILLAGE_MARKER_TEXT_STORY_MULTIPLIER := 2.0

var _level_root: Node = null
var _world_node: Node = null
var _agents_root: Node = null
var _dragging := false
var _touch_drag_id := -1
var _input_enabled := true
var _input_suppressed_until_msec := 0
var _village_marker_world := Vector2.ZERO
var _village_marker_visible := false
var _redraw_elapsed := 0.0
var _redraw_requested := true
var _last_camera_center := Vector2.INF
var _last_camera_size := Vector2.ZERO
var _last_panel_size := Vector2.ZERO
var _last_world_rect := Rect2(Vector2.ZERO, Vector2.ZERO)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func configure(level_root: Node, world_node: Node, agents_root: Node) -> void:
	_level_root = level_root
	_world_node = world_node
	_agents_root = agents_root
	_request_redraw()


func set_village_marker(world_pos: Vector2, visible: bool) -> void:
	if _village_marker_world == world_pos and _village_marker_visible == visible:
		return
	_village_marker_world = world_pos
	_village_marker_visible = visible
	_request_redraw()


func get_village_marker_screen_position() -> Dictionary:
	if not _village_marker_visible:
		return {
			"ok": false,
			"pos": Vector2.ZERO
		}
	var marker = _world_to_map(_village_marker_world)
	if marker == Vector2.INF:
		return {
			"ok": false,
			"pos": Vector2.ZERO
		}
	return {
		"ok": true,
		"pos": get_global_rect().position + marker + Vector2(0, -8)
	}


func set_input_enabled(enabled: bool) -> void:
	if _input_enabled == enabled:
		return
	_input_enabled = enabled
	if not _input_enabled:
		_cancel_drag_state()
	_request_redraw()


func suppress_input(duration_sec: float = 0.25) -> void:
	_input_suppressed_until_msec = maxi(_input_suppressed_until_msec, Time.get_ticks_msec() + int(duration_sec * 1000.0))
	_cancel_drag_state()


func _cancel_drag_state() -> void:
	_dragging = false
	_touch_drag_id = -1
	_request_redraw()


func _is_input_suppressed() -> bool:
	return Time.get_ticks_msec() < _input_suppressed_until_msec


func _clear_mobile_selection_for_pan() -> void:
	LevelHelpersRef.clear_selection_and_bars(_level_root, _agents_root)
	LevelHelpersRef.suppress_hover_focus_until_pointer_moves(_level_root)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_request_redraw()


func _request_redraw() -> void:
	_redraw_requested = true


func _camera_or_world_changed() -> bool:
	var changed := false
	if _last_panel_size != size:
		_last_panel_size = size
		changed = true
	var world_rect = _get_world_rect()
	if _last_world_rect != world_rect:
		_last_world_rect = world_rect
		changed = true
	if is_instance_valid(_level_root):
		var viewport = _level_root.get_viewport()
		if viewport != null:
			var view_size = viewport.get_visible_rect().size
			if _last_camera_size != view_size:
				_last_camera_size = view_size
				changed = true
			var camera = viewport.get_camera_2d()
			if is_instance_valid(camera):
				var center = camera.get_screen_center_position()
				if _last_camera_center == Vector2.INF or _last_camera_center.distance_squared_to(center) > 0.01:
					_last_camera_center = center
					changed = true
	return changed


func _process(delta: float) -> void:
	_redraw_elapsed += maxf(delta, 0.0)
	if _camera_or_world_changed():
		_request_redraw()
	var interval = Global.get_minimap_interaction_redraw_interval() if _dragging else Global.get_minimap_idle_redraw_interval()
	if _redraw_requested or _redraw_elapsed >= maxf(interval, 0.016):
		_redraw_elapsed = 0.0
		_redraw_requested = false
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not _input_enabled or _is_input_suppressed():
		accept_event()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_drag_id != -1 and event.index != _touch_drag_id:
				return
			_touch_drag_id = event.index
			_dragging = true
			_request_redraw()
			_clear_mobile_selection_for_pan()
			_emit_pan_for_local(event.position)
		else:
			if event.index != _touch_drag_id:
				return
			_touch_drag_id = -1
			_dragging = false
			_request_redraw()
		return
	if event is InputEventScreenDrag:
		if event.index != _touch_drag_id:
			return
		_dragging = true
		_request_redraw()
		_emit_pan_for_local(event.position)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Global.is_mobile_platform:
			return
		if event.pressed:
			_dragging = true
			_request_redraw()
			_clear_mobile_selection_for_pan()
			_emit_pan_for_local(event.position)
		else:
			_dragging = false
			_request_redraw()
	elif event is InputEventMouseMotion and _dragging:
		if Global.is_mobile_platform:
			return
		_request_redraw()
		_emit_pan_for_local(event.position)


func _emit_pan_for_local(local_pos: Vector2) -> void:
	var world_pos = _map_to_world(local_pos)
	if world_pos == Vector2.INF:
		return
	_request_redraw()
	emit_signal("camera_pan_requested", world_pos)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR, true)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, 1.5, true)
	_draw_agents()
	_draw_camera_rect()
	_draw_village_marker()


func _draw_agents() -> void:
	if not is_instance_valid(_agents_root):
		return
	for agent in _agents_root.get_children():
		if not is_instance_valid(agent):
			continue
		if bool(agent.get("dead")):
			continue
		var agent_type = str(agent.get("type"))
		if agent_type == "cloud":
			continue
		var dot_color = _color_for_agent_type(agent_type)
		var local_pos = _world_to_map(agent.global_position)
		if local_pos == Vector2.INF:
			continue
		draw_circle(local_pos, 2.4, dot_color)


func _draw_camera_rect() -> void:
	if not is_instance_valid(_level_root):
		return
	var viewport = _level_root.get_viewport()
	if viewport == null:
		return
	var camera = viewport.get_camera_2d()
	if not is_instance_valid(camera):
		return
	var view_size = viewport.get_visible_rect().size
	var cam_world = Rect2(camera.get_screen_center_position() - view_size * 0.5, view_size)
	var p0 = _world_to_map(cam_world.position)
	var p1 = _world_to_map(cam_world.position + cam_world.size)
	if p0 == Vector2.INF or p1 == Vector2.INF:
		return
	var rect = Rect2(p0, p1 - p0).abs()
	draw_rect(rect, CAMERA_COLOR, false, 1.6, true)


func _draw_village_marker() -> void:
	if not _village_marker_visible:
		return
	var marker = _world_to_map(_village_marker_world)
	if marker == Vector2.INF:
		return
	draw_circle(marker, 5.5, Color(VILLAGE_MARKER_COLOR, 0.22))
	draw_circle(marker, 2.2, VILLAGE_MARKER_COLOR)
	var font = ThemeDB.fallback_font
	if font != null:
		var text_scale = VILLAGE_MARKER_TEXT_STORY_MULTIPLIER if str(Global.mode) == "story" else 1.0
		var text_size = int(round(float(VILLAGE_MARKER_TEXT_SIZE) * text_scale))
		draw_string(font, marker + Vector2(-3.8 * text_scale, -6.2 * text_scale), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, VILLAGE_MARKER_COLOR)


func _color_for_agent_type(agent_type: String) -> Color:
	match agent_type:
		"myco":
			return Color(1.0, 1.0, 1.0, 0.95)
		"bean":
			return Color(0.32, 0.95, 0.45, 0.95)
		"squash":
			return Color(1.0, 0.62, 0.23, 0.95)
		"maize":
			return Color(1.0, 0.48, 0.78, 0.95)
		"tree":
			return Color(0.35, 0.62, 1.0, 0.95)
		"farmer":
			return Color(0.30, 0.93, 0.45, 0.95)
		"vendor":
			return Color(1.0, 0.62, 0.23, 0.95)
		"cook":
			return Color(1.0, 0.48, 0.78, 0.95)
		_:
			return Color(0.85, 0.85, 0.85, 0.9)


func _map_to_world(local_pos: Vector2) -> Vector2:
	var world_rect = _get_world_rect()
	if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
		return Vector2.INF
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.INF
	var clamped = Vector2(
		clampf(local_pos.x, 0.0, size.x),
		clampf(local_pos.y, 0.0, size.y)
	)
	var uv = Vector2(clamped.x / size.x, clamped.y / size.y)
	return world_rect.position + Vector2(uv.x * world_rect.size.x, uv.y * world_rect.size.y)


func _world_to_map(world_pos: Vector2) -> Vector2:
	var world_rect = _get_world_rect()
	if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
		return Vector2.INF
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.INF
	var rel = world_pos - world_rect.position
	var uv = Vector2(rel.x / world_rect.size.x, rel.y / world_rect.size.y)
	return Vector2(uv.x * size.x, uv.y * size.y)


func _get_world_rect() -> Rect2:
	if is_instance_valid(_world_node) and _world_node.has_method("get_world_rect"):
		return _world_node.get_world_rect()
	return Global.get_world_rect(self)
