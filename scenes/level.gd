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

func _ready():
	#get_tree().call_group('ui','set_health',health)
	#var num_maize = $Agents.get_children().size()
	#if num_maize <= 5:
	#var uix = ui_scene.instantiate()
	#uix.connect('new_agent',_on_new_agent)
	$UI.connect('new_agent',_on_new_agent)
	$UI.setup()
	DisplayServer.window_set_title("Plants Gardening")
	$BirdLong.play()
	#$BirdLong.
		 
	$"UI/TutorialMarginContainer1".visible = false
	if(Global.mode == "tutorial"):
		$"UI/TutorialMarginContainer1".visible=true
		$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
		$"UI/TutorialMarginContainer1/ColorRect".color = Global.stage_colors[Global.stage]

	mid_width = int(get_viewport().get_visible_rect().size[0]/2)
	mid_height = int(get_viewport().get_visible_rect().size[1]/2)
	
	var maize_center_offset_x = 75
	var maize_center_offset_y = 65
	var maize_position = Vector2(mid_width+maize_center_offset_x,mid_height+maize_center_offset_y)
	
	make_maize(maize_position)

	
	var bean_center_offset_x = -75
	var bean_center_offset_y = 0
	var bean_position = Vector2(mid_width+bean_center_offset_x,mid_height+bean_center_offset_y)
	
	make_bean(bean_position)
	
	
	var squash_center_offset_x = 0
	var squash_center_offset_y = -90
	var squash_position = Vector2(mid_width+squash_center_offset_x,mid_height+squash_center_offset_y)
	
	make_squash(squash_position)
	
	var tree_center_offset_x = 75
	var tree_center_offset_y = -50
	var tree_position = Vector2(mid_width+tree_center_offset_x,mid_height+tree_center_offset_y)
	
	make_tree(tree_position)
	
	
	var myco_width = int(get_viewport().get_visible_rect().size[0]/2)+40
	var myco_height = int(get_viewport().get_visible_rect().size[1]/2)+100
	var myco_position = Vector2(myco_width,myco_height)

	var myco = make_myco(myco_position)

	Global.active_agent = myco
	
	if(Global.is_raining == true):
		var cloud_width = int(get_viewport().get_visible_rect().size[0]/2)+250
		var cloud_height = int(get_viewport().get_visible_rect().size[1]/2)-300
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
	
	if event is InputEventKey:
		if event.pressed: 
			if event.keycode == KEY_PLUS or event.keycode == KEY_EQUAL:
				Global.move_rate +=1
				Global.movement_speed+=50
			elif event.keycode == KEY_MINUS or event.keycode == KEY_UNDERSCORE: 
				Global.move_rate -=1
				Global.movement_speed-=50
				if Global.move_rate < 0:
					Global.move_rate = 0
					Global.movement_speed = 0
			elif event.keycode == KEY_ESCAPE or event.keycode == KEY_Q:
				
				get_tree().call_deferred("change_scene_to_file","res://scenes/game_over.tscn")
				
				
			elif event.keycode == KEY_B:
				Global.bars_on = not Global.bars_on
				#print("Bars on: ", Global.bars_on )
				
				for agent in $Agents.get_children():
					if agent.type != "myco":
						agent.bar_canvas.visible = Global.bars_on
			elif event.keycode == KEY_A:
				Global.baby_mode = not Global.baby_mode
			
			elif event.keycode == KEY_TAB:
				var index = 0
				var found_it = -1
				var agents = $Agents.get_children()
				for agent in agents:	
					if(is_instance_valid(Global.active_agent)):
						if(Global.active_agent.name == agent.name):
							found_it = index
							#print("found: ", found_it, " out of ", len(agents), " all agents: ", agents)
							break
					index +=1
				
				if(found_it >= len(agents)-1):
					found_it = 0
					#print("too high found: ", found_it)
					Global.active_agent = agents[found_it]
				else:
					Global.active_agent = agents[found_it+1]
				
				Global.active_agent.draw_box = true
				
				
				
				



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
	if agent_dict["name"]  == "squash":
		$TwinkleSound.play()
		new_agent = make_squash(agent_dict["pos"])
	elif agent_dict["name"]  == "bean":
		$TwinkleSound.play()
		new_agent = make_bean(agent_dict["pos"])
	elif agent_dict["name"]  == "maize":
		$TwinkleSound.play()
		new_agent = make_maize(agent_dict["pos"])
	elif agent_dict["name"]  == "myco":
		$SquelchSound.play()
		new_agent = make_myco(agent_dict["pos"])
	elif agent_dict["name"]  == "tree":
		$BushSound.play()
		new_agent = make_tree(agent_dict["pos"])
	
	if is_instance_valid(new_agent):
		if agent_dict.has("spawn_anchor"):
			LevelHelpersRef.ensure_spawn_buddy_link(new_agent, agent_dict["spawn_anchor"])
		LevelHelpersRef.mark_all_buddies_dirty($Agents)
		LevelHelpersRef.mark_myco_lines_dirty($Agents)
	if(Global.active_agent == null):
		Global.active_agent = new_agent
			
func make_squash(pos):
	#print("Clicked On Squash. making")
	
	var squash_position = pos
	
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
	
	
	var named = "Tree_" + str($Agents.get_child_count()+1)
	
	var tree_dict = {
		"name": named,
		"type": "tree",
		"position": pos,
		"prod_res": ["R"],
		"start_res": null,
		"texture": TEX_TREE
	}
	var tree = plant_scene.instantiate()
	tree.set_variables(tree_dict)
	$Agents.add_child(tree)
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
	
	var mid_width = int(get_viewport().get_visible_rect().size[0]/2)
	var mid_height = int(get_viewport().get_visible_rect().size[1]/2)
	
	var maize_center_offset_x = 160
	var maize_center_offset_y = -20
	var maize_position = pos
	
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
	
	var bean_position = pos
	
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
	var myco_position = pos
	
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
	LevelHelpersRef.stop_audio_players([
		$BirdSound,
		$BirdLong,
		$CarSound,
		$SquelchSound,
		$TwinkleSound,
		$BushSound
	])
		
						
			
		
