class_name HudOverlay
extends Control
## HUD overlay for in-game telemetry and status messages.

const Copy = preload("res://game/content/copy_catalog.gd")
const Style = preload("res://game/ui/terminal_style.gd")
var hold_label: Label
signal resume_pressed
signal station_pressed

@onready var header_title: Label = $Margin/VBox/HeaderTitle
@onready var header_subtitle: Label = $Margin/VBox/HeaderSubtitle
@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var time_label: Label = $Margin/VBox/TimeRow/TimeLabel
@onready var resume_button: Button = $Margin/VBox/TimeRow/ResumeButton


func _ready() -> void:
	resume_button.text = Copy.RESUME
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "monospace"])
	time_label.add_theme_font_override("font",mono)
	Style.danger_hazard(resume_button)
	Style.setup_button_juice(resume_button, self)
	header_title.add_theme_color_override("font_color", Color("8af0d4"))
	header_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hold_label = Label.new()
	hold_label.add_theme_font_size_override("font_size", 14)
	$Margin/VBox.add_child(hold_label)
	update_hold(false)

	var back := Button.new()
	back.text = "На станцию"
	back.pressed.connect(func(): station_pressed.emit())
	$Margin/VBox/TimeRow.add_child(back)
	Style.setup_button_juice(back, self)
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
		var cs := maxi(0,int(floor(active_seconds*100)))
		time_label.text = Copy.TIMER_LABEL + "  %02d:%02d.%02d" % [cs/6000,(cs/100)%60,cs%100]


var _resume_tween: Tween

func set_resume_visible(is_visible: bool) -> void:
	if resume_button != null:
		if resume_button.visible == is_visible: return
		resume_button.visible = is_visible
		if _resume_tween != null and _resume_tween.is_valid():
			_resume_tween.kill()
		if is_visible:
			_resume_tween = create_tween().set_loops()
			_resume_tween.tween_property(resume_button, "modulate", Color(1.0, 0.85, 0.65), 0.5).set_trans(Tween.TRANS_SINE)
			_resume_tween.tween_property(resume_button, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE)
		else:
			resume_button.modulate = Color.WHITE

func update_hold(active: bool) -> void:
	if hold_label != null:
		hold_label.text = Copy.HOLD_ACTIVE if active else Copy.HOLD_IDLE
		hold_label.modulate = Color("8af0d4") if active else Color("8b9bb4")


func _process(_delta: float) -> void:
	# Wrapped telemetry must reserve its actual height in the outer VBox.
	custom_minimum_size.y = $Margin.get_combined_minimum_size().y
