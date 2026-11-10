extends SceneTree
## Drives the actual campaign controls and feeds samples through the real decoder.
const Main = preload("res://game/main.tscn")
const State = preload("res://game/station/station_state.gd")
const Navigation = preload("res://game/gameplay/deck_navigation.gd")
const Opening = preload("res://game/ui/opening_timeline.gd")
const GardenPlots = preload("res://game/ui/garden_plots.gd")
const ExpeditionPilot = preload("res://game/side_expedition/tests/demo_pilot.gd")
var host
var scene
var model: State
var checks := 0
var errors := 0
var now := 0
var fixture := ""

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		errors += 1
		push_error(message)

func _run() -> void:
	fixture = "user://campaign_smoke_%d" % OS.get_process_id()
	SessionCoordinator.store_path_override = fixture + "_profile.json"
	root.content_scale_size = Vector2i(1152,648)
	root.size = Vector2i(1152,648)
	var main := Main.instantiate()
	root.add_child(main)
	await process_frame
	host = main.get_child(0)
	host.set_process(false)
	host._game_view.set_process(false)
	scene = host._game_view.campaign
	scene.set_process(false)
	model = host._game_view.station
	model.path = fixture + "_station.json"
	check(scene.mode == "intro" and scene.art.shot == 0, "fresh game starts in orbit")
	check(not scene._supplies.visible, "supplies HUD leaves cinematic frames clear")
	check(absf(scene.sound.OPENING_MIX.get_length() - Opening.DURATION) < 0.08,
		"opening mix and cut timeline share their duration")
	scene._process(1.3)
	await capture("orbit")
	var stopped: float = scene._intro_clock
	scene.foreground = false
	scene._process(3.0)
	var audio_paused: bool = DisplayServer.get_name() == "headless" or scene.sound._opening.stream_paused
	check(scene._intro_clock == stopped and audio_paused, "opening video and audio pause together")
	scene.foreground = true
	var labels := ["orbit", "opening-cockpit", "opening-failure", "opening-reentry", "opening-descent", "fall", "opening-aftermath"]
	for index in range(1, Opening.SHOTS.size()):
		var offset := 2.45 if index == 5 else 1.3
		scene._process(Opening.TIMECODES[index] + offset - scene._intro_clock)
		check(scene.art.shot == Opening.SHOTS[index], "opening camera cut %d follows timeline" % index)
		await capture(labels[index])
	scene._process(Opening.DURATION + 0.02 - scene._intro_clock)
	check(scene.mode == "room" and scene.room == 0 and model.data.intro_seen, "crash cuts end inside the cabin")
	check(not scene.sound._opening.playing, "opening audio stops in playable cabin")
	check(scene._supplies.visible, "supply bars visible in playable cabin")
	host._game_view._process(60.0)
	check(is_equal_approx(model.supply("water"), 64.0), "tutorial grace period preserves reserves")
	check(not scene._right.visible, "airlock blocks the corridor before repair")
	var gait := Navigation.new()
	gait.enter(6,0)
	gait.walk_to(Vector2(320,200))
	var start_contact := gait.footfall
	for frame in range(60): gait.advance(1.0/60.0)
	check(gait.footfall - start_contact in [2,3], "one second of walking emits two to three foot contacts")
	for frame in range(300): gait.advance(1.0/60.0)
	var stopped_contact := gait.footfall
	for frame in range(60): gait.advance(1.0/60.0)
	check(not gait.moving and gait.footfall == stopped_contact, "stationary feet make no additional contacts")
	await capture("cabin")
	scene.nav.walk_to(Vector2(6,66))
	settle()
	check(scene.nav.on_floor(scene.nav.feet) and scene.nav.feet.y >= 176.0, "walk target snaps away from hull wall")
	var before: Vector2 = scene.nav.feet
	await process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var frame: Rect2 = scene.art.frame_rect()
	click.position = frame.position + frame.size * Vector2(0.57,0.94)
	root.push_input(click)
	settle()
	check(scene.nav.feet.distance_to(before) > 30.0 and scene.nav.on_floor(scene.nav.feet), "viewport click moves the hero along the floor")
	use("job")
	check(scene.mode == "repair" and scene._resume.visible, "first repair requires explicit resume")
	await capture("airlock")
	host.request_resume()
	now = host._now_ms()
	sample(1,1,12)
	check(host.repair_task.active_seconds == 0.0, "BOTH cannot move or score the device")
	sample(0,0,5)
	turn_valve(2)
	check(model.data.air_ready and scene._right.visible, "airlock repair opens the hall")
	check(scene.world.next_objective()[0] == 1 and scene._right.text.ends_with("◆"),
		"route highlights the next pump stop")
	var energy := model.supply("energy")
	host._game_view._process(60.0)
	check(is_equal_approx(model.supply("energy"), energy - 6.0)
		and is_equal_approx(model.supply("water"), 59.0)
		and is_equal_approx(model.supply("food"), 49.0), "one minute consumes 6/5/4 points in the ship")
	check(model.data.water == 0 and model.data.food == 0, "life support does not consume crafting cargo")
	host.set_foreground(false)
	host._game_view._process(60.0)
	check(is_equal_approx(model.supply("water"), 59.0), "background does not drain supplies")
	host.set_foreground(true)
	go(1)
	var before_replay_water: int = model.data.water
	scene._bag.pressed.emit()
	scene._replay.pressed.emit()
	check(scene.mode == "intro", "saved game can replay the opening from inventory")
	host._game_view._process(60.0)
	check(not scene._supplies.visible and is_equal_approx(model.supply("water"), 59.0), "replaying intro pauses supplies")
	scene._action.pressed.emit()
	check(scene.mode == "room" and scene.room == 1 and model.data.water == before_replay_water,
		"skipping replay returns to the same room with progress")
	await capture("coolant")
	use("job")
	host._game_view._process(6.0)
	check(is_equal_approx(model.supply("water"), 58.5)
		and host.repair_task.active_seconds == 0.0, "repair keeps supply time separate from gesture time")
	await capture("valve")
	activate_input()
	sample(0,1,35)
	check(host.repair_task.mistakes == 1 and host.repair_task._pressure_hold == 0.0
		and model.data.water == 0, "pressure overshoot vents without docking cargo")
	turn_valve(3)
	check(model.data.water == 3 and model.data.pump, "pump adds water")
	check(is_equal_approx(model.supply("water"), 82.5), "pump also refills the ship water meter")
	go(3)
	use("garden")
	check(not model.plant(2, "berries"), "berries require an upgraded greenhouse")
	use("plant")
	model.advance(18, false)
	check(model.data.beds[0] == 0, "crops stay paused when game is inactive")
	model.advance(18,true)
	await capture("biosad")
	use("harvest")
	check(model.data.food == 2, "first crop feeds construction")
	check(is_equal_approx(model.supply("food"), 74.6), "harvest feeds life support and adds cargo")
	go(2)
	check(scene._scrap.visible and scene._verb == "fuses", "salvage remains available beside the proposed craft")
	use("fuses")
	check(model.data.fuses == 1, "bench crafts a fuse from parts and charge")
	await salvage(true)
	await salvage()
	go(4)
	use("generator")
	use("job")
	await capture("phase")
	activate_input()
	sample(0,1,1)
	check(host.repair_task._stage == 0, "early brake cannot lock phase")
	phase_lock()
	check(model.data.energy >= 4 and "repair-3" in scene.unlocked, "reactor reward unlocks radio")
	go(2)
	use("coils")
	check(model.data.fuses == 0 and model.data.coils == 1, "coil uses crafted fuse")
	await salvage()
	await salvage()
	go(5)
	use("beacon")
	check(model.data.beacon and model.data.coils == 0, "antenna consumes the coil")
	check(scene._verb != "job", "radio waits for the off-ship relay")
	go(6)
	collect(0)
	use("filter")
	go(7)
	var exterior_water := model.supply("water")
	host._game_view._process(60.0)
	check(is_equal_approx(model.supply("water"), exterior_water - 8.0), "exterior heat increases water usage")
	await capture("ravine")
	collect(0)
	collect(0)
	check(scene.world.data.ore == 2, "deposits cannot be harvested twice immediately")
	collect(1)
	check(scene.world.data.ore >= 3, "ravine supplies ore")
	var ore_before: int = scene.world.data.ore
	scene.nav.walk_to(Vector2(165,200))
	settle()
	scene._shift_time = 7.72
	scene._update_storm()
	check(scene.nav.feet.x < 100.0 and scene.world.data.ore == ore_before, "storm sends player to cover without losing loot")
	go(8)
	collect(0)
	check(scene.world.data.silica == 0, "crystals need drill calibration")
	use("job")
	await capture("drill")
	activate_input()
	for i in range(4):
		sample(1 if i % 2 == 0 else 0,0 if i % 2 == 0 else 1,37)
		sample(0,0,6)
	check(scene.world.data.extractor and not host._playing, "four distinct drill holds unlock extraction")
	collect(0)
	await capture("cave")
	scene._map_button.pressed.emit()
	check(scene._map.visible and not scene._map._nodes[2].disabled and scene._map._nodes[9].disabled, "map distinguishes visited and locked rooms")
	check(scene._map._nodes[2].text.begins_with("◆"), "map guides a stocked expedition back to the workshop")
	await capture("map")
	scene._map._nodes[2].pressed.emit()
	check(scene.room == 2 and not scene._map.visible, "map backtracks to the discovered workshop")
	use("alloy")
	use("shield")
	check(scene.world.data.shield and scene.world.data.alloy == 0, "two-stage crafting makes shield")
	go(9)
	use("job")
	await capture("relay")
	activate_input()
	sample(1,0,99)
	check(host.repair_task.mistakes > 0 and host.repair_task._stage == 0, "storm surge resets an unlatched stage")
	for stage in range(3):
		for i in range(110):
			if not host._playing or absf(host.repair_task._value - host.repair_task._center) < 0.023: break
			sample(1,0,1)
		sample(0,0,2)
		sample(0,1,1)
		sample(0,0,2)
	check(scene.world.data.relay and not model.data.signal and not host._playing, "three phase locks open ship radio without faking the final signal")
	go(5)
	use("job")
	await capture("radio")
	activate_input()
	for i in range(160):
		if not host._playing: break
		var error: float = host.repair_task._value - host.repair_task._center
		sample(1 if error > 0.045 else 0, 1 if error < -0.045 else 0, 1)
	if scene.mode == "chapter": scene._finish_cut()
	check(model.data.signal and scene.mode == "room", "radio rewards sustained tracking of a moving target")
	go(1)
	use("job")
	activate_input()
	turn_valve(3)
	go(3)
	use("plant")
	use("plant")
	model.advance(18,true)
	use("harvest")
	use("harvest")
	go(2)
	for i in range(3): await salvage()
	go(0)
	use("launch")
	check(scene.mode == "takeoff" and model.data.launched, "completed supply chain triggers takeoff")
	await capture("takeoff")
	scene._finish_cut()
	if scene.mode == "chapter": scene._finish_cut()
	var saved := State.new(model.path)
	check(saved.data.launched and saved.data.air_ready and saved.data.intro_seen and saved.data.expedition.relay, "progress reloads")
	check(is_equal_approx(saved.supply("water"), model.supply("water")), "life support loads from the normal save")
	var stock_before := int(model.data.energy)
	host._game_view._process(2400.0)
	check(model.supply("energy") == 0.0 and model.supply("food") == 0.0 and model.economy_mode(), "depleted supplies clamp and trigger economy mode")
	check(model.data.energy == stock_before, "running dry never removes cargo")
	scene._supplies._process(2.0)
	await capture("life-support-low")
	var spent := State.new(model.path)
	check(spent.supply("energy") == 0.0, "drain is periodically saved without another action")
	go(1)
	use("job")
	activate_input()
	turn_valve(3)
	check(model.supply("water") == 24.0, "pump can recover water from empty without stock")
	go(8)
	collect(1)
	go(2)
	scene._bag.pressed.emit()
	check(scene._cell.visible and not scene._cell.disabled, "battery becomes available after field collection")
	scene._cell.pressed.emit()
	check(model.supply("energy") == 27.0, "crafted battery restores power")
	var charge_before := int(model.data.energy)
	check(not scene._refill_buttons.energy.disabled and scene._refill_buttons.food.disabled,
		"inventory offers stored charge but cannot transfer absent food")
	scene._refill_buttons.energy.pressed.emit()
	check(model.data.energy == charge_before - 1 and model.supply("energy") == 36.0,
		"spending stored charge restores the meter exactly once")
	scene._supplies._process(2.0)
	await capture("life-support-stock")
	scene._bag.pressed.emit()
	go(3)
	use("plant")
	host._game_view._process(0.1)
	check(is_equal_approx(model.data.beds[0], 0.08), "economy slows growth without stopping it")
	model.advance(18.0,true)
	use("harvest")
	scene._bag.pressed.emit()
	check(scene._greenhouse_upgrade.visible and not scene._greenhouse_upgrade.disabled, "first harvest and salvage unlock the greenhouse upgrade")
	scene._greenhouse_upgrade.pressed.emit()
	check(model.data.garden_level == 2 and model.data.food == 0, "greenhouse upgrade spends cargo")
	scene._bag.pressed.emit()
	use("plant")
	model.advance(18.0,true)
	use("harvest")
	check(model.data.food == 3 and model.supply("food") > 64.0, "upgraded greenhouse yields three portions and 39 life support points")
	scene._seed_picker.pressed.emit()
	var water_before := int(model.data.water)
	await tap_plot(2)
	check(model.data.crops[2] == "berries" and model.data.beds[2] == 0.0 and model.data.water == water_before - 2,
		"touching the third tray plants the selected crop there")
	await tap_plot(2)
	check(model.data.water == water_before - 2, "touching a growing tray cannot spend water twice")
	model.advance(18.0,true)
	check(State.new(model.path).grow_seconds(2) == 32.0 and model.ripe_bed() == -1,
		"berry identity survives reload and does not ripen at the green crop duration")
	model.advance(14.0,true)
	await capture("biosad-berries")
	await tap_plot(2)
	check(model.data.beds[2] == -1.0 and model.data.food == 7 and scene.art.garden.reward_yield == 4,
		"ripe berries grant four food and play the harvest feedback")
	await capture("biosad-harvest")
	root.content_scale_size = Vector2i(648,1152)
	root.size = Vector2i(648,1152)
	await capture("portrait")
	if "--live-supplies" in OS.get_cmdline_user_args():
		await check_live_supplies()
		host.set_foreground(true)
	root.content_scale_size = Vector2i(1152,648)
	root.size = Vector2i(1152,648)
	go(6)
	for i in range(4):
		scene.world.tick(12.0)
		collect(0)
	go(7)
	scene.world.tick(12.0)
	collect(0)
	collect(1)
	go(8)
	scene.world.tick(12.0)
	collect(0)
	go(4)
	var parts := int(model.data.parts)
	var ore := int(scene.world.data.ore)
	scene._equipment.pressed.emit()
	check(scene.world.data.capacitor and scene._equipment.disabled and model.data.parts == parts - 4
		and scene.world.data.ore == ore - 3, "capacitor installs using salvaged parts and ore")
	await capture("reactor-capacitor")
	go(1)
	var silica := int(scene.world.data.silica)
	scene._equipment.pressed.emit()
	check(scene.world.data.condenser and model.data.parts == parts - 8
		and scene.world.data.silica == silica - 2, "condenser installs using crystals from the cave")
	check(not scene.world.craft("condenser"), "an installed module cannot charge twice")
	var energy_before := model.supply("energy")
	var water_before_upgrade := model.supply("water")
	host._game_view._process(60.0)
	check(is_equal_approx(energy_before - model.supply("energy"), 4.0)
		and is_equal_approx(water_before_upgrade - model.supply("water"), 3.0),
		"both upgrades reduce actual ship drain")
	await capture("coolant-condenser")
	go(7)
	var outdoor_water := model.supply("water")
	host._game_view._process(60.0)
	check(is_equal_approx(outdoor_water - model.supply("water"), 5.0), "condenser recovers water during exterior travel")
	var installed: Dictionary = State.new(model.path).data.expedition
	check(installed.capacitor and installed.condenser, "both upgrades survive relaunch")
	await check_quiet_signal()
	for suffix in ["_profile.json", "_station.json", "_station.json.tmp", "_station.json.quiet_signal.json", "_station.json.quiet_signal.json.tmp"]:
		if FileAccess.file_exists(fixture + suffix): DirAccess.remove_absolute(fixture + suffix)
	main.queue_free()
	await process_frame
	await process_frame
	print("CAMPAIGN SMOKE checks=%d failures=%d" % [checks,errors])
	quit(0 if errors == 0 else 1)

