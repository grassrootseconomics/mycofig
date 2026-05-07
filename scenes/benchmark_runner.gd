extends Node

const LEVEL_SCENE = preload("res://scenes/level.tscn")

var scenario := "s1"
var duration_seconds := 60.0
var spawn_target := 700
var spawn_batch := 10
var spawn_interval := 0.2
var seed_value := 1337
var write_traces := true
var trace_prefix := "/tmp/mycofig_trace"
var benchmark_draw_lines := true
var benchmark_bars_on := false

var interaction_interval := 0.35
var interaction_burst_actions := 8
var endurance_churn_interval := 1.0
var endurance_churn_batch := 10
var scenario_profile := "baseline"

var _rng := RandomNumberGenerator.new()
var _elapsed := 0.0
var _spawn_elapsed := 0.0
var _interaction_elapsed := 0.0
var _endurance_elapsed := 0.0
var _spawned_agents := 0
var _level: Node = null
var _trace_json_path := ""
var _trace_csv_path := ""


func _ready() -> void:
	_parse_args()
	_apply_scenario_profile()
	_rng.seed = seed_value
	seed(seed_value)

	Global.mode = "challenge"
	Global.stage = 1
	Global.social_mode = false
	Global.draw_lines = benchmark_draw_lines
	Global.bars_on = benchmark_bars_on
	Global.perf_metrics_enabled = true
	Global.perf_quality_override = -1
	Global.perf_adaptive_enabled = true
	Global.set_perf_tier(0)
	Global.perf_set_run_metadata({
		"scenario_id": scenario,
		"profile": scenario_profile,
		"seed": seed_value,
		"target": spawn_target,
		"duration_s": duration_seconds
	})

	_level = LEVEL_SCENE.instantiate()
	add_child(_level)
	_configure_perf_monitor_trace_paths()
	print(str("[bench] scenario=", scenario, " profile=", scenario_profile, " seed=", seed_value, " duration=", duration_seconds, "s target=", spawn_target))


func _process(delta: float) -> void:
	_elapsed += delta
	if scenario == "s2" or scenario == "s3" or scenario == "s4":
		_run_spawn_ramp(delta)
	if scenario == "s3":
		_run_interaction_stress(delta)
	elif scenario == "s4":
		_run_endurance_churn(delta)
	if _elapsed >= duration_seconds:
		_finish()


func _apply_scenario_profile() -> void:
	match scenario:
		"s2":
			scenario_profile = "density_ramp"
		"s3":
			scenario_profile = "interaction_stress"
			spawn_batch = maxi(spawn_batch, 12)
			spawn_interval = minf(spawn_interval, 0.16)
		"s4":
			scenario_profile = "endurance_soak"
			spawn_batch = maxi(spawn_batch, 14)
			spawn_interval = minf(spawn_interval, 0.14)
			duration_seconds = maxf(duration_seconds, 120.0)
			endurance_churn_batch = maxi(endurance_churn_batch, 12)
		_:
			scenario_profile = "baseline"


func _run_spawn_ramp(delta: float) -> void:
	if not is_instance_valid(_level):
		return
	if _spawned_agents >= spawn_target:
		return
	_spawn_elapsed += delta
	if _spawn_elapsed < spawn_interval:
		return
	_spawn_elapsed = 0.0
	for _i in range(spawn_batch):
		if _spawned_agents >= spawn_target:
			break
		if _spawn_random_agent(false):
			_spawned_agents += 1


func _run_interaction_stress(delta: float) -> void:
	_interaction_elapsed += delta
	if _interaction_elapsed < interaction_interval:
		return
	_interaction_elapsed = 0.0
	for _i in range(interaction_burst_actions):
		var roll = _rng.randf()
		if roll < 0.45:
			_kill_random_agent()
		elif roll < 0.85:
			_spawn_random_agent(true)
		else:
			_spawn_random_agent(false)


func _run_endurance_churn(delta: float) -> void:
	if _spawned_agents < spawn_target:
		return
	_endurance_elapsed += delta
	if _endurance_elapsed < endurance_churn_interval:
		return
	_endurance_elapsed = 0.0
	var live_agents = _get_live_agent_count()
	var top_up = maxi(spawn_target - live_agents, 0)
	for _i in range(top_up):
		_spawn_random_agent(true, false)
		live_agents += 1
	for _i in range(endurance_churn_batch):
		if live_agents > spawn_target and _rng.randf() < 0.35:
			if _kill_random_agent(false):
				live_agents -= 1
		if _spawn_random_agent(true, false):
			live_agents += 1


func _spawn_random_agent(allow_replace: bool, include_myco: bool = true) -> bool:
	if not is_instance_valid(_level):
		return false
	var agents_root = _level.get_node_or_null("Agents")
	var world = _level.get_node_or_null("WorldFoundation")
	if not is_instance_valid(agents_root) or not is_instance_valid(world):
		return false
	var limits = Vector2i(int(world.get("columns")), int(world.get("rows")))
	if limits.x <= 0 or limits.y <= 0:
		return false
	var spawn_type = _pick_spawn_type(include_myco)
	var coord = Vector2i(_rng.randi_range(0, limits.x - 1), _rng.randi_range(0, limits.y - 1))
	var spawn_pos = world.tile_to_world_center(coord)
	var before = agents_root.get_child_count()
	_level._on_new_agent({
		"name": spawn_type,
		"pos": spawn_pos,
		"require_exact_tile": true,
		"allow_replace": allow_replace,
		"allow_unanchored_spawn": true
	})
	return agents_root.get_child_count() > before


