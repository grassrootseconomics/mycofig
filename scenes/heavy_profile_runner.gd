extends Node

const LEVEL_SCENE = preload("res://scenes/level.tscn")
const LevelHelpersRef = preload("res://scenes/level_helpers.gd")

var duration_seconds := 30.0
var seed_value := 4242
var myco_count := 100
var plant_count := 232
var people_count := 50
var basket_count := 10
var bank_count := 0
var cloud_count := 0
var runtime_mode := "profile"
var challenge_dual_enabled := false
var columns := 48
var rows := 27
var trace_prefix := "/tmp/mycofig_heavy_mixed"
var draw_lines := true
var bars_on := false
var disable_trades := false
var settle_initial_dirty := false
var timed_planting_enabled := false
var planting_interval_seconds := 1.0
var planting_batch_size := 1
var wall_timeout_seconds := 0.0

var _level: Node = null
var _elapsed := 0.0
var _wall_start_msec := 0
var _finishing := false
var _spawn_report := {}
var _used_tiles: Dictionary = {}
var _pending_plantings: Array = []
var _planting_elapsed := 0.0
var _timed_spawn_counts := {}


func _ready() -> void:
	_parse_args()
	_wall_start_msec = Time.get_ticks_msec()
	seed(seed_value)
	Global.mode = runtime_mode
	Global.challenge_dual_village_enabled = challenge_dual_enabled
	Global.social_mode = false
	Global.baby_mode = false
	Global.is_birding = false
	Global.is_killing = false
	Global.is_raining = true
	Global.draw_lines = draw_lines
	Global.bars_on = bars_on
	Global.perf_metrics_enabled = true
	Global.perf_quality_override = -1
	Global.perf_adaptive_enabled = true
	Global.trade_dispatch_limit_enabled = not disable_trades
	Global.set_perf_tier(0)
	Global.perf_set_run_metadata({
		"scenario_id": "heavy_mixed",
		"profile": "myco_plants_people_baskets",
		"mode": runtime_mode,
		"seed": seed_value,
		"target": myco_count + plant_count + people_count + basket_count + bank_count + cloud_count,
		"duration_s": duration_seconds
	})

	_level = LEVEL_SCENE.instantiate()
	add_child(_level)
	await get_tree().process_frame
	_reset_level()
	if timed_planting_enabled:
		_setup_timed_gameplay_mix()
	else:
		_spawn_heavy_mix()
	_configure_trace_paths()
	print(str("[heavy] seed=", seed_value, " duration=", duration_seconds, "s mode=", runtime_mode, " challenge_dual=", challenge_dual_enabled, " timed=", timed_planting_enabled, " grid=", columns, "x", rows, " lines=", draw_lines, " bars=", bars_on, " trades=", not disable_trades, " banks=", bank_count, " clouds=", cloud_count))
	print(str("[heavy] spawned=", JSON.stringify(_spawn_report)))


func _process(delta: float) -> void:
	_elapsed += delta
	if timed_planting_enabled:
		_process_timed_planting(delta)
	if wall_timeout_seconds > 0.0:
		var wall_elapsed = float(Time.get_ticks_msec() - _wall_start_msec) / 1000.0
		if wall_elapsed >= wall_timeout_seconds:
			_finish("wall_timeout")
			return
	if _elapsed >= duration_seconds:
		_finish("complete")


func _reset_level() -> void:
	var agents = _level.get_node_or_null("Agents")
	var trades = _level.get_node_or_null("Trades")
	var lines = _level.get_node_or_null("Lines")
	var animals = _level.get_node_or_null("Animals")
	var sparkles = _level.get_node_or_null("Sparkles")
	if is_instance_valid(lines):
		LevelHelpers.clear_trade_line_cache(lines, true)
	for root_node in [agents, trades, animals, sparkles]:
		if not is_instance_valid(root_node):
			continue
		for child in root_node.get_children():
			child.free()
	var world = _level.get_node_or_null("WorldFoundation")
	if is_instance_valid(world) and world.has_method("configure_dimensions"):
		world.configure_dimensions(columns, rows)
	if is_instance_valid(world) and world.has_method("set_context"):
		world.set_context("profile", "heavy_mixed")
	LevelHelpers.rebuild_world_occupancy_cache(_level, agents)
	if _level.has_method("request_all_agents_dirty"):
		_level.request_all_agents_dirty()


