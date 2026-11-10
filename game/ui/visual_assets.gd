extends RefCounted
## Regions are measured from the source PNGs. Keep the original pixels and alpha.
const INTERIORS = preload("res://assets/last_light/interiors.png")
const OBJECTS = preload("res://assets/last_light/objects.png")
const CUTS = preload("res://assets/last_light/cinematics.png")
const EXPEDITION = preload("res://assets/last_light/expedition.png")
const CHAPTERS = preload("res://assets/last_light/chapters.png")
const OPENING = preload("res://assets/last_light/opening.png")
const WALK = preload("res://assets/last_light/ranger_walk.png")
const WALK_BACK = preload("res://assets/last_light/ranger_back.png")
const LOOT = preload("res://assets/last_light/loot.png")
const WALK_SIDE := [Rect2(96,22,282,407),Rect2(580,22,192,407),
	Rect2(975,22,290,407),Rect2(1465,22,194,407)]
const WALK_FRONT := [Rect2(131,467,195,398),Rect2(575,467,198,398),
	Rect2(1018,467,193,398),Rect2(1463,467,193,398)]
const WALK_AWAY := [Rect2(121,52,303,598),Rect2(667,52,299,598),
	Rect2(1207,52,299,598),Rect2(1753,52,303,598)]
const MATERIALS := {
	"ore":Rect2(46,74,337,298),"silica":Rect2(456,42,332,332),"alloy":Rect2(867,91,346,279),
	"parts":Rect2(33,464,356,311),"energy":Rect2(451,466,352,309),"scrap":Rect2(857,464,367,310),
	"filter":Rect2(44,866,338,325),"shield":Rect2(436,842,371,363),"liner":Rect2(861,853,359,338)
}
const QUADRANTS := [Rect2(2,2,832,466),Rect2(838,2,831,466),
	Rect2(2,473,832,465),Rect2(838,473,831,465)]
const ROOMS := [
	Rect2(2, 2, 554, 465), Rect2(560, 2, 552, 465), Rect2(1115, 2, 554, 465),
	Rect2(2, 474, 554, 464), Rect2(560, 474, 552, 464), Rect2(1115, 474, 554, 464)
]
const PROPS := {
	"idle": Rect2(76, 0, 162, 313),
	"walk_a": Rect2(369, 0, 209, 313),
	"walk_b": Rect2(668, 0, 228, 313),
	"kneel": Rect2(981, 66, 279, 248),
	"valve": Rect2(11, 331, 283, 291),
	"gear": Rect2(325, 332, 293, 294),
	"dial": Rect2(634, 320, 307, 304),
	"needle": Rect2(1052, 337, 111, 260),
	"button": Rect2(2, 698, 309, 160),
	"button_hot": Rect2(320, 698, 305, 160),
	"scope": Rect2(638, 625, 303, 305),
	"claw_head": Rect2(1035, 628, 144, 148),
	"claw_left": Rect2(968, 744, 137, 183),
	"claw_right": Rect2(1105, 744, 152, 183),
	"steam": Rect2(0, 932, 315, 312),
	"drone": Rect2(321, 938, 302, 288),
	"spark": Rect2(630, 974, 306, 271),
	"plate": Rect2(948, 970, 314, 231)
}
static var _skins: Dictionary = {}

static func prop(canvas: CanvasItem, id: String, destination: Rect2, tint := Color.WHITE) -> void:
	canvas.draw_texture_rect_region(OBJECTS, destination, PROPS[id], tint)

static func skin(id: String, compact := false) -> StyleBoxTexture:
	if not _skins.has(id):
		# Author at the atlas resolution, then pack the nine-slice at UI scale.
		var art := OBJECTS.get_image().get_region(Rect2i(PROPS[id]))
		art.resize(112, 56, Image.INTERPOLATE_LANCZOS)
		_skins[id] = ImageTexture.create_from_image(art)
	var style := StyleBoxTexture.new()
	style.texture = _skins[id]
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		var horizontal: bool = side in [SIDE_LEFT, SIDE_RIGHT]
		style.set_texture_margin(side, 18 if horizontal else 13)
		style.set_content_margin(side, (8 if compact else 12) if horizontal else 6)
	return style
