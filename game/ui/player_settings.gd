extends RefCounted

const DEFAULT_PATH := "user://last_light_settings_v1.cfg"
const DEFAULTS := {
	"master": 0.85, "music": 0.75, "effects": 0.85, "vibration": 0.25,
	"large_pad": false, "one_hand": false, "large_text": false, "reduce_motion": false
}
var values := DEFAULTS.duplicate()
var path: String

func _init(save_path := DEFAULT_PATH) -> void:
	path = save_path
	if path.is_empty(): return
	var config := ConfigFile.new()
	if config.load(path) != OK: return
	for key in DEFAULTS:
		set_value(key, config.get_value("player", key, DEFAULTS[key]))

func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key): return
	if DEFAULTS[key] is bool:
		if value is bool: values[key] = value
	elif (value is int or value is float) and is_finite(float(value)):
		values[key] = clampf(float(value), 0.0, 1.0)

func save() -> bool:
	if path.is_empty(): return true
	var config := ConfigFile.new()
	for key in values: config.set_value("player", key, values[key])
	return config.save(path) == OK
