extends Node2D

#to run: python3 -m http.server  .. browse to localhost:8000

const LevelHelpersRef = preload("res://scenes/level_helpers.gd")
const PerfMonitorRef = preload("res://scenes/perf_monitor.gd")
const TEX_SQUASH = preload("res://graphics/squash.png")
const TEX_TREE = preload("res://graphics/acorn_32.png")
const TEX_MAIZE = preload("res://graphics/maize.png")
const TEX_BEAN = preload("res://graphics/bean.png")
const TEX_CLOUD = preload("res://graphics/cloud.png")
const TEX_MYCO = preload("res://graphics/mushroom_32.png")
const TEX_BANK = preload("res://graphics/bank.png")
const TEX_FARMER = preload("res://graphics/farmer.png")
const TEX_VENDOR = preload("res://graphics/mama.png")
const TEX_COOK = preload("res://graphics/cook.png")
const TEX_BASKET = preload("res://graphics/basket.png")
const DEFAULT_PARENT_BOUND_RADIUS_TILES := 4
const MYCO_HEALTHY_ANCHOR_RADIUS_TILES := 4
const STORY_WORLD_COLUMNS := 26
const STORY_WORLD_ROWS := 27
const STORY_START_TILE := Vector2i(3, 13)
const STORY_VILLAGE_RECT := Rect2i(16, 9, 10, 10)
const STORY_VILLAGE_REVEAL_DISTANCE := 4
const STORY_BIRD_SAFE_BUFFER := 6
const STORY_TUKTUK_START_PHASE := 5
const STORY_TUKTUK_SPAWN_RING_MIN := 1
const STORY_TUKTUK_SPAWN_RING_MAX := 2
const STORY_TUKTUK_TARGET_BUFFER := 4
const STORY_VILLAGER_COUNT_PER_ROLE := 3
const STORY_PHASE_MIN := 1
const STORY_PHASE_MAX := 6
const STORY_PHASE3_MYCO_NEAR_VILLAGER_RADIUS := 4
const STORY_VILLAGE_PERMANENT_REVEAL_BUFFER := 4
const STORY_PHASE5_OBJECTIVE_KEY := "village_everyone_trading"
const AMBIENT_TREE_AUDIO_RADIUS_TILES := 4.0
const AMBIENT_TREE_AUDIO_SILENT_DB := -36.0
const AMBIENT_TREE_AUDIO_FADE_SPEED_DB := 28.0
const STORY_GUIDANCE_RING_COLOR := Color(1.0, 0.96, 0.50, 1.0)
const STORY_GUIDANCE_RING_WIDTH := 3.0
const STORY_GUIDANCE_RING_PULSE_SPEED := 5.2
const STORY_GUIDANCE_RING_PAD := 6.0
const STORY_GUIDANCE_RING_REFRESH_SEC := 0.08
const STORY_PHASE2_HARVEST_RING_NAME := "StoryPhase2HarvestRing"
const STORY_PHASE1_REQUIRED_PLACED_TYPES := {
	"bean": true,
	"squash": true,
	"maize": true,
	"tree": true,
	"myco": true
}
const STORY_PHASE2_REQUIRED_INVENTORY_HARVEST_TYPES := {
	"bean": true,
	"squash": true,
	"maize": true,
	"tree": true,
	"myco": true
}
const STORY_PHASE4_REQUIRED_FARMER_DELIVERY_TYPES := {
	"bean": true,
	"squash": true,
	"maize": true,
	"tree": true,
	"myco": true
}

const PARENT_BOUNDED_TYPES := {
	"myco": true,
	"bean": true,
	"squash": true,
	"maize": true
}

var plant_scene: PackedScene = load("res://scenes/plant.tscn")
var trade_scene: PackedScene = load("res://scenes/trade.tscn")
var myco_scene: PackedScene = load("res://scenes/myco.tscn")
var cloud_scene: PackedScene = load("res://scenes/cloud.tscn")
var bird_scene: PackedScene = load("res://scenes/bird.tscn")
var tuktuk_scene: PackedScene = load("res://scenes/tuktuk.tscn")
var socialagent_scene: PackedScene = load("res://scenes/socialagent.tscn")
var basket_scene: PackedScene = load("res://scenes/basket.tscn")
var ui_scene: PackedScene = load("res://scenes/ui.tscn")


var mid_width = 0
var mid_height = 0

var health : int = 3

var score_lvl = 0

var num_maize = 1
var num_beans = 1
var num_squash = 1

var is_dragging = false
var delay = 10
var inventory_preview_lines: Array = []
var perf_monitor: Node = null
var _line_visual_refresh_accum := 0.0
var _dirty_refresh_accum := 0.0
var _dirty_buddies_agents: Dictionary = {}
var _dirty_lines_agents: Dictionary = {}
var _dirty_tile_hints_agents: Dictionary = {}
var _trade_pool: Array = []
var _shutdown_cleanup_done := false
var _story_village_revealed := false
var _story_village_center_world := Vector2.ZERO
var _story_progress_accum := 0.0
var _story_phase_id := 1
var _story_phase1_placed_types: Dictionary = {}
var _story_phase2_inventory_harvested_types: Dictionary = {}
var _story_phase3_myco_near_villager := false
var _story_phase4_farmer_delivery_types: Dictionary = {}
var _story_phase5_target_villager_ids: Dictionary = {}
var _story_phase5_traded_villager_ids: Dictionary = {}
var _story_phase5_all_villagers_trading := false
var _story_phase5_basket_placed := false
var _story_guidance_pulse_time := 0.0
var _story_guidance_refresh_accum := 0.0
var _ambient_tree_audio_base_db := 0.0
@onready var _bird_sound_player: AudioStreamPlayer2D = get_node_or_null("BirdSound")
@onready var _bird_long_player: AudioStreamPlayer = get_node_or_null("BirdLong")
@onready var _car_sound_player: AudioStreamPlayer2D = get_node_or_null("CarSound")
@onready var _squelch_sound_player: AudioStreamPlayer2D = get_node_or_null("SquelchSound")
@onready var _twinkle_sound_player: AudioStreamPlayer2D = get_node_or_null("TwinkleSound")
@onready var _bush_sound_player: AudioStreamPlayer2D = get_node_or_null("BushSound")


func _is_headless_runtime() -> bool:
	return DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server")


func _get_runtime_audio_players() -> Array:
	var players: Array = []
	for player in [
		_bird_sound_player,
		_bird_long_player,
		_car_sound_player,
		_squelch_sound_player,
		_twinkle_sound_player,
		_bush_sound_player
	]:
		if is_instance_valid(player):
			players.append(player)
	return players


func _mute_runtime_audio_if_headless() -> void:
	if not _is_headless_runtime():
		return
	LevelHelpersRef.stop_audio_players(_get_runtime_audio_players())


func _get_world_foundation() -> Node:
	return get_node_or_null("WorldFoundation")


func _get_world_center() -> Vector2:
	var world = _get_world_foundation()
	if is_instance_valid(world) and world.has_method("get_world_center"):
		return world.get_world_center()
	return Global.get_world_center(self)


func _set_tutorial_panel_color(color: Color) -> void:
	var helper_panel: Panel = get_node_or_null("UI/TutorialMarginContainer1/HelperPanel")
	if not is_instance_valid(helper_panel):
		return
	var style_box = helper_panel.get_theme_stylebox("panel")
	var helper_style := StyleBoxFlat.new()
	if style_box is StyleBoxFlat:
		var duplicated = (style_box as StyleBoxFlat).duplicate()
		if duplicated is StyleBoxFlat:
			helper_style = duplicated
	helper_style.bg_color = color
	helper_panel.add_theme_stylebox_override("panel", helper_style)


func _get_listener_world_position() -> Vector2:
	var camera = get_viewport().get_camera_2d()
	if is_instance_valid(camera):
		return camera.get_screen_center_position()
	return _get_world_center()


func _update_tree_ambient_audio(delta: float) -> void:
	if _is_headless_runtime():
		return
	if not is_instance_valid(_bird_long_player):
		return
	if not _bird_long_player.playing:
		_bird_long_player.play()
	var world = _get_world_foundation()
	var tile_size_world := 64.0
	if is_instance_valid(world):
		var raw_tile_size = float(world.get("tile_size"))
		if raw_tile_size > 0.0:
			tile_size_world = raw_tile_size
	var radius_world = maxf(tile_size_world * AMBIENT_TREE_AUDIO_RADIUS_TILES, 1.0)
	var listener_pos = _get_listener_world_position()
	var nearest_tree_dist := INF
	for agent in $Agents.get_children():
		if not is_instance_valid(agent):
			continue
		if bool(agent.get("dead")):
			continue
		if str(agent.get("type")) != "tree":
			continue
		var world_dist = listener_pos.distance_to(agent.global_position)
		if world_dist < nearest_tree_dist:
			nearest_tree_dist = world_dist
	var target_db = AMBIENT_TREE_AUDIO_SILENT_DB
	if nearest_tree_dist <= radius_world:
		var normalized = clampf(1.0 - (nearest_tree_dist / radius_world), 0.0, 1.0)
		target_db = lerpf(AMBIENT_TREE_AUDIO_SILENT_DB, _ambient_tree_audio_base_db, normalized)
	_bird_long_player.volume_db = move_toward(_bird_long_player.volume_db, target_db, AMBIENT_TREE_AUDIO_FADE_SPEED_DB * delta)


func _is_story_mode() -> bool:
	return str(Global.mode) == "story"


func _is_story_village_item_type(spawn_name: String) -> bool:
	return spawn_name == "farmer" or spawn_name == "vendor" or spawn_name == "cook" or spawn_name == "basket"


func _is_crop_type(agent_type: String) -> bool:
	return agent_type == "bean" or agent_type == "squash" or agent_type == "maize" or agent_type == "tree"


func _is_story_villager(agent: Variant) -> bool:
	if not is_instance_valid(agent):
		return false
	if not bool(agent.get_meta("story_villager", false)):
		return false
	return true


func _is_story_village_actor(agent: Variant) -> bool:
	if not is_instance_valid(agent):
		return false
	return bool(agent.get_meta("story_village_actor", false))


func _can_share_story_trade_network_nodes(node_a: Variant, node_b: Variant) -> bool:
	if not is_instance_valid(node_a) or not is_instance_valid(node_b):
		return false
	if not _is_story_mode():
		return true
	var a_is_village = _is_story_village_actor(node_a)
	var b_is_village = _is_story_village_actor(node_b)
	return a_is_village == b_is_village


func _is_ecology_myco_anchor(agent: Variant) -> bool:
	if not is_instance_valid(agent):
		return false
	if bool(agent.get("dead")):
		return false
	if str(agent.get("type")) != "myco":
		return false
	if _is_story_mode() and _is_story_village_actor(agent):
		return false
	return true


func _get_story_village_center_coord() -> Vector2i:
	return Vector2i(
		STORY_VILLAGE_RECT.position.x + int(STORY_VILLAGE_RECT.size.x / 2),
		STORY_VILLAGE_RECT.position.y + int(STORY_VILLAGE_RECT.size.y / 2)
	)


