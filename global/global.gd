extends Node

var score := 0
var high_score := 0
var last_score := 0
var last_rank_key := 0
const HIGH_SCORE_SAVE_PATH := "user://high_score.cfg"

var move_rate = 1 #4 #6
var movement_speed = 50 #100 #200
var social_buddy_radius = 128
var num_connectors = 4
var active_agent = null
var is_mobile_platform = false

var is_dragging = false
var bars_on = false
var stage_inc = 0
var max_stage_inc = 5
var baby_mode = true
var allow_agent_reposition = false
var draw_lines = true

var social_mode = false
var world_bounds_enabled = false
var world_rect = Rect2(Vector2.ZERO, Vector2.ZERO)
var active_mode_id = ""
var active_scenario_id = ""
var story_chapter_id := 1
var village_revealed := false
var village_objective_flags := {}
var story_force_visible_plant_bars := false
var enable_tuktuk_predators := false
var prevent_auto_select = false
var perf_adaptive_enabled = true
var perf_quality_override = -1
var perf_metrics_enabled = false
var perf_tier = 0
var perf_soil_tiles_touched_last_tick = 0
var perf_soil_tick_ms_last = 0.0
var perf_tile_occupancy_queries = 0
var perf_last_sample = {}
var perf_run_metadata = {}
var minimap_adaptive_redraw_enabled = true
var ui_layout_cadence_enabled = true
var trade_dispatch_limit_enabled = true
var trade_sender_rate_per_sec := 6.0
var trade_sender_burst := 2.0
var trade_link_rate_per_sec := 4.0
var trade_link_burst := 1.0
var trade_sender_rate_per_sec_village := 14.0
var trade_sender_burst_village := 4.0
var trade_link_rate_per_sec_village := 10.0
var trade_link_burst_village := 2.0
var trade_sender_rate_per_sec_myco := 14.0
var trade_sender_burst_myco := 4.0
var trade_link_rate_per_sec_myco := 10.0
var trade_link_burst_myco := 2.0
var trade_visual_hybrid_enabled := true
var trade_visual_per_link_cap_t0 := 4
var trade_visual_per_link_cap_t1 := 3
var trade_visual_per_link_cap_t2 := 2
var _trade_sender_buckets: Dictionary = {}
var _trade_link_buckets: Dictionary = {}



var sparkle_scene: PackedScene = load("res://scenes/sparkle.tscn")

var growth_time = 0.4
var decay_time = 1110.6
var action_time = 0.3
var village_action_time := 0.2
var evap_time = 1
var mode = "challenge"
var stage = 1
var is_raining = true
var is_birding = true
var is_killing = true
var is_max_babies = true
var challenge_dual_village_enabled = true
var villager_r_buffer_target := 1
var villager_surplus_dominance_margin := 1
var villager_r_medium_only := true
var story_farmer_inbound_wait_timeout_sec := 1.8
var villager_max_liquidity_inflight_swaps := 4

var quarry_type = "maize"

var eco_names = ["bean","squash","maize","tree", "myco"]
var social_names = ["service","good","city","value add", "basket"]

var inventory = { #how many of each plant do we have to use
	"bean": 12,
	"squash": 12,				
	"maize": 12,
	"tree": 12,
	"myco": 12,
	"farmer": 0,
	"vendor": 0,
	"cook": 0,
	"basket": 0
	}

var social_inventory = { #how many of each plant do we have to use
	"service": 12,
	"good": 12,				
	"value add": 12,
	"city": 12,
	"basket": 12
	}

var values = { #list of assets - 
	#for each asset there is a balance, and stready state amount needed for growth
	"N": 1,
	"P": 1,				
	"K": 1,
	"R": 1
	
	}
	
var assets_social = { #list of assets - 
	#for each asset there is a balance, and stready state amount needed for growth
	"N": "Farming",
	"P": "Teaching",				
	"K": "Cooking",
	"R": "Money"
	
	}

