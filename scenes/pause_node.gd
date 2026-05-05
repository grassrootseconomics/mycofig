extends Node

func _is_android_back_input(event: InputEvent) -> bool:
	if not Global.is_mobile_platform:
		return false
	if event.is_action_pressed("ui_cancel"):
		return true
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE
	return false


func _input(event: InputEvent) -> void:
	if not get_tree().paused:
		return
	if not _is_android_back_input(event):
		return
	var ui = get_parent()
	if is_instance_valid(ui) and ui.has_method("show_back_to_menu_confirm"):
		ui.show_back_to_menu_confirm()
	get_viewport().set_input_as_handled()
		
