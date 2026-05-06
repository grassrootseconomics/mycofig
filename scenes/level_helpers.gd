extends RefCounted
class_name LevelHelpers

const HOTKEY_SPEED_UP := [KEY_PLUS, KEY_EQUAL]
const HOTKEY_SPEED_DOWN := [KEY_MINUS, KEY_UNDERSCORE]
const HOTKEY_QUIT := [KEY_ESCAPE, KEY_Q]
const HOTKEY_TOGGLE_BARS := [KEY_B]
const HOTKEY_TOGGLE_BABY := [KEY_M]
const HOTKEY_TOGGLE_REPOSITION := [KEY_G]
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
	refresh_agent_bar_visibility(agents_root)


static func refresh_agent_bar_visibility(agents_root: Node) -> void:
	if not is_instance_valid(agents_root):
		return
	for agent in agents_root.get_children():
		if not is_instance_valid(agent):
			continue
		if agent.has_method("refresh_bar_visibility"):
			agent.refresh_bar_visibility()
			continue
		var canvas = agent.get("bar_canvas")
		if is_instance_valid(canvas):
			canvas.visible = Global.bars_on


static func clear_selection_boxes(level_root: Node) -> void:
	if not is_instance_valid(level_root):
		return
	var boxes = level_root.get_node_or_null("Boxes")
	if is_instance_valid(boxes):
		for box in boxes.get_children():
			if box.has_method("clear_points"):
				box.clear_points()
			box.queue_free()
	level_root.set_meta("focus_outline_agent_id", -1)


static func set_agent_focus_outline(level_root: Node, focus_agent: Variant) -> void:
	if not is_instance_valid(level_root):
		return
	var current_id := -1
	if level_root.has_meta("focus_outline_agent_id"):
		current_id = int(level_root.get_meta("focus_outline_agent_id"))
	var next_id := -1
	if is_instance_valid(focus_agent):
		next_id = int(focus_agent.get_instance_id())
	if current_id == next_id:
		return
	clear_selection_boxes(level_root)
	if not is_instance_valid(focus_agent):
		return
	if focus_agent.has_method("draw_selected_box"):
		focus_agent.draw_selected_box()
	level_root.set_meta("focus_outline_agent_id", next_id)


static func clear_focus_outline_if_owner(level_root: Node, owner_agent: Variant) -> void:
	if not is_instance_valid(level_root) or not is_instance_valid(owner_agent):
		return
	if not level_root.has_meta("focus_outline_agent_id"):
		return
	var current_id = int(level_root.get_meta("focus_outline_agent_id"))
	if current_id != int(owner_agent.get_instance_id()):
		return
	clear_selection_boxes(level_root)


static func clear_mobile_selection_and_bars(level_root: Node, agents_root: Node) -> void:
	if not Global.is_mobile_platform:
		return
	Global.active_agent = null
	Global.bars_on = false
	Global.prevent_auto_select = true
	clear_selection_boxes(level_root)
	refresh_agent_bar_visibility(agents_root)


static func _pointer_over_core_ui(level_root: Node, screen_pos: Vector2) -> bool:
	if not is_instance_valid(level_root):
		return false
	var ui = level_root.get_node_or_null("UI")
	if not is_instance_valid(ui):
		return false
	var panel = ui.get_node_or_null("MarginContainer")
	if is_instance_valid(panel) and panel.visible and panel.get_global_rect().has_point(screen_pos):
		return true
	var restart = ui.get_node_or_null("RestartContainer")
	if is_instance_valid(restart) and restart.visible and restart.get_global_rect().has_point(screen_pos):
		return true
	var tutorial_box = ui.get_node_or_null("TutorialMarginContainer1")
	if is_instance_valid(tutorial_box) and tutorial_box.visible and tutorial_box.get_global_rect().has_point(screen_pos):
		return true
	return false


static func _agent_supports_hover_focus(agent: Variant) -> bool:
	if not is_instance_valid(agent):
		return false
	if bool(agent.get("dead")):
		return false
	if str(agent.get("type")) == "cloud":
		return false
	return agent.has_method("set_hover_focus")


