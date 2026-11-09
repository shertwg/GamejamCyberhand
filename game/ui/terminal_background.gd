extends Control
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("08111d"))
	for y in range(0,int(size.y),64):
		draw_rect(Rect2(0,y,size.x,32),Color("0b1624"))
	for i in range(70):
		var p := Vector2(fmod(i * 179.0, maxf(size.x,1)), fmod(i * 97.0, maxf(size.y,1))).snapped(Vector2(4,4))
		draw_rect(Rect2(p,Vector2(4,4)),Color("224263"))
	for x in range(0,int(size.x),64):
		draw_rect(Rect2(x,0,1,size.y),Color("101d30"))
