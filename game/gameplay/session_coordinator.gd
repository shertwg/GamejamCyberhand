class_name SessionCoordinator
extends Control
## Pure gameplay and input session coordinator.
## Manages InputPipeline, LocalStore, SessionTracker, course simulation,
## lifecycle events, and bounded difficulty adaptation without UI rendering code.

const CourseScript = preload("res://game/gameplay/course.gd")
const Config = preload("res://game/core/input_config.gd")
const Pipeline = preload("res://game/core/input_pipeline.gd")
const Source = preload("res://game/core/manual_input_source.gd")
const Command = preload("res://game/core/control_command.gd")
const Level = preload("res://game/core/level_config.gd")
const Tracker = preload("res://game/core/session_tracker.gd")
const Store = preload("res://game/core/local_store.gd")
const Copy = preload("res://game/content/copy_catalog.gd")

## Signals defining the contract for Astra's UI (planning/astra-contract.md)
signal command_updated(command: Command)
signal mission_started(level_id: String, config: Level)
signal mission_tick(active_seconds: float, in_hold_zone: bool)
signal mission_completed(summary: Variant, adaptation: Dictionary)
signal input_barrier_changed(needs_resume: bool, prompt_text: String)
signal hand_side_changed(is_left: bool)
signal unlocked_missions_changed(unlocked_ids: Array)

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

var _profile
var _pipeline
var _source
var _origin_ms: int = 0
var _last_sample_ms: int = -1
var _channel_a: float = 0.0
var _channel_b: float = 0.0
var _current: Command
var _playing: bool = false
var _expedition_input := false
var _foreground: bool = true
var _application_paused: bool = false
var _application_focused: bool = true
var _skip_gameplay_frame: bool = true
var _last_status_key: String = ""

var _course
var repair_task: Control


func _ready() -> void:
	init_coordinator()


func init_coordinator() -> void:
	if _store != null:
		return
	name = "SessionCoordinator"
	_store = Store.new(store_path_override if store_path_override != "" else Store.DEFAULT_PATH)
	_save = _store.load_profile()
	_tracker = Tracker.new()
	_level_id = _first_open_level()
	_start_input()
	_init_course()


func _init_course() -> void:
	if _course == null:
		_course = CourseScript.new()
		_course.name = "Course"
		_course.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_course.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_course.completed.connect(_on_level_completed)
		_course.event_emitted.connect(_on_game_event)
		add_child(_course)


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
	# Watchdog: runs on every host frame, including start/result screens and focus loss.
	_pipeline.tick(now_ms)
	if _foreground and sample_heartbeat and _should_sample(now_ms):
		_emit_frame(now_ms)
	var skip_gameplay := _skip_gameplay_frame
	_skip_gameplay_frame = false
	if _playing and _foreground and _current != null and not skip_gameplay:
		if is_instance_valid(repair_task):
			_tracker.record_step(int(round(delta * 1000.0)), _current)
			repair_task.advance(minf(delta, 0.1), _current)
			return
		_tracker.record_step(int(round(delta * 1000.0)), _current,
			_level_cfg.count_both_as_unwanted, _course.is_in_hold_zone(), _level_cfg.hold_target_ms)
		_course.advance(delta, _current)
		mission_tick.emit(_course.active_seconds, _course.is_in_hold_zone())


## External suspension is not a resume. The player must return to neutral and
## explicitly press "Продолжить" after the host reports WAITING_RESUME.
func set_foreground(value: bool) -> void:
	if value == _foreground:
		return
	_foreground = value
	if not value:
		_channel_a = 0.0
		_channel_b = 0.0
		if _pipeline != null:
			_pipeline.suspend()
	else:
		_last_sample_ms = -1
		_skip_gameplay_frame = true
	_update_status()


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


