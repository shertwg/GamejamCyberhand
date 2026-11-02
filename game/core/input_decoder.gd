class_name InputDecoder
extends RefCounted

const Frame = preload("res://game/core/input_frame.gd")
const Command = preload("res://game/core/control_command.gd")
const Config = preload("res://game/core/input_config.gd")

var _config: Config
var _active_a: bool = false
var _active_b: bool = false


func _init(config: Config) -> void:
	_config = config


## Clear hysteresis memory on every fault and new stream.
func reset() -> void:
	_active_a = false
	_active_b = false


## Only the pipeline supplies validated, connected frames here.
func decode(frame: Frame) -> Command:
	_active_a = _next_active(_active_a, frame.channel_a, _config.on_a, _config.off_a)
	_active_b = _next_active(_active_b, frame.channel_b, _config.on_b, _config.off_b)
	if _active_a and _active_b:
		return Command.new(Command.BOTH, 0.0, &"BOTH", &"opposing_channels", true)
	if _active_a:
		return Command.new(Command.OPEN, _intensity(frame.channel_a, _config.on_a), &"ACTIVE", &"channel_a", false)
	if _active_b:
		return Command.new(Command.CLOSE, _intensity(frame.channel_b, _config.on_b), &"ACTIVE", &"channel_b", false)
	return Command.new(Command.REST, 0.0, &"REST", &"neutral", _config.rest_pauses)


func _next_active(active: bool, value: float, on: float, off: float) -> bool:
	if active:
		return value > off
	return value >= on


func _intensity(value: float, on: float) -> float:
	# Approved formula: linear above ON; retained direction in the band has zero speed.
	return clampf((value - on) / (1.0 - on), 0.0, 1.0)
