extends Node

func _input(event: InputEvent) -> void:
	#print("test pause")
	if Input.is_anything_pressed():
		get_viewport().set_input_as_handled()
		if(get_tree().paused == true):
			get_tree().paused = false
			$"../MarginCMarginContainer2ontainer/HBoxContainer/PauseButton".text = "Pause"
		
