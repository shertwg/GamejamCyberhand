extends "res://game/ui/ui_base.gd"

const LEVEL_IDS := ["repair-1", "repair-2", "repair-3"]
const LEVEL_NAMES := ["1 · Крупные детали", "2 · Перенос детали", "3 · Точная установка"]

var left_button: Button
var right_button: Button
var levels_option: OptionButton


func _ready() -> void:
	super._ready()
	_heading("НАСТРОЙКИ / 01", "Подготовь управление", "Рука и уровень пока сохраняются локально в UI.")
	var hand_box := _section(page_content, "ВЕДУЩАЯ РУКА", "Эмулятор разместит контролы с этой стороны.", "HandSection")
	var hand_row := hand_box.get_node_or_null("HandRow") as HBoxContainer
	if hand_row == null:
		hand_row = HBoxContainer.new()
		hand_row.name = "HandRow"
		hand_row.add_theme_constant_override("separation", DesignTheme.SPACE_100)
		hand_box.add_child(hand_row)
	left_button = _button(hand_row, "ЛЕВАЯ", func(): _select_hand("left"), false, "LeftHandButton")
	right_button = _button(hand_row, "ПРАВАЯ", func(): _select_hand("right"), false, "RightHandButton")
	left_button.toggle_mode = true
	right_button.toggle_mode = true
	_refresh_hand_buttons()

	var level_box := _section(page_content, "УРОВЕНЬ", "Демонстрационный список, не игровые данные из контракта.", "LevelSection")
	levels_option = level_box.get_node_or_null("LevelOptionButton") as OptionButton
	if levels_option == null:
		levels_option = OptionButton.new()
		levels_option.name = "LevelOptionButton"
		levels_option.custom_minimum_size.y = maxf(48.0, dp_to_vp(48.0))
		levels_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		level_box.add_child(levels_option)
	if levels_option.item_count == 0:
		for level_name in LEVEL_NAMES:
			levels_option.add_item(level_name)
	var selected_index := LEVEL_IDS.find(runtime.level_id)
	levels_option.select(maxi(selected_index, 0))
	levels_option.item_selected.connect(func(index: int): runtime.level_id = LEVEL_IDS[index])

	var actions := page_content.get_node_or_null("ActionsRow") as HBoxContainer
	if actions == null:
		actions = HBoxContainer.new()
		actions.name = "ActionsRow"
		actions.add_theme_constant_override("separation", DesignTheme.SPACE_100)
		page_content.add_child(actions)
	_button(actions, "Назад", func(): _go("res://game/ui/start_screen.tscn"), false, "BackButton")
	_button(actions, "Продолжить", func(): _go("res://game/ui/calibration_screen.tscn"), true, "ContinueButton")


func _on_viewport_resized(_viewport_size: Vector2) -> void:
	if levels_option != null:
		levels_option.custom_minimum_size.y = maxf(48.0, dp_to_vp(48.0))


func _select_hand(selected: String) -> void:
	runtime.hand = selected
	_refresh_hand_buttons()


func _refresh_hand_buttons() -> void:
	if left_button == null or right_button == null:
		return
	left_button.set_pressed_no_signal(runtime.hand == "left")
	right_button.set_pressed_no_signal(runtime.hand == "right")
	left_button.theme_type_variation = DesignTheme.TYPE_SELECTED_CHOICE if runtime.hand == "left" else DesignTheme.TYPE_CHOICE
	right_button.theme_type_variation = DesignTheme.TYPE_SELECTED_CHOICE if runtime.hand == "right" else DesignTheme.TYPE_CHOICE
