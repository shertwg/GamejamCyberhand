extends RefCounted
## Campaign progression and repeatable deposits. Save data lives with the ship.
const ROOMS := ["Рубка","Гидроузел","Мастерская","Биосад","Реакторная",
	"Радиорубка","Шлюз","Ущелье","Кристальная пещера","Ретранслятор"]
const LABELS := {"parts":"Детали","energy":"Заряд","ore":"Руда","silica":"Кристаллы","alloy":"Сплав"}
const RECIPES := {
	"filter": {"parts":2,"energy":1},
	"alloy": {"ore":3,"energy":1},
	"shield": {"alloy":1,"silica":2},
	"liner": {"silica":3,"parts":2},
	"cell": {"ore":1,"silica":1},
	"stabilizer": {"silica":2,"alloy":1},
	"condenser": {"parts":4,"silica":2},
	"capacitor": {"parts":4,"ore":3}
}
const INSTALLATIONS := {1: "condenser", 4: "capacitor"}
const DEPOSITS := {
	6: [[Vector2(105,176),"parts",2,"Контейнер"],[Vector2(263,182),"energy",1,"Батарея"]],
	7: [[Vector2(88,176),"ore",2,"Рудная жила"],[Vector2(279,185),"ore",2,"Обломки"]],
	8: [[Vector2(100,183),"silica",2,"Кристаллы"],[Vector2(267,182),"silica",2,"Минералы"]],
	9: [[Vector2(299,184),"energy",2,"Ячейка"]]
}
const CHAPTERS := [
	["I · Авария","Перекрой утечку воздуха в рубке."],
	["II · Первый контур","Верни воду и вырасти первый урожай."],
	["III · Снова под током","Собери реактор и подключи антенну."],
	["IV · Голос в эфире","Поймай ответ орбитального патруля."],
	["V · Окно домой","Заполни трюм и запусти корабль."],
	["Эпилог · Восход","Керна осталась позади."]
]

static func physical_room(system: int) -> int:
	return 0 if system < 6 and system != 3 else system

var station
var data: Dictionary
var cooldowns: Dictionary = {}
var available_repairs: Array = ["tutorial", "repair-1"]

static func defaults() -> Dictionary:
	return {"ore":0,"silica":0,"alloy":0,"filter":false,"shield":false,"liner":false,"stabilizer":false,"extractor":false,
		"relay":false,"discovered":[0],"collected":0,"repairs":0,"last":{},
		"story_flags":[],"dialogue":[],"best_relay":-1,"condenser":false,"capacitor":false,
		"weather_shift":0,"weather_event":""}

func _init(model) -> void:
	station = model
	data = defaults()
	var saved: Variant = station.data.get("expedition", {})
	if saved is Dictionary:
		for key in ["ore","silica","alloy","collected","repairs","best_relay","weather_shift"]:
			var amount: Variant = saved.get(key,data[key])
			if (amount is int or amount is float) and is_finite(float(amount)):
				data[key] = int(clampf(float(amount),-1 if key == "best_relay" else 0,9999))
		for key in ["filter","shield","liner","relay","stabilizer","extractor","condenser","capacitor"]:
			var flag: Variant = saved.get(key,false)
			data[key] = flag if flag is bool else false
		for key in ["discovered","story_flags"]:
			if saved.get(key) is Array:
				for id in saved[key]:
					var max_id := 9 if key == "discovered" else 5
					if (id is int or id is float) and is_finite(float(id)) and id >= 0 and id <= max_id and int(id) not in data[key]:
						data[key].append(int(id))
		if saved.get("dialogue") is Array:
			for id in saved.dialogue:
				if id is String and id.length() <= 24 and id not in data.dialogue and data.dialogue.size() < 64:
					data.dialogue.append(id)
		if saved.get("last") is Dictionary:
			data.last = saved.last.duplicate()
		if saved.get("weather_event") in ["dust", "vent"]:
			data.weather_event = saved.weather_event
	station.data.expedition = data

func next_station_event() -> String:
	if not data.weather_event.is_empty(): return ""
	var event: String = ["dust", "vent", "tracks"][int(data.weather_shift) % 3]
	data.weather_shift = (int(data.weather_shift) + 1) % 3
	if event != "tracks": data.weather_event = event
	station.save()
	return event

func finish_dust_cycle() -> void:
	if data.weather_event != "dust": return
	data.weather_event = ""
	station.save()

func chapter() -> int:
	if station.data.launched: return 5
	if not station.data.air_ready: return 0
	if station.data.harvests == 0: return 1
	if not station.data.beacon: return 2
	if not station.data.signal: return 3
	return 4

func locked(room: int) -> String:
	if room <= 0: return ""
	if not station.data.air_ready: return "Сначала закрой аварийную заслонку."
	if room >= 6 and not station.data.pump: return "Сначала верни охлаждение в гидроузле."
	if room >= 7 and not data.filter: return "Собери фильтр в шлюзе."
	if room == 8 and data.ore == 0 and data.alloy == 0 and not data.shield and 8 not in data.discovered:
		return "Возьми образец руды в ущелье."
	if room == 9 and (not data.shield or not station.data.generator or not station.data.beacon):
		return "Нужны экран, реактор и антенна корабля."
	return ""

