extends PanelContainer

const DesignTheme = preload("res://game/ui/ui_theme.gd")

signal channel_changed(channel: String, value: float)

const PAD_HOLD_VALUE := 0.85

var hand: String = "right"
var interaction_blocked: bool = false
var header_grid: GridContainer
var pads_grid: GridContainer
var columns_by_channel: Dictionary = {}
var pad_buttons: Dictionary = {}
var sliders: Dictionary = {}
var min_labels: Dictionary = {}
var max_labels: Dictionary = {}
var _channel_values: Dictionary = {"A": 0.0, "B": 0.0}
var _touches_by_channel: Dictionary = {"A": {}, "B": {}}
var _mouse_held: Dictionary = {"A": false, "B": false}
var _visual_blend: Dictionary = {"A": 0.0, "B": 0.0}


func _ready() -> void:
	if theme == null:
		theme = DesignTheme.get_shared_theme()
	theme_type_variation = DesignTheme.TYPE_FIELD_SURFACE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_or_bind()
	apply_hand_layout(hand)
	_update_all_pad_visuals()


func _process(delta: float) -> void:
	var dirty := false
	for ch in ["A", "B"]:
		var is_active := _is_pad_pressed(ch) or float(_channel_values.get(ch, 0.0)) >= 0.35
		var target := 1.0 if is_active else 0.0
		var current := float(_visual_blend.get(ch, 0.0))
		if not is_equal_approx(current, target):
			_visual_blend[ch] = move_toward(current, target, delta * 12.0)
			dirty = true
			if pad_buttons.has(ch) and is_instance_valid(pad_buttons[ch]):
				(pad_buttons[ch] as Control).queue_redraw()
	if not dirty:
		set_process(false)


func _build_or_bind() -> void:
	var margin := get_node_or_null("SurfaceMargin") as MarginContainer
	if margin == null:
		margin = MarginContainer.new()
		margin.name = "SurfaceMargin"
		margin.add_theme_constant_override("margin_left", DesignTheme.SPACE_200)
		margin.add_theme_constant_override("margin_top", DesignTheme.SPACE_100)
		margin.add_theme_constant_override("margin_right", DesignTheme.SPACE_200)
		margin.add_theme_constant_override("margin_bottom", DesignTheme.SPACE_100)
		add_child(margin)

	var content := margin.get_node_or_null("SurfaceContent") as VBoxContainer
	if content == null:
		content = VBoxContainer.new()
		content.name = "SurfaceContent"
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation", DesignTheme.SPACE_050)
		margin.add_child(content)

	header_grid = content.get_node_or_null("HeaderGrid") as GridContainer
	if header_grid == null:
		header_grid = GridContainer.new()
		header_grid.name = "HeaderGrid"
		header_grid.columns = 2
		header_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_grid.add_theme_constant_override("h_separation", DesignTheme.SPACE_200)
		header_grid.add_theme_constant_override("v_separation", DesignTheme.SPACE_050)
		content.add_child(header_grid)
		header_grid.add_child(_make_label("ЭМУЛЯТОР · ТОЛЬКО ТЕСТОВЫЙ ВВОД", "EyebrowLabel", "EmulatorEyebrow"))
		header_grid.add_child(_make_label("Кнопки касания и ползунки отправляют значения в локальный адаптер.", "SubtleLabel", "EmulatorSubtitle"))

	pads_grid = content.get_node_or_null("PadsGrid") as GridContainer
	if pads_grid == null:
		pads_grid = GridContainer.new()
		pads_grid.name = "PadsGrid"
		pads_grid.columns = 2
		pads_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pads_grid.add_theme_constant_override("h_separation", DesignTheme.SPACE_200)
		pads_grid.add_theme_constant_override("v_separation", DesignTheme.SPACE_100)
		content.add_child(pads_grid)

	for ch in ["A", "B"]:
		_ensure_channel_column(ch)


