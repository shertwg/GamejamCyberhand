extends Node

## TEMPORARY UI-ONLY RUNTIME.
## Keeps demo preferences alive while the UI changes scenes and forwards the
## InputFrame shape from the contract. It does not control gameplay or timers.
##
## Integration seam for August: replace this node with an adapter to core that
## keeps the methods start_session(level_id), pause(), resume(), retry(), exit();
## forwards InputFrame and ControlCommand updates to the UI; forwards
## action_succeeded/action_failed and session_finished(SessionSummary); and
## reports disconnected/stale input. No such core signals exist in this base.

signal input_frame_received(frame: Dictionary)
signal command_display_changed(direction: String, intensity: float, hint: String)
signal demo_event_changed(hint: String)
signal session_started(level_id: String)
signal session_paused
signal session_resumed
signal session_finished(summary: Dictionary)
signal session_exited
signal waiting_resume_changed(active: bool)

const DEMO_THRESHOLD := 0.35
const EXAMPLE_SUMMARY := {
	"schema_version": 1,
	"level_id": "repair-2",
	"active_ms": 90000,
	"attempts": 5,
	"successes": 4,
	"unwanted_both_ms": 1500,
	"scored_window_ms": 30000,
	"median_reaction_ms": 420,
	"hold_in_target_ms": 8000,
	"hold_target_ms": 10000,
	"source": "replay"
}

var hand: String = "right"
var level_id: String = "repair-2"
var channel_a: float = 0.0
var channel_b: float = 0.0
var connected: bool = true
var paused: bool = false
var waiting_resume: bool = false
var simulated_safe_area: Rect2i = Rect2i()
var frame_seq: int = 0
var last_summary: Dictionary = {}


const META_KEY := &"_ui_demo_runtime"

var _saved_content_scale_mode: int = -1
var _saved_content_scale_aspect: int = -1
var _saved_content_scale_size: Vector2i = Vector2i.ZERO
var _scale_overridden: bool = false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if _is_on_game_screen():
			trigger_waiting_resume()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		if waiting_resume:
			waiting_resume_changed.emit(true)


func _is_on_game_screen() -> bool:
	if not is_inside_tree():
		return false
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return false
	return tree.current_scene.scene_file_path.ends_with("game_screen.tscn")


static func get_or_create(scene_tree: SceneTree) -> Node:
	var root := scene_tree.root
	var runtime := root.get_node_or_null("UIDemoRuntime")
	if runtime != null:
		return runtime
	if root.has_meta(META_KEY):
		var pending: Variant = root.get_meta(META_KEY)
		if is_instance_valid(pending) and pending is Node:
			return pending
	runtime = (load("res://game/ui/ui_demo_runtime.gd") as GDScript).new()
	runtime.name = "UIDemoRuntime"
	root.set_meta(META_KEY, runtime)
	root.add_child.call_deferred(runtime)
	return runtime


func enter_ui_screen(root: Window) -> void:
	if root == null:
		return
	if not _scale_overridden:
		_saved_content_scale_mode = root.content_scale_mode
		_saved_content_scale_aspect = root.content_scale_aspect
		_saved_content_scale_size = root.content_scale_size
		_scale_overridden = true
	update_ui_window_scale(root)


func update_ui_window_scale(root: Window) -> void:
	if root == null or not _scale_overridden:
		return
	var win_size := root.size
	if win_size.x <= 0 or win_size.y <= 0:
		win_size = DisplayServer.window_get_size()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	if win_size.y > win_size.x:
		var target_w := mini(win_size.x, 412)
		var target_h := int(roundf(float(target_w) * float(win_size.y) / float(maxi(win_size.x, 1))))
		var target_size := Vector2i(target_w, maxi(target_h, 640))
		if root.content_scale_size != target_size:
			root.content_scale_size = target_size
	else:
		var landscape_base := Vector2i(1280, 720)
		if root.content_scale_size != landscape_base:
			root.content_scale_size = landscape_base


func check_restore_window_scale() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var active := tree.current_scene
	if active != null and active.scene_file_path.begins_with("res://game/ui/"):
		return
	for child in tree.root.get_children():
		if child is Control and child.scene_file_path.begins_with("res://game/ui/"):
			return
	restore_window_scale(tree.root)


func restore_window_scale(root: Window) -> void:
	if not _scale_overridden or root == null:
		return
	root.content_scale_mode = _saved_content_scale_mode as Window.ContentScaleMode
	root.content_scale_aspect = _saved_content_scale_aspect as Window.ContentScaleAspect
	root.content_scale_size = _saved_content_scale_size
	_scale_overridden = false


