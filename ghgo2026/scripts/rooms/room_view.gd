class_name RoomView
extends Node

@export var rooms: Dictionary[StringName, PackedScene] = {}

@export_group("Panning")
@export var pan_speed: float = 900.0
@export var pan_acceleration: float = 4000.0
@export_range(0.0, 0.95) var mouse_deadzone: float = 0.5

@export_group("Transition")
@export var fade_time: float = 0.35

@onready var room_layer: CanvasLayer = $RoomLayer
@onready var room_ui: CanvasLayer = $RoomUI
@onready var exit_button: Button = $RoomUI/ExitButton
@onready var fade_rect: ColorRect = $FadeLayer/Fade

var _room: Room = null
var _busy := false # guard against double-triggers
var _room_width := 0.0
var _max_pan := 0.0
var _pan_x := 0.0
var _pan_velocity := 0.0
var _exit_spot := Transform3D.IDENTITY

func _ready() -> void:
	room_ui.visible = false
	fade_rect.color.a = 0.0
	Events.door_opened.connect(enter_room)
	exit_button.pressed.connect(exit_room)
	get_viewport().size_changed.connect(_fit_room)

func _exit_tree() -> void:
	get_viewport().disable_3d = false
	GameState.leave_room()

#region - SHIFTING IN AND OUT OF ROOMS
func enter_room(room_id: StringName, exit_spot: Transform3D) -> void:
	if _busy or _room:
		return
	if not rooms.has(room_id):
		push_warning("RoomView: no scene for room '%s'. Add it under RoomView > Rooms." % room_id)
		return
	_exit_spot = exit_spot
	_busy = true
	await _fade_to(1.0)
	
	_room = rooms[room_id].instantiate() as Room
	room_layer.add_child(_room)
	GameState.enter_room(room_id)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_viewport().disable_3d = true
	room_ui.visible = true
	_max_pan = 0.0
	_pan_velocity = 0.0
	_fit_room()
	
	await _fade_to(0.0)
	_busy = false

func exit_room() -> void:
	if _busy or not _room:
		return
	_busy = true
	await _fade_to(1.0)
	
	_room.queue_free()
	_room = null
	room_ui.visible = false
	get_viewport().disable_3d = false
	GameState.leave_room()
	Events.returned_to_hall.emit(_exit_spot)
	Events.interaction_prompt_changed.emit("", false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	await _fade_to(0.0)
	_busy = false

func _unhandled_input(event: InputEvent) -> void:
	if _room and not _busy and not GameState.controls_locked and event.is_action_pressed("move_backward"): # S Key
		exit_room()
		get_viewport().set_input_as_handled()

func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", alpha, fade_time)
	await tween.finished
#endregion

#region - PANNING
func _process(delta: float) -> void:
	if not _room or _busy or GameState.controls_locked:
		return
	
	var direction := Input.get_axis("move_left", "move_right") # A/D keys
	if direction == 0.0 and _mouse_may_pan():
		direction = _mouse_pan_direction()
	
	_pan_velocity = move_toward(_pan_velocity, direction * pan_speed, pan_acceleration * delta)
	_pan_x = clampf(_pan_x + _pan_velocity * delta, 0.0, _max_pan)
	if (_pan_x <= 0.0 and _pan_velocity < 0.0) or (_pan_x >= _max_pan and _pan_velocity > 0.0):
		_pan_velocity = 0.0
	_apply_pan()

func _mouse_may_pan() -> bool:
	if Powers.target != &"":
		return false
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered == null or hovered.mouse_filter == Control.MOUSE_FILTER_IGNORE

func _mouse_pan_direction() -> float:
	var screen_width := get_viewport().get_visible_rect().size.x
	var mouse_x := get_viewport().get_mouse_position().x
	var from_center := clampf(mouse_x / screen_width * 2.0 - 1.0, -1.0, 1.0)
	var beyond_deadzone := absf(from_center) - mouse_deadzone
	if beyond_deadzone <= 0.0:
		return 0.0
	return signf(from_center) * beyond_deadzone / (1.0 - mouse_deadzone)

func _fit_room() -> void:
	if not _room:
		return
	var screen := get_viewport().get_visible_rect().size
	var room_size := _room.get_room_size()
	var fit := screen.y / room_size.y
	var pan_ratio := _pan_x / _max_pan if _max_pan > 0.0 else _room.start_pan
	
	_room.scale = Vector2(fit, fit)
	_room_width = room_size.x * fit
	_max_pan = maxf(_room_width - screen.x, 0.0)
	_pan_x = _max_pan * pan_ratio
	_apply_pan()

func _apply_pan():
	var screen_width := get_viewport().get_visible_rect().size.x
	if _room_width <= screen_width:
		room_layer.offset.x = (screen_width - _room_width) / 2.0
	else:
		room_layer.offset.x = -_pan_x
#endregion
