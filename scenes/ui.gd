extends CanvasLayer
var time_elapsed := 0

#signal sliderChanged(info_dict)
signal new_agent(agent_dict)
signal inventory_drag_preview(agent_name, world_pos, active)

var sliders = []

var last_agent = null

var next_agent = null
var resContainer = null
var drag_preview_sprite: Sprite2D = null
var inventory_spawn_rng := RandomNumberGenerator.new()
const AUTO_SPAWN_ATTEMPTS := 96
const AUTO_SPAWN_SWEEP_STEPS := 48

func _ready() -> void:
	#$PalletContainer2/HBoxContainer/ActiveTexture.texture = Global.active_agent.sprite_texture
	#resContainer = $MarginContainer/HBoxContainer/ResVBoxContainer
	inventory_spawn_rng.randomize()
	_ensure_drag_preview()

var clicked_slider = false
var mouseOverMyco = false
var mouseOverSquash = false
var mouseOverBean = false
var mouseOverMaize = false
var mouseOverCloud = false
var mouseOverTree = false



var inventory_labels = { #how many of each plant do we have to use
	"bean": null,
	"squash": null,				
	"maize": null,
	"tree": null,
	"myco": null
	}

var inventory_sprites = { #how many of each plant do we have to use
	"bean": null,
	"squash": null,				
	"maize": null,
	"tree": null,
	"myco": null
	}


func setup():
	
	
	inventory_labels = { #how many of each plant do we have to use
	"bean": $MarginContainer/VBoxContainer/PalletContainer/VBoxContainer/HBoxContainer/VBoxContainer/BeanInv,
	"squash": $MarginContainer/VBoxContainer/PalletContainer/VBoxContainer/HBoxContainer/VBoxContainer2/SquashInv,
	"maize": $MarginContainer/VBoxContainer/PalletContainer/VBoxContainer/HBoxContainer/VBoxContainer3/MaizeInv,
	"tree":  $MarginContainer/VBoxContainer/PalletContainer/VBoxContainer/HBoxContainer/VBoxContainer4/TreeInv,
	"myco": $MarginContainer/VBoxContainer/PalletContainer/VBoxContainer/HBoxContainer/VBoxContainer5/MycoInv
	}
	inventory_sprites = { #how many of each plant do we have to use
	"bean": $MarginContainer/VBoxContainer/PalletContainer/VBoxContainer/HBoxContainer/VBoxContainer/ChooseBeans,
	"squash": $MarginContainer/VBoxContainer/PalletContainer/VBoxContainer/HBoxContainer/VBoxContainer2/ChooseSquash,
	"maize": $MarginContainer/VBoxContainer/PalletContainer/VBoxContainer/HBoxContainer/VBoxContainer3/ChooseMaize,
	"tree":  $MarginContainer/VBoxContainer/PalletContainer/VBoxContainer/HBoxContainer/VBoxContainer4/ChooseTree,
	"myco": $MarginContainer/VBoxContainer/PalletContainer/VBoxContainer/HBoxContainer/VBoxContainer5/ChooseMyco
	}
	if(Global.social_mode):
		for invs in inventory_sprites:
			if(invs=="bean"):
				inventory_sprites[invs].texture = load("res://graphics/farmer.png")
			elif(invs=="squash"):
				inventory_sprites[invs].texture = load("res://graphics/mama.png")
			elif(invs=="maize"):
				inventory_sprites[invs].texture = load("res://graphics/cook.png")
			elif(invs=="tree"):
				inventory_sprites[invs].texture = load("res://graphics/bank.png")
				inventory_sprites[invs].visible = false
				inventory_labels[invs].visible = false
			elif(invs=="myco"):
				inventory_sprites[invs].texture = load("res://graphics/basket.png")
	refresh_inventory_counts()
		
	
	sliders = []
	
	#var assets = agent.assets
	var resContainer = $MarginContainer/VBoxContainer/HBoxContainer/ResVBoxContainer
	var valContainer = $MarginContainer/VBoxContainer/HBoxContainer/ValVBoxContainer
	
	for child in resContainer.get_children():
		child.queue_free()
		await child.tree_exited
	for child in valContainer.get_children():
		child.queue_free()
		await child.tree_exited
	

	var assetLabel = Label.new()
	assetLabel.text = "Resource"
	assetLabel.name = "Title"
	assetLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resContainer.add_child(assetLabel)
	
	var valLabel = Label.new()
	valLabel.text = "Relative Value"
	valLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	valContainer.add_child(valLabel)
	

	for asset in Global.values:
		var resText = Label.new()
		resText.name = str(asset)
		if(Global.social_mode==true):
			resText.text = str(Global.assets_social[asset]) + str(" ") + str(Global.values[asset])
		else:
			resText.text = str(Global.assets_plant[asset]) + str(" ") + str(Global.values[asset])
		resText.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		resContainer.add_child(resText)
		
		
		var valSlider = HSlider.new()
		valSlider.min_value = 1
		valSlider.max_value = 300
		valSlider.value = Global.values[asset]*100
		valSlider.modulate= Global.asset_colors[asset]
		valSlider.tick_count =4
		valSlider.ticks_on_borders = true
		
		valContainer.add_child(valSlider)
		var passed = {
			"slider":valSlider,
			"res": asset
		}
		valSlider.connect("drag_ended",_on_h_slider_drag_ended)
		sliders.append(passed)
		#print (" ui process: ", sliders)