var story_stage_text = {
	1: "Phase 1 - Start Your Garden!

Your basket below has beans, squash, maize, tree seeds, and mushrooms.

Tap to plant one of each.",
	2: "Phase 2 - Harvest Time!

Tap ready plants to harvest them before the birds do.

Try to collect one of each garden item.",
	3: "Phase 3 - Grow your garden!
	
	Tap plants to check their need. Plant mushrooms so nearby plants can share through the network.",
	4: "Phase 4 - You Found a Village!

The farmers need healthy food.

Grow crops near the village so the farmers can harvest and recover.",
	5: "Phase 5: Help them share!
	
	Some villagers have goods, skills, time or services, but not enough money.

	Place a basket near the village so people can trade with eachother - before more leave the village!",
	6: "You Did It!

You helped the garden grow and helped the village share again.

You restored healthy soil and strong village connections. Ready for Challenge Mode?"
}
	
var assets_plant = { #list of assets - 
	#for each asset there is a balance, and stready state amount needed for growth
	"N": "Nitrogen (N)",
	"P": "Potassium (P)",				
	"K": "Phosphorous (K)",
	"R": "Rain Water (R)"
	
	}	

var social_values = { #list of assets - 
	#for each asset there is a balance, and stready state amount needed for growth
	"S": 1, #services
	"G": 1, #goods	
	"F": 1, #foreign
	"M": 1 #money
	
	}


var asset_colors = {
	"N": Color.SPRING_GREEN,
	"P": Color.ORANGE,
	"K": Color.VIOLET,
	"R": Color.DEEP_SKY_BLUE
	}
	
var asset_colors_social = {
	"S": Color.SPRING_GREEN,
	"G": Color.ORANGE,
	"F": Color.VIOLET,
	"M": Color.DEEP_SKY_BLUE
	}

	
var ranks = {
	0: "Sporeling",
	20000: "Mycelium Weaver",
	50000: "Mycorrhizal Guardian",
	200000: "Myceliator",
	500000: "Shroom Architect",
	1000000: "Nutrient Flow Oracle",
	2000000: "Fungal Network Shepherd",
	3000000: "Mycorrhizal Visionary",
	4000000: "Soil Web Custodian 1",
	5000000: "Grassroots Economist"
}



var birds = {
	0: 0,
	1000: 1,
	2000: 1,
	5000: 1,
	10000: 1,
	50000: 1,
	100000: 5,
	500000: 10,
	1000000: 15,
	2000000: 20,
	3000000: 23,
	4000000: 25,
	5000000: 1
}

var rand_quarry = ["maize","bean","squash"]
# Lightweight runtime cap for mobile sessions.
var max_predators_per_wave_mobile = 6
#var rand_quarry_social = ["maize","bean","squash"]
#var rand_quarry = ["bean"]

var stage_text = {
	1: "Stage 1: Each plant is rich in minerals:
	Beans -> (N) Nitrogen (Green)
	Squash -> (P) Potassium (Orange)
	Maize -> (K) Phosphorous (Pink)
	Trees -> (R) Water (Blue)
	** Click and drag the mushroom and plants so that the mycorrhizal fungi touches all five plants.",
	2: "Stage 2: The mycorrhizal fungi is now distributing resources to the plants and more plants should start growing!
	
	** Click and drag another mushroom from your inventory below, into the garden to help the baby plants.",
	3: "Stage 3: Now you have two mycorrhizal fungi! 
	
	When fungi are connected together they can also help each other and store nutrients for hard times. 
	** Click and drag another mushroom from your inventory below and ensure all 3 fungi are connected to eachother and that they have all the resources they need.",
	
	4: "Stage 4: You are doing great!
	
	With all these fungi connected your garden should be able to feed some hungry birds!
	
	** After the birds have eaten your maize. Add three maize from your inventory.",
	5: "Stage 5: Grow maize faster by increasing the relative value of Phosphorous (K) in the mycorrhizal network. 
	
	** Adjust the purple level at the bottom.",
	6: "Stage 6: 
	Make sure your maize crop has all the nutrients it needs. 
	Try to grow as much  maize as you can!
	
	**Use your inventory as needed.",
	7: "Stage 7: 
	Now that the birds have migrated you should return the value of Phosphorous (K) back to normal, so that the other plants have a chance to grow.",
	8: "Stage 8: 
		
		Well done!
		
		You have grown a Mycorrhizal Fungi network and a nice garden!
		Head back to the main menu and try challenge mode to reach the rank of 
		Grassroots Economist!"

}


