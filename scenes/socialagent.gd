extends Agent

const SocialLevelHelpersRef = preload("res://scenes/level_helpers.gd")
const STORY_FARMER_HARVEST_IDLE := "idle"
const STORY_FARMER_HARVEST_MOVING_TO_CROP := "moving_to_crop"
const STORY_FARMER_HARVEST_RETURNING_HOME := "returning_home"
const STORY_FARMER_HARVEST_SPEED_MULTIPLIER := 0.10
const STORY_FARMER_MOVE_TO_CROP_SECONDS := 0.32 / STORY_FARMER_HARVEST_SPEED_MULTIPLIER
const STORY_FARMER_RETURN_HOME_SECONDS := 0.30 / STORY_FARMER_HARVEST_SPEED_MULTIPLIER
const FARMER_CARRY_OFFSET := Vector2(16.0, -20.0)
const FARMER_CARRY_SCALE := Vector2(0.7, 0.7)
const FARMER_WALK_STRIDE_RADIANS_PER_SEC := 18.0
const FARMER_WALK_BOB_PIXELS := 3.0
const FARMER_WALK_SWAY_RADIANS := 0.08
const FARMER_WALK_STRETCH := 0.045
const FARMER_WALK_MOVE_EPSILON := 0.04
const CARRY_TEX_BEAN := preload("res://graphics/bean.png")
const CARRY_TEX_SQUASH := preload("res://graphics/squash_32.png")
const CARRY_TEX_MAIZE := preload("res://graphics/maize_32.png")
const CARRY_TEX_TREE := preload("res://graphics/acorn_32.png")
const VILLAGER_FAMILY_ENERGY_THRESHOLD := 48
const VILLAGER_FAMILY_ENERGY_TRADE := 1
const VILLAGER_FAMILY_ENERGY_MISSING_NUTRIENT := 2
const VILLAGER_FAMILY_ENERGY_COMPLETE_NPK := 1
const VILLAGER_FAMILY_RETRY_TICKS := 24
const VILLAGER_CHILD_MATURITY_THRESHOLD := 10
const VILLAGER_CHILD_FAILED_RETRY_TICKS := 4
const VILLAGER_NUTRIENTS := ["N", "P", "K"]
const DIRECT_PERSON_TRADE_TILE_REDUCTION := 0
const VILLAGER_NUTRIENT_TRADE_RESERVE := 1.0
const VILLAGER_LIQUIDITY_STALL_BACKOFF_MSEC := 800
const BANK_BOOTSTRAP_MAX_INFLIGHT_SWAPS := 2
const VILLAGER_VENDOR_MIN_MATURE_SCALE := 0.92
const VILLAGER_ADULT_TEXTURE_PATHS := {
	"farmer": "res://graphics/farmer.png",
	"vendor": "res://graphics/mama.png",
	"cook": "res://graphics/cook.png"
}

var trade_queue = []
var is_trading = false
var is_raining = true
var villager_family_energy := 0
var villager_family_retry_ticks := 0
var villager_family_reproduction_pending := false
var _story_farmer_harvest_state := STORY_FARMER_HARVEST_IDLE
var _story_farmer_harvest_target: Node = null
var _story_farmer_harvest_target_pos := Vector2.ZERO
var _story_farmer_harvest_home_pos := Vector2.ZERO
var _story_farmer_harvest_home_set := false
var _story_farmer_harvest_move_tween: Tween = null
var _story_farmer_carry_sprite: Sprite2D = null
var _story_farmer_carried_harvest_type := ""
var _story_farmer_carried_harvest_source: Node = null
var _story_farmer_walk_time := 0.0
var _story_farmer_walk_active := false
var _story_farmer_walk_base_position := Vector2.ZERO
var _story_farmer_walk_base_scale := Vector2.ONE
var _story_farmer_walk_base_rotation := 0.0
var _story_farmer_walk_last_global_position := Vector2.ZERO
var _story_farmer_walk_last_global_position_set := false
var _story_farmer_waiting_for_harvest_target := false
var _liquidity_inflight_count := 0
var _liquidity_source_cache: Dictionary = {}
var _liquidity_direct_candidates_cache: Array = []
var _liquidity_direct_candidates_cache_valid := false
var _liquidity_backoff_until_msec := 0
var _bank_bootstrap_pending_by_res: Dictionary = {}


func _story_farmer_get_level_root() -> Node:
	return get_node_or_null("../..")


func _is_story_farmer_actor() -> bool:
	if not Global.to_bool(get_meta("story_villager", false)):
		return false
	return str(type) == "farmer"


func _is_farmer_actor() -> bool:
	return str(type) == "farmer"


func _story_farmer_auto_harvest_enabled(level_root: Node) -> bool:
	if not _is_story_farmer_actor():
		return false
	if not is_instance_valid(level_root):
		return false
	if not level_root.has_method("story_farmer_auto_harvest_is_enabled"):
		return false
	return Global.to_bool(level_root.call("story_farmer_auto_harvest_is_enabled", self))


func _story_farmer_has_no_n() -> bool:
	if not _is_story_farmer_actor():
		return false
	return float(assets.get("N", 0.0)) <= 0.0


func _story_farmer_should_wait_for_harvest_target(level_root: Node) -> bool:
	if not _story_farmer_has_no_n():
		return false
	if _story_farmer_harvest_state != STORY_FARMER_HARVEST_IDLE:
		return false
	if not _story_farmer_auto_harvest_enabled(level_root):
		return false
	return _story_farmer_waiting_for_harvest_target


func _story_farmer_harvest_trip_active() -> bool:
	return _is_story_farmer_actor() and _story_farmer_harvest_state != STORY_FARMER_HARVEST_IDLE


func is_farmer_auto_harvesting() -> bool:
	return _story_farmer_harvest_trip_active()


func is_trade_locked_by_user_move() -> bool:
	if super.is_trade_locked_by_user_move():
		return true
	return _story_farmer_harvest_trip_active()


func _story_farmer_stop_harvest_tween() -> void:
	if is_instance_valid(_story_farmer_harvest_move_tween):
		_story_farmer_harvest_move_tween.kill()
	_story_farmer_harvest_move_tween = null


func _story_farmer_is_walking() -> bool:
	return not Global.to_bool(dead) and _is_farmer_actor() and (
		_story_farmer_harvest_state == STORY_FARMER_HARVEST_MOVING_TO_CROP
		or _story_farmer_harvest_state == STORY_FARMER_HARVEST_RETURNING_HOME
	)


func _story_farmer_capture_walk_base() -> void:
	if not is_instance_valid(sprite):
		return
	_story_farmer_walk_base_position = sprite.position
	_story_farmer_walk_base_scale = sprite.scale
	_story_farmer_walk_base_rotation = sprite.rotation
	_story_farmer_walk_time = 0.0
	_story_farmer_walk_active = true


func _story_farmer_reset_walk_animation() -> void:
	if not _story_farmer_walk_active:
		return
	if is_instance_valid(sprite):
		sprite.position = _story_farmer_walk_base_position
		sprite.scale = _story_farmer_walk_base_scale
		sprite.rotation = _story_farmer_walk_base_rotation
	_story_farmer_walk_active = false
	_story_farmer_walk_time = 0.0


func _story_farmer_update_walk_animation(delta: float) -> void:
	if not _is_farmer_actor() or not is_instance_valid(sprite):
		_story_farmer_reset_walk_animation()
		return
	if Global.to_bool(dead):
		_story_farmer_reset_walk_animation()
		_story_farmer_walk_last_global_position = global_position
		_story_farmer_walk_last_global_position_set = true
		return
	var moved_this_frame := false
	if _story_farmer_walk_last_global_position_set:
		moved_this_frame = global_position.distance_squared_to(_story_farmer_walk_last_global_position) > FARMER_WALK_MOVE_EPSILON
	_story_farmer_walk_last_global_position = global_position
	_story_farmer_walk_last_global_position_set = true
	if not (_story_farmer_is_walking() or moved_this_frame):
		_story_farmer_reset_walk_animation()
		return
	if not _story_farmer_walk_active:
		_story_farmer_capture_walk_base()
	_story_farmer_walk_time += maxf(delta, 0.0)
	var stride = sin(_story_farmer_walk_time * FARMER_WALK_STRIDE_RADIANS_PER_SEC)
	var lift = absf(stride)
	sprite.position = _story_farmer_walk_base_position + Vector2(0.0, -lift * FARMER_WALK_BOB_PIXELS)
	sprite.rotation = _story_farmer_walk_base_rotation + stride * FARMER_WALK_SWAY_RADIANS
	sprite.scale = Vector2(
		_story_farmer_walk_base_scale.x * (1.0 + lift * FARMER_WALK_STRETCH),
		_story_farmer_walk_base_scale.y * (1.0 - lift * FARMER_WALK_STRETCH * 0.45)
	)


func _story_farmer_release_target(level_root: Node) -> void:
	if not is_instance_valid(_story_farmer_harvest_target):
		_story_farmer_harvest_target = null
		_story_farmer_harvest_target_pos = Vector2.ZERO
		return
	if is_instance_valid(level_root) and level_root.has_method("story_farmer_release_harvest_target"):
		level_root.call("story_farmer_release_harvest_target", self, _story_farmer_harvest_target)
	_story_farmer_harvest_target = null
	_story_farmer_harvest_target_pos = Vector2.ZERO


