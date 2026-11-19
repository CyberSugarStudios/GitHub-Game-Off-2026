class_name CreditsRoll
extends Control

signal finished

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"

@export var scroll_speed: float = 70.0
@export var music: AudioStream
@export var ending: bool = false
@export var loop: bool = false

@onready var text: RichTextLabel = %CreditsText
@onready var background: CanvasItem = get_node_or_null("Background")

var _tween: Tween
var _leaving := false

func _ready() -> void:
	clip_contents = true
	if background:
		background.visible = ending
	if ending:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		start()

func start():
	if _tween:
		_tween.kill()
	if music:
		Music.play(music)
	await get_tree().process_frame
	text.position.y = size.y
	_tween = create_tween()
	_tween.tween_property(text, "position:y", -text.size.y, (size.y + text.size.y) / scroll_speed)
	await _tween.finished
	finished.emit()
	if loop:
		start()
	elif ending:
		_back_to_title()

func _unhandled_input(event: InputEvent) -> void:
	if ending and event.is_action_pressed("ui_cancel"):
		_back_to_title()

func _back_to_title() -> void:
	if _leaving:
		return
	_leaving = true
	Music.stop(1.5)
	await create_tween().tween_interval(1.5).finished
	get_tree().change_scene_to_file(TITLE_SCENE)
