extends Node

signal minute_changed(day: int, minute: int)
signal hour_changed(day: int, hour: int)

const SECONDS_PER_GAME_MINUTE := 1.0 #0.5 = 1 game hour every real world 30 seconds
const MINUTES_PER_DAY := 1440
const START_MINUTE := 9 * 60 # 17 = 5PM

const ASTRAL_TIME_SCALE := 0.15
const TIME_SCALE_EASE := 3.0

var day := 1
var minute := START_MINUTE
var _carry := 0.0 #real seconds accumulated towards next game minute

var world_speed := 1.0

func _process(delta: float) -> void:
	var target_speed := ASTRAL_TIME_SCALE if GameState.in_astral else 1.0
	world_speed = move_toward(world_speed, target_speed, TIME_SCALE_EASE * delta)
	
	if GameState.controls_locked:
		return
	_carry += delta * world_speed
	while _carry >= SECONDS_PER_GAME_MINUTE:
		_carry -= SECONDS_PER_GAME_MINUTE
		_advance_minute()

func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo \
	and event.keycode == KEY_F2:
		set_time(day, minute + 15)

func get_day_fraction() -> float:
	return (minute + _carry / SECONDS_PER_GAME_MINUTE) / MINUTES_PER_DAY

func get_time_text() -> String:
	@warning_ignore("integer_division")
	return "%d:%02d" % [minute / 60, minute % 60]

func set_time(new_day: int, new_minute: int) -> void:
	@warning_ignore("integer_division")
	day = new_day + new_minute / MINUTES_PER_DAY
	minute = posmod(new_minute, MINUTES_PER_DAY)
	_carry = 0.0
	minute_changed.emit(day, minute)
	@warning_ignore("integer_division")
	hour_changed.emit(day, minute / 60)

func reset() -> void:
	set_time(1, START_MINUTE)

func _advance_minute() -> void:
	minute += 1
	if minute >= MINUTES_PER_DAY:
		minute = 0
		day += 1
	minute_changed.emit(day, minute)
	if minute % 60 == 0:
		@warning_ignore("integer_division")
		hour_changed.emit(day, minute / 60)
