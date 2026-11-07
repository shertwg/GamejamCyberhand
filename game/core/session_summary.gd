class_name SessionSummary
extends RefCounted
## Session outcome contract matching contracts/examples/session-summary.json.
## Zero denominators always yield null, never NaN or 0%.

var schema_version: int = 1
var level_id: String = "repair-1"
var active_ms: int = 0
var attempts: int = 0
var successes: int = 0
var unwanted_both_ms: int = 0
var scored_window_ms: int = 0
var median_reaction_ms: Variant = null
var hold_in_target_ms: int = 0
var hold_target_ms: int = 0
var source: String = "manual_emulator"
var difficulty_step: int = 0
var adaptation_reason: String = ""


func success_ratio() -> Variant:
	if attempts <= 0:
		return null
	return float(successes) / float(attempts)


func unwanted_both_ratio() -> Variant:
	if scored_window_ms <= 0:
		return null
	return clampf(float(unwanted_both_ms) / float(scored_window_ms), 0.0, 1.0)


func hold_accuracy_ratio() -> Variant:
	if hold_target_ms <= 0:
		return null
	return clampf(float(hold_in_target_ms) / float(hold_target_ms), 0.0, 1.0)


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"level_id": level_id,
		"active_ms": active_ms,
		"attempts": attempts,
		"successes": successes,
		"unwanted_both_ms": unwanted_both_ms,
		"scored_window_ms": scored_window_ms,
		"median_reaction_ms": median_reaction_ms,
		"hold_in_target_ms": hold_in_target_ms,
		"hold_target_ms": hold_target_ms,
		"source": source,
	}


static func from_dictionary(data: Dictionary) -> SessionSummary:
	var summary := SessionSummary.new()
	if data.has("level_id") and typeof(data["level_id"]) == TYPE_STRING:
		summary.level_id = data["level_id"]
	if data.has("active_ms") and (typeof(data["active_ms"]) == TYPE_INT or typeof(data["active_ms"]) == TYPE_FLOAT):
		summary.active_ms = maxi(0, int(data["active_ms"]))
	if data.has("attempts") and (typeof(data["attempts"]) == TYPE_INT or typeof(data["attempts"]) == TYPE_FLOAT):
		summary.attempts = maxi(0, int(data["attempts"]))
	if data.has("successes") and (typeof(data["successes"]) == TYPE_INT or typeof(data["successes"]) == TYPE_FLOAT):
		summary.successes = maxi(0, int(data["successes"]))
	if data.has("unwanted_both_ms") and (typeof(data["unwanted_both_ms"]) == TYPE_INT or typeof(data["unwanted_both_ms"]) == TYPE_FLOAT):
		summary.unwanted_both_ms = maxi(0, int(data["unwanted_both_ms"]))
	if data.has("scored_window_ms") and (typeof(data["scored_window_ms"]) == TYPE_INT or typeof(data["scored_window_ms"]) == TYPE_FLOAT):
		summary.scored_window_ms = maxi(0, int(data["scored_window_ms"]))
	if data.has("median_reaction_ms") and (typeof(data["median_reaction_ms"]) == TYPE_INT or typeof(data["median_reaction_ms"]) == TYPE_FLOAT):
		summary.median_reaction_ms = maxi(0, int(data["median_reaction_ms"]))
	else:
		summary.median_reaction_ms = null
	if data.has("hold_in_target_ms") and (typeof(data["hold_in_target_ms"]) == TYPE_INT or typeof(data["hold_in_target_ms"]) == TYPE_FLOAT):
		summary.hold_in_target_ms = maxi(0, int(data["hold_in_target_ms"]))
	if data.has("hold_target_ms") and (typeof(data["hold_target_ms"]) == TYPE_INT or typeof(data["hold_target_ms"]) == TYPE_FLOAT):
		summary.hold_target_ms = maxi(0, int(data["hold_target_ms"]))
	if data.has("source") and typeof(data["source"]) == TYPE_STRING and data["source"] in ["manual_emulator", "replay"]:
		summary.source = data["source"]
	return summary
