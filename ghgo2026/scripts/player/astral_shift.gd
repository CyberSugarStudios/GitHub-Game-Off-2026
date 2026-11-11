class_name AstralShift
extends Node

var _held := 0.0
var _focus_seconds := 0.0

func start_focus(seconds: float = 6.0) -> void:
	_focus_seconds = seconds

func is_focus_armed() -> bool:
	return _focus_seconds > 0.0

func _process(delta: float) -> void:
	if not GameState.shift_allowed or GameState.controls_locked:
		if _held > 0.0:
			_reset_hold()
		return
	
	if not is_focus_armed():
		if Input.is_action_just_pressed("enter_astral_plane"):
			GameState.toggle_plane()
		return
	
	if not Input.is_action_pressed("enter_astral_plane"):
		if _held > 0.0:
			_reset_hold()
		return
	_held += delta
	Events.shift_charge_changed.emit(clampf(_held / _focus_seconds, 0.0, 1.0))
	if _held >= _focus_seconds:
		_focus_seconds = 0.0
		_reset_hold()
		GameState.toggle_plane()
		Events.story_event.emit(&"first_focus_complete")

func _reset_hold() -> void:
	_held = 0.0
	Events.shift_charge_changed.emit(0.0)

func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed \
			and not event.echo and event.keycode == KEY_F3:
		start_focus(6.0)
