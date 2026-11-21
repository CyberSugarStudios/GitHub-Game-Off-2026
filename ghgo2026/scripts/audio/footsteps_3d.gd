class_name Footsteps3D
extends AudioStreamPlayer3D

@export var stride: float = 0.65
@export var teleport_distance: float = 1.0
@export var in_room_db: float = -10.0

@onready var walker := get_parent() as Node3D

var _last := Vector3.ZERO
var _walked := 0.0
var _base_db := 0.0

func _ready() -> void:
	_base_db = volume_db
	_last = walker.global_position

func _physics_process(_delta: float) -> void:
	var now := walker.global_position
	var moved := Vector2(now.x - _last.x, now.z - _last.z).length()
	_last = now
	if moved < 0.0001 or moved > teleport_distance or not walker.is_visible_in_tree():
		_walked = stride * 0.5
		return
	_walked += moved
	if _walked >= stride:
		_walked -= stride
		volume_db = _base_db + (in_room_db if GameState.is_in_room() else 0.0)
		play()
