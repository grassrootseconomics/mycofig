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

enum BeanGrowthStage {
	SEED,
	SPROUT,
	VINE,
	POD_READY,
	DEAD
}

const BEAN_OVERRIPE_TICKS := 14
const BEAN_DEAD_CLEANUP_TICKS := 6
const BEAN_DEAD_RESPAWN_DELAY_TICKS := 1
const BEAN_POST_HARVEST_TO_DEAD_TICKS := 2
const BEAN_POD_BABY_TICK_INTERVAL := 4
const BEAN_STAGE_CONSUMPTIONS_PER_ADVANCE := 3
const BEAN_STAGE_ADVANCE_WAIT_TICKS := 1
const BEAN_HARVEST_YIELD := 3
const LIFECYCLE_POD_BABY_MIN := 0
const LIFECYCLE_POD_BABY_MAX := 3
const BASE_MOVE_RATE_FOR_STARVATION := 6.0
const BASE_MOVEMENT_SPEED_FOR_STARVATION := 200.0
const MIN_STARVATION_SPEED_SCALE := 0.2

signal trade(pos)
signal clicked
signal clicked_agent(agent)
signal new_agent(agent_dict)
signal update_score
signal lifecycle_residue(coord, biomass, source_type)

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
var _harvest_drag_sprite: Sprite2D = null
var bean_pod_ticks := 0
var bean_dead_ticks := 0
var bean_stage_consumptions := 0
var bean_stage_wait_ticks := 0
var bean_respawn_wait_ticks := 0
var bean_respawn_requested := false
var bean_post_harvest_senescence := false
var bean_post_harvest_ticks := 0
var bean_stage: int = BeanGrowthStage.SEED
var bean_harvest_ready := false
var bean_pod_sparkle_played := false
var bean_stage_textures := {}
var bean_base_scale := Vector2.ONE
var bean_residue_pending := false
var bean_residue_emitted := false


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
				anchor = Global.world_to_screen(self, position)
	for bar in bars:
		if is_instance_valid(bars[bar]):
			bars[bar].position = anchor + bars_offset[bar]


func _get_world_foundation_node() -> Node:
	return get_node_or_null("../../WorldFoundation")


func _get_level_root() -> Node:
	return get_node_or_null("../..")


func _get_agents_root() -> Node:
	return get_node_or_null("../../Agents")


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


func _start_harvest_drag_proxy() -> void:
	if not _harvest_drag_only:
		_end_harvest_drag_proxy()
		return
	if is_instance_valid(_harvest_drag_sprite):
		_update_harvest_drag_proxy_position()
		return
	var harvest_texture := _get_harvest_drag_texture()
	if not is_instance_valid(harvest_texture):
		return
	var level_root = _get_level_root()
	if not is_instance_valid(level_root):
		return
	var drag_sprite := Sprite2D.new()
	drag_sprite.texture = harvest_texture
	drag_sprite.top_level = true
	drag_sprite.z_index = 2000
	drag_sprite.z_as_relative = false
	drag_sprite.modulate = Color(1.0, 1.0, 1.0, 0.96)
	var drag_scale := Vector2.ONE
	if _is_bean_lifecycle_enabled():
		drag_scale = bean_base_scale
	elif is_instance_valid(sprite):
		drag_scale = sprite.scale
	if drag_scale == Vector2.ZERO:
		drag_scale = Vector2.ONE
	drag_sprite.scale = drag_scale
	level_root.add_child(drag_sprite)
	_harvest_drag_sprite = drag_sprite
	_update_harvest_drag_proxy_position()


func _update_harvest_drag_proxy_position() -> void:
	if not is_instance_valid(_harvest_drag_sprite):
		return
	_harvest_drag_sprite.global_position = get_global_mouse_position()


func _end_harvest_drag_proxy() -> void:
	if is_instance_valid(_harvest_drag_sprite):
		_harvest_drag_sprite.queue_free()
	_harvest_drag_sprite = null


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
	for box in $"../../Boxes".get_children():
		if box.has_method("clear_points"):
			box.clear_points()
		box.queue_free()
	Global.active_agent = null
	Global.prevent_auto_select = true


