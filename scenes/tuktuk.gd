extends CharacterBody2D
class_name Tuktuk

signal scripted_capture_finished
signal scripted_capture_started

@export var speed := 250
const CAPTURE_DISTANCE := 20.0
var going = Vector2(1, 0)
var quarry_found = false
var the_quarry: Node = null
var quarry_type = "maize"
var caught = false
var _captured_target: Node = null
var _capture_cleanup_done := false
var _captured_target_offset := Vector2(-20, -8)
var _scripted_capture_enabled := false
var _scripted_spawn_pos := Vector2.ZERO
var _scripted_target: Node = null
var _scripted_finished_emitted := false
var _scripted_capture_started_emitted := false


func _ready():
	if _scripted_capture_enabled:
		_start_scripted_capture()
	else:
		reset()
	if quarry_found or is_instance_valid(_captured_target):
		_play_entry_sound()


func _play_entry_sound() -> void:
	var level_root = get_node_or_null("../..")
	if is_instance_valid(level_root) and level_root.has_method("play_tuktuk_entry_sound"):
		level_root.call("play_tuktuk_entry_sound")
		return
	var car_sound = get_node_or_null("../../CarSound")
	if is_instance_valid(car_sound) and car_sound.has_method("play"):
		car_sound.play()


func configure_scripted_capture(target: Node, spawn_pos: Vector2) -> void:
	_scripted_capture_enabled = true
	_scripted_spawn_pos = spawn_pos
	_scripted_target = target
	position = spawn_pos


func _emit_scripted_capture_finished() -> void:
	if not _scripted_capture_enabled:
		return
	if _scripted_finished_emitted:
		return
	_scripted_finished_emitted = true
	scripted_capture_finished.emit()


func _emit_scripted_capture_started() -> void:
	if not _scripted_capture_enabled:
		return
	if _scripted_capture_started_emitted:
		return
	_scripted_capture_started_emitted = true
	scripted_capture_started.emit()


func _start_scripted_capture() -> void:
	quarry_found = false
	the_quarry = null
	caught = false
	_captured_target = null
	_capture_cleanup_done = false
	_scripted_finished_emitted = false
	_scripted_capture_started_emitted = false
	position = _scripted_spawn_pos
	set_rotation(0)
	if not is_instance_valid(_scripted_target) or bool(_scripted_target.get("dead")):
		_emit_scripted_capture_finished()
		call_deferred("queue_free")
		return
	quarry_found = true
	the_quarry = _scripted_target
	quarry_type = str(_scripted_target.get("type"))


func reset():
	quarry_found = false
	the_quarry = null
	caught = false
	_captured_target = null
	_capture_cleanup_done = false
	_scripted_finished_emitted = false
	_scripted_capture_started_emitted = false
	var rng := RandomNumberGenerator.new()
	var world_rect = Global.get_world_rect(self)
	var level_root = get_node_or_null("../..")
	var spawn_set := false
	if is_instance_valid(level_root) and level_root.has_method("get_tuktuk_spawn_position"):
		var custom_spawn = level_root.call("get_tuktuk_spawn_position")
		if typeof(custom_spawn) == TYPE_VECTOR2:
			position = custom_spawn
			spawn_set = true
	if not spawn_set:
		var random_x = rng.randi_range(int(world_rect.position.x) - 120, int(world_rect.position.x) - 40)
		var vertical_margin = clampi(int(round(world_rect.size.y * 0.08)), 16, 96)
		var min_y = int(world_rect.position.y) + vertical_margin
		var max_y = int(world_rect.end.y) - vertical_margin
		var random_y = int(world_rect.position.y + world_rect.size.y * 0.5)
		if max_y >= min_y:
			random_y = rng.randi_range(min_y, max_y)
		position = Vector2(random_x, random_y)
	quarry_type = Global.quarry_type
	set_rotation(0)
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
	if is_instance_valid(_captured_target) and _captured_target.has_method("kill_it"):
		_captured_target.kill_it()
	_emit_scripted_capture_finished()
	call_deferred("queue_free")


func _begin_escape_with_capture(agent: Node) -> void:
	caught = true
	_captured_target = agent
	if is_instance_valid(_captured_target):
		_captured_target.set("dead", true)
		var captured_shape = _captured_target.get_node_or_null("CollisionShape2D")
		if is_instance_valid(captured_shape):
			captured_shape.set_deferred("disabled", true)
		_captured_target.global_position = global_position + _captured_target_offset
	quarry_found = false
	the_quarry = null
	var vertical = randf_range(-0.20, 0.20)
	going = Vector2(1.0, vertical).normalized()
	_emit_scripted_capture_started()


func _try_capture_quarry() -> bool:
	if not quarry_found:
		return false
	if not is_instance_valid(the_quarry):
		return false
	if bool(the_quarry.get("dead")):
		the_quarry = null
		quarry_found = false
		return false
	if global_position.distance_to(the_quarry.global_position) <= CAPTURE_DISTANCE:
		_begin_escape_with_capture(the_quarry)
		return true
	return false


func _physics_process(delta: float) -> void:
	if _scripted_capture_enabled and not caught and (not is_instance_valid(the_quarry) or bool(the_quarry.get("dead"))):
		the_quarry = null
		quarry_found = false
		_emit_scripted_capture_finished()
		call_deferred("queue_free")
		return

	if not is_instance_valid(the_quarry) or bool(the_quarry.get("dead")):
		the_quarry = null
		quarry_found = false

	if is_instance_valid(_captured_target):
		move_and_collide(speed * going * delta)
		if is_instance_valid(_captured_target):
			_captured_target.global_position = global_position + _captured_target_offset
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
	if is_instance_valid(_captured_target):
		return
	if not is_instance_valid(agent):
		return
	if _scripted_capture_enabled:
		if quarry_found and agent == the_quarry:
			_begin_escape_with_capture(agent)
		return
	var level_root = get_node_or_null("../..")
	if is_instance_valid(level_root) and level_root.has_method("is_valid_predator_target"):
		if not bool(level_root.is_valid_predator_target(self, agent)):
			return
	if is_instance_valid(the_quarry) and agent != the_quarry:
		return
	if str(agent.get("type")) != quarry_type:
		return
	_begin_escape_with_capture(agent)