func _story_farmer_get_carry_texture(harvest_type: String) -> Texture2D:
	match harvest_type:
		"bean":
			return CARRY_TEX_BEAN
		"squash":
			return CARRY_TEX_SQUASH
		"maize":
			return CARRY_TEX_MAIZE
		"tree":
			return CARRY_TEX_TREE
	return null


func _story_farmer_show_carry_visual(harvest_type: String) -> void:
	_story_farmer_clear_carry_visual()
	var carry_texture = _story_farmer_get_carry_texture(harvest_type)
	if not is_instance_valid(carry_texture):
		return
	var carry_sprite := Sprite2D.new()
	carry_sprite.name = "FarmerCarrySprite"
	carry_sprite.texture = carry_texture
	carry_sprite.position = FARMER_CARRY_OFFSET
	carry_sprite.scale = FARMER_CARRY_SCALE
	carry_sprite.z_index = 20
	add_child(carry_sprite)
	_story_farmer_carry_sprite = carry_sprite


func _story_farmer_clear_carry_visual() -> void:
	if is_instance_valid(_story_farmer_carry_sprite):
		_story_farmer_carry_sprite.queue_free()
	_story_farmer_carry_sprite = null


func _story_farmer_clear_carry_state() -> void:
	_story_farmer_clear_carry_visual()
	_story_farmer_carried_harvest_type = ""
	_story_farmer_carried_harvest_source = null


func _story_farmer_abort_carried_harvest() -> void:
	if is_instance_valid(_story_farmer_carried_harvest_source):
		if _story_farmer_carried_harvest_source.has_method("cancel_farmer_harvest_delivery"):
			_story_farmer_carried_harvest_source.call("cancel_farmer_harvest_delivery")
	_story_farmer_clear_carry_state()


func _story_farmer_finalize_carried_harvest(level_root: Node) -> void:
	if _story_farmer_carried_harvest_type == "":
		_story_farmer_clear_carry_state()
		return
	var delivered_type = _story_farmer_carried_harvest_type
	var delivered := false
	if is_instance_valid(_story_farmer_carried_harvest_source):
		if _story_farmer_carried_harvest_source.has_method("finalize_farmer_harvest_delivery"):
			delivered = Global.to_bool(_story_farmer_carried_harvest_source.call("finalize_farmer_harvest_delivery", self))
		elif _story_farmer_carried_harvest_source.has_method("try_harvest_to_farmer"):
			delivered = Global.to_bool(_story_farmer_carried_harvest_source.call("try_harvest_to_farmer", self))
	if delivered and is_instance_valid(level_root) and level_root.has_method("story_farmer_on_harvest_success"):
		level_root.call("story_farmer_on_harvest_success", self, delivered_type)
	if delivered:
		Global.perf_count_farmer_harvest_completed()
	_story_farmer_clear_carry_state()


func _story_farmer_reset_harvest_state(level_root: Node) -> void:
	_story_farmer_stop_harvest_tween()
	_story_farmer_reset_walk_animation()
	_story_farmer_abort_carried_harvest()
	_story_farmer_release_target(level_root)
	_story_farmer_harvest_state = STORY_FARMER_HARVEST_IDLE
	is_trading = false


func notify_tuktuk_capture_started() -> void:
	if _is_farmer_actor():
		_story_farmer_reset_harvest_state(_story_farmer_get_level_root())
	_story_farmer_reset_walk_animation()
	_story_farmer_walk_last_global_position = global_position
	_story_farmer_walk_last_global_position_set = true
	is_trading = false


func _story_farmer_is_harvest_target_valid(crop_target: Variant) -> bool:
	if not is_instance_valid(crop_target):
		return false
	if Global.to_bool(crop_target.get("dead")):
		return false
	if not crop_target.has_method("try_harvest_to_farmer"):
		return false
	if crop_target.has_method("can_drag_for_inventory_harvest"):
		if not Global.to_bool(crop_target.call("can_drag_for_inventory_harvest")):
			return false
	return true


func _story_farmer_harvest_target_is_still_here() -> bool:
	if not _story_farmer_is_harvest_target_valid(_story_farmer_harvest_target):
		return false
	return _story_farmer_harvest_target.global_position.distance_squared_to(_story_farmer_harvest_target_pos) <= 16.0


func _story_farmer_reacquire_harvest_target(level_root: Node) -> bool:
	_story_farmer_reset_harvest_state(level_root)
	logistics_ready = true
	if not _story_farmer_auto_harvest_enabled(level_root):
		return false
	if not _story_farmer_begin_harvest_trip(level_root):
		return false
	logistics_ready = false
	return true


func _story_farmer_resolve_home_pos() -> Vector2:
	if _story_farmer_harvest_home_set:
		return _story_farmer_harvest_home_pos
	var meta_home = get_meta("story_home_world_pos", null)
	if typeof(meta_home) == TYPE_VECTOR2:
		_story_farmer_harvest_home_pos = meta_home
	else:
		_story_farmer_harvest_home_pos = global_position
	_story_farmer_harvest_home_set = true
	return _story_farmer_harvest_home_pos


func _story_farmer_begin_return_home() -> void:
	var home_pos = _story_farmer_resolve_home_pos()
	_story_farmer_harvest_state = STORY_FARMER_HARVEST_RETURNING_HOME
	_story_farmer_stop_harvest_tween()
	if global_position.distance_squared_to(home_pos) <= 4.0:
		call_deferred("_on_story_farmer_return_home_finished")
		return
	var tween = get_tree().create_tween()
	_story_farmer_harvest_move_tween = tween
	tween.tween_property(self, "global_position", home_pos, STORY_FARMER_RETURN_HOME_SECONDS)
	tween.finished.connect(_on_story_farmer_return_home_finished)


func _story_farmer_refresh_trade_network(level_root: Node) -> void:
	new_buddies = true
	draw_lines = true
	generate_buddies()
	if not is_instance_valid(level_root):
		return
	if level_root.has_method("mark_agent_moved"):
		level_root.call("mark_agent_moved", self, global_position, global_position)
	elif level_root.has_method("request_agent_dirty"):
		level_root.call("request_agent_dirty", self, true, true, false)


func _story_farmer_cancel_trip_and_return_home(level_root: Node) -> void:
	if _story_farmer_harvest_state != STORY_FARMER_HARVEST_IDLE:
		Global.perf_count_farmer_harvest_cancelled()
	_story_farmer_stop_harvest_tween()
	_story_farmer_abort_carried_harvest()
	_story_farmer_release_target(level_root)
	logistics_ready = false
	is_trading = false
	_story_farmer_begin_return_home()


func _on_story_farmer_return_home_finished() -> void:
	_story_farmer_harvest_move_tween = null
	if _story_farmer_harvest_state != STORY_FARMER_HARVEST_RETURNING_HOME:
		return
	var level_root = _story_farmer_get_level_root()
	_story_farmer_finalize_carried_harvest(level_root)
	_story_farmer_harvest_state = STORY_FARMER_HARVEST_IDLE
	_story_farmer_reset_walk_animation()
	is_trading = false
	logistics_ready = true
	_story_farmer_refresh_trade_network(level_root)


func _on_story_farmer_arrived_at_crop() -> void:
	_story_farmer_harvest_move_tween = null
	if _story_farmer_harvest_state != STORY_FARMER_HARVEST_MOVING_TO_CROP:
		return
	var level_root = _story_farmer_get_level_root()
	if not _story_farmer_harvest_target_is_still_here():
		_story_farmer_cancel_trip_and_return_home(level_root)
		return
	var harvest_source = _story_farmer_harvest_target
	var harvest_type = str(harvest_source.get("type"))
	var harvested := false
	if harvest_source.has_method("begin_farmer_harvest_delivery"):
		harvested = Global.to_bool(harvest_source.call("begin_farmer_harvest_delivery", self))
	elif harvest_source.has_method("try_harvest_to_farmer"):
		harvested = Global.to_bool(harvest_source.call("try_harvest_to_farmer", self))
	if not harvested:
		_story_farmer_cancel_trip_and_return_home(level_root)
		return
	Global.perf_count_farmer_harvest_picked_up()
	_story_farmer_carried_harvest_type = harvest_type
	_story_farmer_carried_harvest_source = harvest_source
	_story_farmer_show_carry_visual(harvest_type)
	_story_farmer_release_target(level_root)
	_story_farmer_begin_return_home()


func _story_farmer_begin_harvest_trip(level_root: Node) -> bool:
	if not is_instance_valid(level_root):
		return false
	if not level_root.has_method("story_farmer_try_assign_harvest_target"):
		return false
	var crop_target = level_root.call("story_farmer_try_assign_harvest_target", self)
	if not _story_farmer_is_harvest_target_valid(crop_target):
		var was_waiting = _story_farmer_waiting_for_harvest_target
		_story_farmer_waiting_for_harvest_target = _story_farmer_has_no_n() and _story_farmer_auto_harvest_enabled(level_root)
		if _story_farmer_waiting_for_harvest_target and not was_waiting:
			Global.perf_count_farmer_harvest_waiting_no_target()
		return false
	_story_farmer_waiting_for_harvest_target = false
	_story_farmer_resolve_home_pos()
	_story_farmer_harvest_target = crop_target
	_story_farmer_harvest_target_pos = crop_target.global_position
	_story_farmer_harvest_state = STORY_FARMER_HARVEST_MOVING_TO_CROP
	trade_queue.clear()
	is_trading = false
	_story_farmer_stop_harvest_tween()
	if level_root.has_method("cancel_trades_for_harvesting_farmer"):
		level_root.call("cancel_trades_for_harvesting_farmer", self)
	_story_farmer_refresh_trade_network(level_root)
	Global.perf_count_farmer_harvest_started()
	var tween = get_tree().create_tween()
	_story_farmer_harvest_move_tween = tween
	tween.tween_property(self, "global_position", crop_target.global_position, STORY_FARMER_MOVE_TO_CROP_SECONDS)
	tween.finished.connect(_on_story_farmer_arrived_at_crop)
	return true


