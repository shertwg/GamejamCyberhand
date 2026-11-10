extends "res://game/ui/ui_base.gd"

const MeterScript = preload("res://game/ui/channel_meter.gd")
const EmulatorPadScript = preload("res://game/ui/emulator_pad.gd")
const EMULATOR_PAD_SCENE_PATH := "res://game/ui/emulator_pad.tscn"
const DEMO_THRESHOLD := 0.35

var value_labels: Dictionary = {}
var meters: Dictionary = {}
var sliders: Dictionary = {}
var pad_buttons: Dictionary = {}
var command_label: Label
var intensity_label: Label
var hint_label: Label
var event_label: Label
var command_grid: GridContainer
var monitor_grid: GridContainer
var emulator_pad: PanelContainer
var event_actions: GridContainer
var nav_actions: GridContainer
var waiting_resume_overlay: Control
var waiting_resume_margin: MarginContainer
var resume_overlay_button: Button


func _ready() -> void:
	super._ready()
	page_content.add_theme_constant_override("separation", DesignTheme.SPACE_050)
	_heading("ДЕМО / УРОВЕНЬ %s" % runtime.level_id, "Игровая оболочка", "Демонстрация без захвата и таймера. Адаптация темпа не подключена.")
	_add_command_status()
	_add_channel_monitor()
	_add_emulator()
	_add_demo_events()
	_add_actions()
	_add_waiting_resume_overlay()
	_on_viewport_resized(get_viewport_rect().size)
	runtime.command_display_changed.connect(_on_command_changed)
	runtime.demo_event_changed.connect(_on_demo_event)
	runtime.input_frame_received.connect(_on_input_frame)
	if runtime.has_signal("waiting_resume_changed"):
		runtime.waiting_resume_changed.connect(_on_waiting_resume_changed)
	_refresh_readouts()
	if runtime.connected:
		_on_command_changed("REST", 0.0, "Покой. Оба канала ниже демонстрационного порога.")
	else:
		_on_command_changed("REST", 0.0, "Потеря или устаревание сигнала. Команда сброшена в безопасное состояние.")
	_on_waiting_resume_changed(bool(runtime.get("waiting_resume")))


func _on_viewport_resized(viewport_size: Vector2) -> void:
	var two_col := 2 if viewport_size.x >= 640.0 else 1
	if command_grid != null:
		command_grid.columns = two_col
	if monitor_grid != null:
		monitor_grid.columns = two_col
	var dp_unit := dp_to_vp(1.0)
	if emulator_pad != null and emulator_pad.has_method("update_responsive_metrics"):
		emulator_pad.update_responsive_metrics(viewport_size, dp_unit)
	if event_actions != null:
		event_actions.columns = 3 if viewport_size.x >= 520.0 else 1
	if nav_actions != null:
		nav_actions.columns = 3 if viewport_size.x >= 520.0 else 1
	if waiting_resume_margin != null:
		var insets := compute_safe_area_insets_vp()
		var base_pad := DesignTheme.SPACE_300
		waiting_resume_margin.add_theme_constant_override("margin_left", int(ceilf(float(insets["left"]))) + base_pad)
		waiting_resume_margin.add_theme_constant_override("margin_top", int(ceilf(float(insets["top"]))) + base_pad)
		waiting_resume_margin.add_theme_constant_override("margin_right", int(ceilf(float(insets["right"]))) + base_pad)
		waiting_resume_margin.add_theme_constant_override("margin_bottom", int(ceilf(float(insets["bottom"]))) + base_pad)
	if resume_overlay_button != null:
		resume_overlay_button.custom_minimum_size = Vector2(maxf(220.0, dp_to_vp(220.0)), maxf(56.0, dp_to_vp(56.0)))


