extends Agent

const STORY_FARMER_HARVEST_IDLE := "idle"
const STORY_FARMER_HARVEST_MOVING_TO_CROP := "moving_to_crop"
const STORY_FARMER_HARVEST_RETURNING_HOME := "returning_home"
const STORY_FARMER_HARVEST_SPEED_MULTIPLIER := 0.10
const STORY_FARMER_MOVE_TO_CROP_SECONDS := 0.32 / STORY_FARMER_HARVEST_SPEED_MULTIPLIER
const STORY_FARMER_RETURN_HOME_SECONDS := 0.30 / STORY_FARMER_HARVEST_SPEED_MULTIPLIER

var is_trading = false
var is_raining = true
var _story_farmer_harvest_state := STORY_FARMER_HARVEST_IDLE
var _story_farmer_harvest_target: Node = null
var _story_farmer_harvest_home_pos := Vector2.ZERO
var _story_farmer_harvest_home_set := false
var _story_farmer_harvest_move_tween: Tween = null


func _story_farmer_get_level_root() -> Node:
	return get_node_or_null("../..")


func _is_story_farmer_actor() -> bool:
	if not bool(get_meta("story_villager", false)):
		return false
	return str(type) == "farmer"


func _story_farmer_auto_harvest_enabled(level_root: Node) -> bool:
	if not _is_story_farmer_actor():
		return false
	if not is_instance_valid(level_root):
		return false
	if not level_root.has_method("story_farmer_auto_harvest_is_enabled"):
		return false
	return bool(level_root.call("story_farmer_auto_harvest_is_enabled", self))


func _story_farmer_stop_harvest_tween() -> void:
	if is_instance_valid(_story_farmer_harvest_move_tween):
		_story_farmer_harvest_move_tween.kill()
	_story_farmer_harvest_move_tween = null


func _story_farmer_release_target(level_root: Node) -> void:
	if not is_instance_valid(_story_farmer_harvest_target):
		_story_farmer_harvest_target = null
		return
	if is_instance_valid(level_root) and level_root.has_method("story_farmer_release_harvest_target"):
		level_root.call("story_farmer_release_harvest_target", self, _story_farmer_harvest_target)
	_story_farmer_harvest_target = null


func _story_farmer_reset_harvest_state(level_root: Node) -> void:
	_story_farmer_stop_harvest_tween()
	_story_farmer_release_target(level_root)
	_story_farmer_harvest_state = STORY_FARMER_HARVEST_IDLE


func _story_farmer_resolve_home_pos() -> Vector2:
	if _story_farmer_harvest_home_set:
		return _story_farmer_harvest_home_pos
	var meta_home = get_meta("story_home_world_pos", null)
	if typeof(meta_home) == TYPE_VECTOR2:
		_story_farmer_harvest_home_pos = meta_home
	else:
		_story_farmer_harvest_home_pos = global_position
	_story_farmer_harvest_home_set = true
	return _story_farmer_harvest_home_pos


func _story_farmer_begin_return_home() -> void:
	var home_pos = _story_farmer_resolve_home_pos()
	_story_farmer_harvest_state = STORY_FARMER_HARVEST_RETURNING_HOME
	_story_farmer_stop_harvest_tween()
	var tween = get_tree().create_tween()
	_story_farmer_harvest_move_tween = tween
	tween.tween_property(self, "global_position", home_pos, STORY_FARMER_RETURN_HOME_SECONDS)
	tween.finished.connect(_on_story_farmer_return_home_finished)


func _story_farmer_refresh_trade_network(level_root: Node) -> void:
	new_buddies = true
	draw_lines = true
	generate_buddies()
	if not is_instance_valid(level_root):
		return
	if level_root.has_method("mark_agent_moved"):
		level_root.call("mark_agent_moved", self, global_position, global_position)
	elif level_root.has_method("request_agent_dirty"):
		level_root.call("request_agent_dirty", self, true, true, false)


