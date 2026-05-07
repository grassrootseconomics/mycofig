extends RefCounted
class_name LevelRuntimeServices

const PerfMonitorRef = preload("res://scenes/perf_monitor.gd")
const LevelHelpersRef = preload("res://scenes/level_helpers.gd")


static func agent_key(agent: Variant) -> int:
	if not is_instance_valid(agent):
		return -1
	return int(agent.get_instance_id())


static func request_agent_dirty(dirty_buddies: Dictionary, dirty_lines: Dictionary, dirty_tile_hints: Dictionary, agent: Variant, buddies: bool = true, lines: bool = true, tile_hint: bool = false) -> void:
	var key = agent_key(agent)
	if key < 0:
		return
	if buddies:
		dirty_buddies[key] = agent
	if lines and str(agent.get("type")) != "cloud":
		dirty_lines[key] = agent
	if tile_hint:
		dirty_tile_hints[key] = agent


static func process_dirty_queues(level_root: Node, agents_root: Node, lines_root: Node, dirty_buddies: Dictionary, dirty_lines: Dictionary, dirty_tile_hints: Dictionary, social_mode: bool) -> void:
	if dirty_buddies.is_empty() and dirty_lines.is_empty() and dirty_tile_hints.is_empty():
		return
	for key in dirty_buddies.keys():
		var agent = dirty_buddies[key]
		if not is_instance_valid(agent):
			continue
		if bool(agent.get("dead")):
			continue
		if agent.has_method("generate_buddies"):
			agent.generate_buddies()
	for key in dirty_tile_hints.keys():
		var agent = dirty_tile_hints[key]
		if not is_instance_valid(agent):
			continue
		if bool(agent.get("dead")):
			continue
		if agent.has_method("_update_drag_tile_hint"):
			var pos = agent.get("position")
			if typeof(pos) == TYPE_VECTOR2:
				agent._update_drag_tile_hint(pos)
	if Global.draw_lines and not dirty_lines.is_empty():
		LevelHelpersRef.sync_myco_trade_lines(lines_root, agents_root, social_mode, dirty_lines.values())
	dirty_buddies.clear()
	dirty_lines.clear()
	dirty_tile_hints.clear()


static func setup_perf_monitor(owner: Node, existing_monitor: Node, agents_root: Node, trades_root: Node, lines_root: Node, world_root: Node) -> Node:
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


static func build_trade_visual_key(path_dict: Dictionary) -> String:
	var from_agent = path_dict.get("from_agent", null)
	var to_agent = path_dict.get("to_agent", null)
	var asset_key = str(path_dict.get("trade_asset", ""))
	if asset_key == "":
		return ""
	if not is_instance_valid(from_agent) or not is_instance_valid(to_agent):
		return ""
	return str(int(from_agent.get_instance_id()), "->", int(to_agent.get_instance_id()), ":", asset_key)


static func get_trade_visual_key_for_packet(trade: Node) -> String:
	if not is_instance_valid(trade):
		return ""
	if not trade.has_method("get_trade_visual_key"):
		return ""
	return str(trade.call("get_trade_visual_key"))


static func get_trade_visual_packets_for_key(packet_store: Dictionary, trades_root: Node, visual_key: String) -> Array:
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


static func register_trade_visual_packet(packet_store: Dictionary, trade: Node) -> void:
	var visual_key = get_trade_visual_key_for_packet(trade)
	if visual_key == "":
		return
	var packets_variant = packet_store.get(visual_key, [])
	var packets: Array = packets_variant if typeof(packets_variant) == TYPE_ARRAY else []
	if not packets.has(trade):
		packets.append(trade)
	packet_store[visual_key] = packets


static func unregister_trade_visual_packet(packet_store: Dictionary, trade: Node) -> void:
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


static func recycle_trade(trade_pool: Array, packet_store: Dictionary, trade: Node) -> void:
	if not is_instance_valid(trade):
		return
	unregister_trade_visual_packet(packet_store, trade)
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
	trade_pool.append(trade)
