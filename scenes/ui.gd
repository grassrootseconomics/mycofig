extends CanvasLayer
var time_elapsed := 0

#signal sliderChanged(info_dict)
signal new_agent(agent_dict)

var sliders = []

var last_agent = null

var next_agent = null
var resContainer = null

func _ready() -> void:
	#$PalletContainer2/HBoxContainer/ActiveTexture.texture = Global.active_agent.sprite_texture
	#resContainer = $MarginContainer/HBoxContainer/ResVBoxContainer
	pass

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
	for inv in inventory_labels:
		inventory_labels[inv].text = str(Global.inventory[inv])
	if(Global.social_mode):
		for invs in inventory_sprites:
			if(invs=="bean"):
				inventory_sprites[invs].texture = load("res://graphics/services.png")
			elif(invs=="squash"):
				inventory_sprites[invs].texture = load("res://graphics/coopproduction.png")
			elif(invs=="maize"):
				inventory_sprites[invs].texture = load("res://graphics/shop-green.png")
			elif(invs=="tree"):
				inventory_sprites[invs].texture = load("res://graphics/city.png")
			elif(invs=="myco"):
				inventory_sprites[invs].texture = load("res://graphics/basket.png")
		
	
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
	resContainer.add_child(assetLabel)
	
	var valLabel = Label.new()
	valLabel.text = "Relative Value"
	valContainer.add_child(valLabel)
	

	for asset in Global.values:
		var resText = Label.new()
		resText.name = str(asset)
		if(Global.social_mode==true):
			resText.text = str(Global.assets_social[asset]) + str(" ") + str(Global.values[asset])
		else:
			resText.text = str(asset) + str(" ") + str(Global.values[asset])
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
					label.text = res + str(" ") + str(Global.values[res])
		



func _input(event):
	if event is InputEventMouseButton:
		if mouseOverMyco == true:
			#print("Clicked On myco")
			next_agent = "myco"
		elif mouseOverMaize == true:
			#print("Clicked On maize")
			next_agent = "maize"
		elif mouseOverTree == true:
			#print("Clicked On tree")
			next_agent = "tree"
		elif mouseOverBean == true:
			#print("Clicked On Bean")
			next_agent = "bean"
		elif mouseOverSquash == true:
			#print("Clicked On Squash")
			next_agent = "squash"
			
		if event.pressed == false and next_agent != null:
			#var space = get_world_2d().direct_space_state
			if(Global.inventory[next_agent] >0 ):
				var hit = false
				if $MarginContainer.get_rect().has_point(event.position):
					hit = true
					#print("hit something-pallet: ", $PalletContainer.get_rect(), " point: ", event.position)
				
				"""
				for agent in $"../Agents".get_children():
					var recto = agent.sprite.get_rect()
					var posr = recto.position+agent.global_position
					var rects = Rect2(posr,recto.size) 
					
					#var newRect = rects
					#rects["P"] += agent.sprite.global_position
					#print("testing collision: ", agent.name, " rect:", rects)
					
					if rects.has_point(event.position):
					#if agent.sprite.get_rect().has_point(event.position):
						hit = true
						print("hit something-agent: ", agent.name)
				"""		
			# Check if there is a collision at the mouse position
				#if space.intersect_point(event.position, 1):
				#	print("hit something")
				#else:
				#	print("no hit")
				if( hit == false):
					var new_agent_dict = {
						"name" : next_agent,
						"pos": event.position
					}
					#print("()()clicked sending signal: ", new_agent_dict)
					emit_signal("new_agent", new_agent_dict)
					Global.inventory[next_agent] -=1
					inventory_labels[next_agent].text = str(Global.inventory[next_agent])
					if (Global.inventory[next_agent] <1):
						inventory_sprites[next_agent].modulate.a =0.5
					
					next_agent = null
					#make_squash(event.position)		


			
		


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
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