func _story_farmer_tick_auto_harvest(level_root: Node) -> bool:
	if not _is_story_farmer_actor():
		return false
	if _story_farmer_harvest_state == STORY_FARMER_HARVEST_MOVING_TO_CROP:
		if not _story_farmer_auto_harvest_enabled(level_root) or not _story_farmer_harvest_target_is_still_here():
			_story_farmer_cancel_trip_and_return_home(level_root)
			return true
		if not is_instance_valid(_story_farmer_harvest_move_tween):
			_story_farmer_cancel_trip_and_return_home(level_root)
			return true
		logistics_ready = false
		return true
	if _story_farmer_harvest_state == STORY_FARMER_HARVEST_RETURNING_HOME:
		if not is_instance_valid(_story_farmer_harvest_move_tween):
			_story_farmer_begin_return_home()
		logistics_ready = false
		return true
	if not _story_farmer_auto_harvest_enabled(level_root):
		if _story_farmer_harvest_state != STORY_FARMER_HARVEST_IDLE or is_instance_valid(_story_farmer_harvest_target):
			_story_farmer_reset_harvest_state(level_root)
		_story_farmer_waiting_for_harvest_target = false
		return false
	if not _story_farmer_has_no_n():
		_story_farmer_waiting_for_harvest_target = false
	if logistics_ready and _story_farmer_has_no_n():
		if _story_farmer_begin_harvest_trip(level_root):
			logistics_ready = false
			return true
	if is_instance_valid(level_root) and level_root.has_method("story_farmer_has_pending_inbound_trades"):
		if Global.to_bool(level_root.call("story_farmer_has_pending_inbound_trades", self)):
			return false
	if not logistics_ready:
		return false
	if _story_farmer_begin_harvest_trip(level_root):
		logistics_ready = false
		return true
	return false


func _process(delta: float) -> void:
	super._process(delta)
	_keep_villager_opaque()
	_apply_mature_villager_scale_floor()
	_story_farmer_update_walk_animation(delta)


func _is_story_village_person_actor() -> bool:
	if not Global.to_bool(get_meta("story_village_actor", false)):
		return false
	var role = str(type)
	return role == "farmer" or role == "vendor" or role == "cook"


func _keep_villager_opaque() -> void:
	if not _is_story_village_person_actor():
		return
	if is_equal_approx(modulate.a, 1.0):
		return
	var opaque_color := modulate
	opaque_color.a = 1.0
	modulate = opaque_color


func _is_villager_child() -> bool:
	return Global.to_bool(get_meta("villager_child", false))


func _apply_mature_villager_scale_floor() -> void:
	if str(type) != "vendor" or _is_villager_child() or not is_instance_valid(sprite):
		return
	min_scale = maxf(min_scale, VILLAGER_VENDOR_MIN_MATURE_SCALE)
	var current_scale_max = maxf(absf(sprite.scale.x), absf(sprite.scale.y))
	if current_scale_max >= VILLAGER_VENDOR_MIN_MATURE_SCALE:
		return
	if current_scale_max <= 0.0:
		sprite.scale = Vector2(VILLAGER_VENDOR_MIN_MATURE_SCALE, VILLAGER_VENDOR_MIN_MATURE_SCALE)
	else:
		sprite.scale *= VILLAGER_VENDOR_MIN_MATURE_SCALE / current_scale_max
	bean_base_scale = sprite.scale
	_sync_occupancy_cache()


func _should_use_villager_r_liquidity_cycle() -> bool:
	if not Global.to_bool(Global.villager_r_medium_only):
		return false
	return _is_story_village_person_actor()


func _should_use_bank_liquidity_bootstrap() -> bool:
	if not Global.to_bool(Global.villager_r_medium_only):
		return false
	return _is_village_bank_node(self)


func _is_villager_nutrient(res: String) -> bool:
	return VILLAGER_NUTRIENTS.has(res)


func _villager_has_complete_nutrients() -> bool:
	for res in VILLAGER_NUTRIENTS:
		if float(assets.get(res, 0.0)) <= 0.0:
			return false
	return true


func _can_villager_family_reproduce() -> bool:
	if not _is_story_village_person_actor():
		return false
	if _is_villager_child():
		return false
	if Global.to_bool(get_meta("story_disable_birth", false)):
		return false
	if not Global.baby_mode:
		return false
	if current_babies >= num_babies:
		return false
	return true


func _try_villager_family_reproduction() -> void:
	villager_family_reproduction_pending = false
	if villager_family_energy < VILLAGER_FAMILY_ENERGY_THRESHOLD:
		return
	if villager_family_retry_ticks > 0:
		return
	if not _can_villager_family_reproduce():
		return
	var babies_before: int = int(current_babies)
	emit_signal("new_agent", {
		"name": str(type),
		"pos": global_position,
		"villager_child_spawn": true,
		"villager_parent": self
	})
	if current_babies == babies_before and villager_family_retry_ticks <= 0:
		notify_villager_child_spawn_failed()


func notify_villager_child_spawned(child: Node) -> void:
	villager_family_reproduction_pending = false
	if not is_instance_valid(child):
		notify_villager_child_spawn_failed()
		return
	current_babies += 1
	villager_family_energy = 0
	villager_family_retry_ticks = VILLAGER_FAMILY_RETRY_TICKS


func notify_villager_child_spawn_failed() -> void:
	villager_family_reproduction_pending = false
	villager_family_retry_ticks = maxi(villager_family_retry_ticks, VILLAGER_CHILD_FAILED_RETRY_TICKS)


func _get_adult_villager_texture() -> Texture2D:
	var path = str(VILLAGER_ADULT_TEXTURE_PATHS.get(str(type), ""))
	if path == "":
		return null
	var loaded = ResourceLoader.load(path)
	if loaded is Texture2D:
		return loaded
	return null


func _mature_villager_child() -> void:
	if not _is_villager_child():
		return
	var adult_texture = _get_adult_villager_texture()
	if adult_texture is Texture2D:
		sprite_texture = adult_texture
		if is_instance_valid(sprite):
			sprite.texture = adult_texture
	set_meta("villager_child", false)
	set_meta("villager_child_maturity_energy", VILLAGER_CHILD_MATURITY_THRESHOLD)
	_apply_mature_villager_scale_floor()


func _add_villager_child_maturity_energy(amount: int) -> void:
	if amount <= 0:
		return
	if not _is_villager_child():
		return
	var maturity_energy = mini(
		int(get_meta("villager_child_maturity_energy", 0)) + amount,
		VILLAGER_CHILD_MATURITY_THRESHOLD
	)
	set_meta("villager_child_maturity_energy", maturity_energy)
	if maturity_energy >= VILLAGER_CHILD_MATURITY_THRESHOLD:
		_mature_villager_child()


func _add_villager_family_energy(amount: int) -> void:
	if amount <= 0:
		return
	if not _can_villager_family_reproduce():
		return
	villager_family_energy = mini(
		villager_family_energy + amount,
		VILLAGER_FAMILY_ENERGY_THRESHOLD * 2
	)
	if villager_family_energy >= VILLAGER_FAMILY_ENERGY_THRESHOLD and villager_family_retry_ticks <= 0 and not villager_family_reproduction_pending:
		villager_family_reproduction_pending = true
		call_deferred("_try_villager_family_reproduction")


func _get_villager_r_buffer_target() -> int:
	return maxi(int(Global.villager_r_buffer_target), 0)


func _get_villager_surplus_dominance_margin() -> int:
	return maxi(int(Global.villager_surplus_dominance_margin), 1)


func _get_villager_max_liquidity_inflight_swaps() -> int:
	return int(Global.villager_max_liquidity_inflight_swaps)


func _get_bank_bootstrap_packet_nutrient(trade_packet: Variant) -> String:
	if not _should_use_bank_liquidity_bootstrap():
		return ""
	if not is_instance_valid(trade_packet):
		return ""
	var trade_asset = str(trade_packet.get("asset"))
	if trade_asset == "R":
		var return_asset = str(trade_packet.get("return_asset"))
		if _is_villager_nutrient(return_asset):
			return return_asset
		return ""
	if _is_villager_nutrient(trade_asset):
		return trade_asset
	return ""


func _track_bank_bootstrap_pending(trade_packet: Variant, delta: int) -> void:
	var nutrient := _get_bank_bootstrap_packet_nutrient(trade_packet)
	if nutrient == "":
		return
	var current = int(_bank_bootstrap_pending_by_res.get(nutrient, 0))
	var next_value = maxi(current + delta, 0)
	if next_value <= 0:
		_bank_bootstrap_pending_by_res.erase(nutrient)
	else:
		_bank_bootstrap_pending_by_res[nutrient] = next_value


