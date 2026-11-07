class_name ConversationPlayer
extends Node
# plays Dialogue Manager conversations with voice acting in two modes:
# Mode 1: Live (frozen = false): The game keeps running, and the lines play from the speaker's pos
# Mode 2: Memory (frozen = true): Cutscene, letterbox, full subtitles, voice not positional
# Voice files: res://audio/voice/line.ogg. Missing file fallback to reading-time estimate

#region - INIT
const VOICE_FOLDER := "res://audio/voice/"
#region - EXPORTS
@export_group("Live Listening")
@export var clear_distance: float = 4.0
@export var lost_distance: float = 14.0

@export_group("Timing")
@export var gap_after_line: float = 0.25
@export var seconds_per_character: float = 0.06
@export var min_line_time: float = 1.5
#endregion
@onready var flat_voice: AudioStreamPlayer = $FlatVoice

var _run_id := 0
var _running := false
var _frozen := false
var _line: DialogueLine = null
var _speaker: Speaker = null
var _time_left := 0.0
var _last_clarity := -1.0
#endregion

func _ready() -> void:
	Events.conversation_requested.connect(play)

func _exit_tree() -> void:
	GameState.set_controls_locked(false)

#region - PLAYING
func play(dialogue: DialogueResource, title: String, frozen: bool) -> void:
	if _running and _frozen:
		return
	_stop_current()
	_run_id += 1
	var my_id := _run_id
	_running = true
	_frozen = frozen
	if frozen:
		GameState.set_controls_locked(true)
	
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(dialogue, title)
	while line and my_id == _run_id:
		await _play_line(line, my_id)
		if my_id != _run_id:
			return
		line = await DialogueManager.get_next_dialogue_line(dialogue, line.next_id)
	
	if my_id == _run_id:
		_finish(title)

func _play_line(line: DialogueLine, my_id: int) -> void:
	_line = line
	_speaker = null if _frozen else _find_speaker(line.character)
	
	var voice := _load_voice(line)
	if voice:
		_time_left = voice.get_length() + gap_after_line
		if _speaker:
			_speaker.voice.stream = voice
			_speaker.voice.play()
		else:
			flat_voice.stream = voice
			flat_voice.play()
	else:
		_time_left = maxf(min_line_time, line.text.length() * seconds_per_character)
	
	_last_clarity = -1.0
	_update_subtitle()
	
	while _time_left > 0.0 and my_id == _run_id:
		await get_tree().process_frame
	
	if my_id == _run_id:
		_stop_audio()
		Events.subtitle_changed.emit("", "", 1.0, false)

func _process(delta: float) -> void:
	if not _running:
		return
	_time_left -= delta
	_update_subtitle()

func _unhandled_input(event: InputEvent) -> void:
	if _running and _frozen and (event.is_action_pressed("struggle") or event.is_action_pressed("interact")):
		_time_left = 0.0
		get_viewport().set_input_as_handled()

func _finish(title: String) -> void:
	_running = false
	_line = null
	if _frozen:
		GameState.set_controls_locked(false)
	_frozen = false
	Events.subtitle_changed.emit("", "", 1.0, false)
	Events.conversation_finished.emit(title)

func _stop_current() -> void:
	_stop_audio()
	_line = null
	_time_left = 0.0
	if _running:
		Events.subtitle_changed.emit("", "", 1.0, false)
	_running = false

func _stop_audio() -> void:
	flat_voice.stop()
	if is_instance_valid(_speaker):
		_speaker.voice.stop()
#endregion

#region - HELPERS
func _find_speaker(character: String) -> Speaker:
	for node in get_tree().get_nodes_in_group("speakers"):
		var speaker := node as Speaker
		if speaker and speaker.character_name == character and speaker.is_visible_in_tree():
			return speaker
	return null # No one in hall, voice plays flat

func _load_voice(line: DialogueLine) -> AudioStream:
	if line.static_id == "":
		return null # Scene not locked yet, no line IDs
	var path := VOICE_FOLDER + line.static_id + ".ogg"
	if not ResourceLoader.exists(path):
		return null # Not recorded yet
	return load(path) as AudioStream

# 1 = readble, 0 = lost
func _get_clarity() -> float:
	if _frozen or not is_instance_valid(_speaker):
		return 1.0
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return 1.0
	var distance := camera.global_position.distance_to(_speaker.global_position)
	return clampf(inverse_lerp(lost_distance, clear_distance, distance), 0.0, 1.0)

func _update_subtitle() -> void:
	if _line == null:
		return
	var clarity := _get_clarity()
	if absf(clarity - _last_clarity) < 0.02:
		return # barely changed, no need to resend
	_last_clarity = clarity
	Events.subtitle_changed.emit(_line.character, _line.text, clarity, _line.has_tag("thought"))
#endregion
