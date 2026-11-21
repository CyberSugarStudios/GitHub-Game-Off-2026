class_name Household
extends Node

@export var schedules: Array[ParentSchedule] = []
@export var hall_parents: Array[HallParent] = []
@export var inner_rooms: Dictionary[StringName, StringName] = {}

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
	Events.parents_staged.connect(_on_parent_staged)
	place_everyone.call_deferred()

func send(parent_id: StringName, location: StringName, minutes: int, then: Array = [], \
	activity: StringName = &"") -> void:
		_detours[parent_id] = {"location": location, "until": _now() + minutes, "then": then, \
			"activity": activity}
		_update()

func has_errand(parent_id: StringName) -> bool:
	if not _detours.has(parent_id):
		return false
	var detour: Dictionary = _detours[parent_id]
	return _now() < detour["until"] or not detour.get("then", []).is_empty()

func place_everyone() -> void:
	_detours.clear()
	settle_everyone()

func settle_everyone() -> void:
	for parent in hall_parents:
		parent.stop()
		var target := _target_location(parent.parent_id)
		if target == &"":
			continue
		var spot := _find_spot(target)
		if spot is HallMark:
			parent.stand_at(spot)
		GameState.set_parent_activity(parent.parent_id, _target_activity(parent.parent_id))
		GameState.set_parent_location(parent.parent_id, target)

func expected_location(parent_id: StringName) -> StringName:
	return _target_location(parent_id)

func _update() -> void:
	for parent in hall_parents:
		var target := _target_location(parent.parent_id)
		if target == &"":
			continue
		var activity := _target_activity(parent.parent_id)
	
		if parent.is_walking():
			if parent.get_destination() != target:
				var new_spot := _find_spot(target)
				if new_spot:
					parent.walk(null, new_spot, target, new_spot is HallMark)
			continue
		
		var current := GameState.get_parent_location(parent.parent_id)
		if current == target:
			GameState.set_parent_activity(parent.parent_id, activity)
			continue
		if _are_linked(current, target):
			GameState.set_parent_activity(parent.parent_id, activity)
			GameState.set_parent_location(parent.parent_id, target)
			continue
		
		var to := _find_spot(target)
		if to == null:
			push_warning("Household: no RoomEntrance or HallMark for '%s'; placing %s there directly." % \
			[target, parent.parent_id])
			GameState.set_parent_activity(parent.parent_id, activity)
			GameState.set_parent_location(parent.parent_id, target)
			continue
		
		GameState.set_parent_location(parent.parent_id, GameState.HALL)
		parent.walk(_find_spot(current), to, target, to is HallMark)

func _on_parent_arrived(parent_id: StringName, room_id: StringName) -> void:
	GameState.set_parent_activity(parent_id, _target_activity(parent_id))
	GameState.set_parent_location(parent_id, room_id)

func _on_parent_staged(parent_id: StringName, spot: StringName) -> void:
	var hall_parent := get_hall_parent(parent_id)
	if hall_parent and hall_parent.visible:
		for node in get_tree().get_nodes_in_group("hall_marks"):
			var mark := node as HallMark
			if mark.mark_id == spot:
				hall_parent.stage_to(mark)
				return
		push_warning("Household: no HallMark '%s' to stage %s to." % [spot, parent_id])
		return
	GameState.set_parent_activity(parent_id, spot)

func _target_location(parent_id: StringName) -> StringName:
	if _detours.has(parent_id):
		var detour: Dictionary = _detours[parent_id]
		if _now() < detour["until"]:
			return detour["location"]
		var then: Array = detour.get("then", [])
		if not then.is_empty():
			var stop: Array = then[0]
			_detours[parent_id] = {"location": stop[0], "until": _now() + stop[1], \
				"then": then.slice(1), "activity": stop[2] if stop.size() > 2 else &""}
			return stop[0]
		_detours.erase(parent_id)
	var entry := _current_entry(parent_id)
	return entry.location if entry else &""

func _target_activity(parent_id: StringName) -> StringName:
	if _detours.has(parent_id):
		return _detours[parent_id].get("activity", &"")
	var entry := _current_entry(parent_id)
	return entry.activity if entry else &""

func _current_entry(parent_id: StringName) -> ScheduleEntry:
	var best: ParentSchedule = null
	for schedule in schedules:
		if schedule.parent_id == parent_id and schedule.stage <= GameState.story_stage and \
		(best == null or schedule.stage > best.stage):
			best = schedule
	return best.get_entry_at(GameClock.minute) if best else null

func _now() -> int:
	return GameClock.get_total_minutes()

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

func _are_linked(a: StringName, b: StringName) -> bool:
	return inner_rooms.get(a, &"") == b or inner_rooms.get(b, &"") == a
