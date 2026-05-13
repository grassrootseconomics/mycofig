extends Control

const LevelHelpersRef = preload("res://scenes/level_helpers.gd")
const TITLE_COMPACT_SHORT_EDGE := 640.0
const TITLE_TINY_SHORT_EDGE := 500.0
const GE_LOGO_PATH := "res://graphics/ge-logo-horizontal-text.png"
const TITLE_SOIL_BACKGROUND_PATH := "res://graphics/soil_end.jpeg"
const TITLE_ART_BACKGROUND_PATH := "res://graphics/social.png"
const TITLE_PREDATOR_BIRD_SOUND_PATH := "res://audio/cardinal.mp3"
const TITLE_TUKTUK_ENGINE_SOUND_PATH := "res://audio/tuktuk-engine-loop.wav"
const TITLE_BASKET_LAND_SOUND_PATH := "res://audio/squelch_slayer.wav"
const TITLE_SCORE_STAR_COUNT := 12
const TITLE_BIRD_FRAME_PATHS := [
	"res://graphics/bird1.png",
	"res://graphics/bird2.png",
	"res://graphics/bird3.png",
	"res://graphics/bird4.png"
]
const TITLE_TUKTUK_TEXTURE_PATH := "res://graphics/tuktuk.png"
const TITLE_BASKET_TEXTURE_PATH := "res://graphics/basket.png"
const TITLE_BIRD_FLYBY_SECONDS := 4.8
const TITLE_BASKET_DROP_SECONDS := 1.05
const TITLE_BASKET_DROP_LAND_T := 0.72
const TITLE_TUKTUK_FLYBY_SECONDS := 4.2
const TITLE_FLYBY_WAIT_SECONDS := 1.5
const TITLE_PREDATOR_BIRD_ACTIVE_VOLUME_DB := -6.0
const TITLE_PREDATOR_BIRD_DISTANT_VOLUME_DB := -24.0
const TITLE_PREDATOR_BIRD_SILENT_VOLUME_DB := -48.0
const TITLE_TUKTUK_ENGINE_ACTIVE_VOLUME_DB := -9.0
const TITLE_TUKTUK_ENGINE_DISTANT_VOLUME_DB := -25.0
const TITLE_TUKTUK_ENGINE_SILENT_VOLUME_DB := -48.0
const TITLE_BASKET_LAND_VOLUME_DB := -16.0
const TITLE_FLYBY_FOCUS_RADIUS := 90.0
const TITLE_FLYBY_APPROACH_FADE_DB_PER_SEC := 10.0
const TITLE_FLYBY_DEPART_FADE_DB_PER_SEC := 44.0

var _ge_logo_texture: Texture2D = null
var _title_soil_background: TextureRect = null
var _title_art_background: TextureRect = null
var _title_pending_layout_frames := 0
var _last_score_label: Label = null
var _high_score_label: Label = null
var _last_score_panel: Panel = null
var _high_score_panel: Panel = null
var _title_score_star_layer: Control = null
var _title_score_stars: Array[Label] = []
var _title_score_sparkle_target: Label = null
var _title_score_sparkle_time := 0.0
var _title_flyby_layer: Node2D = null
var _title_bird_sprite: AnimatedSprite2D = null
var _title_bird_basket_sprite: Sprite2D = null
var _title_tuktuk_node: Node2D = null
var _title_tuktuk_basket_sprite: Sprite2D = null
var _title_flyby_running := false
var _title_flyby_phase := ""
var _title_flyby_elapsed := 0.0
var _title_bird_start_pos := Vector2.ZERO
var _title_bird_drop_pos := Vector2.ZERO
var _title_bird_exit_pos := Vector2.ZERO
var _title_basket_drop_start_pos := Vector2.ZERO
var _title_basket_rest_pos := Vector2.ZERO
var _title_tuktuk_start_pos := Vector2.ZERO
var _title_tuktuk_pickup_pos := Vector2.ZERO
var _title_tuktuk_exit_pos := Vector2.ZERO
var _title_tuktuk_pickup_seconds := 0.0
var _title_tuktuk_exit_seconds := 0.0
var _title_basket_land_sound_played := false
var _title_predator_bird_sound_player: AudioStreamPlayer = null
var _title_tuktuk_engine_sound_player: AudioStreamPlayer = null
var _title_basket_land_sound_player: AudioStreamPlayer = null


func _get_ge_logo_texture() -> Texture2D:
	if is_instance_valid(_ge_logo_texture):
		return _ge_logo_texture
	var texture: Resource = load(GE_LOGO_PATH)
	if not texture is Texture2D:
		return null
	_ge_logo_texture = texture as Texture2D
	return _ge_logo_texture

func _make_cta_style(bg_color: Color, border_color: Color, border_width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 5
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _make_ge_logo_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.97)
	style.border_color = Color(0.88, 0.82, 0.64, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


func _make_title_score_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.16, 0.09, 0.58)
	style.border_color = Color(1.0, 0.86, 0.32, 0.72)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	return style


func _style_cta_button(button: Button, base_bg: Color, base_border: Color) -> void:
	if not is_instance_valid(button):
		return
	button.custom_minimum_size = Vector2(340, 78)
	button.size_flags_horizontal = Control.SIZE_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 46)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))

	var hover_bg = base_bg.lightened(0.12)
	var pressed_bg = base_bg.darkened(0.15)
	var focus_border = Color(1, 1, 1, 0.95)

	button.add_theme_stylebox_override("normal", _make_cta_style(base_bg, base_border, 2))
	button.add_theme_stylebox_override("hover", _make_cta_style(hover_bg, base_border, 3))
	button.add_theme_stylebox_override("pressed", _make_cta_style(pressed_bg, base_border, 2))
	button.add_theme_stylebox_override("focus", _make_cta_style(hover_bg, focus_border, 4))
	button.add_theme_stylebox_override("disabled", _make_cta_style(base_bg.darkened(0.35), base_border.darkened(0.4), 2))


func _setup_primary_buttons() -> void:
	var story_button: Button = $CenterContainer/VBoxContainer/Tutorial
	var challenge_button: Button = $CenterContainer/VBoxContainer/ChallengeButton
	_style_cta_button(story_button, Color(0.15, 0.48, 0.24, 0.95), Color(0.72, 0.95, 0.77, 1.0))
	_style_cta_button(challenge_button, Color(0.78, 0.34, 0.10, 0.95), Color(1.0, 0.80, 0.52, 1.0))