func _add_command_status() -> void:
	var status := _section(page_content, "ТЕКУЩАЯ КОМАНДА", "", "CommandStatusSection")
	status.add_theme_constant_override("separation", DesignTheme.SPACE_050)
	command_grid = status.get_node_or_null("CommandGrid") as GridContainer
	if command_grid == null:
		command_grid = GridContainer.new()
		command_grid.name = "CommandGrid"
		command_grid.columns = 2 if get_viewport_rect().size.x >= 640.0 else 1
		command_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		command_grid.add_theme_constant_override("h_separation", DesignTheme.SPACE_200)
		command_grid.add_theme_constant_override("v_separation", DesignTheme.SPACE_050)
		status.add_child(command_grid)
	var line := command_grid.get_node_or_null("CommandLine") as HBoxContainer
	if line == null:
		line = HBoxContainer.new()
		line.name = "CommandLine"
		line.add_theme_constant_override("separation", DesignTheme.SPACE_200)
		command_grid.add_child(line)
	command_label = line.get_node_or_null("CommandLabel") as Label
	if command_label == null:
		command_label = _label("REST", "MetricLabel", "CommandLabel")
		command_label.size_flags_horizontal = Control.SIZE_FILL
		command_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		line.add_child(command_label)
	intensity_label = line.get_node_or_null("IntensityLabel") as Label
	if intensity_label == null:
		intensity_label = _label("Интенсивность 0.00", "SubtleLabel", "IntensityLabel")
		intensity_label.size_flags_horizontal = Control.SIZE_FILL
		intensity_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		intensity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(intensity_label)
	hint_label = command_grid.get_node_or_null("HintLabel") as Label
	if hint_label == null:
		hint_label = _label("Покой. Оба канала ниже демонстрационного порога.", "SubtleLabel", "HintLabel")
		hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		command_grid.add_child(hint_label)


func _add_channel_monitor() -> void:
	var monitor := _section(page_content, "КАНАЛЫ", "0.00—1.00 · отметка демонстрационного порога 0.35", "ChannelMonitorSection")
	monitor_grid = monitor.get_node_or_null("MonitorGrid") as GridContainer
	if monitor_grid == null:
		monitor_grid = GridContainer.new()
		monitor_grid.name = "MonitorGrid"
		monitor_grid.columns = 2 if get_viewport_rect().size.x >= 640.0 else 1
		monitor_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		monitor_grid.add_theme_constant_override("h_separation", DesignTheme.SPACE_200)
		monitor_grid.add_theme_constant_override("v_separation", DesignTheme.SPACE_100)
		monitor.add_child(monitor_grid)
	_add_meter_row(monitor_grid, "A", "OPEN")
	_add_meter_row(monitor_grid, "B", "CLOSE")


func _add_meter_row(parent: Container, channel: String, action_name: String) -> void:
	var row_name := "MeterRow%s" % channel
	var row := parent.get_node_or_null(row_name) as VBoxContainer
	if row == null:
		row = VBoxContainer.new()
		row.name = row_name
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", DesignTheme.SPACE_050)
		parent.add_child(row)
	var header := row.get_node_or_null("MeterHeader") as HBoxContainer
	if header == null:
		header = HBoxContainer.new()
		header.name = "MeterHeader"
		row.add_child(header)
		header.add_child(_label("КАНАЛ %s · %s" % [channel, action_name], "SubtleLabel", "ChannelTitle%s" % channel))
	var value_label := header.get_node_or_null("ValueLabel%s" % channel) as Label
	if value_label == null:
		value_label = _label("0.00", "SignalValueLabel", "ValueLabel%s" % channel)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.custom_minimum_size.x = 48
		value_label.size_flags_horizontal = Control.SIZE_FILL
		value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		header.add_child(value_label)
	var meter := row.get_node_or_null("Channel%sMeter" % channel) as Control
	if meter == null:
		meter = MeterScript.new()
		meter.name = "Channel%sMeter" % channel
		meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(meter)
	var scale_row := row.get_node_or_null("MeterScaleRow") as HBoxContainer
	if scale_row == null:
		scale_row = HBoxContainer.new()
		scale_row.name = "MeterScaleRow"
		var min_label := _label("0.00", "SubtlestLabel", "ScaleMin")
		min_label.size_flags_horizontal = Control.SIZE_FILL
		min_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		scale_row.add_child(min_label)
		var mid_label := _label("порог 0.35", "SubtlestLabel", "ScaleThreshold")
		mid_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scale_row.add_child(mid_label)
		var max_label := _label("1.00", "SubtlestLabel", "ScaleMax")
		max_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		max_label.size_flags_horizontal = Control.SIZE_FILL
		max_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		scale_row.add_child(max_label)
		row.add_child(scale_row)
	meters[channel] = meter
	value_labels[channel] = value_label


