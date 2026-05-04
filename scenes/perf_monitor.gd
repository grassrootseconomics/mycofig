extends CanvasLayer
class_name PerfMonitor

@export var sample_interval_seconds := 0.5
@export var overlay_enabled := false
@export var adaptive_quality_enabled := true
@export var log_to_files := false
@export var log_json_path := ""
@export var log_csv_path := ""

const TIER_ENTER_CONFIRM_SAMPLES := 2
const TIER_EXIT_CONFIRM_SAMPLES := 5
const TIER1_EXIT_SCALE := 0.74
const TIER2_EXIT_SCALE := 0.80
const TIER1_THRESHOLDS := {
	"p95": 13.0,
	"avg": 10.5,
	"agents": 340.0,
	"packets": 145.0,
	"lines": 24.0,
	"bars": 340.0,
	"occ": 38.0
}
const TIER2_THRESHOLDS := {
	"p95": 20.0,
	"avg": 14.5,
	"agents": 500.0,
	"packets": 150.0,
	"lines": 30.0,
	"bars": 500.0,
	"occ": 46.0
}
const PRESSURE_WEIGHTS := {
	"perf": 0.48,
	"agents": 0.24,
	"packets": 0.18,
	"lines": 0.07,
	"bars": 0.02,
	"occ": 0.01
}
const HOTKEY_PERF_OVERLAY := KEY_N

var _level_root: Node = null
var _agents_root: Node = null
var _trades_root: Node = null
var _lines_root: Node = null
var _world_root: Node = null

var _sample_elapsed := 0.0
var _frame_times: Array = []
var _frame_history_limit := 300
var _samples: Array = []
var _overlay_label: Label = null
var _tier_up_counter := 0
var _tier_down_counter := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_overlay()


func configure(level_root: Node, agents_root: Node, trades_root: Node, lines_root: Node, world_root: Node) -> void:
	_level_root = level_root
	_agents_root = agents_root
	_trades_root = trades_root
	_lines_root = lines_root
	_world_root = world_root


func _create_overlay() -> void:
	if is_instance_valid(_overlay_label):
		return
	_overlay_label = Label.new()
	_overlay_label.visible = overlay_enabled
	_overlay_label.position = Vector2(10, 8)
	_overlay_label.z_index = 2048
	_overlay_label.z_as_relative = false
	_overlay_label.text = ""
	add_child(_overlay_label)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == HOTKEY_PERF_OVERLAY:
			overlay_enabled = not overlay_enabled
			if is_instance_valid(_overlay_label):
				_overlay_label.visible = overlay_enabled


func _process(delta: float) -> void:
	_frame_times.append(delta)
	if _frame_times.size() > _frame_history_limit:
		_frame_times.remove_at(0)
	_sample_elapsed += delta
	if _sample_elapsed >= maxf(sample_interval_seconds, 0.1):
		_sample_elapsed = 0.0
		_collect_sample()


