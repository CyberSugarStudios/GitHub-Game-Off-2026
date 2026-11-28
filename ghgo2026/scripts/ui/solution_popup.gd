class_name SolutionPopup
extends CanvasLayer

const SOLUTIONS := preload("res://dialogue/solutions.dialogue")

@export var ask_title: String = "Stuck?"
@export var ask_text: String = "Want to see how to solve this part? It will spoil the puzzle."
@export var answer_title: String = "Here's what to do..."

@onready var title: Label = $Panel/MarginContainer/VBoxContainer/Title
@onready var body: RichTextLabel = %Body
@onready var close_button: BaseButton = %CloseButton

var _mouse_before := Input.MOUSE_MODE_VISIBLE
var _reveal_button: BaseButton
var _answer := ""
var _asking := false

func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)
	_reveal_button = close_button.duplicate() as BaseButton
	close_button.add_sibling(_reveal_button)
	close_button.get_parent().move_child(_reveal_button, close_button.get_index())
	_reveal_button.set("text", "SHOW SOLUTION")
	_reveal_button.pressed.connect(_reveal)

func show_solution(cue: String) -> void:
	if visible or not cue in SOLUTIONS.get_cues():
		return
	var lines := PackedStringArray()
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(SOLUTIONS, cue)
	while line:
		lines.append(line.text)
		line = await DialogueManager.get_next_dialogue_line(SOLUTIONS, line.next_id)
	_answer = "\n\n".join(lines)
	_asking = true
	title.text = ask_title
	body.text = ask_text
	_reveal_button.visible = true
	close_button.set("text", "NOT YET")
	visible = true
	GameState.set_controls_locked(true)
	GameState.overlay_open = true
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _reveal() -> void:
	_asking = false
	title.text = answer_title
	body.text = _answer
	_reveal_button.visible = false
	close_button.set("text", "CLOSE")

func close() -> void:
	if not visible:
		return
	visible = false
	GameState.set_controls_locked(false)
	Input.mouse_mode = _mouse_before
	GameState.overlay_open = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _asking and event.is_action_pressed("hint"):
		_reveal()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("move_backward") \
			or event.is_action_pressed("hint"):
		close()
		get_viewport().set_input_as_handled()
