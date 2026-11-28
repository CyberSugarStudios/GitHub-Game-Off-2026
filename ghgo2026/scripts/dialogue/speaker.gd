class_name Speaker
extends Node3D

const MUFFLED_BUS := &"VoicesMuffled"

@export var character_name: String = ""
@export var behind_door: bool = false
@export var muffled_cutoff_hz: float = 700.0
@export var muffled_db: float = -4.0

@onready var voice: AudioStreamPlayer3D = $Voice

func _ready() -> void:
	add_to_group("speakers")
	if behind_door:
		voice.bus = _muffled_bus()

func _muffled_bus() -> StringName:
	if AudioServer.get_bus_index(MUFFLED_BUS) == -1:
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, MUFFLED_BUS)
		AudioServer.set_bus_send(index, &"Voices")
		AudioServer.set_bus_volume_db(index, muffled_db)
		var filter := AudioEffectLowPassFilter.new()
		filter.cutoff_hz = muffled_cutoff_hz
		AudioServer.add_bus_effect(index, filter)
	return MUFFLED_BUS
