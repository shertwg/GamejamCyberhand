class_name HudOverlay
extends Control
## HUD overlay for in-game telemetry and status messages.

const Copy = preload("res://game/content/copy_catalog.gd")
var hold_label: Label
signal resume_pressed

@onready var header_title: Label = $Margin/VBox/HeaderTitle
@onready var header_subtitle: Label = $Margin/VBox/HeaderSubtitle
@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var time_label: Label = $Margin/VBox/TimeRow/TimeLabel
@onready var resume_button: Button = $Margin/VBox/TimeRow/ResumeButton


func _ready() -> void:
	resume_button.text = Copy.RESUME
	preload("res://game/ui/terminal_style.gd").primary(resume_button)
	header_title.add_theme_color_override("font_color", Color("8af0d4"))
	header_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hold_label = Label.new()
	hold_label.add_theme_font_size_override("font_size", 14)
	$Margin/VBox.add_child(hold_label)
	update_hold(false)

	resume_button.pressed.connect(func(): resume_pressed.emit())


func update_mission(title: String, subtitle: String) -> void:
	if header_title != null:
		header_title.text = title
	if header_subtitle != null:
		header_subtitle.text = subtitle


func update_status(text: String, color: Color) -> void:
	if status_label != null:
		status_label.text = text
		status_label.add_theme_color_override("font_color", color)


func update_time(active_seconds: float) -> void:
	if time_label != null:
		time_label.text = Copy.ACTIVE_TIME % active_seconds


func set_resume_visible(is_visible: bool) -> void:
	if resume_button != null:
		resume_button.visible = is_visible

func update_hold(active: bool) -> void:
	if hold_label != null:
		hold_label.text = Copy.HOLD_ACTIVE if active else Copy.HOLD_IDLE
		hold_label.modulate = Color("8af0d4") if active else Color("8b9bb4")


func _process(_delta: float) -> void:
	# Wrapped telemetry must reserve its actual height in the outer VBox.
	custom_minimum_size.y = $Margin.get_combined_minimum_size().y