func _spawn_heavy_mix() -> void:
	var world = _level.get_node_or_null("WorldFoundation")
	var agents = _level.get_node_or_null("Agents")
	if not is_instance_valid(world) or not is_instance_valid(agents):
		return
	var spawn_start_us = Time.get_ticks_usec()
	var used := {}
	var spawned_myco := 0
	var spawned_plants := 0
	var spawned_people := 0
	var spawned_baskets := 0
	var spawned_banks := 0
	var spawned_clouds := 0

	var myco_tiles: Array[Vector2i] = []
	var center = Vector2i(columns / 2, rows / 2)
	var cluster_radius = maxi(int(ceil(sqrt(float(myco_count + plant_count + people_count + basket_count)))) + 8, 18)

	for tile in _cluster_tiles(center, cluster_radius):
		if spawned_myco >= myco_count:
			break
		if _claim(used, tile):
			var node = _level.make_myco(world.tile_to_world_center(tile), true)
			if is_instance_valid(node):
				_prepare_agent(node)
				myco_tiles.append(tile)
				spawned_myco += 1

	var plant_types = ["bean", "squash", "maize", "tree"]
	var plant_index := 0
	for radius in range(1, 13):
		for anchor in myco_tiles:
			if spawned_plants >= plant_count:
				break
			for tile in _exact_ring_tiles(anchor, radius):
				if spawned_plants >= plant_count:
					break
				if not _claim(used, tile):
					continue
				var plant_type = plant_types[plant_index % plant_types.size()]
				var node = _make_plant(plant_type, world.tile_to_world_center(tile))
				if is_instance_valid(node):
					_prepare_agent(node)
					spawned_plants += 1
					plant_index += 1
		if spawned_plants >= plant_count:
			break

	for tile in _cluster_tiles(center + Vector2i(cluster_radius + 4, 0), cluster_radius):
		if spawned_people >= people_count:
			break
		if not _claim(used, tile):
			continue
		var role = ["farmer", "vendor", "cook"][spawned_people % 3]
		var node = _make_person(role, world.tile_to_world_center(tile))
		if is_instance_valid(node):
			_prepare_agent(node)
			spawned_people += 1

	for tile in _cluster_tiles(center + Vector2i(cluster_radius + 2, -4), cluster_radius):
		if spawned_banks >= bank_count:
			break
		if not _claim(used, tile):
			continue
		var node = _level.make_story_bank(world.tile_to_world_center(tile))
		if is_instance_valid(node):
			_prepare_agent(node)
			spawned_banks += 1

	for tile in _cluster_tiles(center + Vector2i(0, -(cluster_radius + 4)), cluster_radius):
		if spawned_clouds >= cloud_count:
			break
		if not _claim(used, tile):
			continue
		var node = _level.make_cloud(world.tile_to_world_center(tile))
		if is_instance_valid(node):
			_prepare_agent(node)
			spawned_clouds += 1

	var basket_search_center = center + Vector2i(-(cluster_radius + 4), 0)
	if runtime_mode == "challenge" and challenge_dual_enabled and _level.has_method("_get_runtime_village_cobble_rect"):
		var cobble_rect: Rect2i = _level.call("_get_runtime_village_cobble_rect", world)
		basket_search_center = Vector2i(
			cobble_rect.position.x + int(cobble_rect.size.x / 2),
			cobble_rect.position.y + int(cobble_rect.size.y / 2)
		)
	for tile in _cluster_tiles(basket_search_center, cluster_radius):
		if spawned_baskets >= basket_count:
			break
		if not _claim(used, tile):
			continue
		var node = _level.make_story_basket(world.tile_to_world_center(tile))
		if is_instance_valid(node):
			_prepare_agent(node)
			spawned_baskets += 1

	LevelHelpers.rebuild_world_occupancy_cache(_level, agents)
	if _level.has_method("request_all_agents_dirty"):
		_level.request_all_agents_dirty()
	if settle_initial_dirty and _level.has_method("_process_dirty_queues"):
		_level._process_dirty_queues(true)
	_spawn_report = {
		"myco": spawned_myco,
		"plants": spawned_plants,
		"people": spawned_people,
		"baskets": spawned_baskets,
		"banks": spawned_banks,
		"clouds": spawned_clouds,
		"agents": agents.get_child_count(),
		"spawn_ms": float(Time.get_ticks_usec() - spawn_start_us) / 1000.0
	}
	Global.apply_perf_density_gate(int(_spawn_report["agents"]))


