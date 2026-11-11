extends Control
## Minimal framing around the ship interiors. Navigation and crafting are UI
## actions; the repair device never receives touch or keyboard input directly.
signal job_requested(level_id: String)
signal resume_requested
signal exit_requested
signal hand_requested
signal quiet_signal_requested
signal menu_requested

const Art = preload("res://game/ui/crash_art.gd")
const State = preload("res://game/station/station_state.gd")
const Assets = preload("res://game/ui/visual_assets.gd")
const World = preload("res://game/gameplay/expedition.gd")
const Navigation = preload("res://game/gameplay/deck_navigation.gd")
const MapView = preload("res://game/ui/expedition_map.gd")
const Sound = preload("res://game/ui/campaign_audio.gd")
const Opening = preload("res://game/ui/opening_timeline.gd")
const LifeSupportHUD = preload("res://game/ui/life_support_hud.gd")
const CargoInventory = preload("res://game/ui/cargo_inventory.gd")
const GardenPlots = preload("res://game/ui/garden_plots.gd")
const ROOMS = World.ROOMS
const Journal = preload("res://game/ui/ship_journal.gd")
const CHAPTER_ENTRIES := ["threshold", "storm", "answer", "epilogue"]
var station: State
var world: World
var nav := Navigation.new()
var sound := Sound.new()
var _map: MapView
var _supplies: LifeSupportHUD
var _map_button: Button
var _menu: Button
var _journal_button: Button
var _journal: Journal
var journal_open: bool:
	get: return is_instance_valid(_journal) and _journal.visible
var menu_open := false
var reduce_motion := false
var _liner: Button
var _cell: Button
var _stabilizer: Button
var _greenhouse_upgrade: Button
var _seed_picker: Button
var _equipment: Button
var _scrap: Button
var _purge: Button
var _crop := "greens"
var _refill_buttons: Dictionary = {}
var _bag_panel: CargoInventory
var _arrival: Callable
var _chapter_cut := 0
var _shift_time := 0.0
var _struck := false
var room := 0
var mode := "room"
var unlocked: Array
var foreground := true:
	set(value):
		foreground = value
		if art != null:
			art.foreground = value and not menu_open and not journal_open
		if is_instance_valid(device): device.set_process(value and not menu_open and not journal_open)
		if sound.is_node_ready(): sound.pause_audio(not value or menu_open or journal_open)
var art: Art
var device: Control
var _action: Button
var _left: Button
var _right: Button
var _bag: Button
var _exit: Button
var _resume: Button
var _title: Label
var _hint: Label
var _objective: Label
var _toast: Label
var _story := ""
var _toast_left := 0.0
var _transition := 0.0
var _verb := ""
var _job := ""
var _intro_clock := 0.0
var _opening_return_room := 0
var _bag_open := false
var _repair_hint := ""
var _repair_barrier := ""


