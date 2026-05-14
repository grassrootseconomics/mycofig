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

var draw_box = false
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


func _update_bar_positions() -> void:
	if not is_instance_valid(bar_canvas):
		return
	var anchor = position
	var bar_zoom := Vector2.ONE
	if bar_canvas is CanvasLayer:
		var camera = get_viewport().get_camera_2d()
		if is_instance_valid(camera):
			bar_zoom = Vector2(maxf(absf(camera.zoom.x), 0.001), maxf(absf(camera.zoom.y), 0.001))
		anchor = Global.world_to_screen(self, position)
	for bar in bars:
		if is_instance_valid(bars[bar]):
			var offset = bars_offset.get(bar, Vector2.ZERO)
			if typeof(offset) != TYPE_VECTOR2:
				offset = Vector2.ZERO
			bars[bar].scale = bar_zoom
			bars[bar].position = anchor + Vector2(offset.x * bar_zoom.x, offset.y * bar_zoom.y)


func refresh_bar_visibility() -> void:
	if not is_instance_valid(bar_canvas):
		return
	var should_show = Global.bars_on and not dead
	if bar_canvas.visible != should_show:
		bar_canvas.visible = should_show
	if should_show:
		_update_bar_positions()



func _is_story_mode_runtime() -> bool:
	if Global.has_method("is_parallel_village_runtime"):
		return bool(Global.is_parallel_village_runtime())
	return str(Global.mode) == "story"


func _is_story_village_actor_node(node: Variant) -> bool:
	return is_instance_valid(node) and bool(node.get_meta("story_village_actor", false))


func _can_target_in_story_network(candidate: Variant) -> bool:
	if not is_instance_valid(candidate):
		return false
	if bool(candidate.get("dead")):
		return false
	if not _is_story_mode_runtime():
		return true
	var self_is_village_actor = _is_story_village_actor_node(self)
	var candidate_is_village_actor = _is_story_village_actor_node(candidate)
	return self_is_village_actor == candidate_is_village_actor


func set_variables(a_dict) -> void:
	#print("setup: ", a_dict)
	name = a_dict.get("name")
	type = a_dict.get("type")
	prod_res = a_dict.get("prod_res")
	
	if (prod_res[0] != null):
		if a_dict.get("start_res") == null:
			for res in prod_res:
				assets[res] = needs[res]
			#assets[prod_res].amt = assets[prod_res].need
		else:
			for res in prod_res:
				assets[res] = a_dict.get("start_res")
	
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
		bars[bar].tint_progress = Global.asset_colors[bar]
		
	bar_canvas = $CanvasLayer
	refresh_bar_visibility()


func logistics():
	#wait for timer
	
		
	if logistics_ready:

		var children =  $"../../Agents".get_children()
		children.shuffle()
		for child in children:
			if(assets[prod_res[0]] - needs[prod_res[0]]  >= 1):
				if(is_instance_valid(child)):
					if not _can_target_in_story_network(child):
						continue
					if child.type != 'myco' and child.type != 'cloud':
						#print(child.name, " needs: ", prod_res)
						#if child.name != 'Maize':
						#		print(child.name, " needs: ", prod_res)
						if child.assets.get(prod_res[0]) != null:	
							#==========+++print(" needed: ", needed_res, ":", amt_needed)
							#print(" cloud supply: ", child.assets[excess_res], " maize excess: ", excess_res, ":", amt_excess)
							#if child.assets[needed_res] >= amt_needed:
							var path_dict = {
								"from_agent": self,
								"to_agent": child,
								"trade_path": [self,child],
								"trade_asset": prod_res[0],
								"trade_amount": 1, #amt_needed,
								"trade_type": "send",
								"return_res": null,
								"return_amt": 1,#amt_needed
							}
							#print("cloud .... sending a trade along, ", path_dict)
							assets[prod_res[0]] -= 1#amt_needed
							bars[prod_res[0]].value = assets[prod_res[0]]
							#print(excess_res, " value: ", bars[excess_res].value)
							#bars[excess_res].update()
							emit_signal("trade",path_dict)
							logistics_ready = false
							#trade.emit(path_dict)
	
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
		for res in prod_res:
			if assets[res] < needs[res] *2:
				assets[res]+=3
			if assets[res]> needs[res] *2:
				assets[res] = needs[res] *2
			bars[res].value = assets[res]
			
	
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	
	if Global.is_raining and self.is_raining:
		logistics()
	if is_instance_valid(bar_canvas) and bar_canvas.visible:
		_update_bar_positions()
	#pass


func _on_body_entered(body: Node2D) -> void:
	#print(body_entered)
	#print(body)
	collision.emit(body)
	
func _physics_process(delta):
		
	if is_dragging:
		
		var hit = false
		var mouse_screen = Global.world_to_screen(self, get_global_mouse_position())
		var ui_node = get_node_or_null("../../UI")
		if is_instance_valid(ui_node):
			var pallet = ui_node.get_node_or_null("MarginContainer/VBoxContainer/PalletContainer")
			if is_instance_valid(pallet) and pallet.get_global_rect().has_point(mouse_screen):
				hit = true
			var margin = ui_node.get_node_or_null("MarginContainer")
			if is_instance_valid(margin) and margin.get_global_rect().has_point(mouse_screen):
				hit = true
		if hit==true:
			queue_free()
			return
	
		var t = min(1.0, delay * delta)
		position = position.lerp(get_global_mouse_position(), t)
		_update_bar_positions()
	
func _input(event):
	if false:
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
		
	else:
		wait_for_rain = random.randi_range(1, 50)
		is_raining = true
		var tween = get_tree().create_tween()
		tween.tween_property(sprite, "modulate:a", 1, 0.5)
		#tween.set_parallel(true)
		#$Sprite2D.modulate.a = 1
	$DryTimer.set_wait_time(wait_for_rain)