func refresh_inventory_counts() -> void:
	for inv in inventory_labels:
		if is_instance_valid(inventory_labels[inv]):
			inventory_labels[inv].text = str(int(Global.inventory.get(inv, 0)))
		if is_instance_valid(inventory_sprites[inv]):
			if int(Global.inventory.get(inv, 0)) < 1:
				inventory_sprites[inv].modulate.a = 0.5
			else:
				inventory_sprites[inv].modulate.a = 1.0



func _process(delta: float) -> void:
	pass	
func _on_score_timer_timeout() -> void:
	#time_elapsed += 1
	#Global.score += 1
	$EndGameContainer/Label.text=str(Global.score)
	


func _on_h_slider_drag_ended(value_changed: bool) -> void:
	#print("sliders:", sliders)
	clicked_slider = true
	for slider in sliders:
		#var agent = slider["agent"]
		var res = slider["res"]
		#if(is_instance_valid(agent)):
		#print("slider value:", slider["slider"].value, slider)
		Global.values[res] = slider["slider"].value/100
				
		for label in $MarginContainer/VBoxContainer/HBoxContainer/ResVBoxContainer.get_children():
			#print("g. << inside asadas: ", label.name, " : ", label.text, path_dict["trade_asset"])
			if label.name == res:
				#print("h. ><><< inside asadas, lable", label.name, " : ", label.text)
				if(Global.social_mode==true):
					label.text = Global.assets_social[res] + str(" ") + str(Global.values[res])
				else:
					label.text = Global.assets_plant[res] + str(" ") + str(Global.values[res])
		



func _ensure_drag_preview() -> void:
	if is_instance_valid(drag_preview_sprite):
		return
	drag_preview_sprite = Sprite2D.new()
	drag_preview_sprite.visible = false
	drag_preview_sprite.centered = true
	drag_preview_sprite.z_as_relative = false
	drag_preview_sprite.z_index = 200
	drag_preview_sprite.modulate = Color(1,1,1,0.85)
	add_child(drag_preview_sprite)


func _get_inventory_agent_at(mouse_pos: Vector2) -> String:
	for agent_name in inventory_sprites:
		var icon = inventory_sprites[agent_name]
		if not is_instance_valid(icon):
			continue
		if not icon.visible:
			continue
		if icon.get_global_rect().has_point(mouse_pos):
			return agent_name
	return ""


func _start_inventory_drag(agent_name: String, mouse_pos: Vector2) -> void:
	_ensure_drag_preview()
	var icon = inventory_sprites.get(agent_name)
	if is_instance_valid(icon):
		drag_preview_sprite.texture = icon.texture
	drag_preview_sprite.global_position = mouse_pos
	drag_preview_sprite.visible = true


func _update_inventory_drag(mouse_pos: Vector2) -> void:
	if is_instance_valid(drag_preview_sprite) and drag_preview_sprite.visible:
		drag_preview_sprite.global_position = mouse_pos


func _end_inventory_drag() -> void:
	if is_instance_valid(drag_preview_sprite):
		drag_preview_sprite.visible = false
		drag_preview_sprite.texture = null


func _get_agents_root() -> Node:
	return get_node_or_null("../Agents")


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return Global.screen_to_world(self, screen_pos)


func _world_to_screen(world_pos: Vector2) -> Vector2:
	return Global.world_to_screen(self, world_pos)


