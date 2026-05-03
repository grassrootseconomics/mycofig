extends RefCounted
class_name LevelHelpers

const HOTKEY_SPEED_UP := [KEY_PLUS, KEY_EQUAL]
const HOTKEY_SPEED_DOWN := [KEY_MINUS, KEY_UNDERSCORE]
const HOTKEY_QUIT := [KEY_ESCAPE, KEY_Q]
const HOTKEY_TOGGLE_BARS := [KEY_B]
const HOTKEY_TOGGLE_BABY := [KEY_M]
const HOTKEY_CYCLE_ACTIVE := [KEY_TAB]
const HOTKEY_CONNECTORS_2 := [KEY_2]
const HOTKEY_CONNECTORS_3 := [KEY_3]
const HOTKEY_CONNECTORS_4 := [KEY_4]
const HOTKEY_CONNECTORS_5 := [KEY_5]


static func _is_pressed_key(event: InputEvent, keycodes: Array) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	for code in keycodes:
		if key_event.keycode == code:
			return true
	return false


static func _cycle_active_agent(agents_root: Node) -> void:
	if not is_instance_valid(agents_root):
		return
	var agents = agents_root.get_children()
	if agents.is_empty():
		return
	var found_it := -1
	if is_instance_valid(Global.active_agent):
		for index in range(agents.size()):
			var agent = agents[index]
			if is_instance_valid(agent) and agent.name == Global.active_agent.name:
				found_it = index
				break
	if found_it >= agents.size() - 1:
		Global.active_agent = agents[0]
	else:
		Global.active_agent = agents[found_it + 1]
	Global.prevent_auto_select = false
	if is_instance_valid(Global.active_agent):
		Global.active_agent.draw_box = true


static func handle_gameplay_hotkeys(event: InputEvent, owner: Node, agents_root: Node, include_connector_keys: bool = false) -> bool:
	if _is_pressed_key(event, HOTKEY_SPEED_UP):
		Global.move_rate += 1
		Global.movement_speed += 50
		return true

	if _is_pressed_key(event, HOTKEY_SPEED_DOWN):
		Global.move_rate -= 1
		Global.movement_speed -= 50
		if Global.move_rate < 0:
			Global.move_rate = 0
			Global.movement_speed = 0
		return true

	if _is_pressed_key(event, HOTKEY_QUIT):
		if is_instance_valid(owner):
			owner.get_tree().call_deferred("change_scene_to_file", "res://scenes/game_over.tscn")
		return true

	if _is_pressed_key(event, HOTKEY_TOGGLE_BARS):
		Global.bars_on = not Global.bars_on
		if is_instance_valid(agents_root):
			for agent in agents_root.get_children():
				var canvas = agent.get("bar_canvas")
				if is_instance_valid(canvas):
					canvas.visible = Global.bars_on
		return true

	if _is_pressed_key(event, HOTKEY_TOGGLE_BABY):
		Global.baby_mode = not Global.baby_mode
		return true

	if include_connector_keys:
		if _is_pressed_key(event, HOTKEY_CONNECTORS_2):
			Global.num_connectors = 2
			return true
		if _is_pressed_key(event, HOTKEY_CONNECTORS_3):
			Global.num_connectors = 3
			return true
		if _is_pressed_key(event, HOTKEY_CONNECTORS_4):
			Global.num_connectors = 4
			return true
		if _is_pressed_key(event, HOTKEY_CONNECTORS_5):
			Global.num_connectors = 5
			return true

	if _is_pressed_key(event, HOTKEY_CYCLE_ACTIVE):
		_cycle_active_agent(agents_root)
		return true

	return false


static func connect_core_agent_signals(agent: Node, trade_target: Callable, new_agent_target: Callable, update_score_target: Callable) -> void:
	if agent.has_signal("trade"):
		agent.connect("trade", trade_target)
	if agent.has_signal("new_agent"):
		agent.connect("new_agent", new_agent_target)
	if agent.has_signal("update_score"):
		agent.connect("update_score", update_score_target)


static func mark_myco_lines_dirty(agents_root: Node) -> void:
	for agent in agents_root.get_children():
		if agent.get("type") == "myco":
			agent.draw_lines = true


static func mark_all_buddies_dirty(agents_root: Node) -> void:
	for agent in agents_root.get_children():
		agent.new_buddies = true


