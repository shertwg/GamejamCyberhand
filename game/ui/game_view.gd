class_name GameView
extends CanvasLayer
## Master UI composition layer connecting UI scenes to SessionCoordinator by contract.

const Copy = preload("res://game/content/copy_catalog.gd")
const StartScreenScript = preload("res://game/ui/screens/start_screen.gd")
const HudOverlayScript = preload("res://game/ui/screens/hud_overlay.gd")
const ResultScreenScript = preload("res://game/ui/screens/result_screen.gd")
const PadScript = preload("res://game/ui/manual_pad.gd")

var coordinator: SessionCoordinator

@onready var root: Control = $Root
@onready var hud_overlay: HudOverlay = $Root/Margin/VBox/HudOverlay
@onready var course_container: Control = $Root/Margin/VBox/CourseContainer
@onready var emulator_pad: Control = $Root/Margin/VBox/EmulatorPad
@onready var screen_overlay: ColorRect = $Root/ScreenOverlay
@onready var start_screen: StartScreen = $Root/ScreenOverlay/StartScreen
@onready var result_screen: ResultScreen = $Root/ScreenOverlay/ResultScreen


func _ready() -> void:
	root.theme = preload("res://game/ui/terminal_style.gd").make_theme()
	start_screen.mission_selected.connect(func(id):
		if coordinator != null:
			coordinator.select_level(id)
			_refresh_start_screen()
	)
	start_screen.start_pressed.connect(_on_start_pressed)
	start_screen.cycle_mission_pressed.connect(_on_cycle_mission_pressed)
	start_screen.hand_toggle_pressed.connect(_on_hand_toggle_pressed)
	hud_overlay.resume_pressed.connect(_on_resume_pressed)
	result_screen.retry_pressed.connect(_on_retry_pressed)
	result_screen.next_pressed.connect(_on_next_pressed)
	result_screen.ship_pressed.connect(show_start_screen)
	emulator_pad.channels_changed.connect(_on_pad_channels_changed)


func bind_coordinator(p_coordinator: SessionCoordinator) -> void:
	coordinator = p_coordinator
	if course_container != null and coordinator._course != null:
		if coordinator._course.get_parent() != course_container:
			if coordinator._course.get_parent() != null:
				coordinator._course.get_parent().remove_child(coordinator._course)
			course_container.add_child(coordinator._course)
		coordinator._course.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	coordinator.command_updated.connect(_on_command_updated)
	coordinator.mission_started.connect(_on_mission_started)
	coordinator.mission_tick.connect(_on_mission_tick)
	coordinator.mission_completed.connect(_on_mission_completed)
	coordinator.input_barrier_changed.connect(_on_input_barrier_changed)
	coordinator.hand_side_changed.connect(_on_hand_side_changed)
	coordinator.unlocked_missions_changed.connect(_on_unlocked_missions_changed)
	
	_apply_initial_state()


func show_start_screen() -> void:
	$Root/Margin.visible = false
	if coordinator != null:
		coordinator._playing = false
	if screen_overlay != null:
		screen_overlay.visible = true
	if start_screen != null:
		start_screen.visible = true
	if result_screen != null:
		result_screen.visible = false
	if emulator_pad != null:
		emulator_pad.visible = false
	if hud_overlay != null:
		hud_overlay.set_resume_visible(false)
		hud_overlay.update_time(0.0)
	_refresh_start_screen()


func _refresh_start_screen() -> void:
	if coordinator != null and start_screen != null:
		var cfg = coordinator._config_for(coordinator._level_id)
		var unlocked_cnt: int = coordinator._unlocked().size()
		var is_left: bool = coordinator.is_hand_left()
		start_screen.set_mission_info(cfg, unlocked_cnt, is_left)
		start_screen.set_mission_cards(LevelConfig.ordered_ids(), coordinator._unlocked(), coordinator._level_id)
		start_screen.set_ship_progress(coordinator._save.get("completed_levels", []), coordinator._unlocked(), coordinator._level_id)
		if hud_overlay != null:
			hud_overlay.update_mission(Copy.HEADER_TITLE, Copy.HEADER_SUBTITLE)


