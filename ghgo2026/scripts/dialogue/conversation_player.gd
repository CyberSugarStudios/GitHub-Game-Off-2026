class_name ConversationPlayer
extends Node

#region - INIT
const VOICE_FOLDER := "res://audio/voice/"
const EMILY_VOICE_FOLDER := "res://assets/audio/Emily Voicelines/"
const STAGED_PARENTS: Array[String] = ["leanne", "david"]
#region - EXPORTS
@export_group("Live Listening")
@export var clear_distance: float = 4.0
@export var lost_distance: float = 14.0

@export_group("Timing")
@export var gap_after_line: float = 0.25
@export var seconds_per_character: float = 0.06
@export var min_line_time: float = 1.5
@export var uninterruptible_prefixes: Array[String] = ["emily_stage"]
#endregion
@onready var flat_voice: AudioStreamPlayer = $FlatVoice

var _run_id := 0
var _running := false
var _frozen := false
var _line: DialogueLine = null
var _speaker: Speaker = null
var _time_left := 0.0
var _last_clarity := -1.0
var _title := ""
var _dialogue: DialogueResource = null
var _protected := false
var _started_frame := -1
#endregion

func _ready() -> void:
	Events.conversation_requested.connect(play)
	Events.dialogue_interrupt_requested.connect(interrupt)
	Events.creature_moment.connect(_on_creature_moment)

func _exit_tree() -> void:
	_run_id += 1
	_running = false
	GameState.set_controls_locked(false)

#region - PLAYING
func is_running() -> bool:
	return _running

func interrupt() -> void:
	if _running and not _frozen and _started_frame != Engine.get_process_frames():
		_stop_current()

func current_title() -> String:
	return _title if _running else ""

func line_time_left() -> float:
	return maxf(_time_left - gap_after_line, 0.0) if _running and _line else INF

func _on_creature_moment(kind: StringName) -> void:
	if kind == &"grabbed":
		interrupt()

func play(dialogue: DialogueResource, title: String, frozen: bool) -> void:
	if _running and _frozen:
		return
	if _running and _protected and not frozen:
		return
	_stop_current()
	_title = title
	_dialogue = dialogue
	_protected = uninterruptible_prefixes.any(func(prefix: String) -> bool: return title.begins_with(prefix))
	_started_frame = Engine.get_process_frames()
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
	_stage(line)
	_speaker = null if (_frozen or line.has_tag("thought")) else _find_speaker(line.character)
	
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
	
	while _time_left > 0.0 and my_id == _run_id and is_inside_tree():
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

func _stage(line: DialogueLine) -> void:
	for parent_id in STAGED_PARENTS:
		var spot := line.get_tag_value(parent_id)
		if spot != "":
			Events.parents_staged.emit(StringName(parent_id), StringName(spot))
	var pan := line.get_tag_value("pan")
	if pan != "":
		Events.room_pan_requested.emit(pan.to_float())

func _stop_current() -> void:
	_stop_audio()
	_line = null
	_time_left = 0.0
	if _running:
		Events.subtitle_changed.emit("", "", 1.0, false)
		Events.conversation_finished.emit.call_deferred(_title)
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
	return null

func _load_voice(line: DialogueLine) -> AudioStream:
	var path := VOICE_FOLDER + line.static_id + ".ogg"
	if line.static_id == "" or not ResourceLoader.exists(path):
		path = emily_voice_path(_dialogue, line)
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream

static func emily_voice_path(dialogue: DialogueResource, line: DialogueLine) -> String:
	var local_id := line.id.get_slice("@", line.id.get_slice_count("@") - 1)
	if dialogue == null or line.character != "Emily" or not local_id.is_valid_int():
		return ""
	var line_id := local_id.to_int()
	var cue := ""
	var cue_start := -1
	for cue_name in dialogue.cues:
		var start := str(dialogue.cues[cue_name]).to_int()
		if start <= line_id and start > cue_start:
			cue = cue_name
			cue_start = start
	if cue == "":
		return ""
	var count := 0
	for id in range(cue_start, line_id + 1):
		var info: Dictionary = dialogue.lines.get(str(id), {})
		if info.get("type") == "dialogue" and info.get("character") == "Emily":
			count += 1
	var file_name := cue if count <= 1 else cue + str(count)
	return EMILY_VOICE_FOLDER + dialogue.resource_path.get_file().get_basename() + "/" + file_name + ".wav"

# 1 = readble, 0 = lost
func _get_clarity() -> float:
	if _frozen or not is_instance_valid(_speaker) or not _speaker.is_visible_in_tree():
		return 1.0
	if _in_same_room(_line.character):
		return 1.0
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return 1.0
	var distance := camera.global_position.distance_to(_speaker.global_position)
	return clampf(inverse_lerp(lost_distance, clear_distance, distance), 0.0, 1.0)

func _in_same_room(character: String) -> bool:
	if not GameState.is_in_room():
		return false
	var parent_id := StringName(character.to_lower())
	return GameState.get_parent_location(parent_id) == GameState.current_room

func _update_subtitle() -> void:
	if _line == null:
		return
	var clarity := _get_clarity()
	if absf(clarity - _last_clarity) < 0.02:
		return
	_last_clarity = clarity
	Events.subtitle_changed.emit(_line.character, _line.text, clarity, _line.has_tag("thought"))
#endregion
