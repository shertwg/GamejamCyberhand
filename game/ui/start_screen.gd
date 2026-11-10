extends "res://game/ui/ui_base.gd"


func _ready() -> void:
	super._ready()
	_heading("ОРБИТАЛЬНАЯ МАСТЕРСКАЯ / СТАРТ", "Вернём станции свет", "Проведи детали через три этапа и восстанови питание станции.")
	var intro := _section(page_content, "СИГНАЛЫ · УЧЕБНЫЙ ЗАПУСК · ВОССТАНОВЛЕНИЕ", "Маршрут работает в демонстрационном режиме.", "IntroSection")
	if intro.get_node_or_null("EmulatorNoteLabel") == null:
		intro.add_child(_label("Данные эмулятора служат только для показа интерфейса и не управляют захватом.", "SubtleLabel", "EmulatorNoteLabel"))
	_button(page_content, "Начать маршрут", func(): _go("res://game/ui/settings_screen.tscn"), true, "StartButton")
	_button(page_content, "Что такое Эмулятор?", func(): _go("res://game/ui/calibration_screen.tscn"), false, "EmulatorInfoButton")
