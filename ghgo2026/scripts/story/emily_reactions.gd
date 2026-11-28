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
	if GameState.has_flag(once):
		return
	var step := stage
	if kind == &"grabbed" or kind == &"escaped":
		step = 1
		for earlier in range(0, stage):
			if GameState.has_flag(StringName("reacted_creature_%s_stage%d" % [kind, earlier])):
				step += 1
	_say.call_deferred(["creature_%s_stage%d" % [kind, step], "creature_%s" % kind], once)

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
