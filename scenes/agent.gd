extends Area2D
class_name Agent

@export var speed: int

signal trade(pos)
signal clicked
signal clicked_agent(agent)
signal new_agent(agent_dict)
signal update_score

var my_lines = []
var buddy_radius = 250
var sprite_myco = null
var sprite_myco_texture = null

var random = RandomNumberGenerator.new()

var caught_by = null
var is_dragging = false
var mouse_offset
var delay = 10
var last_position = null
var draw_box = true
var draw_lines = false
var dead = false

var low_alpha = 0.75
var high_alpha = 1.0
var max_scale = 1.4
var min_scale = 0.8


var num_steps_down = 35.0
var num_steps_up = 10.0

var alpha_step_down = (high_alpha - low_alpha) / num_steps_down
var alpha_step_up = (high_alpha - low_alpha) / num_steps_up

var scale_step_down = (max_scale - min_scale) / num_steps_down
var scale_step_up = (max_scale - min_scale) / num_steps_up

var logistics_ready = false
var production_ready = false
var decay_ready = false
var evaporate_ready = false
var sprite = null
var sprite_texture = null
var bar_canvas = null
var prod_res = "N"
var type = null

var START_N = 0 #Nitrogen
var START_P = 0 # Potassium 
var START_K = 0 #Phosphorus
var START_R = 0 #Rain
var trades = [] #list of outstanding trades
var trade_buddies = []
var new_buddies = true

var peak_maturity = 3
var current_maturity = 0

var num_buddies = 5
var num_connectors = 0
var max_connectors = 5
var num_babies = 12
var current_babies = 0

#var assets = {}


var assets = { #list of assets - 
	#for each asset there is a balance, and stready state amount needed for growth
	"N": START_N,
	"P": START_P,				
	"K": START_K,
	"R": START_R
	}
var needs = { #list of needed assets with need level
	"N": 10,
	"P": 10,				
	"K": 10,
	"R": 10
	}
var current_needs = { #list of needed assets with need level
	"N": 0,
	"P": 0,				
	"K": 0,
	"R": 0
	}
	
var current_excess = { #list of needed assets with need level
	"N": 0,
	"P": 0,				
	"K": 0,
	"R": 0
	}

var bars = { #list of needed assets with need level
	"N": null,
	"P": null,
	"K": null,
	"R": null
}

var bars_offset = { #list of needed assets with need level
	"N": null,
	"P": null,
	"K": null,
	"R": null
}

	
func set_variables(a_dict) -> void:
	#print("setup: ", a_dict)
	
	var asset_dict = {
		"long_name": "Nitrogen",
		"symbol": "N",
		"color": Color.SPRING_GREEN,
		"amt": 0,
		"need": 0,
		"current_need": 0,
		"current_excess": 0,
		"bar": $CanvasLayer/Nbar,
		"bar_offset": (position + $CanvasLayer/Nbar.position)
	}
	
	#var dict_assets = []
	
	#var asset_N = Asset.new()
	#asset_N.setup(asset_dict)
	
	#dict_assets.append(asset_N)
	
	#for new_asset in dict_assets:
	#	assets[new_asset.symbol] = new_asset
	
	#print("assets: ", dict_assets)
	
	
	
	
	name = a_dict.get("name")
	type = a_dict.get("type")
	
	prod_res = a_dict.get("prod_res")
	if a_dict.get("start_res") == null:
		assets[prod_res] = needs[prod_res]
		#assets[prod_res].amt = assets[prod_res].need
	else:
		assets[prod_res] = a_dict.get("start_res")
		#assets[prod_res].amt = a_dict.get("start_res")
	position = a_dict.get("position")
	last_position = position
	sprite_texture = a_dict.get("texture")
	sprite = $Sprite2D
	$Sprite2D.texture = sprite_texture
	
	if(Global.social_mode):
		min_scale = 1
	sprite.scale *= min_scale
	
	$GrowthTimer.wait_time = Global.growth_time
	$EvaporateTimer.wait_time = Global.evap_time
	$DecayTimer.wait_time = Global.decay_time
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
	if(Global.bars_on == false):
		bar_canvas.visible = false
		


