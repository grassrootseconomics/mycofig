extends Agent

const ResourceEconomyRef = preload("res://scenes/resource_economy.gd")
const TEX_MYCO_RHIZO_STAGE_PATH := "res://graphics/rhizomorphic.png"

enum MycoGrowthStage {
	SPORE,
	RHIZO_GROW,
	POD_READY,
	DEAD
}

const MYCO_DEAD_RECOVERY_TICKS := 42
const MYCO_POD_BABY_TICK_INTERVAL := 4
const MYCO_STAGE_CONSUMPTIONS_PER_ADVANCE := 3
const MYCO_STAGE_ADVANCE_WAIT_TICKS := 1
const MYCO_POD_BABY_MIN := 0
const MYCO_POD_BABY_MAX := 0
const MYCO_HARVEST_YIELD := 3
const MYCO_HARVEST_BIRTH_MAX := 0
const MYCO_PARENT_BOUND_TILES := 4
const MYCO_HARVEST_BIRTH_ATTEMPTS := 32
const MYCO_INITIAL_RADIUS_TILES := 1.5
const MYCO_MATURE_RADIUS_TILES := 3.0
const MYCO_RHIZO_ALPHA_LIVE := 0.32
const MYCO_STARVATION_REVERT_TICKS := 48
const MYCO_STARVATION_SHRINK_LERP := 0.06
const MYCO_DEAD_MUSHROOM_SHRINK_LERP := 0.08
const MYCO_DEAD_RHIZO_SHRINK_LERP := 0.07
const MYCO_DEAD_MUSHROOM_ALPHA_STEP := 0.03
const MYCO_MIN_ADJACENT_BUDDY_RADIUS := 72.0
const MYCO_MAX_SENDS_PER_LOGISTICS_TICK := 2
const MYCO_RHIZO_SPORE_CELL_RATIO := 0.42
const MYCO_RHIZO_GROW_CELL_RATIO := 0.78
const MYCO_DEAD_RHIZO_BODY_CELL_RATIO := 0.16
const MYCO_SUPPORTED_STARVATION_MULTIPLIER := 4

var myco_stage: int = MycoGrowthStage.SPORE
var myco_stage_consumptions := 0
var myco_stage_wait_ticks := 0
var myco_pod_ticks := 0
var myco_dead_ticks := 0
var myco_starvation_ticks := 0
var myco_harvest_ready := false
var myco_pod_sparkle_played := false
var trade_queue: Array = []

var mushroom_base_texture: Texture2D = null
var mushroom_base_scale := Vector2.ONE
var rhizo_native_scale := Vector2.ONE
var rhizo_spore_scale := Vector2.ONE
var myco_rhizo_texture: Texture2D = null
var myco_tile_span := 64.0


func _challenge_myco_death_enabled() -> bool:
	return str(Global.mode) == "challenge" and bool(Global.is_killing)


func _has_complete_nutrient_set() -> bool:
	for res in assets:
		if assets[res] <= 0:
			return false
	return true


func _is_dead_resource_bar_visual() -> bool:
	return myco_stage == MycoGrowthStage.DEAD or super._is_dead_resource_bar_visual()


func _load_myco_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var loaded = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if not (loaded is Texture2D):
		loaded = ResourceLoader.load(path)
	if loaded is Texture2D:
		return loaded
	return null


func _get_mushroom_texture_scale_adjust(texture: Texture2D) -> Vector2:
	if not is_instance_valid(texture):
		return Vector2.ONE
	if not is_instance_valid(mushroom_base_texture):
		return Vector2.ONE
	var base_size: Vector2 = mushroom_base_texture.get_size()
	var stage_size: Vector2 = texture.get_size()
	if base_size.x <= 0.0 or base_size.y <= 0.0:
		return Vector2.ONE
	if stage_size.x <= 0.0 or stage_size.y <= 0.0:
		return Vector2.ONE
	return Vector2(base_size.x / stage_size.x, base_size.y / stage_size.y)


func _get_texture_fit_scale(texture: Texture2D, max_size_px: float) -> Vector2:
	if not is_instance_valid(texture):
		return Vector2.ONE
	var texture_size = texture.get_size()
	var max_axis = maxf(texture_size.x, texture_size.y)
	if max_axis <= 0.001:
		return Vector2.ONE
	var safe_size = clampf(max_size_px, 1.0, myco_tile_span)
	var scale = safe_size / max_axis
	return Vector2(scale, scale)


