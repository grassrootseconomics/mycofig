extends Control

const SOIL_BACKGROUND_PATH := "res://graphics/soil_end.jpeg"
const GE_BOOK_URI := "https://grassrootseconomics.org/book/"
const SHARE_URL := "https://grassecon.org/games/"
const SHARE_URL_DISPLAY := "grassecon.org/games"
const SHARE_CARD_DIR := "user://share"
const SHARE_CARD_PATH := "user://share/social_soil_result.png"
const SHARE_CARD_DEFAULT_FILENAME := "social_soil_result.png"
const SHARE_CARD_SIZE := Vector2i(1080, 1920)
const ANDROID_SHARE_CLASS := "com.godot.game.SocialSoilShare"
const SHARE_CARD_BIRD_PATH := "res://graphics/bird1.png"
const SHARE_CARD_TUKTUK_PATH := "res://graphics/tuktuk.png"
const SHARE_CARD_MUSHROOM_PATH := "res://graphics/mushroom_32.png"
const BIRD_FRAME_PATHS := [
	"res://graphics/bird1.png",
	"res://graphics/bird2.png",
	"res://graphics/bird3.png",
	"res://graphics/bird4.png"
]
const COMPACT_SHORT_EDGE := 640.0
const TINY_SHORT_EDGE := 500.0
const MAX_CONTENT_WIDTH := 660.0
const MIN_CONTENT_WIDTH := 300.0
const PHASE_SKILL_TEXTS := {
	1: "- You reached the starting garden.\n- No tutorial phase was completed yet.\n- The next milestone is planting each starter item from the basket.",
	2: "- You completed the first planting milestone.\n- You placed the starter mix of crops, trees, and fungi.\n- You proved you can begin building a living soil network.",
	3: "- You completed the first harvest milestone.\n- You collected garden resources before losing them all to pressure.\n- You proved the garden can produce more than it consumes.",
	4: "- You completed the first network milestone.\n- You planted crops around each other to help each other. You used fungi to extend sharing toward the village.\n- You proved the garden can connect beyond the starting patch and created more healthy soil.",
	5: "- You completed the first village support milestone.\n- You grew food close enough for farmers to harvest and recover.\n- You proved the garden can support people as well as plants.",
	6: "- You completed all the milestones.\n- You helped villagers exchange through baskets.\n- You restored healthy soil and stronger village connections!"
}
const RANK_SKILL_TEXTS := {
	0: "- You started a garden, but this is still an early run.\n- You created your first resource flows.\n- You built the foundation for a stronger attempt.",
	20000: "- You connected plantings into a stronger network.\n- You used myco placement to keep resources moving.\n- You recovered after early losses.",
	50000: "- You protected the garden with better harvest timing.\n- You kept multiple crop types alive.\n- You managed risk instead of chasing one resource.",
	200000: "- You scaled the garden while keeping resource balance.\n- You placed networks deliberately around productive clusters.\n- You turned small harvests into sustained growth.",
	500000: "- You designed a more resilient layout.\n- You supported many plants through shared resource flow.\n- You kept producing under heavier pressure.",
	1000000: "- You read shortages before they became collapses.\n- You routed support through myco and harvest timing.\n- You maintained high-score pace over a long run.",
	2000000: "- You coordinated a large living system.\n- You kept distant clusters productive.\n- You recovered quickly when predators or shortages hit.",
	3000000: "- You planned ahead across the whole map.\n- You balanced expansion with protection.\n- You built enough redundancy to survive repeated threats.",
	4000000: "- You stewarded a mature soil web.\n- You kept production, harvesting, and recovery synchronized.\n- You pushed close to the full Grassroots Economics goal.",
	5000000: "- You completed the challenge path.\n- You linked healthy soil with village exchange.\n- You demonstrated the full loop: grow, harvest, share, trade, and recover."
}

var _background: TextureRect = null
var _scrim: ColorRect = null
var _content_margin: MarginContainer = null
var _content_center: CenterContainer = null
var _main_vbox: VBoxContainer = null
var _title_label: Label = null
var _achievement_panel: Panel = null
var _achievement_vbox: VBoxContainer = null
var _achievement_heading_label: Label = null
var _hero_label: Label = null
var _achievement_info_button: Button = null
var _info_panel: Panel = null
var _info_title_label: Label = null
var _info_body_label: Label = null
var _result_grid: GridContainer = null
var _score_panel: Panel = null
var _score_title_label: Label = null
var _score_value_label: Label = null
var _high_score_panel: Panel = null
var _high_score_title_label: Label = null
var _high_score_value_label: Label = null
var _mode_label: Label = null
var _ge_link: LinkButton = null
var _share_button: Button = null
var _main_button: Button = null
var _quit_button: Button = null
var _bird_sprite: AnimatedSprite2D = null
var _is_story_result := false
var _is_new_high_score := false
var _info_open := false
var _web_share_card_base64 := ""
var _web_share_card_ready := false
var _desktop_save_dialog: FileDialog = null
var _desktop_share_card_image: Image = null
var _desktop_share_pending := false


func _ready() -> void:
	Global.reset_gameplay_speed()
	_build_layout()
	_populate_content()
	_apply_responsive_layout()
	_connect_viewport_resize_signal()
	_play_intro_animation()
	_prepare_web_share_card()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("shoot"):
		_return_to_title_screen()


