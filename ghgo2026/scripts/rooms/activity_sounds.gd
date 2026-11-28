class_name ActivitySounds
extends Node

@export var parent_id: StringName = &"david"
@export var activity_contains: String = "drinking"
@export var activity_excludes: String = ""
@export var sounds: Array[AudioStream] = []
@export var gap_seconds := Vector2(8.0, 20.0)
@export var plays_per_activity: int = 0
@export var volume_db: float = 0.0
@export var bus: StringName = &"SFX"
@export var actor: RoomActor
@export var quiet_animations: Array[StringName] = [&"sleeping"]

var _room_id: StringName
var _player: AudioStreamPlayer
var _wait := 0.0
var _played := 0
var _last := -1

func _ready() -> void:
	var node := get_parent()
	while node and not node is Room:
		node = node.get_parent()
	if node:
		_room_id = (node as Room).room_id
	_player = AudioStreamPlayer.new()
	_player.bus = bus
	_player.volume_db = volume_db
	add_child(_player)
	GameState.parent_activity_changed.connect(_on_parent_activity_changed)
	_restart()

func _on_parent_activity_changed(changed_id: StringName, _activity: StringName) -> void:
	if changed_id == parent_id:
		_restart()

func _restart() -> void:
	_played = 0
	_wait = randf_range(gap_seconds.x, gap_seconds.y)

func _process(delta: float) -> void:
	if sounds.is_empty() or not _is_active():
		return
	if plays_per_activity > 0 and _played >= plays_per_activity:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = randf_range(gap_seconds.x, gap_seconds.y)
	_played += 1
	_play_random()

func _is_active() -> bool:
	if GameState.current_room != _room_id or GameState.get_parent_location(parent_id) != _room_id:
		return false
	var activity := String(GameState.get_parent_activity(parent_id))
	if not activity.contains(activity_contains):
		return false
	if actor and actor.sprite.animation in quiet_animations:
		return false
	return activity_excludes == "" or not activity.contains(activity_excludes)

func _play_random() -> void:
	var index := randi() % sounds.size()
	if sounds.size() > 1 and index == _last:
		index = (index + 1) % sounds.size()
	_last = index
	_player.stream = sounds[index]
	_player.pitch_scale = randf_range(0.95, 1.05)
	_player.play()
