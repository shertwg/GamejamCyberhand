extends Control
## Code-native art; visual effects use model time and therefore stop with REST.

const Model = preload("res://game/side_expedition/expedition_model.gd")
const INK := Color("08111d")
const CYAN := Color("8af0d4")
const GOLD := Color("ffd166")
const DIM := Color("7594a5")
var model
var _font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	custom_minimum_size = Vector2(0, 170)
	resized.connect(queue_redraw)

func _draw() -> void:
	if model == null:
		return
	_font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	for x in range(12, int(size.x), 24):
		for y in range(12, int(size.y), 24):
			draw_rect(Rect2(x, y, 2, 2), Color("142b3b"))
	match model.stage:
		"salvage", "scout_salvage": _draw_salvage()
		"choice": _draw_choice()
		"adapter": _draw_adapter()
		"power": _draw_power()
		_: _draw_canyon()
	draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2), Color("2d5866"), false, 2)
	# Same restrained cyan instruments and hard pixel edges as the ship overview.
	for corner in [Vector2(2, 2), Vector2(size.x - 2, 2), Vector2(2, size.y - 2), size - Vector2(2, 2)]:
		var inward := Vector2(1 if corner.x < size.x * 0.5 else -1, 1 if corner.y < size.y * 0.5 else -1)
		draw_line(corner, corner + Vector2(inward.x * 15, 0), CYAN, 2)
		draw_line(corner, corner + Vector2(0, inward.y * 10), CYAN, 2)

func _field() -> Rect2:
	return Rect2(Vector2(24, 32), Vector2(maxf(1, size.x - 48), maxf(1, size.y - 54)))

func _point(v: Vector2) -> Vector2:
	var field := _field()
	return field.position + field.size * v

func _box(rect: Rect2, fill: Color, border: Color) -> void:
	draw_rect(rect, Color("030911"))
	draw_rect(Rect2(rect.position + Vector2(3, 3), rect.size), Color(0, 0, 0, 0.4))
	draw_rect(rect, fill)
	draw_rect(rect, border, false, 2)

func _text(p: Vector2, value: String, color: Color = DIM, font_size: int = 13, width: float = -1) -> void:
	draw_string(_font, p, value, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)