func check_quiet_signal() -> void:
	var view = host._game_view
	scene._map_button.pressed.emit()
	check(scene._map._quiet.visible, "campaign map exposes Quiet Signal after making the filter")
	scene._map._quiet.pressed.emit()
	var expedition = view.quiet_signal
	check(is_instance_valid(expedition) and not scene.visible and host._expedition_input, "map opens the expedition with shared input")
	if not is_instance_valid(expedition): return
	expedition.set_process(false)
	expedition._action.pressed.emit()
	expedition.suspend_input()
	check(host._current.state == &"SUSPENDED" and expedition._current.pause_required, "expedition pauses the owner's input pipeline")
	expedition.request_resume()
	check(host._current.state == &"REST" and expedition._current.state == &"REST", "explicit resume shares the owner's neutral command")
	await capture("quiet-signal-campaign")
	now = host._now_ms()
	for i in range(3000):
		if expedition.model.stage == "complete": break
		var channels := ExpeditionPilot.channels(expedition.model)
		now += 50
		host._pipeline.submit(host._source.sample(now, channels.x, channels.y, true), now)
		host.update_host(now, 0.05, false)
		expedition.update_host(now, 0.05, false)
	check(expedition.model.stage == "complete", "shared A/B pipeline drives the entire round trip (%s, %s)" % [expedition.model.stage, host._current.state])
	if expedition.model.stage != "complete": return
	var parts := int(model.data.parts)
	var energy := int(model.data.energy)
	var result: Dictionary = expedition.model.result()
	check(expedition.claim_reward(), "expedition delivers its earned reward")
	check(model.data.parts >= parts + 8 and model.data.energy == energy + 3, "campaign deposits salvage and battery")
	var paid_parts := int(model.data.parts)
	check(model.credit_quiet_signal(result) and not expedition.claim_reward()
		and model.data.parts == paid_parts, "duplicate IDs cannot pay twice")
	var disk := State.new(model.path)
	check(disk.data.quiet_signal_claims.has(result.reward_id) and disk.data.parts == paid_parts
		and expedition._ledger.pending_events().is_empty(), "durable ship receipt precedes ledger acknowledgement")
	var unavailable := State.new("")
	unavailable.path = fixture + "_missing/station.json"
	check(not unavailable.credit_quiet_signal(result) and unavailable.data.parts == 3
		and unavailable.data.quiet_signal_claims.is_empty(), "failed save rolls back stock and receipt together")
	expedition._on_exit()
	check(view.quiet_signal == null and scene.visible and scene._map.visible and not host._expedition_input, "expedition closes back to the campaign map")
	check(scene.world.data.weather_event == "dust", "successful battery delivery brings a weather event home")
	scene._map.dismissed.emit()
	go(3)
	var water := int(model.data.water)
	check(scene._purge.visible, "dust adds a voluntary purge job in the greenhouse")
	scene._purge.pressed.emit()
	if host._playing:
		activate_input()
		turn_valve(3)
	check(scene.world.data.weather_event.is_empty() and model.data.water == water, "purge clears dust without charging or granting water")
	check(not scene.world.next_station_event().is_empty() and scene.world.data.weather_event == "vent", "next station event reveals geothermal crystals")
	go(8)
	scene.world.tick(12.0)
	var silica := int(scene.world.data.silica)
	collect(0)
	check(scene.world.data.silica == silica + 4 and scene.world.data.weather_event.is_empty(), "vent adds one extra crystal payout")
	check("следы" in scene.world.next_station_event() and scene.world.data.weather_event.is_empty(), "fauna event is a short story beat")
	await process_frame