static func _get_world_foundation(level_root: Node) -> Node:
	if not is_instance_valid(level_root):
		return null
	return level_root.get_node_or_null("WorldFoundation")


static func _supports_tile_world(level_root: Node) -> bool:
	var world = _get_world_foundation(level_root)
	if not is_instance_valid(world):
		return false
	return world.has_method("world_to_tile") and world.has_method("tile_to_world_center") and world.has_method("in_bounds")


static func _get_world_limits(world: Node) -> Vector2i:
	var columns = int(world.get("columns"))
	var rows = int(world.get("rows"))
	return Vector2i(max(columns, 1), max(rows, 1))


static func _clamp_tile_to_world(world: Node, coord: Vector2i) -> Vector2i:
	var limits = _get_world_limits(world)
	return Vector2i(
		clampi(coord.x, 0, limits.x - 1),
		clampi(coord.y, 0, limits.y - 1)
	)


static func _is_tile_blocking_agent(agent: Node) -> bool:
	if not is_instance_valid(agent):
		return false
	if bool(agent.get("dead")):
		return false
	return str(agent.get("type")) != "cloud"


static func _agent_uses_multi_tile_occupancy(agent: Node) -> bool:
	if not is_instance_valid(agent):
		return false
	return str(agent.get("type")) == "tree"


static func _get_agent_sprite_node(agent: Node) -> Node2D:
	if not is_instance_valid(agent):
		return null
	if not agent.has_node("Sprite2D"):
		return null
	var sprite = agent.get_node("Sprite2D")
	if sprite is Node2D and sprite.has_method("get_rect"):
		return sprite
	return null


static func _get_world_rect(world: Node) -> Rect2:
	if not is_instance_valid(world):
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	if world.has_method("get_world_rect"):
		return world.get_world_rect()
	var limits = _get_world_limits(world)
	var tile_size = float(world.get("tile_size"))
	if tile_size <= 0.0:
		tile_size = 64.0
	return Rect2(Vector2.ZERO, Vector2(float(limits.x) * tile_size, float(limits.y) * tile_size))


static func _get_agent_world_bounds(level_root: Node, agent: Node, world_pos_override: Variant = null, sprite_scale_override: Variant = null) -> Rect2:
	if not is_instance_valid(agent):
		return Rect2(Vector2.ZERO, Vector2.ZERO)

	var center = agent.global_position
	if typeof(world_pos_override) == TYPE_VECTOR2:
		center = world_pos_override
	if not _agent_uses_multi_tile_occupancy(agent):
		return Rect2(center, Vector2.ZERO)

	var sprite_node = _get_agent_sprite_node(agent)
	if not is_instance_valid(sprite_node):
		return Rect2(center, Vector2.ZERO)

	var sprite_rect: Rect2 = sprite_node.get_rect()
	var sprite_scale: Vector2 = sprite_node.scale
	if typeof(sprite_scale_override) == TYPE_VECTOR2:
		sprite_scale = sprite_scale_override

	var scaled_pos = Vector2(sprite_rect.position.x * sprite_scale.x, sprite_rect.position.y * sprite_scale.y)
	var scaled_size = Vector2(sprite_rect.size.x * sprite_scale.x, sprite_rect.size.y * sprite_scale.y)
	var min_local = Vector2(
		minf(scaled_pos.x, scaled_pos.x + scaled_size.x),
		minf(scaled_pos.y, scaled_pos.y + scaled_size.y)
	)
	var max_local = Vector2(
		maxf(scaled_pos.x, scaled_pos.x + scaled_size.x),
		maxf(scaled_pos.y, scaled_pos.y + scaled_size.y)
	)
	return Rect2(center + min_local, max_local - min_local)


