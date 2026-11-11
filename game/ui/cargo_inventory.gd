extends PanelContainer
## Cargo slots inspect actual saved quantities. Transfers use the ship's existing ledger.
const Art = preload("res://game/ui/visual_assets.gd")
const CARGO_ICONS = preload("res://assets/last_light/cargo_icons.png")
const ITEMS := [
	["parts","Детали","Ремонт и сборка корабельных систем.","parts"],
	["water","Канистра","Полив биосада или пополнение водяного контура.","water"],
	["energy","Заряд","Питание систем, посев и крафт.","energy"],
	["food","Провизия","Запас для взлёта или пополнение пайка.","food"],
	["fuses","Предохранитель","Защита силового контура реактора.","fuses"],
	["coils","Катушка","Компонент корабельной антенны.","coils"],
	["ore","Руда","Переплавляется в сплав. Добывается в ущелье.","ore"],
	["silica","Кристаллы","Материал для улучшений. Добывается в пещере.","silica"],
	["alloy","Сплав","Материал для экрана и стабилизатора.","alloy"],
]
signal item_chosen(key: String)
signal dismissed
var selected := "parts"
var actions: VBoxContainer
var transfer: HBoxContainer
var _slots := {}
var _counts := {}
var _quantity_labels := {}
var _style_cache := {}
var _name: Label
var _description: Label

func _ready() -> void:
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("141720fa")
	skin.border_color = Color("9d7857")
	skin.set_border_width_all(2)
	skin.set_content_margin_all(12)
	skin.shadow_color = Color("070810bd")
	skin.shadow_size = 8
	add_theme_stylebox_override("panel", skin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 7)
	scroll.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	var heading := _label("ГРУЗОВОЙ ОТСЕК", 19, "f5d5a3")
	heading.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(heading)
	var close := Button.new()
	close.text = "Закрыть"
	close.custom_minimum_size = Vector2(87, 44)
	close.add_theme_stylebox_override("normal", Art.skin("button", true))
	close.add_theme_stylebox_override("hover", Art.skin("button_hot", true))
	close.pressed.connect(func(): dismissed.emit())
	header.add_child(close)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	stack.add_child(grid)
	for item in ITEMS:
		var key: String = item[0]
		var slot := Button.new()
		slot.clip_text = true
		slot.custom_minimum_size.y = 54
		slot.size_flags_horizontal = SIZE_EXPAND_FILL
		slot.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot.add_theme_font_size_override("font_size", 14)
		slot.add_theme_constant_override("icon_max_width", 32)
		slot.texture_filter = TEXTURE_FILTER_NEAREST
		slot.tooltip_text = item[2]
		slot.icon = _icon(item[3])
		slot.pressed.connect(_select.bind(key))
		grid.add_child(slot)
		_slots[key] = slot
		var quantity := _label("", 14, "edd9b7")
		quantity.mouse_filter = MOUSE_FILTER_IGNORE
		quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		quantity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_child(quantity)
		quantity.set_anchors_and_offsets_preset(PRESET_RIGHT_WIDE)
		quantity.offset_left = -55
		quantity.offset_right = -8
		_quantity_labels[key] = quantity
	var detail := PanelContainer.new()
	var well := StyleBoxFlat.new()
	well.bg_color = Color("242833")
	well.border_color = Color("625244")
	well.set_border_width_all(1)
	well.set_content_margin_all(8)
	detail.add_theme_stylebox_override("panel", well)
	stack.add_child(detail)
	var info := VBoxContainer.new()
	detail.add_child(info)
	_name = _label("", 17, "ffe0ac")
	_description = _label("", 14, "c2cdd6")
	info.add_child(_name)
	info.add_child(_description)
	transfer = HBoxContainer.new()
	info.add_child(transfer)
	actions = VBoxContainer.new()
	actions.add_theme_constant_override("separation", 3)
	stack.add_child(actions)
	_select(selected)
	resized.connect(_refresh)
	hide()

func _icon(id: String) -> Texture2D:
	if Art.MATERIALS.has(id):
		var icon := AtlasTexture.new()
		icon.atlas = Art.LOOT
		icon.region = Art.MATERIALS[id]
		return icon
	var icon := AtlasTexture.new()
	icon.atlas = CARGO_ICONS
	icon.region = Rect2(["water","food","fuses","coils"].find(id) * 32, 0, 32, 32)
	return icon

func _label(value: String, pixels: int, tint: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", Color(tint))
	return label

func _select(key: String) -> void:
	selected = key
	_refresh()
	item_chosen.emit(key)

func update_cargo(ship: Dictionary, materials: Dictionary) -> void:
	for item in ITEMS:
		var key: String = item[0]
		_counts[key] = int(materials.get(key, ship.get(key, 0)))
	_refresh()

func _refresh() -> void:
	for item in ITEMS:
		var key: String = item[0]
		var amount := int(_counts.get(key, 0))
		var slot: Button = _slots[key]
		var short_names := {"fuses":"Предохр.", "silica":"Крист.", "food":"Еда"}
		var title: String = short_names.get(key, item[1]) if size.x < 670 else item[1]
		slot.text = title
		_quantity_labels[key].text = "×%d" % amount
		slot.modulate = Color.WHITE if amount > 0 or key == selected else Color("99a1ad")
		for state in ["normal","hover","pressed","focus"]:
			var bright: bool = key == selected or state != "normal"
			slot.add_theme_stylebox_override(state, _slot_style(bright))
		if key == selected:
			_name.text = "%s   /   %d на складе" % [item[1], amount]
			_description.text = item[2]

func _slot_style(active: bool) -> StyleBoxFlat:
	if not _style_cache.has(active):
		var well := StyleBoxFlat.new()
		well.bg_color = Color("3b3028" if active else "212631")
		well.border_color = Color("c69a58" if active else "544b49")
		well.set_border_width_all(1)
		well.border_width_left = 3
		well.set_content_margin_all(7)
		well.content_margin_right = 55
		_style_cache[active] = well
	return _style_cache[active]

func set_large_text(enabled: bool) -> void:
	_name.add_theme_font_size_override("font_size", 20 if enabled else 17)
	_description.add_theme_font_size_override("font_size", 17 if enabled else 14)
	for slot in _slots.values():
		slot.add_theme_font_size_override("font_size", 16 if enabled else 14)
