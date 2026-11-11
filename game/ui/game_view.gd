class_name GameView
extends CanvasLayer
## Master UI composition layer connecting UI scenes to SessionCoordinator by contract.

const Copy = preload("res://game/content/copy_catalog.gd")
const StartScreenScript = preload("res://game/ui/screens/start_screen.gd")
const HudOverlayScript = preload("res://game/ui/screens/hud_overlay.gd")
const ResultScreenScript = preload("res://game/ui/screens/result_screen.gd")
const PadScript = preload("res://game/ui/manual_pad.gd")

const StationState = preload("res://game/station/station_state.gd")
const Campaign = preload("res://game/ui/campaign_view.gd")
const RepairTask = preload("res://game/gameplay/repair_task.gd")
const QuietSignal = preload("res://game/side_expedition/quiet_signal.tscn")
const PlayerSettings = preload("res://game/ui/player_settings.gd")
const PlayerMenu = preload("res://game/ui/player_menu.gd")
static var legacy_demo := false
var coordinator: SessionCoordinator
var station: StationState
var campaign: Campaign
var quiet_signal: Control
var _quiet_notice := ""
var settings: PlayerSettings
var player_menu: PlayerMenu

@onready var root: Control = $Root
@onready var hud_overlay: HudOverlay = $Root/Margin/VBox/HudOverlay
@onready var course_container: Control = $Root/Margin/VBox/CourseContainer
@onready var emulator_pad: Control = $Root/Margin/VBox/EmulatorPad
@onready var screen_overlay: ColorRect = $Root/ScreenOverlay
@onready var start_screen: StartScreen = $Root/ScreenOverlay/StartScreen
@onready var result_screen: ResultScreen = $Root/ScreenOverlay/ResultScreen


func _ready() -> void:
	root.theme = preload("res://game/ui/terminal_style.gd").make_theme()
	start_screen.mission_selected.connect(func(id):
		if coordinator != null:
			coordinator.select_level(id)
			_refresh_start_screen()
	)
	start_screen.start_pressed.connect(_on_start_pressed)
	start_screen.cycle_mission_pressed.connect(_on_cycle_mission_pressed)
	start_screen.hand_toggle_pressed.connect(_on_hand_toggle_pressed)
	hud_overlay.resume_pressed.connect(_on_resume_pressed)
	hud_overlay.station_pressed.connect(show_start_screen)
	result_screen.retry_pressed.connect(_on_retry_pressed)
	result_screen.next_pressed.connect(_on_next_pressed)
	result_screen.ship_pressed.connect(show_start_screen)
	emulator_pad.channels_changed.connect(_on_pad_channels_changed)


func bind_coordinator(p_coordinator: SessionCoordinator) -> void:
	coordinator = p_coordinator
	var fixture := not SessionCoordinator.store_path_override.is_empty()
	station = StationState.new("" if fixture else StationState.DEFAULT_PATH)
	start_screen.station_panel.bind(station, coordinator._unlocked())
	if course_container != null and coordinator._course != null:
		if coordinator._course.get_parent() != course_container:
			if coordinator._course.get_parent() != null:
				coordinator._course.get_parent().remove_child(coordinator._course)
			course_container.add_child(coordinator._course)
		coordinator._course.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	coordinator.command_updated.connect(_on_command_updated)
	coordinator.mission_started.connect(_on_mission_started)
	coordinator.mission_tick.connect(_on_mission_tick)
	coordinator.mission_completed.connect(_on_mission_completed)
	coordinator.input_barrier_changed.connect(_on_input_barrier_changed)
	coordinator.hand_side_changed.connect(_on_hand_side_changed)
	coordinator.unlocked_missions_changed.connect(_on_unlocked_missions_changed)
	
	_apply_initial_state()
	if not legacy_demo:
		_open_campaign()
		_open_settings_layer(fixture)