func _setup_version_label() -> void:
	var version_label: Label = $VersionLabel
	if not is_instance_valid(version_label):
		return
	var version_text = str(ProjectSettings.get_setting("application/config/version", "1.1.7"))
	if not version_text.begins_with("v"):
		version_text = "v" + version_text
	version_label.text = version_text
	version_label.add_theme_color_override("font_color", Color(0.08, 0.16, 0.1, 0.86))
	version_label.add_theme_color_override("font_outline_color", Color(1.0, 0.98, 0.84, 0.7))
	version_label.add_theme_constant_override("outline_size", 2)


func _style_title_score_label(label: Label, font_size: int) -> void:
	if not is_instance_valid(label):
		return
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.34, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.025, 0.08, 0.035, 0.98))
	label.add_theme_color_override("font_shadow_color", Color(0.03, 0.02, 0.01, 0.45))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)


func _ensure_title_score_widgets() -> void:
	if not is_instance_valid(_last_score_panel):
		_last_score_panel = Panel.new()
		_last_score_panel.name = "LastScorePanel"
		_last_score_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_last_score_panel.z_as_relative = false
		_last_score_panel.z_index = 34
		add_child(_last_score_panel)
	if not is_instance_valid(_last_score_label):
		_last_score_label = Label.new()
		_last_score_label.name = "LastScoreLabel"
		_last_score_label.z_as_relative = false
		_last_score_label.z_index = 35
		add_child(_last_score_label)
	if not is_instance_valid(_high_score_panel):
		_high_score_panel = Panel.new()
		_high_score_panel.name = "TitleHighScorePanel"
		_high_score_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_high_score_panel.z_as_relative = false
		_high_score_panel.z_index = 34
		add_child(_high_score_panel)
	if not is_instance_valid(_high_score_label):
		_high_score_label = Label.new()
		_high_score_label.name = "TitleHighScoreLabel"
		_high_score_label.z_as_relative = false
		_high_score_label.z_index = 35
		add_child(_high_score_label)
	if not is_instance_valid(_title_score_star_layer):
		_title_score_star_layer = Control.new()
		_title_score_star_layer.name = "TitleScoreStars"
		_title_score_star_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_title_score_star_layer.z_as_relative = false
		_title_score_star_layer.z_index = 38
		add_child(_title_score_star_layer)
	while _title_score_stars.size() < TITLE_SCORE_STAR_COUNT:
		var star := Label.new()
		star.name = str("ScoreStar", _title_score_stars.size())
		star.text = "*"
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		star.custom_minimum_size = Vector2(24, 24)
		star.size = Vector2(24, 24)
		star.add_theme_font_size_override("font_size", 24)
		star.add_theme_color_override("font_color", Color(1.0, 0.92, 0.20, 1.0))
		star.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.0, 1.0))
		star.add_theme_constant_override("outline_size", 3)
		_title_score_star_layer.add_child(star)
		_title_score_stars.append(star)


func _get_last_rank_text() -> String:
	var rank_key = int(Global.last_rank_key)
	if not Global.ranks.has(rank_key):
		rank_key = Global.get_rank_threshold(Global.last_score)
	return str(Global.ranks.get(rank_key, "Sporeling"))


func _layout_title_score_panel(panel: Panel, label: Label, visible: bool) -> void:
	if not is_instance_valid(panel):
		return
	panel.visible = visible and is_instance_valid(label)
	if not panel.visible:
		return
	panel.add_theme_stylebox_override("panel", _make_title_score_panel_style())
	var label_rect = Rect2(label.position, label.size)
	panel.position = Vector2(label_rect.position.x - 10.0, label_rect.position.y - 6.0)
	panel.size = Vector2(label_rect.size.x + 20.0, label_rect.size.y + 12.0)


func _get_title_menu_column_rect(view_size: Vector2, fallback_width: float) -> Rect2:
	var column_center_x: float = view_size.x * 0.5
	var center_container := get_node_or_null("CenterContainer") as Control
	if is_instance_valid(center_container):
		var center_rect: Rect2 = center_container.get_global_rect()
		if center_rect.size.x > 1.0:
			column_center_x = center_rect.get_center().x
	for button_path in ["CenterContainer/VBoxContainer/Tutorial", "CenterContainer/VBoxContainer/ChallengeButton"]:
		var button := get_node_or_null(button_path) as Button
		if not is_instance_valid(button) or not button.visible:
			continue
		var button_rect: Rect2 = button.get_global_rect()
		if button_rect.size.x > 1.0:
			return Rect2(Vector2(round(column_center_x - button_rect.size.x * 0.5), button_rect.position.y), button_rect.size)
	var menu_box := get_node_or_null("CenterContainer/VBoxContainer") as Control
	if is_instance_valid(menu_box):
		var menu_rect: Rect2 = menu_box.get_global_rect()
		if menu_rect.size.x > 1.0:
			return Rect2(Vector2(round(column_center_x - menu_rect.size.x * 0.5), menu_rect.position.y), menu_rect.size)
	return Rect2(Vector2(round(column_center_x - fallback_width * 0.5), 0.0), Vector2(fallback_width, 0.0))