func _world_to_tile_coord(world: Node, world_pos: Vector2) -> Vector2i:
	if not _supports_world_tiles(world):
		return Vector2i.ZERO
	return _clamp_tile_coord(world, Vector2i(world.world_to_tile(world_pos)))


func _is_coord_in_story_village(coord: Vector2i) -> bool:
	return STORY_VILLAGE_RECT.has_point(coord)


func _tile_distance_to_rect(coord: Vector2i, rect: Rect2i) -> int:
	var dx := 0
	if coord.x < rect.position.x:
		dx = rect.position.x - coord.x
	elif coord.x >= rect.position.x + rect.size.x:
		dx = coord.x - (rect.position.x + rect.size.x - 1)
	var dy := 0
	if coord.y < rect.position.y:
		dy = rect.position.y - coord.y
	elif coord.y >= rect.position.y + rect.size.y:
		dy = coord.y - (rect.position.y + rect.size.y - 1)
	return maxi(dx, dy)


func _is_coord_in_story_village_buffer(coord: Vector2i, buffer_tiles: int) -> bool:
	return _tile_distance_to_rect(coord, STORY_VILLAGE_RECT) <= maxi(buffer_tiles, 0)


func _is_story_village_spawn_allowed(spawn_pos: Vector2) -> bool:
	var world = _get_world_foundation()
	if not _supports_world_tiles(world):
		return false
	var coord = _world_to_tile_coord(world, spawn_pos)
	return _is_coord_in_story_village(coord)


func get_story_tuktuk_spawn_position() -> Vector2:
	var world = _get_world_foundation()
	if not _supports_world_tiles(world):
		return _get_world_center()
	var candidates: Array = []
	var min_x = STORY_VILLAGE_RECT.position.x - STORY_TUKTUK_SPAWN_RING_MAX
	var min_y = STORY_VILLAGE_RECT.position.y - STORY_TUKTUK_SPAWN_RING_MAX
	var max_x = STORY_VILLAGE_RECT.position.x + STORY_VILLAGE_RECT.size.x - 1 + STORY_TUKTUK_SPAWN_RING_MAX
	var max_y = STORY_VILLAGE_RECT.position.y + STORY_VILLAGE_RECT.size.y - 1 + STORY_TUKTUK_SPAWN_RING_MAX
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var coord = Vector2i(x, y)
			if not world.in_bounds(coord):
				continue
			var dist = _tile_distance_to_rect(coord, STORY_VILLAGE_RECT)
			if dist < STORY_TUKTUK_SPAWN_RING_MIN or dist > STORY_TUKTUK_SPAWN_RING_MAX:
				continue
			candidates.append(coord)
	if candidates.is_empty():
		return world.tile_to_world_center(_clamp_tile_coord(world, _get_story_village_center_coord()))
	var choice = Vector2i(candidates[randi() % candidates.size()])
	return world.tile_to_world_center(choice)


func _story_set_prompt(text: String) -> void:
	$"UI/TutorialMarginContainer1".visible = true
	$"UI/TutorialMarginContainer1/Label".text = text
	_set_tutorial_panel_color(Global.stage_colors.get(1, Color(0.2, 0.4, 0.2, 0.8)))


func _story_reset_phase_state() -> void:
	_story_phase_id = STORY_PHASE_MIN
	_story_phase1_placed_types.clear()
	_story_phase2_inventory_harvested_types.clear()
	_story_phase3_myco_near_villager = false
	_story_phase4_farmer_delivery_types.clear()
	_story_phase5_target_villager_ids.clear()
	_story_phase5_traded_villager_ids.clear()
	_story_phase5_all_villagers_trading = false
	_story_phase5_basket_placed = false
	Global.village_objective_flags[STORY_PHASE5_OBJECTIVE_KEY] = false


func _set_story_phase(phase_id: int) -> void:
	if not _is_story_mode():
		return
	var safe_phase = clampi(phase_id, STORY_PHASE_MIN, STORY_PHASE_MAX)
	if safe_phase <= _story_phase_id:
		return
	var previous_phase = _story_phase_id
	_story_phase_id = safe_phase
	Global.story_chapter_id = maxi(Global.story_chapter_id, safe_phase)
	var fallback = str("Phase ", safe_phase, ": Continue restoring the village ecosystem.")
	_story_set_prompt(Global.story_stage_text.get(safe_phase, fallback))
	if previous_phase < 2 and _story_phase_id >= 2:
		# Birds are intentionally deferred until Phase 2 in story mode.
		_on_update_score()
	if safe_phase == 3:
		_story_phase3_myco_near_villager = false
	if safe_phase == 4:
		_story_phase4_farmer_delivery_types.clear()
	if safe_phase == 5:
		_story_reset_phase5_trading_progress()
	_story_sync_phase1_inventory_sparkle_targets()


func _story_is_phase1_required_placement_type(agent_type: String) -> bool:
	return STORY_PHASE1_REQUIRED_PLACED_TYPES.has(agent_type)


func _story_is_phase2_required_inventory_harvest_type(harvest_type: String) -> bool:
	return STORY_PHASE2_REQUIRED_INVENTORY_HARVEST_TYPES.has(harvest_type)


func _story_is_phase4_required_farmer_delivery_type(harvest_type: String) -> bool:
	return STORY_PHASE4_REQUIRED_FARMER_DELIVERY_TYPES.has(harvest_type)


func _story_has_all_required_types(tracked: Dictionary, required: Dictionary) -> bool:
	for required_type in required.keys():
		if not bool(tracked.get(required_type, false)):
			return false
	return true


func _story_collect_phase1_pending_placement_types() -> Dictionary:
	var pending: Dictionary = {}
	for required_type in STORY_PHASE1_REQUIRED_PLACED_TYPES.keys():
		if bool(_story_phase1_placed_types.get(required_type, false)):
			continue
		pending[str(required_type)] = true
	return pending


func _story_collect_phase2_pending_harvest_types() -> Dictionary:
	var pending: Dictionary = {}
	for required_type in STORY_PHASE2_REQUIRED_INVENTORY_HARVEST_TYPES.keys():
		if bool(_story_phase2_inventory_harvested_types.get(required_type, false)):
			continue
		pending[str(required_type)] = true
	return pending


func _story_is_phase5_basket_inventory_guidance_active() -> bool:
	if not _is_story_mode() or _story_phase_id != 5:
		return false
	return int(Global.inventory.get("basket", 0)) > 0


func _story_sync_phase1_inventory_sparkle_targets() -> void:
	var ui_node = get_node_or_null("UI")
	if not is_instance_valid(ui_node):
		return
	var phase1_active = _is_story_mode() and _story_phase_id == 1
	var phase1_pending: Dictionary = {}
	if phase1_active:
		phase1_pending = _story_collect_phase1_pending_placement_types()
	var phase5_basket_active = _story_is_phase5_basket_inventory_guidance_active()
	if ui_node.has_method("set_story_inventory_sparkle_targets"):
		ui_node.set_story_inventory_sparkle_targets(phase1_active, phase1_pending, phase5_basket_active)
		return
	if ui_node.has_method("set_story_phase1_inventory_sparkle_targets"):
		ui_node.set_story_phase1_inventory_sparkle_targets(phase1_active, phase1_pending)


func _hide_story_phase2_harvest_guidance_ring(agent: Node) -> void:
	if not is_instance_valid(agent):
		return
	var ring: Line2D = agent.get_node_or_null(STORY_PHASE2_HARVEST_RING_NAME) as Line2D
	if is_instance_valid(ring):
		ring.visible = false


func _ensure_story_phase2_harvest_guidance_ring(agent: Node) -> Line2D:
	if not is_instance_valid(agent):
		return null
	var existing = agent.get_node_or_null(STORY_PHASE2_HARVEST_RING_NAME)
	var existing_ring: Line2D = existing as Line2D
	if is_instance_valid(existing_ring):
		return existing_ring
	if is_instance_valid(existing):
		existing.queue_free()
	var ring := Line2D.new()
	ring.name = STORY_PHASE2_HARVEST_RING_NAME
	ring.width = STORY_GUIDANCE_RING_WIDTH
	ring.antialiased = true
	ring.z_as_relative = false
	ring.z_index = 120
	ring.default_color = STORY_GUIDANCE_RING_COLOR
	ring.visible = false
	agent.add_child(ring)
	return ring


func _update_story_phase2_harvest_guidance_ring_shape(agent: Node, ring: Line2D) -> void:
	if not is_instance_valid(agent) or not is_instance_valid(ring):
		return
	var sprite = agent.get_node_or_null("Sprite2D")
	if not (sprite is Sprite2D):
		ring.visible = false
		return
	var sprite_node: Sprite2D = sprite
	if not is_instance_valid(sprite_node.texture):
		ring.visible = false
		return
	var guide_rect = Rect2()
	if agent.has_method("get_story_harvest_guidance_rect_local"):
		var candidate = agent.get_story_harvest_guidance_rect_local()
		if candidate is Rect2:
			guide_rect = candidate
	if guide_rect.size.x <= 0.001 or guide_rect.size.y <= 0.001:
		guide_rect = sprite_node.get_rect()
	var scaled_rect: Rect2 = guide_rect * Transform2D(0, sprite_node.scale, 0, Vector2.ZERO)
	var left = sprite_node.position.x + scaled_rect.position.x - STORY_GUIDANCE_RING_PAD
	var top = sprite_node.position.y + scaled_rect.position.y - STORY_GUIDANCE_RING_PAD
	var right = left + scaled_rect.size.x + STORY_GUIDANCE_RING_PAD * 2.0
	var bottom = top + scaled_rect.size.y + STORY_GUIDANCE_RING_PAD * 2.0
	ring.clear_points()
	ring.add_point(Vector2(left, top))
	ring.add_point(Vector2(right, top))
	ring.add_point(Vector2(right, bottom))
	ring.add_point(Vector2(left, bottom))
	ring.add_point(Vector2(left, top))


func _update_story_phase2_harvest_guidance_ring_visual(agent: Node, ring: Line2D) -> void:
	if not is_instance_valid(agent) or not is_instance_valid(ring):
		return
	var phase_offset = float(int(agent.get_instance_id()) % 19) * 0.33
	var pulse = 0.42 + 0.58 * (0.5 + 0.5 * sin(_story_guidance_pulse_time * STORY_GUIDANCE_RING_PULSE_SPEED + phase_offset))
	ring.width = STORY_GUIDANCE_RING_WIDTH + pulse * 1.35
	ring.default_color = Color(STORY_GUIDANCE_RING_COLOR.r, STORY_GUIDANCE_RING_COLOR.g, STORY_GUIDANCE_RING_COLOR.b, 0.38 + pulse * 0.62)


func _should_show_story_phase2_harvest_guidance(agent: Node, pending_types: Dictionary) -> bool:
	if not is_instance_valid(agent):
		return false
	if bool(agent.get("dead")):
		return false
	var crop_type = str(agent.get("type"))
	if crop_type == "":
		return false
	if not bool(pending_types.get(crop_type, false)):
		return false
	if not agent.has_method("can_drag_for_inventory_harvest"):
		return false
	return bool(agent.can_drag_for_inventory_harvest())


