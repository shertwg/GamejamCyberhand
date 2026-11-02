class_name ManualInputSource
extends RefCounted
## Programmatic emulator: no UI, keyboard polling, hardware or automatic clock.

const Frame = preload("res://game/core/input_frame.gd")
signal frame_ready(frame: Frame)

var _next_seq: int = 0


## Reset only together with InputPipeline.begin_stream and a new shared clock origin.
func reset() -> void:
	_next_seq = 0


## Call at each configured heartbeat, even when values do not change.
## Equal argument sequences after reset produce equal frames. Silence = stop calling.
func sample(timestamp_ms: int, channel_a: float, channel_b: float, connected: bool = true) -> Frame:
	var frame := Frame.new()
	frame.seq = _next_seq
	_next_seq += 1
	frame.timestamp_ms = timestamp_ms
	frame.connected = connected
	frame.channel_a = channel_a if connected else 0.0
	frame.channel_b = channel_b if connected else 0.0
	frame.source = "manual_emulator"
	# Invalid connected samples deliberately reach the validator, never get clamped.
	frame_ready.emit(frame)
	return frame