func _update_title_score_widgets(view_size: Vector2, compact: bool, tiny: bool) -> void:
	_ensure_title_score_widgets()
	var has_last_score = int(Global.last_score) > 0
	var has_high_score = int(Global.high_score) > 0
	var show_scores = has_last_score or has_high_score
	var fallback_panel_width: float = clampf(view_size.x - 64.0, 220.0, 720.0)
	var menu_rect: Rect2 = _get_title_menu_column_rect(view_size, fallback_panel_width)
	var score_center_x: float = menu_rect.get_center().x
	var max_panel_width: float = maxf(220.0, view_size.x - 64.0)
	var panel_width: float = clampf(menu_rect.size.x, 220.0, max_panel_width)
	var label_width: float = maxf(200.0, panel_width - 20.0)
	var last_size := Vector2(label_width, 66.0 if tiny else (72.0 if compact else 78.0))
	var high_size := Vector2(label_width, 42.0 if tiny else (48.0 if compact else 54.0))
	_style_title_score_label(_last_score_label, 22 if tiny else (24 if compact else 27))
	_style_title_score_label(_high_score_label, 22 if tiny else (24 if compact else 27))
	if is_instance_valid(_last_score_label):
		_last_score_label.visible = has_last_score
		_last_score_label.custom_minimum_size = last_size
		_last_score_label.size = last_size
		_last_score_label.text = str("Last Score: ", Global.format_score_value(Global.last_score), "\nLast Rank: ", _get_last_rank_text())
	if is_instance_valid(_high_score_label):
		_high_score_label.visible = has_high_score
		_high_score_label.custom_minimum_size = high_size
		_high_score_label.size = high_size
		_high_score_label.text = str("High Score: ", Global.format_score_value(Global.high_score))
	var basket_center: Vector2 = _get_title_basket_score_anchor(view_size, compact)
	if is_instance_valid(_last_score_label):
		var last_y = basket_center.y - (98.0 if tiny else (108.0 if compact else 122.0))
		var link: LinkButton = $CenterContainer/VBoxContainer/LinkButton
		if is_instance_valid(link):
			var link_rect = link.get_global_rect()
			last_y = maxf(last_y, link_rect.position.y + link_rect.size.y + 8.0)
		_last_score_label.position = Vector2(round(score_center_x - last_size.x * 0.5), round(last_y))
	if is_instance_valid(_high_score_label):
		var high_y = basket_center.y + (34.0 if tiny else (40.0 if compact else 48.0))
		_high_score_label.position = Vector2(round(score_center_x - high_size.x * 0.5), round(high_y))
	_layout_title_score_panel(_last_score_panel, _last_score_label, has_last_score)
	_layout_title_score_panel(_high_score_panel, _high_score_label, has_high_score)
	_title_score_sparkle_target = null
	if show_scores and has_last_score and int(Global.last_score) == int(Global.high_score):
		_title_score_sparkle_target = _last_score_label
	elif show_scores and has_high_score:
		_title_score_sparkle_target = _high_score_label
	_update_title_score_sparkles(0.0)


func _update_title_score_sparkles(delta: float) -> void:
	_title_score_sparkle_time += maxf(delta, 0.0)
	var show_stars = is_instance_valid(_title_score_sparkle_target) and _title_score_sparkle_target.visible
	if is_instance_valid(_title_score_star_layer):
		_title_score_star_layer.visible = show_stars
	if not show_stars:
		for star in _title_score_stars:
			if is_instance_valid(star):
				star.visible = false
		return
	var target_rect = _title_score_sparkle_target.get_global_rect()
	var center = target_rect.get_center()
	var radius_x = target_rect.size.x * 0.52 + 14.0
	var radius_y = target_rect.size.y * 0.50 + 10.0
	for idx in range(_title_score_stars.size()):
		var star = _title_score_stars[idx]
		if not is_instance_valid(star):
			continue
		var phase = (idx * TAU) / max(TITLE_SCORE_STAR_COUNT, 1)
		var shimmer = 0.5 + 0.5 * sin(_title_score_sparkle_time * 4.2 + idx * 0.91)
		var orbit = phase + sin(_title_score_sparkle_time * 0.9 + idx) * 0.08
		star.visible = true
		star.modulate.a = 0.38 + shimmer * 0.62
		star.scale = Vector2.ONE * (0.82 + shimmer * 0.36)
		star.position = center + Vector2(cos(orbit) * radius_x, sin(orbit) * radius_y) - star.size * 0.5


func _make_title_bird_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	if not frames.has_animation(&"default"):
		frames.add_animation(&"default")
	frames.set_animation_loop(&"default", true)
	frames.set_animation_speed(&"default", 5.0)
	for path in TITLE_BIRD_FRAME_PATHS:
		var texture: Resource = load(str(path))
		if texture is Texture2D:
			frames.add_frame(&"default", texture as Texture2D)
	return frames


func _ensure_title_loop_player(player_name: String, asset_path: String, silent_volume_db: float) -> AudioStreamPlayer:
	var existing := get_node_or_null(player_name) as AudioStreamPlayer
	if is_instance_valid(existing):
		return existing
	var stream: AudioStream = LevelHelpersRef.load_looping_audio_stream(asset_path)
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	player.volume_db = silent_volume_db
	add_child(player)
	return player


func _ensure_title_predator_bird_sound_player() -> AudioStreamPlayer:
	if is_instance_valid(_title_predator_bird_sound_player):
		return _title_predator_bird_sound_player
	_title_predator_bird_sound_player = _ensure_title_loop_player("TitlePredatorBirdLoop", TITLE_PREDATOR_BIRD_SOUND_PATH, TITLE_PREDATOR_BIRD_SILENT_VOLUME_DB)
	return _title_predator_bird_sound_player


func _ensure_title_tuktuk_engine_sound_player() -> AudioStreamPlayer:
	if is_instance_valid(_title_tuktuk_engine_sound_player):
		return _title_tuktuk_engine_sound_player
	_title_tuktuk_engine_sound_player = _ensure_title_loop_player("TitleTuktukEngineLoop", TITLE_TUKTUK_ENGINE_SOUND_PATH, TITLE_TUKTUK_ENGINE_SILENT_VOLUME_DB)
	return _title_tuktuk_engine_sound_player


func _ensure_title_basket_land_sound_player() -> AudioStreamPlayer:
	if is_instance_valid(_title_basket_land_sound_player):
		return _title_basket_land_sound_player
	var stream: AudioStream = load(TITLE_BASKET_LAND_SOUND_PATH) as AudioStream
	if stream == null:
		return null
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = "TitleBasketLandSound"
	player.stream = stream
	player.volume_db = TITLE_BASKET_LAND_VOLUME_DB
	add_child(player)
	_title_basket_land_sound_player = player
	return _title_basket_land_sound_player


func _play_title_basket_land_sound() -> void:
	var player: AudioStreamPlayer = _ensure_title_basket_land_sound_player()
	if not is_instance_valid(player):
		return
	player.volume_db = TITLE_BASKET_LAND_VOLUME_DB
	player.stop()
	player.play()


func _get_title_flyby_target_volume(pos: Vector2, active_db: float, distant_db: float) -> float:
	var view_size: Vector2 = get_viewport_rect().size
	var listener_pos := view_size * 0.5
	var audible_radius: float = maxf(maxf(view_size.x, view_size.y) * 0.58, TITLE_FLYBY_FOCUS_RADIUS + 1.0)
	var fade_range: float = maxf(audible_radius - TITLE_FLYBY_FOCUS_RADIUS, 1.0)
	var dist: float = listener_pos.distance_to(pos)
	var closeness: float = clampf(1.0 - ((dist - TITLE_FLYBY_FOCUS_RADIUS) / fade_range), 0.0, 1.0)
	var shaped: float = closeness * closeness * (3.0 - 2.0 * closeness)
	return lerpf(distant_db, active_db, shaped)