func _build_layout() -> void:
	_background = TextureRect.new()
	_background.name = "Background"
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.texture = load(SOIL_BACKGROUND_PATH) as Texture2D
	add_child(_background)

	_scrim = ColorRect.new()
	_scrim.name = "ReadableOverlay"
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.color = Color(0.015, 0.018, 0.012, 0.58)
	add_child(_scrim)

	_bird_sprite = AnimatedSprite2D.new()
	_bird_sprite.name = "DecorativeBird"
	_bird_sprite.sprite_frames = _make_bird_frames()
	_bird_sprite.animation = &"default"
	_bird_sprite.z_as_relative = false
	_bird_sprite.z_index = 2
	add_child(_bird_sprite)
	if _bird_sprite.sprite_frames.get_frame_count(&"default") > 0:
		_bird_sprite.play(&"default")

	_content_margin = MarginContainer.new()
	_content_margin.name = "ContentMargin"
	_content_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content_margin.z_as_relative = false
	_content_margin.z_index = 4
	add_child(_content_margin)

	_content_center = CenterContainer.new()
	_content_center.name = "ContentCenter"
	_content_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content_margin.add_child(_content_center)

	_main_vbox = VBoxContainer.new()
	_main_vbox.name = "MainVBox"
	_main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_main_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_main_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_content_center.add_child(_main_vbox)

	_title_label = _make_label("TitleLabel", "Gardening Over", Color.WHITE, 38, 3, Color(0, 0, 0, 0.72))
	_main_vbox.add_child(_title_label)

	_achievement_panel = Panel.new()
	_achievement_panel.name = "AchievementPanel"
	_achievement_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.03, 0.13, 0.07, 0.82), Color(0.78, 1.0, 0.58, 0.9), 2, 8))
	_main_vbox.add_child(_achievement_panel)

	_achievement_vbox = VBoxContainer.new()
	_achievement_vbox.name = "AchievementVBox"
	_achievement_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_achievement_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_achievement_panel.add_child(_achievement_vbox)

	_achievement_heading_label = _make_label("AchievementHeading", "Achievement Unlocked", Color(1.0, 0.9, 0.42, 1.0), 25, 3, Color(0.05, 0.035, 0.0, 0.95))
	_achievement_vbox.add_child(_achievement_heading_label)

	_hero_label = _make_label("HeroLabel", "", Color(0.62, 1.0, 0.66, 1.0), 58, 5, Color(0.015, 0.07, 0.03, 1.0))
	_hero_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hero_label.clip_text = false
	_achievement_vbox.add_child(_hero_label)

	_achievement_info_button = Button.new()
	_achievement_info_button.name = "AchievementInfoButton"
	_achievement_info_button.text = "i"
	_achievement_info_button.focus_mode = Control.FOCUS_ALL
	_achievement_info_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_achievement_info_button.z_as_relative = false
	_achievement_info_button.z_index = 6
	_style_info_button()
	_achievement_info_button.pressed.connect(_on_achievement_info_pressed)
	_achievement_panel.add_child(_achievement_info_button)

	_info_panel = Panel.new()
	_info_panel.name = "AchievementInfoPanel"
	_info_panel.visible = false
	_info_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.025, 0.07, 0.055, 0.9), Color(1.0, 0.86, 0.32, 0.82), 2, 8))
	_main_vbox.add_child(_info_panel)

	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.name = "InfoVBox"
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	info_vbox.offset_left = 16.0
	info_vbox.offset_top = 12.0
	info_vbox.offset_right = -16.0
	info_vbox.offset_bottom = -12.0
	info_vbox.add_theme_constant_override("separation", 6)
	_info_panel.add_child(info_vbox)

	_info_title_label = _make_label("InfoTitle", "", Color(1.0, 0.91, 0.36, 1.0), 23, 3, Color(0.06, 0.04, 0.0, 0.96))
	info_vbox.add_child(_info_title_label)

	_info_body_label = _make_label("InfoBody", "", Color(0.94, 1.0, 0.9, 1.0), 20, 2, Color(0.0, 0.04, 0.02, 0.9))
	_info_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_info_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_vbox.add_child(_info_body_label)

	_result_grid = GridContainer.new()
	_result_grid.name = "ResultGrid"
	_result_grid.columns = 2
	_main_vbox.add_child(_result_grid)

	_score_panel = _make_result_panel("ScorePanel")
	_score_title_label = _make_label("ScoreTitle", "Score", Color(1.0, 0.88, 0.36, 1.0), 23, 2, Color(0.06, 0.04, 0.01, 1.0))
	_score_value_label = _make_label("ScoreValue", "", Color(1.0, 0.93, 0.48, 1.0), 34, 3, Color(0.06, 0.04, 0.01, 1.0))
	_add_result_labels(_score_panel, _score_title_label, _score_value_label)
	_result_grid.add_child(_score_panel)

	_high_score_panel = _make_result_panel("HighScorePanel")
	_high_score_title_label = _make_label("HighScoreTitle", "High Score", Color(0.64, 0.86, 1.0, 1.0), 23, 2, Color(0.02, 0.04, 0.08, 1.0))
	_high_score_value_label = _make_label("HighScoreValue", "", Color(0.76, 0.92, 1.0, 1.0), 31, 3, Color(0.02, 0.04, 0.08, 1.0))
	_add_result_labels(_high_score_panel, _high_score_title_label, _high_score_value_label)
	_result_grid.add_child(_high_score_panel)

	_mode_label = _make_label("ModeLabel", "", Color.WHITE, 22, 3, Color(0, 0, 0, 0.82))
	_mode_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_main_vbox.add_child(_mode_label)

	_ge_link = LinkButton.new()
	_ge_link.name = "GrassrootsEconomicsLink"
	_ge_link.text = "Grassroots Economics"
	_ge_link.uri = GE_BOOK_URI
	_ge_link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ge_link.add_theme_font_size_override("font_size", 21)
	_ge_link.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0, 0.86))
	_ge_link.add_theme_color_override("font_hover_color", Color(1.0, 0.93, 0.55, 1.0))
	_main_vbox.add_child(_ge_link)

	_share_button = Button.new()
	_share_button.name = "ShareResultButton"
	_share_button.text = "Share Result"
	_share_button.visible = false
	_share_button.size_flags_horizontal = Control.SIZE_FILL
	_share_button.focus_mode = Control.FOCUS_ALL
	_share_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_share_button()
	_share_button.pressed.connect(_on_share_button_pressed)
	_main_vbox.add_child(_share_button)

	_main_button = Button.new()
	_main_button.name = "ReturnButton"
	_main_button.text = "Return to Main Menu"
	_main_button.size_flags_horizontal = Control.SIZE_FILL
	_main_button.focus_mode = Control.FOCUS_ALL
	_main_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_return_button()
	_main_button.pressed.connect(_on_button_pressed)
	_main_vbox.add_child(_main_button)

	_quit_button = Button.new()
	_quit_button.name = "QuitGameButton"
	_quit_button.text = "Quit Game"
	_quit_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_quit_button.focus_mode = Control.FOCUS_ALL
	_quit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_quit_button()
	_quit_button.pressed.connect(_on_quit_game_pressed)
	_main_vbox.add_child(_quit_button)
	_update_share_button_visibility()


