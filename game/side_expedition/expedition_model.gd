extends RefCounted
## No input polling, nodes, campaign state, stock, or filesystem writes.
## The host supplies only validated ControlCommand instances and simulation time.

signal stage_changed(stage_id: String)
signal journal_added(entry: Dictionary)
signal expedition_completed(result: Dictionary)
signal location_entered(location_id: String, entry_line: String)

const Command = preload("res://game/core/control_command.gd")
const ClampTrial = preload("res://game/side_expedition/clamp_trial.gd")
const PowerTrial = preload("res://game/side_expedition/power_trial.gd")
const Storm = preload("res://game/side_expedition/storm.gd")
const STAGES := ["outbound", "salvage", "choice", "to_scout", "scout_salvage", "adapter", "power", "return", "homebound", "complete"]
const LOCATION_ORDER := ["airlock", "debris", "scout"]
const LOCATIONS := {
	"airlock": {"title": "Шлюз Керны", "x": 0.07},
	"debris": {"title": "Поле обломков", "x": 0.40},
	"scout": {"title": "Остов разведчика", "x": 0.91},
}
const INTERACTIONS := {
	"salvage": {"id": "debris_parts", "location_id": "debris", "label": "Собрать детали"},
	"scout_salvage": {"id": "scout_coupler", "location_id": "scout", "label": "Снять керамический переходник"},
	"adapter": {"id": "scout_workbench", "location_id": "scout", "label": "Собрать переходник"},
	"power": {"id": "scout_power", "location_id": "scout", "label": "Забрать аварийную батарею"},
}
const HALF := Vector2(0.014, 0.045)
const WALLS: Array[Rect2] = [
	Rect2(0.25, 0.0, 0.045, 0.51),
	Rect2(0.49, 0.47, 0.045, 0.53),
	Rect2(0.73, 0.0, 0.045, 0.57),
]
const PARTS := ["контактная гребёнка", "силовой контакт", "гибкий проводник"]
const PART_TARGETS := [0.27, 0.70, 0.43]
const ADAPTER_SEQUENCE := [Command.OPEN, Command.CLOSE, Command.OPEN]
const SAFE_WALLS: Array[Rect2] = [Rect2(0.49, 0.0, 0.045, 0.60), Rect2(0.73, 0.0, 0.045, 0.60)]
const SHELTERS: Array[Vector2] = [Vector2(0.07, 0.50), Vector2(0.40, 0.35), Vector2(0.61, 0.32), Vector2(0.91, 0.50)]

var stage: String = "briefing"
var run_id: String = ""
var player := Vector2(0.07, 0.50)
var cursor: float = 0.50
var active_seconds: float = 0.0
var stage_seconds: float = 0.0
var hold_seconds: float = 0.0
var collected_parts: Array[String] = []
var adapter_step: int = 0
var awaiting_neutral: bool = false
var adapter_built: bool = false
var battery_secured: bool = false
var blocked: bool = false
var wind: float = 0.0
var wall_contacts: int = 0
var journal: Array[Dictionary] = []
var location_id: String = "airlock"
var destination_id: String = "debris"
var entry_line: String = "У разведчика может уцелеть батарея. Она нужна Керне."
var location_history: Array[String] = []
var clamp = ClampTrial.new()
var power = PowerTrial.new()
var clamp_failures: int = 0
var power_failures: int = 0
var clamp_active_seconds: float = 0.0
var inventory: Dictionary = {}
var first_delivery_done: bool = false
var route_choice: String = "safe"
var rare_requested: bool = false
var optional_note_found: bool = false
var rare_collected: bool = false
var last_shelter := Vector2(0.07, 0.50)
var weather = Storm.new()
var knockbacks: int = 0
var _gust_hit: int = -1
var _cache_hold: float = 0.0
var _choice_direction: StringName = &"REST"
var _completion_sent: bool = false
var _suppress_events: bool = false

