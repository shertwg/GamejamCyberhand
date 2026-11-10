extends Control
## Standalone host. Game rules live in expedition_model.gd.
## No LocalStore, autoload, campaign resources, or inventory writes.

signal expedition_completed(result: Dictionary)
signal journal_added(entry: Dictionary)
signal stage_changed(stage_id: String)
signal exit_requested(result: Dictionary)
signal location_entered(location_id: String, entry_line: String)
signal checkpoint_changed(checkpoint: Dictionary)
signal input_pause_requested
signal input_resume_requested

const Model = preload("res://game/side_expedition/expedition_model.gd")
const View = preload("res://game/side_expedition/expedition_view.gd")
const Adapter = preload("res://game/side_expedition/signal_adapter.gd")
const Config = preload("res://game/core/input_config.gd")
const Pipeline = preload("res://game/core/input_pipeline.gd")
const Source = preload("res://game/core/manual_input_source.gd")
const Command = preload("res://game/core/control_command.gd")
const Pad = preload("res://game/ui/manual_pad.gd")
const Style = preload("res://game/ui/terminal_style.gd")
const Ledger = preload("res://game/side_expedition/demo_ledger.gd")

var model = Model.new()
## Set before add_child() to use the campaign's already-approved input profile.
var input_config = Config.emulator_profile()
var persistence_enabled: bool = true
var campaign_context: Dictionary = {}
var external_input_mode: bool = false
var _ledger
var _restoring: bool = false
var _last_checkpoint_ms: int = 0
var _save_message: String = ""
var _delivered_reward_ids: Dictionary = {}
var _pipeline
var _source = Source.new()
var _input
var _current
var _origin: int = 0
var _last_sample: int = -1
var _foreground: bool = true
var _paused_by_system: bool = false
var _focused: bool = true
var _skip_frame: bool = true
var _run_counter: int = 0
var _completed_emitted: bool = false
var _mirrored: bool = false
var _view
var _pad
var _title: Label
var _subtitle: Label
var _objective: Label
var _hint: Label
var _keyboard_hint: Label
var _progress: ProgressBar
var _action: Button
var _pause: Button
var _journal_button: Button
var _hand: Button
var _chips: Array[Label] = []
var _journal: AcceptDialog
var _journal_body: RichTextLabel
var _margin: MarginContainer
var _box: VBoxContainer