func _get_world_rect() -> Rect2:
	return Global.get_world_rect(self)


func _emit_inventory_drag_preview(agent_name: String, screen_pos: Vector2, active: bool) -> void:
	if not active:
		emit_signal("inventory_drag_preview", agent_name, Vector2.ZERO, false)
		return
	var view = get_viewport().get_visible_rect()
	if not view.has_point(screen_pos):
		emit_signal("inventory_drag_preview", agent_name, Vector2.ZERO, false)
		return
	if $MarginContainer.get_global_rect().has_point(screen_pos):
		emit_signal("inventory_drag_preview", agent_name, Vector2.ZERO, false)
		return
	var world_pos = _screen_to_world(screen_pos)
	var world_rect = _get_world_rect()
	if not world_rect.has_point(world_pos):
		emit_signal("inventory_drag_preview", agent_name, Vector2.ZERO, false)
		return
	emit_signal("inventory_drag_preview", agent_name, world_pos, true)


func _get_agent_edge_radius(agent: Node) -> float:
	var radius := 24.0
	var sprite_node = agent.get("sprite")
	if is_instance_valid(sprite_node) and sprite_node.has_method("get_rect"):
		var rect = sprite_node.get_rect()
		var sx = abs(sprite_node.scale.x)
		var sy = abs(sprite_node.scale.y)
		radius = max(rect.size.x * sx, rect.size.y * sy) * 0.5
	elif agent.has_node("Sprite2D"):
		var sprite_child = agent.get_node("Sprite2D")
		if is_instance_valid(sprite_child) and sprite_child.has_method("get_rect"):
			var child_rect = sprite_child.get_rect()
			var csx = abs(sprite_child.scale.x)
			var csy = abs(sprite_child.scale.y)
			radius = max(child_rect.size.x * csx, child_rect.size.y * csy) * 0.5
	return max(radius, 16.0)


func _get_anchor_reach_radius(anchor: Node) -> float:
	var reach := 0.0
	var reach_value = anchor.get("buddy_radius")
	if typeof(reach_value) == TYPE_FLOAT or typeof(reach_value) == TYPE_INT:
		reach = float(reach_value)
	if reach <= 0.0:
		reach = _get_agent_edge_radius(anchor) + 24.0
	return max(reach, 24.0)


func _get_reach_anchors(agents_root: Node) -> Array:
	var anchors: Array = []
	if not is_instance_valid(agents_root):
		return anchors
	for agent in agents_root.get_children():
		if not is_instance_valid(agent):
			continue
		if agent.get("dead") == true:
			continue
		if agent.get("type") == "myco":
			anchors.append(agent)
	return anchors


func _is_valid_auto_spawn_position(pos: Vector2, agents_root: Node, anchor: Node = null) -> bool:
	var world_rect = _get_world_rect()
	if not world_rect.has_point(pos):
		return false
	var pos_screen = _world_to_screen(pos)
	var view = get_viewport().get_visible_rect()
	if view.has_point(pos_screen) and $MarginContainer.get_global_rect().has_point(pos_screen):
		return false
	if is_instance_valid(anchor):
		var reach = _get_anchor_reach_radius(anchor)
		var distance_to_anchor = anchor.global_position.distance_to(pos)
		if abs(distance_to_anchor - reach) > 1.5:
			return false
	if is_instance_valid(agents_root):
		for agent in agents_root.get_children():
			if not is_instance_valid(agent):
				continue
			if agent.get("dead") == true:
				continue
			var min_dist = _get_agent_edge_radius(agent) + 6.0
			if agent.global_position.distance_to(pos) < min_dist:
				return false
	return true


