extends RefCounted
## Shared, code-native terminal styling. No external artwork.
const PX := 3.0
const CYAN := Color("4ef2d2")
const AMBER := Color("ff9e44")

static func box(bg: String, border: String, _radius: int = 0) -> StyleBoxTexture:
	return make_pixel_panel(Color(bg), Color("070c14"), Color(border), Color("09121c"))

static func make_pixel_panel(bg: Color, border: Color, light: Color, dark: Color) -> StyleBoxTexture:
	# Nine-slice pixel texture: real stepped chamfers, bevels and corner fasteners.
	var img := Image.create(24,24,false,Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for y in range(24):
		for x in range(24):
			if x+y < 3 or (23-x)+y < 3 or x+(23-y) < 3 or (23-x)+(23-y) < 3: continue
			var c := bg
			if x == 0 or y == 0 or x == 23 or y == 23: c = border
			elif x <= 2 or y <= 2: c = light
			elif x >= 21 or y >= 21: c = dark
			elif (x == 4 or x == 19) and (y == 4 or y == 19): c = light
			img.set_pixel(x,y,c)
	var style := StyleBoxTexture.new()
	img.resize(72,72,Image.INTERPOLATE_NEAREST)
	style.texture = ImageTexture.create_from_image(img)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		style.set_texture_margin(side, 21)
		style.set_content_margin(side, 14 if side in [SIDE_TOP,SIDE_BOTTOM] else 20)
	return style

static func secondary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", box("182838", "3a5775"))

static func danger_hazard(button: Button) -> void:
	button.add_theme_stylebox_override("normal", box("4a220b", "ffd166"))

static func pulse(button: Button, host: Control) -> void:
	if button.has_meta("pixel_pulse"): return
	button.set_meta("pixel_pulse", true)
	var tw := host.create_tween().set_loops()
	tw.tween_property(button, "self_modulate", Color(1.12,1.12,1.12), 0.8)
	tw.tween_property(button, "self_modulate", Color.WHITE, 0.8)

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 17
	t.set_color("font_color", "Label", Color("e8f1f5"))
	t.set_stylebox("panel", "PanelContainer", box("0d1e2e", "3a5775"))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var bg := "182838"
		var edge := "3a5775"
		if state == "hover" or state == "focus": edge = "4ef2d2"
		if state == "pressed":
			bg = "1b6b6e"
			edge = "4ef2d2"
		t.set_stylebox(state, "Button", box(bg, edge, 10))
	t.set_color("font_color", "Button", Color("e8f1f5"))
	t.set_color("font_disabled_color", "Button", Color("7d9bb8"))
	return t

static func primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", box("1b6b6e", "4ef2d2", 10))

static func _stop_juice(b: Button) -> void:
	if not b.has_meta("pixel_juice_tween"): return
	var old: Tween = b.get_meta("pixel_juice_tween", null)
	if old != null and old.is_valid(): old.kill()

static func setup_button_juice(b: Button, host: Control) -> void:
	if b.has_meta("pixel_juice_ready"): return
	b.set_meta("pixel_juice_ready", true)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.pivot_offset = b.size * 0.5
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	var reset := func():
		_stop_juice(b)
		b.modulate = Color.WHITE
		b.scale = Vector2.ONE
	b.visibility_changed.connect(reset)
	b.focus_exited.connect(reset)
	b.button_down.connect(func():
		_stop_juice(b)
		b.modulate = CYAN
		b.scale = Vector2(0.96,0.96)
	)
	b.button_up.connect(func():
		_stop_juice(b)
		var tw := host.create_tween()
		b.set_meta("pixel_juice_tween",tw)
		tw.tween_property(b,"modulate",Color.WHITE,0.15)
		tw.parallel().tween_property(b,"scale",Vector2.ONE,0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)


static func prepare_screen(screen: Control, max_width: float = 760) -> void:
	screen.theme = make_theme()
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
			setup_button_juice(child, screen)
	screen.visibility_changed.connect(func():
		if screen.visible:
			screen.modulate.a = 0.0
			screen.create_tween().tween_property(screen, "modulate:a", 1.0, 0.25)
	)
