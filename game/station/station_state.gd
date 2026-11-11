extends RefCounted
## Ship systems and the cargo manifest are separate. No offline decay.
signal changed
const GROW_SECONDS := 18.0
const BERRY_SECONDS := 32.0
const DEFAULT_PATH := "user://station_homestead_v1.json"
const SUPPLY_START := {"energy": 78.0, "water": 64.0, "food": 53.0}
const SUPPLY_PER_MINUTE := {"energy": 6.0, "water": 5.0, "food": 4.0}
const SUPPLY_PER_UNIT := {"energy": 9, "water": 8, "food": 13}
const SUPPLY_LOW := 25.0
const REWARDS := {
	"tutorial": {"parts": 3, "energy": 1}, "repair-1": {"water": 3, "parts": 1},
	"repair-2": {"energy": 4, "parts": 1}, "repair-3": {"parts": 2}
}
const NAMES := {"parts": "Детали", "water": "Вода", "energy": "Энергия", "food": "Еда"}
const BUILD_COSTS := {"garden": {"parts": 3, "water": 1}, "generator": {"parts": 6, "food": 2}, "beacon": {"parts": 5, "energy": 2}}
const PLANT_COST := {"water": 1, "energy": 1}
const BERRY_COST := {"water": 2, "energy": 1}
const UPGRADE_COST := {"parts": 6, "food": 2}
const LAUNCH_COST := {"parts": 8, "food": 4, "energy": 3}
var path := ""
var data: Dictionary
var notice := "Аварийный запас найден. Восстанови воду для биосада."
var save_ok := true
var _reward_pending := ""
var _save_elapsed := 0.0
var _supply_save_elapsed := 0.0
var _supply_dirty := false

func _init(save_path: String = DEFAULT_PATH) -> void:
	path = save_path
	data = defaults()
	load_save()

static func defaults() -> Dictionary:
	return {"version": 1, "parts": 3, "water": 0, "energy": 2, "food": 0,
		"pump": false, "garden": false, "generator": false, "beacon": false,
		"signal": false, "launched": false, "harvests": 0, "garden_level": 1,
		"beds": [-1.0, -1.0, -1.0], "crops": ["greens", "greens", "greens"], "intro_seen": false, "air_ready": false,
		"fuses": 0, "coils": 0, "expedition": {}, "supplies": SUPPLY_START.duplicate(),
		"quiet_signal_claims": {}, "saved_room": 0}

func load_save() -> void:
	if path.is_empty() or not FileAccess.file_exists(path): return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		save_ok = false
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		notice = "Сохранение станции повреждено. Начинаем с аварийного запаса."
		return
	var raw: Dictionary = json.data
	if raw.get("version") != 1: return
	# Only accept our small typed schema; never copy arbitrary profile fields.
	for key in ["parts", "water", "energy", "food", "harvests", "garden_level"]:
		if not (raw.get(key) is float or raw.get(key) is int): return
		if not is_finite(float(raw[key])) or float(raw[key]) < 0: return
	for key in ["pump", "garden", "generator", "beacon", "signal", "launched"]:
		if not raw.get(key) is bool: return
	if not raw.get("beds") is Array or raw.beds.size() != 3: return
	for bed in raw.beds:
		if not (bed is float or bed is int) or not is_finite(float(bed)): return
		if float(bed) < -1 or float(bed) > BERRY_SECONDS: return
	for key in data:
		if raw.has(key): data[key] = raw[key]
	for key in ["intro_seen", "air_ready"]:
		if not data[key] is bool: data[key] = false
	for key in ["fuses", "coils"]:
		var value: Variant = data[key]
		data[key] = clampi(int(value), 0, 9999) if (value is float or value is int) and is_finite(float(value)) else 0
	for key in ["parts", "water", "energy", "food", "harvests"]:
		data[key] = clampi(int(data[key]), 0, 9999)
	var restored: Variant = data.supplies
	data.supplies = SUPPLY_START.duplicate()
	if restored is Dictionary:
		for key in SUPPLY_START:
			var value: Variant = restored.get(key)
			if (value is float or value is int) and is_finite(float(value)):
				data.supplies[key] = clampf(float(value), 0.0, 100.0)
	data.garden_level = clampi(int(data.garden_level), 1, 2)
	if not data.quiet_signal_claims is Dictionary: data.quiet_signal_claims = {}
	var location: Variant = data.saved_room
	data.saved_room = clampi(int(location), 0, 9) if (location is int or location is float) and is_finite(float(location)) else 0
	var stored_crops: Variant = raw.get("crops", [])
	data.crops = ["greens", "greens", "greens"]
	for i in range(data.beds.size()):
		if data.garden_level == 2 and stored_crops is Array and i < stored_crops.size() and stored_crops[i] == "berries":
			data.crops[i] = "berries"
		data.beds[i] = minf(float(data.beds[i]), grow_seconds(i))
	notice = "Сохранение загружено."

