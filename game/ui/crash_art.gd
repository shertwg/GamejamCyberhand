extends Control
## Texture staging for the campaign. Atmosphere is composited above the room
## plates and never touches the scene's gameplay or input coordinates.
const Art = preload("res://game/ui/visual_assets.gd")
const Navigation = preload("res://game/gameplay/deck_navigation.gd")
const Station = preload("res://game/station/station_state.gd")
const GardenPlots = preload("res://game/ui/garden_plots.gd")
const FRAME := Vector2(384, 216)
const RANGER_SCALE := 2.0
const CUTS := [Rect2(2,2,832,466), Rect2(838,2,831,466),
	Rect2(2,473,832,465), Rect2(), Rect2(838,473,831,465)]
const ROOM_CROPS := [83.0, 97.0, 92.0, 101.0, 107.0, 97.0]
const HERO_FEET := [Vector2(122,187), Vector2(126,182), Vector2(120,185),
	Vector2(145,181), Vector2(140,183), Vector2(121,183)]
const LAMPS := [Vector2(48,41), Vector2(104,81), Vector2(184,38),
	Vector2(98,54), Vector2(192,81), Vector2(82,55)]
const LIGHT_COLORS := [Color("ffab63"), Color("65e3df"), Color("f4b56a"),
	Color("c978fa"), Color("ffbb50"), Color("f387cc")]

var room := 0
var shot := -1
var age := 0.0
var opening := false
var restored := false
var station: Station
var garden := GardenPlots.new()
var selected_crop := "greens"
var repairing := false
var foreground := true
var reduce_motion := false
var navigator: Navigation
var resource_points: Array = []
var material_preview := ""
var storm_pressure := 0.0
var strike_point := Vector2.ZERO
var strike_strength := 0.0
var _frame_time := 0.0
var _light: GradientTexture2D

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_NEAREST
	clip_contents = true
	resized.connect(queue_redraw)
	var falloff := Gradient.new()
	falloff.colors = PackedColorArray([Color.WHITE, Color(1,1,1,0.30), Color(1,1,1,0)])
	falloff.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	_light = GradientTexture2D.new()
	_light.width = 96
	_light.height = 96
	_light.gradient = falloff
	_light.fill = GradientTexture2D.FILL_RADIAL
	_light.fill_from = Vector2(0.5, 0.5)
	_light.fill_to = Vector2(1.0, 0.5)

func frame_rect() -> Rect2:
	var dimensions := FRAME * minf(size.x / FRAME.x, size.y / FRAME.y)
	if size.y > size.x and shot < 0:
		dimensions.y = minf(size.y, dimensions.y * 1.33)
	return Rect2((size - dimensions) * 0.5, dimensions)

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not foreground:
		return
	if not opening: age += delta
	_frame_time += delta
	if _frame_time >= 1.0 / 30.0:
		_frame_time = fmod(_frame_time, 1.0 / 30.0)
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b1020"))
	var frame := frame_rect()
	if frame.size.x <= 0:
		return
	if frame.position.y > 24.0 and size.y > size.x:
		_draw_portrait_backdrop()
	draw_set_transform(frame.position, 0, frame.size / FRAME)
	if shot in [0, 1, 2, 4] or shot >= 5:
		_draw_cut()
	else:
		_draw_interior()

func _draw_portrait_backdrop() -> void:
	var external := shot in [0, 1, 2, 4] or shot >= 5
	var texture: Texture2D = _cut_texture() if external else _room_texture()
	var source: Rect2 = _cut_region() if external else _room_region()
	var width := source.size.y * size.x / size.y
	source.position.x += (source.size.x - width) * 0.5
	source.size.x = width
	draw_texture_rect_region(texture, Rect2(Vector2.ZERO, size), source, Color("34364f"))

