class_name RoomLight
extends PointLight2D

const DAY_NIGHT := preload("res://resources/day_night_palette.tres")

@export var on_energy: float = 1.0
@export_range(0.0, 1.0) var day_strength: float = 0.0
@export var lit_hours := Vector2(0.0, 24.0)
@export var needs_activity: String = ""
@export var fade_speed: float = 4.0

@export_group("TV")
@export var tv_flicker: bool = false
@export var tv_colors := PackedColorArray([
	Color(0.55, 0.75, 1.0),
	Color(1.0, 0.85, 0.7),
	Color(0.75, 1.0, 0.8),
	Color(1.0, 1.0, 1.0),
	Color(0.9, 0.6, 0.9),
	Color(0.5, 0.6, 0.9)
])
@export var shot_seconds := Vector2(0.6, 3.0)
@export var power_target: StringName
@export var cut_by_power: StringName = &"static"
@export var off_when_asleep_sober: bool = false
@export var on_sound: AudioStream
@export var off_sound: AudioStream

var _room_id: StringName
var _level := 0.0
var _cut := false
var _shot_left := 0.0
var _shot_color := Color.WHITE
var _shot_energy := 1.0
var _flicker_energy := 1.0
var _was_on := false
var _switch_sound: AudioStreamPlayer

func _ready() -> void:
	var node := get_parent()
	while node and not node is Room:
		node = node.get_parent()
	if node:
		_room_id = (node as Room).room_id
	Events.power_used.connect(_on_power_used)
	GameState.parent_activity_changed.connect(
		func(_parent_id: StringName, _activity: StringName) -> void:
			_cut = false
	)
	_level = 1.0 if _is_switched_on() else 0.0
	_was_on = _is_switched_on()
	if on_sound or off_sound:
		_switch_sound = AudioStreamPlayer.new()
		_switch_sound.bus = &"SFX"
		add_child(_switch_sound)

func _process(delta: float) -> void:
	var switched_on := _is_switched_on()
	if switched_on != _was_on:
		_was_on = switched_on
		_play_switch(switched_on)
	_level = move_toward(_level, 1.0 if switched_on else 0.0, delta * fade_speed)
	var daylight := DAY_NIGHT.sun_energy.sample(GameClock.get_day_fraction())
	var strength := on_energy * _level * lerpf(1.0, day_strength, daylight) * (1.0 - DayNight.astral_amount)
	if tv_flicker:
		strength *= _flicker(delta)
	energy = strength
	visible = energy > 0.001

func _is_switched_on() -> bool:
	if _cut:
		return false
	var hour := GameClock.get_day_fraction() * 24.0
	var in_hours := (hour >= lit_hours.x and hour < lit_hours.y) if lit_hours.x <= lit_hours.y \
		else (hour >- lit_hours.x or hour < lit_hours.y)
	if not in_hours:
		return false
	if needs_activity == "":
		return true
	for parent_id in GameState.parent_activities:
		if GameState.get_parent_location(parent_id) == _room_id \
			and String(GameState.get_parent_activity(parent_id)).contains(needs_activity) \
			and not _dozed_off(parent_id):
				return true
	return false

func _dozed_off(parent_id: StringName) -> bool:
	if not off_when_asleep_sober or not GameState.is_parent_asleep(parent_id):
		return false
	var drank := String(GameState.get_parent_activity(parent_id)).contains("drinking")
	return not drank or GameState.has_flag(StringName("%s_sober_tonight" % parent_id))

func _play_switch(switched_on: bool) -> void:
	var stream := on_sound if switched_on else off_sound
	if stream == null or _switch_sound == null or GameState.current_room != _room_id:
		return
	_switch_sound.stream = stream
	_switch_sound.play()

func _flicker(delta: float) -> float:
	_shot_left -= delta
	if _shot_left <= 0.0 and not tv_colors.is_empty():
		var shot_range := shot_seconds
		if Settings.reduce_flashing:
			shot_range = Vector2(maxf(shot_seconds.x, 2.0), maxf(shot_seconds.y, 5.0))
		_shot_left = randf_range(shot_range.x, shot_range.y)
		_shot_color = tv_colors[randi() % tv_colors.size()]
		_shot_energy = randf_range(0.6, 1.3)
	var ease_in := minf(delta * (2.5 if Settings.reduce_flashing else 10.0), 1.0)
	color = color.lerp(_shot_color, ease_in)
	_flicker_energy = lerpf(_flicker_energy, _shot_energy, ease_in)
	return _flicker_energy * (1.0 if Settings.reduce_flashing else randf_range(0.96, 1.04))

func _on_power_used(power_id: StringName, id: StringName) -> void:
	if power_target != &"" and id == power_target and power_id == cut_by_power:
		_cut = true
		_level = 0.0