func _is_reposition_subject() -> bool:
	var entity_type = str(type)
	return entity_type == "bean" or entity_type == "squash" or entity_type == "maize" or entity_type == "tree" or entity_type == "myco"


func _can_user_reposition() -> bool:
	if not _is_reposition_subject():
		return true
	return bool(Global.allow_agent_reposition)


func can_drag_for_inventory_harvest() -> bool:
	return _is_bean_lifecycle_enabled() and bean_harvest_ready and bean_stage == BeanGrowthStage.POD_READY


func _can_start_user_drag() -> bool:
	if _can_user_reposition():
		return true
	return can_drag_for_inventory_harvest()


func _is_bean_lifecycle_enabled() -> bool:
	if Global.social_mode:
		return false
	var crop_type = str(type)
	return crop_type == "bean" or crop_type == "squash" or crop_type == "maize"


func _get_lifecycle_crop_type() -> String:
	var crop_type = str(type)
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


func _spawn_growth_sparkle() -> void:
	var sparkle = Global.sparkle_scene.instantiate()
	sparkle.z_as_relative = false
	sparkle.position = self.position
	sparkle.global_position = self.global_position
	$"../../Sparkles".add_child(sparkle)
	sparkle.start(0.75)


func _get_bean_stage_scale_multiplier(stage_value: int) -> float:
	var crop_type = _get_lifecycle_crop_type()
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


func _get_lifecycle_stage_texture_path(stage_value: int) -> String:
	var crop_type = _get_lifecycle_crop_type()
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

	bean_stage = new_stage
	bean_harvest_ready = bean_stage == BeanGrowthStage.POD_READY
	if bean_stage != BeanGrowthStage.DEAD:
		bean_residue_pending = false
		bean_residue_emitted = false
	draggable = bean_stage != BeanGrowthStage.DEAD
	if bean_stage == BeanGrowthStage.DEAD:
		_clear_active_selection_if_self()
		if bean_respawn_wait_ticks <= 0:
			bean_respawn_wait_ticks = BEAN_DEAD_RESPAWN_DELAY_TICKS
		bean_respawn_requested = false
		bean_post_harvest_senescence = false
		bean_post_harvest_ticks = 0
	var next_path = _get_lifecycle_stage_texture_path(bean_stage)
	var next_texture: Texture2D = _load_bean_stage_texture(next_path)
	if not is_instance_valid(next_texture):
		next_texture = sprite_texture

	if is_instance_valid(sprite):
		sprite.texture = next_texture
		sprite.modulate = Color.WHITE
		var stage_scale = _get_bean_stage_target_scale(bean_stage)
		stage_scale *= _get_lifecycle_texture_scale_adjust(next_texture)
		if bean_stage == BeanGrowthStage.DEAD:
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


func _reset_bean_lifecycle() -> void:
	bean_pod_ticks = 0
	bean_dead_ticks = 0
	bean_stage_consumptions = 0
	bean_stage_wait_ticks = 0
	bean_respawn_wait_ticks = 0
	bean_respawn_requested = false
	bean_post_harvest_senescence = false
	bean_post_harvest_ticks = 0
	bean_harvest_ready = false
	bean_pod_sparkle_played = false
	bean_residue_pending = false
	bean_residue_emitted = false
	bean_stage = BeanGrowthStage.SPROUT
	_set_bean_stage(BeanGrowthStage.SPROUT, true)