var social_stage_text = {
	1: "Stage 1: Each person is rich in their own resources:
	Farmers -> Labor (Green), Mama Mboga -> Vegetables (Orange)
	Mpishi -> Cooking (Pink), Bank -> Money (Blue)
	
	The baskets here represent agreements that connect certain resources together. 
	For now, all we have are colored baskets (bank agreements) that connect to money.
	But what happens if the money from the city or bank stop comming?
	
	** Click and drag a new basket from your inventory so that the people have a 
	way to trade with eachother directly without using the money.",
	2: "Stage 2: The people using the baskets are now able to fairly exchange and distribute resources 
	and more people are becomming farmers, cooks and selling vegetables to eachoter!
	
	** Click and drag another basket from your inventory below, into the economy to help the new service providers.",
	3: "Stage 3: Now you have two new baskets!! 
	
	When baskets are connected together they can also help each other and store commitemnts for resources for hard times. 
	
	** Click and drag a 3rd basket from your inventory below and ensure all 3 baskets are connected to eachother and each is connected to a cook, farmer and mama mboga.",
	4: "Stage 4: You are doing great!
	
	With all these baskets connected your economy should be able to deal with some losses.
	
	** After the cooks have migrated to the city on tuktuks, train 3 more cooks from your inventory.",
	5: "Stage 5: Train cooks faster by increasing the relative value of Cooking in the economy. 
	
	** Increase the Cooking level in purple at the bottom.",
	6: "Stage 6: 
	Make sure your cooks have all the resources they need (Farming Labor and Vegetables). 
	Try to train as many cooks as you can!
	
	**Use your inventory as needed.",
	7: "Stage 7: 
	Now that the tuktuks have left you should return the value of Cooking (purple) back to normal, 
	so that the other services are equally valued again. ",
	8: "Stage 8: 
		
		Well done!
		
		You have grown a small local economy!
		Head back to the main menu and try challenge mode to reach the rank of Grassroots Economist!"

}



var stage_colors = {
	1: Color(Color.DARK_GREEN,0.8),
	2: Color(Color.DARK_ORCHID,0.8),
	3: Color(Color.DARK_RED,0.8),
	4: Color(Color.DARK_BLUE,0.8),
	5: Color(Color.DARK_MAGENTA,0.8),
	6: Color(Color.DARK_GOLDENROD,0.8),
	7: Color(Color.DARK_ORANGE,0.8),
	8: Color(Color.DARK_SEA_GREEN,0.8),
	}


func _ready() -> void:
	load_high_score()
	var seeded = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			var seed_text = arg.trim_prefix("--seed=")
			var seed_val = int(seed_text)
			seed(seed_val)
			seeded = true
			break
	if not seeded:
		randomize()
	is_mobile_platform = OS.has_feature("mobile") or OS.get_name() == "Android" or OS.get_name() == "iOS"
	if is_mobile_platform:
		# Tile-ring village reach stays at 2 rings on mobile too.
		social_buddy_radius = 128
	reset_trade_dispatch_budgets()


func load_high_score() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(HIGH_SCORE_SAVE_PATH)
	if err == OK:
		high_score = max(0, int(cfg.get_value("scores", "high_score", 0)))
		last_score = max(0, int(cfg.get_value("scores", "last_score", 0)))
		last_rank_key = int(cfg.get_value("scores", "last_rank_key", get_rank_threshold(last_score)))
	else:
		high_score = 0
		last_score = 0
		last_rank_key = 0


func save_high_score() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "high_score", max(0, high_score))
	cfg.set_value("scores", "last_score", max(0, last_score))
	cfg.set_value("scores", "last_rank_key", last_rank_key)
	cfg.save(HIGH_SCORE_SAVE_PATH)


