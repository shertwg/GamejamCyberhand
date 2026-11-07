class_name LocalStore
extends RefCounted
## Versioned offline storage for thresholds, hand side, unlocked missions, and last summary.
## Missing or corrupted files never crash the game: load_profile() falls back to defaults.

const Config = preload("res://game/core/input_config.gd")
const Summary = preload("res://game/core/session_summary.gd")

const DEFAULT_PATH: String = "user://ranger_profile_v1.json"
const SCHEMA_VERSION: int = 1
const VALID_LEVELS: Array[String] = ["tutorial", "repair-1", "repair-2", "repair-3"]

var save_path: String = DEFAULT_PATH
var last_load_status: StringName = &"not_loaded"


func _init(p_save_path: String = DEFAULT_PATH) -> void:
	save_path = p_save_path


static func default_profile() -> Dictionary:
	var defaults := Config.emulator_profile()
	return {
		"schema_version": SCHEMA_VERSION,
		"on_a": defaults.on_a,
		"off_a": defaults.off_a,
		"on_b": defaults.on_b,
		"off_b": defaults.off_b,
		"hand_side": "right",
		"adaptation_enabled": true,
		"unlocked_levels": ["tutorial", "repair-1"],
		"completed_levels": [],
		"difficulty_steps": {
			"tutorial": 0,
			"repair-1": 0,
			"repair-2": 0,
			"repair-3": 0,
		},
		"last_summary": {},
	}


func load_profile() -> Dictionary:
	var fallback := default_profile()
	if not FileAccess.file_exists(save_path):
		last_load_status = &"missing_default"
		return fallback
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		last_load_status = &"corrupted_recovered"
		return fallback
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		last_load_status = &"corrupted_recovered"
		return fallback
	var validated := _sanitize_profile(parsed as Dictionary)
	if validated.is_empty():
		last_load_status = &"corrupted_recovered"
		return fallback
	last_load_status = &"ok"
	return validated


func save_profile(profile: Dictionary) -> bool:
	var clean := _sanitize_profile(profile)
	if clean.is_empty():
		clean = default_profile()
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(clean, "\t"))
	file.close()
	return true


func to_input_config(profile: Dictionary) -> Config:
	var clean := _sanitize_profile(profile)
	if clean.is_empty():
		return Config.emulator_profile()
	var cfg := Config.new(
		float(clean["on_a"]),
		float(clean["off_a"]),
		float(clean["on_b"]),
		float(clean["off_b"])
	)
	if cfg.validation_error() != &"":
		return Config.emulator_profile()
	return cfg


func _sanitize_profile(raw: Dictionary) -> Dictionary:
	if not raw.has("schema_version"):
		return {}
	var version_val: Variant = raw["schema_version"]
	if (typeof(version_val) != TYPE_INT and typeof(version_val) != TYPE_FLOAT) or int(version_val) != SCHEMA_VERSION:
		return {}
	for key in ["on_a", "off_a", "on_b", "off_b"]:
		if not raw.has(key):
			return {}
		var v: Variant = raw[key]
		if (typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT) or not is_finite(float(v)):
			return {}
	var test_cfg := Config.new(
		float(raw["on_a"]),
		float(raw["off_a"]),
		float(raw["on_b"]),
		float(raw["off_b"])
	)
	if test_cfg.validation_error() != &"":
		return {}
	var result := default_profile()
	result["on_a"] = test_cfg.on_a
	result["off_a"] = test_cfg.off_a
	result["on_b"] = test_cfg.on_b
	result["off_b"] = test_cfg.off_b
	if raw.has("hand_side") and typeof(raw["hand_side"]) == TYPE_STRING and raw["hand_side"] in ["left", "right"]:
		result["hand_side"] = raw["hand_side"]
	if raw.has("adaptation_enabled") and typeof(raw["adaptation_enabled"]) == TYPE_BOOL:
		result["adaptation_enabled"] = raw["adaptation_enabled"]
	if raw.has("unlocked_levels") and typeof(raw["unlocked_levels"]) == TYPE_ARRAY:
		var unlocked: Array[String] = ["tutorial", "repair-1"]
		for item in raw["unlocked_levels"]:
			if typeof(item) == TYPE_STRING and item in VALID_LEVELS and not unlocked.has(item):
				unlocked.append(item)
		result["unlocked_levels"] = unlocked
	if raw.has("completed_levels") and typeof(raw["completed_levels"]) == TYPE_ARRAY:
		var completed: Array[String] = []
		for item in raw["completed_levels"]:
			if typeof(item) == TYPE_STRING and item in VALID_LEVELS and not completed.has(item):
				completed.append(item)
		result["completed_levels"] = completed
	if raw.has("difficulty_steps") and typeof(raw["difficulty_steps"]) == TYPE_DICTIONARY:
		var steps: Dictionary = result["difficulty_steps"].duplicate()
		for level_id in VALID_LEVELS:
			if raw["difficulty_steps"].has(level_id):
				var s: Variant = raw["difficulty_steps"][level_id]
				if typeof(s) == TYPE_INT or typeof(s) == TYPE_FLOAT:
					steps[level_id] = clampi(int(s), -1, 1)
		result["difficulty_steps"] = steps
	if raw.has("last_summary") and typeof(raw["last_summary"]) == TYPE_DICTIONARY and not (raw["last_summary"] as Dictionary).is_empty():
		result["last_summary"] = Summary.from_dictionary(raw["last_summary"]).to_dictionary()
	return result