func _populate_content() -> void:
	_is_story_result = str(Global.mode) == "story"
	if _is_story_result:
		var reached_phase: int = clampi(int(Global.story_chapter_id), 1, 6)
		_title_label.text = "Tutorial Progress"
		_achievement_heading_label.text = "Phase Reached"
		_hero_label.text = str("Phase ", reached_phase)
		_result_grid.visible = false
		_mode_label.text = "Tutorial"
		_set_info_content(str("Phase ", reached_phase, " Progress"), str(PHASE_SKILL_TEXTS.get(reached_phase, PHASE_SKILL_TEXTS[1])))
		_update_share_button_visibility()
		return

	_is_new_high_score = Global.record_last_score(Global.score)
	var rank_key: int = Global.get_rank_threshold(Global.score)
	var rank_str: String = str(Global.ranks.get(rank_key, "Sporeling"))
	_title_label.text = "Gardening Over"
	_achievement_heading_label.text = "Achievement Unlocked"
	if rank_str == "Grassroots Economist":
		_achievement_heading_label.text = "Top Rank Achieved"
		_mode_label.text = "You WON! Plants " + str(Global.mode) + " mode"
	else:
		_mode_label.text = "Plants " + str(Global.mode) + " mode"
	_hero_label.text = rank_str
	_set_info_content(str(rank_str, " Skills"), str(RANK_SKILL_TEXTS.get(rank_key, RANK_SKILL_TEXTS[0])))
	_score_value_label.text = Global.format_score_value(Global.score)
	_high_score_value_label.text = Global.format_score_value(Global.high_score)
	if _is_new_high_score:
		_high_score_title_label.text = "New High Score!"
		_high_score_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.32, 1.0))
		_high_score_value_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.48, 1.0))
		_high_score_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.22, 0.14, 0.02, 0.84), Color(1.0, 0.86, 0.28, 1.0), 3, 8))
	_update_share_button_visibility()


func _make_label(node_name: String, text_value: String, font_color: Color, font_size: int, outline_size: int, outline_color: Color) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("outline_size", outline_size)
	label.size_flags_horizontal = Control.SIZE_FILL
	return label


func _make_panel_style(bg_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = 16.0
	style.content_margin_top = 12.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 12.0
	return style


func _make_result_panel(node_name: String) -> Panel:
	var panel: Panel = Panel.new()
	panel.name = node_name
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.02, 0.045, 0.035, 0.78), Color(0.78, 0.92, 0.78, 0.42), 1, 8))
	return panel


func _add_result_labels(panel: Panel, title_label: Label, value_label: Label) -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	vbox.add_child(title_label)
	vbox.add_child(value_label)


func _style_return_button() -> void:
	var normal: StyleBoxFlat = _make_panel_style(Color(0.13, 0.36, 0.18, 0.95), Color(0.78, 1.0, 0.68, 0.92), 2, 8)
	var hover: StyleBoxFlat = _make_panel_style(Color(0.18, 0.46, 0.23, 0.98), Color(0.95, 1.0, 0.75, 1.0), 3, 8)
	var pressed: StyleBoxFlat = _make_panel_style(Color(0.08, 0.25, 0.12, 0.98), Color(0.66, 0.9, 0.56, 1.0), 2, 8)
	_main_button.add_theme_stylebox_override("normal", normal)
	_main_button.add_theme_stylebox_override("hover", hover)
	_main_button.add_theme_stylebox_override("pressed", pressed)
	_main_button.add_theme_stylebox_override("focus", hover)
	_main_button.add_theme_color_override("font_color", Color.WHITE)
	_main_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_main_button.add_theme_color_override("font_pressed_color", Color.WHITE)


func _style_share_button() -> void:
	var normal: StyleBoxFlat = _make_panel_style(Color(0.08, 0.18, 0.30, 0.92), Color(0.62, 0.86, 1.0, 0.88), 2, 8)
	var hover: StyleBoxFlat = _make_panel_style(Color(0.12, 0.25, 0.40, 0.96), Color(0.86, 0.96, 1.0, 1.0), 3, 8)
	var pressed: StyleBoxFlat = _make_panel_style(Color(0.04, 0.12, 0.22, 0.98), Color(0.46, 0.72, 0.92, 1.0), 2, 8)
	_share_button.add_theme_stylebox_override("normal", normal)
	_share_button.add_theme_stylebox_override("hover", hover)
	_share_button.add_theme_stylebox_override("pressed", pressed)
	_share_button.add_theme_stylebox_override("focus", hover)
	_share_button.add_theme_color_override("font_color", Color(0.9, 0.97, 1.0, 1.0))
	_share_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_share_button.add_theme_color_override("font_pressed_color", Color(0.82, 0.94, 1.0, 1.0))