func _draw_cut() -> void:
	var source := _cut_region()
	var zoom := 0.97 - minf(age / 5.0, 1.0) * 0.10
	if shot in [9, 12]:
		zoom = 0.99 - minf(age / 6.8, 1.0) * 0.058
	var crop := source.size * zoom
	var center := source.get_center()
	var drift := sin(age * 23.0) * (7.0 if shot == 11 else 4.0) if shot in [1, 11] and not reduce_motion else 0.0
	center += Vector2(drift + (1.0 - zoom) * 90.0, drift * 0.4)
	draw_texture_rect_region(_cut_texture(), Rect2(Vector2.ZERO, FRAME),
		Rect2(center - crop * 0.5, crop))
	match shot:
		0, 4:
			_particles(Vector2(48, 134) if shot == 0 else Vector2(270, 60), Color("8ef8ff"), 15, 0.75)
		1:
			_particles(Vector2(212, 134), Color("ff9960"), 34, 1.8)
			var flash := pow(maxf(0.0, sin(age * 3.7)), 14.0) * 0.10
			draw_rect(Rect2(Vector2.ZERO, FRAME), Color(0.85, 0.58, 1.0, flash))
		2:
			_steam(Vector2(102, 187), Color("d3b0aa"), 1.5, 0.29)
			_steam(Vector2(258, 190), Color("d3b0aa"), 1.2, 0.26)
		5, 6:
			_weather(0.65)
		9:
			_cut_glow(Vector2(30,30),Color("ffc58c"),0.12 + 0.025*sin(age*2.1))
		10:
			_cut_glow(Vector2(260,64),Color("ef534f"),0.19 + 0.08*sin(age*4.2))
			_particles(Vector2(314,112),Color("bcaaff"),12,0.44)
		11:
			_cut_glow(Vector2(41,40),Color("fa7456"),0.22 + 0.06*sin(age*5.6))
			_particles(Vector2(264,114),Color("fca07f"),26,1.15)
		12:
			_steam(Vector2(250,168),Color("bda8c9"),0.70,0.16)
	if opening:
		_opening_fade()
	_frame_edges()

func _cut_texture() -> Texture2D:
	if shot >= 9: return Art.OPENING
	return Art.CHAPTERS if shot >= 5 else Art.CUTS

func _cut_region() -> Rect2:
	if shot >= 9: return Art.QUADRANTS[shot-9]
	return Art.QUADRANTS[shot-5] if shot >= 5 else CUTS[shot]

func _cut_glow(point: Vector2, tint: Color, opacity: float) -> void:
	draw_texture_rect(_light,Rect2(point-Vector2(50,50),Vector2(100,100)),false,Color(tint,opacity))

func _opening_fade() -> void:
	var darkness := 0.0
	match shot:
		0: darkness = 1.0 - smoothstep(0.0, 0.65, age)
		2:
			# Cut to darkness after ground contact, then show the ranger.
			darkness = smoothstep(0.16,0.46,age) * (1.0-smoothstep(1.15,2.15,age))
		12: darkness = 0.64 * (1.0 - smoothstep(0.0,0.62,age))
	if darkness > 0:
		draw_rect(Rect2(Vector2.ZERO,FRAME),Color(0.018,0.024,0.05,darkness))

func _room_texture() -> Texture2D:
	return Art.INTERIORS if room < 6 else Art.EXPEDITION

func _room_region() -> Rect2:
	return Art.ROOMS[room] if room < 6 else Art.QUADRANTS[room-6]