func _collect_sample() -> void:
	var frame_avg = _compute_avg(_frame_times)
	var frame_p95 = _compute_percentile(_frame_times, 0.95)
	var active_agents := 0
	var moving_agents := 0
	var visible_bars := 0
	if is_instance_valid(_agents_root):
		for agent in _agents_root.get_children():
			if not is_instance_valid(agent):
				continue
			var dead_variant = agent.get("dead")
			if typeof(dead_variant) == TYPE_BOOL and dead_variant:
				continue
			active_agents += 1
			var dragging := false
			var dragging_variant = agent.get("is_dragging")
			if typeof(dragging_variant) == TYPE_BOOL:
				dragging = dragging_variant
			var keyboard_moving := false
			var keyboard_variant = agent.get("_keyboard_moving")
			if typeof(keyboard_variant) == TYPE_BOOL:
				keyboard_moving = keyboard_variant
			if dragging or keyboard_moving:
				moving_agents += 1
			var bar_canvas = agent.get("bar_canvas")
			if is_instance_valid(bar_canvas) and bar_canvas.visible:
				visible_bars += 1

	var packet_count := 0
	if is_instance_valid(_trades_root):
		packet_count = _trades_root.get_child_count()

	var line_count := 0
	if is_instance_valid(_lines_root):
		for line in _lines_root.get_children():
			if line is Line2D and line.visible:
				line_count += 1

	var soil_tiles_touched = Global.perf_consume_soil_tiles_touched()
	var soil_tick_ms = Global.perf_consume_soil_tick_ms()
	var occupancy_queries = Global.perf_consume_tile_occupancy_queries()
	var run_meta: Dictionary = {}
	if typeof(Global.perf_run_metadata) == TYPE_DICTIONARY:
		run_meta = Global.perf_run_metadata
	var sample = {
		"timestamp_ms": Time.get_ticks_msec(),
		"frame_avg_ms": frame_avg * 1000.0,
		"frame_p95_ms": frame_p95 * 1000.0,
		"active_agents": active_agents,
		"moving_agents": moving_agents,
		"trade_packets": packet_count,
		"line_count": line_count,
		"visible_bars": visible_bars,
		"soil_tiles_touched": soil_tiles_touched,
		"soil_tick_ms": soil_tick_ms,
		"tile_occupancy_queries": occupancy_queries,
		"scenario_id": str(run_meta.get("scenario_id", "")),
		"run_seed": int(run_meta.get("seed", 0)),
		"run_profile": str(run_meta.get("profile", "")),
		"run_target": int(run_meta.get("target", 0)),
		"quality_tier": Global.get_effective_perf_tier()
	}

	var pressure_t1 = _compute_pressure_score(sample, TIER1_THRESHOLDS)
	var pressure_t2 = _compute_pressure_score(sample, TIER2_THRESHOLDS)
	sample["pressure_t1"] = pressure_t1
	sample["pressure_t2"] = pressure_t2

	_samples.append(sample)
	Global.perf_set_last_sample(sample)

	if adaptive_quality_enabled and Global.perf_adaptive_enabled and Global.perf_quality_override < 0:
		_apply_adaptive_tier_from_sample(sample)
		sample["quality_tier"] = Global.get_effective_perf_tier()

	_update_overlay(sample)


func _compute_pressure_score(sample: Dictionary, thresholds: Dictionary) -> float:
	var perf_pressure = maxf(
		float(sample.get("frame_p95_ms", 0.0)) / maxf(float(thresholds.get("p95", 1.0)), 0.001),
		float(sample.get("frame_avg_ms", 0.0)) / maxf(float(thresholds.get("avg", 1.0)), 0.001)
	)
	var agents_pressure = float(sample.get("active_agents", 0.0)) / maxf(float(thresholds.get("agents", 1.0)), 0.001)
	var packets_pressure = float(sample.get("trade_packets", 0.0)) / maxf(float(thresholds.get("packets", 1.0)), 0.001)
	var lines_pressure = float(sample.get("line_count", 0.0)) / maxf(float(thresholds.get("lines", 1.0)), 0.001)
	var bars_pressure = float(sample.get("visible_bars", 0.0)) / maxf(float(thresholds.get("bars", 1.0)), 0.001)
	var occ_pressure = float(sample.get("tile_occupancy_queries", 0.0)) / maxf(float(thresholds.get("occ", 1.0)), 0.001)
	return (
		(perf_pressure * float(PRESSURE_WEIGHTS["perf"])) +
		(agents_pressure * float(PRESSURE_WEIGHTS["agents"])) +
		(packets_pressure * float(PRESSURE_WEIGHTS["packets"])) +
		(lines_pressure * float(PRESSURE_WEIGHTS["lines"])) +
		(bars_pressure * float(PRESSURE_WEIGHTS["bars"])) +
		(occ_pressure * float(PRESSURE_WEIGHTS["occ"]))
	)


func _apply_adaptive_tier_from_sample(sample: Dictionary) -> void:
	var current_tier = clampi(int(Global.perf_tier), 0, 2)
	var score_t1 = float(sample.get("pressure_t1", 0.0))
	var score_t2 = float(sample.get("pressure_t2", 0.0))
	var next_tier = current_tier

	if current_tier <= 0:
		if score_t1 >= 1.0:
			_tier_up_counter += 1
			_tier_down_counter = 0
			if _tier_up_counter >= TIER_ENTER_CONFIRM_SAMPLES:
				next_tier = 1
		else:
			_tier_up_counter = 0
	elif current_tier == 1:
		if score_t2 >= 1.0:
			_tier_up_counter += 1
			_tier_down_counter = 0
			if _tier_up_counter >= TIER_ENTER_CONFIRM_SAMPLES:
				next_tier = 2
		else:
			_tier_up_counter = 0
			if score_t1 < TIER1_EXIT_SCALE:
				_tier_down_counter += 1
				if _tier_down_counter >= TIER_EXIT_CONFIRM_SAMPLES:
					next_tier = 0
			else:
				_tier_down_counter = 0
	else:
		if score_t2 < TIER2_EXIT_SCALE:
			_tier_down_counter += 1
			if _tier_down_counter >= TIER_EXIT_CONFIRM_SAMPLES:
				next_tier = 1
		else:
			_tier_down_counter = 0

	if next_tier != current_tier:
		Global.set_perf_tier(next_tier)
		_tier_up_counter = 0
		_tier_down_counter = 0


