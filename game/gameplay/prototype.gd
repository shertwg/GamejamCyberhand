extends Control
## First integrated slice: start screen -> one short route -> result/retry.
## Gameplay consumes only InputPipeline snapshots. The manual pad is an input
## adapter; it never moves the capture directly.

const Course = preload("res://game/gameplay/course.gd")
const Pad = preload("res://game/ui/manual_pad.gd")
const Config = preload("res://game/core/input_config.gd")
const Pipeline = preload("res://game/core/input_pipeline.gd")
const Source = preload("res://game/core/manual_input_source.gd")
const Command = preload("res://game/core/control_command.gd")
const Level = preload("res://game/core/level_config.gd")
const Tracker = preload("res://game/core/session_tracker.gd")
const Store = preload("res://game/core/local_store.gd")
const Copy = preload("res://game/content/copy_catalog.gd")

## Tests set this to an isolated file so user progress is never touched.
static var store_path_override: String = ""

var _store
var _save: Dictionary = {}
var _tracker
var _level_cfg
var _level_id: String = "tutorial"
var _session_counter: int = 0
var _attempt_counter: int = 0
var _clean_streak: int = 0
var _struggle_streak: int = 0
var _last_result_text: String = ""
var _subtitle: Label
var _next_button: Button
var _hand_button: Button
var _mission_button: Button

var _profile
var _pipeline
var _source
var _origin_ms: int = 0
var _last_sample_ms: int = -1
var _channel_a: float = 0.0
var _channel_b: float = 0.0
var _current
var _playing: bool = false
var _foreground: bool = true
var _application_paused: bool = false
var _application_focused: bool = true
var _skip_gameplay_frame: bool = true
var _last_status_key: String = ""

var _root: Control
var _course
var _pad
var _overlay: ColorRect
var _screen_title: Label
var _screen_body: Label
var _screen_button: Button
var _status_label: Label
var _time_label: Label
var _resume_button: Button


func _ready() -> void:
	name = "Prototype"
	_store = Store.new(store_path_override if store_path_override != "" else Store.DEFAULT_PATH)
	_save = _store.load_profile()
	_tracker = Tracker.new()
	_level_id = _first_open_level()
	_build_ui()
	_fit()
	get_viewport().size_changed.connect(_fit)
	_start_input()
	_apply_hand_side()
	_show_start()


func _process(delta: float) -> void:
	update_host(_now_ms(), delta, true)


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_application_paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_application_paused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_application_focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_application_focused = true
	else:
		return
	# Focus cannot cancel an outstanding system pause, or vice versa.
	set_foreground(not _application_paused and _application_focused)


## Host update used by _process and by deterministic smoke tests. When
## sample_heartbeat is false, only the watchdog and gameplay clock run.
func update_host(now_ms: int, delta: float, sample_heartbeat: bool = true) -> void:
	if _pipeline == null:
		return
	# Watchdog: runs on every host frame, including the start/result screens and
	# desktop focus loss. A fully suspended app receives no frames, so the gap is
	# detected on the first frame after return instead of requiring background ticks.
	_pipeline.tick(now_ms)
	if _foreground and sample_heartbeat and _should_sample(now_ms):
		_emit_frame(now_ms)
	var skip_gameplay := _skip_gameplay_frame
	_skip_gameplay_frame = false
	if _playing and _foreground and _current != null and not skip_gameplay:
		_tracker.record_step(int(round(delta * 1000.0)), _current,
			_level_cfg.count_both_as_unwanted, _course.is_in_hold_zone(), _level_cfg.hold_target_ms)
		_course.advance(delta, _current)
		_time_label.text = "Активное время: %.1f с" % _course.active_seconds


## External suspension is not a resume. The player must return to neutral and
## explicitly press "Продолжить" after the host reports WAITING_RESUME.
func set_foreground(value: bool) -> void:
	if value == _foreground:
		return
	_foreground = value
	if not value:
		_channel_a = 0.0
		_channel_b = 0.0
		if _pad != null:
			_pad.clear()
		if _pipeline != null:
			_pipeline.suspend()
		if _pad != null:
			_pad.visible = false
		if _resume_button != null:
			_resume_button.visible = false
	else:
		if _pad != null:
			_pad.visible = _playing
		_last_sample_ms = -1
		_skip_gameplay_frame = true
	_update_status()


func _fit() -> void:
	size = get_viewport().get_visible_rect().size
	position = Vector2.ZERO


