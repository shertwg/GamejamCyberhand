extends Control
## Normalized geometry; gameplay consumes only ControlCommand and emits GameEvent.
signal completed
signal event_emitted(event)

const Command = preload("res://game/core/control_command.gd")
const Event = preload("res://game/core/game_event.gd")
const Level = preload("res://game/core/level_config.gd")

const WALLS: Array[Rect2] = [
	Rect2(0.27, 0.0, 0.055, 0.60),
	Rect2(0.51, 0.40, 0.055, 0.60),
	Rect2(0.75, 0.0, 0.055, 0.60),
]
const HALF := Vector2(0.012, 0.045)

var player := Vector2(0.06, 0.50)
var active_seconds: float = 0.0
var finished: bool = false
var blocked: bool = false

var current_level_id: String = "repair-1"
var active_walls: Array[Rect2] = WALLS.duplicate()
var hold_zone: Rect2 = Rect2(0.36, 0.10, 0.14, 0.25)
var hold_target_ms: int = 1200
var horizontal_speed: float = 0.085
var vertical_speed: float = 0.48
var session_id: String = "session-1"
var attempt_id: int = 1
var _event_seq: int = 0
var _started_emitted: bool = false
var _last_direction: StringName = Command.REST


func _ready() -> void:
	custom_minimum_size = Vector2(0, 130)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func apply_level_config(config: Level, p_session_id: String = "session-1", p_attempt_id: int = 1) -> void:
	if config == null:
		return
	current_level_id = config.level_id
	active_walls = config.walls.duplicate()
	hold_zone = config.hold_zone
	hold_target_ms = config.hold_target_ms
	horizontal_speed = config.horizontal_speed
	vertical_speed = config.vertical_speed
	session_id = p_session_id
	attempt_id = p_attempt_id
	reset()


func reset() -> void:
	player = Vector2(0.06, 0.50)
	active_seconds = 0.0
	finished = false
	blocked = false
	_started_emitted = false
	_last_direction = Command.REST
	queue_redraw()


func is_in_hold_zone() -> bool:
	return hold_zone.has_point(player)


func advance(delta: float, command: Command) -> void:
	if finished or command.pause_required:
		return
	if command.direction not in [Command.OPEN, Command.CLOSE]:
		return
	if not _started_emitted:
		_started_emitted = true
		_emit_game_event(Event.ACTION_STARTED, &"attempt_started", {"expected_direction": String(command.direction)})
	_last_direction = command.direction
	active_seconds += delta
	var vertical := -1.0 if command.direction == Command.OPEN else 1.0
	# Substeps prevent tunnelling on a slow host.
	var steps := maxi(1, ceili(delta / 0.016))
	var step := delta / steps
	for index in range(steps):
		var target := player
		target.y = clampf(target.y + vertical * command.intensity * step * vertical_speed, HALF.y, 1.0 - HALF.y)
		if not _collides(target):
			player = target
		target = player + Vector2(command.intensity * step * horizontal_speed, 0)
		blocked = _collides(target)
		if not blocked:
			player = target
		if player.x >= 0.94:
			finished = true
			_emit_game_event(Event.ACTION_SUCCEEDED, &"airlock_reached", {"active_seconds": active_seconds})
			_emit_game_event(Event.LEVEL_COMPLETED, &"mission_repaired", {"active_seconds": active_seconds})
			completed.emit()
			break
	queue_redraw()


func _emit_game_event(event_type: StringName, reason: StringName, payload: Dictionary = {}) -> void:
	_event_seq += 1
	var ev := Event.new(
		"%s-%d-%d" % [session_id, attempt_id, _event_seq],
		event_type,
		session_id,
		attempt_id,
		current_level_id,
		int(round(active_seconds * 1000.0)),
		reason,
		payload
	)
	event_emitted.emit(ev)


func _collides(point: Vector2) -> bool:
	for wall in active_walls:
		if wall.intersects(Rect2(point - HALF, HALF * 2.0)):
			return true
	return false


const PX := 3.0


func _px_rect(pos: Vector2, sz: Vector2, color: Color) -> void:
	var p := pos.snapped(Vector2(PX, PX))
	var s := sz.snapped(Vector2(PX, PX))
	draw_rect(Rect2(p, s), color)