func _add_emulator() -> void:
	emulator_pad = page_content.get_node_or_null("EmulatorPad") as PanelContainer
	if emulator_pad == null:
		if ResourceLoader.exists(EMULATOR_PAD_SCENE_PATH):
			var packed := load(EMULATOR_PAD_SCENE_PATH) as PackedScene
			if packed != null:
				emulator_pad = packed.instantiate() as PanelContainer
		if emulator_pad == null:
			emulator_pad = EmulatorPadScript.new()
		emulator_pad.name = "EmulatorPad"
		page_content.add_child(emulator_pad)
	emulator_pad.hand = runtime.hand
	emulator_pad.apply_hand_layout(runtime.hand)
	if not emulator_pad.channel_changed.is_connected(_set_channel):
		emulator_pad.channel_changed.connect(_set_channel)
	sliders = emulator_pad.sliders
	pad_buttons = emulator_pad.pad_buttons


func _add_demo_events() -> void:
	var event_line := page_content.get_node_or_null("EventStatusLine") as HBoxContainer
	if event_line == null:
		event_line = HBoxContainer.new()
		event_line.name = "EventStatusLine"
		event_line.add_theme_constant_override("separation", DesignTheme.SPACE_100)
		page_content.add_child(event_line)
	event_label = event_line.get_node_or_null("EventLabel") as Label
	if event_label == null:
		event_label = _label("Событие демо не выбрано.", "SubtleLabel", "EventLabel")
		event_line.add_child(event_label)
	event_actions = page_content.get_node_or_null("EventActionsGrid") as GridContainer
	if event_actions == null:
		event_actions = GridContainer.new()
		event_actions.name = "EventActionsGrid"
		event_actions.columns = 3 if get_viewport_rect().size.x >= 520.0 else 1
		event_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		event_actions.add_theme_constant_override("h_separation", DesignTheme.SPACE_050)
		event_actions.add_theme_constant_override("v_separation", DesignTheme.SPACE_050)
		page_content.add_child(event_actions)
	_button(event_actions, "Успех", func(): runtime.show_demo_event(true), false, "SuccessEventButton")
	_button(event_actions, "Промах", func(): runtime.show_demo_event(false), false, "MissEventButton")
	_button(event_actions, "Потеря сигнала", runtime.simulate_stale_signal, false, "StaleSignalButton")


func _add_actions() -> void:
	nav_actions = page_content.get_node_or_null("NavActionsGrid") as GridContainer
	if nav_actions == null:
		nav_actions = GridContainer.new()
		nav_actions.name = "NavActionsGrid"
		nav_actions.columns = 3 if get_viewport_rect().size.x >= 520.0 else 1
		nav_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav_actions.add_theme_constant_override("h_separation", DesignTheme.SPACE_100)
		nav_actions.add_theme_constant_override("v_separation", DesignTheme.SPACE_100)
		page_content.add_child(nav_actions)
	_button(nav_actions, "Пауза", _pause, false, "PauseButton")
	_button(nav_actions, "Выход", _exit_to_menu, false, "ExitButton")
	_button(nav_actions, "К результату", _finish_demo, true, "FinishDemoButton")


func _add_waiting_resume_overlay() -> void:
	waiting_resume_overlay = get_node_or_null("WaitingResumeOverlay") as Control
	if waiting_resume_overlay == null:
		var backdrop := ColorRect.new()
		backdrop.name = "WaitingResumeOverlay"
		backdrop.color = Color(0.09, 0.17, 0.30, 0.72)
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		backdrop.process_mode = Node.PROCESS_MODE_ALWAYS
		backdrop.z_index = 100
		backdrop.visible = false
		add_child(backdrop)
		waiting_resume_overlay = backdrop

		waiting_resume_margin = MarginContainer.new()
		waiting_resume_margin.name = "ResumeSafeMargin"
		waiting_resume_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		waiting_resume_overlay.add_child(waiting_resume_margin)

		var center := CenterContainer.new()
		center.name = "ResumeCenter"
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		waiting_resume_margin.add_child(center)

		var card := PanelContainer.new()
		card.name = "WaitingResumeCard"
		card.theme_type_variation = DesignTheme.TYPE_RESUME_PANEL
		card.custom_minimum_size = Vector2(300, 0)
		center.add_child(card)

		var card_box := VBoxContainer.new()
		card_box.name = "ResumeCardContent"
		card_box.add_theme_constant_override("separation", DesignTheme.SPACE_150)
		card.add_child(card_box)

		card_box.add_child(_label("WAITING_RESUME · ОЖИДАНИЕ ПРОДОЛЖЕНИЯ", "EyebrowLabel", "ResumeEyebrowLabel"))
		card_box.add_child(_label("Приложение возвращено в фокус", "SectionTitle", "ResumeTitleLabel"))
		card_box.add_child(_label("Поток ввода был приостановлен при сворачивании, каналы A и B сброшены в безопасное состояние REST.", "SubtleLabel", "ResumeBodyLabel"))
		resume_overlay_button = _button(card_box, "Продолжить", _on_waiting_resume_confirmed, true, "ResumeOverlayButton")
		resume_overlay_button.process_mode = Node.PROCESS_MODE_ALWAYS
		resume_overlay_button.custom_minimum_size = Vector2(maxf(220.0, dp_to_vp(220.0)), maxf(56.0, dp_to_vp(56.0)))
	else:
		waiting_resume_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
		waiting_resume_overlay.z_index = 100
		waiting_resume_margin = waiting_resume_overlay.find_child("ResumeSafeMargin", true, false) as MarginContainer
		resume_overlay_button = waiting_resume_overlay.find_child("ResumeOverlayButton", true, false) as Button
		if resume_overlay_button != null:
			resume_overlay_button.process_mode = Node.PROCESS_MODE_ALWAYS
			if not resume_overlay_button.pressed.is_connected(_on_waiting_resume_confirmed):
				resume_overlay_button.pressed.connect(_on_waiting_resume_confirmed)


