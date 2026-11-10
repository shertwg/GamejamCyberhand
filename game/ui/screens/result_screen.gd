class_name ResultScreen
extends Control
## Mission outcome and rewards screen.

const Copy = preload("res://game/content/copy_catalog.gd")
const Style = preload("res://game/ui/terminal_style.gd")
var _metrics: HBoxContainer
var _decode: Tween
var _show_log: Button
var _ship_button: Button
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
	Style.pulse(next_button,self)
	retry_button.text = Copy.RETRY
	next_button.text = "На станцию →"
	disclaimer_label.text = Copy.RESULT_NOTE
	_ship_button = Button.new()
	var ship_button := _ship_button
	ship_button.text = "На станцию →"
	ship_button.custom_minimum_size.y = 44
	$Center/Panel/VBox.add_child(ship_button)
	$Center/Panel/VBox.move_child(ship_button, $Center/Panel/VBox.get_child_count() - 2)
	ship_button.pressed.connect(func(): ship_pressed.emit())
	Style.setup_button_juice(ship_button, self)
	_show_log = Button.new()
	_show_log.text = Copy.SHOW_LOG
	_show_log.pressed.connect(_finish_decode)
	$Center/Panel/VBox.add_child(_show_log)
	$Center/Panel/VBox.move_child(_show_log,2)
	Style.setup_button_juice(_show_log,self)
	visibility_changed.connect(func():
		if not visible: _finish_decode()
	)
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
	var captions := [Copy.METRIC_TIME, Copy.METRIC_BOTH, Copy.METRIC_HOLD]
	var values := ["%02d:%02d.%02d" % [int(seconds)/60,int(seconds)%60,int(seconds*100)%100], Copy.NO_DATA if both == null else "%d%%" % roundi(both * 100), Copy.NO_DATA if hold == null else "%d%%" % roundi(hold * 100)]
	result_title.add_theme_color_override("font_color", Color("4ef2d2"))
	for i in range(3):
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box_style := Style.box("0e1d2b", "224263")
		box_style.set_content_margin(SIDE_LEFT, 8)
		box_style.set_content_margin(SIDE_RIGHT, 8)
		box_style.set_content_margin(SIDE_TOP, 8)
		box_style.set_content_margin(SIDE_BOTTOM, 8)
		panel.add_theme_stylebox_override("panel", box_style)
		var column := VBoxContainer.new()
		var caption := Label.new()
		caption.text = captions[i]
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size",14)
		caption.add_theme_color_override("font_color",Color("7d9bb8"))
		var value_label := Label.new()
		value_label.text = values[i]
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.add_theme_font_size_override("font_size",24)
		value_label.add_theme_color_override("font_color",Color("4ef2d2"))
		value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(caption)
		column.add_child(value_label)
		panel.add_child(column)
		_metrics.add_child(panel)
	var upgrade: String = level_cfg.upgrade_unlocked if level_cfg != null else ""
	var log_text: String = level_cfg.expedition_log if level_cfg != null else ""
	result_body.text = upgrade + "\n\n" + explanation + "\n\n" + Copy.LOG_TITLE + "\n" + log_text
	if not adaptation.has("station_reward") and level_cfg != null and level_cfg.level_id == "repair-3":
		result_title.text = Copy.FINALE_TITLE
		result_body.text = Copy.FINALE_BODY + "\n\n" + result_body.text
	if adaptation.has("station_reward"):
		result_title.text = "ЗАДАНИЕ ВЫПОЛНЕНО"
		result_body.text = "%s\n\nДальше на станции · %s" % [adaptation.station_reward, adaptation.station_objective]
	_finish_decode()
	result_body.visible_ratio = 0.0
	_show_log.visible = true
	_decode = create_tween()
	_decode.tween_property(result_body,"visible_ratio",1.0,0.8)
	_decode.tween_callback(func(): _show_log.visible = false)
	next_button.visible = next_id != "" and next_id in unlocked
	_ship_button.visible = not next_button.visible


func _finish_decode() -> void:
	if _decode != null and _decode.is_valid(): _decode.kill()
	if result_body != null: result_body.visible_ratio = 1.0
	if _show_log != null: _show_log.visible = false
