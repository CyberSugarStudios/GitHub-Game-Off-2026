class_name ScheduleEntry
extends Resource

## 24hr clock
@export var start_time: String = "17:00"
## Room id, must match the doors
@export var location: StringName = &"kitchen"
## What parent will do in room
@export var activity: StringName = &"idle"

func get_start_minute() -> int:
	var parts := start_time.split(":")
	if parts.size() != 2:
		push_warning("ScheduleEntry: bad time '%s', expected HH:MM." % start_time)
		return 0
	return int(parts[0]) * 60 + int(parts[1])