func _px_box(pos: Vector2, sz: Vector2, fill_col: Color, border_col: Color) -> void:
	var p := pos.snapped(Vector2(PX, PX))
	var s := sz.snapped(Vector2(PX, PX))
	draw_rect(Rect2(p, s), fill_col)
	draw_rect(Rect2(p, Vector2(s.x, PX)), border_col)
	draw_rect(Rect2(Vector2(p.x, p.y + s.y - PX), Vector2(s.x, PX)), border_col)
	draw_rect(Rect2(p, Vector2(PX, s.y)), border_col)
	draw_rect(Rect2(Vector2(p.x + s.x - PX, p.y), Vector2(PX, s.y)), border_col)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a1420"))
	if current_level_id == "repair-1":
		_draw_cooling_housing()
	for x in range(0, int(size.x), 36):
		for y in range(0, int(size.y), 36):
			_px_rect(Vector2(x, y), Vector2(PX, PX), Color(0.2, 0.45, 0.55, 0.12))
	_px_box(Vector2.ZERO, size, Color.TRANSPARENT, Color("224263"))
	# 1. Pixel-art Hold Zone with holographic dither and corner brackets
	var hold_rect := Rect2(hold_zone.position * size, hold_zone.size * size)
	var in_zone := is_in_hold_zone()
	var zone_accent := Color("8af0d4") if in_zone else Color("3caea3")
	# Dither grid
	for dx in range(int(hold_rect.position.x), int(hold_rect.end.x), 6):
		for dy in range(int(hold_rect.position.y), int(hold_rect.end.y), 6):
			if (int(dx / 6) + int(dy / 6)) % 2 == 0:
				_px_rect(Vector2(dx, dy), Vector2(PX, PX), Color(zone_accent, 0.28 if in_zone else 0.10))
	# Corner brackets ┌ ┐ └ ┘
	var b_len := 15.0
	var hp := hold_rect.position.snapped(Vector2(PX, PX))
	var he := hold_rect.end.snapped(Vector2(PX, PX))
	_px_rect(hp, Vector2(b_len, PX), zone_accent)
	_px_rect(hp, Vector2(PX, b_len), zone_accent)
	_px_rect(Vector2(he.x - b_len, hp.y), Vector2(b_len, PX), zone_accent)
	_px_rect(Vector2(he.x - PX, hp.y), Vector2(PX, b_len), zone_accent)
	_px_rect(Vector2(hp.x, he.y - PX), Vector2(b_len, PX), zone_accent)
	_px_rect(Vector2(hp.x, he.y - b_len), Vector2(PX, b_len), zone_accent)
	_px_rect(Vector2(he.x - b_len, he.y - PX), Vector2(b_len, PX), zone_accent)
	_px_rect(Vector2(he.x - PX, he.y - b_len), Vector2(PX, b_len), zone_accent)

	# 2. Pixel-art Obstacles (Hazard bulkheads with stepped diagonal stripes)
	for wall in active_walls:
		var r := Rect2(wall.position * size, wall.size * size)
		_px_box(r.position, r.size, Color("14232e"), Color("0c161d"))
		# 45-degree pixel hazard stripes
		var stripe_w := 12.0
		for sy in range(int(r.position.y), int(r.end.y), int(stripe_w)):
			for step_x in range(0, int(r.size.x), int(PX)):
				var stripe_y: float = sy + step_x
				if stripe_y >= r.position.y and stripe_y + PX <= r.end.y:
					_px_rect(Vector2(r.position.x + step_x, stripe_y), Vector2(PX, PX), Color("df9675"))
		# Outer metallic border and rivets
		_px_box(r.position, r.size, Color.TRANSPARENT, Color("df9675"))
		for sy in range(int(r.position.y + 12), int(r.end.y - 12), 24):
			_px_rect(Vector2(r.position.x + 4, sy), Vector2(PX, PX), Color("8c9d9d"))
			_px_rect(Vector2(r.end.x - 4 - PX, sy), Vector2(PX, PX), Color("8c9d9d"))
		# Neon hazard edge facing the passageway
		var edge_y := r.end.y - PX if wall.position.y == 0.0 else r.position.y
		_px_rect(Vector2(r.position.x, edge_y), Vector2(r.size.x, PX), Color("ffd166"))

	# 3. Pixel-art Docking Airlock Socket
	var socket := Rect2(Vector2(0.94, 0) * size, Vector2(0.06, 1) * size)
	_px_box(socket.position, socket.size, Color("0f242b"), Color("237f85"))
	# Proximity LED segments (light up as player approaches finish)
	var approach := clampf((player.x - 0.5) / 0.44, 0.0, 1.0)
	var total_leds := 8
	var active_leds := int(approach * total_leds)
	for i in range(total_leds):
		var ly := socket.position.y + 18.0 + i * (socket.size.y - 36.0) / total_leds
		var led_on := i <= active_leds
		var led_col := Color("8af0d4") if led_on else Color("16373d")
		_px_rect(Vector2(socket.position.x + 6, ly), Vector2(socket.size.x - 12, 6), led_col)
	if current_level_id == "repair-1":
		var gauge := Vector2(socket.get_center().x, size.y * 0.5)
		var gauge_radius := minf(socket.size.x * 0.34, 24.0)
		_pixel_disc(gauge, gauge_radius, Color("08111d"))
		_pixel_disc(gauge, gauge_radius * 0.4, Color("ffd166"))
		# 4 pixel ticks around gauge
		for a in [-PI * 0.75, -PI * 0.25, PI * 0.25, PI * 0.75]:
			var tick_p := gauge + Vector2(cos(a), sin(a)) * (gauge_radius - PX)
			_px_rect(tick_p, Vector2(PX, PX), Color("8af0d4"))

	# 4. Pixel-art Ranger Manipulator Drone
	var center := (player * size).snapped(Vector2(PX, PX))
	var radius := maxf(8.0, minf(HALF.x * size.x, HALF.y * size.y))
	var accent := Color("ffd166") if blocked else Color("8af0d4")

	# Reactive Thruster Plume (drawn behind drone)
	var thruster_x := center.x - radius * 1.3
	_px_rect(Vector2(thruster_x - PX * 2, center.y - PX), Vector2(PX * 2, PX * 2), Color("ffffff"))
	_px_rect(Vector2(thruster_x - PX * 4, center.y - PX * 1.5), Vector2(PX * 2, PX * 3), Color("ffd166"))
	_px_rect(Vector2(thruster_x - PX * 7, center.y - PX), Vector2(PX * 3, PX * 2), Color("df9675"))
	_px_rect(Vector2(thruster_x - PX * 10, center.y - PX * 0.5), Vector2(PX * 3, PX), Color(0.3, 0.5, 0.6, 0.4))

	# Drone Armored Hull
	var hull_w := radius * 1.8
	var hull_h := radius * 1.4
	var hull_pos := Vector2(center.x - hull_w * 0.5, center.y - hull_h * 0.5)
	_px_box(hull_pos, Vector2(hull_w, hull_h), Color("152632"), Color("224263"))
	_px_rect(Vector2(hull_pos.x + PX, hull_pos.y + PX), Vector2(hull_w - PX * 2, PX), Color("3caea3"))

	# Sensor Eye / Visor
	var eye_sz := Vector2(PX * 2, PX * 2)
	var eye_pos := Vector2(center.x + PX, center.y - PX)
	_px_rect(eye_pos, eye_sz, accent)
	_px_rect(eye_pos, Vector2(PX, PX), Color.WHITE)

	# Robotic Manipulator Claws
	var claw_spread := radius * (1.35 if _last_direction == Command.OPEN else (0.35 if _last_direction == Command.CLOSE else 0.85))
	var claw_root_x := center.x + hull_w * 0.45
	for side in [-1.0, 1.0]:
		var elbow_p := Vector2(claw_root_x + PX * 2, center.y + claw_spread * side * 0.6)
		var tip_p := Vector2(elbow_p.x + PX * 3, center.y + claw_spread * side)
		_px_rect(Vector2(claw_root_x, center.y + PX * side), Vector2(PX * 2, PX), accent)
		_px_rect(elbow_p, Vector2(PX * 2, PX * 2), Color("237f85"))
		_px_rect(tip_p, Vector2(PX * 2, PX), accent)
		_px_rect(Vector2(tip_p.x + PX, tip_p.y + (PX if side < 0 else -PX)), Vector2(PX, PX), Color("ffd166"))

	# Magnetic arc between claws when OPEN
	if _last_direction == Command.OPEN:
		_px_rect(Vector2(claw_root_x + PX * 3, center.y - PX), Vector2(PX, PX * 2), Color(accent, 0.6))