func _move_title_loop_volume(player: AudioStreamPlayer, target_db: float, silent_db: float, delta: float) -> void:
	if not is_instance_valid(player):
		return
	if not player.playing and target_db > silent_db + 0.1:
		player.volume_db = silent_db
		player.play()
	var fade_rate := TITLE_FLYBY_APPROACH_FADE_DB_PER_SEC
	if target_db < player.volume_db:
		fade_rate = TITLE_FLYBY_DEPART_FADE_DB_PER_SEC
	player.volume_db = move_toward(player.volume_db, target_db, fade_rate * maxf(delta, 0.0))
	if player.playing and target_db <= silent_db + 0.1 and player.volume_db <= silent_db + 0.1:
		player.stop()


func _update_title_flyby_audio(delta: float) -> void:
	var bird_target_db := TITLE_PREDATOR_BIRD_SILENT_VOLUME_DB
	if is_instance_valid(_title_bird_sprite) and _title_bird_sprite.visible and str(_title_flyby_phase).begins_with("bird"):
		bird_target_db = _get_title_flyby_target_volume(_title_bird_sprite.global_position, TITLE_PREDATOR_BIRD_ACTIVE_VOLUME_DB, TITLE_PREDATOR_BIRD_DISTANT_VOLUME_DB)
	if bird_target_db > TITLE_PREDATOR_BIRD_SILENT_VOLUME_DB + 0.1 or is_instance_valid(_title_predator_bird_sound_player):
		_move_title_loop_volume(_ensure_title_predator_bird_sound_player(), bird_target_db, TITLE_PREDATOR_BIRD_SILENT_VOLUME_DB, delta)
	var tuktuk_target_db := TITLE_TUKTUK_ENGINE_SILENT_VOLUME_DB
	if is_instance_valid(_title_tuktuk_node) and _title_tuktuk_node.visible and str(_title_flyby_phase).begins_with("tuktuk"):
		tuktuk_target_db = _get_title_flyby_target_volume(_title_tuktuk_node.global_position, TITLE_TUKTUK_ENGINE_ACTIVE_VOLUME_DB, TITLE_TUKTUK_ENGINE_DISTANT_VOLUME_DB)
	if tuktuk_target_db > TITLE_TUKTUK_ENGINE_SILENT_VOLUME_DB + 0.1 or is_instance_valid(_title_tuktuk_engine_sound_player):
		_move_title_loop_volume(_ensure_title_tuktuk_engine_sound_player(), tuktuk_target_db, TITLE_TUKTUK_ENGINE_SILENT_VOLUME_DB, delta)


func _ensure_title_flyby_nodes() -> void:
	if not is_instance_valid(_title_flyby_layer):
		_title_flyby_layer = Node2D.new()
		_title_flyby_layer.name = "TitleFlybys"
		_title_flyby_layer.z_as_relative = false
		_title_flyby_layer.z_index = 44
		add_child(_title_flyby_layer)
	if not is_instance_valid(_title_bird_sprite):
		_title_bird_sprite = AnimatedSprite2D.new()
		_title_bird_sprite.name = "TitleBird"
		_title_bird_sprite.sprite_frames = _make_title_bird_frames()
		_title_bird_sprite.animation = &"default"
		_title_bird_sprite.scale = Vector2(1.25, 1.25)
		_title_bird_sprite.visible = false
		_title_flyby_layer.add_child(_title_bird_sprite)
		_title_bird_basket_sprite = Sprite2D.new()
		_title_bird_basket_sprite.name = "BeakBasket"
		var bird_basket_texture: Resource = load(TITLE_BASKET_TEXTURE_PATH)
		if bird_basket_texture is Texture2D:
			_title_bird_basket_sprite.texture = bird_basket_texture as Texture2D
		_title_bird_basket_sprite.position = Vector2(34.0, 4.0)
		_title_bird_basket_sprite.scale = Vector2(0.44, 0.44)
		_title_bird_basket_sprite.z_index = 1
		_title_bird_basket_sprite.visible = false
		_title_bird_sprite.add_child(_title_bird_basket_sprite)
	if not is_instance_valid(_title_tuktuk_node):
		_title_tuktuk_node = Node2D.new()
		_title_tuktuk_node.name = "TitleTuktuk"
		_title_tuktuk_node.scale = Vector2(1.18, 1.18)
		_title_tuktuk_node.visible = false
		_title_flyby_layer.add_child(_title_tuktuk_node)
		var tuktuk_sprite := Sprite2D.new()
		tuktuk_sprite.name = "Sprite2D"
		var tuktuk_texture: Resource = load(TITLE_TUKTUK_TEXTURE_PATH)
		if tuktuk_texture is Texture2D:
			tuktuk_sprite.texture = tuktuk_texture as Texture2D
		_title_tuktuk_node.add_child(tuktuk_sprite)
		_title_tuktuk_basket_sprite = Sprite2D.new()
		_title_tuktuk_basket_sprite.name = "CarriedBasket"
		var basket_texture: Resource = load(TITLE_BASKET_TEXTURE_PATH)
		if basket_texture is Texture2D:
			_title_tuktuk_basket_sprite.texture = basket_texture as Texture2D
		_title_tuktuk_basket_sprite.position = Vector2(-28.0, -8.0)
		_title_tuktuk_basket_sprite.scale = Vector2(0.72, 0.72)
		_title_tuktuk_basket_sprite.visible = false
		_title_tuktuk_node.add_child(_title_tuktuk_basket_sprite)


func _get_title_bird_flyby_y(view_size: Vector2) -> float:
	var title_label: Label = $CenterContainer/VBoxContainer/RegenerationLabel
	if is_instance_valid(title_label):
		var title_rect = title_label.get_global_rect()
		return maxf(32.0, title_rect.position.y - 30.0)
	return view_size.y * 0.16


func _get_title_basket_sprite() -> Sprite2D:
	return get_node_or_null("CenterContainer/Basket") as Sprite2D


func _get_title_basket_local_rest_position(compact: bool) -> Vector2:
	var center_container: Control = $CenterContainer
	var center_x = center_container.size.x * 0.5 if is_instance_valid(center_container) else 283.5
	return Vector2(center_x, 520.0 if compact else 534.5)


func _get_title_basket_score_anchor(view_size: Vector2, compact: bool) -> Vector2:
	var center_container: Control = $CenterContainer
	if is_instance_valid(center_container):
		var local_rest = _get_title_basket_local_rest_position(compact)
		return center_container.global_position + local_rest
	return Vector2(view_size.x * 0.5, view_size.y * 0.72)