func _ready() -> void:
	art = Art.new()
	add_child(art)
	art.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_bag_panel = CargoInventory.new()
	add_child(_bag_panel)
	_bag_panel.dismissed.connect(_toggle_bag)
	_bag_panel.item_chosen.connect(func(_key): _refresh_refill_buttons())
	_title = make_label(19, "eee1d5")
	_hint = make_label(17, "fff1d8")
	_objective = make_label(16, "ffe0ac")
	_toast = make_label(16, "f5ca9a")
	_action = make_button("", _activate)
	_left = make_button("На корабль", func(): _enter(0))
	_right = make_button("", _follow_objective)
	_bag = make_button("Склад", _toggle_bag)
	_menu = make_button("Меню", func(): menu_requested.emit())
	_journal_button = make_button("Журнал", _open_journal)
	_journal = Journal.new()
	add_child(_journal)
	_journal.visibility_changed.connect(func():
		if not _journal.visible: _journal_button.release_focus()
		foreground = foreground)
	_exit = make_button("В отсек", func(): exit_requested.emit())
	_resume = make_button("Продолжить", func(): resume_requested.emit())
	_action.add_theme_stylebox_override("normal", Assets.skin("button_hot"))
	_resume.add_theme_stylebox_override("normal", Assets.skin("button_hot"))
	add_child(sound)
	art.navigator = nav
	_map_button = make_button("План", _toggle_map)
	_liner = make_button("Подкладка · 3кр + 2дет", func():
		if world.craft("liner"):
			sound.fx("craft")
			show_room("Подкладка готова. Руда и кристаллы дают +1 к каждой находке."))
	_cell = make_button("Батарея · 1руда + 1кр", func():
		if world.craft("cell"):
			sound.fx("craft")
			show_room("Из материалов собрана батарея. Заряд +3."))
	_stabilizer = make_button("Стабилизатор · 1спл + 2кр", func():
		if world.craft("stabilizer"):
			sound.fx("craft")
			show_room("Стабилизатор даёт ещё 0,8 с до грозового импульса."))
	_greenhouse_upgrade = make_button("Биосад · 6 дет. + 2 еды", func():
		if station.upgrade_garden():
			sound.fx("craft")
			show_room("Уровень 2 · Ягоды открыты"))
	_seed_picker = make_button("", _change_seed)
	_equipment = make_button("", _install_equipment)
	_scrap = make_button("Разобрать обломки", _queue_salvage)
	_purge = make_button("Продувка", func():
		if foreground and _purge.visible: job_requested.emit("repair-1"))
	for recipe_button in [_liner, _cell, _stabilizer, _greenhouse_upgrade]:
		recipe_button.add_theme_font_size_override("font_size", 14)
		recipe_button.custom_minimum_size.y = 44
		recipe_button.reparent(_bag_panel.actions, false)
	for key in State.SUPPLY_PER_UNIT:
		var button := make_button("%s +%d п. п." % [State.NAMES[key], State.SUPPLY_PER_UNIT[key]], _refill.bind(key))
		button.tooltip_text = "Перенести 1 единицу со склада в систему корабля"
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.reparent(_bag_panel.transfer, false)
		_refill_buttons[key] = button
	_supplies = LifeSupportHUD.new()
	add_child(_supplies)
	_map = MapView.new()
	add_child(_map)
	_map.room_chosen.connect(func(id):
		_enter(id))
	_map.quiet_signal_requested.connect(func(): quiet_signal_requested.emit())
	_map.dismissed.connect(func():
		_map.hide()
		refresh())
	resized.connect(_layout)

func bind(model: State, levels: Array) -> void:
	station = model
	art.station = model
	_supplies.station = station
	world = World.new(station)
	_restore_dialogue()
	nav.enter(0,0)
	unlocked = levels
	station.changed.connect(refresh)
	if not station.data.intro_seen:
		_begin_opening()
	else:
		_enter(clampi(int(station.data.saved_room), 0, ROOMS.size() - 1))
	refresh()

func _process(delta: float) -> void:
	if station == null or not foreground or menu_open or journal_open: return
	if _bag_panel.visible and room < 6:
		_refresh_refill_buttons()
	if _transition > 0:
		_transition = maxf(0, _transition - delta)
		art.modulate = Color.WHITE.lerp(Color("3f4664"), _transition / 0.28)
	if mode == "room" and not _map.visible:
		var previous_footfall := nav.footfall
		nav.advance(delta)
		if nav.footfall != previous_footfall:
			sound.footstep(art.room, nav.depth())
		if not nav.moving and _arrival.is_valid():
			var action := _arrival
			_arrival = Callable()
			action.call()
		if world.tick(delta):
			_refresh_deposits()
		_shift_time += delta
		art.storm_pressure = 0.25 + 0.24 * sin(_shift_time * 0.45)
		_update_storm()
	if mode == "intro":
		_intro_clock = minf(_intro_clock + delta,Opening.DURATION)
		if _intro_clock >= Opening.DURATION:
			_finish_cut()
		else:
			var frame := Opening.frame_at(_intro_clock)
			var id: int = Opening.SHOTS[frame]
			if art.shot != id:
				art.shot = id
				refresh()
			art.age = _intro_clock - Opening.TIMECODES[frame]
			_log_opening_through(_intro_clock)
	elif mode in ["takeoff","chapter"]:
		_intro_clock += minf(delta, 0.1)
		var duration := 4.6 if mode == "chapter" else 5.0
		if _intro_clock >= duration:
			_finish_cut()
	if _toast_left > 0:
		_toast_left -= delta
		if _toast_left <= 0:
			_toast.hide()

func _begin_opening() -> void:
	if not foreground or mode != "room": return
	_opening_return_room = room
	_intro_clock = 0
	_arrival = Callable()
	_bag_open = false
	_map.hide()
	art.modulate = Color.WHITE
	_transition = 0
	mode = "intro"
	art.opening = true
	art.shot = Opening.SHOTS[0]
	art.age = 0
	sound.start_opening()
	refresh()

