class_name CreditsRoll
extends Control

signal help_dismissed
signal finished

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"

@export var scroll_speed: float = 70.0
@export var music: AudioStream
@export var prompt_delay: float = 3.0

@onready var roll: Control = %Roll
@onready var help_text: Control = %HelpText
@onready var continue_prompt: CanvasItem = %ContinuePrompt

var _tween: Tween
var _waiting_on_help := false
var _leaving := false

func _ready() -> void:
	clip_contents = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	continue_prompt.modulate.a = 0.0
	if music:
		Music.play(music)
	await get_tree().process_frame
	await get_tree().process_frame
	roll.position.y = size.y

	await _scroll_to(size.y * 0.5 - (help_text.position.y + help_text.size.y * 0.5))

	_waiting_on_help = true
	var prompt_tween := create_tween()
	prompt_tween.tween_interval(prompt_delay)
	prompt_tween.tween_property(continue_prompt, "modulate:a", 1.0, 0.8)
	await help_dismissed
	prompt_tween.kill()
	create_tween().tween_property(continue_prompt, "modulate:a", 0.0, 0.4)

	await _scroll_to(-roll.size.y)
	finished.emit()
	_back_to_title()

func _scroll_to(y: float) -> void:
	_tween = create_tween()
	_tween.tween_property(roll, "position:y", y, absf(roll.position.y - y) / scroll_speed)
	await _tween.finished

func _unhandled_input(event: InputEvent) -> void:
	if _waiting_on_help:
		var any_button := event is InputEventKey or event is InputEventMouseButton \
				or event is InputEventJoypadButton
		if any_button and event.is_pressed() and not event.is_echo():
			_waiting_on_help = false
			help_dismissed.emit()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _tween and _tween.is_running():
		_tween.custom_step(9999.0)
		get_viewport().set_input_as_handled()

func _back_to_title() -> void:
	if _leaving:
		return
	_leaving = true
	Music.stop(1.5)
	await create_tween().tween_interval(1.5).finished
	get_tree().change_scene_to_file(TITLE_SCENE)