func _setup_timed_gameplay_mix() -> void:
	var world = _level.get_node_or_null("WorldFoundation")
	var agents = _level.get_node_or_null("Agents")
	if not is_instance_valid(world) or not is_instance_valid(agents):
		return
	var spawn_start_us = Time.get_ticks_usec()
	_used_tiles.clear()
	_pending_plantings.clear()
	_timed_spawn_counts = {
		"myco": 0,
		"plants": 0,
		"people": 0,
		"baskets": 0,
		"banks": 0,
		"clouds": 0
	}
	var center = Vector2i(columns / 2, rows / 2)
	var garden_center = center
	if runtime_mode == "challenge" and challenge_dual_enabled and _level.has_method("_get_runtime_start_tile"):
		garden_center = _level.call("_get_runtime_start_tile", world)
	var village_center = _get_timed_village_center(world, center)
	_spawn_timed_village_actors(world, village_center)
	_queue_dense_garden_plantings(world, garden_center)
	LevelHelpers.rebuild_world_occupancy_cache(_level, agents)
	if _level.has_method("request_all_agents_dirty"):
		_level.request_all_agents_dirty()
	_spawn_report = {
		"myco": 0,
		"plants": 0,
		"people": int(_timed_spawn_counts.get("people", 0)),
		"baskets": 0,
		"banks": int(_timed_spawn_counts.get("banks", 0)),
		"clouds": int(_timed_spawn_counts.get("clouds", 0)),
		"pending_plantings": _pending_plantings.size(),
		"agents": agents.get_child_count(),
		"spawn_ms": float(Time.get_ticks_usec() - spawn_start_us) / 1000.0
	}
	Global.apply_perf_density_gate(agents.get_child_count())


func _spawn_timed_village_actors(world: Node, center: Vector2i) -> void:
	var cluster_radius = maxi(int(ceil(sqrt(float(myco_count + plant_count + people_count + basket_count + bank_count + cloud_count)))) + 8, 18)
	var people_center = center + Vector2i(cluster_radius + 4, 0)
	var bank_center = center + Vector2i(cluster_radius + 2, -4)
	var cloud_center = center + Vector2i(0, -(cluster_radius + 4))
	if runtime_mode == "challenge" and challenge_dual_enabled:
		people_center = center
		bank_center = center + Vector2i(0, -3)
		cloud_center = center + Vector2i(-4, -5)
	var spawned_people := 0
	for tile in _cluster_tiles(people_center, cluster_radius):
		if spawned_people >= people_count:
			break
		if not _claim(_used_tiles, tile):
			continue
		var role = ["farmer", "vendor", "cook"][spawned_people % 3]
		var node = _make_person(role, world.tile_to_world_center(tile))
		if is_instance_valid(node):
			_prepare_agent(node)
			_after_timed_spawn(node)
			spawned_people += 1
	_timed_spawn_counts["people"] = spawned_people

	var spawned_banks := 0
	for tile in _cluster_tiles(bank_center, cluster_radius):
		if spawned_banks >= bank_count:
			break
		if not _claim(_used_tiles, tile):
			continue
		var node = _level.make_story_bank(world.tile_to_world_center(tile))
		if is_instance_valid(node):
			_prepare_agent(node)
			_after_timed_spawn(node)
			spawned_banks += 1
	_timed_spawn_counts["banks"] = spawned_banks

	var spawned_clouds := 0
	for tile in _cluster_tiles(cloud_center, cluster_radius):
		if spawned_clouds >= cloud_count:
			break
		if not _claim(_used_tiles, tile):
			continue
		var node = _level.make_cloud(world.tile_to_world_center(tile))
		if is_instance_valid(node):
			_prepare_agent(node)
			_after_timed_spawn(node)
			spawned_clouds += 1
		_timed_spawn_counts["clouds"] = spawned_clouds


