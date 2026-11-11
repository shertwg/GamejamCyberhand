extends Control
## One modal for game actions and preferences. The host owns pause and saves.
signal closed
signal save_requested
signal replay_requested
signal quit_requested
signal hand_requested(left: bool)
signal setting_changed(key: String, value: Variant)
signal vibration_preview

const AMBER := Color("f4ca83")
const INK := Color("131623")
const MIST := Color("b6b9ca")
var _panel: PanelContainer
var _body: VBoxContainer
var _status: Label
var _close: Button
var _tabs: Array[Button] = []
var _page := 0
var _values: Dictionary
var _left := false
var _can_replay := false
var _fade: Tween
var _tick := AudioStreamPlayer.new()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_tick.stream = preload("res://assets/last_light/audio/click.wav")
	_tick.bus = &"KernaEffects"
	_tick.volume_db = -21
	add_child(_tick)
	var shade := ColorRect.new()
	shade.color = Color(0.028, 0.035, 0.068, 0.78)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _box(INK, Color("8d6952"), 18))
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	var title := _label("Маяк  /  Последний свет", 23, AMBER)
	title.clip_text = true
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(title)
	_close = _button("Закрыть", func(): closed.emit())
	head.add_child(_close)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 7)
	column.add_child(tabs)
	for i in range(3):
		var tab := _button(["Игра", "Звук", "Управление"][i], _show_page.bind(i))
		tab.size_flags_horizontal = SIZE_EXPAND_FILL
		tabs.add_child(tab)
		_tabs.append(tab)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	_body.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_body)
	_status = _label("", 15, AMBER)
	_status.custom_minimum_size.y = 23
	column.add_child(_status)
	resized.connect(_layout)
	hide()

func open(settings: Dictionary, left: bool, can_replay: bool) -> void:
	_values = settings
	_left = left
	_can_replay = can_replay
	set_status("")
	show()
	_layout()
	_show_page(0)
	_close.grab_focus()
	if _fade != null: _fade.kill()
	modulate.a = 1.0
	if not _values.reduce_motion:
		modulate.a = 0.0
		_fade = create_tween()
		_fade.tween_property(self, "modulate:a", 1.0, 0.17).set_trans(Tween.TRANS_QUAD)

func set_status(message: String) -> void:
	_status.text = message

func snap_open() -> void:
	if _fade != null: _fade.kill()
	modulate.a = 1.0

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.keycode != KEY_TAB: return
	var controls: Array[Control] = []
	for node in find_children("*", "Control", true, false):
		var item := node as Control
		if item.focus_mode == FOCUS_ALL and item.is_visible_in_tree() and not (item is Button and item.disabled):
			controls.append(item)
	if controls.is_empty(): return
	var index := controls.find(get_viewport().gui_get_focus_owner())
	var next := posmod(index + (-1 if event.shift_pressed else 1), controls.size())
	controls[next].grab_focus()
	get_viewport().set_input_as_handled()

func _layout() -> void:
	_panel.size = Vector2(clampf(size.x - 28, 0, 620), clampf(size.y - 24, 0, 512))
	_panel.position = ((size - _panel.size) * 0.5).round()

func _show_page(page: int) -> void:
	_page = page
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	for i in range(_tabs.size()):
		_tabs[i].add_theme_stylebox_override("normal", _box(Color("4b372c"), AMBER, 8) if i == page else _box(Color("252737"), Color("61515a"), 8))
	match page:
		0:
			_body.add_child(_button("Продолжить игру", func(): closed.emit(), true))
			_body.add_child(_button("Сохранить", func(): save_requested.emit()))
			if _can_replay: _body.add_child(_button("Повторить вступление", func(): replay_requested.emit()))
			_body.add_child(_button("Сохранить и выйти", func(): quit_requested.emit()))
		1:
			_slider("Общая громкость", "master")
			_slider("Музыка", "music")
			_slider("Звуки и окружение", "effects")
			_slider("Сила виброотклика", "vibration")
			var note := _label("Вступление использует общий звуковой микс.", 14, MIST)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_body.add_child(note)
			if OS.has_feature("mobile"):
				_body.add_child(_button("Проверить вибрацию", func(): vibration_preview.emit()))
			else:
				_body.add_child(_label("Виброотклик доступен на мобильном устройстве.", 14, MIST))
		2:
			var hand := _button("Ведущая рука · " + ("Левая" if _left else "Правая"), Callable())
			hand.pressed.connect(func():
				_left = not _left
				hand.text = "Ведущая рука · " + ("Левая" if _left else "Правая")
				hand_requested.emit(_left))
			_body.add_child(hand)
			_toggle("A/B ближе к одной руке", "one_hand")
			_toggle("Увеличенные зоны A/B", "large_pad")
			_toggle("Крупные подсказки", "large_text")
			_toggle("Меньше движения", "reduce_motion")
			var description := _label("Рука меняет расположение кнопок. Сигналы A и B сохраняют назначение.", 14, MIST)
			description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_body.add_child(description)

func _slider(title: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_body.add_child(row)
	var label := _label(title, 15, Color("f7ebdd"))
	label.custom_minimum_size.x = 148
	row.add_child(label)
	var slider := HSlider.new()
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(_values[key])
	slider.size_flags_horizontal = SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = 40
	var track := _box(Color("222b3a"), Color("50465a"), 0)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", _box(Color("668a86"), Color("85b3a6"), 0))
	slider.add_theme_stylebox_override("grabber_area_highlight", _box(Color("b58e63"), AMBER, 0))
	row.add_child(slider)
	var number := _label("%d%%" % roundi(slider.value * 100), 15, AMBER)
	number.custom_minimum_size.x = 44
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(number)
	slider.value_changed.connect(func(value: float):
		number.text = "%d%%" % roundi(value * 100)
		setting_changed.emit(key, value))

func _toggle(title: String, key: String) -> void:
	var button := _button(title, Callable())
	button.toggle_mode = true
	button.button_pressed = bool(_values[key])
	button.text = title + ("  ✓" if button.button_pressed else "  —")
	button.toggled.connect(func(enabled: bool):
		button.text = title + ("  ✓" if enabled else "  —")
		setting_changed.emit(key, enabled))
	_body.add_child(button)

func _label(title: String, points: int, color: Color) -> Label:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", color)
	return label

func _button(title: String, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 43
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _box(Color("49352a") if primary else Color("252737"), Color("bd9061") if primary else Color("61515a"), 8))
	button.add_theme_stylebox_override("hover", _box(Color("3d3544"), AMBER, 8))
	button.add_theme_stylebox_override("pressed", _box(Color("503930"), AMBER, 8))
	var focus := _box(Color.TRANSPARENT, Color("89d6cd"), 8)
	focus.draw_center = false
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(func():
		if DisplayServer.get_name() != "headless": _tick.play())
	if callback.is_valid(): button.pressed.connect(callback)
	return button

func _box(fill: Color, edge: Color, padding: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(padding)
	return box
