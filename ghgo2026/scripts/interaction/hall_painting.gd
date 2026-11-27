class_name HallPainting
extends PowerTarget

const GRAVITY := 9.8

@export var household: Household
@export var inspect_mark: HallMark
@export var broken_mark_id: StringName = &"pumpkin_photo_broken"
@export var broken_linger_activity: StringName = &"idle_sad"
@export_range(0.0, 1.0) var broken_linger_chance: float = 0.5
@export var crooked_degrees: float = 7.0
@export var fall_distance: float = 1.2
@export var fall_story_event: StringName = &"hall_painting_fell"
@export var fallen_from_stage: int = 2

@export_group("Sounds")
@export var wobble_sound: AudioStream
@export var fall_sound: AudioStream = preload("res://assets/audio/sfx/varied/frame_break.wav")

@onready var frame: Node3D = $Frame
@onready var broken_glass: Node3D = $BrokenGlass
@onready var sound: AudioStreamPlayer3D = $Sound

var _crooked := false
var _fallen := false

func _ready() -> void:
	super()
	sound.bus = &"SFX"
	broken_glass.visible = false
	Events.power_used.connect(_on_power_used)
	for parent in household.hall_parents:
		parent.linger_started.connect(_on_linger_started)
	if GameState.has_flag(fall_story_event) or GameState.story_stage >= fallen_from_stage:
		_show_fallen()

func is_focusable() -> bool:
	return not _fallen and super()

func _on_power_used(power_id: StringName, id: StringName) -> void:
	if id != target_id or power_id != &"nudge" or _fallen:
		return
	if _both_parents_in_hall():
		_fall()
	else:
		_knock_crooked()

func _both_parents_in_hall() -> bool:
	for parent in household.hall_parents:
		if not parent.visible:
			return false
	return true

func _knock_crooked() -> void:
	_crooked = true
	_play(wobble_sound)
	GameState.add_near_miss(target_id)
	var tilt := deg_to_rad(crooked_degrees) * (1.0 if randf() < 0.5 else -1.0)
	var tween := create_tween()
	tween.tween_property(frame, "rotation:z", tilt * 1.6, 0.08)
	tween.tween_property(frame, "rotation:z", tilt * 0.6, 0.12)
	tween.tween_property(frame, "rotation:z", tilt, 0.15)

func _on_linger_started(_parent_id: StringName, mark_id: StringName) -> void:
	if mark_id != inspect_mark.mark_id or not _crooked or _fallen:
		return
	_crooked = false
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(frame, "rotation:z", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _fall() -> void:
	_fallen = true
	set_collision_layer_value(2, false)
	var time := sqrt(2.0 * fall_distance / GRAVITY)
	var tween := create_tween()
	tween.tween_property(frame, "position:y",  frame.position.y - fall_distance, time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(frame, "rotation:z", frame.rotation.z + deg_to_rad(12.0), time)
	tween.tween_callback(_shatter)

func _shatter() -> void:
	_play(fall_sound)
	_show_fallen()
	GameState.set_flag(fall_story_event)
	Events.story_event.emit(fall_story_event)

func _show_fallen() -> void:
	_fallen = true
	set_collision_layer_value(2, false)
	frame.visible = false
	broken_glass.visible = true
	inspect_mark.mark_id = broken_mark_id
	inspect_mark.linger_activity  = broken_linger_activity
	inspect_mark.linger_chance = broken_linger_chance

func _play(stream:AudioStream) -> void:
	if stream:
		sound.stream = stream
		sound.play()
