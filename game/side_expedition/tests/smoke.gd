extends SceneTree
## --headless --path . --script res://game/side_expedition/tests/smoke.gd
## Optional GPU screenshots: same command without --headless, then -- --capture.

const Model = preload("res://game/side_expedition/expedition_model.gd")
const Scene = preload("res://game/side_expedition/quiet_signal.tscn")
const Config = preload("res://game/core/input_config.gd")
const Pipeline = preload("res://game/core/input_pipeline.gd")
const Source = preload("res://game/core/manual_input_source.gd")
const TrialChecks = preload("res://game/side_expedition/tests/trial_checks.gd")

var checks := 0
var failures := 0

class Stream:
	extends RefCounted
	var pipeline = Pipeline.new(Config.emulator_profile())
	var source = Source.new()
	var now := 0
	func _init() -> void:
		pipeline.begin_stream("manual_emulator")
		sample(0, 0)
		pipeline.request_resume(now)
	func sample(a: float, b: float, delta_ms: int = 50):
		now += delta_ms
		return pipeline.submit(source.sample(now, a, b), now)

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func snapshot(model) -> Array:
	return [model.stage, model.player, model.cursor, model.active_seconds, model.stage_seconds, model.wind, model.hold_seconds, model.collected_parts.duplicate(), model.adapter_step, model.battery_secured, model.location_id, model.destination_id, model.location_history.duplicate()]

func channels(model, strength: float) -> Vector2:
	if model.awaiting_neutral:
		return Vector2.ZERO
	if model.stage == "adapter":
		return Vector2(strength, 0) if Model.ADAPTER_SEQUENCE[model.adapter_step] == &"OPEN" else Vector2(0, strength)
	if model.stage == "salvage":
		if model.clamp.needs_neutral() or (model.clamp.pulse_seconds >= 0.25 and not model.clamp.neutral_seen):
			return Vector2.ZERO
		return Vector2(strength, 0) if model.cursor > model.target_value() else Vector2(0, strength)
	if model.stage == "power":
		if model.power.needs_neutral(): return Vector2.ZERO
		return Vector2(strength, 0) if model.power.expected_direction() == &"OPEN" else Vector2(0, strength)
	var target_y := 0.5
	if model.stage in ["outbound", "to_scout"]:
		for wall in Model.WALLS:
			if wall.end.x + Model.HALF.x > model.player.x:
				target_y = wall.end.y + Model.HALF.y + 0.035 if wall.position.y == 0.0 else wall.position.y - Model.HALF.y - 0.035
				break
	else:
		for i in range(Model.WALLS.size() - 1, -1, -1):
			var wall: Rect2 = Model.WALLS[i]
			if wall.position.x - Model.HALF.x < model.player.x:
				target_y = wall.end.y + Model.HALF.y + 0.035 if wall.position.y == 0.0 else wall.position.y - Model.HALF.y - 0.035
				break
	return Vector2(strength, 0) if model.player.y > target_y else Vector2(0, strength)

