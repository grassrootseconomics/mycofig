extends RefCounted
class_name LevelRuntimeServices

const PerfMonitorRef = preload("res://scenes/perf_monitor.gd")
const LevelHelpersRef = preload("res://scenes/level_helpers.gd")

const DIRTY_BUDDY_PROCESS_CAP_T0 := 96
const DIRTY_BUDDY_PROCESS_CAP_T1 := 32
const DIRTY_BUDDY_PROCESS_CAP_T2 := 16
const DIRTY_LINE_PROCESS_CAP_T0 := 160
const DIRTY_LINE_PROCESS_CAP_T1 := 64
const DIRTY_LINE_PROCESS_CAP_T2 := 32
const DIRTY_TILE_HINT_PROCESS_CAP := 24


func agent_key(agent: Variant) -> int:
	if not is_instance_valid(agent):
		return -1
	return int(agent.get_instance_id())


func request_agent_dirty(dirty_buddies: Dictionary, dirty_lines: Dictionary, dirty_tile_hints: Dictionary, agent: Variant, buddies: bool = true, lines: bool = true, tile_hint: bool = false) -> void:
	var key = agent_key(agent)
	if key < 0:
		return
	if buddies:
		dirty_buddies[key] = agent
	if lines and str(agent.get("type")) != "cloud":
		dirty_lines[key] = agent
	if tile_hint:
		dirty_tile_hints[key] = agent


func _get_dirty_buddy_process_cap() -> int:
	match Global.get_effective_perf_tier():
		1:
			return DIRTY_BUDDY_PROCESS_CAP_T1
		2:
			return DIRTY_BUDDY_PROCESS_CAP_T2
		_:
			return DIRTY_BUDDY_PROCESS_CAP_T0


func _get_dirty_line_process_cap() -> int:
	match Global.get_effective_perf_tier():
		1:
			return DIRTY_LINE_PROCESS_CAP_T1
		2:
			return DIRTY_LINE_PROCESS_CAP_T2
		_:
			return DIRTY_LINE_PROCESS_CAP_T0


func _is_priority_dirty_agent(agent: Variant) -> bool:
	if not is_instance_valid(agent):
		return false
	if is_instance_valid(Global.active_agent) and agent == Global.active_agent:
		return true
	var dragging_variant = agent.get("is_dragging")
	if typeof(dragging_variant) == TYPE_BOOL and Global.to_bool(dragging_variant):
		return true
	var keyboard_variant = agent.get("_keyboard_moving")
	return typeof(keyboard_variant) == TYPE_BOOL and Global.to_bool(keyboard_variant)


func _take_dirty_agents(dirty_store: Dictionary, max_count: int, skip_keys: Dictionary = {}) -> Array:
	var agents: Array = []
	var processed_keys: Array = []
	for priority_pass in [true, false]:
		for key in dirty_store.keys():
			if max_count >= 0 and agents.size() >= max_count:
				break
			if skip_keys.has(key) or processed_keys.has(key):
				continue
			var agent = dirty_store[key]
			if priority_pass and not _is_priority_dirty_agent(agent):
				continue
			if not priority_pass and _is_priority_dirty_agent(agent):
				continue
			processed_keys.append(key)
			if is_instance_valid(agent) and not Global.to_bool(agent.get("dead")):
				agents.append(agent)
	for key in processed_keys:
		dirty_store.erase(key)
	return agents


func _count_live_agents(agents_root: Node) -> int:
	if not is_instance_valid(agents_root):
		return 0
	var total := 0
	for agent in agents_root.get_children():
		if not is_instance_valid(agent):
			continue
		if Global.to_bool(agent.get("dead")):
			continue
		if str(agent.get("type")) == "cloud":
			continue
		total += 1
	return total