func begin(p_run_id: String, context: Dictionary = {}) -> void:
	run_id = p_run_id
	player = Vector2(0.07, 0.50)
	cursor = 0.50
	active_seconds = 0.0
	stage_seconds = 0.0
	hold_seconds = 0.0
	collected_parts.clear()
	adapter_step = 0
	awaiting_neutral = false
	adapter_built = false
	battery_secured = false
	blocked = false
	wind = 0.0
	wall_contacts = 0
	journal.clear()
	location_history.clear()
	clamp.begin(0.50, PART_TARGETS[0], true)
	power.begin()
	clamp_failures = 0
	power_failures = 0
	clamp_active_seconds = 0.0
	inventory = {"conductive_scrap": 0, "ceramic_coupler": 0, "rare_coil": 0}
	first_delivery_done = bool(context.get("first_delivery_done", false))
	route_choice = "safe"
	rare_requested = false
	optional_note_found = false
	rare_collected = false
	last_shelter = SHELTERS[0]
	weather.reset()
	knockbacks = 0
	_gust_hit = -1
	_cache_hold = 0.0
	_choice_direction = &"REST"
	_completion_sent = false
	_arrive("outbound", "airlock", "У разведчика может уцелеть батарея. Сначала найдём детали в обломках.", "debris")
	_add_journal("weak_signal", "Зачем идти", "Керне нужна аварийная батарея. За шлюзом повторяется старый позывной. Путь к разведчику проходит через поле обломков — там найдутся детали для переходника.")

func advance(delta: float, command) -> void:
	if command == null or delta <= 0.0 or stage in ["briefing", "complete"]:
		return
	observe_command(command)
	if awaiting_neutral:
		return
	if command.pause_required or command.state != &"ACTIVE" or command.intensity <= 0.0:
		return
	if command.direction not in [Command.OPEN, Command.CLOSE]:
		return
	if stage in ["salvage", "scout_salvage"] and clamp.needs_neutral():
		return
	if stage == "power" and power.phase in ["cue", "retry"] and not power.armed:
		return
	# Bounded substeps also keep task completion stable on a slower host.
	var steps := maxi(1, ceili(delta / 0.016))
	var dt := delta / float(steps)
	var initial_stage := stage
	var initial_knockbacks := knockbacks
	for i in range(steps):
		if stage != initial_stage or awaiting_neutral or knockbacks != initial_knockbacks:
			break
		if stage in ["salvage", "scout_salvage"] and clamp.needs_neutral():
			break
		if stage == "power" and power.phase == "retry" and not power.armed:
			break
		active_seconds += dt
		stage_seconds += dt
		match stage:
			"outbound", "to_scout", "return", "homebound":
				_advance_route(dt, command)
			"salvage", "scout_salvage":
				_advance_salvage(dt, command)
			"choice":
				_advance_choice(dt, command)
			"adapter":
				_advance_adapter(dt, command)
			"power":
				_advance_power(dt, command)

func observe_command(command) -> void:
	# Called at delivery as well as by deterministic simulation. A short
	# neutral frame must not disappear between two rendered frames.
	if command == null or command.state != &"REST" or command.direction != &"REST" or stage in ["briefing", "complete"]:
		return
	if stage in ["salvage", "scout_salvage"]:
		clamp.observe_neutral(command)
	elif stage == "power":
		var previous_failures: int = power.failures
		power.observe_neutral(command)
		power_failures += power.failures - previous_failures
		if power.phase == "done":
			_finish_power()
	awaiting_neutral = false
	_choice_direction = &"REST"