func _draw_canyon() -> void:
	var f := _field()
	for band in range(8):
		draw_rect(Rect2(f.position.x, f.position.y + f.size.y * band / 8, f.size.x, f.size.y / 8 + 1), Color("102330").lerp(Color("182f3b"), float(band) / 8))
	# Rock ledges and sediment lines keep this an exterior canyon, rather
	# than another corridor of the main ship. They never affect collisions.
	var top: PackedVector2Array = [f.position, Vector2(f.end.x, f.position.y)]
	var bottom: PackedVector2Array = [Vector2(f.position.x, f.end.y), f.end]
	for i in range(12, -1, -1):
		var x := f.position.x + f.size.x * i / 12.0
		top.append(Vector2(x, f.position.y + 7 + (i * 13 % 21)))
		bottom.append(Vector2(x, f.end.y - 7 - (i * 17 % 19)))
	draw_colored_polygon(top, Color("453d43"))
	draw_colored_polygon(bottom, Color("684b43"))
	for i in range(7):
		var p := _point(Vector2(0.10 + i * 0.13, 0.30 + fmod(i * 0.23, 0.52)))
		draw_polyline(PackedVector2Array([p, p + Vector2(11, 4), p + Vector2(18, 1), p + Vector2(30, 7)]), Color("38524e"), 2)
	for i in range(36):
		var p := _point(Vector2(fmod(i * 0.183, 1.0), fmod(i * 0.317, 1.0)))
		draw_rect(Rect2(p, Vector2(6, 3)), Color("28434a"))
	if model.stage in ["choice", "to_scout", "return"]:
		draw_polyline(PackedVector2Array([_point(Vector2(0.40, 0.35)), _point(Vector2(0.45, 0.80)), _point(Vector2(0.88, 0.80)), _point(Vector2(0.91, 0.50))]), Color(0.54, 0.94, 0.83, 0.30), 3)
		draw_polyline(PackedVector2Array([_point(Vector2(0.40, 0.35)), _point(Vector2(0.61, 0.32)), _point(Vector2(0.91, 0.50))]), Color(1.0, 0.82, 0.40, 0.30), 2)
	for wall in model.active_walls():
		var r := Rect2(_point(wall.position), wall.size * f.size)
		_box(r, Color("453d43"), Color("806557"))
		for y in range(int(r.position.y + 8), int(r.end.y - 4), 14):
			draw_line(Vector2(r.position.x + 4, y), Vector2(r.end.x - 4, y + 4), Color("526054"), 3)
		var edge := r.end.y if wall.position.y == 0.0 else r.position.y
		draw_line(Vector2(r.position.x, edge), Vector2(r.end.x, edge), GOLD, 3)
	_draw_ship(_point(Vector2(0.025, 0.50)))
	_draw_wreck(_point(Vector2(0.94, 0.5)))
	var cover := _point(Vector2(0.61, 0.32))
	var cover_width := f.size.x * 0.085
	draw_rect(Rect2(cover - Vector2(cover_width * 0.5, f.size.y * 0.20), Vector2(cover_width, f.size.y * 0.40)), Color(0.30, 0.75, 0.75, 0.12))
	draw_line(cover + Vector2(-cover_width * 0.6, -f.size.y * 0.20), cover + Vector2(cover_width * 0.6, -f.size.y * 0.20 - 4), CYAN, 4)
	for side in [-1, 1]:
		var post := cover + Vector2(side * cover_width * 0.53, -f.size.y * 0.19)
		draw_line(post, post + Vector2(0, f.size.y * 0.35), Color("506a74"), 4)
		draw_rect(Rect2(post + Vector2(-2, 5), Vector2(4, 12)), CYAN)
	_text(cover + Vector2(-27, -f.size.y * 0.20 - 8), "УКРЫТИЕ", CYAN, 10)
	# The cable and warning lamp are driven by the same paused weather clock.
	var anchor := _point(Vector2(0.93, 0.12))
	var sway: float = sin(model.weather.clock * 2.0) * model.weather.strength * 14.0
	draw_polyline(PackedVector2Array([anchor, anchor + Vector2(sway * 0.3, 14), anchor + Vector2(sway, 35)]), Color("a2a991"), 3)
	var warning_alpha := 0.88 + sin(model.weather.clock * 6.0) * 0.08 if model.weather.phase == "warning" else 1.0
	draw_rect(Rect2(anchor + Vector2(sway - 4, 35), Vector2(8, 7)), Color(GOLD, warning_alpha))
	_text(Vector2(24, 22), "КЕРНА / ВНЕШНИЙ КОНТУР", CYAN, 12)
	var radio := clampf((model.player.x - 0.07) / 0.84, 0.0, 1.0)
	if model.stage in ["briefing", "outbound", "to_scout"]:
		_text(Vector2(maxf(24, size.x - 208), 22), "СИГНАЛ  %02d%%" % int(radio * 100), GOLD, 12)
		for ring in range(3):
			var radius := 16.0 + ring * 13.0 + fmod(model.stage_seconds * 9, 13)
			draw_arc(_point(Vector2(0.94, 0.5)), radius, PI * 0.68, PI * 1.32, 18, Color(0.54, 0.94, 0.83, 0.25), 1)
	if model.stage in ["to_scout", "return", "homebound"]:
		var weather_label := "ПОРЫВ" if model.weather.phase == "gust" else ("ПОРЫВ СКОРО" if model.weather.phase == "warning" else "ТИХИЙ ВЕТЕР")
		_text(Vector2(maxf(24, size.x - 208), 22), weather_label, GOLD, 12)
		for i in range(12 + int(model.weather.strength * 60)):
			var p := Vector2(fmod(i * 79.0 + model.weather.clock * (70 + model.weather.strength * 100), maxf(1, size.x)), fmod(i * 43.0, maxf(1, size.y)))
			draw_line(p, p + Vector2(15, 3 + model.wind * 140), Color(0.85, 0.69, 0.42, 0.28), 2)
	_draw_ranger(_point(model.player), model.battery_secured)
	for id in Model.LOCATION_ORDER:
		var x: float = Model.LOCATIONS[id].x
		var p := _point(Vector2(x, 0.96))
		var col := GOLD if id == model.destination_id else CYAN
		draw_line(p + Vector2(0, -11), p + Vector2(0, -3), col, 2)
		draw_rect(Rect2(p + Vector2(-3, -16), Vector2(6, 6)), col)
		var label := "ШЛЮЗ" if id == "airlock" else ("ПОЛЕ ОБЛОМКОВ" if id == "debris" else "ОСТОВ")
		_text(Vector2(clampf(p.x - 24, 24, size.x - 115), size.y - 24), label, col, 10, 112)
	_text(Vector2(22, size.y - 8), "Маяк: " + model.entry_line, DIM, 11, size.x - 44)
	if model.stage == "briefing":
		_text(Vector2(size.x * 0.18, size.y * 0.47), "ЗА ПОЗЫВНЫМ — В УЩЕЛЬЕ", Color("e6f4f0"), 18, size.x * 0.72)
		_text(Vector2(size.x * 0.18, size.y * 0.47 + 23), "Разведчик. Обломки. Чужая история.", DIM, 13, size.x * 0.72)
	elif model.stage == "complete":
		_box(Rect2(Vector2(size.x * 0.21, size.y * 0.31), Vector2(size.x * 0.62, 76)), Color("112e34"), CYAN)
		_text(Vector2(size.x * 0.24, size.y * 0.31 + 29), "БАТАРЕЯ ДОСТАВЛЕНА" if model.battery_secured else "ДОБЫЧА ДОСТАВЛЕНА", CYAN, 19, size.x * 0.55)
		_text(Vector2(size.x * 0.24, size.y * 0.31 + 54), "Этот сигнал уже слышали до нас." if model.battery_secured else "Можно вернуться за батареей и редкой катушкой.", GOLD, 13, size.x * 0.55)

