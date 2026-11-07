extends Node

const DEFAULT_FADE := 1.5
const PAUSE_FILTER_EFFECT := 0

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _fade_tween: Tween
var _music_bus := -1
var _was_paused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_bus = AudioServer.get_bus_index(&"Music")
	
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		player.volume_linear = 0.0
		add_child(player)
		_players.append(player)
	_set_muffled(false)

func _process(_delta: float) -> void:
	var paused := get_tree().paused
	if paused != _was_paused:
		_was_paused = paused
		_set_muffled(paused)

func play(stream: AudioStream, fade_time: float = DEFAULT_FADE) -> void:
	var current := _players[_active]
	if current.stream == stream and current.playing:
		return
	if _fade_tween:
		_fade_tween.kill()
	
	var next := _players[1 - _active]
	next.stop()
	next.stream = stream
	next.volume_linear = 0.0
	next.play()
	
	_fade_tween = create_tween().set_parallel()
	_fade_tween.tween_property(next, "volume_linear", 1.0, fade_time)
	_fade_tween.tween_property(current, "volume_linear", 0.0, fade_time)
	_fade_tween.chain().tween_callback(current.stop)
	_active = 1 - _active

func stop(fade_time: float = DEFAULT_FADE) -> void:
	if _fade_tween:
		_fade_tween.kill()
	var current := _players[_active]
	_fade_tween = create_tween()
	_fade_tween.tween_property(current, "volume_linear", 0.0, fade_time)
	_fade_tween.tween_callback(current.stop)

func _set_muffled(on: bool) -> void:
	if _music_bus >= 0 and AudioServer.get_bus_effect_count(_music_bus) > PAUSE_FILTER_EFFECT:
		AudioServer.set_bus_effect_enabled(_music_bus, PAUSE_FILTER_EFFECT, on)