func _advance_route(dt: float, command) -> void:
	var direction := -1.0 if command.direction == Command.OPEN else 1.0
	var returning := stage in ["return", "homebound"]
	var weather_active := stage in ["to_scout", "return", "homebound"]
	if weather_active:
		weather.advance(dt * command.intensity)
		var shelter := current_shelter()
		if shelter >= 0:
			last_shelter = SHELTERS[shelter]
			if command.direction == Command.OPEN and (weather.phase != "calm" or (shelter == 2 and not optional_note_found) or (shelter == 2 and rare_requested and not rare_collected)):
				if shelter == 2:
					_cache_hold += dt
					if _cache_hold >= 0.45 and not optional_note_found:
						optional_note_found = true
						_add_journal("broken_launch", "Запись под навесом", "«Стартовый кабель разорвало бурей. Батареи хватило лишь на маяк. Мы остались ждать корабль, который ещё не знал о нас». Теперь ясно, почему разведчик не улетел.")
					if _cache_hold >= 0.70 and rare_requested and not rare_collected:
						rare_collected = true
						inventory.rare_coil += 1
						_add_journal("rare_coil", "Риск оправдался", "Под навесом уцелела редкая катушка. До шлюза её ещё нужно донести.")
				return
		if weather.phase == "gust" and route_choice == "exposed" and shelter < 0 and _gust_hit != weather.cycle:
			_gust_hit = weather.cycle
			knockbacks += 1
			player = last_shelter
			blocked = false
			entry_line = "Порыв вернул к последнему укрытию. Вся добыча осталась при нас."
			return
	wind = sin(weather.clock * 0.7) * 0.035 * weather.strength if weather_active and route_choice == "exposed" else 0.0
	var target := player
	target.y = clampf(target.y + (direction * 0.36 + wind) * command.intensity * dt, HALF.y, 1.0 - HALF.y)
	if not collides(target):
		player = target
	var speed := -0.075 if returning else 0.105
	if route_choice == "safe" and weather_active: speed = -0.050 if returning else 0.050
	if stage == "outbound": speed = 0.082
	target = player + Vector2(speed * command.intensity * dt, 0.0)
	var previous_blocked := blocked
	blocked = collides(target)
	if blocked and not previous_blocked:
		wall_contacts += 1
	if not blocked:
		player = target
	var destination_x: float = LOCATIONS[destination_id].x
	var reached := player.x <= destination_x if returning else player.x >= destination_x
	if not reached:
		return
	player.x = destination_x
	if stage == "outbound":
		cursor = 0.50
		clamp.begin(cursor, PART_TARGETS[0], true)
		awaiting_neutral = true
		_arrive("salvage", "debris", "В этих обломках есть всё для переходника. Соберём три детали.")
		_add_journal("debris_found", "Поле обломков", "На поле найдены проводящие детали. Второй компонент — керамическую втулку — придётся снять с остова.")
	elif stage == "to_scout":
		cursor = 0.50
		clamp.begin(cursor, 0.65, false)
		awaiting_neutral = true
		_arrive("scout_salvage", "scout", "На остове есть керамическая втулка. Вместе с проводником она станет переходником.")
		_add_journal("scout_found", "Остов «Севера-3»", "Разведчик прибыл раньше нас. В обломках был проводник, а на остове сохранилась керамическая втулка — второй вид деталей для чужого разъёма.")
	elif stage == "return":
		_arrive("homebound", "debris", "Снова поле обломков. Шлюз уже близко — несём батарею домой.", "airlock")
		_add_journal("return_field", "Обратный путь", "С батареей вернулись к знакомому полю обломков. Буря продолжается. Остался последний участок до шлюза Керны.")
	elif stage == "homebound":
		_finish()

func _advance_salvage(dt: float, command) -> void:
	var before_time: float = clamp.elapsed
	var before_failures: int = clamp.failures
	clamp.advance(dt, command)
	clamp_active_seconds += clamp.elapsed - before_time
	clamp_failures += clamp.failures - before_failures
	cursor = clamp.position
	hold_seconds = clamp.hold_seconds
	if clamp.state == "done":
		if stage == "scout_salvage":
			inventory.ceramic_coupler += 1
			awaiting_neutral = true
			entry_line = "Оба вида деталей собраны. Собираем переходник у остова."
			_set_stage("adapter")
			return
		collected_parts.append(PARTS[collected_parts.size()])
		inventory.conductive_scrap += 1
		hold_seconds = 0.0
		awaiting_neutral = true
		if collected_parts.size() == PARTS.size():
			entry_line = "Проводники собраны. Теперь выбери путь к разведчику."
			_set_stage("choice")
			_add_journal("parts_collected", "Развилка", "Длинная тропа проходит под скалой. Короткий путь открыт порывам, зато ведёт к укрытию с тайником. Вернуться с простой добычей можно через меню.")
		else:
			clamp.begin(cursor, PART_TARGETS[collected_parts.size()], false)

