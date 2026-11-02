extends Node2D

## Temporary composition root so the project opens and exports while UI/gameplay
## modules are being developed. Replace this placeholder after the first integration.

func _ready() -> void:
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(canvas)

	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	layout.position = Vector2(-360, -70)
	layout.custom_minimum_size = Vector2(720, 140)
	canvas.add_child(layout)

	var title := Label.new()
	title.text = "ОРБИТАЛЬНАЯ МАСТЕРСКАЯ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Последний свет · команда shertwg · каркас проекта"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(subtitle)