func _draw_interior() -> void:
	var source := _room_region()
	if room < 6 and size.x >= size.y:
		source.position.y += ROOM_CROPS[room]
		source.size.y = source.size.x * FRAME.y / FRAME.x
	elif room < 6:
		# Show more of the painted wall and floor when the available frame is tall.
		source.position.y += 40.0
		source.size.y -= 65.0
	var tint := Color.WHITE if restored or room in [2, 3] else Color(0.86, 0.89, 0.96)
	draw_texture_rect_region(_room_texture(), Rect2(Vector2.ZERO, FRAME), source, tint)
	var lamp: Vector2 = LAMPS[room % 6] if room < 6 else Vector2(215,91)
	var glow := 0.11 + 0.04 * sin(age * (2.6 if restored else 5.0))
	draw_texture_rect(_light, Rect2(lamp - Vector2(52, 52), Vector2(104, 104)),
		false, Color(LIGHT_COLORS[room % 6], glow))
	match room:
		0:
			_particles(Vector2(308, 84), Color("ffc382"), 10 if not restored else 4, 0.42)
			if not restored:
				_steam(Vector2(79, 160), Color("c5adcc"), 0.55, 0.14)
		1:
			_steam(Vector2(314, 138), Color("a4e4ee"), 0.82, 0.36 if restored else 0.54)
			_steam(Vector2(49, 163), Color("90d0db"), 0.6, 0.22)
			for i in range(16):
				var climb := fposmod(age*(16.0+i%5*3)+i*31,71)
				var bubble := Vector2(90+i%3*42+sin(climb*0.20+i)*5,106-climb)
				draw_circle(bubble,0.8+i%3*0.25,Color(0.71,1.0,0.98,0.12+climb/260))
			if station != null and station.data.expedition.get("condenser", false):
				_draw_installation(Vector2(271, 104), Color("74dcfa"), "condenser")
		2:
			_clock(Vector2(53, 49))
			_particles(Vector2(255, 114), Color("ffd4a0"), 7, 0.40)
		3:
			_particles(Vector2(211, 132), Color("e4f8a3"), 14 if restored else 5, 0.42)
			if restored:
				draw_texture_rect(_light, Rect2(127, 55, 131, 101), false, Color(0.63, 0.88, 0.68, 0.14 + 0.03 * sin(age * 1.7)))
		4:
			_spin("gear", Vector2(93, 96), Vector2(38, 38), age * (0.36 if restored else 0.16), Color("c7a2a1"))
			_particles(Vector2(193, 118), Color("ffd384"), 25 if restored else 12, 0.74)
			_steam(Vector2(282, 164), Color("c7a6ba"), 0.65, 0.22)
			if station != null and station.data.expedition.get("capacitor", false):
				_draw_installation(Vector2(275, 113), Color("ffd47a"), "capacitor")
		5:
			_particles(Vector2(93, 77), Color("ff9edf"), 10, 0.37)
			_spin("gear",Vector2(348,103),Vector2(13,13),age*0.95,Color("a1a3b3"))
			_spin("gear",Vector2(365,103),Vector2(12,12),-age*1.12,Color("9798ae"))
			if restored:
				var pulse := 0.30 + 0.18 * sin(age * 3.4)
				Art.prop(self, "spark", Rect2(242, 88, 21, 17), Color(0.55, 1.0, 0.76, pulse))
		6:
			_steam(Vector2(33,164),Color("ead4b0"),0.8,0.40)
			_particles(Vector2(230,85),Color("ffb270"),16,0.62)
		7:
			_weather(0.90 + storm_pressure)
			_steam(Vector2(96,148),Color("d293a4"),1.5,0.27)
			_draw_strike()
		8:
			_steam(Vector2(227,167),Color("90cde2"),1.35,0.35)
			_particles(Vector2(215,130),Color("8affef"),30,0.88)
		9:
			_weather(0.60 + storm_pressure)
			_particles(Vector2(81,90),Color("f4a1ff"),22,0.80)
	if shot == -1:
		_draw_deposits()
		if room == 3 and restored and station != null:
			garden.draw(self, station, age)
		_draw_crew()
		if room == 3 and restored and station != null:
			garden.draw_feedback(self, station, age, selected_crop)
		if not material_preview.is_empty() and not repairing:
			var point := Vector2(192,132)
			draw_texture_rect(_light,Rect2(point-Vector2(23,23),Vector2(46,46)),false,Color(0.75,0.46,0.25,0.28))
			draw_texture_rect_region(Art.LOOT,Rect2(point-Vector2(13,15),Vector2(26,26)),Art.MATERIALS[material_preview])
	_frame_edges()