func _advance_choice(dt: float, command) -> void:
	if command.direction != _choice_direction:
		hold_seconds = 0.0
		_choice_direction = command.direction
	hold_seconds += dt
	if hold_seconds < 0.22: return
	if first_delivery_done and command.direction == Command.OPEN:
		request_return()
		return
	route_choice = "safe" if command.direction == Command.OPEN else "exposed"
	rare_requested = first_delivery_done and route_choice == "exposed"
	destination_id = "scout"
	entry_line = "Идём под скалой: длиннее, зато безопасно." if route_choice == "safe" else "Открытый участок короче. При сигнале бури беги к навесу или пережди под ним."
	awaiting_neutral = true
	_set_stage("to_scout")

func _advance_adapter(dt: float, command) -> void:
	if awaiting_neutral:
		return
	if command.direction == ADAPTER_SEQUENCE[adapter_step]:
		hold_seconds += dt
	else:
		hold_seconds = 0.0
	if hold_seconds >= 0.45:
		adapter_step += 1
		hold_seconds = 0.0
		if adapter_step == ADAPTER_SEQUENCE.size():
			if inventory.conductive_scrap < 1 or inventory.ceramic_coupler < 1:
				adapter_step = 0
				awaiting_neutral = true
				entry_line = "Для переходника нужен проводник из поля и втулка с остова."
				return
			inventory.conductive_scrap -= 1
			inventory.ceramic_coupler -= 1
			adapter_built = true
			power.begin()
			awaiting_neutral = true
			entry_line = "Переходник готов. Открываем блок питания."
			_set_stage("power")
			_add_journal("adapter_built", "Крафт завершён", "Проводник из поля и керамическая втулка с остова соединены. Только теперь инструмент получает доступ к батарее.")
		else:
			awaiting_neutral = true

func _advance_power(dt: float, command) -> void:
	var before_failures: int = power.failures
	power.advance(dt, command)
	power_failures += power.failures - before_failures

func _finish_power() -> void:
	if not adapter_built: return
	battery_secured = true
	destination_id = "debris"
	entry_line = "Батарея у нас. Возвращаемся через поле обломков, пока идёт буря."
	_set_stage("return")
	if not first_delivery_done:
		_add_journal("old_log", "Экспедиция до нас", "В памяти блока — запись другой посадочной группы: «Мы тоже шли на этот сигнал». Батарея закреплена. По ущелью идёт буря — пора возвращаться в шлюз.")
	else:
		_add_journal("repeat_supply", "Повторный рейс", "Запасная батарея освобождена. Тайник уже не такой богатый; редкая катушка осталась в укрытии открытого участка.")

func current_shelter() -> int:
	for i in range(SHELTERS.size()):
		if absf(player.x - SHELTERS[i].x) <= 0.037 and absf(player.y - SHELTERS[i].y) <= 0.20: return i
	return -1

func active_walls() -> Array[Rect2]:
	return SAFE_WALLS if route_choice == "safe" and stage in ["to_scout", "return"] else WALLS

func request_return() -> bool:
	if stage in ["briefing", "complete", "return", "homebound"]: return false
	awaiting_neutral = true
	if player.x > float(LOCATIONS.debris.x) + 0.001:
		destination_id = "debris"
		_set_stage("return")
	else:
		destination_id = "airlock"
		_set_stage("homebound")
	entry_line = "Возвращаемся с тем, что успели собрать. Новые детали снова найдутся в следующем заходе."
	return true