func _refresh_story_phase2_harvest_guidance_visuals(delta: float) -> void:
	_story_guidance_pulse_time += maxf(delta, 0.0)
	_story_guidance_refresh_accum += maxf(delta, 0.0)
	var refresh_shape = _story_guidance_refresh_accum >= STORY_GUIDANCE_RING_REFRESH_SEC
	if refresh_shape:
		_story_guidance_refresh_accum = 0.0
	var phase2_active = _is_story_mode() and _story_phase_id == 2
	var pending_types: Dictionary = {}
	if phase2_active:
		pending_types = _story_collect_phase2_pending_harvest_types()
	if not phase2_active or pending_types.is_empty():
		for agent in $Agents.get_children():
			_hide_story_phase2_harvest_guidance_ring(agent)
		return
	for agent in $Agents.get_children():
		if not _should_show_story_phase2_harvest_guidance(agent, pending_types):
			_hide_story_phase2_harvest_guidance_ring(agent)
			continue
		var ring = _ensure_story_phase2_harvest_guidance_ring(agent)
		if not is_instance_valid(ring):
			continue
		if refresh_shape or ring.get_point_count() < 5:
			_update_story_phase2_harvest_guidance_ring_shape(agent, ring)
		if ring.get_point_count() < 5:
			ring.visible = false
			continue
		_update_story_phase2_harvest_guidance_ring_visual(agent, ring)
		ring.visible = true


func _story_collect_villager_ids() -> Dictionary:
	var ids: Dictionary = {}
	for agent in $Agents.get_children():
		if not _is_story_villager(agent):
			continue
		ids[int(agent.get_instance_id())] = true
	return ids


func _story_reset_phase5_trading_progress() -> void:
	_story_phase5_target_villager_ids = _story_collect_villager_ids()
	_story_phase5_traded_villager_ids.clear()
	_story_phase5_all_villagers_trading = false
	Global.village_objective_flags[STORY_PHASE5_OBJECTIVE_KEY] = false


func _story_mark_phase5_villager_trade(agent: Variant) -> void:
	if not _is_story_villager(agent):
		return
	var key = int(agent.get_instance_id())
	if not bool(_story_phase5_target_villager_ids.get(key, false)):
		return
	_story_phase5_traded_villager_ids[key] = true


func _story_update_phase5_trading_completion() -> void:
	if _story_phase_id < 5:
		return
	if _story_phase5_target_villager_ids.is_empty():
		_story_phase5_target_villager_ids = _story_collect_villager_ids()
	if _story_phase5_target_villager_ids.is_empty():
		return
	for villager_id in _story_phase5_target_villager_ids.keys():
		if not bool(_story_phase5_traded_villager_ids.get(villager_id, false)):
			return
	_story_phase5_all_villagers_trading = true
	Global.village_objective_flags[STORY_PHASE5_OBJECTIVE_KEY] = true


func _is_story_myco_near_any_villager(world_pos: Vector2) -> bool:
	if not _is_story_mode() or not _story_village_revealed:
		return false
	var world = _get_world_foundation()
	if not _supports_world_tiles(world):
		return false
	var myco_coord = _world_to_tile_coord(world, world_pos)
	for agent in $Agents.get_children():
		if not _is_story_villager(agent):
			continue
		var villager_coord = _world_to_tile_coord(world, agent.global_position)
		if _tile_chebyshev_distance(myco_coord, villager_coord) <= STORY_PHASE3_MYCO_NEAR_VILLAGER_RADIUS:
			return true
	return false


func _story_try_advance_phase_milestones() -> void:
	if not _is_story_mode():
		return
	if _story_phase_id == 1:
		if _story_has_all_required_types(_story_phase1_placed_types, STORY_PHASE1_REQUIRED_PLACED_TYPES):
			_set_story_phase(2)
	if _story_phase_id == 2:
		if _story_has_all_required_types(_story_phase2_inventory_harvested_types, STORY_PHASE2_REQUIRED_INVENTORY_HARVEST_TYPES):
			_set_story_phase(3)
	if _story_phase_id == 3:
		if _story_phase3_myco_near_villager:
			_set_story_phase(4)
	if _story_phase_id == 4:
		if not _story_phase4_farmer_delivery_types.is_empty():
			_set_story_phase(5)
	if _story_phase_id == 5:
		_story_update_phase5_trading_completion()
		if _story_phase5_all_villagers_trading:
			_set_story_phase(6)


func _story_refresh_hud() -> void:
	var ui_node = get_node_or_null("UI")
	if not is_instance_valid(ui_node):
		return
	if not _is_story_mode():
		if ui_node.has_method("set_village_inventory_unlocked"):
			ui_node.set_village_inventory_unlocked(false)
		if ui_node.has_method("set_story_village_marker"):
			ui_node.set_story_village_marker(Vector2.ZERO, false)
		if ui_node.has_method("refresh_inventory_counts"):
			ui_node.refresh_inventory_counts()
		_story_sync_phase1_inventory_sparkle_targets()
		return
	if ui_node.has_method("set_village_inventory_unlocked"):
		ui_node.set_village_inventory_unlocked(_story_village_revealed)
	if ui_node.has_method("set_story_village_marker"):
		ui_node.set_story_village_marker(_story_village_center_world, not _story_village_revealed)
	if ui_node.has_method("refresh_inventory_counts"):
		ui_node.refresh_inventory_counts()
	_story_sync_phase1_inventory_sparkle_targets()


func _find_story_farmer_at_world_pos(world_pos: Vector2) -> Node:
	var world = _get_world_foundation()
	if not _supports_world_tiles(world):
		return null
	var coord = _world_to_tile_coord(world, world_pos)
	var best_farmer: Node = null
	var best_dist := INF
	for agent in $Agents.get_children():
		if not _is_story_villager(agent):
			continue
		if str(agent.get("type")) != "farmer":
			continue
		var agent_coord = _world_to_tile_coord(world, agent.global_position)
		if agent_coord == coord:
			return agent
		if _tile_chebyshev_distance(agent_coord, coord) > 1:
			continue
		var world_dist = agent.global_position.distance_squared_to(world_pos)
		if world_dist < best_dist:
			best_dist = world_dist
			best_farmer = agent
	return best_farmer


func _refill_story_farmer_n_resource(target_farmer: Node) -> void:
	if not is_instance_valid(target_farmer):
		return
	var needs_data = target_farmer.get("needs")
	var assets_data = target_farmer.get("assets")
	if typeof(needs_data) != TYPE_DICTIONARY or typeof(assets_data) != TYPE_DICTIONARY:
		return
	var needs: Dictionary = needs_data
	var assets: Dictionary = assets_data
	var n_need = int(needs.get("N", 10))
	if n_need <= 0:
		n_need = 10
	var n_cap = maxi(n_need * 2, 0)
	assets["N"] = n_cap
	target_farmer.set("assets", assets)
	var bars_data = target_farmer.get("bars")
	if typeof(bars_data) != TYPE_DICTIONARY:
		return
	var bars: Dictionary = bars_data
	var n_bar = bars.get("N", null)
	if is_instance_valid(n_bar):
		n_bar.value = n_cap


func can_agent_harvest_to_inventory(agent: Node) -> bool:
	if not _is_story_mode() or not _story_village_revealed:
		return true
	if not is_instance_valid(agent):
		return true
	if not _is_crop_type(str(agent.get("type"))):
		return true
	return false


func try_story_harvest_drop(agent: Node, world_pos: Vector2) -> bool:
	if not _is_story_mode() or not _story_village_revealed:
		return false
	if _story_phase_id < 4:
		return false
	if not is_instance_valid(agent):
		return false
	if not _story_is_phase4_required_farmer_delivery_type(str(agent.get("type"))):
		return false
	var target_farmer = _find_story_farmer_at_world_pos(world_pos)
	if not is_instance_valid(target_farmer):
		return false
	if not agent.has_method("try_harvest_to_farmer"):
		return false
	var harvested = bool(agent.try_harvest_to_farmer(target_farmer))
	if harvested:
		# Story farmer deliveries refill the farmer's actual N resource bar.
		_refill_story_farmer_n_resource(target_farmer)
		_story_try_advance_phase_milestones()
	return harvested


func try_story_inventory_delivery(item_type: String, world_pos: Vector2) -> bool:
	if not _is_story_mode() or not _story_village_revealed:
		return false
	if _story_phase_id < 4:
		return false
	var normalized_type = str(item_type)
	if not _story_is_phase4_required_farmer_delivery_type(normalized_type):
		return false
	var target_farmer = _find_story_farmer_at_world_pos(world_pos)
	if not is_instance_valid(target_farmer):
		return false
	_story_phase4_farmer_delivery_types[normalized_type] = true
	# Story farmer deliveries refill the farmer's actual N resource bar.
	_refill_story_farmer_n_resource(target_farmer)
	_story_try_advance_phase_milestones()
	return true


func can_place_inventory_item_at_world_pos(item_name: String, world_pos: Vector2) -> bool:
	var spawn_name = str(item_name)
	if spawn_name == "":
		return false
	if int(Global.inventory.get(spawn_name, 0)) <= 0:
		return false
	var world = _get_world_foundation()
	if not _supports_world_tiles(world):
		return false
	var coord = _clamp_tile_coord(world, Vector2i(world.world_to_tile(world_pos)))
	var target_pos = world.tile_to_world_center(coord)
	var story_village_item = _is_story_village_item_type(spawn_name)
	if _is_story_mode() and story_village_item:
		if not _story_village_revealed:
			return false
		if not _is_story_village_spawn_allowed(target_pos):
			return false
	if _is_story_mode() and not story_village_item:
		if _story_village_revealed and _story_phase_id >= 4 and _story_is_phase4_required_farmer_delivery_type(spawn_name):
			if is_instance_valid(_find_story_farmer_at_world_pos(target_pos)):
				return true
	if world.has_method("is_world_pos_revealed") and not bool(world.is_world_pos_revealed(target_pos)):
		return false
	if _is_parent_bounded_spawn_type(spawn_name):
		var parent_anchor = _find_nearest_living_myco_anchor(target_pos)
		if not _is_valid_parent_anchor(parent_anchor):
			return false
		var parent_coord = _clamp_tile_coord(world, Vector2i(world.world_to_tile(parent_anchor.global_position)))
		if _tile_chebyshev_distance(coord, parent_coord) > DEFAULT_PARENT_BOUND_RADIUS_TILES:
			return false
		if LevelHelpersRef.is_tile_occupied(self, $Agents, coord):
			return false
	elif spawn_name == "tree":
		# Acorn/tree footprint in plants mode is two vertical tiles:
		# base tile + tile above.
		var upper_coord = coord + Vector2i(0, -1)
		if not world.in_bounds(upper_coord):
			return false
		if LevelHelpersRef.is_tile_occupied(self, $Agents, coord):
			return false
		if LevelHelpersRef.is_tile_occupied(self, $Agents, upper_coord):
			return false
	else:
		var exact_spawn = _resolve_exact_tile_spawn_pos(target_pos)
		if not bool(exact_spawn.get("ok", false)):
			return false
	if spawn_name == "myco":
		var myco_gate = _validate_myco_spawn(target_pos)
		if not bool(myco_gate.get("ok", false)):
			return false
	return true