static func _screen_over_agent(agent: Node, screen_pos: Vector2) -> bool:
	if not is_instance_valid(agent):
		return false
	var sprite = agent.get("sprite")
	if not is_instance_valid(sprite) or not sprite.has_method("get_rect"):
		return false
	var world_pos = Global.screen_to_world(agent, screen_pos)
	return sprite.get_rect().has_point(agent.to_local(world_pos))


static func _resolve_hovered_agent_from_cell(level_root: Node, agents_root: Node, screen_pos: Vector2) -> Node:
	var world = _get_world_foundation(level_root)
	if not is_instance_valid(world):
		return null
	if not (world.has_method("world_to_tile") and world.has_method("in_bounds")):
		return null
	var world_pos = Global.screen_to_world(level_root, screen_pos)
	var coord = Vector2i(world.world_to_tile(world_pos))
	if not world.in_bounds(coord):
		return null
	var has_cached_occupancy = world.has_method("get_tile_occupants_cached")
	if has_cached_occupancy:
		var occupants_variant = world.get_tile_occupants_cached(coord)
		if typeof(occupants_variant) == TYPE_ARRAY:
			var occupants: Array = occupants_variant
			var best: Node = null
			var best_dist := INF
			for occupant in occupants:
				if not _agent_supports_hover_focus(occupant):
					continue
				var dist = occupant.global_position.distance_squared_to(world_pos)
				if dist < best_dist:
					best_dist = dist
					best = occupant
			return best
		# Tile-world hover should remain cell-based; if cached occupancy exists but no
		# valid array/occupant is found, do not fall back to sprite bounds.
		return null
	# Fallback for scenes/worlds that do not expose cached occupancy query.
	var agents = agents_root.get_children()
	for idx in range(agents.size() - 1, -1, -1):
		var agent = agents[idx]
		if not _agent_supports_hover_focus(agent):
			continue
		if not _screen_over_agent(agent, screen_pos):
			continue
		return agent
	return null


static func update_agent_hover_focus(level_root: Node, agents_root: Node) -> void:
	if not is_instance_valid(level_root) or not is_instance_valid(agents_root):
		return
	if Global.is_dragging:
		for agent in agents_root.get_children():
			if _agent_supports_hover_focus(agent):
				agent.set_hover_focus(bool(agent.get("is_dragging")))
		return
	if Global.is_mobile_platform:
		for agent in agents_root.get_children():
			if _agent_supports_hover_focus(agent):
				agent.set_hover_focus(false)
		return
	var viewport = level_root.get_viewport()
	if viewport == null:
		return
	var screen_pos = viewport.get_mouse_position()
	var hovered_agent: Node = null
	if not _pointer_over_core_ui(level_root, screen_pos):
		hovered_agent = _resolve_hovered_agent_from_cell(level_root, agents_root, screen_pos)
	for agent in agents_root.get_children():
		if _agent_supports_hover_focus(agent):
			agent.set_hover_focus(agent == hovered_agent)


static func handle_gameplay_hotkeys(event: InputEvent, owner: Node, agents_root: Node, include_connector_keys: bool = false) -> bool:
	if _is_pressed_key(event, HOTKEY_SPEED_UP):
		Global.move_rate += 1
		Global.movement_speed += 50
		return true

	if _is_pressed_key(event, HOTKEY_SPEED_DOWN):
		Global.move_rate = maxi(Global.move_rate - 1, 1)
		Global.movement_speed = maxi(Global.movement_speed - 50, 1)
		return true

	if _is_pressed_key(event, HOTKEY_QUIT):
		if is_instance_valid(owner):
			owner.get_tree().call_deferred("change_scene_to_file", "res://scenes/game_over.tscn")
		return true

	if _is_pressed_key(event, HOTKEY_TOGGLE_BARS):
		Global.bars_on = not Global.bars_on
		refresh_agent_bar_visibility(agents_root)
		return true

	if _is_pressed_key(event, HOTKEY_TOGGLE_BABY):
		Global.baby_mode = not Global.baby_mode
		return true

	if _is_pressed_key(event, HOTKEY_TOGGLE_REPOSITION):
		Global.allow_agent_reposition = not Global.allow_agent_reposition
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


