extends "res://game/ui/ui_base.gd"


func _ready() -> void:
	super._ready()
	_heading("ПОДКЛЮЧЕНИЕ / 02", "Проверь сигналы", "Перед реальным вводом потребуется калибровка в core.")
	var calibration := _section(page_content, "КАЛИБРОВКА", "В проекте она пока не подключена. Порог 0.35 используется только локальным UI-адаптером.", "CalibrationSection")
	if calibration.get_node_or_null("CalibrationNoteLabel") == null:
		calibration.add_child(_label("Это техническая настройка демонстрации, не медицинская норма.", "SubtleLabel", "CalibrationNoteLabel"))
	var emulator := _section(page_content, "ЭМУЛЯТОР", "Кнопки касания и ползунки отправляют тестовые значения 0..1 в InputFrame.", "EmulatorSection")
	if emulator.get_node_or_null("EmulatorMappingLabel") == null:
		emulator.add_child(_label("A → OPEN · B → CLOSE · оба канала → BOTH · ниже порога → REST.", "BodyText", "EmulatorMappingLabel"))
	if emulator.get_node_or_null("EmulatorDisclaimerLabel") == null:
		emulator.add_child(_label("Тестовый ввод не управляет захватом и не измеряет перенос навыка на протез.", "SubtleLabel", "EmulatorDisclaimerLabel"))
	var actions := page_content.get_node_or_null("ActionsRow") as HBoxContainer
	if actions == null:
		actions = HBoxContainer.new()
		actions.name = "ActionsRow"
		actions.add_theme_constant_override("separation", DesignTheme.SPACE_100)
		page_content.add_child(actions)
	_button(actions, "Назад", func(): _go("res://game/ui/settings_screen.tscn"), false, "BackButton")
	_button(actions, "К обучению", func(): _go("res://game/ui/tutorial_screen.tscn"), true, "ContinueButton")