func tap_plot(index: int) -> void:
	await process_frame
	var frame: Rect2 = scene.art.frame_rect()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = frame.position + frame.size * (GardenPlots.CENTERS[index] / Vector2(384, 216))
	click.pressed = true
	root.push_input(click)
	click.pressed = false
	root.push_input(click)

func check_live_supplies() -> void:
	var view = host._game_view
	var start := model.supply("energy")
	view.set_process(true)
	await create_timer(4.0, true, false, true).timeout
	var drained := start - model.supply("energy")
	check(absf(drained - 0.4) < 0.12, "four seconds of live game frames draw power at the chosen rate")
	host.set_foreground(false)
	var paused := model.supply("energy")
	await create_timer(1.0, true, false, true).timeout
	check(is_equal_approx(model.supply("energy"), paused), "live frames do not drain power in the background")
	view.set_process(false)

func use(expected: String) -> void:
	check(scene._verb == expected and not scene._action.disabled, "action " + expected + " in " + str(scene.room))
	if scene._verb == expected and not scene._action.disabled:
		scene._action.pressed.emit()
		settle()

func settle() -> void:
	for i in range(130):
		if not scene.nav.moving and not scene._arrival.is_valid(): break
		scene._process(0.05)

func collect(index: int) -> void:
	scene.queue_collect(index)
	settle()

