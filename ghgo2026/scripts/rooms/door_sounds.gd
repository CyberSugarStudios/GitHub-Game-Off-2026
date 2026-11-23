class_name DoorSound
extends Node3D

const OPEN_SOUNDS := [
	preload("res://assets/audio/sfx/varied/door_open_1.wav"),
	preload("res://assets/audio/sfx/varied/door_open_2.wav")
]
const CLOSE_SOUNDS := [
	preload("res://assets/audio/sfx/varied/door_close_1.wav"),
	preload("res://assets/audio/sfx/varied/door_close_2.wav")
]

@export var room_id: StringName
@export var has_door: bool = true
@export var close_after: float = 2.0
@export var hall_unit_size: float = 4.0
@export var room_volume_db: float = -4.0

func open_and_close() -> void:
	if not has_door:
		return
	_play(OPEN_SOUNDS.pick_random())
	await get_tree().create_timer(close_after, false).timeout
	_play(CLOSE_SOUNDS.pick_random())

func _play(stream: AudioStream) -> void:
	if GameState.is_in_room():
		if GameState.current_room != room_id:
			return
		var flat := AudioStreamPlayer.new()
		flat.stream = stream
		flat.bus = &"SFX"
		flat.volume_db = room_volume_db
		flat.pitch_scale = randf_range(0.95, 1.05)
		flat.finished.connect(flat.queue_free)
		add_child(flat)
		flat.play()
	else:
		var spatial := AudioStreamPlayer3D.new()
		spatial.stream = stream
		spatial.bus = &"SFX"
		spatial.unit_size = hall_unit_size
		spatial.pitch_scale = randf_range(0.95, 1.05)
		spatial.finished.connect(spatial.queue_free)
		add_child(spatial)
		spatial.play()
