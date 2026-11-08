class_name HallMark
extends Marker3D

const MIDDLE_HALL_NORTH: float = -5.8 #middle of north hallway Z
const MIDDLE_HALL_WEST: float = 0.0 #middle of west hallway X

@export var mark_id: StringName

@export_group("Passing By")
@export_range(0.0, 1.0) var linger_chance: float = 0.0
@export var linger_seconds: float = 3.0
@export var linger_activity: StringName = &"look_at_photo"

func _ready() -> void:
	add_to_group("hall_marks")
