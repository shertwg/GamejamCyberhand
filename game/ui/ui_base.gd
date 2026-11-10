extends Control

const RuntimeScript = preload("res://game/ui/ui_demo_runtime.gd")
const DesignTheme = preload("res://game/ui/ui_theme.gd")

const COLOR_TEXT := DesignTheme.COLOR_TEXT
const COLOR_TEXT_SUBTLE := DesignTheme.COLOR_TEXT_SUBTLE
const COLOR_TEXT_SUBTLEST := DesignTheme.COLOR_TEXT_SUBTLEST
const COLOR_SURFACE := DesignTheme.COLOR_SURFACE
const COLOR_CANVAS := DesignTheme.COLOR_CANVAS
const COLOR_NEUTRAL := DesignTheme.COLOR_NEUTRAL
const COLOR_BORDER := DesignTheme.COLOR_BORDER
const COLOR_BRAND := DesignTheme.COLOR_BRAND
const COLOR_SUCCESS := DesignTheme.COLOR_SUCCESS
const COLOR_WARNING := DesignTheme.COLOR_WARNING
const COLOR_DANGER := DesignTheme.COLOR_DANGER
const COLOR_INFORMATION := DesignTheme.COLOR_INFORMATION

var runtime: Node
var page_content: VBoxContainer
var _margin: MarginContainer
var _scroll: ScrollContainer
var _center: CenterContainer
var _tracked_buttons: Array[Button] = []


func _ready() -> void:
	runtime = RuntimeScript.get_or_create(get_tree())
	if runtime != null and runtime.has_method("enter_ui_screen"):
		runtime.enter_ui_screen(get_tree().root)
	if theme == null:
		theme = DesignTheme.get_shared_theme()
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_on_root_viewport_size_changed):
		vp.size_changed.connect(_on_root_viewport_size_changed)
	_build_frame()
	_update_responsive_frame.call_deferred()


func _exit_tree() -> void:
	var vp := get_viewport()
	if vp != null and vp.size_changed.is_connected(_on_root_viewport_size_changed):
		vp.size_changed.disconnect(_on_root_viewport_size_changed)
	if is_instance_valid(runtime) and runtime.has_method("check_restore_window_scale"):
		runtime.check_restore_window_scale.call_deferred()


func _notification(what: int) -> void:
	if (
		what == NOTIFICATION_RESIZED
		or what == NOTIFICATION_WM_SIZE_CHANGED
		or what == NOTIFICATION_APPLICATION_FOCUS_IN
		or what == NOTIFICATION_APPLICATION_RESUMED
		or what == NOTIFICATION_WM_WINDOW_FOCUS_IN
	):
		if is_instance_valid(runtime) and is_inside_tree() and runtime.has_method("update_ui_window_scale"):
			runtime.update_ui_window_scale(get_tree().root)
		_update_responsive_frame()


func _on_root_viewport_size_changed() -> void:
	if is_instance_valid(runtime) and is_inside_tree() and runtime.has_method("update_ui_window_scale"):
		runtime.update_ui_window_scale(get_tree().root)
	_update_responsive_frame()


func _build_frame() -> void:
	var background := get_node_or_null("Background") as ColorRect
	if background == null:
		background = ColorRect.new()
		background.name = "Background"
		background.color = COLOR_CANVAS
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(background)

	_margin = get_node_or_null("SafeAreaMargin") as MarginContainer
	if _margin == null:
		_margin = MarginContainer.new()
		_margin.name = "SafeAreaMargin"
		_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_margin)

	_scroll = _margin.get_node_or_null("PageScroll") as ScrollContainer
	if _scroll == null:
		_scroll = ScrollContainer.new()
		_scroll.name = "PageScroll"
		_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_margin.add_child(_scroll)

	_center = _scroll.get_node_or_null("PageCenter") as CenterContainer
	if _center == null:
		_center = CenterContainer.new()
		_center.name = "PageCenter"
		_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_scroll.add_child(_center)

	page_content = _center.get_node_or_null("PageContent") as VBoxContainer
	if page_content == null:
		page_content = VBoxContainer.new()
		page_content.name = "PageContent"
		page_content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		page_content.add_theme_constant_override("separation", DesignTheme.SPACE_300)
		_center.add_child(page_content)
	_update_responsive_frame()


func get_window_to_viewport_transform() -> Transform2D:
	var vp := get_viewport()
	if vp == null:
		return Transform2D.IDENTITY
	var vp_rect := get_viewport_rect()
	var win_px := Vector2.ZERO
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		win_px = Vector2(get_tree().root.size)
	if win_px.x <= 0.0 or win_px.y <= 0.0:
		win_px = Vector2(DisplayServer.window_get_size())
	var final_xform := vp.get_final_transform()
	if final_xform == Transform2D.IDENTITY and win_px.x > 0.0 and win_px.y > 0.0 and win_px != vp_rect.size:
		var sx := vp_rect.size.x / win_px.x
		var sy := vp_rect.size.y / win_px.y
		return Transform2D(Vector2(sx, 0.0), Vector2(0.0, sy), Vector2.ZERO)
	return final_xform.affine_inverse()


