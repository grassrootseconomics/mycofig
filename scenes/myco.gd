extends Area2D

@export var speed: int
signal collision
signal trade(pos)

var draw_lines = true
var draw_box = true

var type = null
var my_lines = []
var trade_buddies = []
var new_buddies = true
var buddy_radius = 250
var num_buddies = 5

var logistics_ready = false
var sprite = null
var sprite_texture = null
var sprite_myco = null
var sprite_myco_texture = null
var is_dragging = false
var mouse_offset
var delay = 10
var bar_canvas = null

var dead = false

var low_alpha = 0.6
var high_alpha = 1.0
var max_scale = 1.5
var min_scale = 0.3


var num_steps_down = 20.0
var num_steps_up = 5.0

var alpha_step_down = (high_alpha - low_alpha) / num_steps_down
var alpha_step_up = (high_alpha - low_alpha) / num_steps_up

var scale_step_down = (max_scale - min_scale) / num_steps_down
var scale_step_up = (max_scale - min_scale) / num_steps_up


var START_N = 5 #Nitrogen
var START_P = 5 # Potassium
var START_K = 5 #Phosphorus
var START_R = 5 #Rain

var assets = { #list of assets - 
	#for each asset there is a balance, and stready state amount needed for growth
	"N": START_N,
	"P": START_P,				
	"K": START_K,
	"R": START_R
			}

var needs = { #list of assets - 
	#for each asset there is a balance, and stready state amount needed for growth
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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
func set_variables(a_dict) -> void:
	name = a_dict.get("name")
	type = a_dict.get("type")
	#prod_res = a_dict.get("prod_res")
	#assets[prod_res] = a_dict.get("start_res")
	position = a_dict.get("position")
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
					var dist = global_position.distance_to(agent.global_position)
					if dist <= buddy_radius:
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


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if draw_lines == true and Global.draw_lines == true:
		new_draw_line()
		draw_lines = false
	if new_buddies:
		generate_buddies()
		new_buddies = false
	if(dead == false and is_instance_valid(self)):
		logistics()
	if(is_instance_valid(self) and is_instance_valid(Global.active_agent)):
		if(Global.active_agent.name == self.name):
			var direction = Input.get_vector("left","right","up","down")
			#velocity = direction * speed
			position += direction * 200 * delta
			#move_and_slide()
			
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
			if draw_box == true:
				draw_selected_box()
				#draw_box = false

	pass

func _on_body_entered(body: Node2D) -> void:
	#print(body_entered)
	#print(body)
	collision.emit(body)

		
func _physics_process(delta):
	#_draw()
	if is_dragging:
		#for agent in $"../../Agents".get_children():
		#	if(agent.is_dragging == true):
		#		if(self.get_index() > agent.get_index()):
		#			return
				
		var hit = false
		
		if $"../../UI/MarginContainer".get_rect().has_point(get_global_mouse_position()):
			hit = true
		
		if hit==true:
			kill_it()
			#queue_free()
			return
			
		
		
		new_buddies = true
		var children =  $"../../Agents".get_children()
		for child in children:
			#if child.type == 'myco': 
			child.draw_lines = true
			child.new_buddies = true
		
		
		
		var tween = get_tree().create_tween()
		tween.tween_property(self, "position", get_global_mouse_position(), delay * delta)
		#tween.set_parallel(true)
		for bar in bars:
			#bars[bar].position = (position + bars[bar].position)
			tween.tween_property(bars[bar], "position", (position + bars_offset[bar]), 0)
			#tween.set_parallel(true)


func old_draw():
	#print("outise")
	var from = to_local(position)
	#print("from: ", from, " x: ", from.x, " y: ", from.y)
	#from = from.normalized() *100
	if($"../../Agents" != null):
		#print("<><><>>< ", position, " ", global_position)
		for agent in $"../../Agents".get_children():
			if agent.name != "Myco" and agent.name != "Cloud" :
				var to = to_local(agent.position)#+agent.global_position			
				#print("to: ", to)
				var new_pos1 = Vector2(to.x,from.y)
				#print("new_pos1: ", new_pos1)
				#draw_line(from, new_pos1 , Color(0, 0, 1), 5)
				#draw_line(from, new_pos1, Color(1, 1, 1), 1)
				
				#draw_line(new_pos1, to , Color(0, 0, 1), 5)
				#draw_line(new_pos1, to , Color(1, 1, 1), 1)
				#to = to.normalized() *100
				# blue
				
				#draw_line(from, to , Color(0, 0, 1), 5)
				# white
				#draw_line(from, to, Color(1, 1, 1), 1)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			
			if event.pressed:
				if $Sprite2D.get_rect().has_point(to_local(event.position)):
					if(Global.is_dragging == false):
						is_dragging = true
						Global.is_dragging = true
						Global.active_agent = self
			else:
				is_dragging = false
				Global.is_dragging = false
				if $Sprite2D.get_rect().has_point(to_local(event.position)):
					#emit_signal("clicked_agent",self)
					Global.active_agent = self
					print(" clicked: ", name)
				

func _on_area_2d_body_entered(_body):
	#rest_point = input_pos.global_position
	print('hello')


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

func kill_it():
	#new_alpha = low_alpha
	#self.queue_free()
	self.call_deferred("queue_free")
	self.dead = true
	
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
	var living = false
	for child in children:
		child.draw_lines = true
		child.new_buddies = true
		
		
		if(child.dead == false and child.type != "cloud"):
			living = true
		
			if( living == false  and Global.mode != "tutorial"):
				get_tree().change_scene_to_file("res://scenes/game_over.tscn")
			

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
		Global.score += int(Global.score_boost[self.type])


	
func _on_action_timer_timeout() -> void:
	logistics_ready = true
