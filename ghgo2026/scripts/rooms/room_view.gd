class_name RoomView
extends Node

@export var rooms: Dictionary[StringName, PackedScene] = {}

@export_group("Panning")
@export var pan_speed: float = 900.0
@export var pan_acceleration: float = 4000.0

@export_group("Transition")
@export var fade_time: float = 0.35
@export var staged_pan_time: float = 1.2

@export_group("Followning")
@export var follow_speed: float = 3.0

@onready var room_layer: CanvasLayer = $RoomLayer
@onready var room_ui: CanvasLayer = $RoomUI
@onready var exit_button: TextureRect = $RoomUI/KeyHints/ExitButton
@onready var exit_arrow: TextureRect = $RoomUI/KeyHints/ExitArrow
@onready var fade_rect: ColorRect = $FadeLayer/Fade
@onready var input_blocker: ColorRect = $RoomUI/InputBlocker
@onready var key_hints: Control = $RoomUI/KeyHints

@export var key_hint_hold: float = 3.0
@export var key_hint_fade: float = 2.5

@export var intro_room: StringName = &"living_room"

@export var exit_fade: float = 1.2
@export var exit_reveal_scale: float = 3.0
@export var exit_reveal_hold: float = 0.8
@export var exit_reveal_fly: float = 0.7

static var _hinted_rooms: Dictionary = {}
var _key_tween: Tween
var _hold_hints := false
var _exit_tween: Tween

var _room: Room = null
var _busy := false # guard against double-triggers
var _room_width := 0.0
var _max_pan := 0.0
var _pan_x := 0.0
var _pan_velocity := 0.0
var _pan_tween: Tween
var _following := false
var _speaker := ""
var _follow_held := false
var _hold_this_line := false
var _exit_spot := Transform3D.IDENTITY
var exit_locked := false:
	set(value):
		var was_locked := exit_locked
		exit_locked = value
		if exit_button == null:
			return
		if was_locked and not value and room_ui.visible:
			_reveal_exit()
		else:
			_show_exit(not value)

func _ready() -> void:
	room_ui.visible = false
	fade_rect.color.a = 0.0
	Events.door_opened.connect(enter_room)
	Events.room_door_opened.connect(change_room)
	Events.room_pan_requested.connect(_on_pan_requested)
	Events.subtitle_changed.connect(_on_subtitle_changed)
	_show_exit(not exit_locked, true)
	get_viewport().size_changed.connect(_fit_room)
	GameState.controls_locked_changed.connect(_on_controls_locked_changed)
	_on_controls_locked_changed(GameState.controls_locked)

func _on_controls_locked_changed(locked: bool) -> void:
	input_blocker.visible = locked
	key_hints.visible = not locked or _hold_hints

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
	_busy = true
	await _fade_to(1.0)
	
	_open(room_id, exit_spot)
	
	await _fade_to(0.0)
	_busy = false

func _open(room_id: StringName, exit_spot: Transform3D) -> void:
	_exit_spot = exit_spot
	
	_room = rooms[room_id].instantiate() as Room
	room_layer.add_child(_room)
	GameState.enter_room(room_id)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_viewport().disable_3d = true
	room_ui.visible = true
	_max_pan = 0.0
	_pan_velocity = 0.0
	_fit_room()
	_show_key_hints(room_id)

func open_now(room_id: StringName, exit_spot: Transform3D) -> void:
	if _room or not rooms.has(room_id):
		return
	_open(room_id, exit_spot)

func change_room(room_id: StringName) -> void:
	if _busy or not _room:
		return
	if not rooms.has(room_id):
		push_warning("RoomView: no scene for room '%s'. Add it under RoomView > Rooms." % room_id)
		return
	_busy = true
	await _fade_to(1.0)
	_room.queue_free()
	_room = null
	_open(room_id, _exit_spot)
	await _fade_to(0.0)
	_busy = false

func _show_exit(shown: bool, instant: bool = false) -> void:
	if _exit_tween:
		_exit_tween.kill()
	exit_button.visible = true
	exit_arrow.visible = true
	if instant or not shown:
		exit_button.modulate.a = 1.0 if shown else 0.0
		exit_arrow.modulate.a = exit_button.modulate.a
		return
	_exit_tween = create_tween().set_parallel()
	_exit_tween.tween_property(exit_button, "modulate:a", 1.0, exit_fade)
	_exit_tween.tween_property(exit_arrow, "modulate:a", 1.0, exit_fade)

