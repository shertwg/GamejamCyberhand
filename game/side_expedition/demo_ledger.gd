extends RefCounted
## Isolated demo persistence. Never writes campaign storage or awards stock.
const Model = preload("res://game/side_expedition/expedition_model.gd")
const DEFAULT_PATH := "user://quiet_signal_demo_v1.json"
var path: String
var data := {"version": 1, "first_delivery_done": false, "claims": {}, "checkpoint": {}, "pending_events": {}}
var status: String = "fresh"

func _init(save_path: String = DEFAULT_PATH) -> void:
	path = save_path
	if path == "" or not FileAccess.file_exists(path): return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		status = "recovered_bad_save"
		return
	var raw = json.data
	if not raw is Dictionary or raw.get("version") != 1 or typeof(raw.get("first_delivery_done")) != TYPE_BOOL or not raw.get("claims") is Dictionary or not raw.get("checkpoint") is Dictionary:
		status = "recovered_bad_save"
		return
	for id in raw.claims:
		if not id is String or not raw.claims[id] is Dictionary: status = "recovered_bad_save"; return
	if not raw.get("pending_events", {}) is Dictionary: status = "recovered_bad_save"; return
	raw["pending_events"] = raw.get("pending_events", {})
	data = raw
	status = "loaded"

func context() -> Dictionary:
	return {"first_delivery_done": data.first_delivery_done}

func has_checkpoint() -> bool:
	return not data.checkpoint.is_empty()

func checkpoint() -> Dictionary:
	return data.checkpoint.duplicate(true)

func save_checkpoint(value: Dictionary) -> bool:
	var next := data.duplicate(true)
	next.checkpoint = value.duplicate(true)
	return _commit(next)

func receipt(id: String) -> Dictionary:
	return data.claims.get(id, {}).duplicate(true)

func pending_events() -> Dictionary:
	return data.pending_events.duplicate(true)

func acknowledge(id: String) -> bool:
	var next := data.duplicate(true)
	next.pending_events.erase(id)
	return _commit(next)

func claim(result: Dictionary) -> Dictionary:
	var id := String(result.get("reward_id", ""))
	if id == "" or not result.get("completed", false): return {"ok": false, "error": "not_delivered"}
	if data.claims.has(id): return {"ok": true, "already_claimed": true, "result": receipt(id)}
	var value := result.duplicate(true)
	value.first_clear = bool(value.battery_secured) and not bool(data.first_delivery_done)
	value.reward_proposal = Model.rewards_for(value.inventory, not value.crafted_items.is_empty(), value.battery_secured, value.first_clear)
	var next := data.duplicate(true)
	next.claims[id] = value
	next.pending_events[id] = value.duplicate(true)
	next.first_delivery_done = data.first_delivery_done or value.battery_secured
	next.checkpoint = {}
	if not _commit(next): return {"ok": false, "error": "save_failed"}
	return {"ok": true, "already_claimed": false, "result": value.duplicate(true)}

func _commit(next: Dictionary) -> bool:
	if path != "":
		var temporary := path + ".tmp"
		var directory := ProjectSettings.globalize_path(path).get_base_dir()
		if DirAccess.make_dir_recursive_absolute(directory) != OK: status = "save_failed"; return false
		var file = FileAccess.open(temporary, FileAccess.WRITE)
		if file == null: status = "save_failed"; return false
		file.store_string(JSON.stringify(next))
		file.close()
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) != OK:
			status = "save_failed"
			return false
	data = next
	status = "saved"
	return true
