extends Node2D

#to run: python3 -m http.server  .. browse to localhost:8000

const LevelHelpersRef = preload("res://scenes/level_helpers.gd")
const PerfMonitorRef = preload("res://scenes/perf_monitor.gd")
const TEX_SQUASH = preload("res://graphics/squash.png")
const TEX_TREE = preload("res://graphics/acorn_32.png")
const TEX_MAIZE = preload("res://graphics/maize.png")
const TEX_BEAN = preload("res://graphics/bean.png")
const TEX_CLOUD = preload("res://graphics/cloud.png")
const TEX_MYCO = preload("res://graphics/mushroom_32.png")
const DEFAULT_PARENT_BOUND_RADIUS_TILES := 4
const MYCO_HEALTHY_ANCHOR_RADIUS_TILES := 4
const PARENT_BOUNDED_TYPES := {
	"myco": true,
	"bean": true,
	"squash": true,
	"maize": true
}

var plant_scene: PackedScene = load("res://scenes/plant.tscn")
var trade_scene: PackedScene = load("res://scenes/trade.tscn")
var myco_scene: PackedScene = load("res://scenes/myco.tscn")
var cloud_scene: PackedScene = load("res://scenes/cloud.tscn")
var bird_scene: PackedScene = load("res://scenes/bird.tscn")
var tuktuk_scene: PackedScene = load("res://scenes/tuktuk.tscn")
var ui_scene: PackedScene = load("res://scenes/ui.tscn")


var mid_width = 0
var mid_height = 0

var health : int = 3

var score_lvl = 0

var num_maize = 1
var num_beans = 1
var num_squash = 1

var is_dragging = false
var delay = 10
var inventory_preview_lines: Array = []
var perf_monitor: Node = null
var _line_visual_refresh_accum := 0.0
var _dirty_refresh_accum := 0.0
var _dirty_buddies_agents: Dictionary = {}
var _dirty_lines_agents: Dictionary = {}
var _dirty_tile_hints_agents: Dictionary = {}
var _trade_pool: Array = []
var _shutdown_cleanup_done := false


func _is_headless_runtime() -> bool:
	return DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server")


func _mute_runtime_audio_if_headless() -> void:
	if not _is_headless_runtime():
		return
	LevelHelpersRef.stop_audio_players([
		$BirdSound,
		$BirdLong,
		$CarSound,
		$SquelchSound,
		$TwinkleSound,
		$BushSound
	])


func _get_world_foundation() -> Node:
	return get_node_or_null("WorldFoundation")


func _get_world_center() -> Vector2:
	var world = _get_world_foundation()
	if is_instance_valid(world) and world.has_method("get_world_center"):
		return world.get_world_center()
	return Global.get_world_center(self)


func _resolve_tile_spawn_pos(pos: Vector2) -> Vector2:
	return LevelHelpersRef.resolve_snapped_spawn_position(self, $Agents, pos)


func _resolve_exact_tile_spawn_pos(pos: Vector2, ignore_agent: Variant = null) -> Dictionary:
	var result := {
		"ok": true,
		"pos": pos
	}
	var world = _get_world_foundation()
	if not is_instance_valid(world):
		return result
	if not (world.has_method("world_to_tile") and world.has_method("tile_to_world_center") and world.has_method("in_bounds")):
		return result
	var coord = Vector2i(world.world_to_tile(pos))
	if not world.in_bounds(coord):
		result["ok"] = false
		return result
	if LevelHelpersRef.is_tile_occupied(self, $Agents, coord, ignore_agent):
		result["ok"] = false
		return result
	result["pos"] = world.tile_to_world_center(coord)
	return result


func _find_replaceable_agent_at_world_pos(pos: Vector2, ignore_agent: Variant = null) -> Node:
	var world = _get_world_foundation()
	if not is_instance_valid(world):
		return null
	if not (world.has_method("world_to_tile") and world.has_method("tile_to_world_center") and world.has_method("in_bounds")):
		return null
	var coord = Vector2i(world.world_to_tile(pos))
	if not world.in_bounds(coord):
		return null
	for agent in $Agents.get_children():
		if not is_instance_valid(agent):
			continue
		if is_instance_valid(ignore_agent) and agent == ignore_agent:
			continue
		if bool(agent.get("dead")):
			continue
		if str(agent.get("type")) == "cloud":
			continue
		if not bool(agent.get("killable")):
			continue
		var occupied_tiles = LevelHelpersRef.get_agent_occupied_tiles(self, agent)
		if occupied_tiles.has(coord):
			return agent
	return null


func _supports_world_tiles(world: Node) -> bool:
	if not is_instance_valid(world):
		return false
	return world.has_method("world_to_tile") and world.has_method("tile_to_world_center") and world.has_method("in_bounds")


func _clamp_tile_coord(world: Node, coord: Vector2i) -> Vector2i:
	var columns = max(int(world.get("columns")), 1)
	var rows = max(int(world.get("rows")), 1)
	return Vector2i(
		clampi(coord.x, 0, columns - 1),
		clampi(coord.y, 0, rows - 1)
	)


