extends TextureRect

var is_dragging = false
var mouse_offset
var delay = 10

func _physics_process(delta):
	if is_dragging:
		var tween = get_tree().create_tween()
		tween.tween_property(self, "position", get_global_mouse_position(), delay * delta)
		
	
func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if self.get_rect().has_point(get_local_mouse_position()):
					is_dragging = true
			else:
				is_dragging = false
