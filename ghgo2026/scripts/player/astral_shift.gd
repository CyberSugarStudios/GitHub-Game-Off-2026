class_name AstralShift
extends Node

@export var hold_seconds: float = 1.5

var _held := 0.0
var _wait_for_release := false
var _focus_seconds := 0.0
var _flicker_windows: Array[Vector2] = []
var _flickering := false

func start_focus(seconds: float, flicker_windows: Array[Vector2]) -> void:
	_focus_seconds = seconds
	_flicker_windows = flicker_windows

func is_focus_armed() -> bool:
	return _focus_seconds > 0.0

func _process(delta: float) -> void:
	var holding := Input.is_action_pressed("enter_astral_plane")
	if _wait_for_release:
		if not holding:
			_wait_for_release = false
		return
	
	var blocked := not GameState.shift_allowed or GameState.controls_locked
	if not holding or blocked:
		if _held > 0.0:
			_reset_hold()
		return
	
	_held += delta
	var needed := _focus_seconds if is_focus_armed() else hold_seconds
	Events.shift_charge_changed.emit(clampf(_held / needed, 0.0, 1.0))
	_set_flicker(_in_flicker_window(_held))
	if _held >= needed:
		_complete()

func _complete() -> void:
	var was_focus := is_focus_armed()
	_focus_seconds = 0.0
	_flicker_windows.clear()
	_reset_hold()
	_wait_for_release = true
	GameState.toggle_plane()
	if was_focus:
		Events.story_event.emit(&"first_focus_complete")

func _reset_hold() -> void:
	_held = 0.0
	_set_flicker(false)
	Events.shift_charge_changed.emit(0.0)

func _in_flicker_window(seconds: float) -> bool:
	if not  is_focus_armed():
		return false
	for window in _flicker_windows:
		if seconds  >= window.x and seconds < window.y:
			return true
	return false

func _set_flicker(on: bool) -> void:
	if on != _flickering:
		_flickering = on
		Events.shift_flicker.emit(on)