func _ensure_channel_column(channel: String) -> void:
	var col_name := "Channel%sColumn" % channel
	var col := pads_grid.get_node_or_null(col_name) as VBoxContainer
	var direction := "OPEN" if channel == "A" else "CLOSE"
	if col == null:
		col = VBoxContainer.new()
		col.name = col_name
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", DesignTheme.SPACE_050)
		pads_grid.add_child(col)
		col.add_child(_make_label("ТЕСТОВЫЙ КАНАЛ %s → %s" % [channel, direction], "SubtleLabel", "Channel%sTitle" % channel))

	var pad_name := "PadButton%s" % channel
	var pad := col.get_node_or_null(pad_name) as Button
	if pad == null:
		pad = Button.new()
		pad.name = pad_name
		pad.custom_minimum_size = Vector2(140, 56)
		pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pad.focus_mode = Control.FOCUS_ALL
		pad.theme_type_variation = DesignTheme.TYPE_PAD_BUTTON
		col.add_child(pad)
	pad.button_mask = 0
	var ch_key := channel
	if not pad.draw.is_connected(_on_pad_draw.bind(ch_key)):
		pad.draw.connect(_on_pad_draw.bind(ch_key))

	var slider_name := "Slider%s" % channel
	var slider := col.get_node_or_null(slider_name) as HSlider
	if slider == null:
		slider = HSlider.new()
		slider.name = slider_name
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.page = 0.1
		slider.custom_minimum_size = Vector2(0, 28)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(slider)
	if not slider.value_changed.is_connected(_on_slider_value_changed.bind(ch_key)):
		slider.value_changed.connect(_on_slider_value_changed.bind(ch_key))

	var ends_name := "ScaleRow%s" % channel
	var ends := col.get_node_or_null(ends_name) as HBoxContainer
	if ends == null:
		ends = HBoxContainer.new()
		ends.name = ends_name
		col.add_child(ends)
		var min_lbl := _make_label("0.00", "SubtlestLabel", "MinLabel%s" % channel)
		min_lbl.size_flags_horizontal = Control.SIZE_FILL
		min_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		ends.add_child(min_lbl)
		var scale_note := _make_label("Удерживай кнопку или ползунок", "SubtlestLabel", "ScaleNote%s" % channel)
		scale_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ends.add_child(scale_note)
		var max_lbl := _make_label("1.00", "SubtlestLabel", "MaxLabel%s" % channel)
		max_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		max_lbl.size_flags_horizontal = Control.SIZE_FILL
		max_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		ends.add_child(max_lbl)

	columns_by_channel[channel] = col
	pad_buttons[channel] = pad
	sliders[channel] = slider
	min_labels[channel] = ends.get_node_or_null("MinLabel%s" % channel) as Label
	max_labels[channel] = ends.get_node_or_null("MaxLabel%s" % channel) as Label


func _make_label(text_value: String, role: String, node_name: String) -> Label:
	var lbl := Label.new()
	lbl.name = node_name
	lbl.text = text_value
	lbl.theme_type_variation = role
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl


func apply_hand_layout(selected_hand: String) -> void:
	hand = selected_hand
	if pads_grid == null or not columns_by_channel.has("A") or not columns_by_channel.has("B"):
		return
	var first_ch := "A" if hand == "right" else "B"
	var second_ch := "B" if hand == "right" else "A"
	pads_grid.move_child(columns_by_channel[first_ch], 0)
	pads_grid.move_child(columns_by_channel[second_ch], 1)

	for ch in ["A", "B"]:
		var slider := sliders.get(ch) as HSlider
		if slider != null:
			slider.layout_direction = Control.LAYOUT_DIRECTION_RTL if hand == "left" else Control.LAYOUT_DIRECTION_LTR
		var min_lbl := min_labels.get(ch) as Label
		var max_lbl := max_labels.get(ch) as Label
		if min_lbl != null and max_lbl != null:
			min_lbl.text = "1.00" if hand == "left" else "0.00"
			max_lbl.text = "0.00" if hand == "left" else "1.00"


func update_responsive_metrics(viewport_size: Vector2, dp_unit: float) -> void:
	var two_col := 2 if viewport_size.x >= 640.0 else 1
	if header_grid != null:
		header_grid.columns = two_col
	if pads_grid != null:
		pads_grid.columns = two_col
	var compact_landscape := viewport_size.y <= 740.0 and viewport_size.x >= 640.0
	var pad_dp_h := 48.0 if compact_landscape else 64.0
	var pad_h := maxf(48.0, roundf(pad_dp_h * dp_unit))
	var pad_w := maxf(140.0, roundf(140.0 * dp_unit))
	var slider_h := maxf(20.0, roundf((22.0 if compact_landscape else 28.0) * dp_unit))
	for ch in ["A", "B"]:
		var pad := pad_buttons.get(ch) as Button
		if pad != null:
			pad.custom_minimum_size = Vector2(pad_w, pad_h)
		var slider := sliders.get(ch) as HSlider
		if slider != null:
			slider.custom_minimum_size = Vector2(0, slider_h)