func route_checks() -> void:
	for dt in [0.016, 0.05, 0.20]:
		for strength in [0.65, 1.0]:
			var model = Model.new()
			var stream = Stream.new()
			var results: Array = []
			var stages: Array = []
			var locations: Array = []
			var points: Array = []
			var points_valid := true
			var goals_present := true
			var clamp_grades: Array = []
			model.expedition_completed.connect(func(result): results.append(result))
			model.stage_changed.connect(func(id): stages.append(id))
			model.location_entered.connect(func(id, line): locations.append([id, line]))
			model.begin("smoke-%.3f-%.2f" % [dt, strength])
			var loops := 0
			var tested_storm := false
			while model.stage != "complete" and loops < int(700.0 / dt):
				goals_present = goals_present and model.objective() != "" and model.entry_line != ""
				var point = model.interaction_point()
				if model.stage == "salvage" and clamp_grades.size() == model.collected_parts.size():
					clamp_grades.append(model.clamp.practice)
				if not point.is_empty():
					if not point.id in points: points.append(point.id)
					points_valid = points_valid and point.location_id == model.location_id and is_equal_approx(model.player.x, float(Model.LOCATIONS[model.location_id].x))
				if model.stage == "return" and not tested_storm:
					tested_storm = true
					var before := snapshot(model)
					model.advance(0.2, stream.sample(0, 0))
					check(snapshot(model) == before, "REST freezes return, battery, wind and time")
					model.advance(0.2, stream.sample(1, 1))
					check(snapshot(model) == before, "BOTH freezes the storm")
					var blocked = stream.sample(1, 0)
					check(blocked.state == &"WAITING_NEUTRAL", "held channel cannot escape BOTH")
					model.advance(0.2, blocked)
					check(snapshot(model) == before, "WAITING_NEUTRAL freezes storm")
					model.advance(0.2, stream.sample(0, 0))
				var input := channels(model, strength)
				var command = stream.sample(input.x, input.y, int(round(dt * 1000)))
				model.advance(dt, command)
				loops += 1
			var label := "dt=%.3f signal=%.2f" % [dt, strength]
			check(model.stage == "complete", label + " entire expedition passable")
			check(stages == Model.STAGES, label + " all stages in intended order")
			check(model.collected_parts.size() == 3 and model.adapter_built, label + " salvage precedes adapter")
			check(model.battery_secured and is_equal_approx(model.player.x, float(Model.LOCATIONS.airlock.x)), label + " battery returned to airlock")
			check(results.size() == 1, label + " completion delivered once")
			check(model.result().reward_proposal == [{"item_id": "emergency_battery", "amount": 1}], label + " host receives proposed reward")
			check(model.journal.size() == 8, label + " story beats retained")
			check(model.location_history == ["airlock", "debris", "scout", "debris", "airlock"], label + " exact three-point round trip")
			check(points == ["debris_parts", "field_workbench", "scout_power"] and points_valid, label + " interaction points belong to reached locations")
			check(locations.size() == 5 and goals_present, label + " location entry lines and stage goals exist")
			check(clamp_grades == [true, false, false], label + " difficulty increases only after first successful clamp")
			var done := snapshot(model)
			model.advance(1.0, stream.sample(1, 0))
			check(snapshot(model) == done and results.size() == 1, label + " finished model is immutable")
			var external = model.result()
			external.journal.clear()
			check(model.journal.size() == 8, label + " host cannot mutate internal journal")
			model.begin("retry")
			check(model.result().reward_proposal.is_empty() and not model.battery_secured and model.collected_parts.is_empty(), label + " replay clears local rewards")
			print("QUIET ROUTE ", label, " loops=", loops)
	var isolated = Model.new()
	var probe = Stream.new()
	isolated.begin("zero-intensity-fixture")
	isolated.stage = "power"
	isolated.cursor = 0.67
	probe.sample(0.8, 0)
	var stopped := snapshot(isolated)
	isolated.advance(1.5, probe.sample(0.49, 0))
	check(snapshot(isolated) == stopped, "zero intensity cannot farm stabilization or active time")
	isolated.stage = "adapter"
	isolated.adapter_step = 0
	isolated.advance(2.0, probe.sample(1, 0))
	check(isolated.adapter_step == 1 and isolated.awaiting_neutral, "one held signal cannot complete several adapter contacts")
	isolated.advance(1.0, probe.sample(0, 1))
	check(isolated.adapter_step == 1, "opposite channel without neutral cannot skip adapter barrier")
	isolated.advance(0.05, probe.sample(0, 0))
	isolated.advance(1.0, probe.sample(1, 0))
	check(isolated.adapter_step == 1 and not isolated.awaiting_neutral, "wrong channel cannot assemble next contact")

func host_checks(host) -> void:
	host.set_process(false)
	host.start_expedition("host-check")
	check(host._current.state == &"REST", "explicit start establishes neutral and resume")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_B
	event.pressed = true
	host._input._input(event)
	check(host._current.direction == &"CLOSE", "keyboard B goes through source and pipeline")
	event.pressed = false
	host._input._input(event)
	check(host._current.state == &"REST", "key release yields REST")
	host._input.set_touch_channels(1, 1)
	check(host._current.state == &"BOTH", "touch channels route through BOTH guard")
	host._input.set_touch_channels(1, 0)
	check(host._current.state == &"WAITING_NEUTRAL", "host preserves BOTH neutral barrier")
	host._input.clear()
	check(host._current.state == &"REST", "host BOTH recovers after neutral")
	host.set_foreground(false)
	check(host._current.state == &"SUSPENDED", "focus loss suspends pipeline")
	var before := snapshot(host.model)
	host.update_host(host._now(), 0.1)
	check(snapshot(host.model) == before, "background host cannot advance gameplay")
	host.set_foreground(true)
	host.update_host(host._now(), 0.05)
	check(host._current.state == &"WAITING_RESUME", "return requires explicit resume")
	host._input.set_touch_channels(1, 0)
	host.request_resume()
	check(host._current.state == &"WAITING_NEUTRAL", "held channel cannot resume after focus loss")
	host._input.clear()
	host.request_resume()
	check(host._current.state == &"REST", "neutral plus resume recovers focus loss")
	var future: int = host._pipeline._last_now_ms + 300
	host.update_host(future, 0.05, false)
	check(host._current.state == &"STALE", "host watchdog detects a silent stream")
	check(snapshot(host.model) == before, "stale stream cannot advance")
	host._origin = Time.get_ticks_msec() - future
	host._input.clear()
	check(host._current.state == &"WAITING_RESUME", "fresh neutral alone cannot escape timeout")
	host.request_resume()
	check(host._current.state == &"REST", "explicit resume restores timeout")
	host._toggle_hand()
	check(host._pad.mirrored, "left-hand pad mirrors")
	host._input.clear()
	host.request_resume()
	host._open_journal()
	check(host._journal.visible and host._current.pause_required, "reading journal pauses input")
	host._journal.hide()