func _get_title_basket_center(view_size: Vector2) -> Vector2:
	var compact = Global.is_mobile_platform or minf(view_size.x, view_size.y) <= TITLE_COMPACT_SHORT_EDGE
	return _get_title_basket_score_anchor(view_size, compact)


func _title_phase_t(duration: float) -> float:
	if duration <= 0.0:
		return 1.0
	return clampf(_title_flyby_elapsed / duration, 0.0, 1.0)


func _title_ease_sine(t: float) -> float:
	return 0.5 - 0.5 * cos(clampf(t, 0.0, 1.0) * PI)


func _title_basket_drop_position(t: float) -> Vector2:
	var drop_t = clampf(t, 0.0, 1.0)
	var drop_x = _title_basket_rest_pos.x
	var start_y = _title_basket_drop_start_pos.y
	var rest_y = _title_basket_rest_pos.y
	var fall_end := TITLE_BASKET_DROP_LAND_T
	var first_bounce_end := 0.88
	var bounce_height = clampf((rest_y - start_y) * 0.12, 12.0, 34.0)
	if drop_t < fall_end:
		var fall_t = drop_t / fall_end
		return Vector2(drop_x, lerpf(start_y, rest_y, fall_t * fall_t))
	if drop_t < first_bounce_end:
		var bounce_t = (drop_t - fall_end) / (first_bounce_end - fall_end)
		return Vector2(drop_x, rest_y - sin(bounce_t * PI) * bounce_height)
	var settle_t = (drop_t - first_bounce_end) / (1.0 - first_bounce_end)
	return Vector2(drop_x, rest_y - sin(settle_t * PI) * bounce_height * 0.32)


func _begin_title_bird_flyby() -> void:
	_ensure_title_flyby_nodes()
	var view_size = get_viewport_rect().size
	var y = _get_title_bird_flyby_y(view_size)
	_title_basket_rest_pos = _get_title_basket_center(view_size)
	_title_bird_start_pos = Vector2(-98.0, y)
	_title_bird_drop_pos = Vector2(_title_basket_rest_pos.x - 42.0, y - 4.0)
	_title_bird_exit_pos = Vector2(view_size.x + 98.0, y - 12.0)
	var basket = _get_title_basket_sprite()
	if is_instance_valid(basket):
		basket.global_position = _title_basket_rest_pos
		basket.visible = false
	if not is_instance_valid(_title_bird_sprite):
		return
	_title_bird_sprite.position = _title_bird_start_pos
	_title_bird_sprite.visible = true
	_title_bird_sprite.play(&"default")
	var bird_player := _ensure_title_predator_bird_sound_player()
	if is_instance_valid(bird_player):
		bird_player.volume_db = TITLE_PREDATOR_BIRD_SILENT_VOLUME_DB
		bird_player.play()
	if is_instance_valid(_title_bird_basket_sprite):
		_title_bird_basket_sprite.visible = true
	if is_instance_valid(_title_tuktuk_node):
		_title_tuktuk_node.visible = false
	if is_instance_valid(_title_tuktuk_basket_sprite):
		_title_tuktuk_basket_sprite.visible = false
	_title_flyby_phase = "bird_in"
	_title_flyby_elapsed = 0.0


func _drop_title_basket_from_bird() -> void:
	_title_basket_land_sound_played = false
	_title_basket_drop_start_pos = Vector2(_title_basket_rest_pos.x, _title_bird_drop_pos.y + 5.0)
	if is_instance_valid(_title_bird_basket_sprite):
		_title_basket_drop_start_pos.y = _title_bird_basket_sprite.global_position.y
		_title_bird_basket_sprite.visible = false
	var basket = _get_title_basket_sprite()
	if is_instance_valid(basket):
		basket.global_position = _title_basket_drop_start_pos
		basket.visible = true
	_title_flyby_phase = "bird_out_drop"
	_title_flyby_elapsed = 0.0


func _begin_title_tuktuk_flyby() -> void:
	_ensure_title_flyby_nodes()
	var view_size = get_viewport_rect().size
	if _title_basket_rest_pos == Vector2.ZERO:
		_title_basket_rest_pos = _get_title_basket_center(view_size)
	_title_tuktuk_start_pos = Vector2(-96.0, _title_basket_rest_pos.y)
	_title_tuktuk_pickup_pos = Vector2(_title_basket_rest_pos.x - 24.0, _title_basket_rest_pos.y)
	_title_tuktuk_exit_pos = Vector2(view_size.x + 112.0, _title_basket_rest_pos.y)
	var total_distance = maxf(_title_tuktuk_exit_pos.x - _title_tuktuk_start_pos.x, 1.0)
	_title_tuktuk_pickup_seconds = clampf(((_title_tuktuk_pickup_pos.x - _title_tuktuk_start_pos.x) / total_distance) * TITLE_TUKTUK_FLYBY_SECONDS, 0.55, TITLE_TUKTUK_FLYBY_SECONDS * 0.72)
	_title_tuktuk_exit_seconds = maxf(TITLE_TUKTUK_FLYBY_SECONDS - _title_tuktuk_pickup_seconds, 0.75)
	if is_instance_valid(_title_tuktuk_node):
		_title_tuktuk_node.position = _title_tuktuk_start_pos
		_title_tuktuk_node.visible = true
	var tuktuk_player := _ensure_title_tuktuk_engine_sound_player()
	if is_instance_valid(tuktuk_player):
		tuktuk_player.volume_db = TITLE_TUKTUK_ENGINE_SILENT_VOLUME_DB
		tuktuk_player.play()
	if is_instance_valid(_title_tuktuk_basket_sprite):
		_title_tuktuk_basket_sprite.visible = false
	var basket = _get_title_basket_sprite()
	if is_instance_valid(basket):
		basket.global_position = _title_basket_rest_pos
		basket.visible = true
	_title_flyby_phase = "tuktuk_pickup"
	_title_flyby_elapsed = 0.0


func _title_tuktuk_pickup_basket() -> void:
	var basket = _get_title_basket_sprite()
	if is_instance_valid(basket):
		basket.visible = false
	if is_instance_valid(_title_tuktuk_basket_sprite):
		_title_tuktuk_basket_sprite.visible = true
	_title_flyby_phase = "tuktuk_exit"
	_title_flyby_elapsed = 0.0


