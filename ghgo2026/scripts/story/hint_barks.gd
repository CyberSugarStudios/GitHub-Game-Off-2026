class_name HintBarks
extends Node

const BARKS := preload("res://dialogue/barks.dialogue")

@export var household: Household
@export var conversation_player: ConversationPlayer
@export var every_minutes: int = 30

var _minutes := 0

func _ready() -> void:
	GameClock.minute_changed.connect(_on_minute_changed)

func _on_minute_changed(_day: int, _minute: int) -> void:
	_minutes += 1
	if _minutes < every_minutes:
		return
	_minutes = 0
	_try_bark()

func _try_bark() -> void:
	var level := GameState.get_hint_level()
	if level <= 0 or GameState.controls_locked or conversation_player.is_running():
		return
	var can_hear := household.hall_parents.filter(_can_hear)
	if can_hear.is_empty():
		return
	var parent: HallParent = can_hear.pick_random()
	var cue := _hint_cue(parent.parent_id, level)
	if cue == "":
		cue = _hint_cue(&"emily", level)
	if cue != "":
		Events.conversation_requested.emit(BARKS, cue, false)

func _can_hear(parent: HallParent) -> bool:
	if GameState.is_in_room():
		return GameState.get_parent_location(parent.parent_id) == GameState.current_room
	return parent.visible

func _hint_cue(parent_id: StringName, level: int) -> String:
	var cues := BARKS.get_cues()
	for l in range(level, 0, -1):
		var cue := "%s_stage%d_hint%d" % [parent_id, GameState.story_stage, l]
		if cue in cues:
			return cue
	return ""