func _finish_cut() -> void:
	var previous := mode
	if previous == "intro":
		_log_opening_through(Opening.DURATION)
		station.finish_intro()
		sound.stop_opening()
		art.opening = false
	mode = "room"
	art.shot = -1
	if previous == "chapter":
		sound.room(art.room,station.data.signal)
		if _chapter_cut == 0: log_dialogue("ravine")
		refresh()
	elif previous == "intro":
		_enter(_opening_return_room)
	else:
		_enter(0)
		if previous == "takeoff": chapter_scene(3)

func chapter_scene(index: int) -> void:
	if index in world.data.story_flags: return
	world.data.story_flags.append(index)
	station.save()
	_chapter_cut = index
	mode = "chapter"
	_intro_clock = 0
	art.shot = 5 + index
	art.age = 0
	sound.cue([9,12,13,14][index])
	log_dialogue(CHAPTER_ENTRIES[index])
	refresh()

func _enter(target: int) -> void:
	if target < 0 or target >= ROOMS.size() or not foreground or menu_open: return
	if not world.locked(target).is_empty():
		show_room(world.locked(target))
		return
	_arrival = Callable()
	_map.hide()
	var direction := signi(target - room)
	room = target
	var previous_art: int = art.room
	art.room = World.physical_room(room)
	_shift_time = 0
	_struck = false
	art.strike_strength = 0
	if previous_art != art.room:
		nav.enter(art.room,direction)
	else:
		nav.walk_to(nav.feet)
	art.age = 0.0
	_transition = 0.0 if reduce_motion or previous_art == art.room else 0.28
	_bag_open = false
	_story = ""
	_toast.hide()
	var first := world.discover(room)
	sound.room(art.room,station.data.signal)
	sound.fx("click" if previous_art == art.room else "hatch")
	if first and room == 7:
		chapter_scene(0)
	elif first and room == 9:
		chapter_scene(1)
	elif first and room == 8:
		log_dialogue("cave")
	refresh()

func show_room(message := "") -> void:
	mode = "room"
	art.shot = -1
	art.repairing = false
	_story = message
	if not message.is_empty():
		_toast_left = 3.8
	refresh()

func show_repair(title: String) -> void:
	mode = "repair"
	_arrival = Callable()
	art.repairing = true
	_title.text = title
	_repair_hint = ""
	_repair_barrier = ""
	_resume.hide()
	refresh()

func repair_hint(value: String) -> void:
	_repair_hint = value
	_update_repair_hint()

func repair_barrier(value: String, can_resume: bool) -> void:
	_repair_barrier = value
	_resume.visible = mode == "repair" and can_resume
	_update_repair_hint()

func _update_repair_hint() -> void:
	if mode == "repair":
		_hint.text = _repair_barrier if not _repair_barrier.is_empty() else _repair_hint
		_layout()

func log_dialogue(id: String, persist := true) -> void:
	if id in world.data.dialogue or Journal.line_for(id).is_empty(): return
	world.data.dialogue.append(id)
	_journal_button.text = "Журнал •"
	if persist: station.save()

func _log_opening_through(seconds: float) -> void:
	for cue in Opening.DIALOGUE_CUES:
		if seconds >= float(cue[0]): log_dialogue(cue[2], false)

func _restore_dialogue() -> void:
	if not world.data.dialogue.is_empty(): return
	if station.data.intro_seen: _log_opening_through(Opening.DURATION)
	for key in ["air_ready", "pump", "generator", "beacon", "signal", "launched"]:
		if station.data[key]:
			log_dialogue({"air_ready":"air", "pump":"water", "signal":"answer", "launched":"home"}.get(key,key), false)
	for flag in world.data.story_flags:
		log_dialogue(["threshold", "storm", "answer", "epilogue", "wreck", "seam"][flag], false)
	if 7 in world.data.discovered: log_dialogue("ravine", false)
	if 8 in world.data.discovered: log_dialogue("cave", false)
	if world.data.relay: log_dialogue("relay", false)

func _open_journal() -> void:
	if not foreground or menu_open or journal_open or not _journal_button.visible: return
	_arrival = Callable()
	_map.hide()
	_bag_open = false
	refresh()
	_journal_button.text = "Журнал"
	_journal.show_entries(world.data.dialogue, size)

func _follow_objective() -> void:
	var target: int = world.next_objective()[0]
	if target >= 0 and target != room:
		_enter(target)

