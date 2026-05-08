extends CharacterBody2D
class_name Bird

@export var speed := 250
const CAPTURE_DISTANCE := 22.0
const CARRY_OFFSET := Vector2(39.0, -5.0) #(26.0, -4.0)
const CARRY_SCALE := Vector2(0.75, 0.75)
const RETARGET_RETRY_INTERVAL := 0.25
const FORWARD_TARGET_MIN_X_DELTA := 8.0
const CARRY_TEX_BEAN := preload("res://graphics/bean.png")
const CARRY_TEX_SQUASH := preload("res://graphics/squash_32.png")
const CARRY_TEX_MAIZE := preload("res://graphics/maize_32.png")
const CARRY_TEX_TREE := preload("res://graphics/acorn_32.png")
var going = Vector2(1, 0)
var quarry_found = false
var the_quarry: Node = null
var quarry_type = "maize"
var caught = false
var _capture_cleanup_done := false
var _carry_sprite: Sprite2D = null
var _reserved_harvest_target: Node = null
var _retarget_retry_cooldown := 0.0


func _ready():
	reset()


func _get_level_root() -> Node:
	return get_node_or_null("../..")


func _is_target_forward(target: Node) -> bool:
	if not is_instance_valid(target):
		return false
	var forward_sign = signf(going.x)
	if is_zero_approx(forward_sign):
		forward_sign = 1.0
	var delta_x = target.global_position.x - global_position.x
	if forward_sign >= 0.0:
		return delta_x >= FORWARD_TARGET_MIN_X_DELTA
	return delta_x <= -FORWARD_TARGET_MIN_X_DELTA


func _assign_reserved_harvest_target() -> bool:
	var level_root = _get_level_root()
	if not is_instance_valid(level_root):
		return false
	if not level_root.has_method("bird_try_assign_harvest_target"):
		return false
	var assigned_target = level_root.call("bird_try_assign_harvest_target", self)
	if not is_instance_valid(assigned_target):
		return false
	if not _is_target_forward(assigned_target):
		if level_root.has_method("bird_release_harvest_target"):
			level_root.call("bird_release_harvest_target", self, assigned_target)
		return false
	_reserved_harvest_target = assigned_target
	quarry_found = true
	the_quarry = assigned_target
	quarry_type = str(assigned_target.get("type"))
	return true


func _try_switch_to_preferred_acorn() -> bool:
	if caught:
		return false
	if quarry_found and is_instance_valid(the_quarry) and str(the_quarry.get("type")) == "tree":
		return false
	var level_root = _get_level_root()
	if not is_instance_valid(level_root):
		return false
	if not level_root.has_method("bird_try_assign_acorn_target"):
		return false
	var acorn_target = level_root.call("bird_try_assign_acorn_target", self)
	if not is_instance_valid(acorn_target):
		return false
	if not _is_target_forward(acorn_target):
		if level_root.has_method("bird_release_harvest_target"):
			level_root.call("bird_release_harvest_target", self, acorn_target)
		return false
	var previous_target = the_quarry
	if is_instance_valid(previous_target) and previous_target != acorn_target:
		_release_reserved_harvest_target(previous_target)
	_reserved_harvest_target = acorn_target
	quarry_found = true
	the_quarry = acorn_target
	quarry_type = str(acorn_target.get("type"))
	return true


func _release_reserved_harvest_target(release_target: Node = null) -> void:
	var target_to_release = release_target
	if not is_instance_valid(target_to_release):
		target_to_release = _reserved_harvest_target
	if not is_instance_valid(target_to_release):
		return
	var level_root = _get_level_root()
	if is_instance_valid(level_root) and level_root.has_method("bird_release_harvest_target"):
		level_root.call("bird_release_harvest_target", self, target_to_release)
	if target_to_release == _reserved_harvest_target:
		_reserved_harvest_target = null


func _clear_quarry_target(release_reservation := true) -> void:
	if release_reservation:
		_release_reserved_harvest_target(the_quarry)
	quarry_found = false
	the_quarry = null


func reset():
	_release_reserved_harvest_target()
	quarry_found = false
	the_quarry = null
	caught = false
	_capture_cleanup_done = false
	_reserved_harvest_target = null
	_retarget_retry_cooldown = 0.0
	_clear_carry_visual()
	var rng := RandomNumberGenerator.new()
	var world_rect = Global.get_world_rect(self)
	var random_x = rng.randi_range(int(world_rect.position.x) - 120, int(world_rect.position.x) - 40)
	var min_y = int(world_rect.position.y) + 100
	var max_y = int(world_rect.position.y + world_rect.size.y) - 200
	if max_y < min_y:
		max_y = min_y
	var random_y = rng.randi_range(min_y, max_y)
	quarry_type = Global.quarry_type
	position = Vector2(random_x, random_y)
	set_rotation(0)
	if _assign_reserved_harvest_target():
		return
	var level_root = _get_level_root()
	var children = $"../../Agents".get_children()
	children.shuffle()
	for child in children:
		if not is_instance_valid(child):
			continue
		if bool(child.get("dead")):
			continue
		var valid_target := false
		if is_instance_valid(level_root) and level_root.has_method("is_valid_predator_target"):
			valid_target = bool(level_root.is_valid_predator_target(self, child))
		else:
			valid_target = str(child.get("type")) == quarry_type
		if not valid_target:
			continue
		if not _is_target_forward(child):
			continue
		quarry_found = true
		the_quarry = child
		quarry_type = str(child.get("type"))
		break
	if not quarry_found:
		call_deferred("queue_free")


