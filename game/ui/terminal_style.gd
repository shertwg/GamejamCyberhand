extends RefCounted
## Shared, code-native terminal styling. No external artwork.
static func box(bg: String, border: String, _radius: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(bg)
	s.border_color = Color(border)
	s.set_border_width_all(2)
	s.set_corner_radius_all(0)
	s.anti_aliasing = false
	s.shadow_size = 4
	s.shadow_offset = Vector2(4,4)
	s.shadow_color = Color("050b14")
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 17
	t.set_color("font_color", "Label", Color("f0f6fc"))
	t.set_stylebox("panel", "PanelContainer", box("12263a", "224263"))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var bg := "18334c"
		var edge := "224263"
		if state == "hover" or state == "focus": edge = "8af0d4"
		if state == "pressed":
			bg = "237f85"
			edge = "8af0d4"
		t.set_stylebox(state, "Button", box(bg, edge, 10))
	t.set_color("font_color", "Button", Color("f0f6fc"))
	t.set_color("font_disabled_color", "Button", Color("8b9bb4"))
	return t

static func primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", box("237f85", "3caea3", 10))

static func prepare_screen(screen: Control, max_width: float = 760) -> void:
	screen.theme = make_theme()
	var scroll := screen.get_node("Center") as ScrollContainer
	var panel := screen.get_node("Center/Panel") as PanelContainer
	var fit := func():
		panel.custom_minimum_size.x = maxf(240, minf(max_width, screen.size.x - 48))
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.offset_left = maxf(24, (screen.size.x - max_width) / 2)
		scroll.offset_right = -scroll.offset_left
		scroll.offset_top = 24
		scroll.offset_bottom = -24
		panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for child in screen.get_node("Center/Panel/VBox").get_children():
			if child is Label:
				child.custom_minimum_size.x = 0
				child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fit.call()
	screen.resized.connect(fit)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	for child in screen.get_node("Center/Panel/VBox").get_children():
		if child is Button:
			child.button_down.connect(func(): child.modulate = Color("8af0d4"))
			child.button_up.connect(func(): screen.create_tween().tween_property(child, "modulate", Color.WHITE, 0.15))
	screen.visibility_changed.connect(func():
		if screen.visible:
			screen.modulate.a = 0.0
			screen.create_tween().tween_property(screen, "modulate:a", 1.0, 0.25)
	)
