extends Agent

var is_trading = false
var is_raining = true


func logistics():
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
	if(prod_res[0] != null):
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
