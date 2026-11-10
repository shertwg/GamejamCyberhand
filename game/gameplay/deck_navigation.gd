extends RefCounted
## Paths use the actor's feet, in the same 384×216 coordinates as the room art.
const CELL := 5
const STEP_LENGTH := 34.0
const WALK_SPEED := 88.0
const FLOOR_TOP := [176, 185, 171, 166, 173, 170, 153, 150, 157, 151]
const BLOCKERS := [
	[Rect2(12,175,51,23),Rect2(326,175,58,21)],
	[Rect2(0,183,92,15),Rect2(300,180,84,17)],
	[Rect2(0,169,65,27),Rect2(320,169,64,25)],
	[Rect2(0,165,86,25),Rect2(298,164,86,26)],
	[Rect2(0,174,56,18),Rect2(331,172,53,19)],
	[Rect2(0,170,48,18),Rect2(332,170,52,20)],
	[Rect2(272,149,92,24)],
	[Rect2(2,146,56,29),Rect2(257,148,117,26),Rect2(145,183,30,12)],
	[Rect2(0,153,94,24),Rect2(269,153,115,20)],
	[Rect2(0,147,110,26),Rect2(317,147,67,19)]
]
var feet := Vector2(120,195)
var facing := 1
var heading := Vector2.RIGHT
var gait := 0.0
var footfall: int:
	get: return floori(gait / STEP_LENGTH)
var moving: bool:
	get: return not _way.is_empty()
var _room := 0
var _grid := AStarGrid2D.new()
var _way := PackedVector2Array()
var _valid: Array[Vector2i] = []

func enter(room: int, direction: int) -> void:
	_room = room
	_grid.region = Rect2i(0,0,77,43)
	_grid.cell_size = Vector2.ONE * CELL
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	_valid.clear()
	for y in range(43):
		for x in range(77):
			var cell := Vector2i(x,y)
			var point := Vector2(cell) * CELL
			var passable := on_floor(point)
			_grid.set_point_solid(cell, not passable)
			if passable: _valid.append(cell)
	feet = Vector2(_nearest(Vector2(57 if direction >= 0 else 324,200))) * CELL
	_way.clear()
	gait = STEP_LENGTH * 0.6
	if direction != 0:
		facing = direction
		heading = Vector2(direction,0)
		walk_to(Vector2(115 if direction > 0 else 268,196))

func on_floor(point: Vector2) -> bool:
	var far_y: int = FLOOR_TOP[_room]
	var inset := lerpf(35,12,clampf((point.y-far_y)/float(209-far_y),0,1))
	if point.y < far_y or point.y > 209 or point.x < inset or point.x > 384-inset:
		return false
	for obstacle in BLOCKERS[_room]:
		if obstacle.grow(3.0).has_point(point): return false
	return true

func walk_to(point: Vector2) -> bool:
	var start := _nearest(feet)
	var end := _nearest(point)
	_way = _grid.get_point_path(start,end)
	if _way.is_empty(): return false
	return true

func advance(delta: float) -> float:
	var remaining := minf(delta,0.1) * WALK_SPEED
	var travelled := 0.0
	while not _way.is_empty() and remaining > 0:
		var offset := _way[0] - feet
		var distance := offset.length()
		if absf(offset.x) > 0.3: facing = 1 if offset.x > 0 else -1
		var step := minf(distance,remaining)
		if distance <= 0.001:
			_way.remove_at(0)
			continue
		heading = offset / distance
		feet += offset * (step/distance)
		remaining -= step
		travelled += step
		if distance <= step: _way.remove_at(0)
	gait += travelled
	return travelled

func depth() -> float:
	return clampf((feet.y - FLOOR_TOP[_room]) / float(209-FLOOR_TOP[_room]),0,1)

func _nearest(point: Vector2) -> Vector2i:
	var best := _valid[0]
	var distance := INF
	for cell in _valid:
		var candidate := (Vector2(cell)*CELL).distance_squared_to(point)
		if candidate < distance:
			best = cell
			distance = candidate
	return best
