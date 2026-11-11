extends AcceptDialog

const LINES := {
	"air": "Маяк: Держит. Теперь вода, пока реактор не перегрелся.",
	"water": "Маяк: Вода пошла. Перед выходом собери фильтр.",
	"generator": "Маяк: Реактор собран. Осталось синхронизировать его.",
	"beacon": "Маяк: Катушка на месте. Попробуем докричаться до орбиты.",
	"threshold": "Маяк: Фильтр держит. Возьми руду в ущелье.",
	"ravine": "Маяк: Видишь блеск у обломков? Там руда.",
	"cave": "Маяк: Вот они. Из кристаллов соберём экран для антенны.",
	"storm": "Маяк: Буря на хребте. Три окна, по одному.",
	"relay": "Маяк: Ретранслятор ответил. Попробуй антенну на корабле.",
	"answer": "Орбита: Маяк, это орбита. Видим вас. Коридор открыт.",
	"home": "Маяк: Тяга держится. Мы оторвались.",
	"wreck": "Рейнджер: Смотри, старый бортовой номер. Мы здесь не первые.",
	"seam": "Рейнджер: Они прятали аппаратуру от грозы. Может, маяк ещё жив.",
	"epilogue": "Рейнджер: Я думал, мы здесь останемся. Веди домой, Маяк.",
	"dust": "Маяк: Пыль забила фильтр биосада.",
	"vent": "Маяк: Выброс обнажил кристаллы в пещере.",
	"tracks": "Маяк: У шлюза следы. У них больше ног, чем я рассчитывал.",
	"purge": "Маяк: Фильтр чист. Биосад снова дышит.",
}
const Art = preload("res://game/ui/visual_assets.gd")
const Opening = preload("res://game/ui/opening_timeline.gd")
var body: RichTextLabel

func _ready() -> void:
	title = "Керна / Бортжурнал"
	ok_button_text = "Закрыть"
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("141821")
	skin.border_color = Color("a07b54")
	skin.set_border_width_all(2)
	skin.shadow_color = Color("05070ccc")
	skin.shadow_size = 7
	var journal_theme := Theme.new()
	journal_theme.set_stylebox("panel", "AcceptDialog", skin)
	var frame := skin.duplicate() as StyleBoxFlat
	frame.expand_margin_top = 30.0
	journal_theme.set_stylebox("embedded_border", "Window", frame)
	journal_theme.set_stylebox("embedded_unfocused_border", "Window", frame)
	journal_theme.set_color("title_color", "Window", Color("efd2a2"))
	theme = journal_theme
	get_ok_button().add_theme_stylebox_override("normal", Art.skin("button", true))
	get_ok_button().add_theme_stylebox_override("hover", Art.skin("button_hot", true))
	get_ok_button().add_theme_stylebox_override("pressed", Art.skin("button_hot", true))
	get_ok_button().add_theme_stylebox_override("focus", Art.skin("button_hot", true))
	body = RichTextLabel.new()
	body.selection_enabled = true
	var padding := StyleBoxEmpty.new()
	padding.set_content_margin_all(14.0)
	body.add_theme_stylebox_override("normal", padding)
	body.scroll_active = true
	body.add_theme_font_size_override("normal_font_size", 17)
	body.add_theme_color_override("default_color", Color("eee1d5"))
	add_child(body)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 14
	body.offset_right = -14
	body.offset_top = 14
	body.offset_bottom = -56

static func line_for(id: String) -> String:
	if LINES.has(id): return LINES[id]
	for cue in Opening.DIALOGUE_CUES:
		if cue[2] == id: return cue[3]
	return ""

func show_entries(ids: Array, view_size: Vector2) -> void:
	var entries := PackedStringArray()
	for id in ids:
		var line := line_for(id)
		if not line.is_empty(): entries.append(line)
	body.text = "\n\n".join(entries) if not entries.is_empty() else "Записей пока нет."
	popup_centered(Vector2i(minf(view_size.x - 28, 680), minf(view_size.y - 56, 460)))
	body.scroll_to_line(0)