func sort_decending(a, b):
	if a[1] > b[1]:
		return true
	return false


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
	



func logistics():
	#wait for timer
	var excess_res = null
	var high_amt_excess = 0
	var needed_res = null
	var high_amt_needed = 0
	
	var debug_mode = false
	
	if logistics_ready:
		if( is_instance_valid(Global.active_agent)):
			if self.name == Global.active_agent.name:
				debug_mode = false#true
	
		if debug_mode:
			print("New Round in: ", name ,", ", assets, " needs: ", needs)	
		#determine if there are extra resources (offers)
		#find excess stock
		for res in assets:
				
				 
				var c_excess = assets[res] - needs[res] 
				
				if assets[res] > needs[res]:
					if c_excess > high_amt_excess:
						high_amt_excess = c_excess
						excess_res = res
						
				if assets[res] < needs[res]:
					#print("res: ", res, " c_excess: ", c_excess, " high_amt_needed: ", high_amt_needed)
					#if -1 * c_excess > high_amt_needed:
					high_amt_needed = -1 * c_excess
					needed_res = res
					current_needs[res] = high_amt_needed
				else:
					current_needs[res] = 0
		
		var keys: Array = current_needs.keys()
		# Sort keys in descending order of values.
		keys.sort_custom(func(x: String, y: String) -> bool: return current_needs[x] > current_needs[y])
		#print("actual needs: ", needs)
		if debug_mode:
			print("excess: ", excess_res, " current_needs: ", current_needs, keys)
		
		if excess_res != null and needed_res != null:
			#var children =  $"../../Agents".get_children()
			randomize()
			trade_buddies.shuffle()
			
			if debug_mode:
				print(" shuffle" )
			var need_itter = 0
			
			for child in trade_buddies: #children:
				if(is_instance_valid(child)):
					if logistics_ready and child.type == 'myco':
						if debug_mode:
							print(" child found" )
						for need in keys:
							need_itter +=1
							if debug_mode:
								print(need_itter, ". current need: ", need, " supply: ",assets[need], " needs: ", needs[need] )
							if logistics_ready and current_needs[need] > 0 and assets[need] < needs[need] :
								if child.assets.get(need) != null:
									if debug_mode:
										print(" ... myco assets: " , child.assets, " needs: ", child.needs[need])
									if true: #child.assets[need] >= 1:# and child.assets[excess_res] < (child.needs[excess_res]*2):
										
										if need  != excess_res:
											var path_dict = {
												"from_agent": self,
												"to_agent": child,
												"trade_path": [self,child],
												"trade_asset": excess_res,
												"trade_amount": 1, #amt_needed,
												"trade_type": "swap",
												"return_res": need,
												"return_amt": 1,#amt_needed
											}
											if debug_mode:
												print(" .... sending a trade along, ")
											#print(" .... sending a trade along, ", path_dict)
											assets[excess_res] -= 1#amt_needed
											bars[excess_res].value = assets[excess_res]
											#print(excess_res, " value: ", bars[excess_res].value)
											#bars[excess_res].update()
											emit_signal("trade",path_dict)
											logistics_ready = false
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
	
func kill_it():
	#new_alpha = low_alpha
	#self.queue_free()
	self.call_deferred("queue_free")
	self.dead = true
	

	if(draw_box):
		for box in $"../../Boxes".get_children():
			box.clear_points()	
			box.queue_free()
	
	
	new_buddies = true
	#var children =  $"../../Agents".get_children()
	#for child in children:
		#if child.type == 'myco': 
		
	
	
	
	for child in trade_buddies:#children:
		child.draw_lines = true
		child.new_buddies = true
		
	var children =  $"../../Agents".get_children()
	var living = false
	for child in children:#children:
		
		if(child.type != "cloud" and child.type != "myco"):
			if(child.dead == false):
				living = true
		
	if( living == false and Global.mode != "tutorial"):
		get_tree().change_scene_to_file("res://scenes/game_over.tscn")