func is_valid_predator_target(predator: Node, candidate: Node) -> bool:
	if not is_instance_valid(predator) or not is_instance_valid(candidate):
		return false
	if bool(candidate.get("dead")):
		return false
	var c_type = str(candidate.get("type"))
	if predator is Bird and c_type == "tree":
		return false
	if not _is_story_mode():
		return c_type == str(predator.get("quarry_type"))
	var world = _get_world_foundation()
	if predator is Bird:
		if not _is_crop_type(c_type):
			return false
		if _supports_world_tiles(world):
			var coord = _world_to_tile_coord(world, candidate.global_position)
			if _is_coord_in_story_village_buffer(coord, STORY_BIRD_SAFE_BUFFER):
				return false
		return true
	if predator is Tuktuk:
		if _story_phase_id < STORY_TUKTUK_START_PHASE:
			return false
		if not _is_story_villager(candidate):
			return false
		if _supports_world_tiles(world):
			var villager_coord = _world_to_tile_coord(world, candidate.global_position)
			if not _is_coord_in_story_village_buffer(villager_coord, STORY_TUKTUK_TARGET_BUFFER):
				return false
		return true
	return false


func _resolve_tile_spawn_pos(pos: Vector2) -> Vector2:
	return LevelHelpersRef.resolve_snapped_spawn_position(self, $Agents, pos)


func _resolve_exact_tile_spawn_pos(pos: Vector2, ignore_agent: Variant = null) -> Dictionary:
	var result := {
		"ok": true,
		"pos": pos
	}
	var world = _get_world_foundation()
	if not is_instance_valid(world):
		return result
	if not (world.has_method("world_to_tile") and world.has_method("tile_to_world_center") and world.has_method("in_bounds")):
		return result
	var coord = Vector2i(world.world_to_tile(pos))
	if not world.in_bounds(coord):
		result["ok"] = false
		return result
	if LevelHelpersRef.is_tile_occupied(self, $Agents, coord, ignore_agent):
		result["ok"] = false
		return result
	result["pos"] = world.tile_to_world_center(coord)
	return result


func _find_replaceable_agent_at_world_pos(pos: Vector2, ignore_agent: Variant = null) -> Node:
	var world = _get_world_foundation()
	if not is_instance_valid(world):
		return null
	if not (world.has_method("world_to_tile") and world.has_method("tile_to_world_center") and world.has_method("in_bounds")):
		return null
	var coord = Vector2i(world.world_to_tile(pos))
	if not world.in_bounds(coord):
		return null
	for agent in $Agents.get_children():
		if not is_instance_valid(agent):
			continue
		if is_instance_valid(ignore_agent) and agent == ignore_agent:
			continue
		if bool(agent.get("dead")):
			continue
		if str(agent.get("type")) == "cloud":
			continue
		if not bool(agent.get("killable")):
			continue
		var occupied_tiles = LevelHelpersRef.get_agent_occupied_tiles(self, agent)
		if occupied_tiles.has(coord):
			return agent
	return null


func _supports_world_tiles(world: Node) -> bool:
	if not is_instance_valid(world):
		return false
	return world.has_method("world_to_tile") and world.has_method("tile_to_world_center") and world.has_method("in_bounds")


func _clamp_tile_coord(world: Node, coord: Vector2i) -> Vector2i:
	var columns = max(int(world.get("columns")), 1)
	var rows = max(int(world.get("rows")), 1)
	return Vector2i(
		clampi(coord.x, 0, columns - 1),
		clampi(coord.y, 0, rows - 1)
	)


func _tile_pos_from_center(world: Node, center: Vector2i, delta: Vector2i) -> Vector2:
	var coord = _clamp_tile_coord(world, center + delta)
	return world.tile_to_world_center(coord)


func _is_parent_bounded_spawn_type(spawn_name: String) -> bool:
	return PARENT_BOUNDED_TYPES.has(spawn_name)


func _tile_chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(abs(a.x - b.x), abs(a.y - b.y))


func _is_valid_parent_anchor(anchor: Variant, ignore_agent: Variant = null) -> bool:
	if not _is_ecology_myco_anchor(anchor):
		return false
	if is_instance_valid(ignore_agent) and anchor == ignore_agent:
		return false
	return true


func _find_nearest_living_myco_anchor(spawn_pos: Vector2, ignore_agent: Variant = null) -> Node:
	var world = _get_world_foundation()
	var best_anchor: Node = null
	var best_dist := INF
	if _supports_world_tiles(world):
		var target_coord = _clamp_tile_coord(world, Vector2i(world.world_to_tile(spawn_pos)))
		for agent in $Agents.get_children():
			if not _is_valid_parent_anchor(agent, ignore_agent):
				continue
			var coord = _clamp_tile_coord(world, Vector2i(world.world_to_tile(agent.global_position)))
			var dist = float(_tile_chebyshev_distance(coord, target_coord))
			if dist < best_dist:
				best_dist = dist
				best_anchor = agent
		return best_anchor
	for agent in $Agents.get_children():
		if not _is_valid_parent_anchor(agent, ignore_agent):
			continue
		var dist = agent.global_position.distance_to(spawn_pos)
		if dist < best_dist:
			best_dist = dist
			best_anchor = agent
	return best_anchor