func _ready() -> void:
	name = "QuietSignal"
	theme = Style.make_theme()
	_ledger = Ledger.new(Ledger.DEFAULT_PATH if persistence_enabled else "")
	if not persistence_enabled and not campaign_context.is_empty():
		_ledger.data.first_delivery_done = bool(campaign_context.get("first_delivery_done", false))
	_input = Adapter.new()
	_input.enabled = not external_input_mode
	add_child(_input)
	_input.channels_changed.connect(_on_channels)
	_build_ui()
	model.stage_changed.connect(_on_stage_changed)
	model.journal_added.connect(_on_journal_added)
	model.expedition_completed.connect(_on_completed)
	model.location_entered.connect(func(id: String, line: String): location_entered.emit(id, line))
	_pipeline = Pipeline.new(input_config)
	_pipeline.command_ready.connect(_on_command)
	_begin_stream()
	resized.connect(_layout)
	_layout()
	_refresh()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("080f1a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	_margin.add_child(_box)
	var header := HBoxContainer.new()
	_box.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	_title = _label("ТИХИЙ СИГНАЛ", 25, Color("e8f3ed"))
	titles.add_child(_title)
	_subtitle = _label("ПОБОЧНАЯ ЭКСПЕДИЦИЯ  /  QS-01", 12, Color("8af0d4"))
	_subtitle.clip_text = true
	titles.add_child(_subtitle)
	_hand = _button("РУКА: ПРАВАЯ", _toggle_hand)
	header.add_child(_hand)
	var menu := MenuButton.new()
	menu.text = "ВЫЛАЗКА ▾"
	menu.add_theme_font_size_override("font_size", 12)
	menu.get_popup().add_item("Вернуться к шлюзу с добычей", 0)
	menu.get_popup().add_item("Новый заход — детали доступны заново", 1)
	menu.get_popup().add_item("Продолжить сохранённый заход", 2)
	menu.about_to_popup.connect(func(): suspend_input(); _save_checkpoint())
	menu.get_popup().id_pressed.connect(_on_menu)
	header.add_child(menu)
	var steps := HBoxContainer.new()
	steps.add_theme_constant_override("separation", 5)
	_box.add_child(steps)
	for text in ["01 ШЛЮЗ", "02 ПОЛЕ ОБЛОМКОВ", "03 ОСТОВ РАЗВЕДЧИКА"]:
		var chip := _label(text, 11, Color("65818e"))
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		steps.add_child(chip)
		_chips.append(chip)
	_view = View.new()
	_view.model = model
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(_view)
	var panel := PanelContainer.new()
	_box.add_child(panel)
	var tasks := VBoxContainer.new()
	panel.add_child(tasks)
	_objective = _label("", 17, Color("f0f6fc"))
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tasks.add_child(_objective)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.max_value = 1.0
	_progress.custom_minimum_size.y = 7
	tasks.add_child(_progress)
	_hint = _label("", 13, Color("ffd166"))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tasks.add_child(_hint)
	_pad = Pad.new()
	if input_config != null:
		_pad.set_thresholds(input_config.on_a, input_config.off_a, input_config.on_b, input_config.off_b)
	_pad.channels_changed.connect(_input.set_touch_channels)
	_box.add_child(_pad)
	_keyboard_hint = _label("[ЭМУЛ]  A / W / ↑ — вверх     B / S / D / ↓ — вниз     отпусти — покой", 12, Color("7594a5"))
	_keyboard_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_keyboard_hint)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	_box.add_child(toolbar)
	_action = _button("ВЫЙТИ ИЗ ШЛЮЗА", _on_action)
	_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Style.primary(_action)
	toolbar.add_child(_action)
	_pause = _button("ПАУЗА", suspend_input)
	toolbar.add_child(_pause)
	_journal_button = _button("ЖУРНАЛ 0", _open_journal)
	toolbar.add_child(_journal_button)
	var exit := _button("ВЫХОД", _on_exit)
	toolbar.add_child(exit)
	_journal = AcceptDialog.new()
	_journal.title = "Тихий сигнал / журнал экспедиции"
	_journal.ok_button_text = "Закрыть журнал"
	_journal.dialog_autowrap = true
	add_child(_journal)
	_journal_body = RichTextLabel.new()
	_journal_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_journal_body.offset_left = 12
	_journal_body.offset_top = 12
	_journal_body.offset_right = -12
	_journal_body.offset_bottom = -60
	_journal_body.custom_minimum_size = Vector2(0, 100)
	_journal_body.scroll_active = true
	_journal_body.selection_enabled = true
	_journal_body.add_theme_font_size_override("normal_font_size", 15)
	_journal.add_child(_journal_body)

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 38
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(callback)
	return button

func _layout() -> void:
	if _view == null:
		return
	var compact := size.y < 500
	for side in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, 8 if compact else 14)
	_box.add_theme_constant_override("separation", 5 if compact else 8)
	_subtitle.visible = not compact
	_keyboard_hint.visible = not compact
	_hint.visible = not compact
	_title.add_theme_font_size_override("font_size", 18 if compact else 25)
	_objective.add_theme_font_size_override("font_size", 13 if compact else 17)
	_view.custom_minimum_size.y = 96 if compact else 170
	_pad.custom_minimum_size.y = 64 if compact else 92
	_pad.set_mirrored(_mirrored)
	_pad.visible = not external_input_mode
	_keyboard_hint.visible = not compact and not external_input_mode
	_hand.visible = not external_input_mode

