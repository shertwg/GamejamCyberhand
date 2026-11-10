extends RefCounted
const Model = preload("res://game/side_expedition/expedition_model.gd")
const Ledger = preload("res://game/side_expedition/demo_ledger.gd")
const Pilot = preload("res://game/side_expedition/tests/demo_pilot.gd")
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
	_check.call(value, "EXPEDITION " + message)

func drive(model, exposed: bool = false, cache: bool = false, quick: bool = false, stop_stage: String = "complete") -> bool:
	var stream = Stream.new()
	for i in range(18000):
		if model.stage == stop_stage: return true
		var input := Pilot.channels(model, 1.0, exposed, cache, quick)
		model.advance(0.05, stream.sample(input.x, input.y))
	return false

func amount(result: Dictionary, id: String) -> int:
	for item in result.reward_proposal:
		if item.item_id == id: return int(item.amount)
	return 0

func run(callback: Callable) -> void:
	_check = callback
	weather_checks()
	reward_and_resume_checks()
	print("EXPEDITION CHECKS branches/weather/loot/checkpoints/receipts complete")

func weather_snapshot(model) -> Array:
	return [model.player, model.weather.clock, model.weather.phase, model.wind, model.inventory.duplicate(), model.knockbacks]

func weather_checks() -> void:
	var model = Model.new()
	model.begin("gust-fixture")
	model.stage = "to_scout"
	model.location_id = "debris"
	model.destination_id = "scout"
	model.route_choice = "exposed"
	model.inventory.conductive_scrap = 3
	model.player = Vector2(0.56, 0.60)
	model.last_shelter = Model.SHELTERS[1]
	model.weather.advance(model.weather.CALM)
	check(model.weather.phase == "warning" and "ПОРЫВ СКОРО" in model.weather.cue(), "readable warning precedes gust")
	var before := weather_snapshot(model)
	for state in [&"REST", &"BOTH", &"WAITING_NEUTRAL", &"WAITING_RESUME", &"SUSPENDED", &"STALE", &"INVALID", &"DISCONNECTED"]:
		model.advance(2.0, Command.new(&"REST", 0, state, &"fixture", true))
		check(weather_snapshot(model) == before, "weather and loot freeze under " + String(state))
	model.weather.advance(model.weather.WARNING - 0.01)
	var stream = Stream.new()
	model.advance(0.05, stream.sample(0, 1))
	check(model.knockbacks == 1 and model.player.distance_to(model.last_shelter) < 0.01, "unprotected player returns to last cover")
	check(model.inventory.conductive_scrap == 3, "gust preserves carried loot")
	model.player = Vector2(0.56, 0.60)
	model.advance(0.05, stream.sample(0, 1))
	check(model.knockbacks == 1, "same gust does not repeatedly knock back")
	model.begin("cover-fixture", {"first_delivery_done": true})
	model.stage = "to_scout"
	model.location_id = "debris"
	model.destination_id = "scout"
	model.route_choice = "exposed"
	model.rare_requested = true
	model.player = Model.SHELTERS[2]
	model.weather.advance(model.weather.CALM)
	before = weather_snapshot(model)
	for i in range(16): model.advance(0.05, stream.sample(1, 0))
	check(model.player == before[0] and model.weather.clock > before[1], "active waiting advances storm while shelter holds position")
	check(model.optional_note_found and model.rare_collected and model.inventory.rare_coil == 1, "shelter contains optional log and risky repeat loot")
	for i in range(20): model.advance(0.05, stream.sample(1, 0))
	check(model.inventory.rare_coil == 1 and model.knockbacks == 0, "cache cannot be collected twice and cover prevents knockback")
	var safe = Model.new()
	safe.begin("safe-route")
	check(drive(safe, false), "entire protected long route passable")
	check(safe.knockbacks == 0 and safe.route_choice == "safe", "safe branch never loses ground to gusts")
	var risk = Model.new()
	risk.begin("short-route")
	check(drive(risk, true, true), "entire exposed route with cover and log passable")
	check(risk.optional_note_found, "optional explanation can be found without blocking quest")
	check(risk.inventory.ceramic_coupler == 0 and risk.inventory.conductive_scrap == 2 and risk.adapter_built, "two component types consumed exactly once")

