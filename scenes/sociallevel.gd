extends Node2D

#to run: python3 -m http.server  .. browse to localhost:8000

const LevelHelpersRef = preload("res://scenes/level_helpers.gd")
const LevelRuntimeServicesRef = preload("res://scenes/level_runtime_services.gd")
const TEX_SQUASH = preload("res://graphics/mama.png")
const TEX_TREE = preload("res://graphics/bank.png")
const TEX_MAIZE = preload("res://graphics/cook.png")
const TEX_BEAN = preload("res://graphics/farmer.png")
const TEX_BASKET = preload("res://graphics/basket.png")
const PREDATOR_BIRD_SOUND_PATH := "res://audio/cardinal.mp3"
const PREDATOR_BIRD_ACTIVE_VOLUME_DB := -6.0
const PREDATOR_BIRD_DISTANT_VOLUME_DB := -24.0
const PREDATOR_BIRD_SILENT_VOLUME_DB := -48.0
const PREDATOR_BIRD_FADE_OUT_SECONDS := 0.28
const PREDATOR_BIRD_FOCUS_RADIUS_WORLD := 72.0
const PREDATOR_BIRD_APPROACH_FADE_DB_PER_SEC := 10.0
const PREDATOR_BIRD_DEPART_FADE_DB_PER_SEC := 44.0
const TUKTUK_ENGINE_SOUND_PATH := "res://audio/tuktuk-engine-loop.wav"
const TUKTUK_ENGINE_ACTIVE_VOLUME_DB := -13.0
const TUKTUK_ENGINE_DISTANT_VOLUME_DB := -28.0
const TUKTUK_ENGINE_SILENT_VOLUME_DB := -48.0
const TUKTUK_ENGINE_FADE_OUT_SECONDS := 0.28
const TUKTUK_ENGINE_FOCUS_RADIUS_WORLD := 72.0
const TUKTUK_ENGINE_APPROACH_FADE_DB_PER_SEC := 11.0
const TUKTUK_ENGINE_DEPART_FADE_DB_PER_SEC := 42.0

var socialagent_scene: PackedScene = load("res://scenes/socialagent.tscn")
var trade_scene: PackedScene = load("res://scenes/trade.tscn")
#var myco_scene: PackedScene = load("res://scenes/myco.tscn")
var basket_scene: PackedScene = load("res://scenes/basket.tscn")
var tuktuk_scene: PackedScene = load("res://scenes/tuktuk.tscn")
#var city_scene: PackedScene = load("res://scenes/city.tscn")
var bird_scene: PackedScene = load("res://scenes/bird.tscn")
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
var _trade_visual_packets_by_key: Dictionary = {}
var _shutdown_cleanup_done := false
var _bank_hotkey_enabled := true
var _tuktuk_engine_sound_player: AudioStreamPlayer = null
var _tuktuk_engine_active_count := 0
var _tuktuk_engine_fade_tween: Tween = null
var _tuktuk_engine_states: Dictionary = {}
var _predator_bird_sound_player: AudioStreamPlayer = null
var _predator_bird_active_count := 0
var _predator_bird_fade_tween: Tween = null
var _predator_bird_states: Dictionary = {}
const BASKET_NEAR_PERSON_MAX_TILES := 4


func _is_headless_runtime() -> bool:
	return DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server")


func _mute_runtime_audio_if_headless() -> void:
	if not _is_headless_runtime():
		return
	LevelHelpersRef.stop_audio_players([
		$BirdSound,
		$BirdLong,
		_predator_bird_sound_player,
		$CarSound,
		_tuktuk_engine_sound_player,
		$SquelchSound,
		$TwinkleSound,
		$BushSound
	])


func _play_squelch_at(world_pos: Vector2) -> void:
	var player: AudioStreamPlayer2D = get_node_or_null("SquelchSound") as AudioStreamPlayer2D
	if not is_instance_valid(player):
		return
	player.global_position = world_pos
	player.play()


func _ensure_tuktuk_engine_sound_player() -> AudioStreamPlayer:
	if is_instance_valid(_tuktuk_engine_sound_player):
		return _tuktuk_engine_sound_player
	var stream: AudioStream = LevelHelpersRef.load_tuktuk_engine_stream(TUKTUK_ENGINE_SOUND_PATH)
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	player.name = "TuktukEngineLoop"
	player.stream = stream
	player.volume_db = TUKTUK_ENGINE_SILENT_VOLUME_DB
	add_child(player)
	_tuktuk_engine_sound_player = player
	return _tuktuk_engine_sound_player


func _fade_tuktuk_engine(target_volume_db: float, duration: float, stop_after: bool = false) -> void:
	var engine_player := _ensure_tuktuk_engine_sound_player()
	if not is_instance_valid(engine_player):
		return
	if is_instance_valid(_tuktuk_engine_fade_tween):
		_tuktuk_engine_fade_tween.kill()
	_tuktuk_engine_fade_tween = get_tree().create_tween()
	_tuktuk_engine_fade_tween.tween_property(engine_player, "volume_db", target_volume_db, duration)
	if stop_after:
		_tuktuk_engine_fade_tween.finished.connect(func() -> void:
			if _tuktuk_engine_active_count <= 0 and is_instance_valid(engine_player):
				engine_player.stop()
		)