func refresh() -> void:
	if station == null: return
	world.available_repairs = unlocked
	_supplies.visible = mode in ["room", "repair"]
	_bag_panel.visible = _bag_open and mode == "room"
	_objective.visible = mode == "room" and not _bag_open and not _map.visible
	_refresh_refill_buttons()
	_map_button.visible = mode == "room"
	_menu.visible = mode in ["room", "repair", "intro", "chapter", "takeoff"]
	_journal_button.visible = mode in ["room", "intro", "chapter", "takeoff"]
	_liner.visible = _bag_open and mode == "room" and room == 2 and not world.data.liner
	_liner.disabled = not world.can_craft("liner")
	_cell.visible = _bag_open and mode == "room" and room == 2 and world.data.filter
	_cell.disabled = not world.can_craft("cell")
	_stabilizer.visible = _cell.visible and world.data.shield and not world.data.stabilizer
	_stabilizer.disabled = not world.can_craft("stabilizer")
	_greenhouse_upgrade.visible = _bag_panel.visible and room == 3 and station.data.garden and int(station.data.garden_level) < 2
	_greenhouse_upgrade.disabled = not station.can_pay(State.UPGRADE_COST)
	_greenhouse_upgrade.tooltip_text = "Больше зелени и новый сорт · " + State.cost_text(State.UPGRADE_COST)
	_seed_picker.visible = room == 3 and mode == "room" and not _bag_open and not _map.visible and int(station.data.garden_level) >= 2
	_seed_picker.text = "Ягоды · 32 с" if _crop == "berries" else "Зелень · 18 с"
	_seed_picker.tooltip_text = "Сменить семена · " + State.cost_text(_seed_cost())
	_refresh_equipment()
	_scrap.hide()
	_purge.visible = mode == "room" and room == 3 and station.data.garden and world.data.weather_event == "dust" and not _bag_open and not _map.visible
	if mode == "repair":
		_left.hide()
		_right.hide()
		_action.hide()
		_bag.hide()
		_toast.hide()
		_exit.show()
		_layout()
		return
	_left.hide()
	_right.hide()
	_action.hide()
	_bag.hide()
	_toast.hide()
	_exit.visible = mode == "repair"
	_resume.hide()
	if mode in ["intro","takeoff","chapter"]:
		_title.text = "" if mode == "intro" and art.shot != 0 else "МАЯК  /  ПОСЛЕДНИЙ СВЕТ"
		_hint.text = ""
		_action.text = "Пропустить"
		_verb = "skip"
		_action.disabled = false
		_action.show()
		_layout()
		return
	_title.text = World.ROOMS[room] if room == art.room else "Рубка  /  " + World.ROOMS[room]
	_bag.show()
	if _bag_open:
		_bag_panel.update_cargo(station.data, world.data)
	_refresh_deposits()
	if _map.visible: _map.update_map(world,room)
	var objective := world.next_objective()
	var target: int = objective[0]
	_objective.text = "%s  ·  %s" % [World.CHAPTERS[world.chapter()][0], objective[1]]
	_left.visible = room >= 6 and not _map.visible
	_right.visible = target >= 0 and target != room and not _map.visible
	if _right.visible: _right.text = "К задаче   ◆"
	_toast.text = _story if station.save_ok else "Не удалось записать сохранение"
	_toast.visible = (not _bag_open and not _map.visible and _toast_left > 0) or not station.save_ok
	_room_action()
	if art.room == 0: art.restored = station.data.air_ready
	_scrap.visible = room == 2 and _verb != "job" and not _bag_open and not _map.visible
	if _bag_open or _map.visible:
		_action.hide()
		_left.hide()
		_right.hide()
		_hint.hide()
	else:
		_hint.show()
	_layout()

