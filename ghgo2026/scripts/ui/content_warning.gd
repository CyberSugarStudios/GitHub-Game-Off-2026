extends Control

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const FIRST_SETTINGS_SCENE := "res://scenes/ui/first_settings.tscn"

@export var fade_time: float = 0.8

@onready var continue_button: Button = %ContinueButton
@onready var body_text: RichTextLabel = $VBoxContainer/Body

var _leaving := false
var cw_url := "https://www.findahelpline.com"

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, fade_time)
	continue_button.pressed.connect(_continue)
	continue_button.grab_focus()
	ResourceLoader.load_threaded_request(TITLE_SCENE)
	ResourceLoader.load_threaded_request(GAME_SCENE, "", true)
	body_text.meta_clicked.connect(on_find_help_clicked)

func on_find_help_clicked(meta):
	OS.shell_open(str(meta))

func _continue() -> void:
	if _leaving:
		return
	_leaving = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	await tween.finished
	if _first_run():
		get_tree().change_scene_to_file(FIRST_SETTINGS_SCENE)
	else:
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(TITLE_SCENE) as PackedScene)

static func _first_run() -> bool:
	if Settings.onboarding_seen < Settings.ONBOARDING_VERSION:
		return true
	return not FileAccess.file_exists(Settings.PATH) and not GameState.has_checkpoint()
