class_name AstralShift
extends Node

var _held := 0.0
var _focus_seconds := 0.0
var _wait_for_release := false

func start_focus(seconds: float = 6.0) -> void:
	_focus_seconds = seconds

func is_focus_armed() -> bool:
	return _focus_seconds > 0.0

func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed \
			and not event.echo and event.keycode == KEY_F3:
		start_focus(6.0)
		return
	
	if event.is_action_pressed("enter_astral_plane") and _may_cross_instantly():
		GameState.toggle_plane()
		get_viewport().set_input_as_handled()

func _may_cross_instantly() -> bool:
	return GameState.shift_allowed and not GameState.controls_locked and not is_focus_armed() \
	and not _wait_for_release

func _process(delta: float) -> void:
	var holding := Input.is_action_pressed("enter_astral_plane")
	if _wait_for_release:
		if not holding:
			_wait_for_release = false
		return
	if not is_focus_armed():
		return
	
	if not holding or not GameState.shift_allowed or GameState.controls_locked:
		if _held > 0.0:
			_reset_hold()
		return
	
	_held += delta
	Events.shift_charge_changed.emit(clampf(_held / _focus_seconds, 0.0, 1.0))
	if _held >= _focus_seconds:
		var entered := GameState.enter_astral()
		_reset_hold()
		if entered:
			_focus_seconds = 0.0
			_wait_for_release = true
			Events.story_event.emit(&"first_focus_complete")

func _reset_hold() -> void:
	_held = 0.0
	Events.shift_charge_changed.emit(0.0)
