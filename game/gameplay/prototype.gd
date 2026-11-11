extends SessionCoordinator
## Legacy integration adapter and backward-compatibility facade for prototype_smoke.gd.
## Delegates pure logic to SessionCoordinator and binds game/ui/game_view.tscn.

const GameViewScene = preload("res://game/ui/game_view.tscn")

var _game_view: GameView

## UI proxies for prototype_smoke.gd
var _root: Control:
	get:
		return _game_view.root if _game_view != null else null

var _pad: Control:
	get:
		return _game_view.emulator_pad if _game_view != null else null

var _overlay: Control:
	get:
		return _game_view.screen_overlay if _game_view != null else null

var _screen_button: Button:
	get:
		if _game_view != null:
			if _game_view.result_screen.visible:
				return _game_view.result_screen.retry_button
			if _game_view.start_screen != null:
				return _game_view.start_screen.start_button
		return null

var _resume_button: Button:
	get:
		return _game_view.hud_overlay.resume_button if _game_view != null else null

var _next_button: Button:
	get:
		return _game_view.result_screen.next_button if _game_view != null else null

var _mission_button: Button:
	get:
		return _game_view.start_screen.cycle_mission_button if _game_view != null else null

var _hand_button: Button:
	get:
		return _game_view.start_screen.hand_button if _game_view != null else null

var _status_label: Label:
	get:
		return _game_view.hud_overlay.status_label if _game_view != null else null

var _time_label: Label:
	get:
		return _game_view.hud_overlay.time_label if _game_view != null else null


func _ready() -> void:
	name = "Prototype"
	init_coordinator()
	_fit()
	get_viewport().size_changed.connect(_fit)
	
	_game_view = GameViewScene.instantiate()
	add_child(_game_view)
	_game_view.bind_coordinator(self)


func _fit() -> void:
	size = get_viewport().get_visible_rect().size
	position = Vector2.ZERO


func select_level(level_id: String) -> void:
	super.select_level(level_id)
	if _game_view != null:
		_game_view._refresh_start_screen()


func _show_start() -> void:
	if _game_view != null:
		_game_view.show_start_screen()


func _begin_round() -> void:
	start_current_mission()


func set_foreground(value: bool) -> void:
	super.set_foreground(value)
	if _game_view != null and _game_view.emulator_pad != null:
		if _game_view.campaign != null:
			_game_view.campaign.foreground = value
		if not value:
			_game_view.emulator_pad.clear()
			_game_view.emulator_pad.visible = false
		else:
			_game_view.emulator_pad.visible = _playing or _expedition_input


func _begin_input_stream() -> void:
	if _game_view != null and _game_view.emulator_pad != null:
		_game_view.emulator_pad.clear()
	super._begin_input_stream()
