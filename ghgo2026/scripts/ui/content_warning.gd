extends Control

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"

@export var fade_time: float = 0.8

@onready var continue_button: Button = %ContinueButton

var _leaving := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, fade_time)
	continue_button.pressed.connect(_continue)
	continue_button.grab_focus()
	ResourceLoader.load_threaded_request(TITLE_SCENE)

func _continue() -> void:
	if _leaving:
		return
	_leaving = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	await tween.finished
	get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(TITLE_SCENE) as PackedScene)
