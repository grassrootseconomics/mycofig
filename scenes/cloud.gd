extends Area2D

@export var speed: int
signal collision
signal trade(pos)


var random = RandomNumberGenerator.new()

var is_dragging = false
var mouse_offset
var delay = 10
var sprite = null
var sprite_texture = null
var bar_canvas = null
var dead = false
var is_raining = true

var draw_lines = false
var new_buddies = false
var trade_buddies = []

var type = "cloud"

var logistics_ready = false
var decay_ready = false
var production_ready = false
var prod_res = "R"

var START_R = 0 #Nitrogen
var trades = [] #list of outstanding trades

var assets = { #list of assets - 
	#for each asset there is a balance, and stready state amount needed for growth
	"R": START_R
	}

var needs = { #list of needed assets with need level
	"R": 10
	}


var bars = { #list of needed assets with need level
	"R": null
}

var bars_offset = { #list of needed assets with need level
	"R": null
}


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	#var rng :=  RandomNumberGenerator.new()
	#var width = get_viewport().get_visible_rect().size[0]
	#var height = get_viewport().get_visible_rect().size[1]
	#var random_x = rng.randi_range(5,width-100)
	#var random_y = rng.randi_range(5,height-200)
	#var random_y = rng.randi_range(5,-1*height)
	#position = Vector2(random_x,random_y)
	#$GrowthTimer.wait_time = Global.growth_time
	#position = Vector2(width,height)
	
	#sprite = $Sprite2D
	#sprite_texture = load("res://graphics/cloud.png")
	#bars = { #list of needed assets with need level
	#	"R": $CanvasLayer/Rbar
	#}
	#for bar in bars:
	#	bars[bar].max_value = int(needs[bar]*1.2)
	#	bars[bar].value = assets[bar]
	#	bars_offset[bar] = bars[bar].position
	#	bars[bar].position = (position + bars[bar].position)
	#	bars[bar].tint_progress = Global.asset_colors[bar]
		#print(bar, " value: ", bars[bar].value)
		
		#var sb = StyleBoxFlat.new()
		#bars[bar].add_theme_stylebox_override("fill", sb)
		#sb.bg_color = Global.asset_colors[bar]

	#speed = 0 #rng.randi_range(200,500)


func set_variables(a_dict) -> void:
	#print("setup: ", a_dict)
	name = a_dict.get("name")
	type = a_dict.get("type")
	prod_res = a_dict.get("prod_res")
	if a_dict.get("start_res") == null:
		assets[prod_res] = needs[prod_res]
	else:
		assets[prod_res] = a_dict.get("start_res")
	position = a_dict.get("position")
	sprite_texture = a_dict.get("texture")
	sprite = $Sprite2D
	$Sprite2D.texture = sprite_texture
	
	
	$GrowthTimer.wait_time = Global.growth_time
	
	$DecayTimer.wait_time = Global.decay_time
	$ActionTimer.wait_time = Global.action_time+0.5
	bars = { #list of needed assets with need level
		"R": $CanvasLayer/Rbar
	}
	for bar in bars:
		bars[bar].max_value = int(needs[bar]*1.2)
		bars[bar].value = assets[bar]
		bars_offset[bar] = bars[bar].position
		bars[bar].position = (position + bars[bar].position)
		bars[bar].tint_progress = Global.asset_colors[bar]
		
	bar_canvas = $CanvasLayer


func logistics():
	#wait for timer
	
		
	if logistics_ready:

		var children =  $"../../Agents".get_children()
		randomize()
		children.shuffle()
		for child in children:
			if(assets[prod_res] - needs[prod_res]  >= 1):
				if(is_instance_valid(child)):
					if child.type != 'myco' and child.type != 'cloud':
						#print(child.name, " needs: ", prod_res)
						#if child.name != 'Maize':
						#		print(child.name, " needs: ", prod_res)
						if child.assets.get(prod_res) != null:	
							#==========+++print(" needed: ", needed_res, ":", amt_needed)
							#print(" cloud supply: ", child.assets[excess_res], " maize excess: ", excess_res, ":", amt_excess)
							#if child.assets[needed_res] >= amt_needed:
							var path_dict = {
								"from_agent": self,
								"to_agent": child,
								"trade_path": [self,child],
								"trade_asset": prod_res,
								"trade_amount": 1, #amt_needed,
								"trade_type": "send",
								"return_res": null,
								"return_amt": 1,#amt_needed
							}
							#print("cloud .... sending a trade along, ", path_dict)
							assets[prod_res] -= 1#amt_needed
							bars[prod_res].value = assets[prod_res]
							#print(excess_res, " value: ", bars[excess_res].value)
							#bars[excess_res].update()
							emit_signal("trade",path_dict)
							logistics_ready = false
							#trade.emit(path_dict)
							#send what is in excess. 
					
								#Attempt to push out what you have in abundance
						