func _finish_title_tuktuk_flyby() -> void:
	if is_instance_valid(_title_tuktuk_node):
		_title_tuktuk_node.visible = false
	if is_instance_valid(_title_tuktuk_basket_sprite):
		_title_tuktuk_basket_sprite.visible = false
	_title_flyby_phase = "wait_after_tuktuk"
	_title_flyby_elapsed = 0.0


func _update_title_flyby(delta: float) -> void:
	if not _title_flyby_running:
		return
	_title_flyby_elapsed += maxf(delta, 0.0)
	match _title_flyby_phase:
		"bird_in":
			var bird_in_seconds = TITLE_BIRD_FLYBY_SECONDS * 0.48
			var t = _title_ease_sine(_title_phase_t(bird_in_seconds))
			if is_instance_valid(_title_bird_sprite):
				_title_bird_sprite.position = _title_bird_start_pos.lerp(_title_bird_drop_pos, t)
			if _title_flyby_elapsed >= bird_in_seconds:
				_drop_title_basket_from_bird()
		"bird_out_drop":
			var bird_out_seconds = TITLE_BIRD_FLYBY_SECONDS * 0.52
			var t_bird = _title_ease_sine(_title_phase_t(bird_out_seconds))
			if is_instance_valid(_title_bird_sprite):
				_title_bird_sprite.position = _title_bird_drop_pos.lerp(_title_bird_exit_pos, t_bird)
				if _title_flyby_elapsed >= bird_out_seconds:
					_title_bird_sprite.visible = false
			var basket = _get_title_basket_sprite()
			var t_drop = _title_phase_t(TITLE_BASKET_DROP_SECONDS)
			if is_instance_valid(basket):
				basket.global_position = _title_basket_drop_position(t_drop)
			if not _title_basket_land_sound_played and t_drop >= TITLE_BASKET_DROP_LAND_T:
				_title_basket_land_sound_played = true
				_play_title_basket_land_sound()
			if _title_flyby_elapsed >= maxf(bird_out_seconds, TITLE_BASKET_DROP_SECONDS):
				if is_instance_valid(basket):
					basket.global_position = _title_basket_rest_pos
					basket.visible = true
				_title_flyby_phase = "wait_after_drop"
				_title_flyby_elapsed = 0.0
		"wait_after_drop":
			if _title_flyby_elapsed >= TITLE_FLYBY_WAIT_SECONDS:
				_begin_title_tuktuk_flyby()
		"tuktuk_pickup":
			var t_pickup = _title_ease_sine(_title_phase_t(_title_tuktuk_pickup_seconds))
			if is_instance_valid(_title_tuktuk_node):
				_title_tuktuk_node.position = _title_tuktuk_start_pos.lerp(_title_tuktuk_pickup_pos, t_pickup)
			if _title_flyby_elapsed >= _title_tuktuk_pickup_seconds:
				_title_tuktuk_pickup_basket()
		"tuktuk_exit":
			var t_exit = _title_ease_sine(_title_phase_t(_title_tuktuk_exit_seconds))
			if is_instance_valid(_title_tuktuk_node):
				_title_tuktuk_node.position = _title_tuktuk_pickup_pos.lerp(_title_tuktuk_exit_pos, t_exit)
			if _title_flyby_elapsed >= _title_tuktuk_exit_seconds:
				_finish_title_tuktuk_flyby()
		"wait_after_tuktuk":
			if _title_flyby_elapsed >= TITLE_FLYBY_WAIT_SECONDS:
				_begin_title_bird_flyby()
		_:
			_begin_title_bird_flyby()


func _reset_title_flyby_visuals() -> void:
	_title_basket_land_sound_played = false
	if is_instance_valid(_title_bird_sprite):
		_title_bird_sprite.visible = false
	if is_instance_valid(_title_bird_basket_sprite):
		_title_bird_basket_sprite.visible = false
	if is_instance_valid(_title_tuktuk_node):
		_title_tuktuk_node.visible = false
	if is_instance_valid(_title_tuktuk_basket_sprite):
		_title_tuktuk_basket_sprite.visible = false
	if is_instance_valid(_title_predator_bird_sound_player):
		_title_predator_bird_sound_player.stop()
		_title_predator_bird_sound_player.volume_db = TITLE_PREDATOR_BIRD_SILENT_VOLUME_DB
	if is_instance_valid(_title_tuktuk_engine_sound_player):
		_title_tuktuk_engine_sound_player.stop()
		_title_tuktuk_engine_sound_player.volume_db = TITLE_TUKTUK_ENGINE_SILENT_VOLUME_DB
	if is_instance_valid(_title_basket_land_sound_player):
		_title_basket_land_sound_player.stop()


func _release_title_audio() -> void:
	LevelHelpersRef.stop_audio_players([
		_title_predator_bird_sound_player,
		_title_tuktuk_engine_sound_player,
		_title_basket_land_sound_player
	], true)
	_title_predator_bird_sound_player = null
	_title_tuktuk_engine_sound_player = null
	_title_basket_land_sound_player = null


func _start_title_flyby_cycle() -> void:
	if _title_flyby_running:
		return
	_title_flyby_running = true
	_begin_title_bird_flyby()


func _connect_viewport_resize_signal() -> void:
	var viewport = get_viewport()
	if not is_instance_valid(viewport):
		return
	if viewport.size_changed.is_connected(_on_viewport_size_changed):
		return
	viewport.size_changed.connect(_on_viewport_size_changed)


func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()
	_request_title_layout_refresh(3)


func _request_title_layout_refresh(frames: int = 3) -> void:
	_title_pending_layout_frames = maxi(_title_pending_layout_frames, frames)
	call_deferred("_apply_responsive_layout")


func _load_title_texture(path: String) -> Texture2D:
	var texture: Resource = load(path)
	if texture is Texture2D:
		return texture as Texture2D
	return null


func _configure_title_background_rect(rect: TextureRect, z_index: int, texture_path: String) -> void:
	if not is_instance_valid(rect):
		return
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_as_relative = false
	rect.z_index = z_index
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.offset_left = 0.0
	rect.offset_top = 0.0
	rect.offset_right = 0.0
	rect.offset_bottom = 0.0
	var texture = _load_title_texture(texture_path)
	if is_instance_valid(texture):
		rect.texture = texture


