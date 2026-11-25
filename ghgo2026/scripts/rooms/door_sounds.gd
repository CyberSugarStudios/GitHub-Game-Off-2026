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

const DOOR_BUS := &"ThroughDoor"
const DOORWAY_BUS := &"ThroughDoorway"
const DOOR_CUTOFF_HZ := 500.0
const DOORWAY_CUTOFF_HZ := 1800.0
const DOOR_VOLUME_DB := -6.0
const DOORWAY_VOLUME_DB := -2.0

@export var room_id: StringName
@export var has_door: bool = true
@export var close_after: float = 2.0
@export var hall_unit_size: float = 4.0
@export var room_volume_db: float = -4.0

static func muffled_bus(through_door: bool) -> StringName:
	var bus_name := DOOR_BUS if through_door else DOORWAY_BUS
	if AudioServer.get_bus_index(bus_name) == -1:
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, &"SFX")
		AudioServer.set_bus_volume_db(index, DOOR_VOLUME_DB if through_door else DOORWAY_VOLUME_DB)
		var filter := AudioEffectLowPassFilter.new()
		filter.cutoff_hz = DOOR_CUTOFF_HZ if through_door else DOORWAY_CUTOFF_HZ
		AudioServer.add_bus_effect(index, filter)
	return bus_name

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