func _get_tuktuk_engine_listener_world_position() -> Vector2:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if is_instance_valid(camera):
		return camera.get_screen_center_position()
	return Global.get_world_center(self)


func _get_tuktuk_engine_audible_radius_world() -> float:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if is_instance_valid(camera):
		var view_size: Vector2 = get_viewport().get_visible_rect().size
		var zoom: Vector2 = camera.zoom
		var world_width: float = view_size.x / maxf(absf(zoom.x), 0.001)
		var world_height: float = view_size.y / maxf(absf(zoom.y), 0.001)
		return maxf(maxf(world_width, world_height) * 0.58, TUKTUK_ENGINE_FOCUS_RADIUS_WORLD + 1.0)
	var world_rect: Rect2 = Global.get_world_rect(self)
	return maxf(maxf(world_rect.size.x, world_rect.size.y) * 0.58, TUKTUK_ENGINE_FOCUS_RADIUS_WORLD + 1.0)


func _set_tuktuk_engine_state(tuktuk_id: int, tuktuk_pos: Vector2, escaping: bool) -> void:
	if tuktuk_id == 0:
		return
	_tuktuk_engine_states[tuktuk_id] = {
		"pos": tuktuk_pos,
		"escaping": escaping
	}
	_tuktuk_engine_active_count = _tuktuk_engine_states.size()


func _compute_tuktuk_engine_target_db() -> float:
	if _tuktuk_engine_states.is_empty():
		if _tuktuk_engine_active_count > 0:
			return TUKTUK_ENGINE_ACTIVE_VOLUME_DB
		return TUKTUK_ENGINE_SILENT_VOLUME_DB
	var listener_pos: Vector2 = _get_tuktuk_engine_listener_world_position()
	var audible_radius: float = _get_tuktuk_engine_audible_radius_world()
	var target_db: float = TUKTUK_ENGINE_DISTANT_VOLUME_DB
	for raw_state in _tuktuk_engine_states.values():
		if not (raw_state is Dictionary):
			continue
		var state: Dictionary = raw_state
		var pos: Variant = state.get("pos", listener_pos)
		if typeof(pos) != TYPE_VECTOR2:
			continue
		var tuktuk_pos: Vector2 = pos
		var escaping: bool = bool(state.get("escaping", false))
		var state_audible_radius: float = audible_radius
		if escaping:
			state_audible_radius = maxf(audible_radius * 0.62, TUKTUK_ENGINE_FOCUS_RADIUS_WORLD + 1.0)
		var fade_range: float = maxf(state_audible_radius - TUKTUK_ENGINE_FOCUS_RADIUS_WORLD, 1.0)
		var dist: float = listener_pos.distance_to(tuktuk_pos)
		var closeness: float = clampf(1.0 - ((dist - TUKTUK_ENGINE_FOCUS_RADIUS_WORLD) / fade_range), 0.0, 1.0)
		var shaped: float = closeness * closeness * (3.0 - 2.0 * closeness)
		target_db = maxf(target_db, lerpf(TUKTUK_ENGINE_DISTANT_VOLUME_DB, TUKTUK_ENGINE_ACTIVE_VOLUME_DB, shaped))
	return target_db


func _update_tuktuk_engine_volume(delta: float) -> void:
	if _shutdown_cleanup_done or _is_headless_runtime():
		return
	if _tuktuk_engine_active_count <= 0 and _tuktuk_engine_states.is_empty():
		return
	var engine_player := _ensure_tuktuk_engine_sound_player()
	if not is_instance_valid(engine_player):
		return
	if not engine_player.playing:
		engine_player.volume_db = TUKTUK_ENGINE_SILENT_VOLUME_DB
		engine_player.play()
	var target_db := _compute_tuktuk_engine_target_db()
	var fade_rate := TUKTUK_ENGINE_APPROACH_FADE_DB_PER_SEC
	if target_db < engine_player.volume_db:
		fade_rate = TUKTUK_ENGINE_DEPART_FADE_DB_PER_SEC
	engine_player.volume_db = move_toward(engine_player.volume_db, target_db, fade_rate * maxf(delta, 0.0))


func start_tuktuk_engine_sound(tuktuk_id: int = 0, tuktuk_pos: Vector2 = Vector2.ZERO, escaping: bool = false) -> void:
	if _shutdown_cleanup_done or _is_headless_runtime():
		return
	if tuktuk_id != 0:
		_set_tuktuk_engine_state(tuktuk_id, tuktuk_pos, escaping)
	else:
		_tuktuk_engine_active_count += 1
	var engine_player := _ensure_tuktuk_engine_sound_player()
	if is_instance_valid(engine_player):
		if is_instance_valid(_tuktuk_engine_fade_tween):
			_tuktuk_engine_fade_tween.kill()
			_tuktuk_engine_fade_tween = null
		if not engine_player.playing:
			engine_player.volume_db = TUKTUK_ENGINE_SILENT_VOLUME_DB
			engine_player.play()
		_update_tuktuk_engine_volume(0.0)


func update_tuktuk_engine_sound(tuktuk_id: int, tuktuk_pos: Vector2, escaping: bool = false) -> void:
	if _shutdown_cleanup_done or _is_headless_runtime():
		return
	_set_tuktuk_engine_state(tuktuk_id, tuktuk_pos, escaping)
	_update_tuktuk_engine_volume(0.0)


