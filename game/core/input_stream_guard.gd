class_name InputStreamGuard
extends RefCounted

const Command = preload("res://game/core/control_command.gd")
const Config = preload("res://game/core/input_config.gd")

var _config: Config
var _blocked: bool = true
var _both_blocked: bool = false
var _fault_reason: StringName = &"new_stream_requires_neutral"
var _neutral_now: bool = false
var _has_connected_frame: bool = false
var _last_frame_ms: int = 0
var _timeout_latched: bool = false


func _init(config: Config) -> void:
	_config = config


## Faults revoke any previous neutral/resume permission immediately.
func stop(state: StringName, reason: StringName) -> Command:
	_blocked = true
	_both_blocked = false
	_fault_reason = reason
	if state == &"STALE":
		_timeout_latched = true
	_neutral_now = false
	_has_connected_frame = false
	return Command.new(Command.REST, 0.0, state, reason, true)


## Call independently of frame delivery. Timestamp age also detects a stalled producer.
func is_stale(now_ms: int) -> bool:
	return not _timeout_latched and now_ms - _last_frame_ms >= _config.timeout_ms


## Valid connected frames refresh freshness, but held channels cannot release a fault.
func filter(command: Command, neutral: bool, timestamp_ms: int) -> Command:
	_last_frame_ms = timestamp_ms
	_timeout_latched = false
	_has_connected_frame = true
	_neutral_now = neutral
	if command.direction == Command.BOTH:
		_both_blocked = true
		return command
	# A BOTH cycle never weakens a pre-existing fault/startup barrier.
	if _blocked:
		if not neutral:
			return Command.new(Command.REST, 0.0, &"WAITING_NEUTRAL", _fault_reason, true)
		_both_blocked = false
		return Command.new(Command.REST, 0.0, &"WAITING_RESUME", _fault_reason, true)
	if _both_blocked:
		if not neutral:
			return Command.new(Command.REST, 0.0, &"WAITING_NEUTRAL", &"both_requires_neutral", true)
		_both_blocked = false
		return Command.new(Command.REST, 0.0, &"REST", &"both_neutral_recovery", true)
	return command


## Resume only while the latest connected frame is fresh AND still neutral.
func try_resume(now_ms: int) -> bool:
	if not _blocked or not _has_connected_frame or not _neutral_now or is_stale(now_ms):
		return false
	_blocked = false
	_both_blocked = false
	_fault_reason = &""
	return true