func _is_outside_world_bounds() -> bool:
	var world_rect = Global.get_world_rect(self)
	return position.x > world_rect.end.x + 60 or position.y > world_rect.end.y + 60 or position.y < world_rect.position.y - 60


func _capture_and_exit() -> void:
	if _capture_cleanup_done:
		return
	_capture_cleanup_done = true
	_release_reserved_harvest_target()
	_clear_carry_visual()
	call_deferred("queue_free")


func _get_carry_texture(harvest_type: String) -> Texture2D:
	match harvest_type:
		"bean":
			return CARRY_TEX_BEAN
		"squash":
			return CARRY_TEX_SQUASH
		"maize":
			return CARRY_TEX_MAIZE
		"tree":
			return CARRY_TEX_TREE
	return null


func _clear_carry_visual() -> void:
	if is_instance_valid(_carry_sprite):
		_carry_sprite.queue_free()
	_carry_sprite = null


func _set_carry_visual(harvest_type: String) -> void:
	_clear_carry_visual()
	var carry_texture = _get_carry_texture(harvest_type)
	if not is_instance_valid(carry_texture):
		return
	var carry_sprite := Sprite2D.new()
	carry_sprite.name = "BirdCarrySprite"
	carry_sprite.texture = carry_texture
	carry_sprite.position = CARRY_OFFSET
	carry_sprite.scale = CARRY_SCALE
	carry_sprite.z_index = 20
	add_child(carry_sprite)
	_carry_sprite = carry_sprite


func _begin_escape_with_capture(harvest_type: String) -> void:
	caught = true
	_release_reserved_harvest_target(the_quarry)
	quarry_found = false
	the_quarry = null
	_set_carry_visual(harvest_type)
	speed = maxf(speed - 100.0, 80.0)
	var vertical = randf_range(-0.25, 0.25)
	going = Vector2(1.0, vertical).normalized()


func on_predator_harvest_success(harvest_type: String) -> void:
	_begin_escape_with_capture(harvest_type)


func _try_harvest_target(target: Node) -> bool:
	if not is_instance_valid(target):
		return false
	if bool(target.get("dead")):
		return false
	if not target.has_method("try_harvest_to_predator"):
		return false
	var harvest_type = str(target.get("type"))
	if not bool(target.call("try_harvest_to_predator", self)):
		return false
	_begin_escape_with_capture(harvest_type)
	return true


func _try_capture_quarry() -> bool:
	if not quarry_found:
		return false
	if not is_instance_valid(the_quarry):
		return false
	if bool(the_quarry.get("dead")):
		_clear_quarry_target()
		return false
	if global_position.distance_to(the_quarry.global_position) <= CAPTURE_DISTANCE:
		if _try_harvest_target(the_quarry):
			return true
		_clear_quarry_target()
		return false
	return false


func _physics_process(delta: float) -> void:
	var animated_sprite = get_node_or_null("AnimatedSprite2D")
	if is_instance_valid(animated_sprite):
		animated_sprite.play()

	_retarget_retry_cooldown = maxf(_retarget_retry_cooldown - maxf(delta, 0.0), 0.0)
	if quarry_found and is_instance_valid(the_quarry):
		var level_root = _get_level_root()
		if is_instance_valid(level_root) and level_root.has_method("is_valid_predator_target"):
			if not bool(level_root.call("is_valid_predator_target", self, the_quarry)):
				_clear_quarry_target()
		if is_instance_valid(the_quarry) and not _is_target_forward(the_quarry):
			_clear_quarry_target()

	if not is_instance_valid(the_quarry) or bool(the_quarry.get("dead")):
		_clear_quarry_target()

	if (str(Global.mode) == "story" or str(Global.mode) == "challenge") and not caught and quarry_found and is_instance_valid(the_quarry) and _retarget_retry_cooldown <= 0.0:
		_try_switch_to_preferred_acorn()
		_retarget_retry_cooldown = RETARGET_RETRY_INTERVAL

	if not caught and not quarry_found and _retarget_retry_cooldown <= 0.0:
		if not _assign_reserved_harvest_target():
			_retarget_retry_cooldown = RETARGET_RETRY_INTERVAL

	if caught:
		move_and_collide(speed * going * delta)
	else:
		if _try_capture_quarry():
			move_and_collide(speed * going * delta)
		elif quarry_found and is_instance_valid(the_quarry):
			position = position.move_toward(the_quarry.position, speed * delta)
		else:
			quarry_found = false
			the_quarry = null
			move_and_collide(speed * going * delta)

	if _is_outside_world_bounds():
		_capture_and_exit()


func _on_area_entered(agent: Area2D) -> void:
	if caught:
		return
	if not is_instance_valid(agent):
		return
	var level_root = get_node_or_null("../..")
	if is_instance_valid(level_root) and level_root.has_method("is_valid_predator_target"):
		if not bool(level_root.is_valid_predator_target(self, agent)):
			return
	if is_instance_valid(the_quarry) and agent != the_quarry:
		return
	if str(agent.get("type")) != quarry_type:
		return
	if not _try_harvest_target(agent):
		_clear_quarry_target()


func _exit_tree() -> void:
	_release_reserved_harvest_target()
	_clear_carry_visual()