func _draw_cooling_housing() -> void:
	# Pixel-art cooling conduits and background radiator plates
	for y in [8.0, size.y - 16.0]:
		_px_box(Vector2(0, y), Vector2(size.x, 8.0), Color("223e4a"), Color("152632"))
		_px_rect(Vector2(0, y + 2), Vector2(size.x, PX), Color("3caea3"))
		for x in range(16, int(size.x), 72):
			_px_box(Vector2(x, y - 2), Vector2(8, 12), Color("3caea3"), Color("152632"))
	for x in range(24, int(size.x * 0.91), 54):
		var plate_h := maxf(32.0, size.y - 48.0)
		_px_box(Vector2(x, 24), Vector2(36, plate_h), Color("0d1c26"), Color("122736"))
		for py in range(32, int(size.y - 32), 12):
			_px_rect(Vector2(x + 6, py), Vector2(24, PX), Color(0.2, 0.45, 0.55, 0.25))


func _pixel_disc(center: Vector2, radius: float, color: Color) -> void:
	# Square 3px cells; the rendered art never participates in collisions.
	var step := 3.0
	var origin := (center - Vector2.ONE * radius).snapped(Vector2.ONE * step)
	for y in range(ceili(radius * 2 / step) + 1):
		for x in range(ceili(radius * 2 / step) + 1):
			var point := origin + Vector2(x,y) * step
			if (point + Vector2.ONE * step * 0.5).distance_squared_to(center) <= radius * radius:
				draw_rect(Rect2(point,Vector2.ONE * step),color)
