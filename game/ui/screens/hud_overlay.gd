class_name HudOverlay
extends Control
## HUD overlay for in-game telemetry and status messages.

signal resume_pressed

@onready var header_title: Label = $Margin/VBox/HeaderTitle
@onready var header_subtitle: Label = $Margin/VBox/HeaderSubtitle
@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var time_label: Label = $Margin/VBox/TimeRow/TimeLabel
@onready var resume_button: Button = $Margin/VBox/TimeRow/ResumeButton


func _ready() -> void:
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
		time_label.text = "Активное время: %.1f с" % active_seconds


func set_resume_visible(is_visible: bool) -> void:
	if resume_button != null:
		resume_button.visible = is_visible