func _start_input() -> void:
	_profile = _store.to_input_config(_save)
	_pipeline = Pipeline.new(_profile)
	_source = Source.new()
	_pipeline.command_ready.connect(_on_command_ready)
	_begin_input_stream()


## New stream only. Fault/focus recovery keeps this origin and sequence.
func _begin_input_stream() -> void:
	_channel_a = 0.0
	_channel_b = 0.0
	_pad.clear()
	_origin_ms = Time.get_ticks_msec()
	_source.reset()
	_pipeline.begin_stream("manual_emulator")
	_last_sample_ms = -1
	_skip_gameplay_frame = true
	if _foreground:
		var now := _now_ms()
		_emit_frame(now)
	else:
		_pipeline.suspend()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)

	_root = Control.new()
	_root.name = "Root"
	layer.add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color("08111d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(background)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	_root.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var title := Label.new()
	title.text = Copy.HEADER_TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("e8f6ff"))
	column.add_child(title)

	var subtitle := Label.new()
	_subtitle = subtitle
	subtitle.text = Copy.HEADER_SUBTITLE
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("7fa6bd"))
	column.add_child(subtitle)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(0, 48)
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color("c7d9e8"))
	column.add_child(_status_label)

	var time_row := HBoxContainer.new()
	time_row.name = "TimeRow"
	time_row.add_theme_constant_override("separation", 12)
	column.add_child(time_row)

	_time_label = Label.new()
	_time_label.name = "TimeLabel"
	_time_label.text = "Активное время: 0.0 с"
	_time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time_label.add_theme_font_size_override("font_size", 16)
	_time_label.add_theme_color_override("font_color", Color("7fa6bd"))
	time_row.add_child(_time_label)

	_resume_button = Button.new()
	_resume_button.name = "ResumeButton"
	_resume_button.text = "Продолжить"
	_resume_button.custom_minimum_size = Vector2(190, 40)
	_resume_button.add_theme_font_size_override("font_size", 18)
	_style_button(_resume_button, Color("b07a2a"))
	_resume_button.visible = false
	_resume_button.pressed.connect(_on_resume_pressed)
	time_row.add_child(_resume_button)

	_course = Course.new()
	_course.name = "Course"
	_course.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_course.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_course)
	_course.completed.connect(_on_level_completed)
	_course.event_emitted.connect(_on_game_event)

	_pad = Pad.new()
	_pad.name = "ManualPad"
	_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pad.visible = false
	column.add_child(_pad)
	_pad.channels_changed.connect(_on_channels_changed)

	_overlay = ColorRect.new()
	_overlay.name = "ScreenOverlay"
	_overlay.color = Color(0.02, 0.04, 0.08, 0.88)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("12263a")
	panel_style.border_color = Color("2d6f73")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	panel_style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var panel_column := VBoxContainer.new()
	panel_column.add_theme_constant_override("separation", 14)
	panel.add_child(panel_column)

	_screen_title = Label.new()
	_screen_title.name = "ScreenTitle"
	_screen_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen_title.add_theme_font_size_override("font_size", 30)
	_screen_title.add_theme_color_override("font_color", Color("e8f6ff"))
	panel_column.add_child(_screen_title)

	_screen_body = Label.new()
	_screen_body.name = "ScreenBody"
	_screen_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_screen_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen_body.custom_minimum_size = Vector2(400, 0)
	_screen_body.add_theme_font_size_override("font_size", 18)
	_screen_body.add_theme_color_override("font_color", Color("c7d9e8"))
	panel_column.add_child(_screen_body)

	_screen_button = Button.new()
	_screen_button.name = "ScreenButton"
	_screen_button.custom_minimum_size = Vector2(0, 54)
	_screen_button.add_theme_font_size_override("font_size", 22)
	_style_button(_screen_button, Color("237f85"))
	_screen_button.pressed.connect(_on_screen_button_pressed)
	panel_column.add_child(_screen_button)

	_next_button = _make_panel_button(panel_column, "Следующая миссия", Color("2d5f8a"))
	_next_button.pressed.connect(_on_next_pressed)
	_mission_button = _make_panel_button(panel_column, "", Color("2d5f8a"))
	_mission_button.pressed.connect(_on_mission_pressed)
	_hand_button = _make_panel_button(panel_column, "", Color("3b4f66"))
	_hand_button.pressed.connect(_on_hand_pressed)
	_apply_hand_side()

	var note := Label.new()
	note.text = Copy.EMULATOR_DISCLAIMER
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", Color("7fa6bd"))
	panel_column.add_child(note)


