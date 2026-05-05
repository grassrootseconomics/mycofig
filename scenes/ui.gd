extends CanvasLayer
const MiniMapPanelRef = preload("res://scenes/minimap_panel.gd")
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
var minimap_panel: Control = null
var inventory_spawn_rng := RandomNumberGenerator.new()
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
const TUTORIAL_PANEL_EXPANDED_SIZE := Vector2(372, 178)
const TUTORIAL_PANEL_COLLAPSED_SIZE := Vector2(44, 44)

var _slot_icons: Array = []
var _slot_labels: Array = []
var _slot_items: Array = []
var _inventory_texture_cache: Dictionary = {}
var _active_touch_drag_id := -1
var _slot_backplates: Dictionary = {}
var _slot_lock_glyphs: Dictionary = {}
var _back_confirm_dialog: ConfirmationDialog = null
var _minimap_drag_locked := false
var _tutorial_toggle_button: Button = null
var _tutorial_collapsed := false
var _tutorial_last_visible := false
var _tutorial_last_text := ""

func _ready() -> void:
	#$PalletContainer2/HBoxContainer/ActiveTexture.texture = Global.active_agent.sprite_texture
	#resContainer = $MarginContainer/HBoxContainer/ResVBoxContainer
	process_mode = Node.PROCESS_MODE_ALWAYS
	inventory_spawn_rng.randomize()
	_ensure_drag_preview()
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
	_ensure_tutorial_panel_toggle()
	_update_minimap_input_lock()
	_set_inventory_tab("farm")
	# Legacy valuation bars are retained in scene/code but hidden from runtime.
	$MarginContainer/VBoxContainer/HBoxContainer/ResVBoxContainer.visible = false
	$MarginContainer/VBoxContainer/HBoxContainer/ValVBoxContainer.visible = false
	refresh_inventory_counts()


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
	minimap_panel.custom_minimum_size = Vector2(180, 120)
	minimap_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	minimap_panel.size_flags_vertical = Control.SIZE_FILL
	host.add_child(minimap_panel)
	minimap_panel.camera_pan_requested.connect(_on_minimap_camera_requested)
	var level_root = get_parent()
	var world = get_node_or_null("../WorldFoundation")
	var agents = get_node_or_null("../Agents")
	minimap_panel.configure(level_root, world, agents)


func _is_story_basket_slot_unlocked() -> bool:
	return Global.mode == "story" and int(Global.story_chapter_id) >= 5


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
		glyph_label.add_theme_font_size_override("font_size", 24)
		glyph_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
		host.add_child(glyph_label)
		_slot_lock_glyphs[icon] = glyph_label
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
			_apply_inventory_backplate_for_item(icon, "")
			_set_inventory_lock_glyph(icon, true)
			continue
		label.visible = true
		icon.texture = _get_inventory_item_texture(item)
		icon.set_meta("item_name", item)
		_apply_inventory_backplate_for_item(icon, item)
		_set_inventory_lock_glyph(icon, false)


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


func _ensure_inventory_backplates() -> void:
	_slot_backplates.clear()
	_slot_lock_glyphs.clear()
	for icon in _slot_icons:
		if not is_instance_valid(icon):
			continue
		var existing_parent = icon.get_parent()
		if existing_parent is Panel and bool(existing_parent.get_meta("inventory_backplate", false)):
			_slot_backplates[icon] = existing_parent
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
		icon.offset_left = 4.0
		icon.offset_top = 4.0
		icon.offset_right = -4.0
		icon.offset_bottom = -4.0
		_slot_backplates[icon] = host


func _apply_inventory_backplate_for_item(icon: TextureRect, item_name: String) -> void:
	if not is_instance_valid(icon):
		return
	var host = _slot_backplates.get(icon, null)
	if not (host is Panel):
		return
	var base_color: Color = INVENTORY_BACKPLATE_COLORS.get(item_name, INVENTORY_BACKPLATE_DEFAULT)
	host.add_theme_stylebox_override("panel", _make_inventory_backplate_style(base_color))


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
	var panel_rect = $MarginContainer.get_global_rect()
	return panel_rect.position + panel_rect.size * 0.5


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
	_refresh_tutorial_panel_state()
	_layout_quit_container()
	_layout_tutorial_container()
	_position_tutorial_toggle()