func _get_rhizo_body_scale(cell_ratio: float, keep_smaller_than_mushroom: bool = false) -> Vector2:
	var target_size = myco_tile_span * cell_ratio
	if keep_smaller_than_mushroom and is_instance_valid(mushroom_base_texture):
		var mushroom_size = mushroom_base_texture.get_size()
		var displayed_mushroom = Vector2(
			mushroom_size.x * absf(mushroom_base_scale.x),
			mushroom_size.y * absf(mushroom_base_scale.y)
		)
		var max_mushroom_axis = maxf(displayed_mushroom.x, displayed_mushroom.y)
		if max_mushroom_axis > 0.001:
			target_size = minf(target_size, max_mushroom_axis * 0.9)
	target_size = maxf(target_size, myco_tile_span * 0.32)
	return _get_texture_fit_scale(myco_rhizo_texture, target_size)


func _refresh_buddy_radius_from_rhizo() -> void:
	if not is_instance_valid(sprite_myco):
		return
	var rect = sprite_myco.get_rect()
	var scale_x = absf(sprite_myco.scale.x)
	var min_reach = MYCO_MIN_ADJACENT_BUDDY_RADIUS
	var world = get_node_or_null("../../WorldFoundation")
	var tile_span := 64.0
	if is_instance_valid(world):
		var raw_tile_span = world.get("tile_size")
		if typeof(raw_tile_span) == TYPE_INT or typeof(raw_tile_span) == TYPE_FLOAT:
			tile_span = raw_tile_span * 1.0
		if tile_span > 0.0:
			min_reach = max(min_reach, tile_span * 1.05)
	if myco_stage == MycoGrowthStage.POD_READY:
		min_reach = max(min_reach, tile_span * MYCO_MATURE_RADIUS_TILES)
	else:
		min_reach = max(min_reach, tile_span * MYCO_INITIAL_RADIUS_TILES)
	buddy_radius = max(min_reach, (rect.size.x * 0.5) * scale_x)


func _mark_network_dirty() -> void:
	_queue_dirty_update(true, true, false)
	var agents_root = get_node_or_null("../../Agents")
	var level_root = _get_level_root()
	if not is_instance_valid(agents_root):
		return
	if is_instance_valid(level_root):
		LevelHelpersRef.mark_agents_dirty_for_movement(level_root, agents_root, self, global_position, global_position)
	else:
		LevelHelpersRef.mark_all_buddies_dirty(agents_root)


func _set_rhizo_scale(new_scale: Vector2) -> void:
	if not is_instance_valid(sprite_myco):
		return
	if sprite_myco.scale.distance_to(new_scale) < 0.001:
		return
	sprite_myco.scale = new_scale
	_refresh_buddy_radius_from_rhizo()
	_mark_network_dirty()


func _has_supporting_neighbors() -> bool:
	var agents_root = get_node_or_null("../../Agents")
	if not is_instance_valid(agents_root):
		return false
	var level_root = _get_level_root()
	for child in agents_root.get_children():
		if not is_instance_valid(child):
			continue
		if child == self:
			continue
		if bool(child.get("dead")):
			continue
		var child_type = str(child.get("type"))
		if child_type == "cloud":
			continue
		if not _can_share_story_trade_network(child):
			continue
		if LevelHelpersRef.are_agents_in_tile_reach(level_root, self, child, false):
			return true
		if not LevelHelpersRef._supports_tile_world(level_root) and global_position.distance_to(child.global_position) <= buddy_radius:
			return true
	return false