func stop_tuktuk_engine_sound(tuktuk_id: int = 0) -> void:
	if _shutdown_cleanup_done:
		return
	if tuktuk_id != 0:
		_tuktuk_engine_states.erase(tuktuk_id)
		_tuktuk_engine_active_count = _tuktuk_engine_states.size()
	else:
		_tuktuk_engine_active_count = maxi(_tuktuk_engine_active_count - 1, 0)
	if _tuktuk_engine_active_count > 0:
		return
	var engine_player := _tuktuk_engine_sound_player
	if is_instance_valid(engine_player) and engine_player.playing:
		_fade_tuktuk_engine(TUKTUK_ENGINE_SILENT_VOLUME_DB, TUKTUK_ENGINE_FADE_OUT_SECONDS, true)


func play_tuktuk_entry_sound() -> void:
	start_tuktuk_engine_sound()


func _ensure_predator_bird_sound_player() -> AudioStreamPlayer:
	if is_instance_valid(_predator_bird_sound_player):
		return _predator_bird_sound_player
	var stream: AudioStream = LevelHelpersRef.load_looping_audio_stream(PREDATOR_BIRD_SOUND_PATH)
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	player.name = "PredatorBirdLoop"
	player.stream = stream
	player.volume_db = PREDATOR_BIRD_SILENT_VOLUME_DB
	add_child(player)
	_predator_bird_sound_player = player
	return _predator_bird_sound_player


func _fade_predator_bird_sound(target_volume_db: float, duration: float, stop_after: bool = false) -> void:
	var bird_player := _ensure_predator_bird_sound_player()
	if not is_instance_valid(bird_player):
		return
	if is_instance_valid(_predator_bird_fade_tween):
		_predator_bird_fade_tween.kill()
	_predator_bird_fade_tween = get_tree().create_tween()
	_predator_bird_fade_tween.tween_property(bird_player, "volume_db", target_volume_db, duration)
	if stop_after:
		_predator_bird_fade_tween.finished.connect(func() -> void:
			if _predator_bird_active_count <= 0 and is_instance_valid(bird_player):
				bird_player.stop()
		)


func _get_predator_bird_audible_radius_world() -> float:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if is_instance_valid(camera):
		var view_size: Vector2 = get_viewport().get_visible_rect().size
		var zoom: Vector2 = camera.zoom
		var world_width: float = view_size.x / maxf(absf(zoom.x), 0.001)
		var world_height: float = view_size.y / maxf(absf(zoom.y), 0.001)
		return maxf(maxf(world_width, world_height) * 0.58, PREDATOR_BIRD_FOCUS_RADIUS_WORLD + 1.0)
	var world_rect: Rect2 = Global.get_world_rect(self)
	return maxf(maxf(world_rect.size.x, world_rect.size.y) * 0.58, PREDATOR_BIRD_FOCUS_RADIUS_WORLD + 1.0)


func _set_predator_bird_state(bird_id: int, bird_pos: Vector2, escaping: bool) -> void:
	if bird_id == 0:
		return
	_predator_bird_states[bird_id] = {
		"pos": bird_pos,
		"escaping": escaping
	}
	_predator_bird_active_count = _predator_bird_states.size()


func _compute_predator_bird_target_db() -> float:
	if _predator_bird_states.is_empty():
		if _predator_bird_active_count > 0:
			return PREDATOR_BIRD_ACTIVE_VOLUME_DB
		return PREDATOR_BIRD_SILENT_VOLUME_DB
	var listener_pos: Vector2 = _get_tuktuk_engine_listener_world_position()
	var audible_radius: float = _get_predator_bird_audible_radius_world()
	var target_db: float = PREDATOR_BIRD_DISTANT_VOLUME_DB
	for raw_state in _predator_bird_states.values():
		if not (raw_state is Dictionary):
			continue
		var state: Dictionary = raw_state
		var pos: Variant = state.get("pos", listener_pos)
		if typeof(pos) != TYPE_VECTOR2:
			continue
		var bird_pos: Vector2 = pos
		var escaping: bool = bool(state.get("escaping", false))
		var state_audible_radius: float = audible_radius
		if escaping:
			state_audible_radius = maxf(audible_radius * 0.62, PREDATOR_BIRD_FOCUS_RADIUS_WORLD + 1.0)
		var fade_range: float = maxf(state_audible_radius - PREDATOR_BIRD_FOCUS_RADIUS_WORLD, 1.0)
		var dist: float = listener_pos.distance_to(bird_pos)
		var closeness: float = clampf(1.0 - ((dist - PREDATOR_BIRD_FOCUS_RADIUS_WORLD) / fade_range), 0.0, 1.0)
		var shaped: float = closeness * closeness * (3.0 - 2.0 * closeness)
		target_db = maxf(target_db, lerpf(PREDATOR_BIRD_DISTANT_VOLUME_DB, PREDATOR_BIRD_ACTIVE_VOLUME_DB, shaped))
	return target_db


func _update_predator_bird_volume(delta: float) -> void:
	if _shutdown_cleanup_done or _is_headless_runtime():
		return
	if _predator_bird_active_count <= 0 and _predator_bird_states.is_empty():
		return
	var bird_player := _ensure_predator_bird_sound_player()
	if not is_instance_valid(bird_player):
		return
	if not bird_player.playing:
		bird_player.volume_db = PREDATOR_BIRD_SILENT_VOLUME_DB
		bird_player.play()
	var target_db := _compute_predator_bird_target_db()
	var fade_rate := PREDATOR_BIRD_APPROACH_FADE_DB_PER_SEC
	if target_db < bird_player.volume_db:
		fade_rate = PREDATOR_BIRD_DEPART_FADE_DB_PER_SEC
	bird_player.volume_db = move_toward(bird_player.volume_db, target_db, fade_rate * maxf(delta, 0.0))


