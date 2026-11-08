class_name ParentReactions
extends Node

const BARKS := preload("res://dialogue/barks.dialogue")
const THOUGHTS := preload("res://dialogue/thoughts.dialogue")

@export var household: Household
@export var chill_destinations: Dictionary[StringName, StringName] = {
	&"leanne": &"linen_closet",
	&"david": &"thermostat"
}
@export var chill_minutes: int = 15
@export var conversation_player: ConversationPlayer

func _ready() -> void:
	Events.power_used.connect(_on_power_used)
	if household:
		for parent in household.hall_parents:
			parent.linger_started.connect(_on_linger_started)

func _on_power_used(power_id: StringName, parent_id: StringName) -> void:
	match power_id:
		&"read_thought":
			Events.conversation_requested.emit(THOUGHTS, _thought_cue(parent_id), false)
		&"chill":
			Events.conversation_requested.emit(BARKS, "%s_chilled" % parent_id, false)
			var destination: StringName = chill_destinations.get(parent_id, &"")
			if destination != &"" and household:
				household.send(parent_id, destination, chill_minutes)
		_:
			push_warning("ParentReactions: no reaction for power '%s'" % power_id)

func _thought_cue(parent_id: StringName) -> String:
	var general := "thoughts_%s" % parent_id
	var hall_parent := household.get_hall_parent(parent_id) if household else null
	if hall_parent and hall_parent.current_linger:
		var specific := "%s_%s" % [general, hall_parent.current_linger.mark_id]
		if _has_cue(THOUGHTS, specific):
			return specific
	return general

func _on_linger_started(parent_id: StringName, mark_id: StringName) -> void:
	var cue := "%s_linger_%s" % [parent_id, mark_id]
	if not _has_cue(BARKS, cue):
		return
	if conversation_player and conversation_player.is_running():
		return
	Events.conversation_requested.emit(BARKS, cue, false)

func _has_cue(dialogue: DialogueResource, cue: String) -> bool:
	return cue in dialogue.get_cues()
