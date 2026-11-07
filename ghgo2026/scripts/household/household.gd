class_name HouseHold
extends Node

@export var schedules: Array[ParentSchedule] = []
@export var hall_parents: Array[HallParent] = []

func _ready() -> void:
	GameClock.minute_changed.connect(func(_day: int, _minute: int) -> void: _update())
	GameState.story_stage_changed.connect(func(_stage: int) -> void: _update())
	for parent in hall_parents:
		parent.arrived.connect(_on_parent_arrived)
	_place_everyone()

func _place_everyone() -> void:
	for parent in hall_parents:
		var entry := _current_entry(parent.parent_id)
		if entry:
			GameState.set_parent_location(parent.parent_id, entry.location)

func _update() -> void:
	for parent in hall_parents:
		var entry := _current_entry(parent.parent_id)
		if entry == null:
			continue
		var target := entry.location
	
		if parent.is_walking():
			if parent.get_destination() != target:
				var new_to := _find_entrance(target)
				if new_to:
					parent.walk(null, new_to)
			continue
		
		var current := GameState.get_parent_location(parent.parent_id)
		if current == target:
			continue
		
		var from := _find_entrance(current)
		var to := _find_entrance(target)
		if to == null:
			push_warning("Household: no RoomEntrance for '%s'; placing %s there directly." % \
			[target, parent.parent_id])
			GameState.set_parent_location(parent.parent_id, target)
			continue
		
		GameState.set_parent_location(parent.parent_id, GameState.HALL)
		parent.walk(from, to)

func _on_parent_arrived(parent_id: StringName, room_id: StringName) -> void:
	GameState.set_parent_location(parent_id, room_id)

func _current_entry(parent_id: StringName) -> ScheduleEntry:
	for schedule in schedules:
		if schedule.parent_id == parent_id and schedule.stage == GameState.story_stage:
			return schedule.get_entry_at(GameClock.minute)
	return null

func _find_entrance(room_id: StringName) -> RoomEntrance:
	for node in get_tree().get_nodes_in_group("room_entrances"):
		var entrance := node as RoomEntrance
		if entrance and entrance.room_id == room_id:
			return entrance
	return null