func collides(point: Vector2) -> bool:
	for wall in active_walls():
		if wall.intersects(Rect2(point - HALF, HALF * 2.0)):
			return true
	return false

func target_value() -> float:
	if stage in ["salvage", "scout_salvage"]:
		return clamp.target
	return 0.67

func task_progress() -> float:
	match stage:
		"salvage", "scout_salvage": return clamp.progress()
		"choice": return clampf(hold_seconds / 0.22, 0.0, 1.0)
		"adapter": return clampf(hold_seconds / 0.45, 0.0, 1.0)
		"power": return power.progress()
	return 0.0

func objective() -> String:
	match stage:
		"outbound": return "Доберись до поля обломков по маркеру впереди."
		"to_scout": return "Доберись до остова. " + ("Под навесом A — переждать и осмотреть тайник." if route_choice == "exposed" else "Длинная тропа защищена от порывов.")
		"choice": return "A — забрать простую добычу и вернуться; B — рискнуть ради редкой катушки." if first_delivery_done else "Выбери путь: A — длинный под скалой; B — короткий открытый."
		"scout_salvage": return "Сними керамическую втулку с остова: второй вид деталей для переходника."
		"salvage": return "Зажим %d/3: %s. Короткие усилия A/B и удержание в зоне." % [mini(collected_parts.size() + 1, 3), PARTS[mini(collected_parts.size(), 2)]]
		"adapter":
			if awaiting_neutral: return "Отпусти оба канала перед следующим соединением."
			var action := "A ↑" if ADAPTER_SEQUENCE[mini(adapter_step, 2)] == Command.OPEN else "B ↓"
			return "Собери переходник · соединение %d/3. Подай %s, затем отпусти." % [mini(adapter_step + 1, 3), action]
		"power": return power.instruction()
		"return": return "Вернись с батареей к полю обломков слева."
		"homebound": return "Донеси батарею от поля обломков до шлюза слева."
		"complete": return "Добыча доставлена. Получи награду, прежде чем начать новую вылазку."
	return "Керне нужна батарея. Пройди через поле обломков к старому разведчику и вернись."

func route_text() -> String:
	if destination_id != "":
		return "%s → %s" % [LOCATIONS[location_id].title, LOCATIONS[destination_id].title]
	return String(LOCATIONS[location_id].title)

func trial_feedback() -> String:
	if stage in ["salvage", "scout_salvage"]: return clamp.feedback
	if stage == "power": return power.feedback
	if stage in ["to_scout", "return", "homebound"]:
		return weather.cue() if route_choice == "exposed" else "Под скалой порыв не отбросит. Открытая тропа короче, но опаснее."
	return ""

func interaction_point() -> Dictionary:
	if not INTERACTIONS.has(stage):
		return {}
	var point: Dictionary = INTERACTIONS[stage].duplicate(true)
	point["ready"] = not awaiting_neutral
	return point

func _arrive(next_stage: String, at_location: String, line: String, next_destination: String = "") -> void:
	location_id = at_location
	destination_id = next_destination
	entry_line = line
	location_history.append(at_location)
	last_shelter = Vector2(float(LOCATIONS[at_location].x), 0.35 if at_location == "debris" else 0.50)
	_set_stage(next_stage)
	if not _suppress_events: location_entered.emit(at_location, line)

func _set_stage(value: String) -> void:
	stage = value
	stage_seconds = 0.0
	hold_seconds = 0.0
	blocked = false
	wind = 0.0
	if not _suppress_events: stage_changed.emit(stage)

func _add_journal(id: String, title: String, body: String) -> void:
	var entry := {"id": id, "title": title, "body": body}
	journal.append(entry)
	if not _suppress_events: journal_added.emit(entry.duplicate(true))

