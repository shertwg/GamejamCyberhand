extends Node2D
## Composition root: the emulator reaches gameplay only through the pipeline.
const Session = preload("res://game/gameplay/prototype.gd")

func _ready() -> void:
	add_child(Session.new())
