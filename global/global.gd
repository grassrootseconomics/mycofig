extends Node

var score := 0

var move_rate = 4 #6
var movement_speed = 100 #200
var social_buddy_radius = 200
var num_connectors = 4
var active_agent = null
var is_mobile_platform = false

var is_dragging = false
var bars_on = false
var stage_inc = 0
var max_stage_inc = 5
var baby_mode = true
var allow_agent_reposition = false
var draw_lines = false

var social_mode = false
var world_bounds_enabled = false
var world_rect = Rect2(Vector2.ZERO, Vector2.ZERO)
var active_mode_id = ""
var active_scenario_id = ""
var story_chapter_id := 1
var village_revealed := false
var village_objective_flags := {}
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



var sparkle_scene: PackedScene = load("res://scenes/sparkle.tscn")

var growth_time = 0.4
var decay_time = 1110.6
var action_time = 0.3
var evap_time = 1
var mode = "challenge"
var stage = 1
var is_raining = true
var is_birding = true
var is_killing = true
var is_max_babies = true

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
	1: "Phase 1: Plant one of each of your crops.
	Each one provides different nutrients. Mushrooms transport nutrients and help create healthy soil. 
	Tap on your crops to check what nutrients they need.",
	2: "Phase 2: Harvest each type of crop in your inventory by double clicking. Birds are hungry, so grow more crops.",
	3: "Phase 3: Expand your garden toward the ? on the map.",
	4: "Phase 4: You found a village! Looks like they need food. Deliver at some food to your fellow farmers so villagers can become healthy.",
	5: "Phase 5: Place a basket from your inventory and help all villagers exchange even if they don't have money.",
	6: "Phase 6: Complete! You restored soil health, revived the ecosystem, and helped the village recover. Well done!"
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
	1000: "Mycelium Weaver",
	2000: "Mycorrhizal Guardian",
	5000: "Myceliator",
	10000: "Shroom Architect",
	50000: "Nutrient Flow Oracle",
	100000: "Fungal Network Shepherd",
	500000: "Mycorrhizal Visionary",
	1000000: "Soil Web Custodian Moja",
	2000000: "Soil Web Custodian Mbili",
	3000000: "Soil Web Custodian Tatu",
	4000000: "Soil Web Custodian Nne",
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
		# Smaller radius reduces partner scans and line churn on phones.
		social_buddy_radius = 170


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
