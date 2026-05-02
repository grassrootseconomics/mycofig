extends RefCounted
class_name LevelHelpers


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


static func stop_audio_players(players: Array) -> void:
	for player in players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
