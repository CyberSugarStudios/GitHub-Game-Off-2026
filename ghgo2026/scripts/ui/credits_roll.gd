class_name CreditsRoll
extends Control

signal help_dismissed
signal finished

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"

@export var scroll_speed: float = 60.0
@export var music: AudioStream
@export var music_fade: float = 8.0
@export var music_db: float = -7.0
@export var music_limit_seconds: float = 88.45
@export var prompt_delay: float = 3.0
@export var gap: float = 160.0
@export var fade_in_seconds: float = 2.5

@onready var credits_title: TextureRect = %CreditsTitle
@onready var credits_text: Control = %CreditsText
@onready var help_text: Control = %HelpText
@onready var continue_prompt: CanvasItem = %ContinuePrompt
@onready var feedback_button: Button = %FeedbackButton

var _scrolled := 0.0
var _credits_start := 0.0
var _title_start := 0.0
var _help_start := 0.0
var _help_rest := 0.0
var _tween: Tween
var _waiting_on_help := false
var _leaving := false

func _ready() -> void:
	feedback_button.visible = Playtest.is_enabled()
	feedback_button.focus_mode = Control.FOCUS_NONE
	feedback_button.pressed.connect(Playtest.open_form)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in find_children("*", "Control", true, false):
		if child != feedback_button:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fade_in_from_white()
	continue_prompt.modulate.a = 0.0
	if music:
		Music.play(music, music_fade, 0.0, db_to_linear(music_db))
	await get_tree().process_frame
	await get_tree().process_frame
	_title_start = size.y - (gap * 2)
	_credits_start = _title_start + credits_title.size.y - (gap * 1.5)
	_help_start = _credits_start + credits_text.get_content_height() + gap
	_help_rest = (size.y - help_text.size.y) * 0.5
	_set_scrolled(0.0)

	var credits_gone := _title_start + credits_title.size.y + _credits_start + credits_text.size.y
	var help_settled := _help_start - _help_rest
	await _scroll_to(maxf(credits_gone, help_settled))

	_waiting_on_help = true
	var prompt_tween := create_tween()
	prompt_tween.tween_interval(prompt_delay)
	prompt_tween.tween_property(continue_prompt, "modulate:a", 1.0, 0.8)
	await help_dismissed
	prompt_tween.kill()
	create_tween().tween_property(continue_prompt, "modulate:a", 0.0, 0.4)

	_tween = create_tween()
	_tween.tween_property(help_text, "position:y", -help_text.size.y,
		(help_text.position.y + help_text.size.y) / scroll_speed)
	await _tween.finished
	finished.emit()
	_back_to_title()

func _process(_delta: float) -> void:
	if not _leaving and music_limit_seconds > 0.0 and Music.current_stream() == music \
			and Music.current_position() >= music_limit_seconds - 1.5:
		_back_to_title()

func _fade_in_from_white() -> void:
	RenderingServer.set_default_clear_color(
		ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color", Color.BLACK))
	var white := ColorRect.new()
	white.color = Color.WHITE
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(white)
	white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tween := create_tween()
	tween.tween_property(white, "color:a", 0.0, fade_in_seconds)
	tween.tween_callback(white.queue_free)

func _set_scrolled(value: float) -> void:
	_scrolled = value
	credits_title.position.y = _title_start - value
	credits_text.position.y = _credits_start - value
	help_text.position.y = maxf(_help_start - value, _help_rest)

func _scroll_to(target: float) -> void:
	_tween = create_tween()
	_tween.tween_method(_set_scrolled, _scrolled, target, absf(target - _scrolled) / scroll_speed)
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
	var black := ColorRect.new()
	black.color = Color(0.0, 0.0, 0.0, 0.0)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Music.stop(1.5)
	await create_tween().tween_property(black, "color:a", 1.0, 1.5).finished
	get_tree().change_scene_to_file(TITLE_SCENE)
