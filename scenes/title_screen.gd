extends Control


func _reset_run_state() -> void:
	Global.values = {
		"N": 1,
		"P": 1,
		"K": 1,
		"R": 1
	}
	Global.active_agent = null
	Global.is_dragging = false
	Global.stage_inc = 0


func _ready():
	DisplayServer.window_set_title("Plants and People Gardening")
	Global.score = 0
	
	if(Global.social_mode):
		$CenterContainer/BG.modulate.a = 1
		$CenterContainer/BG2.modulate.a = 0
		$CenterContainer/VBoxContainer/HBoxContainer/CheckButton2.button_pressed = true
		$CenterContainer/VBoxContainer/HBoxContainer/CheckButton.button_pressed = false
		var tween = get_tree().create_tween()
		tween.tween_property($CenterContainer/BG, "modulate:a", 0, 0.5)
		var tween2 = get_tree().create_tween()
		tween2.tween_property($CenterContainer/BG2, "modulate:a", 1, 0.5)
	else:
		$CenterContainer/BG.modulate.a = 0
		$CenterContainer/BG2.modulate.a = 1
		$CenterContainer/VBoxContainer/HBoxContainer/CheckButton.button_pressed = true
		$CenterContainer/VBoxContainer/HBoxContainer/CheckButton2.button_pressed = false
		var tween2 = get_tree().create_tween()
		tween2.tween_property($CenterContainer/BG2, "modulate:a", 0, 0.5)
		var tween = get_tree().create_tween()
		tween.tween_property($CenterContainer/BG, "modulate:a", 1, 0.5)
		

func _on_tutorial_pressed() -> void:
	_reset_run_state()
	Global.mode = "tutorial"
	Global.is_raining = false
	Global.is_birding = false
	Global.is_killing = false
	Global.is_max_babies = false
	Global.draw_lines = true
	Global.bars_on = true
	Global.stage = 1
	Global.inventory = { #how many of each plant do we have to use
	"bean": 5,
	"squash": 5,				
	"maize": 15,
	"tree": 5,
	"myco": 4
	}
	if(Global.social_mode== false):
		get_tree().change_scene_to_file("res://scenes/level.tscn")
	else:

		get_tree().change_scene_to_file("res://scenes/sociallevel.tscn")

func _on_free_garden_pressed() -> void:
	_reset_run_state()
	Global.mode = "free"
	Global.is_raining = false
	Global.is_birding = false
	Global.is_killing = true
	Global.is_max_babies = true
	Global.bars_on = false
	Global.draw_lines = false
	Global.inventory = { #how many of each plant do we have to use
	"bean": 60,
	"squash": 60,				
	"maize": 60,
	"tree": 60,
	"myco": 40
	}

	if(Global.social_mode== false):
		get_tree().change_scene_to_file("res://scenes/level.tscn")
	else:
		Global.draw_lines = true
		get_tree().change_scene_to_file("res://scenes/sociallevel.tscn")

func _on_challenge_button_pressed() -> void:
	_reset_run_state()
	Global.mode = "challenge"
	Global.is_raining = true
	Global.is_birding = true
	Global.is_killing = true
	Global.is_max_babies = true
	Global.bars_on = false
	Global.draw_lines = true
	Global.inventory = { #how many of each plant do we have to use
	"bean": 12,
	"squash": 12,				
	"maize": 12,
	"tree": 12,
	"myco": 12
	}
	if(Global.social_mode== false):
		get_tree().change_scene_to_file("res://scenes/level.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/sociallevel.tscn")


func _on_cofi_button_pressed() -> void:
	_reset_run_state()
	Global.social_mode = true
	Global.mode = "challenge"
	Global.is_raining = true
	Global.is_birding = false
	Global.is_killing = false
	Global.is_max_babies = false
	Global.bars_on = true
	Global.draw_lines = true
	Global.baby_mode = false
	
	Global.social_inventory = { #how many of each plant do we have to use
	"service": 12,
	"good": 12,				
	"value add": 12,
	"city": 12,
	"basket": 12
	}
	get_tree().change_scene_to_file("res://scenes/sociallevel.tscn")


func _on_check_button_toggled(toggled_on: bool) -> void:

	$CenterContainer/VBoxContainer/HBoxContainer/CheckButton2.emit_signal("pressed")
	
	$CenterContainer/VBoxContainer/HBoxContainer/CheckButton2.button_pressed=not toggled_on
	if toggled_on == true:
		Global.social_mode = false
		$CenterContainer/BG.texture = load("res://graphics/soil_end.jpeg")
	else:
		Global.social_mode = true
		$CenterContainer/BG.texture = load("res://graphics/social.png")
		


func _on_check_button_2_toggled(toggled_on: bool) -> void:
	
	$CenterContainer/VBoxContainer/HBoxContainer/CheckButton.emit_signal("pressed")
	$CenterContainer/VBoxContainer/HBoxContainer/CheckButton.button_pressed=not toggled_on
	if toggled_on == true:
		Global.social_mode = true
		#$CenterContainer/BG.texture = load("res://graphics/social.png")
		var tween = get_tree().create_tween()
		tween.tween_property($CenterContainer/BG2, "modulate:a", 1, 0.2)
		var tween2 = get_tree().create_tween()
		tween2.tween_property($CenterContainer/BG, "modulate:a", 0, 0.2)
	else:
		Global.social_mode = false
		#$CenterContainer/BG.texture = load("res://graphics/soil_end.jpeg")
		var tween = get_tree().create_tween()
		tween.tween_property($CenterContainer/BG2, "modulate:a", 0, 0.2)
		var tween2 = get_tree().create_tween()
		tween2.tween_property($CenterContainer/BG, "modulate:a", 1, 0.2)