func go(target: int) -> void:
	var count: int = absi(scene.room - target)
	for i in range(count):
		if target > scene.room and scene._right.visible: scene._right.pressed.emit()
		elif target < scene.room and scene._left.visible: scene._left.pressed.emit()
		if scene.mode == "chapter": scene._finish_cut()
	check(scene.room == target, "navigate to room %d" % target)

func activate_input() -> void:
	host.request_resume()
	now = host._now_ms()

func sample(a: float, b: float, frames: int) -> void:
	for i in range(frames):
		if not host._playing: return
		now += 50
		host._pipeline.submit(host._source.sample(now,a,b,true),now)
		host.update_host(now,0.05,false)

func turn_valve(count: int) -> void:
	if host.repair_task.level_id == "repair-1":
		for i in range(160):
			if not host._playing: break
			sample(0, 1 if host.repair_task._value < 0.70 else 0, 1)
		check(not host._playing, "short digital pulses and rest can regulate pressure")
		return
	for i in range(count):
		sample(1 if i % 2 else 0, 0 if i % 2 else 1, 38)
		sample(0,0,6)
	check(not host._playing, "valve releases complete")

func phase_lock() -> void:
	for target in [0.68,0.40]:
		for i in range(100):
			if not host._playing or host.repair_task._value >= target - 0.025: break
			sample(1,0,1)
		for i in range(100):
			if not host._playing or host.repair_task._right_phase <= target + 0.025: break
			sample(0,1,1)
		sample(0,0,8)
	check(not host._playing, "two phase windows complete")

func salvage(show_capture := false) -> void:
	use("job")
	if show_capture: await capture("claw")
	activate_input()
	if show_capture:
		var stock := int(model.data.parts)
		sample(0,1,16)
		check(host.repair_task.mistakes == 1 and model.data.parts == stock, "overgrip retries without consuming stock")
		sample(0,0,18)
	sample(0,1,8)
	sample(0,0,3)
	sample(0,1,17)
	sample(0,0,22)
	sample(1,0,2)
	check(not host._playing, "grip, lift, neutral and weld finish salvage")

func capture(name: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	scene.art.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://work/campaign")
	root.get_texture().get_image().save_png("res://work/campaign/" + name + ".png")
