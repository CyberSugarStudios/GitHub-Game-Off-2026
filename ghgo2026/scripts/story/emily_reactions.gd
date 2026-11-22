class_name EmilyReactions
extends Node

const REACTIONS := preload("res://dialogue/reactions.dialogue")

@export var conversation_player: ConversationPlayer

func _ready() -> void:
	Events.near_missed.connect(_on_near_missed)
	Events.creature_moment.connect(_on_creature_moment)
	Events.conversation_finished.connect(_on_conversation_finished)

func _on_near_missed(source: StringName) -> void:
	if source == &"":
		return
	var stage := GameState.story_stage
	_say.call_deferred(["near_miss_%s_stage%d" % [source, stage], "near_miss_%s" % source, "near_miss"])

func _on_creature_moment(kind: StringName) -> void:
	var stage := GameState.story_stage
	var once := StringName("reacted_creature_%s_stage%d" % [kind, stage])
	if not GameState.has_flag(once):
		_say.call_deferred(["creature_%s_stage%d" % [kind, stage], "creature_%s" % kind], once)

func _on_conversation_finished(title: String) -> void:
	if title.begins_with("thoughts_") and not GameState.has_flag(&"reacted_read_thoughts"):
		_say.call_deferred(["read_thoughts_first"], &"reacted_read_thoughts")

func _say(cues: Array, once: StringName = &"") -> void:
	if conversation_player.is_running():
		return
	var written := REACTIONS.get_cues()
	for cue in cues:
		if cue in written:
			if once != &"":
				GameState.set_flag(once)
			Events.conversation_requested.emit(REACTIONS, cue, false)
			return
