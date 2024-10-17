extends Node2D


func _ready():
	
	pass
	

func start(duration: float):
	$Timer.start(duration)

func _on_timer_timeout() -> void:
	call_deferred("queue_free")#queue_free()