func _get_timed_village_center(world: Node, fallback_center: Vector2i) -> Vector2i:
	if runtime_mode == "challenge" and challenge_dual_enabled and _level.has_method("_get_runtime_village_rect"):
		var village_rect: Rect2i = _level.call("_get_runtime_village_rect", world)
		return Vector2i(
			village_rect.position.x + int(village_rect.size.x / 2),
			village_rect.position.y + int(village_rect.size.y / 2)
		)
	return fallback_center


func _queue_dense_garden_plantings(world: Node, center: Vector2i) -> void:
	var myco_tiles: Array[Vector2i] = []
	for tile in _cluster_tiles(center, 4):
		if myco_tiles.size() >= myco_count:
			break
		if _claim(_used_tiles, tile):
			myco_tiles.append(tile)
	var plant_tiles_by_myco: Array = []
	for myco_tile in myco_tiles:
		var local_tiles: Array[Vector2i] = []
		for radius in range(1, 6):
			for tile in _exact_ring_tiles(myco_tile, radius):
				if _claim(_used_tiles, tile):
					local_tiles.append(tile)
		plant_tiles_by_myco.append(local_tiles)
	var plant_types = ["bean", "squash", "maize", "tree"]
	var queued_plants := 0
	for myco_index in range(myco_tiles.size()):
		_pending_plantings.append({"kind": "myco", "tile": myco_tiles[myco_index]})
		var local_tiles: Array = plant_tiles_by_myco[myco_index]
		var local_count := 0
		while queued_plants < plant_count and not local_tiles.is_empty() and local_count < 8:
			_pending_plantings.append({
				"kind": plant_types[queued_plants % plant_types.size()],
				"tile": local_tiles.pop_front()
			})
			queued_plants += 1
			local_count += 1
	while queued_plants < plant_count:
		var made_progress := false
		for local_tiles_variant in plant_tiles_by_myco:
			if queued_plants >= plant_count:
				break
			var local_tiles: Array = local_tiles_variant
			if local_tiles.is_empty():
				continue
			var tile = local_tiles.pop_front()
			_pending_plantings.append({
				"kind": plant_types[queued_plants % plant_types.size()],
				"tile": tile
			})
			queued_plants += 1
			made_progress = true
		if not made_progress:
			break
	var basket_tiles = _get_timed_basket_tiles(world, center)
	for tile in basket_tiles:
		if _pending_count_for_kind("basket") >= basket_count:
			break
		_pending_plantings.append({"kind": "basket", "tile": tile})


func _get_timed_basket_tiles(world: Node, fallback_center: Vector2i) -> Array[Vector2i]:
	var search_center = fallback_center
	if runtime_mode == "challenge" and challenge_dual_enabled and _level.has_method("_get_runtime_village_cobble_rect"):
		var cobble_rect: Rect2i = _level.call("_get_runtime_village_cobble_rect", world)
		search_center = Vector2i(
			cobble_rect.position.x + int(cobble_rect.size.x / 2),
			cobble_rect.position.y + int(cobble_rect.size.y / 2)
		)
	var tiles: Array[Vector2i] = []
	for tile in _cluster_tiles(search_center, 6):
		if tiles.size() >= basket_count:
			break
		if _claim(_used_tiles, tile):
			tiles.append(tile)
	return tiles


func _pending_count_for_kind(kind: String) -> int:
	var count := 0
	for planting in _pending_plantings:
		if typeof(planting) == TYPE_DICTIONARY and str(planting.get("kind", "")) == kind:
			count += 1
	return count


func _process_timed_planting(delta: float) -> void:
	if _pending_plantings.is_empty():
		return
	_planting_elapsed += maxf(delta, 0.0)
	if _planting_elapsed < maxf(planting_interval_seconds, 0.01):
		return
	_planting_elapsed = 0.0
	for _i in range(maxi(planting_batch_size, 1)):
		if _pending_plantings.is_empty():
			break
		_spawn_queued_planting(_pending_plantings.pop_front())


