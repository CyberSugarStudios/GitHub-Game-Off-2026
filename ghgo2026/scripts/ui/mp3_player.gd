class_name MP3Player
extends CanvasLayer

@export var tracks: Array[MP3Track] = []
@export var open_event: StringName = &"listen_mp3"
@export var restart_after: float = 3.0
@export_range(0.0, 1.0) var start_volume: float = 0.8
@export var button_sound: AudioStream = preload("res://assets/audio/sfx/varied/mp3_button.wav")
@export var close_fade: float = 1.0
@export var scroll_seconds: float = 5.0

@onready var audio: AudioStreamPlayer = $Audio
@onready var title_label: Label = %TitleLabel
@onready var artist_label: Label = %ArtistLabel
@onready var cover_art: TextureRect = %CoverArt
@onready var time_label: Label = %TimeLabel
@onready var progress: ProgressBar = %Progress
@onready var back_button: Button = %BackButton
@onready var play_button: Button = %PlayButton
@onready var skip_button: Button = %SkipButton
@onready var volume_slider: HSlider = %VolumeSlider
@onready var close_button: Button = %CloseButton

var _index := 0
var _started := false
var _click: AudioStreamPlayer
var _fade: Tween

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
	progress.mouse_filter = Control.MOUSE_FILTER_STOP
	progress.gui_input.connect(_on_progress_input)
	volume_slider.value_changed.connect(
		func(value: float) -> void:
			audio.volume_linear = value
	)
	audio.finished.connect(_on_song_ended)
	_click = AudioStreamPlayer.new()
	_click.bus = &"SFX"
	_click.stream = button_sound
	add_child(_click)
	for button in [back_button, play_button, skip_button, close_button]:
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_click.play)
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
	_fade_out_song()

func _fade_out_song() -> void:
	if not _started:
		return
	_started = false
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(audio, "volume_linear", 0.0, close_fade)
	_fade.tween_callback(audio.stop)
	Music.duck(false, close_fade * 1.5)
	_show_track()

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

func _on_progress_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_seek_to(_position() + scroll_seconds)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_seek_to(_position() - scroll_seconds)
		elif button.button_index == MOUSE_BUTTON_LEFT:
			_seek_to(_track_length() * button.position.x / progress.size.x)
		progress.accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_seek_to(_track_length() * motion.position.x / progress.size.x)
		progress.accept_event()

func _seek_to(seconds: float) -> void:
	if tracks.is_empty() or tracks[_index].stream == null:
		return
	var paused := audio.stream_paused and _started
	if not _started:
		_play_index(_index)
	audio.play(clampf(seconds, 0.0, maxf(_track_length() - 0.5, 0.0)))
	audio.stream_paused = paused
	_after_change()

func _position() -> float:
	return audio.get_playback_position() if _started else 0.0

func _track_length() -> float:
	return tracks[_index].stream.get_length() if not tracks.is_empty() and tracks[_index].stream else 0.0

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
	if _fade:
		_fade.kill()
	audio.volume_linear = volume_slider.value
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
	cover_art.texture = track.cover if track else null
	cover_art.visible = cover_art.texture != null

func _process(_delta: float) -> void:
	if not visible or tracks.is_empty() or tracks[_index].stream == null:
		return
	var length := tracks[_index].stream.get_length()
	var at := audio.get_playback_position() if _started else 0.0
	progress.value = at / length if length > 0.0 else 0.0
	time_label.text = "%s  %s / %s" % [">" if is_playing() else "||", _clock(at), _clock(length)]

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
