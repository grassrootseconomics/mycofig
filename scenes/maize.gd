extends Area2D

@export var speed: int
signal collision
signal trade(pos)

var random = RandomNumberGenerator.new()

var is_dragging = false
var mouse_offset
var delay = 10


var logistics_ready = false
var decay_ready = false
var production_ready = false
var prod_res = "K"

var START_N = 0 #Nitrogen
var START_P = 0 # Potassium 
var START_K = 50 #Phosphorus
var START_R = 50 #Rain
var trades = [] #list of outstanding trades

var assets = { #list of assets - 
	#for each asset there is a balance, and stready state amount needed for growth
	"N": START_N,
	"P": START_P,				
	"K": START_K,
	"R": START_R
	}

var needs = { #list of needed assets with need level
	"N": 50,
	"P": 50,				
	"K": 50,
	"R": 50
	}

var current_needs = { #list of needed assets with need level
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
	#var rng :=  RandomNumberGenerator.new()
	#var width = get_viewport().get_visible_rect().size[0]
	#var height = get_viewport().get_visible_rect().size[1]
	#var random_x = rng.randi_range(5,width-100)
	#var random_y = rng.randi_range(5,height-200)
	#var random_y = rng.randi_range(5,-1*height)
	#position = Vector2(random_x,random_y)
	var width = int(get_viewport().get_visible_rect().size[0]/2)+160
	var height = int(get_viewport().get_visible_rect().size[1]/2)-20
	position = Vector2(width,height)
	
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
		#print(bar, " value: ", bars[bar].value)
		
		#var sb = StyleBoxFlat.new()
		#bars[bar].add_theme_stylebox_override("fill", sb)
		#sb.bg_color = Global.asset_colors[bar]

	speed = 0 #rng.randi_range(200,500)


func logistics():
	#wait for timer
	var excess_res = null
	var amt_excess = 0
	var needed_res = null
	var amt_needed = 0
		
	if logistics_ready:
		#print("New Round in Maize: ", assets)	
		#determine if there are extra resources (offers)
		#find excess stock
		for res in assets:
				var amount_instock = assets[res] 
				var amount_needed = needs[res] 
				var c_excess = amount_instock - amount_needed 
				
				if amount_instock > amount_needed:
					if c_excess > amt_excess:
						amt_excess = c_excess
						excess_res = res
						
				if amount_instock < amount_needed:
					#if -1 * c_excess > amt_needed:
					amt_needed = -1 * c_excess
					current_needs[res] = amt_needed
					needed_res = res
				else:
					current_needs[res] = 0
	
		var keys: Array = current_needs.keys()
		# Sort keys in descending order of values.
		keys.sort_custom(func(x: String, y: String) -> bool: return current_needs[x] > current_needs[y])
		#print("current_needs: ", current_needs, keys)
		
		if excess_res != null and needed_res != null:
			var children =  $"../../Agents".get_children()
			for child in children:
				#print(">>current_need2: ")
				if child.name == 'Myco':
					for need in keys:
						#print(">>current_need: ", need)
						if current_needs[need] > 0 and assets[need] < needs[need]:
							if child.assets.get(need) != null:
								if logistics_ready and child.assets[need] >= 3:
									needed_res = need
									if need  != excess_res:
										var path_dict = {
											"from_agent": self,
											"to_agent": child,
											"trade_path": [self,child],
											"trade_asset": excess_res,
											"trade_amount": 1, #amt_needed,
											"trade_type": "swap",
											"return_res": needed_res,
											"return_amt": 1,#amt_needed
										}
										#print(" .... sending a trade along, ", path_dict)
										assets[excess_res] -= 1#amt_needed
										bars[excess_res].value = assets[excess_res]
										#print(excess_res, " value: ", bars[excess_res].value)
										#bars[excess_res].update()
										emit_signal("trade",path_dict)
										logistics_ready = false
										#trade.emit(path_dict)
										#send what is in excess. 
										
	#determine what is needed (needs)
		
		#if they can swap a resource for a needed resource do it 
		#     Send the resource to the myco (when it arrives the needed resource will come back)

		#Consume resources
		#These are combinations NPK together
		
		#Increase health
		
	if decay_ready:
		#print("decay", assets)
		decay_ready = false
		for res in assets:
			if assets[res] > 0 and res != "R":
				assets[res] -=1
				bars[res].value = assets[res]
				#print(" decay: ", assets)
			if assets[res] > 0 and res == "R": #evaporate
				var children =  $"../../Agents".get_children()
				for child in children:
					#print(children)
					if child.name == 'Cloud':	
						var path_dict = {
							"from_agent": self,
							"to_agent": child,
							"trade_path": [self,child],
							"trade_asset": res,
							"trade_amount": 1, #amt_needed,
							"trade_type": "send",
							"return_res": null,
							"return_amt": 0,#amt_needed
						}
						#print(" .... sending a trade along, ", path_dict)
						assets[res] -= 1#amt_needed
						bars[res].value = assets[res]
						#print(excess_res, " value: ", bars[excess_res].value)
						#bars[excess_res].update()
						emit_signal("trade",path_dict)
	
	
	if production_ready:		
		assets[prod_res]+=5
		if assets[prod_res]>= needs[prod_res] *2:
			assets[prod_res] = needs[prod_res] *2
		bars[prod_res].value = assets[prod_res]
		production_ready = false

	
	
	#Decay unused resources
	
	
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position += Vector2(0,1.0) *speed*delta
	var height = get_viewport().get_visible_rect().size[1]
	if position.y>height:
		queue_free()
	logistics()
	#pass


func _on_body_entered(body: Node2D) -> void:
	#print(body_entered)
	#print(body)
	collision.emit(body)
	
func _physics_process(delta):
	if is_dragging:
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
			else:
				is_dragging = false

func _on_area_entered(ztrade: Area2D) -> void:
	if ztrade.end_agent == self:
		assets[ztrade.asset]+=ztrade.amount
		if assets[ztrade.asset]> needs[ztrade.asset] *2:
			assets[ztrade.asset] = needs[ztrade.asset] *2
		bars[ztrade.asset].value = assets[ztrade.asset]
		ztrade.queue_free()
	


func _on_action_timer_timeout() -> void:
	logistics_ready = true
	


func _on_growth_timer_timeout() -> void:
	$GrowthTimer.set_wait_time(random.randf_range(1, 5))
	production_ready = true


func _on_decay_timer_timeout() -> void:
	$DecayTimer.set_wait_time(random.randf_range(1, 5))
	decay_ready = true
