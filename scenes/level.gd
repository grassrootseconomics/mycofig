extends Node2D

#to run: python3 -m http.server  .. browse to localhost:8000

const LevelHelpersRef = preload("res://scenes/level_helpers.gd")
const TEX_SQUASH = preload("res://graphics/squash.png")
const TEX_TREE = preload("res://graphics/baobab.png")
const TEX_MAIZE = preload("res://graphics/maize.png")
const TEX_BEAN = preload("res://graphics/bean.png")
const TEX_CLOUD = preload("res://graphics/cloud.png")
const TEX_MYCO = preload("res://graphics/mushroom_32.png")

var plant_scene: PackedScene = load("res://scenes/plant.tscn")
var trade_scene: PackedScene = load("res://scenes/trade.tscn")
var myco_scene: PackedScene = load("res://scenes/myco.tscn")
var cloud_scene: PackedScene = load("res://scenes/cloud.tscn")
var bird_scene: PackedScene = load("res://scenes/bird.tscn")
var tuktuk_scene: PackedScene = load("res://scenes/tuktuk.tscn")
var ui_scene: PackedScene = load("res://scenes/ui.tscn")


var mid_width = 0
var mid_height = 0

var health : int = 3

var score_lvl = 0

var num_maize = 1
var num_beans = 1
var num_squash = 1

var is_dragging = false
var delay = 10
var inventory_preview_lines: Array = []


func _get_world_foundation() -> Node:
	return get_node_or_null("WorldFoundation")


func _get_world_center() -> Vector2:
	var world = _get_world_foundation()
	if is_instance_valid(world) and world.has_method("get_world_center"):
		return world.get_world_center()
	return Global.get_world_center(self)


func _resolve_tile_spawn_pos(pos: Vector2) -> Vector2:
	return LevelHelpersRef.resolve_snapped_spawn_position(self, $Agents, pos)


func _resolve_exact_tile_spawn_pos(pos: Vector2, ignore_agent: Variant = null) -> Dictionary:
	var result := {
		"ok": true,
		"pos": pos
	}
	var world = _get_world_foundation()
	if not is_instance_valid(world):
		return result
	if not (world.has_method("world_to_tile") and world.has_method("tile_to_world_center") and world.has_method("in_bounds")):
		return result
	var coord = Vector2i(world.world_to_tile(pos))
	if not world.in_bounds(coord):
		result["ok"] = false
		return result
	if LevelHelpersRef.is_tile_occupied(self, $Agents, coord, ignore_agent):
		result["ok"] = false
		return result
	result["pos"] = world.tile_to_world_center(coord)
	return result


func _find_replaceable_agent_at_world_pos(pos: Vector2, ignore_agent: Variant = null) -> Node:
	var world = _get_world_foundation()
	if not is_instance_valid(world):
		return null
	if not (world.has_method("world_to_tile") and world.has_method("tile_to_world_center") and world.has_method("in_bounds")):
		return null
	var coord = Vector2i(world.world_to_tile(pos))
	if not world.in_bounds(coord):
		return null
	for agent in $Agents.get_children():
		if not is_instance_valid(agent):
			continue
		if is_instance_valid(ignore_agent) and agent == ignore_agent:
			continue
		if bool(agent.get("dead")):
			continue
		if str(agent.get("type")) == "cloud":
			continue
		if not bool(agent.get("killable")):
			continue
		var occupied_tiles = LevelHelpersRef.get_agent_occupied_tiles(self, agent)
		if occupied_tiles.has(coord):
			return agent
	return null


func _supports_world_tiles(world: Node) -> bool:
	if not is_instance_valid(world):
		return false
	return world.has_method("world_to_tile") and world.has_method("tile_to_world_center") and world.has_method("in_bounds")


func _clamp_tile_coord(world: Node, coord: Vector2i) -> Vector2i:
	var columns = max(int(world.get("columns")), 1)
	var rows = max(int(world.get("rows")), 1)
	return Vector2i(
		clampi(coord.x, 0, columns - 1),
		clampi(coord.y, 0, rows - 1)
	)


func _tile_pos_from_center(world: Node, center: Vector2i, delta: Vector2i) -> Vector2:
	var coord = _clamp_tile_coord(world, center + delta)
	return world.tile_to_world_center(coord)


