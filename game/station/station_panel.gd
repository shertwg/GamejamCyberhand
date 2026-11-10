extends VBoxContainer
## The station map and journal are the entry point for all production and repairs.
signal job_requested(level_id: String)

const State = preload("res://game/station/station_state.gd")
const Map = preload("res://game/station/station_map.gd")
const Style = preload("res://game/ui/terminal_style.gd")
const MODULES := {
	"workshop": ["Мастерская", "ffac90"], "pump": ["Насос", "9ad9ff"],
	"garden": ["Теплица", "b9eb9d"], "generator": ["Генератор", "ffda8d"],
	"beacon": ["Корабль", "e4b7f7"]
}
const JOBS := {"workshop": "tutorial", "pump": "repair-1", "generator": "repair-2", "beacon": "repair-3"}
const RESOURCE_COLORS := ["ffc39e", "96dfff", "ffe393", "b9eb9d"]

var station: State
var unlocked: Array = []
var selected := "pump"
var _quest_step := -1
var _command := ""
var _resources: Dictionary
var _modules: Dictionary
var _map: Map
var _body: BoxContainer
var _tabs: GridContainer
var _journal: VBoxContainer
var _chapter: Label
var _objective: Label
var _story: Label
var _title: Label
var _detail: Label
var _notice: Label
var _action: Button
var _upgrade: Button

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var stock := HBoxContainer.new()
	stock.add_theme_constant_override("separation", 6)
	add_child(stock)
	var index := 0
	for key in State.NAMES:
		var tile := PanelContainer.new()
		var box := Style.box("252e46", RESOURCE_COLORS[index])
		for side in [SIDE_TOP, SIDE_BOTTOM, SIDE_LEFT, SIDE_RIGHT]:
			box.set_content_margin(side, 5)
		tile.add_theme_stylebox_override("panel", box)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stock.add_child(tile)
		var value := label(State.NAMES[key], 15, RESOURCE_COLORS[index])
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(value)
		_resources[key] = value
		index += 1

	_body = BoxContainer.new()
	_body.add_theme_constant_override("separation", 14)
	add_child(_body)
	var grounds := VBoxContainer.new()
	grounds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(grounds)
	_map = Map.new()
	grounds.add_child(_map)
	_map.module_selected.connect(select)
	_tabs = GridContainer.new()
	_tabs.columns = MODULES.size()
	_tabs.add_theme_constant_override("h_separation", 4)
	grounds.add_child(_tabs)
	for id in MODULES:
		var button := make_button(MODULES[id][0])
		button.toggle_mode = true
		button.add_theme_color_override("font_color", Color(MODULES[id][1]))
		button.pressed.connect(select.bind(id))
		_tabs.add_child(button)
		_modules[id] = button
	_notice = label("", 14, "f2d3ba")
	grounds.add_child(_notice)

	_journal = VBoxContainer.new()
	_journal.add_theme_constant_override("separation", 5)
	_body.add_child(_journal)
	_chapter = label("", 13, "ffcf93")
	_objective = label("", 22, "fff1d7")
	_story = label("", 15, "ddd9ea")
	_title = label("", 18, "b9eb9d")
	_detail = label("", 14, "ddd9ea")
	for child in [_chapter, _objective, _story, HSeparator.new(), _title, _detail]:
		_journal.add_child(child)
	_action = make_button("")
	Style.primary(_action)
	_action.pressed.connect(_activate)
	_journal.add_child(_action)
	_upgrade = make_button("Улучшить теплицу · 6 деталей, 2 еды")
	_upgrade.pressed.connect(func(): station.upgrade_garden())
	_journal.add_child(_upgrade)
	resized.connect(_fit)
	_fit()

func bind(model: State, available: Array) -> void:
	station = model
	unlocked = available
	station.changed.connect(refresh)
	refresh()

func set_unlocked(available: Array) -> void:
	unlocked = available
	refresh()

func select(id: String) -> void:
	if not MODULES.has(id): return
	selected = id
	refresh()

func refresh() -> void:
	if station == null: return
	var q := station.quest()
	if _quest_step != q.step:
		_quest_step = q.step
		selected = q.module
	for key in _resources:
		_resources[key].text = "%s  %d" % [State.NAMES[key], station.data[key]]
	for id in _modules:
		_modules[id].set_pressed_no_signal(id == selected)
	_map.show_station(station.data, selected)
	_chapter.text = q.chapter
	_objective.text = q.title
	_story.text = q.body
	_title.text = MODULES[selected][0]
	_title.add_theme_color_override("font_color", Color(MODULES[selected][1]))
	_notice.text = station.notice if station.save_ok else "Прогресс пока не удалось записать на диск."
	_upgrade.visible = selected == "garden" and station.data.garden and station.data.garden_level < 2
	_upgrade.disabled = not station.can_pay(State.UPGRADE_COST)
	_refresh_action()

