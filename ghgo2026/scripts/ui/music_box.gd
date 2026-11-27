class_name MusicBoxView
extends CanvasLayer

signal closed

const REACTIONS := preload("res://dialogue/reactions.dialogue")

@export var lullaby: AudioStream = preload("res://assets/audio/music/lullaby.mp3")
@export var music_fade: float = 1.0
@export var opened_flag: StringName = &"music_box_seen"
@export var closed_flag: StringName = &"music_box_left"

@onready var art: AnimatedSprite2D = $TextureRect

var _lullaby: AudioStreamPlayer
var _fade: Tween

func _ready() -> void:
	visible = false
	_lullaby = AudioStreamPlayer.new()
	_lullaby.stream = lullaby
	_lullaby.bus = &"MP3"
	add_child(_lullaby)
	_lullaby.finished.connect(_on_lullaby_finished)

func open() -> void:
	if visible:
		return
	visible = true
	GameState.set_controls_locked(true)
	_play_lullaby()
	_say_once("music_box_opened", opened_flag)

func close() -> void:
	if not visible:
		return
	visible = false
	GameState.set_controls_locked(false)
	_stop_lullaby()
	_say_once("music_box_closed", closed_flag)
	closed.emit()

func _play_lullaby() -> void:
	if _fade:
		_fade.kill()
	_lullaby.volume_db = 0.0
	Music.duck(true, music_fade)
	_lullaby.play()

func _stop_lullaby() -> void:
	if not _lullaby.playing:
		return
	_fade = create_tween()
	_fade.tween_property(_lullaby, "volume_db", -40.0, music_fade)
	_fade.tween_callback(_lullaby.stop)
	Music.duck(false, music_fade)

func _on_lullaby_finished() -> void:
	Music.duck(false, music_fade)

func _say_once(cue: String, flag: StringName) -> void:
	if GameState.has_flag(flag):
		return
	GameState.set_flag(flag)
	Events.conversation_requested.emit(REACTIONS, cue, false)

func _process(_delta: float) -> void:
	if not visible:
		return
	if _lullaby.playing and not art.is_playing():
		art.play()
	elif not _lullaby.playing and art.is_playing():
		art.pause()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("move_backward") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if _lullaby and _lullaby.playing:
		Music.duck(false, 0.0)