func evaporate():

	if assets["R"] > 0: #evaporate
		var children =  $"../../Agents".get_children()
		randomize()
		children.shuffle()
		for child in children:
			#print(children)
			if child.type == 'cloud':
				var path_dict = {
					"from_agent": self,
					"to_agent": child,
					"trade_path": [self,child],
					"trade_asset": "R",
					"trade_amount": 1, #amt_needed,
					"trade_type": "send",
					"return_res": null,
					"return_amt": 0,#amt_needed
				}
				#print(" .... sending a trade along, ", path_dict)
				assets["R"] -= 1#amt_needed
				bars["R"].value = assets["R"]
				#print(excess_res, " value: ", bars[excess_res].value)
				#bars[excess_res].update()
				emit_signal("trade",path_dict)
				break
					


func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			
			if event.pressed:
				
				if $Sprite2D.get_rect().has_point(to_local(event.position)):
					if(Global.is_dragging == false):
						is_dragging = true
						Global.is_dragging = true
						Global.active_agent = self
					#is_dragging = true
					#Global.active_agent = self
					#print(" clicked: ", name)
					
			else:
				is_dragging = false
				Global.is_dragging = false
				if $Sprite2D.get_rect().has_point(to_local(event.position)):
					#emit_signal("clicked_agent",self)
					Global.active_agent = self
					#print(" clicked: ", name)
				

func _physics_process(delta):
	#_draw()
	if is_dragging:
		
		var hit = false
		
		if $"../../UI/MarginContainer".get_rect().has_point(get_global_mouse_position()):
			hit = true
		
		if hit==true:
			kill_it()
			return
		
		
		new_buddies = true
		#print(self.name, " new buddies children: ", children)
		var children =  $"../../Agents".get_children()
		for child in children:
			#if child.type == 'myco': 
			child.draw_lines = true
			child.new_buddies = true
			
		
		var tween = get_tree().create_tween()
		tween.tween_property(self, "position", get_global_mouse_position(), delay * delta)
		tween.set_parallel(true)
		for bar in bars:
			#bars[bar].position = (position + bars[bar].position)
			tween.tween_property(bars[bar], "position", (position + bars_offset[bar]), 0)
			tween.set_parallel(true)
	
	if(caught_by != null):
		position = caught_by.position+Vector2(33,0)
		bar_canvas.visible = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if new_buddies:
		generate_buddies()
		new_buddies = false
	if draw_lines and Global.draw_lines and self.type == "myco":
		new_draw_line()
		new_buddies = false
	if(dead == false and is_instance_valid(self)):
		logistics()
	if(is_instance_valid(self) and is_instance_valid(Global.active_agent)):
		if(Global.active_agent.name == self.name):
			if draw_box == true:
				draw_selected_box()
				draw_box=false
			var direction = Input.get_vector("left","right","up","down")
			#velocity = direction * speed
			
			position += direction * 200 * delta
			
			if(position != last_position):
			#move_and_slide()
				last_position = position
				#move_and_slide()
				#print("setting ")
				new_buddies = true
				var children =  $"../../Agents".get_children()
				for child in children:
					#if child.type == 'myco': 
					child.draw_lines = true
					child.new_buddies = true
					
			
				for bar in bars:
					var tween = get_tree().create_tween()
					#bars[bar].position = (position + bars[bar].position)
					tween.tween_property(bars[bar], "position", (position + bars_offset[bar]), 0)
					#tween.set_parallel(true)
				#if draw_box == true:
				#	draw_selected_box()
				draw_box = true



