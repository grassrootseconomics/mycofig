extends CharacterBody2D

class_name Tuktuk
@export var speed := 250
var MAX_VEL = 600
var flying = true
var START_POS = Vector2(100,300)
var going = Vector2(1,0)
var quarry_found = false
var the_quarry = null
var caught = false
var quarry_type = "maize"
func _ready():
	reset()
	
func reset():
	flying = true
	caught = false
	quarry_found = false
	the_quarry = null
	#var mid_width = int(get_viewport().get_visible_rect().size[0]/2)
	#if(Global.social_mode == true):
		
	var rng :=  RandomNumberGenerator.new()
	var world_rect = Global.get_world_rect(self)
	var random_x = rng.randi_range(int(world_rect.position.x) - 120, int(world_rect.position.x) - 40)
	var min_y = int(world_rect.position.y) + 100
	var max_y = int(world_rect.position.y + world_rect.size.y) - 200
	if max_y < min_y:
		max_y = min_y
	var random_y = rng.randi_range(min_y, max_y)
	quarry_type = Global.quarry_type
	position = Vector2(random_x,random_y)
	
	#position = START_POS
	set_rotation(0)
	var children =  $"../../Agents".get_children()
	children.shuffle()
		
	for child in children:
		if(child.type == quarry_type and child.dead == false):
			if(child.position.x > self.position.x+10):
				quarry_found = true
				the_quarry = child
				#print("found quarry: ", the_quarry)
				break

	
func _physics_process(delta: float) -> void:
	if true:
		#$AnimatedSprite2D.play()
		
		
		
		#var direction = Input.get_vector("left","right","up","down")
		#velocity = direction * speed
		
		#print("test down"+ str(direction.angle()))
		#if Input.is_action_pressed("down"):
		#	print("test down")
		#position += direction * speed * delta
		#move_and_slide()
		
		#move_and_slide()
		
		if(the_quarry != null):
			if(not is_instance_valid(the_quarry)):
				the_quarry = null
				quarry_found = false
			elif(the_quarry.dead == true):
				the_quarry = null
				quarry_found = false
			
		
		if(caught == false):
			if(quarry_found and is_instance_valid(the_quarry)):
				#print("-1:", self.name, " caught:", caught, " found: ",quarry_found, " tuktuk:", speed, going, delta)
				position = position.move_toward(the_quarry.position,speed * delta)
			else:
				quarry_found = false
				the_quarry = null
				#print("0:", self.name, "tuktuk:", speed, going, delta)
				move_and_collide(speed*going * delta)
		if(caught == true):
			#print("1:", self.name, "tuktuk:", speed, going, delta)
			var collision = move_and_collide(speed*going * delta)
		
		
		var world_rect = Global.get_world_rect(self)
		if(position.x > world_rect.end.x + 60 or position.y > world_rect.end.y + 60 or position.y < world_rect.position.y - 60):
			if(the_quarry != null):
				if(is_instance_valid(the_quarry)):
					the_quarry.kill_it()
					#the_quarry.call_deferred("queue_free")
					await the_quarry.tree_exited
			self.call_deferred("queue_free")
			
		#while (collision):
		#	var collider = collision.get_collider()
		#	print("hit ", collider)
			#if collider is Plant:
				#print("hit ", collider)
	
		#collision = move_and_collide(remainder)

func _on_area_entered(agent: Area2D) -> void:
	if agent.type == quarry_type:
		flying = false