static func _queue_agent_dirty(level_root: Node, agent: Variant, buddies: bool = true, lines: bool = true, tile_hint: bool = false) -> void:
	if not is_instance_valid(agent):
		return
	if is_instance_valid(level_root) and level_root.has_method("request_agent_dirty"):
		level_root.request_agent_dirty(agent, buddies, lines, tile_hint)
		return
	if buddies:
		agent.new_buddies = true
	if lines and agent.get("type") == "myco":
		agent.draw_lines = true


static func mark_myco_lines_dirty(agents_root: Node) -> void:
	if not is_instance_valid(agents_root):
		return
	var level_root = agents_root.get_parent()
	for agent in agents_root.get_children():
		if agent.get("type") == "myco":
			_queue_agent_dirty(level_root, agent, false, true, false)


static func mark_all_buddies_dirty(agents_root: Node) -> void:
	if not is_instance_valid(agents_root):
		return
	var level_root = agents_root.get_parent()
	for agent in agents_root.get_children():
		_queue_agent_dirty(level_root, agent, true, true, false)


static func _get_world_foundation(level_root: Node) -> Node:
	if not is_instance_valid(level_root):
		return null
	return level_root.get_node_or_null("WorldFoundation")


static func _supports_tile_world(level_root: Node) -> bool:
	var world = _get_world_foundation(level_root)
	if not is_instance_valid(world):
		return false
	return world.has_method("world_to_tile") and world.has_method("tile_to_world_center") and world.has_method("in_bounds")


static func rebuild_world_occupancy_cache(level_root: Node, agents_root: Node) -> void:
	var world = _get_world_foundation(level_root)
	if not is_instance_valid(world):
		return
	if world.has_method("rebuild_occupancy_cache"):
		world.rebuild_occupancy_cache(level_root, agents_root)


static func sync_agent_occupancy(level_root: Node, agent: Variant) -> void:
	var world = _get_world_foundation(level_root)
	if not is_instance_valid(world):
		return
	if world.has_method("sync_agent_footprint"):
		world.sync_agent_footprint(level_root, agent)


static func unregister_agent_occupancy(level_root: Node, agent: Variant) -> void:
	var world = _get_world_foundation(level_root)
	if not is_instance_valid(world):
		return
	if world.has_method("unregister_agent_footprint"):
		world.unregister_agent_footprint(agent)


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


static func _is_two_tile_vertical_tree(agent: Node) -> bool:
	if not is_instance_valid(agent):
		return false
	if str(agent.get("type")) != "tree":
		return false
	# Plants-mode tree occupies base tile + tile above from seedling onward.
	return not bool(Global.social_mode)


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

	if _is_two_tile_vertical_tree(agent):
		var base_tile = _clamp_tile_to_world(world, world.world_to_tile(center))
		occupied_tiles.append(base_tile)
		occupied_tiles.append(base_tile + Vector2i(0, -1))
		return occupied_tiles

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
	if _agent_uses_multi_tile_occupancy(candidate_agent) and not _is_two_tile_vertical_tree(candidate_agent):
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

	var ignore_agent = ignore
	if not is_instance_valid(ignore_agent):
		ignore_agent = candidate_agent
	if world.has_method("is_tile_occupied_cached"):
		for coord in candidate_tiles:
			if world.is_tile_occupied_cached(coord, ignore_agent):
				return false
		return true

	for agent in agents_root.get_children():
		if not _is_tile_blocking_agent(agent):
			continue
		if is_instance_valid(ignore_agent) and agent == ignore_agent:
			continue
		if agent == candidate_agent:
			continue
		var occupied_tiles = get_agent_occupied_tiles(level_root, agent)
		for coord in candidate_tiles:
			Global.perf_count_tile_occupancy_query()
			if occupied_tiles.has(coord):
				return false

	return true


static func is_tile_occupied(level_root: Node, agents_root: Node, coord: Vector2i, ignore: Node = null) -> bool:
	if not _supports_tile_world(level_root):
		return false
	if not is_instance_valid(agents_root):
		return false
	var world = _get_world_foundation(level_root)
	if is_instance_valid(world) and world.has_method("is_tile_occupied_cached"):
		return world.is_tile_occupied_cached(coord, ignore)
	for agent in agents_root.get_children():
		if not _is_tile_blocking_agent(agent):
			continue
		if is_instance_valid(ignore) and agent == ignore:
			continue
		Global.perf_count_tile_occupancy_query()
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
	var level_root = spawned_agent.get_node_or_null("../..")
	_queue_agent_dirty(level_root, spawned_agent, true, true, false)
	_queue_agent_dirty(level_root, anchor, true, true, false)


