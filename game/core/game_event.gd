class_name GameEvent
extends RefCounted
## Structured gameplay event passed from game/gameplay to game/core.
## Deduplicated by event_id inside SessionTracker so retries or double-hooks never double-count.

const ACTION_STARTED: StringName = &"action_started"
const ACTION_SUCCEEDED: StringName = &"action_succeeded"
const ACTION_FAILED: StringName = &"action_failed"
const LEVEL_COMPLETED: StringName = &"level_completed"
const ADAPTATION_CHANGED: StringName = &"adaptation_changed"

var schema_version: int = 1
var event_id: String = ""
var event_type: StringName = ACTION_STARTED
var session_id: String = ""
var attempt_id: int = 1
var level_id: String = "repair-1"
var timestamp_ms: int = 0
var reason: StringName = &""
var payload: Dictionary = {}


func _init(
	p_event_id: String = "",
	p_event_type: StringName = ACTION_STARTED,
	p_session_id: String = "",
	p_attempt_id: int = 1,
	p_level_id: String = "repair-1",
	p_timestamp_ms: int = 0,
	p_reason: StringName = &"",
	p_payload: Dictionary = {}
) -> void:
	event_id = p_event_id
	event_type = p_event_type
	session_id = p_session_id
	attempt_id = p_attempt_id
	level_id = p_level_id
	timestamp_ms = p_timestamp_ms
	reason = p_reason
	payload = p_payload.duplicate(true)


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"event_id": event_id,
		"event_type": String(event_type),
		"session_id": session_id,
		"attempt_id": attempt_id,
		"level_id": level_id,
		"timestamp_ms": timestamp_ms,
		"reason": String(reason),
		"payload": payload.duplicate(true),
	}
