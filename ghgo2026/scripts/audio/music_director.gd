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
@export var calm_after_hunt: float = 4.0

var _set: MusicSet
var _last_track: AudioStream
var _playing: AudioStream
var _positions: Dictionary[AudioStream, float] = {}
var _quiet_left := -1.0
var _hunting := false
var _calm_left := 0.0
var _held := false

func _ready() -> void:
	Music.finished.connect(_on_track_finished)
	GameState.story_stage_changed.connect(func(_stage: int) -> void: _choose_set())
	GameState.plane_changed.connect(func(_astral: bool) -> void: _on_plane_changed())
	GameState.flag_set.connect(func(id: StringName) -> void:
		if id == &"creature_accepted":
			_held = true)
	_choose_set()

func _process(delta: float) -> void:
	if _held:
		return
	if _creature_close():
		_calm_left = calm_after_hunt
		if not _hunting:
			_hunting = true
			_quiet_left = -1.0
			_remember_position()
			_playing = null
			if hunt_music:
				Music.play(hunt_music, hunt_fade, hunt_music_start)
			else:
				Music.stop(hunt_fade)
		return
	if _hunting:
		_calm_left -= delta
		if _calm_left <= 0.0:
			_hunting = false
			_resume()
		return
	if _quiet_left >= 0.0:
		_quiet_left -= delta
		if _quiet_left < 0.0:
			_play_next()

func _creature_close() -> bool:
	if creature == null:
		return false
	var state := creature.get_state()
	return state == Creature.State.HUNTING or state == Creature.State.GRABBING

func _choose_set() -> void:
	var best := -1
	for stage in stage_music:
		if stage <= GameState.story_stage and stage > best:
			best = stage
	var chosen: MusicSet = stage_music[best] if best >= 0 else null
	if chosen == _set:
		return
	_set = chosen
	if not _hunting and not _held:
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

func _resume() -> void:
	var was_playing := _last_track != null and \
		(_positions.has(_last_track) or _positions.has(astral_versions.get(_last_track)))
	if was_playing:
		_play_track(_version(_last_track), hunt_fade)
	else:
		_play_next()

func _on_plane_changed() -> void:
	if _held or _hunting or _playing == null:
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
	if _hunting or _held or _set == null:
		return
	if _last_track:
		_positions.erase(_last_track)
		if astral_versions.has(_last_track):
			_positions.erase(astral_versions[_last_track])
	_playing = null
	_quiet_left = randf_range(_set.silence_between.x, _set.silence_between.y)
