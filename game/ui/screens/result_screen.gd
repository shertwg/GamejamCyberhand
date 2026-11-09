class_name ResultScreen
extends Control
## Mission outcome and rewards screen.

const Copy = preload("res://game/content/copy_catalog.gd")
const Style = preload("res://game/ui/terminal_style.gd")
var _metrics: HBoxContainer
signal ship_pressed
signal retry_pressed
signal next_pressed

@onready var result_title: Label = $Center/Panel/VBox/ResultTitle
@onready var result_body: Label = $Center/Panel/VBox/ResultBody
@onready var retry_button: Button = $Center/Panel/VBox/RetryButton
@onready var next_button: Button = $Center/Panel/VBox/NextButton
@onready var disclaimer_label: Label = $Center/Panel/VBox/DisclaimerLabel


func _ready() -> void:
	Style.prepare_screen(self)
	Style.primary(next_button)
	retry_button.text = Copy.RETRY
	next_button.text = Copy.NEXT
	disclaimer_label.text = Copy.RESULT_NOTE
	var ship_button := Button.new()
	ship_button.text = Copy.SHIP_RETURN
	ship_button.custom_minimum_size.y = 44
	$Center/Panel/VBox.add_child(ship_button)
	$Center/Panel/VBox.move_child(ship_button, $Center/Panel/VBox.get_child_count() - 2)
	ship_button.pressed.connect(func(): ship_pressed.emit())
	result_title.add_theme_color_override("font_color", Color("8af0d4"))
	_metrics = HBoxContainer.new()
	_metrics.add_theme_constant_override("separation", 12)
	$Center/Panel/VBox.add_child(_metrics)
	$Center/Panel/VBox.move_child(_metrics, 1)

	retry_button.pressed.connect(func(): retry_pressed.emit())
	next_button.pressed.connect(func(): next_pressed.emit())


func show_result(summary, adaptation: Dictionary) -> void:
	var level_cfg = adaptation.get("level_cfg", null)
	var explanation: String = adaptation.get("explanation", "")
	var next_id: String = adaptation.get("next_id", "")
	var unlocked: Array = adaptation.get("unlocked", [])
	
	result_title.text = Copy.SUCCESS
	for child in _metrics.get_children():
		_metrics.remove_child(child)
		child.queue_free()
	var seconds := float(summary.active_ms) / 1000.0 if summary != null else 0.0
	var both = summary.unwanted_both_ratio() if summary != null else null
	var hold = summary.hold_accuracy_ratio() if summary != null else null
	var captions := [Copy.ACTIVE_TIME % seconds, Copy.METRIC_BOTH, Copy.METRIC_HOLD]
	var values := ["", Copy.NO_DATA if both == null else "%d%%" % roundi(both * 100), Copy.NO_DATA if hold == null else "%d%%" % roundi(hold * 100)]
	for i in range(3):
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label := Label.new()
		label.text = captions[i] + "\n" + values[i]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(label)
		_metrics.add_child(panel)
	var upgrade: String = level_cfg.upgrade_unlocked if level_cfg != null else ""
	var log_text: String = level_cfg.expedition_log if level_cfg != null else ""
	result_body.text = upgrade + "\n\n" + explanation + "\n\n" + Copy.LOG_TITLE + "\n" + log_text
	next_button.visible = next_id != "" and next_id in unlocked