func _room_action() -> void:
	var d := station.data
	match room:
		0:
			art.restored = d.air_ready
			if not d.air_ready:
				_offer_job("Закрыть заслонку", "Корпус пробит. Перекрой воздуховод.", "tutorial")
			elif d.launched:
				_offer("", "Полёт домой. Отсеки доступны в свободном режиме.", "")
			elif d.signal:
				_offer_cost("Взлететь", State.LAUNCH_COST, "launch")
			else:
				_offer("", "", "")
		1:
			art.restored = d.pump
			_offer_job("Наполнить бак" if d.pump else "Открыть клапан", "Каждый прогон: до +24 п. п. воды и 3 канистры." if d.pump else "Жара растёт. Верни воду в контур.", "repair-1")
		2:
			art.restored = d.fuses > 0 or d.coils > 0
			if not d.beacon and d.fuses == 0 and d.coils == 0 and station.can_pay({"parts": 2, "energy": 1}):
				_offer_cost("Собрать предохранитель", {"parts": 2, "energy": 1}, "fuses")
			elif d.generator and not d.beacon and d.fuses > 0 and d.coils == 0 and station.can_pay({"parts": 3}):
				_offer_cost("Намотать катушку", {"parts": 3, "fuses": 1}, "coils")
			elif not world.data.shield and world.can_craft("shield"):
				_world_recipe("Экран для антенны","shield")
			elif not world.data.shield and world.data.alloy == 0 and world.can_craft("alloy"):
				_world_recipe("Выплавить сплав","alloy")
			else:
				_offer_job("Разобрать обломки", "Добыча: детали и заряд.", "tutorial")
		3:
			art.restored = d.garden
			if not d.garden:
				_offer_cost("Запустить биосад", State.BUILD_COSTS.garden, "garden", "Нужен насос" if not d.pump else "")
			elif station.ripe_bed() >= 0:
				_offer("Собрать", "", "harvest")
			elif -1.0 in d.beds and station.can_pay(_seed_cost()):
				_offer_cost("Посадить", _seed_cost(), "plant")
			else:
				_offer("", "Нужны вода и заряд" if -1.0 in d.beds else "", "")
		4:
			art.restored = d.generator
			if not d.generator:
				var missing := "Нужен предохранитель из мастерской." if d.fuses == 0 else ""
				if d.harvests == 0: missing = "Сначала вырасти еду для экипажа."
				_offer_cost("Собрать реактор", State.BUILD_COSTS.generator, "generator", missing)
			else:
				_offer_job("Захватить фазу", "Каждый прогон: до +36 п. п. энергии, 4 заряда и деталь.", "repair-2")
		5:
			art.restored = d.signal
			if not d.beacon:
				var missing := "Нужна катушка из мастерской." if d.coils == 0 else ""
				if not d.generator: missing = "Сначала собери реактор."
				_offer_cost("Подключить антенну", State.BUILD_COSTS.beacon, "beacon", missing)
			elif not d.signal and "repair-3" not in unlocked:
				_offer("", "Антенне нужен стабильный ток. Синхронизируй реактор.", "")
			elif not d.signal:
				_offer_job("Настроить частоту", "Поймай ответ орбитального патруля.", "repair-3")
			else:
				_offer_job("Проверить частоту", "Сигнал принят. В рубке можно готовить взлёт.", "repair-3")

		6:
			art.restored = world.data.filter
			if not world.data.filter:
				_world_recipe("Собрать фильтр","filter")
			else:
				_offer("", "Фильтр готов. Выход в ущелье справа.", "")
		7:
			art.restored = false
			_offer("", "Выбери светящуюся залежь. Обломки и руда восстанавливаются.", "")
		8:
			art.restored = world.data.extractor
			if not world.data.extractor:
				_offer_job("Откалибровать бур", "Зажим заклинило. Четыре хода с полным отпусканием.", "repair-1")
			else:
				_offer("", "Возьми кристаллы. Экран для антенны собирается в мастерской.", "")
		9:
			art.restored = world.data.relay
			_offer_job("Повторить синхронизацию" if world.data.relay else "Поймать окно связи",
				"Три фазовых окна. Порыв сбрасывает только текущую фазу.", "repair-3")

func _world_recipe(title: String, id: String) -> void:
	_offer(title,world.price(id),id if world.can_craft(id) else "")


func _offer_job(title: String, message: String, id: String) -> void:
	_job = id
	_offer(title, message, "job" if id in unlocked else "")

func _offer_cost(title: String, cost: Dictionary, verb: String, blocker := "") -> void:
	var price := State.cost_text(cost)
	var allowed := blocker.is_empty() and station.can_pay(cost)
	_offer(title, blocker if not blocker.is_empty() else price, verb if allowed else "")

func _offer(title: String, hint: String, verb: String) -> void:
	_verb = verb
	art.material_preview = verb if verb in ["filter","alloy","shield"] else ""
	_action.text = title
	_action.visible = not title.is_empty()
	_action.disabled = verb.is_empty()
	_hint.text = hint

func _activate() -> void:
	if not foreground or menu_open: return
	if mode == "room":
		var intended := _verb
		var target := Vector2(float([193, 117, 153, 193, 236, 273][room]) if room < 6 else 193.0, 194)
		_arrival = func():
			if _verb == intended and mode == "room": _perform()
		if not nav.walk_to(target): _arrival = Callable()
	else:
		_perform()

