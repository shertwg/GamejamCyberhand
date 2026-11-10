extends Control
## Original low-resolution art. Every primitive snaps to the same pixel grid.
signal module_selected(id: String)
const WORLD := Vector2(300, 130)
const AREAS := {"workshop": Rect2(18, 46, 62, 38), "pump": Rect2(91, 48, 46, 38),
	"garden": Rect2(156, 37, 70, 51), "generator": Rect2(80, 92, 55, 32), "beacon": Rect2(241, 29, 48, 70)}
var state: Dictionary = {}
var selected := "pump"
var phase := 0
var _elapsed := 0.0
var _scale := 1.0
var _origin := Vector2.ZERO
var _launched := false
var _launch_seconds := 0.0

func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	_scale = maxf(0.5, minf(size.x / WORLD.x, maxf(1, floor(size.x / WORLD.x))))
	custom_minimum_size.y = WORLD.y * _scale
	_origin = Vector2(floor((size.x - WORLD.x * _scale) / 2), 0)
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	if _launched and _launch_seconds < 2:
		_launch_seconds += delta
		queue_redraw()
	_elapsed += delta
	if _elapsed > 0.25:
		_elapsed = 0
		phase += 1
		queue_redraw()

func show_station(data: Dictionary, module: String) -> void:
	if data.get("launched", false) and not _launched:
		_launch_seconds = 2.0 if state.is_empty() else 0.0
		_launched = true
	state = data
	selected = module
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_choose((event.position - _origin) / _scale)
	elif event is InputEventScreenTouch and event.pressed:
		_choose((event.position - _origin) / _scale)

func _choose(point: Vector2) -> void:
	for id in AREAS:
		if AREAS[id].has_point(point):
			module_selected.emit(id)
			accept_event()
			return

func r(x: float, y: float, w: float, h: float, color: String) -> void:
	draw_rect(Rect2(x, y, w, h), Color(color))

func poly(points: Array, color: String) -> void:
	var packed := PackedVector2Array()
	for p in points: packed.append(Vector2(p[0], p[1]))
	draw_colored_polygon(packed, Color(color))