func _open_campaign() -> void:
	screen_overlay.hide()
	start_screen.hide()
	campaign = Campaign.new()
	root.add_child(campaign)
	campaign.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	campaign.bind(station, coordinator._unlocked())
	campaign.job_requested.connect(func(id: String):
		coordinator.select_level(id)
		if coordinator._level_id == id:
			coordinator.start_current_mission(true)
	)
	campaign.resume_requested.connect(_on_resume_pressed)
	campaign.exit_requested.connect(_leave_repair)
	campaign.hand_requested.connect(_on_hand_toggle_pressed)
	campaign.quiet_signal_requested.connect(_open_quiet_signal)
	campaign.menu_requested.connect(_open_player_menu)
	emulator_pad.reparent(root, false)
	emulator_pad.compact = true
	emulator_pad.lever_mode = true
	emulator_pad.custom_minimum_size.y = 58
	emulator_pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	emulator_pad.offset_top = -68
	emulator_pad.offset_bottom = -10
	emulator_pad.offset_left = 14
	emulator_pad.offset_right = -14


func _open_settings_layer(fixture: bool) -> void:
	settings = PlayerSettings.new("" if fixture else PlayerSettings.DEFAULT_PATH)
	player_menu = PlayerMenu.new()
	root.add_child(player_menu)
	player_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player_menu.closed.connect(_close_player_menu)
	player_menu.save_requested.connect(_save_game.bind(false))
	player_menu.quit_requested.connect(_save_game.bind(true))
	player_menu.replay_requested.connect(func():
		_close_player_menu()
		campaign._begin_opening())
	player_menu.hand_requested.connect(coordinator.set_hand_side)
	player_menu.setting_changed.connect(_on_setting_changed)
	player_menu.vibration_preview.connect(func(): campaign.sound.vibrate(55))
	_apply_player_settings()


func _open_player_menu() -> void:
	if player_menu == null or player_menu.visible or not coordinator._foreground: return
	campaign.menu_open = true
	campaign.foreground = coordinator._foreground
	emulator_pad.input_enabled = false
	emulator_pad.clear()
	if is_instance_valid(quiet_signal):
		quiet_signal.suspend_input()
	elif coordinator._playing:
		coordinator.suspend_current_input()
	root.move_child(player_menu, -1)
	player_menu.open(settings.values, coordinator.is_hand_left(), campaign.mode == "room")


func _close_player_menu() -> void:
	if player_menu == null or not player_menu.visible: return
	player_menu.hide()
	emulator_pad.clear()
	emulator_pad.input_enabled = true
	campaign.menu_open = false
	campaign.foreground = coordinator._foreground


func _input(event: InputEvent) -> void:
	if player_menu == null or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode != KEY_ESCAPE: return
	if player_menu.visible:
		_close_player_menu()
	else:
		_open_player_menu()
	get_viewport().set_input_as_handled()


func _save_game(quit_after: bool) -> void:
	var old_room := int(station.data.saved_room)
	station.data.saved_room = campaign.room
	var ok := station.save()
	if not ok: station.data.saved_room = old_room
	if is_instance_valid(quiet_signal):
		ok = quiet_signal.save_progress() and ok
	ok = settings.save() and ok
	if not ok:
		player_menu.set_status("Не удалось сохранить. Попробуй ещё раз.")
		return
	player_menu.set_status("Сохранено · ремонт начнётся заново" if campaign.mode == "repair" else "Прогресс сохранён")
	if quit_after: get_tree().quit()


func _on_setting_changed(key: String, value: Variant) -> void:
	settings.set_value(key, value)
	_apply_player_settings()
	if not settings.save(): player_menu.set_status("Не удалось записать настройки")


func _apply_player_settings() -> void:
	var options := settings.values
	if options.reduce_motion and player_menu.visible: player_menu.snap_open()
	campaign.sound.apply_settings(options)
	campaign.apply_accessibility(options.large_text, options.reduce_motion)
	emulator_pad.one_hand = options.one_hand
	var pad_height := 100.0 if options.large_pad else 58.0
	emulator_pad.offset_top = -10.0 - pad_height
	emulator_pad.custom_minimum_size.y = pad_height
	var reserved := pad_height + 14.0
	if campaign.mode == "repair": campaign.offset_bottom = -reserved
	if is_instance_valid(quiet_signal):
		quiet_signal.offset_bottom = -reserved
		quiet_signal.apply_accessibility(options.large_text, options.reduce_motion)