func _update_overlay(sample: Dictionary) -> void:
	if not is_instance_valid(_overlay_label):
		return
	_overlay_label.visible = overlay_enabled
	if not overlay_enabled:
		return
	var lines = [
		"Perf Monitor (N)",
		str("tier=", sample.get("quality_tier", 0), " avg=", _fmt(sample.get("frame_avg_ms", 0.0)), "ms p95=", _fmt(sample.get("frame_p95_ms", 0.0)), "ms"),
		str("pressure t1=", _fmt(sample.get("pressure_t1", 0.0)), " t2=", _fmt(sample.get("pressure_t2", 0.0))),
		str("agents=", sample.get("active_agents", 0), " moving=", sample.get("moving_agents", 0)),
		str("packets=", sample.get("trade_packets", 0), " lines=", sample.get("line_count", 0), " bars=", sample.get("visible_bars", 0)),
		str("soil_tick_tiles=", sample.get("soil_tiles_touched", 0), " soil_tick_ms=", _fmt(sample.get("soil_tick_ms", 0.0)), " occ_q=", sample.get("tile_occupancy_queries", 0))
	]
	_overlay_label.text = "\n".join(lines)


func _fmt(value: Variant) -> String:
	return "%0.2f" % float(value)


func _compute_avg(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return total / float(values.size())


func _compute_percentile(values: Array, percentile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	var idx = int(clampf(percentile, 0.0, 1.0) * float(sorted.size() - 1))
	return float(sorted[idx])


func _exit_tree() -> void:
	if not log_to_files and not Global.perf_metrics_enabled:
		return
	_write_logs()


func _write_logs() -> void:
	var json_target = log_json_path if log_json_path != "" else "user://perf_metrics.json"
	var csv_target = log_csv_path if log_csv_path != "" else "user://perf_metrics.csv"
	var json_file = FileAccess.open(json_target, FileAccess.WRITE)
	if json_file != null:
		json_file.store_string(JSON.stringify(_samples))
		json_file.close()

	var csv_file = FileAccess.open(csv_target, FileAccess.WRITE)
	if csv_file != null:
		csv_file.store_line("timestamp_ms,scenario_id,run_profile,run_seed,run_target,frame_avg_ms,frame_p95_ms,active_agents,moving_agents,trade_packets,line_count,visible_bars,soil_tiles_touched,soil_tick_ms,tile_occupancy_queries,pressure_t1,pressure_t2,quality_tier")
		for sample_variant in _samples:
			if typeof(sample_variant) != TYPE_DICTIONARY:
				continue
			var sample: Dictionary = sample_variant
			csv_file.store_line(
				str(sample.get("timestamp_ms", 0), ",",
				sample.get("scenario_id", ""), ",",
				sample.get("run_profile", ""), ",",
				sample.get("run_seed", 0), ",",
				sample.get("run_target", 0), ",",
				sample.get("frame_avg_ms", 0.0), ",",
				sample.get("frame_p95_ms", 0.0), ",",
				sample.get("active_agents", 0), ",",
				sample.get("moving_agents", 0), ",",
				sample.get("trade_packets", 0), ",",
					sample.get("line_count", 0), ",",
					sample.get("visible_bars", 0), ",",
					sample.get("soil_tiles_touched", 0), ",",
					sample.get("soil_tick_ms", 0.0), ",",
					sample.get("tile_occupancy_queries", 0), ",",
					sample.get("pressure_t1", 0.0), ",",
					sample.get("pressure_t2", 0.0), ",",
					sample.get("quality_tier", 0))
			)
		csv_file.close()