func _ready():
	#get_tree().call_group('ui','set_health',health)
	#var num_maize = $Agents.get_children().size()
	#if num_maize <= 5:
	#var uix = ui_scene.instantiate()
	#uix.connect('new_agent',_on_new_agent)
	$UI.connect('new_agent',_on_new_agent)
	$UI.connect("inventory_drag_preview", _on_inventory_drag_preview)
	$UI.setup()
	Global.prevent_auto_select = false
	DisplayServer.window_set_title("Plants Gardening")
	$BirdLong.play()
	var world = _get_world_foundation()
	if is_instance_valid(world) and world.has_method("set_context"):
		world.set_context(Global.mode, "plants")
	#$BirdLong.
		 
	$"UI/TutorialMarginContainer1".visible = false
	if(Global.mode == "tutorial"):
		$"UI/TutorialMarginContainer1".visible=true
		$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
		$"UI/TutorialMarginContainer1/ColorRect".color = Global.stage_colors[Global.stage]

	var world_center = _get_world_center()
	mid_width = int(world_center.x)
	mid_height = int(world_center.y)

	var myco = null
	var clustered_start = Global.mode == "tutorial" or Global.mode == "challenge"
	if clustered_start and _supports_world_tiles(world):
		var center_coord = _clamp_tile_coord(world, Vector2i(world.world_to_tile(world_center)))
		var myco_position = _tile_pos_from_center(world, center_coord, Vector2i(0, 0))
		var bean_position = _tile_pos_from_center(world, center_coord, Vector2i(-1, 0))
		var squash_position = _tile_pos_from_center(world, center_coord, Vector2i(0, -1))
		var maize_position = _tile_pos_from_center(world, center_coord, Vector2i(1, 0))
		var tree_position = _tile_pos_from_center(world, center_coord, Vector2i(0, 1))

		myco = make_myco(myco_position)
		make_bean(bean_position)
		make_squash(squash_position)
		make_maize(maize_position)
		make_tree(tree_position)
	else:
		var maize_center_offset_x = 75
		var maize_center_offset_y = 65
		var maize_position = Vector2(mid_width + maize_center_offset_x, mid_height + maize_center_offset_y)
		make_maize(maize_position)

		var bean_center_offset_x = -75
		var bean_center_offset_y = 0
		var bean_position = Vector2(mid_width + bean_center_offset_x, mid_height + bean_center_offset_y)
		make_bean(bean_position)

		var squash_center_offset_x = 0
		var squash_center_offset_y = -90
		var squash_position = Vector2(mid_width + squash_center_offset_x, mid_height + squash_center_offset_y)
		make_squash(squash_position)

		var tree_center_offset_x = 75
		var tree_center_offset_y = -50
		var tree_position = Vector2(mid_width + tree_center_offset_x, mid_height + tree_center_offset_y)
		make_tree(tree_position)

		var myco_width = mid_width + 40
		var myco_height = mid_height + 100
		var myco_position = Vector2(myco_width, myco_height)
		myco = make_myco(myco_position)

	Global.active_agent = myco
	
	if(Global.is_raining == true):
		var cloud_width = mid_width + 250
		var cloud_height = mid_height - 300
		var cloud_position = Vector2(cloud_width,cloud_height)

		make_cloud(cloud_position)

	
	#var bird = bird_scene.instantiate()
	#bird.set_variables(cloud_dict)
	#$Animals.add_child(bird)
	#cloud.connect('trade', _on_agent_trade)


	#var cloud = cloud_scene.instantiate()
	#$Agents.add_child(cloud)
	#cloud.connect('trade', _on_agent_trade)
	
			
func _input(event):
	if LevelHelpersRef.handle_gameplay_hotkeys(event, self, $Agents, false):
		return


func _process(_delta: float) -> void:
	LevelHelpersRef.refresh_trade_line_visuals($Lines)


func _on_inventory_drag_preview(agent_name: String, world_pos: Vector2, active: bool) -> void:
	LevelHelpersRef.update_inventory_connection_preview(self, $Agents, $Lines, inventory_preview_lines, agent_name, world_pos, active)
				
				
				
				



func _on_player_laser(path_dict) -> void:
	pass
	#var trade = trade_scene.instantiate()
	#trade.set_variables(path_dict)
	#print(" trade created: ", path_dict["from_agent"], " ", path_dict)
	#$Trades.add_child(trade)
	
func _on_agent_trade(path_dict) -> void:
	call_deferred("_spawn_trade", path_dict)


