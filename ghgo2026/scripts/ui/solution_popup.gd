class_name SolutionPopup
extends CanvasLayer

const SOLUTIONS := preload("res://dialogue/solutions.dialogue")

@onready var body: RichTextLabel = %Body
@onready var close_button: Button = %CloseButton

var _mouse_before := Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)

func show_solution(cue: String) -> void:
	if visible or not cue in SOLUTIONS.get_cues():
		return
	var lines := PackedStringArray()
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(SOLUTIONS, cue)
	while line:
		lines.append(line.text)
		line = await DialogueManager.get_next_dialogue_line(SOLUTIONS, line.next_id)
	body.text = "\n\n".join(lines)
	visible = true
	GameState.set_controls_locked(true)
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	if not visible:
		return
	visible = false
	GameState.set_controls_locked(false)
	Input.mouse_mode = _mouse_before

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("move_backward") \
			or event.is_action_pressed("hint")):
		close()
		get_viewport().set_input_as_handled()
