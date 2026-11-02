class_name InputFrame
extends RefCounted
## Internal InputFrame v1, not a Motorica hardware protocol.

var schema_version: int = 1
var seq: int = 0
var timestamp_ms: int = 0
var channel_a: float = 0.0
var channel_b: float = 0.0
var connected: bool = false
var source: String = "manual_emulator"


## Snapshot for validation; callers may also submit an untrusted Dictionary.
func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"seq": seq,
		"timestamp_ms": timestamp_ms,
		"channel_a": channel_a,
		"channel_b": channel_b,
		"connected": connected,
		"source": source,
	}