func _open_quiet_signal() -> void:
	if is_instance_valid(quiet_signal) or campaign.mode != "room" or not coordinator._foreground or not campaign.world.data.filter: return
	_quiet_notice = ""
	campaign.mode = "expedition"
	campaign.hide()
	campaign.sound.cue(10)
	campaign.sound.ambience("storm")
	emulator_pad.clear()
	coordinator.set_expedition_input(true)
	quiet_signal = QuietSignal.instantiate()
	quiet_signal.external_input_mode = true
	quiet_signal.persistence_path = station.path + ".quiet_signal.json" if not station.path.is_empty() else ""
	quiet_signal.input_pause_requested.connect(_pause_quiet_input)
	quiet_signal.input_resume_requested.connect(coordinator.resume_expedition_input)
	quiet_signal.expedition_completed.connect(_receive_quiet_reward)
	quiet_signal.exit_requested.connect(_close_quiet_signal)
	quiet_signal.settings_requested.connect(_open_player_menu)
	root.add_child(quiet_signal)
	quiet_signal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_player_settings()
	root.move_child(emulator_pad, -1)
	emulator_pad.show()
	quiet_signal.flush_pending_rewards()


func _pause_quiet_input() -> void:
	emulator_pad.clear()
	coordinator.suspend_current_input()


func _receive_quiet_reward(result: Dictionary) -> void:
	var first_receipt: bool = not station.data.quiet_signal_claims.has(result.get("reward_id"))
	if station.credit_quiet_signal(result):
		quiet_signal.acknowledge_reward(result.reward_id)
		_quiet_notice = station.notice
		if first_receipt and result.get("battery_secured") == true:
			var weather := campaign.world.next_station_event()
			if not weather.is_empty(): campaign.log_dialogue(weather)
	else:
		_quiet_notice = "Склад недоступен. Открой вылазку снова, чтобы повторить доставку."
		quiet_signal.report_storage_error(_quiet_notice)


func _close_quiet_signal(_result: Dictionary) -> void:
	var previous := quiet_signal
	quiet_signal = null
	coordinator.set_expedition_input(false)
	emulator_pad.clear()
	emulator_pad.hide()
	previous.hide()
	previous.queue_free()
	campaign.show()
	campaign.sound.room(campaign.art.room, station.data.signal)
	campaign.sound.pause_audio(not coordinator._foreground)
	campaign.show_room(_quiet_notice)


func _leave_repair(message := "") -> void:
	station.cancel_job()
	coordinator._playing = false
	coordinator.clear_channel_values()
	var previous := coordinator.repair_task
	coordinator.repair_task = null
	campaign.device = null
	if is_instance_valid(previous):
		previous.hide()
		previous.queue_free()
	emulator_pad.clear()
	emulator_pad.hide()
	campaign.offset_bottom = 0
	campaign.show_room(message)


func show_start_screen() -> void:
	if campaign != null:
		_leave_repair()
		return
	station.cancel_job()
	$Root/Margin.visible = false
	if coordinator != null:
		coordinator._playing = false
		coordinator.set_channel_values(0.0, 0.0)
	if screen_overlay != null:
		screen_overlay.visible = true
	if start_screen != null:
		start_screen.visible = true
	if result_screen != null:
		result_screen.visible = false
	if emulator_pad != null:
		emulator_pad.visible = false
	if hud_overlay != null:
		hud_overlay.set_resume_visible(false)
		hud_overlay.update_time(0.0)
	_refresh_start_screen()


func _refresh_start_screen() -> void:
	if coordinator != null and start_screen != null:
		var cfg = coordinator._config_for(coordinator._level_id)
		var unlocked_cnt: int = coordinator._unlocked().size()
		var is_left: bool = coordinator.is_hand_left()
		start_screen.set_mission_info(cfg, unlocked_cnt, is_left)
		start_screen.station_panel.set_unlocked(coordinator._unlocked())
		if hud_overlay != null:
			hud_overlay.update_mission(Copy.HEADER_TITLE, Copy.HEADER_SUBTITLE)


func _apply_initial_state() -> void:
	if coordinator == null:
		return
	var is_left: bool = coordinator.is_hand_left()
	if emulator_pad != null:
		emulator_pad.set_mirrored(is_left)
		if coordinator._profile != null:
			emulator_pad.set_thresholds(
				coordinator._profile.on_a, coordinator._profile.off_a,
				coordinator._profile.on_b, coordinator._profile.off_b
			)
	show_start_screen()


