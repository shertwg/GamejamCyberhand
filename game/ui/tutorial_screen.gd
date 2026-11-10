extends "res://game/ui/ui_base.gd"


func _ready() -> void:
	super._ready()
	_heading("ОБУЧЕНИЕ / 03", "Четыре коротких сигнала", "Смотри на подпись и значение, не только на цвет.")
	var steps := page_content.get_node_or_null("TutorialSteps") as VBoxContainer
	if steps == null:
		steps = VBoxContainer.new()
		steps.name = "TutorialSteps"
		steps.add_theme_constant_override("separation", DesignTheme.SPACE_100)
		page_content.add_child(steps)
		_add_step(steps, "01", "A выше порога — OPEN", "Открытие по каналу A.")
		_add_step(steps, "02", "B выше порога — CLOSE", "Закрытие по каналу B.")
		_add_step(steps, "03", "Оба выше порога — BOTH", "Встречный сигнал безопасно останавливает действие.")
		_add_step(steps, "04", "Оба ниже порога — REST", "Покой. Потеря сигнала отдельно покажет предупреждение.")
	if page_content.get_node_or_null("TutorialFooterLabel") == null:
		page_content.add_child(_label("Далее можно проверить тестовые значения, успех и промах в режиме «Эмулятор».", "SubtleLabel", "TutorialFooterLabel"))
	var actions := page_content.get_node_or_null("ActionsRow") as HBoxContainer
	if actions == null:
		actions = HBoxContainer.new()
		actions.name = "ActionsRow"
		actions.add_theme_constant_override("separation", DesignTheme.SPACE_100)
		page_content.add_child(actions)
	_button(actions, "Назад", func(): _go("res://game/ui/calibration_screen.tscn"), false, "BackButton")
	_button(actions, "Начать демо", _start_demo, true, "StartDemoButton")


func _add_step(parent: Container, number: String, title: String, detail: String) -> void:
	var row := HBoxContainer.new()
	row.name = "StepRow%s" % number
	row.add_theme_constant_override("separation", DesignTheme.SPACE_150)
	parent.add_child(row)
	var number_label := _label(number, "EyebrowLabel", "StepNumber%s" % number)
	number_label.custom_minimum_size.x = 32
	number_label.size_flags_horizontal = Control.SIZE_FILL
	number_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(number_label)
	var copy := VBoxContainer.new()
	copy.name = "StepCopy%s" % number
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", DesignTheme.SPACE_050)
	row.add_child(copy)
	copy.add_child(_label(title, "SectionTitle", "StepTitle%s" % number))
	copy.add_child(_label(detail, "SubtleLabel", "StepDetail%s" % number))


func _start_demo() -> void:
	runtime.start_session(runtime.level_id)
	_go("res://game/ui/game_screen.tscn")
