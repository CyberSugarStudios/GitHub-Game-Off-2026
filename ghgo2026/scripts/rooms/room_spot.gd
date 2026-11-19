@tool
class_name RoomSpot
extends Marker2D

enum Facing { EITHER, LEFT, RIGHT }

@export var facing: Facing = Facing.EITHER
@export_placeholder("") var spot_id: String = ""

func get_spot_id() -> StringName:
	return StringName(spot_id if spot_id != "" else String(name).to_snake_case())

func _validate_property(property: Dictionary) -> void:
	if property.name == "spot_id":
		property.hint_string = String(name).to_snake_case()
