class_name CupboardKeypad
extends CanvasLayer

const KEY_PROMPT := preload("res://scenes/ui/key_prompt.tscn")
const MUSIC_BOX_VIEW := preload("res://scenes/ui/music_box.tscn")

@export var open_event: StringName = &"tv_cupboard"
@export var code: String = "2184"
@export var caption_text: String = "Locked"
@export var unlocked_flag: StringName = &"tv_cupboard_unlocked"
@export var unlock_pause: float = 0.6

var _keypad: DiaryKeypad
var _leave_prompt: KeyPrompt
var _music_box: MusicBoxView

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
	_music_box = MUSIC_BOX_VIEW.instantiate() as MusicBoxView
	add_child(_music_box)
	Events.story_event.connect(_on_story_event)

func _on_story_event(id: StringName) -> void:
	if id == open_event:
		open()

func open() -> void:
	if GameState.has_flag(unlocked_flag):
		_music_box.open()
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
	_music_box.open()