func _update_minimap_input_lock() -> void:
	if not is_instance_valid(minimap_panel):
		_minimap_drag_locked = false
		return
	var should_lock = Global.is_dragging or next_agent != null
	if should_lock == _minimap_drag_locked:
		return
	_minimap_drag_locked = should_lock
	if minimap_panel.has_method("set_input_enabled"):
		minimap_panel.call("set_input_enabled", not should_lock)


func _ensure_tutorial_panel_toggle() -> void:
	var tutorial = get_node_or_null("TutorialMarginContainer1")
	if not is_instance_valid(tutorial):
		return
	tutorial.clip_contents = true
	if not is_instance_valid(_tutorial_toggle_button):
		_tutorial_toggle_button = Button.new()
		_tutorial_toggle_button.name = "ToggleButton"
		_tutorial_toggle_button.text = "X"
		_tutorial_toggle_button.custom_minimum_size = Vector2(28, 28)
		_tutorial_toggle_button.focus_mode = Control.FOCUS_NONE
		_tutorial_toggle_button.z_as_relative = false
		_tutorial_toggle_button.z_index = 120
		_tutorial_toggle_button.add_theme_font_size_override("font_size", 14)
		_tutorial_toggle_button.pressed.connect(_on_tutorial_toggle_pressed)
		add_child(_tutorial_toggle_button)
	_apply_tutorial_panel_state()


func _set_tutorial_collapsed(collapsed: bool) -> void:
	if _tutorial_collapsed == collapsed:
		return
	_tutorial_collapsed = collapsed
	_apply_tutorial_panel_state()


func _apply_tutorial_panel_state() -> void:
	var tutorial = get_node_or_null("TutorialMarginContainer1")
	if not is_instance_valid(tutorial):
		return
	var label: Label = tutorial.get_node_or_null("Label")
	var helper_panel: Panel = tutorial.get_node_or_null("HelperPanel")
	var content_visible = not _tutorial_collapsed
	if is_instance_valid(label):
		label.visible = content_visible
	if is_instance_valid(helper_panel):
		helper_panel.visible = content_visible
	var target_size = TUTORIAL_PANEL_COLLAPSED_SIZE if _tutorial_collapsed else TUTORIAL_PANEL_EXPANDED_SIZE
	tutorial.custom_minimum_size = target_size
	tutorial.size = target_size
	if is_instance_valid(_tutorial_toggle_button):
		_tutorial_toggle_button.text = "i" if _tutorial_collapsed else "X"
		_tutorial_toggle_button.visible = tutorial.visible
	_layout_tutorial_container()
	_position_tutorial_toggle()


func _position_tutorial_toggle() -> void:
	if not is_instance_valid(_tutorial_toggle_button):
		return
	var tutorial = get_node_or_null("TutorialMarginContainer1")
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
	var quit_container: MarginContainer = get_node_or_null("QuitContainer")
	var inventory_panel: MarginContainer = get_node_or_null("MarginContainer")
	if not is_instance_valid(quit_container) or not is_instance_valid(inventory_panel):
		return
	var inventory_left = inventory_panel.get_global_rect().position.x
	var midpoint = inventory_left * 0.5
	var width = quit_container.size.x
	if width <= 0.0:
		width = quit_container.custom_minimum_size.x
	if width <= 0.0:
		width = 112.0
	quit_container.offset_left = round(midpoint - width * 0.5)
	quit_container.offset_right = round(midpoint + width * 0.5)