func notify_liquidity_trade_spawned(trade_packet: Variant = null) -> void:
	if not _should_use_villager_r_liquidity_cycle() and not _should_use_bank_liquidity_bootstrap():
		return
	_liquidity_inflight_count += 1
	_track_bank_bootstrap_pending(trade_packet, 1)


func notify_liquidity_trade_finished(trade_packet: Variant = null) -> void:
	_track_bank_bootstrap_pending(trade_packet, -1)
	if _liquidity_inflight_count <= 0:
		_liquidity_inflight_count = 0
		return
	_liquidity_inflight_count -= 1


func _count_inflight_liquidity_swaps_for_self() -> int:
	return maxi(_liquidity_inflight_count, 0)


func _is_liquidity_swap_backpressure_blocked() -> bool:
	var max_inflight = _get_villager_max_liquidity_inflight_swaps()
	if max_inflight <= 0:
		return false
	return _count_inflight_liquidity_swaps_for_self() >= max_inflight


func _is_bank_bootstrap_backpressure_blocked() -> bool:
	if BANK_BOOTSTRAP_MAX_INFLIGHT_SWAPS <= 0:
		return false
	return _count_inflight_liquidity_swaps_for_self() >= BANK_BOOTSTRAP_MAX_INFLIGHT_SWAPS


func _is_villager_liquidity_trade(path_dict: Dictionary) -> bool:
	return Global.to_bool(path_dict.get("liquidity_cycle_trade", false))


func _has_queued_liquidity_trade() -> bool:
	for queued_trade in trade_queue:
		if typeof(queued_trade) != TYPE_DICTIONARY:
			continue
		var path_dict: Dictionary = queued_trade
		if _is_villager_liquidity_trade(path_dict):
			return true
	return false


func _reset_liquidity_tick_cache() -> void:
	_liquidity_source_cache.clear()
	_liquidity_direct_candidates_cache.clear()
	_liquidity_direct_candidates_cache_valid = false


func _start_liquidity_backoff() -> void:
	_liquidity_backoff_until_msec = Time.get_ticks_msec() + VILLAGER_LIQUIDITY_STALL_BACKOFF_MSEC


func _liquidity_backoff_active() -> bool:
	return Time.get_ticks_msec() < _liquidity_backoff_until_msec


func _append_unique_direct_candidate(candidates: Array, seen: Dictionary, candidate: Variant) -> void:
	if not _is_village_person_node(candidate):
		return
	if candidate == self:
		return
	if Global.to_bool(candidate.get("dead")):
		return
	var candidate_id = int(candidate.get_instance_id())
	if seen.has(candidate_id):
		return
	seen[candidate_id] = true
	candidates.append(candidate)


func _get_direct_person_liquidity_candidates() -> Array:
	if _liquidity_direct_candidates_cache_valid:
		return _liquidity_direct_candidates_cache
	_liquidity_direct_candidates_cache_valid = true
	var candidates: Array = []
	var seen: Dictionary = {}
	for child in trade_buddies:
		_append_unique_direct_candidate(candidates, seen, child)
	var level_root = _story_farmer_get_level_root()
	var world = null
	if is_instance_valid(level_root):
		world = level_root.get_node_or_null("WorldFoundation")
	if is_instance_valid(world) and world.has_method("world_to_tile") and world.has_method("in_bounds") and world.has_method("get_trade_hub_occupants_cached"):
		var center_coord = Vector2i(world.world_to_tile(global_position))
		var radius_tiles = maxi(_get_direct_person_trade_reach_delta(self), 1) + 1
		for y in range(center_coord.y - radius_tiles, center_coord.y + radius_tiles + 1):
			for x in range(center_coord.x - radius_tiles, center_coord.x + radius_tiles + 1):
				var coord = Vector2i(x, y)
				if not world.in_bounds(coord):
					continue
				var occupants_variant = world.get_trade_hub_occupants_cached(coord, self)
				if typeof(occupants_variant) != TYPE_ARRAY:
					continue
				for occupant in occupants_variant:
					_append_unique_direct_candidate(candidates, seen, occupant)
	var reachable: Array = []
	for candidate in candidates:
		Global.perf_count_village_liquidity_direct_candidate_scan()
		if _can_reach_direct_person_trade(candidate):
			reachable.append(candidate)
	_liquidity_direct_candidates_cache = reachable
	return _liquidity_direct_candidates_cache


func _get_bank_bootstrap_nutrient_target() -> float:
	return maxf(float(Global.village_bank_bootstrap_nutrient_target), 0.0)


func _get_bank_bootstrap_effective_inventory(nutrient: String) -> float:
	if not _is_villager_nutrient(nutrient):
		return 0.0
	return float(assets.get(nutrient, 0.0)) + float(_bank_bootstrap_pending_by_res.get(nutrient, 0))


func _bank_needs_bootstrap_nutrient(nutrient: String) -> bool:
	if not _is_villager_nutrient(nutrient):
		return false
	var target := _get_bank_bootstrap_nutrient_target()
	if target <= 0.0:
		return false
	return _get_bank_bootstrap_effective_inventory(nutrient) < target


func _get_bank_bootstrap_needed_order() -> Array[String]:
	var needed: Array = []
	var target := _get_bank_bootstrap_nutrient_target()
	if target <= 0.0:
		var empty: Array[String] = []
		return empty
	for nutrient in VILLAGER_NUTRIENTS:
		var effective := _get_bank_bootstrap_effective_inventory(nutrient)
		if effective < target:
			needed.append({"res": nutrient, "deficit": target - effective})
	needed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["deficit"]) > float(b["deficit"])
	)
	var ordered: Array[String] = []
	for pair in needed:
		ordered.append(str(pair["res"]))
	return ordered


func _can_bank_reach_bootstrap_candidate(level_root: Node, candidate: Variant) -> bool:
	if not is_instance_valid(candidate):
		return false
	if is_instance_valid(level_root) and SocialLevelHelpersRef.are_agents_in_shared_tile_reach(level_root, self, candidate):
		return true
	var candidate_radius := 0.0
	if candidate.get("buddy_radius") != null:
		candidate_radius = float(candidate.get("buddy_radius"))
	var reach_px = maxf(float(buddy_radius), candidate_radius)
	return global_position.distance_to(candidate.global_position) <= reach_px


func _get_bank_bootstrap_candidates() -> Array:
	var candidates: Array = []
	var seen: Dictionary = {}
	for child in trade_buddies:
		_append_unique_direct_candidate(candidates, seen, child)
	var level_root = _story_farmer_get_level_root()
	var world = null
	if is_instance_valid(level_root):
		world = level_root.get_node_or_null("WorldFoundation")
	if is_instance_valid(world) and world.has_method("world_to_tile") and world.has_method("in_bounds") and world.has_method("get_trade_hub_occupants_cached"):
		var center_coord = Vector2i(world.world_to_tile(global_position))
		var radius_tiles = maxi(LevelHelpers.get_agent_tile_reach_delta(level_root, self), 1) + 1
		for y in range(center_coord.y - radius_tiles, center_coord.y + radius_tiles + 1):
			for x in range(center_coord.x - radius_tiles, center_coord.x + radius_tiles + 1):
				var coord = Vector2i(x, y)
				if not world.in_bounds(coord):
					continue
				var occupants_variant = world.get_trade_hub_occupants_cached(coord, self)
				if typeof(occupants_variant) != TYPE_ARRAY:
					continue
				for occupant in occupants_variant:
					_append_unique_direct_candidate(candidates, seen, occupant)
	elif is_instance_valid(level_root):
		var agents = level_root.get_node_or_null("Agents")
		if is_instance_valid(agents):
			for child in agents.get_children():
				_append_unique_direct_candidate(candidates, seen, child)
	var reachable: Array = []
	for candidate in candidates:
		Global.perf_count_village_liquidity_direct_candidate_scan()
		if _can_bank_reach_bootstrap_candidate(level_root, candidate):
			reachable.append(candidate)
	return reachable


func _can_bank_bootstrap_buy_from_person(person: Variant, nutrient: String) -> bool:
	if not _is_village_person_node(person):
		return false
	if person.has_method("is_farmer_auto_harvesting") and Global.to_bool(person.call("is_farmer_auto_harvesting")):
		return false
	if not _bank_needs_bootstrap_nutrient(nutrient):
		return false
	if not _person_can_accept_r_for_swap(person, 1):
		return false
	if not _is_person_specialty_nutrient(person, nutrient):
		return false
	return _person_can_trade_dominant_nutrient(person, nutrient, 1)