func save() -> bool:
	if path.is_empty(): return true # In-memory test fixture.
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		save_ok = false
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	save_ok = DirAccess.rename_absolute(path + ".tmp", path) == OK
	if save_ok:
		_supply_dirty = false
		_supply_save_elapsed = 0.0
	return save_ok

func supply(key: String) -> float:
	return float(data.supplies[key])

func economy_mode() -> bool:
	if not data.air_ready: return false
	for key in SUPPLY_START:
		if supply(key) <= SUPPLY_LOW: return true
	return false

func add_stock(key: String, amount: int) -> void:
	data[key] = mini(9999, int(data[key]) + amount)
	if SUPPLY_PER_UNIT.has(key):
		data.supplies[key] = minf(100.0, supply(key) + amount * int(SUPPLY_PER_UNIT[key]))

func credit_quiet_signal(result: Dictionary) -> bool:
	var id: Variant = result.get("reward_id")
	if result.get("schema_version") != 1 or result.get("expedition_id") != "quiet_signal" or result.get("completed") != true: return false
	if not id is String or not id.begins_with("quiet_signal/") or id.length() <= 13 or id.length() > 120: return false
	if result.get("run_id") != id.substr(13): return false
	if data.quiet_signal_claims.has(id): return true
	var rewards: Variant = result.get("reward_proposal")
	if not rewards is Array or rewards.size() > 5: return false
	var gains := {"parts": 0, "energy": 0, "alloy": 0}
	var seen := {}
	for item in rewards:
		if not item is Dictionary: return false
		var key: Variant = item.get("item_id")
		var count: Variant = item.get("amount")
		if not key is String or seen.has(key): return false
		if not (count is int or count is float) or not is_finite(float(count)) or count < 1 or count > 8 or float(count) != floorf(count): return false
		seen[key] = true
		match key:
			"conductive_scrap", "ceramic_coupler": gains.parts += int(count)
			"scout_adapter": gains.parts += 2 * int(count)
			"emergency_battery": gains.energy += 3 * int(count)
			"rare_coil": gains.alloy += int(count)
			_: return false
	var previous := {"parts": data.parts, "energy": data.energy, "alloy": data.expedition.get("alloy", 0), "meter": supply("energy")}
	add_stock("parts", gains.parts)
	add_stock("energy", gains.energy)
	data.expedition.alloy = mini(9999, int(previous.alloy) + int(gains.alloy))
	data.quiet_signal_claims[id] = true
	if not save():
		data.parts = previous.parts
		data.energy = previous.energy
		data.expedition.alloy = previous.alloy
		data.supplies.energy = previous.meter
		data.quiet_signal_claims.erase(id)
		return false
	notice = "Добыча на складе · %s" % cost_text(gains) if gains.parts + gains.energy + gains.alloy > 0 else "Вылазка завершена"
	changed.emit()
	return true

func can_refill_from_stock(key: String) -> bool:
	return SUPPLY_PER_UNIT.has(key) and int(data[key]) > 0 and supply(key) <= 100.0 - int(SUPPLY_PER_UNIT[key])

func refill_from_stock(key: String) -> bool:
	if not can_refill_from_stock(key): return false
	data[key] -= 1
	var points := int(SUPPLY_PER_UNIT[key])
	data.supplies[key] = supply(key) + points
	_publish("%s +%d п. п. · Со склада списана 1 единица." % [NAMES[key], points])
	return true

func advance_supplies(delta: float, exposed: bool) -> void:
	if not data.air_ready or delta <= 0.0 or not is_finite(delta): return
	for key in SUPPLY_PER_MINUTE:
		var level := supply(key)
		if level <= 0.0: continue
		var rate := supply_rate(key, exposed)
		data.supplies[key] = maxf(0.0, level - rate * delta / 60.0)
		_supply_dirty = true
	if not _supply_dirty or path.is_empty(): return
	_supply_save_elapsed += delta
	if _supply_save_elapsed >= 10.0:
		_supply_save_elapsed = 0.0
		save()

