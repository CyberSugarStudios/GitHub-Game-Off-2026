extends CharacterBody3D

# Controls:
#   WASD      - move
#   Mouse     - look
#   E / F     - interact
#   Shift     - toggle astral plane (tap, never mash: Windows Sticky Keys)
#   Space     - struggle out of the monster's grasp (mash)
#   Esc / P   - pause (browsers eat Esc, so P is required)

#region - INIT
#region - VARS
#region - EXPORTS
@export_group("Movement")
## Living world move speed.
@export var walk_speed: float = 2.5
## Astral Plane speed modifier
@export var astral_speed_multiplier: float = 1.8
## How quickly player reaches max speed
@export var acceleration: float = 12.0

@export_group("Look")
@export var mouse_sensitivity: float = 0.0025
@export var invert_y: bool = false
@export var max_pitch_degrees: float = 80.0

@export_group("Astral Feel")
@export var astral_fov_boost: float = 8.0
@export var fov_transition_time: float = 0.5
#endregion
#region - ONREADY
@onready var camera: Camera3D = $PlayerFirstPersonCamera
#endregion
var _last_position: Vector3

var _base_fov: float
var _fov_tween: Tween
#endregion
#endregion

func _ready() -> void:
	_last_position = global_position
	_base_fov = camera.fov
	GameState.plane_changed.connect(_on_plane_changed)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
	and not GameState.is_in_room():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.screen_relative)
	elif event.is_action_pressed("enter_astral_plane"):
		GameState.toggle_plane()

func _physics_process(delta: float) -> void:
	if GameState.is_in_room():
		velocity = Vector3.ZERO
		_last_position = global_position
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := global_basis * Vector3(input.x, 0.0, input.y)
	var speed := walk_speed
	if GameState.in_astral:
		speed *= astral_speed_multiplier
	velocity = velocity.move_toward(direction * speed, acceleration * delta)
	velocity.y = 0.0
	move_and_slide()
	
	_report_distance_moved()

func _look(relative: Vector2) -> void:
	rotate_y(-relative.x * mouse_sensitivity)
	var pitch_direction := 1.0 if invert_y else -1.0
	camera.rotate_x(pitch_direction * relative.y * mouse_sensitivity)
	var limit := deg_to_rad(max_pitch_degrees)
	camera.rotation.x = clampf(camera.rotation.x, -limit, limit)

func _report_distance_moved() -> void:
	var moved := global_position.distance_to(_last_position)
	_last_position = global_position
	GameState.drain_for_movement(moved)

func _on_plane_changed(in_astral: bool) -> void:
	if _fov_tween:
		_fov_tween.kill()
	_fov_tween = create_tween()
	var target_fov := _base_fov + (astral_fov_boost if in_astral else 0.0)
	_fov_tween.tween_property(camera, "fov", target_fov, fov_transition_time).set_trans(Tween.TRANS_SINE) \
	.set_ease(Tween.EASE_OUT)