func _on_start_pressed() -> void:
	if coordinator != null:
		coordinator.start_current_mission()


func _on_cycle_mission_pressed() -> void:
	if coordinator != null:
		coordinator.cycle_mission()
		_refresh_start_screen()


func _on_hand_toggle_pressed() -> void:
	if coordinator != null:
		coordinator.toggle_hand_side()


func _on_resume_pressed() -> void:
	if player_menu != null and player_menu.visible: return
	if coordinator != null:
		coordinator.request_resume()


func _on_retry_pressed() -> void:
	if coordinator != null:
		coordinator.retry_mission()


func _on_next_pressed() -> void:
	show_start_screen()


func _process(delta: float) -> void:
	if station == null or not coordinator._foreground or (player_menu != null and player_menu.visible):
		return
	if campaign != null and campaign.journal_open: return
	if campaign != null and campaign.mode in ["room", "repair"]:
		station.advance_supplies(delta, campaign.room >= 7)
	# Greenhouse advances at base and during active repair, never during an input barrier.
	var active_repair := coordinator._playing and coordinator._current != null and not coordinator._current.pause_required
	var at_base := campaign.mode == "room" if campaign != null else start_screen.visible
	var growth := 0.8 if campaign != null and station.economy_mode() else 1.0
	if campaign != null and campaign.world.data.weather_event == "dust":
		growth *= 0.85
	station.advance(minf(delta, 0.1) * growth, at_base or active_repair)


func _notification(what: int) -> void:
	if station != null and what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		station.flush_supplies()


func _on_pad_channels_changed(a: float, b: float) -> void:
	if coordinator != null:
		coordinator.set_channel_values(a, b)


func _on_command_updated(command) -> void:
	if is_instance_valid(quiet_signal):
		quiet_signal.submit_core_command(command)
	if coordinator != null and coordinator._course != null:
		coordinator._course.set_visual_command(command)
	var color := _state_color(command.state)
	var text := Copy.state_message(command)
	if hud_overlay != null:
		hud_overlay.update_status(text, color)


func _on_mission_started(level_id: String, config) -> void:
	station.begin_job(level_id)
	if campaign != null:
		var device := RepairTask.new()
		device.salvage = campaign.room == 2
		device.storm_trial = campaign.room == 9
		device.drill = campaign.room == 8
		if device.storm_trial and campaign.world.data.stabilizer:
			device.surge_limit += 0.8
		campaign.add_child(device)
		campaign.move_child(device, 1)
		coordinator.repair_task = device
		campaign.device = device
		var title: String = RepairTask.TITLES[level_id]
		if device.storm_trial: title = "Ретранслятор · грозовой фронт"
		elif device.drill: title = "Бур · калибровка зажима"
		elif device.salvage: title = "Снять ячейку"
		elif campaign.room == 3 and level_id == "repair-1": title = "Продувка биосада"
		campaign.show_repair(title)
		_apply_player_settings()
		device.completed.connect(coordinator._on_level_completed)
		device.event_emitted.connect(coordinator._on_game_event)
		device.hint_changed.connect(campaign.repair_hint)
		device.sound_requested.connect(campaign.sound.fx)
		device.setup(level_id, coordinator._step_for(level_id), coordinator._tracker.session_id, coordinator._attempt_counter)
		emulator_pad.clear()
		emulator_pad.show()
		coordinator._update_status()
		return
	$Root/Margin.visible = true
	if screen_overlay != null:
		screen_overlay.visible = false
	if start_screen != null:
		start_screen.visible = false
	if result_screen != null:
		result_screen.visible = false
	if emulator_pad != null:
		emulator_pad.visible = true
		emulator_pad.clear()
	var title: String = {"tutorial": "МАСТЕРСКАЯ", "repair-1": "ВОДЯНОЙ НАСОС",
		"repair-2": "ГЕНЕРАТОР", "repair-3": "АНТЕННА"}[level_id]
	var sub := "Доведи дрон до выхода справа. Удерживай A для подъёма или B для спуска. Отпусти, чтобы остановиться."
	if config != null and not config.hazard_subtitle.is_empty():
		sub += " " + config.hazard_subtitle
	if hud_overlay != null:
		hud_overlay.update_mission(title, sub)
		hud_overlay.update_time(0.0)