func capture(host, name: String, viewport = null) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	host._refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://work/quiet_signal"))
	var path := "res://work/quiet_signal/%s.png" % name
	var target = root if viewport == null else viewport
	check(target.get_texture().get_image().save_png(path) == OK, "capture " + name)

func art_state(host, stage: String, entries: Array) -> void:
	# Explicit art fixture, separate from the actual playthrough assertions.
	host.model.stage = stage
	host.model.journal.assign(entries.slice(0, Model.STAGES.find(stage) + 1))
	var positions := {"outbound": Vector2(0.07, 0.50), "salvage": Vector2(0.40, 0.35), "adapter": Vector2(0.40, 0.35), "to_scout": Vector2(0.60, 0.35), "power": Vector2(0.91, 0.50), "return": Vector2(0.64, 0.68), "homebound": Vector2(0.36, 0.65), "complete": Vector2(0.07, 0.50)}
	host.model.player = positions[stage]
	host.model.battery_secured = stage in ["return", "homebound", "complete"]
	host.model.stage_seconds = 3.0
	host.model.wind = sin(2.1) * 0.035 if stage in ["return", "homebound"] else 0.0
	host.model.cursor = 0.65 if stage == "power" else 0.30
	host.model.adapter_step = 1
	host.model.clamp.begin(0.30, Model.PART_TARGETS[0], true)
	host.model.power.begin()
	var index: int = Model.STAGES.find(stage)
	var ids := ["airlock", "debris", "debris", "debris", "scout", "scout", "debris", "airlock"]
	var destinations := ["debris", "", "", "scout", "", "debris", "airlock", ""]
	host.model.location_id = ids[index]
	host.model.destination_id = destinations[index]
	var histories := [
		["airlock"], ["airlock", "debris"], ["airlock", "debris"], ["airlock", "debris"],
		["airlock", "debris", "scout"], ["airlock", "debris", "scout"],
		["airlock", "debris", "scout", "debris"], ["airlock", "debris", "scout", "debris", "airlock"],
	]
	host.model.location_history.assign(histories[index])
	host.model.entry_line = String(entries[index].body).split(".")[0] + "."
	if stage in ["salvage", "adapter", "power"]:
		host.model.player.x = Model.LOCATIONS[host.model.location_id].x
	host._refresh()