func start_predator_bird_sound(bird_id: int = 0, bird_pos: Vector2 = Vector2.ZERO, escaping: bool = false) -> void:
	if _shutdown_cleanup_done or _is_headless_runtime():
		return
	if bird_id != 0:
		_set_predator_bird_state(bird_id, bird_pos, escaping)
	else:
		_predator_bird_active_count += 1
	var bird_player := _ensure_predator_bird_sound_player()
	if is_instance_valid(bird_player):
		if is_instance_valid(_predator_bird_fade_tween):
			_predator_bird_fade_tween.kill()
			_predator_bird_fade_tween = null
		if not bird_player.playing:
			bird_player.volume_db = PREDATOR_BIRD_SILENT_VOLUME_DB
			bird_player.play()
		_update_predator_bird_volume(0.0)


func update_predator_bird_sound(bird_id: int, bird_pos: Vector2, escaping: bool = false) -> void:
	if _shutdown_cleanup_done or _is_headless_runtime():
		return
	_set_predator_bird_state(bird_id, bird_pos, escaping)
	_update_predator_bird_volume(0.0)


func stop_predator_bird_sound(bird_id: int = 0) -> void:
	if _shutdown_cleanup_done:
		return
	if bird_id != 0:
		_predator_bird_states.erase(bird_id)
		_predator_bird_active_count = _predator_bird_states.size()
	else:
		_predator_bird_active_count = maxi(_predator_bird_active_count - 1, 0)
	if _predator_bird_active_count > 0:
		return
	var bird_player := _predator_bird_sound_player
	if is_instance_valid(bird_player) and bird_player.playing:
		_fade_predator_bird_sound(PREDATOR_BIRD_SILENT_VOLUME_DB, PREDATOR_BIRD_FADE_OUT_SECONDS, true)


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
	if LevelHelpersRef.is_tile_occupied(self, $Agents, coord, ignore_agent, true):
		result["ok"] = false
		return result
	result["pos"] = world.tile_to_world_center(coord)
	return result


func _tile_chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(abs(a.x - b.x), abs(a.y - b.y))


func _is_village_person_type(agent_type: String) -> bool:
	return agent_type == "bean" or agent_type == "squash" or agent_type == "maize" or agent_type == "farmer" or agent_type == "vendor" or agent_type == "cook"


func _can_place_basket_near_person(world_pos: Vector2) -> bool:
	var world = _get_world_foundation()
	if not (is_instance_valid(world) and world.has_method("world_to_tile")):
		return false
	var basket_coord = Vector2i(world.world_to_tile(world_pos))
	for agent in $Agents.get_children():
		if not is_instance_valid(agent):
			continue
		if bool(agent.get("dead")):
			continue
		if not _is_village_person_type(str(agent.get("type"))):
			continue
		var person_coord = Vector2i(world.world_to_tile(agent.global_position))
		if _tile_chebyshev_distance(basket_coord, person_coord) <= BASKET_NEAR_PERSON_MAX_TILES:
			return true
	return false


func can_place_inventory_item_at_world_pos(item_name: String, world_pos: Vector2) -> bool:
	var spawn_name = str(item_name)
	if spawn_name == "":
		return false
	if int(Global.inventory.get(spawn_name, 0)) <= 0:
		return false
	var world = _get_world_foundation()
	if not (is_instance_valid(world) and world.has_method("world_to_tile") and world.has_method("tile_to_world_center") and world.has_method("in_bounds")):
		return false
	var coord = Vector2i(world.world_to_tile(world_pos))
	if not world.in_bounds(coord):
		return false
	var target_pos = world.tile_to_world_center(coord)
	if world.has_method("is_world_pos_revealed") and not bool(world.is_world_pos_revealed(target_pos)):
		return false
	var exact_spawn = _resolve_exact_tile_spawn_pos(target_pos)
	if not bool(exact_spawn.get("ok", false)):
		return false
	if spawn_name == "basket" or spawn_name == "myco":
		if not _can_place_basket_near_person(target_pos):
			return false
	if spawn_name == "myco" and world.has_method("can_place_myco_on_tile"):
		if not bool(world.call("can_place_myco_on_tile", coord)):
			return false
	return true


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


func _agent_key(agent: Variant) -> int:
	return LevelRuntimeServicesRef.agent_key(agent)


func request_agent_dirty(agent: Variant, buddies: bool = true, lines: bool = true, tile_hint: bool = false) -> void:
	LevelRuntimeServicesRef.request_agent_dirty(_dirty_buddies_agents, _dirty_lines_agents, _dirty_tile_hints_agents, agent, buddies, lines, tile_hint)


func request_all_agents_dirty() -> void:
	for agent in $Agents.get_children():
		request_agent_dirty(agent, true, true, false)


func mark_agent_moved(agent: Variant, old_pos: Vector2, new_pos: Vector2) -> void:
	LevelHelpersRef.mark_agents_dirty_for_movement(self, $Agents, agent, old_pos, new_pos)
	LevelHelpersRef.sync_agent_occupancy(self, agent)