func update_high_score(score_value: int = -1) -> bool:
	if str(mode) == "story":
		return false
	var checked_score := score if score_value < 0 else score_value
	if checked_score <= high_score:
		return false
	high_score = checked_score
	save_high_score()
	return true


func record_last_score(score_value: int = -1) -> bool:
	if str(mode) == "story":
		return false
	var checked_score := score if score_value < 0 else score_value
	if checked_score <= 0:
		return false
	last_score = checked_score
	last_rank_key = get_rank_threshold(checked_score)
	var new_high_score = checked_score > high_score
	if new_high_score:
		high_score = checked_score
	save_high_score()
	return new_high_score


func add_score(amount: int) -> int:
	if str(mode) == "story":
		return score
	score += amount
	update_high_score(score)
	return score


func format_score_value(score_value: int) -> String:
	var raw := str(score_value)
	var formatted := ""
	var digit_count := 0
	for index in range(raw.length() - 1, -1, -1):
		formatted = raw.substr(index, 1) + formatted
		digit_count += 1
		if digit_count % 3 == 0 and index > 0:
			formatted = "," + formatted
	return formatted


func set_world_context(rect: Rect2, mode_id: String = "", scenario_id: String = "") -> void:
	world_rect = rect
	world_bounds_enabled = true
	active_mode_id = mode_id
	active_scenario_id = scenario_id


func clear_world_context() -> void:
	world_bounds_enabled = false
	world_rect = Rect2(Vector2.ZERO, Vector2.ZERO)
	active_mode_id = ""
	active_scenario_id = ""


func get_world_rect(node: Node = null) -> Rect2:
	if world_bounds_enabled:
		return world_rect
	if is_instance_valid(node):
		return node.get_viewport().get_visible_rect()
	return Rect2(Vector2.ZERO, Vector2(720, 1280))


func get_world_center(node: Node = null) -> Vector2:
	var rect = get_world_rect(node)
	return rect.position + rect.size * 0.5


func screen_to_world(node: Node, screen_pos: Vector2) -> Vector2:
	if not is_instance_valid(node):
		return screen_pos
	var camera = node.get_viewport().get_camera_2d()
	if is_instance_valid(camera):
		var view_size = node.get_viewport().get_visible_rect().size
		return camera.get_screen_center_position() - view_size * 0.5 + screen_pos
	return screen_pos


func world_to_screen(node: Node, world_pos: Vector2) -> Vector2:
	if not is_instance_valid(node):
		return world_pos
	var camera = node.get_viewport().get_camera_2d()
	if is_instance_valid(camera):
		var view_size = node.get_viewport().get_visible_rect().size
		return world_pos - (camera.get_screen_center_position() - view_size * 0.5)
	return world_pos


func get_rank_threshold(score_value: int) -> int:
	var keys: Array = ranks.keys()
	keys.sort()
	var current: int = int(keys[0])
	for key in keys:
		var threshold := int(key)
		if score_value >= threshold:
			current = threshold
	return current


func is_story_mode_runtime() -> bool:
	return str(mode) == "story"


func is_challenge_dual_village_mode() -> bool:
	return str(mode) == "challenge" and bool(challenge_dual_village_enabled)


func is_parallel_village_runtime() -> bool:
	return is_story_mode_runtime() or is_challenge_dual_village_mode()


func get_predator_spawn_count(score_level: int) -> int:
	var spawn_count = int(birds.get(score_level, 0))
	if is_mobile_platform:
		spawn_count = min(spawn_count, max_predators_per_wave_mobile)
	return max(spawn_count, 0)


func get_effective_perf_tier() -> int:
	if perf_quality_override >= 0:
		return clampi(perf_quality_override, 0, 2)
	return clampi(perf_tier, 0, 2)


func set_perf_tier(new_tier: int) -> void:
	perf_tier = clampi(new_tier, 0, 2)


func get_line_visual_refresh_interval() -> float:
	match get_effective_perf_tier():
		1:
			return 0.25
		2:
			return 0.40
		_:
			return 0.10