static func get_agent_occupied_tiles(level_root: Node, agent: Node, world_pos_override: Variant = null, sprite_scale_override: Variant = null) -> Array:
	var occupied_tiles: Array = []
	if not _supports_tile_world(level_root):
		return occupied_tiles
	if not is_instance_valid(agent):
		return occupied_tiles

	var world = _get_world_foundation(level_root)
	var center = agent.global_position
	if typeof(world_pos_override) == TYPE_VECTOR2:
		center = world_pos_override

	if not _agent_uses_multi_tile_occupancy(agent):
		occupied_tiles.append(_clamp_tile_to_world(world, world.world_to_tile(center)))
		return occupied_tiles

	var world_bounds = _get_agent_world_bounds(level_root, agent, center, sprite_scale_override)
	if world_bounds.size.x <= 0.0 or world_bounds.size.y <= 0.0:
		occupied_tiles.append(_clamp_tile_to_world(world, world.world_to_tile(center)))
		return occupied_tiles

	var world_min = world_bounds.position
	var world_max = world_bounds.position + world_bounds.size - Vector2(0.001, 0.001)
	var min_coord = _clamp_tile_to_world(world, world.world_to_tile(world_min))
	var max_coord = _clamp_tile_to_world(world, world.world_to_tile(world_max))
	for y in range(min_coord.y, max_coord.y + 1):
		for x in range(min_coord.x, max_coord.x + 1):
			occupied_tiles.append(Vector2i(x, y))

	return occupied_tiles


static func _agent_covers_tile(level_root: Node, agent: Node, coord: Vector2i) -> bool:
	for covered_coord in get_agent_occupied_tiles(level_root, agent):
		if covered_coord == coord:
			return true
	return false


static func can_place_agent_on_tile(level_root: Node, agents_root: Node, candidate_agent: Node, target_tile: Vector2i, ignore: Node = null, sprite_scale_override: Variant = null) -> bool:
	if not _supports_tile_world(level_root):
		return true
	var world = _get_world_foundation(level_root)
	if not world.in_bounds(target_tile):
		return false
	if not is_instance_valid(agents_root):
		return true
	if not is_instance_valid(candidate_agent):
		return not is_tile_occupied(level_root, agents_root, target_tile, ignore)

	var target_center = world.tile_to_world_center(target_tile)
	if _agent_uses_multi_tile_occupancy(candidate_agent):
		var world_bounds = _get_agent_world_bounds(level_root, candidate_agent, target_center, sprite_scale_override)
		var world_rect = _get_world_rect(world)
		var world_bounds_max = world_bounds.position + world_bounds.size
		var world_rect_max = world_rect.position + world_rect.size
		if world_bounds.position.x < world_rect.position.x:
			return false
		if world_bounds.position.y < world_rect.position.y:
			return false
		if world_bounds_max.x > world_rect_max.x:
			return false
		if world_bounds_max.y > world_rect_max.y:
			return false

	var candidate_tiles = get_agent_occupied_tiles(level_root, candidate_agent, target_center, sprite_scale_override)
	if candidate_tiles.is_empty():
		return false
	for coord in candidate_tiles:
		if not world.in_bounds(coord):
			return false

	for agent in agents_root.get_children():
		if not _is_tile_blocking_agent(agent):
			continue
		if is_instance_valid(ignore) and agent == ignore:
			continue
		if agent == candidate_agent:
			continue
		var occupied_tiles = get_agent_occupied_tiles(level_root, agent)
		for coord in candidate_tiles:
			if occupied_tiles.has(coord):
				return false

	return true


static func is_tile_occupied(level_root: Node, agents_root: Node, coord: Vector2i, ignore: Node = null) -> bool:
	if not _supports_tile_world(level_root):
		return false
	if not is_instance_valid(agents_root):
		return false
	for agent in agents_root.get_children():
		if not _is_tile_blocking_agent(agent):
			continue
		if is_instance_valid(ignore) and agent == ignore:
			continue
		if _agent_covers_tile(level_root, agent, coord):
			return true
	return false


