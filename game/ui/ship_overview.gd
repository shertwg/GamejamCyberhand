extends Control
## Interactive cutaway: presentation only; progression comes from coordinator.
signal bridge_selected
var _bridge: Button
signal module_selected(id: String)
const Copy = preload("res://game/content/copy_catalog.gd")
const IDS = ["tutorial", "repair-1", "repair-2", "repair-3"]
var completed: Array = []
var unlocked: Array = []
var selected := "repair-1"
var _buttons: Array[Button] = []
var _art: Control
var _texture: TextureRect
var _viewport: SubViewport
var _art_scale := 4
var _art_offset := Vector2.ZERO

func _ready() -> void:
	custom_minimum_size.y = 272
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(250,68)
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	_art = preload("res://game/ui/ship_pixel_art.gd").new()
	_viewport.add_child(_art)
	_texture = TextureRect.new()
	_texture.texture = _viewport.get_texture()
	_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texture)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(4):
		var b := Button.new()
		b.flat = true
		b.clip_text = true
		for state in ["normal", "disabled", "hover", "pressed", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.1,0.3,0.35,0.2) if state == "hover" else Color.TRANSPARENT
			style.content_margin_left = 2
			style.content_margin_right = 2
			if state == "focus":
				style.border_color = Color("8af0d4")
				style.set_border_width_all(2)
			b.add_theme_stylebox_override(state, style)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func(): module_selected.emit(IDS[i]))
		b.add_theme_font_size_override("font_size", 13)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(b)
		_buttons.append(b)
	_bridge = Button.new()
	_bridge.text = Copy.BRIDGE
	_bridge.tooltip_text = Copy.BRIDGE_INFO
	_bridge.flat = true
	_bridge.clip_text = true
	_bridge.add_theme_font_size_override("font_size",11)
	_bridge.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	_bridge.add_theme_stylebox_override("hover",StyleBoxEmpty.new())
	_bridge.pressed.connect(func(): bridge_selected.emit())
	add_child(_bridge)
	resized.connect(_layout)
	_layout()

func set_progress(done: Array, available: Array, current: String) -> void:
	completed = done.duplicate()
	unlocked = available.duplicate()
	selected = current
	_layout()

func _layout() -> void:
	_art_scale = maxi(1, mini(4, int(size.x / 250)))
	var art_size := Vector2(250,68) * _art_scale
	custom_minimum_size.y = art_size.y + (60 if _art_scale < 3 else 8)
	_art_offset = Vector2(floorf((size.x - art_size.x) / 2), 0)
	if _texture != null:
		_texture.position = _art_offset
		_texture.size = art_size
	if _art != null:
		_art.completed = completed
		_art.selected = selected
		_art.queue_redraw()
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var scale_x := float(_art_scale) / 4.0
	if _bridge != null:
		_bridge.position = _art_offset + Vector2(820,174)*scale_x
		_bridge.size = Vector2(110*scale_x,44)
		if _art_scale < 3:
			_bridge.position = Vector2(size.x-80,0)
			_bridge.size = Vector2(80,44)
	for i in range(_buttons.size()):
		var b := _buttons[i]
		b.position = _art_offset + Vector2((145 + i * 180) * scale_x, 174 * scale_x)
		b.size = Vector2(170 * scale_x, 44)
		if _art_scale < 3:
			var width := (size.x-18)/4
			b.position = Vector2(i*(width+6),art_size.y+6)
			b.size = Vector2(width,44)
		b.disabled = not IDS[i] in unlocked
		b.add_theme_font_size_override("font_size", 11 if _art_scale < 3 else 13)
		b.text = Copy.SHIP_MODULES[i] + "\n" + (Copy.SHIP_DONE if IDS[i] in completed else (Copy.SHIP_REPAIR if IDS[i] in unlocked else Copy.SHIP_LOCKED))
		b.tooltip_text = Copy.MISSION_SHORT[IDS[i]]
		b.add_theme_color_override("font_color", Color("8af0d4") if IDS[i] in completed else Color("f0f6fc"))
	queue_redraw()



var _spark_time := 0.0
func _process(delta: float) -> void:
	if not is_visible_in_tree() or _art == null: return
	_spark_time += delta
	if _spark_time >= 0.2:
		_spark_time = 0
		_art.spark_phase = (_art.spark_phase + 1) % 10
		_art.queue_redraw()
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
