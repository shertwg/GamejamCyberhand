extends Control
## Minimal framing around the ship interiors. Navigation and crafting are UI
## actions; the repair device never receives touch or keyboard input directly.
signal job_requested(level_id: String)
signal resume_requested
signal exit_requested
signal hand_requested
signal quiet_signal_requested

const Art = preload("res://game/ui/crash_art.gd")
const State = preload("res://game/station/station_state.gd")
const Assets = preload("res://game/ui/visual_assets.gd")
const World = preload("res://game/gameplay/expedition.gd")
const Navigation = preload("res://game/gameplay/deck_navigation.gd")
const MapView = preload("res://game/ui/expedition_map.gd")
const Sound = preload("res://game/ui/campaign_audio.gd")
const Opening = preload("res://game/ui/opening_timeline.gd")
const LifeSupportHUD = preload("res://game/ui/life_support_hud.gd")
const GardenPlots = preload("res://game/ui/garden_plots.gd")
const ROOMS = World.ROOMS
const CHAPTER_LINES := ["Маяк: фильтр держит. Возьми образец в ущелье.",
	"Маяк: буря уже на хребте. Держи руку ровно.",
	"Орбита: сигнал получен. Ваш коридор открыт.",
	"Рейнджер: я думал, мы останемся здесь. Пора домой."]
var station: State
var world: World
var nav := Navigation.new()
var sound := Sound.new()
var _map: MapView
var _supplies: LifeSupportHUD
var _map_button: Button
var _mute: Button
var _replay: Button
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
var _bag_panel: Panel
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
			art.foreground = value
		if sound.is_node_ready(): sound.pause_audio(not value)
var art: Art
var device: Control
var _action: Button
var _left: Button
var _right: Button
var _bag: Button
var _hand: Button
var _exit: Button
var _resume: Button
var _title: Label
var _hint: Label
var _stock: Label
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
	_bag_panel = Panel.new()
	_bag_panel.mouse_filter = MOUSE_FILTER_IGNORE
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color("141521f2")
	backing.border_color = Color("786050")
	backing.set_border_width_all(2)
	backing.shadow_color = Color("090a12cc")
	backing.shadow_size = 5
	_bag_panel.add_theme_stylebox_override("panel", backing)
	add_child(_bag_panel)
	_title = make_label(19, "eee1d5")
	_hint = make_label(17, "fff1d8")
	_stock = make_label(14, "b1d8db")
	_stock.add_theme_constant_override("line_spacing", 1)
	_toast = make_label(16, "f5ca9a")
	_action = make_button("", _activate)
	_left = make_button("", func(): _enter(room - 1))
	_right = make_button("", func(): _enter(room + 1))
	_bag = make_button("Запасы", _toggle_bag)
	_hand = make_button("Левая / правая рука", func(): hand_requested.emit())
	_exit = make_button("В отсек", func(): exit_requested.emit())
	_resume = make_button("Продолжить", func(): resume_requested.emit())
	_action.add_theme_stylebox_override("normal", Assets.skin("button_hot"))
	_resume.add_theme_stylebox_override("normal", Assets.skin("button_hot"))
	add_child(sound)
	art.navigator = nav
	_map_button = make_button("Карта", _toggle_map)
	_mute = make_button("Звук", func():
		sound.toggle()
		_mute.text = "Тихо" if sound.muted else "Звук")
	_replay = make_button("Вступление", _begin_opening)
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
	for key in State.SUPPLY_PER_UNIT:
		var button := make_button("%s +%d п. п." % [State.NAMES[key], State.SUPPLY_PER_UNIT[key]], _refill.bind(key))
		button.tooltip_text = "Перенести 1 единицу со склада в систему корабля"
		_refill_buttons[key] = button
	_supplies = LifeSupportHUD.new()
	add_child(_supplies)
	_map = MapView.new()
	add_child(_map)
	_map.room_chosen.connect(func(id):
		if id in world.data.discovered: _enter(id))
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
	nav.enter(0,0)
	unlocked = levels
	station.changed.connect(refresh)
	if not station.data.intro_seen:
		_begin_opening()
	else:
		sound.room(0,station.data.signal)
	refresh()

func _process(delta: float) -> void:
	if station == null or not foreground: return
	if _bag_panel.visible and room < 6:
		_refresh_refill_buttons()
	if _transition > 0:
		_transition = maxf(0, _transition - delta)
		art.modulate = Color.WHITE.lerp(Color("3f4664"), _transition / 0.28)
	if mode == "room" and not _map.visible:
		var previous_footfall := nav.footfall
		nav.advance(delta)
		if nav.footfall != previous_footfall:
			sound.footstep(room, nav.depth())
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
			var line := Opening.subtitle_at(_intro_clock)
			if _hint.text != line: _hint.text = line
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
		station.finish_intro()
		sound.stop_opening()
		art.opening = false
	mode = "room"
	art.shot = -1
	if previous == "chapter":
		sound.room(room,station.data.signal)
		if _chapter_cut == 0: sound.say("ravine")
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
	sound.say(["threshold","storm","answer","epilogue"][index])
	refresh()

