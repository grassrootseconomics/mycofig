extends CanvasLayer
const MiniMapPanelRef = preload("res://scenes/minimap_panel.gd")
const LevelHelpersRef = preload("res://scenes/level_helpers.gd")
var time_elapsed := 0

#signal sliderChanged(info_dict)
signal new_agent(agent_dict)
signal inventory_drag_preview(agent_name, world_pos, active)
signal request_back_to_menu

var sliders = []

var last_agent = null

var next_agent = null
var resContainer = null
var drag_preview_sprite: Sprite2D = null
var drag_preview_outline: Line2D = null
var minimap_panel: Control = null
var inventory_spawn_rng := RandomNumberGenerator.new()
const INVENTORY_DRAG_THRESHOLD_MOUSE := 8.0
const INVENTORY_DRAG_THRESHOLD_TOUCH := 18.0
const AUTO_SPAWN_ATTEMPTS := 96
const AUTO_SPAWN_SWEEP_STEPS := 48
const PARENT_BOUNDED_AUTO_ATTEMPTS := 96
const PARENT_BOUNDED_MAX_TILES := 4
const PARENT_BOUNDED_TYPES := {
	"myco": true,
	"bean": true,
	"squash": true,
	"maize": true
}
const INVENTORY_SLOT_ITEMS := ["bean", "squash", "maize", "tree", "myco", "basket"]
const INVENTORY_BASKET_SLOT_INDEX := 5
const INVENTORY_LOCKED_GLYPH := "?"
const INVENTORY_BACKPLATE_COLORS := {
	"bean": Color(0.44, 0.86, 0.34, 0.58),
	"squash": Color(1.0, 0.55, 0.20, 0.58),
	"maize": Color(1.0, 0.45, 0.75, 0.60),
	"tree": Color(0.30, 0.63, 1.0, 0.58)
}
const INVENTORY_BACKPLATE_DEFAULT := Color(0.08, 0.12, 0.18, 0.28)
const INVENTORY_SELECTED_OUTLINE_COLOR := Color(0.98, 0.96, 0.58, 0.98)
const INVENTORY_DRAG_PREVIEW_OUTLINE_COLOR := Color(0.98, 0.96, 0.58, 0.95)
const INVENTORY_PHASE1_SPARKLE_COLOR := Color(1.0, 0.98, 0.58, 0.95)
const INVENTORY_PHASE1_SPARKLE_PULSE_SPEED := 4.6
const TUTORIAL_PANEL_EXPANDED_SIZE := Vector2(372, 178)
const TUTORIAL_PANEL_COLLAPSED_SIZE := Vector2(44, 44)
const INVENTORY_ICON_PAD_DEFAULT := 4.0
const INVENTORY_ICON_PAD_BASKET := 7.0
const INVENTORY_SIDE_BUTTON_BUFFER := 5.0
const TUTORIAL_LABEL_HORIZONTAL_PADDING := 34.0
const TUTORIAL_PANEL_TEXT_VERTICAL_PADDING := 44.0
const TUTORIAL_PANEL_STORY_TEXT_VERTICAL_PADDING := 96.0
const TUTORIAL_PANEL_MAX_HEIGHT_FRACTION := 0.62
const STORY_TUTORIAL_PANEL_EXPANDED_SIZE := Vector2(520, 252)
const STORY_TUTORIAL_CONTINUE_BUTTON_SIZE := Vector2(132, 40)
const STORY_TUTORIAL_CHALLENGE_BUTTON_SIZE := Vector2(220, 42)
const STORY_TUTORIAL_CONTINUE_TEXT := "Let's go!"
const STORY_TUTORIAL_CHALLENGE_TEXT := "Give me a Challenge!"
const CHALLENGE_LOSS_CONTINUE_TEXT := "View my score"
const STORY_FACTS_BUTTON_SIZE := Vector2(196, 42)
const STORY_FACTS_PANEL_SIZE := Vector2(640, 430)
const STORY_FACTS_PANEL_COLOR := Color(0.96, 0.42, 0.08, 0.82)
const STORY_FACTS_PANEL_BORDER := Color(1.0, 0.86, 0.44, 0.72)
const STORY_FACTS_BUTTON_BG := Color(0.82, 0.33, 0.08, 0.94)
const STORY_FACTS_BUTTON_BG_HOVER := Color(0.96, 0.45, 0.12, 0.98)
const STORY_FACTS_BUTTON_BG_PRESSED := Color(0.62, 0.23, 0.06, 1.0)
const STORY_FACTS_SPARKLE_INTERVAL := 0.72
const STORY_FACTS_SPARKLE_DURATION := 0.70
const STORY_FACTS_TEXT := {
	1: "Growing plants require healthy soil.\n\nFungi help make the soil healthy and alive.",
	2: "Birds deserve to eat too. So plant more to feed them.\n\nBirds like seeds.",
	3: "Beans help fix nitrogen (Green) in the soil.\nSquash bring shade and potassium (Orange).\nMaize brings Phosphorus (Pink).\nTrees are helping bring in water (Blue).\n\nBelow the Mushrooms is Mycorrhizal fungi which form a relationship with plant roots, acting as an extension of the root system to enhance nutrient and water absorption.",
	4: "Healthy people need healthy soil.",
	5: "People can exchange, lend, borrow, rotate their goods and services fairly even without money.",
	6: "This was the easy part. Now try Challenge Mode!"
}
const STORY_GUIDE_ARROW_COLOR := Color(1.0, 0.74, 0.16, 0.96)
const STORY_GUIDE_ARROW_SHADOW_COLOR := Color(0.12, 0.05, 0.02, 0.42)
const STORY_GUIDE_ARROW_WIDTH := 7.0
const STORY_GUIDE_ARROW_SHADOW_WIDTH := 12.0
const STORY_GUIDE_ARROW_HEAD_LENGTH := 32.0
const STORY_GUIDE_ARROW_HEAD_WIDTH := 30.0
const QUIT_DIALOG_PANEL_COLOR := Color(0.00, 0.13, 0.47, 0.57)
const QUIT_DIALOG_BORDER_COLOR := Color(0.035, 0.071, 0.149, 0.78)
const QUIT_DIALOG_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.25)
const QUIT_DIALOG_BUTTON_BG := Color(0.17, 0.31, 0.24, 0.86)
const QUIT_DIALOG_BUTTON_BORDER := Color(0.90, 0.97, 0.92, 0.44)
const QUIT_DIALOG_BUTTON_BG_HOVER := Color(0.21, 0.37, 0.28, 0.92)
const QUIT_DIALOG_BUTTON_BG_PRESSED := Color(0.12, 0.22, 0.17, 0.94)
const QUIT_DIALOG_BUTTON_BG_CANCEL := Color(0.35, 0.21, 0.16, 0.86)
const QUIT_DIALOG_BUTTON_BG_CANCEL_HOVER := Color(0.43, 0.26, 0.20, 0.92)
const QUIT_DIALOG_BUTTON_BG_CANCEL_PRESSED := Color(0.24, 0.14, 0.11, 0.94)
const UI_COMPACT_SHORT_EDGE := 640.0
const UI_TINY_SHORT_EDGE := 480.0
const INVENTORY_SLOT_SIZE_DEFAULT := 40.0
const INVENTORY_SLOT_SIZE_COMPACT := 46.0
const INVENTORY_SLOT_SIZE_TINY := 52.0
const MINIMAP_SIZE_DEFAULT := Vector2(180, 120)
const MINIMAP_SIZE_COMPACT := Vector2(152, 100)
const MINIMAP_SIZE_TINY := Vector2(132, 88)
const SIDE_BUTTON_SIZE_DEFAULT := Vector2(84, 38)
const SIDE_BUTTON_SIZE_COMPACT := Vector2(98, 46)
const SIDE_BUTTON_SIZE_TINY := Vector2(112, 52)
const RANK_FLASH_SCALE := 1.34
const RANK_SPARKLE_DURATION := 0.62

var _slot_icons: Array = []
var _slot_labels: Array = []
var _slot_items: Array = []
var _inventory_texture_cache: Dictionary = {}
var _active_touch_drag_id := -1
var _slot_backplates: Dictionary = {}
var _slot_lock_glyphs: Dictionary = {}
var _slot_selection_frames: Dictionary = {}
var _slot_sparkle_rings: Dictionary = {}
var _back_confirm_dialog: ConfirmationDialog = null
var _minimap_drag_locked := false
var _tutorial_toggle_button: Button = null
var _tutorial_continue_button: Button = null
var _tutorial_collapsed := false
var _tutorial_last_visible := false
var _tutorial_last_text := ""
var _selected_inventory_item := ""
var _pointer_is_down := false
var _pointer_is_touch := false
var _pointer_drag_active := false
var _pointer_press_pos := Vector2.ZERO
var _pointer_press_tile_ok := false
var _pointer_press_tile_pos := Vector2.ZERO
var _pointer_press_item := ""
var _pointer_press_selection_changed := false
var _last_pointer_pos := Vector2.ZERO
var _failed_placement_item := ""
var _failed_placement_coord := Vector2i(-1, -1)
var _failed_placement_count := 0
var _story_phase1_sparkle_active := false
var _story_phase5_basket_sparkle_active := false
var _story_phase3_bar_demo_active := false
var _story_phase1_pending_types: Dictionary = {}
var _story_inventory_sparkle_ignore_counts := false
var _story_phase1_sparkle_time := 0.0
var _challenge_loss_instruction_active := false
var _inventory_slot_size := INVENTORY_SLOT_SIZE_DEFAULT
var _inventory_icon_pad_default := INVENTORY_ICON_PAD_DEFAULT
var _inventory_icon_pad_basket := INVENTORY_ICON_PAD_BASKET
var _tutorial_expanded_size := TUTORIAL_PANEL_EXPANDED_SIZE
var _tutorial_expanded_size_base := TUTORIAL_PANEL_EXPANDED_SIZE
var _tutorial_collapsed_size := TUTORIAL_PANEL_COLLAPSED_SIZE
var _story_instruction_phase_id := 0
var _story_phase1_arrow_layer: Node2D = null
var _story_phase1_arrow_lines: Array = []
var _story_phase1_arrow_shadows: Array = []
var _story_phase1_arrow_heads: Array = []
var _story_phase1_arrow_head_shadows: Array = []
var _inventory_side_controls_embedded := false
var _inventory_panel: MarginContainer = null
var _tutorial_panel: Control = null
var _tutorial_label: Label = null
var _tutorial_helper_panel: Panel = null
var _endgame_container: Control = null
var _score_label: Label = null
var _rank_label: Label = null
var _high_score_container: Control = null
var _high_score_value_label: Label = null
var _story_facts_button: Button = null
var _story_facts_panel: Panel = null
var _story_facts_label: Label = null
var _story_facts_close_button: Button = null
var _story_facts_back_button: Button = null
var _story_facts_challenge_button: Button = null
var _story_facts_available := false
var _story_facts_seen_phases: Dictionary = {}
var _story_facts_current_phase := 0
var _story_facts_sparkle_elapsed := 0.0
var _story_facts_sparkle_spawn_elapsed := STORY_FACTS_SPARKLE_INTERVAL
var _last_rank_key := -1
var _rank_flash_tween: Tween = null
var _pause_container_ref: MarginContainer = null
var _quit_container_ref: MarginContainer = null
var _pause_button_ref: Button = null
var _quit_button_ref: Button = null
var _ui_layout_elapsed := 0.0
var _ui_layout_dirty := true
var _last_inventory_rect := Rect2(Vector2.ZERO, Vector2.ZERO)
var _last_tutorial_visible := false
var _last_endgame_visible := false

func _ready() -> void:
	#$PalletContainer2/HBoxContainer/ActiveTexture.texture = Global.active_agent.sprite_texture
	#resContainer = $MarginContainer/HBoxContainer/ResVBoxContainer
	process_mode = Node.PROCESS_MODE_ALWAYS
	inventory_spawn_rng.randomize()
	_ensure_drag_preview()
	_cache_layout_nodes()
	_update_score_rank_display(false)
	_connect_viewport_resize_signal()
	_apply_responsive_layout()
	_flush_layout_updates(true)
	set_pause_state(false)

var clicked_slider = false
var mouseOverMyco = false
var mouseOverSquash = false
var mouseOverBean = false
var mouseOverMaize = false
var mouseOverCloud = false
var mouseOverTree = false



var inventory_labels = {}
var inventory_sprites = {}


func setup():
	_cache_layout_nodes()
	_update_score_rank_display(false)
	_slot_icons = [
		$MarginContainer/VBoxContainer/PalletContainer/VBoxContainer/HBoxContainer/VBoxContainer/ChooseBeans,
		$MarginContainer/VBoxContainer/PalletContainer/VBoxContainer/HBoxContainer/VBoxContainer2/ChooseSquash,
		$MarginContainer/VBoxContainer/PalletContainer/VBoxContainer/HBoxContainer/VBoxContainer3/ChooseMaize,
		$MarginContainer/VBoxContainer/PalletContainer/VBoxContainer/HBoxContainer/VBoxContainer4/ChooseTree,
		$MarginContainer/VBoxContainer/PalletContainer/VBoxContainer/HBoxContainer/VBoxContainer5/ChooseMyco,
		$MarginContainer/VBoxContainer/PalletContainer/VBoxContainer/HBoxContainer/VBoxContainer6/ChooseBasket
	]
	_slot_labels = [
		$MarginContainer/VBoxContainer/PalletContainer/VBoxContainer/HBoxContainer/VBoxContainer/BeanInv,
		$MarginContainer/VBoxContainer/PalletContainer/VBoxContainer/HBoxContainer/VBoxContainer2/SquashInv,
		$MarginContainer/VBoxContainer/PalletContainer/VBoxContainer/HBoxContainer/VBoxContainer3/MaizeInv,
		$MarginContainer/VBoxContainer/PalletContainer/VBoxContainer/HBoxContainer/VBoxContainer4/TreeInv,
		$MarginContainer/VBoxContainer/PalletContainer/VBoxContainer/HBoxContainer/VBoxContainer5/MycoInv,
		$MarginContainer/VBoxContainer/PalletContainer/VBoxContainer/HBoxContainer/VBoxContainer6/BasketInv
	]
	_slot_items = INVENTORY_SLOT_ITEMS.duplicate()
	_ensure_inventory_backplates()
	_ensure_minimap_panel()
	_embed_pause_quit_controls_next_to_minimap()
	_ensure_tutorial_panel_toggle()
	_ensure_tutorial_continue_button()
	_update_minimap_input_lock()
	_set_inventory_tab("farm")
	_apply_responsive_layout()
	# Legacy valuation bars are retained in scene/code but hidden from runtime.
	$MarginContainer/VBoxContainer/HBoxContainer/ResVBoxContainer.visible = false
	$MarginContainer/VBoxContainer/HBoxContainer/ValVBoxContainer.visible = false
	refresh_inventory_counts()
	_flush_layout_updates(true)


func _cache_layout_nodes() -> void:
	_inventory_panel = get_node_or_null("MarginContainer")
	_tutorial_panel = get_node_or_null("TutorialMarginContainer1")
	_tutorial_label = get_node_or_null("TutorialMarginContainer1/Label")
	_tutorial_helper_panel = get_node_or_null("TutorialMarginContainer1/HelperPanel")
	_endgame_container = get_node_or_null("EndGameContainer")
	_score_label = get_node_or_null("EndGameContainer/ScoreVBox/Label")
	if not is_instance_valid(_score_label):
		_score_label = get_node_or_null("EndGameContainer/Label")
	_rank_label = get_node_or_null("EndGameContainer/ScoreVBox/RankLabel")
	_high_score_container = get_node_or_null("HighScoreContainer")
	_high_score_value_label = get_node_or_null("HighScoreContainer/VBoxContainer/ValueLabel")
	_pause_container_ref = find_child("MarginCMarginContainer2ontainer", true, false) as MarginContainer
	_quit_container_ref = find_child("QuitContainer", true, false) as MarginContainer
	_pause_button_ref = find_child("PauseButton", true, false) as Button
	_quit_button_ref = find_child("QuitButton", true, false) as Button
	_ensure_story_facts_button()
	_ensure_story_facts_panel()


