extends CanvasLayer

const TITLE_SCENE_PATH := "res://scenes/ui/title_screen.tscn"

@onready var resume_button: Button = $Buttons/ResumeButton
@onready var settings_button: Button = $Buttons/SettingsButton
@onready var quit_button: Button = $Buttons/QuitToTitleButton

var _had_mouse_capture := false

func _ready() -> void:
	visible = false
	resume_button.pressed.connect(resume)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _process(_delta: float) -> void:
	if get_tree().paused:
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_had_mouse_capture = true
	elif _had_mouse_capture:
		open()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if get_tree().paused:
			resume()
		else:
			open()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not get_tree().paused:
		open()

func open() -> void:
	get_tree().paused = true
	visible = true
	_had_mouse_capture = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	resume_button.grab_focus()

func resume() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_settings_pressed() -> void:
	pass

func _on_quit_pressed() -> void:
	get_tree().paused = false
	GameState.exit_astral()
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)