func _enter(target: int) -> void:
	if target < 0 or target >= ROOMS.size() or not foreground: return
	if not world.locked(target).is_empty():
		show_room(world.locked(target))
		return
	_arrival = Callable()
	_map.hide()
	var direction := signi(target - room)
	room = target
	art.room = room
	_shift_time = 0
	_struck = false
	art.strike_strength = 0
	nav.enter(room,direction)
	art.age = 0.0
	_transition = 0.28
	_bag_open = false
	_story = ""
	_toast.hide()
	var first := world.discover(room)
	sound.room(room,station.data.signal)
	sound.fx("hatch")
	if first and room == 7:
		chapter_scene(0)
	elif first and room == 9:
		chapter_scene(1)
	elif first and room == 8:
		sound.say("cave")
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

func refresh() -> void:
	if station == null: return
	_supplies.visible = mode in ["room", "repair"]
	_bag_panel.visible = _bag_open and mode == "room"
	_refresh_refill_buttons()
	_map_button.visible = mode == "room"
	_mute.visible = _bag_open and mode == "room"
	_replay.visible = _mute.visible
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
		_stock.hide()
		_hand.hide()
		_toast.hide()
		_exit.show()
		_layout()
		return
	_left.hide()
	_right.hide()
	_action.hide()
	_bag.hide()
	_stock.hide()
	_hand.hide()
	_toast.hide()
	_exit.visible = mode == "repair"
	_resume.hide()
	if mode in ["intro","takeoff","chapter"]:
		_title.text = "" if mode == "intro" and art.shot != 0 else "МАЯК  /  ПОСЛЕДНИЙ СВЕТ"
		_hint.text = Opening.subtitle_at(_intro_clock) if mode == "intro" else (CHAPTER_LINES[_chapter_cut] if mode == "chapter" else "Маяк: тяга стабильна. Теперь — домой.")
		_action.text = "Пропустить"
		_verb = "skip"
		_action.disabled = false
		_action.show()
		_layout()
		return
	_title.text = "%02d   %s" % [room+1, ROOMS[room]]
	_bag.show()
	_hand.visible = _bag_open
	_stock.visible = _bag_open
	_stock.text = "Детали %d · Вода %d · Заряд %d · Еда %d · Предохр. %d · Катушки %d" % [
		station.data.parts, station.data.water, station.data.energy, station.data.food, station.data.fuses, station.data.coils]
	_stock.text += "\nРуда %d · Кристаллы %d · Сплав %d" % [world.data.ore,world.data.silica,world.data.alloy]
	_stock.text += "\nПри ≤25% биосад растёт медленнее"
	if room < 6: _stock.text += "\nПополнение системы · 1 ед. со склада"
	if not world.data.last.is_empty():
		_stock.text += "\nПоследний ремонт: %.1f с · отпусканий %d · промахов %d" % [
			float(world.data.last.get("seconds",0)),int(world.data.last.get("releases",0)),int(world.data.last.get("mistakes",0))]
		_stock.text += "\nДва канала вместе: %.2f с" % (float(world.data.last.get("both_ms",0))/1000)
		if world.data.best_relay >= 0:
			_stock.text += " · Рекорд ретранслятора: %d" % world.data.best_relay
	_refresh_deposits()
	if _map.visible: _map.update_map(world,room)
	_left.visible = room > 0
	_right.visible = room < ROOMS.size() - 1 and world.locked(room + 1).is_empty()
	var target: int = world.next_objective()[0]
	if _left.visible: _left.text = ("◆  " if target >= 0 and target < room else "‹  ") + ROOMS[room-1]
	if _right.visible: _right.text = ROOMS[room+1] + ("  ◆" if target > room else "  ›")
	_toast.text = _story if station.save_ok else "Не удалось записать сохранение"
	_toast.visible = _toast_left > 0 or not station.save_ok
	_room_action()
	_scrap.visible = room == 2 and _verb != "job" and not _bag_open and not _map.visible
	if _bag_open:
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
				_offer_job("Закрыть заслонку", "Маяк: корпус пробит. Сначала перекрой воздуховод.", "tutorial")
			elif d.launched:
				_offer("", "Полёт домой. Отсеки доступны в свободном режиме.", "")
			elif d.signal and world.data.relay:
				_offer_cost("Взлететь", State.LAUNCH_COST, "launch")
			elif d.signal:
				_offer("", "Нужен маршрут через грозу. Почини ретранслятор на хребте.", "")
			else:
				_offer("", "Маяк: связь молчит. Иди в гидроузел.", "")
		1:
			art.restored = d.pump
			_offer_job("Наполнить бак" if d.pump else "Открыть клапан", "Каждый прогон: до +24 п. п. воды и 3 канистры." if d.pump else "Жара растёт. Верни воду в контур.", "repair-1")
		2:
			art.restored = d.fuses > 0 or d.coils > 0
			if not world.data.shield and world.can_craft("shield"):
				_world_recipe("Экран для антенны","shield")
			elif world.data.alloy == 0 and not world.data.stabilizer and world.can_craft("alloy"):
				_world_recipe("Выплавить сплав","alloy")
			elif not d.beacon and d.fuses == 0 and d.coils == 0 and station.can_pay({"parts": 2, "energy": 1}):
				_offer_cost("Собрать предохранитель", {"parts": 2, "energy": 1}, "fuses")
			elif d.generator and not d.beacon and d.fuses > 0 and d.coils == 0 and station.can_pay({"parts": 3}):
				_offer_cost("Намотать катушку", {"parts": 3, "fuses": 1}, "coils")
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
			elif not d.signal:
				if world.data.relay:
					_offer_job("Настроить частоту", "Поймай сигнал с хребта.", "repair-3")
				else:
					_offer("", "Антенна готова. Нужен ретранслятор на хребте.", "")
			else:
				_offer_job("Проверить частоту", "Маяк: сигнал принят. В рубке можно готовить взлёт.", "repair-3")

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
	if not foreground: return
	if mode == "room":
		var intended := _verb
		var target := Vector2(193,194)
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
				sound.fx("craft")
				var note: String = {"garden": "Биосад работает",
					"generator": "Маяк: реактор собран. Осталось синхронизировать его.",
					"beacon": "Маяк: катушка на месте. Попробуем докричаться до орбиты."}[module]
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
				sound.say("home")
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
	if mode != "room" or not foreground or _map.visible or _bag_open: return
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
				sound.say("wreck" if flag == 4 else "seam")
				reward += " · " + ("Рейнджер: здесь уже падал корабль." if flag == 4 else
					"Рейнджер: кто-то прятал оборудование от грозы.")
			show_room(reward)
		else:
			show_room("Залежь пустая. Осталось %d с." % ceili(world.remaining(room,index)))
	if not nav.walk_to(nodes[index][0]): _arrival = Callable()

