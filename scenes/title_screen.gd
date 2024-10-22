extends Control


func _ready():
	DisplayServer.window_set_title("Mycofi Garden")
	Global.score = 0

func _on_tutorial_pressed() -> void:
	Global.social_mode= false
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
	get_tree().change_scene_to_file("res://scenes/level.tscn")

func _on_free_garden_pressed() -> void:
	Global.social_mode= false
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

	get_tree().change_scene_to_file("res://scenes/level.tscn")

func _on_challenge_button_pressed() -> void:
	Global.social_mode= false
	Global.mode = "challenge"
	Global.is_raining = true
	Global.is_birding = true
	Global.is_killing = true
	Global.is_max_babies = true
	Global.bars_on = false
	Global.draw_lines = false
	Global.inventory = { #how many of each plant do we have to use
	"bean": 12,
	"squash": 12,				
	"maize": 12,
	"tree": 12,
	"myco": 12
	}
	get_tree().change_scene_to_file("res://scenes/level.tscn")


func _on_cofi_button_pressed() -> void:
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
	"foreign": 12,
	"city": 12,
	"basket": 12
	}
	get_tree().change_scene_to_file("res://scenes/sociallevel.tscn")
