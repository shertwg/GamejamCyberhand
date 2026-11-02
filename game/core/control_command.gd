class_name ControlCommand
extends RefCounted
## direction/intensity are the contract. Remaining fields are local safety metadata.

const REST: StringName = &"REST"
const OPEN: StringName = &"OPEN"
const CLOSE: StringName = &"CLOSE"
const BOTH: StringName = &"BOTH"

var direction: StringName = REST
var intensity: float = 0.0
var state: StringName = &"NOT_STARTED"
var reason: StringName = &"stream_not_started"
var pause_required: bool = true


## Every publication is a new value; consumers must treat it as read-only.
func _init(
	p_direction: StringName = REST,
	p_intensity: float = 0.0,
	p_state: StringName = &"NOT_STARTED",
	p_reason: StringName = &"stream_not_started",
	p_pause_required: bool = true
) -> void:
	direction = p_direction
	intensity = p_intensity
	state = p_state
	reason = p_reason
	pause_required = p_pause_required