func checkpoint() -> Dictionary:
	return {
		"version": 1, "run_id": run_id, "stage": stage,
		"location_id": location_id, "destination_id": destination_id,
		"location_history": location_history.duplicate(), "journal": journal.duplicate(true),
		"inventory": inventory.duplicate(), "parts": collected_parts.size(),
		"adapter_step": adapter_step, "adapter_built": adapter_built,
		"battery_secured": battery_secured, "first_delivery_done": first_delivery_done,
		"route_choice": route_choice, "rare_requested": rare_requested,
		"optional_note_found": optional_note_found, "rare_collected": rare_collected,
		"last_shelter": [last_shelter.x, last_shelter.y], "cursor": cursor,
		"weather_clock": weather.clock, "gust_hit": _gust_hit, "knockbacks": knockbacks,
		"active_seconds": active_seconds, "stage_seconds": stage_seconds,
		"clamp_failures": clamp_failures, "power_failures": power_failures,
		"clamp_active_seconds": clamp_active_seconds, "power_elapsed": power.elapsed,
		"power_window": mini(power.window_index, 2), "entry_line": entry_line,
	}

func restore(data: Dictionary, context: Dictionary = {}) -> bool:
	if data.get("version") != 1 or data.get("stage", "") not in STAGES or not data.get("run_id") is String or data.run_id == "": return false
	if data.get("location_id", "") not in LOCATION_ORDER or data.get("destination_id", "") not in ["", "airlock", "debris", "scout"]: return false
	if data.get("route_choice", "") not in ["safe", "exposed"]: return false
	if not data.get("inventory") is Dictionary or not data.get("journal") is Array or not data.get("location_history") is Array: return false
	for key in ["conductive_scrap", "ceramic_coupler", "rare_coil"]:
		if not _valid_number(data.inventory.get(key), 0, 1000): return false
	for key in ["active_seconds", "stage_seconds", "weather_clock", "clamp_active_seconds", "power_elapsed"]:
		if not _valid_number(data.get(key), 0, 1000000): return false
	for key in ["adapter_built", "battery_secured", "first_delivery_done", "rare_requested", "optional_note_found", "rare_collected"]:
		if typeof(data.get(key)) != TYPE_BOOL: return false
	for key in ["parts", "adapter_step", "power_window", "clamp_failures", "power_failures", "knockbacks"]:
		if not _valid_number(data.get(key), 0, 10000): return false
	if data.parts > 3 or data.adapter_step > 3 or data.power_window > 2 or not _valid_number(data.get("cursor"), 0.06, 0.94): return false
	if not data.get("last_shelter") is Array or data.last_shelter.size() != 2: return false
	if not _valid_number(data.last_shelter[0], 0.05, 0.95) or not _valid_number(data.last_shelter[1], 0.05, 0.95): return false
	for entry in data.journal:
		if not entry is Dictionary: return false
		for key in ["id", "title", "body"]:
			if not entry.get(key) is String: return false
	for id in data.location_history:
		if id not in LOCATION_ORDER: return false
	if data.stage in ["outbound", "to_scout", "return", "homebound"] and data.destination_id == "": return false
	if data.stage == "power" and not data.adapter_built: return false
	if data.battery_secured and not data.adapter_built: return false
	if data.stage == "adapter" and (data.inventory.conductive_scrap < 1 or data.inventory.ceramic_coupler < 1): return false
	if data.stage == "adapter" and data.adapter_step >= 3: return false
	if data.stage == "salvage" and data.parts >= 3: return false
	var saved_cover := Vector2(float(data.last_shelter[0]), float(data.last_shelter[1]))
	var known_cover := false
	for cover in SHELTERS:
		known_cover = known_cover or cover.is_equal_approx(saved_cover)
	if not known_cover: return false
	_suppress_events = true
	begin(data.run_id, {"first_delivery_done": context.get("first_delivery_done", data.first_delivery_done)})
	stage = data.stage
	location_id = data.location_id
	destination_id = data.destination_id
	location_history.assign(data.location_history)
	journal.assign(data.journal.duplicate(true))
	for key in inventory: inventory[key] = int(data.inventory[key])
	collected_parts.assign(PARTS.slice(0, int(data.parts)))
	adapter_step = int(data.adapter_step)
	adapter_built = data.adapter_built
	battery_secured = data.battery_secured
	route_choice = data.route_choice
	rare_requested = data.rare_requested
	optional_note_found = data.optional_note_found
	rare_collected = data.rare_collected
	last_shelter = Vector2(float(data.last_shelter[0]), float(data.last_shelter[1]))
	player = last_shelter if stage in ["outbound", "to_scout", "return", "homebound"] else Vector2(float(LOCATIONS[location_id].x), 0.35 if location_id == "debris" else 0.50)
	cursor = float(data.cursor)
	weather.advance(float(data.weather_clock))
	_gust_hit = weather.cycle if weather.phase == "gust" else -1
	knockbacks = int(data.knockbacks)
	active_seconds = float(data.active_seconds)
	stage_seconds = float(data.stage_seconds)
	clamp_failures = int(data.clamp_failures)
	power_failures = int(data.power_failures)
	clamp_active_seconds = float(data.clamp_active_seconds)
	power.elapsed = float(data.power_elapsed)
	power.window_index = int(data.power_window)
	power.cue_serial = power.window_index + 1
	clamp.begin(cursor, 0.65 if stage == "scout_salvage" else PART_TARGETS[mini(collected_parts.size(), 2)], stage == "salvage" and collected_parts.is_empty())
	entry_line = "Продолжаем от последнего укрытия. Добыча и готовые шаги сохранены."
	awaiting_neutral = true
	_completion_sent = stage == "complete"
	_suppress_events = false
	stage_changed.emit(stage)
	location_entered.emit(location_id, entry_line)
	return true

