extends Node
## All audio is local. Streams are loaded when their scene is selected.
const PATH := "res://assets/last_light/audio/"
const OPENING_MIX = preload("res://assets/last_light/audio/opening_mix.ogg")
const SCORE := ["01_orbit","02_fall","03_emergency","04_pressure","05_cold_water",
	"06_workbench","07_greenhouse","08_reactor","09_static","10_threshold",
	"11_ravine","12_crystal","13_relay","14_answer","15_home"]
const ROOM_TRACK := [3,4,5,6,7,8,9,10,11,12]
const SURFACES := ["metal","wet","metal","metal","metal","metal","metal","gravel","stone","metal"]
const EFFECT_LEVELS := {"click":-24.0,"servo":-21.0,"hatch":-17.0,"craft":-16.0,
	"pickup":-17.0,"success":-18.0,"warning":-15.0,"impact":-12.0}
var _music := AudioStreamPlayer.new()
var _atmos := AudioStreamPlayer.new()
var _effects := AudioStreamPlayer.new()
var _feet := AudioStreamPlayer.new()
var _opening := AudioStreamPlayer.new()
var _last_step := -1
var _last_variant := 0
var _track := -1
var _ambience := ""
var _fade: Tween
var muted := false
var _paused := false
var vibration_strength := 0.0
var _last_vibration := -1000
const CHANNELS := {"music":"KernaMusic", "effects":"KernaEffects"}

func _ready() -> void:
	for player in [_music,_atmos,_effects,_feet,_opening]:
		add_child(player)
	for bus in CHANNELS.values():
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	_music.bus = CHANNELS.music
	_atmos.bus = CHANNELS.effects
	_effects.bus = CHANNELS.effects
	_feet.bus = CHANNELS.effects
	_opening.bus = CHANNELS.effects
	_atmos.volume_db = -25
	_opening.volume_db = -2
	_opening.stream = OPENING_MIX
	var mixer := AudioStreamPolyphonic.new()
	mixer.polyphony = 6
	_effects.stream = mixer
	if DisplayServer.get_name() != "headless": _effects.play()
	_music.finished.connect(func():
		if not muted: _music.play()
	)

func room(index: int, resolved: bool) -> void:
	cue(13 if index == 0 and resolved else ROOM_TRACK[index])
	ambience("storm" if index in [7,9] else ("cave" if index == 8 else "air"))

func start_opening() -> void:
	if DisplayServer.get_name() == "headless": return
	if _fade != null: _fade.kill()
	_track = -1
	_ambience = ""
	for player in [_music, _atmos, _feet]:
		player.stop()
	_effects.stop()
	_opening.play()
	_opening.stream_paused = _paused or muted

func stop_opening() -> void:
	_opening.stop()
	if DisplayServer.get_name() != "headless" and not _effects.playing:
		_effects.play()

func cue(index: int) -> void:
	if _track == index or DisplayServer.get_name() == "headless": return
	_track = index
	if _fade != null: _fade.kill()
	_fade = create_tween()
	_fade.tween_property(_music,"volume_db",-48.0,0.25)
	_fade.tween_callback(func():
		_music.stream = load(PATH + SCORE[index] + ".ogg")
		if not muted:
			_music.play()
			_music.stream_paused = _paused
	)
	_fade.tween_property(_music,"volume_db",-15.0,0.7)

func ambience(id: String) -> void:
	if _ambience == id or DisplayServer.get_name() == "headless": return
	_ambience = id
	var stream := load(PATH+id+".wav") as AudioStreamWAV
	if stream == null: return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length()*stream.mix_rate)
	_atmos.stream = stream
	if not muted:
		_atmos.play()
		_atmos.stream_paused = _paused

func fx(id: String) -> void:
	if id in ["success", "warning", "craft", "pickup"]:
		vibrate(44 if id in ["success", "warning"] else 24)
	if muted or DisplayServer.get_name() == "headless": return
	var sample := load(PATH+id+".wav") as AudioStream
	var mixer := _effects.get_stream_playback() as AudioStreamPlaybackPolyphonic
	if sample != null and mixer != null:
		mixer.play_stream(sample, 0.0, EFFECT_LEVELS.get(id,-18.0))

func footstep(room_id: int, depth: float) -> void:
	if muted or DisplayServer.get_name() == "headless": return
	var now := Time.get_ticks_msec()
	if _last_step >= 0 and now - _last_step < 240: return
	_last_step = now
	var variant := (_last_variant + randi_range(0, 2)) % 4 + 1
	_last_variant = variant
	var asset := "%sfoot_%s_%d.wav" % [PATH, SURFACES[room_id], variant]
	_feet.stream = load(asset)
	if _feet.stream == null: return
	_feet.pitch_scale = randf_range(0.96, 1.04)
	_feet.volume_db = lerpf(-22.0, -15.0, depth)
	_feet.play()

func pause_audio(value: bool) -> void:
	_paused = value
	for player in [_music,_atmos,_effects,_feet,_opening]:
		player.stream_paused = value or muted

func apply_settings(values: Dictionary) -> void:
	vibration_strength = float(values.vibration)
	for channel in CHANNELS:
		var gain := float(values.master) * float(values.get(channel, 1.0))
		var bus := AudioServer.get_bus_index(CHANNELS[channel])
		AudioServer.set_bus_mute(bus, gain <= 0.0)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(gain, 0.001)))

func vibrate(duration: int) -> void:
	if vibration_strength <= 0.0 or not OS.has_feature("mobile"): return
	var now := Time.get_ticks_msec()
	if now - _last_vibration < 90: return
	_last_vibration = now
	Input.vibrate_handheld(duration, vibration_strength)