func _perform() -> void:
	match _verb:
		"skip": _finish_cut()
		"job": job_requested.emit(_job)
		"filter", "alloy", "shield":
			if world.craft(_verb):
				sound.fx("craft")
				show_room("Компонент готов.")
		"fuses", "coils":
			if station.craft(_verb):
				sound.fx("craft")
				show_room(station.notice)
		"garden", "generator", "beacon":
			var module := _verb
			if station.build(module, module == "beacon"):
				if module in ["generator", "beacon"]: log_dialogue(module)
				sound.fx("craft")
				var note: String = {"garden": "Биосад работает",
					"generator": "Реактор собран. Синхронизируй контур.",
					"beacon": "Катушка установлена. Настрой антенну."}[module]
				show_room(note)
		"plant":
			_tend_bed(station.data.beds.find(-1.0))
		"harvest":
			_tend_bed(station.ripe_bed())
		"launch":
			if station.launch():
				mode = "takeoff"
				_intro_clock = 0.0
				art.shot = 4
				art.age = 0.0
				sound.cue(14)
				log_dialogue("home")
				refresh()

func _refresh_deposits() -> void:
	art.resource_points.clear()
	var nodes := world.nodes(room)
	for i in range(nodes.size()):
		var item: Array = nodes[i]
		var hue := Color("8af4f6") if item[1] == "silica" else Color("ffd889")
		var sprite: String = "scrap" if room == 7 and i == 1 else item[1]
		art.resource_points.append([item[0],world.remaining(room,i) == 0,hue,sprite])

func _gui_input(event: InputEvent) -> void:
	if mode != "room" or not foreground or menu_open or journal_open or _map.visible or _bag_open: return
	var point: Vector2
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		point = event.position
	elif event is InputEventScreenTouch and event.pressed:
		point = event.position
	else: return
	var frame := art.frame_rect()
	if not frame.has_point(point): return
	var floor_point := (point - frame.position) * Art.FRAME / frame.size
	if room == 3 and station.data.garden:
		var bed := GardenPlots.index_at(floor_point)
		if bed >= 0:
			_arrival = Callable()
			_tend_bed(bed)
			accept_event()
			return
	var nodes := world.nodes(room)
	for i in range(nodes.size()):
		if floor_point.distance_to(nodes[i][0]) < 19:
			queue_collect(i)
			accept_event()
			return
	_arrival = Callable()
	nav.walk_to(floor_point)
	accept_event()

func queue_collect(index: int) -> void:
	var nodes := world.nodes(room)
	if index < 0 or index >= nodes.size(): return
	if room == 8 and not world.data.extractor:
		show_room("Кристаллы зажаты породой. Сначала откалибруй бур.")
		return
	var visited_room := room
	_arrival = func():
		if room != visited_room: return
		var reward := world.collect(room,index)
		if not reward.is_empty():
			sound.fx("pickup")
			var flag := 4 if room == 7 and index == 1 else (5 if room == 8 else -1)
			if flag >= 0 and flag not in world.data.story_flags:
				world.data.story_flags.append(flag)
				station.save()
				log_dialogue("wreck" if flag == 4 else "seam")
			show_room(reward)
		else:
			show_room("Залежь пустая. Осталось %d с." % ceili(world.remaining(room,index)))
	if not nav.walk_to(nodes[index][0]): _arrival = Callable()

func _toggle_map() -> void:
	if mode != "room" or menu_open: return
	sound.fx("click")
	_arrival = Callable()
	_map.visible = not _map.visible
	if _map.visible and _bag_open:
		_bag_open = false
	_map.update_map(world,room)
	refresh()

func _update_storm() -> void:
	if room != 7:
		art.strike_strength = 0
		return
	var cycle := int(_shift_time / 9.0)
	var phase := fmod(_shift_time,9.0)
	art.strike_point = Vector2(165.0 if cycle % 2 == 0 else 278.0,191.0)
	art.strike_strength = clampf((phase - 6.0) / 1.7,0,1) if phase < 8.15 else 0.0
	if phase < 6:
		_struck = false
	elif not _struck and phase >= 7.7:
		_struck = true
		sound.fx("impact")
		var offset := (nav.feet - art.strike_point) * Vector2(1,2.6)
		if offset.length() < 32.0:
			_arrival = Callable()
			nav.enter(room,0)
			show_room("Разряд! Ты укрылся у входа. Запасы целы.")

func _toggle_bag() -> void:
	if menu_open: return
	sound.fx("click")
	_bag_open = not _bag_open
	if _bag_open: _map.hide()
	refresh()