func _reveal_exit() -> void:
	if _exit_tween:
		_exit_tween.kill()
	var parts: Array[Control] = [exit_button, exit_arrow]
	var group := Rect2(exit_button.global_position, exit_button.size) \
		.merge(Rect2(exit_arrow.global_position, exit_arrow.size))
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room_ui.add_child(holder)
	holder.size = group.size
	holder.pivot_offset = group.size * 0.5
	for part in parts:
		part.visible = true
		var copy := part.duplicate() as Control
		holder.add_child(copy)
		copy.set_anchors_preset(Control.PRESET_TOP_LEFT)
		copy.size = part.size
		copy.position = part.global_position - group.position
		copy.modulate.a = 1.0
		part.modulate.a = 0.0
	holder.position = get_viewport().get_visible_rect().size * 0.5 - holder.pivot_offset
	holder.scale = Vector2.ONE * exit_reveal_scale * 1.15
	holder.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(holder, "modulate:a", 1.0, 0.4)
	tween.parallel().tween_property(holder, "scale", Vector2.ONE * exit_reveal_scale, 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(exit_reveal_hold)
	tween.tween_property(holder, "position", group.position, exit_reveal_fly) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(holder, "scale", Vector2.ONE, exit_reveal_fly) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	for part in parts:
		part.modulate.a = 1.0
	holder.queue_free()

func _show_key_hints(room_id: StringName) -> void:
	if _key_tween:
		_key_tween.kill()
	key_hints.modulate.a = 0.0
	_hold_hints = false
	var in_intro := not GameState.has_flag(StoryDirector.INTRO_DONE) and room_id == intro_room
	var shown: int = _hinted_rooms.get(room_id, 0)
	if shown >= (2 if in_intro else 1):
		return
	_hinted_rooms[room_id] = shown + 1
	_hold_hints = in_intro and shown == 0
	while GameState.controls_locked or _busy:
		await get_tree().process_frame
	if _room == null or GameState.current_room != room_id:
		return
	_key_tween = create_tween()
	_key_tween.tween_property(key_hints, "modulate:a", 1.0, 0.4)
	if _hold_hints:
		return
	_key_tween.tween_interval(key_hint_hold)
	_key_tween.tween_property(key_hints, "modulate:a", 0.0, key_hint_fade)

func current_room() -> Room:
	return _room

func exit_room() -> void:
	if _busy or not _room or exit_locked or GameState.controls_locked:
		return
	if _hold_hints:
		_hold_hints = false
		if _key_tween:
			_key_tween.kill()
		_key_tween = create_tween()
		_key_tween.tween_property(key_hints, "modulate:a", 0.0, 0.4)
	if _room.exits_to != &"":
		change_room(_room.exits_to)
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
	if _following and _room and not _busy:
		_follow(delta)
	if not _room or _busy or GameState.controls_locked:
		return
	
	var direction := Input.get_axis("move_left", "move_right") # A/D keys
	
	_pan_velocity = move_toward(_pan_velocity, direction * pan_speed, pan_acceleration * delta)
	_pan_x = clampf(_pan_x + _pan_velocity * delta, 0.0, _max_pan)
	if (_pan_x <= 0.0 and _pan_velocity < 0.0) or (_pan_x >= _max_pan and _pan_velocity > 0.0):
		_pan_velocity = 0.0
	_apply_pan()

func set_pan(ratio: float) -> void:
	_set_pan_x(_max_pan * clampf(ratio,  0.0, 1.0))

func pan_to(ratio: float, seconds: float) -> void:
	if not _room:
		return
	_pan_velocity = 0.0
	_pan_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pan_tween.tween_method(_set_pan_x, _pan_x, _max_pan * clampf(ratio, 0.0, 1.0), seconds)
	await _pan_tween.finished

func _set_pan_x(x: float) -> void:
	_pan_x = x
	_apply_pan()

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

#region - FOLLOWING SPEAKERS
func follow_speakers(on: bool) -> void:
	_following = on
	_speaker = ""
	_follow_held = false
	_hold_this_line = false

func _on_pan_requested(ratio: float) -> void:
	_follow_held = true
	_hold_this_line = true
	pan_to(ratio, staged_pan_time)

func _on_subtitle_changed(character: String, _text: String, _clarity: float, _is_thought: bool) -> void:
	if character == "":
		return
	if _hold_this_line:
		_hold_this_line = false
		return
	if _actor_for(character):
		_speaker = character
		_follow_held = false

func _follow(delta: float) -> void:
	if _follow_held or _max_pan <= 0.0 or (_pan_tween and _pan_tween.is_running()):
		return
	var actors := _visible_actors()
	if actors.is_empty():
		return
	var talker := _actor_for(_speaker)
	var target_x := 0.0
	if talker:
		target_x = talker.global_position.x
	else:
		for actor in actors:
			target_x += actor.global_position.x
		target_x /= actors.size()
	var screen_width := get_viewport().get_visible_rect().size.x
	var target_pan := clampf(target_x - screen_width * 0.5, 0.0, _max_pan)
	_set_pan_x(lerpf(_pan_x, target_pan, 1.0 - exp(-follow_speed * delta)))

func _visible_actors() -> Array[RoomActor]:
	var actors: Array[RoomActor] = []
	var holder := _room.get_node_or_null("Actors")
	if holder:
		for child in holder.get_children():
			var actor := child as RoomActor
			if actor and actor.visible:
				actors.append(actor)
	return actors

func _actor_for(character: String) -> RoomActor:
	if character == "" or not _room:
		return null
	for actor in _visible_actors():
		if String(actor.parent_id) == character.to_lower():
			return actor
	return null
#endregion