# Search for things to trade with in a radius
func generate_buddies() -> void:
	var children =  $"../../Agents".get_children()
	trade_buddies = []
	#print(self.name, " new buddies children: ", children)
	
	for child in children:
		if child.type == 'myco':
			var over_full = false
			child.num_connectors = 0
			if(Global.social_mode):
				for child2 in children:
					if(child2.name != child.name):
						for buddy in child2.trade_buddies:
							if buddy.name == child.name:
								child.num_connectors +=1
				if(child.num_connectors>= child.max_connectors):
					print("too many: connectors", child.num_connectors)
					over_full = true
			if (over_full == false):
				var dist = global_position.distance_to(child.global_position)
				if dist <= child.buddy_radius:
					#print("child in dist,", dist, " len: ", len(trade_buddies) , " max: ", num_buddies)
					if len(trade_buddies) < num_buddies:
						trade_buddies.append(child)
						if(Global.social_mode):
							child.num_connectors +=1
							print(child.name, " child connectors: ", child.num_connectors, " max con: ", child.max_connectors)
							child.draw_lines = true
					#else:
						#print(self.name, " is too far from myco: ", dist)
			#print("final new buddies: ", trade_buddies)

func new_draw_line():
	for line in $"../../Lines".get_children():
		for my_line in my_lines:
			if(my_line == line):
				line.clear_points()	
				line.queue_free()
		
	my_lines = []
	#var g = Gradient.new()
	var start_color = Color(Color.ANTIQUE_WHITE,0.3)
	#var end_color = Color(Color.ANTIQUE_WHITE,0.3)
	
	#g.set_color( 0,  start_color)
	#g.set_color( 1,  end_color )
	#g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR		# 0
	#g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT	# 1
	#g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC		# 2

	#var from = to_local(position)
	var from = position
	#print("from: ", from, " x: ", from.x, " y: ", from.y)
	#from = from.normalized() *100
	if($"../../Agents" != null):
		#print("<><><>>< ", position, " ", global_position)
		for agent in $"../../Agents".get_children():
			if(is_instance_valid(agent)):
				if agent.type != "cloud" and agent.dead != true and agent.name != self.name:
					for buddy in agent.trade_buddies:
						if buddy.name == self.name:
							
							var myco_line1 = Line2D.new()
							myco_line1.width = 2
							myco_line1.z_as_relative = false
							myco_line1.antialiased = true
							myco_line1.global_rotation = 0
							#myco_line1.modulate = start_color
							myco_line1.modulate = start_color#set_gradient( g )
							#var to = to_local(agent.position)#+agent.global_position		
							var to = agent.position#+agent.global_position							
							var new_pos1 = Vector2(to.x,from.y)
							var new_pos2 = Vector2(from.x,to.y)
							
							
							myco_line1.add_point( from )
							myco_line1.add_point( new_pos1 )
							myco_line1.add_point( to )
							
							var myco_line2 = Line2D.new()
							myco_line2.width = 2
							myco_line2.z_as_relative = false
							myco_line2.antialiased = true
							#myco_line2.global_rotation = 0
							myco_line2.modulate = start_color
							#var to = to_local(agent.position)#+agent.global_position		
							
							myco_line2.add_point( from )
							myco_line2.add_point( new_pos2 )
							myco_line2.add_point( to )
							
							#myco_line.z_index = -1
							$"../../Lines".add_child(myco_line1)
							my_lines.append(myco_line1)
							$"../../Lines".add_child(myco_line2)
							my_lines.append(myco_line2)



func _on_area_entered(ztrade: Area2D) -> void:
	if ztrade.end_agent == self:
		assets[ztrade.asset]+=ztrade.amount	
		if assets[ztrade.asset]> needs[ztrade.asset] *2:
			assets[ztrade.asset] = needs[ztrade.asset] *2
		else:
			Global.score+=ztrade.amount
			emit_signal("update_score")
		bars[ztrade.asset].value = assets[ztrade.asset]
		ztrade.call_deferred("queue_free")

func _on_action_timer_timeout() -> void:
	logistics_ready = true