func _style_quit_button() -> void:
	var normal: StyleBoxFlat = _make_panel_style(Color(0.42, 0.06, 0.05, 0.94), Color(1.0, 0.42, 0.36, 0.86), 2, 8)
	var hover: StyleBoxFlat = _make_panel_style(Color(0.56, 0.09, 0.07, 0.98), Color(1.0, 0.62, 0.54, 1.0), 3, 8)
	var pressed: StyleBoxFlat = _make_panel_style(Color(0.27, 0.035, 0.03, 0.98), Color(0.82, 0.28, 0.24, 1.0), 2, 8)
	_quit_button.add_theme_stylebox_override("normal", normal)
	_quit_button.add_theme_stylebox_override("hover", hover)
	_quit_button.add_theme_stylebox_override("pressed", pressed)
	_quit_button.add_theme_stylebox_override("focus", hover)
	_quit_button.add_theme_color_override("font_color", Color.WHITE)
	_quit_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_quit_button.add_theme_color_override("font_pressed_color", Color(1.0, 0.9, 0.88, 1.0))


func _make_info_button_style(bg_color: Color, border_color: Color, shadow_alpha: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_left = 24
	style.corner_radius_bottom_right = 24
	style.shadow_color = Color(1.0, 0.86, 0.22, shadow_alpha)
	style.shadow_size = 12
	style.shadow_offset = Vector2.ZERO
	return style


func _style_info_button() -> void:
	if not is_instance_valid(_achievement_info_button):
		return
	_achievement_info_button.add_theme_stylebox_override("normal", _make_info_button_style(Color(0.05, 0.18, 0.10, 0.96), Color(1.0, 0.9, 0.38, 1.0), 0.58))
	_achievement_info_button.add_theme_stylebox_override("hover", _make_info_button_style(Color(0.12, 0.34, 0.15, 0.98), Color(1.0, 0.96, 0.54, 1.0), 0.78))
	_achievement_info_button.add_theme_stylebox_override("pressed", _make_info_button_style(Color(0.04, 0.13, 0.07, 1.0), Color(0.92, 0.78, 0.28, 1.0), 0.46))
	_achievement_info_button.add_theme_stylebox_override("focus", _make_info_button_style(Color(0.12, 0.34, 0.15, 0.98), Color(1.0, 1.0, 0.72, 1.0), 0.88))
	_achievement_info_button.add_theme_font_size_override("font_size", 26)
	_achievement_info_button.add_theme_color_override("font_color", Color(1.0, 0.96, 0.58, 1.0))
	_achievement_info_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_achievement_info_button.add_theme_color_override("font_pressed_color", Color(1.0, 0.88, 0.42, 1.0))
	_achievement_info_button.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.015, 0.95))
	_achievement_info_button.add_theme_constant_override("outline_size", 3)


func _set_info_content(title_text: String, body_text: String) -> void:
	if is_instance_valid(_info_title_label):
		_info_title_label.text = title_text
	if is_instance_valid(_info_body_label):
		_info_body_label.text = body_text


func _set_info_open(open: bool) -> void:
	_info_open = open
	if is_instance_valid(_info_panel):
		_info_panel.visible = _info_open
	if is_instance_valid(_achievement_info_button):
		_achievement_info_button.text = "X" if _info_open else "i"
	_apply_responsive_layout()


func _on_achievement_info_pressed() -> void:
	_set_info_open(not _info_open)


func _make_bird_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	if not frames.has_animation(&"default"):
		frames.add_animation(&"default")
	frames.set_animation_loop(&"default", true)
	frames.set_animation_speed(&"default", 5.0)
	for path in BIRD_FRAME_PATHS:
		var texture: Resource = load(str(path))
		if texture is Texture2D:
			frames.add_frame(&"default", texture as Texture2D)
	return frames


func _connect_viewport_resize_signal() -> void:
	var viewport: Viewport = get_viewport()
	if not is_instance_valid(viewport):
		return
	if viewport.size_changed.is_connected(_on_viewport_size_changed):
		return
	viewport.size_changed.connect(_on_viewport_size_changed)


func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()


func _position_info_button(button_size: int) -> void:
	if not is_instance_valid(_achievement_info_button):
		return
	var size_value := float(button_size)
	var pad := 8.0
	_achievement_info_button.anchor_left = 1.0
	_achievement_info_button.anchor_top = 0.0
	_achievement_info_button.anchor_right = 1.0
	_achievement_info_button.anchor_bottom = 0.0
	_achievement_info_button.offset_left = -size_value - pad
	_achievement_info_button.offset_top = pad
	_achievement_info_button.offset_right = -pad
	_achievement_info_button.offset_bottom = size_value + pad
	_achievement_info_button.custom_minimum_size = Vector2(size_value, size_value)
	_achievement_info_button.size = Vector2(size_value, size_value)
	_achievement_info_button.add_theme_font_size_override("font_size", maxi(button_size - 18, 20))


