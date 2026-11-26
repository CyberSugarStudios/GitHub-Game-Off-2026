class_name DiaryBook
extends CanvasLayer

const LOCKED_LINES := preload("res://dialogue/puzzle_4.dialogue")

@export var pages: DiaryPages
@export var open_event: StringName = &"open_diary"
@export var finished_event: StringName = &"diary_finished"
@export var unlocked_flag: StringName = &"diary_unlocked"
@export var locked_cue: String = "p4_diary_locked"
@export var unlock_pause: float = 0.6
@export var turn_time: float = 0.3
@export var turn_sounds: Array[AudioStream] = [
	preload("res://assets/audio/sfx/varied/paper_1.wav"),
	preload("res://assets/audio/sfx/varied/paper_2.wav"),
	preload("res://assets/audio/sfx/varied/paper_3.wav"),
	preload("res://assets/audio/sfx/varied/paper_4.wav")
]

@onready var book: Control = $Book
@onready var left_page: RichTextLabel = $Book/LeftPage
@onready var right_page: RichTextLabel = $Book/RightPage
@onready var page_number: Label = $Book/PageNumber
@onready var prev_button: Button = $Book/PrevButton
@onready var next_button: Button = $Book/NextButton
#@onready var close_button: TextureRect = $Book/CloseButton
@onready var keypad: DiaryKeypad = $Keypad

var _spread := 0
var _reached_end := false
var _turning := false
var _sound: AudioStreamPlayer

func _ready() -> void:
	visible = false
	Events.story_event.connect(_on_story_event)
	prev_button.pressed.connect(turn.bind(-1))
	next_button.pressed.connect(turn.bind(1))
	#close_button.pressed.connect(close)
	keypad.unlocked.connect(_on_keypad_unlocked)
	keypad.close_requested.connect(close)
	_sound = AudioStreamPlayer.new()
	_sound.bus = &"SFX"
	add_child(_sound)

func _on_story_event(id: StringName) -> void:
	if id == open_event:
		open()

func open() -> void:
	if visible or pages == null or pages.pages.is_empty():
		return
	visible = true
	GameState.set_controls_locked(true)
	if GameState.has_flag(unlocked_flag):
		_show_book()
	else:
		book.visible = false
		keypad.open()

func _show_book() -> void:
	_spread = 0
	keypad.visible = false
	book.visible = true
	left_page.pivot_offset = Vector2(left_page.size.x, 0.0)
	_show_spread()

func _on_keypad_unlocked() -> void:
	GameState.set_flag(unlocked_flag)
	await get_tree().create_timer(unlock_pause).timeout
	if not visible:
		return
	_show_book()
	book.modulate.a = 0.0
	create_tween().tween_property(book, "modulate:a", 1.0, turn_time)

func close() -> void:
	if not visible:
		return
	visible = false
	keypad.visible = false
	GameState.set_controls_locked(false)
	if not GameState.has_flag(unlocked_flag):
		_say_locked()
	elif _reached_end and not GameState.has_flag(finished_event):
		GameState.set_flag(finished_event)
		Events.story_event.emit(finished_event)

func _say_locked() -> void:
	if locked_cue == "" or GameState.has_flag(&"diary_lock_hinted"):
		return
	GameState.set_flag(&"diary_lock_hinted")
	Events.conversation_requested.emit(LOCKED_LINES, locked_cue, false)

func turn(step: int) -> void:
	var next := clampi(_spread + step, 0, _last_spread())
	if next == _spread or _turning:
		return
	_turning = true
	if not turn_sounds.is_empty():
		_play(turn_sounds.pick_random())
	var folding := right_page if step > 0 else left_page
	var unfolding := left_page if step > 0 else  right_page
	var tween := create_tween()
	tween.tween_property(folding, "scale:x", 0.0, turn_time * 0.5).set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN)
	tween.tween_callback(_swap_spread.bind(next, folding, unfolding))
	tween.tween_property(unfolding, "scale:x", 1.0, turn_time * 0.5).set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)
	await tween.finished
	_turning = false

func _swap_spread(next: int, folding: Control, unfolding: Control) -> void:
	_spread = next
	_show_spread()
	folding.scale.x = 1.0
	unfolding.scale.x = 0.0

func _show_spread() -> void:
	left_page.text = _page(_spread * 2)
	right_page.text = _page(_spread * 2 + 1)
	page_number.text = "%d | %d" %[_spread + 1, _last_spread() + 1]
	prev_button.disabled = _spread == 0
	next_button.disabled = _spread == _last_spread()
	if _spread == _last_spread():
		_reached_end = true

func _page(index: int) -> String:
	return pages.pages[index] if index < pages.pages.size() else ""

func _last_spread() -> int:
	return maxi(0, ceili(pages.pages.size() / 2.0) - 1)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or \
	event.is_action_pressed("move_backward"):
		close()
	elif not book.visible:
		return
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		turn(-1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		turn(1)
	else:
		return
	get_viewport().set_input_as_handled()

func _play(stream: AudioStream) -> void:
	if stream:
		_sound.stream = stream
		_sound.pitch_scale = randf_range(0.94, 1.06)
		_sound.play()