func _on_growth_timer_timeout() -> void:
	#$GrowthTimer.set_wait_time(random.randf_range(1, 5))
	#production_ready = true
	#if production_ready:		
	#	production_ready = false
	assets[prod_res]+=3
	if assets[prod_res]> needs[prod_res] *2:
		assets[prod_res] = needs[prod_res] *2
	bars[prod_res].value = assets[prod_res]
	
	#if there is 1 res in each asset - consume them all and grow in size
	#if any are missing shrink
	var all_in = true
	for res in assets:
		if assets[res] <= 0:
			all_in = false
			
	var newScale = $Sprite2D.scale
	#print(name, " assets: ", assets)
	if all_in == true:	
		
		
		
		if $Sprite2D.scale.x < max_scale and $Sprite2D.scale.y < max_scale:
			var tween = get_tree().create_tween()
			newScale = $Sprite2D.scale * (1+scale_step_up)
			
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
			#if(res != "R"):
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
			
			if(Global.is_killing == true):
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
	
		if Global.baby_mode:
			if(Global.is_max_babies == true):
				if(current_babies < num_babies):
					have_babies()
			else:
				have_babies()
	
func have_babies()  -> void:
	
	var max_rounds = 10
	var current_round = 0
	var baby_made = false
	
	
	#produce a baby
	#find a random place nearby
	
	var new_x = global_position.x
	var new_y = global_position.y
	
	var size_x = sprite.get_rect().size[0]
	var size_y = sprite.get_rect().size[1]
	
	while(baby_made == false and current_round < max_rounds):
		if(Global.is_max_babies):
			if(current_babies >= num_babies):
				return
				
		new_x = global_position.x
		new_y = global_position.y
		current_round+=1
		var rng :=  RandomNumberGenerator.new()
		#print(" sizes: x: ", sprite.get_rect().size[0], " y: ", sprite.get_rect().size[1])
		var random_x = rng.randi_range(-1*size_x*4,size_x*4)
		var random_y = rng.randi_range(-1*size_y*4,size_y*4)
		
		#print(" rand_x: ", random_x, " rand_y: ", random_y)
		new_x = new_x + random_x
		new_y = new_y + random_y
		
		var new_pos = Vector2(new_x, new_y )
		var hit = false
		
		if $"../../UI/MarginContainer".get_rect().has_point(new_pos):
			hit = true
			#print("hit something-info")
		
		for agent in $"../../Agents".get_children():
			var recto = agent.sprite.get_rect()
			var posr = recto.position+agent.global_position
			var rects = Rect2(posr,recto.size*agent.scale*2) 
			
			if rects.has_point(new_pos):
				hit = true
		
			
		
		if( hit == false):
			var screen_rect = get_viewport().get_visible_rect()
			if (screen_rect.has_point(new_pos)):
				var new_agent_dict = {
					"name" : self.type,
					"pos": new_pos
				}
				#print("old pos: x: ",global_position.x, " y: ", global_position.y , "new agent signal: ", new_agent_dict)
				current_maturity +=1 
				if(current_maturity >= peak_maturity):
					emit_signal("new_agent", new_agent_dict)
					baby_made = true
					current_babies +=1
					current_maturity = 0
				
				#make_squash(event.position)		



func _on_decay_timer_timeout() -> void:
	#$DecayTimer.set_wait_time(random.randf_range(1, 5))
	decay_ready = true


func _on_evaporate_timer_timeout() -> void:
	#$EvaporateTimer.set_wait_time(random.randf_range(1, 5))
	evaporate_ready = true


func _on_body_entered(body: Node2D) -> void:
	if (body is Bird and self.type == body.quarry_type):#"maize"):
		
		#print("bird endered: ", body)
		if(body.caught == false and caught_by == null):
			body.caught = true
			caught_by = body
			logistics_ready = false
			sprite.rotate(PI/4)
			self.dead = true
			
			var living = false
			
			body.speed -=100
			
			
			body.going = Vector2(1,randi_range(-1,1))
			#var children =  $"../../Agents".get_children()
			for child in trade_buddies:# children:
				child.draw_lines = true
				child.new_buddies = true

			#sprite.z_index = 10