static func _get_agent_interaction_radius(agent: Variant) -> float:
	if not is_instance_valid(agent):
		return 96.0
	var buddy_radius = agent.get("buddy_radius")
	if typeof(buddy_radius) == TYPE_FLOAT or typeof(buddy_radius) == TYPE_INT:
		return maxf(float(buddy_radius), 64.0)
	return 96.0


static func mark_agents_dirty_for_movement(level_root: Node, agents_root: Node, moved_agent: Variant, old_pos: Vector2, new_pos: Vector2) -> void:
	if not is_instance_valid(moved_agent) or not is_instance_valid(agents_root):
		return
	_queue_agent_dirty(level_root, moved_agent, true, true, true)
	var moved_reach = _get_agent_interaction_radius(moved_agent)
	for agent in agents_root.get_children():
		if not is_instance_valid(agent):
			continue
		if agent == moved_agent:
			continue
		if bool(agent.get("dead")):
			continue
		if str(agent.get("type")) == "cloud":
			continue
		var pair_reach = maxf(moved_reach, _get_agent_interaction_radius(agent)) + 48.0
		var near_old = agent.global_position.distance_to(old_pos) <= pair_reach
		var near_new = agent.global_position.distance_to(new_pos) <= pair_reach
		if near_old or near_new:
			_queue_agent_dirty(level_root, agent, true, true, false)


static func _line_pair_key(agent_a: Variant, agent_b: Variant) -> String:
	if not is_instance_valid(agent_a) or not is_instance_valid(agent_b):
		return ""
	var a_id = int(agent_a.get_instance_id())
	var b_id = int(agent_b.get_instance_id())
	if a_id == b_id:
		return ""
	if a_id < b_id:
		return str(a_id, ":", b_id)
	return str(b_id, ":", a_id)


static func _get_line_pairs_store(lines_root: Node) -> Dictionary:
	if not is_instance_valid(lines_root):
		return {}
	if lines_root.has_meta("trade_line_pairs"):
		var store_variant = lines_root.get_meta("trade_line_pairs")
		if typeof(store_variant) == TYPE_DICTIONARY:
			return store_variant
	var store := {}
	lines_root.set_meta("trade_line_pairs", store)
	return store


static func _set_line_pairs_store(lines_root: Node, store: Dictionary) -> void:
	if is_instance_valid(lines_root):
		lines_root.set_meta("trade_line_pairs", store)


static func _get_line_meta_store(lines_root: Node) -> Dictionary:
	if not is_instance_valid(lines_root):
		return {}
	if lines_root.has_meta("trade_line_meta"):
		var store_variant = lines_root.get_meta("trade_line_meta")
		if typeof(store_variant) == TYPE_DICTIONARY:
			return store_variant
	var store := {}
	lines_root.set_meta("trade_line_meta", store)
	return store


static func _set_line_meta_store(lines_root: Node, store: Dictionary) -> void:
	if is_instance_valid(lines_root):
		lines_root.set_meta("trade_line_meta", store)


static func _get_line_agent_index_store(lines_root: Node) -> Dictionary:
	if not is_instance_valid(lines_root):
		return {}
	if lines_root.has_meta("trade_line_agent_index"):
		var store_variant = lines_root.get_meta("trade_line_agent_index")
		if typeof(store_variant) == TYPE_DICTIONARY:
			return store_variant
	var store := {}
	lines_root.set_meta("trade_line_agent_index", store)
	return store


static func _set_line_agent_index_store(lines_root: Node, store: Dictionary) -> void:
	if is_instance_valid(lines_root):
		lines_root.set_meta("trade_line_agent_index", store)


