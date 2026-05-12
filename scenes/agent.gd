extends Area2D
class_name Agent

@export var speed: int

const LevelHelpersRef = preload("res://scenes/level_helpers.gd")
const TEX_BEAN_SEED_STAGE_PATH := "res://graphics/bean_seed_stage.png"
const TEX_BEAN_SPROUT_STAGE_PATH := "res://graphics/bean_sprout_stage.png"
const TEX_BEAN_VINE_STAGE_PATH := "res://graphics/bean_vine_stage.png"
const TEX_BEAN_POD_STAGE_PATH := "res://graphics/bean_pod_stage.png"
const TEX_BEAN_DEAD_STAGE_PATH := "res://graphics/bean_dead_stage.png"
const TEX_SQUASH_SPROUT_STAGE_PATH := "res://graphics/squash_sprout_stage.png"
const TEX_SQUASH_VINE_STAGE_PATH := "res://graphics/squash_vine_stage.png"
const TEX_SQUASH_POD_STAGE_PATH := "res://graphics/squash_pod_stage.png"
const TEX_SQUASH_DEAD_STAGE_PATH := "res://graphics/squash_dead_stage.png"
const TEX_MAIZE_SPROUT_STAGE_PATH := "res://graphics/maize_sprout_stage.png"
const TEX_MAIZE_VINE_STAGE_PATH := "res://graphics/maize_vine_stage.png"
const TEX_MAIZE_POD_STAGE_PATH := "res://graphics/maize_pod_stage.png"
const TEX_MAIZE_DEAD_STAGE_PATH := "res://graphics/maize_dead_stage.png"
const TEX_ACORN_TREE_VINE_STAGE_PATH := "res://graphics/acorn_tree_vine_stage.png"
const TEX_ACORN_TREE_POD_STAGE_PATH := "res://graphics/acorn_tree_pod_stage.png"
const TEX_ACORN_TREE_DEAD_STAGE_PATH := "res://graphics/acorn_tree_dead_stage.png"
const TEX_ACORN_HARVEST_PATH := "res://graphics/acorn_32.png"

enum BeanGrowthStage {
	SEED,
	SPROUT,
	VINE,
	POD_READY,
	DEAD
}

const BEAN_OVERRIPE_TICKS := 20
const BEAN_DEAD_CLEANUP_TICKS := 6
const BEAN_DEAD_RESPAWN_DELAY_TICKS := 1
const BEAN_POST_HARVEST_TO_DEAD_TICKS := 2
const BEAN_POD_BABY_TICK_INTERVAL := 4
const BEAN_STAGE_CONSUMPTIONS_PER_ADVANCE := 3
const BEAN_STAGE_ADVANCE_WAIT_TICKS := 1
const BEAN_HARVEST_YIELD := 3
const LIFECYCLE_POD_BABY_MIN := 0
const LIFECYCLE_POD_BABY_MAX := 3
const TREE_STARVATION_DURATION_MULTIPLIER := 3.0
const TREE_CHALLENGE_STARVATION_DEAD_TICKS := 180
const LIFECYCLE_ORPHAN_STARVATION_MULTIPLIER := 4.0
const LIFECYCLE_ORPHAN_CHALLENGE_DEAD_TICKS := 45
const BASE_MOVE_RATE_FOR_STARVATION := 6.0
const BASE_MOVEMENT_SPEED_FOR_STARVATION := 200.0
const MIN_STARVATION_SPEED_SCALE := 0.2
const STORY_PREDATOR_DISRUPT_SECONDS := 4.0
const LIFECYCLE_PARENT_BOUND_TILES := 4
const HARVEST_GUIDE_BEAN_RECT := Rect2(0.04, 0.26, 0.50, 0.56)
const HARVEST_GUIDE_SQUASH_RECT := Rect2(0.02, 0.30, 0.42, 0.52)
const HARVEST_GUIDE_MAIZE_RECT := Rect2(0.28, 0.20, 0.42, 0.66)
const HARVEST_GUIDE_MYCO_RECT := Rect2(0.08, 0.08, 0.84, 0.84)
const TREE_HARVEST_ACORN_LOCAL_POS := Vector2(0.0, -64.0)
const TREE_HARVEST_ACORN_HOTSPOT_RADIUS := 24.0
const STORY_PHASE5_FORCED_BASKET_LINK_META := "story_force_phase5_basket_link"
const RESOURCE_BAR_UI_CLEARANCE := 14.0

signal trade(pos)
signal clicked
signal clicked_agent(agent)
signal new_agent(agent_dict)
signal update_score
signal lifecycle_residue(coord, biomass, source_type)
signal harvest_committed(harvest_type, destination)

var my_lines = []
var buddy_radius = 250
var sprite_myco = null
var sprite_myco_texture = null



var random = RandomNumberGenerator.new()

var caught_by = null
var draggable = true
var killable = true
var is_dragging = false
var mouse_offset
var delay = 10
var last_position = null
var draw_box = true
var draw_lines = false
var dead = false
var story_predator_disrupt_timer := 0.0

var low_alpha = 0.75
var high_alpha = 1.0
var max_scale = 1.4
var min_scale = 0.8


var num_steps_down = 35.0
var num_steps_up = 10.0

var alpha_step_down = (high_alpha - low_alpha) / num_steps_down
var alpha_step_up = (high_alpha - low_alpha) / num_steps_up

var scale_step_down = (max_scale - min_scale) / num_steps_down
var scale_step_up = (max_scale - min_scale) / num_steps_up

var logistics_ready = false
var production_ready = false
var decay_ready = false
var evaporate_ready = false
var sprite = null
var sprite_texture = null
var bar_canvas = null
var prod_res = [null]
var type = null

var START_N = 0 #Nitrogen
var START_P = 0 # Potassium 
var START_K = 0 #Phosphorus
var START_R = 0 #Rain
var trades = [] #list of outstanding trades
var trade_buddies = []
var new_buddies = true

var peak_maturity = 3
var current_maturity = 0

var num_buddies = 5
var num_connectors = 0

var num_babies = 12
var current_babies = 0

#var assets = {}


var assets = { #list of assets - 
	#for each asset there is a balance, and stready state amount needed for growth
	"N": START_N,
	"P": START_P,				
	"K": START_K,
	"R": START_R
	}
var needs = { #list of needed assets with need level
	"N": 10,
	"P": 10,				
	"K": 10,
	"R": 10
	}
var current_needs = { #list of needed assets with need level
	"N": 0,
	"P": 0,				
	"K": 0,
	"R": 0
	}
	
var current_excess = { #list of needed assets with need level
	"N": 0,
	"P": 0,				
	"K": 0,
	"R": 0
	}

var bars = { #list of needed assets with need level
	"N": null,
	"P": null,
	"K": null,
	"R": null
}

var bars_offset = { #list of needed assets with need level
	"N": null,
	"P": null,
	"K": null,
	"R": null
}
var _tile_snap_target := Vector2.ZERO
var _tile_snap_in_progress := false
var _keyboard_moving := false
var _drag_hint_active := false
var _press_started_here := false
var _harvest_drag_only := false
var _active_touch_id := -1
var _drag_pointer_screen_pos := Vector2.ZERO
var _has_drag_pointer_screen_pos := false
var _drag_pointer_down := false
var _harvest_drag_sprite: Sprite2D = null
var bean_pod_ticks := 0
var bean_dead_ticks := 0
var bean_starvation_ticks := 0
var bean_stage_consumptions := 0
var bean_stage_wait_ticks := 0
var bean_respawn_wait_ticks := 0
var bean_respawn_requested := false
var bean_post_harvest_senescence := false
var bean_post_harvest_ticks := 0
var bean_stage: int = BeanGrowthStage.SEED
var bean_death_preserve_stage_visual := false
var bean_death_visual_stage: int = BeanGrowthStage.SPROUT
var bean_death_regrowth_allowed := true
var bean_harvest_ready := false
var bean_pod_sparkle_played := false
var bean_stage_textures := {}
var bean_base_scale := Vector2.ONE
var bean_residue_pending := false
var bean_residue_emitted := false
var _farmer_harvest_delivery_reserved := false
var _bar_update_accum := 0.0
var _last_occupancy_scale := Vector2(-99999.0, -99999.0)
var _last_bar_camera_center := Vector2(INF, INF)
var _hover_visual_focus := false
var _harvest_visual_detached := false
var _harvest_inventory_animating := false
var _harvest_drag_proxy_in_ui := false
var tree_harvest_sprite: Sprite2D = null


func _get_sprite_half_extents() -> Vector2:
	if is_instance_valid(sprite) and sprite.has_method("get_rect"):
		var rect: Rect2 = sprite.get_rect()
		var sprite_scale := Vector2(1.0, 1.0)
		if sprite is Node2D:
			sprite_scale = Vector2(abs(sprite.scale.x), abs(sprite.scale.y))
		var half = rect.size * sprite_scale * 0.5
		return Vector2(max(half.x, 8.0), max(half.y, 8.0))
	if has_node("Sprite2D"):
		var sprite_node = get_node("Sprite2D")
		if is_instance_valid(sprite_node) and sprite_node.has_method("get_rect"):
			var sprite_rect: Rect2 = sprite_node.get_rect()
			var node_scale := Vector2(abs(sprite_node.scale.x), abs(sprite_node.scale.y))
			var node_half = sprite_rect.size * node_scale * 0.5
			return Vector2(max(node_half.x, 8.0), max(node_half.y, 8.0))
	return Vector2(8.0, 8.0)


func _clamp_position_to_world(candidate: Vector2) -> Vector2:
	var world_rect = Global.get_world_rect(self)
	var half = _get_sprite_half_extents()

	var min_x = world_rect.position.x + half.x
	var max_x = world_rect.position.x + world_rect.size.x - half.x
	var min_y = world_rect.position.y + half.y
	var max_y = world_rect.position.y + world_rect.size.y - half.y

	var result = candidate
	if min_x > max_x:
		result.x = world_rect.position.x + world_rect.size.x * 0.5
	else:
		result.x = clampf(candidate.x, min_x, max_x)
	if min_y > max_y:
		result.y = world_rect.position.y + world_rect.size.y * 0.5
	else:
		result.y = clampf(candidate.y, min_y, max_y)
	return result


func _update_bar_positions() -> void:
	if bars.is_empty():
		return
	var anchor = position
	if is_instance_valid(bar_canvas) and bar_canvas is CanvasLayer:
		var viewport = get_viewport()
		if viewport != null:
			var camera = viewport.get_camera_2d()
			if camera != null:
				_last_bar_camera_center = camera.get_screen_center_position()
				anchor = Global.world_to_screen(self, position)
	for bar in bars:
		if is_instance_valid(bars[bar]):
			bars[bar].position = anchor + bars_offset[bar]


func setup_resource_bars(asset_keys: Array = [], force_hidden: bool = false) -> void:
	var canvas = get_node_or_null("CanvasLayer")
	if not is_instance_valid(canvas):
		return
	var bar_nodes := {
		"N": canvas.get_node_or_null("Nbar"),
		"P": canvas.get_node_or_null("Pbar"),
		"K": canvas.get_node_or_null("Kbar"),
		"R": canvas.get_node_or_null("Rbar")
	}
	var visible_assets: Array = asset_keys.duplicate()
	if visible_assets.is_empty():
		visible_assets = assets.keys()
	bars = {}
	for asset in bar_nodes.keys():
		var bar_node = bar_nodes[asset]
		if is_instance_valid(bar_node):
			bar_node.visible = visible_assets.has(asset)
	for asset in visible_assets:
		if not bar_nodes.has(asset):
			continue
		var bar_node = bar_nodes[asset]
		if not is_instance_valid(bar_node):
			continue
		if assets.get(asset) == null or needs.get(asset) == null:
			continue
		bars[asset] = bar_node
		bar_node.max_value = int(needs[asset] * 1.2)
		bar_node.value = assets[asset]
		bars_offset[asset] = bar_node.position
		bar_node.tint_progress = Global.asset_colors[asset]
	bar_canvas = canvas
	if force_hidden or not Global.bars_on:
		bar_canvas.visible = false
	_update_bar_positions()


func _hide_resource_bars() -> void:
	_hover_visual_focus = false
	if is_instance_valid(bar_canvas):
		bar_canvas.visible = false


func _is_dead_resource_bar_visual() -> bool:
	return _is_bean_lifecycle_enabled() and bean_stage == BeanGrowthStage.DEAD


