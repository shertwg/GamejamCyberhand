extends Control
## A small ship instrument, independent of repair controls and story overlays.
const State = preload("res://game/station/station_state.gd")
const KEYS := ["energy", "water", "food"]
const LABELS := ["Энергия", "Вода", "Еда"]
const COLORS := [Color("ffd47a"), Color("74dcfa"), Color("a8e38e")]
const PIXELS := [
	["...##", "..##.", ".###.", "#####", "..##.", ".##.", ".#..."],
	["..#..", "..#..", ".###.", ".###.", "#####", "#####", ".###."],
	["....#", ".#.##", ".###.", "#.##.", "###..", "##...", "#...."]
]
var station: State
var _display := PackedFloat32Array([0, 0, 0])
var _first_frame := true

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	if station == null or not is_visible_in_tree(): return
	var redraw := false
	for i in range(KEYS.size()):
		var goal := station.supply(KEYS[i])
		var level := goal if _first_frame else move_toward(_display[i], goal, delta * 70.0)
		if level != _display[i]:
			_display[i] = level
			redraw = true
	_first_frame = false
	if redraw: queue_redraw()

func _draw() -> void:
	if station == null or size.x <= 0: return
	var font := get_theme_default_font()
	var compact := size.x < 340.0
	var font_size := 12 if compact else 14
	var gap := 5.0
	var width := floorf((size.x - gap * 2.0) / 3.0)
	for i in range(KEYS.size()):
		var x := i * (width + gap)
		var level := _display[i]
		var low := level <= State.SUPPLY_LOW
		var accent: Color = COLORS[i] if not low else Color("ff977a")
		var shell := Rect2(x, 0, width, size.y - 2)
		draw_rect(Rect2(shell.position + Vector2(2, 3), shell.size), Color("10101c"))
		draw_rect(shell, Color("131825"))
		draw_rect(shell.grow(-2), Color("211f2d"))
		draw_rect(Rect2(x, 0, width, 1), Color("695045") if not low else accent.darkened(0.35))
		draw_rect(Rect2(x, 0, 2, shell.size.y), accent.darkened(0.34))
		var icon_step := 1.5 if compact else 2.0
		var icon_x := x + (6.0 if compact else 8.0)
		for row in range(PIXELS[i].size()):
			var bits: String = PIXELS[i][row]
			for col in range(bits.length()):
				if bits[col] == "#":
					draw_rect(Rect2(icon_x + col * icon_step, 5 + row * icon_step, icon_step, icon_step), accent)
		var digits := ("%d%%" if not low else "! %d%%") % ceili(level)
		var number_width := font.get_string_size(digits, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var name_x := icon_x + (11.0 if compact else 16.0)
		var name_width := maxf(1.0, x + width - 9.0 - number_width - name_x)
		draw_string(font, Vector2(name_x, 17), LABELS[i], HORIZONTAL_ALIGNMENT_LEFT, name_width, font_size, Color("f3e6d8"))
		draw_string(font, Vector2(x + width - number_width - 6, 17), digits, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, accent)
		var track := Rect2(x + 7, size.y - 12, width - 14, 6)
		draw_rect(track.grow(1), Color("0b0d18"))
		for segment in range(10):
			var start := roundf(track.size.x * segment / 10.0)
			var end := roundf(track.size.x * (segment + 1) / 10.0)
			var cell := Rect2(track.position + Vector2(start, 0), Vector2(end - start - 1, track.size.y))
			draw_rect(cell, Color("393440"))
			var fill := floorf(cell.size.x * clampf(level / 10.0 - segment, 0.0, 1.0))
			if fill > 0:
				draw_rect(Rect2(cell.position, Vector2(fill, cell.size.y)), accent.darkened(0.24))
				draw_rect(Rect2(cell.position, Vector2(fill, 2)), accent)
