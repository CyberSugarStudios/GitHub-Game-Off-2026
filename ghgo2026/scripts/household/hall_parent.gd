class_name HallParent
extends Node3D

signal arrived(parent_id: StringName, room_id: StringName)

const LINGER_RADIUS := 0.6

@export var parent_id: StringName = &"leanne"
@export var walk_speed: float = 1.1

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var target_shape: CollisionShape3D = $Target/CollisionShape3D

var _destination: StringName = &""
var _stay_visible := false
var _linger_left := 0.0
var _passed_marks: Array[HallMark] = []

func _ready() -> void:
	_set_present(false)

func is_walking() -> bool:
	return _destination != &""

func get_destination() -> StringName:
	return _destination

func stand_at(spot: Node3D) -> void:
	global_position = spot.global_position
	_set_present(true)

func walk(from: Node3D, to: Node3D, to_id: StringName, stay_visible: bool) -> void:
	if not visible and from:
		global_position = from.global_position
	_destination = to_id
	_stay_visible = stay_visible
	agent.target_position = to.global_position
	_passed_marks.clear()
	_set_present(true)

func _physics_process(delta: float) -> void:
	if not is_walking() or GameState.controls_locked:
		return
	
	if _linger_left > 0.0:
		_linger_left -= delta * GameClock.world_speed
		return
	
	if agent.is_navigation_finished():
		var location := _destination
		_destination = &""
		_set_present(_stay_visible)
		arrived.emit(parent_id, location)
		return
	
	_check_linger()
	if _linger_left > 0.0:
		return
	
	var next := agent.get_next_path_position()
	var to_next := next - global_position
	to_next.y = 0.0
	var step := walk_speed * GameClock.world_speed * delta
	if to_next.length() <= step:
		global_position = Vector3(next.x, global_position.y, next.z)
	else:
		global_position += to_next.normalized() * step


func _check_linger() -> void:
	for node in get_tree().get_nodes_in_group("hall_marks"):
		var mark := node as HallMark
		if mark.linger_chance <= 0.0 or mark in _passed_marks:
			continue
		var offset := mark.global_position - global_position
		offset.y = 0.0
		if offset.length() <= LINGER_RADIUS:
			_passed_marks.append(mark)
			if randf() < mark.linger_chance:
				_linger_left = mark.linger_seconds
				return

func _set_present(present: bool) -> void:
	visible = present
	target_shape.set_deferred("disabled", not present)
