class_name CupboardKeypad
extends CanvasLayer

const KEY_PROMPT := preload("res://scenes/ui/key_prompt.tscn")

@export var open_event: StringName = &"tv_cupboard"
@export var code: String = "2184"
@export var caption_text: String = "Locked"
@export var unlocked_flag: StringName = &"tv_cupboard_unlocked"
@export var lullaby: AudioStream = preload("res://assets/audio/music/lullaby.mp3")
@export var unlock_pause: float = 0.6
@export var duck_fade: float = 1.0

var _keypad: DiaryKeypad
var _leave_prompt: KeyPrompt
var _lullaby: AudioStreamPlayer

func _ready() -> void:
	layer = 10
	_keypad = DiaryKeypad.new()
	_keypad.code = code
	_keypad.caption_text = caption_text
	add_child(_keypad)
	_keypad.unlocked.connect(_on_unlocked)
	_keypad.close_requested.connect(close)
	_leave_prompt = KEY_PROMPT.instantiate() as KeyPrompt
	_leave_prompt.font_size = 26
	_leave_prompt.show_prompt("S", "Leave")
	_leave_prompt.visible = false
	add_child(_leave_prompt)
	_leave_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_leave_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_leave_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_leave_prompt.offset_top = -40.0
	_leave_prompt.offset_bottom = -40.0
	_lullaby = AudioStreamPlayer.new()
	_lullaby.stream = lullaby
	_lullaby.bus = &"MP3"
	add_child(_lullaby)
	_lullaby.finished.connect(_on_lullaby_finished)
	Events.story_event.connect(_on_story_event)
	GameState.room_changed.connect(_on_room_changed)

func _on_story_event(id: StringName) -> void:
	if id == open_event:
		open()
	elif id == &"front_door_opened":
		_stop_lullaby()

func _on_room_changed(room_id: StringName) -> void:
	if room_id != &"living_room":
		_stop_lullaby()

func _stop_lullaby() -> void:
	if not _lullaby.playing:
		return
	var tween := create_tween()
	tween.tween_property(_lullaby, "volume_db", -40.0, duck_fade)
	tween.tween_callback(_lullaby.stop)
	tween.tween_property(_lullaby, "volume_db", 0.0, 0.0)
	Music.duck(false, duck_fade)

func _exit_tree() -> void:
	if _lullaby and _lullaby.playing:
		Music.duck(false, 0.0)

func open() -> void:
	if GameState.has_flag(unlocked_flag):
		_play_lullaby()
		return
	if _keypad.visible:
		return
	GameState.set_controls_locked(true)
	_keypad.open()
	_leave_prompt.visible = true

func close() -> void:
	if not _keypad.visible:
		return
	_keypad.visible = false
	_leave_prompt.visible = false
	GameState.set_controls_locked(false)

func _unhandled_input(event: InputEvent) -> void:
	if _keypad.visible and event.is_action_pressed("move_backward"):
		close()
		get_viewport().set_input_as_handled()

func _on_unlocked() -> void:
	GameState.set_flag(unlocked_flag)
	await get_tree().create_timer(unlock_pause).timeout
	close()
	_play_lullaby()

func _play_lullaby() -> void:
	if _lullaby.playing:
		return
	Music.duck(true, duck_fade)
	_lullaby.play()

func _on_lullaby_finished() -> void:
	Music.duck(false, duck_fade)
