class_name CreatureVoice
extends Node3D

@export var swells: AudioStreamRandomizer
@export_range(0.3, 1.0) var peak_at: float = 0.78
@export var unit_size: float = 4.0
@export var fade_out_seconds: float = 0.8
@export_group("Hunting")
@export var hunting_gap := Vector2(0.0, 0.3)
@export var hunting_db: float = 0.0
@export_group("Guarding")
@export var guarding_gap := Vector2(1.5, 4.0)
@export var guarding_db: float = -4.0
@export_group("Lurking")
@export var lurking_gap := Vector2(3.0, 7.0)
@export var lurking_db: float = -8.0

@onready var creature := get_parent() as Creature

var _players: Array[AudioStreamPlayer3D] = []
var _turn := 0
var _last_clip := -1
var _next_in := 0.0
var _state := Creature.State.HIDDEN
var _fading := false
var _fade: Tween

func _ready() -> void:
	for i in 2:
		var player := AudioStreamPlayer3D.new()
		player.bus = &"SFX"
		player.unit_size = unit_size
		add_child(player)
		_players.append(player)

func _process(delta: float) -> void:
	var state := creature.get_state()
	if state != _state:
		_state = state
		_next_in = 0.0
	if state == Creature.State.HIDDEN:
		_fade_out()
		return
	_next_in -= delta
	if _next_in <= 0.0:
		_swell(state)

func _swell(state: Creature.State) -> void:
	var clip := _pick_clip()
	if clip == null:
		return
	if _fade:
		_fade.kill()
	_fading = false
	var player := _players[_turn]
	_turn = 1 - _turn
	player.stream = clip
	player.volume_db = _volume_for(state)
	player.play()
	var gap := _gap_for(state)
	_next_in = clip.get_length() * peak_at + randf_range(gap.x, gap.y)

func _pick_clip() -> AudioStream:
	if swells == null or swells.streams_count == 0:
		return null
	var index := randi() % swells.streams_count
	if swells.streams_count > 1 and index == _last_clip:
		index = (index + 1) % swells.streams_count
	_last_clip = index
	return swells.get_stream(index)

func _gap_for(state: Creature.State) -> Vector2:
	match state:
		Creature.State.LURKING:
			return lurking_gap
		Creature.State.GUARDING:
			return guarding_gap
	return hunting_gap

func _volume_for(state: Creature.State) -> float:
	match state:
		Creature.State.LURKING:
			return lurking_db
		Creature.State.GUARDING:
			return guarding_db
	return hunting_db

func _fade_out() -> void:
	if _fading or not (_players[0].playing or _players[1].playing):
		return
	_fading = true
	_fade = create_tween().set_parallel()
	for player in _players:
		_fade.tween_property(player, "volume_db", -40.0, fade_out_seconds)
	_fade.chain().tween_callback(func() -> void:
		for player in _players:
			player.stop())