func _layout_tutorial_container() -> void:
	var tutorial: Control = get_node_or_null("TutorialMarginContainer1")
	if not is_instance_valid(tutorial) or not tutorial.visible:
		return
	var view_rect = get_viewport().get_visible_rect()
	var size = tutorial.size
	if size.x <= 0.0 or size.y <= 0.0:
		size = tutorial.custom_minimum_size
	if size.x <= 0.0 or size.y <= 0.0:
		size = TUTORIAL_PANEL_COLLAPSED_SIZE if _tutorial_collapsed else TUTORIAL_PANEL_EXPANDED_SIZE
	var margin := 12.0
	if _tutorial_collapsed:
		tutorial.global_position = Vector2(
			round(view_rect.position.x + margin),
			round(view_rect.position.y + margin)
		)
		return
	var top_y := 16.0
	var score_container: Control = get_node_or_null("EndGameContainer")
	if is_instance_valid(score_container) and score_container.visible:
		var score_rect = score_container.get_global_rect()
		top_y = score_rect.position.y + score_rect.size.y + 12.0
	var x = view_rect.position.x + (view_rect.size.x - size.x) * 0.5
	x = clampf(x, view_rect.position.x + margin, view_rect.position.x + view_rect.size.x - size.x - margin)
	var y = maxf(top_y, view_rect.position.y + margin)
	tutorial.global_position = Vector2(round(x), round(y))


func _refresh_tutorial_panel_state() -> void:
	var tutorial = get_node_or_null("TutorialMarginContainer1")
	if not is_instance_valid(tutorial):
		return
	if not tutorial.visible:
		_tutorial_last_visible = false
		return
	var label: Label = tutorial.get_node_or_null("Label")
	var current_text := ""
	if is_instance_valid(label):
		current_text = str(label.text)
	if not _tutorial_last_visible:
		_tutorial_last_visible = true
		_tutorial_last_text = current_text
		return
	if current_text != _tutorial_last_text:
		_tutorial_last_text = current_text
		if _tutorial_collapsed:
			_set_tutorial_collapsed(false)


func _on_tutorial_toggle_pressed() -> void:
	_set_tutorial_collapsed(not _tutorial_collapsed)


func _on_score_timer_timeout() -> void:
	#time_elapsed += 1
	#Global.score += 1
	$EndGameContainer/Label.text=str(Global.score)
	


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
	drag_preview_sprite.z_index = 200
	drag_preview_sprite.modulate = Color(1,1,1,0.85)
	add_child(drag_preview_sprite)


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
	drag_preview_sprite.global_position = mouse_pos
	drag_preview_sprite.visible = true


func _update_inventory_drag(mouse_pos: Vector2) -> void:
	if is_instance_valid(drag_preview_sprite) and drag_preview_sprite.visible:
		drag_preview_sprite.global_position = mouse_pos


func _end_inventory_drag() -> void:
	if is_instance_valid(drag_preview_sprite):
		drag_preview_sprite.visible = false
		drag_preview_sprite.texture = null


func _ensure_back_confirm_dialog() -> void:
	if is_instance_valid(_back_confirm_dialog):
		return
	_back_confirm_dialog = ConfirmationDialog.new()
	_back_confirm_dialog.name = "BackConfirmDialog"
	_back_confirm_dialog.title = "Quit game?"
	_back_confirm_dialog.dialog_text = "Are you sure you want to quit?"
	if _back_confirm_dialog.has_method("get_label"):
		var dialog_label = _back_confirm_dialog.call("get_label")
		if dialog_label is Label:
			var label_node: Label = dialog_label
			label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ok_button = _back_confirm_dialog.get_ok_button()
	if is_instance_valid(ok_button):
		ok_button.text = "Yes"
		ok_button.custom_minimum_size = Vector2(140, 56)
		ok_button.add_theme_font_size_override("font_size", 18)
	var cancel_button = _back_confirm_dialog.get_cancel_button()
	if is_instance_valid(cancel_button):
		cancel_button.text = "No"
		cancel_button.custom_minimum_size = Vector2(140, 56)
		cancel_button.add_theme_font_size_override("font_size", 18)
	_back_confirm_dialog.confirmed.connect(_on_back_confirmed)
	_back_confirm_dialog.canceled.connect(_on_back_confirm_canceled)
	add_child(_back_confirm_dialog)


func set_pause_state(paused: bool) -> void:
	get_tree().paused = paused
	var pause_button: Button = get_node_or_null("MarginCMarginContainer2ontainer/HBoxContainer/PauseButton")
	if is_instance_valid(pause_button):
		pause_button.text = "Start" if paused else "Pause"


func show_back_to_menu_confirm() -> void:
	set_pause_state(true)
	_ensure_back_confirm_dialog()
	if is_instance_valid(_back_confirm_dialog):
		_back_confirm_dialog.popup_centered(Vector2i(420, 180))


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


