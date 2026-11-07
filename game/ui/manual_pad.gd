extends Control
## Explicit manual emulator; supports independent fingers, desktop mouse,
## left/right hand mirroring, and visual ON/OFF threshold indicators.
signal channels_changed(a: float, b: float)
var _touches: Dictionary = {}
var _mouse_channel: int = -1
var _values := Vector2.ZERO
var mirrored: bool = false
var on_a: float = 0.55
var off_a: float = 0.40
var on_b: float = 0.55
var off_b: float = 0.40


func _ready() -> void:
	custom_minimum_size = Vector2(0, 92)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_mirrored(value: bool) -> void:
	if mirrored == value:
		return
	mirrored = value
	queue_redraw()


func set_thresholds(p_on_a: float, p_off_a: float, p_on_b: float, p_off_b: float) -> void:
	on_a = clampf(p_on_a, 0.05, 0.95)
	off_a = clampf(p_off_a, 0.0, on_a - 0.01)
	on_b = clampf(p_on_b, 0.05, 0.95)
	off_b = clampf(p_off_b, 0.0, on_b - 0.01)
	queue_redraw()


func clear() -> void:
	_touches.clear()
	_mouse_channel = -1
	_publish()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			var channel := _channel_at(event.position)
			if channel >= 0:
				_touches[event.index] = channel
		else:
			_touches.erase(event.index)
		_publish()
	elif event is InputEventScreenDrag and _touches.has(event.index):
		if _channel_at(event.position) != _touches[event.index]:
			_touches.erase(event.index)
			_publish()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_channel = _channel_at(event.position) if event.pressed else -1
			_publish()
	elif event is InputEventMouseMotion and _mouse_channel >= 0:
		if _channel_at(event.position) != _mouse_channel:
			_mouse_channel = -1
			_publish()


func _channel_at(viewport_position: Vector2) -> int:
	var local := get_global_transform_with_canvas().affine_inverse() * viewport_position
	for channel in range(2):
		if _pad_rect(channel).has_point(local):
			return channel
	return -1


func _pad_rect(channel: int) -> Rect2:
	var width := (size.x - 16.0) / 2.0
	var slot := (1 - channel) if mirrored else channel
	return Rect2(slot * (width + 16.0), 0, width, size.y)


func _publish() -> void:
	var values := Vector2.ZERO
	for channel in _touches.values():
		values[channel] = 1.0
	if _mouse_channel >= 0:
		values[_mouse_channel] = 1.0
	if values != _values:
		_values = values
		channels_changed.emit(values.x, values.y)
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for channel in range(2):
		var rect := _pad_rect(channel)
		var active_val := _values[channel]
		var on_th := on_a if channel == 0 else on_b
		var off_th := off_a if channel == 0 else off_b
		var style := StyleBoxFlat.new()
		style.bg_color = Color("237f85") if active_val >= on_th else Color("263e58")
		style.border_color = Color("8af0d4") if active_val >= on_th else Color("3b5d7a")
		style.set_border_width_all(2)
		style.set_corner_radius_all(14)
		draw_style_box(style, rect)
		# Draw live signal meter bar along bottom of button with ON/OFF threshold ticks
		var meter_rect := Rect2(rect.position.x + 14.0, rect.end.y - 16.0, maxf(20.0, rect.size.x - 28.0), 8.0)
		draw_rect(meter_rect, Color("101d30"))
		if active_val > 0.0:
			var fill_w := meter_rect.size.x * clampf(active_val, 0.0, 1.0)
			draw_rect(Rect2(meter_rect.position, Vector2(fill_w, meter_rect.size.y)), Color("8af0d4"))
		var off_x := meter_rect.position.x + meter_rect.size.x * off_th
		var on_x := meter_rect.position.x + meter_rect.size.x * on_th
		draw_line(Vector2(off_x, meter_rect.position.y - 2.0), Vector2(off_x, meter_rect.end.y + 2.0), Color("ffd166"), 2.0)
		draw_line(Vector2(on_x, meter_rect.position.y - 3.0), Vector2(on_x, meter_rect.end.y + 3.0), Color.WHITE, 2.0)
		var text := "A · OPEN ↑ [ЭМУЛ]" if channel == 0 else "B · CLOSE ↓ [ЭМУЛ]"
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
		draw_string(font, rect.get_center() + Vector2(-text_size.x / 2.0, 2.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
