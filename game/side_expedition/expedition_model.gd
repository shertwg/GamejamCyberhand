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
const STAGES := ["outbound", "salvage", "adapter", "to_scout", "power", "return", "homebound", "complete"]
const LOCATION_ORDER := ["airlock", "debris", "scout"]
const LOCATIONS := {
	"airlock": {"title": "Шлюз Керны", "x": 0.07},
	"debris": {"title": "Поле обломков", "x": 0.40},
	"scout": {"title": "Остов разведчика", "x": 0.91},
}
const INTERACTIONS := {
	"salvage": {"id": "debris_parts", "location_id": "debris", "label": "Собрать детали"},
	"adapter": {"id": "field_workbench", "location_id": "debris", "label": "Собрать переходник"},
	"power": {"id": "scout_power", "location_id": "scout", "label": "Забрать аварийную батарею"},
}
const HALF := Vector2(0.014, 0.045)
const WALLS: Array[Rect2] = [
	Rect2(0.25, 0.0, 0.045, 0.51),
	Rect2(0.49, 0.47, 0.045, 0.53),
	Rect2(0.73, 0.0, 0.045, 0.57),
]
const PARTS := ["контактная гребёнка", "керамическая обойма", "гибкий проводник"]
const PART_TARGETS := [0.27, 0.70, 0.43]
const ADAPTER_SEQUENCE := [Command.OPEN, Command.CLOSE, Command.OPEN]

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
var _completion_sent: bool = false

func begin(p_run_id: String) -> void:
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
	if stage == "salvage" and clamp.needs_neutral():
		return
	if stage == "power" and power.phase in ["cue", "retry"] and not power.armed:
		return
	# Bounded substeps also keep task completion stable on a slower host.
	var steps := maxi(1, ceili(delta / 0.016))
	var dt := delta / float(steps)
	var initial_stage := stage
	for i in range(steps):
		if stage != initial_stage or awaiting_neutral:
			break
		if stage == "salvage" and clamp.needs_neutral():
			break
		if stage == "power" and power.phase == "retry" and not power.armed:
			break
		active_seconds += dt
		stage_seconds += dt
		match stage:
			"outbound", "to_scout", "return", "homebound":
				_advance_route(dt, command)
			"salvage":
				_advance_salvage(dt, command)
			"adapter":
				_advance_adapter(dt, command)
			"power":
				_advance_power(dt, command)

func observe_command(command) -> void:
	# Called at delivery as well as by deterministic simulation. A short
	# neutral frame must not disappear between two rendered frames.
	if command == null or command.state != &"REST" or command.direction != &"REST" or stage in ["briefing", "complete"]:
		return
	if stage == "salvage":
		clamp.observe_neutral(command)
	elif stage == "power":
		var previous_failures: int = power.failures
		power.observe_neutral(command)
		power_failures += power.failures - previous_failures
		if power.phase == "done":
			_finish_power()
	awaiting_neutral = false

func _advance_route(dt: float, command) -> void:
	var direction := -1.0 if command.direction == Command.OPEN else 1.0
	var returning := stage in ["return", "homebound"]
	wind = sin(stage_seconds * 0.70) * 0.035 if returning else 0.0
	var target := player
	target.y = clampf(target.y + (direction * 0.36 + wind) * command.intensity * dt, HALF.y, 1.0 - HALF.y)
	if not collides(target):
		player = target
	var speed := -0.062 if returning else 0.082
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
		_add_journal("debris_found", "Поле обломков", "Перед остовом лежат части старого разведчика. Найдены контактная гребёнка, обойма и проводник. Из них получится переходник к чужому разъёму.")
	elif stage == "to_scout":
		power.begin()
		awaiting_neutral = true
		_arrive("power", "scout", "Этот разведчик прибыл раньше нас. Проверим его блок питания.")
		_add_journal("scout_found", "Остов «Севера-3»", "Под пылью виден номер старого разведчика. Его маяк работал до нашего прибытия. Переходник подходит к блоку питания: за крышкой сохранилась батарея.")
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
		collected_parts.append(PARTS[collected_parts.size()])
		hold_seconds = 0.0
		awaiting_neutral = true
		if collected_parts.size() == PARTS.size():
			entry_line = "Детали собраны. Соединим их в переходник."
			_set_stage("adapter")
			_add_journal("parts_collected", "Чужой разъём", "Три детали уцелели. Разъём блока питания не подходит к нашему инструменту — соберём переходник прямо на обломках.")
		else:
			clamp.begin(cursor, PART_TARGETS[collected_parts.size()], false)

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
			adapter_built = true
			destination_id = "scout"
			entry_line = "Переходник готов. Теперь доберёмся до остова разведчика."
			_set_stage("to_scout")
			_add_journal("adapter_built", "Путь к остову открыт", "Переходник собран на поле обломков. Теперь можно пройти оставшийся участок до остова и открыть его блок питания.")
		else:
			awaiting_neutral = true