static func _get_line_pool_store(lines_root: Node) -> Array:
	if not is_instance_valid(lines_root):
		return []
	if lines_root.has_meta("trade_line_pool"):
		var pool_variant = lines_root.get_meta("trade_line_pool")
		if typeof(pool_variant) == TYPE_ARRAY:
			return pool_variant
	var pool: Array = []
	lines_root.set_meta("trade_line_pool", pool)
	return pool


static func _set_line_pool_store(lines_root: Node, pool: Array) -> void:
	if is_instance_valid(lines_root):
		lines_root.set_meta("trade_line_pool", pool)


static func _acquire_trade_line(lines_root: Node) -> Line2D:
	var pool = _get_line_pool_store(lines_root)
	var line: Line2D = null
	if not pool.is_empty():
		line = pool.pop_back()
	_set_line_pool_store(lines_root, pool)
	if not is_instance_valid(line):
		line = Line2D.new()
		line.z_as_relative = false
	if line.get_parent() != lines_root:
		lines_root.add_child(line)
	line.visible = true
	line.clear_points()
	return line


static func _release_trade_line(lines_root: Node, line: Variant) -> void:
	if not is_instance_valid(lines_root) or not (line is Line2D):
		return
	var line_node: Line2D = line
	line_node.clear_points()
	line_node.visible = false
	if line_node.get_parent() != lines_root:
		lines_root.add_child(line_node)
	var pool = _get_line_pool_store(lines_root)
	pool.append(line_node)
	_set_line_pool_store(lines_root, pool)


static func _is_trade_line_agent_valid(agent: Variant) -> bool:
	if not is_instance_valid(agent):
		return false
	if bool(agent.get("dead")):
		return false
	return str(agent.get("type")) != "cloud"


static func _is_myco_trade_agent(agent: Variant) -> bool:
	return _is_trade_line_agent_valid(agent) and str(agent.get("type")) == "myco"


static func _line_base_color(social_mode: bool) -> Color:
	if social_mode:
		return Color(Color.SADDLE_BROWN, 0.3)
	return Color(Color.ANTIQUE_WHITE, 0.3)


static func _sort_pair_endpoints(agent_a: Variant, agent_b: Variant) -> Dictionary:
	var first = agent_a
	var second = agent_b
	if int(agent_a.get_instance_id()) > int(agent_b.get_instance_id()):
		first = agent_b
		second = agent_a
	return {"a": first, "b": second}


static func _has_trade_buddy_link(agent: Variant, buddy: Variant) -> bool:
	if not is_instance_valid(agent) or not is_instance_valid(buddy):
		return false
	var buddies_variant = agent.get("trade_buddies")
	if typeof(buddies_variant) != TYPE_ARRAY:
		return false
	var buddies: Array = buddies_variant
	for linked in buddies:
		if linked == buddy:
			return true
	return false


static func _should_pair_exist(agent_a: Variant, agent_b: Variant) -> bool:
	if not _is_trade_line_agent_valid(agent_a) or not _is_trade_line_agent_valid(agent_b):
		return false
	if not (_is_myco_trade_agent(agent_a) or _is_myco_trade_agent(agent_b)):
		return false
	return _has_trade_buddy_link(agent_a, agent_b) or _has_trade_buddy_link(agent_b, agent_a)


static func _collect_desired_pairs_for_agent(agent: Variant) -> Dictionary:
	var desired: Dictionary = {}
	if not _is_trade_line_agent_valid(agent):
		return desired
	var buddies_variant = agent.get("trade_buddies")
	if typeof(buddies_variant) != TYPE_ARRAY:
		return desired
	var buddies: Array = buddies_variant
	for buddy in buddies:
		if not _is_trade_line_agent_valid(buddy):
			continue
		if not _is_myco_trade_agent(buddy):
			continue
		var pair_key = _line_pair_key(agent, buddy)
		if pair_key == "":
			continue
		if desired.has(pair_key):
			continue
		desired[pair_key] = _sort_pair_endpoints(agent, buddy)
	return desired


static func _pair_keys_for_agent(agent_index: Dictionary, agent: Variant) -> Array:
	if not is_instance_valid(agent):
		return []
	var id = int(agent.get_instance_id())
	if not agent_index.has(id):
		return []
	var keys_variant = agent_index[id]
	if typeof(keys_variant) == TYPE_DICTIONARY:
		return keys_variant.keys()
	if typeof(keys_variant) == TYPE_ARRAY:
		return keys_variant
	return []