func _set_myco_stage(new_stage: int, force: bool = false) -> void:
	if not force and myco_stage == new_stage:
		return
	myco_stage = new_stage
	dead = false
	myco_harvest_ready = myco_stage == MycoGrowthStage.POD_READY
	draggable = myco_stage != MycoGrowthStage.DEAD
	if myco_stage == MycoGrowthStage.DEAD:
		_hide_resource_bars()
		_clear_active_selection_if_self()

	if is_instance_valid(sprite_myco):
		sprite_myco.modulate = Color(1.0, 1.0, 1.0, MYCO_RHIZO_ALPHA_LIVE)
		match myco_stage:
			MycoGrowthStage.SPORE:
				_set_rhizo_scale(rhizo_spore_scale)
			MycoGrowthStage.RHIZO_GROW:
				_set_rhizo_scale(rhizo_spore_scale)
			MycoGrowthStage.POD_READY:
				_set_rhizo_scale(rhizo_native_scale)
			MycoGrowthStage.DEAD:
				_set_rhizo_scale(rhizo_native_scale * 0.92)
				sprite_myco.modulate = Color(0.78, 0.66, 0.52, MYCO_RHIZO_ALPHA_LIVE)

	if is_instance_valid(sprite):
		sprite.visible = true
		match myco_stage:
			MycoGrowthStage.SPORE:
				if is_instance_valid(myco_rhizo_texture):
					sprite.texture = myco_rhizo_texture
					sprite.scale = _get_rhizo_body_scale(MYCO_RHIZO_SPORE_CELL_RATIO, true)
				sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
			MycoGrowthStage.RHIZO_GROW:
				if is_instance_valid(myco_rhizo_texture):
					sprite.texture = myco_rhizo_texture
					sprite.scale = _get_rhizo_body_scale(MYCO_RHIZO_GROW_CELL_RATIO)
				sprite.modulate = Color(1.0, 1.0, 1.0, 0.82)
			MycoGrowthStage.POD_READY:
				sprite.texture = mushroom_base_texture
				sprite.scale = mushroom_base_scale
				sprite.modulate = Color.WHITE
			MycoGrowthStage.DEAD:
				if is_instance_valid(myco_rhizo_texture):
					sprite.texture = myco_rhizo_texture
					sprite.scale = _get_rhizo_body_scale(MYCO_RHIZO_SPORE_CELL_RATIO, true)
				else:
					sprite.texture = mushroom_base_texture
					sprite.scale = mushroom_base_scale * 0.42
				sprite.modulate = Color(0.84, 0.73, 0.58, 0.82)

	if myco_stage == MycoGrowthStage.POD_READY and not myco_pod_sparkle_played:
		var sparkle = Global.sparkle_scene.instantiate()
		sparkle.z_as_relative = false
		sparkle.position = self.position
		sparkle.global_position = self.global_position
		$"../../Sparkles".add_child(sparkle)
		sparkle.start(0.75)
		Global.add_score(200)
		myco_pod_sparkle_played = true


func _revert_to_spore() -> void:
	myco_stage_consumptions = 0
	myco_stage_wait_ticks = 0
	myco_pod_ticks = 0
	myco_dead_ticks = 0
	myco_starvation_ticks = 0
	myco_harvest_ready = false
	myco_pod_sparkle_played = false
	_set_myco_stage(MycoGrowthStage.SPORE, true)


func _supports_tile_world(world: Node) -> bool:
	if not is_instance_valid(world):
		return false
	return world.has_method("world_to_tile") and world.has_method("tile_to_world_center") and world.has_method("in_bounds")


func _sample_parent_bounded_birth_position(max_parent_tiles: int = MYCO_PARENT_BOUND_TILES) -> Vector2:
	var world = get_node_or_null("../../WorldFoundation")
	if not _supports_tile_world(world):
		return global_position
	var safe_tiles = maxi(max_parent_tiles, 1)
	var parent_coord = Vector2i(world.world_to_tile(global_position))
	for _attempt in range(MYCO_HARVEST_BIRTH_ATTEMPTS):
		var dx = random.randi_range(-safe_tiles, safe_tiles)
		var dy = random.randi_range(-safe_tiles, safe_tiles)
		if maxi(abs(dx), abs(dy)) > safe_tiles:
			continue
		if dx == 0 and dy == 0:
			continue
		var coord = parent_coord + Vector2i(dx, dy)
		if not world.in_bounds(coord):
			continue
		return world.tile_to_world_center(coord)
	return world.tile_to_world_center(parent_coord)


func _emit_harvest_spore_births() -> void:
	var birth_count = random.randi_range(MYCO_POD_BABY_MIN, MYCO_HARVEST_BIRTH_MAX)
	_emit_parent_bounded_spore_births(birth_count, "harvest_birth")


func _emit_parent_bounded_spore_births(birth_count: int, spawn_reason: String) -> void:
	var safe_births = maxi(birth_count, 0)
	for _i in range(safe_births):
		var new_agent_dict = {
			"name": "myco",
			"pos": _sample_parent_bounded_birth_position(MYCO_PARENT_BOUND_TILES),
			"parent_anchor": self,
			"max_parent_tiles": MYCO_PARENT_BOUND_TILES,
			"spawn_reason": spawn_reason
		}
		emit_signal("new_agent", new_agent_dict)


