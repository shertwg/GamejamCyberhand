extends Control
## Explicit manual emulator; supports independent fingers, desktop mouse,
## left/right hand mirroring, and visual ON/OFF threshold indicators.
signal channels_changed(a: float, b: float)
const Copy = preload("res://game/content/copy_catalog.gd")
const Art = preload("res://game/ui/visual_assets.gd")
var _visual := Vector2.ZERO
var _phase := 0.0

func _process(delta: float) -> void:
	_phase = fmod(_phase + delta, 10.0)
	if _values.x > 0 and _values.y > 0: queue_redraw()
	_visual = _visual.lerp(_values, minf(1, delta * 18))
	if _visual.distance_to(_values) > 0.001: queue_redraw()

var _touches: Dictionary = {}
var _mouse_channel: int = -1
var _values := Vector2.ZERO
var mirrored: bool = false
var compact := false:
	set(value):
		compact = value
		if value and _pad_skin == null:
			_pad_skin = Art.skin("button")
			_pad_active_skin = Art.skin("button_hot")
		queue_redraw()
var _pad_skin: StyleBoxTexture
var _pad_active_skin: StyleBoxTexture
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
		var value := _values[channel]
		var both := _values.x > 0 and _values.y > 0
		var accent := Color("4ef2d2") if channel == 0 else Color("ff9e44")
		var body := Color("1b6b6e") if channel == 0 else Color("9e4f20")
		var pressed := value > 0
		if compact:
			draw_style_box(_pad_active_skin if pressed else _pad_skin, rect)
			var caption := "A   Раскрыть" if channel == 0 else "B   Сжать"
			if both: caption = "Отпусти"
			draw_string(font, rect.position + Vector2(12,33), caption, HORIZONTAL_ALIGNMENT_CENTER,
				rect.size.x - 24, 16, Color("e8f1f5"))
			continue
		var inset := Vector2(3,3) if pressed else Vector2.ZERO
		var panel := Rect2(rect.position + inset, rect.size - inset)
		draw_rect(panel, body if pressed else Color("182838"))
		draw_rect(Rect2(panel.position, Vector2(panel.size.x,3)), accent)
		draw_rect(Rect2(panel.position, Vector2(3,panel.size.y)), accent)
		draw_rect(Rect2(panel.position.x,panel.end.y-6,panel.size.x,6),Color("09121c"))
		draw_rect(Rect2(panel.end.x-6,panel.position.y,6,panel.size.y),Color("09121c"))
		for corner in [panel.position+Vector2(9,9),panel.end-Vector2(12,12)]:
			draw_rect(Rect2(corner,Vector2(3,3)),Color("3a5775"))
		if both:
			for x in range(int(panel.position.x+6),int(panel.end.x-9),3):
				var lit := (int((x + floorf(_phase * 12)*3)/12) % 2) == 0
				draw_rect(Rect2(x,panel.position.y,3,6),Color("ffd166") if lit else Color("1a1a1a"))
		# 14 vertical LED cells, threshold markers use the actual independent channel settings.
		var on_th := on_a if channel == 0 else on_b
		var off_th := off_a if channel == 0 else off_b
		var led := Vector2(panel.end.x-30,panel.position.y+15)
		for i in range(14):
			var y := led.y + (13-i)*4
			var color := Color("0e383a") if channel == 0 else Color("4a220b")
			if float(i)/14 < value: color = accent
			draw_rect(Rect2(led.x,y,15,3),color)
			if float(i)/14 < value and float(i+1)/14 >= on_th:
				draw_rect(Rect2(led.x+3,y,6,3),Color("e8f1f5"))
		for entry in [[off_th,Copy.LED_HOLD],[on_th,Copy.LED_ACT]]:
			var y: float = led.y + (1.0-entry[0])*56
			draw_line(Vector2(led.x-6,y),Vector2(led.x,y),Color("ffd166"),2)
			draw_string(font,Vector2(led.x-45,y+(8 if entry[1] == Copy.LED_HOLD else -2)),entry[1],HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("7d9bb8"))
		# Stepped chevron lights, separated from the fixed touch hitbox.
		var arrow := Vector2(panel.position.x+24,panel.get_center().y)
		for i in range(4):
			var y := arrow.y + (i*3 if channel == 0 else -i*3)
			draw_rect(Rect2(arrow.x-i*3,y,3+i*6,3),accent if pressed else Color("5c7c99"))
		var text := Copy.BOTH_SHORT if both else (Copy.PAD_A if channel == 0 else Copy.PAD_B)
		var text_x := panel.position.x + 48
		var available := maxf(40,panel.size.x-130)
		var font_size := 18 if available > 160 else 14
		draw_string(font,Vector2(text_x,panel.position.y+39),text,HORIZONTAL_ALIGNMENT_LEFT,available,font_size,Color("e8f1f5"))
		draw_string(font,Vector2(text_x,panel.position.y+60),Copy.EMULATOR,HORIZONTAL_ALIGNMENT_LEFT,available,12,Color("7d9bb8"))