func _spawn_queued_planting(planting: Dictionary) -> void:
	var world = _level.get_node_or_null("WorldFoundation")
	if not is_instance_valid(world):
		return
	var kind = str(planting.get("kind", ""))
	var tile = Vector2i(planting.get("tile", Vector2i.ZERO))
	var pos = world.tile_to_world_center(tile)
	var node: Node = null
	if kind == "myco":
		node = _level.make_myco(pos, true)
	elif kind == "basket":
		node = _level.make_story_basket(pos)
	else:
		node = _make_plant(kind, pos)
	if not is_instance_valid(node):
		return
	_prepare_agent(node)
	_after_timed_spawn(node)
	if kind == "myco":
		_timed_spawn_counts["myco"] = int(_timed_spawn_counts.get("myco", 0)) + 1
	elif kind == "basket":
		_timed_spawn_counts["baskets"] = int(_timed_spawn_counts.get("baskets", 0)) + 1
	else:
		_timed_spawn_counts["plants"] = int(_timed_spawn_counts.get("plants", 0)) + 1
	_update_timed_spawn_report()


func _after_timed_spawn(agent: Node) -> void:
	if not is_instance_valid(agent):
		return
	if _level.has_method("request_spawn_neighborhood_dirty"):
		_level.call("request_spawn_neighborhood_dirty", agent)
	elif _level.has_method("request_all_agents_dirty"):
		_level.call("request_all_agents_dirty")
	var agents = _level.get_node_or_null("Agents")
	if is_instance_valid(agents):
		Global.apply_perf_density_gate(agents.get_child_count())


func _update_timed_spawn_report() -> void:
	var agents = _level.get_node_or_null("Agents")
	_spawn_report["myco"] = int(_timed_spawn_counts.get("myco", 0))
	_spawn_report["plants"] = int(_timed_spawn_counts.get("plants", 0))
	_spawn_report["baskets"] = int(_timed_spawn_counts.get("baskets", 0))
	_spawn_report["pending_plantings"] = _pending_plantings.size()
	if is_instance_valid(agents):
		_spawn_report["agents"] = agents.get_child_count()


func _prepare_agent(agent: Node) -> void:
	agent.set("logistics_ready", not disable_trades)
	agent.set("new_buddies", true)
	agent.set("draw_lines", true)
	if disable_trades:
		var action_timer = agent.get_node_or_null("ActionTimer")
		if is_instance_valid(action_timer):
			action_timer.stop()
	if agent.get("num_babies") != null:
		agent.set("num_babies", 0)
	if agent.get("peak_maturity") != null:
		agent.set("peak_maturity", 999999)


func _make_plant(kind: String, pos: Vector2) -> Node:
	match kind:
		"bean":
			return _level.make_bean(pos, true)
		"squash":
			return _level.make_squash(pos, true)
		"maize":
			return _level.make_maize(pos, true)
		"tree":
			return _level.make_tree(pos, true)
	return null


func _make_person(role: String, pos: Vector2) -> Node:
	match role:
		"farmer":
			return _level.make_farmer(pos, false)
		"vendor":
			return _level.make_vendor(pos, false)
		"cook":
			return _level.make_cook(pos, false)
	return null


