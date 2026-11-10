extends SceneTree
## Godot 4.4.1 --headless --path . --script res://qa/station_smoke.gd
## Use a desktop renderer and append -- --capture to review the screens.
const Main = preload("res://game/main.tscn")
const State = preload("res://game/station/station_state.gd")

var host
var panel
var station: State
var failures := 0
var checks := 0
var fixture := ""

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	GameView.legacy_demo = true
	fixture = "user://station_smoke_%d" % OS.get_process_id()
	SessionCoordinator.store_path_override = fixture + "_profile.json"
	root.size = Vector2i(1152, 648)
	var main := Main.instantiate()
	root.add_child(main)
	await process_frame
	host = main.get_child(0)
	host.set_process(false)
	host._game_view.set_process(false)
	panel = host._game_view.start_screen.station_panel
	station = host._game_view.station
	station.path = fixture + "_station.json"
	check(panel.selected == "pump" and panel._action.text == "Починить насос", "clear first action")
	await capture("station-home")
	panel.select("beacon")
	check(panel._action.disabled, "cannot skip the station story")
	panel.select("pump")
	panel._action.pressed.emit()
	check(host._playing and host._current.state == &"WAITING_RESUME", "repair uses input safety barrier")
	await capture("station-pump")
	host._game_view.hud_overlay.station_pressed.emit()
	check(not host._playing and station.data.water == 0, "returning early grants no reward")
	job("pump", "repair-1")
	check(station.data.water == 3 and station.quest().step == 1, "first repair grants water and next quest")
	check(station.complete_job("repair-1").is_empty(), "no duplicate reward")
	check(panel.selected == "garden", "journal highlights next module")
	action("garden")
	action("garden")
	check(station.data.garden and station.data.beds[0] == 0, "build and plant via station")
	station.advance(30, false)
	check(station.data.beds[0] == 0, "growth pauses when game is inactive")
	station.advance(8, true)
	var restored := State.new(station.path)
	check(restored.data.beds[0] == 8 and restored.data.water == 1, "save restores crop without offline growth")
	station.advance(10, true)
	await capture("station-harvest")
	action("garden")
	check(station.data.food == 2 and station.quest().step == 3, "harvest supplies generator construction")
	job("workshop", "tutorial")
	job("workshop", "tutorial")
	action("generator")
	check(station.data.generator and station.data.food == 0, "generator pays its material cost")
	job("generator", "repair-2")
	job("workshop", "tutorial")
	action("beacon")
	job("beacon", "repair-3")
	check(station.data.signal and not station.data.launched, "radio opens the final supply quest")
	job("pump", "repair-1")
	job("workshop", "tutorial")
	job("workshop", "tutorial")
	action("garden")
	action("garden")
	station.advance(18, true)
	action("garden")
	action("garden")
	action("beacon")
	check(station.data.launched and station.quest().step == 7, "launch closes the story")
	check(State.new(station.path).data.launched, "launch survives reload")
	await capture("station-epilogue")
	root.size = Vector2i(648, 1152)
	root.content_scale_size = Vector2i(648, 1152)
	await process_frame
	await process_frame
	check(panel._body.vertical, "journal stacks beneath the map in portrait")
	await capture("station-portrait")
	for suffix in ["_station.json", "_profile.json", "_station.json.tmp"]:
		if FileAccess.file_exists(fixture + suffix):
			DirAccess.remove_absolute(fixture + suffix)
	print("STATION SMOKE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func action(module: String) -> void:
	panel.select(module)
	check(not panel._action.disabled, "station action available at " + module)
	if not panel._action.disabled:
		panel._action.pressed.emit()

func job(module: String, level: String) -> void:
	action(module)
	check(host._playing and host._level_id == level, "station starts " + level)
	if not host._playing:
		return
	host.request_resume()
	var time: int = host._now_ms()
	for step in range(4000):
		if not host._playing:
			break
		var target := 0.5
		for wall in host._course.active_walls:
			if wall.end.x + host._course.HALF.x > host._course.player.x:
				target = 0.88 if wall.position.y <= 0 else 0.12
				break
		var rise: bool = host._course.player.y > target
		time += 50
		var frame = host._source.sample(time, 1.0 if rise else 0.0, 0.0 if rise else 1.0, true)
		host._pipeline.submit(frame, time)
		host.update_host(time, 0.05, false)
	check(host._course.finished and host._game_view.result_screen.visible, "input route finishes " + level)
	check(host._game_view.result_screen.result_body.text.contains("На склад"), "result explains rewards")
	host._game_view.show_start_screen()

func capture(file: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://work/prototype")
	root.get_texture().get_image().save_png("res://work/prototype/" + file + ".png")