func _apply_responsive_layout() -> void:
	if not is_instance_valid(_main_vbox):
		return
	var view_size: Vector2 = get_viewport_rect().size
	var short_edge: float = minf(view_size.x, view_size.y)
	var compact: bool = short_edge <= COMPACT_SHORT_EDGE
	var tiny: bool = short_edge <= TINY_SHORT_EDGE
	var side_margin: int = int(clampf(short_edge * 0.055, 18.0, 44.0))
	var vertical_margin: int = int(clampf(view_size.y * 0.045, 22.0, 58.0))
	if compact:
		vertical_margin = int(clampf(view_size.y * 0.032, 16.0, 36.0))
	_content_margin.add_theme_constant_override("margin_left", side_margin)
	_content_margin.add_theme_constant_override("margin_right", side_margin)
	_content_margin.add_theme_constant_override("margin_top", vertical_margin)
	_content_margin.add_theme_constant_override("margin_bottom", vertical_margin)

	var content_width: float = clampf(view_size.x - float(side_margin * 2), MIN_CONTENT_WIDTH, MAX_CONTENT_WIDTH)
	var section_gap: int = 16
	var heading_size: int = 27
	var title_size: int = 42
	var body_size: int = 23
	var link_size: int = 21
	var button_size: int = 38
	var button_height: int = 70
	var quit_button_size: int = 24
	var quit_button_height: int = 46
	var share_button_size: int = 25
	var share_button_height: int = 54
	var hero_max_size: int = 66
	var hero_min_size: int = 38
	var achievement_height: int = 184
	var info_panel_height: int = 190
	var info_button_size: int = 46
	var result_height: int = 104
	var score_title_size: int = 24
	var score_value_size: int = 36
	var high_score_value_size: int = 33
	var info_title_size: int = 23
	var info_body_size: int = 20
	var bird_scale: float = 0.82
	if compact:
		section_gap = 13
		heading_size = 24
		title_size = 36
		body_size = 20
		link_size = 20
		button_size = 34
		button_height = 64
		quit_button_size = 22
		quit_button_height = 42
		share_button_size = 23
		share_button_height = 50
		hero_max_size = 58
		achievement_height = 168
		info_panel_height = 182
		info_button_size = 44
		result_height = 94
		score_title_size = 22
		score_value_size = 32
		high_score_value_size = 29
		info_title_size = 21
		info_body_size = 18
		bird_scale = 0.72
	if tiny:
		section_gap = 10
		heading_size = 21
		title_size = 32
		body_size = 18
		link_size = 18
		button_size = 30
		button_height = 58
		quit_button_size = 20
		quit_button_height = 38
		share_button_size = 21
		share_button_height = 46
		hero_max_size = 50
		hero_min_size = 34
		achievement_height = 142
		info_panel_height = 172
		info_button_size = 40
		result_height = 82
		score_title_size = 20
		score_value_size = 28
		high_score_value_size = 26
		info_title_size = 19
		info_body_size = 16
		bird_scale = 0.62
	_main_vbox.custom_minimum_size = Vector2(content_width, 0.0)
	_main_vbox.add_theme_constant_override("separation", section_gap)
	_achievement_vbox.add_theme_constant_override("separation", 4 if compact else 8)
	_result_grid.add_theme_constant_override("h_separation", 10 if compact else 14)
	_result_grid.add_theme_constant_override("v_separation", 8 if compact else 10)
	_result_grid.columns = 1 if content_width < 430.0 else 2

	_title_label.add_theme_font_size_override("font_size", title_size)
	_achievement_heading_label.add_theme_font_size_override("font_size", heading_size)
	_mode_label.add_theme_font_size_override("font_size", body_size)
	_ge_link.add_theme_font_size_override("font_size", link_size)
	_main_button.add_theme_font_size_override("font_size", button_size)
	_main_button.custom_minimum_size = Vector2(content_width, button_height)
	if is_instance_valid(_quit_button):
		_quit_button.add_theme_font_size_override("font_size", quit_button_size)
		_quit_button.custom_minimum_size = Vector2(clampf(content_width * 0.5, 190.0, 300.0), quit_button_height)
	if is_instance_valid(_share_button):
		_share_button.add_theme_font_size_override("font_size", share_button_size)
		_share_button.custom_minimum_size = Vector2(content_width, share_button_height)

	_apply_adaptive_hero_font(content_width, hero_max_size, hero_min_size)
	_achievement_panel.custom_minimum_size = Vector2(content_width, achievement_height)
	_position_info_button(info_button_size)
	if is_instance_valid(_info_panel):
		_info_panel.custom_minimum_size = Vector2(content_width, info_panel_height)
	if is_instance_valid(_info_title_label):
		_info_title_label.add_theme_font_size_override("font_size", info_title_size)
	if is_instance_valid(_info_body_label):
		_info_body_label.add_theme_font_size_override("font_size", info_body_size)

	_score_panel.custom_minimum_size = Vector2(0.0, result_height)
	_high_score_panel.custom_minimum_size = _score_panel.custom_minimum_size
	_score_title_label.add_theme_font_size_override("font_size", score_title_size)
	_score_value_label.add_theme_font_size_override("font_size", score_value_size)
	_high_score_title_label.add_theme_font_size_override("font_size", score_title_size)
	_high_score_value_label.add_theme_font_size_override("font_size", high_score_value_size)

	if is_instance_valid(_bird_sprite):
		_bird_sprite.scale = Vector2.ONE * bird_scale
		_bird_sprite.position = Vector2(view_size.x * 0.5, vertical_margin + 22.0)


func _apply_adaptive_hero_font(content_width: float, max_size: int, min_size: int) -> void:
	var text_len: int = _hero_label.text.length()
	var size: int = max_size
	if text_len >= 24:
		size -= 8
	elif text_len >= 18:
		size -= 4
	var estimated_width: float = float(text_len) * float(size) * 0.56
	while size > min_size and estimated_width > content_width * 0.88:
		size -= 2
		estimated_width = float(text_len) * float(size) * 0.56
	_hero_label.add_theme_font_size_override("font_size", size)


