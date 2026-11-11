class_name Household
extends Node

@export var schedules: Array[ParentSchedule] = []
@export var hall_parents: Array[HallParent] = []

var _detours: Dictionary[StringName, Dictionary] = {}

func _ready() -> void:
	GameClock.minute_changed.connect(
		func(_day: int, _minute: int) -> void:
			_update())
	GameState.story_stage_changed.connect(
		func(_stage: int) -> void:
			_update())
	for parent in hall_parents:
		parent.arrived.connect(_on_parent_arrived)
	_place_everyone.call_deferred()

func send(parent_id: StringName, location: StringName, minutes: int) -> void:
	_detours[parent_id] = {"location": location, "until": _now() + minutes}
	_update()

func _place_everyone() -> void:
	for parent in hall_parents:
		var target := _target_location(parent.parent_id)
		if target == &"":
			continue
		var spot := _find_spot(target)
		if spot is HallMark:
			parent.stand_at(spot)
		GameState.set_parent_location(parent.parent_id, target)

func _update() -> void:
	for parent in hall_parents:
		var target := _target_location(parent.parent_id)
		if target == &"":
			continue
	
		if parent.is_walking():
			if parent.get_destination() != target:
				var new_spot := _find_spot(target)
				if new_spot:
					parent.walk(null, new_spot, target, new_spot is HallMark)
			continue
		
		var current := GameState.get_parent_location(parent.parent_id)
		if current == target:
			continue
		
		var to := _find_spot(target)
		if to == null:
			push_warning("Household: no RoomEntrance or HallMark for '%s'; placing %s there directly." % \
			[target, parent.parent_id])
			GameState.set_parent_location(parent.parent_id, target)
			continue
		
		GameState.set_parent_location(parent.parent_id, GameState.HALL)
		parent.walk(_find_spot(current), to, target, to is HallMark)

func _on_parent_arrived(parent_id: StringName, room_id: StringName) -> void:
	GameState.set_parent_location(parent_id, room_id)

func _target_location(parent_id: StringName) -> StringName:
	if _detours.has(parent_id):
		var detour: Dictionary = _detours[parent_id]
		if _now() < detour["until"]:
			return detour["location"]
		_detours.erase(parent_id)
	var entry := _current_entry(parent_id)
	return entry.location if entry else &""

func _current_entry(parent_id: StringName) -> ScheduleEntry:
	for schedule in schedules:
		if schedule.parent_id == parent_id and schedule.stage == GameState.story_stage:
			return schedule.get_entry_at(GameClock.minute)
	return null

func _now() -> int:
	return GameClock.day * GameClock.MINUTES_PER_DAY + GameClock.minute

func _find_spot(location: StringName) -> Node3D:
	for node in get_tree().get_nodes_in_group("room_entrances"):
		if (node as RoomEntrance).room_id == location:
			return node
	for node in get_tree().get_nodes_in_group("hall_marks"):
		if (node as HallMark).mark_id == location:
			return node
	return null

func get_hall_parent(parent_id: StringName) -> HallParent:
	for parent in hall_parents:
		if parent.parent_id == parent_id:
			return parent
	return null
