extends RefCounted
## Runs from the expedition smoke entry point. All test signals pass InputPipeline.

const Clamp = preload("res://game/side_expedition/clamp_trial.gd")
const Power = preload("res://game/side_expedition/power_trial.gd")
const Config = preload("res://game/core/input_config.gd")
const Pipeline = preload("res://game/core/input_pipeline.gd")
const Source = preload("res://game/core/manual_input_source.gd")
const Command = preload("res://game/core/control_command.gd")
var _check: Callable

class Stream:
	extends RefCounted
	var pipeline = Pipeline.new(Config.emulator_profile())
	var source = Source.new()
	var now := 0
	func _init() -> void:
		pipeline.begin_stream("manual_emulator")
		sample(0, 0)
		pipeline.request_resume(now)
	func sample(a: float, b: float):
		now += 50
		return pipeline.submit(source.sample(now, a, b), now)

func check(value: bool, message: String) -> void:
	_check.call(value, "TRIAL " + message)

func run(callback: Callable) -> void:
	_check = callback
	clamp_checks()
	power_checks()
	blocked_checks()
	print("TRIAL CHECKS clamp/power/retries/blocked clocks complete")

func feed(trial, stream, a: float, b: float, seconds: float) -> void:
	for i in range(maxi(1, int(round(seconds / 0.05)))):
		trial.advance(0.05, stream.sample(a, b))

func clamp_clock(trial) -> Array:
	return [trial.position, trial.elapsed, trial.hold_seconds, trial.pulse_seconds]

func power_clock(trial) -> Array:
	return [trial.elapsed, trial.action_seconds, trial.release_seconds]

func complete_clamp(trial, stream) -> void:
	for i in range(1200):
		if trial.state == "done": break
		if trial.needs_neutral() or (trial.pulse_seconds >= 0.25 and not trial.neutral_seen):
			feed(trial, stream, 0, 0, 0.05)
		else:
			var up: bool = trial.position > trial.target
			feed(trial, stream, 1 if up else 0, 0 if up else 1, 0.05)

func clamp_checks() -> void:
	var clamp_trial = Clamp.new()
	var stream = Stream.new()
	clamp_trial.begin(0.80, 0.20, true)
	feed(clamp_trial, stream, 1, 0, 1.20)
	check(clamp_trial.state == "release" and clamp_trial.failures == 0, "practice long burst asks for rest without failure")
	check(clamp_trial.practice and clamp_trial.half_width >= 0.16, "practice stays wide after excessive effort")
	var paused := clamp_clock(clamp_trial)
	feed(clamp_trial, stream, 0, 0, 0.50)
	check(clamp_clock(clamp_trial) == paused, "clamp REST freezes movement and all timers")
	complete_clamp(clamp_trial, stream)
	check(clamp_trial.state == "done" and clamp_trial.pulses > 1, "short digital bursts and positional hold complete practice")
	var practice_width: float = clamp_trial.half_width
	var practice_limit: float = clamp_trial.pulse_limit
	clamp_trial.begin(0.80, 0.20, false)
	feed(clamp_trial, stream, 0, 0, 0.05)
	feed(clamp_trial, stream, 1, 0, 1.20)
	check(clamp_trial.state == "retry" and clamp_trial.failures == 1, "regular overlong effort fails only current clamp")
	check(clamp_trial.half_width < practice_width and clamp_trial.pulse_limit < practice_limit, "regular clamp is harder than practice")
	var stopped := clamp_clock(clamp_trial)
	feed(clamp_trial, stream, 1, 0, 0.50)
	check(clamp_clock(clamp_trial) == stopped and clamp_trial.failures == 1, "held input cannot repeat failures or run retry clock")
	feed(clamp_trial, stream, 0, 0, 0.05)
	complete_clamp(clamp_trial, stream)
	check(clamp_trial.state == "done" and clamp_trial.failures == 1, "clamp error permits successful retry")
	clamp_trial.begin(0.50, 0.50, false)
	feed(clamp_trial, stream, 0, 0, 0.05)
	feed(clamp_trial, stream, 1, 0, 0.60)
	check(clamp_trial.state == "retry" and "зоны" in clamp_trial.feedback, "leaving zone after hold began gives a clear retry")

