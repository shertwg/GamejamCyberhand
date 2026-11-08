class_name StartScreen
extends Control
## Start & Mission briefing screen for Astra to design.

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
	start_button.pressed.connect(func(): start_pressed.emit())
	cycle_mission_button.pressed.connect(func(): cycle_mission_pressed.emit())
	hand_button.pressed.connect(func(): hand_toggle_pressed.emit())


func set_mission_info(level_cfg, unlocked_count: int, is_left: bool) -> void:
	if screen_title != null and level_cfg != null:
		screen_title.text = level_cfg.title
	if screen_subtitle != null and level_cfg != null:
		screen_subtitle.text = level_cfg.hazard_subtitle
	if screen_body != null and level_cfg != null:
		screen_body.text = (
			level_cfg.hazard_subtitle + "\n\n"
			+ level_cfg.briefing + "\n\n"
			+ "Пока обе кнопки отпущены, движение и таймер стоят. Это не штраф.\n"
			+ "После старта нажмите «Продолжить», когда ввод будет готов."
		)
	if cycle_mission_button != null:
		cycle_mission_button.text = "Сменить миссию (открыто: %d)" % unlocked_count
	if hand_button != null:
		hand_button.text = "Рука: %s (зеркально)" % ("левая" if is_left else "правая")
