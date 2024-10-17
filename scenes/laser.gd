extends Area2D

var start_agent = null
var end_agent = null
var trade_path = null

var direction = null

var trade_type = null
var trade_amount = null

@export var speed = 300 
# Called every frame. 'delta' is the elapsed time since the previous frame.

func set_variables(path_dict) -> void:
	start_agent = path_dict.get("from_agent")
	end_agent = path_dict.get("to_agent")
	trade_path = path_dict.get("trade_path")
	position = start_agent.global_position

func _process(delta: float) -> void:
	if end_agent != null:
		position = position.move_toward(end_agent.global_position,20)
		direction = (end_agent.global_position - self.global_position).normalized()
	else:
		if direction != null:
			position += direction * delta *500
		
	
	var height = get_viewport().get_visible_rect().size[1]
	var width = get_viewport().get_visible_rect().size[0]
	if position.y > height or position.y < 0 or position.x < 0 or position.x > width:
		queue_free()
