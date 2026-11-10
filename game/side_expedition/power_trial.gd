extends RefCounted
## Event-cued OPEN -> REST -> CLOSE windows. REST acknowledges neutral but
## never runs a timer. Fault/blocked commands cannot acknowledge neutral.

const SEQUENCE := [&"OPEN", &"CLOSE", &"OPEN"]
var window_index: int = 0
var phase: String = "cue"
var armed: bool = false
var action_seconds: float = 0.0
var release_seconds: float = 0.0
var elapsed: float = 0.0
var failures: int = 0
var feedback: String = ""
var cue_serial: int = 0
var recovery_rest: bool = false

func begin() -> void:
	window_index = 0
	phase = "cue"
	armed = false
	action_seconds = 0.0
	release_seconds = 0.0
	elapsed = 0.0
	failures = 0
	cue_serial = 1
	recovery_rest = false
	feedback = "Обучающее окно: сначала нейтраль, затем открытие A."

func practice() -> bool:
	return window_index == 0

func action_target() -> float:
	return 0.16 if practice() else 0.25

func release_grace() -> float:
	return 1.80 if practice() else 0.90

func expected_direction() -> StringName:
	return SEQUENCE[mini(window_index, SEQUENCE.size() - 1)]

func needs_neutral() -> bool:
	return phase == "neutral" or (phase in ["retry", "cue"] and not armed)

func observe_neutral(command) -> void:
	if command == null or command.state != &"REST" or command.direction != &"REST" or phase == "done":
		return
	if phase == "act":
		if command.reason in [&"resumed_neutral", &"both_neutral_recovery"]:
			recovery_rest = true
			return
		if recovery_rest:
			return
		_fail("Сигнал слишком короткий. Окно сохранено — попробуй ещё раз.")
		armed = true
	elif phase == "neutral":
		window_index += 1
		if window_index >= SEQUENCE.size():
			phase = "done"
			feedback = "Все контакты пройдены. Батарея освобождена."
		else:
			phase = "cue"
			armed = true
			cue_serial += 1
			feedback = "Новый сигнал: " + ("открытие A ↑." if expected_direction() == &"OPEN" else "закрытие B ↓.")
	else:
		if phase == "retry" and not armed:
			feedback = "Нейтраль принята. Повтори " + ("открытие A ↑." if expected_direction() == &"OPEN" else "закрытие B ↓.")
		armed = true

func advance(delta: float, command) -> void:
	observe_neutral(command)
	if command == null or delta <= 0.0 or phase == "done":
		return
	if command.pause_required or command.state != &"ACTIVE" or command.intensity <= 0.0:
		return
	if command.direction not in [&"OPEN", &"CLOSE"]:
		return
	recovery_rest = false
	if phase in ["cue", "retry"]:
		if not armed:
			return
		# A cue is displayed before activation. No countdown runs in REST.
		phase = "act"
		armed = false
		action_seconds = 0.0
		release_seconds = 0.0
	var steps := maxi(1, ceili(delta / 0.016))
	for i in range(steps):
		if phase in ["retry", "done"]:
			break
		_step(delta / float(steps), command)

func _step(dt: float, command) -> void:
	elapsed += dt
	if command.direction != expected_direction():
		_fail("Нужна нейтраль перед сменой направления." if phase == "neutral" else "Не тот канал. Отпусти оба и повтори это окно.")
		return
	if phase == "act":
		action_seconds += dt
		feedback = "Контакт принят. Дождись сигнала «Нейтраль»."
		if action_seconds >= action_target():
			phase = "neutral"
			feedback = "НЕЙТРАЛЬ: отпусти оба канала."
	elif phase == "neutral":
		release_seconds += dt
		if release_seconds > release_grace():
			_fail("Канал удержан слишком долго. Отпусти оба и повтори это окно.")

func _fail(message: String) -> void:
	phase = "retry"
	armed = false
	failures += 1
	feedback = message

func progress() -> float:
	if phase == "done":
		return 1.0
	var current := clampf(action_seconds / action_target(), 0.0, 1.0) if phase in ["act", "neutral"] else 0.0
	return (window_index + current) / float(SEQUENCE.size())

func instruction() -> String:
	if phase == "retry":
		if armed:
			return "Блок питания · окно %d/3: повтори %s." % [window_index + 1, "ОТКРЫТИЕ A ↑" if expected_direction() == &"OPEN" else "ЗАКРЫТИЕ B ↓"]
		return "Блок питания · окно %d/3: отпусти каналы и попробуй снова." % (window_index + 1)
	if phase == "neutral":
		return "Блок питания · окно %d/3: НЕЙТРАЛЬ — отпусти оба канала." % (window_index + 1)
	var cue := "ОТКРЫТЬ A ↑" if expected_direction() == &"OPEN" else "ЗАКРЫТЬ B ↓"
	return "Блок питания · окно %d/3: %s%s" % [mini(window_index + 1, 3), cue, " · обучение" if practice() else ""]
