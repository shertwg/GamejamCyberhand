extends Control
## Drawn into a 250x68 viewport; nearest-neighbor integer scaling only.
const IDS = ["tutorial", "repair-1", "repair-2", "repair-3"]
var completed: Array = []
var spark_phase := 0
var selected := "repair-1"

func _poly(points: Array, color: String) -> void:
	var packed := PackedVector2Array()
	for point in points: packed.append(Vector2(point[0], point[1]))
	draw_colored_polygon(packed, Color(color))

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(0.25, 0.25))
	# A hostile copper dusk, with a cold moon behind the mountain silhouette.
	for y in range(270):
		draw_line(Vector2(0,y), Vector2(1000,y), [Color("263547"), Color("343b4b"), Color("4b414b"), Color("63494c"), Color("805448")][mini(4, y / 54)])
	draw_circle(Vector2(840,65), 46, Color("caaa80"))
	draw_circle(Vector2(855,54), 40, Color("303d4b"))
	for i in range(35):
		var at := Vector2(fmod(i * 173.7,1000), fmod(i * 47.1,100))
		draw_rect(Rect2(at.snapped(Vector2(4,4)),Vector2(4,4)), Color("ddc4a4"))
	_poly([[0,160],[100,82],[170,142],[270,60],[360,158],[460,109],[540,161],[650,79],[735,140],[880,110],[1000,165],[1000,270],[0,270]],"453d43")
	_poly([[0,205],[120,150],[215,184],[350,145],[465,195],[650,156],[780,194],[920,143],[1000,185],[1000,270],[0,270]],"684b43")
	_poly([[0,238],[160,222],[330,240],[480,225],[660,243],[850,218],[1000,236],[1000,270],[0,270]],"302f36")
	# Landing struts and the damaged outer pressure hull.
	for x in [230,720]:
		draw_line(Vector2(x,210),Vector2(x-18,248),Color("152632"),12)
		draw_line(Vector2(x-42,249),Vector2(x+18,249),Color("93a4a4"),5)
	_poly([[60,185],[110,113],[165,99],[785,99],[895,130],[950,191],[916,218],[123,218]],"152632")
	_poly([[68,174],[123,112],[179,107],[785,107],[892,139],[930,180],[887,171],[785,124],[155,124],[112,183]],"8b9f9f")
	_poly([[120,218],[906,218],[885,229],[150,229]],"6b7e82")
	# Cockpit windows, engine nozzles, antenna and hull wear.
	_poly([[805,127],[867,142],[902,171],[810,159]],"39616b")
	draw_line(Vector2(818,131),Vector2(880,156),Color("8af0d4"),2)
	for y in [145,176]:
		draw_rect(Rect2(64,y,43,22),Color("14232c"))
		draw_rect(Rect2(64,y+4,12,14),Color("b86c4a"))
	draw_line(Vector2(720,108),Vector2(735,76),Color("9da8a1"),3)
	draw_arc(Vector2(737,74),14,0.2,2.8,20,Color("8af0d4") if "repair-3" in completed else Color("a37460"),3)
	for i in range(4):
		var x := 145.0 + i * 180
		var repaired: bool = IDS[i] in completed
		var accent := Color("8af0d4") if repaired else Color("df9675")
		var room := Rect2(x,127,170,83)
		draw_rect(room, Color("24454a") if repaired else Color("1c2e39"))
		draw_rect(room, accent if IDS[i] == selected else Color("50626a"), false, 2)
		draw_line(Vector2(x+10,132),Vector2(x+160,132), accent if repaired else Color("9d644e"),3)
		if repaired: draw_rect(Rect2(x+10,135,150,55),Color(0.5,0.9,0.7,0.07))
		# Each room has distinct machinery rather than an interchangeable icon.
		match i:
			0:
				draw_rect(Rect2(x+25,150,85,10),Color("7a8a89"))
				draw_line(Vector2(x+35,157),Vector2(x+35,173),Color("7a8a89"),3)
				draw_circle(Vector2(x+70,145),10,Color("8af0d4") if repaired else Color("e3b68b"))
				draw_rect(Rect2(x+65,142,10,3),Color("16313d"))
			1:
				for px in [40,78,116]:
					draw_rect(Rect2(x+px,142,22,26),Color("3d777b") if repaired else Color("67483d"))
					draw_line(Vector2(x+px+5,147),Vector2(x+px+5,163),accent,3)
				draw_line(Vector2(x+20,139),Vector2(x+150,139),Color("82a9aa"),3)
			2:
				draw_circle(Vector2(x+84,152),18,Color("406369"))
				draw_arc(Vector2(x+84,152),12,0,TAU,24,accent,3)
				for j in range(4):
					var a := j * PI / 2
					draw_line(Vector2(x+84,152),Vector2(x+84,152)+Vector2(cos(a),sin(a))*10,accent,2)
			3:
				draw_rect(Rect2(x+55,140,57,29),Color("355360"))
				for j in range(3): draw_line(Vector2(x+64,148+j*6),Vector2(x+100,148+j*6),accent,2)
		if not repaired and (spark_phase+i*3)%10 < 2:
			draw_line(Vector2(x+150,140),Vector2(x+145,151),Color("ffd166"),1)
	# Foreground mineral growths frame the shelter.
	for x in [25,45,955,977]:
		_poly([[x,258],[x-5,239],[x+3,225],[x+9,245]],"6b857c")