func supports_inventory_harvest() -> bool:
	return not Global.social_mode and str(type) == "myco"


func can_drag_for_inventory_harvest() -> bool:
	return supports_inventory_harvest() and myco_harvest_ready and myco_stage == MycoGrowthStage.POD_READY


func _get_harvest_drag_display_scale() -> Vector2:
	if mushroom_base_scale != Vector2.ZERO:
		return mushroom_base_scale
	if is_instance_valid(sprite):
		return sprite.scale
	return Vector2.ONE


func _begin_harvest_visual_detach() -> void:
	if not supports_inventory_harvest():
		return
	if _harvest_visual_detached:
		return
	if not myco_harvest_ready or myco_stage != MycoGrowthStage.POD_READY:
		return
	_harvest_visual_detached = true
	if is_instance_valid(sprite):
		if is_instance_valid(myco_rhizo_texture):
			sprite.texture = myco_rhizo_texture
			sprite.scale = _get_rhizo_body_scale(MYCO_RHIZO_GROW_CELL_RATIO)
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.82)


func _cancel_harvest_visual_detach() -> void:
	if not _harvest_visual_detached:
		return
	_harvest_visual_detached = false
	if not myco_harvest_ready or myco_stage != MycoGrowthStage.POD_READY:
		return
	if is_instance_valid(sprite):
		sprite.texture = mushroom_base_texture
		sprite.scale = mushroom_base_scale
		sprite.modulate = Color.WHITE


func _commit_harvest_visual_detach() -> void:
	_harvest_visual_detached = false


func try_harvest_to_inventory() -> bool:
	if not supports_inventory_harvest():
		return false
	if not myco_harvest_ready or myco_stage != MycoGrowthStage.POD_READY:
		return false
	Global.inventory["myco"] = int(Global.inventory.get("myco", 0)) + MYCO_HARVEST_YIELD
	var ui_node = get_node_or_null("../../UI")
	if is_instance_valid(ui_node) and ui_node.has_method("refresh_inventory_counts"):
		ui_node.refresh_inventory_counts()
	if is_dragging:
		is_dragging = false
		Global.is_dragging = false
	_clear_drag_tile_hint()
	_begin_snap_to_nearest_tile(position)
	myco_harvest_ready = false
	myco_pod_ticks = 0
	myco_stage_consumptions = 0
	myco_stage_wait_ticks = 0
	# Harvesting removes only the mushroom; the myco body remains and regrows.
	_set_myco_stage(MycoGrowthStage.RHIZO_GROW, true)
	_commit_harvest_visual_detach()
	emit_signal("harvest_committed", "myco", "inventory")
	_emit_harvest_spore_births()
	return true


func try_harvest_to_farmer(_target_farmer: Node = null) -> bool:
	if not supports_inventory_harvest():
		return false
	if not myco_harvest_ready or myco_stage != MycoGrowthStage.POD_READY:
		return false
	if is_dragging:
		is_dragging = false
		Global.is_dragging = false
	_clear_drag_tile_hint()
	_begin_snap_to_nearest_tile(position)
	myco_harvest_ready = false
	myco_pod_ticks = 0
	myco_stage_consumptions = 0
	myco_stage_wait_ticks = 0
	# Harvesting removes only the mushroom; the myco body remains and regrows.
	_set_myco_stage(MycoGrowthStage.RHIZO_GROW, true)
	_commit_harvest_visual_detach()
	emit_signal("harvest_committed", "myco", "farmer")
	_emit_harvest_spore_births()
	return true