func _spawn_trade(path_dict) -> void:
	#print("Found Trade signal dict: ", path_dict)
	var trade = trade_scene.instantiate()
	trade.set_variables(path_dict)
	$Trades.add_child(trade)
	
func update_bars(path_dict)  -> void:
	if is_instance_valid(Global.active_agent) and is_instance_valid(path_dict["from_agent"]) and is_instance_valid(path_dict["to_agent"]):  
		if Global.active_agent.name == path_dict["from_agent"].name or Global.active_agent.name == path_dict["to_agent"].name:
			for label in $UI.resContainer.get_children():
				#print("g. << inside asadas: ", label.name, " : ", label.text, path_dict["trade_asset"])
				if label.name == path_dict["trade_asset"]:
					#print("h. ><><< inside asadas, lable", label.name, " : ", label.text)
					label.text = str(path_dict["trade_asset"]) + str(" ") + str(Global.active_agent.assets[path_dict["trade_asset"]])


func _play_predator_alert() -> void:
	if(Global.social_mode):
		$CarSound.play()
	else:
		$BirdSound.play()


func _spawn_predators(requested_count: int, play_alert: bool = false) -> void:
	var spawn_count = max(requested_count, 0)
	if Global.is_mobile_platform:
		spawn_count = min(spawn_count, Global.max_predators_per_wave_mobile)
	if spawn_count <= 0:
		return
	if play_alert:
		_play_predator_alert()
	for _i in range(spawn_count):
		make_bird()
					
func _on_update_score() -> void:
	var current_score_lvl := Global.get_rank_threshold(Global.score)
	if current_score_lvl > score_lvl:
		score_lvl = current_score_lvl
		#print("create birds: ", Global.birds[score_lvl])
		if(Global.is_birding == true):
			Global.rand_quarry.shuffle()
			var z_quarry = Global.rand_quarry[0]
			Global.quarry_type = z_quarry
			_spawn_predators(Global.get_predator_spawn_count(score_lvl), true)
	if(Global.mode == "challenge" and Global.ranks[current_score_lvl] == "Grassroots Economist"):
		get_tree().call_deferred("change_scene_to_file","res://scenes/game_over.tscn")
		

func _on_new_agent(agent_dict) -> void:
	#print("found signal: ", agent_dict)
	var new_agent = null
	var spawn_pos = agent_dict["pos"]
	var ignore_agent = agent_dict.get("ignore_agent", null)
	var require_exact_tile = bool(agent_dict.get("require_exact_tile", false))
	if bool(agent_dict.get("allow_replace", false)):
		var replace_target = _find_replaceable_agent_at_world_pos(spawn_pos, ignore_agent)
		if is_instance_valid(replace_target):
			ignore_agent = replace_target
			if replace_target.has_method("kill_it"):
				replace_target.kill_it()
			else:
				replace_target.call_deferred("queue_free")
			require_exact_tile = true
	if require_exact_tile:
		var exact_spawn = _resolve_exact_tile_spawn_pos(spawn_pos, ignore_agent)
		if not bool(exact_spawn["ok"]):
			return
		spawn_pos = exact_spawn["pos"]
	if agent_dict["name"]  == "squash":
		$TwinkleSound.play()
		new_agent = make_squash(spawn_pos)
	elif agent_dict["name"]  == "bean":
		$TwinkleSound.play()
		new_agent = make_bean(spawn_pos)
	elif agent_dict["name"]  == "maize":
		$TwinkleSound.play()
		new_agent = make_maize(spawn_pos)
	elif agent_dict["name"]  == "myco":
		$SquelchSound.play()
		new_agent = make_myco(spawn_pos)
	elif agent_dict["name"]  == "tree":
		$BushSound.play()
		new_agent = make_tree(spawn_pos)
	
	if is_instance_valid(new_agent):
		if agent_dict.has("spawn_anchor"):
			LevelHelpersRef.ensure_spawn_buddy_link(new_agent, agent_dict["spawn_anchor"])
		LevelHelpersRef.mark_all_buddies_dirty($Agents)
		LevelHelpersRef.mark_myco_lines_dirty($Agents)
	if(Global.active_agent == null and not Global.prevent_auto_select):
		Global.active_agent = new_agent
			
