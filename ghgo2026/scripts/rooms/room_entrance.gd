class_name RoomEntrance
extends DoorSound

@export var steps_inside: int = 5
@export var step_gap: float = 0.5

var _walks: Dictionary[StringName, int] = {}

func _ready() -> void:
	add_to_group("room_entrances")
	if has_door:
		GameState.parent_location_changed.connect(_on_parent_moved)
		GameState.parent_activity_changed.connect(_on_parent_moved)

func _on_parent_moved(parent_id: StringName, _value: StringName) -> void:
	if GameState.get_parent_location(parent_id) != room_id:
		return
	var stream: AudioStream = RoomActor.STEPS.get(parent_id)
	if stream == null:
		return
	var walk: int = _walks.get(parent_id, 0) + 1
	_walks[parent_id] = walk
	for i in steps_inside:
		await get_tree().create_timer(step_gap, false).timeout
		if _walks[parent_id] != walk or GameState.get_parent_location(parent_id) != room_id:
			return
		if GameState.is_in_room():
			continue
		var step := AudioStreamPlayer3D.new()
		step.stream = stream
		step.bus = DoorSound.muffled_bus(true)
		step.unit_size = hall_unit_size
		step.finished.connect(step.queue_free)
		add_child(step)
		step.play()
