extends CanvasLayer

const TITLE_SCENE_PATH := "res://scenes/ui/title_screen.tscn"

@onready var resume_button: Button = $Buttons/ResumeButton
@onready var settings_button: Button = $Buttons/SettingsButton
@onready var quit_button: Button = $Buttons/QuitToTitleButton
@onready var feedback_button: Button = $Buttons/FeedbackButton
@onready var buttons: Control = $Buttons
@onready var options_page: Control = $OptionsPage
@onready var back_button: Button = $OptionsPage/BackButton

var _had_mouse_capture := false

func _ready() -> void:
	visible = false
	resume_button.pressed.connect(resume)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	feedback_button.visible = Playtest.is_enabled()
	feedback_button.pressed.connect(Playtest.open_form)
	options_page.visible = false
	back_button.pressed.connect(_close_options)

func _process(_delta: float) -> void:
	if get_tree().paused:
		return
	if GameState.is_in_room():
		_had_mouse_capture = false
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_had_mouse_capture = true
	elif _had_mouse_capture:
		open()
	
	if GameState.is_in_room():
		_had_mouse_capture = false
		return

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if options_page.visible:
			_close_options()
		elif get_tree().paused:
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
	_close_options()
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if GameState.is_in_room() else Input.MOUSE_MODE_CAPTURED

func _on_settings_pressed() -> void:
	buttons.visible = false
	options_page.visible = true
	back_button.grab_focus()

func _close_options() -> void:
	options_page.visible = false
	buttons.visible = true
	settings_button.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().paused = false
	GameState.exit_astral()
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)
