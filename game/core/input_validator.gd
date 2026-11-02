class_name InputValidator
extends RefCounted

const Frame = preload("res://game/core/input_frame.gd")
const FIELDS: Array[String] = [
	"schema_version", "seq", "timestamp_ms", "channel_a", "channel_b", "connected", "source",
]
# JSON numbers arrive as floats; larger float integers cannot be trusted exactly.
const MAX_EXACT_FLOAT_INTEGER: float = 9007199254740991.0


## Validate raw values BEFORE casting them to typed fields. No silent clamping.
func validate(
	data: Dictionary, expected_source: String, last_seq: int,
	last_timestamp_ms: int, now_ms: int, timeout_ms: int
) -> StringName:
	if data.size() != FIELDS.size():
		return &"invalid_fields"
	for field in FIELDS:
		if not data.has(field):
			return &"missing_field"
	for field in ["schema_version", "seq", "timestamp_ms"]:
		if not _is_nonnegative_integer(data[field]):
			return &"invalid_integer"
	if int(data["schema_version"]) != 1:
		return &"unsupported_schema_version"
	for field in ["channel_a", "channel_b"]:
		if not _is_channel(data[field]):
			return &"invalid_channel"
	if typeof(data["connected"]) != TYPE_BOOL:
		return &"invalid_connected"
	if typeof(data["source"]) != TYPE_STRING:
		return &"invalid_source"
	if data["source"] not in ["manual_emulator", "replay"]:
		return &"invalid_source"
	if data["source"] != expected_source:
		return &"unexpected_source"
	if not data["connected"] and (data["channel_a"] != 0 or data["channel_b"] != 0):
		return &"disconnected_channels_not_zero"
	if int(data["seq"]) <= last_seq:
		return &"non_increasing_seq"
	if int(data["timestamp_ms"]) < last_timestamp_ms:
		return &"timestamp_regressed"
	if int(data["timestamp_ms"]) > now_ms:
		return &"timestamp_in_future"
	if now_ms - int(data["timestamp_ms"]) >= timeout_ms:
		return &"stale_frame"
	return &""


## Call only after validate succeeds; the new frame cannot alias caller data.
func materialize(data: Dictionary) -> Frame:
	var frame := Frame.new()
	frame.schema_version = int(data["schema_version"])
	frame.seq = int(data["seq"])
	frame.timestamp_ms = int(data["timestamp_ms"])
	frame.channel_a = float(data["channel_a"])
	frame.channel_b = float(data["channel_b"])
	frame.connected = bool(data["connected"])
	frame.source = String(data["source"])
	return frame


func _is_nonnegative_integer(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return value >= 0
	if typeof(value) == TYPE_FLOAT:
		return is_finite(value) and value >= 0.0 and value <= MAX_EXACT_FLOAT_INTEGER and floor(value) == value
	return false


func _is_channel(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	return is_finite(float(value)) and value >= 0.0 and value <= 1.0
