extends Area2D

const LevelHelpersRef = preload("res://scenes/level_helpers.gd")

var start_agent = null
var end_agent = null
var trade_path = null

var direction = null

var asset = null
var amount = null
var type = null
var return_asset = null
var return_amt = null

var last_pos = null

var height = 0
var width = 0
var _dropping := false
var _drop_elapsed := 0.0
var _pool_owner: Node = null
var _visual_key := ""
var _count_label: Label = null
var created_at_msec := 0
var liquidity_cycle_trade := false
var liquidity_cycle_origin_id := 0
var village_ephemeral_trade_visual := false
var _village_trail_line: Line2D = null
var _village_trail_finalized := false

const DROP_FADE_SECONDS := 0.12
const TRADE_REFERENCE_FPS := 60.0
const TRADE_AXIS_EPSILON := 0.001
const AGGREGATE_LABEL_MIN_AMOUNT := 2
const AGGREGATE_LABEL_FONT_SIZE := 14
const AGGREGATE_LABEL_COLOR := Color(1.0, 1.0, 1.0, 0.95)
const VILLAGE_TRAIL_POINT_MIN_DISTANCE := 5.0


func set_variables(path_dict) -> void:
	_reset_village_trail_state()
	start_agent = path_dict.get("from_agent")
	end_agent = path_dict.get("to_agent")
	trade_path = path_dict.get("trade_path")
	amount = maxi(int(path_dict.get("trade_amount", 1)), 1)
	asset = path_dict.get("trade_asset")
	self.modulate = Global.asset_colors[asset]
	#print(asset, " color: ", Global.asset_colors[asset])
	type = path_dict.get("trade_type")
	return_asset = path_dict.get("return_res")
	return_amt = path_dict.get("return_amt")
	_visual_key = str(path_dict.get("visual_key", ""))
	created_at_msec = int(path_dict.get("created_at_msec", 0))
	if created_at_msec <= 0:
		created_at_msec = Time.get_ticks_msec()
	liquidity_cycle_trade = bool(path_dict.get("liquidity_cycle_trade", false))
	liquidity_cycle_origin_id = int(path_dict.get("liquidity_cycle_origin_id", 0))
	village_ephemeral_trade_visual = bool(path_dict.get("village_ephemeral_trade_visual", false))
	position = start_agent.global_position
	_refresh_trade_amount_visual()
	#print("Created trade: ", start_agent, end_agent, trade_path)


func set_pool_owner(owner: Node) -> void:
	_pool_owner = owner


func activate_trade(path_dict: Dictionary) -> void:
	set_process(true)
	visible = true
	_dropping = false
	_drop_elapsed = 0.0
	_reset_village_trail_state()
	modulate = Color.WHITE
	var shape = get_node_or_null("CollisionShape2D")
	if is_instance_valid(shape):
		shape.set_deferred("disabled", false)
	set_deferred("monitorable", true)
	set_deferred("monitoring", true)
	set_variables(path_dict)


func _reset_village_trail_state() -> void:
	village_ephemeral_trade_visual = false
	_village_trail_line = null
	_village_trail_finalized = false


func _get_village_lines_root() -> Node:
	return get_node_or_null("../../Lines")


func _ensure_village_trail_line() -> void:
	if not village_ephemeral_trade_visual or _village_trail_finalized:
		return
	if is_instance_valid(_village_trail_line):
		return
	var lines_root = _get_village_lines_root()
	if not is_instance_valid(lines_root):
		return
	_village_trail_line = LevelHelpersRef.create_village_trade_trail_line(lines_root)
	if is_instance_valid(_village_trail_line):
		_village_trail_line.add_point(global_position)


func _append_village_trail_point(point: Vector2) -> void:
	_ensure_village_trail_line()
	if not is_instance_valid(_village_trail_line):
		return
	var point_count = _village_trail_line.get_point_count()
	if point_count <= 0:
		_village_trail_line.add_point(point)
		return
	var last_point = _village_trail_line.get_point_position(point_count - 1)
	if last_point.distance_to(point) >= VILLAGE_TRAIL_POINT_MIN_DISTANCE:
		_village_trail_line.add_point(point)
	else:
		_village_trail_line.set_point_position(point_count - 1, point)


func _update_village_trade_trail() -> void:
	if village_ephemeral_trade_visual and not _village_trail_finalized:
		_append_village_trail_point(global_position)


func _finalize_village_trade_trail() -> void:
	if _village_trail_finalized:
		return
	_village_trail_finalized = true
	if not is_instance_valid(_village_trail_line):
		return
	_append_village_trail_point(global_position)
	var lines_root = _get_village_lines_root()
	if is_instance_valid(lines_root):
		LevelHelpersRef.start_village_trade_trail_fade(lines_root, _village_trail_line)
	else:
		_village_trail_line.queue_free()
	_village_trail_line = null