func _process_dirty_queues() -> void:
	LevelRuntimeServicesRef.process_dirty_queues(self, $Agents, $Lines, _dirty_buddies_agents, _dirty_lines_agents, _dirty_tile_hints_agents, true)


func _setup_perf_monitor() -> void:
	perf_monitor = LevelRuntimeServicesRef.setup_perf_monitor(self, perf_monitor, $Agents, $Trades, $Lines, _get_world_foundation())


func _recycle_trade(trade: Node) -> void:
	LevelRuntimeServicesRef.recycle_trade(_trade_pool, _trade_visual_packets_by_key, trade)


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
	DisplayServer.window_set_title("Social Soil")
	if not _is_headless_runtime():
		$BirdLong.play()
	var world = _get_world_foundation()
	if is_instance_valid(world) and world.has_method("set_context"):
		world.set_context(Global.mode, "people")
	#$BirdLong.
		 
	$"UI/TutorialMarginContainer1".visible = false
	if(Global.mode == "tutorial"):
		$"UI/TutorialMarginContainer1".visible=true
		$"UI/TutorialMarginContainer1/Label".text = Global.social_stage_text[Global.stage]
		_set_tutorial_panel_color(Global.stage_colors[Global.stage])

	var world_center = _get_world_center()
	mid_width = int(world_center.x)
	mid_height = int(world_center.y)
	
	
	var tree_center_offset_x = 220
	var tree_center_offset_y = -300
	var tree_position = Vector2(mid_width+tree_center_offset_x,mid_height+tree_center_offset_y)
	
	make_tree(tree_position)
	
	
	
	var myco_width = mid_width + 40
	var myco_height = mid_height + 100
	var myco_position = Vector2(myco_width,myco_height)

	#var myco = make_myco(myco_position)

	#Global.active_agent = myco
	
	var bean_center_offset_x = 80
	var bean_center_offset_y = -90
	var bean_position = Vector2(mid_width+bean_center_offset_x,mid_height+bean_center_offset_y)
	
	make_bean(bean_position)
	
	var bi_myco_n_width = mid_width + 100
	var bi_myco_n_height = mid_height - 210
	var bi_myco_n_position = Vector2(bi_myco_n_width,bi_myco_n_height)

	var bi_n_myco = make_bi_n_myco(bi_myco_n_position)


	var squash_center_offset_x = 120
	var squash_center_offset_y = -70
	var squash_position = Vector2(mid_width+squash_center_offset_x,mid_height+squash_center_offset_y)
	
	make_squash(squash_position)
	

	var bi_myco_p_width = mid_width + 160
	var bi_myco_p_height = mid_height - 220
	var bi_myco_p_position = Vector2(bi_myco_p_width,bi_myco_p_height)

	var bi_p_myco = make_bi_p_myco(bi_myco_p_position)
	
	
	
	var maize_center_offset_x = 200
	var maize_center_offset_y = -80
	var maize_position = Vector2(mid_width+maize_center_offset_x,mid_height+maize_center_offset_y)
	
	make_maize(maize_position)

	
	var bi_myco_k_width = mid_width + 210
	var bi_myco_k_height = mid_height - 230
	var bi_myco_k_position = Vector2(bi_myco_k_width,bi_myco_k_height)

	var bi_k_myco = make_bi_k_myco(bi_myco_k_position)

	LevelHelpersRef.rebuild_world_occupancy_cache(self, $Agents)
	request_all_agents_dirty()
	_process_dirty_queues()
	
			
func _is_android_back_input(event: InputEvent) -> bool:
	return LevelHelpersRef.is_android_back_input(event)


func _handle_android_back_request(event: InputEvent) -> bool:
	return LevelHelpersRef.handle_android_back_request(self, event)


func _is_keyboard_escape_input(event: InputEvent) -> bool:
	return LevelHelpersRef.is_keyboard_escape_input(event)


func _on_ui_request_back_to_menu() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://scenes/game_over.tscn")


func toggle_bank_hotkey() -> void:
	_bank_hotkey_enabled = not _bank_hotkey_enabled
	for agent in $Agents.get_children():
		if not is_instance_valid(agent):
			continue
		if str(agent.get("type")) != "bank":
			continue
		agent.set_meta("bank_disabled", not _bank_hotkey_enabled)
		if _bank_hotkey_enabled:
			agent.set("logistics_ready", true)
	print("Bank trading hotkey state: ", "ON" if _bank_hotkey_enabled else "OFF")


func _input(event):
	if LevelHelpersRef.handle_level_back_or_escape_input(self, event):
		return
	if LevelHelpersRef.handle_gameplay_hotkeys(event, self, $Agents, true):
		return


func _process(_delta: float) -> void:
	_update_tuktuk_engine_volume(_delta)
	_update_predator_bird_volume(_delta)
	if not Global.is_mobile_platform:
		LevelHelpersRef.update_agent_hover_focus(self, $Agents)
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
				
				
				
				



func _on_player_laser(path_dict) -> void:
	pass
	#var trade = trade_scene.instantiate()
	#trade.set_variables(path_dict)
	#print(" trade created: ", path_dict["from_agent"], " ", path_dict)
	#$Trades.add_child(trade)
	
func _on_agent_trade(path_dict) -> void:
	call_deferred("_spawn_trade", path_dict)