func _on_story_farmer_return_home_finished() -> void:
	_story_farmer_harvest_move_tween = null
	if _story_farmer_harvest_state != STORY_FARMER_HARVEST_RETURNING_HOME:
		return
	_story_farmer_harvest_state = STORY_FARMER_HARVEST_IDLE
	is_trading = false
	logistics_ready = true
	var level_root = _story_farmer_get_level_root()
	_story_farmer_refresh_trade_network(level_root)


func _on_story_farmer_arrived_at_crop() -> void:
	_story_farmer_harvest_move_tween = null
	if _story_farmer_harvest_state != STORY_FARMER_HARVEST_MOVING_TO_CROP:
		return
	var level_root = _story_farmer_get_level_root()
	if not is_instance_valid(_story_farmer_harvest_target):
		_story_farmer_reset_harvest_state(level_root)
		return
	if bool(_story_farmer_harvest_target.get("dead")):
		_story_farmer_reset_harvest_state(level_root)
		return
	if not _story_farmer_harvest_target.has_method("try_harvest_to_farmer"):
		_story_farmer_reset_harvest_state(level_root)
		return
	var harvested = bool(_story_farmer_harvest_target.call("try_harvest_to_farmer", self))
	if not harvested:
		_story_farmer_reset_harvest_state(level_root)
		return
	var harvest_type = str(_story_farmer_harvest_target.get("type"))
	if is_instance_valid(level_root) and level_root.has_method("story_farmer_on_harvest_success"):
		level_root.call("story_farmer_on_harvest_success", self, harvest_type)
	_story_farmer_release_target(level_root)
	_story_farmer_begin_return_home()


func _story_farmer_begin_harvest_trip(level_root: Node) -> bool:
	if not is_instance_valid(level_root):
		return false
	if not level_root.has_method("story_farmer_try_assign_harvest_target"):
		return false
	var crop_target = level_root.call("story_farmer_try_assign_harvest_target", self)
	if not is_instance_valid(crop_target):
		return false
	_story_farmer_resolve_home_pos()
	_story_farmer_harvest_target = crop_target
	_story_farmer_harvest_state = STORY_FARMER_HARVEST_MOVING_TO_CROP
	_story_farmer_stop_harvest_tween()
	var tween = get_tree().create_tween()
	_story_farmer_harvest_move_tween = tween
	tween.tween_property(self, "global_position", crop_target.global_position, STORY_FARMER_MOVE_TO_CROP_SECONDS)
	tween.finished.connect(_on_story_farmer_arrived_at_crop)
	return true


func _story_farmer_tick_auto_harvest(level_root: Node) -> bool:
	if not _is_story_farmer_actor():
		return false
	if _story_farmer_harvest_state == STORY_FARMER_HARVEST_MOVING_TO_CROP or _story_farmer_harvest_state == STORY_FARMER_HARVEST_RETURNING_HOME:
		logistics_ready = false
		return true
	if not _story_farmer_auto_harvest_enabled(level_root):
		if _story_farmer_harvest_state != STORY_FARMER_HARVEST_IDLE or is_instance_valid(_story_farmer_harvest_target):
			_story_farmer_reset_harvest_state(level_root)
		return false
	if not logistics_ready:
		return false
	if _story_farmer_begin_harvest_trip(level_root):
		logistics_ready = false
		return true
	return false