func _is_selected_agent() -> bool:
	if not is_instance_valid(Global.active_agent):
		return false
	return Global.active_agent == self or Global.active_agent.name == self.name


func _should_show_resource_bars() -> bool:
	if not is_instance_valid(bar_canvas):
		return false
	if dead or caught_by != null or _is_dead_resource_bar_visual():
		return false
	if _resource_bars_overlap_core_ui():
		return false
	if Global.story_force_visible_plant_bars and _is_reposition_subject():
		var viewport = get_viewport()
		if viewport != null:
			var screen_rect = viewport.get_visible_rect().grow(48.0)
			if screen_rect.has_point(Global.world_to_screen(self, position)):
				return true
	if Global.bars_on:
		return true
	if _is_selected_agent():
		return true
	if not _is_hover_bar_subject():
		return false
	return _hover_visual_focus


func _resource_bars_overlap_core_ui() -> bool:
	if bars.is_empty():
		return false
	var level_root = _get_level_root()
	if not is_instance_valid(level_root):
		return false
	var ui = level_root.get_node_or_null("UI")
	if not is_instance_valid(ui):
		return false
	var avoid_rects: Array[Rect2] = []
	for node_path in ["MarginContainer", "RestartContainer", "TutorialMarginContainer1"]:
		var control = ui.get_node_or_null(node_path) as Control
		if is_instance_valid(control) and control.visible:
			avoid_rects.append(control.get_global_rect().grow(RESOURCE_BAR_UI_CLEARANCE))
	if avoid_rects.is_empty():
		return false
	var anchor = position
	if is_instance_valid(bar_canvas) and bar_canvas is CanvasLayer:
		anchor = Global.world_to_screen(self, position)
	for bar_key in bars:
		var bar = bars[bar_key]
		if not is_instance_valid(bar):
			continue
		var bar_size: Vector2 = bar.size
		if bar_size == Vector2.ZERO:
			bar_size = Vector2(6.0, 30.0)
		var bar_rect = Rect2(anchor + bars_offset[bar_key], bar_size)
		for avoid_rect in avoid_rects:
			if avoid_rect.intersects(bar_rect):
				return true
	return false


func refresh_bar_visibility() -> void:
	if not is_instance_valid(bar_canvas):
		return
	var should_show = _should_show_resource_bars()
	if bar_canvas.visible == should_show:
		return
	bar_canvas.visible = should_show
	_bar_update_accum = 0.0
	if should_show:
		_update_bar_positions()


func set_hover_focus(is_hovered: bool) -> void:
	if _hover_visual_focus == is_hovered:
		return
	_hover_visual_focus = is_hovered
	refresh_bar_visibility()


func _get_adaptive_bar_update_interval() -> float:
	var interval = Global.get_bar_update_interval()
	if Global.bars_on:
		var sample_variant = Global.perf_last_sample
		if typeof(sample_variant) == TYPE_DICTIONARY:
			var sample: Dictionary = sample_variant
			var visible_count = int(sample.get("visible_bars", 0))
			if visible_count >= 500:
				interval = maxf(interval, 0.32)
			elif visible_count >= 320:
				interval = maxf(interval, 0.24)
			elif visible_count >= 180:
				interval = maxf(interval, 0.16)
		if not _is_selected_agent():
			interval = maxf(interval, 0.12)
	return interval


func _did_camera_move_since_last_bar_update() -> bool:
	if not is_instance_valid(bar_canvas) or not (bar_canvas is CanvasLayer):
		return true
	var viewport = get_viewport()
	if viewport == null:
		return true
	var camera = viewport.get_camera_2d()
	if camera == null:
		return true
	var center = camera.get_screen_center_position()
	var moved = center.distance_squared_to(_last_bar_camera_center) > 0.01
	_last_bar_camera_center = center
	return moved


func _get_world_foundation_node() -> Node:
	return get_node_or_null("../../WorldFoundation")


func _rect_from_normalized(source: Rect2, normalized: Rect2) -> Rect2:
	return Rect2(
		Vector2(
			source.position.x + source.size.x * normalized.position.x,
			source.position.y + source.size.y * normalized.position.y
		),
		Vector2(
			source.size.x * normalized.size.x,
			source.size.y * normalized.size.y
		)
	)


func _get_tree_harvest_hotspot_rect() -> Rect2:
	if not is_instance_valid(sprite):
		return Rect2()
	var scale_x = maxf(absf(sprite.scale.x), 0.001)
	var scale_y = maxf(absf(sprite.scale.y), 0.001)
	var radius = TREE_HARVEST_ACORN_HOTSPOT_RADIUS
	return Rect2(
		Vector2(
			(TREE_HARVEST_ACORN_LOCAL_POS.x - radius) / scale_x,
			(TREE_HARVEST_ACORN_LOCAL_POS.y - radius) / scale_y
		),
		Vector2((radius * 2.0) / scale_x, (radius * 2.0) / scale_y)
	)


func get_story_harvest_guidance_rect_local() -> Rect2:
	if not can_drag_for_inventory_harvest():
		return Rect2()
	if not is_instance_valid(sprite) or not sprite.has_method("get_rect"):
		return Rect2()
	var rect: Rect2 = sprite.get_rect()
	var crop_type = str(type)
	if crop_type == "tree":
		return _get_tree_harvest_hotspot_rect()
	if crop_type == "maize":
		return _rect_from_normalized(rect, HARVEST_GUIDE_MAIZE_RECT)
	if crop_type == "squash":
		return _rect_from_normalized(rect, HARVEST_GUIDE_SQUASH_RECT)
	if crop_type == "myco":
		return _rect_from_normalized(rect, HARVEST_GUIDE_MYCO_RECT)
	return _rect_from_normalized(rect, HARVEST_GUIDE_BEAN_RECT)


func _is_tree_harvest_hotspot_hit(world_pos: Vector2) -> bool:
	if not _is_tree_lifecycle_type():
		return false
	if not can_drag_for_inventory_harvest():
		return false

	var world = _get_world_foundation_node()
	if is_instance_valid(world) and world.has_method("world_to_tile"):
		var click_coord = Vector2i(world.world_to_tile(_clamp_position_to_world_rect(world_pos)))
		var base_coord = Vector2i(world.world_to_tile(_clamp_position_to_world_rect(global_position)))
		if click_coord != base_coord + Vector2i(0, -1):
			return false

	var acorn_center = global_position + TREE_HARVEST_ACORN_LOCAL_POS
	return world_pos.distance_squared_to(acorn_center) <= TREE_HARVEST_ACORN_HOTSPOT_RADIUS * TREE_HARVEST_ACORN_HOTSPOT_RADIUS


func _is_tree_occupied_tile_hit(world_pos: Vector2) -> bool:
	if not _is_tree_lifecycle_type():
		return false
	var world = _get_world_foundation_node()
	if not is_instance_valid(world) or not world.has_method("world_to_tile"):
		return false
	var click_coord = Vector2i(world.world_to_tile(_clamp_position_to_world_rect(world_pos)))
	var base_coord = Vector2i(world.world_to_tile(_clamp_position_to_world_rect(global_position)))
	return click_coord == base_coord or click_coord == base_coord + Vector2i(0, -1)


func _is_tile_occupied_focus_hit(world_pos: Vector2) -> bool:
	var world = _get_world_foundation_node()
	var level_root = _get_level_root()
	if not is_instance_valid(world) or not is_instance_valid(level_root):
		return false
	if not (world.has_method("world_to_tile") and world.has_method("in_bounds")):
		return false
	var coord = Vector2i(world.world_to_tile(_clamp_position_to_world_rect(world_pos)))
	if not world.in_bounds(coord):
		return false
	var occupied_tiles = LevelHelpersRef.get_agent_occupied_tiles(level_root, self)
	return occupied_tiles.has(coord)


func _is_focus_hit(world_pos: Vector2) -> bool:
	if _is_reposition_subject():
		return _is_tile_occupied_focus_hit(world_pos)
	if is_instance_valid(sprite) and sprite.has_method("get_rect"):
		if sprite.get_rect().has_point(to_local(world_pos)):
			return true
	return false


func _get_focus_distance_squared(world_pos: Vector2) -> float:
	var world = _get_world_foundation_node()
	var level_root = _get_level_root()
	if not is_instance_valid(world) or not is_instance_valid(level_root):
		return global_position.distance_squared_to(world_pos)
	if not (world.has_method("world_to_tile") and world.has_method("tile_to_world_center")):
		return global_position.distance_squared_to(world_pos)
	var best_dist = global_position.distance_squared_to(world_pos)
	for coord in LevelHelpersRef.get_agent_occupied_tiles(level_root, self):
		var center = world.tile_to_world_center(coord)
		best_dist = minf(best_dist, center.distance_squared_to(world_pos))
	return best_dist


func _is_press_hit(world_pos: Vector2) -> bool:
	if _is_tree_lifecycle_type():
		# Mature trees are intentionally strict on touch:
		# only the acorn hotspot should trigger harvest interactions.
		if can_drag_for_inventory_harvest():
			return _is_tree_harvest_hotspot_hit(world_pos)
		return _is_tree_occupied_tile_hit(world_pos)
	if is_instance_valid(sprite) and sprite.has_method("get_rect"):
		if sprite.get_rect().has_point(to_local(world_pos)):
			return true
	if not Global.is_mobile_platform:
		return false
	# Trees should avoid broad tile fallback on touch to prevent overlap stealing.
	if _is_tree_lifecycle_type():
		return false
	return _is_tile_occupied_focus_hit(world_pos)


func _set_drag_pointer_screen_pos(screen_pos: Vector2) -> void:
	_drag_pointer_screen_pos = screen_pos
	_has_drag_pointer_screen_pos = true


func _get_drag_pointer_screen_pos() -> Vector2:
	if _has_drag_pointer_screen_pos:
		return _drag_pointer_screen_pos
	var viewport = get_viewport()
	if viewport != null:
		return viewport.get_mouse_position()
	return Vector2.ZERO


func _get_drag_pointer_world_pos() -> Vector2:
	return Global.screen_to_world(self, _get_drag_pointer_screen_pos())


func _is_preferred_pointer_focus(screen_pos: Vector2) -> bool:
	var level_root = _get_level_root()
	var agents_root = get_parent()
	if not is_instance_valid(level_root) or not is_instance_valid(agents_root):
		return true
	var focus_agent = LevelHelpersRef.resolve_focus_agent_at_screen_pos(level_root, agents_root, screen_pos)
	return not is_instance_valid(focus_agent) or focus_agent == self


func _is_drag_pointer_held() -> bool:
	return _drag_pointer_down or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _can_pointer_activate_harvest() -> bool:
	if not can_drag_for_inventory_harvest():
		return false
	if not _is_press_hit(_get_drag_pointer_world_pos()):
		return false
	var level_root = _get_level_root()
	if is_instance_valid(level_root) and level_root.has_method("can_agent_harvest_to_inventory"):
		return bool(level_root.can_agent_harvest_to_inventory(self))
	return true


func _pointer_reposition_override_enabled() -> bool:
	return _global_reposition_override_enabled()


func _global_reposition_override_enabled() -> bool:
	return bool(Global.allow_agent_reposition)


func _activate_resource_bars_for_interaction() -> void:
	Global.active_agent = self
	Global.prevent_auto_select = false
	var level_root = _get_level_root()
	if is_instance_valid(level_root):
		LevelHelpersRef.set_hover_focus_agent(level_root, self)
	else:
		set_hover_focus(true)
	_refresh_all_agent_bar_visibility()


func _try_pointer_activate_harvest(screen_pos: Vector2) -> bool:
	if not _can_pointer_activate_harvest():
		return false
	_activate_resource_bars_for_interaction()
	_set_drag_pointer_screen_pos(screen_pos)
	_drag_pointer_down = false
	_cancel_tile_snap()
	_harvest_drag_only = true
	_start_harvest_drag_proxy()
	if _start_harvest_inventory_fly_in():
		return true
	_harvest_drag_only = false
	_end_harvest_drag_proxy()
	if supports_inventory_harvest():
		return try_harvest_to_inventory()
	return false


func _try_start_harvest_inventory_animation() -> bool:
	if _harvest_inventory_animating:
		return true
	_cancel_tile_snap()
	_harvest_drag_only = true
	_start_harvest_drag_proxy()
	if _start_harvest_inventory_fly_in():
		return true
	_harvest_drag_only = false
	_end_harvest_drag_proxy()
	if supports_inventory_harvest():
		return try_harvest_to_inventory()
	return false