func _drop_inventory_agent(drop_pos: Vector2) -> void:
	if next_agent == null:
		return
	var spawn_name = str(next_agent)
	if int(Global.inventory.get(spawn_name, 0)) <= 0:
		return
	var constrained_type = _is_parent_bounded_inventory_type(spawn_name)
	var target_pos = _screen_to_world(drop_pos)
	var level_root = get_node_or_null("..")
	if is_instance_valid(level_root) and level_root.has_method("try_story_inventory_delivery"):
		# Story farmer-delivery path must be evaluated before parent-anchor checks
		# so constrained crop/myco inventory items can still refill farmer stock.
		if bool(level_root.try_story_inventory_delivery(spawn_name, target_pos)):
			Global.inventory[spawn_name] = int(Global.inventory.get(spawn_name, 0)) - 1
			refresh_inventory_counts()
			return
	var spawn_anchor = null
	var allow_replace = true
	var manual_placement = true
	var view = get_viewport().get_visible_rect()
	if $MarginContainer.get_global_rect().has_point(drop_pos) or not view.has_point(drop_pos):
		var auto_target = _get_auto_spawn_target(spawn_name)
		if not bool(auto_target.get("ok", true)):
			return
		target_pos = auto_target["pos"]
		spawn_anchor = auto_target["anchor"]
		allow_replace = false
		manual_placement = false
	elif constrained_type:
		spawn_anchor = _get_nearest_living_myco_anchor(target_pos, _get_agents_root())
		if not is_instance_valid(spawn_anchor):
			return
	var world = _get_world_foundation()
	if is_instance_valid(world) and world.has_method("is_world_pos_revealed"):
		if not bool(world.is_world_pos_revealed(target_pos)):
			return
	var new_agent_dict = {
		"name" : spawn_name,
		"pos": target_pos,
		"allow_replace": allow_replace,
		"from_inventory": true,
		"manual_placement": manual_placement
	}
	if is_instance_valid(spawn_anchor):
		new_agent_dict["spawn_anchor"] = spawn_anchor
		if constrained_type:
			new_agent_dict["parent_anchor"] = spawn_anchor
			new_agent_dict["max_parent_tiles"] = PARENT_BOUNDED_MAX_TILES
	emit_signal("new_agent", new_agent_dict)
	Global.inventory[spawn_name] = int(Global.inventory.get(spawn_name, 0)) - 1
	refresh_inventory_counts()


func _on_inventory_pointer_moved(screen_pos: Vector2) -> void:
	if next_agent != null:
		_update_inventory_drag(screen_pos)
		_emit_inventory_drag_preview(next_agent, screen_pos, true)


func _on_inventory_pointer_pressed(screen_pos: Vector2) -> void:
	var selected = _get_inventory_agent_at(screen_pos)
	if selected != "" and Global.inventory[selected] > 0:
		next_agent = selected
		_start_inventory_drag(selected, screen_pos)
		_emit_inventory_drag_preview(selected, screen_pos, true)
		_update_minimap_input_lock()


func _on_inventory_pointer_released(screen_pos: Vector2) -> void:
	if next_agent != null:
		_drop_inventory_agent(screen_pos)
		_emit_inventory_drag_preview(next_agent, screen_pos, false)
	next_agent = null
	_end_inventory_drag()
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
			_on_inventory_pointer_pressed(event.position)
		else:
			_on_inventory_pointer_released(event.position)
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if _active_touch_drag_id != -1 and event.index != _active_touch_drag_id:
				return
			_active_touch_drag_id = event.index
			_on_inventory_pointer_pressed(event.position)
		else:
			if event.index != _active_touch_drag_id:
				return
			_on_inventory_pointer_released(event.position)
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
	Global.score = 0
	get_tree().call_deferred("change_scene_to_file","res://scenes/title_screen.tscn")


func _on_quit_button_pressed() -> void:
	show_back_to_menu_confirm()


func _on_pause_button_pressed() -> void:
	var next_paused = not get_tree().paused
	set_pause_state(next_paused)
	if not next_paused:
		hide_back_to_menu_confirm()