func logistics():
	var level_root = _story_farmer_get_level_root()
	if _story_farmer_tick_auto_harvest(level_root):
		return
	#wait for timer
	var excess_res = null
	var high_amt_excess = 0
	var needed_res = null
	var high_amt_needed = 0
	
	var debug_mode = false
	
	
	
	if logistics_ready and is_raining:# and is_trading == false:
		if( is_instance_valid(Global.active_agent)):
			if self.name == Global.active_agent.name:
				debug_mode = false#true
	
		if debug_mode:
			print("New Round in: ", name ,", ", assets, " needs: ", needs)	
		#determine if there are extra resources (offers)
		#find excess stock
		
		for res in assets:
			current_excess[res] = -999
			current_needs[res] = -999	
			
			if(res == "R"):
				if assets[res] > 0:
					current_excess[res] = assets[res]
					
			var c_excess = assets[res] - needs[res] 
			
			if assets[res] > needs[res]:
				#if c_excess > high_amt_excess:
				high_amt_excess = c_excess
				excess_res = res
				current_excess[res] = high_amt_excess
				
			if assets[res] < needs[res]:
				#print("res: ", res, " c_excess: ", c_excess, " high_amt_needed: ", high_amt_needed)
				#if -1 * c_excess > high_amt_needed:
				high_amt_needed = -1 * c_excess
				needed_res = res
				current_needs[res] = high_amt_needed
			
		
		var needed_keys: Array = current_needs.keys()
		var excess_keys: Array = current_excess.keys()
		# Sort keys in descending order of values.
		needed_keys.sort_custom(func(x: String, y: String) -> bool: return current_needs[x] > current_needs[y])
		excess_keys.sort_custom(func(x: String, y: String) -> bool: return current_excess[x] > current_excess[y])
		#print("actual needs: ", needs)
		if debug_mode:
			print("excess: ", current_excess  )
			print("excess sorted: ", excess_keys)
			print("needs: ", current_needs  )
			print("needs sorted: ", needed_keys)
			
		
		if excess_res != null and needed_res != null:
			#var children =  $"../../Agents".get_children()
			trade_buddies.shuffle()
			
			if debug_mode:
				print(" shuffle" )
			var need_itter = 0
			
			for child in trade_buddies: #children:
				if(is_instance_valid(child)):
					if logistics_ready and child.type == 'myco':
						if debug_mode:
							print(" child found" )
						for need in needed_keys:
							need_itter +=1
							var excess_iter = 0
							for excess in excess_keys:
								if(excess == need):
									continue
								excess_iter +=1
								if(current_needs[need] > 0 and current_excess[excess] >0 ):
									if debug_mode:
										print(need_itter, ". current need: ", need, " supply: ", assets[need] )
										print(excess_iter, ". current excess: ", excess, " supply: ",assets[excess] )
									if(logistics_ready):
										if child.assets.get(excess) != null and child.assets.get(need) != null:
											if debug_mode:
												print( " ... myco assets: " , child.assets)
											if(child.assets[excess] < child.needs[excess] *2):
												var path_dict = {
													"from_agent": self,
													"to_agent": child,
													"trade_path": [self,child],
													"trade_asset": excess,
													"trade_amount": 1, #amt_needed,
													"trade_type": "swap",
													"return_res": need,
													"return_amt": 1,#amt_needed
												}
												if debug_mode:
													print(" .... sending a trade along, ")
												#print(" .... sending a trade along, ", path_dict)
												assets[excess] -= 1#amt_needed
												bars[excess].value = assets[excess]
												#print(excess_res, " value: ", bars[excess_res].value)
												#bars[excess_res].update()
												emit_signal("trade",path_dict)
												logistics_ready = false
												is_trading = true
												break
												#trade.emit(path_dict)
												#send what is in excess. 
											
					
									#Attempt to push out what you have in abundance
							
		#determine what is needed (needs)
		
		#if they can s wap a resource for a needed resource do it 
		#     Send the resource to the myco (when it arrives the needed resource will come back)

		#Consume resources
		#These are combinations NPK together
		
		#Increase health
		
		#Decay unused resources
	
	if false:
	#if decay_ready:
		#print("decay", assets)
		decay_ready = false
		for res in assets:
			if assets[res] >= 1 and res != "R":
				assets[res] -=1
				bars[res].value = assets[res]
			if assets[res] >= 1 and res == "R":
				evaporate()
				#print(" decay: ", assets)
	
	if evaporate_ready:
		#print("decay", assets)
		evaporate_ready = false
		#evaporate()



func _on_area_entered(ztrade: Area2D) -> void:
	if ztrade.end_agent == self:
		assets[ztrade.asset]+=ztrade.amount
		is_trading = false
		if assets[ztrade.asset]> needs[ztrade.asset] *2:
			assets[ztrade.asset] = needs[ztrade.asset] *2
		else:
			Global.score+=ztrade.amount
			emit_signal("update_score")
		bars[ztrade.asset].value = assets[ztrade.asset]
		ztrade.call_deferred("queue_free")


