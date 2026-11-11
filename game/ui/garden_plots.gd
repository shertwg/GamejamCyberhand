extends RefCounted

const State = preload("res://game/station/station_state.gd")
const CENTERS := [Vector2(112, 126), Vector2(192, 123), Vector2(270, 120)]
const SIZE := Vector2(44, 30)
const BED = preload("res://assets/last_light/hydroponics.png")
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
	canvas.draw_texture_rect(BED, Rect2(54, 79, 276, 101), false)
	for i in range(CENTERS.size()):
		var p: Vector2 = CENTERS[i]
		var elapsed := float(station.data.beds[i])
		if elapsed < 0.0: continue
		var progress := elapsed / station.grow_seconds(i)
		var berries: bool = station.data.crops[i] == "berries"
		for plant in range(5):
			var offset := Vector2((plant - 2) * 7, (plant % 3) * 2)
			_draw_sprout(canvas, p + offset, progress, berries, age + plant * 0.8 + i)
		if progress < 1.0:
			var drop := Vector2(p.x + 5, p.y - 19 + floorf(fmod(age * 13 + i * 9, 14.0)))
			canvas.draw_rect(Rect2(drop, Vector2(1, 2)), Color("83d5d4"))

func draw_feedback(canvas: CanvasItem, station: State, age: float, selected_crop: String) -> void:
	for i in range(CENTERS.size()):
		var p: Vector2 = CENTERS[i]
		var elapsed := float(station.data.beds[i])
		var marker := p + Vector2(0, -7)
		if elapsed < 0.0:
			canvas.draw_rect(Rect2(marker - Vector2(4, 4), Vector2(9, 9)), Color("242036b0"))
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
