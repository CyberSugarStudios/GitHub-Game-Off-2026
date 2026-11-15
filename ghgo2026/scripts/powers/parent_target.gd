class_name ParentTarget
extends PowerTarget

func _ready() -> void:
	super()
	var hall_parent := get_parent() as HallParent
	if hall_parent:
		target_id = hall_parent.parent_id
