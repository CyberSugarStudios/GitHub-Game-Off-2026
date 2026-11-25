class_name MusicDirector
extends Node

@export var creature: Creature
@export var stage_music: Dictionary[int, MusicSet] = {}
@export var astral_versions: Dictionary[AudioStream, AudioStream] = {}
@export var plane_fade: float = 1.5

@export_group("Hunt")
@export var hunt_music: AudioStream
@export var hunt_music_start: float = 9.75
@export var hunt_fade: float = 1.0
@export var hunt_fade_out: float = 0.6
@export var calm_after_hunt: float = 0.5
@export var hall_quiet_db: float = -12.0

@export_group("Diary")
@export var diary_flag: StringName = &"diary_unlocked"
@export var diary_song: AudioStream = preload("res://assets/audio/music/end_credits_music.mp3")
@export var diary_fade: float = 3.0

@export_group("Intro")
@export var intro_song: AudioStream = preload("res://assets/audio/MP3_music/Anathema.mp3")
@export var intro_ambience: AudioStream
@export var intro_ambience_db: float = -6.0
@export_subgroup("Earbuds")
@export var earbuds_low_cut_hz: float = 500.0
@export var earbuds_high_cut_hz: float = 3500.0
@export_range(0.0, 1.0) var earbuds_crunch: float = 0.15
@export_range(0.0, 1.0) var earbuds_width: float = 0.2
@export var earbuds_volume_db: float = -4.0

const EARBUDS_BUS := &"Earbuds"

var _set: MusicSet
var _last_track: AudioStream
var _playing: AudioStream
var _positions: Dictionary[AudioStream, float] = {}
var _quiet_left := -1.0
var _hunting := false
var _calm_left := 0.0
var _held := false
var _song := false
var _intro := false
var _intro_players: Array[AudioStreamPlayer] = []
var _earbuds_db := 0.0

func _ready() -> void:
	Music.finished.connect(_on_track_finished)
	GameState.story_stage_changed.connect(func(_stage: int) -> void: _choose_set())
	GameState.plane_changed.connect(func(_astral: bool) -> void: _on_plane_changed())
	GameState.flag_set.connect(func(id: StringName) -> void:
		if id == &"creature_accepted":
			_held = true
			_end_hunt()
		elif id == diary_flag:
			_play_song())
	_choose_set()
	if GameState.has_flag(diary_flag):
		_play_song()

func _exit_tree() -> void:
	Music.stop_layer(hunt_fade_out)

func _process(delta: float) -> void:
	if _held:
		return
	_update_hunt(delta)
	if _quiet_left >= 0.0:
		_quiet_left -= delta
		if _quiet_left < 0.0:
			_play_next()

#region - HUNT
func _update_hunt(delta: float) -> void:
	if creature and creature.sees_player():
		_calm_left = calm_after_hunt
		if not _hunting and hunt_music:
			_hunting = true
			Music.play_layer(hunt_music, hunt_fade, hunt_music_start, hall_quiet_db)
		return
	if _hunting:
		_calm_left -= delta
		if _calm_left <= 0.0:
			_end_hunt()

func _end_hunt() -> void:
	if not _hunting:
		return
	_hunting = false
	Music.stop_layer(hunt_fade_out)
#endregion

#region - HALL MUSIC
func play_intro() -> void:
	_intro = true
	_remember_position()
	_playing = null
	Music.stop(0.3)
	var earbuds := AudioServer.get_bus_index(_earbuds_bus())
	_earbuds_db = AudioServer.get_bus_volume_db(earbuds)
	AudioServer.set_bus_bypass_effects(earbuds, true)
	AudioServer.set_bus_volume_db(earbuds, 0.0)
	_start_intro_sound(intro_song, EARBUDS_BUS, 0.0)
	_start_intro_sound(intro_ambience, &"Ambience", intro_ambience_db)

func intro_to_earbuds() -> void:
	var earbuds := AudioServer.get_bus_index(EARBUDS_BUS)
	if earbuds < 0:
		return
	AudioServer.set_bus_bypass_effects(earbuds, false)
	AudioServer.set_bus_volume_db(earbuds, _earbuds_db)

func end_intro(fade_time: float) -> void:
	if not _intro:
		return
	_intro = false
	for player in _intro_players:
		var tween := create_tween()
		tween.tween_property(player, "volume_linear", 0.0, fade_time)
		tween.tween_callback(player.queue_free)
	_intro_players.clear()
	_quiet_left = fade_time + (_set.silence_between.x if _set else 0.0)

func _start_intro_sound(stream: AudioStream, bus: StringName, volume_db: float) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	add_child(player)
	player.play()
	_intro_players.append(player)

func _earbuds_bus() -> StringName:
	if AudioServer.get_bus_index(EARBUDS_BUS) == -1:
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, EARBUDS_BUS)
		AudioServer.set_bus_send(index, &"Music")
		AudioServer.set_bus_volume_db(index, earbuds_volume_db)
		var low_cut := AudioEffectHighPassFilter.new()
		low_cut.cutoff_hz = earbuds_low_cut_hz
		var high_cut := AudioEffectLowPassFilter.new()
		high_cut.cutoff_hz = earbuds_high_cut_hz
		var crunch := AudioEffectDistortion.new()
		crunch.mode = AudioEffectDistortion.MODE_LOFI
		crunch.drive = earbuds_crunch
		var narrow := AudioEffectStereoEnhance.new()
		narrow.pan_pullout = earbuds_width
		for effect in [low_cut, high_cut, crunch, narrow]:
			AudioServer.add_bus_effect(index, effect)
	return EARBUDS_BUS

func _play_song() -> void:
	if _song or diary_song == null:
		return
	_song = true
	_remember_position()
	_playing = null
	_quiet_left = -1.0
	Music.play(diary_song, diary_fade)

func _choose_set() -> void:
	if _song:
		return
	var best := -1
	for stage in stage_music:
		if stage <= GameState.story_stage and stage > best:
			best = stage
	var chosen: MusicSet = stage_music[best] if best >= 0 else null
	if chosen == _set:
		return
	_set = chosen
	if not _held and not _intro:
		_play_next()

func _play_next() -> void:
	_quiet_left = -1.0
	if _set == null or _set.tracks.is_empty():
		return
	var choices := _set.tracks.filter(func(track: AudioStream) -> bool: return track != _last_track)
	if choices.is_empty():
		choices = _set.tracks
	_last_track = choices.pick_random()
	_play_track(_version(_last_track), Music.DEFAULT_FADE)

func _on_plane_changed() -> void:
	if _held or _playing == null:
		return
	var version := _version(_last_track)
	if version != _playing:
		_play_track(version, plane_fade)

func _play_track(stream: AudioStream, fade: float) -> void:
	_remember_position()
	_playing = stream
	Music.play(stream, fade, _positions.get(stream, 0.0))

func _remember_position() -> void:
	if _playing and Music.current_stream() == _playing:
		_positions[_playing] = Music.current_position()

func _version(track: AudioStream) -> AudioStream:
	if GameState.in_astral and astral_versions.has(track):
		return astral_versions[track]
	return track

func _on_track_finished() -> void:
	if _held or _song or _intro or _set == null:
		return
	if _last_track:
		_positions.erase(_last_track)
		if astral_versions.has(_last_track):
			_positions.erase(astral_versions[_last_track])
	_playing = null
	_quiet_left = randf_range(_set.silence_between.x, _set.silence_between.y)
#endregion
