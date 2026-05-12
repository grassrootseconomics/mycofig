extends Node

const LEVEL_SCENE = preload("res://scenes/level.tscn")
const LevelHelpersRef = preload("res://scenes/level_helpers.gd")

var duration_seconds := 30.0
var seed_value := 4242
var myco_count := 100
var plant_count := 232
var people_count := 50
var basket_count := 10
var columns := 48
var rows := 27
var trace_prefix := "/tmp/mycofig_heavy_mixed"
var draw_lines := true
var bars_on := false
var disable_trades := false
var settle_initial_dirty := false

var _level: Node = null
var _elapsed := 0.0
var _spawn_report := {}


func _ready() -> void:
	_parse_args()
	seed(seed_value)
	Global.mode = "profile"
	Global.challenge_dual_village_enabled = false
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
		"seed": seed_value,
		"target": myco_count + plant_count + people_count + basket_count,
		"duration_s": duration_seconds
	})

	_level = LEVEL_SCENE.instantiate()
	add_child(_level)
	await get_tree().process_frame
	_reset_level()
	_spawn_heavy_mix()
	_configure_trace_paths()
	print(str("[heavy] seed=", seed_value, " duration=", duration_seconds, "s grid=", columns, "x", rows, " lines=", draw_lines, " bars=", bars_on, " trades=", not disable_trades))
	print(str("[heavy] spawned=", JSON.stringify(_spawn_report)))


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration_seconds:
		_finish()


func _reset_level() -> void:
	var agents = _level.get_node_or_null("Agents")
	var trades = _level.get_node_or_null("Trades")
	var lines = _level.get_node_or_null("Lines")
	var animals = _level.get_node_or_null("Animals")
	var sparkles = _level.get_node_or_null("Sparkles")
	if is_instance_valid(lines):
		LevelHelpersRef.clear_trade_line_cache(lines, true)
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
	LevelHelpersRef.rebuild_world_occupancy_cache(_level, agents)
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

	for tile in _cluster_tiles(center + Vector2i(-(cluster_radius + 4), 0), cluster_radius):
		if spawned_baskets >= basket_count:
			break
		if not _claim(used, tile):
			continue
		var node = _level.make_story_basket(world.tile_to_world_center(tile))
		if is_instance_valid(node):
			_prepare_agent(node)
			spawned_baskets += 1

	LevelHelpersRef.rebuild_world_occupancy_cache(_level, agents)
	if _level.has_method("request_all_agents_dirty"):
		_level.request_all_agents_dirty()
	if settle_initial_dirty and _level.has_method("_process_dirty_queues"):
		_level._process_dirty_queues(true)
	_spawn_report = {
		"myco": spawned_myco,
		"plants": spawned_plants,
		"people": spawned_people,
		"baskets": spawned_baskets,
		"agents": agents.get_child_count(),
		"spawn_ms": float(Time.get_ticks_usec() - spawn_start_us) / 1000.0
	}
	Global.apply_perf_density_gate(int(_spawn_report["agents"]))


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
	var run_id = str("seed", seed_value, "_m", myco_count, "_p", plant_count, "_people", people_count, "_b", basket_count, "_lines", int(draw_lines), "_bars", int(bars_on), "_trades", int(not disable_trades))
	perf_monitor.log_to_files = true
	perf_monitor.log_json_path = str(trace_prefix, "_", run_id, ".json")
	perf_monitor.log_csv_path = str(trace_prefix, "_", run_id, ".csv")
	print(str("[heavy] traces json=", perf_monitor.log_json_path, " csv=", perf_monitor.log_csv_path))


func _finish() -> void:
	var agents = _level.get_node_or_null("Agents")
	var trades = _level.get_node_or_null("Trades")
	var lines = _level.get_node_or_null("Lines")
	print(str("[heavy] done elapsed=", _elapsed, " agents=", agents.get_child_count() if is_instance_valid(agents) else 0, " trades=", trades.get_child_count() if is_instance_valid(trades) else 0, " lines=", lines.get_child_count() if is_instance_valid(lines) else 0))
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