func _toggle_map() -> void:
	if mode != "room": return
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
			if station.data.harvests == 1: show_room("Улучшение биосада в «Запасах»")

func _refresh_refill_buttons() -> void:
	for key in _refill_buttons:
		var button: Button = _refill_buttons[key]
		button.visible = _bag_panel.visible and room < 6
		button.disabled = not station.can_refill_from_stock(key)

func _layout() -> void:
	if _hint == null: return
	var f := art.frame_rect()
	var x := f.position.x + 12
	var top := f.position.y + 8
	var w := f.size.x - 24
	var bottom := f.end.y - 10
	if mode == "room":
		place(_title, Vector2(x + 96, top), Vector2(w - 192, 31))
	else:
		place(_title, Vector2(x, top), Vector2(w - 95, 31))
	place(_bag, Vector2(x+w-96, top), Vector2(96, 47))
	place(_map_button, Vector2(x,top),Vector2(86,47))
	var supply_w := minf(w, 444.0)
	place(_supplies, Vector2(roundf(x+(w-supply_w)*0.5), top+43), Vector2(supply_w, 35))
	place(_seed_picker, Vector2(x+w-145,top+84),Vector2(145,43))
	place(_equipment, Vector2(x+w-162,top+84),Vector2(162,43))
	place(_scrap, Vector2(x+w-196,top+84),Vector2(196,43))
	place(_purge, Vector2(x,top+84),Vector2(144,43))
	var bag_width := minf(w, 646.0)
	var bag_x := roundf(x + (w - bag_width) * 0.5)
	var columns := 3 if bag_width >= 480 else 2
	var slot := floorf((bag_width - 28.0 - (columns - 1) * 6.0) / columns)
	var stock_height := 140.0 if world != null and not world.data.last.is_empty() else 98.0
	if room < 6: stock_height += 21.0
	var toast_top := top + 90.0 + stock_height
	var item_top := toast_top + 34.0
	var visible_items := 0
	var bag_items := _refill_buttons.values() + [_hand, _mute, _replay, _liner, _cell, _stabilizer, _greenhouse_upgrade]
	for item in bag_items:
		if not item.visible: continue
		var column := visible_items % columns
		var row := floori(float(visible_items) / columns)
		place(item, Vector2(bag_x + 14 + column * (slot + 6), item_top + row * 48), Vector2(slot,44))
		visible_items += 1
	var rows := ceili(float(visible_items) / columns)
	place(_bag_panel, Vector2(bag_x, top+81), Vector2(bag_width, item_top + rows * 48 + 8 - (top+81)))
	_liner.tooltip_text = world.price("liner") if world != null else ""
	var map_w := minf(w,870.0)
	place(_map,Vector2(x+(w-map_w)*0.5,top+82),Vector2(map_w,260))
	place(_exit, Vector2(x+w-90, top), Vector2(90, 36))
	place(_stock, Vector2(bag_x+14, top+88), Vector2(bag_width-28, stock_height))
	place(_toast, Vector2(x if not _bag_open else bag_x+14, top+79 if not _bag_open else toast_top),
		Vector2(w if not _bag_open else bag_width-28, 34))
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
		place(_hint, Vector2(x, bottom-37), Vector2(w, 39))
		place(_resume, Vector2(x+(w-action_width)*0.5,bottom-84),Vector2(action_width,42))
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