func _ensure_responsive_background_nodes() -> void:
	if not is_instance_valid(_title_soil_background):
		_title_soil_background = TextureRect.new()
		_title_soil_background.name = "ResponsiveSoilBackground"
		add_child(_title_soil_background)
		_configure_title_background_rect(_title_soil_background, -120, TITLE_SOIL_BACKGROUND_PATH)
	if not is_instance_valid(_title_art_background):
		_title_art_background = TextureRect.new()
		_title_art_background.name = "ResponsiveTitleArt"
		add_child(_title_art_background)
		_configure_title_background_rect(_title_art_background, -110, TITLE_ART_BACKGROUND_PATH)
	move_child(_title_soil_background, 0)
	move_child(_title_art_background, 1)
	_hide_legacy_background_nodes()


func _hide_legacy_background_nodes() -> void:
	for path in ["CenterContainer/BG", "CenterContainer/BG2"]:
		var bg := get_node_or_null(path) as Sprite2D
		if is_instance_valid(bg):
			bg.visible = false


func _layout_responsive_background(view_size: Vector2) -> void:
	_ensure_responsive_background_nodes()
	if is_instance_valid(_title_soil_background):
		_title_soil_background.set_anchors_preset(Control.PRESET_FULL_RECT)
		_title_soil_background.offset_left = 0.0
		_title_soil_background.offset_top = 0.0
		_title_soil_background.offset_right = 0.0
		_title_soil_background.offset_bottom = 0.0
		_title_soil_background.visible = true
		_title_soil_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_title_soil_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if is_instance_valid(_title_art_background):
		var art_size = maxf(view_size.y, 1.0)
		_title_art_background.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_title_art_background.position = Vector2(round((view_size.x - art_size) * 0.5), 0.0)
		_title_art_background.size = Vector2(art_size, art_size)
		_title_art_background.visible = true
		_title_art_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_title_art_background.stretch_mode = TextureRect.STRETCH_SCALE


func _apply_responsive_layout() -> void:
	var view_size = get_viewport_rect().size
	_layout_responsive_background(view_size)
	var short_edge = minf(view_size.x, view_size.y)
	var compact = Global.is_mobile_platform or short_edge <= TITLE_COMPACT_SHORT_EDGE
	var tiny = short_edge <= TITLE_TINY_SHORT_EDGE
	var title_font_size := 56
	if compact:
		title_font_size = 42
	if tiny:
		title_font_size = 34
	var title: Label = $TopLabel
	if is_instance_valid(title):
		title.visible = false
		title.add_theme_font_size_override("font_size", title_font_size)
		var fallback_top = 22.0 if compact else 68.0
		var fallback_bottom = 156.0 if compact else 228.0
		title.offset_top = fallback_top
		title.offset_bottom = fallback_bottom
	var menu_box: VBoxContainer = $CenterContainer/VBoxContainer
	if is_instance_valid(menu_box):
		menu_box.custom_minimum_size = Vector2(minf(view_size.x - 48.0, 420.0), 0.0)
		menu_box.add_theme_constant_override("separation", 7 if compact else 9)
	var cta_width = clampf(view_size.x - 72.0, 220.0, 340.0)
	var cta_height = 62.0 if compact else 70.0
	var cta_font_size = 34 if compact else 42
	if tiny:
		cta_height = 56.0
		cta_font_size = 29
	for button in [$CenterContainer/VBoxContainer/Tutorial, $CenterContainer/VBoxContainer/ChallengeButton]:
		if not is_instance_valid(button):
			continue
		button.custom_minimum_size = Vector2(cta_width, cta_height)
		button.add_theme_font_size_override("font_size", cta_font_size)
	var link: LinkButton = $CenterContainer/VBoxContainer/LinkButton
	if is_instance_valid(link):
		var ge_panel = link.get_node_or_null("GEPanel") as Panel
		var ge_logo = link.get_node_or_null("GELogo") as TextureRect
		var ge_texture = _get_ge_logo_texture()
		var logo_aspect := 4.63
		if is_instance_valid(ge_texture) and ge_texture.get_height() > 0:
			logo_aspect = (ge_texture.get_width() * 1.0) / (ge_texture.get_height() * 1.0)
		var pad_x := 10.0 if tiny else 12.0
		var pad_y := 6.0 if tiny else 8.0
		var logo_width = clampf((view_size.x - 72.0) * 0.5, 140.0, 230.0)
		var logo_height = logo_width / logo_aspect
		link.tooltip_text = "Grassroots Economics"
		link.custom_minimum_size = Vector2(logo_width + pad_x * 2.0, logo_height + pad_y * 2.0)
		link.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if is_instance_valid(ge_panel):
			ge_panel.visible = true
			ge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ge_panel.add_theme_stylebox_override("panel", _make_ge_logo_panel_style())
		if is_instance_valid(ge_logo) and is_instance_valid(ge_texture):
			link.text = ""
			ge_logo.visible = true
			ge_logo.texture = ge_texture
			ge_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ge_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			ge_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ge_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ge_logo.offset_left = pad_x
			ge_logo.offset_top = pad_y
			ge_logo.offset_right = -pad_x
			ge_logo.offset_bottom = -pad_y
		else:
			link.text = "Grassroots Economics"
			link.add_theme_color_override("font_color", Color(0.08, 0.16, 0.1, 1.0))
			link.add_theme_color_override("font_outline_color", Color(1.0, 0.98, 0.84, 0.78))
			link.add_theme_constant_override("outline_size", 2)
			link.add_theme_font_size_override("font_size", 24 if compact else 30)
	var regen_label: Label = $CenterContainer/VBoxContainer/RegenerationLabel
	if is_instance_valid(regen_label):
		var regen_font_size = title_font_size + (24 if tiny else (30 if compact else 36)) - 4
		var title_width = clampf(view_size.x - 48.0, 340.0, 720.0)
		var title_height_box = 88.0 if tiny else (98.0 if compact else 112.0)
		regen_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		regen_label.custom_minimum_size = Vector2(title_width, title_height_box)
		regen_label.text = "Social Soil"
		regen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		regen_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		regen_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.24, 1.0))
		regen_label.add_theme_color_override("font_outline_color", Color(0.035, 0.18, 0.075, 1.0))
		regen_label.add_theme_color_override("font_shadow_color", Color(0.23, 0.09, 0.02, 0.68))
		regen_label.add_theme_constant_override("outline_size", 6 if compact else 8)
		regen_label.add_theme_constant_override("shadow_offset_x", 3 if compact else 4)
		regen_label.add_theme_constant_override("shadow_offset_y", 5 if compact else 7)
		regen_label.add_theme_font_size_override("font_size", regen_font_size)
	var shroom: Sprite2D = get_node_or_null("CenterContainer/shroom") as Sprite2D
	var farmer: Sprite2D = get_node_or_null("CenterContainer/farmer") as Sprite2D
	var small_shroom: Sprite2D = get_node_or_null("CenterContainer/SmallShroom") as Sprite2D
	var basket: Sprite2D = get_node_or_null("CenterContainer/Basket") as Sprite2D
	if is_instance_valid(shroom):
		shroom.visible = false
		shroom.scale = Vector2(0.24, 0.24) if compact else Vector2(0.30561, 0.30561)
		if tiny:
			shroom.scale = Vector2(0.20, 0.20)
		shroom.position = Vector2(86.0, -62.0) if compact else Vector2(88.5, -73.4999)
	if is_instance_valid(farmer):
		farmer.visible = false
		farmer.scale = Vector2(1.64, 1.64) if compact else Vector2(2.03894, 2.03894)
		if tiny:
			farmer.scale = Vector2(1.48, 1.48)
		farmer.position = Vector2(454.0, -70.0) if compact else Vector2(449.5, -84.5)
	if is_instance_valid(small_shroom):
		small_shroom.visible = false
		small_shroom.scale = Vector2(0.48, 0.48) if compact else Vector2(0.629555, 0.629555)
		if tiny:
			small_shroom.scale = Vector2(0.42, 0.42)
		small_shroom.position = Vector2(270.0, 522.0) if compact else Vector2(269.5, 541.5)
	if is_instance_valid(basket):
		if not _title_flyby_running:
			basket.position = _get_title_basket_local_rest_position(compact)
			basket.visible = true
	_update_title_score_widgets(view_size, compact, tiny)
	if is_instance_valid(title):
		var title_height = 122.0 if tiny else (134.0 if compact else 160.0)
		var fallback_top = 22.0 if compact else 68.0
		var vertical_bias = 100.0 if compact else 70.0
		if is_instance_valid(shroom) and shroom.visible and is_instance_valid(farmer) and farmer.visible:
			var shroom_y = shroom.global_position.y
			var farmer_y = farmer.global_position.y
			var midpoint_y = (shroom_y + farmer_y) * 0.5
			var parent_control = title.get_parent() as Control
			var parent_global_y = parent_control.global_position.y if is_instance_valid(parent_control) else 0.0
			var local_midpoint_y = midpoint_y - parent_global_y
			title.offset_top = round(local_midpoint_y - title_height * 0.5 + vertical_bias)
		else:
			title.offset_top = fallback_top + vertical_bias
		title.offset_bottom = title.offset_top + title_height
	var version_label: Label = $VersionLabel
	if is_instance_valid(version_label):
		version_label.add_theme_font_size_override("font_size", 13 if compact else 16)
		version_label.custom_minimum_size = Vector2(112.0, 24.0)
		var label_size = version_label.size
		if label_size.x <= 1.0 or label_size.y <= 1.0:
			label_size = version_label.custom_minimum_size
		var bottom_margin = 8.0 if tiny else (10.0 if compact else 14.0)
		version_label.position = Vector2(
			round((view_size.x - label_size.x) * 0.5),
			round(view_size.y - label_size.y - bottom_margin)
		)