func get_dirty_refresh_interval() -> float:
	match get_effective_perf_tier():
		1:
			return 0.12
		2:
			return 0.18
		_:
			return 0.10


func get_bar_update_interval() -> float:
	match get_effective_perf_tier():
		1:
			return 0.10
		2:
			return 0.20
		_:
			return 0.033


func get_minimap_idle_redraw_interval() -> float:
	if not minimap_adaptive_redraw_enabled:
		return 0.016
	match get_effective_perf_tier():
		1:
			return 0.125
		2:
			return 0.20
		_:
			return 0.083333


func get_minimap_interaction_redraw_interval() -> float:
	if not minimap_adaptive_redraw_enabled:
		return 0.016
	return 0.033333


func get_ui_layout_refresh_interval() -> float:
	if not ui_layout_cadence_enabled:
		return 0.0
	match get_effective_perf_tier():
		1:
			return 0.10
		2:
			return 0.14
		_:
			return 0.066667


func get_village_action_time() -> float:
	return maxf(village_action_time, 0.01)


func get_agent_action_time(agent: Variant) -> float:
	var default_action_time = maxf(action_time, 0.01)
	if not is_instance_valid(agent):
		return default_action_time
	var agent_type = str(agent.get("type"))
	if agent_type == "farmer" or agent_type == "vendor" or agent_type == "cook" or agent_type == "bank":
		return get_village_action_time()
	return default_action_time


func get_trade_visual_link_packet_cap() -> int:
	match get_effective_perf_tier():
		1:
			return maxi(trade_visual_per_link_cap_t1, 1)
		2:
			return maxi(trade_visual_per_link_cap_t2, 1)
		_:
			return maxi(trade_visual_per_link_cap_t0, 1)


func reset_trade_dispatch_budgets() -> void:
	_trade_sender_buckets.clear()
	_trade_link_buckets.clear()


func _trade_sender_key(agent: Variant) -> String:
	if not is_instance_valid(agent):
		return ""
	return str(int(agent.get_instance_id()))


func _trade_link_key(from_agent: Variant, to_agent: Variant) -> String:
	if not is_instance_valid(from_agent) or not is_instance_valid(to_agent):
		return ""
	return str(int(from_agent.get_instance_id()), "->", int(to_agent.get_instance_id()))


func _refill_trade_bucket(store: Dictionary, key: String, rate_per_sec: float, burst: float, now_ms: int) -> Dictionary:
	var tokens = maxf(burst, 0.0)
	var last_ms = now_ms
	if store.has(key):
		var existing_variant = store.get(key, {})
		if typeof(existing_variant) == TYPE_DICTIONARY:
			var existing: Dictionary = existing_variant
			tokens = float(existing.get("tokens", tokens))
			last_ms = int(existing.get("last_ms", now_ms))
	var elapsed_ms = maxi(now_ms - last_ms, 0)
	var elapsed_sec = float(elapsed_ms) / 1000.0
	tokens = minf(maxf(tokens + elapsed_sec * maxf(rate_per_sec, 0.0), 0.0), maxf(burst, 0.0))
	var updated := {
		"tokens": tokens,
		"last_ms": now_ms
	}
	store[key] = updated
	return updated


func _consume_trade_bucket(store: Dictionary, key: String, rate_per_sec: float, burst: float, now_ms: int, cost: float = 1.0) -> bool:
	var safe_cost = maxf(cost, 0.0)
	if safe_cost <= 0.0:
		return true
	var updated = _refill_trade_bucket(store, key, rate_per_sec, burst, now_ms)
	var tokens = float(updated.get("tokens", 0.0))
	if tokens + 0.0001 < safe_cost:
		return false
	updated["tokens"] = maxf(tokens - safe_cost, 0.0)
	store[key] = updated
	return true