func process_dirty_queues(level_root: Node, agents_root: Node, lines_root: Node, dirty_buddies: Dictionary, dirty_lines: Dictionary, dirty_tile_hints: Dictionary, social_mode: bool, force_all: bool = false) -> void:
	if dirty_buddies.is_empty() and dirty_lines.is_empty() and dirty_tile_hints.is_empty():
		return
	var active_agents = _count_live_agents(agents_root)
	Global.apply_perf_density_gate(active_agents)
	var dense_force = force_all and active_agents > Global.PERF_DENSITY_TIER1_AGENT_COUNT
	var buddy_cap = -1 if force_all and not dense_force else _get_dirty_buddy_process_cap()
	var line_cap = -1 if force_all and not dense_force else _get_dirty_line_process_cap()
	var tile_hint_cap = -1 if force_all else DIRTY_TILE_HINT_PROCESS_CAP

	var buddy_agents = _take_dirty_agents(dirty_buddies, buddy_cap)
	for agent in buddy_agents:
		if agent.has_method("generate_buddies"):
			agent.generate_buddies()

	var tile_hint_agents = _take_dirty_agents(dirty_tile_hints, tile_hint_cap)
	for agent in tile_hint_agents:
		if agent.has_method("_update_drag_tile_hint"):
			var pos = agent.get("position")
			if typeof(pos) == TYPE_VECTOR2:
				agent._update_drag_tile_hint(pos)

	if not Global.draw_lines:
		dirty_lines.clear()
	elif not dirty_lines.is_empty():
		var line_agents = _take_dirty_agents(dirty_lines, line_cap, dirty_buddies)
		if not line_agents.is_empty():
			LevelHelpers.sync_myco_trade_lines(lines_root, agents_root, social_mode, line_agents)


func setup_perf_monitor(owner: Node, existing_monitor: Node, agents_root: Node, trades_root: Node, lines_root: Node, world_root: Node) -> Node:
	if is_instance_valid(existing_monitor):
		return existing_monitor
	if not is_instance_valid(owner):
		return null
	var perf_monitor = PerfMonitorRef.new()
	perf_monitor.name = "PerfMonitor"
	perf_monitor.overlay_enabled = false
	perf_monitor.adaptive_quality_enabled = true
	perf_monitor.log_to_files = Global.perf_metrics_enabled
	owner.add_child(perf_monitor)
	perf_monitor.configure(owner, agents_root, trades_root, lines_root, world_root)
	return perf_monitor


func build_trade_visual_key(path_dict: Dictionary) -> String:
	var from_agent = path_dict.get("from_agent", null)
	var to_agent = path_dict.get("to_agent", null)
	var asset_key = str(path_dict.get("trade_asset", ""))
	if asset_key == "":
		return ""
	if not is_instance_valid(from_agent) or not is_instance_valid(to_agent):
		return ""
	return str(int(from_agent.get_instance_id()), "->", int(to_agent.get_instance_id()), ":", asset_key)


func get_trade_visual_key_for_packet(trade: Node) -> String:
	if not is_instance_valid(trade):
		return ""
	if not trade.has_method("get_trade_visual_key"):
		return ""
	return str(trade.call("get_trade_visual_key"))


func get_trade_visual_packets_for_key(packet_store: Dictionary, trades_root: Node, visual_key: String) -> Array:
	var packets: Array = []
	if visual_key == "":
		return packets
	var packets_variant = packet_store.get(visual_key, [])
	if typeof(packets_variant) != TYPE_ARRAY:
		packet_store.erase(visual_key)
		return packets
	for trade in packets_variant:
		if not is_instance_valid(trade):
			continue
		if is_instance_valid(trades_root) and trade.get_parent() != trades_root:
			continue
		if get_trade_visual_key_for_packet(trade) != visual_key:
			continue
		packets.append(trade)
	if packets.is_empty():
		packet_store.erase(visual_key)
	else:
		packet_store[visual_key] = packets
	return packets


func register_trade_visual_packet(packet_store: Dictionary, trade: Node) -> void:
	var visual_key = get_trade_visual_key_for_packet(trade)
	if visual_key == "":
		return
	var packets_variant = packet_store.get(visual_key, [])
	var packets: Array = packets_variant if typeof(packets_variant) == TYPE_ARRAY else []
	if not packets.has(trade):
		packets.append(trade)
	packet_store[visual_key] = packets


func unregister_trade_visual_packet(packet_store: Dictionary, trade: Node) -> void:
	var visual_key = get_trade_visual_key_for_packet(trade)
	if visual_key == "":
		return
	if not packet_store.has(visual_key):
		return
	var packets_variant = packet_store.get(visual_key, [])
	if typeof(packets_variant) != TYPE_ARRAY:
		packet_store.erase(visual_key)
		return
	var packets: Array = packets_variant
	packets.erase(trade)
	if packets.is_empty():
		packet_store.erase(visual_key)
	else:
		packet_store[visual_key] = packets


func recycle_trade(trade_pool: Array, packet_store: Dictionary, trade: Node) -> void:
	if not is_instance_valid(trade):
		return
	unregister_trade_visual_packet(packet_store, trade)
	var already_pooled = trade_pool.has(trade)
	if trade.has_method("prepare_for_pool"):
		trade.call("prepare_for_pool")
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
	if not already_pooled:
		trade_pool.append(trade)