func _run() -> void:
	TrialChecks.new().run(check)
	route_checks()
	var host = Scene.instantiate()
	root.add_child(host)
	await process_frame
	await process_frame
	host_checks(host)
	host.start_expedition("between-frame-neutral-fixture")
	host.model.stage = "power"
	host.model.awaiting_neutral = false
	host.model.power.begin()
	host._input.clear()
	host._input.set_touch_channels(1, 0)
	host.model.advance(0.20, host._current)
	host._input.clear()
	host._input.set_touch_channels(0, 1)
	check(host.model.power.window_index == 1 and host.model.power.armed, "short delivered REST counts even between host frames")
	host.model.advance(0.30, host._current)
	check(host.model.power.phase == "neutral" and host.model.power.failures == 0, "correct between-frame switch does not cause false trial error")
	host.suspend_input()
	check(host.model.power.window_index == 1 and host.model.power.phase == "neutral", "pause cannot acknowledge a trial neutral window by clearing controls")
	host.start_expedition("pause-during-contact-fixture")
	host.model.stage = "power"
	host.model.awaiting_neutral = false
	host.model.power.begin()
	host._input.clear()
	host._input.set_touch_channels(1, 0)
	host.model.advance(0.05, host._current)
	var trial_time: float = host.model.power.elapsed
	host.suspend_input()
	check(host.model.power.failures == 0 and host.model.power.elapsed == trial_time, "pausing during short contact does not fail or advance trial")
	host.request_resume()
	host._input.clear()
	host.model.advance(0.20, host._current)
	check(host.model.power.failures == 0 and host.model.power.elapsed == trial_time, "resume may remain neutral without losing contact progress")
	var configured = Scene.instantiate()
	configured.input_config = Config.new(0.70, 0.50, 0.70, 0.50)
	configured.visible = false
	root.add_child(configured)
	configured.set_process(false)
	configured.start_expedition("custom-profile")
	configured._input.set_touch_channels(0.65, 0)
	check(configured._current.state == &"REST", "host respects supplied input profile")
	configured._input.set_touch_channels(0.8, 0)
	check(configured._current.direction == &"OPEN", "supplied profile still permits valid input")
	check(is_equal_approx(configured._pad.on_a, 0.70), "visual thresholds match supplied profile")
	configured.queue_free()
	var forwarded: Array = []
	var scene_locations: Array = []
	host.expedition_completed.connect(func(result): forwarded.append(result))
	host.location_entered.connect(func(id, _line): scene_locations.append(id))
	var host_stream = Stream.new()
	host.model.begin("host-completion")
	var host_loops := 0
	while host.model.stage != "complete" and host_loops < 5000:
		var values := channels(host.model, 1.0)
		host.model.advance(0.05, host_stream.sample(values.x, values.y))
		host_loops += 1
	check(forwarded.size() == 1 and forwarded[0].run_id == "host-completion", "scene forwards completed run exactly once")
	check(scene_locations == ["airlock", "debris", "scout", "debris", "airlock"], "scene forwards the full route to campaign host")
	host._on_completed(host.model.result())
	check(forwarded.size() == 1, "scene suppresses duplicate completion callback")
	var full_journal: Array = host.model.journal.duplicate(true)
	var exits: Array = []
	host.exit_requested.connect(func(result): exits.append(result))
	host.start_expedition("abort-check")
	host._on_exit()
	check(exits.size() == 1 and not exits[0].completed and exits[0].reward_proposal.is_empty(), "embedded exit has no reward before return")
	host.model.begin("layout-fixture")
	host._input.clear()
	host.request_resume()
	for dimensions in [Vector2i(1152, 648), Vector2i(648, 1152), Vector2i(640, 360)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await process_frame
		await process_frame
		host.model.journal.assign(full_journal)
		host._open_journal()
		await process_frame
		await process_frame
		check(host._journal.size.y <= dimensions.y and host._journal.size.x <= dimensions.x, "full journal fits " + str(dimensions))
		await capture(host, "journal-%dx%d" % [dimensions.x, dimensions.y], host._journal)
		host._journal.hide()
		host._input.clear()
		host.request_resume()
		for stage in Model.STAGES:
			art_state(host, stage, full_journal)
			await process_frame
			await process_frame
			check(host._pad.get_global_rect().end.y <= host.size.y + 1, "%s pad fits %s" % [stage, str(dimensions)])
			check(host._action.get_global_rect().end.y <= host.size.y + 1, "%s toolbar fits %s" % [stage, str(dimensions)])
			check(host._view.size.y >= 90, "%s world remains visible %s" % [stage, str(dimensions)])
		art_state(host, "outbound", full_journal)
		await capture(host, "outbound-%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1152, 648)
	root.content_scale_size = Vector2i(1152, 648)
	await process_frame
	# Art fixtures are synthetic states only; route_checks above use full playthroughs.
	for stage in ["salvage", "adapter", "to_scout", "power", "return", "homebound", "complete"]:
		art_state(host, stage, full_journal)
		await capture(host, stage)
	art_state(host, "power", full_journal)
	var art_stream = Stream.new()
	host.model.advance(0.05, art_stream.sample(0, 0))
	for i in range(4): host.model.advance(0.05, art_stream.sample(1, 0))
	check(host.model.power.phase == "neutral", "render fixture reaches neutral through core commands")
	await capture(host, "power-neutral")
	host.model.advance(0.05, art_stream.sample(0, 1))
	check(host.model.power.phase == "retry", "render fixture demonstrates retry after skipped neutral")
	await capture(host, "power-retry")
	art_state(host, "salvage", full_journal)
	host.model.clamp.begin(0.80, Model.PART_TARGETS[0], false)
	art_stream = Stream.new()
	for i in range(20): host.model.advance(0.05, art_stream.sample(1, 0))
	check(host.model.clamp.state == "retry", "render fixture demonstrates long-effort clamp error")
	await capture(host, "clamp-retry")
	host.queue_free()
	await process_frame
	print("QUIET SIGNAL SMOKE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