func _find_parent_bounded_open_tile(world: Node, start_coord: Vector2i, parent_coord: Vector2i, max_parent_tiles: int, ignore_agent: Variant = null) -> Vector2i:
	var safe_max = maxi(max_parent_tiles, 0)
	if safe_max <= 0:
		return Vector2i(-1, -1)
	var columns = max(int(world.get("columns")), 1)
	var rows = max(int(world.get("rows")), 1)
	var max_search = maxi(columns, rows)
	for radius in range(0, max_search + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if radius > 0 and abs(dx) != radius and abs(dy) != radius:
					continue
				var coord = start_coord + Vector2i(dx, dy)
				if not world.in_bounds(coord):
					continue
				if _tile_chebyshev_distance(coord, parent_coord) > safe_max:
					continue
				if LevelHelpersRef.is_tile_occupied(self, $Agents, coord, ignore_agent):
					continue
				return coord
	return Vector2i(-1, -1)


func _resolve_parent_bounded_spawn_pos(spawn_pos: Vector2, parent_anchor: Variant, max_parent_tiles: int, ignore_agent: Variant = null, require_exact_tile: bool = false) -> Dictionary:
	var result := {
		"ok": false,
		"pos": spawn_pos,
		"coord": Vector2i(-1, -1),
		"parent_coord": Vector2i(-1, -1)
	}
	var world = _get_world_foundation()
	if not _supports_world_tiles(world):
		result["ok"] = _is_valid_parent_anchor(parent_anchor, ignore_agent)
		return result
	if not _is_valid_parent_anchor(parent_anchor, ignore_agent):
		return result
	var safe_max = maxi(max_parent_tiles, 0)
	if safe_max <= 0:
		return result

	var desired_coord = _clamp_tile_coord(world, Vector2i(world.world_to_tile(spawn_pos)))
	var parent_coord = _clamp_tile_coord(world, Vector2i(world.world_to_tile(parent_anchor.global_position)))
	result["parent_coord"] = parent_coord
	var desired_in_range = _tile_chebyshev_distance(desired_coord, parent_coord) <= safe_max
	var resolved_coord = Vector2i(-1, -1)

	if desired_in_range:
		if require_exact_tile:
			if not LevelHelpersRef.is_tile_occupied(self, $Agents, desired_coord, ignore_agent):
				resolved_coord = desired_coord
		else:
			if not LevelHelpersRef.is_tile_occupied(self, $Agents, desired_coord, ignore_agent):
				resolved_coord = desired_coord
			else:
				resolved_coord = _find_parent_bounded_open_tile(world, desired_coord, parent_coord, safe_max, ignore_agent)
	else:
		resolved_coord = _find_parent_bounded_open_tile(world, desired_coord, parent_coord, safe_max, ignore_agent)

	if resolved_coord.x < 0 or resolved_coord.y < 0:
		return result
	result["ok"] = true
	result["coord"] = resolved_coord
	result["pos"] = world.tile_to_world_center(resolved_coord)
	return result


func _refund_inventory_item(agent_name: String, amount: int = 1) -> void:
	if agent_name == "":
		return
	var safe_amount = maxi(amount, 0)
	if safe_amount <= 0:
		return
	var ui_node = get_node_or_null("UI")
	if is_instance_valid(ui_node) and ui_node.has_method("refund_inventory_item"):
		ui_node.refund_inventory_item(agent_name, safe_amount)
		return
	Global.inventory[agent_name] = int(Global.inventory.get(agent_name, 0)) + safe_amount


func _connect_lifecycle_residue_signal(agent: Node) -> void:
	if not is_instance_valid(agent):
		return
	if not agent.has_signal("lifecycle_residue"):
		return
	var target = Callable(self, "_on_agent_lifecycle_residue")
	if agent.is_connected("lifecycle_residue", target):
		return
	agent.connect("lifecycle_residue", target)


func _connect_harvest_committed_signal(agent: Node) -> void:
	if not is_instance_valid(agent):
		return
	if not agent.has_signal("harvest_committed"):
		return
	var target = Callable(self, "_on_agent_harvest_committed")
	if agent.is_connected("harvest_committed", target):
		return
	agent.connect("harvest_committed", target)


func _on_agent_harvest_committed(harvest_type: String, destination: String) -> void:
	if not _is_story_mode():
		return
	var normalized_type = str(harvest_type)
	if destination == "inventory" and _story_is_phase2_required_inventory_harvest_type(normalized_type):
		_story_phase2_inventory_harvested_types[normalized_type] = true
	if destination == "farmer" and _story_phase_id >= 4 and _story_is_phase4_required_farmer_delivery_type(normalized_type):
		_story_phase4_farmer_delivery_types[normalized_type] = true
	_story_try_advance_phase_milestones()
	_story_sync_phase1_inventory_sparkle_targets()


func _count_living_myco(ignore_agent: Variant = null) -> int:
	var total := 0
	for agent in $Agents.get_children():
		if is_instance_valid(ignore_agent) and agent == ignore_agent:
			continue
		if not _is_ecology_myco_anchor(agent):
			continue
		total += 1
	return total


func _find_healthy_myco_anchor_in_radius(world: Node, coord: Vector2i, max_radius_tiles: int, ignore_agent: Variant = null) -> Node:
	var safe_radius = maxi(max_radius_tiles, 0)
	var best_anchor: Node = null
	var best_dist := INF
	for agent in $Agents.get_children():
		if is_instance_valid(ignore_agent) and agent == ignore_agent:
			continue
		if not _is_ecology_myco_anchor(agent):
			continue
		var myco_coord = Vector2i(world.world_to_tile(agent.global_position))
		if not world.in_bounds(myco_coord):
			continue
		var dist = maxi(abs(myco_coord.x - coord.x), abs(myco_coord.y - coord.y))
		if dist > safe_radius:
			continue
		var myco_tile = world.get_tile(myco_coord)
		if myco_tile.is_empty():
			continue
		if int(myco_tile.get("stage", 0)) < 3:
			continue
		if float(dist) < best_dist:
			best_dist = float(dist)
			best_anchor = agent
	return best_anchor


func _validate_myco_spawn(spawn_pos: Vector2, ignore_agent: Variant = null) -> Dictionary:
	var result := {
		"ok": false,
		"coord": Vector2i(-1, -1),
		"anchor": null
	}
	var world = _get_world_foundation()
	if not is_instance_valid(world):
		result["ok"] = true
		return result
	if not (world.has_method("world_to_tile") and world.has_method("tile_to_world_center") and world.has_method("in_bounds")):
		result["ok"] = true
		return result

	var coord = Vector2i(world.world_to_tile(spawn_pos))
	result["coord"] = coord
	if not world.in_bounds(coord):
		return result
	if LevelHelpersRef.is_tile_occupied(self, $Agents, coord, ignore_agent):
		return result
	if world.has_method("can_place_myco_on_tile"):
		if not bool(world.call("can_place_myco_on_tile", coord)):
			return result
	else:
		var tile = world.get_tile(coord)
		if tile.is_empty() or int(tile.get("stage", 0)) < 2:
			return result

	if _count_living_myco(ignore_agent) <= 0:
		result["ok"] = true
		return result

	var anchor = _find_healthy_myco_anchor_in_radius(world, coord, MYCO_HEALTHY_ANCHOR_RADIUS_TILES, ignore_agent)
	if not is_instance_valid(anchor):
		return result
	result["ok"] = true
	result["anchor"] = anchor
	return result


func _agent_key(agent: Variant) -> int:
	if not is_instance_valid(agent):
		return -1
	return int(agent.get_instance_id())


func request_agent_dirty(agent: Variant, buddies: bool = true, lines: bool = true, tile_hint: bool = false) -> void:
	var key = _agent_key(agent)
	if key < 0:
		return
	if buddies:
		_dirty_buddies_agents[key] = agent
	if lines and str(agent.get("type")) != "cloud":
		_dirty_lines_agents[key] = agent
	if tile_hint:
		_dirty_tile_hints_agents[key] = agent


func request_all_agents_dirty() -> void:
	for agent in $Agents.get_children():
		request_agent_dirty(agent, true, true, false)


func mark_agent_moved(agent: Variant, old_pos: Vector2, new_pos: Vector2) -> void:
	LevelHelpersRef.mark_agents_dirty_for_movement(self, $Agents, agent, old_pos, new_pos)
	LevelHelpersRef.sync_agent_occupancy(self, agent)


func _process_dirty_queues() -> void:
	if _dirty_buddies_agents.is_empty() and _dirty_lines_agents.is_empty() and _dirty_tile_hints_agents.is_empty():
		return
	for key in _dirty_buddies_agents.keys():
		var agent = _dirty_buddies_agents[key]
		if not is_instance_valid(agent):
			continue
		if bool(agent.get("dead")):
			continue
		if agent.has_method("generate_buddies"):
			agent.generate_buddies()
	for key in _dirty_tile_hints_agents.keys():
		var agent = _dirty_tile_hints_agents[key]
		if not is_instance_valid(agent):
			continue
		if bool(agent.get("dead")):
			continue
		if agent.has_method("_update_drag_tile_hint"):
			var pos = agent.get("position")
			if typeof(pos) == TYPE_VECTOR2:
				agent._update_drag_tile_hint(pos)

	if Global.draw_lines and not _dirty_lines_agents.is_empty():
		LevelHelpersRef.sync_myco_trade_lines($Lines, $Agents, false, _dirty_lines_agents.values())

	_dirty_buddies_agents.clear()
	_dirty_lines_agents.clear()
	_dirty_tile_hints_agents.clear()


func _setup_perf_monitor() -> void:
	if is_instance_valid(perf_monitor):
		return
	perf_monitor = PerfMonitorRef.new()
	perf_monitor.name = "PerfMonitor"
	perf_monitor.overlay_enabled = false
	perf_monitor.adaptive_quality_enabled = true
	perf_monitor.log_to_files = Global.perf_metrics_enabled
	add_child(perf_monitor)
	perf_monitor.configure(self, $Agents, $Trades, $Lines, _get_world_foundation())


func _recycle_trade(trade: Node) -> void:
	if not is_instance_valid(trade):
		return
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
	_trade_pool.append(trade)


func _ready():
	#get_tree().call_group('ui','set_health',health)
	#var num_maize = $Agents.get_children().size()
	#if num_maize <= 5:
	#var uix = ui_scene.instantiate()
	#uix.connect('new_agent',_on_new_agent)
	$UI.connect('new_agent',_on_new_agent)
	$UI.connect("inventory_drag_preview", _on_inventory_drag_preview)
	$UI.connect("request_back_to_menu", _on_ui_request_back_to_menu)
	$UI.setup()
	_mute_runtime_audio_if_headless()
	_setup_perf_monitor()
	Global.prevent_auto_select = false
	DisplayServer.window_set_title("Social Soil Gardening")
	if is_instance_valid(_bird_long_player):
		_ambient_tree_audio_base_db = _bird_long_player.volume_db
		_bird_long_player.volume_db = AMBIENT_TREE_AUDIO_SILENT_DB
		if not _is_headless_runtime():
			_bird_long_player.play()
	var world = _get_world_foundation()
	if _is_story_mode() and is_instance_valid(world) and world.has_method("configure_dimensions"):
		world.configure_dimensions(STORY_WORLD_COLUMNS, STORY_WORLD_ROWS)
	if is_instance_valid(world) and world.has_method("set_context"):
		world.set_context(Global.mode, "plants")
	#$BirdLong.
	if is_instance_valid(world) and _supports_world_tiles(world):
		_story_village_center_world = world.tile_to_world_center(_get_story_village_center_coord())

	$"UI/TutorialMarginContainer1".visible = false
	if _is_story_mode():
		_story_reset_phase_state()
		_story_set_prompt(Global.story_stage_text.get(1, "Place crops and myco from inventory to start restoring soil."))
		Global.story_chapter_id = STORY_PHASE_MIN
		Global.village_revealed = false
		_story_village_revealed = false
		if is_instance_valid(world) and world.has_method("clear_permanent_reveal"):
			world.clear_permanent_reveal()
		_story_refresh_hud()
		_story_sync_phase1_inventory_sparkle_targets()
	elif Global.mode == "tutorial":
		$"UI/TutorialMarginContainer1".visible = true
		$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
		_set_tutorial_panel_color(Global.stage_colors[Global.stage])
	else:
		_story_sync_phase1_inventory_sparkle_targets()

	var world_center = _get_world_center()
	mid_width = int(world_center.x)
	mid_height = int(world_center.y)

	var myco = null
	var clustered_start = _is_story_mode() or Global.mode == "tutorial" or Global.mode == "challenge"
	if clustered_start and _supports_world_tiles(world):
		var center_coord = _clamp_tile_coord(world, Vector2i(world.world_to_tile(world_center)))
		if _is_story_mode():
			center_coord = _clamp_tile_coord(world, STORY_START_TILE)
		var myco_position = _tile_pos_from_center(world, center_coord, Vector2i(0, 0))
		var bean_position = _tile_pos_from_center(world, center_coord, Vector2i(-1, 0))
		var squash_position = _tile_pos_from_center(world, center_coord, Vector2i(0, -1))
		var maize_position = _tile_pos_from_center(world, center_coord, Vector2i(0, 1))
		var tree_position = _tile_pos_from_center(world, center_coord, Vector2i(1, 0))

		myco = make_myco(myco_position)
		make_bean(bean_position)
		make_squash(squash_position)
		make_maize(maize_position)
		make_tree(tree_position)
	else:
		var maize_center_offset_x = 75
		var maize_center_offset_y = 65
		var maize_position = Vector2(mid_width + maize_center_offset_x, mid_height + maize_center_offset_y)
		make_maize(maize_position)

		var bean_center_offset_x = -75
		var bean_center_offset_y = 0
		var bean_position = Vector2(mid_width + bean_center_offset_x, mid_height + bean_center_offset_y)
		make_bean(bean_position)

		var squash_center_offset_x = 0
		var squash_center_offset_y = -90
		var squash_position = Vector2(mid_width + squash_center_offset_x, mid_height + squash_center_offset_y)
		make_squash(squash_position)

		var tree_center_offset_x = 75
		var tree_center_offset_y = -50
		var tree_position = Vector2(mid_width + tree_center_offset_x, mid_height + tree_center_offset_y)
		make_tree(tree_position)

		var myco_width = mid_width + 40
		var myco_height = mid_height + 100
		var myco_position = Vector2(myco_width, myco_height)
		myco = make_myco(myco_position)

	Global.active_agent = myco
	if _is_story_mode() and is_instance_valid(myco) and is_instance_valid(world) and world.has_method("set_camera_world_center"):
		world.set_camera_world_center(myco.global_position)
	LevelHelpersRef.refresh_agent_bar_visibility($Agents)
	_story_refresh_hud()
	
	if(Global.is_raining == true):
		var cloud_width = mid_width + 250
		var cloud_height = mid_height - 300
		var cloud_position = Vector2(cloud_width,cloud_height)

		make_cloud(cloud_position)

	LevelHelpersRef.rebuild_world_occupancy_cache(self, $Agents)
	request_all_agents_dirty()
	_process_dirty_queues()

	
	#var bird = bird_scene.instantiate()
	#bird.set_variables(cloud_dict)
	#$Animals.add_child(bird)
	#cloud.connect('trade', _on_agent_trade)


	#var cloud = cloud_scene.instantiate()
	#$Agents.add_child(cloud)
	#cloud.connect('trade', _on_agent_trade)
	
			
func _is_android_back_input(event: InputEvent) -> bool:
	if not Global.is_mobile_platform:
		return false
	if event.is_action_pressed("ui_cancel"):
		return true
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE
	return false


func _handle_android_back_request(event: InputEvent) -> bool:
	if not _is_android_back_input(event):
		return false
	if get_tree().paused:
		if $UI.has_method("show_back_to_menu_confirm"):
			$UI.show_back_to_menu_confirm()
	else:
		if $UI.has_method("set_pause_state"):
			$UI.set_pause_state(true)
		else:
			get_tree().paused = true
	get_viewport().set_input_as_handled()
	return true


func _on_ui_request_back_to_menu() -> void:
	Global.score = 0
	get_tree().call_deferred("change_scene_to_file", "res://scenes/game_over.tscn")


func _input(event):
	if _handle_android_back_request(event):
		return
	if LevelHelpersRef.handle_gameplay_hotkeys(event, self, $Agents, false):
		return


func _process(_delta: float) -> void:
	_update_tree_ambient_audio(_delta)
	LevelHelpersRef.update_agent_hover_focus(self, $Agents)
	_refresh_story_phase2_harvest_guidance_visuals(_delta)
	if _is_story_mode():
		_story_progress_accum += _delta
		if _story_progress_accum >= 0.35:
			_story_progress_accum = 0.0
			_story_update_progress()
	_dirty_refresh_accum += _delta
	if _dirty_refresh_accum >= Global.get_dirty_refresh_interval():
		_dirty_refresh_accum = 0.0
		_process_dirty_queues()
	_line_visual_refresh_accum += _delta
	if _line_visual_refresh_accum >= Global.get_line_visual_refresh_interval():
		_line_visual_refresh_accum = 0.0
		LevelHelpersRef.refresh_trade_line_visuals($Lines)


func _on_inventory_drag_preview(agent_name: String, world_pos: Vector2, active: bool) -> void:
	LevelHelpersRef.update_inventory_connection_preview(self, $Agents, $Lines, inventory_preview_lines, agent_name, world_pos, active)
				
				
				
func _story_update_progress() -> void:
	if not _is_story_mode():
		return
	_story_try_advance_phase_milestones()
	if _story_phase_id >= 3 and not _story_village_revealed:
		if _has_story_reveal_crop_contact():
			_story_reveal_village()
			_story_try_advance_phase_milestones()
	_story_refresh_hud()


func _has_story_reveal_crop_contact() -> bool:
	var world = _get_world_foundation()
	if not _supports_world_tiles(world):
		return false
	for agent in $Agents.get_children():
		if not is_instance_valid(agent):
			continue
		if bool(agent.get("dead")):
			continue
		var a_type = str(agent.get("type"))
		if not _is_crop_type(a_type):
			continue
		var coord = _world_to_tile_coord(world, agent.global_position)
		if _tile_distance_to_rect(coord, STORY_VILLAGE_RECT) <= STORY_VILLAGE_REVEAL_DISTANCE:
			return true
	return false


func _story_reveal_village() -> void:
	if _story_village_revealed:
		return
	_story_village_revealed = true
	Global.village_revealed = true
	var world = _get_world_foundation()
	if is_instance_valid(world) and world.has_method("reveal_rect_permanent"):
		world.reveal_rect_permanent(STORY_VILLAGE_RECT, STORY_VILLAGE_PERMANENT_REVEAL_BUFFER)
	Global.inventory["basket"] = int(Global.inventory.get("basket", 0)) + 3
	Global.inventory["farmer"] = int(Global.inventory.get("farmer", 0)) + 2
	Global.inventory["vendor"] = int(Global.inventory.get("vendor", 0)) + 2
	Global.inventory["cook"] = int(Global.inventory.get("cook", 0)) + 2
	_story_spawn_village_cast()
	_story_refresh_hud()


func _spawn_story_villager_role(role: String, world_pos: Vector2) -> Node:
	match role:
		"farmer":
			return make_farmer(world_pos)
		"vendor":
			return make_vendor(world_pos)
		"cook":
			return make_cook(world_pos)
		_:
			return null


func _spawn_story_villager_at_tile(world: Node, tile: Vector2i, role: String) -> Node:
	var clamped = _clamp_tile_coord(world, tile)
	return _spawn_story_villager_role(role, world.tile_to_world_center(clamped))


func _story_spawn_village_cast() -> void:
	var world = _get_world_foundation()
	if not _supports_world_tiles(world):
		return
	var placed := 0
	var spawned_village_actors: Array[Node] = []
	# Mirror the old social-mode cluster: bank at top-right, 3 colored baskets, and 3 villagers beneath.
	var bank_tile = Vector2i(STORY_VILLAGE_RECT.position.x + 8, STORY_VILLAGE_RECT.position.y + 1)
	var basket_tiles = [
		Vector2i(STORY_VILLAGE_RECT.position.x + 6, STORY_VILLAGE_RECT.position.y + 3),
		Vector2i(STORY_VILLAGE_RECT.position.x + 7, STORY_VILLAGE_RECT.position.y + 3),
		Vector2i(STORY_VILLAGE_RECT.position.x + 8, STORY_VILLAGE_RECT.position.y + 3)
	]
	var basket_assets = ["N", "P", "K"]
	for i in range(mini(basket_tiles.size(), basket_assets.size())):
		var tile = basket_tiles[i]
		var basket = make_story_basket(world.tile_to_world_center(_clamp_tile_coord(world, tile)), basket_assets[i])
		if is_instance_valid(basket):
			spawned_village_actors.append(basket)

	var bank = make_story_bank(world.tile_to_world_center(_clamp_tile_coord(world, bank_tile)))
	if is_instance_valid(bank):
		spawned_village_actors.append(bank)

	var top_people_row_y = STORY_VILLAGE_RECT.position.y + 5
	var base_people: Array = [
		{"role": "farmer", "tile": Vector2i(STORY_VILLAGE_RECT.position.x + 5, top_people_row_y)},
		{"role": "vendor", "tile": Vector2i(STORY_VILLAGE_RECT.position.x + 6, top_people_row_y)},
		{"role": "cook", "tile": Vector2i(STORY_VILLAGE_RECT.position.x + 7, top_people_row_y)}
	]
	for person_cfg in base_people:
		var spawned_person = _spawn_story_villager_at_tile(world, person_cfg["tile"], person_cfg["role"])
		if spawned_person != null:
			placed += 1
			spawned_village_actors.append(spawned_person)

	# Add 6 more villagers (2 extra of each role) in random tiles below the base trio.
	var extra_roles: Array[String] = [
		"farmer", "farmer",
		"vendor", "vendor",
		"cook", "cook"
	]
	extra_roles.shuffle()
	var candidate_tiles: Array[Vector2i] = []
	var min_x = STORY_VILLAGE_RECT.position.x + 4
	var max_x = STORY_VILLAGE_RECT.position.x + STORY_VILLAGE_RECT.size.x - 2
	var min_y = top_people_row_y + 2
	var max_y = STORY_VILLAGE_RECT.position.y + STORY_VILLAGE_RECT.size.y - 1
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			candidate_tiles.append(Vector2i(x, y))
	candidate_tiles.shuffle()
	var role_index := 0
	for tile in candidate_tiles:
		if role_index >= extra_roles.size():
			break
		var spawned_extra = _spawn_story_villager_at_tile(world, tile, extra_roles[role_index])
		if spawned_extra != null:
			placed += 1
			role_index += 1
			spawned_village_actors.append(spawned_extra)

	# Kick-start village economy immediately on reveal (old social-level feel).
	for actor in spawned_village_actors:
		if not is_instance_valid(actor):
			continue
		var current_ready = actor.get("logistics_ready")
		if typeof(current_ready) != TYPE_NIL:
			actor.set("logistics_ready", true)

	if placed > 0:
		request_all_agents_dirty()
		_process_dirty_queues()
				



func _on_player_laser(path_dict) -> void:
	pass
	#var trade = trade_scene.instantiate()
	#trade.set_variables(path_dict)
	#print(" trade created: ", path_dict["from_agent"], " ", path_dict)
	#$Trades.add_child(trade)
	
func _on_agent_trade(path_dict) -> void:
	if _is_story_mode() and _story_village_revealed:
		var from_agent = path_dict.get("from_agent", null)
		var to_agent = path_dict.get("to_agent", null)
		if _story_phase_id >= 5:
			_story_mark_phase5_villager_trade(from_agent)
			_story_mark_phase5_villager_trade(to_agent)
			_story_try_advance_phase_milestones()
	call_deferred("_spawn_trade", path_dict)


func _spawn_trade(path_dict) -> void:
	var trade = null
	if not _trade_pool.is_empty():
		trade = _trade_pool.pop_back()
	else:
		trade = trade_scene.instantiate()
	if trade.has_method("set_pool_owner"):
		trade.set_pool_owner(self)
	if trade.has_method("activate_trade"):
		trade.activate_trade(path_dict)
	else:
		trade.set_variables(path_dict)
	$Trades.add_child(trade)
	
func update_bars(path_dict)  -> void:
	if is_instance_valid(Global.active_agent) and is_instance_valid(path_dict["from_agent"]) and is_instance_valid(path_dict["to_agent"]):  
		if Global.active_agent.name == path_dict["from_agent"].name or Global.active_agent.name == path_dict["to_agent"].name:
			for label in $UI.resContainer.get_children():
				#print("g. << inside asadas: ", label.name, " : ", label.text, path_dict["trade_asset"])
				if label.name == path_dict["trade_asset"]:
					#print("h. ><><< inside asadas, lable", label.name, " : ", label.text)
					label.text = str(path_dict["trade_asset"]) + str(" ") + str(Global.active_agent.assets[path_dict["trade_asset"]])


func _on_agent_lifecycle_residue(coord: Vector2i, biomass: float, source_type: String) -> void:
	var world = _get_world_foundation()
	if not is_instance_valid(world):
		return
	if world.has_method("register_residue"):
		world.register_residue(coord, biomass, 8, source_type)


func _play_predator_alert() -> void:
	if _is_story_mode() and Global.enable_tuktuk_predators and _story_village_revealed and _story_phase_id >= STORY_TUKTUK_START_PHASE:
		if is_instance_valid(_car_sound_player):
			_car_sound_player.play()
	else:
		if is_instance_valid(_bird_sound_player):
			_bird_sound_player.play()


func _spawn_predators(requested_count: int, play_alert: bool = false) -> void:
	var spawn_count = max(requested_count, 0)
	if Global.is_mobile_platform:
		spawn_count = min(spawn_count, Global.max_predators_per_wave_mobile)
	if spawn_count <= 0:
		return
	if play_alert:
		_play_predator_alert()
	for _i in range(spawn_count):
		make_bird()
					
func _on_update_score() -> void:
	var current_score_lvl := Global.get_rank_threshold(Global.score)
	if current_score_lvl > score_lvl:
		if _is_story_mode() and _story_phase_id < 2:
			# Keep predator rank progression pending until story phase 2 unlocks birds.
			return
		score_lvl = current_score_lvl
		#print("create birds: ", Global.birds[score_lvl])
		if(Global.is_birding == true):
			Global.rand_quarry.shuffle()
			var z_quarry = Global.rand_quarry[0]
			Global.quarry_type = z_quarry
			_spawn_predators(Global.get_predator_spawn_count(score_lvl), true)
	if(Global.mode == "challenge" and Global.ranks[current_score_lvl] == "Grassroots Economist"):
		get_tree().call_deferred("change_scene_to_file","res://scenes/game_over.tscn")
		

func _on_new_agent(agent_dict) -> void:
	#print("found signal: ", agent_dict)
	var new_agent = null
	var spawn_name = str(agent_dict["name"])
	var spawn_pos = agent_dict["pos"]
	var ignore_agent = agent_dict.get("ignore_agent", null)
	var require_exact_tile = bool(agent_dict.get("require_exact_tile", false))
	var allow_replace = bool(agent_dict.get("allow_replace", false))
	var from_inventory = bool(agent_dict.get("from_inventory", false))
	var allow_unanchored_spawn = bool(agent_dict.get("allow_unanchored_spawn", false))
	var myco_gate_result: Dictionary = {}
	var spawn_already_snapped := false
	var story_village_item = _is_story_village_item_type(spawn_name)
	if story_village_item:
		allow_replace = false
		require_exact_tile = true

	if _is_story_mode() and story_village_item:
		if not _story_village_revealed:
			if from_inventory:
				_refund_inventory_item(spawn_name, 1)
			return
		if not _is_story_village_spawn_allowed(spawn_pos):
			if from_inventory:
				_refund_inventory_item(spawn_name, 1)
			return

	if _is_story_mode() and from_inventory and not story_village_item:
		if try_story_inventory_delivery(spawn_name, spawn_pos):
			return

	var explicit_parent_bound = agent_dict.has("parent_anchor") or agent_dict.has("max_parent_tiles")
	var ecology_spawn = _is_crop_type(spawn_name) or spawn_name == "myco"
	if ecology_spawn and not from_inventory and not story_village_item and not explicit_parent_bound and not allow_unanchored_spawn:
		# Gameplay ecology births/regrowth must be anchored; reject unbounded signals.
		return
	var is_parent_bounded = (_is_parent_bounded_spawn_type(spawn_name) and (from_inventory or explicit_parent_bound)) or (spawn_name == "tree" and explicit_parent_bound)
	var parent_anchor = agent_dict.get("parent_anchor", null)
	var max_parent_tiles = int(agent_dict.get("max_parent_tiles", DEFAULT_PARENT_BOUND_RADIUS_TILES))
	if is_parent_bounded:
		if max_parent_tiles <= 0:
			max_parent_tiles = DEFAULT_PARENT_BOUND_RADIUS_TILES
		if not _is_valid_parent_anchor(parent_anchor, ignore_agent):
			parent_anchor = _find_nearest_living_myco_anchor(spawn_pos, ignore_agent)
		if not _is_valid_parent_anchor(parent_anchor, ignore_agent):
			if from_inventory:
				_refund_inventory_item(spawn_name, 1)
			return
		agent_dict["parent_anchor"] = parent_anchor
		agent_dict["max_parent_tiles"] = max_parent_tiles
		if not agent_dict.has("spawn_anchor"):
			agent_dict["spawn_anchor"] = parent_anchor

	if allow_replace:
		var replace_pos = spawn_pos
		if is_parent_bounded:
			var world_for_replace = _get_world_foundation()
			if _supports_world_tiles(world_for_replace):
				var desired_coord = _clamp_tile_coord(world_for_replace, Vector2i(world_for_replace.world_to_tile(spawn_pos)))
				var parent_coord = _clamp_tile_coord(world_for_replace, Vector2i(world_for_replace.world_to_tile(parent_anchor.global_position)))
				if _tile_chebyshev_distance(desired_coord, parent_coord) <= max_parent_tiles:
					replace_pos = world_for_replace.tile_to_world_center(desired_coord)
				else:
					allow_replace = false
			else:
				allow_replace = false
		if allow_replace:
			var replace_target = _find_replaceable_agent_at_world_pos(replace_pos, ignore_agent)
			if is_instance_valid(replace_target):
				var replace_type = str(replace_target.get("type"))
				if replace_type == "tree" or replace_type == "myco":
					# Inventory drops should never destroy/replace existing trees or fungi.
					allow_replace = false
				else:
					ignore_agent = replace_target
					if replace_target.has_method("kill_it"):
						replace_target.kill_it()
					else:
						replace_target.call_deferred("queue_free")
					require_exact_tile = true
					spawn_pos = replace_pos

	if is_parent_bounded:
		if from_inventory and require_exact_tile:
			var world_for_exact = _get_world_foundation()
			if _supports_world_tiles(world_for_exact):
				var exact_coord = _clamp_tile_coord(world_for_exact, Vector2i(world_for_exact.world_to_tile(spawn_pos)))
				var exact_parent_coord = _clamp_tile_coord(world_for_exact, Vector2i(world_for_exact.world_to_tile(parent_anchor.global_position)))
				if _tile_chebyshev_distance(exact_coord, exact_parent_coord) > max_parent_tiles:
					if from_inventory:
						_refund_inventory_item(spawn_name, 1)
					return
		var parent_spawn = _resolve_parent_bounded_spawn_pos(spawn_pos, parent_anchor, max_parent_tiles, ignore_agent, require_exact_tile)
		if not bool(parent_spawn["ok"]):
			if from_inventory:
				_refund_inventory_item(spawn_name, 1)
			return
		spawn_pos = parent_spawn["pos"]
		require_exact_tile = true
		spawn_already_snapped = true
	elif require_exact_tile:
		var exact_spawn = _resolve_exact_tile_spawn_pos(spawn_pos, ignore_agent)
		if not bool(exact_spawn["ok"]):
			if from_inventory:
				_refund_inventory_item(spawn_name, 1)
			return
		spawn_pos = exact_spawn["pos"]
		spawn_already_snapped = true

	var world_for_reveal = _get_world_foundation()
	if is_instance_valid(world_for_reveal) and world_for_reveal.has_method("is_world_pos_revealed"):
		if from_inventory and not bool(world_for_reveal.is_world_pos_revealed(spawn_pos)):
			_refund_inventory_item(spawn_name, 1)
			return

	if spawn_name == "myco" and not require_exact_tile:
		spawn_pos = _resolve_tile_spawn_pos(spawn_pos)
		spawn_already_snapped = true
		myco_gate_result = _validate_myco_spawn(spawn_pos, ignore_agent)
		if not bool(myco_gate_result["ok"]):
			if from_inventory:
				_refund_inventory_item("myco", 1)
			return
		if is_instance_valid(myco_gate_result["anchor"]):
			agent_dict["spawn_anchor"] = myco_gate_result["anchor"]
	if spawn_name == "squash":
		if is_instance_valid(_twinkle_sound_player):
			_twinkle_sound_player.play()
		new_agent = make_squash(spawn_pos, spawn_already_snapped)
	elif spawn_name == "bean":
		if is_instance_valid(_twinkle_sound_player):
			_twinkle_sound_player.play()
		new_agent = make_bean(spawn_pos, spawn_already_snapped)
	elif spawn_name == "maize":
		if is_instance_valid(_twinkle_sound_player):
			_twinkle_sound_player.play()
		new_agent = make_maize(spawn_pos, spawn_already_snapped)
	elif spawn_name == "myco":
		if myco_gate_result.is_empty():
			myco_gate_result = _validate_myco_spawn(spawn_pos, ignore_agent)
		if not bool(myco_gate_result["ok"]):
			if from_inventory:
				_refund_inventory_item("myco", 1)
			return
		if is_instance_valid(myco_gate_result["anchor"]):
			agent_dict["spawn_anchor"] = myco_gate_result["anchor"]
		if is_instance_valid(_squelch_sound_player):
			_squelch_sound_player.play()
		new_agent = make_myco(spawn_pos, spawn_already_snapped)
	elif spawn_name == "tree":
		if is_instance_valid(_bush_sound_player):
			_bush_sound_player.play()
		new_agent = make_tree(spawn_pos, spawn_already_snapped)
	elif spawn_name == "farmer":
		new_agent = make_farmer(spawn_pos)
	elif spawn_name == "vendor":
		new_agent = make_vendor(spawn_pos)
	elif spawn_name == "cook":
		new_agent = make_cook(spawn_pos)
	elif spawn_name == "basket":
		new_agent = make_story_basket(spawn_pos)
	
	if is_instance_valid(new_agent):
		if agent_dict.has("spawn_anchor") and _can_share_story_trade_network_nodes(new_agent, agent_dict["spawn_anchor"]):
			LevelHelpersRef.ensure_spawn_buddy_link(new_agent, agent_dict["spawn_anchor"])
		LevelHelpersRef.sync_agent_occupancy(self, new_agent)
		if _is_story_mode() and from_inventory:
			if _story_phase_id == 1 and _story_is_phase1_required_placement_type(spawn_name):
				_story_phase1_placed_types[spawn_name] = true
			if _story_phase_id == 3 and spawn_name == "myco" and _is_story_myco_near_any_villager(new_agent.global_position):
				_story_phase3_myco_near_villager = true
			if spawn_name == "basket":
				_story_phase5_basket_placed = true
			_story_try_advance_phase_milestones()
			_story_sync_phase1_inventory_sparkle_targets()
		request_all_agents_dirty()
		if _is_story_mode() and _is_story_village_actor(new_agent):
			_story_refresh_hud()
	if(Global.active_agent == null and not Global.prevent_auto_select):
		Global.active_agent = new_agent
		LevelHelpersRef.refresh_agent_bar_visibility($Agents)
			
func make_squash(pos, already_snapped: bool = false):
	#print("Clicked On Squash. making")
	
	var squash_position = pos
	if not already_snapped:
		squash_position = _resolve_tile_spawn_pos(pos)
	
	var named = "Squash_" + str($Agents.get_child_count()+1)
	
	var squash_dict = {
		"name": named,
		"type": "squash",
		"position": squash_position,
		"prod_res": ["P"],
		"start_res": null,
		"texture": TEX_SQUASH
	}
	
	var squash = plant_scene.instantiate()
	squash.set_variables(squash_dict)
	$Agents.add_child(squash)
	LevelHelpersRef.connect_core_agent_signals(squash, _on_agent_trade, _on_new_agent, _on_update_score)
	_connect_harvest_committed_signal(squash)
	_connect_lifecycle_residue_signal(squash)
	LevelHelpersRef.sync_agent_occupancy(self, squash)
	request_all_agents_dirty()
	
	return squash

func make_tree(pos, already_snapped: bool = false):
	#print("Clicked On Squash. making")
	
	var tree_position = pos
	if not already_snapped:
		tree_position = _resolve_tile_spawn_pos(pos)
	
	var named = "Tree_" + str($Agents.get_child_count()+1)
	
	var tree_dict = {
		"name": named,
		"type": "tree",
		"position": tree_position,
		"prod_res": ["R"],
		"start_res": null,
		"texture": TEX_TREE
	}
	var tree = plant_scene.instantiate()
	tree.set_variables(tree_dict)
	$Agents.add_child(tree)
	tree.position = LevelHelpersRef.resolve_snapped_position_for_agent(self, $Agents, tree, tree_position)
	LevelHelpersRef.connect_core_agent_signals(tree, _on_agent_trade, _on_new_agent, _on_update_score)
	_connect_harvest_committed_signal(tree)
	_connect_lifecycle_residue_signal(tree)
	LevelHelpersRef.sync_agent_occupancy(self, tree)
	request_all_agents_dirty()
	return tree
	
	
func make_bird():
	call_deferred("_spawn_bird")


func _spawn_bird():
	var predator = null
	if _is_story_mode() and Global.enable_tuktuk_predators and _story_village_revealed and _story_phase_id >= STORY_TUKTUK_START_PHASE and randf() < 0.42:
		predator = tuktuk_scene.instantiate()
	else:
		predator = bird_scene.instantiate()
	$Animals.add_child(predator)

	
func make_maize(pos, already_snapped: bool = false):
	var maize_position = pos
	if not already_snapped:
		maize_position = _resolve_tile_spawn_pos(pos)
	
	var named = "Maize_" + str($Agents.get_child_count()+1)
	
	var maize_dict = {
		"name": named,
		"type": "maize",
		"position": maize_position,
		"prod_res": ["K"],
		"start_res": null,
		"texture": TEX_MAIZE
	}
	var maize = plant_scene.instantiate()
	maize.set_variables(maize_dict)
	$Agents.add_child(maize)
	LevelHelpersRef.connect_core_agent_signals(maize, _on_agent_trade, _on_new_agent, _on_update_score)
	_connect_harvest_committed_signal(maize)
	_connect_lifecycle_residue_signal(maize)
	LevelHelpersRef.sync_agent_occupancy(self, maize)
	request_all_agents_dirty()
	
	return maize
		
func make_bean(pos, already_snapped: bool = false):
	
	var bean_position = pos
	if not already_snapped:
		bean_position = _resolve_tile_spawn_pos(pos)
	
	var named = "Bean_" + str($Agents.get_child_count()+1)
	
	var bean_dict = {
		"name": named,
		"type": "bean",
		"position": bean_position,
		"prod_res": ["N"],
		"start_res": null,
		"texture": TEX_BEAN
	}
	var bean = plant_scene.instantiate()
	bean.set_variables(bean_dict)
	$Agents.add_child(bean)
	LevelHelpersRef.connect_core_agent_signals(bean, _on_agent_trade, _on_new_agent, _on_update_score)
	_connect_harvest_committed_signal(bean)
	_connect_lifecycle_residue_signal(bean)
	LevelHelpersRef.sync_agent_occupancy(self, bean)
	request_all_agents_dirty()
	
	return bean


func make_cloud(pos):
	
	var named = "Cloud_" + str($Agents.get_child_count()+1)
	
	var cloud_dict = {
		"name": named,
		"type": "cloud",
		"position": pos,
		"prod_res": ["R"],
		"start_res": 20,
		"texture": TEX_CLOUD
	}
	var cloud = cloud_scene.instantiate()
	cloud.set_variables(cloud_dict)
	$Agents.add_child(cloud)
	if cloud.has_signal("trade"):
		cloud.connect("trade", _on_agent_trade)
	
	return cloud


func make_story_bank(pos: Vector2) -> Node:
	var bank_pos = _resolve_tile_spawn_pos(pos)
	if _is_story_mode() and not _is_story_village_spawn_allowed(bank_pos):
		return null
	var named = str("VillageBank_", $Agents.get_child_count() + 1)
	var bank_dict = {
		"name": named,
		"type": "bank",
		"position": bank_pos,
		"prod_res": ["R"],
		"start_res": null,
		"texture": TEX_BANK
	}
	var bank = socialagent_scene.instantiate()
	bank.set_variables(bank_dict)
	bank.buddy_radius = Global.social_buddy_radius
	bank.draggable = false
	bank.killable = false
	bank.set_meta("story_village_actor", true)
	bank.set_meta("story_kind", "bank")
	$Agents.add_child(bank)
	bank.position = LevelHelpersRef.resolve_snapped_position_for_agent(self, $Agents, bank, bank_pos)
	LevelHelpersRef.connect_core_agent_signals(bank, _on_agent_trade, _on_new_agent, _on_update_score)
	LevelHelpersRef.sync_agent_occupancy(self, bank)
	return bank


func make_myco(pos, already_snapped: bool = false):
	var myco_position = pos
	if not already_snapped:
		myco_position = _resolve_tile_spawn_pos(pos)
	
	var named = "Mycorrhizal_" + str($Agents.get_child_count()+1)
		
	
	var myco_dict = {
		"name": named,
		"type": "myco",
		"position": myco_position,
		"prod_res": [null],
		"start_res": null,
		"texture": TEX_MYCO
	}
	
	var myco = myco_scene.instantiate()
	myco.set_variables(myco_dict)
	myco.sprite_texture = TEX_MYCO
	$Agents.add_child(myco)
	
	if myco.has_signal("trade"):
		myco.connect("trade", _on_agent_trade)
	if myco.has_signal("new_agent"):
		myco.connect("new_agent", _on_new_agent)
	_connect_harvest_committed_signal(myco)
	_connect_lifecycle_residue_signal(myco)
	LevelHelpersRef.sync_agent_occupancy(self, myco)
	request_all_agents_dirty()
	
	return myco


func _setup_story_person_flags(person: Node, role: String) -> void:
	if not is_instance_valid(person):
		return
	person.set_meta("story_villager", true)
	person.set_meta("story_village_actor", true)
	person.set_meta("story_disable_birth", true)
	person.set_meta("story_disable_farmer_production", role == "farmer")
	person.draggable = false
	person.killable = false
	person.num_babies = 0
	person.peak_maturity = 999999
	person.current_babies = 0
	person.current_maturity = 0


func _make_story_person(role: String, texture: Texture2D, pos: Vector2, prod_res: Array) -> Node:
	var spawn_pos = _resolve_tile_spawn_pos(pos)
	if _is_story_mode() and not _is_story_village_spawn_allowed(spawn_pos):
		return null
	var named = str(role.capitalize(), "_", $Agents.get_child_count() + 1)
	var person_dict = {
		"name": named,
		"type": role,
		"position": spawn_pos,
		"prod_res": prod_res,
		"start_res": null,
		"texture": texture
	}
	var person = socialagent_scene.instantiate()
	person.set_variables(person_dict)
	$Agents.add_child(person)
	person.buddy_radius = Global.social_buddy_radius
	_setup_story_person_flags(person, role)
	LevelHelpersRef.connect_core_agent_signals(person, _on_agent_trade, _on_new_agent, _on_update_score)
	LevelHelpersRef.sync_agent_occupancy(self, person)
	return person


func make_farmer(pos: Vector2) -> Node:
	return _make_story_person("farmer", TEX_FARMER, pos, [null])


func make_vendor(pos: Vector2) -> Node:
	return _make_story_person("vendor", TEX_VENDOR, pos, ["P"])


func make_cook(pos: Vector2) -> Node:
	return _make_story_person("cook", TEX_COOK, pos, ["K"])


func make_story_basket(pos: Vector2, asset_key: String = "") -> Node:
	var basket_pos = _resolve_tile_spawn_pos(pos)
	if _is_story_mode() and not _is_story_village_spawn_allowed(basket_pos):
		return null
	var named = str("VillageBasket_", $Agents.get_child_count() + 1)
	var basket_dict = {
		"name": named,
		"type": "myco",
		"position": basket_pos,
		"prod_res": [null],
		"start_res": null,
		"texture": TEX_BASKET
	}
	var basket = basket_scene.instantiate()
	var normalized_asset = asset_key.strip_edges()
	if normalized_asset != "":
		basket.assets = {
			normalized_asset: 5,
			"R": 0
		}
		basket.needs = {
			normalized_asset: 10,
			"R": 10
		}
	basket.set_variables(basket_dict)
	basket.draw_lines = true
	basket.draggable = false
	basket.killable = false
	if normalized_asset != "" and is_instance_valid(basket.sprite):
		basket.sprite.modulate = Global.asset_colors.get(normalized_asset, Color.WHITE)
	basket.set_meta("story_village_actor", true)
	if normalized_asset != "":
		basket.set_meta("story_kind", str("basket_", normalized_asset))
	else:
		basket.set_meta("story_kind", "basket")
	$Agents.add_child(basket)
	if basket.has_signal("trade"):
		basket.connect("trade", _on_agent_trade)
	LevelHelpersRef.sync_agent_occupancy(self, basket)
	return basket
	
	


func _on_tutorial_timer_timeout() -> void:
	if(Global.mode == "tutorial"):
		#print("mode: ", Global.mode, "stage: ", Global.stage)
		if( Global.stage == 1):
			
			var c_buds = 0
			for child in $Agents.get_children():
				if(child.type!="myco"):
					c_buds += len(child.trade_buddies)
				#print(" child bud: ", child.name, " ", child.trade_buddies)
			#print("len buds: ", c_buds)
			if(c_buds >=4):
				Global.stage += 1
				$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
				_set_tutorial_panel_color(Global.stage_colors[Global.stage])
				
		elif(Global.stage == 2):
			
			var c_buds = 0
			var num_myco = 0
			for child in $Agents.get_children():
				if(child.type=="myco"):
					num_myco += 1
			if(num_myco >=2):
				Global.stage += 1
				$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
				_set_tutorial_panel_color(Global.stage_colors[Global.stage])
		elif(Global.stage == 3):
			
			var c_buds = 0
			var num_myco = 0
			for child in $Agents.get_children():
				if(child.type=="myco"):
					num_myco += 1
					c_buds += len(child.trade_buddies)
					#print(" child bud: ", child.name, " ", child.trade_buddies)
			if(num_myco >= 3 and c_buds >=2):
				Global.stage += 1
				$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
				_set_tutorial_panel_color(Global.stage_colors[Global.stage])
		elif(Global.stage == 4):
			
			var c_maize = 0
			for child in $Agents.get_children():
				if(child.type=="maize" and child.dead==false):
					c_maize += 1
			
			_spawn_predators(c_maize * 3, true)
				
			Global.stage = 4.1
			
		elif(Global.stage == 4.1):
			var c_maize = 0
			for child in $Agents.get_children():
				if(child.type=="maize" and child.dead==false):
					c_maize += 1
			
			if(c_maize >=3):
				Global.stage = 5
				$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
				_set_tutorial_panel_color(Global.stage_colors[Global.stage])
		
		elif(Global.stage == 5):
			
			var c_maize = 0
			for child in $Agents.get_children():
				if(child.type=="maize" and child.dead==false):
					c_maize += 1
			
			_spawn_predators(c_maize - 1, true)
				
			Global.stage = 5.1
			
		elif(Global.stage == 5.1):
			var c_maize = 0
			for child in $Agents.get_children():
				if(child.type=="maize" and child.dead==false):
					c_maize += 1
			
			
			
			if(c_maize >=2 and Global.values['K']>1):
				Global.stage = 6
				$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
				_set_tutorial_panel_color(Global.stage_colors[Global.stage])
				
		elif(Global.stage == 6):
			
			
			var c_maize = 0
			for child in $Agents.get_children():
				if(child.type=="maize" and child.dead==false):
					c_maize += 1
			
			_spawn_predators(c_maize - 1)
			Global.stage_inc+=1
			if(Global.stage_inc>=Global.max_stage_inc):
				Global.stage = 6.1
				Global.stage_inc = 0
			
		elif(Global.stage == 6.1):
			var c_maize = 0
			for child in $Agents.get_children():
				if(child.type=="maize" and child.dead==false):
					c_maize += 1
			
			
			
			if(c_maize >=2 and Global.values['K']>1):
				Global.stage = 7
				$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
				_set_tutorial_panel_color(Global.stage_colors[Global.stage])
		
		elif(Global.stage == 7):
			
			var c_maize = 0
			for child in $Agents.get_children():
				if(child.type=="maize" and child.dead==false):
					c_maize += 1
					
			if(c_maize >=2 and Global.values['K']<=1.1):
				Global.stage = 8
				$"UI/TutorialMarginContainer1/Label".text = Global.stage_text[Global.stage]
				_set_tutorial_panel_color(Global.stage_colors[Global.stage])
				$"UI/RestartContainer".visible=true


func _exit_tree() -> void:
	_release_audio()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_release_audio()


func _release_audio() -> void:
	if _shutdown_cleanup_done:
		return
	_shutdown_cleanup_done = true
	LevelHelpersRef.clear_trade_line_cache($Lines, true)
	LevelHelpersRef.clear_inventory_connection_preview_lines(inventory_preview_lines, true)
	LevelHelpersRef.stop_audio_players(_get_runtime_audio_players(), true)
	for active_trade in $Trades.get_children():
		if is_instance_valid(active_trade):
			if active_trade.get_parent() != null:
				active_trade.get_parent().remove_child(active_trade)
			active_trade.free()
	for pooled_trade in _trade_pool:
		if is_instance_valid(pooled_trade):
			if pooled_trade.get_parent() != null:
				pooled_trade.get_parent().remove_child(pooled_trade)
			pooled_trade.free()
	_trade_pool.clear()
		
						
			
		