func _tile_pos_from_center(world: Node, center: Vector2i, delta: Vector2i) -> Vector2:
	var coord = _clamp_tile_coord(world, center + delta)
	return world.tile_to_world_center(coord)


func _is_parent_bounded_spawn_type(spawn_name: String) -> bool:
	return PARENT_BOUNDED_TYPES.has(spawn_name)


func _tile_chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(abs(a.x - b.x), abs(a.y - b.y))


func _is_valid_parent_anchor(anchor: Variant, ignore_agent: Variant = null) -> bool:
	if not is_instance_valid(anchor):
		return false
	if is_instance_valid(ignore_agent) and anchor == ignore_agent:
		return false
	if bool(anchor.get("dead")):
		return false
	return str(anchor.get("type")) == "myco"


func _find_nearest_living_myco_anchor(spawn_pos: Vector2, ignore_agent: Variant = null) -> Node:
	var world = _get_world_foundation()
	var best_anchor: Node = null
	var best_dist := INF
	if _supports_world_tiles(world):
		var target_coord = _clamp_tile_coord(world, Vector2i(world.world_to_tile(spawn_pos)))
		for agent in $Agents.get_children():
			if not _is_valid_parent_anchor(agent, ignore_agent):
				continue
			var coord = _clamp_tile_coord(world, Vector2i(world.world_to_tile(agent.global_position)))
			var dist = float(_tile_chebyshev_distance(coord, target_coord))
			if dist < best_dist:
				best_dist = dist
				best_anchor = agent
		return best_anchor
	for agent in $Agents.get_children():
		if not _is_valid_parent_anchor(agent, ignore_agent):
			continue
		var dist = agent.global_position.distance_to(spawn_pos)
		if dist < best_dist:
			best_dist = dist
			best_anchor = agent
	return best_anchor