func _is_village_dispatch_actor(agent: Variant) -> bool:
	if not is_instance_valid(agent):
		return false
	var agent_type = str(agent.get("type"))
	if agent_type == "farmer" or agent_type == "vendor" or agent_type == "cook" or agent_type == "bank":
		return true
	if agent_type == "myco":
		if bool(agent.get_meta("story_village_actor", false)):
			var story_kind = str(agent.get_meta("story_kind", ""))
			if story_kind.begins_with("basket"):
				return true
		var script_ref = agent.get_script()
		if script_ref != null:
			var script_path = str(script_ref.resource_path)
			if script_path.ends_with("basket.gd"):
				return true
	return false


func _get_trade_dispatch_profile(from_agent: Variant) -> Dictionary:
	var sender_rate = trade_sender_rate_per_sec
	var sender_burst = trade_sender_burst
	var link_rate = trade_link_rate_per_sec
	var link_burst = trade_link_burst
	if is_instance_valid(from_agent):
		var agent_type = str(from_agent.get("type"))
		var is_native_myco = agent_type == "myco" and from_agent.has_node("MycoSprite")
		if is_native_myco:
			sender_rate = trade_sender_rate_per_sec_myco
			sender_burst = trade_sender_burst_myco
			link_rate = trade_link_rate_per_sec_myco
			link_burst = trade_link_burst_myco
		elif _is_village_dispatch_actor(from_agent):
			sender_rate = trade_sender_rate_per_sec_village
			sender_burst = trade_sender_burst_village
			link_rate = trade_link_rate_per_sec_village
			link_burst = trade_link_burst_village
	return {
		"sender_rate": sender_rate,
		"sender_burst": sender_burst,
		"link_rate": link_rate,
		"link_burst": link_burst
	}


func allow_trade_dispatch(from_agent: Variant, to_agent: Variant) -> bool:
	if not trade_dispatch_limit_enabled:
		return true
	var sender_key = _trade_sender_key(from_agent)
	if sender_key == "":
		return true
	var profile = _get_trade_dispatch_profile(from_agent)
	var sender_rate = float(profile.get("sender_rate", trade_sender_rate_per_sec))
	var sender_burst = float(profile.get("sender_burst", trade_sender_burst))
	var link_rate = float(profile.get("link_rate", trade_link_rate_per_sec))
	var link_burst = float(profile.get("link_burst", trade_link_burst))
	var now_ms = Time.get_ticks_msec()
	if not _consume_trade_bucket(_trade_sender_buckets, sender_key, sender_rate, sender_burst, now_ms):
		return false
	var link_key = _trade_link_key(from_agent, to_agent)
	if link_key == "":
		return true
	if _consume_trade_bucket(_trade_link_buckets, link_key, link_rate, link_burst, now_ms):
		return true
	var sender_state_variant = _trade_sender_buckets.get(sender_key, {})
	if typeof(sender_state_variant) == TYPE_DICTIONARY:
		var sender_state: Dictionary = sender_state_variant
		var sender_tokens = float(sender_state.get("tokens", 0.0))
		sender_state["tokens"] = minf(sender_tokens + 1.0, maxf(sender_burst, 0.0))
		_trade_sender_buckets[sender_key] = sender_state
	return false


func perf_count_tile_occupancy_query() -> void:
	perf_tile_occupancy_queries += 1


func perf_consume_tile_occupancy_queries() -> int:
	var consumed = perf_tile_occupancy_queries
	perf_tile_occupancy_queries = 0
	return consumed


func perf_set_soil_tiles_touched(count: int) -> void:
	perf_soil_tiles_touched_last_tick = maxi(count, 0)


func perf_consume_soil_tiles_touched() -> int:
	var consumed = perf_soil_tiles_touched_last_tick
	perf_soil_tiles_touched_last_tick = 0
	return consumed


func perf_set_soil_tick_ms(ms: float) -> void:
	perf_soil_tick_ms_last = maxf(ms, 0.0)


func perf_consume_soil_tick_ms() -> float:
	var consumed = perf_soil_tick_ms_last
	perf_soil_tick_ms_last = 0.0
	return consumed


func perf_set_last_sample(sample: Dictionary) -> void:
	perf_last_sample = sample.duplicate(true)


func perf_set_run_metadata(metadata: Dictionary) -> void:
	perf_run_metadata = metadata.duplicate(true)
