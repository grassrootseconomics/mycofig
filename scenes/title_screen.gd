extends Control

const TITLE_COMPACT_SHORT_EDGE := 640.0
const TITLE_TINY_SHORT_EDGE := 500.0

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


func _connect_viewport_resize_signal() -> void:
	var viewport = get_viewport()
	if not is_instance_valid(viewport):
		return
	if viewport.size_changed.is_connected(_on_viewport_size_changed):
		return
	viewport.size_changed.connect(_on_viewport_size_changed)


func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	var view_size = get_viewport_rect().size
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
		title.add_theme_font_size_override("font_size", title_font_size)
		var fallback_top = 22.0 if compact else 68.0
		var fallback_bottom = 156.0 if compact else 228.0
		title.offset_top = fallback_top
		title.offset_bottom = fallback_bottom
	var menu_box: VBoxContainer = $CenterContainer/VBoxContainer
	if is_instance_valid(menu_box):
		menu_box.custom_minimum_size = Vector2(minf(view_size.x - 48.0, 420.0), 0.0)
		menu_box.add_theme_constant_override("separation", 9 if compact else 11)
	var cta_width = clampf(view_size.x - 72.0, 220.0, 340.0)
	var cta_height = 68.0 if compact else 78.0
	var cta_font_size = 37 if compact else 46
	if tiny:
		cta_height = 60.0
		cta_font_size = 31
	for button in [$CenterContainer/VBoxContainer/Tutorial, $CenterContainer/VBoxContainer/ChallengeButton]:
		if not is_instance_valid(button):
			continue
		button.custom_minimum_size = Vector2(cta_width, cta_height)
		button.add_theme_font_size_override("font_size", cta_font_size)
	var link: LinkButton = $CenterContainer/VBoxContainer/LinkButton
	if is_instance_valid(link):
		link.add_theme_font_size_override("font_size", 24 if compact else 30)
		if tiny:
			link.add_theme_font_size_override("font_size", 20)
	var regen_label: RichTextLabel = $CenterContainer/VBoxContainer/RegenerationLabel
	if is_instance_valid(regen_label):
		var regen_font_size = title_font_size + (8 if tiny else 10)
		regen_label.bbcode_enabled = true
		regen_label.fit_content = true
		regen_label.scroll_active = false
		regen_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		regen_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		regen_label.custom_minimum_size = Vector2(clampf(view_size.x - 96.0, 260.0, 520.0), 0.0)
		regen_label.text = "[i]Regeneration[/i]"
		regen_label.add_theme_font_size_override("normal_font_size", regen_font_size)
		regen_label.add_theme_font_size_override("italics_font_size", regen_font_size)
	var shroom: Sprite2D = $CenterContainer/shroom
	var farmer: Sprite2D = $CenterContainer/farmer
	var small_shroom: Sprite2D = $CenterContainer/SmallShroom
	var basket: Sprite2D = $CenterContainer/Basket
	if is_instance_valid(shroom):
		shroom.visible = true
		shroom.scale = Vector2(0.24, 0.24) if compact else Vector2(0.30561, 0.30561)
		if tiny:
			shroom.scale = Vector2(0.20, 0.20)
		shroom.position = Vector2(86.0, -62.0) if compact else Vector2(88.5, -73.4999)
	if is_instance_valid(farmer):
		farmer.visible = true
		farmer.scale = Vector2(1.64, 1.64) if compact else Vector2(2.03894, 2.03894)
		if tiny:
			farmer.scale = Vector2(1.48, 1.48)
		farmer.position = Vector2(454.0, -70.0) if compact else Vector2(449.5, -84.5)
	if is_instance_valid(small_shroom):
		small_shroom.visible = true
		small_shroom.scale = Vector2(0.48, 0.48) if compact else Vector2(0.629555, 0.629555)
		if tiny:
			small_shroom.scale = Vector2(0.42, 0.42)
		small_shroom.position = Vector2(270.0, 522.0) if compact else Vector2(269.5, 541.5)
	if is_instance_valid(basket):
		basket.visible = true
		basket.position = Vector2(268.5, 520.0) if compact else Vector2(268.5, 534.5)
	if is_instance_valid(title):
		var title_height = 122.0 if tiny else (134.0 if compact else 160.0)
		var fallback_top = 22.0 if compact else 68.0
		var vertical_bias = 100.0 if compact else 70.0
		if is_instance_valid(shroom) and is_instance_valid(farmer):
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


func _ready():
	DisplayServer.window_set_title("Social Soil Gardening")
	Global.score = 0
	$CenterContainer/BG.modulate.a = 1
	$CenterContainer/BG2.modulate.a = 0
	$CenterContainer/VBoxContainer/HBoxContainer.visible = false
	_setup_primary_buttons()
	_connect_viewport_resize_signal()
	_apply_responsive_layout()
	Global.social_mode = false
		

func _on_tutorial_pressed() -> void:
	_reset_run_state()
	Global.mode = "story"
	Global.is_raining = false
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
