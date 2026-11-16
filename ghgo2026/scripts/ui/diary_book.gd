class_name DiaryBook
extends CanvasLayer

@export var pages: DiaryPages
@export var open_event: StringName = &"open_diary"
@export var finished_event: StringName = &"diary_finished"
@export var turn_time: float = 0.3
@export var turn_sound: AudioStream

@onready var book: Control = $Book
@onready var left_page: RichTextLabel = $Book/LeftPage
@onready var right_page: RichTextLabel = $Book/RightPage
@onready var page_number: Label = $Book/PageNumber
@onready var prev_button: Button = $Book/PrevButton
@onready var next_button: Button = $Book/NextButton
@onready var close_button: Button = $Book/CloseButton

var _spread := 0
var _reached_end := false
var _turning := false
var _sound: AudioStreamPlayer

func _ready() -> void:
	visible = false
	Events.story_event.connect(_on_story_event)
	prev_button.pressed.connect(turn.bind(-1))
	next_button.pressed.connect(turn.bind(1))
	close_button.pressed.connect(close)
	_sound = AudioStreamPlayer.new()
	add_child(_sound)

func _on_story_event(id: StringName) -> void:
	if id == open_event:
		open()

func open() -> void:
	if visible or pages == null or pages.pages.is_empty():
		return
	_spread = 0
	visible = true
	GameState.set_controls_locked(true)
	left_page.pivot_offset = Vector2(left_page.size.x, 0.0)
	_show_spread()

func close() -> void:
	if not visible:
		return
	visible = false
	GameState.set_controls_locked(false)
	if _reached_end and not GameState.has_flag(finished_event):
		GameState.set_flag(finished_event)
		Events.story_event.emit(finished_event)

func turn(step: int) -> void:
	var next := clampf(_spread + step, 0, _last_spread())
	if next == _spread or _turning:
		return
	_turning = true
	_play(turn_sound)
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
	page_number.text = "%d / %d" %[_spread + 1, _last_spread() + 1]
	prev_button.disabled = _spread == 0
	next_button.disabled = _last_spread()
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
		_sound.play()