func _build_trade_visual_key(path_dict: Dictionary) -> String:
	return LevelRuntimeServicesRef.build_trade_visual_key(path_dict)


func _get_trade_visual_key_for_packet(trade: Node) -> String:
	return LevelRuntimeServicesRef.get_trade_visual_key_for_packet(trade)


func _get_trade_visual_packets_for_key(visual_key: String) -> Array:
	return LevelRuntimeServicesRef.get_trade_visual_packets_for_key(_trade_visual_packets_by_key, $Trades, visual_key)


func _register_trade_visual_packet(trade: Node) -> void:
	LevelRuntimeServicesRef.register_trade_visual_packet(_trade_visual_packets_by_key, trade)


func _unregister_trade_visual_packet(trade: Node) -> void:
	LevelRuntimeServicesRef.unregister_trade_visual_packet(_trade_visual_packets_by_key, trade)


func _spawn_trade(path_dict) -> void:
	if typeof(path_dict) != TYPE_DICTIONARY:
		return
	var trade_dict: Dictionary = path_dict.duplicate()
	if int(trade_dict.get("created_at_msec", 0)) <= 0:
		trade_dict["created_at_msec"] = Time.get_ticks_msec()
	var trade_amount = maxi(int(trade_dict.get("trade_amount", 1)), 1)
	trade_dict["trade_amount"] = trade_amount
	if Global.trade_visual_hybrid_enabled:
		var visual_key = _build_trade_visual_key(trade_dict)
		if visual_key != "":
			trade_dict["visual_key"] = visual_key
			var per_link_cap = Global.get_trade_visual_link_packet_cap()
			var packets_for_key = _get_trade_visual_packets_for_key(visual_key)
			if packets_for_key.size() >= per_link_cap:
				for packet in packets_for_key:
					if not is_instance_valid(packet):
						continue
					if not packet.has_method("accumulate_trade_amount"):
						continue
					var aggregated = bool(packet.call("accumulate_trade_amount", trade_amount))
					if aggregated:
						return
	var trade = null
	if not _trade_pool.is_empty():
		trade = _trade_pool.pop_back()
	else:
		trade = trade_scene.instantiate()
	if trade.has_method("set_pool_owner"):
		trade.set_pool_owner(self)
	if trade.has_method("activate_trade"):
		trade.activate_trade(trade_dict)
	else:
		trade.set_variables(trade_dict)
	$Trades.add_child(trade)
	_register_trade_visual_packet(trade)
	
func update_bars(path_dict)  -> void:
	if is_instance_valid(Global.active_agent) and is_instance_valid(path_dict["from_agent"]) and is_instance_valid(path_dict["to_agent"]):  
		if Global.active_agent.name == path_dict["from_agent"].name or Global.active_agent.name == path_dict["to_agent"].name:
			for label in $UI.resContainer.get_children():
				#print("g. << inside asadas: ", label.name, " : ", label.text, path_dict["trade_asset"])
				if label.name == path_dict["trade_asset"]:
					#print("h. ><><< inside asadas, lable", label.name, " : ", label.text)
					label.text = str(path_dict["trade_asset"]) + str(" ") + str(Global.active_agent.assets[path_dict["trade_asset"]])


func _play_predator_alert() -> void:
	return


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
	var ui_node = get_node_or_null("UI")
	if is_instance_valid(ui_node) and ui_node.has_method("refresh_score_rank_display"):
		ui_node.refresh_score_rank_display()
	if current_score_lvl > score_lvl:
		score_lvl = current_score_lvl
		#print("create birds: ", Global.birds[score_lvl])
		if(Global.is_birding == true):
			Global.rand_quarry.shuffle()
			var z_quarry = Global.rand_quarry[0]
			Global.quarry_type = z_quarry
			_spawn_predators(Global.get_predator_spawn_count(score_lvl), true)
	if(Global.mode == "challenge" and Global.ranks[current_score_lvl] == "Grassroots Economist"):
		get_tree().call_deferred("change_scene_to_file","res://scenes/game_over.tscn")


func _refund_inventory_item(item_name: String, amount: int = 1) -> void:
	if item_name == "":
		return
	if amount <= 0:
		return
	Global.inventory[item_name] = int(Global.inventory.get(item_name, 0)) + amount
	var ui_node = get_node_or_null("UI")
	if is_instance_valid(ui_node) and ui_node.has_method("refresh_inventory_counts"):
		ui_node.refresh_inventory_counts()