static func _add_pair_to_agent_index(agent_index: Dictionary, agent: Variant, pair_key: String) -> void:
	if not is_instance_valid(agent) or pair_key == "":
		return
	var id = int(agent.get_instance_id())
	var keys: Dictionary = {}
	if agent_index.has(id) and typeof(agent_index[id]) == TYPE_DICTIONARY:
		keys = agent_index[id]
	keys[pair_key] = true
	agent_index[id] = keys


static func _remove_pair_from_agent_index(agent_index: Dictionary, agent: Variant, pair_key: String) -> void:
	if not is_instance_valid(agent) or pair_key == "":
		return
	var id = int(agent.get_instance_id())
	if not agent_index.has(id):
		return
	var keys_variant = agent_index[id]
	if typeof(keys_variant) != TYPE_DICTIONARY:
		agent_index.erase(id)
		return
	var keys: Dictionary = keys_variant
	keys.erase(pair_key)
	if keys.is_empty():
		agent_index.erase(id)
	else:
		agent_index[id] = keys


static func _release_pair_from_stores(lines_root: Node, pair_store: Dictionary, pair_meta: Dictionary, agent_index: Dictionary, pair_key: String) -> void:
	if pair_store.has(pair_key):
		var pair_variant = pair_store[pair_key]
		if typeof(pair_variant) == TYPE_ARRAY:
			var pair_lines: Array = pair_variant
			for line_variant in pair_lines:
				_release_trade_line(lines_root, line_variant)
		pair_store.erase(pair_key)
	if pair_meta.has(pair_key):
		var meta_variant = pair_meta[pair_key]
		if typeof(meta_variant) == TYPE_DICTIONARY:
			var meta: Dictionary = meta_variant
			_remove_pair_from_agent_index(agent_index, meta.get("a", null), pair_key)
			_remove_pair_from_agent_index(agent_index, meta.get("b", null), pair_key)
		pair_meta.erase(pair_key)


static func _configure_pair_lines(line1: Line2D, line2: Line2D, endpoint_a: Node, endpoint_b: Node, base_color: Color, pair_key: String) -> void:
	var antialias = Global.get_effective_perf_tier() <= 1
	var width = 2.0 if antialias else 1.5
	var from = endpoint_a.global_position
	var to = endpoint_b.global_position
	var elbow1 = Vector2(to.x, from.y)
	var elbow2 = Vector2(from.x, to.y)
	var lines_to_update = [line1, line2]
	for line in lines_to_update:
		line.width = width
		line.antialiased = antialias
		line.z_as_relative = false
		line.global_rotation = 0.0
		line.visible = true
		line.modulate = base_color
		line.set_meta("endpoint_a", endpoint_a)
		line.set_meta("endpoint_b", endpoint_b)
		line.set_meta("base_color", base_color)
		line.set_meta("pair_key", pair_key)
		line.clear_points()
	line1.add_point(from)
	line1.add_point(elbow1)
	line1.add_point(to)
	line2.add_point(from)
	line2.add_point(elbow2)
	line2.add_point(to)


static func _upsert_pair(lines_root: Node, pair_store: Dictionary, pair_meta: Dictionary, agent_index: Dictionary, pair_key: String, endpoint_a: Node, endpoint_b: Node, base_color: Color) -> void:
	var lines_variant = pair_store.get(pair_key, [])
	var pair_lines: Array = lines_variant if typeof(lines_variant) == TYPE_ARRAY else []
	var line1: Line2D = null
	var line2: Line2D = null
	if pair_lines.size() >= 2:
		if pair_lines[0] is Line2D and is_instance_valid(pair_lines[0]):
			line1 = pair_lines[0]
		if pair_lines[1] is Line2D and is_instance_valid(pair_lines[1]):
			line2 = pair_lines[1]
	if not is_instance_valid(line1):
		line1 = _acquire_trade_line(lines_root)
	elif line1.get_parent() != lines_root:
		lines_root.add_child(line1)
	if not is_instance_valid(line2):
		line2 = _acquire_trade_line(lines_root)
	elif line2.get_parent() != lines_root:
		lines_root.add_child(line2)

	_configure_pair_lines(line1, line2, endpoint_a, endpoint_b, base_color, pair_key)
	pair_store[pair_key] = [line1, line2]
	pair_meta[pair_key] = {"a": endpoint_a, "b": endpoint_b}
	_add_pair_to_agent_index(agent_index, endpoint_a, pair_key)
	_add_pair_to_agent_index(agent_index, endpoint_b, pair_key)


