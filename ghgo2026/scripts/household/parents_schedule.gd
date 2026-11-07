class_name ParentSchedule
extends Resource

@export var parent_id: StringName = &"leanne"
## The GameState.story_stage this time is used in
@export var stage: int = 0
@export var entries: Array[ScheduleEntry] = []

func get_entry_at(minute_of_day: int) -> ScheduleEntry:
	var current: ScheduleEntry = null
	var last_of_day: ScheduleEntry = null
	for entry in entries:
		var start := entry.get_start_minute()
		if start <= minute_of_day and (current == null or start > current.get_start_minute()):
			current = entry
		if last_of_day == null or start > last_of_day.get_start_minute():
			last_of_day = entry
	return current if current else last_of_day
