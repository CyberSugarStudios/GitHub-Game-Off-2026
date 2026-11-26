class_name HintBarks
extends Node

const BARKS := preload("res://dialogue/barks.dialogue")
const SOLUTION_POPUP := preload("res://scenes/ui/solution_popup.tscn")

@export var household: Household
@export var conversation_player: ConversationPlayer
@export var every_minutes: int = 30
@export var presses_per_level: int = 3
@export var prompt_label: CanvasItem
@export var prompt_fade: float = 0.4

var _minutes := 0
var _presses := 0
var _shown_level := 1
var _stage := ""
var _popup: SolutionPopup
var _prompt_tween: Tween

func _ready() -> void:
	if not InputMap.has_action(&"hint"):
		InputMap.add_action(&"hint")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_H
		InputMap.action_add_event(&"hint", key)
	GameClock.minute_changed.connect(_on_minute_changed)
	_popup = SOLUTION_POPUP.instantiate() as SolutionPopup
	add_child(_popup)
	if prompt_label:
		prompt_label.modulate.a = 0.0
	_stage = _stage_key()

func _on_minute_changed(_day: int, _minute: int) -> void:
	_check_stage()
	_minutes += 1
	if _minutes < every_minutes:
		return
	_minutes = 0
	if GameState.get_hint_level() <= 0:
		return
	_shown_level = maxi(GameState.get_hint_level(), 1)
	_show_prompt(true)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("hint") or GameState.controls_locked or conversation_player.is_running():
		return
	get_viewport().set_input_as_handled()
	_check_stage()
	_show_prompt(false)
	_presses += 1
	if _presses >= presses_per_level:
		_presses = 0
		if _shown_level >= GameState.MAX_HINT_LEVEL:
			_popup.show_solution("solution_" + _stage_key())
			return
		GameState.raise_hint_level()
	_play_hint()

func _play_hint() -> void:
	var cue := ""
	var can_hear := household.hall_parents.filter(_can_hear)
	if not can_hear.is_empty():
		var parent: HallParent = can_hear.pick_random()
		cue = _hint_cue(parent.parent_id, _shown_level)
	if cue == "":
		cue = _hint_cue(&"emily", _shown_level)
	if cue != "":
		Events.conversation_requested.emit(BARKS, cue, false)

func _check_stage() -> void:
	var key := _stage_key()
	if key == _stage:
		return
	_stage = key
	_presses = 0
	_shown_level = 1
	_show_prompt(false)

func _show_prompt(on: bool) -> void:
	if prompt_label == null:
		return
	if _prompt_tween:
		_prompt_tween.kill()
	_prompt_tween = create_tween()
	_prompt_tween.tween_property(prompt_label, "modulate:a", 1.0 if on else 0.0, prompt_fade)

func _can_hear(parent: HallParent) -> bool:
	if GameState.is_in_room():
		return GameState.get_parent_location(parent.parent_id) == GameState.current_room
	return parent.visible

func _hint_cue(parent_id: StringName, level: int) -> String:
	var cues := BARKS.get_cues()
	var stage := _stage_key()
	for l in range(level, 0, -1):
		var cue := "%s_%s_hint%d" % [parent_id, stage, l]
		if cue in cues:
			return cue
	return ""

func _stage_key() -> String:
	var stage := "stage%d" % GameState.story_stage
	if GameState.hint_step > 0:
		stage += "_step%d" % GameState.hint_step
	return stage