func _ensure_minimap_panel() -> void:
	if is_instance_valid(minimap_panel):
		return
	var inventory_vbox = $MarginContainer/VBoxContainer/PalletContainer/VBoxContainer
	var host = CenterContainer.new()
	host.name = "MiniMapHost"
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_FILL
	inventory_vbox.add_child(host)
	minimap_panel = MiniMapPanelRef.new()
	minimap_panel.name = "MiniMapPanel"
	minimap_panel.custom_minimum_size = MINIMAP_SIZE_DEFAULT
	minimap_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	minimap_panel.size_flags_vertical = Control.SIZE_FILL
	host.add_child(minimap_panel)
	minimap_panel.camera_pan_requested.connect(_on_minimap_camera_requested)
	var level_root = get_parent()
	var world = get_node_or_null("../WorldFoundation")
	var agents = get_node_or_null("../Agents")
	minimap_panel.configure(level_root, world, agents)
	_request_layout_update()


func _get_pause_container() -> MarginContainer:
	if is_instance_valid(_pause_container_ref):
		return _pause_container_ref
	_pause_container_ref = find_child("MarginCMarginContainer2ontainer", true, false) as MarginContainer
	return _pause_container_ref


func _get_quit_container() -> MarginContainer:
	if is_instance_valid(_quit_container_ref):
		return _quit_container_ref
	_quit_container_ref = find_child("QuitContainer", true, false) as MarginContainer
	return _quit_container_ref


func _get_pause_button() -> Button:
	if is_instance_valid(_pause_button_ref):
		return _pause_button_ref
	_pause_button_ref = find_child("PauseButton", true, false) as Button
	return _pause_button_ref


func _get_quit_button() -> Button:
	if is_instance_valid(_quit_button_ref):
		return _quit_button_ref
	_quit_button_ref = find_child("QuitButton", true, false) as Button
	return _quit_button_ref


func _embed_pause_quit_controls_next_to_minimap() -> void:
	var inventory_vbox: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/PalletContainer/VBoxContainer")
	if not is_instance_valid(inventory_vbox):
		return
	var row: HBoxContainer = inventory_vbox.get_node_or_null("MiniMapRow")
	if not is_instance_valid(row):
		row = HBoxContainer.new()
		row.name = "MiniMapRow"
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.size_flags_vertical = Control.SIZE_FILL
		row.add_theme_constant_override("separation", 8)
		inventory_vbox.add_child(row)
	var minimap_host: Control = inventory_vbox.get_node_or_null("MiniMapHost")
	var quit_container: MarginContainer = _get_quit_container()
	var pause_container: MarginContainer = _get_pause_container()
	var controls := [quit_container, minimap_host, pause_container]
	for node in controls:
		if not is_instance_valid(node):
			continue
		var parent = node.get_parent()
		if is_instance_valid(parent) and parent != row:
			parent.remove_child(node)
		if node.get_parent() != row:
			row.add_child(node)
	if is_instance_valid(quit_container):
		quit_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
		quit_container.offset_left = 0.0
		quit_container.offset_top = 0.0
		quit_container.offset_right = 0.0
		quit_container.offset_bottom = 0.0
		quit_container.custom_minimum_size = Vector2.ZERO
		quit_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		quit_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.move_child(quit_container, 0)
	if is_instance_valid(minimap_host):
		minimap_host.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		minimap_host.size_flags_vertical = Control.SIZE_FILL
		row.move_child(minimap_host, 1 if is_instance_valid(quit_container) else 0)
	if is_instance_valid(pause_container):
		pause_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
		pause_container.offset_left = 0.0
		pause_container.offset_top = 0.0
		pause_container.offset_right = 0.0
		pause_container.offset_bottom = 0.0
		pause_container.custom_minimum_size = Vector2.ZERO
		pause_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pause_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.move_child(pause_container, row.get_child_count() - 1)
	_inventory_side_controls_embedded = is_instance_valid(minimap_host) and is_instance_valid(quit_container) and is_instance_valid(pause_container)
	_cache_layout_nodes()
	_request_layout_update()


func _is_story_basket_slot_unlocked() -> bool:
	if Global.mode == "story":
		return int(Global.story_chapter_id) >= 5
	if Global.has_method("is_challenge_dual_village_mode"):
		return bool(Global.is_challenge_dual_village_mode())
	return false


func _set_inventory_lock_glyph(icon: TextureRect, show_glyph: bool) -> void:
	if not is_instance_valid(icon):
		return
	var host = _slot_backplates.get(icon, null)
	if not (host is Panel):
		return
	var glyph_label: Label = _slot_lock_glyphs.get(icon, null)
	if not is_instance_valid(glyph_label):
		glyph_label = Label.new()
		glyph_label.name = "LockedGlyph"
		glyph_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph_label.anchors_preset = Control.PRESET_FULL_RECT
		glyph_label.anchor_right = 1.0
		glyph_label.anchor_bottom = 1.0
		glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph_label.z_index = 30
		glyph_label.add_theme_font_size_override("font_size", 24)
		glyph_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
		host.add_child(glyph_label)
		_slot_lock_glyphs[icon] = glyph_label
	glyph_label.z_index = 30
	glyph_label.text = INVENTORY_LOCKED_GLYPH
	glyph_label.visible = show_glyph


func _set_inventory_tab(_tab_id: String = "farm") -> void:
	if _slot_items.size() != INVENTORY_SLOT_ITEMS.size():
		_slot_items = INVENTORY_SLOT_ITEMS.duplicate()
	var basket_unlocked = _is_story_basket_slot_unlocked()
	for idx in range(_slot_icons.size()):
		var icon: TextureRect = _slot_icons[idx]
		var label: Label = _slot_labels[idx]
		if not is_instance_valid(icon) or not is_instance_valid(label):
			continue
		if idx >= _slot_items.size():
			icon.visible = false
			label.visible = false
			continue
		var item = str(_slot_items[idx])
		icon.visible = true
		if idx == INVENTORY_BASKET_SLOT_INDEX and not basket_unlocked:
			icon.texture = null
			icon.modulate = Color(1, 1, 1, 1)
			label.visible = false
			label.text = ""
			if icon.has_meta("item_name"):
				icon.remove_meta("item_name")
			_apply_inventory_icon_slot_layout(icon, "")
			_apply_inventory_backplate_for_item(icon, "")
			_set_inventory_lock_glyph(icon, true)
			continue
		label.visible = true
		icon.texture = _get_inventory_item_texture(item)
		icon.set_meta("item_name", item)
		_apply_inventory_icon_slot_layout(icon, item)
		_apply_inventory_backplate_for_item(icon, item)
		_set_inventory_lock_glyph(icon, false)
	_refresh_inventory_selection_visuals()
	_refresh_inventory_phase1_sparkle_visuals()


func _make_inventory_backplate_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.04, 0.06, 0.10, 0.70)
	return style


func _make_inventory_selection_frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = INVENTORY_SELECTED_OUTLINE_COLOR
	style.expand_margin_left = 3.0
	style.expand_margin_top = 3.0
	style.expand_margin_right = 3.0
	style.expand_margin_bottom = 3.0
	return style


func _make_inventory_sparkle_ring_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = INVENTORY_PHASE1_SPARKLE_COLOR
	style.expand_margin_left = 2.0
	style.expand_margin_top = 2.0
	style.expand_margin_right = 2.0
	style.expand_margin_bottom = 2.0
	return style


func _make_quit_dialog_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = QUIT_DIALOG_PANEL_COLOR
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = QUIT_DIALOG_BORDER_COLOR
	style.shadow_color = QUIT_DIALOG_SHADOW_COLOR
	style.shadow_size = 4
	style.content_margin_left = 16
	style.content_margin_top = 14
	style.content_margin_right = 16
	style.content_margin_bottom = 14
	return style


