class_name StartScreen
extends Control
## Start & Mission briefing screen for Astra to design.

const Copy = preload("res://game/content/copy_catalog.gd")
const Style = preload("res://game/ui/terminal_style.gd")
signal mission_selected(id: String)
var _ship: Control
var _cards: GridContainer

signal start_pressed
signal cycle_mission_pressed
signal hand_toggle_pressed

@onready var screen_title: Label = $Center/Panel/VBox/ScreenTitle
@onready var screen_subtitle: Label = $Center/Panel/VBox/ScreenSubtitle
@onready var screen_body: Label = $Center/Panel/VBox/ScreenBody
@onready var start_button: Button = $Center/Panel/VBox/StartButton
@onready var cycle_mission_button: Button = $Center/Panel/VBox/CycleMissionButton
@onready var hand_button: Button = $Center/Panel/VBox/HandButton
@onready var disclaimer_label: Label = $Center/Panel/VBox/DisclaimerLabel


func _ready() -> void:
	Style.prepare_screen(self, 1040)
	Style.primary(start_button)
	start_button.text = Copy.START
	disclaimer_label.text = Copy.EMULATOR_DISCLAIMER
	screen_subtitle.add_theme_color_override("font_color", Color("8af0d4"))
	_cards = GridContainer.new()
	_cards.columns = 2
	_cards.visible = false
	_ship = preload("res://game/ui/ship_overview.gd").new()
	$Center/Panel/VBox.add_child(_ship)
	$Center/Panel/VBox.move_child(_ship, 2)
	_ship.module_selected.connect(func(id): mission_selected.emit(id))
	cycle_mission_button.visible = false
	$Center/Panel/VBox.add_theme_constant_override("separation", 8)
	_cards.add_theme_constant_override("separation", 8)
	$Center/Panel/VBox.add_child(_cards)
	$Center/Panel/VBox.move_child(_cards, 2)

	start_button.pressed.connect(func(): start_pressed.emit())
	cycle_mission_button.pressed.connect(func(): cycle_mission_pressed.emit())
	hand_button.pressed.connect(func(): hand_toggle_pressed.emit())


func set_mission_info(level_cfg, unlocked_count: int, is_left: bool) -> void:
	if screen_title != null and level_cfg != null:
		screen_title.text = Copy.SHIP_TITLE
	if screen_subtitle != null and level_cfg != null:
		screen_subtitle.text = Copy.SHIP_SUBTITLE
	if screen_body != null and level_cfg != null:
		screen_body.text = level_cfg.title + "\n" + level_cfg.briefing
		start_button.tooltip_text = Copy.BRIEFING_NOTE
	if cycle_mission_button != null:
		cycle_mission_button.text = Copy.CYCLE % unlocked_count
	if hand_button != null:
		hand_button.text = Copy.HAND % (Copy.HAND_LEFT if is_left else Copy.HAND_RIGHT)


func set_mission_cards(ids: Array, unlocked: Array, selected: String) -> void:
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for id in ids:
		var button := Button.new()
		var cfg := LevelConfig.for_id(id)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 58
		button.clip_text = true
		button.text = "%02d · %s" % [ids.find(id) + 1, Copy.SELECTED if id == selected else (Copy.AVAILABLE if id in unlocked else Copy.LOCKED)]
		button.text = Copy.MISSION_SHORT.get(id, cfg.title) + "\n" + button.text
		button.add_theme_font_size_override("font_size", 14)
		button.tooltip_text = cfg.title
		button.disabled = not id in unlocked
		button.pressed.connect(func(): mission_selected.emit(id))
		if id == selected: Style.primary(button)
		_cards.add_child(button)

func set_ship_progress(done: Array, available: Array, current: String) -> void:
	_ship.set_progress(done, available, current)