func _draw_ship(center: Vector2) -> void:
	# A fragment of Kerna's pressure hull, using the campaign cutaway palette.
	draw_colored_polygon(PackedVector2Array([center + Vector2(-53, -52), center + Vector2(6, -52), center + Vector2(29, -30), center + Vector2(29, 30), center + Vector2(6, 52), center + Vector2(-53, 52)]), Color("152632"))
	draw_polyline(PackedVector2Array([center + Vector2(-43, -48), center + Vector2(3, -48), center + Vector2(24, -27)]), Color("8b9f9f"), 5)
	_box(Rect2(center - Vector2(16, 38), Vector2(32, 76)), Color("355360"), Color("6b7e82"))
	_box(Rect2(center - Vector2(9, 25), Vector2(18, 50)), Color("0b1925"), CYAN)
	draw_line(center + Vector2(0, -23), center + Vector2(0, 23), Color("355360"), 2)
	for side in [-1, 1]:
		draw_rect(Rect2(center + Vector2(side * 23 - 2, -16), Vector2(4, 32)), Color("39616b"))
		draw_rect(Rect2(center + Vector2(side * 23 - 2, -13), Vector2(4, 9)), CYAN)
	for y in [-30, 30]:
		draw_rect(Rect2(center + Vector2(-18, y), Vector2(36, 4)), GOLD)

func _draw_wreck(center: Vector2) -> void:
	var light_on: bool = model.battery_secured or model.first_delivery_done
	if light_on: draw_circle(center, 39, Color(0.54, 0.94, 0.83, 0.10))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-36, 13), center + Vector2(-23, -20), center + Vector2(8, -24), center + Vector2(33, -5), center + Vector2(41, 19), center + Vector2(-27, 25)]), Color("152632"))
	draw_polyline(PackedVector2Array([center + Vector2(-33, 10), center + Vector2(-20, -16), center + Vector2(7, -20), center + Vector2(30, -3)]), Color("8b9f9f"), 4)
	_box(Rect2(center + Vector2(-20, -10), Vector2(23, 23)), Color("24454a") if light_on else Color("1c2e39"), CYAN if light_on else Color("50626a"))
	draw_colored_polygon(PackedVector2Array([center + Vector2(9, -12), center + Vector2(25, -2), center + Vector2(29, 6), center + Vector2(9, 3)]), Color("39616b"))
	draw_line(center + Vector2(11, -8), center + Vector2(23, 0), CYAN if light_on else DIM, 2)
	draw_line(center + Vector2(-28, 8), center + Vector2(-35, -27), Color("9da8a1"), 3)
	draw_rect(Rect2(center + Vector2(-38, -31), Vector2(10, 5)), GOLD)
	for i in range(3):
		draw_rect(Rect2(center + Vector2(-17 + i * 7, -6), Vector2(3, 12)), CYAN if light_on else Color("9d644e"))
	draw_line(center + Vector2(-18, 25), center + Vector2(-23, 30), DIM, 3)
	draw_line(center + Vector2(23, 22), center + Vector2(27, 30), DIM, 3)