func _play_intro_animation() -> void:
	call_deferred("_run_intro_animation")


func _run_intro_animation() -> void:
	if not is_instance_valid(_achievement_panel):
		return
	_achievement_panel.pivot_offset = _achievement_panel.size * 0.5
	_achievement_panel.modulate.a = 0.0
	_achievement_panel.scale = Vector2(0.97, 0.97)
	var tween: Tween = create_tween()
	tween.tween_property(_achievement_panel, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(_achievement_panel, "scale", Vector2(1.03, 1.03), 0.18)
	tween.tween_property(_achievement_panel, "scale", Vector2.ONE, 0.16)


func _return_to_title_screen() -> void:
	Global.record_last_score()
	Global.score = 0
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


func _on_button_pressed() -> void:
	_return_to_title_screen()


func _on_quit_game_pressed() -> void:
	Global.record_last_score()
	get_tree().quit()


func _is_android_share_available() -> bool:
	if OS.get_name() != "Android":
		return false
	return Engine.has_singleton("AndroidRuntime") and Engine.has_singleton("JavaClassWrapper")


func _is_web_share_available() -> bool:
	return OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge")


func _is_desktop_share_available() -> bool:
	var os_name: String = OS.get_name()
	return os_name in ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]


func _is_share_available() -> bool:
	return _is_android_share_available() or _is_web_share_available() or _is_desktop_share_available()


func _update_share_button_visibility() -> void:
	if is_instance_valid(_share_button):
		_share_button.visible = _is_share_available()
		_apply_web_share_button_state()


func _apply_web_share_button_state() -> void:
	if not is_instance_valid(_share_button):
		return
	if not _is_web_share_available():
		return
	_share_button.disabled = not _web_share_card_ready
	_share_button.text = "Share Result" if _web_share_card_ready else "Preparing..."


func _on_share_button_pressed() -> void:
	if _is_web_share_available():
		_open_web_share_sheet()
		return
	if _is_desktop_share_available():
		await _open_desktop_share_save_dialog()
		return
	if not _is_android_share_available():
		return
	if is_instance_valid(_share_button):
		_share_button.disabled = true
		_share_button.text = "Preparing..."
	var png_path: String = await _create_share_card_png()
	if png_path != "":
		_open_android_share_sheet(ProjectSettings.globalize_path(png_path), _make_share_text())
	if is_instance_valid(_share_button):
		_share_button.disabled = false
		_share_button.text = "Share Result"


func _prepare_web_share_card() -> void:
	if not _is_web_share_available():
		return
	_web_share_card_ready = false
	_apply_web_share_button_state()
	call_deferred("_render_web_share_card")


func _render_web_share_card() -> void:
	if not _is_web_share_available():
		return
	var image: Image = await _render_share_card_image()
	if image.is_empty():
		_web_share_card_base64 = ""
		_web_share_card_ready = true
		_apply_web_share_button_state()
		return
	var png_buffer: PackedByteArray = image.save_png_to_buffer()
	_web_share_card_base64 = Marshalls.raw_to_base64(png_buffer)
	_web_share_card_ready = true
	_apply_web_share_button_state()


func _create_share_card_png() -> String:
	var absolute_dir: String = ProjectSettings.globalize_path(SHARE_CARD_DIR)
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK:
		push_warning(str("Could not create share directory: ", absolute_dir))
		return ""

	var image: Image = await _render_share_card_image()
	if image.is_empty():
		push_warning("Could not render share card image.")
		return ""

	var save_error: Error = image.save_png(SHARE_CARD_PATH)
	if save_error != OK:
		push_warning(str("Could not save share card: ", SHARE_CARD_PATH))
		return ""
	return SHARE_CARD_PATH


func _set_share_button_busy(busy: bool, label: String = "Share Result") -> void:
	if not is_instance_valid(_share_button):
		return
	_share_button.disabled = busy
	_share_button.text = label


func _try_enable_native_save_dialog(dialog: FileDialog) -> void:
	if not is_instance_valid(dialog):
		return
	for property_info in dialog.get_property_list():
		if typeof(property_info) == TYPE_DICTIONARY and str(property_info.get("name", "")) == "use_native_dialog":
			dialog.set("use_native_dialog", true)
			return


func _ensure_desktop_save_dialog() -> void:
	if is_instance_valid(_desktop_save_dialog):
		return
	_desktop_save_dialog = FileDialog.new()
	_desktop_save_dialog.name = "DesktopShareSaveDialog"
	_desktop_save_dialog.title = "Save Result Card"
	_desktop_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_desktop_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_desktop_save_dialog.filters = PackedStringArray(["*.png ; PNG Image"])
	_desktop_save_dialog.current_file = SHARE_CARD_DEFAULT_FILENAME
	_desktop_save_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	_try_enable_native_save_dialog(_desktop_save_dialog)
	_desktop_save_dialog.file_selected.connect(_on_desktop_share_save_selected)
	_desktop_save_dialog.canceled.connect(_on_desktop_share_save_canceled)
	add_child(_desktop_save_dialog)


func _open_desktop_share_save_dialog() -> void:
	if _desktop_share_pending:
		return
	_desktop_share_pending = true
	_set_share_button_busy(true, "Preparing...")
	var image: Image = await _render_share_card_image()
	if image.is_empty():
		_desktop_share_pending = false
		_set_share_button_busy(false)
		push_warning("Could not render share card image.")
		return
	_desktop_share_card_image = image
	_ensure_desktop_save_dialog()
	if not is_instance_valid(_desktop_save_dialog):
		_desktop_share_pending = false
		_desktop_share_card_image = null
		_set_share_button_busy(false)
		return
	_desktop_save_dialog.current_dir = ProjectSettings.globalize_path("user://")
	_desktop_save_dialog.current_file = SHARE_CARD_DEFAULT_FILENAME
	_set_share_button_busy(true, "Choose Save Location...")
	_desktop_save_dialog.popup_centered(Vector2i(760, 560))