func _on_pointer_press(screen_pos: Vector2) -> void:
	_set_drag_pointer_screen_pos(screen_pos)
	var world_click_pos = Global.screen_to_world(self, screen_pos)
	var clicked_self = _is_focus_hit(world_click_pos)
	var clicked_action_hit = _is_press_hit(world_click_pos)
	if clicked_self and not _is_preferred_pointer_focus(screen_pos):
		clicked_self = false
	_drag_pointer_down = clicked_self
	if clicked_self:
		_press_started_here = true
		_activate_resource_bars_for_interaction()
		var reposition_override = _pointer_reposition_override_enabled()
		if not reposition_override and _is_inventory_placement_active():
			# Inventory placement gestures should never start crop drag/harvest flows.
			_press_started_here = false
			_drag_pointer_down = false
			return
		if not reposition_override and _can_pointer_activate_harvest():
			return
		if clicked_action_hit and Global.is_dragging == false and _can_start_user_drag():
			_harvest_drag_only = false
			is_dragging = true
			Global.is_dragging = true
			_cancel_tile_snap()
			if _harvest_drag_only:
				_start_harvest_drag_proxy()
			else:
				_end_harvest_drag_proxy()
	else:
		_press_started_here = false


func _on_pointer_release(screen_pos: Vector2) -> void:
	_set_drag_pointer_screen_pos(screen_pos)
	_drag_pointer_down = false
	var world_click_pos = Global.screen_to_world(self, screen_pos)
	var clicked_self = _is_focus_hit(world_click_pos)
	var pressed_here = _press_started_here
	_press_started_here = false
	var reposition_override = _pointer_reposition_override_enabled()
	if not reposition_override and _is_inventory_placement_active():
		return
	if not reposition_override and pressed_here and clicked_self and _try_pointer_activate_harvest(screen_pos):
		return
	var was_dragging = is_dragging
	if was_dragging:
		is_dragging = false
		Global.is_dragging = false
		if _harvest_drag_only:
			var dropped_to_story_target := false
			var level_root = _get_level_root()
			if is_instance_valid(level_root) and level_root.has_method("try_story_harvest_drop"):
				dropped_to_story_target = bool(level_root.try_story_harvest_drop(self, _get_drag_pointer_world_pos()))
			_end_harvest_drag_proxy()
			if not dropped_to_story_target:
				_begin_snap_to_nearest_tile(position)
		else:
			_begin_snap_to_nearest_tile(position)
		_harvest_drag_only = false
		_clear_drag_tile_hint()
	if pressed_here and clicked_self:
		_activate_resource_bars_for_interaction()


func _get_level_root() -> Node:
	return get_node_or_null("../..")


func _is_inventory_placement_active() -> bool:
	var ui_node = get_node_or_null("../../UI")
	if not is_instance_valid(ui_node):
		return false
	if ui_node.has_method("is_inventory_placement_active"):
		return bool(ui_node.call("is_inventory_placement_active"))
	var selected_item = str(ui_node.get("_selected_inventory_item"))
	return selected_item != ""


func _get_agents_root() -> Node:
	return get_node_or_null("../../Agents")


func _refresh_all_agent_bar_visibility() -> void:
	var agents_root = _get_agents_root()
	if is_instance_valid(agents_root):
		LevelHelpersRef.refresh_agent_bar_visibility(agents_root)


func _queue_dirty_update(buddies: bool = true, lines: bool = true, tile_hint: bool = false) -> void:
	var level_root = _get_level_root()
	if is_instance_valid(level_root) and level_root.has_method("request_agent_dirty"):
		level_root.request_agent_dirty(self, buddies, lines, tile_hint)
		return
	new_buddies = buddies or new_buddies
	if lines and str(type) == "myco":
		draw_lines = true


func _sync_occupancy_cache() -> void:
	if str(type) == "cloud":
		return
	var level_root = _get_level_root()
	if not is_instance_valid(level_root):
		return
	LevelHelpersRef.sync_agent_occupancy(level_root, self)


func _uses_tile_snap() -> bool:
	if str(type) == "cloud":
		return false
	var world = _get_world_foundation_node()
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


func _clamp_position_to_world_rect(candidate: Vector2) -> Vector2:
	var rect = Global.get_world_rect(self)
	var max_x = rect.position.x + rect.size.x - 0.001
	var max_y = rect.position.y + rect.size.y - 0.001
	return Vector2(
		clampf(candidate.x, rect.position.x, max_x),
		clampf(candidate.y, rect.position.y, max_y)
	)


func _is_tile_occupied(_world: Node, coord: Vector2i) -> bool:
	var level_root = _get_level_root()
	var agents_root = _get_agents_root()
	if not is_instance_valid(level_root) or not is_instance_valid(agents_root):
		return false
	return LevelHelpersRef.is_tile_occupied(level_root, agents_root, coord, self)


func _can_place_on_tile(coord: Vector2i, sprite_scale_override: Variant = null) -> bool:
	if not _uses_tile_snap():
		return true
	var world = _get_world_foundation_node()
	var level_root = _get_level_root()
	var agents_root = _get_agents_root()
	if not is_instance_valid(world) or not is_instance_valid(level_root) or not is_instance_valid(agents_root):
		return true
	var clamped_coord = _clamp_tile_coord(world, coord)
	return LevelHelpersRef.can_place_agent_on_tile(level_root, agents_root, self, clamped_coord, self, sprite_scale_override)


func _can_expand_to_scale(scale_candidate: Vector2) -> bool:
	if str(type) != "tree":
		return true
	if not _uses_tile_snap():
		return true
	var world = _get_world_foundation_node()
	if not is_instance_valid(world):
		return true
	var current_coord = _clamp_tile_coord(world, world.world_to_tile(_clamp_position_to_world_rect(position)))
	return _can_place_on_tile(current_coord, scale_candidate)


func _get_tree_single_tile_spawn_scale() -> float:
	var target_tile_pixels := 56.0
	var texture_max_dim := 0.0
	if is_instance_valid(sprite_texture):
		var texture_size = sprite_texture.get_size()
		texture_max_dim = maxf(texture_size.x, texture_size.y)
	if texture_max_dim <= 0.0:
		return min_scale

	var base_scale_max := 1.0
	if is_instance_valid(sprite):
		base_scale_max = maxf(abs(sprite.scale.x), abs(sprite.scale.y))
	if base_scale_max <= 0.0:
		base_scale_max = 1.0

	var fit_scale = target_tile_pixels / (texture_max_dim * base_scale_max)
	return clampf(fit_scale, 0.08, 1.0)