func _find_parent_bounded_open_tile(world: Node, start_coord: Vector2i, parent_coord: Vector2i, max_parent_tiles: int, ignore_agent: Variant = null) -> Vector2i:
	var safe_max = maxi(max_parent_tiles, 0)
	if safe_max <= 0:
		return Vector2i(-1, -1)
	var columns = max(int(world.get("columns")), 1)
	var rows = max(int(world.get("rows")), 1)
	var max_search = maxi(columns, rows)
	for radius in range(0, max_search + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if radius > 0 and abs(dx) != radius and abs(dy) != radius:
					continue
				var coord = start_coord + Vector2i(dx, dy)
				if not world.in_bounds(coord):
					continue
				if _tile_chebyshev_distance(coord, parent_coord) > safe_max:
					continue
				if LevelHelpersRef.is_tile_occupied(self, $Agents, coord, ignore_agent):
					continue
				return coord
	return Vector2i(-1, -1)


func _resolve_parent_bounded_spawn_pos(spawn_pos: Vector2, parent_anchor: Variant, max_parent_tiles: int, ignore_agent: Variant = null, require_exact_tile: bool = false) -> Dictionary:
	var result := {
		"ok": false,
		"pos": spawn_pos,
		"coord": Vector2i(-1, -1),
		"parent_coord": Vector2i(-1, -1)
	}
	var world = _get_world_foundation()
	if not _supports_world_tiles(world):
		result["ok"] = _is_valid_parent_anchor(parent_anchor, ignore_agent)
		return result
	if not _is_valid_parent_anchor(parent_anchor, ignore_agent):
		return result
	var safe_max = maxi(max_parent_tiles, 0)
	if safe_max <= 0:
		return result

	var desired_coord = _clamp_tile_coord(world, Vector2i(world.world_to_tile(spawn_pos)))
	var parent_coord = _clamp_tile_coord(world, Vector2i(world.world_to_tile(parent_anchor.global_position)))
	result["parent_coord"] = parent_coord
	var desired_in_range = _tile_chebyshev_distance(desired_coord, parent_coord) <= safe_max
	var resolved_coord = Vector2i(-1, -1)

	if desired_in_range:
		if require_exact_tile:
			if not LevelHelpersRef.is_tile_occupied(self, $Agents, desired_coord, ignore_agent):
				resolved_coord = desired_coord
		else:
			if not LevelHelpersRef.is_tile_occupied(self, $Agents, desired_coord, ignore_agent):
				resolved_coord = desired_coord
			else:
				resolved_coord = _find_parent_bounded_open_tile(world, desired_coord, parent_coord, safe_max, ignore_agent)
	else:
		resolved_coord = _find_parent_bounded_open_tile(world, desired_coord, parent_coord, safe_max, ignore_agent)

	if resolved_coord.x < 0 or resolved_coord.y < 0:
		return result
	result["ok"] = true
	result["coord"] = resolved_coord
	result["pos"] = world.tile_to_world_center(resolved_coord)
	return result


func _refund_inventory_item(agent_name: String, amount: int = 1) -> void:
	if agent_name == "":
		return
	var safe_amount = maxi(amount, 0)
	if safe_amount <= 0:
		return
	var ui_node = get_node_or_null("UI")
	if is_instance_valid(ui_node) and ui_node.has_method("refund_inventory_item"):
		ui_node.refund_inventory_item(agent_name, safe_amount)
		return
	Global.inventory[agent_name] = int(Global.inventory.get(agent_name, 0)) + safe_amount


func _connect_lifecycle_residue_signal(agent: Node) -> void:
	if not is_instance_valid(agent):
		return
	if not agent.has_signal("lifecycle_residue"):
		return
	var target = Callable(self, "_on_agent_lifecycle_residue")
	if agent.is_connected("lifecycle_residue", target):
		return
	agent.connect("lifecycle_residue", target)


func _count_living_myco(ignore_agent: Variant = null) -> int:
	var total := 0
	for agent in $Agents.get_children():
		if not is_instance_valid(agent):
			continue
		if is_instance_valid(ignore_agent) and agent == ignore_agent:
			continue
		if bool(agent.get("dead")):
			continue
		if str(agent.get("type")) != "myco":
			continue
		total += 1
	return total


func _find_healthy_myco_anchor_in_radius(world: Node, coord: Vector2i, max_radius_tiles: int, ignore_agent: Variant = null) -> Node:
	var safe_radius = maxi(max_radius_tiles, 0)
	var best_anchor: Node = null
	var best_dist := INF
	for agent in $Agents.get_children():
		if not is_instance_valid(agent):
			continue
		if is_instance_valid(ignore_agent) and agent == ignore_agent:
			continue
		if bool(agent.get("dead")):
			continue
		if str(agent.get("type")) != "myco":
			continue
		var myco_coord = Vector2i(world.world_to_tile(agent.global_position))
		if not world.in_bounds(myco_coord):
			continue
		var dist = maxi(abs(myco_coord.x - coord.x), abs(myco_coord.y - coord.y))
		if dist > safe_radius:
			continue
		var myco_tile = world.get_tile(myco_coord)
		if myco_tile.is_empty():
			continue
		if int(myco_tile.get("stage", 0)) < 3:
			continue
		if float(dist) < best_dist:
			best_dist = float(dist)
			best_anchor = agent
	return best_anchor


func _validate_myco_spawn(spawn_pos: Vector2, ignore_agent: Variant = null) -> Dictionary:
	var result := {
		"ok": false,
		"coord": Vector2i(-1, -1),
		"anchor": null
	}
	var world = _get_world_foundation()
	if not is_instance_valid(world):
		result["ok"] = true
		return result
	if not (world.has_method("world_to_tile") and world.has_method("tile_to_world_center") and world.has_method("in_bounds")):
		result["ok"] = true
		return result

	var coord = Vector2i(world.world_to_tile(spawn_pos))
	result["coord"] = coord
	if not world.in_bounds(coord):
		return result
	if LevelHelpersRef.is_tile_occupied(self, $Agents, coord, ignore_agent):
		return result
	if world.has_method("can_place_myco_on_tile"):
		if not bool(world.call("can_place_myco_on_tile", coord)):
			return result
	else:
		var tile = world.get_tile(coord)
		if tile.is_empty() or int(tile.get("stage", 0)) < 2:
			return result

	if _count_living_myco(ignore_agent) <= 0:
		result["ok"] = true
		return result

	var anchor = _find_healthy_myco_anchor_in_radius(world, coord, MYCO_HEALTHY_ANCHOR_RADIUS_TILES, ignore_agent)
	if not is_instance_valid(anchor):
		return result
	result["ok"] = true
	result["anchor"] = anchor
	return result


func _agent_key(agent: Variant) -> int:
	if not is_instance_valid(agent):
		return -1
	return int(agent.get_instance_id())


func request_agent_dirty(agent: Variant, buddies: bool = true, lines: bool = true, tile_hint: bool = false) -> void:
	var key = _agent_key(agent)
	if key < 0:
		return
	if buddies:
		_dirty_buddies_agents[key] = agent
	if lines and str(agent.get("type")) != "cloud":
		_dirty_lines_agents[key] = agent
	if tile_hint:
		_dirty_tile_hints_agents[key] = agent


func request_all_agents_dirty() -> void:
	for agent in $Agents.get_children():
		request_agent_dirty(agent, true, true, false)


func mark_agent_moved(agent: Variant, old_pos: Vector2, new_pos: Vector2) -> void:
	LevelHelpersRef.mark_agents_dirty_for_movement(self, $Agents, agent, old_pos, new_pos)
	LevelHelpersRef.sync_agent_occupancy(self, agent)


func _process_dirty_queues() -> void:
	if _dirty_buddies_agents.is_empty() and _dirty_lines_agents.is_empty() and _dirty_tile_hints_agents.is_empty():
		return
	for key in _dirty_buddies_agents.keys():
		var agent = _dirty_buddies_agents[key]
		if not is_instance_valid(agent):
			continue
		if bool(agent.get("dead")):
			continue
		if agent.has_method("generate_buddies"):
			agent.generate_buddies()
	for key in _dirty_tile_hints_agents.keys():
		var agent = _dirty_tile_hints_agents[key]
		if not is_instance_valid(agent):
			continue
		if bool(agent.get("dead")):
			continue
		if agent.has_method("_update_drag_tile_hint"):
			var pos = agent.get("position")
			if typeof(pos) == TYPE_VECTOR2:
				agent._update_drag_tile_hint(pos)

	if Global.draw_lines and not _dirty_lines_agents.is_empty():
		LevelHelpersRef.sync_myco_trade_lines($Lines, $Agents, false, _dirty_lines_agents.values())

	_dirty_buddies_agents.clear()
	_dirty_lines_agents.clear()
	_dirty_tile_hints_agents.clear()


func _setup_perf_monitor() -> void:
	if is_instance_valid(perf_monitor):
		return
	perf_monitor = PerfMonitorRef.new()
	perf_monitor.name = "PerfMonitor"
	perf_monitor.overlay_enabled = false
	perf_monitor.adaptive_quality_enabled = true
	perf_monitor.log_to_files = Global.perf_metrics_enabled
	add_child(perf_monitor)
	perf_monitor.configure(self, $Agents, $Trades, $Lines, _get_world_foundation())


func _recycle_trade(trade: Node) -> void:
	if not is_instance_valid(trade):
		return
	if trade.get_parent() != null:
		trade.get_parent().remove_child(trade)
	trade.visible = false
	trade.set_process(false)
	if trade.has_method("set_deferred"):
		trade.set_deferred("monitoring", false)
		trade.set_deferred("monitorable", false)
	var shape = trade.get_node_or_null("CollisionShape2D")
	if is_instance_valid(shape):
		shape.set_deferred("disabled", true)
	_trade_pool.append(trade)


func _ready():
	#get_tree().call_group('ui','set_health',health)
	#var num_maize = $Agents.get_children().size()
	#if num_maize <= 5:
	#var uix = ui_scene.instantiate()
	#uix.connect('new_agent',_on_new_agent)
	$UI.connect('new_agent',_on_new_agent)
	$UI.connect("inventory_drag_preview", _on_inventory_drag_preview)
	$UI.setup()
	_mute_runtime_audio_if_headless()
	_setup_perf_monitor()
	Global.prevent_auto_select = false
	DisplayServer.window_set_title("Plants Gardening")
	if not _is_headless_runtime():
		$BirdLong.play()
	var world = _get_world_foundation()
	if is_instance_valid(world) and world.has_method("set_context"):
		world.set_context(Global.mode, "plants")
	#$BirdLong.
		 
	$"UI/TutorialMarginContainer1".visible = false
	if(Global.mode == "tutorial"):
		$"UI/TutorialMarginContainer1".visible=true
		$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
		$"UI/TutorialMarginContainer1/ColorRect".color = Global.stage_colors[Global.stage]

	var world_center = _get_world_center()
	mid_width = int(world_center.x)
	mid_height = int(world_center.y)

	var myco = null
	var clustered_start = Global.mode == "tutorial" or Global.mode == "challenge"
	if clustered_start and _supports_world_tiles(world):
		var center_coord = _clamp_tile_coord(world, Vector2i(world.world_to_tile(world_center)))
		var myco_position = _tile_pos_from_center(world, center_coord, Vector2i(0, 0))
		var bean_position = _tile_pos_from_center(world, center_coord, Vector2i(-1, 0))
		var squash_position = _tile_pos_from_center(world, center_coord, Vector2i(0, -1))
		var maize_position = _tile_pos_from_center(world, center_coord, Vector2i(0, 1))
		var tree_position = _tile_pos_from_center(world, center_coord, Vector2i(1, 0))

		myco = make_myco(myco_position)
		make_bean(bean_position)
		make_squash(squash_position)
		make_maize(maize_position)
		make_tree(tree_position)
	else:
		var maize_center_offset_x = 75
		var maize_center_offset_y = 65
		var maize_position = Vector2(mid_width + maize_center_offset_x, mid_height + maize_center_offset_y)
		make_maize(maize_position)

		var bean_center_offset_x = -75
		var bean_center_offset_y = 0
		var bean_position = Vector2(mid_width + bean_center_offset_x, mid_height + bean_center_offset_y)
		make_bean(bean_position)

		var squash_center_offset_x = 0
		var squash_center_offset_y = -90
		var squash_position = Vector2(mid_width + squash_center_offset_x, mid_height + squash_center_offset_y)
		make_squash(squash_position)

		var tree_center_offset_x = 75
		var tree_center_offset_y = -50
		var tree_position = Vector2(mid_width + tree_center_offset_x, mid_height + tree_center_offset_y)
		make_tree(tree_position)

		var myco_width = mid_width + 40
		var myco_height = mid_height + 100
		var myco_position = Vector2(myco_width, myco_height)
		myco = make_myco(myco_position)

	Global.active_agent = myco
	LevelHelpersRef.refresh_agent_bar_visibility($Agents)
	
	if(Global.is_raining == true):
		var cloud_width = mid_width + 250
		var cloud_height = mid_height - 300
		var cloud_position = Vector2(cloud_width,cloud_height)

		make_cloud(cloud_position)

	LevelHelpersRef.rebuild_world_occupancy_cache(self, $Agents)
	request_all_agents_dirty()
	_process_dirty_queues()

	
	#var bird = bird_scene.instantiate()
	#bird.set_variables(cloud_dict)
	#$Animals.add_child(bird)
	#cloud.connect('trade', _on_agent_trade)


	#var cloud = cloud_scene.instantiate()
	#$Agents.add_child(cloud)
	#cloud.connect('trade', _on_agent_trade)
	
			
func _input(event):
	if LevelHelpersRef.handle_gameplay_hotkeys(event, self, $Agents, false):
		return


func _process(_delta: float) -> void:
	LevelHelpersRef.update_agent_hover_focus(self, $Agents)
	_dirty_refresh_accum += _delta
	if _dirty_refresh_accum >= Global.get_dirty_refresh_interval():
		_dirty_refresh_accum = 0.0
		_process_dirty_queues()
	_line_visual_refresh_accum += _delta
	if _line_visual_refresh_accum >= Global.get_line_visual_refresh_interval():
		_line_visual_refresh_accum = 0.0
		LevelHelpersRef.refresh_trade_line_visuals($Lines)


func _on_inventory_drag_preview(agent_name: String, world_pos: Vector2, active: bool) -> void:
	LevelHelpersRef.update_inventory_connection_preview(self, $Agents, $Lines, inventory_preview_lines, agent_name, world_pos, active)
				
				
				
				



func _on_player_laser(path_dict) -> void:
	pass
	#var trade = trade_scene.instantiate()
	#trade.set_variables(path_dict)
	#print(" trade created: ", path_dict["from_agent"], " ", path_dict)
	#$Trades.add_child(trade)
	
func _on_agent_trade(path_dict) -> void:
	call_deferred("_spawn_trade", path_dict)


func _spawn_trade(path_dict) -> void:
	var trade = null
	if not _trade_pool.is_empty():
		trade = _trade_pool.pop_back()
	else:
		trade = trade_scene.instantiate()
	if trade.has_method("set_pool_owner"):
		trade.set_pool_owner(self)
	if trade.has_method("activate_trade"):
		trade.activate_trade(path_dict)
	else:
		trade.set_variables(path_dict)
	$Trades.add_child(trade)
	
func update_bars(path_dict)  -> void:
	if is_instance_valid(Global.active_agent) and is_instance_valid(path_dict["from_agent"]) and is_instance_valid(path_dict["to_agent"]):  
		if Global.active_agent.name == path_dict["from_agent"].name or Global.active_agent.name == path_dict["to_agent"].name:
			for label in $UI.resContainer.get_children():
				#print("g. << inside asadas: ", label.name, " : ", label.text, path_dict["trade_asset"])
				if label.name == path_dict["trade_asset"]:
					#print("h. ><><< inside asadas, lable", label.name, " : ", label.text)
					label.text = str(path_dict["trade_asset"]) + str(" ") + str(Global.active_agent.assets[path_dict["trade_asset"]])


func _on_agent_lifecycle_residue(coord: Vector2i, biomass: float, source_type: String) -> void:
	var world = _get_world_foundation()
	if not is_instance_valid(world):
		return
	if world.has_method("register_residue"):
		world.register_residue(coord, biomass, 8, source_type)


func _play_predator_alert() -> void:
	if(Global.social_mode):
		$CarSound.play()
	else:
		$BirdSound.play()


func _spawn_predators(requested_count: int, play_alert: bool = false) -> void:
	var spawn_count = max(requested_count, 0)
	if Global.is_mobile_platform:
		spawn_count = min(spawn_count, Global.max_predators_per_wave_mobile)
	if spawn_count <= 0:
		return
	if play_alert:
		_play_predator_alert()
	for _i in range(spawn_count):
		make_bird()
					
func _on_update_score() -> void:
	var current_score_lvl := Global.get_rank_threshold(Global.score)
	if current_score_lvl > score_lvl:
		score_lvl = current_score_lvl
		#print("create birds: ", Global.birds[score_lvl])
		if(Global.is_birding == true):
			Global.rand_quarry.shuffle()
			var z_quarry = Global.rand_quarry[0]
			Global.quarry_type = z_quarry
			_spawn_predators(Global.get_predator_spawn_count(score_lvl), true)
	if(Global.mode == "challenge" and Global.ranks[current_score_lvl] == "Grassroots Economist"):
		get_tree().call_deferred("change_scene_to_file","res://scenes/game_over.tscn")
		

func _on_new_agent(agent_dict) -> void:
	#print("found signal: ", agent_dict)
	var new_agent = null
	var spawn_name = str(agent_dict["name"])
	var spawn_pos = agent_dict["pos"]
	var ignore_agent = agent_dict.get("ignore_agent", null)
	var require_exact_tile = bool(agent_dict.get("require_exact_tile", false))
	var allow_replace = bool(agent_dict.get("allow_replace", false))
	var from_inventory = bool(agent_dict.get("from_inventory", false))
	var myco_gate_result: Dictionary = {}
	var spawn_already_snapped := false

	var is_parent_bounded = _is_parent_bounded_spawn_type(spawn_name) and (from_inventory or agent_dict.has("parent_anchor") or agent_dict.has("max_parent_tiles"))
	var parent_anchor = agent_dict.get("parent_anchor", null)
	var max_parent_tiles = int(agent_dict.get("max_parent_tiles", DEFAULT_PARENT_BOUND_RADIUS_TILES))
	if is_parent_bounded:
		if max_parent_tiles <= 0:
			max_parent_tiles = DEFAULT_PARENT_BOUND_RADIUS_TILES
		if not _is_valid_parent_anchor(parent_anchor, ignore_agent):
			parent_anchor = _find_nearest_living_myco_anchor(spawn_pos, ignore_agent)
		if not _is_valid_parent_anchor(parent_anchor, ignore_agent):
			if from_inventory:
				_refund_inventory_item(spawn_name, 1)
			return
		agent_dict["parent_anchor"] = parent_anchor
		agent_dict["max_parent_tiles"] = max_parent_tiles
		if not agent_dict.has("spawn_anchor"):
			agent_dict["spawn_anchor"] = parent_anchor

	if allow_replace:
		var replace_pos = spawn_pos
		if is_parent_bounded:
			var world_for_replace = _get_world_foundation()
			if _supports_world_tiles(world_for_replace):
				var desired_coord = _clamp_tile_coord(world_for_replace, Vector2i(world_for_replace.world_to_tile(spawn_pos)))
				var parent_coord = _clamp_tile_coord(world_for_replace, Vector2i(world_for_replace.world_to_tile(parent_anchor.global_position)))
				if _tile_chebyshev_distance(desired_coord, parent_coord) <= max_parent_tiles:
					replace_pos = world_for_replace.tile_to_world_center(desired_coord)
				else:
					allow_replace = false
			else:
				allow_replace = false
		if allow_replace:
			var replace_target = _find_replaceable_agent_at_world_pos(replace_pos, ignore_agent)
			if is_instance_valid(replace_target):
				var replace_type = str(replace_target.get("type"))
				if replace_type == "tree" or replace_type == "myco":
					# Inventory drops should never destroy/replace existing trees or fungi.
					allow_replace = false
				else:
					ignore_agent = replace_target
					if replace_target.has_method("kill_it"):
						replace_target.kill_it()
					else:
						replace_target.call_deferred("queue_free")
					require_exact_tile = true
					spawn_pos = replace_pos

	if is_parent_bounded:
		var parent_spawn = _resolve_parent_bounded_spawn_pos(spawn_pos, parent_anchor, max_parent_tiles, ignore_agent, require_exact_tile)
		if not bool(parent_spawn["ok"]):
			if from_inventory:
				_refund_inventory_item(spawn_name, 1)
			return
		spawn_pos = parent_spawn["pos"]
		require_exact_tile = true
		spawn_already_snapped = true
	elif require_exact_tile:
		var exact_spawn = _resolve_exact_tile_spawn_pos(spawn_pos, ignore_agent)
		if not bool(exact_spawn["ok"]):
			if from_inventory:
				_refund_inventory_item(spawn_name, 1)
			return
		spawn_pos = exact_spawn["pos"]
		spawn_already_snapped = true

	if spawn_name == "myco" and not require_exact_tile:
		spawn_pos = _resolve_tile_spawn_pos(spawn_pos)
		spawn_already_snapped = true
		myco_gate_result = _validate_myco_spawn(spawn_pos, ignore_agent)
		if not bool(myco_gate_result["ok"]):
			if from_inventory:
				_refund_inventory_item("myco", 1)
			return
		if is_instance_valid(myco_gate_result["anchor"]):
			agent_dict["spawn_anchor"] = myco_gate_result["anchor"]
	if spawn_name == "squash":
		$TwinkleSound.play()
		new_agent = make_squash(spawn_pos, spawn_already_snapped)
	elif spawn_name == "bean":
		$TwinkleSound.play()
		new_agent = make_bean(spawn_pos, spawn_already_snapped)
	elif spawn_name == "maize":
		$TwinkleSound.play()
		new_agent = make_maize(spawn_pos, spawn_already_snapped)
	elif spawn_name == "myco":
		if myco_gate_result.is_empty():
			myco_gate_result = _validate_myco_spawn(spawn_pos, ignore_agent)
		if not bool(myco_gate_result["ok"]):
			if from_inventory:
				_refund_inventory_item("myco", 1)
			return
		if is_instance_valid(myco_gate_result["anchor"]):
			agent_dict["spawn_anchor"] = myco_gate_result["anchor"]
		$SquelchSound.play()
		new_agent = make_myco(spawn_pos, spawn_already_snapped)
	elif spawn_name == "tree":
		$BushSound.play()
		new_agent = make_tree(spawn_pos, spawn_already_snapped)
	
	if is_instance_valid(new_agent):
		if agent_dict.has("spawn_anchor"):
			LevelHelpersRef.ensure_spawn_buddy_link(new_agent, agent_dict["spawn_anchor"])
		LevelHelpersRef.sync_agent_occupancy(self, new_agent)
		request_all_agents_dirty()
	if(Global.active_agent == null and not Global.prevent_auto_select):
		Global.active_agent = new_agent
		LevelHelpersRef.refresh_agent_bar_visibility($Agents)
			
func make_squash(pos, already_snapped: bool = false):
	#print("Clicked On Squash. making")
	
	var squash_position = pos
	if not already_snapped:
		squash_position = _resolve_tile_spawn_pos(pos)
	
	var named = "Squash_" + str($Agents.get_child_count()+1)
	
	var squash_dict = {
		"name": named,
		"type": "squash",
		"position": squash_position,
		"prod_res": ["P"],
		"start_res": null,
		"texture": TEX_SQUASH
	}
	
	var squash = plant_scene.instantiate()
	squash.set_variables(squash_dict)
	$Agents.add_child(squash)
	LevelHelpersRef.connect_core_agent_signals(squash, _on_agent_trade, _on_new_agent, _on_update_score)
	_connect_lifecycle_residue_signal(squash)
	LevelHelpersRef.sync_agent_occupancy(self, squash)
	request_all_agents_dirty()
	
	return squash

func make_tree(pos, already_snapped: bool = false):
	#print("Clicked On Squash. making")
	
	var tree_position = pos
	if not already_snapped:
		tree_position = _resolve_tile_spawn_pos(pos)
	
	var named = "Tree_" + str($Agents.get_child_count()+1)
	
	var tree_dict = {
		"name": named,
		"type": "tree",
		"position": tree_position,
		"prod_res": ["R"],
		"start_res": null,
		"texture": TEX_TREE
	}
	var tree = plant_scene.instantiate()
	tree.set_variables(tree_dict)
	$Agents.add_child(tree)
	tree.position = LevelHelpersRef.resolve_snapped_position_for_agent(self, $Agents, tree, tree_position)
	LevelHelpersRef.connect_core_agent_signals(tree, _on_agent_trade, _on_new_agent, _on_update_score)
	_connect_lifecycle_residue_signal(tree)
	LevelHelpersRef.sync_agent_occupancy(self, tree)
	request_all_agents_dirty()
	return tree
	
	
func make_bird():
	call_deferred("_spawn_bird")


func _spawn_bird():
	var bird = null
	if(Global.social_mode):
		bird = tuktuk_scene.instantiate()
	else:
		bird = bird_scene.instantiate()
	$Animals.add_child(bird)

	
func make_maize(pos, already_snapped: bool = false):
	var maize_position = pos
	if not already_snapped:
		maize_position = _resolve_tile_spawn_pos(pos)
	
	var named = "Maize_" + str($Agents.get_child_count()+1)
	
	var maize_dict = {
		"name": named,
		"type": "maize",
		"position": maize_position,
		"prod_res": ["K"],
		"start_res": null,
		"texture": TEX_MAIZE
	}
	var maize = plant_scene.instantiate()
	maize.set_variables(maize_dict)
	$Agents.add_child(maize)
	LevelHelpersRef.connect_core_agent_signals(maize, _on_agent_trade, _on_new_agent, _on_update_score)
	_connect_lifecycle_residue_signal(maize)
	LevelHelpersRef.sync_agent_occupancy(self, maize)
	request_all_agents_dirty()
	
	return maize
		
func make_bean(pos, already_snapped: bool = false):
	
	var bean_position = pos
	if not already_snapped:
		bean_position = _resolve_tile_spawn_pos(pos)
	
	var named = "Bean_" + str($Agents.get_child_count()+1)
	
	var bean_dict = {
		"name": named,
		"type": "bean",
		"position": bean_position,
		"prod_res": ["N"],
		"start_res": null,
		"texture": TEX_BEAN
	}
	var bean = plant_scene.instantiate()
	bean.set_variables(bean_dict)
	$Agents.add_child(bean)
	LevelHelpersRef.connect_core_agent_signals(bean, _on_agent_trade, _on_new_agent, _on_update_score)
	_connect_lifecycle_residue_signal(bean)
	LevelHelpersRef.sync_agent_occupancy(self, bean)
	request_all_agents_dirty()
	
	return bean


func make_cloud(pos):
	
	var named = "Cloud_" + str($Agents.get_child_count()+1)
	
	var cloud_dict = {
		"name": named,
		"type": "cloud",
		"position": pos,
		"prod_res": ["R"],
		"start_res": 20,
		"texture": TEX_CLOUD
	}
	var cloud = cloud_scene.instantiate()
	cloud.set_variables(cloud_dict)
	$Agents.add_child(cloud)
	if cloud.has_signal("trade"):
		cloud.connect("trade", _on_agent_trade)
	
	return cloud


func make_myco(pos, already_snapped: bool = false):
	var myco_position = pos
	if not already_snapped:
		myco_position = _resolve_tile_spawn_pos(pos)
	
	var named = "Mycorrhizal_" + str($Agents.get_child_count()+1)
		
	
	var myco_dict = {
		"name": named,
		"type": "myco",
		"position": myco_position,
		"prod_res": [null],
		"start_res": null,
		"texture": TEX_MYCO
	}
	
	var myco = myco_scene.instantiate()
	myco.set_variables(myco_dict)
	myco.sprite_texture = TEX_MYCO
	$Agents.add_child(myco)
	
	if myco.has_signal("trade"):
		myco.connect("trade", _on_agent_trade)
	if myco.has_signal("new_agent"):
		myco.connect("new_agent", _on_new_agent)
	_connect_lifecycle_residue_signal(myco)
	LevelHelpersRef.sync_agent_occupancy(self, myco)
	request_all_agents_dirty()
	
	return myco
	
	


func _on_tutorial_timer_timeout() -> void:
	if(Global.mode == "tutorial"):
		#print("mode: ", Global.mode, "stage: ", Global.stage)
		if( Global.stage == 1):
			
			var c_buds = 0
			for child in $Agents.get_children():
				if(child.type!="myco"):
					c_buds += len(child.trade_buddies)
				#print(" child bud: ", child.name, " ", child.trade_buddies)
			#print("len buds: ", c_buds)
			if(c_buds >=4):
				Global.stage += 1
				$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
				$"UI/TutorialMarginContainer1/ColorRect".color = Global.stage_colors[Global.stage]
				
		elif(Global.stage == 2):
			
			var c_buds = 0
			var num_myco = 0
			for child in $Agents.get_children():
				if(child.type=="myco"):
					num_myco += 1
			if(num_myco >=2):
				Global.stage += 1
				$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
				$"UI/TutorialMarginContainer1/ColorRect".color = Global.stage_colors[Global.stage]
		elif(Global.stage == 3):
			
			var c_buds = 0
			var num_myco = 0
			for child in $Agents.get_children():
				if(child.type=="myco"):
					num_myco += 1
					c_buds += len(child.trade_buddies)
					#print(" child bud: ", child.name, " ", child.trade_buddies)
			if(num_myco >= 3 and c_buds >=2):
				Global.stage += 1
				$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
				$"UI/TutorialMarginContainer1/ColorRect".color = Global.stage_colors[Global.stage]
		elif(Global.stage == 4):
			
			var c_maize = 0
			for child in $Agents.get_children():
				if(child.type=="maize" and child.dead==false):
					c_maize += 1
			
			_spawn_predators(c_maize * 3, true)
				
			Global.stage = 4.1
			
		elif(Global.stage == 4.1):
			var c_maize = 0
			for child in $Agents.get_children():
				if(child.type=="maize" and child.dead==false):
					c_maize += 1
			
			if(c_maize >=3):
				Global.stage = 5
				$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
				$"UI/TutorialMarginContainer1/ColorRect".color = Global.stage_colors[Global.stage]
		
		elif(Global.stage == 5):
			
			var c_maize = 0
			for child in $Agents.get_children():
				if(child.type=="maize" and child.dead==false):
					c_maize += 1
			
			_spawn_predators(c_maize - 1, true)
				
			Global.stage = 5.1
			
		elif(Global.stage == 5.1):
			var c_maize = 0
			for child in $Agents.get_children():
				if(child.type=="maize" and child.dead==false):
					c_maize += 1
			
			
			
			if(c_maize >=2 and Global.values['K']>1):
				Global.stage = 6
				$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
				$"UI/TutorialMarginContainer1/ColorRect".color = Global.stage_colors[Global.stage]
				
		elif(Global.stage == 6):
			
			
			var c_maize = 0
			for child in $Agents.get_children():
				if(child.type=="maize" and child.dead==false):
					c_maize += 1
			
			_spawn_predators(c_maize - 1)
			Global.stage_inc+=1
			if(Global.stage_inc>=Global.max_stage_inc):
				Global.stage = 6.1
				Global.stage_inc = 0
			
		elif(Global.stage == 6.1):
			var c_maize = 0
			for child in $Agents.get_children():
				if(child.type=="maize" and child.dead==false):
					c_maize += 1
			
			
			
			if(c_maize >=2 and Global.values['K']>1):
				Global.stage = 7
				$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
				$"UI/TutorialMarginContainer1/ColorRect".color = Global.stage_colors[Global.stage]
		
		elif(Global.stage == 7):
			
			var c_maize = 0
			for child in $Agents.get_children():
				if(child.type=="maize" and child.dead==false):
					c_maize += 1
					
			if(c_maize >=2 and Global.values['K']<=1.1):
				Global.stage = 8
				$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
				$"UI/TutorialMarginContainer1/ColorRect".color = Global.stage_colors[Global.stage]
				$"UI/RestartContainer".visible=true


func _exit_tree() -> void:
	_release_audio()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_release_audio()


func _release_audio() -> void:
	if _shutdown_cleanup_done:
		return
	_shutdown_cleanup_done = true
	LevelHelpersRef.clear_trade_line_cache($Lines, true)
	LevelHelpersRef.clear_inventory_connection_preview_lines(inventory_preview_lines, true)
	LevelHelpersRef.stop_audio_players([
		$BirdSound,
		$BirdLong,
		$CarSound,
		$SquelchSound,
		$TwinkleSound,
		$BushSound
	], true)
	for active_trade in $Trades.get_children():
		if is_instance_valid(active_trade):
			if active_trade.get_parent() != null:
				active_trade.get_parent().remove_child(active_trade)
			active_trade.free()
	for pooled_trade in _trade_pool:
		if is_instance_valid(pooled_trade):
			if pooled_trade.get_parent() != null:
				pooled_trade.get_parent().remove_child(pooled_trade)
			pooled_trade.free()
	_trade_pool.clear()
		
						
			
		
