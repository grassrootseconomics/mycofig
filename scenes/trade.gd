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

# Called every frame. 'delta' is the elapsed time since the previous frame.

func set_variables(path_dict) -> void:
	start_agent = path_dict.get("from_agent")
	end_agent = path_dict.get("to_agent")
	trade_path = path_dict.get("trade_path")
	amount = path_dict.get("trade_amount")
	asset = path_dict.get("trade_asset")
	self.modulate= Global.asset_colors[asset]
	#print(asset, " color: ", Global.asset_colors[asset])
	type = path_dict.get("trade_type")
	return_asset = path_dict.get("return_res")
	return_amt = path_dict.get("return_amt")
	position = start_agent.global_position
	
	
	#print("Created trade: ", start_agent, end_agent, trade_path)

func _process(delta: float) -> void:
	if end_agent != null:
		#print("moving trade")
		#move in x then y
		if(end_agent.dead == true):
			self.call_deferred("queue_free")
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
			if dest_x - current_x < Global.move_rate :
				new_pos = end_agent.global_position
			else:
				new_pos = Vector2(current_x+Global.move_rate,current_y)	
		elif current_x > dest_x:
			if current_x - dest_x < Global.move_rate :
				new_pos = end_agent.global_position
			else:
				new_pos = Vector2(current_x-Global.move_rate,current_y)	
		elif current_y < dest_y:
			if dest_y - current_y < Global.move_rate :
				new_pos = end_agent.global_position
			else:
				new_pos = Vector2(current_x,current_y+Global.move_rate)	
		elif current_y > dest_y:
			if current_y - dest_y < Global.move_rate :
				new_pos = end_agent.global_position
			else:
				new_pos = Vector2(current_x,current_y-Global.move_rate)	
		
		if new_pos == null:
			position = position.move_toward(end_agent.global_position,Global.movement_speed * delta)
		else:	
			position = position.move_toward(new_pos,Global.movement_speed * delta)
			#new_pos#position.move_toward(Vector2(current_x+2,current_y),1)
		#direction = (end_agent.global_position - self.global_position).normalized()
	else:
		#print("missing target - clearnup!")
		self.call_deferred("queue_free")
		
	var height = get_viewport().get_visible_rect().size[1]
	var width = get_viewport().get_visible_rect().size[0]
	if position.y > height or position.y < 0 or position.x < 0 or position.x > width:
		self.call_deferred("queue_free")
