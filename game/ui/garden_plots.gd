extends RefCounted

const State = preload("res://game/station/station_state.gd")
const CENTERS := [Vector2(91, 137), Vector2(192, 137), Vector2(293, 137)]
const SIZE := Vector2(44, 30)
const BRONZE := Color("ad7f55")
const MINT := Color("8fe4b9")
const AMBER := Color("f9cc83")
const BERRY := Color("e88dbb")
var reward_index := -1
var reward_time := -1.0
var reward_yield := 0

static func index_at(point: Vector2) -> int:
	for i in range(CENTERS.size()):
		if Rect2(CENTERS[i] - SIZE * 0.5, SIZE).grow(5.0).has_point(point): return i
	return -1

func draw(canvas: CanvasItem, station: State, age: float) -> void:
	for i in range(CENTERS.size()):
		var p: Vector2 = CENTERS[i]
		var elapsed := float(station.data.beds[i])
		var progress := elapsed / station.grow_seconds(i)
		var ripe := progress >= 1.0
		var berries: bool = station.data.crops[i] == "berries"
		var accent := AMBER if ripe else (BERRY if berries else MINT)
		# Riveted hydroponic trays use the same dark metal and copper as the ship.
		canvas.draw_rect(Rect2(p + Vector2(-21, 28), Vector2(43, 4)), Color("1d1527"))
		for x in [-18, 14]:
			canvas.draw_rect(Rect2(p + Vector2(x, 11), Vector2(5, 20)), Color("2b2434"))
			canvas.draw_rect(Rect2(p + Vector2(x + 3, 13), Vector2(2, 17)), Color("645066"))
			canvas.draw_rect(Rect2(p + Vector2(x - 1, 28), Vector2(8, 3)), BRONZE.darkened(0.42))
		canvas.draw_rect(Rect2(p + Vector2(-22, -9), Vector2(44, 22)), Color("171426"))
		canvas.draw_rect(Rect2(p + Vector2(-22, -9), Vector2(44, 2)), BRONZE)
		canvas.draw_rect(Rect2(p + Vector2(-20, -7), Vector2(40, 10)), Color("383047"))
		canvas.draw_rect(Rect2(p + Vector2(-18, -6), Vector2(36, 6)), Color("261d2c"))
		canvas.draw_rect(Rect2(p + Vector2(-20, 1), Vector2(40, 3)), Color("50415b"))
		canvas.draw_rect(Rect2(p + Vector2(-18, 10), Vector2(36, 1)), Color("362938"))
		for x in [-20, 18]:
			canvas.draw_rect(Rect2(p + Vector2(x, 6), Vector2(2, 2)), BRONZE)
		if elapsed >= 0.0:
			for plant in range(3):
				_draw_sprout(canvas, p + Vector2(plant * 12 - 12, 1), progress, berries, age + plant * 0.8 + i)
		canvas.draw_rect(Rect2(p + Vector2(-15, 6), Vector2(30, 3)), Color("464257"))
		if ripe:
			canvas.draw_rect(Rect2(p + Vector2(-15, 6), Vector2(30, 3)), accent)

func draw_feedback(canvas: CanvasItem, station: State, age: float, selected_crop: String) -> void:
	for i in range(CENTERS.size()):
		var p: Vector2 = CENTERS[i]
		var elapsed := float(station.data.beds[i])
		var marker := p + Vector2(0, -12)
		if elapsed < 0.0:
			canvas.draw_rect(Rect2(marker - Vector2(5, 5), Vector2(11, 11)), Color("242036"))
			_spark(canvas, marker, BERRY if selected_crop == "berries" else MINT)
		elif elapsed >= station.grow_seconds(i):
			_spark(canvas, p + Vector2(-14, -18 + roundf(sin(age * 2.7 + i) * 2.0)), AMBER)
			_spark(canvas, p + Vector2(15, -15 + roundf(sin(age * 2.7 + i + 1.0) * 2.0)), MINT)
		else:
			var bar := Rect2(marker + Vector2(-13, -9), Vector2(26, 4))
			var fill := maxf(1.0, floorf(elapsed / station.grow_seconds(i) * 24.0))
			canvas.draw_rect(bar, Color("242036"))
			canvas.draw_rect(Rect2(bar.position + Vector2.ONE, Vector2(fill, 2)), BERRY if station.data.crops[i] == "berries" else MINT)
	var t := age - reward_time
	if reward_index < 0 or t < 0.0 or t >= 1.0: return
	var p: Vector2 = CENTERS[reward_index]
	var at := p + Vector2(0, -22 - t * 17)
	canvas.draw_rect(Rect2(at - Vector2(13, 11), Vector2(26, 14)), Color(0.08, 0.06, 0.14, 1.0 - t))
	canvas.draw_string(ThemeDB.fallback_font, at - Vector2(9, 0), "+%d" % reward_yield, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(AMBER, 1.0 - t))
	for j in range(5):
		var offset := Vector2((j - 2) * 5, -8).normalized() * t * 28.0
		_spark(canvas, p + offset, Color(MINT, 1.0 - t))

func _draw_sprout(canvas: CanvasItem, base: Vector2, progress: float, berries: bool, phase: float) -> void:
	var height := 4 if progress < 0.32 else (9 if progress < 0.7 else 13)
	var lean := roundf(sin(phase * 2.0)) if height > 4 else 0.0
	var tip := base + Vector2(lean, -height)
	canvas.draw_rect(Rect2(base + Vector2(0, -height), Vector2(2, height)), Color("557b64"))
	canvas.draw_rect(Rect2(tip + Vector2(-4, 2), Vector2(5, 3)), Color("6ea078"))
	canvas.draw_rect(Rect2(tip + Vector2(1, 0), Vector2(5, 3)), MINT)
	if height > 4:
		canvas.draw_rect(Rect2(tip + Vector2(-3, 5), Vector2(4, 2)), Color("547764"))
	if progress >= 1.0:
		var fruit := BERRY if berries else AMBER
		canvas.draw_rect(Rect2(tip + Vector2(-3, -2), Vector2(4, 3)), fruit.darkened(0.2))
		canvas.draw_rect(Rect2(tip + Vector2(2, -3), Vector2(4, 3)), fruit)
		canvas.draw_rect(Rect2(tip + Vector2(2, -3), Vector2(1, 1)), fruit.lightened(0.5))

func _spark(canvas: CanvasItem, p: Vector2, color: Color) -> void:
	canvas.draw_rect(Rect2(p + Vector2(-2, 0), Vector2(5, 1)), color)
	canvas.draw_rect(Rect2(p + Vector2(0, -2), Vector2(1, 5)), color)