func _run_bank_liquidity_bootstrap(debug_mode: bool = false) -> bool:
	if not _should_use_bank_liquidity_bootstrap():
		return false
	if not logistics_ready or not is_raining:
		return false
	if _liquidity_backoff_active():
		logistics_ready = false
		is_trading = false
		return false
	if _has_queued_liquidity_trade():
		return false
	if _is_bank_bootstrap_backpressure_blocked():
		return false
	var needed_order := _get_bank_bootstrap_needed_order()
	if needed_order.is_empty():
		return false
	var candidates := _get_bank_bootstrap_candidates()
	candidates.shuffle()
	var found_possible_source := false
	for nutrient in needed_order:
		if not _bank_needs_bootstrap_nutrient(nutrient):
			continue
		for person in candidates:
			if not _can_bank_bootstrap_buy_from_person(person, nutrient):
				continue
			found_possible_source = true
			var path_dict = {
				"from_agent": self,
				"to_agent": person,
				"trade_path": [self, person],
				"trade_asset": "R",
				"trade_amount": 1,
				"trade_type": "swap",
				"return_res": nutrient,
				"return_amt": 1,
				"liquidity_cycle_trade": true,
				"liquidity_cycle_origin_id": int(get_instance_id()),
				"liquidity_cycle_origin_agent": self
			}
			if debug_mode:
				print("bank bootstrap: R -> ", nutrient, " via ", person.name)
			if _emit_or_queue_trade(path_dict):
				logistics_ready = false
				is_trading = true
				return true
			logistics_ready = false
			is_trading = true
			return true
	if not found_possible_source:
		_start_liquidity_backoff()
		logistics_ready = false
		is_trading = false
	return false


func _has_reachable_nutrient_source(requested_res: String) -> bool:
	if not _is_villager_nutrient(requested_res):
		return true
	if _liquidity_source_cache.has(requested_res):
		return Global.to_bool(_liquidity_source_cache[requested_res])
	Global.perf_count_village_liquidity_source_check()
	for child in trade_buddies:
		if not is_instance_valid(child) or child == self:
			continue
		if Global.to_bool(child.get("dead")):
			continue
		if _is_village_bank_node(child):
			if _can_bank_handle_liquidity_swap(child, "R", requested_res):
				_liquidity_source_cache[requested_res] = true
				return true
			continue
		if str(child.get("type")) == "myco":
			if child.assets.get(requested_res) != null and float(child.assets[requested_res]) > 0.0:
				_liquidity_source_cache[requested_res] = true
				return true
	for child in _get_direct_person_liquidity_candidates():
		if not _person_can_accept_r_for_swap(child, 1):
			continue
		if _person_has_return_surplus(child, requested_res, 1):
			_liquidity_source_cache[requested_res] = true
			return true
	_liquidity_source_cache[requested_res] = false
	return false


func _has_unreachable_core_deficit(deficit_order: Array[String]) -> bool:
	return _get_unreachable_core_deficit(deficit_order) != ""


func _get_unreachable_core_deficit(deficit_order: Array[String]) -> String:
	for deficit_res in deficit_order:
		if _is_villager_nutrient(deficit_res) and not _has_reachable_nutrient_source(deficit_res):
			return deficit_res
	return ""


func _is_villager_liquidity_stalled() -> bool:
	if not _should_use_villager_r_liquidity_cycle():
		return false
	return _liquidity_backoff_active()


func _drop_stalled_liquidity_queue() -> void:
	if trade_queue.is_empty():
		return
	var remaining_queue: Array = []
	var dropped_count := 0
	for queued_trade in trade_queue:
		if typeof(queued_trade) != TYPE_DICTIONARY:
			continue
		var path_dict: Dictionary = queued_trade
		if _is_villager_liquidity_trade(path_dict):
			dropped_count += 1
			continue
		remaining_queue.append(path_dict)
	trade_queue = remaining_queue
	if dropped_count > 0:
		Global.perf_count_village_liquidity_dropped_queue(dropped_count)


func _get_liquidity_dominant_nutrient() -> String:
	var nutrients: Array[String] = ["N", "P", "K"]
	var best_res := ""
	var best_value := -INF
	var min_value := INF
	for res in nutrients:
		if assets.get(res) == null:
			continue
		var value = float(assets[res])
		if value > best_value:
			best_value = value
			best_res = res
		if value < min_value:
			min_value = value
	if best_res == "" or min_value == INF:
		return ""
	if best_value <= 0.0:
		return ""
	if (best_value - min_value) < float(_get_villager_surplus_dominance_margin()):
		return ""
	return best_res


func _get_liquidity_any_tradeable_nutrient() -> String:
	var nutrients: Array[String] = ["N", "P", "K"]
	var best_res := ""
	var best_value := 0.0
	for res in nutrients:
		if assets.get(res) == null:
			continue
		var value = float(assets[res])
		if value > best_value:
			best_value = value
			best_res = res
	if best_value <= 0.0:
		return ""
	return best_res


func _get_liquidity_tradeable_nutrient() -> String:
	var specialty_res := _get_village_person_specialty_nutrient(self)
	if specialty_res != "" and _person_can_trade_dominant_nutrient(self, specialty_res, 1):
		return specialty_res
	return ""


func _get_highest_nutrient_deficit() -> String:
	var nutrients: Array[String] = ["N", "P", "K"]
	var best_need := ""
	var best_deficit := 0.0
	for res in nutrients:
		if assets.get(res) == null or needs.get(res) == null:
			continue
		var deficit = float(needs[res]) - float(assets[res])
		if deficit > best_deficit:
			best_deficit = deficit
			best_need = res
	return best_need


func _get_sorted_nutrient_deficits() -> Array[String]:
	var nutrients: Array[String] = ["N", "P", "K"]
	var deficit_pairs: Array = []
	for res in nutrients:
		if assets.get(res) == null or needs.get(res) == null:
			continue
		var deficit = float(needs[res]) - float(assets[res])
		if deficit > 0.0:
			deficit_pairs.append({"res": res, "deficit": deficit})
	deficit_pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["deficit"]) > float(b["deficit"])
	)
	var ordered: Array[String] = []
	for pair in deficit_pairs:
		ordered.append(str(pair["res"]))
	return ordered


func _get_liquidity_r_fill_target() -> float:
	var need_r = float(needs.get("R", 0.0))
	if need_r <= 0.0:
		need_r = float(_get_villager_r_buffer_target())
	return maxf(need_r, float(_get_villager_r_buffer_target()))


func _get_excess_r_repayment_threshold() -> float:
	var threshold = float(needs.get("R", 0.0))
	if threshold <= 0.0:
		threshold = float(_get_villager_r_buffer_target())
	return threshold


func _can_bank_offer_r_to_target(target: Node, offered_res: String, requested_res: String = "") -> bool:
	if str(type) != "bank" or offered_res != "R":
		return true
	if not is_instance_valid(target):
		return false
	if target.assets.get("R") == null or target.needs.get("R") == null:
		return true
	# Basket/target max is needs["R"] * 2, so half capacity is needs["R"].
	if float(target.assets["R"]) >= float(target.needs["R"]):
		return false
	if requested_res == "":
		return true
	if target.assets.get(requested_res) == null or target.needs.get(requested_res) == null:
		return false
	return float(target.assets[requested_res]) - float(target.needs[requested_res]) >= 1.0


func _is_village_bank_node(agent: Variant) -> bool:
	return is_instance_valid(agent) and str(agent.get("type")) == "bank" and Global.to_bool(agent.get_meta("story_village_actor", false))


func _is_village_person_node(agent: Variant) -> bool:
	if not is_instance_valid(agent):
		return false
	if not Global.to_bool(agent.get_meta("story_village_actor", false)):
		return false
	var agent_type = str(agent.get("type"))
	return agent_type == "farmer" or agent_type == "vendor" or agent_type == "cook"


func _get_village_person_specialty_nutrient(person: Variant) -> String:
	if not _is_village_person_node(person):
		return ""
	match str(person.get("type")):
		"farmer":
			return "N"
		"vendor":
			return "P"
		"cook":
			return "K"
	return ""


func _is_person_specialty_nutrient(person: Variant, nutrient: String) -> bool:
	return nutrient != "" and nutrient == _get_village_person_specialty_nutrient(person)


func _can_bank_handle_liquidity_swap(bank: Variant, offered_res: String, requested_res: String) -> bool:
	if not _is_village_bank_node(bank):
		return false
	if requested_res == "R":
		return _is_villager_nutrient(offered_res)
	if offered_res == "R" and _is_villager_nutrient(requested_res):
		if bank.assets.get(requested_res) == null:
			return false
		return float(bank.assets[requested_res]) > 0.0
	return false


func _set_agent_asset_bar(agent: Variant, asset_key: String, amount: float) -> void:
	if not is_instance_valid(agent):
		return
	if agent.assets.get(asset_key) == null:
		return
	agent.assets[asset_key] = amount
	if agent.bars.get(asset_key) != null and is_instance_valid(agent.bars[asset_key]):
		agent.bars[asset_key].value = amount


func _person_can_accept_r_for_swap(person: Variant, amount: int) -> bool:
	if not _is_village_person_node(person):
		return false
	if person.assets.get("R") == null or person.needs.get("R") == null:
		return false
	return float(person.assets["R"]) + float(amount) <= float(person.needs["R"]) * 2.0


func _is_agent_nutrient_dominant(agent: Variant, nutrient: String) -> bool:
	if not is_instance_valid(agent):
		return false
	if not _is_villager_nutrient(nutrient):
		return false
	if agent.assets.get(nutrient) == null:
		return false
	var requested_value = float(agent.assets.get(nutrient, 0.0))
	var best_value := -INF
	var min_value := INF
	for res in VILLAGER_NUTRIENTS:
		var value = float(agent.assets.get(res, 0.0))
		if value > best_value:
			best_value = value
		if value < min_value:
			min_value = value
	if best_value <= 0.0 or min_value == INF:
		return false
	if requested_value + 0.001 < best_value:
		return false
	return (best_value - min_value) >= float(_get_villager_surplus_dominance_margin())


