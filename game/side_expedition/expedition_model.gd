extends RefCounted
## No input polling, nodes, campaign state, stock, or filesystem writes.
## The host supplies only validated ControlCommand instances and simulation time.

signal stage_changed(stage_id: String)
signal journal_added(entry: Dictionary)
signal expedition_completed(result: Dictionary)

const Command = preload("res://game/core/control_command.gd")
const STAGES := ["outbound", "salvage", "adapter", "power", "return", "complete"]
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
	_completion_sent = false
	_set_stage("outbound")
	_add_journal("weak_signal", "Слабый сигнал", "За внешним шлюзом Керны повторяется короткий позывной. Маяк отмечает источник в ущелье: разведчик, которого нет на нашей карте.")

func advance(delta: float, command) -> void:
	if command == null or delta <= 0.0 or stage in ["briefing", "complete"]:
		return
	# Neutral is observed as input state, without advancing the world or clocks.
	if awaiting_neutral and command.state == &"REST":
		awaiting_neutral = false
	if command.pause_required or command.state != &"ACTIVE" or command.intensity <= 0.0:
		return
	if command.direction not in [Command.OPEN, Command.CLOSE]:
		return
	# Bounded substeps also keep task completion stable on a slower host.
	var steps := maxi(1, ceili(delta / 0.016))
	var dt := delta / float(steps)
	var initial_stage := stage
	for i in range(steps):
		if stage != initial_stage:
			break
		active_seconds += dt
		stage_seconds += dt
		match stage:
			"outbound", "return":
				_advance_route(dt, command)
			"salvage":
				_advance_salvage(dt, command)
			"adapter":
				_advance_adapter(dt, command)
			"power":
				_advance_power(dt, command)

func _advance_route(dt: float, command) -> void:
	var direction := -1.0 if command.direction == Command.OPEN else 1.0
	var returning := stage == "return"
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
	if not returning and player.x >= 0.91:
		_set_stage("salvage")
		cursor = 0.50
		_add_journal("scout_found", "Обломки «Севера-3»", "Под пылью виден бортовой номер старого разведчика. Его посадочный маяк работал ещё до нашего прибытия. Керна здесь не первая.")
	elif returning and player.x <= 0.07:
		_finish()

func _advance_salvage(dt: float, command) -> void:
	_move_cursor(dt, command, 0.34)
	var target := float(PART_TARGETS[collected_parts.size()])
	if absf(cursor - target) <= 0.105:
		hold_seconds += dt
	else:
		hold_seconds = 0.0
	if hold_seconds >= 0.55:
		collected_parts.append(PARTS[collected_parts.size()])
		hold_seconds = 0.0
		if collected_parts.size() == PARTS.size():
			_set_stage("adapter")
			_add_journal("parts_collected", "Чужой разъём", "Три детали уцелели. Разъём блока питания не подходит к нашему инструменту — соберём переходник прямо на обломках.")

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
			cursor = 0.20
			_set_stage("power")
			_add_journal("adapter_built", "Переходник готов", "Обойма держит контакт. За крышкой блока питания сохранилась аварийная батарея. Сначала разгрузим замок: сдвинем и стабилизируем каретку.")
		else:
			awaiting_neutral = true

func _advance_power(dt: float, command) -> void:
	_move_cursor(dt, command, 0.25)
	if absf(cursor - 0.67) <= 0.115:
		hold_seconds += dt
	else:
		hold_seconds = 0.0
	if hold_seconds >= 1.10:
		battery_secured = true
		player = Vector2(0.91, 0.50)
		_set_stage("return")
		_add_journal("old_log", "Экспедиция до нас", "В памяти блока — запись другой посадочной группы: «Мы тоже шли на этот сигнал». Батарея закреплена. По ущелью идёт буря — пора возвращаться в шлюз.")

func _move_cursor(dt: float, command, speed: float) -> void:
	var direction := -1.0 if command.direction == Command.OPEN else 1.0
	cursor = clampf(cursor + direction * command.intensity * dt * speed, 0.06, 0.94)

func collides(point: Vector2) -> bool:
	for wall in WALLS:
		if wall.intersects(Rect2(point - HALF, HALF * 2.0)):
			return true
	return false

func target_value() -> float:
	if stage == "salvage":
		return float(PART_TARGETS[mini(collected_parts.size(), PART_TARGETS.size() - 1)])
	return 0.67

func task_progress() -> float:
	match stage:
		"salvage": return clampf(hold_seconds / 0.55, 0.0, 1.0)
		"adapter": return clampf(hold_seconds / 0.45, 0.0, 1.0)
		"power": return clampf(hold_seconds / 1.10, 0.0, 1.0)
	return 0.0

func objective() -> String:
	match stage:
		"outbound": return "Найди разведчик · A — вверх, B — вниз. Движение вперёд — при активном канале."
		"salvage": return "Собери деталь %d/3: %s. Держи захват в подсвеченной зоне." % [mini(collected_parts.size() + 1, 3), PARTS[mini(collected_parts.size(), 2)]]
		"adapter":
			if awaiting_neutral: return "Отпусти оба канала перед следующим соединением."
			var action := "A ↑" if ADAPTER_SEQUENCE[mini(adapter_step, 2)] == Command.OPEN else "B ↓"
			return "Собери переходник · соединение %d/3. Подай %s, затем отпусти." % [mini(adapter_step + 1, 3), action]
		"power": return "Вскрой блок питания · A/B совмещают каретку с зоной замка. Стабилизируй её."
		"return": return "Доставь батарею в шлюз слева. A/B компенсируют снос. Покой останавливает бурю."
		"complete": return "Батарея доставлена. Маяк сохранил запись прежней экспедиции."
	return "Снаружи Керны слышен старый позывной. Найди источник и вернись с тем, что уцелело."

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
		"stats": {"active_seconds": active_seconds, "wall_contacts": wall_contacts},
	}

func _finish() -> void:
	if _completion_sent:
		return
	_set_stage("complete")
	_add_journal("home", "Возвращение в Керну", "Аварийная батарея в шлюзе. Теперь у нас есть питание и чужой журнал. Кто-то уже пытался выбраться отсюда — и оставил след.")
	_completion_sent = true
	expedition_completed.emit(result())