func dp_to_vp(dp_value: float) -> float:
	var dpi := float(DisplayServer.screen_get_dpi())
	if dpi <= 0.0:
		dpi = 160.0
	var screen_scale := maxf(1.0, DisplayServer.screen_get_scale())
	var px_per_dp := maxf(screen_scale, dpi / 160.0)
	var win_to_vp := get_window_to_viewport_transform()
	var vp_scale := maxf(win_to_vp.get_scale().x, win_to_vp.get_scale().y)
	var unit_per_dp := maxf(1.0, px_per_dp * vp_scale)
	return roundf(dp_value * unit_per_dp)


func compute_safe_area_insets_vp() -> Dictionary:
	var vp_rect := get_viewport_rect()
	var win_px := Vector2.ZERO
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		win_px = Vector2(get_tree().root.size)
	if win_px.x <= 0.0 or win_px.y <= 0.0:
		win_px = Vector2(DisplayServer.window_get_size())
	if win_px.x <= 0.0 or win_px.y <= 0.0:
		win_px = vp_rect.size

	var raw_safe := Rect2i()
	var has_simulated := false
	if is_instance_valid(runtime) and runtime.get("simulated_safe_area") is Rect2i:
		var sim: Rect2i = runtime.simulated_safe_area
		if sim.size.x > 0 and sim.size.y > 0:
			raw_safe = sim
			has_simulated = true
	if not has_simulated:
		raw_safe = DisplayServer.get_display_safe_area()

	var is_mobile := OS.get_name() == "Android" or OS.get_name() == "iOS" or OS.has_feature("mobile")
	var safe_win_rect := Rect2(Vector2.ZERO, win_px)
	if raw_safe.size.x > 0 and raw_safe.size.y > 0:
		if has_simulated or is_mobile:
			safe_win_rect = Rect2(Vector2(raw_safe.position), Vector2(raw_safe.size)).intersection(Rect2(Vector2.ZERO, win_px))
		else:
			var win_pos := Vector2(DisplayServer.window_get_position())
			var win_screen_rect := Rect2(win_pos, win_px)
			var raw_safe_f := Rect2(Vector2(raw_safe.position), Vector2(raw_safe.size))
			if raw_safe_f.encloses(win_screen_rect):
				safe_win_rect = Rect2(Vector2.ZERO, win_px)

	if safe_win_rect.size.x <= 0.0 or safe_win_rect.size.y <= 0.0:
		safe_win_rect = Rect2(Vector2.ZERO, win_px)

	var win_to_vp := get_window_to_viewport_transform()
	var safe_vp_tl: Vector2 = win_to_vp * safe_win_rect.position
	var safe_vp_br: Vector2 = win_to_vp * safe_win_rect.end

	return {
		"left": maxf(0.0, safe_vp_tl.x - vp_rect.position.x),
		"top": maxf(0.0, safe_vp_tl.y - vp_rect.position.y),
		"right": maxf(0.0, vp_rect.end.x - safe_vp_br.x),
		"bottom": maxf(0.0, vp_rect.end.y - safe_vp_br.y),
	}


func _update_responsive_frame() -> void:
	if _margin == null or page_content == null:
		return
	var viewport_size := get_viewport_rect().size
	var insets := compute_safe_area_insets_vp()
	var base_h := DesignTheme.SPACE_200 if viewport_size.x < 600.0 else DesignTheme.SPACE_300
	var base_v := DesignTheme.SPACE_100 if viewport_size.y <= 740.0 else DesignTheme.SPACE_200
	var left_m := int(ceilf(float(insets["left"]))) + base_h
	var top_m := int(ceilf(float(insets["top"]))) + base_v
	var right_m := int(ceilf(float(insets["right"]))) + base_h
	var bottom_m := int(ceilf(float(insets["bottom"]))) + base_v
	_margin.add_theme_constant_override("margin_left", left_m)
	_margin.add_theme_constant_override("margin_top", top_m)
	_margin.add_theme_constant_override("margin_right", right_m)
	_margin.add_theme_constant_override("margin_bottom", bottom_m)
	var available_width := maxf(200.0, viewport_size.x - float(left_m + right_m) - 12.0)
	var max_content_w := 880.0 if viewport_size.x >= 1000.0 else 760.0
	page_content.custom_minimum_size.x = minf(max_content_w, available_width)

	var min_btn_h := dp_to_vp(48.0)
	for btn in _tracked_buttons:
		if is_instance_valid(btn):
			btn.custom_minimum_size.y = maxf(48.0, min_btn_h)

	_on_viewport_resized(viewport_size)


func _on_viewport_resized(_viewport_size: Vector2) -> void:
	pass