func _emit_death_cycle_regrowth_request() -> void:
	if not _is_bean_lifecycle_enabled():
		return
	var world_pos := global_position
	var world = _get_world_foundation_node()
	if is_instance_valid(world) and world.has_method("world_to_tile") and world.has_method("tile_to_world_center") and world.has_method("in_bounds"):
		var coord = Vector2i(world.world_to_tile(_clamp_position_to_world_rect(global_position)))
		if not world.in_bounds(coord):
			return
		world_pos = world.tile_to_world_center(coord)
	var new_agent_dict = {
		"name": str(type),
		"pos": world_pos,
		"require_exact_tile": true,
		"ignore_agent": self
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
			if bean_residue_pending and not bean_residue_emitted:
				_emit_lifecycle_residue_signal(1.0, str(type))
				bean_residue_emitted = true
			bean_respawn_requested = true
			dead = true
			_emit_death_cycle_regrowth_request()
		if killable:
			kill_it()
		return

	if bean_post_harvest_senescence:
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
		bean_pod_ticks += 1
		var pod_baby_tick = bean_pod_ticks > 0 and (bean_pod_ticks % BEAN_POD_BABY_TICK_INTERVAL) == 0
		if pod_baby_tick and bean_harvest_ready and Global.baby_mode:
			var pod_baby_roll := random.randi_range(LIFECYCLE_POD_BABY_MIN, LIFECYCLE_POD_BABY_MAX)
			for _i in range(pod_baby_roll):
				have_babies(true)
		if bean_pod_ticks >= BEAN_OVERRIPE_TICKS:
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
	if bean_stage_consumptions < BEAN_STAGE_CONSUMPTIONS_PER_ADVANCE:
		return

	bean_stage_consumptions = 0
	bean_stage_wait_ticks = BEAN_STAGE_ADVANCE_WAIT_TICKS

	if bean_stage == BeanGrowthStage.SPROUT:
		_set_bean_stage(BeanGrowthStage.VINE)
	elif bean_stage == BeanGrowthStage.VINE:
		bean_pod_ticks = 0
		_set_bean_stage(BeanGrowthStage.POD_READY)


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
	bean_harvest_ready = false
	bean_pod_ticks = 0
	bean_stage_consumptions = 0
	bean_stage_wait_ticks = 0
	bean_respawn_requested = false
	bean_post_harvest_senescence = true
	bean_post_harvest_ticks = 0
	_set_bean_stage(BeanGrowthStage.VINE, true)
	if is_dragging:
		is_dragging = false
		Global.is_dragging = false
	_clear_drag_tile_hint()
	_begin_snap_to_nearest_tile(position)
	return true


func supports_inventory_harvest() -> bool:
	return _is_bean_lifecycle_enabled()


func try_harvest_to_inventory() -> bool:
	if not supports_inventory_harvest():
		return false
	return _try_harvest_to_inventory()


func set_variables(a_dict) -> void:
	#print("setup: ", a_dict)
	
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
	$ActionTimer.wait_time = Global.action_time
	bars = { #list of needed assets with need level
		"N": $CanvasLayer/Nbar,
		"P": $CanvasLayer/Pbar,
		"K": $CanvasLayer/Kbar,
		"R": $CanvasLayer/Rbar
	}
	for bar in bars:
		bars[bar].max_value = int(needs[bar]*1.2)
		bars[bar].value = assets[bar]
		bars_offset[bar] = bars[bar].position
		bars[bar].tint_progress = Global.asset_colors[bar]
	
	bar_canvas = $CanvasLayer
	if(Global.bars_on == false):
		bar_canvas.visible = false
	_update_bar_positions()
		


func sort_decending(a, b):
	if a[1] > b[1]:
		return true
	return false


func draw_selected_box():
	for line in $"../../Boxes".get_children():
		line.clear_points()	
		line.queue_free()
	
	var rect = $Sprite2D.get_rect()
	#position - rect*scale/2 for top left point 
	#position + rect*scale/2 for bottom right point


	var pos = rect.position#+self.global_position
	#var rects = Rect2(pos,rect.size*5) 

	var rects = rect * Transform2D(0, $Sprite2D.scale, 0, Vector2())
	#Color(Color.ANTIQUE_WHITE,0.3)
	#draw_rect(new_rect,Color.GREEN_YELLOW)
	#draw_line(pos, Vector2(pos.x+200,pos.y+200) , Color.GREEN_YELLOW, 5)
	
	var myco_line1 = Line2D.new()
	myco_line1.width = 2
	myco_line1.z_as_relative = false
	myco_line1.antialiased = true
	myco_line1.global_rotation = 0
	#myco_line1.modulate = start_color
	myco_line1.modulate = Color.GREEN_YELLOW
	#var to = to_local(agent.position)#+agent.global_position		
	
	myco_line1.add_point( Vector2(position.x+rects.position.x,position.y+rects.position.y)  )
	myco_line1.add_point( Vector2(position.x+rects.position.x+2*rects.size[0]/2,position.y+rects.position.y)  )
	myco_line1.add_point( Vector2(position.x+rects.position.x+2*rects.size[0]/2,position.y+rects.position.y+2*rects.size[1]/2)  )
	myco_line1.add_point( Vector2(position.x+rects.position.x,position.y+rects.position.y+2*rects.size[1]/2)  )
	myco_line1.add_point( Vector2(position.x+rects.position.x,position.y+rects.position.y)  )
			#myco_line.z_index = -1
	$"../../Boxes".add_child(myco_line1)
	



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
										assets[excess] -= 1#amt_needed
										bars[excess].value = assets[excess]
										#print(excess_res, " value: ", bars[excess_res].value)
										#bars[excess_res].update()
										emit_signal("trade",path_dict)
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
	_clear_drag_tile_hint()
	_tile_snap_in_progress = false
	_harvest_drag_only = false
	_end_harvest_drag_proxy()
	if is_dragging:
		is_dragging = false
		Global.is_dragging = false
	self.call_deferred("queue_free")
	self.dead = true
	_clear_active_selection_if_self()
	
	
	new_buddies = true
	#var children =  $"../../Agents".get_children()
	#for child in children:
		#if child.type == 'myco': 
		
	
	
	
	for child in trade_buddies:#children:
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
	_clear_drag_tile_hint()
	_end_harvest_drag_proxy()


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
				#print(" .... sending a trade along, ", path_dict)
				assets["R"] -= 1#amt_needed
				bars["R"].value = assets["R"]
				#print(excess_res, " value: ", bars[excess_res].value)
				#bars[excess_res].update()
				emit_signal("trade",path_dict)
				break
					


func _input(event):
	if(draggable == true):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				var world_click_pos = Global.screen_to_world(self, event.position)
				
				if event.pressed:
					
					if $Sprite2D.get_rect().has_point(to_local(world_click_pos)):
						_press_started_here = true
						if(Global.is_dragging == false and _can_start_user_drag()):
							_harvest_drag_only = can_drag_for_inventory_harvest()
							is_dragging = true
							Global.is_dragging = true
							Global.active_agent = self
							Global.prevent_auto_select = false
							_cancel_tile_snap()
							if _harvest_drag_only:
								_start_harvest_drag_proxy()
							else:
								_end_harvest_drag_proxy()
						else:
							Global.active_agent = self
							Global.prevent_auto_select = false
					else:
						_press_started_here = false
						#is_dragging = true
						#Global.active_agent = self
						#print(" clicked: ", name)
						
				else:
					var pressed_here = _press_started_here
					_press_started_here = false
					var was_dragging = is_dragging
					if was_dragging:
						is_dragging = false
						Global.is_dragging = false
						if _harvest_drag_only:
							_end_harvest_drag_proxy()
						else:
							_begin_snap_to_nearest_tile(position)
						_harvest_drag_only = false
						_clear_drag_tile_hint()
					if pressed_here and $Sprite2D.get_rect().has_point(to_local(world_click_pos)):
						#emit_signal("clicked_agent",self)
						Global.active_agent = self
						Global.prevent_auto_select = false
						#print(" clicked: ", name)
					

func _physics_process(delta):
	#_draw()
	if is_dragging:
		
		var hit = false
		var mouse_screen = Global.world_to_screen(self, get_global_mouse_position())
		
		if $"../../UI/MarginContainer".get_global_rect().has_point(mouse_screen):
			hit = true
		
		if hit==true:
			if supports_inventory_harvest():
				if try_harvest_to_inventory():
					_end_harvest_drag_proxy()
					_harvest_drag_only = false
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
			var dragged_target = position.lerp(get_global_mouse_position(), t)
			position = _clamp_position_to_world(dragged_target)
			_update_bar_positions()
	
	if(caught_by != null):
		if(caught_by is Tuktuk):
			position = caught_by.position+Vector2(-6,0)
		else:
			position = caught_by.position+Vector2(33,0)
		bar_canvas.visible = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Global.is_dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		Global.is_dragging = false
	if is_dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		is_dragging = false
		if _harvest_drag_only:
			_end_harvest_drag_proxy()
		else:
			_begin_snap_to_nearest_tile(position)
		_harvest_drag_only = false
		_clear_drag_tile_hint()

	if new_buddies:
		generate_buddies()
		new_buddies = false
	if draw_lines and Global.draw_lines and self.type == "myco":
		new_draw_line()
		draw_lines = false
	if not Global.get_world_rect(self).has_point(position):
		self.kill_it()
	var is_active = is_instance_valid(self) and is_instance_valid(Global.active_agent) and Global.active_agent.name == self.name
	if(is_active):
		if draw_box == true:
			draw_selected_box()
			draw_box=false
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
	if(dead == false and not bean_dead_phase and is_instance_valid(self) and not is_trade_locked_by_user_move()):
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

	if is_instance_valid(bar_canvas) and bar_canvas.visible:
		_update_bar_positions()
			
	if(position != last_position):
			#move_and_slide()
		last_position = position
		#move_and_slide()
		#print("setting ")
		new_buddies = true
		var children =  $"../../Agents".get_children()
		for child in children:
			#if child.type == 'myco': 
			child.draw_lines = true
			child.new_buddies = true
			
	
		#if draw_box == true:
		#	draw_selected_box()
		draw_box = true



# Search for things to trade with in a radius
func generate_buddies() -> void:
	var children =  $"../../Agents".get_children()
	trade_buddies = []
	#print(self.name, " new buddies children: ", children)
	
	for child in children:
		if child.type == 'myco':
			var over_full = false
			child.num_connectors = 0
			
			
			var dist = global_position.distance_to(child.global_position)
			if dist <= child.buddy_radius:
				#print("child in dist,", dist, " len: ", len(trade_buddies) , " max: ", num_buddies)
				if len(trade_buddies) < num_buddies:
					trade_buddies.append(child)
		
func new_draw_line():
	for line in $"../../Lines".get_children():
		for my_line in my_lines:
			if(my_line == line):
				line.clear_points()	
				line.queue_free()
		
	my_lines = []
	#var g = Gradient.new()
	var start_color = Color(Color.ANTIQUE_WHITE,0.3)
	if(Global.social_mode):
		start_color = Color(Color.SADDLE_BROWN,0.3)
		
	#var end_color = Color(Color.ANTIQUE_WHITE,0.3)
	
	#g.set_color( 0,  start_color)
	#g.set_color( 1,  end_color )
	#g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR		# 0
	#g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT	# 1
	#g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC		# 2

	#var from = to_local(position)
	var from = position
	#print("from: ", from, " x: ", from.x, " y: ", from.y)
	#from = from.normalized() *100
	if($"../../Agents" != null):
		#print("<><><>>< ", position, " ", global_position)
		for agent in $"../../Agents".get_children():
			if(is_instance_valid(agent)):
				if agent.type != "cloud" and agent.dead != true and agent.name != self.name:
					for buddy in agent.trade_buddies:
						if is_instance_valid(buddy):
							if buddy.name == self.name:
								
								var myco_line1 = Line2D.new()
								myco_line1.width = 2
								myco_line1.z_as_relative = false
								myco_line1.antialiased = true
								myco_line1.global_rotation = 0
								#myco_line1.modulate = start_color
								myco_line1.modulate = start_color#set_gradient( g )
								myco_line1.set_meta("endpoint_a", self)
								myco_line1.set_meta("endpoint_b", agent)
								myco_line1.set_meta("base_color", start_color)
								#var to = to_local(agent.position)#+agent.global_position		
								var to = agent.position#+agent.global_position							
								var new_pos1 = Vector2(to.x,from.y)
								var new_pos2 = Vector2(from.x,to.y)
								
								
								myco_line1.add_point( from )
								myco_line1.add_point( new_pos1 )
								myco_line1.add_point( to )
								
								var myco_line2 = Line2D.new()
								myco_line2.width = 2
								myco_line2.z_as_relative = false
								myco_line2.antialiased = true
								#myco_line2.global_rotation = 0
								myco_line2.modulate = start_color
								myco_line2.set_meta("endpoint_a", self)
								myco_line2.set_meta("endpoint_b", agent)
								myco_line2.set_meta("base_color", start_color)
								#var to = to_local(agent.position)#+agent.global_position		
								
								myco_line2.add_point( from )
								myco_line2.add_point( new_pos2 )
								myco_line2.add_point( to )
								
								#myco_line.z_index = -1
								$"../../Lines".add_child(myco_line1)
								my_lines.append(myco_line1)
								$"../../Lines".add_child(myco_line2)
								my_lines.append(myco_line2)



func _on_area_entered(ztrade: Area2D) -> void:
	if ztrade.end_agent == self:
		assets[ztrade.asset]+=ztrade.amount	
		if assets[ztrade.asset]> needs[ztrade.asset] *2:
			assets[ztrade.asset] = needs[ztrade.asset] *2
		else:
			Global.score+=ztrade.amount
			emit_signal("update_score")
		bars[ztrade.asset].value = assets[ztrade.asset]
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

	if _is_bean_lifecycle_enabled():
		var consumed_all_nutrients := false
		if all_in:
			var old_modulate_up = modulate
			var new_alpha_up = modulate.a + alpha_step_up
			if new_alpha_up > high_alpha:
				new_alpha_up = high_alpha
			self.modulate = Color(old_modulate_up, new_alpha_up)

			Global.score += 400
			emit_signal("update_score")
			for res in assets:
				assets[res] -= 1
				bars[res].value = assets[res]
			consumed_all_nutrients = true
		elif bean_stage != BeanGrowthStage.DEAD:
			var old_modulate_down = modulate
			var new_alpha_down = modulate.a - starvation_alpha_step
			if new_alpha_down < low_alpha:
				new_alpha_down = low_alpha
				if Global.is_killing and killable:
					if bean_stage == BeanGrowthStage.POD_READY or bean_post_harvest_senescence:
						bean_harvest_ready = false
						bean_dead_ticks = 0
						bean_respawn_wait_ticks = BEAN_DEAD_RESPAWN_DELAY_TICKS
						bean_respawn_requested = false
						bean_post_harvest_senescence = false
						bean_post_harvest_ticks = 0
						bean_residue_pending = false
						bean_residue_emitted = false
						_set_bean_stage(BeanGrowthStage.DEAD)
					else:
						kill_it()
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
		
		Global.score += 400
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
	if _is_bean_lifecycle_enabled() and bean_stage != BeanGrowthStage.POD_READY:
		return
	
	var max_rounds = 10
	var current_round = 0
	var baby_made = false
	
	
	#produce a baby
	#find a random place nearby
	
	var new_x = global_position.x
	var new_y = global_position.y
	
	var size_x = sprite.get_rect().size[0]
	var size_y = sprite.get_rect().size[1]
	
	while(baby_made == false and current_round < max_rounds):
		if(Global.is_max_babies):
			if(current_babies >= num_babies):
				return
				
		new_x = global_position.x
		new_y = global_position.y
		current_round+=1
		var rng :=  RandomNumberGenerator.new()
		#print(" sizes: x: ", sprite.get_rect().size[0], " y: ", sprite.get_rect().size[1])
		var random_x = rng.randi_range(-1*size_x*4,size_x*4)
		var random_y = rng.randi_range(-1*size_y*4,size_y*4)
		
		#print(" rand_x: ", random_x, " rand_y: ", random_y)
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
	if (self.type == body.quarry_type):#"maize"):
		
		#print("bird endered: ", body)
		if(body.caught == false and caught_by == null):
			body.caught = true
			caught_by = body
			logistics_ready = false
			if(body is Bird):
				sprite.rotate(PI/4)
			self.dead = true
			_clear_active_selection_if_self()
			
			var living = false
			
			body.speed -=100
			
			
			body.going = Vector2(1,randi_range(-1,1))
			#var children =  $"../../Agents".get_children()
			for child in trade_buddies:# children:
				child.draw_lines = true
				child.new_buddies = true

			#sprite.z_index = 10
