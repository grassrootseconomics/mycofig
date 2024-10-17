extends CharacterBody2D

@export var speed := 250
var can_shoot: bool = true

var START_NITROGEN = 0
var START_POTASSIUM = 0
var START_PHOSPHORUS = 0
var trades = [] #list of outstanding trades

var assets = { #list of assets including money
	"Nitrogen": START_NITROGEN,
	"Potassium": START_POTASSIUM,				
	"Phosphorus": START_PHOSPHORUS
			}

signal laser(pos)
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#position = Vector2(100,500)
	pass
	
func sort_closest(a, b):
	return a.position < b.position

func get_closest_enemy():
	var enemies = get_tree().get_nodes_in_group("enemies")
	enemies.sort_custom(sort_closest)
	return enemies.front()
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	#print("start")
	var direction = Input.get_vector("left","right","up","down")
	velocity = direction * speed
	#print("test down"+ str(direction.angle()))
	#if Input.is_action_pressed("down"):
	#	print("test down")
	#position += direction * speed * delta
	move_and_slide()
	if Input.is_action_just_pressed("shoot") and can_shoot:
		
		can_shoot = false
		$LaserTimer.start()
		randomize()
		var children =  $"../Agents".get_children()
		
		var min_distance = 99999999.0
		
		var dest_agent = null
		
		if children.size() > 0:
			#var dest_agent = children[randi() % children.size()]
			children.sort_custom(func(a, b): return a.global_position > b.global_position)
			for child in children:
				var dist = self.get_global_transform().origin.distance_to( child.get_global_transform().origin );
				if dist < min_distance : 
					min_distance = dist
					dest_agent = child
			
			#tilemap.set_visible(false)
			var path_dict = {
				"from_agent": self,
				"to_agent": dest_agent,
				"trade_path": [self,dest_agent]
			}
			laser.emit(path_dict)
		else:
			if false:
				var path_dict = {
					"from_agent": self,
					"to_agent": null,
					"trade_path": [self,null]
				} 
				laser.emit(path_dict)

func _on_laser_timer_timeout() -> void:
	can_shoot = true