func discover(room: int) -> bool:
	if room in data.discovered: return false
	data.discovered.append(room)
	station.save()
	return true

func tick(delta: float) -> bool:
	var refreshed := false
	for key in cooldowns:
		if cooldowns[key] <= 0: continue
		cooldowns[key] = maxf(0.0,cooldowns[key] - delta)
		if cooldowns[key] == 0: refreshed = true
	return refreshed

func nodes(room: int) -> Array:
	return DEPOSITS.get(room, [])

func remaining(room: int, index: int) -> float:
	return cooldowns.get(Vector2i(room,index),0.0)

func collect(room: int, index: int) -> String:
	var points := nodes(room)
	if index < 0 or index >= points.size() or remaining(room,index) > 0 or not locked(room).is_empty():
		return ""
	if room == 8 and not data.extractor: return ""
	var deposit: Array = points[index]
	var key: String = deposit[1]
	var count: int = deposit[2] + (1 if data.liner and key in ["ore","silica"] else 0)
	if key == "silica" and data.weather_event == "vent":
		count += 2
		data.weather_event = ""
	if data.has(key): data[key] = mini(9999,int(data[key])+count)
	else: station.add_stock(key, count)
	data.collected = mini(9999,int(data.collected)+count)
	cooldowns[Vector2i(room,index)] = 12.0
	station.save()
	return "%s +%d" % [LABELS[key],count]

func can_craft(id: String) -> bool:
	if not RECIPES.has(id): return false
	if id not in ["alloy","cell"] and data[id]: return false
	if id == "condenser" and not station.data.pump: return false
	if id == "capacitor" and not station.data.generator: return false
	for key in RECIPES[id]:
		var pool: Dictionary = data if data.has(key) else station.data
		if int(pool[key]) < RECIPES[id][key]: return false
	return true

func craft(id: String) -> bool:
	if not can_craft(id): return false
	for key in RECIPES[id]:
		var pool: Dictionary = data if data.has(key) else station.data
		pool[key] -= RECIPES[id][key]
	if id == "alloy": data.alloy = mini(9999,int(data.alloy)+1)
	elif id == "cell": station.add_stock("energy", 3)
	else: data[id] = true
	station.save()
	return true

func price(id: String) -> String:
	var pieces := PackedStringArray()
	for key in RECIPES[id]:
		pieces.append("%s ×%d" % [LABELS[key],RECIPES[id][key]])
	return " · ".join(pieces)

func next_objective() -> Array:
	var ship: Dictionary = station.data
	if ship.launched: return [-1, "Свободный полёт"]
	if not ship.air_ready: return [0, "Закрыть заслонку"]
	if not ship.pump: return [1, "Вернуть воду"]
	if not ship.garden:
		if ship.water < 1: return [1, "Набрать воду для биосада"]
		return [2, "Добыть детали"] if ship.parts < 3 else [3, "Запустить биосад"]
	if ship.harvests == 0 or (not ship.generator and ship.food < 2):
		return _food_objective()
	if not ship.generator:
		if ship.parts < 6 or ship.fuses == 0: return [2, "Подготовить детали и предохранитель"]
		return [4, "Собрать реактор"]
	if not ship.beacon:
		if ship.parts < 5 or ship.coils == 0: return [2, "Подготовить детали и катушку"]
		if ship.energy < 2: return [4, "Набрать заряд"]
		return [5, "Подключить антенну"]
	if not ship.signal:
		if "repair-3" not in available_repairs: return [4, "Синхронизировать реактор"]
		return [5, "Настроить антенну"]
	if ship.parts < 8: return [2, "Дособрать детали для взлёта"]
	if ship.food < 4: return _food_objective()
	if ship.energy < 3: return [4, "Запасти заряд для взлёта"]
	return [0, "Подготовить взлёт"]

func _food_objective() -> Array:
	for elapsed in station.data.beds:
		if elapsed >= 0.0: return [3, "Дождаться урожая" if station.ripe_bed() < 0 else "Собрать урожай"]
	if station.data.water < 1: return [1, "Набрать воду для посева"]
	if station.data.energy < 1: return [4 if station.data.generator else 2, "Набрать заряд для посева"]
	return [3, "Посадить семена"]

func record(summary, mistakes: int, releases: int, is_relay: bool) -> void:
	data.repairs = mini(9999,int(data.repairs)+1)
	data.last = {"seconds":summary.active_ms / 1000.0,"mistakes":mistakes,"releases":releases,
		"both_ms":summary.unwanted_both_ms}
	if is_relay:
		var reward := 1 if data.relay else 3
		station.add_stock("energy", reward)
		data.relay = true
		if data.best_relay < 0 or mistakes < data.best_relay: data.best_relay = mistakes
	station.save()