func _draw_ranger(center: Vector2, carrying: bool) -> void:
	draw_rect(Rect2(center + Vector2(-11, 17), Vector2(26, 4)), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(center + Vector2(-10, -3), Vector2(5, 17)), Color("152632"))
	draw_rect(Rect2(center + Vector2(-7, -4), Vector2(15, 22)), Color("355360"))
	draw_rect(Rect2(center + Vector2(-6, -2), Vector2(13, 5)), Color("8b9f9f"))
	draw_rect(Rect2(center + Vector2(-8, -17), Vector2(17, 15)), Color("8b9f9f"))
	draw_rect(Rect2(center + Vector2(-5 if model.stage in ["return", "homebound"] else 0, -13), Vector2(9, 7)), Color("16313d"))
	draw_rect(Rect2(center + Vector2(-3 if model.stage in ["return", "homebound"] else 1, -12), Vector2(6, 2)), CYAN)
	draw_rect(Rect2(center + Vector2(-2, 6), Vector2(5, 3)), CYAN)
	draw_rect(Rect2(center + Vector2(-6, 18), Vector2(5, 6)), Color("7594a5"))
	draw_rect(Rect2(center + Vector2(3, 18), Vector2(5, 6)), Color("7594a5"))
	draw_rect(Rect2(center + Vector2(8, 0), Vector2(7, 8)), Color("8b9f9f"))
	draw_rect(Rect2(center + Vector2(12, 2), Vector2(9, 3)), CYAN)
	if carrying:
		_box(Rect2(center + Vector2(11, 4), Vector2(18, 18)), Color("4b442b"), GOLD)
		draw_rect(Rect2(center + Vector2(15, 8), Vector2(10, 3)), CYAN)

func _draw_salvage() -> void:
	var at_scout: bool = model.stage == "scout_salvage"
	_text(Vector2(22, 24), "ОСТОВ / КЕРАМИЧЕСКАЯ ВТУЛКА" if at_scout else "ЗАЖИМ / " + ("ОБУЧАЮЩАЯ ПОПЫТКА" if model.clamp.practice else "ТОЧНЫЕ ИМПУЛЬСЫ"), GOLD, 13)
	var f := _field()
	_box(Rect2(_point(Vector2(0.15, 0.04)), f.size * Vector2(0.58, 0.91)), Color("1e303b"), Color("4d6569"))
	for i in range(1 if at_scout else 3):
		var p := _point(Vector2(0.45 if at_scout else 0.34 + i * 0.10, 0.65 if at_scout else Model.PART_TARGETS[i]))
		var done: bool = not at_scout and i < model.collected_parts.size()
		var col := CYAN if done else (GOLD if at_scout or i == model.collected_parts.size() else DIM)
		_box(Rect2(p - Vector2(15, 10), Vector2(30, 20)), Color("28444b"), col)
		draw_line(p - Vector2(11, 0), p + Vector2(11, 0), col, 3)
		_text(p + Vector2(-10, 27), "ВТУЛКА" if at_scout else ("✓" if done else "0%d" % (i + 1)), col, 12)
	var target: float = model.target_value()
	var width: float = model.clamp.half_width
	var zone := Rect2(_point(Vector2(0.19, target - width)), f.size * Vector2(0.58, width * 2.0))
	draw_rect(zone, Color(0.54, 0.94, 0.83, 0.10))
	draw_rect(zone, CYAN, false, 2)
	_draw_tool(_point(Vector2(0.73, model.cursor)))
	var pulse := Rect2(_point(Vector2(0.83, 0.08)), Vector2(8, f.size.y * 0.72))
	draw_rect(pulse, Color("233b49"))
	draw_rect(Rect2(pulse.position, Vector2(8, pulse.size.y * clampf(model.clamp.pulse_seconds / model.clamp.pulse_limit, 0, 1))), GOLD)
	_text(Vector2(22, size.y - 10), model.clamp.feedback, Color("ef9f84") if model.clamp.state == "retry" else DIM, 11, size.x - 44)

