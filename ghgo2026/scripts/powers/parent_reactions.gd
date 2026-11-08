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

func _ready() -> void:
	Events.power_used.connect(_on_power_used)

func _on_power_used(power_id: StringName, parent_id: StringName) -> void:
	match power_id:
		&"read_thought":
			Events.conversation_requested.emit(THOUGHTS, "thoughts_%s" % parent_id, false)
		&"chill":
			Events.conversation_requested.emit(BARKS, "%s_chilled" % parent_id, false)
			var destination: StringName = chill_destinations.get(parent_id, &"")
			if destination != &"" and household:
				household.send(parent_id, destination, chill_minutes)
		_:
			push_warning("ParentReactions: no reaction for power '%s'" % power_id)