func set_variables(a_dict) -> void:

	var START_N = 5 #Nitrogen
	var START_P = 5 # Potassium
	var START_K = 5 #Phosphorus
	var START_R = 5 #Rain
	
	assets = {
		"N": START_N,
		"P": START_P,				
		"K": START_K,
		"R": START_R
	}

	name = a_dict.get("name")
	type = a_dict.get("type")
	position = a_dict.get("position")
	last_position = position
	sprite_texture = a_dict.get("texture")
	sprite = $Sprite2D
	sprite_myco = $MycoSprite

	mushroom_base_texture = sprite_texture
	myco_rhizo_texture = _load_myco_texture(TEX_MYCO_RHIZO_STAGE_PATH)
	$Sprite2D.texture = mushroom_base_texture

	sprite.z_index = 9
	$MycoSprite.z_index = -1
	var world = get_node_or_null("../../WorldFoundation")
	var tile_span := 64.0
	if is_instance_valid(world):
		var world_tile_size := 64.0
		var raw_tile_size = world.get("tile_size")
		if typeof(raw_tile_size) == TYPE_INT or typeof(raw_tile_size) == TYPE_FLOAT:
			world_tile_size = raw_tile_size * 1.0
		if world_tile_size > 0.0:
			tile_span = world_tile_size
	myco_tile_span = tile_span
	var base_scale = sprite_myco.scale
	var base_rect = sprite_myco.get_rect()
	var base_radius = (base_rect.size.x * 0.5) * absf(base_scale.x)
	if base_radius <= 0.001:
		base_radius = 100.0
	var target_initial_radius = tile_span * MYCO_INITIAL_RADIUS_TILES
	var target_mature_radius = tile_span * MYCO_MATURE_RADIUS_TILES
	var initial_scale_factor = target_initial_radius / base_radius
	var mature_scale_factor = target_mature_radius / base_radius
	if mature_scale_factor < initial_scale_factor:
		mature_scale_factor = initial_scale_factor
	rhizo_spore_scale = base_scale * initial_scale_factor
	rhizo_native_scale = base_scale * mature_scale_factor
	mushroom_base_scale = sprite.scale
	$MycoSprite.modulate.a = MYCO_RHIZO_ALPHA_LIVE
	_refresh_buddy_radius_from_rhizo()

	myco_stage = MycoGrowthStage.SPORE
	myco_stage_consumptions = 0
	myco_stage_wait_ticks = 0
	myco_pod_ticks = 0
	myco_dead_ticks = 0
	myco_starvation_ticks = 0
	myco_harvest_ready = false
	myco_pod_sparkle_played = false
	_set_myco_stage(MycoGrowthStage.SPORE, true)

	$GrowthTimer.wait_time = Global.growth_time
	$ActionTimer.wait_time = Global.action_time
	setup_resource_bars(["N", "P", "K", "R"])
	

# Search for things to trade with in tile reach
func generate_buddies() -> void:
	var agents_root = get_node_or_null("../../Agents")
	trade_buddies = LevelHelpersRef.query_trade_hubs_near_agent(_get_level_root(), agents_root, self, num_buddies, false)


func logistics():
	var new_trade_queue: Array = []
	for trade in trade_queue:
		if typeof(trade) != TYPE_DICTIONARY:
			continue
		var trade_asset = str(trade.get("trade_asset", ""))
		var trade_amount = int(trade.get("trade_amount", 0))
		if trade_asset == "" or trade_amount <= 0:
			continue
		if assets.get(trade_asset) == null or int(assets[trade_asset]) < trade_amount:
			new_trade_queue.append(trade)
			continue
		if _emit_trade_with_budget(trade):
			assets[trade_asset] -= trade_amount
			bars[trade_asset].value = assets[trade_asset]
		else:
			new_trade_queue.append(trade)
	trade_queue = new_trade_queue

	var excess_res = null
	var high_amt_excess = 0
	var needed_res = null
	var high_amt_needed = 0
	
	var debug_mode = false
	
	var buddies_len = len(trade_buddies)
	
	if logistics_ready and buddies_len > 0:
		if( is_instance_valid(Global.active_agent)):
			if self.name == Global.active_agent.name:
				debug_mode = false
		
		if debug_mode:
			print("New Round in: ", name ,", ", assets, " needs: ", needs, "buddies: ", trade_buddies)	
			
		var balance: Dictionary = ResourceEconomyRef.analyze_balances(assets, needs, 0.0)
		current_excess = balance["current_excess"]
		current_needs = balance["current_needs"]
		excess_res = balance["excess_res"]
		needed_res = balance["needed_res"]
		high_amt_excess = balance["high_amt_excess"]
		high_amt_needed = balance["high_amt_needed"]
		var keys_c: Array = balance["needed_keys"]
		var keys_e: Array = balance["excess_keys"]
		if debug_mode:
			print("excess: ", current_excess,  keys_e, " current_needs: ", current_needs, keys_c)
		
		if excess_res != null and needed_res != null:
			trade_buddies.shuffle()
			
			if debug_mode:
				print(" shuffle" )
			var sent_count := 0
			for child in trade_buddies:
				if sent_count >= MYCO_MAX_SENDS_PER_LOGISTICS_TICK:
					break
				if(is_instance_valid(child)):
					if child.type == 'myco' and child.name != self.name:
						if debug_mode:
							print(" child found: ", child.name )
						for excess in keys_e:
							if sent_count >= MYCO_MAX_SENDS_PER_LOGISTICS_TICK:
								break
							if current_excess[excess] > 0 and assets[excess] > needs[excess] and child.assets[excess] < child.needs[excess]:
								var path_dict = {
									"from_agent": self,
									"to_agent": child,
									"trade_path": [self,child],
									"trade_asset": excess,
									"trade_amount": 1,
									"trade_type": "send",
									"return_res": null,
									"return_amt": 1
								}
								if debug_mode:
									print(" .... sending a trade along, ", path_dict)
								if _emit_trade_with_budget(path_dict):
									assets[excess] -= 1
									bars[excess].value = assets[excess]
									sent_count += 1
			if sent_count > 0:
				logistics_ready = false


