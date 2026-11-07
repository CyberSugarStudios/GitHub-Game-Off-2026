class_name RoomEntrance
extends Marker3D

@export var room_id: StringName

func _ready() -> void:
	add_to_group("room_entrances")