func _reset_run_state() -> void:
	Global.values = {
		"N": 1,
		"P": 1,
		"K": 1,
		"R": 1
	}
	Global.active_agent = null
	Global.is_dragging = false
	Global.stage_inc = 0
	Global.bars_on = false
	Global.allow_agent_reposition = false
	Global.social_mode = false
	Global.enable_tuktuk_predators = false
	Global.story_chapter_id = 1
	Global.village_revealed = false
	Global.village_objective_flags = {}
	Global.perf_tier = 0
	Global.perf_tile_occupancy_queries = 0
	Global.perf_last_sample = {}
	if Global.has_method("reset_trade_dispatch_budgets"):
		Global.reset_trade_dispatch_budgets()


func _ready():
	DisplayServer.window_set_title("Social Soil")
	Global.record_last_score()
	Global.score = 0
	_ensure_responsive_background_nodes()
	$CenterContainer/VBoxContainer/HBoxContainer.visible = false
	_setup_primary_buttons()
	_setup_version_label()
	_ensure_title_score_widgets()
	_ensure_title_flyby_nodes()
	_connect_viewport_resize_signal()
	_apply_responsive_layout()
	_request_title_layout_refresh(4)
	call_deferred("_start_title_flyby_cycle")
	Global.social_mode = false


func _process(delta: float) -> void:
	if _title_pending_layout_frames > 0:
		_title_pending_layout_frames -= 1
		_apply_responsive_layout()
	_update_title_score_sparkles(delta)
	_update_title_flyby(delta)
	_update_title_flyby_audio(delta)


func _exit_tree() -> void:
	_title_flyby_running = false
	_reset_title_flyby_visuals()
	_release_title_audio()
	var basket = _get_title_basket_sprite()
	if is_instance_valid(basket):
		basket.visible = true
		

func _on_tutorial_pressed() -> void:
	_reset_run_state()
	Global.mode = "story"
	Global.is_raining = true
	Global.is_birding = true
	Global.is_killing = false
	Global.is_max_babies = true
	Global.enable_tuktuk_predators = false
	Global.draw_lines = true
	Global.bars_on = false
	Global.stage = 1
	Global.inventory = { #how many of each plant do we have to use
	"bean": 3,
	"squash": 3,				
	"maize": 3,
	"tree": 3,
	"myco": 3,
	"farmer": 0,
	"vendor": 0,
	"cook": 0,
	"basket": 0
	}
	get_tree().change_scene_to_file("res://scenes/level.tscn")

func _on_free_garden_pressed() -> void:
	_on_challenge_button_pressed()

func _on_challenge_button_pressed() -> void:
	_reset_run_state()
	Global.mode = "challenge"
	Global.is_raining = true
	Global.is_birding = true
	Global.is_killing = true
	Global.is_max_babies = true
	Global.enable_tuktuk_predators = true
	Global.bars_on = false
	Global.draw_lines = true
	Global.inventory = { #how many of each plant do we have to use
	"bean": 3,
	"squash": 3,				
	"maize": 3,
	"tree": 3,
	"myco": 3,
	"farmer": 0,
	"vendor": 0,
	"cook": 0,
	"basket": 3
	}
	get_tree().change_scene_to_file("res://scenes/level.tscn")


func _on_cofi_button_pressed() -> void:
	_on_challenge_button_pressed()


func _on_check_button_toggled(toggled_on: bool) -> void:
	Global.social_mode = false
		


func _on_check_button_2_toggled(toggled_on: bool) -> void:
	Global.social_mode = false