func draw_selected_box():
	LevelHelpersRef.draw_agent_selection_box(_get_level_root(), self)


func _on_area_entered(trade: Area2D) -> void:
	if trade.end_agent == self:
		if assets.get(trade.asset) != null:
			if (assets[trade.asset] < (needs[trade.asset] * 2)):
				assets[trade.asset] += trade.amount
				bars[trade.asset].value = assets[trade.asset]
			
			if trade.type == "swap":
				var return_amount = trade.return_amt * Global.values[trade.asset] / Global.values[trade.return_asset]
				if return_amount < 0.5:
					return_amount = 0
				else:
					if return_amount < 1:
						return_amount = 1
					else:
						return_amount = int(return_amount)
				if return_amount > 0:
					var liquidity_origin_value = trade.get("liquidity_cycle_origin_id")
					var liquidity_origin_id := 0
					if liquidity_origin_value != null:
						liquidity_origin_id = int(liquidity_origin_value)
					var path_dict = {
						"from_agent": self,
						"to_agent": trade.start_agent,
						"trade_path": [self, trade.start_agent],
						"trade_asset": trade.return_asset,
						"trade_amount": return_amount,
						"trade_type": "send",
						"return_res": null,
						"return_amt": null,
						"liquidity_cycle_trade": bool(trade.get("liquidity_cycle_trade")),
						"liquidity_cycle_origin_id": liquidity_origin_id
					}
					if (assets[trade.return_asset] >= return_amount):
						if _emit_trade_with_budget(path_dict):
							assets[trade.return_asset] -= return_amount
							bars[trade.return_asset].value = assets[trade.return_asset]
						else:
							trade_queue.append(path_dict)
					else:
						trade_queue.append(path_dict)
				if trade.has_method("finish_trade"):
					trade.call_deferred("finish_trade")
				else:
					trade.call_deferred("queue_free")
		else:
			print("Error myco without asset:", trade.asset, assets)