## Public contract methods called by UI / Astra
func start_current_mission(arm_fresh_manual := false) -> void:
	if not _foreground:
		return
	_playing = false
	_level_cfg = _config_for(_level_id)
	_session_counter += 1
	_attempt_counter += 1
	var session_id := "s%d" % _session_counter
	_course.apply_level_config(_level_cfg, session_id, _attempt_counter)
	_tracker.begin_session(session_id, _level_id, "manual_emulator",
		_level_cfg.count_both_as_unwanted, _step_for(_level_id))
	_tracker.begin_attempt(_attempt_counter)
	_begin_input_stream()
	_playing = true
	_last_status_key = ""
	_update_status()
	mission_started.emit(_level_id, _level_cfg)
	# The player explicitly chose the repair. Only this fresh manual stream can arm here.
	if arm_fresh_manual: request_resume()


func select_level(level_id: String) -> void:
	if level_id in _unlocked() and not _playing:
		_level_id = level_id


func retry_mission() -> void:
	start_current_mission()


func next_mission() -> void:
	var next_id := _next_level_id()
	if next_id != "" and next_id in _unlocked():
		_level_id = next_id


func cycle_mission() -> void:
	var opened := _unlocked()
	var index := opened.find(_level_id)
	_level_id = opened[(index + 1) % opened.size()]


func toggle_hand_side() -> void:
	var new_side := "left" if _save.get("hand_side", "right") == "right" else "right"
	set_hand_side(new_side == "left")


func set_hand_side(is_left: bool) -> void:
	_save["hand_side"] = "left" if is_left else "right"
	_store.save_profile(_save)
	hand_side_changed.emit(is_left)


func is_hand_left() -> bool:
	return _save.get("hand_side", "right") == "left"


func request_resume() -> void:
	if not _foreground or not (_playing or _expedition_input) or _current == null or _current.state != &"WAITING_RESUME":
		return
	var now := _now_ms()
	if _should_sample(now):
		_emit_frame(now)
	_pipeline.request_resume(now)


func set_channel_values(a: float, b: float) -> void:
	_channel_a = clampf(a, 0.0, 1.0)
	_channel_b = clampf(b, 0.0, 1.0)
	if (_playing or _expedition_input) and _foreground:
		_emit_frame(_now_ms())


func set_expedition_input(enabled: bool) -> void:
	_expedition_input = enabled
	if enabled:
		_begin_input_stream()
	suspend_current_input()


func suspend_current_input() -> void:
	_channel_a = 0.0
	_channel_b = 0.0
	_pipeline.suspend()
	_last_sample_ms = -1


func resume_expedition_input() -> void:
	if not _expedition_input or not _foreground: return
	_emit_frame(_now_ms())
	request_resume()


func clear_channel_values() -> void:
	set_channel_values(0.0, 0.0)


func _on_level_completed() -> void:
	if not _playing:
		return
	_playing = false
	_channel_a = 0.0
	_channel_b = 0.0
	var seconds: float = repair_task.active_seconds if is_instance_valid(repair_task) else _course.active_seconds
	var summary = _tracker.build_summary(int(round(seconds * 1000.0)))
	var adaptation := _finish_progress(summary)
	mission_completed.emit(summary, {
		"explanation": adaptation,
		"level_cfg": _level_cfg,
		"unlocked": _unlocked(),
		"next_id": _next_level_id()
	})
	unlocked_missions_changed.emit(_unlocked())


## Applies bounded adaptation between attempts, unlocks next mission, persists.
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


func _on_game_event(event) -> void:
	_tracker.record_event(event)


func _on_command_ready(next_command) -> void:
	_current = next_command
	_update_status()
	command_updated.emit(_current)


func _now_ms() -> int:
	return Time.get_ticks_msec() - _origin_ms


func _should_sample(now_ms: int) -> bool:
	return _last_sample_ms < 0 or now_ms - _last_sample_ms >= _profile.heartbeat_ms


func _emit_frame(now_ms: int) -> void:
	var frame = _source.sample(now_ms, _channel_a, _channel_b, true)
	_pipeline.submit(frame, now_ms)
	_last_sample_ms = now_ms


func _update_status() -> void:
	var state: StringName = &"NOT_STARTED"
	var needs_resume: bool = false
	var prompt_text: String = ""
	if _current != null:
		state = _current.state
		prompt_text = Copy.state_message(_current)
		needs_resume = _foreground and _playing and state == &"WAITING_RESUME"
	else:
		prompt_text = "Ввод ещё не запущен."
	input_barrier_changed.emit(needs_resume, prompt_text)


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