func _refill(key: String) -> void:
	if not _bag_panel.visible or room >= 6: return
	if station.refill_from_stock(key):
		sound.fx("pickup")
		show_room(station.notice)

func _seed_cost() -> Dictionary:
	return State.BERRY_COST if _crop == "berries" else State.PLANT_COST

func _refresh_equipment() -> void:
	_equipment.hide()
	if mode != "room" or _bag_open or _map.visible or not World.INSTALLATIONS.has(room): return
	if not (station.data.pump if room == 1 else station.data.generator): return
	var id: String = World.INSTALLATIONS[room]
	_equipment.show()
	_equipment.disabled = world.data[id]
	_equipment.text = ("Конденсатор" if room == 1 else "Накопитель") + (" ✓" if world.data[id] else " +")
	_equipment.tooltip_text = world.price(id)

func _install_equipment() -> void:
	if not _equipment.visible or _equipment.disabled: return
	var id: String = World.INSTALLATIONS[room]
	if world.craft(id):
		sound.fx("craft")
		show_room("Вода −2 п. п./мин · снаружи −3" if room == 1 else "Энергия −2 п. п./мин")
	else:
		sound.fx("click")
		show_room(world.price(id))

func _queue_salvage() -> void:
	if not foreground or not _scrap.visible: return
	_arrival = func():
		if mode == "room" and room == 2 and not _map.visible and not _bag_open:
			job_requested.emit("tutorial")
	if not nav.walk_to(Vector2(193, 194)): _arrival = Callable()

func _change_seed() -> void:
	_crop = "greens" if _crop == "berries" else "berries"
	art.selected_crop = _crop
	sound.fx("click")
	refresh()

func _tend_bed(index: int) -> void:
	if index < 0: return
	var elapsed := float(station.data.beds[index])
	if elapsed < 0.0:
		if station.plant(index, _crop):
			sound.fx("click")
			if station.data.harvests == 0: show_room("Растёт · Можно заняться ремонтом")
		else:
			show_room(State.cost_text(_seed_cost()))
	elif elapsed >= station.grow_seconds(index):
		var amount := station.crop_yield(index)
		if station.harvest(index):
			sound.fx("pickup")
			art.garden.reward_index = index
			art.garden.reward_time = art.age
			art.garden.reward_yield = amount
			show_room("Урожай +%d · Улучшение на складе" % amount if station.data.harvests == 1 else "Урожай +%d" % amount)
	else:
		show_room("До урожая · ≈%d с" % ceili(station.grow_seconds(index) - elapsed))

func _refresh_refill_buttons() -> void:
	for key in _refill_buttons:
		var button: Button = _refill_buttons[key]
		button.visible = _bag_panel.visible and room < 6 and _bag_panel.selected == key
		button.disabled = not station.can_refill_from_stock(key)

func _layout() -> void:
	if _hint == null: return
	var f := art.frame_rect()
	var x := f.position.x + 12
	var top := f.position.y + 8
	var w := f.size.x - 24
	var bottom := f.end.y - 10
	if mode == "room":
		place(_title, Vector2(x + 166, top), Vector2(maxf(50.0, w - 366), 31))
	else:
		place(_title, Vector2(x + 81, top), Vector2(w - 195, 31))
	place(_bag, Vector2(x+w-96, top), Vector2(96, 47))
	place(_menu, Vector2(x,top),Vector2(75,47))
	place(_journal_button, Vector2(x + 81, bottom - 47), Vector2(99, 47))
	if mode == "room": place(_journal_button, Vector2(x + w - 195, top), Vector2(95,47))
	place(_map_button, Vector2(x+81,top),Vector2(81,47))
	var supply_w := minf(w, 444.0)
	place(_supplies, Vector2(roundf(x+(w-supply_w)*0.5), top+43), Vector2(supply_w, 35))
	place(_seed_picker, Vector2(x+w-145,top+84),Vector2(145,43))
	place(_equipment, Vector2(x+w-162,top+84),Vector2(162,43))
	place(_scrap, Vector2(x+w-196,top+84),Vector2(196,43))
	place(_purge, Vector2(x,top+84),Vector2(144,43))
	var bag_width := minf(w, 696.0)
	place(_bag_panel, Vector2(x+(w-bag_width)*0.5, top+81), Vector2(bag_width,maxf(235.0,bottom-top-81)))
	_liner.tooltip_text = world.price("liner") if world != null else ""
	var map_w := minf(w,870.0)
	place(_map,Vector2(x+(w-map_w)*0.5,top+82),Vector2(map_w,maxf(230.0,bottom-top-82)))
	place(_exit, Vector2(x+w-90, top), Vector2(90, 36))
	place(_objective, Vector2(x,top+81), Vector2(w,46))
	place(_toast, Vector2(x,top+124), Vector2(w,38))
	var action_width := minf(w, 318)
	var nav_width := minf(200.0, w * 0.47)
	place(_left, Vector2(x, bottom-47), Vector2(nav_width, 47))
	place(_right, Vector2(x+w-nav_width, bottom-47), Vector2(nav_width, 47))
	place(_action, Vector2(x+(w-action_width)*0.5, bottom-103), Vector2(action_width, 50))
	var hint_height := 144 if _action.visible else 88
	place(_hint, Vector2(x, bottom-hint_height if mode == "room" else bottom-132), Vector2(w, 39))
	if mode in ["intro", "takeoff", "chapter"]:
		place(_action, Vector2(x+w-106,top),Vector2(106,34))
		place(_hint, Vector2(x,bottom-43),Vector2(w,40))
	if mode == "repair":
		# Repair touch pads sit in a separate strip below the picture.
		var repair_hint_h := 61 if _hint.get_theme_font_size("font_size") > 17 else 43
		place(_hint, Vector2(x, bottom-repair_hint_h), Vector2(w, repair_hint_h))
		place(_resume, Vector2(x+(w-action_width)*0.5,bottom-repair_hint_h-43),Vector2(action_width,42))
		if is_instance_valid(device):
			place(device, f.position + f.size * Vector2(0.17,0.16), f.size * Vector2(0.66,0.65))

