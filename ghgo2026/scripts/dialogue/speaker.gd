class_name Speaker
extends Node3D

const MUFFLED_BUS := &"VoicesMuffled"
const MUFFLED_CUTOFF_HZ := 700.0
const MUFFLED_DB := -6.0

@export var character_name: String = ""
@export var behind_door: bool = false

@onready var voice: AudioStreamPlayer3D = $Voice

func _ready() -> void:
	add_to_group("speakers")
	set_muffled(false)

func set_muffled(on: bool) -> void:
	voice.bus = muffled_bus() if on or behind_door else &"Voices"

static func muffled_bus() -> StringName:
	if AudioServer.get_bus_index(MUFFLED_BUS) == -1:
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, MUFFLED_BUS)
		AudioServer.set_bus_send(index, &"Voices")
		AudioServer.set_bus_volume_db(index, MUFFLED_DB)
		var filter := AudioEffectLowPassFilter.new()
		filter.cutoff_hz = MUFFLED_CUTOFF_HZ
		AudioServer.add_bus_effect(index, filter)
	return MUFFLED_BUS
