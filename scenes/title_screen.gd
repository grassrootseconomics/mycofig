extends Control


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
	Global.social_mode = false
		

func _on_tutorial_pressed() -> void:
	_reset_run_state()
	Global.mode = "story"
	Global.is_raining = false
	Global.is_birding = true
	Global.is_killing = false
	Global.is_max_babies = true
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
	"basket": 0
	}
	get_tree().change_scene_to_file("res://scenes/level.tscn")


func _on_cofi_button_pressed() -> void:
	_on_challenge_button_pressed()


func _on_check_button_toggled(toggled_on: bool) -> void:
	Global.social_mode = false
		


func _on_check_button_2_toggled(toggled_on: bool) -> void:
	Global.social_mode = false
