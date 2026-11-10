extends Control

const DesignTheme = preload("res://game/ui/ui_theme.gd")

var value: float = 0.0
var threshold: float = 0.35

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(180, 20)
	queue_redraw()

func set_reading(next_value: float, next_threshold: float) -> void:
	value = clampf(next_value, 0.0, 1.0)
	threshold = clampf(next_threshold, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, DesignTheme.COLOR_NEUTRAL, true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * value, size.y)), DesignTheme.COLOR_CHART_BRAND, true)
	var tick_x := size.x * threshold
	draw_line(Vector2(tick_x, -2), Vector2(tick_x, size.y + 2), DesignTheme.COLOR_WARNING, 2.0, true)