func _draw_installation(point: Vector2, accent: Color, id: String) -> void:
	draw_texture_rect(_light, Rect2(point - Vector2(34, 34), Vector2(68, 68)), false, Color(accent, 0.26))
	Art.prop(self, "plate", Rect2(point - Vector2(18, 15), Vector2(36, 30)), Color("d5bfae"))
	if id == "condenser":
		_spin("gear", point, Vector2(19, 19), age * 0.7, accent)
	else:
		draw_texture_rect_region(Art.LOOT, Rect2(point - Vector2(11, 11), Vector2(22, 22)), Art.MATERIALS.energy)
	var step := floori(age * 5.0) % 4
	for i in range(4):
		draw_rect(Rect2(point + Vector2(-8 + i * 4, 10), Vector2(2, 2)), accent if i == step else accent.darkened(0.62))

func _draw_crew() -> void:
	var feet: Vector2 = navigator.feet if navigator != null else HERO_FEET[room % 6]
	var pose := "kneel" if repairing else "idle"
	var depth := navigator.depth() if navigator != null else 0.5
	var height := lerpf(38,66,depth) * RANGER_SCALE
	var texture: Texture2D = Art.OBJECTS
	var region: Rect2 = Art.PROPS[pose]
	var mirror := false
	if repairing:
		feet.x = 48.0
		height *= 0.77
	elif navigator != null and navigator.moving:
		var frame_index := floori(navigator.gait / (Navigation.STEP_LENGTH * 0.5)) % 4
		if absf(navigator.heading.y) > absf(navigator.heading.x) * 1.06:
			texture = Art.WALK if navigator.heading.y > 0 else Art.WALK_BACK
			region = Art.WALK_FRONT[frame_index] if navigator.heading.y > 0 else Art.WALK_AWAY[frame_index]
		else:
			texture = Art.WALK
			region = Art.WALK_SIDE[frame_index]
			mirror = navigator.facing < 0
		height += float(frame_index % 2)
	elif navigator != null:
		mirror = navigator.facing < 0
	var frame_scale := frame_rect().size / FRAME
	var width := height * region.size.x / region.size.y * frame_scale.y / frame_scale.x
	var shadow := Vector2(lerpf(35,56,depth),lerpf(9,14,depth))
	draw_texture_rect(_light,Rect2(feet-shadow*0.5,shadow),false,Color(0.01,0.013,0.025,0.72))
	if mirror:
		var frame := frame_rect()
		var scale_factor := frame.size / FRAME
		draw_set_transform(frame.position + feet * scale_factor, 0, Vector2(-scale_factor.x, scale_factor.y))
		draw_texture_rect_region(texture,Rect2(-width * 0.5, -height, width, height),region)
		draw_set_transform(frame.position, 0, scale_factor)
	else:
		draw_texture_rect_region(texture,Rect2(feet.x - width * 0.5, feet.y - height, width, height),region)
	if not repairing:
		var hover := sin(age * 3.6) * 4.0
		var drone := Vector2(clampf(feet.x-width*0.5-24,8,354),maxf(20,feet.y-height*0.81+hover))
		Art.prop(self, "drone", Rect2(drone,Vector2(22,21)))

func _draw_deposits() -> void:
	for item in resource_points:
		var pos: Vector2 = item[0]
		var lit: bool = item[1]
		var hue: Color = item[2]
		var material: Rect2 = Art.MATERIALS[item[3]]
		draw_texture_rect(_light,Rect2(pos-Vector2(11,12),Vector2(22,18)),false,Color(hue,0.42 if lit else 0.12))
		draw_texture_rect_region(Art.LOOT,Rect2(pos-Vector2(15,21),Vector2(30,22)),material,
			Color.WHITE if lit else Color(0.44,0.45,0.53,0.64))
		var pulse := 1.0 + sin(age*3.6+pos.x)*0.09
		Art.prop(self,"spark",Rect2(pos-Vector2(5,24),Vector2(10,10)*pulse),Color(hue,0.88 if lit else 0.0))