func _heading(kicker: String, title: String, description: String = "") -> void:
	var header := page_content.get_node_or_null("PageHeader") as VBoxContainer
	if header != null:
		var kicker_lbl := header.get_node_or_null("KickerLabel") as Label
		if kicker_lbl != null:
			kicker_lbl.text = kicker.to_upper()
		return
	header = VBoxContainer.new()
	header.name = "PageHeader"
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", DesignTheme.SPACE_050)
	page_content.add_child(header)
	var brand_line := HBoxContainer.new()
	brand_line.name = "BrandLine"
	brand_line.add_theme_constant_override("separation", DesignTheme.SPACE_100)
	header.add_child(brand_line)
	var mark := _label("◌", "EyebrowLabel", "BrandMark")
	mark.size_flags_horizontal = Control.SIZE_FILL
	mark.autowrap_mode = TextServer.AUTOWRAP_OFF
	brand_line.add_child(mark)
	brand_line.add_child(_label("ОРБИТАЛЬНАЯ МАСТЕРСКАЯ", "EyebrowLabel", "BrandTitle"))
	header.add_child(_label(kicker.to_upper(), "SubtlestLabel", "KickerLabel"))
	var title_label := _label(title, "PageTitle", "PageTitleLabel")
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(title_label)
	if not description.is_empty():
		var detail := _label(description, "SubtleLabel", "PageDescriptionLabel")
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		header.add_child(detail)
	_add_divider(header, "HeaderDivider")


func _label(text_value: String, role: String = "BodyText", node_name: String = "") -> Label:
	var label := Label.new()
	if not node_name.is_empty():
		label.name = node_name
	label.text = text_value
	label.theme_type_variation = role
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _button(parent: Container, text_value: String, action: Callable, primary: bool = false, node_name: String = "") -> Button:
	var existing: Button = null
	if not node_name.is_empty():
		existing = parent.get_node_or_null(node_name) as Button
		if existing == null:
			existing = find_child(node_name, true, false) as Button
	if existing != null:
		if not existing.pressed.is_connected(action):
			existing.pressed.connect(action)
		if not _tracked_buttons.has(existing):
			_tracked_buttons.append(existing)
		existing.custom_minimum_size.y = maxf(existing.custom_minimum_size.y, dp_to_vp(48.0))
		return existing

	var button := Button.new()
	if not node_name.is_empty():
		button.name = node_name
	button.text = text_value
	button.custom_minimum_size = Vector2(0, maxf(48.0, dp_to_vp(48.0)))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.theme_type_variation = DesignTheme.TYPE_PRIMARY if primary else DesignTheme.TYPE_QUIET
	button.pressed.connect(action)
	parent.add_child(button)
	_tracked_buttons.append(button)
	return button


func _section(parent: Container, title: String, subtitle: String = "", section_name: String = "") -> VBoxContainer:
	if not section_name.is_empty():
		var existing_sec := parent.get_node_or_null(section_name) as VBoxContainer
		if existing_sec != null:
			var existing_body := existing_sec.get_node_or_null("SectionBody") as VBoxContainer
			if existing_body != null:
				return existing_body
	var section := VBoxContainer.new()
	if not section_name.is_empty():
		section.name = section_name
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", DesignTheme.SPACE_100)
	parent.add_child(section)
	section.add_child(_label(title, "SectionTitle", "SectionTitleLabel"))
	if not subtitle.is_empty():
		section.add_child(_label(subtitle, "SubtleLabel", "SectionSubtitleLabel"))
	_add_divider(section, "SectionDivider")
	var body := VBoxContainer.new()
	body.name = "SectionBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", DesignTheme.SPACE_100)
	section.add_child(body)
	return body


func _add_divider(parent: Container, node_name: String = "") -> ColorRect:
	var divider := ColorRect.new()
	if not node_name.is_empty():
		divider.name = node_name
	divider.color = COLOR_BORDER
	divider.custom_minimum_size = Vector2(0, 1)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(divider)
	return divider


func _field_surface(parent: Container, surface_name: String = "") -> VBoxContainer:
	if not surface_name.is_empty():
		var existing_panel := parent.get_node_or_null(surface_name) as PanelContainer
		if existing_panel != null:
			var existing_content := existing_panel.find_child("SurfaceContent", true, false) as VBoxContainer
			if existing_content != null:
				return existing_content
	var panel := PanelContainer.new()
	if not surface_name.is_empty():
		panel.name = surface_name
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.theme_type_variation = DesignTheme.TYPE_FIELD_SURFACE
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.name = "SurfaceMargin"
	margin.add_theme_constant_override("margin_left", DesignTheme.SPACE_200)
	margin.add_theme_constant_override("margin_top", DesignTheme.SPACE_150)
	margin.add_theme_constant_override("margin_right", DesignTheme.SPACE_200)
	margin.add_theme_constant_override("margin_bottom", DesignTheme.SPACE_150)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.name = "SurfaceContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", DesignTheme.SPACE_100)
	margin.add_child(content)
	return content


func _go(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