func _on_mission_tick(active_seconds: float, in_hold_zone: bool) -> void:
	if hud_overlay != null:
		hud_overlay.update_time(active_seconds)
		hud_overlay.update_hold(in_hold_zone)


func _on_mission_completed(summary, adaptation: Dictionary) -> void:
	if campaign != null:
		campaign.sound.fx("success")
		var task = coordinator.repair_task
		var relay: bool = task.storm_trial
		var repeat_relay: bool = campaign.world.data.relay
		campaign.world.record(summary,task.mistakes,task.releases,relay)
		if campaign.room == 3 and summary.level_id == "repair-1":
			campaign.world.finish_dust_cycle()
			campaign.log_dialogue("purge")
			_leave_repair("Фильтр биосада очищен.")
			return
		if task.drill:
			station.cancel_job()
			campaign.world.data.extractor = true
			station.save()
			_leave_repair("Бур откалиброван. Теперь можно собрать кристаллы.")
			return
		if relay:
			station.cancel_job()
			_leave_repair("Синхронизация стабильна. Заряд +1." if repeat_relay else
				"Ретранслятор синхронизирован. Заряд +3.")
			if not repeat_relay: campaign.log_dialogue("relay")
			return
		var first_air: bool = not station.data.air_ready and summary.level_id == "tutorial"
		var first_water: bool = not station.data.pump and summary.level_id == "repair-1"
		var first_signal: bool = not station.data.signal and summary.level_id == "repair-3"
		var reward := station.complete_job(summary.level_id)
		var story := ""
		if first_air: story = "Давление стабильно. "
		elif first_water: story = "Охлаждение восстановлено. "
		elif first_signal: story = "Орбитальный коридор открыт. "
		elif task.mistakes == 0 and summary.level_id in ["repair-1", "repair-2"]:
			story = "Чистый контур. "
		_leave_repair(story + reward)
		if first_air: campaign.log_dialogue("air")
		elif first_water: campaign.log_dialogue("water")
		elif first_signal: campaign.chapter_scene(2)
		return
	$Root/Margin.visible = false
	if screen_overlay != null:
		screen_overlay.visible = true
	if start_screen != null:
		start_screen.visible = false
	if result_screen != null:
		result_screen.visible = true
	if emulator_pad != null:
		emulator_pad.visible = false
		emulator_pad.clear()
	if hud_overlay != null:
		hud_overlay.set_resume_visible(false)
	if result_screen != null:
		var result := adaptation.duplicate()
		result["station_reward"] = station.complete_job(summary.level_id) if summary != null else ""
		result["station_objective"] = station.quest().title
		result_screen.show_result(summary, result)


func _on_input_barrier_changed(needs_resume: bool, prompt_text: String) -> void:
	if campaign != null:
		var safe: bool = coordinator._current != null and coordinator._current.state in [&"REST", &"ACTIVE"]
		campaign.repair_barrier("" if safe else prompt_text, needs_resume)
		return
	if hud_overlay != null:
		hud_overlay.set_resume_visible(needs_resume)
		if coordinator != null and coordinator._current != null:
			hud_overlay.update_status(prompt_text, _state_color(coordinator._current.state))


func _on_hand_side_changed(is_left: bool) -> void:
	if emulator_pad != null:
		emulator_pad.set_mirrored(is_left)
	if start_screen != null and coordinator != null:
		var cfg = coordinator._config_for(coordinator._level_id)
		start_screen.set_mission_info(cfg, coordinator._unlocked().size(), is_left)


func _on_unlocked_missions_changed(_unlocked: Array) -> void:
	if campaign != null:
		campaign.unlocked = _unlocked
		campaign.refresh()
		return
	_refresh_start_screen()


func _state_color(state: StringName) -> Color:
	match state:
		&"ACTIVE":
			return Color("8af0d4")
		&"REST":
			return Color("c7d9e8")
		&"BOTH", &"WAITING_NEUTRAL", &"WAITING_RESUME":
			return Color("ffd166")
		&"STALE", &"DISCONNECTED", &"INVALID", &"SUSPENDED":
			return Color("ff9b9b")
		_:
			return Color("c7d9e8")
