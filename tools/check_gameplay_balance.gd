extends SceneTree
## Godot 4.4.1 --headless --path . --script res://tools/check_gameplay_balance.gd
## Isolated experiment: no coordinator, LocalStore, UI, or player save is used.

const Config = preload("res://game/core/input_config.gd")
const Pipeline = preload("res://game/core/input_pipeline.gd")
const Frame = preload("res://game/core/input_frame.gd")
const Level = preload("res://game/core/level_config.gd")
const Course = preload("res://game/gameplay/course.gd")
const Tracker = preload("res://game/core/session_tracker.gd")
const DT := 0.05
const DT_MS := 50
const SIGNALS := [0.58, 0.65, 0.80, 1.0]
const CANDIDATE_OFF := {"tutorial": 0.30, "repair-1": 0.40, "repair-2": 0.43, "repair-3": 0.50}

class Stream:
	extends RefCounted
	var pipeline
	var seq := 0
	var now := 0
	func _init(config) -> void:
		pipeline = Pipeline.new(config)
		pipeline.begin_stream("replay")
		sample(0.0, 0.0)
		pipeline.request_resume(now)
	func sample(a: float, b: float):
		now += DT_MS
		var frame = Frame.new()
		frame.source = "replay"
		frame.connected = true
		frame.seq = seq
		seq += 1
		frame.timestamp_ms = now
		frame.channel_a = a
		frame.channel_b = b
		return pipeline.submit(frame, now)

var checks := 0
var failures: Array[String] = []
var report := {
	"schema_version": 1,
	"mode": "isolated InputPipeline + current Course/LevelConfig; JSON is not wired into the game",
	"sample_ms": DT_MS,
	"routes": [], "holds": [], "signals": [], "stationary": [], "binary_bounds": [],
}

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	var version = Engine.get_version_info()
	check(version.major == 4 and version.minor == 4 and version.patch == 1, "requires Godot 4.4.1")
	if not failures.is_empty():
		quit(1)
		return
	report["godot_version"] = version.string
	report["inputs_sha256"] = {}
	for path in ["game/content/missions.json", "game/core/level_config.gd", "game/core/input_decoder.gd", "game/core/session_tracker.gd", "game/gameplay/course.gd", "tools/check_gameplay_balance.gd"]:
		report.inputs_sha256[path] = FileAccess.get_sha256("res://" + path)
	var missions = JSON.parse_string(FileAccess.get_file_as_string("res://game/content/missions.json"))
	check(missions is Array and missions.size() == 4, "four mission definitions required")
	if not failures.is_empty():
		quit(1)
		return
	for variant in ["current_json", "common_on"]:
		for mission in missions:
			var id = String(mission.id)
			var on = float(mission.on_threshold) if variant == "current_json" else 0.55
			var off = float(mission.off_threshold) if variant == "current_json" else float(CANDIDATE_OFF[id])
			var input_config = Config.new(on, off, on, off)
			check(input_config.validation_error() == &"", "%s %s valid input settings" % [variant, id])
			probe_signals(variant, id, input_config)
			probe_stationary(variant, id, input_config)
			for step in [-1, 0, 1]:
				for strength in SIGNALS:
					var route = run_route(id, step, input_config, strength, "route")
					route["variant"] = variant
					report.routes.append(route)
					check(route.finished if strength > on else route.inactive, "%s %s step=%d signal=%.2f expected route result" % [variant, id, step, strength])
					if step == 0 and is_equal_approx(strength, 0.65):
						print("COMPARE %s %s signal=0.65 intensity=%.4f seconds=%.2f" % [variant, id, route.intensity, route.seconds])
				for strength in [0.65, 0.80, 1.0]:
					var holding = run_route(id, step, input_config, strength, "analog_hold")
					holding["variant"] = variant
					report.holds.append(holding)
					check(holding.finished and holding.goal_met, "%s %s step=%d signal=%.2f positive-intensity continuous hold and finish" % [variant, id, step, strength])
				var digital = run_route(id, step, input_config, 1.0, "binary_hold")
				digital["variant"] = variant
				report.holds.append(digital)
				check(digital.finished, "%s %s step=%d binary strategy reaches airlock" % [variant, id, step])
				if id == "repair-2":
					var longer = run_route(id, step, input_config, 0.65, "analog_hold", 1800)
					longer["variant"] = variant
					report.holds.append(longer)
					check(longer.finished and longer.goal_met, "%s storm step=%d proposed 1800ms hold and finish" % [variant, step])
	probe_binary_bounds()
	report["checks"] = checks
	report["failures"] = failures
	var output := "res://work/gameplay-balance/report.json"
	var args = OS.get_cmdline_user_args()
	if not args.is_empty():
		if args.size() != 2 or args[0] != "--output" or not args[1].begins_with("res://work/") or ".." in args[1]:
			push_error("usage: -- --output res://work/<report>.json")
			quit(2)
			return
		output = args[1]
	var directory_error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	if directory_error != OK:
		push_error("cannot create report directory")
		quit(2)
		return
	var file = FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("cannot write balance report")
		quit(2)
		return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("GAMEPLAY BALANCE checks=%d failures=%d routes=%d holds=%d" % [checks, failures.size(), report.routes.size(), report.holds.size()])
	print("REPORT ", output)
	quit(0 if failures.is_empty() else 1)

