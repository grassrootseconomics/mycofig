extends Area2D


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

const DROP_FADE_SECONDS := 0.12
const TRADE_REFERENCE_FPS := 60.0
const TRADE_AXIS_EPSILON := 0.001


func set_variables(path_dict) -> void:
	start_agent = path_dict.get("from_agent")
	end_agent = path_dict.get("to_agent")
	trade_path = path_dict.get("trade_path")
	amount = path_dict.get("trade_amount")
	asset = path_dict.get("trade_asset")
	self.modulate = Global.asset_colors[asset]
	#print(asset, " color: ", Global.asset_colors[asset])
	type = path_dict.get("trade_type")
	return_asset = path_dict.get("return_res")
	return_amt = path_dict.get("return_amt")
	position = start_agent.global_position
	#print("Created trade: ", start_agent, end_agent, trade_path)


func set_pool_owner(owner: Node) -> void:
	_pool_owner = owner


func activate_trade(path_dict: Dictionary) -> void:
	set_process(true)
	visible = true
	_dropping = false
	_drop_elapsed = 0.0
	modulate = Color.WHITE
	var shape = get_node_or_null("CollisionShape2D")
	if is_instance_valid(shape):
		shape.set_deferred("disabled", false)
	set_deferred("monitorable", true)
	set_deferred("monitoring", true)
	set_variables(path_dict)


func _despawn() -> void:
	if is_instance_valid(_pool_owner) and _pool_owner.has_method("_recycle_trade"):
		_pool_owner._recycle_trade(self)
	else:
		call_deferred("queue_free")


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

	var world_rect = Global.get_world_rect(self)
	if not world_rect.has_point(position):
		_despawn()
