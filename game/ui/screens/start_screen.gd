class_name StartScreen
extends Control
## Start & Mission briefing screen for Astra to design.

const Copy = preload("res://game/content/copy_catalog.gd")
const Style = preload("res://game/ui/terminal_style.gd")
const StationPanel = preload("res://game/station/station_panel.gd")
signal mission_selected(id: String)
var station_panel: StationPanel

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
	Style.prepare_screen(self, 1080)
	screen_title.text = "СТАНЦИЯ «МАЯК»"
	screen_title.add_theme_color_override("font_color", Color("fff1d7"))
	screen_subtitle.text = "Аварийный лагерь на чужой планете"
	screen_subtitle.add_theme_color_override("font_color", Color("ffcf93"))
	disclaimer_label.text = "Ремонтный дрон · экранные каналы A и B"
	start_button.hide()
	screen_body.hide()
	cycle_mission_button.hide()
	$Center/Panel.add_theme_stylebox_override("panel", Style.box("1c2035", "a285a9"))
	$Center/Panel/VBox.add_theme_constant_override("separation", 7)
	station_panel = StationPanel.new()
	$Center/Panel/VBox.add_child(station_panel)
	$Center/Panel/VBox.move_child(station_panel, 2)
	station_panel.job_requested.connect(func(id):
		mission_selected.emit(id)
		start_pressed.emit()
	)

	start_button.pressed.connect(func(): start_pressed.emit())
	cycle_mission_button.pressed.connect(func(): cycle_mission_pressed.emit())
	hand_button.pressed.connect(func(): hand_toggle_pressed.emit())
	Style.setup_button_juice(start_button, self)
	Style.setup_button_juice(hand_button, self)


func set_mission_info(_level_cfg, _unlocked_count: int, is_left: bool) -> void:
	hand_button.text = Copy.HAND % (Copy.HAND_LEFT if is_left else Copy.HAND_RIGHT)