func _process(delta: float) -> void:
	update_host(_now(), delta)
	if Time.get_ticks_msec() - _last_checkpoint_ms >= 1500:
		_save_checkpoint()

func update_host(now_ms: int, delta: float, heartbeat: bool = true) -> void:
	if external_input_mode:
		var skip := _skip_frame
		_skip_frame = false
		if _foreground and not skip: model.advance(delta, _current)
		_refresh()
		return
	if _pipeline == null:
		return
	_pipeline.tick(now_ms)
	if _foreground and heartbeat and (_last_sample < 0 or now_ms - _last_sample >= 50):
		_sample(now_ms)
	var skip := _skip_frame
	_skip_frame = false
	if _foreground and not skip:
		model.advance(delta, _current)
	_refresh()

func _begin_stream() -> void:
	if external_input_mode:
		_current = Command.new(Command.REST, 0, &"SUSPENDED", &"external_owner", true)
		_skip_frame = true
		input_pause_requested.emit()
		return
	_pipeline.suspend()
	_input.clear()
	_pad.clear()
	_origin = Time.get_ticks_msec()
	_source.reset()
	_pipeline.begin_stream("manual_emulator")
	_last_sample = -1
	_skip_frame = true
	if _foreground:
		_sample(0)
	else:
		_pipeline.suspend()

func _now() -> int:
	return Time.get_ticks_msec() - _origin

func _sample(now_ms: int) -> void:
	_current = _pipeline.submit(_source.sample(now_ms, _input.channels.x, _input.channels.y), now_ms)
	_last_sample = now_ms

func _on_channels(_a: float, _b: float) -> void:
	if not external_input_mode and _pipeline != null and _foreground:
		_sample(_now())

func _on_command(command) -> void:
	_current = command
	model.observe_command(command)

func submit_core_command(command: Command) -> bool:
	if not external_input_mode or command == null or not _foreground: return false
	_on_command(Command.new(command.direction, command.intensity, command.state, command.reason, command.pause_required))
	return true

func start_expedition(p_run_id: String = "") -> void:
	_run_counter += 1
	var id := p_run_id if p_run_id != "" else "quiet-%d-%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec(), _run_counter]
	_completed_emitted = false
	_save_message = ""
	_begin_stream()
	model.begin(id, _ledger.context())
	request_resume()
	_refresh()

func resume_saved() -> bool:
	if not _ledger.has_checkpoint(): return false
	_completed_emitted = false
	_restoring = true
	_begin_stream()
	var ok: bool = model.restore(_ledger.checkpoint(), _ledger.context())
	_restoring = false
	if not ok:
		_ledger.save_checkpoint({})
		start_expedition()
		_save_message = "Начат новый заход: все необходимые детали снова доступны."
		return false
	request_resume()
	_refresh()
	return true

func claim_reward() -> bool:
	if model.stage != "complete" or _completed_emitted: return false
	var claim: Dictionary = _ledger.claim(model.result())
	if not claim.ok:
		_save_message = "Результат пока не сохранён. Нажми получение награды ещё раз."
		_refresh()
		return false
	_completed_emitted = true
	if not claim.already_claimed:
		_deliver_reward(claim.result)
	_refresh()
	return not claim.already_claimed

func _deliver_reward(value: Dictionary) -> void:
	var id: String = value.reward_id
	if _delivered_reward_ids.has(id): return
	_delivered_reward_ids[id] = true
	var embedded := not get_signal_connection_list("expedition_completed").is_empty()
	expedition_completed.emit(value.duplicate(true))
	if not embedded: acknowledge_reward(id)

func flush_pending_rewards() -> void:
	for id in _ledger.pending_events(): _deliver_reward(_ledger.pending_events()[id])
	_refresh()

func acknowledge_reward(id: String) -> bool:
	return _ledger.acknowledge(id)