func _despawn() -> void:
	_finalize_village_trade_trail()
	if is_instance_valid(_pool_owner) and _pool_owner.has_method("_recycle_trade"):
		_pool_owner._recycle_trade(self)
	else:
		call_deferred("queue_free")


func finish_trade() -> void:
	_despawn()


func _is_endpoint_locked(agent: Variant) -> bool:
	if not is_instance_valid(agent):
		return false
	if bool(agent.get("dead")):
		return false
	if agent.has_method("is_trade_locked_by_user_move"):
		return bool(agent.call("is_trade_locked_by_user_move"))
	return false


func _begin_drop() -> void:
	if _dropping:
		return
	_dropping = true
	_drop_elapsed = 0.0
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var shape = get_node_or_null("CollisionShape2D")
	if is_instance_valid(shape):
		shape.set_deferred("disabled", true)


func _advance_drop(delta: float) -> void:
	if Global.get_effective_perf_tier() >= 2:
		_despawn()
		return
	_drop_elapsed += max(delta, 0.0)
	var t = clampf(_drop_elapsed / DROP_FADE_SECONDS, 0.0, 1.0)
	var faded = modulate
	faded.a = 1.0 - t
	modulate = faded
	if t >= 1.0:
		_despawn()


func get_trade_visual_key() -> String:
	return _visual_key


func get_trade_amount() -> int:
	return maxi(int(amount), 1)


func accumulate_trade_amount(extra_amount: int) -> bool:
	var safe_extra = maxi(extra_amount, 0)
	if safe_extra <= 0:
		return false
	amount = maxi(int(amount), 1) + safe_extra
	_refresh_trade_amount_visual()
	return true


func _refresh_trade_amount_visual() -> void:
	if int(amount) < AGGREGATE_LABEL_MIN_AMOUNT:
		if is_instance_valid(_count_label):
			_count_label.visible = false
		return
	_ensure_count_label()
	if not is_instance_valid(_count_label):
		return
	_count_label.visible = true
	_count_label.text = str("x", int(amount))


func _ensure_count_label() -> void:
	if is_instance_valid(_count_label):
		return
	_count_label = Label.new()
	_count_label.name = "CountLabel"
	_count_label.z_as_relative = false
	_count_label.z_index = 12
	_count_label.position = Vector2(7.0, -14.0)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.add_theme_font_size_override("font_size", AGGREGATE_LABEL_FONT_SIZE)
	_count_label.add_theme_color_override("font_color", AGGREGATE_LABEL_COLOR)
	add_child(_count_label)


func _get_axis_step(delta: float) -> float:
	var safe_delta = maxf(delta, 0.0)
	# Keep axis motion frame-rate independent while honoring the global speed cap.
	var normalized_axis_step = maxf(float(Global.move_rate) * TRADE_REFERENCE_FPS * safe_delta, 0.0)
	var movement_cap_step = maxf(float(Global.movement_speed) * safe_delta, 0.0)
	return minf(normalized_axis_step, movement_cap_step)


func _step_axis_toward(current: float, target: float, max_step: float) -> float:
	if max_step <= 0.0:
		return current
	var gap = target - current
	if absf(gap) <= max_step:
		return target
	return current + signf(gap) * max_step


func _process(delta: float) -> void:
	if not is_instance_valid(end_agent):
		_despawn()
		return
	if not is_instance_valid(start_agent):
		_despawn()
		return
	if bool(end_agent.get("dead")) or bool(start_agent.get("dead")):
		_despawn()
		return

	if _is_endpoint_locked(start_agent) or _is_endpoint_locked(end_agent):
		_begin_drop()
	if _dropping:
		_advance_drop(delta)
		return
	# Keep packet flow visible in every quality tier.
	visible = true
	_update_village_trade_trail()

	# Move in axis order (x then y), normalized to time to avoid FPS-dependent speed.
	var current_x = global_position.x
	var current_y = global_position.y
	var dest_x = end_agent.global_position.x
	var dest_y = end_agent.global_position.y
	var axis_step = _get_axis_step(delta)
	var new_pos = global_position
	if absf(dest_x - current_x) > TRADE_AXIS_EPSILON:
		new_pos.x = _step_axis_toward(current_x, dest_x, axis_step)
	elif absf(dest_y - current_y) > TRADE_AXIS_EPSILON:
		new_pos.y = _step_axis_toward(current_y, dest_y, axis_step)
	else:
		new_pos = end_agent.global_position

	position = new_pos
	_update_village_trade_trail()

	var world_rect = Global.get_world_rect(self)
	if not world_rect.has_point(position):
		_despawn()