func _on_waiting_resume_changed(active: bool) -> void:
	if waiting_resume_overlay == null:
		return
	waiting_resume_overlay.visible = active
	if emulator_pad != null:
		emulator_pad.interaction_blocked = active
		if active and emulator_pad.has_method("clear_all_touches"):
			emulator_pad.clear_all_touches()
	if active and resume_overlay_button != null and is_inside_tree():
		resume_overlay_button.grab_focus.call_deferred()


func _on_waiting_resume_confirmed() -> void:
	if runtime != null and runtime.has_method("resume_from_waiting"):
		runtime.resume_from_waiting()


func _set_channel(channel: String, value: float) -> void:
	if channel == "A":
		runtime.set_demo_channels(value, runtime.channel_b)
	else:
		runtime.set_demo_channels(runtime.channel_a, value)


func _on_command_changed(direction: String, intensity: float, hint: String) -> void:
	command_label.text = direction
	intensity_label.text = "Интенсивность %.2f" % intensity
	if hint.begins_with("Потеря"):
		command_label.theme_type_variation = "DangerStateLabel"
	elif direction == "BOTH":
		command_label.theme_type_variation = "WarningStateLabel"
	elif direction == "OPEN" or direction == "CLOSE":
		command_label.theme_type_variation = "InfoStateLabel"
	else:
		command_label.theme_type_variation = "MetricLabel"
	hint_label.text = hint


func _on_demo_event(hint: String) -> void:
	event_label.text = hint
	if hint.begins_with("Успех"):
		event_label.theme_type_variation = "SuccessMessage"
	elif hint.begins_with("Промах"):
		event_label.theme_type_variation = "DangerMessage"
	else:
		event_label.theme_type_variation = "SubtleLabel"


func _on_input_frame(frame: Dictionary) -> void:
	var frame_is_connected: bool = frame.get("connected", false)
	for channel in ["A", "B"]:
		var key := "channel_a" if channel == "A" else "channel_b"
		var value := float(frame.get(key, 0.0)) if frame_is_connected else 0.0
		value_labels[channel].text = "%.2f" % value
		meters[channel].set_reading(value, DEMO_THRESHOLD)
		if emulator_pad != null and emulator_pad.has_method("set_channel_display"):
			emulator_pad.set_channel_display(channel, value)


func _refresh_readouts() -> void:
	for channel in ["A", "B"]:
		var value: float = runtime.channel_a if channel == "A" else runtime.channel_b
		value_labels[channel].text = "%.2f" % value
		meters[channel].set_reading(value, DEMO_THRESHOLD)
		if emulator_pad != null and emulator_pad.has_method("set_channel_display"):
			emulator_pad.set_channel_display(channel, value)
	if not runtime.connected:
		_on_command_changed("REST", 0.0, "Потеря или устаревание сигнала. Команда сброшена в безопасное состояние.")


func _pause() -> void:
	runtime.pause()
	_go("res://game/ui/pause_screen.tscn")


func _finish_demo() -> void:
	runtime.finish_demo()
	_go("res://game/ui/result_screen.tscn")


func _exit_to_menu() -> void:
	runtime.exit()
	_go("res://game/ui/start_screen.tscn")