func make_squash(pos):
	#print("Clicked On Squash. making")
	
	var squash_position = _resolve_tile_spawn_pos(pos)
	
	var named = "Squash_" + str($Agents.get_child_count()+1)
	
	var squash_dict = {
		"name": named,
		"type": "squash",
		"position": squash_position,
		"prod_res": ["P"],
		"start_res": null,
		"texture": TEX_SQUASH
	}
	
	var squash = plant_scene.instantiate()
	squash.set_variables(squash_dict)
	$Agents.add_child(squash)
	LevelHelpersRef.connect_core_agent_signals(squash, _on_agent_trade, _on_new_agent, _on_update_score)
	LevelHelpersRef.mark_myco_lines_dirty($Agents)
	
	return squash

func make_tree(pos):
	#print("Clicked On Squash. making")
	
	var tree_position = _resolve_tile_spawn_pos(pos)
	
	var named = "Tree_" + str($Agents.get_child_count()+1)
	
	var tree_dict = {
		"name": named,
		"type": "tree",
		"position": tree_position,
		"prod_res": ["R"],
		"start_res": null,
		"texture": TEX_TREE
	}
	var tree = plant_scene.instantiate()
	tree.set_variables(tree_dict)
	$Agents.add_child(tree)
	tree.position = LevelHelpersRef.resolve_snapped_position_for_agent(self, $Agents, tree, tree_position)
	LevelHelpersRef.connect_core_agent_signals(tree, _on_agent_trade, _on_new_agent, _on_update_score)
	LevelHelpersRef.mark_myco_lines_dirty($Agents)
	return tree
	
	
func make_bird():
	call_deferred("_spawn_bird")


func _spawn_bird():
	var bird = null
	if(Global.social_mode):
		bird = tuktuk_scene.instantiate()
	else:
		bird = bird_scene.instantiate()
	$Animals.add_child(bird)

	
func make_maize(pos):
	var maize_position = _resolve_tile_spawn_pos(pos)
	
	var named = "Maize_" + str($Agents.get_child_count()+1)
	
	var maize_dict = {
		"name": named,
		"type": "maize",
		"position": maize_position,
		"prod_res": ["K"],
		"start_res": null,
		"texture": TEX_MAIZE
	}
	var maize = plant_scene.instantiate()
	maize.set_variables(maize_dict)
	$Agents.add_child(maize)
	LevelHelpersRef.connect_core_agent_signals(maize, _on_agent_trade, _on_new_agent, _on_update_score)
	LevelHelpersRef.mark_myco_lines_dirty($Agents)
	
	return maize
		
func make_bean(pos):
	
	var bean_position = _resolve_tile_spawn_pos(pos)
	
	var named = "Bean_" + str($Agents.get_child_count()+1)
	
	var bean_dict = {
		"name": named,
		"type": "bean",
		"position": bean_position,
		"prod_res": ["N"],
		"start_res": null,
		"texture": TEX_BEAN
	}
	var bean = plant_scene.instantiate()
	bean.set_variables(bean_dict)
	$Agents.add_child(bean)
	LevelHelpersRef.connect_core_agent_signals(bean, _on_agent_trade, _on_new_agent, _on_update_score)
	LevelHelpersRef.mark_myco_lines_dirty($Agents)
	
	return bean


func make_cloud(pos):
	
	var named = "Cloud_" + str($Agents.get_child_count()+1)
	
	var cloud_dict = {
		"name": named,
		"type": "cloud",
		"position": pos,
		"prod_res": ["R"],
		"start_res": 20,
		"texture": TEX_CLOUD
	}
	var cloud = cloud_scene.instantiate()
	cloud.set_variables(cloud_dict)
	$Agents.add_child(cloud)
	if cloud.has_signal("trade"):
		cloud.connect("trade", _on_agent_trade)
	
	return cloud


func make_myco(pos):
	var myco_position = _resolve_tile_spawn_pos(pos)
	
	var named = "Mycorrhizal_" + str($Agents.get_child_count()+1)
		
	
	var myco_dict = {
		"name": named,
		"type": "myco",
		"position": myco_position,
		"prod_res": [null],
		"start_res": null,
		"texture": TEX_MYCO
	}
	
	var myco = myco_scene.instantiate()
	myco.set_variables(myco_dict)
	myco.sprite_texture = TEX_MYCO
	$Agents.add_child(myco)
	
	if myco.has_signal("trade"):
		myco.connect("trade", _on_agent_trade)
	LevelHelpersRef.mark_all_buddies_dirty($Agents)
	
	return myco
	
	


