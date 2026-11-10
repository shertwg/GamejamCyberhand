extends PanelContainer

signal room_chosen(room: int)
signal quiet_signal_requested
signal dismissed
const World = preload("res://game/gameplay/expedition.gd")
const Art = preload("res://game/ui/visual_assets.gd")
var _nodes: Array[Button] = []
var _chapter: Label
var _details: Label
var _graph: Control
var _quiet: Button

func _ready() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.046,0.065,0.11,0.97)
	panel.border_color = Color("9e8879")
	panel.set_border_width_all(2)
	panel.set_content_margin_all(15)
	add_theme_stylebox_override("panel",panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",8)
	add_child(stack)
	_chapter = Label.new()
	_chapter.add_theme_font_size_override("font_size",22)
	_chapter.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_chapter)
	_details = Label.new()
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_details)
	_graph = Control.new()
	_graph.custom_minimum_size.y = 112
	stack.add_child(_graph)
	_graph.resized.connect(_place_route)
	_graph.draw.connect(_draw_route)
	for id in range(World.ROOMS.size()):
		var node := Button.new()
		node.clip_text = true
		node.custom_minimum_size.y = 46
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		node.add_theme_stylebox_override("normal",Art.skin("button"))
		node.add_theme_stylebox_override("hover",Art.skin("button_hot"))
		node.add_theme_stylebox_override("pressed",Art.skin("button_hot"))
		node.pressed.connect(func(): room_chosen.emit(id))
		_nodes.append(node)
		node.add_theme_stylebox_override("disabled",Art.skin("button",true))
		node.add_theme_color_override("font_disabled_color",Color("9eafbe"))
		_graph.add_child(node)
	_quiet = Button.new()
	_quiet.text = "Тихий сигнал"
	_quiet.custom_minimum_size.y = 44
	_quiet.add_theme_stylebox_override("normal", Art.skin("button_hot"))
	_quiet.pressed.connect(func(): quiet_signal_requested.emit())
	stack.add_child(_quiet)
	var close := Button.new()
	close.text = "Закрыть карту"
	close.custom_minimum_size.y = 44
	close.add_theme_stylebox_override("normal",Art.skin("button"))
	close.pressed.connect(func(): dismissed.emit())
	stack.add_child(close)
	hide()

func _place_route() -> void:
	var columns := 3 if _graph.size.x < 580 else 5
	var rows := ceili(float(_nodes.size())/columns)
	_graph.custom_minimum_size.y = rows * 56.0
	var width := _graph.size.x / columns
	for i in range(_nodes.size()):
		var row := i / columns
		var slot := i % columns
		var column := slot if row % 2 == 0 else columns - 1 - slot
		_nodes[i].position = Vector2(column * width + 5,row * 56)
		_nodes[i].size = Vector2(width - 10,46)
	_graph.queue_redraw()

func _draw_route() -> void:
	for i in range(_nodes.size()-1):
		var first := _nodes[i].get_rect().get_center()
		var second := _nodes[i+1].get_rect().get_center()
		_graph.draw_line(first,second,Color("65566e") if _nodes[i+1].disabled else Color("ba9d70"),3)

func update_map(world: World, current: int) -> void:
	_quiet.visible = world.data.filter
	var chapter: Array = World.CHAPTERS[world.chapter()]
	var objective := world.next_objective()
	var target: int = objective[0]
	_chapter.text = chapter[0]
	_details.text = ("◆ %02d · " % (target + 1) if target >= 0 else "") + str(objective[1])
	if world.data.weather_event == "dust": _details.text += "\nБиосад · Нужна продувка"
	elif world.data.weather_event == "vent": _details.text += "\nПещера · Новые кристаллы"
	if world.chapter() in [2,3]:
		var materials := "Экран готов" if world.data.shield else "Экран · сплав %d/1 · кристаллы %d/2" % [
			mini(1,int(world.data.alloy)),mini(2,int(world.data.silica))]
		if not world.data.shield and world.data.alloy == 0:
			materials += "   |   Для сплава: руда %d/3" % mini(3,int(world.data.ore))
		_details.text += "\n" + materials
	for id in range(_nodes.size()):
		var node := _nodes[id]
		var known: bool = id in world.data.discovered
		var name: String = ("Пещера" if id == 8 else World.ROOMS[id]) if known or id <= 6 or id == target else "Закрыто"
		var marker := "◆ " if id == target else ("▸ " if id == current else "")
		node.text = "%s%02d · %s" % [marker, id+1, name]
		node.add_theme_color_override("font_color", Color("ffe2a1") if id == target else Color("f4ede8"))
		node.add_theme_color_override("font_disabled_color", Color("eac989") if id == target else Color("9eafbe"))
		node.disabled = not known or id == current or not world.locked(id).is_empty()
		node.tooltip_text = "Здесь" if id == current else world.locked(id)
	_place_route()