func route_target(course) -> float:
	for wall in course.active_walls:
		if wall.end.x + course.HALF.x > course.player.x:
			return wall.end.y + course.HALF.y + 0.01 if wall.position.y == 0.0 else wall.position.y - course.HALF.y - 0.01
	return 0.5

func run_route(id: String, step: int, config, strength: float, strategy: String, target_override: int = -1) -> Dictionary:
	var level = Level.for_id(id, step)
	var course = Course.new()
	course.apply_level_config(level)
	var stream = Stream.new(config)
	var tracker = Tracker.new()
	tracker.begin_session("balance", id, "replay", level.count_both_as_unwanted, step)
	tracker.begin_attempt(1)
	course.event_emitted.connect(tracker.record_event)
	var target_ms = level.hold_target_ms if target_override < 0 else target_override
	var longest_ms := 0
	var streak_ms := 0
	var total_ms := 0
	var ticks := 0
	var intensity := 0.0
	var zero_speed_hold_ms := 0
	var reached_zone := false
	while not course.finished and ticks < 12000:
		var target_y = route_target(course)
		var in_zone: bool = course.is_in_hold_zone()
		reached_zone = reached_zone or in_zone
		var first_wall: Rect2 = course.active_walls[0]
		var seeking: bool = strategy != "route" and longest_ms < target_ms and course.player.x > first_wall.end.x + course.HALF.x + 0.001
		if seeking and course.player.x < course.hold_zone.end.x:
			target_y = course.hold_zone.get_center().y
		var value = strength
		# Keep a strictly positive signal while increasing dwell time. This is
		# an analog strategy, intentionally unavailable to today's 0/1 UI pad.
		if strategy == "analog_hold" and seeking and in_zone:
			value = config.on_a + (1.0 - config.on_a) * minf(0.10, (strength - config.on_a) / (1.0 - config.on_a))
		var up: bool = course.player.y > target_y
		var command = stream.sample(value if up else 0.0, 0.0 if up else value)
		intensity = command.intensity
		if strength <= config.on_a:
			break
		if in_zone and command.state == &"ACTIVE" and command.intensity > 0.0 and not command.pause_required:
			streak_ms += DT_MS
			total_ms += DT_MS
			longest_ms = maxi(longest_ms, streak_ms)
		else:
			streak_ms = 0
		if in_zone and command.state == &"ACTIVE" and command.intensity == 0.0:
			zero_speed_hold_ms += DT_MS
		tracker.record_step(DT_MS, command, level.count_both_as_unwanted, in_zone, target_ms)
		course.advance(DT, command)
		ticks += 1
	var summary = tracker.build_summary()
	var result := {
		"id": id, "step": step, "strategy": strategy, "strength": strength,
		"on": config.on_a, "off": config.off_a, "intensity": intensity,
		"finished": course.finished, "inactive": ticks == 0 and intensity == 0.0,
		"seconds": ticks * DT, "hold_target_ms": target_ms, "hold_total_ms": total_ms,
		"hold_longest_ms": longest_ms, "goal_met": longest_ms >= target_ms,
		"zero_speed_hold_ms": zero_speed_hold_ms, "reached_zone": reached_zone,
		"tracker_hold_ms": summary.hold_in_target_ms,
	}
	course.free()
	return result

