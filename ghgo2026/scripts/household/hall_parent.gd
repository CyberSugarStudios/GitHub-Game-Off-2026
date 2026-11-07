class_name HallParent
extends Node3D

signal arrived(parent_id: StringName, room_id: StringName)

@export var parent_id: StringName = &"leanne"
@export var walk_speed: float = 1.1

@onready var agent: NavigationAgent3D = $NavigationAgent3D

var _destination: StringName = &""

func _ready() -> void:
	visible = false

func is_walking() -> bool:
	return _destination != &""

func get_destination() -> StringName:
	return _destination

func walk(from: RoomEntrance, to: RoomEntrance) -> void:
	if not is_walking() and from:
		global_position = from.global_position
	_destination = to.room_id
	agent.target_position = to.global_position
	visible = true

func _physics_process(delta: float) -> void:
	if not is_walking() or GameState.controls_locked:
		return
	
	if agent.is_navigation_finished():
		var room := _destination
		_destination = &""
		visible = false
		arrived.emit(parent_id, room)
		return
	
	var next := agent.get_next_path_position()
	var to_next := next - global_position
	to_next.y = 0.0
	var step := walk_speed * GameClock.world_speed * delta
	if to_next.length() <= step:
		global_position = Vector3(next.x, global_position.y, next.z)
	else:
		global_position += to_next.normalized() * step