func _person_can_trade_dominant_nutrient(person: Variant, nutrient: String, amount: int) -> bool:
	if amount <= 0:
		return false
	if not _is_village_person_node(person):
		return false
	if not _is_villager_nutrient(nutrient):
		return false
	if person.assets.get(nutrient) == null:
		return false
	var current_value = float(person.assets[nutrient])
	if current_value - float(amount) < VILLAGER_NUTRIENT_TRADE_RESERVE:
		return false
	return _is_agent_nutrient_dominant(person, nutrient) or _is_person_specialty_nutrient(person, nutrient)


func _person_has_return_surplus(person: Variant, requested_res: String, amount: int) -> bool:
	if Global.to_bool(Global.villager_r_medium_only) and _is_village_person_node(person) and not _is_person_specialty_nutrient(person, requested_res):
		return false
	return _person_can_trade_dominant_nutrient(person, requested_res, amount)


func _has_reachable_bank_stock_need(nutrient: String) -> bool:
	if not _is_villager_nutrient(nutrient):
		return false
	var target := _get_bank_bootstrap_nutrient_target()
	if target <= 0.0:
		return false
	for child in trade_buddies:
		if not _is_village_bank_node(child):
			continue
		if child.assets.get(nutrient) == null:
			continue
		if float(child.assets[nutrient]) < target:
			return true
	return false


func _get_direct_person_trade_reach_delta(target: Variant) -> int:
	var level_root = _story_farmer_get_level_root()
	var self_delta = LevelHelpers.get_agent_tile_reach_delta(level_root, self)
	var target_delta = LevelHelpers.get_agent_tile_reach_delta(level_root, target)
	return maxi(1, int(min(self_delta, target_delta)) - DIRECT_PERSON_TRADE_TILE_REDUCTION)


func _can_reach_direct_person_trade(target: Variant) -> bool:
	var level_root = _story_farmer_get_level_root()
	if LevelHelpers._supports_tile_world(level_root):
		return LevelHelpers.are_agents_in_neighboring_tiles(level_root, self, target, _get_direct_person_trade_reach_delta(target))
	var self_reach = float(buddy_radius)
	var target_reach = self_reach
	if is_instance_valid(target):
		var target_radius = target.get("buddy_radius")
		if typeof(target_radius) == TYPE_FLOAT or typeof(target_radius) == TYPE_INT:
			target_reach = float(target_radius)
	return global_position.distance_to(target.global_position) <= minf(self_reach, target_reach)


func _try_send_direct_person_liquidity_swap(requested_res: String, debug_mode: bool = false) -> bool:
	if not _is_story_village_person_actor():
		return false
	if not _is_villager_nutrient(requested_res):
		return false
	if assets.get("R") == null or float(assets["R"]) <= 0.0:
		return false
	var candidates: Array = _get_direct_person_liquidity_candidates().duplicate()
	candidates.shuffle()
	for child in candidates:
		Global.perf_count_village_liquidity_direct_candidate_scan()
		if not _person_can_accept_r_for_swap(child, 1):
			continue
		if not _person_has_return_surplus(child, requested_res, 1):
			continue
		var path_dict = {
			"from_agent": self,
			"to_agent": child,
			"trade_path": [self, child],
			"trade_asset": "R",
			"trade_amount": 1,
			"trade_type": "swap",
			"return_res": requested_res,
			"return_amt": 1,
			"liquidity_cycle_trade": true,
			"liquidity_cycle_origin_id": int(get_instance_id()),
			"liquidity_cycle_origin_agent": self
		}
		if debug_mode:
			print("buy: R -> ", requested_res, " via ", child.name)
		if _emit_trade_with_budget(path_dict):
			assets["R"] -= 1
			bars["R"].value = assets["R"]
			logistics_ready = false
			is_trading = true
			return true
	return false


func _try_send_excess_r_to_bank(debug_mode: bool = false) -> bool:
	if not _is_story_village_person_actor():
		return false
	if assets.get("R") == null:
		return false
	if float(assets["R"]) <= _get_excess_r_repayment_threshold():
		return false
	trade_buddies.shuffle()
	for child in trade_buddies:
		if not _is_village_bank_node(child):
			continue
		var path_dict = {
			"from_agent": self,
			"to_agent": child,
			"trade_path": [self, child],
			"trade_asset": "R",
			"trade_amount": 1,
			"trade_type": "send",
			"return_res": null,
			"return_amt": null
		}
		if debug_mode:
			print("excess R repayment: ", name, " -> ", child.name)
		if _emit_trade_with_budget(path_dict):
			assets["R"] -= 1
			bars["R"].value = assets["R"]
			logistics_ready = false
			is_trading = true
			return true
	return false


func _try_send_liquidity_swap(offered_res: String, requested_res: String, debug_mode: bool = false) -> bool:
	if offered_res == "" or requested_res == "":
		return false
	if assets.get(offered_res) == null or float(assets[offered_res]) <= 0.0:
		return false
	var offered_is_nutrient = _is_villager_nutrient(offered_res)
	var requested_is_nutrient = _is_villager_nutrient(requested_res)
	if offered_res != "R" and not offered_is_nutrient:
		return false
	if requested_res != "R" and not requested_is_nutrient:
		return false
	if offered_is_nutrient:
		if requested_is_nutrient and offered_res == requested_res:
			return false
		if _is_story_village_person_actor() and not _is_person_specialty_nutrient(self, offered_res):
			return false
		if not _person_can_trade_dominant_nutrient(self, offered_res, 1):
			return false
	if offered_res == "R" and requested_is_nutrient:
		if _try_send_direct_person_liquidity_swap(requested_res, debug_mode):
			return true
	trade_buddies.shuffle()
	for child in trade_buddies:
		if not is_instance_valid(child):
			continue
		if child == self:
			continue
		var child_is_bank = _is_village_bank_node(child)
		var child_is_basket = str(child.get("type")) == "myco"
		if not child_is_bank and not child_is_basket:
			continue
		if child_is_bank:
			if not ((offered_res == "R" and requested_is_nutrient) or (offered_is_nutrient and requested_res == "R")):
				continue
			if not _can_bank_handle_liquidity_swap(child, offered_res, requested_res):
				continue
		else:
			if not ((offered_res == "R" and requested_is_nutrient) or (offered_is_nutrient and requested_is_nutrient)):
				continue
			if child.assets.get(offered_res) == null or child.assets.get(requested_res) == null:
				continue
			if float(child.assets[requested_res]) <= 0.0:
				continue
			if offered_res != "R" and child.assets[offered_res] >= child.needs[offered_res] * 2:
				continue
		var path_dict = {
			"from_agent": self,
			"to_agent": child,
			"trade_path": [self, child],
			"trade_asset": offered_res,
			"trade_amount": 1,
			"trade_type": "swap",
			"return_res": requested_res,
			"return_amt": 1,
			"liquidity_cycle_trade": true,
			"liquidity_cycle_origin_id": int(get_instance_id()),
			"liquidity_cycle_origin_agent": self
		}
		if debug_mode:
			var swap_label = "swap"
			if offered_res == "R" and requested_is_nutrient:
				swap_label = "buy"
			elif offered_is_nutrient and requested_res == "R":
				swap_label = "sell"
			print(swap_label, ": ", offered_res, " -> ", requested_res, " via ", child.name)
		if _emit_trade_with_budget(path_dict):
			assets[offered_res] -= 1
			bars[offered_res].value = assets[offered_res]
			logistics_ready = false
			is_trading = true
			return true
	return false


func _run_villager_r_liquidity_cycle(debug_mode: bool = false) -> void:
	if not logistics_ready or not is_raining:
		return
	if _liquidity_backoff_active():
		logistics_ready = false
		is_trading = false
		return
	if _story_farmer_should_wait_for_harvest_target(_story_farmer_get_level_root()):
		return
	if _is_liquidity_swap_backpressure_blocked():
		return
	var deficit_order = _get_sorted_nutrient_deficits()
	var has_deficit = not deficit_order.is_empty()
	var tradeable_res = _get_liquidity_tradeable_nutrient()
	var current_r = float(assets.get("R", 0.0))
	var r_fill_target = float(_get_liquidity_r_fill_target())
	if has_deficit and current_r > 0.0:
		for deficit_res in deficit_order:
			if _try_send_liquidity_swap("R", deficit_res, debug_mode):
				return
	if _try_send_excess_r_to_bank(debug_mode):
		return
	if tradeable_res != "" and (current_r < r_fill_target or _has_reachable_bank_stock_need(tradeable_res)):
		if _try_send_liquidity_swap(tradeable_res, "R", debug_mode):
			return
	if has_deficit and tradeable_res != "":
		for deficit_res in deficit_order:
			if deficit_res == tradeable_res:
				continue
			if _try_send_liquidity_swap(tradeable_res, deficit_res, debug_mode):
				return
	if has_deficit or (tradeable_res != "" and current_r < r_fill_target):
		_drop_stalled_liquidity_queue()
		_start_liquidity_backoff()
		if debug_mode:
			print("blocked: no available liquidity route for ", name)
		logistics_ready = false
		is_trading = false