#determine what is needed (needs)
		
		#if they can swap a resource for a needed resource do it 
		#     Send the resource to the myco (when it arrives the needed resource will come back)

		#Consume resources
		#These are combinations NPK together
		
		#Increase health
		
	
	#if decay_ready:
	if false:
		for res in assets:
			if assets[res] > 0:
				assets[res] -=1
				bars[res].value = assets[res]
				#print(" decay: ", assets)
		decay_ready = false
	
	#if false:
	if production_ready:
		production_ready = false
		if assets[prod_res] < needs[prod_res] *2:
			assets[prod_res]+=3
		if assets[prod_res]> needs[prod_res] *2:
			assets[prod_res] = needs[prod_res] *2
		bars[prod_res].value = assets[prod_res]
			
	
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	
	if Global.is_raining and self.is_raining:
		logistics()
	#pass


func _on_body_entered(body: Node2D) -> void:
	#print(body_entered)
	#print(body)
	collision.emit(body)
	
func _physics_process(delta):
		
	if is_dragging:
		
		var hit = false
		if $"../../UI/PalletContainer".get_rect().has_point(get_global_mouse_position()):
			hit = true
			#print("hit something-pallet: ", $PalletContainer.get_rect(), " point: ", event.position)
		
		if $"../../UI/MarginContainer".get_rect().has_point(get_global_mouse_position()):
			hit = true
		
		if hit==true:
			queue_free()
			return
	
		var tween = get_tree().create_tween()
		tween.tween_property(self, "position", get_global_mouse_position(), delay * delta)
		tween.set_parallel(true)
		for bar in bars:
			#bars[bar].position = (position + bars[bar].position)
			tween.tween_property(bars[bar], "position", (position + bars_offset[bar]), 0)
			tween.set_parallel(true)
	
func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				
				if $Sprite2D.get_rect().has_point(to_local(event.position)):
				
					is_dragging = true
					Global.active_agent = self
					print(" clicked: ", name, " type: ", self.type)
					
			else:
				is_dragging = false
	
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_R:
			if is_raining == false:
				is_raining = true
				print("pressed raining")
			else:
				is_raining = false
				print("pressed not raining")

func _on_area_entered(ztrade: Area2D) -> void:
	if ztrade.end_agent == self:
		assets[ztrade.asset]+=ztrade.amount	
		if(assets[ztrade.asset] > needs[ztrade.asset]*2):
			assets[ztrade.asset] = needs[ztrade.asset]*2 
		bars[ztrade.asset].value = assets[ztrade.asset]
		ztrade.queue_free()
	


func _on_action_timer_timeout() -> void:
	logistics_ready = true
	


func _on_growth_timer_timeout() -> void:
	#$GrowthTimer.set_wait_time(random.randf_range(1, 5))
	production_ready = true


func _on_decay_timer_timeout() -> void:
	#$DecayTimer.set_wait_time(random.randf_range(1, 5))
	decay_ready = true


func _on_dry_timer_timeout() -> void:
	var wait_for_rain = 0
	if(is_raining == true):
		wait_for_rain = random.randi_range(50, 100)
		is_raining = false
		var tween = get_tree().create_tween()
		tween.tween_property(sprite, "modulate:a", 0.2, 0.5)
		#tween.set_parallel(true)
		#$Sprite2D.modulate.a = 0.2
		print("not raining on timer: " , wait_for_rain)
		
	else:
		wait_for_rain = random.randi_range(1, 50)
		is_raining = true
		var tween = get_tree().create_tween()
		tween.tween_property(sprite, "modulate:a", 1, 0.5)
		#tween.set_parallel(true)
		#$Sprite2D.modulate.a = 1
		print("raining on timer: ", wait_for_rain)
	$DryTimer.set_wait_time(wait_for_rain)
