extends "res://game/ui/ui_base.gd"


func _ready() -> void:
	super._ready()
	_heading("ПАУЗА / МАРШРУТ СОХРАНЁН", "Передышка", "В демонстрации таймер уровня не запущен.")
	var actions := page_content.get_node_or_null("PauseActions") as VBoxContainer
	if actions == null:
		actions = VBoxContainer.new()
		actions.name = "PauseActions"
		actions.add_theme_constant_override("separation", DesignTheme.SPACE_100)
		page_content.add_child(actions)
	_button(actions, "Продолжить маршрут", _resume, true, "ResumeButton")
	_button(actions, "Начать заново", _retry, false, "RetryButton")
	_button(actions, "В меню", _exit, false, "MenuButton")


func _resume() -> void:
	runtime.resume()
	_go("res://game/ui/game_screen.tscn")


func _retry() -> void:
	runtime.retry()
	_go("res://game/ui/game_screen.tscn")


func _exit() -> void:
	runtime.exit()
	_go("res://game/ui/start_screen.tscn")
