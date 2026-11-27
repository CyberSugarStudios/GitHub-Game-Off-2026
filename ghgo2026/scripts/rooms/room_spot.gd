@tool
class_name RoomSpot
extends Marker2D

enum Facing { EITHER, LEFT, RIGHT }

@export var facing: Facing = Facing.EITHER
@export var also_for: Array[StringName] = []
@export_placeholder("") var spot_id: String = ""
@export var animation: StringName
@export var night_animation: StringName
@export var night_hours := Vector2(23.0, 6.0)
@export var seat: Node2D

func animation_now() -> StringName:
	if night_animation != &"":
		var hour := GameClock.get_day_fraction() * 24.0
		if hour >= night_hours.x or hour < night_hours.y:
			return night_animation
	return animation

func matches(id: StringName) -> bool:
	return get_spot_id() == id or id in also_for

func get_spot_id() -> StringName:
	return StringName(spot_id if spot_id != "" else String(name).to_snake_case())

func _validate_property(property: Dictionary) -> void:
	if property.name == "spot_id":
		property.hint_string = String(name).to_snake_case()
