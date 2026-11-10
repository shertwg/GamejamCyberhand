extends Control
## These puzzles consume validated commands only. REST can confirm a deliberate
## release but cannot turn, steer or charge any mechanism.
signal completed
signal event_emitted(event: GameEvent)
signal hint_changed(hint: String)
signal sound_requested(cue: String)

const Art = preload("res://game/ui/visual_assets.gd")
const TITLES := {"tutorial": "Аварийная заслонка", "repair-1": "Водяной клапан",
	"repair-2": "Захват фазы", "repair-3": "Настройка сигнала"}
var level_id := ""
var active_seconds := 0.0
var done := false
var salvage := false
var storm_trial := false
var drill := false
var surge_limit := 4.4
var mistakes := 0
var releases := 0
var _stage := 0
var _value := 0.0
var _neutral := 0.0
var _releasing := false
var _last_direction: StringName = &""
var _step := 0
var _center := 0.68
var _width := 0.15
var _session := ""
var _attempt := 0
var _event_number := 0
var _hint := ""
var _feedback := 0.0
var _surge_clock := 0.0
var _unit := 1.0
var _origin := Vector2.ZERO

func setup(id: String, difficulty: int, session: String, attempt: int) -> void:
	level_id = id
	_session = session
	_attempt = attempt
	_step = difficulty
	_value = 0.22 if id == "repair-3" and not storm_trial else 0.0
	_width = (0.096 if storm_trial else 0.133) - difficulty * 0.022
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)
	_event(GameEvent.ACTION_STARTED)
	_update_hint()

func advance(delta: float, command: ControlCommand) -> void:
	if done or delta <= 0: return
	var rest := command.state == &"REST"
	var active := command.state == &"ACTIVE" and not command.pause_required
	if not rest and not active:
		_neutral = 0.0
		_last_direction = &""
		return
	if active:
		active_seconds += delta
		if _last_direction != command.direction: sound_requested.emit("servo")
	elif _last_direction in [&"OPEN",&"CLOSE"]:
		releases += 1
	_feedback = maxf(0.0, _feedback - delta)
	if storm_trial or level_id == "repair-2":
		_phase_lock(delta, command, rest)
	elif level_id == "repair-3":
		_tune(delta, command, rest)
	else:
		_stroke(delta, command, rest)
	_last_direction = command.direction
	_update_hint()
	queue_redraw()

func _stroke(delta: float, command: ControlCommand, rest: bool) -> void:
	var expected := _stroke_direction()
	if _releasing:
		_neutral = _neutral + delta if rest else 0.0
		var release_time := 0.20 if level_id == "tutorial" and not salvage else 0.26
		if _neutral >= release_time:
			_releasing = false
			_neutral = 0.0
			_value = 0.0
			_stage += 1
			if _stage >= _stroke_count():
				_finish()
		return
	if not rest and command.direction == expected:
		var duration := 0.65 if level_id == "tutorial" else 1.29 + _step * 0.2
		if salvage: duration = 0.80
		if drill: duration = 0.92 + 0.18 * _stage + _step * 0.10
		_value = minf(1.0, _value + delta * command.intensity / duration)
		if _value >= 1.0: _releasing = true

func _stroke_direction() -> StringName:
	return &"CLOSE" if (_stage + (1 if drill else 0)) % 2 == 0 else &"OPEN"

func _stroke_count() -> int:
	return 4 if drill else (2 if level_id == "tutorial" else 3)

func _phase_lock(delta: float, command: ControlCommand, rest: bool) -> void:
	if rest: return
	if storm_trial:
		_surge_clock += delta
		if _surge_clock >= surge_limit:
			_surge_clock = 0
			_value = 0
			_center = fposmod(_center + 0.29,0.72)+0.15
			_missed()
			return
	if command.direction == &"OPEN":
		_value = fposmod(_value + delta * ((0.58 if storm_trial else 0.40) + _step * 0.04) * command.intensity, 1.0)
	elif command.direction == &"CLOSE" and _last_direction != &"CLOSE":
		if absf(_value - _center) <= _width * 0.5:
			_stage += 1
			_surge_clock = 0
			if _stage >= (3 if storm_trial else 2):
				_finish()
			else:
				sound_requested.emit("click")
				_center = 0.40 if _stage == 1 else 0.79
				_value = 0.0
				if storm_trial: _width = maxf(0.054,_width - 0.012)
		else:
			_missed()

func _missed() -> void:
	mistakes += 1
	_feedback = 0.8
	sound_requested.emit("warning")

func _tune(delta: float, command: ControlCommand, rest: bool) -> void:
	if rest:
		if absf(_value - _center) <= _width * 0.5:
			_neutral += delta
			if _neutral >= 0.72: _finish()
		else:
			_neutral = 0.0
		return
	_neutral = 0.0
	var direction := 1.0 if command.direction == &"OPEN" else -1.0
	_value = clampf(_value + direction * delta * 0.33 * command.intensity, 0.0, 1.0)

func _update_hint() -> void:
	if done: return
	var next: String
	if storm_trial:
		next = "Импульс сбил фазу. Повтори окно." if _feedback > 0 else "A вращает · B фиксирует   |   %d/3" % _stage
	elif level_id in ["tutorial","repair-1"]:
		next = "Отпусти протез" if _releasing else ("Сожми и удерживай · B" if _stroke_direction() == &"CLOSE" else "Раскрой и удерживай · A")
		if drill: next += "   |   %d/4" % _stage
	elif level_id == "repair-2":
		next = "Мимо. Попробуй ещё раз" if _feedback > 0 else "A вращает · B фиксирует в светлой зоне"
	else:
		next = "Отпусти и удерживай покой" if absf(_value - _center) <= _width * 0.5 else "Совмести сигнал · A вправо, B влево"
	if next != _hint:
		_hint = next
		hint_changed.emit(_hint)

