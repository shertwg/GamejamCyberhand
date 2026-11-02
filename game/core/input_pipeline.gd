class_name InputPipeline
extends RefCounted
## Explicitly driven facade. The integrator MUST call tick even without incoming frames.
## All times are nonnegative milliseconds from one shared stream origin, not wall time.

const Frame = preload("res://game/core/input_frame.gd")
const Command = preload("res://game/core/control_command.gd")
const Config = preload("res://game/core/input_config.gd")
const Validator = preload("res://game/core/input_validator.gd")
const Decoder = preload("res://game/core/input_decoder.gd")
const Guard = preload("res://game/core/input_stream_guard.gd")

signal command_ready(command: Command)

var _config: Config
var _validator := Validator.new()
var _decoder: Decoder
var _guard: Guard
var _source: String = ""
var _last_seq: int = -1
var _last_timestamp_ms: int = -1
var _last_now_ms: int = -1
var _started: bool = false
var _config_error: StringName = &"missing_config"
var _current := Command.new()


## Snapshot configuration so changes outside the pipeline cannot bypass safety.
func _init(config: Config) -> void:
	if config == null:
		return
	_config = Config.new(config.on_a, config.off_a, config.on_b, config.off_b,
		config.timeout_ms, config.recovery_policy, config.rest_pauses, config.heartbeat_ms)
	_config_error = _config.validation_error()
	if _config_error == &"":
		_decoder = Decoder.new(_config)
		_guard = Guard.new(_config)


## Explicit new stream; caller resets source and clock together. Never reset on a packet.
func begin_stream(source: String = "manual_emulator") -> Command:
	_started = false
	if _config_error != &"":
		return _stop(&"INVALID", _config_error)
	if source not in ["manual_emulator", "replay"]:
		return _stop(&"INVALID", &"invalid_source")
	_source = source
	_last_seq = -1
	_last_timestamp_ms = -1
	_last_now_ms = -1
	_decoder.reset()
	_guard = Guard.new(_config)
	_started = true
	return _stop(&"WAITING_NEUTRAL", &"new_stream_requires_neutral")


## Accept a typed frame or raw Dictionary. Malformed inputs always publish a safe stop.
func submit(raw: Variant, now_ms: int) -> Command:
	if not _accept_clock(now_ms):
		return _snapshot()
	# Detect a silent gap BEFORE a fresh packet can hide it and resume held input.
	if _guard.is_stale(now_ms):
		_stop(&"STALE", &"stream_timeout")
	var data: Dictionary
	if raw is Frame:
		data = raw.to_dictionary()
	elif raw is Dictionary:
		data = raw.duplicate()
	else:
		return _stop(&"INVALID", &"invalid_frame_type")
	var error := _validator.validate(data, _source, _last_seq, _last_timestamp_ms,
		now_ms, _config.timeout_ms)
	if error != &"":
		return _stop(&"STALE" if error == &"stale_frame" else &"INVALID", error)
	var frame := _validator.materialize(data)
	_last_seq = frame.seq
	_last_timestamp_ms = frame.timestamp_ms
	if not frame.connected:
		return _stop(&"DISCONNECTED", &"source_disconnected")
	var neutral: bool = frame.channel_a <= _config.off_a and frame.channel_b <= _config.off_b
	return _publish(_guard.filter(_decoder.decode(frame), neutral, frame.timestamp_ms))


## Watchdog; keep calling from the host update loop, including input-recovery pauses.
func tick(now_ms: int) -> Command:
	if not _accept_clock(now_ms):
		return _snapshot()
	if _guard.is_stale(now_ms):
		return _stop(&"STALE", &"stream_timeout")
	return _snapshot()


## Does not queue permission: held, missing or stale input cannot be resumed.
func request_resume(now_ms: int) -> Command:
	tick(now_ms)
	if not _started or _config_error != &"" or now_ms < _last_now_ms or now_ms < 0:
		return _snapshot()
	if _guard.try_resume(now_ms):
		_decoder.reset()
		return _publish(Command.new(Command.REST, 0.0, &"REST", &"resumed_neutral", _config.rest_pauses))
	return _snapshot()


## Call on application backgrounding or any external suspension; resume needs neutral again.
func suspend() -> Command:
	return _stop(&"SUSPENDED", &"external_suspend")


func _accept_clock(now_ms: int) -> bool:
	if _config_error != &"":
		_stop(&"INVALID", _config_error)
		return false
	if not _started:
		_stop(&"NOT_STARTED", &"stream_not_started")
		return false
	if now_ms < 0 or now_ms < _last_now_ms:
		_stop(&"INVALID", &"receiver_clock_regressed")
		return false
	_last_now_ms = now_ms
	return true


func _stop(state: StringName, reason: StringName) -> Command:
	if _decoder != null:
		_decoder.reset()
	if _guard != null:
		return _publish(_guard.stop(state, reason))
	return _publish(Command.new(Command.REST, 0.0, state, reason, true))


func _publish(command: Command) -> Command:
	_current = command
	# Signal consumers and return-value consumers cannot mutate our retained command.
	command_ready.emit(_snapshot())
	return _snapshot()


func _snapshot() -> Command:
	return Command.new(_current.direction, _current.intensity, _current.state,
		_current.reason, _current.pause_required)