static func _prune_invalid_pair_cache(lines_root: Node, pair_store: Dictionary, pair_meta: Dictionary, agent_index: Dictionary) -> void:
	var stale_keys: Array = []
	for key_variant in pair_meta.keys():
		var pair_key = str(key_variant)
		var meta_variant = pair_meta[pair_key]
		if typeof(meta_variant) != TYPE_DICTIONARY:
			stale_keys.append(pair_key)
			continue
		var meta: Dictionary = meta_variant
		var endpoint_a = meta.get("a", null)
		var endpoint_b = meta.get("b", null)
		if not _should_pair_exist(endpoint_a, endpoint_b):
			stale_keys.append(pair_key)
	for pair_key_variant in stale_keys:
		_release_pair_from_stores(lines_root, pair_store, pair_meta, agent_index, str(pair_key_variant))


static func sync_myco_trade_lines(lines_root: Node, agents_root: Node, social_mode: bool = false, dirty_agents: Array = []) -> void:
	if not is_instance_valid(lines_root) or not is_instance_valid(agents_root):
		return
	var pair_store = _get_line_pairs_store(lines_root)
	var pair_meta = _get_line_meta_store(lines_root)
	var agent_index = _get_line_agent_index_store(lines_root)
	var base_color = _line_base_color(social_mode)

	_prune_invalid_pair_cache(lines_root, pair_store, pair_meta, agent_index)

	var dirty_lookup: Dictionary = {}
	for agent in dirty_agents:
		if not is_instance_valid(agent):
			continue
		dirty_lookup[int(agent.get_instance_id())] = agent
	if dirty_lookup.is_empty() and pair_store.is_empty():
		for agent in agents_root.get_children():
			if not is_instance_valid(agent):
				continue
			dirty_lookup[int(agent.get_instance_id())] = agent
	if dirty_lookup.is_empty():
		_set_line_pairs_store(lines_root, pair_store)
		_set_line_meta_store(lines_root, pair_meta)
		_set_line_agent_index_store(lines_root, agent_index)
		return

	var desired_pairs: Dictionary = {}
	var keys_to_process: Dictionary = {}
	for key_variant in dirty_lookup.keys():
		var agent = dirty_lookup[key_variant]
		for pair_key_variant in _pair_keys_for_agent(agent_index, agent):
			keys_to_process[str(pair_key_variant)] = true
		var desired_for_agent = _collect_desired_pairs_for_agent(agent)
		for pair_key_variant in desired_for_agent.keys():
			var pair_key = str(pair_key_variant)
			desired_pairs[pair_key] = desired_for_agent[pair_key_variant]
			keys_to_process[pair_key] = true

	for pair_key_variant in keys_to_process.keys():
		var pair_key = str(pair_key_variant)
		var endpoints: Dictionary = {}
		if desired_pairs.has(pair_key):
			endpoints = desired_pairs[pair_key]
		elif pair_meta.has(pair_key):
			var meta_variant = pair_meta[pair_key]
			if typeof(meta_variant) == TYPE_DICTIONARY:
				endpoints = meta_variant
		var endpoint_a = endpoints.get("a", null)
		var endpoint_b = endpoints.get("b", null)
		if not _should_pair_exist(endpoint_a, endpoint_b):
			_release_pair_from_stores(lines_root, pair_store, pair_meta, agent_index, pair_key)
			continue
		var sorted_endpoints = _sort_pair_endpoints(endpoint_a, endpoint_b)
		_upsert_pair(lines_root, pair_store, pair_meta, agent_index, pair_key, sorted_endpoints["a"], sorted_endpoints["b"], base_color)

	_set_line_pairs_store(lines_root, pair_store)
	_set_line_meta_store(lines_root, pair_meta)
	_set_line_agent_index_store(lines_root, agent_index)


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
		if not line.visible:
			continue
		var base_color = line.modulate
		if line.has_meta("base_color"):
			var base_color_meta = line.get_meta("base_color")
			if typeof(base_color_meta) == TYPE_COLOR:
				base_color = base_color_meta

		var endpoint_a = null
		if line.has_meta("endpoint_a"):
			endpoint_a = line.get_meta("endpoint_a")
		var endpoint_b = null
		if line.has_meta("endpoint_b"):
			endpoint_b = line.get_meta("endpoint_b")
		var locked = _is_agent_trade_locked(endpoint_a) or _is_agent_trade_locked(endpoint_b)

		var target_color = base_color
		if locked:
			target_color.a = base_color.a * 0.25
		if line.modulate != target_color:
			line.modulate = target_color