func probe_signals(variant: String, id: String, config) -> void:
	for channel in [0, 1]:
		var stream = Stream.new(config)
		var expected: StringName = &"OPEN" if channel == 0 else &"CLOSE"
		var command
		for value in [config.on_a - 0.02, config.on_a - 0.01]:
			command = stream.sample(value if channel == 0 else 0.0, value if channel == 1 else 0.0)
			check(command.state == &"REST", "%s %s channel=%d weak signal stays neutral" % [variant, id, channel])
		command = stream.sample(0.8 if channel == 0 else 0.0, 0.8 if channel == 1 else 0.0)
		check(command.direction == expected, "%s %s channel=%d activates" % [variant, id, channel])
		var moving := 0
		var retained := 0
		for i in range(40):
			var value = config.on_a + (-0.01 if i % 2 == 0 else 0.01)
			command = stream.sample(value if channel == 0 else 0.0, value if channel == 1 else 0.0)
			retained += int(command.direction == expected)
			moving += int(command.intensity > 0.0)
		check(retained == 40, "%s %s channel=%d jitter retains direction" % [variant, id, channel])
		check(moving == 20, "%s %s channel=%d jitter can still interrupt motion" % [variant, id, channel])
		command = stream.sample(config.off_a if channel == 0 else 0.0, config.off_a if channel == 1 else 0.0)
		check(command.state == &"REST", "%s %s channel=%d exact OFF releases" % [variant, id, channel])
		stream.sample(0.8 if channel == 0 else 0.0, 0.8 if channel == 1 else 0.0)
		var previous: StringName = &"ACTIVE"
		var transitions := 0
		var unexpected_states := 0
		for i in range(40):
			var value = (config.on_a + config.off_a) * 0.5 + (-0.04 if i % 2 == 0 else 0.04)
			command = stream.sample(value if channel == 0 else 0.0, value if channel == 1 else 0.0)
			transitions += int(command.state != previous)
			unexpected_states += int(command.state not in [&"ACTIVE", &"REST"])
			previous = command.state
		check(unexpected_states == 0, "%s %s channel=%d profile-relative noise produces valid states" % [variant, id, channel])
		report.signals.append({"variant": variant, "id": id, "channel": channel, "on": config.on_a, "off": config.off_a, "jitter_frames": 40, "retained_frames": retained, "moving_frames": moving, "midpoint_noise_amplitude": 0.04, "midpoint_noise_frames": 40, "midpoint_noise_state_changes": transitions})
	var recovery = Stream.new(config)
	check(recovery.sample(0.8, 0.8).state == &"BOTH", "%s %s opposing channels stop" % [variant, id])
	check(recovery.sample(0.8, 0.0).state == &"WAITING_NEUTRAL", "%s %s held input remains blocked" % [variant, id])
	check(recovery.sample(config.off_a, config.off_b).state == &"REST", "%s %s neutral recovers BOTH" % [variant, id])
	check(recovery.sample(0.0, 0.8).direction == &"CLOSE", "%s %s switching channels after neutral" % [variant, id])

func probe_stationary(variant: String, id: String, config) -> void:
	var stream = Stream.new(config)
	var course = Course.new()
	course.apply_level_config(Level.for_id(id))
	course.player = course.hold_zone.get_center()
	var before: Vector2 = course.player
	var tracker = Tracker.new()
	tracker.begin_session("stationary", id, "replay")
	stream.sample(0.8, 0.0)
	for i in range(200):
		var command = stream.sample((config.on_a + config.off_a) * 0.5, 0.0)
		tracker.record_step(DT_MS, command, true, course.is_in_hold_zone(), course.hold_target_ms)
		course.advance(DT, command)
	check(course.player == before, "%s %s no movement in hysteresis band" % [variant, id])
	var summary = tracker.build_summary()
	report.stationary.append({"variant": variant, "id": id, "active_seconds": course.active_seconds, "tracker_active_ms": summary.active_ms, "hold_score": summary.hold_accuracy_ratio()})
	var seconds: float = course.active_seconds
	for i in range(20):
		course.advance(DT, stream.sample(0.0, 0.0))
	check(course.player == before and course.active_seconds == seconds, "%s %s REST freezes motion and time" % [variant, id])
	course.free()

func probe_binary_bounds() -> void:
	# repair-3 has no wall whose expanded X extent intersects the hold zone.
	# Its X cannot stop/reverse in-zone under a digital ACTIVE command.
	for step in [-1, 0, 1]:
		var level = Level.for_id("repair-3", step)
		var course = Course.new()
		var no_obstruction := true
		for wall in level.walls:
			if wall.position.x - course.HALF.x <= level.hold_zone.end.x and wall.end.x + course.HALF.x >= level.hold_zone.position.x:
				no_obstruction = false
		var maximum_ms = 1000.0 * level.hold_zone.size.x / level.horizontal_speed
		report.binary_bounds.append({"id": "repair-3", "step": step, "no_x_obstruction": no_obstruction, "max_active_hold_ms": maximum_ms, "sample_slack_ms": DT_MS, "target_ms": level.hold_target_ms})
		check(no_obstruction, "final step=%d no wall can stop X inside hold zone" % step)
		check(maximum_ms + DT_MS < level.hold_target_ms, "final step=%d even digital upper bound falls short of target" % step)
		print("BINARY BOUND repair-3 step=%d maximum_ms=%.1f target_ms=%d" % [step, maximum_ms, level.hold_target_ms])
		course.free()
