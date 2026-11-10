extends RefCounted
## Short effort bursts + positional hold. Receives validated core commands only.

var position: float = 0.50
var target: float = 0.27
var practice: bool = true
var half_width: float = 0.17
var hold_target: float = 0.45
var pulse_limit: float = 0.85
var hold_seconds: float = 0.0
var pulse_seconds: float = 0.0
var elapsed: float = 0.0
var failures: int = 0
var pulses: int = 0
var state: String = "position"
var neutral_seen: bool = true
var feedback: String = ""

func begin(at: float, goal: float, is_practice: bool) -> void:
	position = at
	target = goal
	practice = is_practice
	half_width = 0.17 if practice else 0.13
	hold_target = 0.45 if practice else 0.65
	pulse_limit = 0.85 if practice else 0.65
	hold_seconds = 0.0
	pulse_seconds = 0.0
	elapsed = 0.0
	failures = 0
	pulses = 0
	state = "position"
	neutral_seen = true
	feedback = "Первый зажим: широкая зона, короткие усилия A/B." if practice else "Точный зажим: короткие усилия, затем удержание в зоне."

func observe_neutral(command) -> void:
	if command != null and command.state == &"REST" and command.direction == &"REST":
		neutral_seen = true
		if state in ["release", "retry"]:
			feedback = "Нейтраль принята. Повтори короткими усилиями A/B."

func needs_neutral() -> bool:
	return state in ["release", "retry"] and not neutral_seen

func advance(delta: float, command) -> void:
	observe_neutral(command)
	if command == null or delta <= 0.0 or state == "done":
		return
	if command.pause_required or command.state != &"ACTIVE" or command.intensity <= 0.0:
		return
	if command.direction not in [&"OPEN", &"CLOSE"] or needs_neutral():
		return
	if neutral_seen:
		pulse_seconds = 0.0
		pulses += 1
		neutral_seen = false
		if state in ["release", "retry"]:
			state = "position"
			feedback = "Повтори короткими усилиями. Готовые детали сохранены."
	var steps := maxi(1, ceili(delta / 0.016))
	for i in range(steps):
		if state != "position":
			break
		_step(delta / float(steps), command)

func _step(dt: float, command) -> void:
	elapsed += dt
	pulse_seconds += dt
	if pulse_seconds > pulse_limit:
		if practice:
			state = "release"
			feedback = "Достаточно усилия. Отпусти каналы; удержание сохранено."
		else:
			_fail("Слишком длинное усилие. Отпусти каналы и повтори зажим.")
		return
	var was_holding := hold_seconds > 0.0
	var direction := -1.0 if command.direction == &"OPEN" else 1.0
	var effort: float = minf(command.intensity, 0.55 if practice else 0.65)
	position = clampf(position + direction * effort * dt * 0.34, 0.06, 0.94)
	if absf(position - target) <= half_width:
		hold_seconds += dt
		feedback = "Захват в зоне. Сохраняй положение короткими усилиями."
	elif practice:
		hold_seconds = 0.0
		feedback = "Подведи захват в широкую зону. Ошибки первого зажима не штрафуются."
	elif was_holding:
		_fail("Захват вышел из зоны. Отпусти каналы и попробуй эту деталь снова.")
	if hold_seconds >= hold_target:
		state = "done"
		feedback = "Деталь зажата."

func _fail(message: String) -> void:
	state = "retry"
	hold_seconds = 0.0
	neutral_seen = false
	failures += 1
	feedback = message

func progress() -> float:
	return clampf(hold_seconds / hold_target, 0.0, 1.0)