func _refresh_action() -> void:
	var data := station.data
	match selected:
		"workshop":
			_offer_job("Разобрать обломки", "Короткий маршрут для дрона. Здесь всегда можно добыть детали и заряд.")
		"pump":
			_offer_job("Пополнить бак" if data.pump else "Починить насос", "Проведи дрон к клапану. Вода нужна для строительства и посева.")
		"generator":
			if data.generator:
				_offer_job("Зарядить батареи", "Обслуживание генератора пополняет энергию.")
			else:
				_offer_build(data.harvests > 0, "Сначала собери урожай в теплице.")
		"beacon":
			if data.launched:
				_offer("", "Курс проложен. Станция работает в свободном режиме.", "")
			elif data.signal:
				_offer_cost("Запустить корабль", State.LAUNCH_COST, "launch")
			elif data.beacon:
				_offer_job("Настроить антенну", "Связь с домом. Сначала заряди батареи в генераторе, чтобы открыть ремонт.")
			else:
				_offer_build(data.generator, "Сначала собери генератор.")
		"garden":
			if not data.garden:
				_offer_build(data.pump, "Сначала почини насос. Теплице нужна вода.")
				return
			var beds: PackedStringArray = []
			for elapsed in data.beds:
				if elapsed < 0: beds.append("пусто")
				elif elapsed >= station.grow_seconds(beds.size()): beds.append("созрела")
				else: beds.append("%d с" % ceili(station.grow_seconds(beds.size()) - elapsed))
			var status := "Грядки · " + " / ".join(beds)
			if station.ripe_bed() >= 0:
				_offer("Собрать урожай +%d" % station.crop_yield(station.ripe_bed()), status, "harvest")
			elif -1.0 in data.beds:
				if data.water == 0:
					status += "\nВоду можно набрать у насоса."
				if data.energy == 0:
					status += "\nЗаряд можно добыть в мастерской."
				_offer_cost("Посадить семена", State.PLANT_COST, "plant", status + "\n")
			else:
				_offer("Грядки растут", status, "")

func _offer_build(available: bool, prerequisite: String) -> void:
	var title: String = {"garden": "Построить теплицу", "generator": "Собрать генератор", "beacon": "Установить антенну"}[selected]
	_offer_cost(title, State.BUILD_COSTS[selected], "build", "" if available else prerequisite + "\n", available)

func _offer_cost(title: String, cost: Dictionary, command: String, prefix := "", available := true) -> void:
	var affordable := station.can_pay(cost)
	_offer(title, prefix + ("Стоимость · " if affordable else "Нужно · ") + State.cost_text(cost),
		command if available and affordable else "")

func _offer_job(title: String, description: String) -> void:
	var id: String = JOBS[selected]
	var available := id in unlocked
	var hint := ("\nНаграда · " + State.cost_text(State.REWARDS[id])) if available else "\nЗадание пока закрыто."
	_offer(title, description + hint, "job" if available else "")

func _offer(title: String, detail: String, command: String) -> void:
	_detail.text = detail
	_action.text = title
	_action.visible = not title.is_empty()
	_action.disabled = command.is_empty()
	_command = command

func _activate() -> void:
	match _command:
		"job": job_requested.emit(JOBS[selected])
		"build": station.build(selected)
		"plant": station.plant()
		"harvest": station.harvest()
		"launch": station.launch()

func _fit() -> void:
	var narrow := size.x < 805
	_body.vertical = narrow
	_tabs.columns = 3 if size.x < 420 else MODULES.size()
	_journal.custom_minimum_size.x = 0 if narrow else 290
	_journal.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_FILL

func label(value: String, font_size: int, color: String) -> Label:
	var node := Label.new()
	node.text = value
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", Color(color))
	return node

func make_button(value: String) -> Button:
	var node := Button.new()
	node.text = value
	node.clip_text = true
	node.custom_minimum_size.y = 44
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_font_size_override("font_size", 14)
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := Style.box("25304a", "e4b781" if style_name != "normal" else "635a7f")
		box.set_content_margin(SIDE_LEFT, 6)
		box.set_content_margin(SIDE_RIGHT, 6)
		node.add_theme_stylebox_override(style_name, box)
	Style.setup_button_juice(node, self)
	return node