func _calculate_swap_return_amount(trade_packet: Area2D) -> int:
	var trade_asset = str(trade_packet.asset)
	var return_asset = str(trade_packet.return_asset)
	var trade_value = float(Global.values.get(trade_asset, 1))
	var return_value = float(Global.values.get(return_asset, 1))
	if return_value <= 0.0:
		return 0
	var return_amount = float(trade_packet.return_amt) * trade_value / return_value
	if return_amount < 0.5:
		return 0
	if return_amount < 1.0:
		return 1
	return int(return_amount)


func _can_return_swap_asset(trade_packet: Area2D, return_amount: int) -> bool:
	if return_amount <= 0:
		return false
	var received_asset = str(trade_packet.asset)
	var return_asset = str(trade_packet.return_asset)
	if _is_village_bank_node(self):
		if received_asset == "R":
			if not _is_villager_nutrient(return_asset):
				return false
			if assets.get(return_asset) == null:
				return false
			return float(assets[return_asset]) >= float(return_amount)
		if return_asset == "R" and _is_villager_nutrient(received_asset):
			return true
		return false
	if _is_story_village_person_actor():
		if received_asset != "R":
			return false
		return _person_has_return_surplus(self, return_asset, return_amount)
	return false


func _deduct_trade_asset(asset_key: String, amount: int) -> void:
	if assets.get(asset_key) == null:
		return
	assets[asset_key] -= amount
	if bars.get(asset_key) != null and is_instance_valid(bars[asset_key]):
		bars[asset_key].value = assets[asset_key]


func _emit_or_queue_trade(path_dict: Dictionary) -> bool:
	var asset_key = str(path_dict.get("trade_asset", ""))
	var amount = maxi(int(path_dict.get("trade_amount", 1)), 1)
	if asset_key == "":
		return false
	if _is_village_bank_node(self) and asset_key == "R":
		if _emit_trade_with_budget(path_dict):
			return true
		trade_queue.append(path_dict)
		return false
	if assets.get(asset_key) == null:
		return false
	if float(assets[asset_key]) < float(amount):
		trade_queue.append(path_dict)
		return false
	if _emit_trade_with_budget(path_dict):
		_deduct_trade_asset(asset_key, amount)
		return true
	trade_queue.append(path_dict)
	return false


func _flush_trade_queue() -> void:
	if trade_queue.is_empty():
		return
	var liquidity_stalled := false
	var checked_liquidity_stall := false
	var remaining_queue: Array = []
	for queued_trade in trade_queue:
		if typeof(queued_trade) != TYPE_DICTIONARY:
			continue
		var path_dict: Dictionary = queued_trade
		if _is_villager_liquidity_trade(path_dict):
			if not checked_liquidity_stall:
				liquidity_stalled = _is_villager_liquidity_stalled()
				checked_liquidity_stall = true
			if liquidity_stalled:
				Global.perf_count_village_liquidity_dropped_queue()
				continue
		var asset_key = str(path_dict.get("trade_asset", ""))
		var amount = maxi(int(path_dict.get("trade_amount", 1)), 1)
		if asset_key == "":
			continue
		if _is_village_bank_node(self) and asset_key == "R":
			if not _emit_trade_with_budget(path_dict):
				remaining_queue.append(path_dict)
			continue
		if assets.get(asset_key) == null:
			continue
		if float(assets[asset_key]) < float(amount):
			remaining_queue.append(path_dict)
			continue
		if _emit_trade_with_budget(path_dict):
			_deduct_trade_asset(asset_key, amount)
		else:
			remaining_queue.append(path_dict)
	trade_queue = remaining_queue


func _finish_trade_packet(trade_packet: Area2D) -> void:
	if trade_packet.has_method("finish_trade"):
		trade_packet.call_deferred("finish_trade")
	else:
		trade_packet.call_deferred("queue_free")


func _refund_rejected_r_swap(trade_packet: Area2D) -> bool:
	if str(trade_packet.asset) != "R":
		return false
	if not is_instance_valid(trade_packet.start_agent):
		return false
	var refund_amount = maxi(int(trade_packet.amount), 1)
	if not _is_village_bank_node(self):
		if assets.get("R") == null:
			return false
		assets["R"] += refund_amount
		if bars.get("R") != null and is_instance_valid(bars["R"]):
			bars["R"].value = assets["R"]
	var refund_path = {
		"from_agent": self,
		"to_agent": trade_packet.start_agent,
		"trade_path": [self, trade_packet.start_agent],
		"trade_asset": "R",
		"trade_amount": refund_amount,
		"trade_type": "send",
		"return_res": null,
		"return_amt": null,
		"liquidity_cycle_trade": Global.to_bool(trade_packet.get("liquidity_cycle_trade")),
		"liquidity_cycle_origin_id": int(trade_packet.get("liquidity_cycle_origin_id")),
		"liquidity_cycle_origin_agent": trade_packet.get("liquidity_cycle_origin_agent")
	}
	return _emit_or_queue_trade(refund_path)


func logistics():
	var level_root = _story_farmer_get_level_root()
	var debug_mode = false
	if _story_farmer_tick_auto_harvest(level_root):
		return
	if str(type) == "bank" and Global.to_bool(get_meta("bank_disabled", false)):
		logistics_ready = false
		is_trading = false
		return
	if _story_farmer_should_wait_for_harvest_target(level_root):
		trade_queue.clear()
		logistics_ready = false
		is_trading = false
		return
	if _should_use_villager_r_liquidity_cycle():
		_reset_liquidity_tick_cache()
	_flush_trade_queue()
	if str(type) == "bank":
		if _should_use_bank_liquidity_bootstrap():
			if not _run_bank_liquidity_bootstrap(debug_mode):
				is_trading = false
		else:
			is_trading = false
		return
	var farmer_trade_any_n := false
	if _is_story_farmer_actor() and is_instance_valid(level_root) and level_root.has_method("story_farmer_should_trade_any_n"):
		farmer_trade_any_n = Global.to_bool(level_root.call("story_farmer_should_trade_any_n", self))
	#wait for timer
	var excess_res = null
	var high_amt_excess = 0
	var needed_res = null
	var high_amt_needed = 0
	
	if _should_use_villager_r_liquidity_cycle():
		_run_villager_r_liquidity_cycle(debug_mode)
		return
	
	
	
	if logistics_ready and is_raining:# and is_trading == false:
		if( is_instance_valid(Global.active_agent)):
			if self.name == Global.active_agent.name:
				debug_mode = false#true
	
		if debug_mode:
			print("New Round in: ", name ,", ", assets, " needs: ", needs)	
		#determine if there are extra resources (offers)
		#find excess stock
		for res in assets:
			current_excess[res] = -999
			current_needs[res] = -999	
			
			if(res == "R"):
				if assets[res] > 0:
					current_excess[res] = assets[res]
			
			if farmer_trade_any_n and res == "N":
				if float(assets[res]) > 0.0:
					current_excess[res] = assets[res]
					excess_res = res
				# Treat N as always-tradable for story/challenge farmers in this mode.
				# Re-harvest timing is handled separately by the level-side low-N threshold.
				current_needs[res] = -999
				continue
					
			var c_excess = assets[res] - needs[res] 
		
			if assets[res] > needs[res]:
				#if c_excess > high_amt_excess:
				high_amt_excess = c_excess
				excess_res = res
				current_excess[res] = high_amt_excess
				
			if assets[res] < needs[res]:
				#print("res: ", res, " c_excess: ", c_excess, " high_amt_needed: ", high_amt_needed)
				#if -1 * c_excess > high_amt_needed:
				high_amt_needed = -1 * c_excess
				needed_res = res
				current_needs[res] = high_amt_needed
			
		
		var needed_keys: Array = current_needs.keys()
		var excess_keys: Array = current_excess.keys()
		# Sort keys in descending order of values.
		needed_keys.sort_custom(func(x: String, y: String) -> bool: return current_needs[x] > current_needs[y])
		excess_keys.sort_custom(func(x: String, y: String) -> bool: return current_excess[x] > current_excess[y])
		#print("actual needs: ", needs)
		if debug_mode:
			print("excess: ", current_excess  )
			print("excess sorted: ", excess_keys)
			print("needs: ", current_needs  )
			print("needs sorted: ", needed_keys)
			
		
		if excess_res != null and needed_res != null:
			#var children =  $"../../Agents".get_children()
			trade_buddies.shuffle()
			
			if debug_mode:
				print(" shuffle" )
			var need_itter = 0
			
			for child in trade_buddies: #children:
				if(is_instance_valid(child)):
					if logistics_ready and child.type == 'myco':
						if debug_mode:
							print(" child found" )
						for need in needed_keys:
							need_itter +=1
							var excess_iter = 0
							for excess in excess_keys:
								if(excess == need):
									continue
								excess_iter +=1
								if current_needs[need] <= 0 or current_excess[excess] <= 0:
									continue
								if debug_mode:
									print(need_itter, ". current need: ", need, " supply: ", assets[need] )
									print(excess_iter, ". current excess: ", excess, " supply: ",assets[excess] )
								if not logistics_ready:
									continue
								if child.assets.get(excess) == null or child.assets.get(need) == null:
									continue
								if debug_mode:
									print( " ... myco assets: " , child.assets)
								if(child.assets[excess] < child.needs[excess] *2 and _can_bank_offer_r_to_target(child, excess, need)):
									var path_dict = {
										"from_agent": self,
										"to_agent": child,
										"trade_path": [self,child],
										"trade_asset": excess,
										"trade_amount": 1, #amt_needed,
										"trade_type": "swap",
										"return_res": need,
										"return_amt": 1,#amt_needed
									}
									if debug_mode:
										print(" .... sending a trade along, ")
									if _emit_trade_with_budget(path_dict):
										assets[excess] -= 1#amt_needed
										bars[excess].value = assets[excess]
										logistics_ready = false
										is_trading = true
										break
									#trade.emit(path_dict)
									#send what is in excess.
											
					
									#Attempt to push out what you have in abundance
							
		#determine what is needed (needs)
		
		#if they can s wap a resource for a needed resource do it 
		#     Send the resource to the myco (when it arrives the needed resource will come back)

		#Consume resources
		#These are combinations NPK together
		
		#Increase health
		
		#Decay unused resources
	
	if false:
	#if decay_ready:
		#print("decay", assets)
		decay_ready = false
		for res in assets:
			if assets[res] >= 1 and res != "R":
				assets[res] -=1
				bars[res].value = assets[res]
			if assets[res] >= 1 and res == "R":
				evaporate()
				#print(" decay: ", assets)
	
	if evaporate_ready:
		#print("decay", assets)
		evaporate_ready = false
		#evaporate()



