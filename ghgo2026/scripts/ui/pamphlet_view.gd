class_name PamphletView
extends CanvasLayer

signal closed

@export var open_event: StringName = &"memorial_pamphlet"
@export var rustles: Array[AudioStream] = [
	preload("res://assets/audio/sfx/varied/paper_1.wav"),
	preload("res://assets/audio/sfx/varied/paper_2.wav"),
	preload("res://assets/audio/sfx/varied/paper_3.wav"),
	preload("res://assets/audio/sfx/varied/paper_4.wav"),
]

@onready var back_button: Button = $BackButton

var _sound: AudioStreamPlayer

func _ready() -> void:
	visible = false
	_sound = AudioStreamPlayer.new()
	_sound.bus = &"SFX"
	add_child(_sound)
	back_button.pressed.connect(close)
	Events.story_event.connect(_on_story_event)

func _on_story_event(id: StringName) -> void:
	if id == open_event:
		open()

func open() -> void:
	if visible:
		return
	visible = true
	GameState.set_controls_locked(true)
	_rustle()

func close() -> void:
	if not visible:
		return
	visible = false
	_rustle()
	GameState.set_controls_locked(false)
	closed.emit()

func _rustle() -> void:
	if rustles.is_empty():
		return
	_sound.stream = rustles.pick_random()
	_sound.pitch_scale = randf_range(0.95, 1.05)
	_sound.play()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_rustle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") \
			or event.is_action_pressed("move_backward"):
		close()
		get_viewport().set_input_as_handled()