func _save_checkpoint() -> void:
	_last_checkpoint_ms = Time.get_ticks_msec()
	if _ledger == null or _restoring or _completed_emitted or model.stage == "briefing": return
	var value: Dictionary = model.checkpoint()
	_ledger.save_checkpoint(value)
	checkpoint_changed.emit(value.duplicate(true))

func _on_menu(id: int) -> void:
	match id:
		0: model.request_return(); _save_checkpoint()
		1: _ledger.save_checkpoint({}); start_expedition()
		2: resume_saved()
	_refresh()

func _exit_tree() -> void:
	_save_checkpoint()

func request_resume() -> void:
	if not _foreground or _journal.visible:
		return
	if external_input_mode:
		_skip_frame = true
		input_resume_requested.emit()
		return
	_sample(_now())
	_pipeline.request_resume(_now())
	_skip_frame = true

func suspend_input() -> void:
	if external_input_mode:
		_current = Command.new(Command.REST, 0, &"SUSPENDED", &"external_owner", true)
		_skip_frame = true
		input_pause_requested.emit()
		_refresh()
		return
	if _pipeline == null:
		return
	_pipeline.suspend()
	_input.clear()
	_pad.clear()
	_skip_frame = true
	_refresh()

func _on_action() -> void:
	if model.stage == "complete":
		claim_reward()
	elif model.stage == "briefing":
		if not _ledger.pending_events().is_empty(): flush_pending_rewards()
		elif not _ledger.has_checkpoint(): start_expedition()
		else: resume_saved()
	else:
		request_resume()

func _on_exit() -> void:
	suspend_input()
	_save_checkpoint()
	var embedded := not get_signal_connection_list("exit_requested").is_empty()
	var value: Dictionary = model.result()
	value.reward_proposal = []
	value["reward_pending"] = model.stage == "complete" and not _completed_emitted
	exit_requested.emit(value)
	if not embedded:
		get_tree().quit()

func set_foreground(value: bool) -> void:
	if value == _foreground:
		return
	_foreground = value
	if not value:
		suspend_input()
	else:
		_last_sample = -1
		_skip_frame = true
	_refresh()

func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_paused_by_system = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_paused_by_system = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true
	else:
		return
	set_foreground(not _paused_by_system and _focused)

func _on_stage_changed(id: String) -> void:
	stage_changed.emit(id)
	_save_checkpoint()
	_refresh()

func _on_journal_added(entry: Dictionary) -> void:
	journal_added.emit(entry.duplicate(true))
	_save_checkpoint()
	_refresh()

func _on_completed(result: Dictionary) -> void:
	suspend_input()
	_save_checkpoint()
	_refresh()

func _toggle_hand() -> void:
	suspend_input()
	_mirrored = not _mirrored
	_pad.set_mirrored(_mirrored)
	_hand.text = "РУКА: ЛЕВАЯ" if _mirrored else "РУКА: ПРАВАЯ"

func _open_journal() -> void:
	suspend_input()
	var entries: PackedStringArray = []
	for entry in model.journal:
		entries.append("%s\n%s" % [entry.title, entry.body])
	_journal_body.text = "\n\n".join(entries) if not entries.is_empty() else "Первый сигнал ещё не найден."
	_journal_body.scroll_to_line(0)
	_journal.popup_centered(Vector2i(int(minf(size.x - 40, 760)), int(minf(size.y - 40, 460))))