func _on_growth_timer_timeout() -> void:
	#$GrowthTimer.set_wait_time(random.randf_range(1, 5))
	#production_ready = true
	#if production_ready:		
	#	production_ready = false
	var disable_story_farmer_production = bool(get_meta("story_disable_farmer_production", false))
	if not disable_story_farmer_production and prod_res.size() > 0 and prod_res[0] != null:
		for res in prod_res:
			assets[res]+=3
			if assets[res]> needs[res] *2:
				assets[res] = needs[res] *2
			bars[res].value = assets[res]
			
	#if there is 1 res in each asset - consume them all and grow in size
	#if any are missing shrink
	var all_in = true
	for res in assets:
		if res !=  "R":
			if assets[res] <= 0:
				all_in = false
			
	var newScale = $Sprite2D.scale
	#print(name, " assets: ", assets)
	if all_in == true:	
		if $Sprite2D.scale.x < max_scale and $Sprite2D.scale.y < max_scale:
			var candidate_scale = $Sprite2D.scale * (1 + scale_step_up)
			if _can_expand_to_scale(candidate_scale):
				newScale = candidate_scale
			
		var old_modulate = modulate
		var new_alpha = modulate.a+alpha_step_up
		if new_alpha > high_alpha:
			new_alpha = high_alpha
		var new_color = Color(old_modulate,new_alpha)
		self.modulate= new_color
		
		
		Global.score += 400
		emit_signal("update_score")
				
		
		
		#print(name, " ", $Sprite2D.scale)
		for res in assets:
			if(res != "R"):
				assets[res] -= 1
				bars[res].value = assets[res]
			#else:
			#	evaporate()
			
		
			
	else:
		#if $Sprite2D.scale.x > 0.5 and $Sprite2D.scale.y > 0.5:
			
			#newScale = $Sprite2D.scale * 0.95
			#print($Sprite2D.scale)
			
		var old_modulate = modulate
		var new_alpha = modulate.a-alpha_step_down
		if new_alpha < low_alpha:
			new_alpha = low_alpha
			
			if(Global.is_killing == true and self.killable == true):
				kill_it()
			
		var new_color = Color(old_modulate,new_alpha)
		self.modulate= new_color

	if newScale != $Sprite2D.scale:
		var tween = get_tree().create_tween()
		tween.tween_property($Sprite2D, "scale", newScale, 0.05)
		#tween.set_parallel(true)	
		
	if newScale.x >= max_scale and newScale.y >= max_scale and modulate.a >= 1:
		#print("increase score and twinkle")
		var sparkle = Global.sparkle_scene.instantiate()
		
		sparkle.z_as_relative = false
		sparkle.position = self.position
		sparkle.global_position = self.global_position
		#sparkle.z_index =-1
		$"../../Sparkles".add_child(sparkle)
		sparkle.start(0.75)
	
		if(Global.baby_mode and self.type != "tree"):
			if(Global.is_max_babies == true):
				if(current_babies < num_babies):
					have_babies()
			else:
				have_babies()


func _on_dry_timer_timeout() -> void:
	if(self.type == "tree"):
		var wait_for_rain = 0
		if(is_raining == true):
			wait_for_rain = random.randi_range(50, 100)
			is_raining = false
			var tween = get_tree().create_tween()
			tween.tween_property(sprite, "modulate:a", 0.2, 0.5)
			#tween.set_parallel(true)
			#$Sprite2D.modulate.a = 0.2
			
		else:
			wait_for_rain = random.randi_range(1, 50)
			is_raining = true
			var tween = get_tree().create_tween()
			tween.tween_property(sprite, "modulate:a", 1, 0.5)
			#tween.set_parallel(true)
			#$Sprite2D.modulate.a = 1
		$DryTimer.set_wait_time(wait_for_rain)


func _exit_tree() -> void:
	var level_root = _story_farmer_get_level_root()
	_story_farmer_reset_harvest_state(level_root)
	super._exit_tree()
