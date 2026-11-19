class_name MP3Player
extends CanvasLayer

@export var tracks: Array[MP3Track] = []
@export var open_event: StringName = &"listen_mp3"
@export var restart_after: float = 3.0
@export_range(0.0, 1.0) var start_volume: float = 0.8

@onready var audio: AudioStreamPlayer = $Audio
@onready var title_label: Label = %TitleLabel
@onready var artist_label: Label = %ArtistLabel
@onready var time_label: Label = %TimeLabel
@onready var progress: ProgressBar = %Progress
@onready var back_button: Button = %BackButton
@onready var play_button: Button = %PlayButton
@onready var skip_button: Button = %SkipButton
@onready var volume_slider: HSlider = %VolumeSlider
@onready var close_button: Button = %CloseButton

var _index := 0
var _started := false

func _ready() -> void:
	visible = false
	audio.bus = &"MP3"
	audio.volume_linear = start_volume
	volume_slider.value = start_volume
	Events.story_event.connect(_on_story_event)
	back_button.pressed.connect(back)
	play_button.pressed.connect(toggle_play)
	skip_button.pressed.connect(skip)
	close_button.pressed.connect(close)
	volume_slider.value_changed.connect(
		func(value: float) -> void:
			audio.volume_linear = value
	)
	audio.finished.connect(_on_song_ended)
	for button in [back_button, play_button, skip_button, close_button]:
		button.focus_mode = Control.FOCUS_NONE
	_show_track()

func _on_story_event(id: StringName) -> void:
	if id == open_event:
		open()

func open() -> void:
	if visible or tracks.is_empty():
		return
	visible = true
	GameState.set_controls_locked(true)

func close() -> void:
	if not visible:
		return
	visible = false
	GameState.set_controls_locked(false)

func toggle_play() -> void:
	if not _started:
		_play_index(_index)
		return
	audio.stream_paused = not audio.stream_paused
	_after_change()

func skip() -> void:
	_select(_index + 1)

func back() -> void:
	if _started and audio.get_playback_position() > restart_after:
		_play_index(_index)
	else:
		_select(_index - 1)

func is_playing() -> bool:
	return _started and not audio.stream_paused

func _select(index: int) -> void:
	if tracks.is_empty():
		return
	if is_playing():
		_play_index(index)
		return
	_index = wrapi(index, 0, tracks.size())
	audio.stop()
	_started = false
	_after_change()

func _on_song_ended() -> void:
	_play_index(_index + 1)

func _play_index(index: int) -> void:
	if tracks.is_empty():
		return
	_index = wrapi(index, 0, tracks.size())
	audio.stream = tracks[_index].stream
	audio.stream_paused = false
	audio.play()
	_started = true
	_after_change()

func _after_change() -> void:
	Music.duck(is_playing())
	_show_track()

func _show_track() -> void:
	var track: MP3Track = tracks[_index] if not tracks.is_empty() else null
	title_label.text = track.title if track else "No songs"
	artist_label.text = track.artist if track else "No artist"
	play_button.text = "Pause" if is_playing() else "Play"

func _process(_delta: float) -> void:
	if not visible or tracks.is_empty() or tracks[_index].stream == null:
		return
	var length := tracks[_index].stream.get_length()
	var at := audio.get_playback_position() if _started else 0.0
	progress.value = at / length if length > 0.0 else 0.0
	time_label.text = "%s / %s" % [_clock(at), _clock(length)]

static func _clock(seconds: float) -> String:
	return "%d:%02d" % [floori(seconds / 60.0), int(seconds) % 60]

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") \
		or event.is_action_pressed("move_backward"):
			close()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("struggle"):
		toggle_play()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		back()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		skip()
	else:
		return
	get_viewport().set_input_as_handled()