func _on_tutorial_timer_timeout() -> void:
	if(Global.mode == "tutorial"):
		#print("mode: ", Global.mode, "stage: ", Global.stage)
		if( Global.stage == 1):
			
			var c_buds = 0
			for child in $Agents.get_children():
				if(child.type!="myco"):
					c_buds += len(child.trade_buddies)
				#print(" child bud: ", child.name, " ", child.trade_buddies)
			#print("len buds: ", c_buds)
			if(c_buds >=4):
				Global.stage += 1
				$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
				$"UI/TutorialMarginContainer1/ColorRect".color = Global.stage_colors[Global.stage]
				
		elif(Global.stage == 2):
			
			var c_buds = 0
			var num_myco = 0
			for child in $Agents.get_children():
				if(child.type=="myco"):
					num_myco += 1
			if(num_myco >=2):
				Global.stage += 1
				$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
				$"UI/TutorialMarginContainer1/ColorRect".color = Global.stage_colors[Global.stage]
		elif(Global.stage == 3):
			
			var c_buds = 0
			var num_myco = 0
			for child in $Agents.get_children():
				if(child.type=="myco"):
					num_myco += 1
					c_buds += len(child.trade_buddies)
					#print(" child bud: ", child.name, " ", child.trade_buddies)
			if(num_myco >= 3 and c_buds >=2):
				Global.stage += 1
				$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
				$"UI/TutorialMarginContainer1/ColorRect".color = Global.stage_colors[Global.stage]
		elif(Global.stage == 4):
			
			var c_maize = 0
			for child in $Agents.get_children():
				if(child.type=="maize" and child.dead==false):
					c_maize += 1
			
			_spawn_predators(c_maize * 3, true)
				
			Global.stage = 4.1
			
		elif(Global.stage == 4.1):
			var c_maize = 0
			for child in $Agents.get_children():
				if(child.type=="maize" and child.dead==false):
					c_maize += 1
			
			if(c_maize >=3):
				Global.stage = 5
				$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
				$"UI/TutorialMarginContainer1/ColorRect".color = Global.stage_colors[Global.stage]
		
		elif(Global.stage == 5):
			
			var c_maize = 0
			for child in $Agents.get_children():
				if(child.type=="maize" and child.dead==false):
					c_maize += 1
			
			_spawn_predators(c_maize - 1, true)
				
			Global.stage = 5.1
			
		elif(Global.stage == 5.1):
			var c_maize = 0
			for child in $Agents.get_children():
				if(child.type=="maize" and child.dead==false):
					c_maize += 1
			
			
			
			if(c_maize >=2 and Global.values['K']>1):
				Global.stage = 6
				$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
				$"UI/TutorialMarginContainer1/ColorRect".color = Global.stage_colors[Global.stage]
				
		elif(Global.stage == 6):
			
			
			var c_maize = 0
			for child in $Agents.get_children():
				if(child.type=="maize" and child.dead==false):
					c_maize += 1
			
			_spawn_predators(c_maize - 1)
			Global.stage_inc+=1
			if(Global.stage_inc>=Global.max_stage_inc):
				Global.stage = 6.1
				Global.stage_inc = 0
			
		elif(Global.stage == 6.1):
			var c_maize = 0
			for child in $Agents.get_children():
				if(child.type=="maize" and child.dead==false):
					c_maize += 1
			
			
			
			if(c_maize >=2 and Global.values['K']>1):
				Global.stage = 7
				$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
				$"UI/TutorialMarginContainer1/ColorRect".color = Global.stage_colors[Global.stage]
		
		elif(Global.stage == 7):
			
			var c_maize = 0
			for child in $Agents.get_children():
				if(child.type=="maize" and child.dead==false):
					c_maize += 1
					
			if(c_maize >=2 and Global.values['K']<=1.1):
				Global.stage = 8
				$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
				$"UI/TutorialMarginContainer1/ColorRect".color = Global.stage_colors[Global.stage]
				$"UI/RestartContainer".visible=true


func _exit_tree() -> void:
	_release_audio()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_release_audio()


func _release_audio() -> void:
	LevelHelpersRef.clear_inventory_connection_preview_lines(inventory_preview_lines)
	LevelHelpersRef.stop_audio_players([
		$BirdSound,
		$BirdLong,
		$CarSound,
		$SquelchSound,
		$TwinkleSound,
		$BushSound
	])
		
						
			
		
