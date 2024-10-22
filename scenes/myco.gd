extends Agent


func set_variables(a_dict) -> void:

	var START_N = 5 #Nitrogen
	var START_P = 5 # Potassium
	var START_K = 5 #Phosphorus
	var START_R = 5 #Rain
	
	assets = { #list of assets - 
	#for each asset there is a balance, and stready state amount needed for growth
	"N": START_N,
	"P": START_P,				
	"K": START_K,
	"R": START_R
			}

	name = a_dict.get("name")
	type = a_dict.get("type")
	#prod_res = a_dict.get("prod_res")
	#assets[prod_res] = a_dict.get("start_res")
	position = a_dict.get("position")
	last_position = position
	sprite_texture = a_dict.get("texture")
	sprite = $Sprite2D
	sprite_myco_texture = load("res://graphics/rhizomorphic.png")
	sprite = $Sprite2D
	sprite_myco = $MycoSprite
	sprite_myco.scale *= min_scale
	$MycoSprite.modulate.a = 0.3
	sprite.z_index = 9
	$MycoSprite.z_index = -1
	buddy_radius = $MycoSprite.get_rect().size[0]/2*min_scale
	print("start radius: ", buddy_radius)
	$Sprite2D.texture = sprite_texture
	$GrowthTimer.wait_time = Global.growth_time
	$ActionTimer.wait_time = Global.action_time
	bars = { #list of needed assets with need level
		"N": $CanvasLayer/Nbar,
		"P": $CanvasLayer/Pbar,
		"K": $CanvasLayer/Kbar,
		"R": $CanvasLayer/Rbar
	}
	for bar in bars:
		bars[bar].max_value = int(needs[bar]*1.2)
		bars[bar].value = assets[bar]
		bars_offset[bar] = bars[bar].position
		bars[bar].position = (position + bars[bar].position)
		bars[bar].tint_progress = Global.asset_colors[bar]
		
	bar_canvas = $CanvasLayer
	
# Search for things to trade with in a radius
func generate_buddies() -> void:
	var children =  $"../../Agents".get_children()
	trade_buddies = []
	#print(self.name, " new buddies children: ", children)
	for child in children:
		if child.type == 'myco' and child.name != self.name:
			var dist = global_position.distance_to(child.global_position)
			if dist <= buddy_radius:
				if len(trade_buddies) < num_buddies:
					trade_buddies.append(child)
			#else:
				#print(self.name, " is too far from myco: ", dist)
	#print("final new buddies: ", trade_buddies)

	pass

func logistics():
	#wait for timer
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
		for res in assets:
				
				 
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
				else:
					current_needs[res] = 0
		
		var keys_c: Array = current_needs.keys()
		var keys_e: Array = current_excess.keys()
		# Sort keys in descending order of values.
		keys_c.sort_custom(func(x: String, y: String) -> bool: return current_needs[x] > current_needs[y])
		keys_e.sort_custom(func(x: String, y: String) -> bool: return current_excess[x] > current_excess[y])
		#print("actual needs: ", needs)
		if debug_mode:
			print("excess: ", current_excess,  keys_e, " current_needs: ", current_needs, keys_c)
		
		if excess_res != null and needed_res != null:
			#var children =  $"../../Agents".get_children()
			randomize()
			trade_buddies.shuffle()
			
			if debug_mode:
				print(" shuffle" )
			var need_itter = 0
			logistics_ready = false
			for child in trade_buddies: #children:
				if(is_instance_valid(child)):
					if child.type == 'myco' and child.name != self.name:
						if debug_mode:
							print(" child found: ", child.name )
						for excess in keys_e:
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
								#print(" .... sending a trade along, ", path_dict)
								assets[excess] -= 1#amt_needed
								bars[excess].value = assets[excess]
								#print(excess_res, " value: ", bars[excess_res].value)
								#bars[excess_res].update()
								emit_signal("trade",path_dict)
								#
								#break
								#trade.emit(path_dict)
								#send what is in excess. 
								

