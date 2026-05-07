extends Agent

const ResourceEconomyRef = preload("res://scenes/resource_economy.gd")
const BASKET_MAX_SENDS_PER_LOGISTICS_TICK := 2

var trade_queue = []
func set_variables(a_dict) -> void:
	name = a_dict.get("name")
	type = a_dict.get("type")
	#prod_res = a_dict.get("prod_res")
	#assets[prod_res] = a_dict.get("start_res")
	position = a_dict.get("position")
	last_position = position
	
	sprite_texture = a_dict.get("texture")
	sprite = $Sprite2D
	
	sprite.z_index = 9
	
	buddy_radius = Global.social_buddy_radius
	#print("start radius: ", buddy_radius)
	$Sprite2D.texture = sprite_texture
	$GrowthTimer.wait_time = Global.growth_time
	$ActionTimer.wait_time = Global.get_village_action_time()
	setup_resource_bars(assets.keys())


# Search for things to trade with in a radius
func generate_buddies() -> void:
	num_connectors = 0
	var agents_root = get_node_or_null("../../Agents")
	trade_buddies = LevelHelpersRef.query_trade_hubs_near_agent(_get_level_root(), agents_root, self, num_buddies, false)

func logistics():
	var new_trade_queue = []
	for trade in trade_queue:
		var queued_asset = str(trade.get("trade_asset", ""))
		var queued_amount = int(trade.get("trade_amount", 0))
		if bool(trade.get("bank_reserve_protected", false)) and not _bank_trade_has_return_surplus(queued_asset, queued_amount):
			new_trade_queue.append(trade)
			continue
		if(assets[trade.trade_asset]>= trade.trade_amount):
			if _emit_trade_with_budget(trade):
				assets[trade.trade_asset]-=trade.trade_amount
				bars[trade.trade_asset].value = assets[trade.trade_asset]
			else:
				new_trade_queue.append(trade)
		else:
			new_trade_queue.append(trade)
	trade_queue = new_trade_queue
	pass
	var excess_res = null
	var high_amt_excess = 0
	var needed_res = null
	var high_amt_needed = 0
	
	var debug_mode = false
	
	var buddies_len = len(trade_buddies)
	
	if logistics_ready and buddies_len > 0:
		if( is_instance_valid(Global.active_agent)):
			if self.name == Global.active_agent.name:
				debug_mode = false #true
		
		if debug_mode:
			print("New Round in: ", name ,", ", assets, " needs: ", needs, "buddies: ", trade_buddies)	
			
		#determine if there are extra resources (offers)
		#find excess stock
		var balance: Dictionary = ResourceEconomyRef.analyze_balances(assets, needs, 0.0)
		current_excess = balance["current_excess"]
		current_needs = balance["current_needs"]
		excess_res = balance["excess_res"]
		needed_res = balance["needed_res"]
		high_amt_excess = balance["high_amt_excess"]
		high_amt_needed = balance["high_amt_needed"]
		var keys_c: Array = balance["needed_keys"]
		var keys_e: Array = balance["excess_keys"]
		#print("actual needs: ", needs)
		if debug_mode:
			print("excess: ", current_excess,  keys_e, " current_needs: ", current_needs, keys_c)
		
		if excess_res != null and needed_res != null:
			#var children =  $"../../Agents".get_children()
			trade_buddies.shuffle()
			
			if debug_mode:
				print(" shuffle" )
			var need_itter = 0
			var sent_count := 0
			for child in trade_buddies: #children:
				if sent_count >= BASKET_MAX_SENDS_PER_LOGISTICS_TICK:
					break
				if(is_instance_valid(child)):
					if child.type == 'myco' and child.name != self.name:
						if debug_mode:
							print(" child found: ", child.name )
						for excess in keys_e:
							if sent_count >= BASKET_MAX_SENDS_PER_LOGISTICS_TICK:
								break
							if(child.assets.get(excess) != null):
								if current_excess[excess] > 0 and assets[excess] > needs[excess] and child.assets[excess]<child.needs[excess]:
									var path_dict = {
										"from_agent": self,
										"to_agent": child,
										"trade_path": [self,child],
										"trade_asset": excess,
										"trade_amount": 1, #amt_needed,
										"trade_type": "send",
										"return_res": null,
										"return_amt": 1,#amt_needed
									}
									if debug_mode:
										print(" .... sending a trade along, ", path_dict)
									if _emit_trade_with_budget(path_dict):
										assets[excess] -= 1#amt_needed
										bars[excess].value = assets[excess]
										sent_count += 1
									#break
									#trade.emit(path_dict)
									#send what is in excess. 
			if sent_count > 0:
				logistics_ready = false
								