func _kill_random_agent(exclude_myco: bool = false) -> bool:
	if not is_instance_valid(_level):
		return false
	var agents_root = _level.get_node_or_null("Agents")
	if not is_instance_valid(agents_root):
		return false
	var candidates: Array = []
	for agent in agents_root.get_children():
		if not is_instance_valid(agent):
			continue
		if bool(agent.get("dead")):
			continue
		var agent_type = str(agent.get("type"))
		if agent_type == "cloud":
			continue
		if exclude_myco and agent_type == "myco":
			continue
		if not bool(agent.get("killable")):
			continue
		candidates.append(agent)
	if candidates.is_empty():
		return false
	var target = candidates[_rng.randi_range(0, candidates.size() - 1)]
	if target.has_method("kill_it"):
		target.kill_it()
	else:
		target.call_deferred("queue_free")
	return true


func _pick_spawn_type(include_myco: bool = true) -> String:
	if not include_myco:
		var non_myco_roll = _rng.randf()
		if non_myco_roll < 0.43:
			return "bean"
		if non_myco_roll < 0.73:
			return "squash"
		if non_myco_roll < 0.93:
			return "maize"
		return "tree"
	var roll = _rng.randf()
	if roll < 0.40:
		return "bean"
	if roll < 0.70:
		return "squash"
	if roll < 0.90:
		return "maize"
	if roll < 0.97:
		return "tree"
	return "myco"


func _get_live_agent_count() -> int:
	if not is_instance_valid(_level):
		return 0
	var agents_root = _level.get_node_or_null("Agents")
	if not is_instance_valid(agents_root):
		return 0
	var total := 0
	for agent in agents_root.get_children():
		if not is_instance_valid(agent):
			continue
		if bool(agent.get("dead")):
			continue
		if str(agent.get("type")) == "cloud":
			continue
		total += 1
	return total


func _finish() -> void:
	var agents_count := 0
	var trades_count := 0
	var lines_count := 0
	if is_instance_valid(_level):
		var agents_root = _level.get_node_or_null("Agents")
		var trades_root = _level.get_node_or_null("Trades")
		var lines_root = _level.get_node_or_null("Lines")
		if is_instance_valid(agents_root):
			agents_count = agents_root.get_child_count()
		if is_instance_valid(trades_root):
			trades_count = trades_root.get_child_count()
		if is_instance_valid(lines_root):
			lines_count = lines_root.get_child_count()
	var sample = Global.perf_last_sample
	print(str("[bench] done elapsed=", _elapsed, " spawned=", _spawned_agents, " agents=", agents_count, " trades=", trades_count, " lines=", lines_count))
	if write_traces:
		print(str("[bench] traces json=", _trace_json_path, " csv=", _trace_csv_path))
	if typeof(sample) == TYPE_DICTIONARY and not sample.is_empty():
		print(str("[bench] last_sample=", JSON.stringify(sample)))
	if is_instance_valid(_level):
		if _level.get_parent() != null:
			_level.get_parent().remove_child(_level)
		_level.free()
		_level = null
	get_tree().quit()


func _configure_perf_monitor_trace_paths() -> void:
	if not write_traces:
		return
	if not is_instance_valid(_level):
		return
	var perf_monitor = _level.get_node_or_null("PerfMonitor")
	if not is_instance_valid(perf_monitor):
		return
	var run_id = str(scenario, "_", scenario_profile, "_seed", seed_value, "_target", spawn_target)
	_trace_json_path = str(trace_prefix, "_", run_id, ".json")
	_trace_csv_path = str(trace_prefix, "_", run_id, ".csv")
	perf_monitor.log_to_files = true
	perf_monitor.log_json_path = _trace_json_path
	perf_monitor.log_csv_path = _trace_csv_path


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			scenario = arg.trim_prefix("--scenario=").to_lower()
		elif arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--duration="):
			duration_seconds = maxf(float(arg.trim_prefix("--duration=")), 5.0)
		elif arg.begins_with("--target="):
			spawn_target = maxi(int(arg.trim_prefix("--target=")), 1)
		elif arg.begins_with("--spawn-batch="):
			spawn_batch = maxi(int(arg.trim_prefix("--spawn-batch=")), 1)
		elif arg.begins_with("--spawn-interval="):
			spawn_interval = maxf(float(arg.trim_prefix("--spawn-interval=")), 0.01)
		elif arg.begins_with("--interaction-interval="):
			interaction_interval = maxf(float(arg.trim_prefix("--interaction-interval=")), 0.05)
		elif arg.begins_with("--interaction-burst="):
			interaction_burst_actions = maxi(int(arg.trim_prefix("--interaction-burst=")), 1)
		elif arg.begins_with("--endurance-interval="):
			endurance_churn_interval = maxf(float(arg.trim_prefix("--endurance-interval=")), 0.1)
		elif arg.begins_with("--endurance-batch="):
			endurance_churn_batch = maxi(int(arg.trim_prefix("--endurance-batch=")), 1)
		elif arg.begins_with("--trace-prefix="):
			trace_prefix = arg.trim_prefix("--trace-prefix=")
		elif arg == "--lines":
			benchmark_draw_lines = true
		elif arg == "--no-lines":
			benchmark_draw_lines = false
		elif arg == "--bars":
			benchmark_bars_on = true
		elif arg == "--no-bars":
			benchmark_bars_on = false
		elif arg == "--no-trace":
			write_traces = false