func set_channel_display(channel: String, value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	_channel_values[channel] = clamped
	if sliders.has(channel) and is_instance_valid(sliders[channel]):
		(sliders[channel] as HSlider).set_value_no_signal(clamped)
	_update_pad_visual(channel)
	set_process(true)


func clear_all_touches() -> void:
	_touches_by_channel["A"].clear()
	_touches_by_channel["B"].clear()
	_mouse_held["A"] = false
	_mouse_held["B"] = false
	_update_all_pad_visuals()


func simulate_touch_event(channel: String, touch_index: int, pressed: bool) -> void:
	if interaction_blocked:
		return
	var dict: Dictionary = _touches_by_channel[channel]
	if pressed:
		dict[touch_index] = true
		_set_pad_channel_value(channel, PAD_HOLD_VALUE)
	else:
		dict.erase(touch_index)
		if not _is_pad_pressed(channel):
			_set_pad_channel_value(channel, 0.0)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or interaction_blocked:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var canvas_pos := _screen_to_global_canvas(touch.position)
		if touch.pressed:
			for ch in ["A", "B"]:
				var pad := pad_buttons.get(ch) as Button
				if pad != null and pad.get_global_rect().has_point(canvas_pos):
					_touches_by_channel[ch][touch.index] = true
					_set_pad_channel_value(ch, PAD_HOLD_VALUE)
		else:
			for ch in ["A", "B"]:
				var dict: Dictionary = _touches_by_channel[ch]
				if dict.has(touch.index):
					dict.erase(touch.index)
					if not _is_pad_pressed(ch):
						_set_pad_channel_value(ch, 0.0)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		var canvas_pos := _screen_to_global_canvas(drag.position)
		for ch in ["A", "B"]:
			var pad := pad_buttons.get(ch) as Button
			if pad == null:
				continue
			var dict: Dictionary = _touches_by_channel[ch]
			var inside := pad.get_global_rect().has_point(canvas_pos)
			if inside and not dict.has(drag.index):
				dict[drag.index] = true
				_set_pad_channel_value(ch, PAD_HOLD_VALUE)
			elif not inside and dict.has(drag.index):
				dict.erase(drag.index)
				if not _is_pad_pressed(ch):
					_set_pad_channel_value(ch, 0.0)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.device == InputEvent.DEVICE_ID_EMULATION or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var canvas_pos := _screen_to_global_canvas(mb.position)
		if mb.pressed:
			for ch in ["A", "B"]:
				var pad := pad_buttons.get(ch) as Button
				if pad != null and pad.get_global_rect().has_point(canvas_pos):
					_mouse_held[ch] = true
					_set_pad_channel_value(ch, PAD_HOLD_VALUE)
		else:
			for ch in ["A", "B"]:
				if _mouse_held[ch]:
					_mouse_held[ch] = false
					if not _is_pad_pressed(ch):
						_set_pad_channel_value(ch, 0.0)


func _screen_to_global_canvas(event_pos: Vector2) -> Vector2:
	return event_pos


func _is_pad_pressed(channel: String) -> bool:
	var dict: Dictionary = _touches_by_channel.get(channel, {})
	return not dict.is_empty() or bool(_mouse_held.get(channel, false))


func _set_pad_channel_value(channel: String, value: float) -> void:
	set_channel_display(channel, value)
	channel_changed.emit(channel, value)


func _on_slider_value_changed(value: float, channel: String) -> void:
	if interaction_blocked:
		return
	_channel_values[channel] = clampf(value, 0.0, 1.0)
	_update_pad_visual(channel)
	set_process(true)
	channel_changed.emit(channel, value)


func _update_all_pad_visuals() -> void:
	for ch in ["A", "B"]:
		_update_pad_visual(ch)


func _update_pad_visual(channel: String) -> void:
	var pad := pad_buttons.get(channel) as Button
	if pad == null:
		return
	var direction := "OPEN" if channel == "A" else "CLOSE"
	var val := float(_channel_values.get(channel, 0.0))
	var active := _is_pad_pressed(channel) or val >= 0.35
	if active:
		pad.theme_type_variation = DesignTheme.TYPE_PAD_BUTTON_ACTIVE
		pad.text = "◆ КАНАЛ %s · %s ◆\n[ АКТИВЕН · %.2f ]" % [channel, direction, val]
	else:
		pad.theme_type_variation = DesignTheme.TYPE_PAD_BUTTON
		pad.text = "КАНАЛ %s · %s\n[ ОТПУЩЕНО · %.2f ]" % [channel, direction, val]
	pad.queue_redraw()


func _on_pad_draw(channel: String) -> void:
	var pad := pad_buttons.get(channel) as Button
	if pad == null:
		return
	var val := clampf(float(_channel_values.get(channel, 0.0)), 0.0, 1.0)
	var blend := clampf(float(_visual_blend.get(channel, 0.0)), 0.0, 1.0)
	var bar_h := 5.0
	var margin_x := 8.0
	var avail_w := maxf(0.0, pad.size.x - margin_x * 2.0)
	var track_rect := Rect2(Vector2(margin_x, pad.size.y - bar_h - 4.0), Vector2(avail_w, bar_h))
	pad.draw_rect(track_rect, DesignTheme.COLOR_NEUTRAL_HOVER, true)
	var fill_ratio := maxf(val, blend * 0.85) if (_is_pad_pressed(channel) or val >= 0.35) else val
	if fill_ratio > 0.01:
		var fill_rect := Rect2(track_rect.position, Vector2(avail_w * fill_ratio, bar_h))
		pad.draw_rect(fill_rect, DesignTheme.COLOR_BRAND, true)
	if blend > 0.05:
		var inset := Rect2(Vector2(3.0, 3.0), pad.size - Vector2(6.0, 6.0))
		var highlight_col := Color(DesignTheme.COLOR_FOCUS.r, DesignTheme.COLOR_FOCUS.g, DesignTheme.COLOR_FOCUS.b, 0.35 * blend)
		pad.draw_rect(inset, highlight_col, false, 2.0)