static func _find_free_tile(level_root: Node, agents_root: Node, start_coord: Vector2i, search_radius: int, candidate_agent: Node = null, candidate_scale_override: Variant = null) -> Vector2i:
	var world = _get_world_foundation(level_root)
	if not is_instance_valid(world):
		return Vector2i(-1, -1)
	if world.in_bounds(start_coord):
		if is_instance_valid(candidate_agent):
			if can_place_agent_on_tile(level_root, agents_root, candidate_agent, start_coord, candidate_agent, candidate_scale_override):
				return start_coord
		elif not is_tile_occupied(level_root, agents_root, start_coord):
			return start_coord

	for radius in range(1, max(search_radius, 1) + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var coord = start_coord + Vector2i(dx, dy)
				if not world.in_bounds(coord):
					continue
				if is_instance_valid(candidate_agent):
					if can_place_agent_on_tile(level_root, agents_root, candidate_agent, coord, candidate_agent, candidate_scale_override):
						return coord
				elif not is_tile_occupied(level_root, agents_root, coord):
					return coord

	var limits = _get_world_limits(world)
	for y in range(limits.y):
		for x in range(limits.x):
			var coord = Vector2i(x, y)
			if is_instance_valid(candidate_agent):
				if can_place_agent_on_tile(level_root, agents_root, candidate_agent, coord, candidate_agent, candidate_scale_override):
					return coord
			elif not is_tile_occupied(level_root, agents_root, coord):
				return coord
	return Vector2i(-1, -1)


static func resolve_snapped_spawn_position(level_root: Node, agents_root: Node, desired_world_pos: Vector2, search_radius: int = 10) -> Vector2:
	if not _supports_tile_world(level_root):
		return desired_world_pos
	var world = _get_world_foundation(level_root)
	var desired_tile = _clamp_tile_to_world(world, world.world_to_tile(desired_world_pos))
	var free_tile = _find_free_tile(level_root, agents_root, desired_tile, search_radius)
	if free_tile.x < 0 or free_tile.y < 0:
		return world.tile_to_world_center(desired_tile)
	return world.tile_to_world_center(free_tile)


static func resolve_snapped_position_for_agent(level_root: Node, agents_root: Node, candidate_agent: Node, desired_world_pos: Vector2, search_radius: int = 10, sprite_scale_override: Variant = null) -> Vector2:
	if not _supports_tile_world(level_root):
		return desired_world_pos
	if not is_instance_valid(candidate_agent):
		return resolve_snapped_spawn_position(level_root, agents_root, desired_world_pos, search_radius)
	var world = _get_world_foundation(level_root)
	var desired_tile = _clamp_tile_to_world(world, world.world_to_tile(desired_world_pos))
	var free_tile = _find_free_tile(level_root, agents_root, desired_tile, search_radius, candidate_agent, sprite_scale_override)
	if free_tile.x < 0 or free_tile.y < 0:
		return world.tile_to_world_center(desired_tile)
	return world.tile_to_world_center(free_tile)


static func _append_unique_buddy(agent: Node, buddy: Node) -> void:
	if not is_instance_valid(agent) or not is_instance_valid(buddy):
		return
	var buddies = agent.get("trade_buddies")
	if typeof(buddies) != TYPE_ARRAY:
		return
	if buddies.has(buddy):
		return
	buddies.append(buddy)
	agent.set("trade_buddies", buddies)


static func ensure_spawn_buddy_link(spawned_agent: Node, anchor: Variant) -> void:
	if not is_instance_valid(spawned_agent) or not is_instance_valid(anchor):
		return
	if anchor.get("dead") == true:
		return
	if anchor.get("type") != "myco":
		return
	_append_unique_buddy(spawned_agent, anchor)
	if spawned_agent.get("type") == "myco":
		_append_unique_buddy(anchor, spawned_agent)
	spawned_agent.new_buddies = true
	anchor.new_buddies = true
	anchor.draw_lines = true
	if spawned_agent.get("type") == "myco":
		spawned_agent.draw_lines = true


static func _is_agent_trade_locked(agent: Variant) -> bool:
	if not is_instance_valid(agent):
		return false
	if bool(agent.get("dead")):
		return false
	if agent.has_method("is_trade_locked_by_user_move"):
		return bool(agent.call("is_trade_locked_by_user_move"))
	return false


static func refresh_trade_line_visuals(lines_root: Node) -> void:
	if not is_instance_valid(lines_root):
		return
	for line in lines_root.get_children():
		if not (line is Line2D):
			continue
		var base_color = line.modulate
		var base_color_meta = line.get_meta("base_color", null)
		if typeof(base_color_meta) == TYPE_COLOR:
			base_color = base_color_meta

		var endpoint_a = line.get_meta("endpoint_a", null)
		var endpoint_b = line.get_meta("endpoint_b", null)
		var locked = _is_agent_trade_locked(endpoint_a) or _is_agent_trade_locked(endpoint_b)

		var target_color = base_color
		if locked:
			target_color.a = base_color.a * 0.25
		if line.modulate != target_color:
			line.modulate = target_color


static func clear_inventory_connection_preview_lines(preview_lines: Array) -> void:
	for line in preview_lines:
		if is_instance_valid(line):
			line.queue_free()
	preview_lines.clear()


static func _is_preview_candidate(agent: Node) -> bool:
	if not is_instance_valid(agent):
		return false
	if bool(agent.get("dead")):
		return false
	return true


static func _get_preview_myco_radius(agents_root: Node) -> float:
	if not is_instance_valid(agents_root):
		return 200.0
	for agent in agents_root.get_children():
		if not _is_preview_candidate(agent):
			continue
		if str(agent.get("type")) != "myco":
			continue
		var reach = agent.get("buddy_radius")
		if typeof(reach) == TYPE_FLOAT or typeof(reach) == TYPE_INT:
			return max(float(reach), 24.0)
	return 200.0


static func _resolve_preview_anchor(level_root: Node, world_pos: Vector2) -> Variant:
	if not is_instance_valid(level_root):
		return world_pos
	var world = _get_world_foundation(level_root)
	if not is_instance_valid(world):
		return world_pos
	if world.has_method("world_to_tile") and world.has_method("tile_to_world_center"):
		var coord = world.world_to_tile(world_pos)
		if world.has_method("in_bounds") and not world.in_bounds(coord):
			return null
		return world.tile_to_world_center(coord)
	return world_pos


static func _add_preview_l_pair(lines_root: Node, preview_lines: Array, from_world: Vector2, to_world: Vector2, color: Color) -> void:
	if not is_instance_valid(lines_root):
		return
	var new_pos1 = Vector2(to_world.x, from_world.y)
	var new_pos2 = Vector2(from_world.x, to_world.y)

	var line1 = Line2D.new()
	line1.width = 2
	line1.z_as_relative = false
	line1.antialiased = true
	line1.modulate = color
	line1.add_point(from_world)
	line1.add_point(new_pos1)
	line1.add_point(to_world)
	lines_root.add_child(line1)
	preview_lines.append(line1)

	var line2 = Line2D.new()
	line2.width = 2
	line2.z_as_relative = false
	line2.antialiased = true
	line2.modulate = color
	line2.add_point(from_world)
	line2.add_point(new_pos2)
	line2.add_point(to_world)
	lines_root.add_child(line2)
	preview_lines.append(line2)


static func update_inventory_connection_preview(level_root: Node, agents_root: Node, lines_root: Node, preview_lines: Array, dragged_agent_type: String, world_pos: Vector2, active: bool) -> void:
	clear_inventory_connection_preview_lines(preview_lines)
	if not active:
		return
	if not is_instance_valid(agents_root) or not is_instance_valid(lines_root):
		return

	var anchor_variant = _resolve_preview_anchor(level_root, world_pos)
	if typeof(anchor_variant) != TYPE_VECTOR2:
		return
	var anchor_world: Vector2 = anchor_variant

	var preview_color = Color(Color.ANTIQUE_WHITE, 0.3)
	if Global.social_mode:
		preview_color = Color(Color.SADDLE_BROWN, 0.3)

	var safe_type = str(dragged_agent_type)
	var preview_is_myco = safe_type == "myco"
	var myco_radius = _get_preview_myco_radius(agents_root)
	for agent in agents_root.get_children():
		if not _is_preview_candidate(agent):
			continue
		var agent_type = str(agent.get("type"))
		if preview_is_myco:
			if agent_type == "myco" or agent_type == "cloud":
				continue
			if anchor_world.distance_to(agent.global_position) > myco_radius:
				continue
			_add_preview_l_pair(lines_root, preview_lines, anchor_world, agent.global_position, preview_color)
		else:
			if agent_type != "myco":
				continue
			var reach = agent.get("buddy_radius")
			var buddy_radius = myco_radius
			if typeof(reach) == TYPE_FLOAT or typeof(reach) == TYPE_INT:
				buddy_radius = max(float(reach), 24.0)
			if anchor_world.distance_to(agent.global_position) > buddy_radius:
				continue
			_add_preview_l_pair(lines_root, preview_lines, agent.global_position, anchor_world, preview_color)


static func stop_audio_players(players: Array) -> void:
	for player in players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
