extends SceneTree
## Run: Godot 4.4.1 --headless --path . --script res://qa/prototype_smoke.gd
const Main = preload("res://game/main.tscn")
# This fixture only controls delivery. Production _process/update_host and
# notification handlers execute unchanged, driven by SceneTree frames.
class LifecycleHost:
	extends "res://game/gameplay/prototype.gd"
	var deliver_frames: bool = true
	var process_calls: int = 0

	func _process(delta: float) -> void:
		process_calls += 1
		super._process(delta)

	func _emit_frame(now_ms: int) -> void:
		if deliver_frames:
			super._emit_frame(now_ms)

var session
var now: int = 100
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func align_clock() -> void:
	now = maxi(now + 10, session._pipeline._last_now_ms + 10)
	session._origin_ms = Time.get_ticks_msec() - now

func frame(a: float, b: float, connected: bool = true) -> void:
	now += 50
	session._channel_a = a
	session._channel_b = b
	session._current = session._pipeline.submit(session._source.sample(now, a, b, connected), now)
	session._last_sample_ms = now

func step() -> void:
	now += 16
	session.update_host(now, 0.016, false)

func frozen(message: String) -> void:
	var position: Vector2 = session._course.player
	var seconds: float = session._course.active_seconds
	step()
	check(session._course.player == position, message + ": movement frozen")
	check(session._course.active_seconds == seconds, message + ": clock frozen")

func resume_neutral() -> void:
	frame(0, 0)
	check(session._current.state == &"WAITING_RESUME", "fault requires explicit resume")
	step()
	check(session._current.state == &"WAITING_RESUME", "host cannot automatically resume neutral input")
	align_clock()
	session._resume_button.pressed.emit()
	check(session._current.state == &"REST", "resume only grants REST")

func touch(index: int, pressed: bool, channel: int) -> void:
	align_clock()
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = session._pad.get_global_transform_with_canvas() * session._pad._pad_rect(channel).get_center()
	session._pad._input(event)