func make_label(font_size: int, tint: String) -> Label:
	var node := Label.new()
	node.mouse_filter = MOUSE_FILTER_IGNORE
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", Color(tint))
	node.add_theme_color_override("font_shadow_color", Color("070c16"))
	node.add_theme_constant_override("shadow_offset_y", 2)
	node.add_theme_color_override("font_outline_color", Color("14101e"))
	node.add_theme_constant_override("outline_size", 4)
	add_child(node)
	return node

func make_button(title: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = title
	node.clip_text = true
	node.add_theme_font_size_override("font_size", 16)
	for state in ["normal","hover","focus","pressed","disabled"]:
		var id := "button_hot" if state in ["hover", "focus", "pressed"] else "button"
		node.add_theme_stylebox_override(state, Assets.skin(id, true))
	node.add_theme_color_override("font_color", Color("f4ede8"))
	node.add_theme_color_override("font_hover_color", Color("fff1c8"))
	node.add_theme_color_override("font_pressed_color", Color("fff5dc"))
	node.add_theme_color_override("font_disabled_color", Color("adb4c5"))
	node.add_theme_color_override("font_outline_color", Color("14101e"))
	node.add_theme_constant_override("outline_size", 3)
	add_child(node)
	node.button_down.connect(_button_motion.bind(node, Color("cfaf95")))
	node.button_up.connect(_button_motion.bind(node, Color.WHITE))
	node.visibility_changed.connect(func():
		if not node.visible:
			_stop_button_motion(node)
			node.self_modulate = Color.WHITE)
	node.pressed.connect(action)
	return node

func _button_motion(node: Button, target: Color) -> void:
	_stop_button_motion(node)
	if reduce_motion:
		node.self_modulate = target
		return
	var tween := node.create_tween()
	node.set_meta("motion", tween)
	tween.tween_property(node, "self_modulate", target, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _stop_button_motion(node: Button) -> void:
	if node.has_meta("motion"):
		var motion := node.get_meta("motion") as Tween
		if motion.is_valid(): motion.kill()

func place(node: Control, position: Vector2, dimensions: Vector2) -> void:
	node.position = position
	node.size = dimensions

func apply_accessibility(large_text: bool, less_motion: bool) -> void:
	reduce_motion = less_motion
	art.reduce_motion = less_motion
	_hint.add_theme_font_size_override("font_size", 22 if large_text else 17)
	_toast.add_theme_font_size_override("font_size", 20 if large_text else 16)
	_objective.add_theme_font_size_override("font_size", 19 if large_text else 16)
	_bag_panel.set_large_text(large_text)
	_journal.body.add_theme_font_size_override("normal_font_size", 21 if large_text else 17)
	_supplies.large_text = large_text
	_supplies.queue_redraw()
	if is_instance_valid(device): device.reduce_motion = less_motion
	if less_motion:
		_transition = 0.0
		art.modulate = Color.WHITE
	_layout()