func draw_selected_box():
	LevelHelpersRef.draw_agent_selection_box(_get_level_root(), self)


		
func _physics_process(delta):
	#_draw()
	if is_dragging and draggable == true:
		var hit = false
		var pointer_world_pos = _get_drag_pointer_world_pos()
		var pointer_screen_pos = _get_drag_pointer_screen_pos()
		
		if $"../../UI/MarginContainer".get_global_rect().has_point(pointer_screen_pos):
			hit = true
		
		if hit==true:
			kill_it()
			#queue_free()
			return
		var t = min(1.0, delay * delta)
		var dragged_target = position.lerp(pointer_world_pos, t)
		position = _clamp_position_to_world(dragged_target)
		if is_instance_valid(bar_canvas) and bar_canvas.visible:
			_update_bar_positions()


func _input(event):
	if not draggable:
		return
	if event is InputEventMouseMotion:
		_set_drag_pointer_screen_pos(event.position)
		return
	if event is InputEventScreenDrag:
		if _active_touch_id != -1 and event.index == _active_touch_id:
			_set_drag_pointer_screen_pos(event.position)
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _active_touch_id != -1 and event.index != _active_touch_id:
				return
			var world_touch_pos = Global.screen_to_world(self, event.position)
			if _is_press_hit(world_touch_pos):
				_active_touch_id = event.index
				_on_pointer_press(event.position)
			else:
				_press_started_here = false
		else:
			if event.index != _active_touch_id:
				return
			_on_pointer_release(event.position)
			_active_touch_id = -1
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Global.is_mobile_platform:
			return
		if event.pressed:
			_on_pointer_press(event.position)
		else:
			_on_pointer_release(event.position)



func _calculate_swap_return_amount(trade: Area2D) -> int:
	var trade_asset = str(trade.asset)
	var return_asset = str(trade.return_asset)
	var trade_value = float(Global.values.get(trade_asset, 1))
	var return_value = float(Global.values.get(return_asset, 1))
	if return_value <= 0.0:
		return 0
	var return_amount = float(trade.return_amt) * trade_value / return_value
	if return_amount < 0.5:
		return 0
	if return_amount < 1.0:
		return 1
	return int(return_amount)


func _bank_trade_has_return_surplus(return_asset: String, return_amount: int) -> bool:
	if return_asset == "" or return_amount <= 0:
		return true
	if assets.get(return_asset) == null or needs.get(return_asset) == null:
		return false
	return float(assets[return_asset]) - float(needs[return_asset]) >= float(return_amount)


func _is_bank_reserve_protected_swap(trade: Area2D, return_amount: int) -> bool:
	if str(trade.type) != "swap":
		return false
	if return_amount <= 0:
		return false
	if str(trade.asset) != "R":
		return false
	if not is_instance_valid(trade.start_agent):
		return false
	if str(trade.start_agent.get("type")) != "bank":
		return false
	return true


func _on_area_entered(trade: Area2D) -> void:
	if trade.end_agent == self:
		#print("myself", body_entered)
		#remove the resource from the trade and give it to the end_agent
		#trade.start_agent.assets[trade.asset]-=trade.amount
		if assets.get(trade.asset) != null:
			var return_amount := 0
			var bank_reserve_protected := false
			if trade.type == "swap" and assets.get(trade.return_asset) != null:
				return_amount = _calculate_swap_return_amount(trade)
				bank_reserve_protected = _is_bank_reserve_protected_swap(trade, return_amount)
				if bank_reserve_protected and not _bank_trade_has_return_surplus(str(trade.return_asset), return_amount):
					if trade.has_method("finish_trade"):
						trade.call_deferred("finish_trade")
					else:
						trade.call_deferred("queue_free")
					return
			if(assets[trade.asset] < (needs[trade.asset]*2)):
				assets[trade.asset]+=trade.amount
				bars[trade.asset].value = assets[trade.asset]

			if trade.type == "swap":
				if(assets.get(trade.return_asset) != null):
					if return_amount > 0:
						var liquidity_origin_value = trade.get("liquidity_cycle_origin_id")
						var liquidity_origin_id := 0
						if liquidity_origin_value != null:
							liquidity_origin_id = int(liquidity_origin_value)
						var path_dict = {
							"from_agent": self,
							"to_agent": trade.start_agent,
							"trade_path": [self,trade.start_agent],
							"trade_asset": trade.return_asset,
							"trade_amount": return_amount,
							"trade_type": "send",
							"return_res": null,
							"return_amt": null,
							"liquidity_cycle_trade": bool(trade.get("liquidity_cycle_trade")),
							"liquidity_cycle_origin_id": liquidity_origin_id,
							"bank_reserve_protected": bank_reserve_protected
						}
						if bank_reserve_protected and not _bank_trade_has_return_surplus(str(trade.return_asset), return_amount):
							trade_queue.append(path_dict)
						elif(assets[trade.return_asset]>= return_amount):
							if _emit_trade_with_budget(path_dict):
								assets[trade.return_asset]-=return_amount
								bars[trade.return_asset].value = assets[trade.return_asset]
							else:
								trade_queue.append(path_dict)
						else: #add to queue
							trade_queue.append(path_dict)
				else:
					print("Error basket without return asset:", trade.return_asset, assets)
			if trade.has_method("finish_trade"):
				trade.call_deferred("finish_trade")
			else:
				trade.call_deferred("queue_free")
		else:
			print("Error basket without asset:", trade.asset, assets)
	#else:
	#	print("not myself", body_entered)
		#collision.emit(body)
	#trade.queue_free()
	#queue_free()


	#queue_free()