func _on_desktop_share_save_selected(path: String) -> void:
	var target_path: String = path
	if target_path.get_extension().to_lower() != "png":
		target_path += ".png"
	if _desktop_share_card_image == null or _desktop_share_card_image.is_empty():
		push_warning("No share card image is ready to save.")
	else:
		var save_error: Error = _desktop_share_card_image.save_png(target_path)
		if save_error != OK:
			push_warning(str("Could not save share card: ", target_path))
	_desktop_share_card_image = null
	_desktop_share_pending = false
	_set_share_button_busy(false)


func _on_desktop_share_save_canceled() -> void:
	_desktop_share_card_image = null
	_desktop_share_pending = false
	_set_share_button_busy(false)


func _render_share_card_image() -> Image:
	var share_viewport: SubViewport = SubViewport.new()
	share_viewport.name = "ShareCardViewport"
	share_viewport.size = SHARE_CARD_SIZE
	share_viewport.disable_3d = true
	share_viewport.transparent_bg = false
	share_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(share_viewport)

	var share_card: Control = _make_share_card_control()
	share_viewport.add_child(share_card)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image: Image = share_viewport.get_texture().get_image()
	share_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	remove_child(share_viewport)
	share_viewport.free()
	return image


func _make_share_card_control() -> Control:
	var root: Control = Control.new()
	root.name = "ShareCard"
	root.position = Vector2.ZERO
	root.size = Vector2(float(SHARE_CARD_SIZE.x), float(SHARE_CARD_SIZE.y))

	var background: TextureRect = TextureRect.new()
	background.name = "Background"
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture = load(SOIL_BACKGROUND_PATH) as Texture2D
	root.add_child(background)

	var overlay: ColorRect = ColorRect.new()
	overlay.name = "Overlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.012, 0.016, 0.01, 0.68)
	root.add_child(overlay)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "ContentMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 88)
	margin.add_theme_constant_override("margin_top", 128)
	margin.add_theme_constant_override("margin_right", 88)
	margin.add_theme_constant_override("margin_bottom", 116)
	root.add_child(margin)

	var center: CenterContainer = CenterContainer.new()
	center.name = "ContentCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "ShareVBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.custom_minimum_size = Vector2(904.0, 0.0)
	vbox.add_theme_constant_override("separation", 30)
	center.add_child(vbox)

	var bird_icon: TextureRect = _make_share_texture("ShareBird", SHARE_CARD_BIRD_PATH, Vector2(118.0, 96.0))
	vbox.add_child(bird_icon)

	var title: Label = _make_label("ShareTitle", "Social Soil", Color(1.0, 0.9, 0.34, 1.0), 92, 6, Color(0.02, 0.05, 0.02, 1.0))
	title.custom_minimum_size = Vector2(904.0, 116.0)
	vbox.add_child(title)

	var panel: Panel = Panel.new()
	panel.name = "ShareAchievementPanel"
	panel.custom_minimum_size = Vector2(904.0, 560.0)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.03, 0.13, 0.07, 0.86), Color(0.92, 1.0, 0.54, 0.95), 4, 8))
	vbox.add_child(panel)

	var panel_vbox: VBoxContainer = VBoxContainer.new()
	panel_vbox.name = "AchievementVBox"
	panel_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_vbox.offset_left = 44.0
	panel_vbox.offset_top = 44.0
	panel_vbox.offset_right = -44.0
	panel_vbox.offset_bottom = -44.0
	panel_vbox.add_theme_constant_override("separation", 22)
	panel.add_child(panel_vbox)

	var heading_text: String = "Tutorial Progress" if _is_story_result else str(_achievement_heading_label.text)
	var heading: Label = _make_label("ShareHeading", heading_text, Color(1.0, 0.91, 0.42, 1.0), 50, 4, Color(0.05, 0.035, 0.0, 0.95))
	panel_vbox.add_child(heading)

	var hero: Label = _make_label("ShareHero", str(_hero_label.text), Color(0.62, 1.0, 0.66, 1.0), 92, 6, Color(0.015, 0.07, 0.03, 1.0))
	hero.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero.custom_minimum_size = Vector2(816.0, 300.0)
	_apply_share_card_hero_font(hero, 92, 66, 816.0)
	panel_vbox.add_child(hero)

	var score_line: String = _make_share_score_line()
	if score_line != "":
		var score: Label = _make_label("ShareScore", score_line, Color(1.0, 0.94, 0.5, 1.0), 42, 4, Color(0.06, 0.04, 0.01, 1.0))
		panel_vbox.add_child(score)

	var mode: Label = _make_label("ShareMode", _make_share_mode_line(), Color(0.96, 1.0, 0.92, 1.0), 38, 3, Color(0.0, 0.04, 0.02, 0.92))
	mode.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode.custom_minimum_size = Vector2(904.0, 96.0)
	vbox.add_child(mode)

	var tuktuk_icon: TextureRect = _make_share_texture("ShareTuktuk", SHARE_CARD_TUKTUK_PATH, Vector2(172.0, 116.0))
	vbox.add_child(tuktuk_icon)

	var footer: Label = _make_label("ShareFooter", str("Play Social Soil\n", SHARE_URL_DISPLAY), Color(0.86, 0.95, 1.0, 1.0), 36, 3, Color(0.0, 0.03, 0.06, 0.95))
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.custom_minimum_size = Vector2(904.0, 110.0)
	vbox.add_child(footer)

	var mushroom_icon: TextureRect = _make_share_texture("ShareMushroom", SHARE_CARD_MUSHROOM_PATH, Vector2(92.0, 90.0))
	vbox.add_child(mushroom_icon)
	return root