func _get_auto_spawn_target() -> Dictionary:
	var target = {
		"pos": Vector2.ZERO,
		"anchor": null
	}
	var agents_root = _get_agents_root()
	var anchors = _get_reach_anchors(agents_root)
	var world_rect = _get_world_rect()
	if anchors.is_empty():
		target["pos"] = world_rect.position + world_rect.size * 0.5
		return target
	for _attempt in range(AUTO_SPAWN_ATTEMPTS):
		var anchor = anchors[inventory_spawn_rng.randi_range(0, anchors.size() - 1)]
		var dist = _get_anchor_reach_radius(anchor)
		var angle = inventory_spawn_rng.randf_range(0.0, TAU)
		var candidate = anchor.global_position + Vector2.RIGHT.rotated(angle) * dist
		if _is_valid_auto_spawn_position(candidate, agents_root, anchor):
			target["pos"] = candidate
			target["anchor"] = anchor
			return target
	for anchor in anchors:
		var dist = _get_anchor_reach_radius(anchor)
		var start_angle = inventory_spawn_rng.randf_range(0.0, TAU)
		for idx in range(AUTO_SPAWN_SWEEP_STEPS):
			var angle = start_angle + (TAU * float(idx) / float(AUTO_SPAWN_SWEEP_STEPS))
			var candidate = anchor.global_position + Vector2.RIGHT.rotated(angle) * dist
			if _is_valid_auto_spawn_position(candidate, agents_root, anchor):
				target["pos"] = candidate
				target["anchor"] = anchor
				return target
	var fallback_anchor = anchors[inventory_spawn_rng.randi_range(0, anchors.size() - 1)]
	var toward_center = world_rect.get_center() - fallback_anchor.global_position
	if toward_center.length() < 0.001:
		toward_center = Vector2.RIGHT
	var fallback_pos = fallback_anchor.global_position + toward_center.normalized() * _get_anchor_reach_radius(fallback_anchor)
	if _is_valid_auto_spawn_position(fallback_pos, agents_root, fallback_anchor):
		target["pos"] = fallback_pos
		target["anchor"] = fallback_anchor
		return target
	target["pos"] = world_rect.position + world_rect.size * 0.5
	return target


func _drop_inventory_agent(drop_pos: Vector2) -> void:
	if next_agent == null:
		return
	if Global.inventory[next_agent] <= 0:
		return
	var target_pos = _screen_to_world(drop_pos)
	var spawn_anchor = null
	var allow_replace = true
	var view = get_viewport().get_visible_rect()
	if $MarginContainer.get_global_rect().has_point(drop_pos) or not view.has_point(drop_pos):
		var auto_target = _get_auto_spawn_target()
		target_pos = auto_target["pos"]
		spawn_anchor = auto_target["anchor"]
		allow_replace = false
	var new_agent_dict = {
		"name" : next_agent,
		"pos": target_pos,
		"allow_replace": allow_replace
	}
	if is_instance_valid(spawn_anchor):
		new_agent_dict["spawn_anchor"] = spawn_anchor
	emit_signal("new_agent", new_agent_dict)
	Global.inventory[next_agent] -=1
	refresh_inventory_counts()


func _input(event):
	if event is InputEventMouseMotion:
		if next_agent != null:
			_update_inventory_drag(event.position)
			_emit_inventory_drag_preview(next_agent, event.position, true)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var selected = _get_inventory_agent_at(event.position)
			if selected != "" and Global.inventory[selected] > 0:
				next_agent = selected
				_start_inventory_drag(selected, event.position)
				_emit_inventory_drag_preview(selected, event.position, true)
		else:
			if next_agent != null:
				_drop_inventory_agent(event.position)
				_emit_inventory_drag_preview(next_agent, event.position, false)
			next_agent = null
			_end_inventory_drag()


func _on_choose_myco_mouse_entered() -> void:
	mouseOverMyco = true
	


func _on_choose_myco_mouse_exited() -> void:
	mouseOverMyco = false


func _on_choose_squash_mouse_entered() -> void:
	mouseOverSquash = true


func _on_choose_maize_mouse_entered() -> void:
	mouseOverMaize = true


func _on_choose_squash_mouse_exited() -> void:
	mouseOverSquash = false


func _on_choose_maize_mouse_exited() -> void:
	mouseOverMaize = false


func _on_choose_beans_mouse_entered() -> void:
	mouseOverBean = true


func _on_choose_beans_mouse_exited() -> void:
	mouseOverBean = false



func _on_choose_tree_mouse_entered() -> void:
	mouseOverTree = true


func _on_choose_tree_mouse_exited() -> void:
	mouseOverTree = false


func _on_button_pressed() -> void:
	Global.score = 0
	get_tree().call_deferred("change_scene_to_file","res://scenes/title_screen.tscn")
	


func _on_pause_button_pressed() -> void:
	var status = get_tree().paused
	get_tree().paused = not status
	if(status == true):
		$MarginCMarginContainer2ontainer/HBoxContainer/PauseButton.text = "Pause"
	else:
		$MarginCMarginContainer2ontainer/HBoxContainer/PauseButton.text = "Start"