func power_checks() -> void:
	var power_trial = Power.new()
	var stream = Stream.new()
	power_trial.begin()
	check(power_trial.phase == "cue" and power_trial.cue_serial == 1 and not power_trial.armed, "first signal is visible before window starts")
	feed(power_trial, stream, 0, 0, 0.50)
	check(power_trial.elapsed == 0.0 and power_trial.phase == "cue", "cue waits indefinitely in neutral without a running timer")
	feed(power_trial, stream, 0, 1, 0.05)
	check(power_trial.phase == "retry" and power_trial.window_index == 0, "wrong channel retries current window")
	check(power_trial.practice(), "wrong first attempt does not increase difficulty")
	feed(power_trial, stream, 0, 0, 0.05)
	feed(power_trial, stream, 1, 0, 0.25)
	check(power_trial.phase == "neutral" and power_trial.window_index == 0, "opening requires neutral acknowledgement before success")
	var first_grace: float = power_trial.release_grace()
	var stopped := power_clock(power_trial)
	feed(power_trial, stream, 0, 0, 0.50)
	check(power_clock(power_trial) == stopped, "neutral advances sequence without running any trial timer")
	check(power_trial.window_index == 1 and power_trial.cue_serial == 2, "next window has its own visible signal")
	check(not power_trial.practice() and power_trial.release_grace() < first_grace, "difficulty increases after first successful window")
	feed(power_trial, stream, 0, 1, 0.30)
	feed(power_trial, stream, 1, 0, 0.05)
	check(power_trial.phase == "retry" and power_trial.window_index == 1, "closing to opening without REST cannot skip neutral")
	feed(power_trial, stream, 0, 0, 0.05)
	feed(power_trial, stream, 0, 1, 0.30)
	feed(power_trial, stream, 0, 0, 0.05)
	check(power_trial.window_index == 2 and power_trial.cue_serial == 3, "retry retains earlier window and announces third")
	feed(power_trial, stream, 1, 0, 0.30)
	feed(power_trial, stream, 0, 0, 0.05)
	check(power_trial.phase == "done" and power_trial.window_index == 3, "OPEN neutral CLOSE neutral OPEN neutral completes block")
	power_trial.begin()
	feed(power_trial, stream, 0, 0, 0.05)
	feed(power_trial, stream, 1, 0, 0.05)
	feed(power_trial, stream, 0, 0, 0.05)
	check(power_trial.phase == "retry" and power_trial.failures == 1, "too-short contact is retryable")
	power_trial.begin()
	feed(power_trial, stream, 0, 0, 0.05)
	feed(power_trial, stream, 1, 0, 2.50)
	check(power_trial.phase == "retry" and power_trial.failures == 1, "ignoring neutral cue expires active-time window")

func blocked_checks() -> void:
	var clamp_trial = Clamp.new()
	var power_trial = Power.new()
	var stream = Stream.new()
	clamp_trial.begin(0.50, 0.50, true)
	power_trial.begin()
	feed(power_trial, stream, 0, 0, 0.05)
	var active = stream.sample(1, 0)
	clamp_trial.advance(0.05, active)
	power_trial.advance(0.05, active)
	for state in [&"BOTH", &"WAITING_NEUTRAL", &"WAITING_RESUME", &"SUSPENDED", &"STALE", &"INVALID", &"DISCONNECTED"]:
		var clamp_before := clamp_clock(clamp_trial)
		var power_before := power_clock(power_trial)
		var blocked = Command.new(&"REST", 0.0, state, &"fixture", true)
		clamp_trial.advance(2.0, blocked)
		power_trial.advance(2.0, blocked)
		check(clamp_clock(clamp_trial) == clamp_before, "clamp freezes under " + String(state))
		check(power_clock(power_trial) == power_before and power_trial.failures == 0, "power freezes without penalty under " + String(state))
	var clamp_before := clamp_clock(clamp_trial)
	var power_before := power_clock(power_trial)
	var paused = Command.new(&"OPEN", 1.0, &"ACTIVE", &"fixture", true)
	clamp_trial.advance(0.5, paused)
	power_trial.advance(0.5, paused)
	check(clamp_clock(clamp_trial) == clamp_before and power_clock(power_trial) == power_before, "pause_required cannot be bypassed by ACTIVE direction")
	var both = stream.sample(1, 1)
	power_trial.advance(0.50, both)
	check(power_clock(power_trial) == power_before, "real pipeline BOTH freezes active power window")
	power_trial.advance(0.50, stream.sample(1, 0))
	check(power_clock(power_trial) == power_before, "real pipeline BOTH barrier freezes window")
	power_trial.advance(0.05, stream.sample(0, 0))
	check(power_trial.failures == 0 and power_trial.phase == "act", "BOTH neutral recovery is not an early-release error")
	power_trial.advance(0.05, stream.pipeline.suspend())
	power_trial.advance(0.05, stream.sample(0, 0))
	check(power_trial.phase == "act" and power_trial.failures == 0, "fresh neutral still waits for explicit resume")
	power_trial.advance(0.05, stream.pipeline.request_resume(stream.now))
	check(power_clock(power_trial) == power_before and power_trial.failures == 0, "resumed neutral retains partial action without penalty")
	feed(power_trial, stream, 0, 0, 0.30)
	check(power_clock(power_trial) == power_before and power_trial.failures == 0 and power_trial.phase == "act", "neutral heartbeats after recovery do not invent an early-release error")
	feed(power_trial, stream, 1, 0, 0.20)
	check(power_trial.phase == "neutral", "correct input continues interrupted window")
	var zero = stream.sample(0.49, 0)
	check(zero.state == &"ACTIVE" and zero.intensity == 0.0, "pipeline retains a zero-effort hysteresis command")
	clamp_before = clamp_clock(clamp_trial)
	power_before = power_clock(power_trial)
	clamp_trial.advance(2.0, zero)
	power_trial.advance(2.0, zero)
	check(clamp_clock(clamp_trial) == clamp_before and power_clock(power_trial) == power_before, "zero effort cannot run either trial timer")
