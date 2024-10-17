extends CharacterBody2D
class_name Bird
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
	#var mid_width = int(get_viewport().get_visible_rect().size[0]/2)
	
	var rng :=  RandomNumberGenerator.new()
	var width = get_viewport().get_visible_rect().size[0]
	var height = get_viewport().get_visible_rect().size[1]
	var random_x = rng.randi_range(-55,-1*width/2)
	var random_y = rng.randi_range(100,height-200)
	quarry_type = Global.quarry_type
	position = Vector2(random_x,random_y)
	
	#position = START_POS
	set_rotation(0)
	var children =  $"../../Agents".get_children()
	randomize()
	children.shuffle()
		
	for child in children:
		if(child.type == quarry_type and child.dead == false):
			var dest = child.position
			if(child.position.x > self.position.x+10):
				quarry_found = true
				the_quarry = child
				#print("found quarry: ", the_quarry)
				break

	
func _physics_process(delta: float) -> void:
	if flying:
		$AnimatedSprite2D.play()
		
		
		
		#var direction = Input.get_vector("left","right","up","down")
		#velocity = direction * speed
		
		#print("test down"+ str(direction.angle()))
		#if Input.is_action_pressed("down"):
		#	print("test down")
		#position += direction * speed * delta
		#move_and_slide()
		
		#move_and_slide()
		
		if(the_quarry != null):
			if((not is_instance_valid(the_quarry)) or the_quarry.dead):
				the_quarry = null
				quarry_found = false
			
		
		if(caught == false and quarry_found == false):
			move_and_collide(speed*going * delta)
				
		
		if(caught ==false and quarry_found == true ):
			if( is_instance_valid(the_quarry) ):
				position = position.move_toward(the_quarry.position,speed * delta)
			else:
				quarry_found == false 
				move_and_collide(speed*going * delta)
		if(caught == true):
			var collision = move_and_collide(speed*going * delta)
		
		
		if(position.x> get_viewport().get_visible_rect().size[0]+60 or position.y > get_viewport().get_visible_rect().size[1]+60 or position.y<-60):
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
	else:
		$AnimatedSprite2D.stop()

func _on_area_entered(agent: Area2D) -> void:
	if agent.type == quarry_type:
		flying = false
		print("hit ", agent)
	else:
		print("hit ", agent)