func _find_nearest_free_tile_coord(world: Node, origin: Vector2i, max_radius: int = 12) -> Vector2i:
	if _can_place_on_tile(origin):
		return origin
	for radius in range(1, max(max_radius, 1) + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var coord = origin + Vector2i(dx, dy)
				if not world.in_bounds(coord):
					continue
				if _can_place_on_tile(coord):
					return coord
	return Vector2i(-1, -1)


func _get_snap_target(candidate: Vector2) -> Vector2:
	if not _uses_tile_snap():
		return _clamp_position_to_world(candidate)

	var world = _get_world_foundation_node()
	var bounded_candidate = _clamp_position_to_world_rect(candidate)
	var target_coord = _clamp_tile_coord(world, world.world_to_tile(bounded_candidate))
	var current_coord = _clamp_tile_coord(world, world.world_to_tile(_clamp_position_to_world_rect(position)))
	var free_coord = _find_nearest_free_tile_coord(world, target_coord, 12)
	if free_coord.x >= 0 and free_coord.y >= 0:
		return world.tile_to_world_center(free_coord)
	if _can_place_on_tile(current_coord):
		return world.tile_to_world_center(current_coord)
	return world.tile_to_world_center(current_coord)


func _begin_snap_to_nearest_tile(candidate: Vector2 = position) -> void:
	if not _uses_tile_snap():
		_tile_snap_in_progress = false
		return
	_tile_snap_target = _get_snap_target(candidate)
	_tile_snap_in_progress = true


func _cancel_tile_snap() -> void:
	_tile_snap_in_progress = false


func _advance_tile_snap(delta: float) -> void:
	if not _tile_snap_in_progress:
		return
	var t = min(1.0, 14.0 * delta)
	position = position.lerp(_tile_snap_target, t)
	if position.distance_to(_tile_snap_target) < 0.5:
		position = _tile_snap_target
		_tile_snap_in_progress = false


func _update_drag_tile_hint(world_pos: Vector2) -> void:
	if not _uses_tile_snap():
		_clear_drag_tile_hint()
		return
	var world = _get_world_foundation_node()
	if not is_instance_valid(world):
		return
	if not world.has_method("set_drag_tile_hint"):
		return
	var bounded = _clamp_position_to_world_rect(world_pos)
	var coord = _clamp_tile_coord(world, world.world_to_tile(bounded))
	world.set_drag_tile_hint(coord, _can_place_on_tile(coord))
	_drag_hint_active = true


func _clear_drag_tile_hint() -> void:
	if not _drag_hint_active:
		return
	var world = _get_world_foundation_node()
	if is_instance_valid(world) and world.has_method("clear_drag_tile_hint"):
		world.clear_drag_tile_hint()
	_drag_hint_active = false


func _get_harvest_drag_texture() -> Texture2D:
	if is_instance_valid(sprite_texture):
		return sprite_texture
	if is_instance_valid(sprite) and is_instance_valid(sprite.texture):
		return sprite.texture
	return null


func _get_harvest_drag_display_scale() -> Vector2:
	if _is_bean_lifecycle_enabled():
		return bean_base_scale
	if is_instance_valid(sprite):
		return sprite.scale
	return Vector2.ONE


func _get_harvest_inventory_key() -> String:
	return str(type)


func _get_harvest_drag_host() -> Node:
	var level_root = _get_level_root()
	if not is_instance_valid(level_root):
		return null
	var ui_node = level_root.get_node_or_null("UI")
	if is_instance_valid(ui_node):
		return ui_node
	return level_root


func _get_harvest_inventory_target_screen_pos() -> Vector2:
	var level_root = _get_level_root()
	if not is_instance_valid(level_root):
		return get_viewport().get_mouse_position()
	var ui_node = level_root.get_node_or_null("UI")
	if is_instance_valid(ui_node) and ui_node.has_method("get_inventory_icon_center"):
		var key = _get_harvest_inventory_key()
		return ui_node.call("get_inventory_icon_center", key)
	return get_viewport().get_mouse_position()


func _get_harvest_inventory_target_proxy_pos() -> Vector2:
	var screen_pos = _get_harvest_inventory_target_screen_pos()
	if _harvest_drag_proxy_in_ui:
		return screen_pos
	return Global.screen_to_world(self, screen_pos)


func _start_harvest_inventory_fly_in() -> bool:
	if _harvest_inventory_animating:
		return true
	if not _harvest_drag_only:
		return false
	if not is_instance_valid(_harvest_drag_sprite):
		return false
	_harvest_inventory_animating = true
	is_dragging = false
	Global.is_dragging = false
	_clear_drag_tile_hint()
	var target_pos = _get_harvest_inventory_target_proxy_pos()
	var tween = get_tree().create_tween()
	tween.tween_property(_harvest_drag_sprite, "global_position", target_pos, 0.14)
	tween.finished.connect(_on_harvest_inventory_fly_in_finished)
	return true


func _on_harvest_inventory_fly_in_finished() -> void:
	if not _harvest_inventory_animating:
		return
	_harvest_inventory_animating = false
	var harvested := false
	if supports_inventory_harvest():
		harvested = try_harvest_to_inventory()
	_end_harvest_drag_proxy()
	_harvest_drag_only = false
	if not harvested:
		_begin_snap_to_nearest_tile(position)


func _start_harvest_drag_proxy() -> void:
	if not _harvest_drag_only:
		_end_harvest_drag_proxy()
		return
	_begin_harvest_visual_detach()
	if is_instance_valid(_harvest_drag_sprite):
		_update_harvest_drag_proxy_position()
		return
	var harvest_texture := _get_harvest_drag_texture()
	if not is_instance_valid(harvest_texture):
		return
	var host = _get_harvest_drag_host()
	if not is_instance_valid(host):
		return
	var drag_sprite := Sprite2D.new()
	drag_sprite.texture = harvest_texture
	_harvest_drag_proxy_in_ui = host is CanvasLayer
	drag_sprite.top_level = not _harvest_drag_proxy_in_ui
	drag_sprite.z_index = 2000
	drag_sprite.z_as_relative = false
	drag_sprite.modulate = Color(1.0, 1.0, 1.0, 0.96)
	var drag_scale := _get_harvest_drag_display_scale()
	if drag_scale == Vector2.ZERO:
		drag_scale = Vector2.ONE
	drag_sprite.scale = drag_scale
	host.add_child(drag_sprite)
	_harvest_drag_sprite = drag_sprite
	_update_harvest_drag_proxy_position()


func _update_harvest_drag_proxy_position() -> void:
	if not is_instance_valid(_harvest_drag_sprite):
		return
	if _harvest_drag_proxy_in_ui:
		_harvest_drag_sprite.global_position = _get_drag_pointer_screen_pos()
	else:
		_harvest_drag_sprite.global_position = _get_drag_pointer_world_pos()


func _end_harvest_drag_proxy() -> void:
	_harvest_inventory_animating = false
	_harvest_drag_proxy_in_ui = false
	if is_instance_valid(_harvest_drag_sprite):
		_harvest_drag_sprite.queue_free()
	_harvest_drag_sprite = null
	if _harvest_visual_detached:
		_cancel_harvest_visual_detach()


func is_trade_locked_by_user_move() -> bool:
	if not draggable:
		return false
	if is_dragging or _keyboard_moving:
		return true
	var is_active = is_instance_valid(Global.active_agent) and Global.active_agent == self
	if is_active:
		return Input.get_vector("left", "right", "up", "down") != Vector2.ZERO
	return false


func _clear_active_selection_if_self() -> void:
	var active_matches_self := false
	if Global.active_agent != null and is_instance_valid(Global.active_agent):
		active_matches_self = Global.active_agent == self or Global.active_agent.name == self.name
	if not active_matches_self:
		return
	var level_root = _get_level_root()
	if is_instance_valid(level_root):
		LevelHelpersRef.clear_focus_outline_if_owner(level_root, self)
	Global.active_agent = null
	Global.prevent_auto_select = true
	_refresh_all_agent_bar_visibility()


func _is_reposition_subject() -> bool:
	var entity_type = str(type)
	return entity_type == "bean" or entity_type == "squash" or entity_type == "maize" or entity_type == "tree" or entity_type == "myco"


func _is_hover_bar_subject() -> bool:
	if _is_reposition_subject():
		return true
	if _is_story_village_actor_node(self):
		return true
	var entity_type = str(type)
	return entity_type == "farmer" or entity_type == "vendor" or entity_type == "cook" or entity_type == "basket"


func _is_story_mode_runtime() -> bool:
	if Global.has_method("is_parallel_village_runtime"):
		return bool(Global.is_parallel_village_runtime())
	return str(Global.mode) == "story"


func _is_story_village_actor_node(node: Variant) -> bool:
	return is_instance_valid(node) and bool(node.get_meta("story_village_actor", false))


func _is_story_village_person_node(node: Variant) -> bool:
	if not _is_story_village_actor_node(node):
		return false
	var node_type = str(node.get("type"))
	return node_type == "farmer" or node_type == "vendor" or node_type == "cook"


func _can_share_story_trade_network(candidate: Variant) -> bool:
	if not is_instance_valid(candidate):
		return false
	if bool(candidate.get("dead")):
		return false
	if str(candidate.get("type")) == "cloud":
		return false
	if not _is_story_mode_runtime():
		return true
	var self_is_village_actor = _is_story_village_actor_node(self)
	var candidate_is_village_actor = _is_story_village_actor_node(candidate)
	return self_is_village_actor == candidate_is_village_actor


func _can_user_reposition() -> bool:
	if _global_reposition_override_enabled():
		return true
	if _is_story_village_actor_node(self) and str(type) == "myco":
		return true
	if not _is_reposition_subject():
		return true
	return bool(Global.allow_agent_reposition)


func can_drag_for_inventory_harvest() -> bool:
	return _is_bean_lifecycle_enabled() and bean_harvest_ready and bean_stage == BeanGrowthStage.POD_READY


func _can_start_user_drag() -> bool:
	if not draggable and not _global_reposition_override_enabled():
		return false
	return _can_user_reposition()


func _is_bean_lifecycle_enabled() -> bool:
	if Global.social_mode:
		return false
	var crop_type = str(type)
	return crop_type == "bean" or crop_type == "squash" or crop_type == "maize" or crop_type == "tree"


func _get_lifecycle_crop_type() -> String:
	var crop_type = str(type)
	if crop_type == "tree":
		return "tree"
	if crop_type == "maize":
		return "maize"
	if crop_type == "squash":
		return "squash"
	return "bean"


func _get_trade_speed_ratio_for_starvation() -> float:
	var move_rate_ratio := float(Global.move_rate) / BASE_MOVE_RATE_FOR_STARVATION
	var movement_speed_ratio := float(Global.movement_speed) / BASE_MOVEMENT_SPEED_FOR_STARVATION
	var combined_ratio := (move_rate_ratio + movement_speed_ratio) * 0.5
	return clampf(combined_ratio, MIN_STARVATION_SPEED_SCALE, 1.0)


func _get_starvation_alpha_step() -> float:
	return maxf(alpha_step_down * _get_trade_speed_ratio_for_starvation(), 0.0001)


func _get_lifecycle_spawn_anchor() -> Variant:
	if not bool(get_meta("lifecycle_spawn_child", false)):
		return null
	var anchor = get_meta("lifecycle_spawn_anchor", null)
	if not is_instance_valid(anchor):
		return null
	if bool(anchor.get("dead")):
		return null
	if str(anchor.get("type")) != "myco":
		return null
	if not _can_share_story_trade_network(anchor):
		return null
	var level_root = _get_level_root()
	if LevelHelpersRef._supports_tile_world(level_root):
		if not LevelHelpersRef.are_agents_in_tile_reach(level_root, self, anchor, true):
			return null
	else:
		var reach = anchor.get("buddy_radius")
		var max_dist := 0.0
		if typeof(reach) == TYPE_FLOAT or typeof(reach) == TYPE_INT:
			max_dist = maxf(float(reach), 0.0)
		if max_dist <= 0.0:
			return null
		if global_position.distance_to(anchor.global_position) > max_dist:
			return null
	return anchor


func _has_trade_buddy_link_to(target: Variant) -> bool:
	if not is_instance_valid(target):
		return false
	for buddy in trade_buddies:
		if buddy == target:
			return true
	return false


func _restore_lifecycle_spawn_anchor_buddy() -> void:
	var anchor = _get_lifecycle_spawn_anchor()
	if not is_instance_valid(anchor):
		return
	if not _has_trade_buddy_link_to(anchor):
		trade_buddies.append(anchor)


func _restore_story_forced_village_basket_buddies() -> void:
	if not _is_story_village_person_node(self):
		return
	var agents_root = _get_agents_root()
	if not is_instance_valid(agents_root):
		return
	for candidate in agents_root.get_children():
		if not is_instance_valid(candidate):
			continue
		if candidate == self:
			continue
		if bool(candidate.get("dead")):
			continue
		if str(candidate.get("type")) != "myco":
			continue
		if not bool(candidate.get_meta(STORY_PHASE5_FORCED_BASKET_LINK_META, false)):
			continue
		if not _can_share_story_trade_network(candidate):
			continue
		if not _has_trade_buddy_link_to(candidate):
			trade_buddies.append(candidate)


func _is_lifecycle_orphan_spawn_child() -> bool:
	if not _is_bean_lifecycle_enabled():
		return false
	if not bool(get_meta("lifecycle_spawn_child", false)):
		return false
	var anchor = _get_lifecycle_spawn_anchor()
	if not is_instance_valid(anchor):
		return true
	return not _has_trade_buddy_link_to(anchor)


func _spawn_growth_sparkle() -> void:
	var sparkle = Global.sparkle_scene.instantiate()
	sparkle.z_as_relative = false
	sparkle.position = self.position
	sparkle.global_position = self.global_position
	$"../../Sparkles".add_child(sparkle)
	sparkle.start(0.75)


func _find_nearby_living_myco_anchor(reference_pos: Vector2, max_tiles: int = LIFECYCLE_PARENT_BOUND_TILES) -> Node:
	var agents_root = _get_agents_root()
	if not is_instance_valid(agents_root):
		return null
	var world = _get_world_foundation_node()
	var use_tiles = _uses_tile_snap() and is_instance_valid(world)
	var safe_max_tiles = maxi(max_tiles, 0)
	var reference_coord := Vector2i.ZERO
	var max_pixel_distance := float(safe_max_tiles) * 64.0
	if is_instance_valid(world):
		var tile_size = float(world.get("tile_size"))
		if tile_size > 0.0:
			max_pixel_distance = float(safe_max_tiles) * tile_size
	if use_tiles:
		reference_coord = _clamp_tile_coord(world, Vector2i(world.world_to_tile(_clamp_position_to_world_rect(reference_pos))))
	var best_anchor: Node = null
	var best_distance := INF
	for candidate in agents_root.get_children():
		if not is_instance_valid(candidate):
			continue
		if candidate == self:
			continue
		if bool(candidate.get("dead")):
			continue
		if str(candidate.get("type")) != "myco":
			continue
		if _is_story_mode_runtime() and _is_story_village_actor_node(candidate):
			continue
		var distance_value := INF
		if use_tiles:
			var candidate_coord = _clamp_tile_coord(world, Vector2i(world.world_to_tile(_clamp_position_to_world_rect(candidate.global_position))))
			distance_value = float(maxi(abs(candidate_coord.x - reference_coord.x), abs(candidate_coord.y - reference_coord.y)))
			if distance_value > float(safe_max_tiles):
				continue
		else:
			distance_value = candidate.global_position.distance_to(reference_pos)
			if distance_value > max_pixel_distance:
				continue
		if distance_value < best_distance:
			best_distance = distance_value
			best_anchor = candidate
	return best_anchor


func _get_bean_stage_scale_multiplier(stage_value: int) -> float:
	var crop_type = _get_lifecycle_crop_type()
	if crop_type == "tree":
		match stage_value:
			BeanGrowthStage.SPROUT:
				return 3.6
			BeanGrowthStage.VINE:
				return 5.8
			BeanGrowthStage.POD_READY:
				return 6.0
			BeanGrowthStage.DEAD:
				return 5.2
			_:
				return 3.6

	if crop_type == "maize":
		match stage_value:
			BeanGrowthStage.SPROUT:
				return 1.2
			BeanGrowthStage.VINE:
				return 1.95
			BeanGrowthStage.POD_READY:
				return 2.25
			BeanGrowthStage.DEAD:
				return 1.75
			_:
				return 1.2

	if crop_type == "squash":
		match stage_value:
			BeanGrowthStage.SPROUT:
				return 1.35
			BeanGrowthStage.VINE:
				return 1.85
			BeanGrowthStage.POD_READY:
				return 2.25
			BeanGrowthStage.DEAD:
				return 1.6
			_:
				return 1.35

	match stage_value:
		BeanGrowthStage.SPROUT:
			return 1.5
		BeanGrowthStage.VINE:
			return 1.9
		BeanGrowthStage.POD_READY:
			return 2.4
		BeanGrowthStage.DEAD:
			return 1.7
		_:
			return 1.5


func _get_bean_stage_target_scale(stage_value: int) -> Vector2:
	return bean_base_scale * _get_bean_stage_scale_multiplier(stage_value)


func _get_lifecycle_stage_sprite_offset(stage_value: int) -> Vector2:
	var crop_type = _get_lifecycle_crop_type()
	if crop_type != "tree":
		return Vector2.ZERO
	# Shift tree visuals upward so the visible tree explains its two-tile footprint.
	match stage_value:
		BeanGrowthStage.SPROUT:
			return Vector2(0.0, -36.0)
		BeanGrowthStage.VINE, BeanGrowthStage.POD_READY, BeanGrowthStage.DEAD:
			return Vector2(0.0, -56.0)
		_:
			return Vector2(0.0, -36.0)


func _ensure_tree_harvest_sprite() -> void:
	if not _is_tree_lifecycle_type():
		return
	if is_instance_valid(tree_harvest_sprite):
		return
	var acorn_sprite := Sprite2D.new()
	acorn_sprite.name = "HarvestAcorn"
	var loaded_texture = ResourceLoader.load(TEX_ACORN_HARVEST_PATH)
	if loaded_texture is Texture2D:
		acorn_sprite.texture = loaded_texture
	acorn_sprite.position = TREE_HARVEST_ACORN_LOCAL_POS
	acorn_sprite.z_as_relative = false
	acorn_sprite.z_index = 115
	acorn_sprite.visible = false
	add_child(acorn_sprite)
	tree_harvest_sprite = acorn_sprite


func _refresh_tree_harvest_acorn_visual() -> void:
	if not _is_tree_lifecycle_type():
		if is_instance_valid(tree_harvest_sprite):
			tree_harvest_sprite.visible = false
		return
	var should_show = bean_stage == BeanGrowthStage.POD_READY and bean_harvest_ready and not _harvest_visual_detached and not bool(dead)
	if should_show:
		_ensure_tree_harvest_sprite()
	if is_instance_valid(tree_harvest_sprite):
		tree_harvest_sprite.position = TREE_HARVEST_ACORN_LOCAL_POS
		tree_harvest_sprite.visible = should_show


func _get_lifecycle_texture_scale_adjust(texture: Texture2D) -> Vector2:
	if not is_instance_valid(texture):
		return Vector2.ONE
	if not is_instance_valid(sprite_texture):
		return Vector2.ONE
	var base_size: Vector2 = sprite_texture.get_size()
	var stage_size: Vector2 = texture.get_size()
	if base_size.x <= 0.0 or base_size.y <= 0.0:
		return Vector2.ONE
	if stage_size.x <= 0.0 or stage_size.y <= 0.0:
		return Vector2.ONE
	return Vector2(
		base_size.x / stage_size.x,
		base_size.y / stage_size.y
	)


func _get_stage_texture_scale_adjust(texture: Texture2D, stage_value: int) -> Vector2:
	var adjust = _get_lifecycle_texture_scale_adjust(texture)
	# Squash lifecycle art uses wider stage atlases than the base inventory sprite.
	# Preserve squash stage aspect ratio with uniform scaling so the full plant
	# (sprout/vine/pod/dead) does not get squeezed.
	if _get_lifecycle_crop_type() == "squash":
		var uniform = maxf(adjust.x, adjust.y)
		return Vector2(uniform, uniform)
	return adjust


func _get_lifecycle_stage_texture_path(stage_value: int) -> String:
	var crop_type = _get_lifecycle_crop_type()
	if crop_type == "tree":
		match stage_value:
			BeanGrowthStage.SEED:
				return TEX_ACORN_TREE_VINE_STAGE_PATH
			BeanGrowthStage.SPROUT:
				return TEX_ACORN_TREE_VINE_STAGE_PATH
			BeanGrowthStage.VINE:
				return TEX_ACORN_TREE_VINE_STAGE_PATH
			BeanGrowthStage.POD_READY:
				return TEX_ACORN_TREE_VINE_STAGE_PATH
			BeanGrowthStage.DEAD:
				return TEX_ACORN_TREE_DEAD_STAGE_PATH
		return TEX_ACORN_TREE_VINE_STAGE_PATH

	if crop_type == "maize":
		match stage_value:
			BeanGrowthStage.SEED:
				return TEX_MAIZE_SPROUT_STAGE_PATH
			BeanGrowthStage.SPROUT:
				return TEX_MAIZE_SPROUT_STAGE_PATH
			BeanGrowthStage.VINE:
				return TEX_MAIZE_VINE_STAGE_PATH
			BeanGrowthStage.POD_READY:
				return TEX_MAIZE_POD_STAGE_PATH
			BeanGrowthStage.DEAD:
				return TEX_MAIZE_DEAD_STAGE_PATH
		return TEX_MAIZE_SPROUT_STAGE_PATH

	if crop_type == "squash":
		match stage_value:
			BeanGrowthStage.SEED:
				return TEX_SQUASH_SPROUT_STAGE_PATH
			BeanGrowthStage.SPROUT:
				return TEX_SQUASH_SPROUT_STAGE_PATH
			BeanGrowthStage.VINE:
				return TEX_SQUASH_VINE_STAGE_PATH
			BeanGrowthStage.POD_READY:
				return TEX_SQUASH_POD_STAGE_PATH
			BeanGrowthStage.DEAD:
				return TEX_SQUASH_DEAD_STAGE_PATH
		return TEX_SQUASH_SPROUT_STAGE_PATH

	match stage_value:
		BeanGrowthStage.SEED:
			return TEX_BEAN_SPROUT_STAGE_PATH
		BeanGrowthStage.SPROUT:
			return TEX_BEAN_SPROUT_STAGE_PATH
		BeanGrowthStage.VINE:
			return TEX_BEAN_VINE_STAGE_PATH
		BeanGrowthStage.POD_READY:
			return TEX_BEAN_POD_STAGE_PATH
		BeanGrowthStage.DEAD:
			return TEX_BEAN_DEAD_STAGE_PATH
	return TEX_BEAN_SPROUT_STAGE_PATH


func _should_preserve_stage_visual_on_starvation_death(stage_value: int) -> bool:
	return stage_value == BeanGrowthStage.SEED or stage_value == BeanGrowthStage.SPROUT


func _load_bean_stage_texture(path: String) -> Texture2D:
	if bean_stage_textures.has(path):
		var cached = bean_stage_textures[path]
		if cached is Texture2D:
			return cached
	var loaded = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if not (loaded is Texture2D):
		loaded = ResourceLoader.load(path)
	if loaded is Texture2D:
		bean_stage_textures[path] = loaded
		return loaded
	return null


func _set_bean_stage(new_stage: int, force: bool = false) -> void:
	if not _is_bean_lifecycle_enabled():
		return
	if new_stage == BeanGrowthStage.SEED:
		new_stage = BeanGrowthStage.SPROUT
	if not force and bean_stage == new_stage:
		return

	var previous_stage := bean_stage
	bean_stage = new_stage
	bean_harvest_ready = bean_stage == BeanGrowthStage.POD_READY
	if bean_stage != BeanGrowthStage.DEAD:
		bean_death_preserve_stage_visual = false
		bean_death_visual_stage = bean_stage
		bean_death_regrowth_allowed = true
		bean_residue_pending = false
		bean_residue_emitted = false
	draggable = bean_stage != BeanGrowthStage.DEAD
	if bean_stage == BeanGrowthStage.DEAD:
		_hide_resource_bars()
		if not bean_death_preserve_stage_visual:
			bean_death_visual_stage = BeanGrowthStage.DEAD
		elif bean_death_visual_stage == BeanGrowthStage.DEAD:
			bean_death_visual_stage = previous_stage
		_clear_active_selection_if_self()
		if bean_respawn_wait_ticks <= 0:
			bean_respawn_wait_ticks = BEAN_DEAD_RESPAWN_DELAY_TICKS
		bean_respawn_requested = false
		bean_post_harvest_senescence = false
		bean_post_harvest_ticks = 0
	var visual_stage := bean_stage
	if bean_stage == BeanGrowthStage.DEAD and bean_death_preserve_stage_visual:
		visual_stage = bean_death_visual_stage
	var next_path = _get_lifecycle_stage_texture_path(visual_stage)
	var next_texture: Texture2D = _load_bean_stage_texture(next_path)
	if not is_instance_valid(next_texture):
		next_texture = sprite_texture

	if is_instance_valid(sprite):
		sprite.texture = next_texture
		sprite.modulate = Color.WHITE
		sprite.offset = _get_lifecycle_stage_sprite_offset(visual_stage)
		var stage_scale = _get_bean_stage_target_scale(visual_stage)
		stage_scale *= _get_stage_texture_scale_adjust(next_texture, visual_stage)
		if bean_stage == BeanGrowthStage.DEAD:
			if not bean_death_preserve_stage_visual:
				sprite.modulate = Color(0.92, 0.86, 0.78, 1.0)
			sprite.scale = stage_scale
		elif not force:
			var base_scale: Vector2 = stage_scale
			sprite.scale = base_scale
			var tween = get_tree().create_tween()
			tween.tween_property(sprite, "scale", base_scale * 1.05, 0.07)
			tween.tween_property(sprite, "scale", base_scale, 0.09)
		else:
			sprite.scale = stage_scale

	if bean_stage == BeanGrowthStage.POD_READY and not bean_pod_sparkle_played:
		_spawn_growth_sparkle()
		bean_pod_sparkle_played = true
	_refresh_tree_harvest_acorn_visual()


func _reset_bean_lifecycle() -> void:
	bean_pod_ticks = 0
	bean_dead_ticks = 0
	bean_starvation_ticks = 0
	bean_stage_consumptions = 0
	bean_stage_wait_ticks = 0
	bean_respawn_wait_ticks = 0
	bean_death_preserve_stage_visual = false
	bean_death_visual_stage = BeanGrowthStage.SPROUT
	bean_death_regrowth_allowed = true
	bean_respawn_requested = false
	bean_post_harvest_senescence = false
	bean_post_harvest_ticks = 0
	bean_harvest_ready = false
	bean_pod_sparkle_played = false
	bean_residue_pending = false
	bean_residue_emitted = false
	_farmer_harvest_delivery_reserved = false
	bean_stage = BeanGrowthStage.SPROUT
	_set_bean_stage(BeanGrowthStage.SPROUT, true)


func _enter_lifecycle_starvation_death() -> void:
	var visual_stage := bean_stage
	var allow_regrowth: bool = _is_tree_lifecycle_type() or bean_stage == BeanGrowthStage.POD_READY or bean_post_harvest_senescence
	bean_harvest_ready = false
	bean_dead_ticks = 0
	bean_respawn_wait_ticks = BEAN_DEAD_RESPAWN_DELAY_TICKS
	bean_respawn_requested = false
	bean_post_harvest_senescence = false
	bean_post_harvest_ticks = 0
	bean_residue_pending = false
	bean_residue_emitted = false
	bean_death_preserve_stage_visual = _should_preserve_stage_visual_on_starvation_death(visual_stage)
	bean_death_visual_stage = visual_stage
	bean_death_regrowth_allowed = allow_regrowth
	_set_bean_stage(BeanGrowthStage.DEAD)


func _emit_death_cycle_regrowth_request() -> void:
	if not _is_bean_lifecycle_enabled():
		return
	var world_pos := global_position
	var parent_anchor: Node = null
	var world = _get_world_foundation_node()
	if is_instance_valid(world) and world.has_method("world_to_tile") and world.has_method("tile_to_world_center") and world.has_method("in_bounds"):
		var coord = Vector2i(world.world_to_tile(_clamp_position_to_world_rect(global_position)))
		if not world.in_bounds(coord):
			return
		world_pos = world.tile_to_world_center(coord)
	parent_anchor = _find_nearby_living_myco_anchor(world_pos, LIFECYCLE_PARENT_BOUND_TILES)
	if not is_instance_valid(parent_anchor):
		return
	var new_agent_dict = {
		"name": str(type),
		"pos": world_pos,
		"require_exact_tile": true,
		"ignore_agent": self,
		"parent_anchor": parent_anchor,
		"max_parent_tiles": LIFECYCLE_PARENT_BOUND_TILES
	}
	emit_signal("new_agent", new_agent_dict)


func _emit_lifecycle_residue_signal(biomass: float, source_type: String) -> void:
	var world = _get_world_foundation_node()
	if not is_instance_valid(world):
		return
	if not (world.has_method("world_to_tile") and world.has_method("in_bounds")):
		return
	var coord = Vector2i(world.world_to_tile(_clamp_position_to_world_rect(global_position)))
	if not world.in_bounds(coord):
		return
	emit_signal("lifecycle_residue", coord, biomass, source_type)


func _is_tree_lifecycle_type() -> bool:
	return _is_bean_lifecycle_enabled() and str(type) == "tree"


func _can_tree_lifecycle_stage_fit(stage_value: int) -> bool:
	if not _is_tree_lifecycle_type():
		return true
	if not _uses_tile_snap():
		return true
	var stage_path = _get_lifecycle_stage_texture_path(stage_value)
	var stage_texture: Texture2D = _load_bean_stage_texture(stage_path)
	if not is_instance_valid(stage_texture):
		stage_texture = sprite_texture
	if not is_instance_valid(stage_texture):
		return true
	var stage_scale = _get_bean_stage_target_scale(stage_value) * _get_lifecycle_texture_scale_adjust(stage_texture)
	return _can_expand_to_scale(stage_scale)


func _get_lifecycle_stage_consumptions_required() -> int:
	# Trees intentionally mature more slowly than annual crops.
	if _is_tree_lifecycle_type():
		return BEAN_STAGE_CONSUMPTIONS_PER_ADVANCE * 2
	return BEAN_STAGE_CONSUMPTIONS_PER_ADVANCE


func _advance_bean_lifecycle(consumed_all_nutrients: bool) -> void:
	if not _is_bean_lifecycle_enabled():
		return

	if bean_stage == BeanGrowthStage.DEAD:
		bean_dead_ticks += 1
		if is_instance_valid(sprite):
			var fade_left = 1.0 - (float(bean_dead_ticks) / float(max(BEAN_DEAD_CLEANUP_TICKS, 1)))
			var c = sprite.modulate
			c.a = clampf(fade_left, 0.0, 1.0)
			sprite.modulate = c
		if bean_dead_ticks < BEAN_DEAD_CLEANUP_TICKS:
			return
		if bean_respawn_wait_ticks > 0:
			bean_respawn_wait_ticks -= 1
			return
		if not bean_respawn_requested:
			if bean_death_regrowth_allowed and bean_residue_pending and not bean_residue_emitted:
				_emit_lifecycle_residue_signal(1.0, str(type))
				bean_residue_emitted = true
			bean_respawn_requested = true
			dead = true
			if bean_death_regrowth_allowed:
				_emit_death_cycle_regrowth_request()
		if killable:
			kill_it()
		return

	if bean_post_harvest_senescence:
		if _is_tree_lifecycle_type():
			bean_post_harvest_senescence = false
			bean_post_harvest_ticks = 0
			return
		bean_post_harvest_ticks += 1
		if bean_post_harvest_ticks >= BEAN_POST_HARVEST_TO_DEAD_TICKS:
			bean_harvest_ready = false
			bean_dead_ticks = 0
			bean_respawn_wait_ticks = BEAN_DEAD_RESPAWN_DELAY_TICKS
			bean_respawn_requested = false
			bean_post_harvest_senescence = false
			bean_post_harvest_ticks = 0
			bean_residue_pending = true
			bean_residue_emitted = false
			_set_bean_stage(BeanGrowthStage.DEAD)
		return

	if bean_stage == BeanGrowthStage.POD_READY:
		if _farmer_harvest_delivery_reserved:
			return
		bean_pod_ticks += 1
		var pod_baby_tick = bean_pod_ticks > 0 and (bean_pod_ticks % BEAN_POD_BABY_TICK_INTERVAL) == 0
		if pod_baby_tick and bean_harvest_ready and Global.baby_mode:
			var pod_baby_roll := random.randi_range(LIFECYCLE_POD_BABY_MIN, LIFECYCLE_POD_BABY_MAX)
			for _i in range(pod_baby_roll):
				have_babies(true)
		if bean_pod_ticks >= BEAN_OVERRIPE_TICKS:
			if _is_tree_lifecycle_type():
				# Tree does not die from overripe acorn; it resets to full tree and can fruit again.
				bean_harvest_ready = false
				bean_pod_ticks = 0
				bean_stage_consumptions = 0
				bean_stage_wait_ticks = 0
				_set_bean_stage(BeanGrowthStage.VINE)
			else:
				bean_harvest_ready = false
				bean_dead_ticks = 0
				bean_respawn_wait_ticks = BEAN_DEAD_RESPAWN_DELAY_TICKS
				bean_respawn_requested = false
				bean_post_harvest_senescence = false
				bean_post_harvest_ticks = 0
				bean_residue_pending = true
				bean_residue_emitted = false
				_set_bean_stage(BeanGrowthStage.DEAD)
		return

	if bean_stage_wait_ticks > 0:
		bean_stage_wait_ticks -= 1

	if not consumed_all_nutrients:
		return

	if bean_stage_wait_ticks > 0:
		return

	bean_stage_consumptions += 1
	var required_consumptions = max(1, _get_lifecycle_stage_consumptions_required())
	if bean_stage_consumptions < required_consumptions:
		return

	bean_stage_consumptions = 0
	bean_stage_wait_ticks = BEAN_STAGE_ADVANCE_WAIT_TICKS

	if bean_stage == BeanGrowthStage.SPROUT:
		if _is_tree_lifecycle_type() and not _can_tree_lifecycle_stage_fit(BeanGrowthStage.VINE):
			return
		_set_bean_stage(BeanGrowthStage.VINE)
	elif bean_stage == BeanGrowthStage.VINE:
		if _is_tree_lifecycle_type() and not _can_tree_lifecycle_stage_fit(BeanGrowthStage.POD_READY):
			return
		bean_pod_ticks = 0
		_set_bean_stage(BeanGrowthStage.POD_READY)


func _apply_preview_bean_visual(stage_value: int) -> void:
	if not _is_bean_lifecycle_enabled():
		return
	if not is_instance_valid(sprite):
		return
	var stage_path = _get_lifecycle_stage_texture_path(stage_value)
	var stage_texture: Texture2D = _load_bean_stage_texture(stage_path)
	if not is_instance_valid(stage_texture):
		stage_texture = sprite_texture
	sprite.texture = stage_texture
	sprite.modulate = Color.WHITE
	sprite.offset = _get_lifecycle_stage_sprite_offset(stage_value)
	var stage_scale = _get_bean_stage_target_scale(stage_value) * _get_stage_texture_scale_adjust(stage_texture, stage_value)
	if stage_value == BeanGrowthStage.DEAD:
		sprite.modulate = Color(0.92, 0.86, 0.78, 1.0)
	sprite.scale = stage_scale


func _begin_harvest_visual_detach() -> void:
	if not _is_bean_lifecycle_enabled():
		return
	if _harvest_visual_detached:
		return
	if bean_stage != BeanGrowthStage.POD_READY or not bean_harvest_ready:
		return
	_harvest_visual_detached = true
	_refresh_tree_harvest_acorn_visual()
	_apply_preview_bean_visual(BeanGrowthStage.VINE)


func _cancel_harvest_visual_detach() -> void:
	if not _harvest_visual_detached:
		return
	_harvest_visual_detached = false
	if _is_bean_lifecycle_enabled() and bean_stage == BeanGrowthStage.POD_READY and bean_harvest_ready:
		_apply_preview_bean_visual(BeanGrowthStage.POD_READY)
	_refresh_tree_harvest_acorn_visual()


func _commit_harvest_visual_detach() -> void:
	_harvest_visual_detached = false
	_refresh_tree_harvest_acorn_visual()


func _apply_crop_harvest_commit_state() -> void:
	bean_harvest_ready = false
	bean_pod_ticks = 0
	bean_stage_consumptions = 0
	bean_stage_wait_ticks = 0
	bean_respawn_requested = false
	if _is_tree_lifecycle_type():
		bean_post_harvest_senescence = false
		bean_post_harvest_ticks = 0
	else:
		bean_post_harvest_senescence = true
		bean_post_harvest_ticks = 0
	_set_bean_stage(BeanGrowthStage.VINE, true)
	_commit_harvest_visual_detach()
	if is_dragging:
		is_dragging = false
		Global.is_dragging = false
	_clear_drag_tile_hint()
	_begin_snap_to_nearest_tile(position)


func begin_farmer_harvest_delivery(_target_farmer: Node = null) -> bool:
	if not _is_bean_lifecycle_enabled():
		return false
	if not bean_harvest_ready or bean_stage != BeanGrowthStage.POD_READY:
		return false
	# Keep farmer pickup visuals in sync with click-harvest: hide ripe fruit
	# immediately while delivery is in transit.
	_begin_harvest_visual_detach()
	bean_harvest_ready = false
	bean_pod_ticks = 0
	bean_stage_consumptions = 0
	bean_stage_wait_ticks = 0
	bean_respawn_requested = false
	bean_post_harvest_senescence = false
	bean_post_harvest_ticks = 0
	_farmer_harvest_delivery_reserved = true
	return true


func finalize_farmer_harvest_delivery(_target_farmer: Node = null) -> bool:
	if not _is_bean_lifecycle_enabled():
		return false
	if not _farmer_harvest_delivery_reserved:
		return false
	_farmer_harvest_delivery_reserved = false
	var harvest_key = str(type)
	_apply_crop_harvest_commit_state()
	emit_signal("harvest_committed", harvest_key, "farmer")
	return true


func cancel_farmer_harvest_delivery() -> void:
	if not _farmer_harvest_delivery_reserved:
		return
	_farmer_harvest_delivery_reserved = false
	if bean_stage == BeanGrowthStage.POD_READY and not bool(dead):
		bean_harvest_ready = true
		_cancel_harvest_visual_detach()


func _try_harvest_to_inventory() -> bool:
	if not _is_bean_lifecycle_enabled():
		return false
	if not bean_harvest_ready or bean_stage != BeanGrowthStage.POD_READY:
		return false
	var harvest_key = str(type)
	Global.inventory[harvest_key] = int(Global.inventory.get(harvest_key, 0)) + BEAN_HARVEST_YIELD
	var ui_node = get_node_or_null("../../UI")
	if is_instance_valid(ui_node) and ui_node.has_method("refresh_inventory_counts"):
		ui_node.refresh_inventory_counts()
	_apply_crop_harvest_commit_state()
	emit_signal("harvest_committed", harvest_key, "inventory")
	return true


func _try_harvest_to_farmer(_target_farmer: Node = null) -> bool:
	if not begin_farmer_harvest_delivery(_target_farmer):
		return false
	return finalize_farmer_harvest_delivery(_target_farmer)


func supports_inventory_harvest() -> bool:
	return _is_bean_lifecycle_enabled()


func try_harvest_to_inventory() -> bool:
	if not supports_inventory_harvest():
		return false
	return _try_harvest_to_inventory()


func can_hover_harvest_at_screen_pos(screen_pos: Vector2) -> bool:
	if not can_drag_for_inventory_harvest():
		return false
	var world_pos = Global.screen_to_world(self, screen_pos)
	if _is_tree_lifecycle_type():
		return _is_tree_harvest_hotspot_hit(world_pos)
	return _is_focus_hit(world_pos)


func try_hover_harvest_to_inventory_at_screen_pos(screen_pos: Vector2) -> bool:
	if Global.is_mobile_platform:
		return false
	if Global.is_dragging or _is_drag_pointer_held():
		return false
	if _is_inventory_placement_active():
		return false
	_set_drag_pointer_screen_pos(screen_pos)
	if not can_drag_for_inventory_harvest():
		return false
	var level_root = _get_level_root()
	if is_instance_valid(level_root) and level_root.has_method("can_agent_harvest_to_inventory"):
		if not bool(level_root.can_agent_harvest_to_inventory(self)):
			return false
	if not can_hover_harvest_at_screen_pos(screen_pos):
		return false
	return _try_start_harvest_inventory_animation()


func try_harvest_to_farmer(target_farmer: Node = null) -> bool:
	if not _is_bean_lifecycle_enabled():
		return false
	return _try_harvest_to_farmer(target_farmer)


func try_harvest_to_predator(_predator: Node = null) -> bool:
	if not _is_bean_lifecycle_enabled():
		return false
	if not bean_harvest_ready or bean_stage != BeanGrowthStage.POD_READY:
		return false
	var harvest_key = str(type)
	_apply_crop_harvest_commit_state()
	emit_signal("harvest_committed", harvest_key, "predator")
	if str(Global.mode) == "challenge" and harvest_key != "tree" and killable:
		kill_it()
	return true


func set_variables(a_dict) -> void:
	#print("setup: ", a_dict)
	# Reinitialize mutable per-agent state so new spawns cannot inherit stale
	# dictionary contents from previous instances.
	assets = {
		"N": 0,
		"P": 0,
		"K": 0,
		"R": 0
	}
	current_needs = {
		"N": 0,
		"P": 0,
		"K": 0,
		"R": 0
	}
	current_excess = {
		"N": 0,
		"P": 0,
		"K": 0,
		"R": 0
	}
	trade_buddies = []
	trades = []
		
	var asset_dict = {
		"long_name": "Nitrogen",
		"symbol": "N",
		"color": Color.SPRING_GREEN,
		"amt": 0,
		"need": 0,
		"current_need": 0,
		"current_excess": 0,
		"bar": $CanvasLayer/Nbar,
		"bar_offset": (position + $CanvasLayer/Nbar.position)
	}
	
	#var dict_assets = []
	
	#var asset_N = Asset.new()
	#asset_N.setup(asset_dict)
	
	#dict_assets.append(asset_N)
	
	#for new_asset in dict_assets:
	#	assets[new_asset.symbol] = new_asset
	
	#print("assets: ", dict_assets)
	
	#Global.active_agent = self
	
	
	name = a_dict.get("name")
	type = a_dict.get("type")
	
	prod_res = a_dict.get("prod_res")
	if (prod_res[0] != null):
		if a_dict.get("start_res") == null:
			for res in prod_res:
				assets[res] = needs[res]
			#assets[prod_res].amt = assets[prod_res].need
		else:
			for res in prod_res:
				assets[res] = a_dict.get("start_res")
			
		#assets[prod_res].amt = a_dict.get("start_res")
	position = a_dict.get("position")
	last_position = position
	sprite_texture = a_dict.get("texture")
	sprite = $Sprite2D
	$Sprite2D.texture = sprite_texture
	
	var applied_scale = min_scale
	if str(type) == "tree":
		applied_scale = minf(applied_scale, _get_tree_single_tile_spawn_scale())
	elif Global.social_mode:
		applied_scale = 1.0
	min_scale = applied_scale
	sprite.scale *= min_scale
	bean_base_scale = sprite.scale
	if _is_bean_lifecycle_enabled():
		_reset_bean_lifecycle()
	
	$GrowthTimer.wait_time = Global.growth_time
	$EvaporateTimer.wait_time = Global.evap_time
	$DecayTimer.wait_time = Global.decay_time
	$ActionTimer.wait_time = Global.get_agent_action_time(self)
	setup_resource_bars(["N", "P", "K", "R"], true)
	refresh_bar_visibility()
	if is_instance_valid(sprite):
		_last_occupancy_scale = sprite.scale
	_sync_occupancy_cache()
		


func sort_decending(a, b):
	if a[1] > b[1]:
		return true
	return false
		

func draw_selected_box():
	LevelHelpersRef.draw_agent_selection_box(_get_level_root(), self)
	



func logistics():
	#wait for timer
	var excess_res = null
	var high_amt_excess = 0
	var needed_res = null
	var high_amt_needed = 0
	
	var debug_mode = false
	
	if logistics_ready:
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
								if(logistics_ready and current_needs[need] > 0 and current_excess[excess] >0 ):
									if debug_mode:
										print(need_itter, ". current need: ", need, " supply: ", assets[need] )
										print(excess_iter, ". current excess: ", excess, " supply: ",assets[excess] )
									
									if child.assets.get(excess) != null and child.assets.get(need) != null:
										if debug_mode:
											print( " ... myco assets: " , child.assets)
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
										#print(" .... sending a trade along, ", path_dict)
										if(assets[excess] <=0) :
											print("WHAAAAAATTTTT:", assets )
											print("excess:" , current_excess)
										if _emit_trade_with_budget(path_dict):
											assets[excess] -= 1#amt_needed
											bars[excess].value = assets[excess]
											logistics_ready = false
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
	
func kill_it():
	#new_alpha = low_alpha
	#self.queue_free()
	self.dead = true
	_hide_resource_bars()
	_clear_drag_tile_hint()
	_tile_snap_in_progress = false
	_harvest_drag_only = false
	_end_harvest_drag_proxy()
	if is_dragging:
		is_dragging = false
		Global.is_dragging = false
	LevelHelpersRef.unregister_agent_occupancy(_get_level_root(), self)
	self.call_deferred("queue_free")
	_refresh_tree_harvest_acorn_visual()
	set_hover_focus(false)
	var level_root = _get_level_root()
	if is_instance_valid(level_root):
		LevelHelpersRef.clear_focus_outline_if_owner(level_root, self)
	_clear_active_selection_if_self()
	
	
	_queue_dirty_update(true, true, false)
	for child in trade_buddies:
		if is_instance_valid(child):
			if is_instance_valid(level_root) and level_root.has_method("request_agent_dirty"):
				level_root.request_agent_dirty(child, true, true, false)
			else:
				child.draw_lines = true
				child.new_buddies = true
		
	var children =  $"../../Agents".get_children()
	var living = false
	for child in children:#children:
		
		if(child.type != "cloud" and child.type != "myco"):
			if(child.dead == false):
				living = true
		
	if( living == false and Global.mode != "tutorial"):
		get_tree().change_scene_to_file("res://scenes/game_over.tscn")


func _exit_tree() -> void:
	_hide_resource_bars()
	_clear_drag_tile_hint()
	_end_harvest_drag_proxy()
	LevelHelpersRef.unregister_agent_occupancy(_get_level_root(), self)


func _is_trade_dispatch_endpoint_locked(agent: Variant) -> bool:
	if not is_instance_valid(agent):
		return false
	if bool(agent.get("dead")):
		return false
	if agent.has_method("is_trade_locked_by_user_move"):
		return bool(agent.call("is_trade_locked_by_user_move"))
	return false


func _emit_trade_with_budget(path_dict: Dictionary) -> bool:
	if typeof(path_dict) != TYPE_DICTIONARY:
		return false
	var from_agent = path_dict.get("from_agent", self)
	var to_agent = path_dict.get("to_agent", null)
	var trade_asset = str(path_dict.get("trade_asset", ""))
	# Rain from ecosystem cloud should never directly feed village people.
	if is_instance_valid(from_agent) and str(from_agent.get("type")) == "cloud" and trade_asset == "R":
		if _is_story_village_person_node(to_agent):
			return false
	if _is_trade_dispatch_endpoint_locked(from_agent) or _is_trade_dispatch_endpoint_locked(to_agent):
		return false
	if not Global.allow_trade_dispatch(from_agent, to_agent):
		return false
	emit_signal("trade", path_dict)
	return true


func evaporate():

	if assets["R"] > 0: #evaporate
		var children =  $"../../Agents".get_children()
		children.shuffle()
		for child in children:
			#print(children)
			if child.type == 'cloud':
				var path_dict = {
					"from_agent": self,
					"to_agent": child,
					"trade_path": [self,child],
					"trade_asset": "R",
					"trade_amount": 1, #amt_needed,
					"trade_type": "send",
					"return_res": null,
					"return_amt": 0,#amt_needed
				}
				if _emit_trade_with_budget(path_dict):
					assets["R"] -= 1#amt_needed
					bars["R"].value = assets["R"]
					break
					


func _input(event):
	var interaction_only = not draggable and not _global_reposition_override_enabled()
	if interaction_only and (dead or caught_by != null or not _is_hover_bar_subject()):
		return
	if event is InputEventMouseMotion:
		_set_drag_pointer_screen_pos(event.position)
		return
	if event is InputEventScreenDrag:
		if _active_touch_id != -1 and event.index == _active_touch_id:
			_set_drag_pointer_screen_pos(event.position)
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _active_touch_id != -1 and event.index != _active_touch_id:
				return
			var world_touch_pos = Global.screen_to_world(self, event.position)
			if _is_focus_hit(world_touch_pos):
				_active_touch_id = event.index
				_on_pointer_press(event.position)
			else:
				_press_started_here = false
		else:
			if event.index != _active_touch_id:
				return
			_on_pointer_release(event.position)
			_active_touch_id = -1
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Global.is_mobile_platform:
			return
		if event.pressed:
			_on_pointer_press(event.position)
		else:
			_on_pointer_release(event.position)
					

func _physics_process(delta):
	#_draw()
	if _harvest_inventory_animating:
		return
	if is_dragging and _is_inventory_placement_active() and not _global_reposition_override_enabled():
		is_dragging = false
		Global.is_dragging = false
		if _harvest_drag_only:
			_end_harvest_drag_proxy()
		else:
			_begin_snap_to_nearest_tile(position)
		_harvest_drag_only = false
		_clear_drag_tile_hint()
		return
	if is_dragging:
		
		var hit = false
		var pointer_world_pos = _get_drag_pointer_world_pos()
		var pointer_screen_pos = _get_drag_pointer_screen_pos()
		
		if $"../../UI/MarginContainer".get_global_rect().has_point(pointer_screen_pos):
			hit = true
		
		if hit==true:
			if supports_inventory_harvest():
				var allow_inventory_harvest := true
				var level_root = _get_level_root()
				if is_instance_valid(level_root) and level_root.has_method("can_agent_harvest_to_inventory"):
					allow_inventory_harvest = bool(level_root.can_agent_harvest_to_inventory(self))
				if allow_inventory_harvest:
					if _start_harvest_inventory_fly_in():
						return
				else:
					is_dragging = false
					Global.is_dragging = false
					_end_harvest_drag_proxy()
					_begin_snap_to_nearest_tile(position)
					_harvest_drag_only = false
					_clear_drag_tile_hint()
					return
				is_dragging = false
				Global.is_dragging = false
				if _harvest_drag_only:
					_end_harvest_drag_proxy()
				else:
					_begin_snap_to_nearest_tile(position)
				_harvest_drag_only = false
			else:
				kill_it()
			_clear_drag_tile_hint()
			return
		
		if _harvest_drag_only:
			_update_harvest_drag_proxy_position()
		else:
			var t = min(1.0, delay * delta)
			var dragged_target = position.lerp(pointer_world_pos, t)
			position = _clamp_position_to_world(dragged_target)
	
	if(caught_by != null):
		if(caught_by is Tuktuk):
			position = caught_by.position+Vector2(-6,0)
		else:
			position = caught_by.position+Vector2(33,0)
		bar_canvas.visible = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Global.is_dragging and not _is_drag_pointer_held():
		Global.is_dragging = false
	if is_dragging and not _is_drag_pointer_held():
		is_dragging = false
		if _harvest_drag_only:
			_end_harvest_drag_proxy()
		else:
			_begin_snap_to_nearest_tile(position)
		_harvest_drag_only = false
		_clear_drag_tile_hint()

	var level_root_for_dirty = _get_level_root()
	var has_dirty_scheduler = is_instance_valid(level_root_for_dirty) and level_root_for_dirty.has_method("request_agent_dirty")
	if not has_dirty_scheduler:
		if new_buddies:
			generate_buddies()
			new_buddies = false
		if draw_lines and Global.draw_lines and self.type == "myco":
			new_draw_line()
			draw_lines = false

	if not Global.get_world_rect(self).has_point(position):
		self.kill_it()
	var is_active = is_instance_valid(self) and is_instance_valid(Global.active_agent) and Global.active_agent.name == self.name
	if story_predator_disrupt_timer > 0.0:
		story_predator_disrupt_timer = maxf(story_predator_disrupt_timer - delta, 0.0)
	var level_root = _get_level_root()
	if is_instance_valid(level_root):
		LevelHelpersRef.clear_focus_outline_if_owner(level_root, self)
	if(is_active):
		var direction = Input.get_vector("left","right","up","down")
		if direction != Vector2.ZERO and _can_user_reposition():
			_keyboard_moving = true
			_cancel_tile_snap()
			var moved_pos = position + direction * 200 * delta
			position = _clamp_position_to_world(moved_pos)
		elif direction != Vector2.ZERO:
			if _keyboard_moving:
				_keyboard_moving = false
				_begin_snap_to_nearest_tile(position)
		elif _keyboard_moving:
			_keyboard_moving = false
			_begin_snap_to_nearest_tile(position)
	else:
		if _keyboard_moving:
			_keyboard_moving = false
			_begin_snap_to_nearest_tile(position)

	var bean_dead_phase = _is_bean_lifecycle_enabled() and bean_stage == BeanGrowthStage.DEAD
	if(dead == false and not bean_dead_phase and is_instance_valid(self) and not is_trade_locked_by_user_move() and story_predator_disrupt_timer <= 0.0):
		logistics()
	
	if not is_dragging and not _keyboard_moving:
		_advance_tile_snap(delta)

	if is_dragging and not _harvest_drag_only:
		_update_drag_tile_hint(position)
	elif _keyboard_moving:
		_update_drag_tile_hint(position)
	elif _tile_snap_in_progress:
		_update_drag_tile_hint(_tile_snap_target)
	else:
		_clear_drag_tile_hint()

	refresh_bar_visibility()
	if is_instance_valid(bar_canvas) and bar_canvas.visible:
		if _did_camera_move_since_last_bar_update():
			_bar_update_accum = 0.0
			_update_bar_positions()
		else:
			_bar_update_accum += delta
			if _bar_update_accum >= _get_adaptive_bar_update_interval():
				_bar_update_accum = 0.0
				_update_bar_positions()
				
	if(position != last_position):
		var old_pos = last_position
		last_position = position
		if is_instance_valid(level_root) and level_root.has_method("mark_agent_moved"):
			level_root.mark_agent_moved(self, old_pos, position)
		else:
			_queue_dirty_update(true, true, false)
			_sync_occupancy_cache()
		draw_box = true
		if is_instance_valid(bar_canvas) and bar_canvas.visible:
			_bar_update_accum = 0.0
			_update_bar_positions()

	if str(type) == "tree" and is_instance_valid(sprite):
		if sprite.scale.distance_to(_last_occupancy_scale) > 0.001:
			_last_occupancy_scale = sprite.scale
			_sync_occupancy_cache()



# Search for things to trade with in tile reach
func generate_buddies() -> void:
	var agents_root = get_node_or_null("../../Agents")
	trade_buddies = LevelHelpersRef.query_trade_hubs_near_agent(_get_level_root(), agents_root, self, num_buddies, true)
	_restore_lifecycle_spawn_anchor_buddy()
	_restore_story_forced_village_basket_buddies()
func new_draw_line():
	var level_root = _get_level_root()
	var lines_root = get_node_or_null("../../Lines")
	var agents_root = _get_agents_root()
	if not is_instance_valid(level_root) or not is_instance_valid(lines_root) or not is_instance_valid(agents_root):
		return
	LevelHelpersRef.sync_myco_trade_lines(lines_root, agents_root, Global.social_mode)



func _on_area_entered(ztrade: Area2D) -> void:
	if ztrade.end_agent == self:
		assets[ztrade.asset]+=ztrade.amount	
		if assets[ztrade.asset]> needs[ztrade.asset] *2:
			assets[ztrade.asset] = needs[ztrade.asset] *2
		else:
			Global.add_score(ztrade.amount)
			emit_signal("update_score")
		bars[ztrade.asset].value = assets[ztrade.asset]
		if ztrade.has_method("finish_trade"):
			ztrade.call_deferred("finish_trade")
		else:
			ztrade.call_deferred("queue_free")

func _on_action_timer_timeout() -> void:
	logistics_ready = true


func _on_growth_timer_timeout() -> void:
	#$GrowthTimer.set_wait_time(random.randf_range(1, 5))
	#production_ready = true
	#if production_ready:		
	#	production_ready = false
	if(prod_res[0] != null):
		for res in prod_res:
			assets[res]+=3
			if assets[res]> needs[res] *2:
				assets[res] = needs[res] *2
			bars[res].value = assets[res]
			
	#if there is 1 res in each asset - consume them all and grow in size
	#if any are missing shrink
	var all_in = true
	for res in assets:
		if assets[res] <= 0:
			all_in = false
	var starvation_alpha_step := _get_starvation_alpha_step()
	if _is_tree_lifecycle_type():
		starvation_alpha_step /= TREE_STARVATION_DURATION_MULTIPLIER
	var orphan_spawn_child: bool = _is_lifecycle_orphan_spawn_child()
	if orphan_spawn_child:
		starvation_alpha_step *= LIFECYCLE_ORPHAN_STARVATION_MULTIPLIER

	if _is_bean_lifecycle_enabled():
		var consumed_all_nutrients := false
		if all_in:
			bean_starvation_ticks = maxi(bean_starvation_ticks - 2, 0)
			var old_modulate_up = modulate
			var new_alpha_up = modulate.a + alpha_step_up
			if new_alpha_up > high_alpha:
				new_alpha_up = high_alpha
			self.modulate = Color(old_modulate_up, new_alpha_up)

			Global.add_score(400)
			emit_signal("update_score")
			for res in assets:
				assets[res] -= 1
				bars[res].value = assets[res]
			consumed_all_nutrients = true
		elif bean_stage != BeanGrowthStage.DEAD:
			bean_starvation_ticks += 1
			var old_modulate_down = modulate
			var new_alpha_down = modulate.a - starvation_alpha_step
			var tree_challenge_starved: bool = _is_tree_lifecycle_type() and str(Global.mode) == "challenge" and bean_starvation_ticks >= TREE_CHALLENGE_STARVATION_DEAD_TICKS
			var orphan_challenge_starved: bool = orphan_spawn_child and str(Global.mode) == "challenge" and bean_starvation_ticks >= LIFECYCLE_ORPHAN_CHALLENGE_DEAD_TICKS
			if new_alpha_down < low_alpha or tree_challenge_starved or orphan_challenge_starved:
				new_alpha_down = low_alpha
				if Global.is_killing and killable:
					_enter_lifecycle_starvation_death()
					return
			self.modulate = Color(old_modulate_down, new_alpha_down)

		_advance_bean_lifecycle(consumed_all_nutrients)
		return

	var newScale = $Sprite2D.scale
	#print(name, " assets: ", assets)
	if all_in == true:	
		if $Sprite2D.scale.x < max_scale and $Sprite2D.scale.y < max_scale:
			var candidate_scale = $Sprite2D.scale * (1 + scale_step_up)
			if _can_expand_to_scale(candidate_scale):
				newScale = candidate_scale
		
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
			#if(res != "R"):
			assets[res] -= 1
			bars[res].value = assets[res]
			#else:
			#	evaporate()
		
	else:
		#if $Sprite2D.scale.x > 0.5 and $Sprite2D.scale.y > 0.5:
			
			#newScale = $Sprite2D.scale * 0.95
			#print($Sprite2D.scale)
			
		var old_modulate = modulate
		var new_alpha = modulate.a - starvation_alpha_step
		if new_alpha < low_alpha:
			new_alpha = low_alpha
			
			if(Global.is_killing == true and self.killable == true):
				kill_it()
			
		var new_color = Color(old_modulate,new_alpha)
		self.modulate= new_color

	if newScale != $Sprite2D.scale:
		var tween = get_tree().create_tween()
		tween.tween_property($Sprite2D, "scale", newScale, 0.05)
		if str(type) == "tree":
			_last_occupancy_scale = newScale
			_sync_occupancy_cache()
		#tween.set_parallel(true)	
		
	if newScale.x >= max_scale and newScale.y >= max_scale and modulate.a >= 1:
		_spawn_growth_sparkle()
	
		if Global.baby_mode:
			if(Global.is_max_babies == true):
				if(current_babies < num_babies):
					have_babies()
			else:
				have_babies()
	
func have_babies(force_spawn: bool = false)  -> void:
	if bool(get_meta("story_disable_birth", false)):
		return
	if _is_bean_lifecycle_enabled() and bean_stage != BeanGrowthStage.POD_READY:
		return
	var parent_anchor = _find_nearby_living_myco_anchor(global_position, LIFECYCLE_PARENT_BOUND_TILES)
	if _is_bean_lifecycle_enabled() and not is_instance_valid(parent_anchor):
		return
	
	var max_rounds = 10
	var current_round = 0
	var baby_made = false
	
	
	#produce a baby
	#find a random place nearby
	
	var new_x = global_position.x
	var new_y = global_position.y
	var world = _get_world_foundation_node()
	var use_tile_sampling = _uses_tile_snap() and is_instance_valid(world) and world.has_method("world_to_tile") and world.has_method("tile_to_world_center")
	var anchor_pos = global_position
	if is_instance_valid(parent_anchor):
		anchor_pos = parent_anchor.global_position
	var anchor_coord := Vector2i.ZERO
	if use_tile_sampling:
		anchor_coord = _clamp_tile_coord(world, Vector2i(world.world_to_tile(_clamp_position_to_world_rect(anchor_pos))))
	var rng = random
	
	while(baby_made == false and current_round < max_rounds):
		if(Global.is_max_babies):
			if(current_babies >= num_babies):
				return
				
		new_x = global_position.x
		new_y = global_position.y
		current_round+=1
		if use_tile_sampling:
			var sample_coord = anchor_coord + Vector2i(
				rng.randi_range(-LIFECYCLE_PARENT_BOUND_TILES, LIFECYCLE_PARENT_BOUND_TILES),
				rng.randi_range(-LIFECYCLE_PARENT_BOUND_TILES, LIFECYCLE_PARENT_BOUND_TILES)
			)
			sample_coord = _clamp_tile_coord(world, sample_coord)
			var sampled_world_pos = world.tile_to_world_center(sample_coord)
			new_x = sampled_world_pos.x
			new_y = sampled_world_pos.y
		else:
			var pixel_radius = int(maxf(48.0, _get_sprite_half_extents().x * 2.0))
			var random_x = rng.randi_range(-pixel_radius, pixel_radius)
			var random_y = rng.randi_range(-pixel_radius, pixel_radius)
			new_x = new_x + random_x
			new_y = new_y + random_y
		
		var new_pos = Vector2(new_x, new_y )
		var hit = false
		var new_pos_screen = Global.world_to_screen(self, new_pos)
		
		if $"../../UI/MarginContainer".get_global_rect().has_point(new_pos_screen):
			hit = true
			#print("hit something-info")
		
		for agent in $"../../Agents".get_children():
			var recto = agent.sprite.get_rect()
			var posr = recto.position+agent.global_position
			var rects = Rect2(posr,recto.size*agent.scale*2) 
			
			if rects.has_point(new_pos):
				hit = true
		
		
		
		if( hit == false):
			var world_rect = Global.get_world_rect(self)
			if (world_rect.has_point(new_pos)):
				var new_agent_dict = {
					"name" : self.type,
					"pos": new_pos
				}
				if is_instance_valid(parent_anchor):
					new_agent_dict["parent_anchor"] = parent_anchor
					new_agent_dict["max_parent_tiles"] = LIFECYCLE_PARENT_BOUND_TILES
				if use_tile_sampling:
					new_agent_dict["require_exact_tile"] = true
				#print("old pos: x: ",global_position.x, " y: ", global_position.y , "new agent signal: ", new_agent_dict)
				if force_spawn:
					emit_signal("new_agent", new_agent_dict)
					baby_made = true
					current_babies +=1
				else:
					current_maturity +=1 
					if(current_maturity >= peak_maturity):
						emit_signal("new_agent", new_agent_dict)
						baby_made = true
						current_babies +=1
						current_maturity = 0
				
				#make_squash(event.position)		



func _on_decay_timer_timeout() -> void:
	#$DecayTimer.set_wait_time(random.randf_range(1, 5))
	decay_ready = true


func _on_evaporate_timer_timeout() -> void:
	#$EvaporateTimer.set_wait_time(random.randf_range(1, 5))
	evaporate_ready = true


func _on_body_entered(body: Node2D) -> void:
	var predator_quarry_type = str(body.get("quarry_type"))
	if self.type == predator_quarry_type:#"maize"):
		if body is Tuktuk and bool(get_meta("story_villager", false)):
			story_predator_disrupt_timer = maxf(story_predator_disrupt_timer, STORY_PREDATOR_DISRUPT_SECONDS)
			for res in assets.keys():
				assets[res] = maxi(int(assets[res]) - 1, 0)
				if bars.has(res):
					bars[res].value = assets[res]
			body.set("caught", true)
			var disrupt_speed = maxf(float(body.get("speed")) - 80.0, 80.0)
			body.set("speed", disrupt_speed)
			body.set("going", Vector2(1, randi_range(-1, 1)))
			return
		if body is Bird:
			if bool(body.get("caught")):
				return
			if not has_method("try_harvest_to_predator"):
				return
			if not bool(call("try_harvest_to_predator", body)):
				return
			var harvested_type = str(type)
			if body.has_method("on_predator_harvest_success"):
				body.call("on_predator_harvest_success", harvested_type)
			else:
				body.set("caught", true)
				body.set("speed", maxf(float(body.get("speed")) - 100.0, 80.0))
				body.set("going", Vector2(1, randf_range(-0.25, 0.25)).normalized())
			return
			
		#print("bird endered: ", body)
		if(not bool(body.get("caught")) and caught_by == null):
			body.set("caught", true)
			caught_by = body
			logistics_ready = false
			if(body is Bird):
				sprite.rotate(PI/4)
			self.dead = true
			_clear_active_selection_if_self()
			
			var living = false
			
			body.set("speed", float(body.get("speed")) - 100.0)
			
			
			body.set("going", Vector2(1,randi_range(-1,1)))
			LevelHelpersRef.unregister_agent_occupancy(_get_level_root(), self)
			var level_root = _get_level_root()
			for child in trade_buddies:
				if not is_instance_valid(child):
					continue
				if is_instance_valid(level_root) and level_root.has_method("request_agent_dirty"):
					level_root.request_agent_dirty(child, true, true, false)
				else:
					child.draw_lines = true
					child.new_buddies = true

			#sprite.z_index = 10