func _style_button(button: Button, accent: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent
	normal.set_corner_radius_all(12)
	normal.set_content_margin_all(12)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = accent.lightened(0.12)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = accent.darkened(0.14)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)


func _show_start() -> void:
	_playing = false
	_overlay.visible = true
	_course.reset()
	_channel_a = 0.0
	_channel_b = 0.0
	_pad.clear()
	_pad.visible = false
	_resume_button.visible = false
	_time_label.text = "Активное время: 0.0 с"
	_level_cfg = _config_for(_level_id)
	_subtitle.text = Copy.HEADER_SUBTITLE
	_screen_title.text = _level_cfg.title
	_screen_body.text = (
		_level_cfg.hazard_subtitle + "\n\n"
		+ _level_cfg.briefing + "\n\n"
		+ "Пока обе кнопки отпущены, движение и таймер стоят. Это не штраф.\n"
		+ "После старта нажмите «Продолжить», когда ввод будет готов."
	)
	_screen_button.text = "Начать миссию"
	_next_button.visible = false
	_mission_button.visible = true
	_hand_button.visible = true
	_mission_button.text = "Сменить миссию (открыто: %d)" % _unlocked().size()
	_last_status_key = ""
	_update_status()


## Public entry for tests and future mission-select UI. Locked missions are ignored.
func select_level(level_id: String) -> void:
	if level_id in _unlocked() and not _playing:
		_level_id = level_id
		_show_start()


func _begin_round() -> void:
	if not _foreground:
		return
	_playing = false
	_overlay.visible = false
	_level_cfg = _config_for(_level_id)
	_session_counter += 1
	_attempt_counter += 1
	var session_id := "s%d" % _session_counter
	_course.apply_level_config(_level_cfg, session_id, _attempt_counter)
	_tracker.begin_session(session_id, _level_id, "manual_emulator",
		_level_cfg.count_both_as_unwanted, _step_for(_level_id))
	_tracker.begin_attempt(_attempt_counter)
	_subtitle.text = (Copy.TUTORIAL_HINTS[1] if _level_id == "tutorial"
		else _level_cfg.title + " · " + _level_cfg.hazard_subtitle)
	_begin_input_stream()
	_playing = true
	_pad.visible = true
	_time_label.text = "Активное время: 0.0 с"
	_last_status_key = ""
	_update_status()


func _show_result() -> void:
	_playing = false
	_overlay.visible = true
	_pad.visible = false
	_pad.clear()
	_channel_a = 0.0
	_channel_b = 0.0
	_resume_button.visible = false
	var summary = _tracker.build_summary(int(round(_course.active_seconds * 1000.0)))
	var adaptation := _finish_progress(summary)
	_screen_title.text = "РЕМОНТ ЗАВЕРШЁН"
	var both_line := ""
	var both_ratio = summary.unwanted_both_ratio()
	if both_ratio != null:
		both_line = "Встречный сигнал в оценочном окне: %d%%.\n" % int(round(both_ratio * 100.0))
	var hold_line := ""
	var hold_ratio = summary.hold_accuracy_ratio()
	if hold_ratio != null:
		hold_line = "Удержание в зоне стабилизации: %d%%.\n" % int(round(hold_ratio * 100.0))
	_screen_body.text = (
		_level_cfg.upgrade_unlocked + "\n\n"
		+ "Активное время: %.1f с.\n" % _course.active_seconds
		+ both_line + hold_line + "\n"
		+ adaptation + "\n\n"
		+ _level_cfg.expedition_log + "\n\n"
		+ "Это показатели игры на эмуляторе, не медицинская оценка."
	)
	_last_result_text = _screen_body.text
	_screen_button.text = "Повторить"
	var next_id := _next_level_id()
	_next_button.visible = next_id != "" and next_id in _unlocked()
	_mission_button.visible = false
	_hand_button.visible = false