func _make_quit_dialog_button_style(bg_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = QUIT_DIALOG_BUTTON_BORDER
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	style.shadow_size = 3
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _make_story_instruction_button_style(bg_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.92, 0.98, 0.74, 0.76)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 3
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _make_story_facts_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = STORY_FACTS_PANEL_COLOR
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = STORY_FACTS_PANEL_BORDER
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 5
	style.content_margin_left = 18
	style.content_margin_top = 16
	style.content_margin_right = 18
	style.content_margin_bottom = 16
	return style


func _make_story_facts_button_style(bg_color: Color) -> StyleBoxFlat:
	var style := _make_story_instruction_button_style(bg_color)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_color = STORY_FACTS_PANEL_BORDER
	return style


func _style_story_facts_button(button: Button, bg_color: Color = STORY_FACTS_BUTTON_BG) -> void:
	if not is_instance_valid(button):
		return
	button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	button.add_theme_stylebox_override("normal", _make_story_facts_button_style(bg_color))
	button.add_theme_stylebox_override("hover", _make_story_facts_button_style(STORY_FACTS_BUTTON_BG_HOVER))
	button.add_theme_stylebox_override("pressed", _make_story_facts_button_style(STORY_FACTS_BUTTON_BG_PRESSED))


func _ensure_story_facts_button() -> void:
	if is_instance_valid(_story_facts_button):
		return
	var score_vbox = get_node_or_null("EndGameContainer/ScoreVBox")
	if not is_instance_valid(score_vbox):
		return
	_story_facts_button = Button.new()
	_story_facts_button.name = "StoryFactsButton"
	_story_facts_button.custom_minimum_size = STORY_FACTS_BUTTON_SIZE
	_story_facts_button.focus_mode = Control.FOCUS_NONE
	_story_facts_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_story_facts_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_story_facts_button.visible = false
	_story_facts_button.add_theme_font_size_override("font_size", 16)
	_style_story_facts_button(_story_facts_button)
	_story_facts_button.pressed.connect(_on_story_facts_button_pressed)
	score_vbox.add_child(_story_facts_button)


func _ensure_story_facts_panel() -> void:
	if is_instance_valid(_story_facts_panel):
		return
	_story_facts_panel = Panel.new()
	_story_facts_panel.name = "StoryFactsPanel"
	_story_facts_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_story_facts_panel.z_index = 180
	_story_facts_panel.visible = false
	_story_facts_panel.add_theme_stylebox_override("panel", _make_story_facts_panel_style())
	add_child(_story_facts_panel)

	_story_facts_label = Label.new()
	_story_facts_label.name = "FactsLabel"
	_story_facts_label.process_mode = Node.PROCESS_MODE_ALWAYS
	_story_facts_label.theme_type_variation = "Label"
	_story_facts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_story_facts_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_story_facts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_facts_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_story_facts_label.add_theme_font_size_override("font_size", 18)
	_story_facts_panel.add_child(_story_facts_label)

	_story_facts_close_button = Button.new()
	_story_facts_close_button.name = "CloseButton"
	_story_facts_close_button.text = "X"
	_story_facts_close_button.custom_minimum_size = Vector2(34, 34)
	_story_facts_close_button.focus_mode = Control.FOCUS_NONE
	_story_facts_close_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_story_facts_button(_story_facts_close_button, Color(0.64, 0.18, 0.06, 0.96))
	_story_facts_close_button.pressed.connect(_on_story_facts_close_pressed)
	_story_facts_panel.add_child(_story_facts_close_button)

	_story_facts_back_button = Button.new()
	_story_facts_back_button.name = "BackButton"
	_story_facts_back_button.text = "Back to the Game"
	_story_facts_back_button.custom_minimum_size = Vector2(190, 44)
	_story_facts_back_button.focus_mode = Control.FOCUS_NONE
	_story_facts_back_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_story_facts_button(_story_facts_back_button, Color(0.22, 0.45, 0.20, 0.96))
	_story_facts_back_button.pressed.connect(_on_story_facts_close_pressed)
	_story_facts_panel.add_child(_story_facts_back_button)

	_story_facts_challenge_button = Button.new()
	_story_facts_challenge_button.name = "ChallengeButton"
	_story_facts_challenge_button.text = "Challenge Mode"
	_story_facts_challenge_button.custom_minimum_size = Vector2(190, 44)
	_story_facts_challenge_button.focus_mode = Control.FOCUS_NONE
	_story_facts_challenge_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_story_facts_button(_story_facts_challenge_button, Color(0.22, 0.35, 0.74, 0.96))
	_story_facts_challenge_button.pressed.connect(_on_story_facts_challenge_pressed)
	_story_facts_panel.add_child(_story_facts_challenge_button)
	_layout_story_facts_panel()


func _ensure_slot_sparkle_ring(icon: TextureRect, host: Panel) -> void:
	if not is_instance_valid(icon) or not is_instance_valid(host):
		return
	var ring: Panel = _slot_sparkle_rings.get(icon, null)
	if not is_instance_valid(ring):
		ring = host.get_node_or_null("Phase1SparkleRing")
	if not is_instance_valid(ring):
		ring = Panel.new()
		ring.name = "Phase1SparkleRing"
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.anchors_preset = Control.PRESET_FULL_RECT
		ring.anchor_right = 1.0
		ring.anchor_bottom = 1.0
		ring.offset_left = 0.0
		ring.offset_top = 0.0
		ring.offset_right = 0.0
		ring.offset_bottom = 0.0
		ring.z_index = 10
		host.add_child(ring)
	ring.add_theme_stylebox_override("panel", _make_inventory_sparkle_ring_style())
	ring.visible = false
	ring.modulate = Color(1, 1, 1, 0.0)
	_slot_sparkle_rings[icon] = ring


func _ensure_slot_selection_frame(icon: TextureRect, host: Panel) -> void:
	if not is_instance_valid(icon) or not is_instance_valid(host):
		return
	var frame: Panel = _slot_selection_frames.get(icon, null)
	if not is_instance_valid(frame):
		frame = host.get_node_or_null("SelectionFrame")
	if not is_instance_valid(frame):
		frame = Panel.new()
		frame.name = "SelectionFrame"
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.anchors_preset = Control.PRESET_FULL_RECT
		frame.anchor_right = 1.0
		frame.anchor_bottom = 1.0
		frame.offset_left = 0.0
		frame.offset_top = 0.0
		frame.offset_right = 0.0
		frame.offset_bottom = 0.0
		frame.z_index = 20
		host.add_child(frame)
	frame.add_theme_stylebox_override("panel", _make_inventory_selection_frame_style())
	frame.visible = false
	_slot_selection_frames[icon] = frame


func _refresh_inventory_selection_visuals() -> void:
	for icon in _slot_icons:
		if not is_instance_valid(icon):
			continue
		var frame: Panel = _slot_selection_frames.get(icon, null)
		if not is_instance_valid(frame):
			continue
		if _selected_inventory_item == "":
			frame.visible = false
			continue
		if not icon.visible:
			frame.visible = false
			continue
		if not icon.has_meta("item_name"):
			frame.visible = false
			continue
		var item_name = str(icon.get_meta("item_name"))
		frame.visible = item_name == _selected_inventory_item and int(Global.inventory.get(item_name, 0)) > 0


func _refresh_inventory_phase1_sparkle_visuals() -> void:
	for icon in _slot_icons:
		if not is_instance_valid(icon):
			continue
		var ring: Panel = _slot_sparkle_rings.get(icon, null)
		if not is_instance_valid(ring):
			continue
		ring.visible = false
		ring.modulate = Color(1, 1, 1, 0.0)
		if not icon.visible:
			continue
		if not icon.has_meta("item_name"):
			continue
		var item_name = str(icon.get_meta("item_name"))
		if item_name == "":
			continue
		var item_count = int(Global.inventory.get(item_name, 0))
		if item_count <= 0 and not _story_inventory_sparkle_ignore_counts:
			continue
		var show_phase1 = _story_phase1_sparkle_active and bool(_story_phase1_pending_types.get(item_name, false))
		var show_phase5_basket = _story_phase5_basket_sparkle_active and item_name == "basket"
		ring.visible = show_phase1 or show_phase5_basket


func _update_inventory_phase1_sparkle_animation(delta: float) -> void:
	if not _story_phase1_sparkle_active and not _story_phase5_basket_sparkle_active:
		return
	_story_phase1_sparkle_time += maxf(delta, 0.0)
	for idx in range(_slot_icons.size()):
		var icon: TextureRect = _slot_icons[idx]
		if not is_instance_valid(icon):
			continue
		var ring: Panel = _slot_sparkle_rings.get(icon, null)
		if not is_instance_valid(ring) or not ring.visible:
			continue
		var phase_offset = float(idx) * 0.42
		var pulse = 0.42 + 0.58 * (0.5 + 0.5 * sin(_story_phase1_sparkle_time * INVENTORY_PHASE1_SPARKLE_PULSE_SPEED + phase_offset))
		ring.modulate = Color(1, 1, 1, pulse)


func set_story_inventory_sparkle_targets(phase1_active: bool, phase1_pending_types: Dictionary, phase5_basket_active: bool, ignore_counts: bool = false) -> void:
	_story_phase1_sparkle_active = phase1_active
	_story_phase5_basket_sparkle_active = phase5_basket_active
	_story_inventory_sparkle_ignore_counts = ignore_counts
	_story_phase1_pending_types.clear()
	for key in phase1_pending_types.keys():
		_story_phase1_pending_types[str(key)] = bool(phase1_pending_types[key])
	if not _story_phase1_sparkle_active and not _story_phase5_basket_sparkle_active:
		_story_phase1_sparkle_time = 0.0
		_story_inventory_sparkle_ignore_counts = false
	_refresh_inventory_phase1_sparkle_visuals()


func set_story_phase1_inventory_sparkle_targets(active: bool, pending_types: Dictionary) -> void:
	set_story_inventory_sparkle_targets(active, pending_types, _story_phase5_basket_sparkle_active)


func _ensure_inventory_backplates() -> void:
	_slot_backplates.clear()
	_slot_lock_glyphs.clear()
	_slot_selection_frames.clear()
	_slot_sparkle_rings.clear()
	for icon in _slot_icons:
		if not is_instance_valid(icon):
			continue
		var existing_parent = icon.get_parent()
		if existing_parent is Panel and bool(existing_parent.get_meta("inventory_backplate", false)):
			_slot_backplates[icon] = existing_parent
			_ensure_slot_sparkle_ring(icon, existing_parent)
			_ensure_slot_selection_frame(icon, existing_parent)
			continue
		var host := Panel.new()
		host.name = str(icon.name, "Backplate")
		host.custom_minimum_size = Vector2(40, 40)
		host.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.set_meta("inventory_backplate", true)
		host.add_theme_stylebox_override("panel", _make_inventory_backplate_style(INVENTORY_BACKPLATE_DEFAULT))
		if not is_instance_valid(existing_parent):
			continue
		var insert_index: int = icon.get_index()
		existing_parent.add_child(host)
		existing_parent.move_child(host, insert_index)
		existing_parent.remove_child(icon)
		host.add_child(icon)
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		_apply_inventory_icon_slot_layout(icon, "")
		_slot_backplates[icon] = host
		_ensure_slot_sparkle_ring(icon, host)
		_ensure_slot_selection_frame(icon, host)


func _apply_inventory_icon_slot_layout(icon: TextureRect, item_name: String) -> void:
	if not is_instance_valid(icon):
		return
	var pad := _inventory_icon_pad_default
	if item_name == "basket":
		pad = _inventory_icon_pad_basket
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP
	icon.offset_left = pad
	icon.offset_top = pad
	icon.offset_right = -pad
	icon.offset_bottom = -pad


func _apply_inventory_backplate_for_item(icon: TextureRect, item_name: String) -> void:
	if not is_instance_valid(icon):
		return
	var host = _slot_backplates.get(icon, null)
	if not (host is Panel):
		return
	var base_color: Color = INVENTORY_BACKPLATE_COLORS.get(item_name, INVENTORY_BACKPLATE_DEFAULT)
	host.add_theme_stylebox_override("panel", _make_inventory_backplate_style(base_color))
	_refresh_inventory_selection_visuals()


func _get_inventory_item_texture(item_name: String) -> Texture2D:
	if _inventory_texture_cache.has(item_name):
		return _inventory_texture_cache[item_name]
	var path := ""
	match item_name:
		"bean":
			path = "res://graphics/bean.png"
		"squash":
			path = "res://graphics/squash_32.png"
		"maize":
			path = "res://graphics/maize_32.png"
		"tree":
			path = "res://graphics/acorn_32.png"
		"myco":
			path = "res://graphics/mushroom_32.png"
		"farmer":
			path = "res://graphics/farmer.png"
		"vendor":
			path = "res://graphics/mama.png"
		"cook":
			path = "res://graphics/cook.png"
		"basket":
			path = "res://graphics/basket.png"
		_:
			path = "res://graphics/bean.png"
	var tex = load(path)
	_inventory_texture_cache[item_name] = tex
	return tex


func refresh_inventory_counts() -> void:
	_set_inventory_tab()
	for idx in range(_slot_icons.size()):
		var icon: TextureRect = _slot_icons[idx]
		var label: Label = _slot_labels[idx]
		if not is_instance_valid(icon) or not is_instance_valid(label):
			continue
		var item = str(_slot_items[idx])
		if item == "":
			continue
		if idx == INVENTORY_BASKET_SLOT_INDEX and not _is_story_basket_slot_unlocked():
			continue
		var count = int(Global.inventory.get(item, 0))
		label.text = str(count)
		icon.modulate.a = 1.0 if count > 0 else 0.5
	if _selected_inventory_item != "" and int(Global.inventory.get(_selected_inventory_item, 0)) <= 0:
		_clear_inventory_selection()
		return
	_refresh_inventory_selection_visuals()
	_refresh_inventory_phase1_sparkle_visuals()
	_request_layout_update()


func show_story_instruction(text_value: String, phase_id: int = 0) -> void:
	_cache_layout_nodes()
	_ensure_tutorial_panel_toggle()
	_ensure_tutorial_continue_button()
	_challenge_loss_instruction_active = false
	_story_instruction_phase_id = phase_id
	_sync_story_continue_button_text()
	_apply_responsive_layout()
	if is_instance_valid(_tutorial_label):
		_tutorial_label.text = text_value
	if is_instance_valid(_tutorial_panel):
		_tutorial_panel.visible = true
	_tutorial_collapsed = false
	_tutorial_last_visible = false
	_tutorial_last_text = text_value
	_sync_story_instruction_bar_demo_state()
	_apply_tutorial_panel_state()
	_update_story_instruction_arrows()
	set_pause_state(true)


func show_challenge_loss_instruction(text_value: String) -> void:
	_cache_layout_nodes()
	_ensure_tutorial_panel_toggle()
	_ensure_tutorial_continue_button()
	_challenge_loss_instruction_active = true
	_story_instruction_phase_id = 0
	_sync_story_continue_button_text()
	_apply_responsive_layout()
	if is_instance_valid(_tutorial_label):
		_tutorial_label.text = text_value
	if is_instance_valid(_tutorial_panel):
		_tutorial_panel.visible = true
	_tutorial_collapsed = false
	_tutorial_last_visible = false
	_tutorial_last_text = text_value
	_sync_story_instruction_bar_demo_state()
	_apply_tutorial_panel_state()
	_update_story_instruction_arrows()
	set_pause_state(true)


func _ensure_story_phase1_arrow_overlay() -> void:
	if is_instance_valid(_story_phase1_arrow_layer):
		return
	_story_phase1_arrow_layer = Node2D.new()
	_story_phase1_arrow_layer.name = "StoryPhase1GuideArrows"
	_story_phase1_arrow_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_story_phase1_arrow_layer.z_as_relative = false
	_story_phase1_arrow_layer.z_index = 85
	add_child(_story_phase1_arrow_layer)
	for idx in range(2):
		var shadow := Line2D.new()
		shadow.name = str("ArrowShadow", idx)
		shadow.width = STORY_GUIDE_ARROW_SHADOW_WIDTH
		shadow.default_color = STORY_GUIDE_ARROW_SHADOW_COLOR
		shadow.antialiased = true
		shadow.round_precision = 12
		shadow.visible = false
		_story_phase1_arrow_layer.add_child(shadow)
		_story_phase1_arrow_shadows.append(shadow)

		var line := Line2D.new()
		line.name = str("ArrowLine", idx)
		line.width = STORY_GUIDE_ARROW_WIDTH
		line.default_color = STORY_GUIDE_ARROW_COLOR
		line.antialiased = true
		line.round_precision = 12
		line.visible = false
		_story_phase1_arrow_layer.add_child(line)
		_story_phase1_arrow_lines.append(line)

		var head_shadow := Line2D.new()
		head_shadow.name = str("ArrowHeadShadow", idx)
		head_shadow.width = STORY_GUIDE_ARROW_SHADOW_WIDTH
		head_shadow.default_color = STORY_GUIDE_ARROW_SHADOW_COLOR
		head_shadow.antialiased = true
		head_shadow.round_precision = 12
		head_shadow.visible = false
		_story_phase1_arrow_layer.add_child(head_shadow)
		_story_phase1_arrow_head_shadows.append(head_shadow)

		var head := Line2D.new()
		head.name = str("ArrowHead", idx)
		head.width = STORY_GUIDE_ARROW_WIDTH
		head.default_color = STORY_GUIDE_ARROW_COLOR
		head.antialiased = true
		head.round_precision = 12
		head.visible = false
		_story_phase1_arrow_layer.add_child(head)
		_story_phase1_arrow_heads.append(head)


func _set_story_arrow_visible(index: int, visible: bool) -> void:
	if index < 0 or index >= _story_phase1_arrow_lines.size():
		return
	var line = _story_phase1_arrow_lines[index] as Line2D
	var shadow = _story_phase1_arrow_shadows[index] as Line2D
	var head = _story_phase1_arrow_heads[index] as Line2D
	var head_shadow = _story_phase1_arrow_head_shadows[index] as Line2D
	if is_instance_valid(line):
		line.visible = visible
	if is_instance_valid(shadow):
		shadow.visible = visible
	if is_instance_valid(head):
		head.visible = visible
	if is_instance_valid(head_shadow):
		head_shadow.visible = visible


func _set_all_story_arrows_visible(visible: bool) -> void:
	for idx in range(_story_phase1_arrow_lines.size()):
		_set_story_arrow_visible(idx, visible)


func _sample_story_arrow_curve(start_pos: Vector2, control_pos: Vector2, end_pos: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var segments := 48
	for idx in range(segments + 1):
		var t = (idx * 1.0) / (segments * 1.0)
		var a = start_pos.lerp(control_pos, t)
		var b = control_pos.lerp(end_pos, t)
		points.append(a.lerp(b, t))
	return points


func _make_story_arrow_head_points(tip: Vector2, tail: Vector2, length: float, width: float) -> PackedVector2Array:
	var dir = tip - tail
	if dir.length_squared() <= 0.01:
		dir = Vector2.DOWN
	else:
		dir = dir.normalized()
	var normal = Vector2(-dir.y, dir.x)
	var base = tip - dir * length
	var half_width = width * 0.5
	var points := PackedVector2Array()
	points.append(base + normal * half_width)
	points.append(tip)
	points.append(base - normal * half_width)
	return points


func _set_story_arrow_shape(index: int, start_pos: Vector2, control_pos: Vector2, end_pos: Vector2) -> void:
	if index < 0 or index >= _story_phase1_arrow_lines.size():
		return
	var points = _sample_story_arrow_curve(start_pos, control_pos, end_pos)
	if points.size() < 2:
		_set_story_arrow_visible(index, false)
		return
	var line = _story_phase1_arrow_lines[index] as Line2D
	var shadow = _story_phase1_arrow_shadows[index] as Line2D
	var head = _story_phase1_arrow_heads[index] as Line2D
	var head_shadow = _story_phase1_arrow_head_shadows[index] as Line2D
	var tip = points[points.size() - 1]
	var tail = points[maxi(points.size() - 5, 0)]
	var dir = tip - tail
	if dir.length_squared() <= 0.01:
		dir = Vector2.DOWN
	else:
		dir = dir.normalized()
	var body_points = points.duplicate()
	body_points[body_points.size() - 1] = tip - dir * (STORY_GUIDE_ARROW_HEAD_LENGTH * 0.58)
	if is_instance_valid(line):
		line.points = body_points
	if is_instance_valid(shadow):
		var shadow_points = body_points.duplicate()
		for point_idx in range(shadow_points.size()):
			shadow_points[point_idx] += Vector2(2, 2)
		shadow.points = shadow_points
	if is_instance_valid(head):
		head.points = _make_story_arrow_head_points(tip, tail, STORY_GUIDE_ARROW_HEAD_LENGTH, STORY_GUIDE_ARROW_HEAD_WIDTH)
	if is_instance_valid(head_shadow):
		head_shadow.points = _make_story_arrow_head_points(tip + Vector2(2, 2), tail + Vector2(2, 2), STORY_GUIDE_ARROW_HEAD_LENGTH + 4.0, STORY_GUIDE_ARROW_HEAD_WIDTH + 5.0)
	_set_story_arrow_visible(index, true)


func _get_phase1_garden_arrow_target() -> Vector2:
	var garden_agent = Global.active_agent
	if is_instance_valid(garden_agent):
		return _world_to_screen(garden_agent.global_position) + Vector2(0, -18)
	var view_size = get_viewport().get_visible_rect().size
	return view_size * 0.5


func _get_phase1_inventory_arrow_target() -> Vector2:
	if is_instance_valid(_inventory_panel):
		var inventory_rect = _inventory_panel.get_global_rect()
		return Vector2(inventory_rect.position.x + inventory_rect.size.x * 0.5, inventory_rect.position.y - 2.0)
	return Vector2(80, 120)


func _get_inventory_item_arrow_target(agent_name: String, gap_px: float = 2.0) -> Vector2:
	for icon in _slot_icons:
		if not is_instance_valid(icon):
			continue
		if not icon.visible:
			continue
		if not icon.has_meta("item_name"):
			continue
		if str(icon.get_meta("item_name")) != agent_name:
			continue
		var icon_rect = icon.get_global_rect()
		return Vector2(icon_rect.position.x + icon_rect.size.x * 0.5, icon_rect.position.y - gap_px)
	return get_inventory_icon_center(agent_name)


func _should_show_story_instruction_arrows() -> bool:
	return (_story_instruction_phase_id == 1 or _story_instruction_phase_id == 2 or _story_instruction_phase_id == 3 or _story_instruction_phase_id == 5) and _is_story_instruction_mode() and is_instance_valid(_tutorial_panel) and _tutorial_panel.visible and not _tutorial_collapsed


func _get_phase2_harvest_arrow_target() -> Dictionary:
	var agents_root = _get_agents_root()
	var screen_rect = get_viewport().get_visible_rect()
	if is_instance_valid(agents_root):
		for agent in agents_root.get_children():
			if not is_instance_valid(agent):
				continue
			var ring = agent.get_node_or_null("StoryPhase2HarvestRing") as Line2D
			if not is_instance_valid(ring) or not ring.visible:
				continue
			var screen_pos = _world_to_screen(agent.global_position)
			if not screen_rect.has_point(screen_pos):
				continue
			return {
				"ok": true,
				"pos": screen_pos + Vector2(0, -18)
			}
	return {
		"ok": false,
		"pos": Vector2.ZERO
	}


func _get_phase3_minimap_arrow_target() -> Dictionary:
	if is_instance_valid(minimap_panel) and minimap_panel.has_method("get_village_marker_screen_position"):
		var result = minimap_panel.call("get_village_marker_screen_position")
		if typeof(result) == TYPE_DICTIONARY:
			return result
	return {
		"ok": false,
		"pos": Vector2.ZERO
	}


func _get_phase3_resource_bar_arrow_target() -> Dictionary:
	var agents_root = _get_agents_root()
	var screen_rect = get_viewport().get_visible_rect()
	if not is_instance_valid(agents_root):
		return {
			"ok": false,
			"pos": Vector2.ZERO
		}
	for agent in agents_root.get_children():
		if not is_instance_valid(agent):
			continue
		var agent_type = str(agent.get("type"))
		var is_plant_bar_target = ["bean", "squash", "maize", "tree", "myco"].has(agent_type)
		if not is_plant_bar_target:
			continue
		var screen_pos = _world_to_screen(agent.global_position)
		if not screen_rect.grow(48.0).has_point(screen_pos):
			continue
		var canvas = agent.get("bar_canvas")
		if not is_instance_valid(canvas) or not canvas.visible:
			continue
		var bars_variant = agent.get("bars")
		if typeof(bars_variant) != TYPE_DICTIONARY:
			continue
		var bars: Dictionary = bars_variant
		for resource in ["N", "P", "K", "R"]:
			var bar = bars.get(resource, null)
			var bar_control: Control = bar as Control
			if is_instance_valid(bar_control) and bar_control.visible:
				return {
					"ok": true,
					"pos": bar_control.get_global_rect().get_center()
				}
	return {
		"ok": false,
		"pos": Vector2.ZERO
	}


func _get_phase5_nontrading_villagers_arrow_target() -> Dictionary:
	var level_root = get_parent()
	if not is_instance_valid(level_root) or not level_root.has_method("get_story_phase5_nontrading_lower_villagers_center_world"):
		return {
			"ok": false,
			"pos": Vector2.ZERO
		}
	var result = level_root.call("get_story_phase5_nontrading_lower_villagers_center_world")
	if typeof(result) != TYPE_DICTIONARY or not bool(result.get("ok", false)):
		return {
			"ok": false,
			"pos": Vector2.ZERO
		}
	var screen_pos = _world_to_screen(result.get("pos", Vector2.ZERO))
	return {
		"ok": true,
		"pos": screen_pos
	}


func _update_story_instruction_arrows() -> void:
	if not _should_show_story_instruction_arrows():
		if is_instance_valid(_story_phase1_arrow_layer):
			_set_all_story_arrows_visible(false)
		return
	_ensure_story_phase1_arrow_overlay()
	if not is_instance_valid(_tutorial_panel):
		_set_all_story_arrows_visible(false)
		return
	var panel_rect = _tutorial_panel.get_global_rect()
	var label_rect = _tutorial_label.get_global_rect() if is_instance_valid(_tutorial_label) else panel_rect
	if _story_instruction_phase_id == 2:
		var target_result = _get_phase2_harvest_arrow_target()
		if not bool(target_result.get("ok", false)):
			_set_all_story_arrows_visible(false)
			return
		var harvest_target = target_result.get("pos", Vector2.ZERO)
		var harvest_start = Vector2(label_rect.position.x + label_rect.size.x + 10.0, label_rect.position.y + label_rect.size.y * 0.34)
		var harvest_control = (harvest_start + harvest_target) * 0.5 + Vector2(116.0, 74.0)
		_set_story_arrow_shape(0, harvest_start, harvest_control, harvest_target)
		_set_story_arrow_visible(1, false)
		return
	if _story_instruction_phase_id == 3:
		var minimap_result = _get_phase3_minimap_arrow_target()
		if bool(minimap_result.get("ok", false)):
			var minimap_target = minimap_result.get("pos", Vector2.ZERO)
			var minimap_dir = (minimap_target - label_rect.get_center()).normalized()
			var minimap_tip = minimap_target - minimap_dir * 28.0
			var minimap_start = Vector2(label_rect.position.x + label_rect.size.x + 14.0, label_rect.position.y + label_rect.size.y * 0.36)
			var minimap_control = (minimap_start + minimap_tip) * 0.5 + Vector2(108.0, 82.0)
			_set_story_arrow_shape(0, minimap_start, minimap_control, minimap_tip)
		else:
			_set_story_arrow_visible(0, false)
		var bar_result = _get_phase3_resource_bar_arrow_target()
		if bool(bar_result.get("ok", false)):
			var bar_target = bar_result.get("pos", Vector2.ZERO)
			var bar_start = Vector2(label_rect.position.x - 14.0, label_rect.position.y + label_rect.size.y * 0.62)
			var bar_control = (bar_start + bar_target) * 0.5 + Vector2(-96.0, -58.0)
			_set_story_arrow_shape(1, bar_start, bar_control, bar_target)
		else:
			_set_story_arrow_visible(1, false)
		return
	if _story_instruction_phase_id == 5:
		var basket_target = _get_inventory_item_arrow_target("basket", 18.0)
		var basket_start = Vector2(label_rect.position.x + label_rect.size.x + 12.0, label_rect.position.y + label_rect.size.y * 0.55)
		var basket_control = (basket_start + basket_target) * 0.5 + Vector2(96.0, 72.0)
		_set_story_arrow_shape(0, basket_start, basket_control, basket_target)
		var villager_result = _get_phase5_nontrading_villagers_arrow_target()
		if bool(villager_result.get("ok", false)):
			var villager_target = villager_result.get("pos", Vector2.ZERO)
			var villager_start = Vector2(label_rect.position.x + label_rect.size.x * 0.54, label_rect.position.y + label_rect.size.y + 10.0)
			var villager_control = (villager_start + villager_target) * 0.5 + Vector2(-86.0, 92.0)
			_set_story_arrow_shape(1, villager_start, villager_control, villager_target)
		else:
			_set_story_arrow_visible(1, false)
		return
	var garden_target = _get_phase1_garden_arrow_target()
	var inventory_target = _get_phase1_inventory_arrow_target()

	var garden_start = Vector2(label_rect.position.x + label_rect.size.x + 10.0, label_rect.position.y + label_rect.size.y * 0.24)
	var garden_control = (garden_start + garden_target) * 0.5 + Vector2(112.0, 74.0)
	_set_story_arrow_shape(0, garden_start, garden_control, garden_target)

	var inventory_start = Vector2(label_rect.position.x + 12.0, label_rect.position.y + label_rect.size.y * 0.50)
	var inventory_control = (inventory_start + inventory_target) * 0.5 + Vector2(-126.0, 82.0)
	_set_story_arrow_shape(1, inventory_start, inventory_control, inventory_target)


func _connect_viewport_resize_signal() -> void:
	var viewport = get_viewport()
	if not is_instance_valid(viewport):
		return
	if viewport.size_changed.is_connected(_on_viewport_size_changed):
		return
	viewport.size_changed.connect(_on_viewport_size_changed)


func _on_viewport_size_changed() -> void:
	_cache_layout_nodes()
	_apply_responsive_layout()
	_request_layout_update()
	_flush_layout_updates(true)


func _request_layout_update() -> void:
	_ui_layout_dirty = true


func _detect_layout_state_change() -> bool:
	var changed := false
	if is_instance_valid(_inventory_panel):
		var inventory_rect = _inventory_panel.get_global_rect()
		if inventory_rect != _last_inventory_rect:
			_last_inventory_rect = inventory_rect
			changed = true
	elif _last_inventory_rect.size != Vector2.ZERO:
		_last_inventory_rect = Rect2(Vector2.ZERO, Vector2.ZERO)
		changed = true
	var tutorial_visible = is_instance_valid(_tutorial_panel) and _tutorial_panel.visible
	if tutorial_visible != _last_tutorial_visible:
		_last_tutorial_visible = tutorial_visible
		changed = true
	var endgame_visible = is_instance_valid(_endgame_container) and _endgame_container.visible
	if endgame_visible != _last_endgame_visible:
		_last_endgame_visible = endgame_visible
		changed = true
	return changed


func _apply_runtime_layout(force: bool = false) -> void:
	if not force and not _ui_layout_dirty:
		return
	_layout_quit_container()
	_layout_tutorial_container()
	_layout_story_facts_panel()
	_position_tutorial_toggle()
	_ui_layout_dirty = false


func _flush_layout_updates(force: bool = false) -> void:
	_ui_layout_elapsed = 0.0
	_apply_runtime_layout(force or _ui_layout_dirty)


func _update_layout_pass(delta: float) -> void:
	var geometry_changed = _detect_layout_state_change()
	if not Global.ui_layout_cadence_enabled:
		_apply_runtime_layout(true)
		return
	_ui_layout_elapsed += maxf(delta, 0.0)
	var interval = maxf(Global.get_ui_layout_refresh_interval(), 0.016)
	if geometry_changed or _ui_layout_dirty or _ui_layout_elapsed >= interval:
		_apply_runtime_layout(geometry_changed or _ui_layout_dirty)
		_ui_layout_elapsed = 0.0


func _estimate_wrapped_line_count(text_value: String, approx_chars_per_line: int) -> int:
	var safe_chars = maxi(approx_chars_per_line, 1)
	var total_lines = 0
	for line in text_value.split("\n", true):
		var line_len = line.length()
		if line_len <= 0:
			total_lines += 1
			continue
		total_lines += int(ceil(float(line_len) / float(safe_chars)))
	return maxi(total_lines, 1)


func _update_tutorial_expanded_size_for_text() -> void:
	var tutorial: Control = _tutorial_panel
	var label: Label = _tutorial_label
	if not is_instance_valid(tutorial) or not is_instance_valid(label):
		return
	var text_value := str(label.text)
	if text_value.strip_edges() == "":
		_tutorial_expanded_size = _tutorial_expanded_size_base
		return
	var font_size = label.get_theme_font_size("font_size")
	if font_size <= 0:
		font_size = 16
	var line_height = float(font_size) * 1.25
	if label.has_method("get_line_height"):
		var measured_height = float(label.call("get_line_height"))
		if measured_height > 0.0:
			line_height = measured_height
	var width_for_text = maxf(_tutorial_expanded_size_base.x - TUTORIAL_LABEL_HORIZONTAL_PADDING, 120.0)
	var approx_chars_per_line = maxi(int(floor(width_for_text / maxf(float(font_size) * 0.58, 6.0))), 8)
	var explicit_lines = maxi(text_value.count("\n") + 1, 1)
	var measured_lines = 0
	if label.has_method("get_line_count"):
		measured_lines = maxi(int(label.call("get_line_count")), 0)
	var wrapped_lines = _estimate_wrapped_line_count(text_value, approx_chars_per_line)
	var effective_lines = maxi(maxi(explicit_lines, measured_lines), wrapped_lines)
	var text_height = float(effective_lines) * line_height
	var vertical_padding = TUTORIAL_PANEL_STORY_TEXT_VERTICAL_PADDING if _is_guidance_instruction_mode() else TUTORIAL_PANEL_TEXT_VERTICAL_PADDING
	var target_height = maxf(_tutorial_expanded_size_base.y, text_height + vertical_padding)
	var max_height = maxf(get_viewport().get_visible_rect().size.y * TUTORIAL_PANEL_MAX_HEIGHT_FRACTION, _tutorial_expanded_size_base.y)
	_tutorial_expanded_size = Vector2(_tutorial_expanded_size_base.x, clampf(target_height, _tutorial_expanded_size_base.y, max_height))


func _is_compact_ui() -> bool:
	var view_size = get_viewport().get_visible_rect().size
	return Global.is_mobile_platform or minf(view_size.x, view_size.y) <= UI_COMPACT_SHORT_EDGE


func _is_tiny_ui() -> bool:
	var view_size = get_viewport().get_visible_rect().size
	return minf(view_size.x, view_size.y) <= UI_TINY_SHORT_EDGE


func _is_story_instruction_mode() -> bool:
	return str(Global.mode) == "story"


func _is_guidance_instruction_mode() -> bool:
	return _is_story_instruction_mode() or _challenge_loss_instruction_active


func _apply_responsive_layout() -> void:
	var view_rect = get_viewport().get_visible_rect()
	var view_size = view_rect.size
	var compact = _is_compact_ui()
	var tiny = _is_tiny_ui()
	var story_instructions = _is_guidance_instruction_mode()
	var inventory: MarginContainer = _inventory_panel
	if is_instance_valid(inventory):
		var margin_px = 10 if compact else 14
		inventory.add_theme_constant_override("margin_left", margin_px)
		inventory.add_theme_constant_override("margin_top", margin_px)
		inventory.add_theme_constant_override("margin_right", margin_px)
		inventory.add_theme_constant_override("margin_bottom", margin_px)
		var panel_width = clampf(view_size.x * 0.36, 200.0, 292.0)
		inventory.offset_left = -round(panel_width * 0.5)
		inventory.offset_right = round(panel_width * 0.5)
		inventory.offset_top = -178.0 if compact else -159.0
	_inventory_slot_size = INVENTORY_SLOT_SIZE_TINY if tiny else (INVENTORY_SLOT_SIZE_COMPACT if compact else INVENTORY_SLOT_SIZE_DEFAULT)
	_inventory_icon_pad_default = 6.0 if tiny else (5.0 if compact else INVENTORY_ICON_PAD_DEFAULT)
	_inventory_icon_pad_basket = 9.0 if tiny else (8.0 if compact else INVENTORY_ICON_PAD_BASKET)
	for icon in _slot_icons:
		if not is_instance_valid(icon):
			continue
		var host = _slot_backplates.get(icon, null)
		if host is Panel:
			host.custom_minimum_size = Vector2(_inventory_slot_size, _inventory_slot_size)
		var item_name = str(icon.get_meta("item_name", ""))
		_apply_inventory_icon_slot_layout(icon, item_name)
	for label in _slot_labels:
		if not is_instance_valid(label):
			continue
		label.add_theme_font_size_override("font_size", 19 if tiny else (17 if compact else 15))
	for glyph in _slot_lock_glyphs.values():
		if glyph is Label:
			glyph.add_theme_font_size_override("font_size", 28 if tiny else (26 if compact else 24))
	if is_instance_valid(minimap_panel):
		minimap_panel.custom_minimum_size = MINIMAP_SIZE_TINY if tiny else (MINIMAP_SIZE_COMPACT if compact else MINIMAP_SIZE_DEFAULT)
	var minimap_row: HBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/PalletContainer/VBoxContainer/MiniMapRow")
	if is_instance_valid(minimap_row):
		minimap_row.add_theme_constant_override("separation", 12 if compact else 8)
	var tutorial_label: Label = _tutorial_label
	if is_instance_valid(tutorial_label):
		tutorial_label.add_theme_font_size_override("font_size", 19 if tiny else (18 if compact else 17))
		tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tutorial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tutorial_label.offset_left = 24.0 if story_instructions else 16.0
		tutorial_label.offset_top = 20.0 if story_instructions else 14.0
		tutorial_label.offset_right = -24.0 if story_instructions else -18.0
		tutorial_label.offset_bottom = -66.0 if story_instructions else -18.0
	var max_expanded_width = STORY_TUTORIAL_PANEL_EXPANDED_SIZE.x if story_instructions else TUTORIAL_PANEL_EXPANDED_SIZE.x
	var min_expanded_width = 300.0 if story_instructions else 248.0
	var expanded_width = minf(max_expanded_width, maxf(view_size.x - 24.0, min_expanded_width))
	var expanded_height = 188.0 if tiny else (182.0 if compact else TUTORIAL_PANEL_EXPANDED_SIZE.y)
	if story_instructions:
		expanded_height = 226.0 if tiny else (238.0 if compact else STORY_TUTORIAL_PANEL_EXPANDED_SIZE.y)
	_tutorial_expanded_size_base = Vector2(expanded_width, expanded_height)
	_tutorial_expanded_size = _tutorial_expanded_size_base
	_tutorial_collapsed_size = Vector2(52, 52) if compact else TUTORIAL_PANEL_COLLAPSED_SIZE
	if is_instance_valid(_tutorial_toggle_button):
		_tutorial_toggle_button.custom_minimum_size = Vector2(38, 38) if tiny else (Vector2(34, 34) if compact else Vector2(28, 28))
		_tutorial_toggle_button.add_theme_font_size_override("font_size", 18 if compact else 14)
	if is_instance_valid(_tutorial_continue_button):
		var continue_size = Vector2(150, 44) if compact else STORY_TUTORIAL_CONTINUE_BUTTON_SIZE
		if tiny:
			continue_size = Vector2(154, 46)
		if _story_instruction_phase_id == 6:
			continue_size = Vector2(226, 48) if compact else STORY_TUTORIAL_CHALLENGE_BUTTON_SIZE
			if tiny:
				continue_size = Vector2(232, 50)
		if _challenge_loss_instruction_active:
			continue_size = Vector2(174, 46) if compact else Vector2(164, 42)
			if tiny:
				continue_size = Vector2(188, 48)
		_tutorial_continue_button.custom_minimum_size = continue_size
		_tutorial_continue_button.size = continue_size
		_tutorial_continue_button.anchor_left = 0.5
		_tutorial_continue_button.anchor_right = 0.5
		_tutorial_continue_button.anchor_top = 1.0
		_tutorial_continue_button.anchor_bottom = 1.0
		_tutorial_continue_button.offset_left = -continue_size.x * 0.5
		_tutorial_continue_button.offset_right = continue_size.x * 0.5
		_tutorial_continue_button.offset_top = -continue_size.y - 12.0
		_tutorial_continue_button.offset_bottom = -12.0
		_tutorial_continue_button.add_theme_font_size_override("font_size", 18 if compact else 16)
	if is_instance_valid(_story_facts_button):
		_story_facts_button.custom_minimum_size = Vector2(214, 48) if compact else STORY_FACTS_BUTTON_SIZE
		_story_facts_button.add_theme_font_size_override("font_size", 18 if compact else 16)
	var pause_button: Button = _get_pause_button()
	var quit_button: Button = _get_quit_button()
	var pause_size = SIDE_BUTTON_SIZE_TINY if tiny else (SIDE_BUTTON_SIZE_COMPACT if compact else SIDE_BUTTON_SIZE_DEFAULT)
	for button in [pause_button, quit_button]:
		if not is_instance_valid(button):
			continue
		button.custom_minimum_size = pause_size
		button.add_theme_font_size_override("font_size", 18 if compact else 14)
	_apply_tutorial_panel_state()


func get_inventory_icon_center(agent_name: String) -> Vector2:
	for icon in _slot_icons:
		if not is_instance_valid(icon):
			continue
		if not icon.visible:
			continue
		if not icon.has_meta("item_name"):
			continue
		if str(icon.get_meta("item_name")) != agent_name:
			continue
		var icon_rect = icon.get_global_rect()
		return icon_rect.position + icon_rect.size * 0.5
	if is_instance_valid(_inventory_panel):
		var panel_rect = _inventory_panel.get_global_rect()
		return panel_rect.position + panel_rect.size * 0.5
	return get_viewport().get_visible_rect().size * 0.5


func refund_inventory_item(agent_name: String, amount: int = 1) -> void:
	if agent_name == "":
		return
	var safe_amount = maxi(amount, 0)
	if safe_amount <= 0:
		return
	Global.inventory[agent_name] = int(Global.inventory.get(agent_name, 0)) + safe_amount
	refresh_inventory_counts()



func _process(delta: float) -> void:
	_update_minimap_input_lock()
	_update_inventory_phase1_sparkle_animation(delta)
	_update_story_facts_button_sparkle(delta)
	_update_selected_inventory_hover_hint()
	_refresh_tutorial_panel_state()
	_update_layout_pass(delta)
	_update_story_instruction_arrows()


func _update_minimap_input_lock() -> void:
	if not is_instance_valid(minimap_panel):
		_minimap_drag_locked = false
		return
	var should_lock = Global.is_dragging or _selected_inventory_item != ""
	if should_lock == _minimap_drag_locked:
		return
	_minimap_drag_locked = should_lock
	if minimap_panel.has_method("set_input_enabled"):
		minimap_panel.call("set_input_enabled", not should_lock)


func _refresh_agent_bar_visibility() -> void:
	var agents_root = _get_agents_root()
	if is_instance_valid(agents_root):
		LevelHelpersRef.refresh_agent_bar_visibility(agents_root)


func _sync_story_instruction_bar_demo_state() -> void:
	var should_show = _story_instruction_phase_id == 3 and _is_story_instruction_mode() and is_instance_valid(_tutorial_panel) and _tutorial_panel.visible and not _tutorial_collapsed
	if should_show == _story_phase3_bar_demo_active:
		return
	_story_phase3_bar_demo_active = should_show
	Global.story_force_visible_plant_bars = should_show
	if not should_show:
		var agents_root = _get_agents_root()
		if is_instance_valid(agents_root):
			LevelHelpersRef.clear_selection_and_bars(get_parent(), agents_root)
			return
		Global.bars_on = false
	_refresh_agent_bar_visibility()


func _suppress_minimap_input_handoff() -> void:
	if is_instance_valid(minimap_panel) and minimap_panel.has_method("suppress_input"):
		minimap_panel.call("suppress_input", 0.30)
	var world = _get_world_foundation()
	if is_instance_valid(world) and world.has_method("suppress_camera_pan_input"):
		world.call("suppress_camera_pan_input", 0.30)


func _ensure_tutorial_panel_toggle() -> void:
	var tutorial = _tutorial_panel
	if not is_instance_valid(tutorial):
		return
	tutorial.clip_contents = true
	tutorial.process_mode = Node.PROCESS_MODE_ALWAYS
	if not is_instance_valid(_tutorial_toggle_button):
		_tutorial_toggle_button = Button.new()
		_tutorial_toggle_button.name = "ToggleButton"
		_tutorial_toggle_button.text = "X"
		_tutorial_toggle_button.custom_minimum_size = Vector2(28, 28)
		_tutorial_toggle_button.focus_mode = Control.FOCUS_NONE
		_tutorial_toggle_button.process_mode = Node.PROCESS_MODE_ALWAYS
		_tutorial_toggle_button.z_as_relative = false
		_tutorial_toggle_button.z_index = 120
		_tutorial_toggle_button.add_theme_font_size_override("font_size", 14)
		_tutorial_toggle_button.pressed.connect(_on_tutorial_toggle_pressed)
		add_child(_tutorial_toggle_button)
		_request_layout_update()
	_apply_tutorial_panel_state()


func _ensure_tutorial_continue_button() -> void:
	var tutorial = _tutorial_panel
	if not is_instance_valid(tutorial):
		return
	if not is_instance_valid(_tutorial_continue_button):
		_tutorial_continue_button = Button.new()
		_tutorial_continue_button.name = "ContinueButton"
		_tutorial_continue_button.text = STORY_TUTORIAL_CONTINUE_TEXT
		_tutorial_continue_button.focus_mode = Control.FOCUS_NONE
		_tutorial_continue_button.process_mode = Node.PROCESS_MODE_ALWAYS
		_tutorial_continue_button.z_index = 40
		_tutorial_continue_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_tutorial_continue_button.pressed.connect(_on_tutorial_continue_pressed)
		tutorial.add_child(_tutorial_continue_button)
	_tutorial_continue_button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_tutorial_continue_button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	_tutorial_continue_button.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	_tutorial_continue_button.add_theme_stylebox_override("normal", _make_story_instruction_button_style(Color(0.18, 0.45, 0.20, 0.96)))
	_tutorial_continue_button.add_theme_stylebox_override("hover", _make_story_instruction_button_style(Color(0.24, 0.55, 0.24, 0.98)))
	_tutorial_continue_button.add_theme_stylebox_override("pressed", _make_story_instruction_button_style(Color(0.12, 0.33, 0.15, 1.0)))
	_tutorial_continue_button.visible = false
	_request_layout_update()


func _sync_story_continue_button_text() -> void:
	if not is_instance_valid(_tutorial_continue_button):
		return
	if _challenge_loss_instruction_active:
		_tutorial_continue_button.text = CHALLENGE_LOSS_CONTINUE_TEXT
		return
	_tutorial_continue_button.text = STORY_TUTORIAL_CHALLENGE_TEXT if _story_instruction_phase_id == 6 else STORY_TUTORIAL_CONTINUE_TEXT


func _set_tutorial_collapsed(collapsed: bool) -> void:
	if _tutorial_collapsed == collapsed:
		return
	_tutorial_collapsed = collapsed
	_apply_tutorial_panel_state()


func _apply_tutorial_panel_state() -> void:
	var tutorial = _tutorial_panel
	if not is_instance_valid(tutorial):
		return
	var label: Label = _tutorial_label
	var helper_panel: Panel = _tutorial_helper_panel
	var content_visible = not _tutorial_collapsed
	if is_instance_valid(label):
		label.visible = content_visible
	if is_instance_valid(helper_panel):
		helper_panel.visible = content_visible
	if is_instance_valid(_tutorial_continue_button):
		_sync_story_continue_button_text()
		_tutorial_continue_button.visible = content_visible and _is_guidance_instruction_mode()
	if not _tutorial_collapsed:
		_update_tutorial_expanded_size_for_text()
	var target_size = _tutorial_collapsed_size if _tutorial_collapsed else _tutorial_expanded_size
	tutorial.custom_minimum_size = target_size
	tutorial.size = target_size
	if is_instance_valid(_tutorial_toggle_button):
		_tutorial_toggle_button.text = "i" if _tutorial_collapsed else "X"
		_tutorial_toggle_button.visible = tutorial.visible
	_request_layout_update()
	_flush_layout_updates(true)
	_sync_story_instruction_bar_demo_state()
	_update_story_instruction_arrows()


func _position_tutorial_toggle() -> void:
	if not is_instance_valid(_tutorial_toggle_button):
		return
	var tutorial = _tutorial_panel
	if not is_instance_valid(tutorial) or not tutorial.visible:
		_tutorial_toggle_button.visible = false
		return
	_tutorial_toggle_button.visible = true
	var rect = tutorial.get_global_rect()
	var btn_size = _tutorial_toggle_button.custom_minimum_size
	var pad := 2.0
	_tutorial_toggle_button.global_position = Vector2(
		rect.position.x + rect.size.x - btn_size.x - pad,
		rect.position.y + rect.size.y - btn_size.y - pad
	)


func _layout_quit_container() -> void:
	if _inventory_side_controls_embedded:
		return
	var quit_container: MarginContainer = _get_quit_container()
	var pause_container: MarginContainer = _get_pause_container()
	var inventory_panel: MarginContainer = _inventory_panel
	if not is_instance_valid(inventory_panel):
		return
	var inventory_rect = inventory_panel.get_global_rect()
	var center_y = inventory_rect.position.y + inventory_rect.size.y * 0.5
	if is_instance_valid(quit_container):
		var quit_size = quit_container.size
		if quit_size.x <= 0.0 or quit_size.y <= 0.0:
			quit_size = quit_container.custom_minimum_size
		if quit_size.x <= 0.0:
			quit_size.x = 96.0
		if quit_size.y <= 0.0:
			quit_size.y = 44.0
		quit_container.global_position = Vector2(
			round(inventory_rect.position.x - INVENTORY_SIDE_BUTTON_BUFFER - quit_size.x),
			round(center_y - quit_size.y * 0.5)
		)
	if is_instance_valid(pause_container):
		var pause_size = pause_container.size
		if pause_size.x <= 0.0 or pause_size.y <= 0.0:
			pause_size = pause_container.custom_minimum_size
		if pause_size.x <= 0.0:
			pause_size.x = 96.0
		if pause_size.y <= 0.0:
			pause_size.y = 44.0
		pause_container.global_position = Vector2(
			round(inventory_rect.position.x + inventory_rect.size.x + INVENTORY_SIDE_BUTTON_BUFFER),
			round(center_y - pause_size.y * 0.5)
		)


func _layout_tutorial_container() -> void:
	var tutorial: Control = _tutorial_panel
	if not is_instance_valid(tutorial) or not tutorial.visible:
		return
	var view_rect = get_viewport().get_visible_rect()
	var size = tutorial.size
	if size.x <= 0.0 or size.y <= 0.0:
		size = tutorial.custom_minimum_size
	if size.x <= 0.0 or size.y <= 0.0:
		size = _tutorial_collapsed_size if _tutorial_collapsed else _tutorial_expanded_size
	var margin := 12.0
	if _tutorial_collapsed:
		if is_instance_valid(_high_score_container) and _high_score_container.visible:
			var high_score_rect = _high_score_container.get_global_rect()
			margin = maxf(margin, high_score_rect.position.y + high_score_rect.size.y + 8.0)
		tutorial.global_position = Vector2(
			round(view_rect.position.x + 12.0),
			round(view_rect.position.y + margin)
		)
		return
	var top_y := 16.0
	var score_container: Control = _endgame_container
	if is_instance_valid(score_container) and score_container.visible:
		var score_rect = score_container.get_global_rect()
		top_y = score_rect.position.y + score_rect.size.y + 12.0
	if is_instance_valid(_high_score_container) and _high_score_container.visible:
		var high_score_rect = _high_score_container.get_global_rect()
		top_y = maxf(top_y, high_score_rect.position.y + high_score_rect.size.y + 12.0)
	var x = view_rect.position.x + (view_rect.size.x - size.x) * 0.5
	x = clampf(x, view_rect.position.x + margin, view_rect.position.x + view_rect.size.x - size.x - margin)
	var y = maxf(top_y, view_rect.position.y + margin)
	tutorial.global_position = Vector2(round(x), round(y))


func _layout_story_facts_panel() -> void:
	if not is_instance_valid(_story_facts_panel):
		return
	var view_rect = get_viewport().get_visible_rect()
	var compact = _is_compact_ui()
	var tiny = _is_tiny_ui()
	var panel_size = STORY_FACTS_PANEL_SIZE
	panel_size.x = minf(panel_size.x, maxf(view_rect.size.x - 28.0, 300.0))
	panel_size.y = minf(panel_size.y, maxf(view_rect.size.y - 28.0, 260.0))
	if compact:
		panel_size = Vector2(minf(panel_size.x, view_rect.size.x - 24.0), minf(panel_size.y, view_rect.size.y - 24.0))
	_story_facts_panel.custom_minimum_size = panel_size
	_story_facts_panel.size = panel_size
	_story_facts_panel.global_position = Vector2(
		round(view_rect.position.x + (view_rect.size.x - panel_size.x) * 0.5),
		round(view_rect.position.y + (view_rect.size.y - panel_size.y) * 0.5)
	)

	if is_instance_valid(_story_facts_close_button):
		var close_size = Vector2(38, 38) if compact else Vector2(34, 34)
		_story_facts_close_button.custom_minimum_size = close_size
		_story_facts_close_button.size = close_size
		_story_facts_close_button.position = Vector2(panel_size.x - close_size.x - 10.0, 10.0)
		_story_facts_close_button.add_theme_font_size_override("font_size", 18 if compact else 16)

	var bottom_button_size = Vector2(204, 46) if compact else Vector2(190, 44)
	if tiny:
		bottom_button_size = Vector2(212, 48)
	var show_challenge = _story_facts_current_phase == 6
	if is_instance_valid(_story_facts_challenge_button):
		_story_facts_challenge_button.visible = show_challenge
		_story_facts_challenge_button.custom_minimum_size = bottom_button_size
		_story_facts_challenge_button.size = bottom_button_size
	if is_instance_valid(_story_facts_back_button):
		_story_facts_back_button.custom_minimum_size = bottom_button_size
		_story_facts_back_button.size = bottom_button_size

	var gap := 14.0
	var buttons_width = bottom_button_size.x
	if show_challenge:
		buttons_width = bottom_button_size.x * 2.0 + gap
	var start_x = (panel_size.x - buttons_width) * 0.5
	var button_y = panel_size.y - bottom_button_size.y - 18.0
	if is_instance_valid(_story_facts_back_button):
		_story_facts_back_button.position = Vector2(start_x, button_y)
	if show_challenge and is_instance_valid(_story_facts_challenge_button):
		_story_facts_challenge_button.position = Vector2(start_x + bottom_button_size.x + gap, button_y)

	if is_instance_valid(_story_facts_label):
		_story_facts_label.add_theme_font_size_override("font_size", 15 if tiny else (16 if compact else 18))
		_story_facts_label.position = Vector2(30.0, 54.0)
		_story_facts_label.size = Vector2(panel_size.x - 60.0, button_y - 64.0)


func _refresh_tutorial_panel_state() -> void:
	var tutorial = _tutorial_panel
	if not is_instance_valid(tutorial):
		return
	if not tutorial.visible:
		_tutorial_last_visible = false
		_sync_story_instruction_bar_demo_state()
		return
	var label: Label = _tutorial_label
	var current_text := ""
	if is_instance_valid(label):
		current_text = str(label.text)
	if not _tutorial_last_visible:
		_tutorial_last_visible = true
		_tutorial_last_text = current_text
		_update_tutorial_expanded_size_for_text()
		if not _tutorial_collapsed:
			_apply_tutorial_panel_state()
		return
	if current_text != _tutorial_last_text:
		_tutorial_last_text = current_text
		_update_tutorial_expanded_size_for_text()
		if _tutorial_collapsed:
			_set_tutorial_collapsed(false)
		else:
			_apply_tutorial_panel_state()


func _on_tutorial_toggle_pressed() -> void:
	if _challenge_loss_instruction_active:
		_on_tutorial_continue_pressed()
		return
	var next_collapsed = not _tutorial_collapsed
	if next_collapsed:
		_suppress_minimap_input_handoff()
	_set_tutorial_collapsed(next_collapsed)
	if _is_guidance_instruction_mode():
		set_pause_state(not next_collapsed)


func _on_tutorial_continue_pressed() -> void:
	var phase_id = _story_instruction_phase_id
	var challenge_loss_active = _challenge_loss_instruction_active
	_suppress_minimap_input_handoff()
	_set_tutorial_collapsed(true)
	if _is_guidance_instruction_mode():
		set_pause_state(false)
	var level_root = get_parent()
	if challenge_loss_active:
		_challenge_loss_instruction_active = false
		if is_instance_valid(level_root) and level_root.has_method("on_challenge_loss_score_continue"):
			level_root.call("on_challenge_loss_score_continue")
		return
	if _is_story_instruction_mode() and phase_id >= 1 and phase_id <= 6:
		_unlock_story_facts_button()
	if is_instance_valid(level_root) and level_root.has_method("on_story_instruction_continue"):
		level_root.call("on_story_instruction_continue", phase_id)


func _on_score_timer_timeout() -> void:
	#time_elapsed += 1
	#Global.score += 1
	_update_score_rank_display()


func refresh_score_rank_display() -> void:
	_update_score_rank_display()


func _update_score_rank_display(animate_rank_change: bool = true) -> void:
	Global.update_high_score(Global.score)
	var story_mode := _is_story_instruction_mode()
	if is_instance_valid(_score_label):
		_score_label.visible = not story_mode
		_score_label.text = Global.format_score_value(Global.score)
	if is_instance_valid(_high_score_container):
		_high_score_container.visible = not story_mode
	if is_instance_valid(_high_score_value_label):
		_high_score_value_label.text = Global.format_score_value(Global.high_score)
	if is_instance_valid(_rank_label):
		_rank_label.visible = not story_mode
		var rank_key := Global.get_rank_threshold(Global.score)
		var rank_changed: bool = _last_rank_key >= 0 and rank_key != _last_rank_key
		_rank_label.text = "Rank: " + str(Global.ranks.get(rank_key, ""))
		_last_rank_key = rank_key
		if not story_mode and animate_rank_change and rank_changed:
			_play_rank_change_attention()
	_sync_story_facts_button_state()
	if is_instance_valid(_endgame_container):
		_endgame_container.visible = (not story_mode) or (is_instance_valid(_story_facts_button) and _story_facts_button.visible)


func _get_story_facts_phase() -> int:
	return clampi(int(Global.story_chapter_id), 1, 6)


func _get_story_facts_button_text(phase_id: int) -> String:
	return str("Phase ", clampi(phase_id, 1, 6), ". Facts!")


func _story_facts_should_sparkle() -> bool:
	if not _is_story_instruction_mode():
		return false
	if not _story_facts_available:
		return false
	if not is_instance_valid(_story_facts_button) or not _story_facts_button.visible:
		return false
	return not bool(_story_facts_seen_phases.get(_story_facts_current_phase, false))


func _sync_story_facts_button_state() -> void:
	_ensure_story_facts_button()
	if not is_instance_valid(_story_facts_button):
		return
	var story_mode := _is_story_instruction_mode()
	if not story_mode:
		_story_facts_button.visible = false
		if is_instance_valid(_story_facts_panel):
			_story_facts_panel.visible = false
		if is_instance_valid(_endgame_container):
			_endgame_container.visible = true
		return
	var old_visible := _story_facts_button.visible
	var old_text := str(_story_facts_button.text)
	var phase_id = _get_story_facts_phase()
	if phase_id != _story_facts_current_phase:
		_story_facts_current_phase = phase_id
		_story_facts_sparkle_spawn_elapsed = STORY_FACTS_SPARKLE_INTERVAL
	var panel_open = is_instance_valid(_story_facts_panel) and _story_facts_panel.visible
	var story_prompt_open = is_instance_valid(_tutorial_panel) and _tutorial_panel.visible and not _tutorial_collapsed
	_story_facts_button.visible = _story_facts_available and not panel_open and not story_prompt_open
	var button_text = _get_story_facts_button_text(phase_id)
	if _story_facts_should_sparkle():
		button_text = str("* ", button_text, " *")
	_story_facts_button.text = button_text
	if is_instance_valid(_endgame_container):
		_endgame_container.visible = _story_facts_button.visible
	if old_visible != _story_facts_button.visible or old_text != button_text:
		_request_layout_update()


func _unlock_story_facts_button() -> void:
	if not _is_story_instruction_mode():
		return
	var was_available = _story_facts_available
	_story_facts_available = true
	_sync_story_facts_button_state()
	if not was_available:
		_spawn_story_facts_sparkles()


func _update_story_facts_button_sparkle(delta: float) -> void:
	_sync_story_facts_button_state()
	if not _story_facts_should_sparkle():
		_story_facts_sparkle_elapsed = 0.0
		if is_instance_valid(_story_facts_button):
			_story_facts_button.modulate = Color.WHITE
		return
	_story_facts_sparkle_elapsed += maxf(delta, 0.0)
	_story_facts_sparkle_spawn_elapsed += maxf(delta, 0.0)
	var pulse = 0.62 + 0.38 * (0.5 + 0.5 * sin(_story_facts_sparkle_elapsed * 5.2))
	_story_facts_button.modulate = Color(1.0, 0.90 + 0.10 * pulse, 0.48 + 0.36 * pulse, 1.0)
	if _story_facts_sparkle_spawn_elapsed >= STORY_FACTS_SPARKLE_INTERVAL:
		_story_facts_sparkle_spawn_elapsed = 0.0
		_spawn_story_facts_sparkles()


func _spawn_story_facts_sparkles() -> void:
	if not is_instance_valid(_story_facts_button) or not _story_facts_button.visible:
		return
	var rect := _story_facts_button.get_global_rect()
	var center := rect.position + rect.size * 0.5
	var offsets := [
		Vector2(-70, -16),
		Vector2(-42, 18),
		Vector2(0, -24),
		Vector2(44, 18),
		Vector2(72, -12)
	]
	for offset in offsets:
		var sparkle := Label.new()
		sparkle.text = "*"
		sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sparkle.z_index = 1000
		sparkle.modulate = Color(1.0, 0.92, 0.24, 1.0)
		sparkle.add_theme_font_size_override("font_size", 24)
		add_child(sparkle)
		var start_pos: Vector2 = center + offset
		var drift: Vector2 = offset.normalized() * 18.0 + Vector2(0, -10)
		sparkle.position = start_pos
		sparkle.scale = Vector2(0.72, 0.72)
		var tween := get_tree().create_tween()
		tween.tween_property(sparkle, "scale", Vector2(1.45, 1.45), STORY_FACTS_SPARKLE_DURATION)
		tween.parallel().tween_property(sparkle, "position", start_pos + drift, STORY_FACTS_SPARKLE_DURATION)
		tween.parallel().tween_property(sparkle, "modulate:a", 0.0, STORY_FACTS_SPARKLE_DURATION).set_delay(0.10)
		tween.finished.connect(Callable(sparkle, "queue_free"))


func _on_story_facts_button_pressed() -> void:
	var phase_id = _get_story_facts_phase()
	_story_facts_current_phase = phase_id
	_story_facts_seen_phases[phase_id] = true
	_ensure_story_facts_panel()
	if is_instance_valid(_story_facts_label):
		_story_facts_label.text = str(STORY_FACTS_TEXT.get(phase_id, ""))
	if is_instance_valid(_story_facts_panel):
		_story_facts_panel.visible = true
	if is_instance_valid(_story_facts_challenge_button):
		_story_facts_challenge_button.visible = phase_id == 6
	_sync_story_facts_button_state()
	_layout_story_facts_panel()
	set_pause_state(true)


func _on_story_facts_close_pressed() -> void:
	if is_instance_valid(_story_facts_panel):
		_story_facts_panel.visible = false
	_sync_story_facts_button_state()
	set_pause_state(false)


func _on_story_facts_challenge_pressed() -> void:
	if is_instance_valid(_story_facts_panel):
		_story_facts_panel.visible = false
	set_pause_state(false)
	var level_root = get_parent()
	if is_instance_valid(level_root) and level_root.has_method("on_story_instruction_continue"):
		level_root.call("on_story_instruction_continue", 6)


func _play_rank_change_attention() -> void:
	if not is_instance_valid(_rank_label):
		return
	if is_instance_valid(_rank_flash_tween):
		_rank_flash_tween.kill()
	_rank_label.scale = Vector2.ONE
	_rank_label.modulate = Color.WHITE
	_rank_label.pivot_offset = _rank_label.size * 0.5
	_spawn_rank_sparkles()
	_rank_flash_tween = get_tree().create_tween()
	_rank_flash_tween.tween_property(_rank_label, "scale", Vector2(RANK_FLASH_SCALE, RANK_FLASH_SCALE), 0.12)
	_rank_flash_tween.parallel().tween_property(_rank_label, "modulate", Color(1.0, 0.88, 0.25, 1.0), 0.12)
	_rank_flash_tween.tween_property(_rank_label, "scale", Vector2(1.08, 1.08), 0.13)
	_rank_flash_tween.parallel().tween_property(_rank_label, "modulate", Color.WHITE, 0.13)
	_rank_flash_tween.tween_property(_rank_label, "scale", Vector2(1.22, 1.22), 0.10)
	_rank_flash_tween.parallel().tween_property(_rank_label, "modulate", Color(1.0, 0.95, 0.45, 1.0), 0.10)
	_rank_flash_tween.tween_property(_rank_label, "scale", Vector2.ONE, 0.22)
	_rank_flash_tween.parallel().tween_property(_rank_label, "modulate", Color.WHITE, 0.22)


func _spawn_rank_sparkles() -> void:
	if not is_instance_valid(_rank_label):
		return
	var rect := _rank_label.get_global_rect()
	var center := rect.position + rect.size * 0.5
	var offsets := [
		Vector2(-58, -10),
		Vector2(-34, 14),
		Vector2(0, -20),
		Vector2(38, 12),
		Vector2(62, -8)
	]
	for offset in offsets:
		var sparkle := Label.new()
		sparkle.text = "*"
		sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sparkle.z_index = 1000
		sparkle.modulate = Color(1.0, 0.94, 0.35, 1.0)
		sparkle.add_theme_font_size_override("font_size", 24)
		add_child(sparkle)
		var start_pos: Vector2 = center + offset
		var drift: Vector2 = offset.normalized() * 20.0 + Vector2(0, -12)
		sparkle.position = start_pos
		sparkle.scale = Vector2(0.75, 0.75)
		var tween := get_tree().create_tween()
		tween.tween_property(sparkle, "scale", Vector2(1.55, 1.55), RANK_SPARKLE_DURATION)
		tween.parallel().tween_property(sparkle, "position", start_pos + drift, RANK_SPARKLE_DURATION)
		tween.parallel().tween_property(sparkle, "modulate:a", 0.0, RANK_SPARKLE_DURATION).set_delay(0.10)
		tween.finished.connect(Callable(sparkle, "queue_free"))
	


func _on_h_slider_drag_ended(value_changed: bool) -> void:
	#print("sliders:", sliders)
	clicked_slider = true
	for slider in sliders:
		#var agent = slider["agent"]
		var res = slider["res"]
		#if(is_instance_valid(agent)):
		#print("slider value:", slider["slider"].value, slider)
		Global.values[res] = slider["slider"].value/100
				
		for label in $MarginContainer/VBoxContainer/HBoxContainer/ResVBoxContainer.get_children():
			#print("g. << inside asadas: ", label.name, " : ", label.text, path_dict["trade_asset"])
			if label.name == res:
				#print("h. ><><< inside asadas, lable", label.name, " : ", label.text)
				if(Global.social_mode==true):
					label.text = Global.assets_social[res] + str(" ") + str(Global.values[res])
				else:
					label.text = Global.assets_plant[res] + str(" ") + str(Global.values[res])
		



func _ensure_drag_preview() -> void:
	if is_instance_valid(drag_preview_sprite):
		return
	drag_preview_sprite = Sprite2D.new()
	drag_preview_sprite.visible = false
	drag_preview_sprite.centered = true
	drag_preview_sprite.z_as_relative = false
	drag_preview_sprite.z_index = 202
	drag_preview_sprite.modulate = Color(1,1,1,0.85)
	add_child(drag_preview_sprite)
	drag_preview_outline = Line2D.new()
	drag_preview_outline.visible = false
	drag_preview_outline.z_as_relative = false
	drag_preview_outline.z_index = 201
	drag_preview_outline.width = 4.0
	drag_preview_outline.default_color = INVENTORY_DRAG_PREVIEW_OUTLINE_COLOR
	drag_preview_outline.closed = false
	add_child(drag_preview_outline)


func _refresh_drag_preview_outline(texture: Texture2D) -> void:
	if not is_instance_valid(drag_preview_outline):
		return
	drag_preview_outline.clear_points()
	var half_size := Vector2(16, 16)
	if is_instance_valid(texture):
		half_size = texture.get_size() * 0.5
	half_size += Vector2(4.0, 4.0)
	var top_left = Vector2(-half_size.x, -half_size.y)
	var top_right = Vector2(half_size.x, -half_size.y)
	var bottom_right = Vector2(half_size.x, half_size.y)
	var bottom_left = Vector2(-half_size.x, half_size.y)
	drag_preview_outline.add_point(top_left)
	drag_preview_outline.add_point(top_right)
	drag_preview_outline.add_point(bottom_right)
	drag_preview_outline.add_point(bottom_left)
	drag_preview_outline.add_point(top_left)


func _get_inventory_agent_at(mouse_pos: Vector2) -> String:
	for icon in _slot_icons:
		if not is_instance_valid(icon):
			continue
		if not icon.visible:
			continue
		if not icon.has_meta("item_name"):
			continue
		var touch_rect = icon.get_global_rect()
		if Global.is_mobile_platform:
			touch_rect = touch_rect.grow(14.0)
		if touch_rect.has_point(mouse_pos):
			return str(icon.get_meta("item_name"))
	return ""


func _start_inventory_drag(agent_name: String, mouse_pos: Vector2) -> void:
	_ensure_drag_preview()
	var icon: TextureRect = null
	for candidate in _slot_icons:
		if is_instance_valid(candidate) and candidate.visible and candidate.has_meta("item_name") and str(candidate.get_meta("item_name")) == agent_name:
			icon = candidate
			break
	if is_instance_valid(icon):
		drag_preview_sprite.texture = icon.texture
		_refresh_drag_preview_outline(icon.texture)
	drag_preview_sprite.global_position = mouse_pos
	drag_preview_sprite.visible = true
	if is_instance_valid(drag_preview_outline):
		drag_preview_outline.global_position = mouse_pos
		drag_preview_outline.visible = true


func _update_inventory_drag(mouse_pos: Vector2) -> void:
	if is_instance_valid(drag_preview_sprite) and drag_preview_sprite.visible:
		drag_preview_sprite.global_position = mouse_pos
	if is_instance_valid(drag_preview_outline) and drag_preview_outline.visible:
		drag_preview_outline.global_position = mouse_pos


func _end_inventory_drag() -> void:
	if is_instance_valid(drag_preview_sprite):
		drag_preview_sprite.visible = false
		drag_preview_sprite.texture = null
	if is_instance_valid(drag_preview_outline):
		drag_preview_outline.visible = false
		drag_preview_outline.clear_points()


func _ensure_back_confirm_dialog() -> void:
	if is_instance_valid(_back_confirm_dialog):
		return
	_back_confirm_dialog = ConfirmationDialog.new()
	_back_confirm_dialog.name = "BackConfirmDialog"
	_back_confirm_dialog.title = "Quit game?"
	_back_confirm_dialog.dialog_text = "Are you sure you want to quit?"
	_back_confirm_dialog.add_theme_stylebox_override("panel", _make_quit_dialog_panel_style())
	_back_confirm_dialog.add_theme_color_override("title_color", Color(1, 1, 1, 0.98))
	if _back_confirm_dialog.has_method("get_label"):
		var dialog_label = _back_confirm_dialog.call("get_label")
		if dialog_label is Label:
			var label_node: Label = dialog_label
			label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label_node.add_theme_font_size_override("font_size", 22 if _is_compact_ui() else 19)
			label_node.add_theme_color_override("font_color", Color(1, 1, 1, 0.97))
	var ok_button = _back_confirm_dialog.get_ok_button()
	if is_instance_valid(ok_button):
		ok_button.text = "Yes"
		ok_button.custom_minimum_size = Vector2(140, 56)
		ok_button.add_theme_font_size_override("font_size", 18)
		ok_button.add_theme_color_override("font_color", Color(1, 1, 1, 0.98))
		ok_button.add_theme_stylebox_override("normal", _make_quit_dialog_button_style(QUIT_DIALOG_BUTTON_BG))
		ok_button.add_theme_stylebox_override("hover", _make_quit_dialog_button_style(QUIT_DIALOG_BUTTON_BG_HOVER))
		ok_button.add_theme_stylebox_override("pressed", _make_quit_dialog_button_style(QUIT_DIALOG_BUTTON_BG_PRESSED))
	var cancel_button = _back_confirm_dialog.get_cancel_button()
	if is_instance_valid(cancel_button):
		cancel_button.text = "No"
		cancel_button.custom_minimum_size = Vector2(140, 56)
		cancel_button.add_theme_font_size_override("font_size", 18)
		cancel_button.add_theme_color_override("font_color", Color(1, 1, 1, 0.98))
		cancel_button.add_theme_stylebox_override("normal", _make_quit_dialog_button_style(QUIT_DIALOG_BUTTON_BG_CANCEL))
		cancel_button.add_theme_stylebox_override("hover", _make_quit_dialog_button_style(QUIT_DIALOG_BUTTON_BG_CANCEL_HOVER))
		cancel_button.add_theme_stylebox_override("pressed", _make_quit_dialog_button_style(QUIT_DIALOG_BUTTON_BG_CANCEL_PRESSED))
	_back_confirm_dialog.confirmed.connect(_on_back_confirmed)
	_back_confirm_dialog.canceled.connect(_on_back_confirm_canceled)
	add_child(_back_confirm_dialog)


func set_pause_state(paused: bool) -> void:
	get_tree().paused = paused
	var pause_button: Button = _get_pause_button()
	if is_instance_valid(pause_button):
		pause_button.text = "Start" if paused else "Pause"


func show_back_to_menu_confirm() -> void:
	set_pause_state(true)
	_ensure_back_confirm_dialog()
	if is_instance_valid(_back_confirm_dialog):
		var compact = _is_compact_ui()
		var popup_size = Vector2i(460, 200)
		if compact:
			popup_size = Vector2i(520, 240)
		_back_confirm_dialog.popup_centered(popup_size)


func hide_back_to_menu_confirm() -> void:
	if is_instance_valid(_back_confirm_dialog):
		_back_confirm_dialog.hide()


func _on_back_confirmed() -> void:
	set_pause_state(false)
	emit_signal("request_back_to_menu")


func _on_back_confirm_canceled() -> void:
	set_pause_state(false)
	hide_back_to_menu_confirm()


func _get_agents_root() -> Node:
	return get_node_or_null("../Agents")


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return Global.screen_to_world(self, screen_pos)


func _world_to_screen(world_pos: Vector2) -> Vector2:
	return Global.world_to_screen(self, world_pos)


func _get_world_rect() -> Rect2:
	return Global.get_world_rect(self)


func _get_world_foundation() -> Node:
	return get_node_or_null("../WorldFoundation")


func _supports_tile_world(world: Node) -> bool:
	if not is_instance_valid(world):
		return false
	return world.has_method("world_to_tile") and world.has_method("tile_to_world_center") and world.has_method("in_bounds")


func _is_parent_bounded_inventory_type(agent_name: String) -> bool:
	return PARENT_BOUNDED_TYPES.has(agent_name)


func _chebyshev_tile_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(abs(a.x - b.x), abs(a.y - b.y))


func _emit_inventory_drag_preview(agent_name: String, screen_pos: Vector2, active: bool) -> void:
	if not active:
		emit_signal("inventory_drag_preview", agent_name, Vector2.ZERO, false)
		return
	if _is_story_village_inventory_item(agent_name):
		emit_signal("inventory_drag_preview", agent_name, Vector2.ZERO, false)
		return
	var view = get_viewport().get_visible_rect()
	if not view.has_point(screen_pos):
		emit_signal("inventory_drag_preview", agent_name, Vector2.ZERO, false)
		return
	if $MarginContainer.get_global_rect().has_point(screen_pos):
		emit_signal("inventory_drag_preview", agent_name, Vector2.ZERO, false)
		return
	var world_pos = _screen_to_world(screen_pos)
	var world_rect = _get_world_rect()
	if not world_rect.has_point(world_pos):
		emit_signal("inventory_drag_preview", agent_name, Vector2.ZERO, false)
		return
	emit_signal("inventory_drag_preview", agent_name, world_pos, true)


func _is_story_village_inventory_item(agent_name: String) -> bool:
	return agent_name == "farmer" or agent_name == "vendor" or agent_name == "cook" or agent_name == "basket"


func _get_agent_edge_radius(agent: Node) -> float:
	var radius := 24.0
	var sprite_node = agent.get("sprite")
	if is_instance_valid(sprite_node) and sprite_node.has_method("get_rect"):
		var rect = sprite_node.get_rect()
		var sx = abs(sprite_node.scale.x)
		var sy = abs(sprite_node.scale.y)
		radius = max(rect.size.x * sx, rect.size.y * sy) * 0.5
	elif agent.has_node("Sprite2D"):
		var sprite_child = agent.get_node("Sprite2D")
		if is_instance_valid(sprite_child) and sprite_child.has_method("get_rect"):
			var child_rect = sprite_child.get_rect()
			var csx = abs(sprite_child.scale.x)
			var csy = abs(sprite_child.scale.y)
			radius = max(child_rect.size.x * csx, child_rect.size.y * csy) * 0.5
	return max(radius, 16.0)


func _get_anchor_reach_radius(anchor: Node) -> float:
	var reach := 0.0
	var reach_value = anchor.get("buddy_radius")
	if typeof(reach_value) == TYPE_FLOAT or typeof(reach_value) == TYPE_INT:
		reach = float(reach_value)
	if reach <= 0.0:
		reach = _get_agent_edge_radius(anchor) + 24.0
	return max(reach, 24.0)


func _get_reach_anchors(agents_root: Node) -> Array:
	var anchors: Array = []
	if not is_instance_valid(agents_root):
		return anchors
	for agent in agents_root.get_children():
		if not is_instance_valid(agent):
			continue
		if agent.get("dead") == true:
			continue
		if agent.get("type") == "myco":
			anchors.append(agent)
	return anchors


func _get_random_living_myco_anchor(agents_root: Node) -> Node:
	var anchors = _get_reach_anchors(agents_root)
	if anchors.is_empty():
		return null
	return anchors[inventory_spawn_rng.randi_range(0, anchors.size() - 1)]


func _get_nearest_living_myco_anchor(world_pos: Vector2, agents_root: Node) -> Node:
	if not is_instance_valid(agents_root):
		return null
	var world = _get_world_foundation()
	var best_anchor: Node = null
	var best_dist := INF
	if _supports_tile_world(world):
		var target_coord = Vector2i(world.world_to_tile(world_pos))
		for agent in agents_root.get_children():
			if not is_instance_valid(agent):
				continue
			if agent.get("dead") == true:
				continue
			if agent.get("type") != "myco":
				continue
			var coord = Vector2i(world.world_to_tile(agent.global_position))
			if not world.in_bounds(coord):
				continue
			var dist = float(_chebyshev_tile_distance(coord, target_coord))
			if dist < best_dist:
				best_dist = dist
				best_anchor = agent
		return best_anchor
	for agent in agents_root.get_children():
		if not is_instance_valid(agent):
			continue
		if agent.get("dead") == true:
			continue
		if agent.get("type") != "myco":
			continue
		var dist = agent.global_position.distance_to(world_pos)
		if dist < best_dist:
			best_dist = dist
			best_anchor = agent
	return best_anchor


func _is_valid_auto_spawn_position(pos: Vector2, agents_root: Node, anchor: Node = null) -> bool:
	var world_rect = _get_world_rect()
	if not world_rect.has_point(pos):
		return false
	var world = _get_world_foundation()
	if is_instance_valid(world) and world.has_method("is_world_pos_revealed"):
		if not bool(world.is_world_pos_revealed(pos)):
			return false
	var pos_screen = _world_to_screen(pos)
	var view = get_viewport().get_visible_rect()
	if view.has_point(pos_screen) and $MarginContainer.get_global_rect().has_point(pos_screen):
		return false
	if is_instance_valid(anchor):
		var reach = _get_anchor_reach_radius(anchor)
		var distance_to_anchor = anchor.global_position.distance_to(pos)
		if abs(distance_to_anchor - reach) > 1.5:
			return false
	if is_instance_valid(agents_root):
		for agent in agents_root.get_children():
			if not is_instance_valid(agent):
				continue
			if agent.get("dead") == true:
				continue
			var min_dist = _get_agent_edge_radius(agent) + 6.0
			if agent.global_position.distance_to(pos) < min_dist:
				return false
	return true


func _sample_parent_bounded_auto_target(parent_anchor: Node, agents_root: Node, max_parent_tiles: int) -> Vector2:
	if not is_instance_valid(parent_anchor):
		return Vector2.ZERO
	var world = _get_world_foundation()
	var safe_tiles = maxi(max_parent_tiles, 0)
	if _supports_tile_world(world):
		var parent_coord = Vector2i(world.world_to_tile(parent_anchor.global_position))
		if safe_tiles <= 0:
			return world.tile_to_world_center(parent_coord)
		for _attempt in range(PARENT_BOUNDED_AUTO_ATTEMPTS):
			var dx = inventory_spawn_rng.randi_range(-safe_tiles, safe_tiles)
			var dy = inventory_spawn_rng.randi_range(-safe_tiles, safe_tiles)
			if maxi(abs(dx), abs(dy)) > safe_tiles:
				continue
			var coord = parent_coord + Vector2i(dx, dy)
			if not world.in_bounds(coord):
				continue
			var candidate = world.tile_to_world_center(coord)
			if _is_valid_auto_spawn_position(candidate, agents_root):
				return candidate
		for radius in range(0, safe_tiles + 1):
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					if radius > 0 and abs(dx) != radius and abs(dy) != radius:
						continue
					var coord = parent_coord + Vector2i(dx, dy)
					if not world.in_bounds(coord):
						continue
					if _chebyshev_tile_distance(parent_coord, coord) > safe_tiles:
						continue
					var candidate = world.tile_to_world_center(coord)
					if _is_valid_auto_spawn_position(candidate, agents_root):
						return candidate
		return world.tile_to_world_center(parent_coord)
	return parent_anchor.global_position


func _get_auto_spawn_target(agent_name: String) -> Dictionary:
	var target = {
		"ok": true,
		"pos": Vector2.ZERO,
		"anchor": null,
		"max_parent_tiles": PARENT_BOUNDED_MAX_TILES
	}
	var agents_root = _get_agents_root()
	if _is_parent_bounded_inventory_type(agent_name):
		var parent_anchor = _get_random_living_myco_anchor(agents_root)
		if not is_instance_valid(parent_anchor):
			target["ok"] = false
			return target
		target["anchor"] = parent_anchor
		target["pos"] = _sample_parent_bounded_auto_target(parent_anchor, agents_root, PARENT_BOUNDED_MAX_TILES)
		return target

	var anchors = _get_reach_anchors(agents_root)
	var world_rect = _get_world_rect()
	if anchors.is_empty():
		target["pos"] = world_rect.position + world_rect.size * 0.5
		return target
	for _attempt in range(AUTO_SPAWN_ATTEMPTS):
		var anchor = anchors[inventory_spawn_rng.randi_range(0, anchors.size() - 1)]
		var dist = _get_anchor_reach_radius(anchor)
		var angle = inventory_spawn_rng.randf_range(0.0, TAU)
		var candidate = anchor.global_position + Vector2.RIGHT.rotated(angle) * dist
		if _is_valid_auto_spawn_position(candidate, agents_root, anchor):
			target["pos"] = candidate
			target["anchor"] = anchor
			return target
	for anchor in anchors:
		var dist = _get_anchor_reach_radius(anchor)
		var start_angle = inventory_spawn_rng.randf_range(0.0, TAU)
		for idx in range(AUTO_SPAWN_SWEEP_STEPS):
			var angle = start_angle + (TAU * float(idx) / float(AUTO_SPAWN_SWEEP_STEPS))
			var candidate = anchor.global_position + Vector2.RIGHT.rotated(angle) * dist
			if _is_valid_auto_spawn_position(candidate, agents_root, anchor):
				target["pos"] = candidate
				target["anchor"] = anchor
				return target
	var fallback_anchor = anchors[inventory_spawn_rng.randi_range(0, anchors.size() - 1)]
	var toward_center = world_rect.get_center() - fallback_anchor.global_position
	if toward_center.length() < 0.001:
		toward_center = Vector2.RIGHT
	var fallback_pos = fallback_anchor.global_position + toward_center.normalized() * _get_anchor_reach_radius(fallback_anchor)
	if _is_valid_auto_spawn_position(fallback_pos, agents_root, fallback_anchor):
		target["pos"] = fallback_pos
		target["anchor"] = fallback_anchor
		return target
	target["pos"] = world_rect.position + world_rect.size * 0.5
	return target


func _select_inventory_item(agent_name: String) -> void:
	if agent_name == "":
		return
	if int(Global.inventory.get(agent_name, 0)) <= 0:
		return
	_selected_inventory_item = agent_name
	next_agent = agent_name
	_reset_failed_placement_attempts()
	_refresh_inventory_selection_visuals()
	_update_minimap_input_lock()


func _clear_world_tile_hint() -> void:
	var world = _get_world_foundation()
	if is_instance_valid(world) and world.has_method("clear_drag_tile_hint"):
		world.clear_drag_tile_hint()


func _clear_inventory_selection() -> void:
	var previous_item = _selected_inventory_item
	_selected_inventory_item = ""
	next_agent = null
	_reset_failed_placement_attempts()
	_pointer_is_down = false
	_pointer_is_touch = false
	_pointer_press_item = ""
	_pointer_press_tile_ok = false
	_pointer_press_tile_pos = Vector2.ZERO
	_pointer_press_selection_changed = false
	_pointer_drag_active = false
	_end_inventory_drag()
	_clear_world_tile_hint()
	if previous_item != "":
		emit_signal("inventory_drag_preview", previous_item, Vector2.ZERO, false)
	_refresh_inventory_selection_visuals()
	_refresh_inventory_phase1_sparkle_visuals()
	_update_minimap_input_lock()


func is_inventory_placement_active() -> bool:
	return _selected_inventory_item != ""


func _get_world_tile_drop_data(screen_pos: Vector2) -> Dictionary:
	var result := {
		"ok": false,
		"coord": Vector2i(-1, -1),
		"pos": Vector2.ZERO
	}
	var world = _get_world_foundation()
	if not _supports_tile_world(world):
		return result
	var view = get_viewport().get_visible_rect()
	if not view.has_point(screen_pos):
		return result
	if $MarginContainer.get_global_rect().has_point(screen_pos):
		return result
	var world_pos = _screen_to_world(screen_pos)
	var coord = Vector2i(world.world_to_tile(world_pos))
	if not world.in_bounds(coord):
		return result
	result["ok"] = true
	result["coord"] = coord
	result["pos"] = world.tile_to_world_center(coord)
	return result


func _can_place_inventory_item_at_world_pos(item_name: String, world_pos: Vector2) -> bool:
	if item_name == "":
		return false
	var level_root = get_node_or_null("..")
	if is_instance_valid(level_root) and level_root.has_method("can_place_inventory_item_at_world_pos"):
		return bool(level_root.can_place_inventory_item_at_world_pos(item_name, world_pos))
	var world = _get_world_foundation()
	if not _supports_tile_world(world):
		return false
	var coord = Vector2i(world.world_to_tile(world_pos))
	if not world.in_bounds(coord):
		return false
	return true


func _reset_failed_placement_attempts() -> void:
	_failed_placement_item = ""
	_failed_placement_coord = Vector2i(-1, -1)
	_failed_placement_count = 0


func _register_failed_placement_attempt(item_name: String, screen_pos: Vector2) -> bool:
	if item_name == "":
		_reset_failed_placement_attempts()
		return false
	var tile_data = _get_world_tile_drop_data(screen_pos)
	if not bool(tile_data.get("ok", false)):
		_reset_failed_placement_attempts()
		return false
	var target_pos: Vector2 = tile_data["pos"]
	if _can_place_inventory_item_at_world_pos(item_name, target_pos):
		_reset_failed_placement_attempts()
		return false
	var coord: Vector2i = tile_data["coord"]
	if _failed_placement_item == item_name and _failed_placement_coord == coord:
		_failed_placement_count += 1
	else:
		_failed_placement_item = item_name
		_failed_placement_coord = coord
		_failed_placement_count = 1
	return _failed_placement_count >= 2


func _uses_two_tile_vertical_hint(item_name: String) -> bool:
	return item_name == "tree" and not bool(Global.social_mode)


func _flash_invalid_selected_tile_hint(screen_pos: Vector2) -> void:
	if _selected_inventory_item == "":
		return
	var tile_data = _get_world_tile_drop_data(screen_pos)
	if not bool(tile_data.get("ok", false)):
		return
	var world = _get_world_foundation()
	if not is_instance_valid(world):
		return
	var coord: Vector2i = tile_data["coord"]
	var secondary_coord := Vector2i(-1, -1)
	var show_secondary := false
	if _uses_two_tile_vertical_hint(_selected_inventory_item):
		secondary_coord = coord + Vector2i(0, -1)
		show_secondary = true
	if world.has_method("flash_drag_tile_hint"):
		world.flash_drag_tile_hint(coord, false, secondary_coord, show_secondary, 0.32)
	elif world.has_method("set_drag_tile_hint"):
		world.set_drag_tile_hint(coord, false, secondary_coord, show_secondary)


func _update_selected_tile_hint(screen_pos: Vector2) -> void:
	if _selected_inventory_item == "":
		_clear_world_tile_hint()
		return
	var tile_data = _get_world_tile_drop_data(screen_pos)
	if not bool(tile_data.get("ok", false)):
		_clear_world_tile_hint()
		emit_signal("inventory_drag_preview", _selected_inventory_item, Vector2.ZERO, false)
		return
	var world = _get_world_foundation()
	if not is_instance_valid(world) or not world.has_method("set_drag_tile_hint"):
		return
	var target_pos: Vector2 = tile_data["pos"]
	var coord: Vector2i = tile_data["coord"]
	var can_place = _can_place_inventory_item_at_world_pos(_selected_inventory_item, target_pos)
	var secondary_coord := Vector2i(-1, -1)
	var show_secondary := false
	if _uses_two_tile_vertical_hint(_selected_inventory_item):
		secondary_coord = coord + Vector2i(0, -1)
		show_secondary = true
	world.set_drag_tile_hint(coord, can_place, secondary_coord, show_secondary)
	_emit_inventory_drag_preview(_selected_inventory_item, screen_pos, true)


func _update_selected_inventory_hover_hint() -> void:
	if _selected_inventory_item == "":
		return
	if _pointer_drag_active:
		return
	_update_selected_tile_hint(_last_pointer_pos)


func _should_begin_inventory_drag(screen_pos: Vector2) -> bool:
	if not _pointer_is_down:
		return false
	if _pointer_drag_active:
		return false
	if _selected_inventory_item == "":
		return false
	var threshold = INVENTORY_DRAG_THRESHOLD_TOUCH if _pointer_is_touch else INVENTORY_DRAG_THRESHOLD_MOUSE
	return _pointer_press_pos.distance_to(screen_pos) >= threshold


func _resolve_selected_item_drag_attempt() -> bool:
	if _selected_inventory_item == "":
		return false
	if not _pointer_press_tile_ok:
		return false
	if _try_place_selected_item_at_world_pos(_pointer_press_tile_pos):
		_clear_inventory_selection()
		return true
	_flash_invalid_selected_tile_hint(_pointer_press_pos)
	_clear_inventory_selection()
	return true


func _try_place_selected_item_at_screen_pos(screen_pos: Vector2) -> bool:
	if _selected_inventory_item == "":
		return false
	var tile_data = _get_world_tile_drop_data(screen_pos)
	if not bool(tile_data.get("ok", false)):
		return false
	var target_pos: Vector2 = tile_data["pos"]
	return _try_place_selected_item_at_world_pos(target_pos)


func _try_place_selected_item_at_world_pos(target_pos: Vector2) -> bool:
	if _selected_inventory_item == "":
		return false
	var spawn_name = _selected_inventory_item
	if int(Global.inventory.get(spawn_name, 0)) <= 0:
		return false
	if not _can_place_inventory_item_at_world_pos(spawn_name, target_pos):
		return false
	var constrained_type = _is_parent_bounded_inventory_type(spawn_name)
	var spawn_anchor = null
	if constrained_type:
		spawn_anchor = _get_nearest_living_myco_anchor(target_pos, _get_agents_root())
		if not is_instance_valid(spawn_anchor):
			return false
	var level_root = get_node_or_null("..")
	if is_instance_valid(level_root) and level_root.has_method("try_story_inventory_delivery"):
		if bool(level_root.try_story_inventory_delivery(spawn_name, target_pos)):
			Global.inventory[spawn_name] = int(Global.inventory.get(spawn_name, 0)) - 1
			refresh_inventory_counts()
			return true
	var new_agent_dict = {
		"name": spawn_name,
		"pos": target_pos,
		"allow_replace": false,
		"from_inventory": true,
		"manual_placement": true,
		"require_exact_tile": true,
		"strict_exact_tile": true
	}
	if is_instance_valid(spawn_anchor):
		new_agent_dict["spawn_anchor"] = spawn_anchor
		if constrained_type:
			new_agent_dict["parent_anchor"] = spawn_anchor
			new_agent_dict["max_parent_tiles"] = PARENT_BOUNDED_MAX_TILES
	emit_signal("new_agent", new_agent_dict)
	Global.inventory[spawn_name] = int(Global.inventory.get(spawn_name, 0)) - 1
	refresh_inventory_counts()
	_reset_failed_placement_attempts()
	return true


func _on_inventory_pointer_moved(screen_pos: Vector2) -> void:
	_last_pointer_pos = screen_pos
	if _selected_inventory_item == "":
		return
	if _should_begin_inventory_drag(screen_pos):
		if _resolve_selected_item_drag_attempt():
			return
		_pointer_drag_active = true
		_start_inventory_drag(_selected_inventory_item, screen_pos)
	if _pointer_drag_active:
		_update_inventory_drag(screen_pos)
	_update_selected_tile_hint(screen_pos)


func _on_inventory_pointer_pressed(screen_pos: Vector2, from_touch: bool = false) -> void:
	_pointer_is_down = true
	_pointer_is_touch = from_touch
	_pointer_drag_active = false
	_pointer_press_pos = screen_pos
	_last_pointer_pos = screen_pos
	var press_tile_data = _get_world_tile_drop_data(screen_pos)
	_pointer_press_tile_ok = bool(press_tile_data.get("ok", false))
	_pointer_press_tile_pos = press_tile_data["pos"] if _pointer_press_tile_ok else Vector2.ZERO
	_pointer_press_item = ""
	_pointer_press_selection_changed = false
	var selected = _get_inventory_agent_at(screen_pos)
	if selected != "" and int(Global.inventory.get(selected, 0)) > 0:
		_pointer_press_item = selected
		if _selected_inventory_item != selected:
			_select_inventory_item(selected)
			_pointer_press_selection_changed = true
	if _selected_inventory_item != "":
		_update_selected_tile_hint(screen_pos)
		_update_minimap_input_lock()


func _on_inventory_pointer_released(screen_pos: Vector2, from_touch: bool = false) -> void:
	_last_pointer_pos = screen_pos
	var active_item = _selected_inventory_item
	var was_dragging = _pointer_drag_active
	var pressed_item = _pointer_press_item
	var selection_changed = _pointer_press_selection_changed
	_pointer_is_down = false
	_pointer_is_touch = from_touch
	_pointer_press_item = ""
	_pointer_press_tile_ok = false
	_pointer_press_tile_pos = Vector2.ZERO
	_pointer_press_selection_changed = false
	_pointer_drag_active = false
	if active_item == "":
		_update_minimap_input_lock()
		return
	if was_dragging:
		_update_inventory_drag(screen_pos)
		var placed_from_drag = _try_place_selected_item_at_screen_pos(screen_pos)
		if placed_from_drag:
			_clear_inventory_selection()
		else:
			_end_inventory_drag()
			emit_signal("inventory_drag_preview", active_item, Vector2.ZERO, false)
			_flash_invalid_selected_tile_hint(screen_pos)
			if _register_failed_placement_attempt(active_item, screen_pos):
				_clear_inventory_selection()
				return
			_refresh_inventory_selection_visuals()
			_update_minimap_input_lock()
		return
	if pressed_item != "" and pressed_item == active_item and not selection_changed:
		var released_item = _get_inventory_agent_at(screen_pos)
		if released_item == active_item:
			_clear_inventory_selection()
			return
	if pressed_item != "" and pressed_item == active_item and selection_changed:
		_refresh_inventory_selection_visuals()
		_update_selected_tile_hint(screen_pos)
		_update_minimap_input_lock()
		return
	var placed_by_tap = _try_place_selected_item_at_screen_pos(screen_pos)
	if placed_by_tap:
		_clear_inventory_selection()
		return
	emit_signal("inventory_drag_preview", active_item, Vector2.ZERO, false)
	_flash_invalid_selected_tile_hint(screen_pos)
	if _register_failed_placement_attempt(active_item, screen_pos):
		_clear_inventory_selection()
		return
	_refresh_inventory_selection_visuals()
	_update_minimap_input_lock()


func _input(event):
	if get_tree().paused:
		return
	if event is InputEventMouseMotion:
		if Global.is_mobile_platform:
			return
		_on_inventory_pointer_moved(event.position)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Global.is_mobile_platform:
			return
		if event.pressed:
			_on_inventory_pointer_pressed(event.position, false)
		else:
			_on_inventory_pointer_released(event.position, false)
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if _active_touch_drag_id != -1 and event.index != _active_touch_drag_id:
				return
			_active_touch_drag_id = event.index
			_on_inventory_pointer_pressed(event.position, true)
		else:
			if event.index != _active_touch_drag_id:
				return
			_on_inventory_pointer_released(event.position, true)
			_active_touch_drag_id = -1
		return

	if event is InputEventScreenDrag:
		if event.index != _active_touch_drag_id:
			return
		_on_inventory_pointer_moved(event.position)


func set_village_inventory_unlocked(_unlocked: bool) -> void:
	# Legacy API kept for level compatibility; tabs are removed.
	# We still refresh because story phase changes can unlock the basket slot.
	refresh_inventory_counts()


func set_story_village_marker(world_pos: Vector2, visible: bool) -> void:
	if is_instance_valid(minimap_panel):
		minimap_panel.set_village_marker(world_pos, visible)


func _on_minimap_camera_requested(world_pos: Vector2) -> void:
	var world = _get_world_foundation()
	if is_instance_valid(world) and world.has_method("set_camera_world_center"):
		world.set_camera_world_center(world_pos)


func _on_choose_myco_mouse_entered() -> void:
	mouseOverMyco = true
	


func _on_choose_myco_mouse_exited() -> void:
	mouseOverMyco = false


func _on_choose_squash_mouse_entered() -> void:
	mouseOverSquash = true


func _on_choose_maize_mouse_entered() -> void:
	mouseOverMaize = true


func _on_choose_squash_mouse_exited() -> void:
	mouseOverSquash = false


func _on_choose_maize_mouse_exited() -> void:
	mouseOverMaize = false


func _on_choose_beans_mouse_entered() -> void:
	mouseOverBean = true


func _on_choose_beans_mouse_exited() -> void:
	mouseOverBean = false



func _on_choose_tree_mouse_entered() -> void:
	mouseOverTree = true


func _on_choose_tree_mouse_exited() -> void:
	mouseOverTree = false


func _on_restart_button_pressed() -> void:
	set_pause_state(false)
	hide_back_to_menu_confirm()
	Global.update_high_score()
	Global.score = 0
	get_tree().call_deferred("change_scene_to_file","res://scenes/title_screen.tscn")


func _on_quit_button_pressed() -> void:
	show_back_to_menu_confirm()


func _on_pause_button_pressed() -> void:
	if is_instance_valid(_story_facts_panel) and _story_facts_panel.visible:
		set_pause_state(true)
		return
	if _is_guidance_instruction_mode() and is_instance_valid(_tutorial_panel) and _tutorial_panel.visible and not _tutorial_collapsed:
		set_pause_state(true)
		return
	var next_paused = not get_tree().paused
	set_pause_state(next_paused)
	if not next_paused:
		hide_back_to_menu_confirm()