static func clear_trade_line_cache(lines_root: Node, immediate: bool = false) -> void:
	if not is_instance_valid(lines_root):
		return
	var seen: Dictionary = {}
	var pair_store = _get_line_pairs_store(lines_root)
	for pair_key in pair_store.keys():
		var pair_variant = pair_store[pair_key]
		if typeof(pair_variant) != TYPE_ARRAY:
			continue
		var pair_lines: Array = pair_variant
		for line_variant in pair_lines:
			if not (line_variant is Line2D):
				continue
			var line: Line2D = line_variant
			if not is_instance_valid(line):
				continue
			var line_id = int(line.get_instance_id())
			if seen.has(line_id):
				continue
			seen[line_id] = true
			if immediate:
				if line.get_parent() != null:
					line.get_parent().remove_child(line)
				line.free()
			else:
				line.queue_free()
	var pool = _get_line_pool_store(lines_root)
	for line_variant in pool:
		if not (line_variant is Line2D):
			continue
		var line: Line2D = line_variant
		if not is_instance_valid(line):
			continue
		var line_id = int(line.get_instance_id())
		if seen.has(line_id):
			continue
		seen[line_id] = true
		if immediate:
			if line.get_parent() != null:
				line.get_parent().remove_child(line)
			line.free()
		else:
			line.queue_free()
	for child in lines_root.get_children():
		if child is Line2D and is_instance_valid(child):
			var line_id = int(child.get_instance_id())
			if seen.has(line_id):
				continue
			seen[line_id] = true
			if immediate:
				if child.get_parent() != null:
					child.get_parent().remove_child(child)
				child.free()
			else:
				child.queue_free()
	_set_line_pairs_store(lines_root, {})
	_set_line_meta_store(lines_root, {})
	_set_line_agent_index_store(lines_root, {})
	_set_line_pool_store(lines_root, [])


static func clear_inventory_connection_preview_lines(preview_lines: Array, immediate: bool = false) -> void:
	for line in preview_lines:
		if is_instance_valid(line):
			if immediate:
				if line.get_parent() != null:
					line.get_parent().remove_child(line)
				line.free()
			else:
				line.queue_free()
	preview_lines.clear()


static func _is_preview_candidate(agent: Node) -> bool:
	if not is_instance_valid(agent):
		return false
	if bool(agent.get("dead")):
		return false
	return true


static func _is_story_mode_runtime() -> bool:
	return str(Global.mode) == "story"


static func _is_story_village_actor_node(node: Variant) -> bool:
	return is_instance_valid(node) and bool(node.get_meta("story_village_actor", false))


static func _is_preview_village_item_type(agent_type: String) -> bool:
	return agent_type == "farmer" or agent_type == "vendor" or agent_type == "cook" or agent_type == "basket" or agent_type == "bank"


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
	var preview_is_village_actor = _is_preview_village_item_type(safe_type)
	var myco_radius = _get_preview_myco_radius(agents_root)
	for agent in agents_root.get_children():
		if not _is_preview_candidate(agent):
			continue
		if _is_story_mode_runtime():
			var candidate_is_village_actor = _is_story_village_actor_node(agent)
			if preview_is_village_actor != candidate_is_village_actor:
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


static func stop_audio_players(players: Array, free_players: bool = false) -> void:
	for player in players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
			if free_players:
				if player.get_parent() != null:
					player.get_parent().remove_child(player)
				player.free()
