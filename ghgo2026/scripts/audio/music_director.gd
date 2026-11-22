class_name MusicDirector
extends Node

@export var creature: Creature
@export var stage_music: Dictionary[int, MusicSet] = {}
@export var hunt_music: AudioStream
@export var hunt_fade: float = 1.0
@export var calm_after_hunt: float = 4.0

var _set: MusicSet
var _last_track: AudioStream
var _quiet_left := -1.0
var _hunting := false
var _calm_left := 0.0
var _held := false

func _ready() -> void:
	Music.finished.connect(_on_track_finished)
	GameState.story_stage_changed.connect(
		func(_stage: int) -> void:
			_choose_set()
	)
	GameState.flag_set.connect(
		func(id: StringName) -> void:
			if id == &"creature_accepted":
				_held = true
	)
	_choose_set()

func _process(delta: float) -> void:
	if _held:
		return
	if _creature_close():
		_calm_left = calm_after_hunt
		if not _hunting:
			_hunting = true
			_quiet_left = -1.0
			if hunt_music:
				Music.play(hunt_music, hunt_fade)
			else:
				Music.stop(hunt_fade)
		return
	if _hunting:
		_calm_left -= delta
		if _calm_left <= 0.0:
			_hunting = false
			_play_next()
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
	var chosen: MusicSet = stage_music[best] if best >= 0 else  null
	if chosen == _set:
		return
	_set = chosen
	if not _hunting and not _held:
		_play_next()

func _play_next() -> void:
	_quiet_left = -1.0
	if _set == null or _set.tracks.is_empty():
		return
	var choices := _set.tracks.filter(
		func(track: AudioStream) -> bool:
			return track != _last_track
	)
	if choices.is_empty():
		choices = _set.tracks
	_last_track = choices.pick_random()
	Music.play(_last_track)

func _on_track_finished() -> void:
	if _hunting or _held or _set == null:
		return
	_quiet_left = randf_range(_set.silence_between.x, _set.silence_between.y)