func _make_share_texture(node_name: String, path: String, min_size: Vector2) -> TextureRect:
	var texture_rect: TextureRect = TextureRect.new()
	texture_rect.name = node_name
	texture_rect.custom_minimum_size = min_size
	texture_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var texture: Resource = load(path)
	if texture is Texture2D:
		texture_rect.texture = texture as Texture2D
	return texture_rect


func _apply_share_card_hero_font(label: Label, max_size: int, min_size: int, content_width: float) -> void:
	var text_len: int = label.text.length()
	var size_value: int = max_size
	if text_len >= 24:
		size_value -= 12
	elif text_len >= 18:
		size_value -= 6
	var estimated_width: float = float(text_len) * float(size_value) * 0.56
	while size_value > min_size and estimated_width > content_width * 0.94:
		size_value -= 2
		estimated_width = float(text_len) * float(size_value) * 0.56
	label.add_theme_font_size_override("font_size", size_value)


func _make_share_score_line() -> String:
	if _is_story_result:
		return ""
	var score_text: String = str(_score_value_label.text)
	if _is_new_high_score:
		return str(score_text, " points - new high score")
	return str(score_text, " points")


func _make_share_mode_line() -> String:
	if _is_story_result:
		return str("I reached ", _hero_label.text, " in Tutorial mode.")
	return str("I reached ", _hero_label.text, " in Social Soil.")


func _make_share_summary_text() -> String:
	if _is_story_result:
		return str("I reached ", _hero_label.text, " in Social Soil.")
	return str("I reached ", _hero_label.text, " with ", _score_value_label.text, " points in Social Soil.")


func _make_share_text() -> String:
	return str(_make_share_summary_text(), " Play here: ", SHARE_URL_DISPLAY)


func _open_android_share_sheet(absolute_png_path: String, share_text: String) -> bool:
	var android_runtime: Object = Engine.get_singleton("AndroidRuntime")
	var java_wrapper: Object = Engine.get_singleton("JavaClassWrapper")
	if android_runtime == null or java_wrapper == null:
		return false
	var activity: Object = android_runtime.getActivity()
	if activity == null:
		return false
	var share_class: Object = java_wrapper.wrap(ANDROID_SHARE_CLASS)
	if share_class == null:
		return false
	var shared: Variant = share_class.sharePng(activity, absolute_png_path, share_text)
	var exception: Object = java_wrapper.get_exception()
	if exception != null:
		push_warning(str("Android share failed: ", exception))
		return false
	return Global.to_bool(shared)


func _open_web_share_sheet() -> bool:
	if not _is_web_share_available():
		return false
	var js_bridge: Object = Engine.get_singleton("JavaScriptBridge")
	if js_bridge == null:
		return false
	var code: String = _make_web_share_script(
		_web_share_card_base64,
		_make_share_summary_text(),
		_make_share_text(),
		SHARE_URL
	)
	var result: Variant = js_bridge.eval(code, true)
	return str(result) != "unsupported"


func _make_web_share_script(png_base64: String, share_summary: String, fallback_text: String, share_url: String) -> String:
	var title_json: String = JSON.stringify("Social Soil")
	var base64_json: String = JSON.stringify(png_base64)
	var summary_json: String = JSON.stringify(share_summary)
	var fallback_json: String = JSON.stringify(fallback_text)
	var url_json: String = JSON.stringify(share_url)
	return """
(function () {
	const title = %s;
	const pngBase64 = %s;
	const shareSummary = %s;
	const fallbackText = %s;
	const shareUrl = %s;

	function base64ToBlob(base64, mimeType) {
		const binary = atob(base64);
		const length = binary.length;
		const bytes = new Uint8Array(length);
		for (let i = 0; i < length; i += 1) {
			bytes[i] = binary.charCodeAt(i);
		}
		return new Blob([bytes], { type: mimeType });
	}

	function downloadImage() {
		if (!pngBase64) {
			return;
		}
		const link = document.createElement("a");
		link.href = "data:image/png;base64," + pngBase64;
		link.download = "social_soil_result.png";
		document.body.appendChild(link);
		link.click();
		link.remove();
	}

	function copyFallbackText() {
		if (navigator.clipboard && window.isSecureContext) {
			navigator.clipboard.writeText(fallbackText).catch(function () {});
		}
	}

	if (!navigator.share) {
		copyFallbackText();
		downloadImage();
		return "unsupported";
	}

	const linkShare = { title: title, text: shareSummary, url: shareUrl };
	if (pngBase64 && window.File && window.Blob && navigator.canShare) {
		const file = new File(
			[base64ToBlob(pngBase64, "image/png")],
			"social_soil_result.png",
			{ type: "image/png" }
		);
		const fileShare = { title: title, text: fallbackText, files: [file] };
		if (navigator.canShare(fileShare)) {
			navigator.share(fileShare).catch(function (error) {
				if (error && error.name === "AbortError") {
					return;
				}
				navigator.share(linkShare).catch(function () {
					copyFallbackText();
					downloadImage();
				});
			});
			return "file";
		}
	}

	navigator.share(linkShare).catch(function (error) {
		if (error && error.name === "AbortError") {
			return;
		}
		copyFallbackText();
		downloadImage();
	});
	return "link";
})()
""" % [title_json, base64_json, summary_json, fallback_json, url_json]