func _event(kind: StringName) -> void:
	_event_number += 1
	event_emitted.emit(GameEvent.new("%s-puzzle-%d" % [_session, _event_number], kind,
		_session, _attempt, level_id, int(active_seconds * 1000.0)))

func _finish() -> void:
	if done: return
	done = true
	_event(GameEvent.ACTION_SUCCEEDED)
	_event(GameEvent.LEVEL_COMPLETED)
	completed.emit()

func _draw() -> void:
	_unit = minf(size.x / 288.0, size.y / 146.0)
	if _unit <= 0: return
	_origin = (size - Vector2(288,146) * _unit) * 0.5
	draw_set_transform(_origin, 0, Vector2.ONE * _unit)
	Art.prop(self, "plate", Rect2(0, 0, 288, 146), Color("bcb2b7"))
	var accent := Color("9cf6c9") if _feedback <= 0 else Color("ff9078")
	if level_id == "repair-2" or storm_trial:
		_dial(accent)
	elif level_id == "repair-3":
		_wave(accent)
	elif drill:
		_draw_drill(accent)
	elif salvage:
		_gripper(accent)
	else:
		_valve(accent)

func _dial(accent: Color) -> void:
	var center := Vector2(144, 70)
	Art.prop(self, "dial", Rect2(center - Vector2(53,53), Vector2(106,106)))
	draw_arc(center, 38, TAU * (_center - _width * 0.5) - PI / 2,
		TAU * (_center + _width * 0.5) - PI / 2, 18, Color(accent, 0.85), 5)
	_spin("needle", center, Vector2(17,50), TAU * _value, Vector2(0.50,0.80))
	_steps(3 if storm_trial else 2, accent)
	if storm_trial:
		draw_rect(Rect2(106,13,76,3),Color("222b3d"))
		draw_rect(Rect2(106,13,76*clampf(_surge_clock/surge_limit,0,1),3),Color("f5ad76"))

func _wave(accent: Color) -> void:
	Art.prop(self, "scope", Rect2(45, 8, 198, 130))
	var glass := Rect2(76, 31, 136, 54)
	var band := Rect2(glass.position.x + glass.size.x * (_center - _width * 0.5),
		glass.position.y, glass.size.x * _width, glass.size.y)
	draw_rect(band, Color(accent,0.24))
	draw_rect(band, Color(accent,0.58), false, 1)
	var line := PackedVector2Array()
	for i in range(91):
		var fraction := float(i) / 90
		var wave := sin((fraction - _value) * 44) * maxf(0, 1.0 - absf(fraction - _value) * 3.4)
		line.append(Vector2(glass.position.x + fraction * glass.size.x,
			glass.get_center().y + roundf(wave * 21)))
	draw_polyline(line, Color("b6f5f0"), 2)
	draw_rect(Rect2(105,104,77,4),Color("182229"))
	draw_rect(Rect2(105,104,77 * clampf(_neutral/0.72,0,1),4),accent)

func _valve(accent: Color) -> void:
	var center := Vector2(144, 68)
	var angle := float(_stage % 2) * 1.6 + _value * (1.6 if _stage % 2 == 0 else -1.6)
	_spin("gear", Vector2(98, 80), Vector2(54, 54), -angle * 1.4)
	_spin("valve", center, Vector2(106, 106), angle)
	if _value > 0:
		draw_arc(center, 55, -PI/2, -PI/2 + TAU * _value, 50, Color(accent, 0.88), 3)
	_steps(_stroke_count(), accent)

func _gripper(accent: Color) -> void:
	var amount := _value if _stage == 0 else 1.0 - _value
	var grip := 7.0 * (1.0 - amount)
	var lift := 9.0 * amount
	var y := 17.0 - lift
	# Animate the two jaw regions beneath a single stationary actuator.
	Art.prop(self, "claw_left", Rect2(98 - grip, y + 40, 45, 59))
	Art.prop(self, "claw_right", Rect2(143 + grip, y + 40, 46, 59))
	Art.prop(self, "claw_head", Rect2(121, y, 46, 50))
	Art.prop(self, "gear", Rect2(129, 88 - lift, 31, 31))
	_steps(2, accent)

func _draw_drill(accent: Color) -> void:
	draw_texture_rect_region(Art.LOOT,Rect2(141,54,90,62),Art.MATERIALS.ore)
	draw_texture_rect_region(Art.LOOT,Rect2(164,49,49,47),Art.MATERIALS.silica,Color(0.86,1,1,0.86))
	draw_texture_rect_region(Art.LOOT,Rect2(55+_value*19,40,93,71),Art.MATERIALS.scrap)
	_spin("gear",Vector2(131+_value*19,72),Vector2(51,51),_stage*1.4+_value*5.0)
	if _value > 0.15:
		Art.prop(self,"spark",Rect2(147+_value*7,59,23,25),Color(1,0.82,0.68,_value))
	_steps(4,accent)

func _spin(id: String, center: Vector2, dimensions: Vector2, angle: float, pivot := Vector2(0.5,0.5)) -> void:
	draw_set_transform(_origin + center * _unit, angle, Vector2.ONE * _unit)
	Art.prop(self, id, Rect2(-dimensions * pivot, dimensions))
	draw_set_transform(_origin, 0, Vector2.ONE * _unit)

func _steps(total: int, accent: Color) -> void:
	for i in range(total):
		draw_rect(Rect2(144-total*13+i*26,128,21,4),accent if i < _stage else Color("26394b"))