func _advance_power(dt: float, command) -> void:
	var before_failures: int = power.failures
	power.advance(dt, command)
	power_failures += power.failures - before_failures

func _finish_power() -> void:
	battery_secured = true
	destination_id = "debris"
	entry_line = "Батарея у нас. Возвращаемся через поле обломков, пока идёт буря."
	_set_stage("return")
	_add_journal("old_log", "Экспедиция до нас", "В памяти блока — запись другой посадочной группы: «Мы тоже шли на этот сигнал». Батарея закреплена. По ущелью идёт буря — пора возвращаться в шлюз.")

func collides(point: Vector2) -> bool:
	for wall in WALLS:
		if wall.intersects(Rect2(point - HALF, HALF * 2.0)):
			return true
	return false

func target_value() -> float:
	if stage == "salvage":
		return clamp.target
	return 0.67

func task_progress() -> float:
	match stage:
		"salvage": return clamp.progress()
		"adapter": return clampf(hold_seconds / 0.45, 0.0, 1.0)
		"power": return power.progress()
	return 0.0

func objective() -> String:
	match stage:
		"outbound": return "Доберись до поля обломков по маркеру впереди."
		"to_scout": return "Доберись до остова разведчика с готовым переходником."
		"salvage": return "Зажим %d/3: %s. Короткие усилия A/B и удержание в зоне." % [mini(collected_parts.size() + 1, 3), PARTS[mini(collected_parts.size(), 2)]]
		"adapter":
			if awaiting_neutral: return "Отпусти оба канала перед следующим соединением."
			var action := "A ↑" if ADAPTER_SEQUENCE[mini(adapter_step, 2)] == Command.OPEN else "B ↓"
			return "Собери переходник · соединение %d/3. Подай %s, затем отпусти." % [mini(adapter_step + 1, 3), action]
		"power": return power.instruction()
		"return": return "Вернись с батареей к полю обломков слева."
		"homebound": return "Донеси батарею от поля обломков до шлюза слева."
		"complete": return "Батарея доставлена. Маяк сохранил запись прежней экспедиции."
	return "Керне нужна батарея. Пройди через поле обломков к старому разведчику и вернись."

func route_text() -> String:
	if destination_id != "":
		return "%s → %s" % [LOCATIONS[location_id].title, LOCATIONS[destination_id].title]
	return String(LOCATIONS[location_id].title)

func trial_feedback() -> String:
	if stage == "salvage": return clamp.feedback
	if stage == "power": return power.feedback
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
	_set_stage(next_stage)
	location_entered.emit(at_location, line)

func _set_stage(value: String) -> void:
	stage = value
	stage_seconds = 0.0
	hold_seconds = 0.0
	blocked = false
	wind = 0.0
	stage_changed.emit(stage)

func _add_journal(id: String, title: String, body: String) -> void:
	var entry := {"id": id, "title": title, "body": body}
	journal.append(entry)
	journal_added.emit(entry.duplicate(true))

func result() -> Dictionary:
	# A proposal for the campaign host, never a direct inventory operation.
	return {
		"schema_version": 1, "expedition_id": "quiet_signal", "run_id": run_id,
		"completed": stage == "complete", "battery_secured": battery_secured,
		"crafted_items": ["scout_adapter"] if adapter_built else [],
		"reward_proposal": [{"item_id": "emergency_battery", "amount": 1}] if stage == "complete" else [],
		"discoveries": ["prior_expedition"] if stage == "complete" else [],
		"journal": journal.duplicate(true),
		"visited_locations": location_history.duplicate(),
		"stats": {"active_seconds": active_seconds, "wall_contacts": wall_contacts, "clamp_failures": clamp_failures, "power_failures": power_failures, "clamp_active_seconds": clamp_active_seconds, "power_active_seconds": power.elapsed},
	}

func _finish() -> void:
	if _completion_sent:
		return
	_arrive("complete", "airlock", "Батарея дома. Теперь разберёмся, кто был здесь до нас.")
	_add_journal("home", "Возвращение в Керну", "Аварийная батарея в шлюзе. Теперь у нас есть питание и чужой журнал. Кто-то уже пытался выбраться отсюда — и оставил след.")
	_completion_sent = true
	expedition_completed.emit(result())
