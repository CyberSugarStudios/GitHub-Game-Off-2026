class_name HallMark
extends Marker3D

@export var mark_id: StringName

@export_group("Passing By")
@export_range(0.0, 1.0) var linger_chance: float = 0.0
@export var linger_seconds: float = 3.0
@export var linger_activity: StringName = &"look_at_photo"
@export var look_target: Node3D

func _ready() -> void:
	if mark_id == &"":
		mark_id = StringName(String(name).to_snake_case())
	add_to_group("hall_marks")

func get_look_direction(from: Vector3) -> Vector3:
	var direction := (look_target.global_position - from) if look_target else - global_basis.z
	direction.y = 0.0
	return direction.normalized()