func _on_new_agent(agent_dict) -> void:
	#print("found signal: ", agent_dict)
	var new_agent = null
	var spawn_name = str(agent_dict["name"])
	var spawn_pos = agent_dict["pos"]
	var ignore_agent = agent_dict.get("ignore_agent", null)
	var require_exact_tile = bool(agent_dict.get("require_exact_tile", false))
	var from_inventory = bool(agent_dict.get("from_inventory", false))
	if bool(agent_dict.get("allow_replace", false)):
		var replace_target = _find_replaceable_agent_at_world_pos(spawn_pos, ignore_agent)
		if is_instance_valid(replace_target):
			ignore_agent = replace_target
			if replace_target.has_method("kill_it"):
				replace_target.kill_it()
			else:
				LevelHelpersRef.unregister_agent_occupancy(self, replace_target)
				replace_target.call_deferred("queue_free")
			require_exact_tile = true
	if require_exact_tile:
		var exact_spawn = _resolve_exact_tile_spawn_pos(spawn_pos, ignore_agent)
		if not bool(exact_spawn["ok"]):
			if from_inventory:
				_refund_inventory_item(spawn_name, 1)
			return
		spawn_pos = exact_spawn["pos"]
	if (spawn_name == "myco" or spawn_name == "basket") and not _can_place_basket_near_person(spawn_pos):
		if from_inventory:
			_refund_inventory_item(spawn_name, 1)
		return
	if spawn_name  == "squash":
		$TwinkleSound.play()
		new_agent = make_squash(spawn_pos)
	elif spawn_name  == "bean":
		$TwinkleSound.play()
		new_agent = make_bean(spawn_pos)
	elif spawn_name  == "maize":
		$TwinkleSound.play()
		new_agent = make_maize(spawn_pos)
	elif spawn_name  == "myco" or spawn_name == "basket":
		_play_squelch_at(spawn_pos)
		new_agent = make_myco(spawn_pos)
	elif spawn_name  == "tree":
		$BushSound.play()
		new_agent = make_tree(spawn_pos)
	
	if is_instance_valid(new_agent):
		if agent_dict.has("spawn_anchor"):
			LevelHelpersRef.ensure_spawn_buddy_link(new_agent, agent_dict["spawn_anchor"])
		LevelHelpersRef.sync_agent_occupancy(self, new_agent)
		Global.apply_perf_density_gate($Agents.get_child_count())
		request_all_agents_dirty()
		new_agent.peak_maturity = 4
	if(Global.active_agent == null and not Global.prevent_auto_select):
		Global.active_agent = new_agent
		LevelHelpersRef.refresh_agent_bar_visibility($Agents)
func make_squash(pos):
	#print("Clicked On Squash. making")
	
	var squash_position = _resolve_tile_spawn_pos(pos)
	
	var named = LevelHelpersRef.make_agent_name("Squash", $Agents)
	var squash_dict = LevelHelpersRef.build_agent_setup_dict(named, "squash", squash_position, ["P"], TEX_SQUASH)
	
	var squash = socialagent_scene.instantiate()
	
	squash.set_variables(squash_dict)
	#squash.needs["R"]=0
	$Agents.add_child(squash)
	squash.buddy_radius = Global.social_buddy_radius
	LevelHelpersRef.connect_core_agent_signals(squash, _on_agent_trade, _on_new_agent, _on_update_score)
	LevelHelpersRef.sync_agent_occupancy(self, squash)
	request_all_agents_dirty()
	
	return squash

func make_tree(pos):
	#print("Clicked On Squash. making")
	
	var tree_position = _resolve_tile_spawn_pos(pos)
	
	var named = LevelHelpersRef.make_agent_name("Tree", $Agents)
	var tree_dict = LevelHelpersRef.build_agent_setup_dict(named, "tree", tree_position, ["R"], TEX_TREE)
	var tree = socialagent_scene.instantiate()
	#tree.needs["R"] = 40
	tree.set_variables(tree_dict)
	#tree.needs["R"]=20
	$Agents.add_child(tree)
	tree.position = LevelHelpersRef.resolve_snapped_position_for_agent(self, $Agents, tree, tree_position)
	tree.buddy_radius = Global.social_buddy_radius
	tree.draggable = false
	tree.killable = false
	LevelHelpersRef.connect_core_agent_signals(tree, _on_agent_trade, _on_new_agent, _on_update_score)
	LevelHelpersRef.sync_agent_occupancy(self, tree)
	request_all_agents_dirty()
	return tree
	
	
func make_bird():
	call_deferred("_spawn_bird")


func _spawn_bird():
	var bird = null
	if(Global.social_mode):
		bird = tuktuk_scene.instantiate()
	else:
		bird = bird_scene.instantiate()
	$Animals.add_child(bird)


	
func make_maize(pos):
	var maize_position = _resolve_tile_spawn_pos(pos)
	
	var named = LevelHelpersRef.make_agent_name("Maize", $Agents)
	var maize_dict = LevelHelpersRef.build_agent_setup_dict(named, "maize", maize_position, ["K"], TEX_MAIZE)
	var maize = socialagent_scene.instantiate()
	maize.set_variables(maize_dict)
	$Agents.add_child(maize)
	maize.buddy_radius = Global.social_buddy_radius
	LevelHelpersRef.connect_core_agent_signals(maize, _on_agent_trade, _on_new_agent, _on_update_score)
	LevelHelpersRef.sync_agent_occupancy(self, maize)
	request_all_agents_dirty()
	
	return maize
		
func make_bean(pos):
	
	var bean_position = _resolve_tile_spawn_pos(pos)
	
	var named = LevelHelpersRef.make_agent_name("Bean", $Agents)
	var bean_dict = LevelHelpersRef.build_agent_setup_dict(named, "bean", bean_position, ["N"], TEX_BEAN)
	var bean = socialagent_scene.instantiate()
	
	bean.set_variables(bean_dict)
	#bean.needs["R"]=0
	$Agents.add_child(bean)
	bean.buddy_radius = Global.social_buddy_radius
	LevelHelpersRef.connect_core_agent_signals(bean, _on_agent_trade, _on_new_agent, _on_update_score)
	LevelHelpersRef.sync_agent_occupancy(self, bean)
	request_all_agents_dirty()
	
	return bean


