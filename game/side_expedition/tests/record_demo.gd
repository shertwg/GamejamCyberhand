extends SceneTree
## Offline deterministic replay through the unchanged input core. No teleports,
## artificial quest completion, player profile, or campaign stock writes.
## Godot --write-movie <file>.avi --fixed-fps 24 --disable-vsync --path .
##       --script res://game/side_expedition/tests/record_demo.gd
const Scene = preload("res://game/side_expedition/quiet_signal.tscn")
const Pilot = preload("res://game/side_expedition/tests/demo_pilot.gd")
const Config = preload("res://game/core/input_config.gd")
const Pipeline = preload("res://game/core/input_pipeline.gd")
const Source = preload("res://game/core/manual_input_source.gd")
var host
var pipeline = Pipeline.new(Config.emulator_profile())
var source = Source.new()
var now := 0
var frame := 0
var rewards: Array = []
var trace: Array = []
var pause_frames := 18
var last_stage := ""
var last_power := ""
var last_cue := -1
var neutral_frames := 0
var reckless := false

func _initialize() -> void:
	call_deferred("_run")

func deliver(a: float, b: float, dt: float) -> void:
	now += maxi(1, int(round(dt * 1000)))
	var command = pipeline.submit(source.sample(now, a, b), now)
	host.model.observe_command(command)
	host.model.advance(dt, command)
	host._current = command
	host._foreground = true # offline replay, not native keyboard focus
	host._pad._values = Vector2(a, b)
	host._pad.queue_redraw()
	host._refresh()

func _run() -> void:
	root.size = Vector2i(960, 600)
	root.content_scale_size = Vector2i(960, 600)
	host = Scene.instantiate()
	host.persistence_enabled = false
	root.add_child(host)
	await process_frame
	host.set_process(false)
	host._input.enabled = false
	host._input.channels_changed.disconnect(host._on_channels)
	host._title.text = "ТИХИЙ СИГНАЛ · ДЕМО"
	host.expedition_completed.connect(func(result): rewards.append(result))
	pipeline.begin_stream("manual_emulator")
	now = 0
	pipeline.submit(source.sample(now, 0, 0), now)
	pipeline.request_resume(now)
	host.model.begin("recorded-demo-quiet-signal")
	while host.model.stage != "complete" and frame < 5000:
		var stage: String = host.model.stage
		if stage != last_stage:
			trace.append({"frame": frame, "stage": stage, "inventory": host.model.inventory.duplicate(), "cue": host.model.entry_line})
			last_stage = stage
			pause_frames = 12
		var dt := 1.0 / 15.0 if stage in ["outbound", "to_scout", "return", "homebound"] else 1.0 / 30.0
		var input := Pilot.channels(host.model, 1.0, true, true)
		if stage == "power":
			dt = 1.0 / 60.0
			if host.model.power.cue_serial != last_cue:
				last_cue = host.model.power.cue_serial
				pause_frames = 12
			if host.model.power.phase == "neutral" and last_power != "neutral": neutral_frames = 8
			last_power = host.model.power.phase
			if neutral_frames > 0:
				neutral_frames -= 1
				input = Vector2(1, 0) if host.model.power.expected_direction() == &"OPEN" else Vector2(0, 1)
		if stage == "return" and host.model.weather.phase == "warning" and host.model.current_shelter() < 0 and host.model.knockbacks == 0:
			reckless = true
		if reckless and host.model.knockbacks == 0: input = Vector2(0, 1)
		if pause_frames > 0:
			pause_frames -= 1
			input = Vector2.ZERO
		deliver(input.x, input.y, dt)
		frame += 1
		await process_frame
	if host.model.stage != "complete":
		push_error("Demo did not complete")
		quit(1)
		return
	deliver(0, 0, 0.0)
	host.claim_reward()
	host.claim_reward()
	host.acknowledge_reward(host.model.result().reward_id)
	for i in range(48):
		host._refresh()
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://game/side_expedition/evidence"))
	var report := {"kind": "automated real-command playthrough", "video_fps": 24, "navigation_simulation_step": 1.0 / 15.0, "trial_simulation_step": 1.0 / 30.0, "power_simulation_step": 1.0 / 60.0, "simulation_frames": frame, "trace": trace, "reward_events": rewards.size(), "result": host.model.result()}
	var file = FileAccess.open("res://game/side_expedition/evidence/demo-run.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("DEMO COMPLETE frames=%d reward_events=%d knockbacks=%d optional_note=%s" % [frame, rewards.size(), host.model.knockbacks, str(host.model.optional_note_found)])
	quit(0 if rewards.size() == 1 and host.model.battery_secured else 1)