func reward_and_resume_checks() -> void:
	const PATH := "res://work/quiet-ledger-smoke.json"
	for path in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var ledger = Ledger.new(PATH)
	var model = Model.new()
	model.begin("first-receipt", ledger.context())
	check(drive(model, false, false, false, "scout_salvage"), "checkpoint reached after first resource point")
	check(model.inventory.conductive_scrap == 3 and model.inventory.ceramic_coupler == 0 and not model.adapter_built, "different sources gate craft")
	check(ledger.save_checkpoint(model.checkpoint()), "isolated demo checkpoint saved")
	ledger = Ledger.new(PATH)
	var resumed = Model.new()
	check(resumed.restore(ledger.checkpoint(), ledger.context()), "partial expedition restored")
	check(resumed.inventory == model.inventory and resumed.run_id == model.run_id, "resume preserves loot and receipt identity")
	check(drive(resumed, false, false, false, "power"), "restored expedition can gather second type and craft")
	var after_craft: Dictionary = resumed.checkpoint()
	var again = Model.new()
	check(again.restore(after_craft, ledger.context()), "exit after consuming craft ingredients is recoverable")
	check(again.adapter_built and again.inventory.ceramic_coupler == 0, "crafted adapter survives resume without paying twice")
	check(drive(again), "resumed post-craft run reaches home")
	var first: Dictionary = ledger.claim(again.result())
	check(first.ok and not first.already_claimed and first.result.first_clear, "first delivery creates large reward receipt")
	check(amount(first.result, "emergency_battery") == 1 and amount(first.result, "conductive_scrap") == 8, "first reward includes battery and large salvage bonus")
	var duplicate: Dictionary = ledger.claim(again.result())
	check(duplicate.ok and duplicate.already_claimed and ledger.pending_events().size() == 1, "double claim cannot create another reward")
	ledger = Ledger.new(PATH)
	check(ledger.context().first_delivery_done and ledger.pending_events().size() == 1, "claimed receipt and outbox survive application restart")
	check(ledger.acknowledge(first.result.reward_id) and ledger.pending_events().is_empty(), "campaign acknowledgement clears only delivery outbox")
	check(ledger.claim(again.result()).already_claimed, "acknowledged receipt still prevents duplicate award")
	var stale_result: Dictionary = again.result()
	stale_result.run_id = "parallel-old-context"
	stale_result.reward_id = "quiet_signal/parallel-old-context"
	var canonical: Dictionary = ledger.claim(stale_result)
	check(canonical.ok and not canonical.result.first_clear and amount(canonical.result, "conductive_scrap") == 3, "second run with stale context cannot receive first-clear bonus twice")
	var simple = Model.new()
	simple.begin("repeat-simple", ledger.context())
	check(drive(simple, false, false, true), "repeat player can bank simple loot and leave")
	check(not simple.battery_secured and simple.location_history == ["airlock", "debris", "airlock"], "simple choice skips risky wreck and returns home")
	check(amount(simple.result(), "conductive_scrap") == 3 and amount(simple.result(), "emergency_battery") == 0, "early return proposes only collected items")
	var repeat = Model.new()
	repeat.begin("repeat-rare", ledger.context())
	check(drive(repeat, true, true), "repeat risky branch with rare cache can be completed")
	var reward: Dictionary = ledger.claim(repeat.result())
	check(reward.ok and not reward.result.first_clear and amount(reward.result, "conductive_scrap") == 3 and amount(reward.result, "rare_coil") == 1, "repeat reward is smaller with optional rare loot")
	check(repeat.journal.any(func(entry): return entry.id == "repeat_supply") and not repeat.journal.any(func(entry): return entry.id == "old_log"), "scout's main recording is first-clear content")
	var fresh = Model.new()
	fresh.begin("new-after-abort", ledger.context())
	check(drive(fresh, true, false, false, "adapter") and fresh.inventory.conductive_scrap >= 1 and fresh.inventory.ceramic_coupler >= 1, "starting afresh respawns every required component")
	var broken: Dictionary = after_craft.duplicate(true)
	broken.adapter_built = false
	check(not Model.new().restore(broken), "invalid power checkpoint cannot bypass craft")
	broken = after_craft.duplicate(true)
	broken.last_shelter = [0.5, 0.5]
	check(not Model.new().restore(broken), "unknown cover is rejected instead of spawning inside obstacles")
	var file = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	ledger = Ledger.new(PATH)
	check(ledger.status == "recovered_bad_save" and not ledger.has_checkpoint(), "corrupted demo save recovers to a fresh playable state")
	const BAD_PATH := "res://work/quiet-ledger-directory"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BAD_PATH))
	var blocked = Ledger.new(BAD_PATH)
	var failed: Dictionary = blocked.claim(again.result())
	check(not failed.ok and blocked.data.claims.is_empty() and not blocked.context().first_delivery_done, "failed durable write does not consume or emit reward")