func draw_selected_box():
	for line in $"../../Boxes".get_children():
		line.clear_points()	
		line.queue_free()
	
	var rect = $Sprite2D.get_rect()
	#position - rect*scale/2 for top left point 
	#position + rect*scale/2 for bottom right point


	var pos = rect.position#+self.global_position
	#var rects = Rect2(pos,rect.size*5) 

	var rects = rect * Transform2D(0, $Sprite2D.scale, 0, Vector2())
	#Color(Color.ANTIQUE_WHITE,0.3)
	#draw_rect(new_rect,Color.GREEN_YELLOW)
	#draw_line(pos, Vector2(pos.x+200,pos.y+200) , Color.GREEN_YELLOW, 5)
	
	var myco_line1 = Line2D.new()
	myco_line1.width = 2
	myco_line1.z_as_relative = false
	myco_line1.antialiased = true
	myco_line1.global_rotation = 0
	#myco_line1.modulate = start_color
	myco_line1.modulate = Color.GREEN_YELLOW
	#var to = to_local(agent.position)#+agent.global_position		
	
	myco_line1.add_point( Vector2(position.x+rects.position.x,position.y+rects.position.y)  )
	myco_line1.add_point( Vector2(position.x+rects.position.x+2*rects.size[0]/2,position.y+rects.position.y)  )
	myco_line1.add_point( Vector2(position.x+rects.position.x+2*rects.size[0]/2,position.y+rects.position.y+2*rects.size[1]/2)  )
	myco_line1.add_point( Vector2(position.x+rects.position.x,position.y+rects.position.y+2*rects.size[1]/2)  )
	myco_line1.add_point( Vector2(position.x+rects.position.x,position.y+rects.position.y)  )
			#myco_line.z_index = -1
	$"../../Boxes".add_child(myco_line1)



func _on_area_entered(trade: Area2D) -> void:
	if trade.end_agent == self:
		#print("myself", body_entered)
		#remove the resource from the trade and give it to the end_agent
		#trade.start_agent.assets[trade.asset]-=trade.amount
		
		if assets.get(trade.asset) != null:
			if(assets[trade.asset] < (needs[trade.asset]*2)):
				assets[trade.asset]+=trade.amount
				bars[trade.asset].value = assets[trade.asset]
			
			
			if trade.type == "swap":
				var return_amount = trade.return_amt*Global.values[trade.asset]/Global.values[trade.return_asset]
				if return_amount < 0.5:
					#print("return amount:", return_amount, trade)
					return_amount = 0
				else:
					if return_amount < 1:
						return_amount = 1
					else:
						return_amount = int(return_amount)
					var path_dict = {
						"from_agent": self,
						"to_agent": trade.start_agent,
						"trade_path": [self,trade.start_agent],
						"trade_asset": trade.return_asset,
						"trade_amount": return_amount,
						"trade_type": "send",
						"return_res": null,
						"return_amt": null
					}	
					if(assets[trade.return_asset]>= return_amount):
						assets[trade.return_asset]-=return_amount
						bars[trade.return_asset].value = assets[trade.return_asset]
						emit_signal("trade",path_dict)
						#print("Returned Trade in Myco: ", path_dict)	
			trade.call_deferred("queue_free")
			
			
		else:
			print("Error myco without asset:", trade.asset, assets)
	#else:
	#	print("not myself", body_entered)
		#collision.emit(body)
	#trade.queue_free()
	#queue_free()


	#queue_free()

func _on_growth_timer_timeout() -> void:
	#concume nutrients
	var newScale = $MycoSprite.scale#$Sprite2D.scale
	
	var all_in = true
	for res in assets:
		if assets[res] <= 0:
			all_in = false
	
		#print(name, " assets: ", assets)
	if all_in == true:	
				
		if $MycoSprite.scale.x < max_scale and $MycoSprite.scale.y < max_scale:
			#var tween = get_tree().create_tween()
			newScale = $MycoSprite.scale * (1+scale_step_up)
			
		var old_modulate = $Sprite2D.modulate
		var new_alpha = $Sprite2D.modulate.a+alpha_step_up
		if new_alpha > high_alpha:
			new_alpha = high_alpha
		var new_color = Color(old_modulate,new_alpha)
		$Sprite2D.modulate= new_color
		
		
	else:
		
		var old_modulate = $Sprite2D.modulate
		var new_alpha = $Sprite2D.modulate.a-alpha_step_down
		
		if new_alpha < low_alpha:
			new_alpha = low_alpha
		
		if false: #undead
		
			kill_it()	
	
		var new_color = Color(old_modulate,new_alpha)
		$Sprite2D.modulate= new_color

	if newScale != $MycoSprite.scale:
		#print(" old scale:", $MycoSprite.scale, " new scale: ", newScale)
		buddy_radius = $MycoSprite.get_rect().size[0]/2*newScale[0]
		#print(" buddy radius: ", buddy_radius)
		var tween = get_tree().create_tween()
		tween.tween_property($MycoSprite, "scale", newScale, 0.05)
		self.new_buddies = true
		self.draw_lines = true
		
		var children =  $"../../Agents".get_children()
		
		#print(self.name, " new buddies children: ", children)
		for child in children:
			child.new_buddies = true
			child.draw_lines = true
		
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
		Global.score += 200


	
func _on_action_timer_timeout() -> void:
	logistics_ready = true