func supply_rate(key: String, exposed: bool) -> float:
	var installed: Dictionary = data.expedition if data.expedition is Dictionary else {}
	if key == "water":
		if installed.get("condenser") == true: return 5.0 if exposed else 3.0
		if exposed: return 8.0
	if key == "energy" and installed.get("capacitor") == true: return 4.0
	return float(SUPPLY_PER_MINUTE[key])

func flush_supplies() -> void:
	if _supply_dirty and not path.is_empty(): save()

func _publish(message: String) -> void:
	notice = message
	save()
	changed.emit()

func can_pay(cost: Dictionary) -> bool:
	for key in cost:
		if int(data.get(key, 0)) < int(cost[key]): return false
	return true

func _pay(cost: Dictionary) -> bool:
	if not can_pay(cost): return false
	for key in cost: data[key] -= cost[key]
	return true

func begin_job(level_id: String) -> void:
	_reward_pending = level_id if REWARDS.has(level_id) else ""

func cancel_job() -> void:
	_reward_pending = ""

func finish_intro() -> void:
	data.intro_seen = true
	save()

func craft(component: String) -> bool:
	match component:
		"fuses":
			if data.fuses > 0 or not _pay({"parts": 2, "energy": 1}): return false
		"coils":
			if data.coils > 0 or data.fuses < 1 or not _pay({"parts": 3}): return false
			data.fuses -= 1
		_:
			return false
	data[component] += 1
	_publish("Собрано: " + ("предохранитель" if component == "fuses" else "катушка связи"))
	return true

func complete_job(level_id: String) -> String:
	# One reward per started run, even if a completion signal is delivered twice.
	if _reward_pending != level_id or not REWARDS.has(level_id): return ""
	_reward_pending = ""
	var reward: Dictionary = REWARDS[level_id]
	for key in reward: add_stock(key, int(reward[key]))
	if level_id == "tutorial": data.air_ready = true
	if level_id == "repair-1": data.pump = true
	if level_id == "repair-3" and data.beacon: data.signal = true
	var text := "На склад: " + cost_text(reward) + "."
	_publish(text + " Вернись на станцию: ресурсами можно строить и выращивать еду.")
	return text

static func cost_text(cost: Dictionary) -> String:
	var items: PackedStringArray = []
	for key in cost:
		if cost[key] > 0:
			items.append("%s ×%d" % ["Сплав" if key == "alloy" else NAMES.get(key, "Предохранитель"), cost[key]])
	return " · ".join(items)

func build(module: String, install_coil := false) -> bool:
	if not BUILD_COSTS.has(module) or data[module]: return false
	if module == "garden" and not data.pump: return false
	if module == "generator" and int(data.harvests) < 1: return false
	if module == "beacon" and not data.generator: return false
	if install_coil and (module != "beacon" or data.coils < 1): return false
	if not _pay(BUILD_COSTS[module]): return false
	if install_coil: data.coils -= 1
	data[module] = true
	_publish({"garden": "Теплица ожила! Посади семена: вода + энергия превращаются в еду.",
		"generator": "Генератор собран. Обслуживай его, чтобы получать энергию для грядок.",
		"beacon": "Антенна установлена. Проведи ремонтный дрон через её контур, чтобы отправить сигнал."}[module])
	return true

func grow_seconds(index: int) -> float:
	return BERRY_SECONDS if data.crops[index] == "berries" else GROW_SECONDS

func ripe_bed() -> int:
	for i in range(data.beds.size()):
		if float(data.beds[i]) >= grow_seconds(i): return i
	return -1

func crop_yield(index: int) -> int:
	return 4 if data.crops[index] == "berries" else 1 + int(data.garden_level)

func plant(index := -1, crop := "greens") -> bool:
	if not data.garden: return false
	if crop not in ["greens", "berries"] or (crop == "berries" and int(data.garden_level) < 2): return false
	if index == -1: index = data.beds.find(-1.0)
	if index < 0 or index >= data.beds.size() or data.beds[index] != -1.0: return false
	if not _pay(BERRY_COST if crop == "berries" else PLANT_COST): return false
	data.crops[index] = crop
	data.beds[index] = 0.0
	_publish("Семена посажены.")
	return true

