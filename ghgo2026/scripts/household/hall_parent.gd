class_name HallParent
extends Node3D

signal arrived(parent_id: StringName, room_id: StringName)
signal linger_started(parent_id: StringName, mark_id: StringName)

const LINGER_RADIUS := 0.6
const STAGE_SNAP_DISTANCE := 0.75

@export var parent_id: StringName = &"leanne"
@export var walk_speed: float = 1.1

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var target_shape: CollisionShape3D = $Target/CollisionShape3D

var current_linger: HallMark = null
var standing_at: HallMark = null
var speed_scale := 1.0
var facing := Vector3.FORWARD
var is_moving := false

var _present := false
var _warming := false
var _destination: StringName = &""
var _walk_target: Node3D = null
var _stay_visible := false
var _linger_left := 0.0
var _linger_target: HallMark = null
var _passed_marks: Array[HallMark] = []
var _stage_target: HallMark = null

func _ready() -> void:
	add_to_group("astral_visibility")
	add_to_group("hall_parents")
	_set_present(false)

func is_walking() -> bool:
	return _destination != &""

func get_destination() -> StringName:
	return _destination

func is_using_mark(mark: HallMark) -> bool:
	return visible and (current_linger == mark or _linger_target == mark or standing_at == mark)

func stand_at(spot: Node3D) -> void:
	global_position = spot.global_position
	standing_at = spot as HallMark
	_set_present(true)

func stop() -> void:
	_stage_target = null
	_destination = &""
	_linger_left = 0.0
	_linger_target = null
	standing_at = null
	current_linger = null
	_set_present(false)

func set_warmup(on: bool) -> void:
	_warming = on
	visible = on or _present

func play_action(anim: StringName) -> void:
	var sprite := get_node_or_null("Sprite") as ParentSprite
	if sprite:
		sprite.play_action(anim)

func stage_to(mark: HallMark) -> void:
	_stage_target = mark
	standing_at = null
	_linger_left = 0.0
	_linger_target = null
	current_linger = null
	agent.target_position = mark.global_position

func walk(from: Node3D, to: Node3D, to_id: StringName, stay_visible: bool) -> void:
	_stage_target = null
	if not visible and from:
		global_position = from.global_position
	_destination = to_id
	_stay_visible = stay_visible
	_walk_target = to
	standing_at = null
	agent.target_position = to.global_position
	_passed_marks.clear()
	_linger_target = null
	_set_present(true)

func _physics_process(delta: float) -> void:
	is_moving = false
	if GameState.is_parent_held(parent_id):
		return
	if _stage_target:
		var point := agent.get_next_path_position()
		if agent.is_navigation_finished():
			var target := _stage_target.global_position
			var gap := Vector2(target.x - global_position.x, target.z - global_position.z).length()
			point = target if gap <= STAGE_SNAP_DISTANCE else global_position
		if _step_toward(point, delta) and agent.is_navigation_finished():
			standing_at = _stage_target
			_stage_target = null
		return
	if not is_walking() or GameState.controls_locked:
		return
	
	if _linger_left > 0.0:
		_linger_left -= delta * GameClock.world_speed
		if _linger_left <= 0.0:
			current_linger = null
		return
	if _linger_target:
		if _step_toward(_linger_target.global_position, delta):
			_linger_left = _linger_target.linger_seconds
			current_linger = _linger_target
			linger_started.emit(parent_id, _linger_target.mark_id)
			_linger_target = null
		return
	
	if agent.is_navigation_finished():
		var location := _destination
		_destination = &""
		speed_scale = 1.0
		standing_at = _walk_target as HallMark
		_set_present(_stay_visible)
		arrived.emit(parent_id, location)
		return
	
	_check_linger()
	if _linger_target:
		_step_toward(_linger_target.global_position, delta)
		return
	
	_step_toward(agent.get_next_path_position(), delta)

func _check_linger() -> void:
	for node in get_tree().get_nodes_in_group("hall_marks"):
		var mark := node as HallMark
		if mark.linger_chance <= 0.0 or mark in _passed_marks:
			continue
		var offset := mark.global_position - global_position
		offset.y = 0.0
		if offset.length() <= LINGER_RADIUS:
			_passed_marks.append(mark)
			if _mark_taken(mark):
				continue
			if randf() < mark.linger_chance:
				_linger_target = mark
				return

func _mark_taken(mark: HallMark) -> bool:
	for node in get_tree().get_nodes_in_group("hall_parents"):
		if node != self and (node as HallParent).is_using_mark(mark):
			return true
	return false

func _step_toward(point: Vector3, delta: float) -> bool:
	var to_point := point - global_position
	to_point.y = 0.0
	var step := walk_speed * speed_scale * GameClock.world_speed * delta
	if to_point.length() > 0.001:
		facing = to_point.normalized()
		is_moving = true
	if to_point.length() <= step:
		global_position = Vector3(point.x, global_position.y, point.z)
		return true
	global_position += to_point.normalized() * step
	return false

func _set_present(present: bool) -> void:
	_present = present
	visible = present or _warming
	target_shape.set_deferred("disabled", not present)