func capture(name: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://work/prototype")
	# Keep local evidence out of Godot imports and exported resources.
	var ignore := FileAccess.open("res://work/.gdignore", FileAccess.WRITE)
	ignore.close()
	root.get_texture().get_image().save_png("res://work/prototype/" + name + ".png")

# Await conditions with a bounded deadline instead of assuming a fixed FPS.
func wait_for(predicate: Callable, message: String) -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await create_timer(0.01).timeout
	check(predicate.call(), message)

func wait_ms(milliseconds: int) -> void:
	await create_timer(float(milliseconds) / 1000.0).timeout

func live_touch(host, index: int, pressed: bool, channel: int) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = host._pad.get_global_transform_with_canvas() * host._pad._pad_rect(channel).get_center()
	root.push_input(event, true)

func check_live_frozen(host, position: Vector2, seconds: float, message: String) -> void:
	check(host._course.player == position, message + ": position")
	check(host._course.active_seconds == seconds, message + ": timer")

func lifecycle_checks() -> void:
	# Keep the original deterministic core/route checks, then use a fresh live scene.
	session.get_parent().queue_free()
	await process_frame
	var host := LifecycleHost.new()
	root.add_child(host)
	await process_frame
	await process_frame
	var states: Array[StringName] = []
	host._pipeline.command_ready.connect(func(value): states.append(value.state))
	var initial_origin: int = host._origin_ms
	var initial_seq: int = host._source._next_seq
	await wait_ms(350)
	check(not host._playing and host._overlay.visible, "live start screen")
	check(host._source._next_seq > initial_seq, "real _process heartbeat on start screen")
	check(host._pipeline._last_now_ms >= 250, "real _process watchdog on start screen")
	check_live_frozen(host, Vector2(0.06, 0.5), 0.0, "start screen")
	states.clear()
	host._screen_button.pressed.emit()
	check(host._origin_ms > initial_origin, "delayed start resets origin")
	check(host._pipeline._last_seq == 0, "new round begins with seq zero")
	check(host._pipeline._last_timestamp_ms < host._profile.timeout_ms, "new round has fresh local timestamp")
	check(not states.has(&"STALE"), "delayed start has no false timeout")
	check(host._current.state == &"WAITING_RESUME", "live round needs explicit resume")
	await wait_ms(80)
	check(host._current.state == &"WAITING_RESUME", "real _process cannot auto resume")
	host._resume_button.pressed.emit()
	live_touch(host, 0, true, 1)
	await wait_for(func(): return host._course.active_seconds > 0.0, "real _process advances round")
	check(host._current.direction == &"CLOSE", "viewport touch reaches pipeline")
	# Silence the delivery point, not _process or watchdog.
	host.deliver_frames = false
	await wait_for(func(): return host._current.state == &"STALE", "live watchdog detects missing frames")
	var position: Vector2 = host._course.player
	var seconds: float = host._course.active_seconds
	await wait_ms(80)
	check_live_frozen(host, position, seconds, "live timeout")
	var fault_origin: int = host._origin_ms
	var fault_seq: int = host._source._next_seq
	host.deliver_frames = true
	await wait_for(func(): return host._current.state == &"WAITING_NEUTRAL", "held touch cannot recover timeout")
	live_touch(host, 0, false, 1)
	await wait_for(func(): return host._current.state == &"WAITING_RESUME", "live neutral after timeout")
	check(host._origin_ms == fault_origin and host._source._next_seq > fault_seq, "timeout recovery keeps origin and seq")
	host._resume_button.pressed.emit()
	# Exercise real notification dispatch, including repeated/mixed notifications.
	for focus in [true, false]:
		live_touch(host, 1, true, 0)
		await wait_for(func(): return host._current.state == &"ACTIVE", "active before lifecycle notification")
		var origin: int = host._origin_ms
		var seq: int = host._source._next_seq
		var out_event := MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT if focus else MainLoop.NOTIFICATION_APPLICATION_PAUSED
		var in_event := MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN if focus else MainLoop.NOTIFICATION_APPLICATION_RESUMED
		host.notification(out_event)
		host.notification(out_event)
		check(host._current.state == &"SUSPENDED", "notification suspends immediately " + str(focus))
		check(host._pad._values == Vector2.ZERO and host._channel_a == 0 and host._channel_b == 0, "notification clears held input")
		position = host._course.player
		seconds = host._course.active_seconds
		var calls: int = host.process_calls
		await wait_ms(350)
		check(host.process_calls > calls and host._current.state == &"STALE", "real _process watchdog while externally paused")
		check(host._source._next_seq == seq, "no frames generated while externally paused")
		check_live_frozen(host, position, seconds, "external pause")
		if not focus:
			# An OS-stopped application receives no _process calls. Resume must still
			# recover safely; no background worker or catch-up is expected.
			host.set_process(false)
			await wait_ms(350)
			host.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
			host.notification(in_event)
			check(not host._foreground, "resume cannot cancel outstanding focus loss")
			host.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
			host.set_process(true)
		else:
			host.notification(in_event)
		host.notification(in_event)
		await wait_for(func(): return host._current.state == &"WAITING_RESUME", "return waits for explicit resume")
		await wait_ms(80)
		check_live_frozen(host, position, seconds, "after return before resume")
		check(host._origin_ms == origin and host._source._next_seq > seq, "lifecycle recovery keeps origin and seq")
		host._resume_button.pressed.emit()
		check(host._current.state == &"REST", "explicit lifecycle resume grants REST")
	# Reaching the finish still goes through production advance -> completed -> UI.
	host._course.player = Vector2(0.939, 0.8)
	live_touch(host, 2, true, 1)
	await wait_for(func(): return not host._playing, "live completion enters result")
	check(host._course.finished and host._overlay.visible, "live result is visible")
	seconds = host._course.active_seconds
	position = host._course.player
	var result_seq: int = host._source._next_seq
	var result_origin: int = host._origin_ms
	await wait_ms(350)
	check(host._source._next_seq > result_seq, "real _process heartbeat on result")
	check_live_frozen(host, position, seconds, "result screen")
	states.clear()
	host._screen_button.pressed.emit()
	check(host._origin_ms > result_origin and host._pipeline._last_seq == 0, "retry resets stream origin and seq together")
	check(not states.has(&"STALE") and host._current.state == &"WAITING_RESUME", "delayed retry has no false timeout or auto resume")
	check_live_frozen(host, Vector2(0.06, 0.5), 0.0, "retry resets course")
	host.queue_free()
	await process_frame
	print("LIFECYCLE live SceneTree process/notifications checks complete")

## Every mission at every adaptation step must be passable with full-intensity commands.
func mission_route_checks() -> void:
	var Level = load("res://game/core/level_config.gd")
	var CourseScript = load("res://game/gameplay/course.gd")
	var Cmd = load("res://game/core/control_command.gd")
	for level_id in Level.ordered_ids():
		for step in [-1, 0, 1]:
			var course = CourseScript.new()
			var events: Array = []
			course.event_emitted.connect(func(e): events.append(e.event_type))
			course.apply_level_config(Level.for_id(level_id, step), "route", 1)
			var hold_ms := 0
			var loops := 0
			while not course.finished and loops < 4000:
				var target_y := 0.5
				for wall in course.active_walls:
					if wall.end.x + course.HALF.x > course.player.x:
						target_y = 0.88 if wall.position.y <= 0.0 else 0.12
						break
				var up: bool = course.player.y > target_y
				var command = Cmd.new(Cmd.OPEN if up else Cmd.CLOSE, 1.0, &"ACTIVE", &"route", false)
				course.advance(0.05, command)
				if course.is_in_hold_zone():
					hold_ms += 50
				loops += 1
			var label := "%s step %d" % [level_id, step]
			check(course.finished, label + " passable")
			check(events.has(&"level_completed"), label + " emits level_completed")
			check(events.count(&"action_started") == 1, label + " single action_started")
			course.free()
	var steps_explain = Level.evaluate_adaptation(0, 2, 0, true)
	check(steps_explain["changed"] and steps_explain["step"] == 1, "adaptation steps up after 2 clean")
	check(Level.evaluate_adaptation(1, 5, 0, true)["step"] == 1, "adaptation bounded at +1")
	check(Level.evaluate_adaptation(0, 0, 2, true)["step"] == -1, "adaptation steps down after 2 struggles")
	check(not Level.evaluate_adaptation(0, 2, 0, false)["changed"], "adaptation can be disabled")
	print("MISSION ROUTES checked")


func _run() -> void:
	# Isolated profile: never touch the player's real user:// progress.
	const SMOKE_STORE := "user://smoke_profile_v1.json"
	if FileAccess.file_exists(SMOKE_STORE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SMOKE_STORE))
	load("res://game/gameplay/prototype.gd").store_path_override = SMOKE_STORE
	root.add_child(Main.instantiate())
	await process_frame
	await process_frame
	session = root.get_child(root.get_child_count() - 1).get_child(0)
	session.set_process(false)
	check(session._overlay.visible and not session._playing, "start screen")
	check(session._level_id == "tutorial", "fresh profile starts with tutorial")
	# Route controller below is tuned to repair-1 baseline geometry.
	session.select_level("repair-1")
	check(session._level_id == "repair-1", "repair-1 open on fresh profile")
	session.select_level("repair-3")
	check(session._level_id == "repair-1", "locked mission cannot be selected")
	await capture("start")
	align_clock()
	session._screen_button.pressed.emit()
	await process_frame
	await process_frame
	check(session._playing, "start enters game")
	check(session._current.state == &"WAITING_RESUME", "startup barrier")
	frozen("startup")
	resume_neutral()
	var last_seq: int = session._source._next_seq
	now += 50
	session.update_host(now, 0.05)
	check(session._source._next_seq == last_seq + 1, "host heartbeat with unchanged channels")
	frozen("heartbeat neutral")
	# Actual manual pad -> ManualInputSource -> pipeline -> course.
	touch(0, true, 0)
	check(session._current.direction == &"OPEN", "touch A becomes OPEN")
	var previous: Vector2 = session._course.player
	step()
	check(session._course.player.x > previous.x and session._course.player.y < previous.y, "OPEN forward and up")
	touch(1, true, 1)
	check(session._current.state == &"BOTH", "two independent touches produce BOTH")
	frozen("BOTH")
	touch(0, false, 0)
	check(session._current.state == &"WAITING_NEUTRAL", "remaining held B blocked")
	frozen("BOTH held B")
	touch(1, false, 1)
	check(session._current.state == &"REST", "BOTH neutral recovery without resume")
	frozen("REST")
	touch(1, true, 1)
	check(session._current.direction == &"CLOSE", "touch B becomes CLOSE")
	previous = session._course.player
	step()
	check(session._course.player.y > previous.y, "CLOSE down")
	touch(1, false, 1)
	# Mouse is a second desktop entry point into the same adapter.
	align_clock()
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = session._pad.get_global_transform_with_canvas() * session._pad._pad_rect(0).get_center()
	session._pad._input(mouse)
	check(session._current.direction == &"OPEN", "desktop mouse press")
	mouse.pressed = false
	align_clock()
	session._pad._input(mouse)
	check(session._current.state == &"REST", "desktop mouse release")
	touch(3, true, 0)
	align_clock()
	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.position = Vector2(-100, -100)
	session._pad._input(drag)
	check(session._current.state == &"REST", "drag outside releases touch")
	touch(4, true, 1)
	align_clock()
	var canceled := InputEventScreenTouch.new()
	canceled.index = 4
	canceled.canceled = true
	session._pad._input(canceled)
	check(session._current.state == &"REST", "OS canceled touch releases channel")
	frame(1, 0)
	now += 250
	session.update_host(now, 0.25, false)
	check(session._current.state == &"STALE", "watchdog without incoming frames")
	frozen("STALE")
	frame(1, 0)
	session._current = session._pipeline.request_resume(now)
	check(session._current.state == &"WAITING_NEUTRAL", "held input cannot resume after timeout")
	resume_neutral()
	# Expired neutral cannot authorize recovery, even without another packet.
	session._pipeline.suspend()
	frame(0, 0)
	now += 250
	session._current = session._pipeline.request_resume(now)
	check(session._current.state == &"STALE", "expired neutral rejects resume")
	frozen("expired neutral")
	resume_neutral()
	frame(1, 0, false)
	check(session._current.state == &"DISCONNECTED", "disconnected source")
	frozen("DISCONNECTED")
	resume_neutral()
	now += 10
	session._current = session._pipeline.submit({"bad": true}, now)
	check(session._current.state == &"INVALID", "malformed frame")
	frozen("INVALID")
	frame(1, 1)
	frame(1, 0)
	frozen("BOTH cannot release fault barrier")
	resume_neutral()
	frame(1, 0)
	session.set_foreground(false)
	check(session._current.state == &"SUSPENDED", "focus loss suspends pipeline")
	frozen("background")
	now += 250
	session.update_host(now, 0.25, false)
	check(session._current.state == &"STALE", "watchdog keeps ticking during suspension")
	frozen("background timeout")
	session.set_foreground(true)
	frame(1, 0)
	frozen("foreground held input")
	resume_neutral()
	# Show a game capture after recovery; check container bounds at multiple aspects.
	await capture("game-landscape")
	for resolution in [Vector2i(1152, 648), Vector2i(1440, 648), Vector2i(648, 1152)]:
		root.size = resolution
		root.content_scale_size = resolution
		await process_frame
		await process_frame
		check(session._pad.get_global_rect().end.y <= session._root.size.y, "pad fits " + str(resolution))
		check(session._pad.get_global_rect().end.x <= session._root.size.x, "pad fits horizontally " + str(resolution))
		check(session._pad.size.x > 500, "pad readable width " + str(resolution))
		check(session._course.size.y >= 130, "course readable height " + str(resolution))
	await capture("game-portrait")
	# Route controller is test-only: all motion still passes through source/pipeline.
	var loops := 0
	while session._playing and loops < 1600:
		var point: Vector2 = session._course.player
		var target_y := 0.80
		if point.x > 0.35 and point.x < 0.59:
			target_y = 0.20
		frame(1 if point.y > target_y else 0, 0 if point.y > target_y else 1)
		session.update_host(now, 0.05, false)
		check(not session._course._collides(session._course.player), "route stays outside walls")
		loops += 1
	check(not session._playing and session._overlay.visible, "route reaches result")
	check(session._course.finished, "completion latched")
	check(session._course.active_seconds > 10, "active time recorded")
	check("repair-2" in session._save["unlocked_levels"], "completing repair-1 unlocks repair-2")
	check(session._next_button.visible, "next mission offered on result")
	var stored: Dictionary = session._store.load_profile()
	check(session._store.last_load_status == &"ok", "profile saved and reloaded")
	check(int(stored["last_summary"].get("attempts", 0)) >= 1, "summary persisted with attempts")
	check(stored["last_summary"].get("level_id", "") == "repair-1", "summary level_id persisted")
	var corrupt := FileAccess.open("user://smoke_corrupt_v1.json", FileAccess.WRITE)
	corrupt.store_string("{not json")
	corrupt.close()
	var corrupt_store = load("res://game/core/local_store.gd").new("user://smoke_corrupt_v1.json")
	var recovered: Dictionary = corrupt_store.load_profile()
	check(corrupt_store.last_load_status == &"corrupted_recovered", "corrupted save recovers")
	check(recovered["unlocked_levels"] == ["tutorial", "repair-1"], "corrupted save falls back to defaults")
	var completed_time: float = session._course.active_seconds
	frame(1, 0)
	step()
	check(session._course.active_seconds == completed_time, "result freezes time")
	await capture("result")
	align_clock()
	session._screen_button.pressed.emit()
	check(session._course.player == Vector2(0.06, 0.5), "retry resets position")
	check(session._course.active_seconds == 0, "retry resets time")
	check(session._current.state == &"WAITING_RESUME", "retry does not bypass resume")
	await lifecycle_checks()
	mission_route_checks()
	print("PROTOTYPE SMOKE checks=%d failures=%d route_steps=%d" % [checks, failures, loops])
	quit(0 if failures == 0 else 1)