func harvest(index := -1) -> bool:
	if index == -1: index = ripe_bed()
	if index < 0 or index >= data.beds.size() or float(data.beds[index]) < grow_seconds(index): return false
	var yield_amount := crop_yield(index)
	data.beds[index] = -1.0
	add_stock("food", yield_amount)
	data.harvests += 1
	_publish("Урожай собран: +%d еды! Запас пригодится для строительства и дороги домой." % yield_amount)
	return true

func upgrade_garden() -> bool:
	if not data.garden or int(data.garden_level) >= 2 or not _pay(UPGRADE_COST): return false
	data.garden_level = 2
	_publish("Теплица улучшена! Теперь каждая грядка даёт 3 еды вместо 2.")
	return true

func launch() -> bool:
	if data.launched or not data.signal or not _pay(LAUNCH_COST): return false
	data.launched = true
	_publish("Курс домой проложен. Доступен свободный режим.")
	return true

func advance(delta: float, running: bool) -> void:
	if not running or delta <= 0 or not is_finite(delta): return
	var grew := false
	var ripe := false
	for i in range(3):
		var elapsed := float(data.beds[i])
		var duration := grow_seconds(i)
		if elapsed >= 0 and elapsed < duration:
			data.beds[i] = minf(duration, elapsed + delta)
			grew = true
			ripe = ripe or data.beds[i] == duration
	if not grew: return
	_save_elapsed += delta
	if ripe:
		_publish("Урожай созрел! Загляни в теплицу и собери еду.")
	elif _save_elapsed >= 1.0:
		_save_elapsed = 0.0
		save()
		changed.emit()

func quest() -> Dictionary:
	if data.launched: return {"chapter": "ЭПИЛОГ · ДОРОГА ДОМОЙ", "title": "Ты вернул станции жизнь", "body": "От аварийного лагеря до зелёного дома. Продолжай выращивать урожай и копить запасы в свободном режиме.", "module": "garden", "step": 7}
	if not data.pump: return {"chapter": "ГЛАВА 1 · ПЕРВАЯ ВОДА", "title": "Запусти водяной насос", "body": "Мы пережили падение. Снаружи жара и ядовитая пыль. Восстанови насос — получишь воду и спасёшь будущий сад.", "module": "pump", "step": 0}
	if not data.garden: return {"chapter": "ГЛАВА 2 · ЗЕЛЁНЫЙ ОСТРОВОК", "title": "Построй теплицу", "body": "Вода есть! Построй теплицу. Если не хватает деталей, разбери обломки в мастерской.", "module": "garden", "step": 1}
	if int(data.harvests) == 0: return {"chapter": "ГЛАВА 2 · ЗЕЛЁНЫЙ ОСТРОВОК", "title": "Вырасти первый урожай", "body": "Посади семена и дождись урожая. Грядка созреет за 18 секунд игры. Пока она растёт, можно заняться ремонтом.", "module": "garden", "step": 2}
	if not data.generator: return {"chapter": "ГЛАВА 3 · ТЁПЛЫЙ ДОМ", "title": "Собери генератор", "body": "Нужно 6 деталей и 2 еды. Еда у тебя уже есть, детали приносит мастерская. Генератор даст возобновляемую энергию.", "module": "generator", "step": 3}
	if not data.beacon: return {"chapter": "ГЛАВА 4 · ЕСТЬ КТО ЖИВОЙ?", "title": "Установи антенну", "body": "Нужно 5 деталей и 2 энергии. Обслужи генератор для запаса энергии. Затем собери антенну на посадочной площадке.", "module": "beacon", "step": 4}
	if not data.signal: return {"chapter": "ГЛАВА 4 · ЕСТЬ КТО ЖИВОЙ?", "title": "Отправь сигнал домой", "body": "Антенна готова, осталось настроить контур. Сначала обслужи генератор: он откроет сложный ремонт антенны.", "module": "beacon", "step": 5}
	return {"chapter": "ГЛАВА 5 · ОБРАТНЫЙ ОТСЧЁТ", "title": "Подготовь корабль к взлёту", "body": "Сигнал принят! Собери 8 деталей, 4 еды и 3 энергии для дороги. Мы улетим, когда ты будешь готов.", "module": "beacon", "step": 6}
