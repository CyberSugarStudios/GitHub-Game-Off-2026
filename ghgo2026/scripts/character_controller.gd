class_name Player
extends CharacterBody3D

# Controls:
#   WASD      - move
#   Mouse     - look
#   E / F     - interact
#   Shift     - press to enter astral plane
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
@export var watch_turn_speed: float = 4.0
@export var watch_head_height: float = 1.5
@export var watch_screen_margin := Vector2(0.03, 0.15)

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
var _watching: Dictionary = {}
var _speaker := ""
var _showing_both := true
#endregion
#endregion

func _ready() -> void:
	_last_position = global_position
	_base_fov = camera.fov
	GameState.plane_changed.connect(_on_plane_changed)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Events.returned_to_hall.connect(place_at)
	Events.shift_charge_changed.connect(_on_shift_charge_changed)
	Events.subtitle_changed.connect(_on_subtitle_changed)

func _on_shift_charge_changed(amount: float) -> void:
	if amount <= 0.0:
		_on_plane_changed(GameState.in_astral)
		return
	if _fov_tween:
		_fov_tween.kill()
	camera.fov = _base_fov + astral_fov_boost * amount

func _unhandled_input(event: InputEvent) -> void:
	if GameState.controls_locked:
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
	and not GameState.is_in_room():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.screen_relative)

func _physics_process(delta: float) -> void:
	if GameState.is_in_room() or GameState.controls_locked:
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

func face_toward(point: Vector3, seconds: float) -> void:
	var to_point := point - camera.global_position
	var yaw := atan2(-to_point.x, -to_point.z)
	var pitch := atan2(to_point.y, Vector2(to_point.x, to_point.z).length())
	var limit := deg_to_rad(max_pitch_degrees)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation:y", rotation.y + wrapf(yaw - rotation.y, -PI, PI), seconds)
	tween.tween_property(camera, "rotation:x", clampf(pitch, -limit, limit), seconds)

func watch(targets: Dictionary) -> void:
	_watching = targets
	_speaker = ""
	_showing_both = true

func _on_subtitle_changed(character: String, _text: String, _clarity: float, _is_thought: bool) -> void:
	if _watching.has(character):
		_speaker = character

func _process(delta: float) -> void:
	if _watching.is_empty():
		return
	var people: Array[Node3D] = []
	for person_name in _watching:
		var person := _watching[person_name] as Node3D
		if is_instance_valid(person) and person.is_visible_in_tree():
			people.append(person)
	if people.is_empty():
		return
	
	var margin := watch_screen_margin.x if _showing_both else watch_screen_margin.y
	_showing_both = people.all(
		func(person: Node3D) -> bool:
			return _on_screen(_head(person), margin)
	)
	
	var talker := _watching.get(_speaker) as Node3D
	var point := Vector3.ZERO
	if not _showing_both and talker in people:
		point = _head(talker)
	else:
		for person in people:
			point += _head(person)
		point /= people.size()
	_turn_toward(point, delta)

func _head(person: Node3D) -> Vector3:
	return person.global_position + Vector3.UP * watch_head_height

func _on_screen(point: Vector3, margin: float) -> bool:
	if camera.is_position_behind(point):
		return false
	var spot := camera.unproject_position(point) / get_viewport().get_visible_rect().size
	return spot.x >= margin and spot.x <= 1.0 - margin and spot.y >= margin and spot.y <= 1.0 - margin

func _turn_toward(point: Vector3, delta: float) -> void:
	var to_point := point - camera.global_position
	var yaw := atan2(-to_point.x, -to_point.z)
	var pitch := atan2(to_point.y, Vector2(to_point.x, to_point.z).length())
	var limit := deg_to_rad(max_pitch_degrees)
	var look_ease := 1.0 - exp(-watch_turn_speed * delta)
	rotation.y = lerp_angle(rotation.y, yaw, look_ease)
	camera.rotation.x = lerpf(camera.rotation.x, clampf(pitch, -limit, limit), look_ease)

func place_at(spot: Transform3D) -> void:
	global_position = spot.origin
	var forward := -spot.basis.z
	look_at(global_position + Vector3(forward.x, 0.0, forward.z), Vector3.UP)
	camera.rotation.x = 0.0
	velocity = Vector3.ZERO
	_last_position = global_position

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
