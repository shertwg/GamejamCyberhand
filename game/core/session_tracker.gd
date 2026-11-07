class_name SessionTracker
extends RefCounted
## Aggregates gameplay events and input timing into SessionSummary.
## Deduplicates event_id and ignores events from stale attempts or sessions.

const Command = preload("res://game/core/control_command.gd")
const Event = preload("res://game/core/game_event.gd")
const Summary = preload("res://game/core/session_summary.gd")

var session_id: String = "session-1"
var attempt_id: int = 1
var level_id: String = "repair-1"
var source: String = "manual_emulator"
var count_both_as_unwanted: bool = true
var difficulty_step: int = 0
var adaptation_reason: String = ""

var _active_ms: int = 0
var _attempts: int = 0
var _successes: int = 0
var _unwanted_both_ms: int = 0
var _scored_window_ms: int = 0
var _hold_in_target_ms: int = 0
var _hold_target_ms: int = 0
var _reactions_ms: Array[int] = []
var _seen_events: Dictionary = {}
var _pending_prompt_ms: int = -1
var _pending_direction: StringName = &""


func begin_session(
	p_session_id: String,
	p_level_id: String,
	p_source: String = "manual_emulator",
	p_count_both_as_unwanted: bool = true,
	p_difficulty_step: int = 0
) -> void:
	session_id = p_session_id
	attempt_id = 1
	level_id = p_level_id
	source = p_source if p_source in ["manual_emulator", "replay"] else "manual_emulator"
	count_both_as_unwanted = p_count_both_as_unwanted
	difficulty_step = p_difficulty_step
	adaptation_reason = ""
	_active_ms = 0
	_attempts = 0
	_successes = 0
	_unwanted_both_ms = 0
	_scored_window_ms = 0
	_hold_in_target_ms = 0
	_hold_target_ms = 0
	_reactions_ms.clear()
	_seen_events.clear()
	_pending_prompt_ms = -1
	_pending_direction = &""


func begin_attempt(next_attempt_id: int) -> void:
	attempt_id = maxi(1, next_attempt_id)
	_pending_prompt_ms = -1
	_pending_direction = &""


func open_reaction_prompt(expected_direction: StringName, prompt_ms: int) -> void:
	if prompt_ms < 0:
		return
	_pending_direction = expected_direction
	_pending_prompt_ms = prompt_ms


func observe_command(command: Command, now_ms: int) -> void:
	if command == null or _pending_prompt_ms < 0 or now_ms < _pending_prompt_ms:
		return
	if command.state == &"ACTIVE":
		if _pending_direction == &"" or command.direction == _pending_direction:
			_reactions_ms.append(now_ms - _pending_prompt_ms)
			_pending_prompt_ms = -1
			_pending_direction = &""


func record_step(
	delta_ms: int,
	command: Command,
	in_scored_window: bool = true,
	in_hold_target: bool = false,
	hold_target_ms_override: int = -1
) -> void:
	if delta_ms <= 0 or command == null:
		return
	if hold_target_ms_override >= 0:
		_hold_target_ms = hold_target_ms_override
	if command.state == &"ACTIVE" and not command.pause_required:
		_active_ms += delta_ms
		if in_scored_window:
			_scored_window_ms += delta_ms
		if in_hold_target:
			_hold_in_target_ms += delta_ms
	elif command.state == &"BOTH":
		if in_scored_window and count_both_as_unwanted:
			_unwanted_both_ms += delta_ms
			_scored_window_ms += delta_ms


func record_event(event: Event) -> bool:
	if event == null or event.event_id == "":
		return false
	if event.session_id != session_id or event.attempt_id != attempt_id:
		return false
	if _seen_events.has(event.event_id):
		return false
	_seen_events[event.event_id] = true
	match event.event_type:
		Event.ACTION_STARTED:
			_attempts += 1
			var expected := StringName(String(event.payload.get("expected_direction", "")))
			open_reaction_prompt(expected, event.timestamp_ms)
		Event.ACTION_SUCCEEDED:
			if _attempts == 0:
				_attempts = 1
			_successes += 1
		Event.ACTION_FAILED:
			if _attempts == 0:
				_attempts = 1
		Event.LEVEL_COMPLETED:
			if _attempts == 0:
				_attempts = 1
			if _successes == 0:
				_successes = 1
		Event.ADAPTATION_CHANGED:
			adaptation_reason = String(event.payload.get("explanation", ""))
	return true


func compute_median_reaction_ms() -> Variant:
	if _reactions_ms.is_empty():
		return null
	var sorted := _reactions_ms.duplicate()
	sorted.sort()
	var mid := sorted.size() / 2
	if sorted.size() % 2 == 1:
		return sorted[mid]
	return int(round((float(sorted[mid - 1]) + float(sorted[mid])) * 0.5))


func build_summary(override_active_ms: int = -1) -> Summary:
	var summary := Summary.new()
	summary.level_id = level_id
	summary.active_ms = override_active_ms if override_active_ms >= 0 else _active_ms
	summary.attempts = _attempts
	summary.successes = mini(_successes, _attempts)
	summary.unwanted_both_ms = _unwanted_both_ms
	summary.scored_window_ms = maxi(_scored_window_ms, _unwanted_both_ms)
	summary.median_reaction_ms = compute_median_reaction_ms()
	summary.hold_in_target_ms = mini(_hold_in_target_ms, _hold_target_ms) if _hold_target_ms > 0 else _hold_in_target_ms
	summary.hold_target_ms = _hold_target_ms
	summary.source = source
	summary.difficulty_step = difficulty_step
	summary.adaptation_reason = adaptation_reason
	return summary
