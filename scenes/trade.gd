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

const DROP_FADE_SECONDS := 0.12


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
	_drop_elapsed += max(delta, 0.0)
	var t = clampf(_drop_elapsed / DROP_FADE_SECONDS, 0.0, 1.0)
	var faded = modulate
	faded.a = 1.0 - t
	modulate = faded
	if t >= 1.0:
		call_deferred("queue_free")


func _process(delta: float) -> void:
	if not is_instance_valid(end_agent):
		call_deferred("queue_free")
		return
	if not is_instance_valid(start_agent):
		call_deferred("queue_free")
		return
	if bool(end_agent.get("dead")) or bool(start_agent.get("dead")):
		call_deferred("queue_free")
		return

	if _is_endpoint_locked(start_agent) or _is_endpoint_locked(end_agent):
		_begin_drop()
	if _dropping:
		_advance_drop(delta)
		return

	#print("moving trade")
	#move in x then y
	var current_x = global_position.x
	var current_y = global_position.y
	var dest_x = end_agent.global_position.x
	var dest_y = end_agent.global_position.y
	#if last_pos != null:
	#	if(last_pos.x == position.x and last_pos.y == position.y):
	#		print("####Tradestuck!")
	#last_pos = position
	#print("####Tradestuck!??")

	var new_pos = null

	if current_x < dest_x:
		if dest_x - current_x < Global.move_rate:
			new_pos = end_agent.global_position
		else:
			new_pos = Vector2(current_x + Global.move_rate, current_y)
	elif current_x > dest_x:
		if current_x - dest_x < Global.move_rate:
			new_pos = end_agent.global_position
		else:
			new_pos = Vector2(current_x - Global.move_rate, current_y)
	elif current_y < dest_y:
		if dest_y - current_y < Global.move_rate:
			new_pos = end_agent.global_position
		else:
			new_pos = Vector2(current_x, current_y + Global.move_rate)
	elif current_y > dest_y:
		if current_y - dest_y < Global.move_rate:
			new_pos = end_agent.global_position
		else:
			new_pos = Vector2(current_x, current_y - Global.move_rate)

	if new_pos == null:
		position = position.move_toward(end_agent.global_position, Global.movement_speed * delta)
	else:
		position = position.move_toward(new_pos, Global.movement_speed * delta)
		#new_pos#position.move_toward(Vector2(current_x+2,current_y),1)
	#direction = (end_agent.global_position - self.global_position).normalized()

	var world_rect = Global.get_world_rect(self)
	if not world_rect.has_point(position):
		call_deferred("queue_free")