func _on_area_entered(ztrade: Area2D) -> void:
	if ztrade.end_agent == self:
		var received_asset := str(ztrade.asset)
		if assets.get(received_asset) == null:
			_finish_trade_packet(ztrade)
			return
		var should_return_swap := str(ztrade.type) == "swap"
		var return_amount := 0
		if should_return_swap:
			return_amount = _calculate_swap_return_amount(ztrade)
			if not _can_return_swap_asset(ztrade, return_amount):
				_refund_rejected_r_swap(ztrade)
				_finish_trade_packet(ztrade)
				return
		var received_nutrient: bool = _is_villager_nutrient(received_asset)
		var was_missing_nutrient: bool = _is_story_village_person_actor() and received_nutrient and float(assets.get(received_asset, 0.0)) <= 0.0
		assets[ztrade.asset]+=ztrade.amount
		is_trading = false
		var bank_receiving_r := _is_village_bank_node(self) and received_asset == "R"
		if not bank_receiving_r and assets[ztrade.asset]> needs[ztrade.asset] *2:
			assets[ztrade.asset] = needs[ztrade.asset] *2
		else:
			Global.add_score(ztrade.amount)
			emit_signal("update_score")
		bars[ztrade.asset].value = assets[ztrade.asset]
		if should_return_swap and return_amount > 0:
			var liquidity_origin_value = ztrade.get("liquidity_cycle_origin_id")
			var liquidity_origin_id := 0
			if liquidity_origin_value != null:
				liquidity_origin_id = int(liquidity_origin_value)
			var return_path = {
				"from_agent": self,
				"to_agent": ztrade.start_agent,
				"trade_path": [self, ztrade.start_agent],
				"trade_asset": str(ztrade.return_asset),
				"trade_amount": return_amount,
				"trade_type": "send",
				"return_res": null,
				"return_amt": null,
				"liquidity_cycle_trade": Global.to_bool(ztrade.get("liquidity_cycle_trade")),
				"liquidity_cycle_origin_id": liquidity_origin_id,
				"liquidity_cycle_origin_agent": ztrade.get("liquidity_cycle_origin_agent")
			}
			_emit_or_queue_trade(return_path)
		if _is_story_village_person_actor() and received_nutrient:
			var nutrient_growth_energy := VILLAGER_FAMILY_ENERGY_TRADE
			if was_missing_nutrient:
				nutrient_growth_energy += VILLAGER_FAMILY_ENERGY_MISSING_NUTRIENT
			if _villager_has_complete_nutrients():
				nutrient_growth_energy += VILLAGER_FAMILY_ENERGY_COMPLETE_NPK
			if _is_villager_child():
				_add_villager_child_maturity_energy(nutrient_growth_energy)
			else:
				_add_villager_family_energy(nutrient_growth_energy)
		var level_root = _story_farmer_get_level_root()
		if is_instance_valid(level_root) and level_root.has_method("notify_story_phase5_trade_received"):
			level_root.call("notify_story_phase5_trade_received", self, ztrade)
		_finish_trade_packet(ztrade)


func _bank_consume_nutrients_if_ready() -> void:
	if not _is_village_bank_node(self):
		return
	if _should_use_bank_liquidity_bootstrap():
		return
	for res in VILLAGER_NUTRIENTS:
		if float(assets.get(res, 0.0)) < 2.0:
			return
	for res in VILLAGER_NUTRIENTS:
		_set_agent_asset_bar(self, res, float(assets[res]) - 1.0)


func _on_growth_timer_timeout() -> void:
	#$GrowthTimer.set_wait_time(random.randf_range(1, 5))
	#production_ready = true
	#if production_ready:		
	#	production_ready = false
	var lock_villager_alpha := _is_story_village_person_actor()
	if lock_villager_alpha:
		_keep_villager_opaque()
	if villager_family_retry_ticks > 0:
		villager_family_retry_ticks -= 1
	if _is_village_bank_node(self):
		_bank_consume_nutrients_if_ready()
		return
	if _is_villager_child():
		return
	var disable_story_farmer_production = Global.to_bool(get_meta("story_disable_farmer_production", false))
	if not disable_story_farmer_production and prod_res.size() > 0 and prod_res[0] != null:
		for res in prod_res:
			assets[res]+=3
			if assets[res]> needs[res] *2:
				assets[res] = needs[res] *2
			bars[res].value = assets[res]
			
	#if there is 1 res in each asset - consume them all and grow in size
	#if any are missing shrink
	var all_in = true
	for res in assets:
		if res !=  "R":
			if assets[res] <= 0:
				all_in = false
			
	var newScale = $Sprite2D.scale
	#print(name, " assets: ", assets)
	if all_in == true:	
		if $Sprite2D.scale.x < max_scale and $Sprite2D.scale.y < max_scale:
			var candidate_scale = $Sprite2D.scale * (1 + scale_step_up)
			if _can_expand_to_scale(candidate_scale):
				newScale = candidate_scale
			
		if not lock_villager_alpha:
			var old_modulate = modulate
			var new_alpha = modulate.a+alpha_step_up
			if new_alpha > high_alpha:
				new_alpha = high_alpha
			var new_color = Color(old_modulate,new_alpha)
			self.modulate= new_color
		
		
		Global.add_score(400)
		emit_signal("update_score")
				
		
		
		#print(name, " ", $Sprite2D.scale)
		for res in assets:
			if(res != "R"):
				assets[res] -= 1
				bars[res].value = assets[res]
			#else:
			#	evaporate()
			
		
			
	else:
		#if $Sprite2D.scale.x > 0.5 and $Sprite2D.scale.y > 0.5:
			
			#newScale = $Sprite2D.scale * 0.95
			#print($Sprite2D.scale)
			
		if not lock_villager_alpha:
			var old_modulate = modulate
			var new_alpha = modulate.a-alpha_step_down
			if new_alpha < low_alpha:
				new_alpha = low_alpha
				
				if(Global.is_killing == true and self.killable == true):
					kill_it()
				
			var new_color = Color(old_modulate,new_alpha)
			self.modulate= new_color

	if newScale != $Sprite2D.scale:
		var tween = get_tree().create_tween()
		tween.tween_property($Sprite2D, "scale", newScale, 0.05)
		#tween.set_parallel(true)	
		
	if not _is_story_village_person_actor() and newScale.x >= max_scale and newScale.y >= max_scale and modulate.a >= 1:
		#print("increase score and twinkle")
		var sparkle = Global.sparkle_scene.instantiate()
		
		sparkle.z_as_relative = false
		sparkle.position = self.position
		sparkle.global_position = self.global_position
		#sparkle.z_index =-1
		$"../../Sparkles".add_child(sparkle)
		sparkle.start(0.75)
	
		if(Global.baby_mode and self.type != "tree" and not _is_story_village_person_actor()):
			if(Global.is_max_babies == true):
				if(current_babies < num_babies):
					have_babies()
			else:
				have_babies()


func _on_dry_timer_timeout() -> void:
	if(self.type == "tree"):
		var wait_for_rain = 0
		if(is_raining == true):
			wait_for_rain = random.randi_range(50, 100)
			is_raining = false
			var tween = get_tree().create_tween()
			tween.tween_property(sprite, "modulate:a", 0.2, 0.5)
			#tween.set_parallel(true)
			#$Sprite2D.modulate.a = 0.2
			
		else:
			wait_for_rain = random.randi_range(1, 50)
			is_raining = true
			var tween = get_tree().create_tween()
			tween.tween_property(sprite, "modulate:a", 1, 0.5)
			#tween.set_parallel(true)
			#$Sprite2D.modulate.a = 1
		$DryTimer.set_wait_time(wait_for_rain)


func _exit_tree() -> void:
	var level_root = _story_farmer_get_level_root()
	_story_farmer_reset_harvest_state(level_root)
	super._exit_tree()