func _on_growth_timer_timeout() -> void:
	var all_in = _has_complete_nutrient_set()

	if myco_stage == MycoGrowthStage.DEAD:
		if _challenge_myco_death_enabled() and all_in and _has_supporting_neighbors():
			myco_dead_ticks = 0
			myco_starvation_ticks = 0
			_set_myco_stage(MycoGrowthStage.SPORE)
			return
		myco_dead_ticks += 1
		if is_instance_valid(sprite):
			var dead_body_scale = _get_texture_fit_scale(myco_rhizo_texture, myco_tile_span * MYCO_DEAD_RHIZO_BODY_CELL_RATIO)
			if not is_instance_valid(myco_rhizo_texture):
				dead_body_scale = mushroom_base_scale * 0.18
			sprite.scale = sprite.scale.lerp(dead_body_scale, MYCO_DEAD_MUSHROOM_SHRINK_LERP)
			var s_col = sprite.modulate
			s_col.a = maxf(s_col.a - MYCO_DEAD_MUSHROOM_ALPHA_STEP, 0.0)
			sprite.modulate = s_col
		if is_instance_valid(sprite_myco):
			sprite_myco.scale = sprite_myco.scale.lerp(rhizo_spore_scale, MYCO_DEAD_RHIZO_SHRINK_LERP)
			sprite_myco.modulate = Color(0.84, 0.73, 0.58, MYCO_RHIZO_ALPHA_LIVE)
			_refresh_buddy_radius_from_rhizo()
			_mark_network_dirty()
		if myco_dead_ticks >= MYCO_DEAD_RECOVERY_TICKS:
			if _challenge_myco_death_enabled():
				kill_it()
			else:
				_revert_to_spore()
		return

	var consumed_all_nutrients := false
	if all_in:
		myco_starvation_ticks = 0
		for res in assets:
			assets[res] -= 1
			bars[res].value = assets[res]
		consumed_all_nutrients = true
		if myco_stage == MycoGrowthStage.RHIZO_GROW and is_instance_valid(sprite_myco):
			_set_rhizo_scale(sprite_myco.scale.lerp(rhizo_native_scale, 0.42))
		if is_instance_valid(sprite):
			var old_up = sprite.modulate
			var up_alpha = minf(old_up.a + alpha_step_up, 1.0)
			sprite.modulate = Color(old_up, up_alpha)
	else:
		var has_support = _has_supporting_neighbors()
		var starvation_limit = MYCO_STARVATION_REVERT_TICKS
		if has_support and not _challenge_myco_death_enabled():
			myco_starvation_ticks = max(myco_starvation_ticks - 1, 0)
			if is_instance_valid(sprite):
				var old_supported = sprite.modulate
				var supported_alpha = minf(old_supported.a + (alpha_step_up * 0.15), 1.0)
				sprite.modulate = Color(old_supported, supported_alpha)
			if is_instance_valid(sprite_myco) and myco_stage != MycoGrowthStage.SPORE:
				_set_rhizo_scale(sprite_myco.scale.lerp(rhizo_native_scale, 0.03))
		else:
			if has_support:
				starvation_limit *= MYCO_SUPPORTED_STARVATION_MULTIPLIER
			myco_starvation_ticks += 1
			if is_instance_valid(sprite):
				var old_down = sprite.modulate
				var down_step = alpha_step_down * 0.5
				if has_support:
					down_step /= float(MYCO_SUPPORTED_STARVATION_MULTIPLIER)
				var down_alpha = maxf(old_down.a - down_step, 0.25)
				sprite.modulate = Color(old_down, down_alpha)
			if is_instance_valid(sprite_myco) and myco_stage != MycoGrowthStage.SPORE:
				var shrink_lerp = MYCO_STARVATION_SHRINK_LERP
				if has_support:
					shrink_lerp /= float(MYCO_SUPPORTED_STARVATION_MULTIPLIER)
				_set_rhizo_scale(sprite_myco.scale.lerp(rhizo_spore_scale, shrink_lerp))
			if myco_starvation_ticks >= starvation_limit:
				if _challenge_myco_death_enabled():
					myco_dead_ticks = 0
					_set_myco_stage(MycoGrowthStage.DEAD)
				elif myco_stage != MycoGrowthStage.SPORE:
					_revert_to_spore()
				return

	if myco_stage == MycoGrowthStage.POD_READY:
		myco_pod_ticks += 1
		var pod_baby_tick = myco_pod_ticks > 0 and (myco_pod_ticks % MYCO_POD_BABY_TICK_INTERVAL) == 0
		if pod_baby_tick and myco_harvest_ready and Global.baby_mode:
			var pod_baby_roll := random.randi_range(MYCO_POD_BABY_MIN, MYCO_POD_BABY_MAX)
			_emit_parent_bounded_spore_births(pod_baby_roll, "pod_birth")
		return

	if myco_stage_wait_ticks > 0:
		myco_stage_wait_ticks -= 1

	if not consumed_all_nutrients:
		return

	if myco_stage_wait_ticks > 0:
		return

	myco_stage_consumptions += 1
	if myco_stage_consumptions < MYCO_STAGE_CONSUMPTIONS_PER_ADVANCE:
		return

	myco_stage_consumptions = 0
	myco_stage_wait_ticks = MYCO_STAGE_ADVANCE_WAIT_TICKS

	if myco_stage == MycoGrowthStage.SPORE:
		_set_myco_stage(MycoGrowthStage.RHIZO_GROW)
	elif myco_stage == MycoGrowthStage.RHIZO_GROW:
		myco_pod_ticks = 0
		_set_myco_stage(MycoGrowthStage.POD_READY)


func _on_action_timer_timeout() -> void:
	logistics_ready = true
