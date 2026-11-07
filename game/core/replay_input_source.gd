class_name ReplayInputSource
extends RefCounted
## Deterministic signal trace player (source = "replay") for QA and core verification.
## Covers clean A, clean B, rest, opposing BOTH, threshold jitter, and disconnect recovery.

const Frame = preload("res://game/core/input_frame.gd")
signal frame_ready(frame: Frame)

var _next_seq: int = 0
var _trace_name: String = "rest"
var _cursor: int = 0
var _steps: Array[Dictionary] = []


static func available_traces() -> PackedStringArray:
	return PackedStringArray([
		"clean_a",
		"clean_b",
		"rest",
		"opposing_both",
		"threshold_jitter",
		"disconnect_recovery",
	])


func reset(trace_name: String = "rest") -> void:
	_next_seq = 0
	_cursor = 0
	_trace_name = trace_name
	_steps = _build_trace(trace_name)


func sample_step(timestamp_ms: int) -> Frame:
	if _steps.is_empty():
		_steps = _build_trace(_trace_name)
	var entry: Dictionary = _steps[mini(_cursor, _steps.size() - 1)]
	_cursor += 1
	var connected := bool(entry.get("connected", true))
	var frame := Frame.new()
	frame.seq = _next_seq
	_next_seq += 1
	frame.timestamp_ms = timestamp_ms
	frame.connected = connected
	frame.channel_a = float(entry.get("a", 0.0)) if connected else 0.0
	frame.channel_b = float(entry.get("b", 0.0)) if connected else 0.0
	frame.source = "replay"
	frame_ready.emit(frame)
	return frame


static func _build_trace(trace_name: String) -> Array[Dictionary]:
	match trace_name:
		"clean_a":
			return [
				{"a": 0.0, "b": 0.0, "connected": true},
				{"a": 0.65, "b": 0.0, "connected": true},
				{"a": 0.85, "b": 0.0, "connected": true},
				{"a": 1.0, "b": 0.0, "connected": true},
				{"a": 0.0, "b": 0.0, "connected": true},
			]
		"clean_b":
			return [
				{"a": 0.0, "b": 0.0, "connected": true},
				{"a": 0.0, "b": 0.65, "connected": true},
				{"a": 0.0, "b": 0.90, "connected": true},
				{"a": 0.0, "b": 0.0, "connected": true},
			]
		"opposing_both":
			return [
				{"a": 0.0, "b": 0.0, "connected": true},
				{"a": 0.80, "b": 0.0, "connected": true},
				{"a": 0.80, "b": 0.80, "connected": true},
				{"a": 0.80, "b": 0.0, "connected": true},
				{"a": 0.0, "b": 0.0, "connected": true},
				{"a": 0.0, "b": 0.80, "connected": true},
			]
		"threshold_jitter":
			# With on=0.55 and off=0.40: stays off at 0.52, turns on at 0.58,
			# stays active inside hysteresis band at 0.45, turns off at 0.38.
			return [
				{"a": 0.0, "b": 0.0, "connected": true},
				{"a": 0.52, "b": 0.0, "connected": true},
				{"a": 0.58, "b": 0.0, "connected": true},
				{"a": 0.45, "b": 0.0, "connected": true},
				{"a": 0.42, "b": 0.0, "connected": true},
				{"a": 0.38, "b": 0.0, "connected": true},
			]
		"disconnect_recovery":
			return [
				{"a": 0.0, "b": 0.0, "connected": true},
				{"a": 0.80, "b": 0.0, "connected": true},
				{"a": 0.0, "b": 0.0, "connected": false},
				{"a": 0.80, "b": 0.0, "connected": true},
				{"a": 0.0, "b": 0.0, "connected": true},
			]
		_:
			return [
				{"a": 0.0, "b": 0.0, "connected": true},
				{"a": 0.0, "b": 0.0, "connected": true},
			]
