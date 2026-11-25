extends Node

signal finished

const DEFAULT_FADE := 1.5
const PAUSE_FILTER_EFFECT := 0
const DUCK_EFFECT := 1
const DUCK_DB := -80.0
const BED_BUS := &"MusicBed"

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _fade_tween: Tween
var _music_bus := -1
var _was_paused := false
var _duck_tween: Tween
var _aside_tween: Tween
var _layer: AudioStreamPlayer
var _layer_tween: Tween
var _bed_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_bus = AudioServer.get_bus_index(&"Music")
	_make_bed_bus()
	
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = BED_BUS
		player.volume_linear = 0.0
		player.finished.connect(_on_player_finished.bind(player))
		add_child(player)
		_players.append(player)
	_layer = AudioStreamPlayer.new()
	_layer.bus = &"Music"
	_layer.volume_linear = 0.0
	add_child(_layer)
	_set_muffled(false)

func _process(_delta: float) -> void:
	var paused := get_tree().paused
	if paused != _was_paused:
		_was_paused = paused
		_set_muffled(paused)

func play(stream: AudioStream, fade_time: float = DEFAULT_FADE, from_position: float = 0.0) -> void:
	var current := _players[_active]
	if current.stream == stream and current.playing:
		return
	if _fade_tween:
		_fade_tween.kill()
	
	var next := _players[1 - _active]
	next.stop()
	next.stream = stream
	next.volume_linear = 0.0
	next.play(from_position)
	
	_fade_tween = create_tween().set_parallel()
	_fade_tween.tween_property(next, "volume_linear", 1.0, fade_time)
	_fade_tween.tween_property(current, "volume_linear", 0.0, fade_time)
	_fade_tween.chain().tween_callback(current.stop)
	_active = 1 - _active

func stop(fade_time: float = DEFAULT_FADE) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween().set_parallel()
	for player in _players:
		if player.playing:
			_fade_tween.tween_property(player, "volume_linear", 0.0, fade_time)
	_fade_tween.chain().tween_callback(_stop_players)

func _stop_players() -> void:
	for player in _players:
		player.stop()

func duck(on: bool, fade_time: float = 0.8, db: float = DUCK_DB) -> void:
	if _music_bus < 0 or AudioServer.get_bus_effect_count(_music_bus) <= DUCK_EFFECT:
		return
	var amplify := AudioServer.get_bus_effect(_music_bus, DUCK_EFFECT) as AudioEffectAmplify
	if amplify == null:
		return
	if _duck_tween:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_property(amplify, "volume_db", db if on else 0.0, fade_time)

func _set_muffled(on: bool) -> void:
	if _music_bus >= 0 and AudioServer.get_bus_effect_count(_music_bus) > PAUSE_FILTER_EFFECT:
		AudioServer.set_bus_effect_enabled(_music_bus, PAUSE_FILTER_EFFECT, on)

func current_stream() -> AudioStream:
	var current := _players[_active]
	return current.stream if current.playing else null

func step_aside(on: bool, fade_time: float = 0.5) -> void:
	if _aside_tween:
		_aside_tween.kill()
	_aside_tween = create_tween()
	_aside_tween.tween_property(_players[_active], "volume_linear", 0.0 if on else 1.0, fade_time)

func _on_player_finished(player: AudioStreamPlayer) -> void:
	if player == _players[_active]:
		finished.emit()

func current_position() -> float:
	var current := _players[_active]
	return current.get_playback_position() if current.playing else 0.0

#region - LAYER
func play_layer(stream: AudioStream, fade_time: float, from_position: float = 0.0, \
		bed_db: float = -12.0) -> void:
	if _layer_tween:
		_layer_tween.kill()
	if _layer.stream != stream or not _layer.playing:
		_layer.stream = stream
		_layer.volume_linear = 0.0
		_layer.play(from_position)
	_layer_tween = create_tween()
	_layer_tween.tween_property(_layer, "volume_linear", 1.0, fade_time)
	_fade_bed(bed_db, fade_time)

func stop_layer(fade_time: float) -> void:
	_fade_bed(0.0, fade_time)
	if not _layer.playing:
		return
	if _layer_tween:
		_layer_tween.kill()
	_layer_tween = create_tween()
	_layer_tween.tween_property(_layer, "volume_linear", 0.0, fade_time)
	_layer_tween.tween_callback(_layer.stop)

func _make_bed_bus() -> void:
	if AudioServer.get_bus_index(BED_BUS) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, BED_BUS)
	AudioServer.set_bus_send(index, &"Music")

func _fade_bed(db: float, fade_time: float) -> void:
	var index := AudioServer.get_bus_index(BED_BUS)
	if index < 0:
		return
	if _bed_tween:
		_bed_tween.kill()
	_bed_tween = create_tween()
	_bed_tween.tween_method(
		func(value: float) -> void: AudioServer.set_bus_volume_db(index, value),
		AudioServer.get_bus_volume_db(index), db, fade_time)
#endregion
