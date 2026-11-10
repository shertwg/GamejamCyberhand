extends Node
## Keyboard/touch emulator only. Never moves gameplay objects or bypasses InputPipeline.
signal channels_changed(a: float, b: float)

var _keys: Dictionary = {}
var _touch := Vector2.ZERO
var channels := Vector2.ZERO
var enabled: bool = true

func _input(event: InputEvent) -> void:
	if not enabled or not event is InputEventKey or event.echo:
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	var key: int = event.physical_keycode
	if key not in [KEY_W, KEY_A, KEY_UP, KEY_B, KEY_S, KEY_D, KEY_DOWN]:
		return
	if event.pressed:
		_keys[key] = true
	else:
		_keys.erase(key)
	_publish()

func set_touch_channels(a: float, b: float) -> void:
	_touch = Vector2(clampf(a, 0.0, 1.0), clampf(b, 0.0, 1.0))
	_publish()

func clear() -> void:
	_keys.clear()
	_touch = Vector2.ZERO
	_publish()

func _publish() -> void:
	channels = _touch
	for key in _keys:
		if key in [KEY_W, KEY_A, KEY_UP]: channels.x = 1.0
		if key in [KEY_B, KEY_S, KEY_D, KEY_DOWN]: channels.y = 1.0
	channels_changed.emit(channels.x, channels.y)