func _draw() -> void:
	draw_set_transform(_origin, 0, Vector2.ONE * _scale)
	# Warm alien morning. Terraced silhouettes, luminous dust and a ringed sun.
	r(0, 0, 300, 130, "ac6578")
	r(0, 0, 300, 16, "5e6091")
	r(0, 16, 300, 13, "9874a4")
	r(0, 29, 300, 15, "dc8b91")
	r(240, 8, 19, 3, "ffe1ad")
	r(236, 11, 26, 16, "ffd999")
	r(239, 27, 20, 3, "f7c18b")
	r(226, 18, 47, 2, "fbe8b6")
	poly([[0,44],[19,22],[31,22],[54,49],[80,27],[99,39],[129,20],[143,20],[174,53],[216,28],[234,48],[270,31],[300,46],[300,78],[0,78]], "775d88")
	poly([[0,56],[35,43],[65,58],[102,45],[145,60],[190,42],[225,59],[262,46],[300,58],[300,130],[0,130]], "b57e87")
	poly([[0,79],[43,68],[101,75],[172,65],[237,73],[300,63],[300,130],[0,130]], "cf9b80")
	# Soil islands and a pale connected service path.
	r(8, 91, 230, 3, "806371")
	r(28, 85, 248, 6, "e7c5a3")
	r(45, 70, 6, 26, "e7c5a3")
	r(105, 76, 6, 45, "e7c5a3")
	r(184, 71, 6, 49, "e7c5a3")
	for i in range(46):
		var x := (i * 73 + 7) % 298
		var y := 71 + (i * 17) % 58
		if i % 3 == 0:
			r(x, y, 3, 2, "b98577")
		else:
			r(x, y, 2, 3, "779274")
			r(x - 1, y + 1, 4, 1, "94b47f")
	# Workshop: coral roof, open loading bay, scrap and rechargeable salvage cells.
	r(19, 80, 64, 5, "96717b")
	r(21, 52, 56, 29, "e9bf96")
	r(21, 56, 56, 3, "a76065")
	r(23, 61, 12, 17, "6d6b86")
	r(25, 63, 8, 8, "9de3dd")
	r(46, 61, 23, 20, "4c536c")
	r(49, 65, 16, 14, "6b8195")
	r(51, 65, 12, 2, "a6bfbc")
	poly([[18,54],[26,43],[69,43],[80,54]], "ce6574")
	r(27, 44, 39, 2, "ffae93")
	for x in [28, 40, 52, 64]: r(x, 48, 2, 6, "a64c69")
	r(26, 78, 11, 6, "b37e65")
	r(27, 78, 9, 1, "ffd798")
	r(38, 78, 4, 6, "f2ca68")
	# Pump: blue tank, copper pipe and a transparent water gauge.
	r(91, 80, 47, 5, "96717b")
	r(96, 55, 28, 26, "3d7eaa")
	r(100, 51, 20, 4, "a1d5df")
	r(96, 55, 28, 3, "75c5de")
	r(100, 60, 12, 17, "294e77")
	r(102, 67 if state.get("pump", false) else 74, 8, 10 if state.get("pump", false) else 3, "73edd8")
	r(120, 64, 14, 4, "d19b68")
	r(130, 64, 4, 16, "d19b68")
	r(127, 77, 10, 4, "eff1be")
	r(116, 61, 3, 3, "a6f4c3" if state.get("pump", false) else "ffb976")
	# Greenhouse glass, white beams and actual crop growth in three soil beds.
	var garden: bool = state.get("garden", false)
	r(151, 80, 78, 9, "94737a")
	poly([[155,57],[168,36],[209,36],[225,57],[225,82],[155,82]], "5b8794" if garden else "917b85")
	poly([[159,56],[170,40],[207,40],[220,56]], "90e2d0" if garden else "b6a6a1")
	r(158, 58, 64, 23, "398883" if garden else "756c7e")
	for x in [158,179,200,222]: r(x, 56, 2, 27, "d5e4b4")
	r(157, 57, 66, 2, "e2f3ca")
	r(170, 38, 2, 18, "d5e4b4")
	r(199, 38, 2, 18, "d5e4b4")
	r(160, 60, 9, 2, "b3ead6")
	var beds: Array = state.get("beds", [-1.0,-1.0,-1.0])
	for i in range(3):
		var x := 162 + i * 20
		r(x, 75, 15, 5, "735d59")
		r(x, 75, 15, 1, "c99871")
		if float(beds[i]) >= 0:
			var h := 3 + int(float(beds[i]) / 3)
			r(x+7, 75-h, 2, h, "cef49b")
			r(x+3, 75-h, 6, 3, "8ae38f")
			r(x+8, 77-h, 5, 3, "a8ed97")
			if float(beds[i]) >= 18:
				r(x+3, 74-h, 4, 4, "ffc87d")
				r(x+10, 76-h, 4, 4, "ff8e78")
	# Generator and its solar wings.
	var gen: bool = state.get("generator", false)
	r(79, 115, 59, 9, "94737a")
	r(96, 97, 27, 23, "e0cba4" if gen else "9c8590")
	r(99, 94, 21, 5, "f8dfa3")
	r(102, 103, 14, 10, "455e80")
	for i in range(3): r(104+i*4, 105, 2, 6, "ffe090" if gen else "967e8d")
	for x in [78,126]:
		r(x, 98, 13, 14, "3b617f")
		for y in [100,105,110]: r(x+1,y,11,1,"8cb7d1")
		r(x+6,98,1,14,"8cb7d1")
	# Parked ship lifts off, leaving the pad and radio dish behind.
	r(239, 90, 52, 7, "9c7880")
	if _launch_seconds < 2.0:
		var altitude := floorf(30.0 * _launch_seconds * _launch_seconds)
		draw_set_transform(_origin - Vector2(0, altitude * _scale), 0, Vector2.ONE * _scale)
		poly([[245,76],[249,49],[262,34],[275,49],[279,76]], "f8dbad")
		poly([[249,49],[262,34],[275,49]], "eb8d85")
		r(253, 53, 18, 11, "446c8c")
		r(255, 54, 14, 6, "97e7dc")
		poly([[245,65],[239,79],[249,77]], "b26480")
		poly([[278,65],[285,79],[275,77]], "b26480")
		r(252, 77, 20, 4, "67627f")
		if _launched:
			poly([[255,81],[268,81],[265,104+phase%3],[260,114],[257,103]], "ffd58c")
		else:
			r(250, 82, 4, 8, "605c74")
			r(272, 82, 4, 8, "605c74")
		draw_set_transform(_origin, 0, Vector2.ONE * _scale)
	r(285, 45, 2, 43, "685c7d")
	poly([[274,40],[293,47],[289,54],[282,53]], "ace8cf" if state.get("beacon", false) else "a38c96")
	if state.get("signal",false):
		r(291,35,2,2,"fff3b0")
		r(295,31,2,2,"fff3b0")
	# A small ranger and their floating companion make the colony feel inhabited.
	var walk := phase % 2
	r(151,103,8,2,"a07777")
	r(151,92,7,6,"f1ddb5")
	r(153,93,5,3,"476a85")
	r(152,98,5,5,"f4a177")
	r(151,103,2,2+walk,"4c607d")
	r(156,103,2,3-walk,"4c607d")
	r(164,91+walk,7,5,"9df4d2")
	r(166,92+walk,4,2,"4c6983")
	if AREAS.has(selected):
		var rect: Rect2 = AREAS[selected]
		draw_rect(rect.grow(2), Color("fff1b0"), false, 1)
		var mid := rect.get_center().x
		poly([[mid-3,rect.position.y-6],[mid+3,rect.position.y-6],[mid,rect.position.y-3]],"fff1b0")
