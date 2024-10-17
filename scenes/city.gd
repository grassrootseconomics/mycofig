extends Area2D

@export var speed: int
signal collision

var START_MONEY = 0
var money = START_MONEY
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var rng :=  RandomNumberGenerator.new()
	var width = get_viewport().get_visible_rect().size[0]
	var height = get_viewport().get_visible_rect().size[1]
	var random_x = rng.randi_range(5,width-100)
	var random_y = rng.randi_range(5,height-200)
	#var random_y = rng.randi_range(5,-1*height)
	position = Vector2(random_x,random_y)
	
	speed = 0 #rng.randi_range(200,500)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position += Vector2(0,1.0) *speed*delta
	var height = get_viewport().get_visible_rect().size[1]
	if position.y>height:
		queue_free()
	#pass


func _on_body_entered(body: Node2D) -> void:
	#print(body_entered)
	#print(body)
	collision.emit(body)
	


func _on_area_entered(trade: Area2D) -> void:
	if trade.get("money"):
		money += trade.money	
	trade.queue_free()
	queue_free()