static func _valid_number(value: Variant, minimum: float, maximum: float) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

func result() -> Dictionary:
	# A proposal for the campaign host, never a direct inventory operation.
	var rewards: Array = rewards_for(inventory, adapter_built, battery_secured, not first_delivery_done)
	return {
		"schema_version": 1, "expedition_id": "quiet_signal", "run_id": run_id,
		"completed": stage == "complete", "battery_secured": battery_secured,
		"crafted_items": ["scout_adapter"] if adapter_built else [],
		"reward_id": "quiet_signal/" + run_id,
		"reward_proposal": rewards if stage == "complete" else [],
		"inventory": inventory.duplicate(), "first_clear": battery_secured and not first_delivery_done,
		"quest_completed": battery_secured, "optional_note_found": optional_note_found,
		"discoveries": (["prior_expedition"] if battery_secured else []) + (["scout_failed_launch"] if optional_note_found else []),
		"journal": journal.duplicate(true),
		"visited_locations": location_history.duplicate(),
		"stats": {"active_seconds": active_seconds, "wall_contacts": wall_contacts, "clamp_failures": clamp_failures, "power_failures": power_failures, "clamp_active_seconds": clamp_active_seconds, "power_active_seconds": power.elapsed, "knockbacks": knockbacks, "route": route_choice},
	}

static func rewards_for(items: Dictionary, crafted: bool, battery: bool, first_clear: bool) -> Array:
	var rewards: Array = []
	for id in ["conductive_scrap", "ceramic_coupler", "rare_coil"]:
		var amount: int = int(items.get(id, 0))
		if id == "conductive_scrap" and battery: amount += 6 if first_clear else 1
		if amount > 0: rewards.append({"item_id": id, "amount": amount})
	if battery: rewards.append({"item_id": "emergency_battery", "amount": 1})
	elif crafted: rewards.append({"item_id": "scout_adapter", "amount": 1})
	return rewards

func _finish() -> void:
	if _completion_sent:
		return
	_arrive("complete", "airlock", "Добыча дома. Запроси награду — и можно идти снова.")
	_add_journal("home", "Возвращение в Керну", "Батарея доставлена вместе с записью разведчика." if battery_secured else "Вернулись с простой добычей. За батареей и редкой деталью можно вернуться позже.")
	_completion_sent = true
	expedition_completed.emit(result())