func _exit_tree() -> void:
	var parent := get_parent()
	if parent is Window:
		restore_window_scale(parent as Window)
	if parent != null and parent.has_meta(META_KEY):
		parent.remove_meta(META_KEY)


func start_session(selected_level_id: String) -> void:
	level_id = selected_level_id
	paused = false
	waiting_resume = false
	connected = true
	set_demo_channels(0.0, 0.0)
	session_started.emit(level_id)
	waiting_resume_changed.emit(false)
	demo_event_changed.emit("Демо начато. Захват движется только в подключённой игровой логике.")


func trigger_waiting_resume() -> void:
	waiting_resume = true
	paused = true
	channel_a = 0.0
	channel_b = 0.0
	frame_seq += 1
	var now_ms := Time.get_ticks_msec()
	var frame := {
		"schema_version": 1,
		"seq": frame_seq,
		"timestamp_ms": now_ms,
		"channel_a": 0.0,
		"channel_b": 0.0,
		"connected": connected,
		"source": "manual_emulator"
	}
	input_frame_received.emit(frame)
	command_display_changed.emit("REST", 0.0, "Ожидание продолжения (WAITING_RESUME). Каналы сброшены в покой.")
	session_paused.emit()
	waiting_resume_changed.emit(true)


func resume_from_waiting() -> void:
	waiting_resume = false
	paused = false
	if is_inside_tree() and get_tree() != null and get_tree().paused:
		get_tree().paused = false
	waiting_resume_changed.emit(false)
	session_resumed.emit()
	_emit_demo_command()


func pause() -> void:
	paused = true
	session_paused.emit()


func resume() -> void:
	waiting_resume = false
	paused = false
	if is_inside_tree() and get_tree() != null and get_tree().paused:
		get_tree().paused = false
	waiting_resume_changed.emit(false)
	session_resumed.emit()


func retry() -> void:
	start_session(level_id)


func exit() -> void:
	waiting_resume = false
	paused = false
	if is_inside_tree() and get_tree() != null and get_tree().paused:
		get_tree().paused = false
	session_exited.emit()


func finish_demo() -> void:
	var summary: Dictionary = EXAMPLE_SUMMARY.duplicate(true)
	summary["level_id"] = level_id
	last_summary = summary.duplicate(true)
	session_finished.emit(summary)


func set_demo_channels(value_a: float, value_b: float) -> void:
	connected = true
	channel_a = clampf(value_a, 0.0, 1.0)
	channel_b = clampf(value_b, 0.0, 1.0)
	frame_seq += 1
	var now_ms := Time.get_ticks_msec()
	var frame := {
		"schema_version": 1,
		"seq": frame_seq,
		"timestamp_ms": now_ms,
		"channel_a": channel_a,
		"channel_b": channel_b,
		"connected": true,
		"source": "manual_emulator"
	}
	input_frame_received.emit(frame)
	_emit_demo_command()


func simulate_stale_signal() -> void:
	connected = false
	channel_a = 0.0
	channel_b = 0.0
	frame_seq += 1
	var now_ms := Time.get_ticks_msec()
	var frame := {
		"schema_version": 1,
		"seq": frame_seq,
		"timestamp_ms": now_ms,
		"channel_a": 0.0,
		"channel_b": 0.0,
		"connected": false,
		"source": "manual_emulator"
	}
	input_frame_received.emit(frame)
	command_display_changed.emit("REST", 0.0, "Потеря или устаревание сигнала. Команда сброшена в безопасное состояние.")


func show_demo_event(succeeded: bool) -> void:
	if succeeded:
		demo_event_changed.emit("Успех: демонстрационное событие уровня.")
	else:
		demo_event_changed.emit("Промах: демонстрационное событие уровня.")


func _emit_demo_command() -> void:
	if channel_a >= DEMO_THRESHOLD and channel_b >= DEMO_THRESHOLD:
		command_display_changed.emit("BOTH", 0.0, "Встречный сигнал. Действие безопасно остановлено.")
	elif channel_a >= DEMO_THRESHOLD:
		var strength_a := clampf((channel_a - DEMO_THRESHOLD) / (1.0 - DEMO_THRESHOLD), 0.0, 1.0)
		command_display_changed.emit("OPEN", strength_a, "Открытие захвата по каналу A.")
	elif channel_b >= DEMO_THRESHOLD:
		var strength_b := clampf((channel_b - DEMO_THRESHOLD) / (1.0 - DEMO_THRESHOLD), 0.0, 1.0)
		command_display_changed.emit("CLOSE", strength_b, "Закрытие захвата по каналу B.")
	else:
		command_display_changed.emit("REST", 0.0, "Покой. Оба канала ниже демонстрационного порога.")