func _cluster_tiles(center: Vector2i, radius: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for r in range(radius + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(abs(dx), abs(dy)) != r:
					continue
				var tile = center + Vector2i(dx, dy)
				if tile.x >= 0 and tile.y >= 0 and tile.x < columns and tile.y < rows:
					tiles.append(tile)
	return tiles


func _ring_tiles(center: Vector2i, radius: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for r in range(1, radius + 1):
		tiles.append_array(_exact_ring_tiles(center, r))
	return tiles


func _exact_ring_tiles(center: Vector2i, radius: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if maxi(abs(dx), abs(dy)) != radius:
				continue
			var tile = center + Vector2i(dx, dy)
			if tile.x >= 0 and tile.y >= 0 and tile.x < columns and tile.y < rows:
				tiles.append(tile)
	return tiles


func _claim(used: Dictionary, tile: Vector2i) -> bool:
	if tile.x < 0 or tile.y < 0 or tile.x >= columns or tile.y >= rows:
		return false
	if used.has(tile):
		return false
	used[tile] = true
	return true


func _configure_trace_paths() -> void:
	var perf_monitor = _level.get_node_or_null("PerfMonitor")
	if not is_instance_valid(perf_monitor):
		return
	var run_id = str("seed", seed_value, "_m", myco_count, "_p", plant_count, "_people", people_count, "_b", basket_count, "_banks", bank_count, "_clouds", cloud_count, "_timed", int(timed_planting_enabled), "_lines", int(draw_lines), "_bars", int(bars_on), "_trades", int(not disable_trades))
	perf_monitor.log_to_files = true
	perf_monitor.log_json_path = str(trace_prefix, "_", run_id, ".json")
	perf_monitor.log_csv_path = str(trace_prefix, "_", run_id, ".csv")
	print(str("[heavy] traces json=", perf_monitor.log_json_path, " csv=", perf_monitor.log_csv_path))


func _flush_perf_logs() -> void:
	if not is_instance_valid(_level):
		return
	var perf_monitor = _level.get_node_or_null("PerfMonitor")
	if is_instance_valid(perf_monitor) and perf_monitor.has_method("flush_logs"):
		perf_monitor.call("flush_logs", true)


func _finish(reason: String = "complete") -> void:
	if _finishing:
		return
	_finishing = true
	var agents = _level.get_node_or_null("Agents")
	var trades = _level.get_node_or_null("Trades")
	var lines = _level.get_node_or_null("Lines")
	_flush_perf_logs()
	print(str("[heavy] done reason=", reason, " elapsed=", _elapsed, " wall=", float(Time.get_ticks_msec() - _wall_start_msec) / 1000.0, " agents=", agents.get_child_count() if is_instance_valid(agents) else 0, " trades=", trades.get_child_count() if is_instance_valid(trades) else 0, " lines=", lines.get_child_count() if is_instance_valid(lines) else 0, " spawned=", JSON.stringify(_spawn_report)))
	print(str("[heavy] last_sample=", JSON.stringify(Global.perf_last_sample)))
	remove_child(_level)
	_level.free()
	get_tree().quit()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--duration="):
			duration_seconds = maxf(float(arg.trim_prefix("--duration=")), 1.0)
		elif arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--myco="):
			myco_count = maxi(int(arg.trim_prefix("--myco=")), 0)
		elif arg.begins_with("--plants="):
			plant_count = maxi(int(arg.trim_prefix("--plants=")), 0)
		elif arg.begins_with("--people="):
			people_count = maxi(int(arg.trim_prefix("--people=")), 0)
		elif arg.begins_with("--baskets="):
			basket_count = maxi(int(arg.trim_prefix("--baskets=")), 0)
		elif arg.begins_with("--banks="):
			bank_count = maxi(int(arg.trim_prefix("--banks=")), 0)
		elif arg.begins_with("--clouds="):
			cloud_count = maxi(int(arg.trim_prefix("--clouds=")), 0)
		elif arg.begins_with("--mode="):
			runtime_mode = arg.trim_prefix("--mode=").strip_edges()
		elif arg == "--challenge-dual":
			challenge_dual_enabled = true
		elif arg.begins_with("--columns="):
			columns = maxi(int(arg.trim_prefix("--columns=")), 1)
		elif arg.begins_with("--rows="):
			rows = maxi(int(arg.trim_prefix("--rows=")), 1)
		elif arg.begins_with("--trace-prefix="):
			trace_prefix = arg.trim_prefix("--trace-prefix=")
		elif arg == "--no-lines":
			draw_lines = false
		elif arg == "--lines":
			draw_lines = true
		elif arg == "--bars":
			bars_on = true
		elif arg == "--no-bars":
			bars_on = false
		elif arg == "--no-trades":
			disable_trades = true
		elif arg == "--settle-initial-dirty":
			settle_initial_dirty = true
		elif arg == "--timed-planting":
			timed_planting_enabled = true
		elif arg.begins_with("--plant-interval="):
			planting_interval_seconds = maxf(float(arg.trim_prefix("--plant-interval=")), 0.01)
		elif arg.begins_with("--plant-batch="):
			planting_batch_size = maxi(int(arg.trim_prefix("--plant-batch=")), 1)
		elif arg.begins_with("--wall-timeout="):
			wall_timeout_seconds = maxf(float(arg.trim_prefix("--wall-timeout=")), 0.0)