## Applies bounded adaptation between attempts, unlocks the next mission, persists.
func _finish_progress(summary) -> String:
	var struggle: bool = summary.unwanted_both_ms >= 1000
	var clean: bool = summary.unwanted_both_ms == 0
	_clean_streak = _clean_streak + 1 if clean else 0
	_struggle_streak = _struggle_streak + 1 if struggle else 0
	var result: Dictionary = Level.evaluate_adaptation(_step_for(_level_id),
		_clean_streak, _struggle_streak, bool(_save.get("adaptation_enabled", true)))
	if _level_id != "tutorial" and result["changed"]:
		_save["difficulty_steps"][_level_id] = result["step"]
		_clean_streak = 0
		_struggle_streak = 0
	var completed: Array = _save["completed_levels"]
	if not completed.has(_level_id):
		completed.append(_level_id)
	var next_id := _next_level_id()
	var unlocked: Array = _save["unlocked_levels"]
	if next_id != "" and not unlocked.has(next_id):
		unlocked.append(next_id)
	_save["last_summary"] = summary.to_dictionary()
	_store.save_profile(_save)
	if _level_id == "tutorial":
		return "Обучение без адаптации: параметры фиксированы."
	return String(result["explanation"])


func _on_next_pressed() -> void:
	var next_id := _next_level_id()
	if next_id != "" and next_id in _unlocked():
		_level_id = next_id
		_show_start()


func _on_mission_pressed() -> void:
	var opened := _unlocked()
	var index := opened.find(_level_id)
	_level_id = opened[(index + 1) % opened.size()]
	_show_start()


func _on_hand_pressed() -> void:
	_save["hand_side"] = "left" if _save.get("hand_side", "right") == "right" else "right"
	_store.save_profile(_save)
	_apply_hand_side()


func _apply_hand_side() -> void:
	var left: bool = _save.get("hand_side", "right") == "left"
	_pad.set_mirrored(left)
	_pad.set_thresholds(_profile.on_a if _profile else 0.55, _profile.off_a if _profile else 0.40,
		_profile.on_b if _profile else 0.55, _profile.off_b if _profile else 0.40)
	_hand_button.text = "Рука: %s (зеркально)" % ("левая" if left else "правая")


func _make_panel_button(parent: Control, text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_font_size_override("font_size", 18)
	_style_button(button, accent)
	parent.add_child(button)
	return button


func _on_game_event(event) -> void:
	_tracker.record_event(event)


func _config_for(level_id: String):
	return Level.for_id(level_id, _step_for(level_id))


func _step_for(level_id: String) -> int:
	return int(_save.get("difficulty_steps", {}).get(level_id, 0))


func _unlocked() -> Array:
	var result: Array = []
	for id in Level.ordered_ids():
		if id in _save.get("unlocked_levels", ["tutorial", "repair-1"]):
			result.append(id)
	return result


func _next_level_id() -> String:
	var ids := Level.ordered_ids()
	var index := ids.find(_level_id)
	return ids[index + 1] if index >= 0 and index + 1 < ids.size() else ""


func _first_open_level() -> String:
	for id in Level.ordered_ids():
		if id in _save.get("unlocked_levels", []) and not id in _save.get("completed_levels", []):
			return id
	return "tutorial"


func _on_screen_button_pressed() -> void:
	_begin_round()


func _on_resume_pressed() -> void:
	if not _foreground or not _playing or _current == null or _current.state != &"WAITING_RESUME":
		return
	var now := _now_ms()
	if _should_sample(now):
		_emit_frame(now)
	_pipeline.request_resume(now)


func _on_channels_changed(a: float, b: float) -> void:
	_channel_a = clampf(a, 0.0, 1.0)
	_channel_b = clampf(b, 0.0, 1.0)
	if _playing and _foreground:
		_emit_frame(_now_ms())


func _on_level_completed() -> void:
	if _playing:
		_show_result()


func _on_command_ready(next_command) -> void:
	_current = next_command
	_update_status()


func _now_ms() -> int:
	return Time.get_ticks_msec() - _origin_ms


func _should_sample(now_ms: int) -> bool:
	return _last_sample_ms < 0 or now_ms - _last_sample_ms >= _profile.heartbeat_ms


func _emit_frame(now_ms: int) -> void:
	var frame = _source.sample(now_ms, _channel_a, _channel_b, true)
	_pipeline.submit(frame, now_ms)
	_last_sample_ms = now_ms


func _update_status() -> void:
	if _status_label == null:
		return
	var state: StringName = &"NOT_STARTED"
	if _current != null:
		state = _current.state
		var key := "%s/%s/%s" % [_current.state, _current.reason, _current.direction]
		if key != _last_status_key:
			_last_status_key = key
			_status_label.text = Copy.state_message(_current)
			_status_label.add_theme_color_override("font_color", _state_color(state))
	else:
		_status_label.text = "Ввод ещё не запущен."
	if _resume_button != null:
		_resume_button.visible = _foreground and _playing and state == &"WAITING_RESUME"


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
