class_name ResultScreen
extends Control
## Mission outcome and rewards screen.

signal retry_pressed
signal next_pressed

@onready var result_title: Label = $Center/Panel/VBox/ResultTitle
@onready var result_body: Label = $Center/Panel/VBox/ResultBody
@onready var retry_button: Button = $Center/Panel/VBox/RetryButton
@onready var next_button: Button = $Center/Panel/VBox/NextButton
@onready var disclaimer_label: Label = $Center/Panel/VBox/DisclaimerLabel


func _ready() -> void:
	retry_button.pressed.connect(func(): retry_pressed.emit())
	next_button.pressed.connect(func(): next_pressed.emit())


func show_result(summary, adaptation: Dictionary) -> void:
	var level_cfg = adaptation.get("level_cfg", null)
	var explanation: String = adaptation.get("explanation", "")
	var next_id: String = adaptation.get("next_id", "")
	var unlocked: Array = adaptation.get("unlocked", [])
	
	if result_title != null:
		result_title.text = "РЕМОНТ ЗАВЕРШЁН"
		
	var both_line := ""
	if summary != null:
		var both_ratio = summary.unwanted_both_ratio()
		if both_ratio != null:
			both_line = "Встречный сигнал в оценочном окне: %d%%.\n" % int(round(both_ratio * 100.0))
			
	var hold_line := ""
	if summary != null:
		var hold_ratio = summary.hold_accuracy_ratio()
		if hold_ratio != null:
			hold_line = "Удержание в зоне стабилизации: %d%%.\n" % int(round(hold_ratio * 100.0))
			
	var upgrade_text: String = level_cfg.upgrade_unlocked if level_cfg != null else ""
	var log_text: String = level_cfg.expedition_log if level_cfg != null else ""
	var active_sec := float(summary.active_ms) / 1000.0 if summary != null else 0.0
	
	if result_body != null:
		result_body.text = (
			upgrade_text + "\n\n"
			+ "Активное время: %.1f с.\n" % active_sec
			+ both_line + hold_line + "\n"
			+ explanation + "\n\n"
			+ log_text + "\n\n"
			+ "Это показатели игры на эмуляторе, не медицинская оценка."
		)
		
	if next_button != null:
		next_button.visible = next_id != "" and next_id in unlocked