func _apply_initial_state() -> void:
	if coordinator == null:
		return
	var is_left: bool = coordinator.is_hand_left()
	if emulator_pad != null:
		emulator_pad.set_mirrored(is_left)
		if coordinator._profile != null:
			emulator_pad.set_thresholds(
				coordinator._profile.on_a, coordinator._profile.off_a,
				coordinator._profile.on_b, coordinator._profile.off_b
			)
	show_start_screen()


func _on_start_pressed() -> void:
	if coordinator != null:
		coordinator.start_current_mission()


func _on_cycle_mission_pressed() -> void:
	if coordinator != null:
		coordinator.cycle_mission()
		_refresh_start_screen()


func _on_hand_toggle_pressed() -> void:
	if coordinator != null:
		coordinator.toggle_hand_side()


func _on_resume_pressed() -> void:
	if coordinator != null:
		coordinator.request_resume()


func _on_retry_pressed() -> void:
	if coordinator != null:
		coordinator.retry_mission()


func _on_next_pressed() -> void:
	if coordinator != null:
		coordinator.next_mission()
		coordinator.start_current_mission()


func _on_pad_channels_changed(a: float, b: float) -> void:
	if coordinator != null:
		coordinator.set_channel_values(a, b)


func _on_command_updated(command) -> void:
	var color := _state_color(command.state)
	var text := Copy.state_message(command)
	if hud_overlay != null:
		hud_overlay.update_status(text, color)


func _on_mission_started(level_id: String, config) -> void:
	$Root/Margin.visible = true
	if screen_overlay != null:
		screen_overlay.visible = false
	if start_screen != null:
		start_screen.visible = false
	if result_screen != null:
		result_screen.visible = false
	if emulator_pad != null:
		emulator_pad.visible = true
		emulator_pad.clear()
	var sub: String = Copy.TUTORIAL_HINTS[1] if level_id == "tutorial" else (config.title + " · " + config.hazard_subtitle)
	if hud_overlay != null:
		hud_overlay.update_mission(Copy.COOLANT_TITLE if level_id == "repair-1" else Copy.HEADER_TITLE, Copy.COOLANT_HINT if level_id == "repair-1" else sub)
		hud_overlay.update_time(0.0)


func _on_mission_tick(active_seconds: float, in_hold_zone: bool) -> void:
	if hud_overlay != null:
		hud_overlay.update_time(active_seconds)
		hud_overlay.update_hold(in_hold_zone)


func _on_mission_completed(summary, adaptation: Dictionary) -> void:
	$Root/Margin.visible = false
	if screen_overlay != null:
		screen_overlay.visible = true
	if start_screen != null:
		start_screen.visible = false
	if result_screen != null:
		result_screen.visible = true
	if emulator_pad != null:
		emulator_pad.visible = false
		emulator_pad.clear()
	if hud_overlay != null:
		hud_overlay.set_resume_visible(false)
	if result_screen != null:
		result_screen.show_result(summary, adaptation)


func _on_input_barrier_changed(needs_resume: bool, prompt_text: String) -> void:
	if hud_overlay != null:
		hud_overlay.set_resume_visible(needs_resume)
		if coordinator != null and coordinator._current != null:
			hud_overlay.update_status(prompt_text, _state_color(coordinator._current.state))


func _on_hand_side_changed(is_left: bool) -> void:
	if emulator_pad != null:
		emulator_pad.set_mirrored(is_left)
	if start_screen != null and coordinator != null:
		var cfg = coordinator._config_for(coordinator._level_id)
		start_screen.set_mission_info(cfg, coordinator._unlocked().size(), is_left)


func _on_unlocked_missions_changed(_unlocked: Array) -> void:
	_refresh_start_screen()


func _state_color(state: StringName) -> Color:
	match state:
		&"ACTIVE":
			return Color("8af0d4")
		&"REST":
			return Color("c7d9e8")
		&"BOTH", &"WAITING_NEUTRAL", &"WAITING_RESUME":
			return Color("ffd166")
		&"STALE", &"DISCONNECTED", &"INVALID", &"SUSPENDED":
			return Color("ff9b9b")
		_:
			return Color("c7d9e8")
