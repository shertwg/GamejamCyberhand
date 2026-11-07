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


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101d30"))
	# Stabilization / hold zone in ship bay
	var hold_rect := Rect2(hold_zone.position * size, hold_zone.size * size)
	draw_rect(hold_rect, Color(0.16, 0.45, 0.40, 0.28))
	draw_rect(hold_rect, Color("3caea3"), false, 1.5)
	for wall in active_walls:
		draw_rect(Rect2(wall.position * size, wall.size * size), Color("df9675"))
	# Right airlock / repair socket
	draw_rect(Rect2(Vector2(0.94, 0) * size, Vector2(0.06, 1) * size), Color("285d5b"))
	var center := player * size
	var radius := maxf(5.0, minf(HALF.x * size.x, HALF.y * size.y))
	draw_circle(center, radius, Color("8af0d4"))
	var jaw_spread := radius * (1.25 if _last_direction == Command.OPEN else (0.65 if _last_direction == Command.CLOSE else 0.95))
	draw_line(center + Vector2(radius, -jaw_spread), center + Vector2(radius * 1.6, -jaw_spread), Color.WHITE, 2)
	draw_line(center + Vector2(radius, jaw_spread), center + Vector2(radius * 1.6, jaw_spread), Color.WHITE, 2)