func _weather(strength: float) -> void:
	var flash := 0.0 if reduce_motion else pow(maxf(0,sin(age*1.37+1.8)),24.0)*0.13*strength
	draw_rect(Rect2(Vector2.ZERO,FRAME),Color(0.59,0.42,0.81,flash))
	for i in range(46):
		var x := fposmod(i*93.0+age*(49+i%8*10),395)
		var y := fposmod(i*37.0+age*(20+i%6*9),218)
		draw_line(Vector2(x,y),Vector2(x-5-i%8,y-2),Color(0.80,0.66,0.87,0.09+strength*0.08),1)

func _draw_strike() -> void:
	if strike_strength <= 0: return
	var frame := frame_rect()
	var scale_factor := frame.size / FRAME
	draw_set_transform(frame.position + strike_point*scale_factor,0,scale_factor*Vector2(1,0.38))
	var color := Color("ffc293") if strike_strength < 1 else Color("f0c7ff")
	draw_arc(Vector2.ZERO,31,0,TAU,40,Color(color,0.64),2)
	draw_arc(Vector2.ZERO,31*strike_strength,0,TAU,40,Color(color,0.50),2)
	draw_set_transform(frame.position,0,scale_factor)
	if strike_strength >= 1:
		var bolt := PackedVector2Array()
		for i in range(9):
			bolt.append(strike_point - Vector2(sin(i*4.7)*9,i*24))
		draw_polyline(bolt,Color(0.61,0.32,1.0,0.65),5)
		draw_polyline(bolt,Color("f9d8ff"),1.5)

func _clock(center: Vector2) -> void:
	Art.prop(self, "dial", Rect2(center - Vector2(16, 16), Vector2(32, 32)), Color("bcacb6"))
	_spin("needle", center, Vector2(4, 15), age * 0.14, Color("e3b39d"), Vector2(0.5, 0.79))

func _spin(id: String, center: Vector2, dimensions: Vector2, angle: float, tint: Color, pivot := Vector2(0.5,0.5)) -> void:
	var frame := frame_rect()
	var scale_factor := frame.size / FRAME
	draw_set_transform(frame.position + center * scale_factor, angle, scale_factor)
	Art.prop(self, id, Rect2(-dimensions * pivot, dimensions), tint)
	draw_set_transform(frame.position, 0, scale_factor)

func _steam(origin: Vector2, tint: Color, strength: float, opacity: float) -> void:
	for index in range(4):
		var phase := fposmod(age * 0.55 + index * 0.25, 1.0)
		var width := (15.0 + phase * 37.0) * strength
		var offset := Vector2(phase * 22.0 + sin(phase * 5.0 + index) * 7.0, -phase * 61.0) * strength
		var alpha := sin(phase * PI) * opacity
		Art.prop(self, "steam", Rect2(origin + offset - Vector2(width * 0.5, width * 0.75), Vector2.ONE * width),
			Color(tint, alpha))

func _particles(origin: Vector2, tint: Color, count: int, intensity: float) -> void:
	for index in range(count):
		var phase := fposmod(age * (0.25 + (index % 6) * 0.04) + index * 0.618, 1.0)
		var drift := Vector2(sin(float(index) * 2.399) * 74.0, -35.0 - (index % 9) * 8.0) * phase * intensity
		var width := 4.0 + (index % 3) * 2.0
		Art.prop(self, "spark", Rect2((origin + drift).round(), Vector2.ONE * width), Color(tint, (1.0 - phase) * 0.70))

func _frame_edges() -> void:
	for i in range(9):
		var opacity := 0.09 - i * 0.009
		draw_rect(Rect2(0, i * 4, FRAME.x, 4), Color(0.025, 0.036, 0.08, opacity))
		draw_rect(Rect2(0, FRAME.y - (i + 1) * 4, FRAME.x, 4), Color(0.025, 0.036, 0.08, opacity * 1.7))