func kill_it():
	#new_alpha = low_alpha
	#self.queue_free()
	LevelHelpersRef.unregister_agent_occupancy(get_node_or_null("../.."), self)
	self.call_deferred("queue_free")
	self.dead = true
	if Global.active_agent != null:
		if is_instance_valid(Global.active_agent) and Global.active_agent.name == self.name:
			LevelHelpersRef.clear_focus_outline_if_owner(get_node_or_null("../.."), self)
			Global.active_agent = null
			Global.prevent_auto_select = true
			_refresh_all_agent_bar_visibility()
	
	trade_buddies = []
	new_buddies = true
	#var children =  $"../../Agents".get_children()
	#for child in children:
		#if child.type == 'myco': 
		
	#print(self.name, "  died! :( ", assets)
	for line in $"../../Lines".get_children():
		for my_line in my_lines:
			if(my_line == line):
				line.clear_points()	
				line.queue_free()

	my_lines = []
	if(draw_box):
		for box in $"../../Boxes".get_children():
			box.clear_points()	
			box.queue_free()
	
	
	var children =  $"../../Agents".get_children()
	var level_root = get_node_or_null("../..")
	var living = false
	for child in children:
		if is_instance_valid(level_root) and level_root.has_method("request_agent_dirty"):
			level_root.request_agent_dirty(child, true, true, false)
		else:
			child.draw_lines = true
			child.new_buddies = true
		
		
		if(child.dead == false and child.type != "cloud"):
			living = true

	if( living == false  and Global.mode != "tutorial"):
		get_tree().change_scene_to_file("res://scenes/game_over.tscn")
			

func _on_growth_timer_timeout() -> void:
	#concume nutrients
	var newScale = $Sprite2D.scale
	
	var all_in = true
	for res in assets:
		if assets[res] <= 0:
			all_in = false
	
		#print(name, " assets: ", assets)
	if all_in == true:	
				
			
		var old_modulate = $Sprite2D.modulate
		var new_alpha = $Sprite2D.modulate.a+alpha_step_up
		if new_alpha > high_alpha:
			new_alpha = high_alpha
		var new_color = Color(old_modulate,new_alpha)
		$Sprite2D.modulate= new_color
		
		
		#for res in assets:		
		#	if(assets[res] >0):
		#		assets[res] -=1
		#		bars[res].value = assets[res]

		#print(name, " ", $Sprite2D.scale)
			
		
			
	else:
		#if $Sprite2D.scale.x > 0.5 and $Sprite2D.scale.y > 0.5:
			
			#newScale = $Sprite2D.scale * 0.95
			#print($Sprite2D.scale)
		
			
		var old_modulate = $Sprite2D.modulate
		var new_alpha = $Sprite2D.modulate.a-alpha_step_down
		
		if new_alpha < low_alpha:
			new_alpha = low_alpha
		
		if false: #undead
		
			kill_it()	
	
		var new_color = Color(old_modulate,new_alpha)
		$Sprite2D.modulate= new_color

	"""
	if modulate.a >= 1:
		#print("increase score and twinkle")
		
		var sparkle = Global.sparkle_scene.instantiate()
		
		sparkle.z_as_relative = false
		sparkle.position = self.position
		sparkle.global_position = self.global_position
		#sparkle.z_index =-1
		$"../../Sparkles".add_child(sparkle)
		sparkle.start(0.75)
		
		
		Global.score += 200
		"""

	
func _on_action_timer_timeout() -> void:
	logistics_ready = true