func make_myco(pos):
	var myco_position = _resolve_tile_spawn_pos(pos)
	
	var named = LevelHelpersRef.make_agent_name("Myco_Basket", $Agents, "")
	var myco_dict = LevelHelpersRef.build_agent_setup_dict(named, "myco", myco_position, [null], TEX_BASKET)
	
	var basket = basket_scene.instantiate()
	basket.set_variables(myco_dict)
	basket.draw_lines = true
	basket.sprite_texture = TEX_BASKET
	$Agents.add_child(basket)
	
	if basket.has_signal("trade"):
		basket.connect("trade", _on_agent_trade)
	LevelHelpersRef.sync_agent_occupancy(self, basket)
	request_all_agents_dirty()
	
	return basket
	

func make_bi_n_myco(pos):
	return _make_bi_myco(pos, "N")
		

func make_bi_p_myco(pos):
	return _make_bi_myco(pos, "P")


func make_bi_k_myco(pos):
	return _make_bi_myco(pos, "K")


func _make_bi_myco(pos: Vector2, asset_key: String):
	var myco_position = _resolve_tile_spawn_pos(pos)
	
	var named = LevelHelpersRef.make_agent_name(str("Bi-", asset_key, "-Mycorrhizal"), $Agents)
	var myco_dict = LevelHelpersRef.build_agent_setup_dict(named, "myco", myco_position, [null], TEX_BASKET)
	
	var basket = basket_scene.instantiate()
	basket.assets = {
		asset_key: 5,
		"R": 5
	}
	basket.needs = {
	asset_key: 10,
	"R": 10
	}
	basket.set_variables(myco_dict)
	$Agents.add_child(basket)
	basket.draw_lines = true
	basket.draggable = true
	basket.killable = false
	basket.sprite.modulate = Global.asset_colors[asset_key]
	
	if basket.has_signal("trade"):
		basket.connect("trade", _on_agent_trade)
	LevelHelpersRef.sync_agent_occupancy(self, basket)
	request_all_agents_dirty()
	
	return basket



func _on_tutorial_timer_timeout() -> void:
	if(Global.mode == "tutorial"):
		#print("mode: ", Global.mode, "stage: ", Global.stage)
		if( Global.stage == 1):
			
			var c_buds = 0
			for child in $Agents.get_children():
				if(child.type=="myco"):
					c_buds += 1
				#print(" child bud: ", child.name, " ", child.trade_buddies)
			#print("len buds: ", c_buds)
			if(c_buds >=4):
				Global.stage += 1
				$"UI/TutorialMarginContainer1/Label".text = Global.social_stage_text[Global.stage]
				_set_tutorial_panel_color(Global.stage_colors[Global.stage])
			
		elif(Global.stage == 2):
			
			var c_buds = 0
			var num_myco = 0
			for child in $Agents.get_children():
				if(child.type=="myco"):
					num_myco += 1
			if(num_myco >=5):
				Global.stage += 1
				$"UI/TutorialMarginContainer1/Label".text = Global.social_stage_text[Global.stage]
				_set_tutorial_panel_color(Global.stage_colors[Global.stage])
		elif(Global.stage == 3):
			
			var c_buds = 0
			var num_myco = 0
			for child in $Agents.get_children():
				if(child.type=="myco"):
					num_myco += 1
					c_buds += len(child.trade_buddies)
					#print(" child bud: ", child.name, " ", child.trade_buddies)
			if(num_myco >= 5 and c_buds >=3):
				Global.stage += 1
				$"UI/TutorialMarginContainer1/Label".text = Global.social_stage_text[Global.stage]
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
				$"UI/TutorialMarginContainer1/Label".text = Global.social_stage_text[Global.stage]
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
				$"UI/TutorialMarginContainer1/Label".text = Global.social_stage_text[Global.stage]
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
				$"UI/TutorialMarginContainer1/Label".text = Global.social_stage_text[Global.stage]
				_set_tutorial_panel_color(Global.stage_colors[Global.stage])
		
		elif(Global.stage == 7):
			
			var c_maize = 0
			for child in $Agents.get_children():
				if(child.type=="maize" and child.dead==false):
					c_maize += 1
					
			if(c_maize >=2 and Global.values['K']<=1.1):
				Global.stage = 8
				$"UI/TutorialMarginContainer1/Label".text = Global.social_stage_text[Global.stage]
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
	_tuktuk_engine_active_count = 0
	_tuktuk_engine_states.clear()
	if is_instance_valid(_tuktuk_engine_fade_tween):
		_tuktuk_engine_fade_tween.kill()
		_tuktuk_engine_fade_tween = null
	_predator_bird_active_count = 0
	_predator_bird_states.clear()
	if is_instance_valid(_predator_bird_fade_tween):
		_predator_bird_fade_tween.kill()
		_predator_bird_fade_tween = null
	LevelHelpersRef.clear_trade_line_cache($Lines, true)
	LevelHelpersRef.clear_inventory_connection_preview_lines(inventory_preview_lines, true)
	LevelHelpersRef.stop_audio_players([
		$BirdSound,
		$BirdLong,
		_predator_bird_sound_player,
		$CarSound,
		_tuktuk_engine_sound_player,
		$SquelchSound,
		$TwinkleSound,
		$BushSound
	], true)
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
		
						
			
			