func _refresh() -> void:
	if _view == null:
		return
	_objective.text = model.objective()
	if model.stage == "complete" and _completed_emitted:
		_objective.text = "Добыча доставлена. Следующий заход — в меню «Вылазка»."
	_subtitle.text = "QS-01  /  " + model.route_text()
	_progress.value = model.task_progress()
	_progress.visible = model.stage in ["salvage", "scout_salvage", "choice", "adapter", "power"]
	_journal_button.text = "ЖУРНАЛ %d" % model.journal.size()
	_pause.disabled = model.stage in ["briefing", "complete"]
	_action.visible = true
	_action.disabled = false
	if model.stage == "briefing":
		_action.text = "ПОЛУЧИТЬ СОХРАНЁННУЮ НАГРАДУ" if not _ledger.pending_events().is_empty() else ("ПРОДОЛЖИТЬ ВЫЛАЗКУ" if _ledger.has_checkpoint() else "ВЫЙТИ ИЗ ШЛЮЗА")
	elif model.stage == "complete":
		_action.text = "НАГРАДА ПОЛУЧЕНА" if _completed_emitted else "ПОЛУЧИТЬ НАГРАДУ"
		_action.disabled = _completed_emitted
	else:
		_action.text = "ПРОДОЛЖИТЬ"
		_action.disabled = not _foreground or _current == null or _current.state != &"WAITING_RESUME" or _journal.visible
	var state: StringName = _current.state if _current != null else &"NOT_STARTED"
	if model.stage not in ["briefing", "complete"]:
		if state == &"ACTIVE": _action.text = "ЭКСПЕДИЦИЯ ИДЁТ"
		elif state == &"REST": _action.text = "ПОКОЙ / ВКЛЮЧИ A ИЛИ B"
		elif state in [&"BOTH", &"WAITING_NEUTRAL"]: _action.text = "ОТПУСТИ ОБА КАНАЛА"
		if model.awaiting_neutral and state in [&"ACTIVE", &"REST"]: _action.text = "ОТПУСТИ ОБА КАНАЛА"
		if state in [&"ACTIVE", &"REST"] and ((model.stage in ["salvage", "scout_salvage"] and model.clamp.needs_neutral()) or (model.stage == "power" and model.power.needs_neutral())):
			_action.text = "ОТПУСТИ ОБА КАНАЛА"
	if _save_message != "":
		_hint.text = _save_message
	elif model.stage == "complete":
		if _completed_emitted: _hint.text = "Награда передана. В меню «Вылазка» можно начать следующий заход."
		elif model.battery_secured: _hint.text = "Первый рейс: батарея + 6 проводников бонусом." if not model.first_delivery_done else "Повтор: батарея + 1 проводник; редкая катушка — если найдена."
		else: _hint.text = "Вернулись с простой добычей. Батарея и нужные детали останутся доступны в следующем заходе."
	elif not _foreground:
		_hint.text = "В фоне всё остановлено. После возврата — нейтраль и «Продолжить»."
	elif state == &"BOTH" or (state == &"WAITING_NEUTRAL" and _current.reason == &"both_requires_neutral"):
		_hint.text = "Встречный сигнал: отпусти оба канала. Ошибки и штрафа нет."
	elif state == &"WAITING_RESUME":
		_hint.text = "Каналы в нейтрали. Нажми «Продолжить», когда будешь готов."
	elif state in [&"WAITING_NEUTRAL", &"SUSPENDED", &"STALE", &"INVALID", &"DISCONNECTED"]:
		_hint.text = "Сигнал остановлен. Отпусти оба канала, затем нажми «Продолжить»."
	elif model.awaiting_neutral:
		_hint.text = "Точка взаимодействия: отпусти оба канала, затем используй A/B для задачи."
	elif model.blocked:
		_hint.text = "Переборка ущелья: измени высоту. Контакт не отнимает батарею."
	elif model.trial_feedback() != "":
		_hint.text = model.trial_feedback()
	elif model.entry_line != "":
		_hint.text = "Маяк: " + model.entry_line
	else:
		_hint.text = "Покой — безопасная остановка. Новые шкалы запасов не используются."
	for i in range(_chips.size()):
		var id: String = Model.LOCATION_ORDER[i]
		var current: bool = id == model.destination_id or (model.destination_id == "" and id == model.location_id)
		_chips[i].add_theme_color_override("font_color", Color("ffd166") if current else (Color("8af0d4") if id in model.location_history else Color("7594a5")))
	_view.queue_redraw()
