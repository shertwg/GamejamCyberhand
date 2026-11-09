extends Control
## Explicit manual emulator; supports independent fingers, desktop mouse,
## left/right hand mirroring, and visual ON/OFF threshold indicators.
signal channels_changed(a: float, b: float)
const Copy = preload("res://game/content/copy_catalog.gd")
var _visual := Vector2.ZERO

func _process(delta: float) -> void:
	_visual = _visual.lerp(_values, minf(1, delta * 18))
	if _visual.distance_to(_values) > 0.001: queue_redraw()

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
	var px := 3.0
	for channel in range(2):
		var rect := _pad_rect(channel)
		var accent := Color("8af0d4") if channel == 0 else Color("df9675")
		var is_both := _values.x > 0 and _values.y > 0
		var active_val := _values[channel]
		var on_th := on_a if channel == 0 else on_b
		var off_th := off_a if channel == 0 else off_b
		var is_pressed := active_val >= on_th
		var press_offset := Vector2(px, px) if is_pressed else Vector2.ZERO

		# 1. Beveled 3D Retro Pixel Button
		var b_rect := Rect2(rect.position + press_offset, rect.size - press_offset)
		var bg_col := (Color("1d5e63") if channel == 0 else Color("8a4325")) if is_pressed else Color("12263a")
		draw_rect(b_rect, bg_col)

		# Pixel Border & 3D Bevel
		var hi_col := Color("ffffff") if is_pressed else (Color("ffd166") if is_both else accent)
		var shadow_col := Color("08111d")
		# Top & Left highlight
		draw_rect(Rect2(b_rect.position, Vector2(b_rect.size.x, px)), hi_col)
		draw_rect(Rect2(b_rect.position, Vector2(px, b_rect.size.y)), hi_col)
		# Bottom & Right shadow
		draw_rect(Rect2(Vector2(b_rect.position.x, b_rect.end.y - px), Vector2(b_rect.size.x, px)), shadow_col)
		draw_rect(Rect2(Vector2(b_rect.end.x - px, b_rect.position.y), Vector2(px, b_rect.size.y)), shadow_col)

		# BOTH hazard stripes on border
		if is_both:
			for hx in range(int(b_rect.position.x), int(b_rect.end.x), 12):
				draw_rect(Rect2(hx, b_rect.position.y, px * 2, px), Color("ffd166"))
				draw_rect(Rect2(hx, b_rect.end.y - px, px * 2, px), Color("ffd166"))

		# 2. Segmented Pixel VU-Meter (Discrete Blocks)
		var meter_margin := 16.0
		var meter_w := b_rect.size.x - meter_margin * 2
		var meter_h := 8.0
		var meter_pos := Vector2(b_rect.position.x + meter_margin, b_rect.end.y - 18.0)
		draw_rect(Rect2(meter_pos - Vector2(px, px), Vector2(meter_w + px * 2, meter_h + px * 2)), Color("091420"))

		var num_blocks := 14
		var block_w := (meter_w - (num_blocks - 1) * 2.0) / float(num_blocks)
		var lit_count := int(clampf(active_val, 0.0, 1.0) * num_blocks)
		for b in range(num_blocks):
			var bx := meter_pos.x + b * (block_w + 2.0)
			var b_ratio := float(b + 1) / float(num_blocks)
			var lit := b < lit_count
			var seg_col := Color("142836")
			if lit:
				if b_ratio >= on_th:
					seg_col = Color("ffffff") if channel == 0 else Color("ffd166")
				else:
					seg_col = accent
			draw_rect(Rect2(Vector2(bx, meter_pos.y), Vector2(block_w, meter_h)), seg_col)

		# Pixel Threshold Arrow Markers ▲
		var off_px := meter_pos.x + meter_w * off_th
		var on_px := meter_pos.x + meter_w * on_th
		var mark_y := meter_pos.y + meter_h
		# OFF marker (amber)
		draw_rect(Rect2(Vector2(off_px - 2, mark_y + 2), Vector2(4, 2)), Color("ffd166"))
		draw_rect(Rect2(Vector2(off_px - 1, mark_y + 4), Vector2(2, 2)), Color("ffd166"))
		# ON marker (white)
		draw_rect(Rect2(Vector2(on_px - 2, mark_y + 2), Vector2(4, 2)), Color.WHITE)
		draw_rect(Rect2(Vector2(on_px - 1, mark_y + 4), Vector2(2, 2)), Color.WHITE)

		# 3. Text Label
		var text := (Copy.PAD_A if channel == 0 else Copy.PAD_B) + "  " + Copy.EMULATOR
		if is_both:
			text = Copy.BOTH_WARNING
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		var text_pos := b_rect.get_center() + Vector2(-text_size.x / 2.0, -1.0)
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