func _draw_adapter() -> void:
	_text(Vector2(22, 24), "КРАФТ / ПРОВОДНИК + ВТУЛКА → ПЕРЕХОДНИК", CYAN, 13)
	var f := _field()
	_box(Rect2(_point(Vector2(0.15, 0.12)), f.size * Vector2(0.70, 0.72)), Color("17333a"), Color("427e77"))
	for i in range(3):
		var center := _point(Vector2(0.30 + i * 0.20, 0.44))
		var done: bool = i < model.adapter_step
		var current: bool = i == model.adapter_step
		var col := CYAN if done else (GOLD if current else DIM)
		if i > 0:
			draw_line(center - Vector2(f.size.x * 0.20 - 20, 0), center - Vector2(21, 0), CYAN if done else Color("365663"), 4)
		_box(Rect2(center - Vector2(21, 23), Vector2(42, 46)), Color("0b1c29"), col)
		for pin in range(3):
			draw_rect(Rect2(center + Vector2(-13 + pin * 11, -33), Vector2(5, 10)), col)
			draw_rect(Rect2(center + Vector2(-13 + pin * 11, 23), Vector2(5, 10)), col)
		_text(center + Vector2(-6, 6), "✓" if done else ("A" if i != 1 else "B"), col, 18)
	var caption := "НЕЙТРАЛЬ → СЛЕДУЮЩИЙ КОНТАКТ" if model.awaiting_neutral else "ОБОЙМА   →   КОНТАКТ   →   ТЕСТ"
	_text(_point(Vector2(0.20, 0.76)), caption, GOLD, 12, size.x * 0.65)
	_text(Vector2(22, size.y - 10), "Маяк: " + model.entry_line, DIM, 11, size.x - 44)

func _draw_choice() -> void:
	_draw_canyon()
	for i in range(2):
		var r := Rect2(Vector2(size.x * (0.05 if i == 0 else 0.53), size.y * 0.20), Vector2(size.x * 0.42, size.y * 0.57))
		_box(r, Color("102630"), CYAN if i == 0 else GOLD)
		var title := "A · ДЛИННЫЙ ПУТЬ" if i == 0 else "B · КОРОТКИЙ ПУТЬ"
		var body := "Под скалой, без отбрасывания" if i == 0 else "Открытый участок, укрытия"
		if model.first_delivery_done:
			title = "A · ПРОСТАЯ ДОБЫЧА" if i == 0 else "B · РЕДКАЯ КАТУШКА"
			body = "Вернуться к шлюзу сейчас" if i == 0 else "Рискнуть на открытом пути"
		_text(r.position + Vector2(12, 24), title, CYAN if i == 0 else GOLD, 13, r.size.x - 24)
		_text(r.position + Vector2(12, 44), body, DIM, 11, r.size.x - 24)

func _draw_power() -> void:
	_text(Vector2(22, 24), "БЛОК ПИТАНИЯ / ОКНА КОНТАКТОВ", GOLD, 13)
	var f := _field()
	_box(Rect2(_point(Vector2(0.14, 0.07)), f.size * Vector2(0.72, 0.84)), Color("172e37"), Color("537d7b"))
	for i in range(3):
		var center := _point(Vector2(0.29 + i * 0.21, 0.40))
		var done: bool = i < model.power.window_index
		var current: bool = i == model.power.window_index
		var col := CYAN if done else (GOLD if current else DIM)
		if current and model.power.phase == "retry": col = Color("ef9f84")
		if current and model.power.phase == "neutral": col = CYAN
		_box(Rect2(center - Vector2(24, 23), Vector2(48, 46)), Color("0b1c29"), col)
		_text(center + Vector2(-5, 6), "✓" if done else ("A" if i != 1 else "B"), col, 18)
		_text(center + Vector2(-21, 40), "ОКНО %d" % (i + 1), col, 10)
	var cue := "ОТКРЫТЬ A ↑" if model.power.expected_direction() == &"OPEN" else "ЗАКРЫТЬ B ↓"
	if model.power.phase == "neutral": cue = "НЕЙТРАЛЬ  ·  ОТПУСТИ ОБА"
	elif model.power.phase == "retry": cue = "ПОВТОРИ " + cue if model.power.armed else "ПОВТОР ОКНА  ·  СНАЧАЛА НЕЙТРАЛЬ"
	_text(_point(Vector2(0.20, 0.78)), cue, GOLD, 14, size.x * 0.70)
	_text(Vector2(22, size.y - 10), model.power.feedback, Color("ef9f84") if model.power.phase == "retry" else DIM, 11, size.x - 44)

func _draw_tool(p: Vector2) -> void:
	draw_line(_point(Vector2(0.90, 0.05)), Vector2(p.x + 28, p.y), Color("567680"), 5)
	draw_line(_point(Vector2(0.90, 0.05)), Vector2(p.x + 28, p.y), Color("8b9f9f"), 2)
	draw_circle(p + Vector2(25, 0), 8, Color("152632"))
	draw_arc(p + Vector2(25, 0), 6, 0, TAU, 12, CYAN, 2)
	draw_line(p + Vector2(25, 0), p, CYAN, 5)
	draw_line(p, p + Vector2(-10, -12), CYAN, 4)
	draw_line(p, p + Vector2(-10, 12), CYAN, 4)
