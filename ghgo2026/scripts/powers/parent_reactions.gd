class_name ParentReactions
extends Node

const BARKS := preload("res://dialogue/barks.dialogue")
const THOUGHTS := preload("res://dialogue/thoughts.dialogue")
const HUGS := preload("res://dialogue/puzzle_5.dialogue")
const THOUGHT_BED := preload("res://assets/audio/sfx/varied/thought_bed.wav")
const THOUGHT_BED_DB := -4.0
const THOUGHT_BED_FADE := 0.8

@export var household: Household
@export var chill_destinations: Dictionary[StringName, StringName] = {
	&"leanne": &"linen_closet",
	&"david": &"thermostat"
}
@export var chill_minutes: int = 15
@export var conversation_player: ConversationPlayer

var _bed: AudioStreamPlayer
var _bed_title := ""
var _bed_tween: Tween

func _ready() -> void:
	Events.power_used.connect(_on_power_used)
	Events.conversation_finished.connect(_on_conversation_finished)
	_bed = AudioStreamPlayer.new()
	_bed.stream = THOUGHT_BED
	_bed.bus = &"SFX"
	add_child(_bed)
	if household:
		for parent in household.hall_parents:
			parent.linger_started.connect(_on_linger_started)

func _on_power_used(power_id: StringName, parent_id: StringName) -> void:
	if household and household.get_hall_parent(parent_id) == null:
		return
	match power_id:
		&"read_thought":
			var cue := _thought_cue(parent_id)
			if cue == "":
				push_warning("ParentReactions: no thought written for %s" % parent_id)
				return
			Events.conversation_requested.emit(THOUGHTS, cue, false)
			_start_bed(cue)
		&"chill":
			var bark := "%s_chilled" % parent_id
			if _has_cue(BARKS, bark):
				Events.conversation_requested.emit(BARKS, bark, false)
			var destination: StringName = chill_destinations.get(parent_id, &"")
			if destination != &"" and household:
				household.send(parent_id, destination, chill_minutes)
		&"hug":
			var hug_cue := "hug_%s" % parent_id
			if _has_cue(HUGS, hug_cue):
				Events.conversation_requested.emit(HUGS, hug_cue, false)
			else:
				push_warning("ParentReactions: no hug written for %s" % parent_id)
		_:
			push_warning("ParentReactions: no reaction for power '%s'" % power_id)

func _thought_cue(parent_id: StringName) -> String:
	var general := "thoughts_%s" % parent_id
	var hall_parent := household.get_hall_parent(parent_id) if household else null
	if hall_parent and hall_parent.current_linger:
		var specific := "%s_%s" % [general, hall_parent.current_linger.mark_id]
		if _has_cue(THOUGHTS, specific):
			return specific
	var for_stage := "%s_stage%d" % [general, GameState.story_stage]
	for level in range(GameState.get_hint_level(), -1, -1):
		var hinted := "%s_hint%d" % [for_stage, level]
		if _has_cue(THOUGHTS, hinted):
			return hinted
	if _has_cue(THOUGHTS, for_stage):
		return for_stage
	return general if _has_cue(THOUGHTS, general) else ""

func _on_linger_started(parent_id: StringName, mark_id: StringName) -> void:
	var cue := "%s_linger_%s" % [parent_id, mark_id]
	if not _has_cue(BARKS, cue):
		return
	if conversation_player and conversation_player.is_running():
		return
	Events.conversation_requested.emit(BARKS, cue, false)

func _has_cue(dialogue: DialogueResource, cue: String) -> bool:
	return cue in dialogue.get_cues()

func _start_bed(title: String) -> void:
	_bed_title = title
	if _bed_tween:
		_bed_tween.kill()
	_bed.volume_db = -40.0
	_bed.play()
	_bed_tween = create_tween()
	_bed_tween.tween_property(_bed, "volume_db", THOUGHT_BED_DB, 0.4)

func _process(_delta: float) -> void:
	if _bed_title == "" or not _bed.playing or conversation_player == null:
		return
	if conversation_player.current_title() == _bed_title \
			and conversation_player.line_time_left() <= THOUGHT_BED_FADE:
		_fade_bed()

func _on_conversation_finished(title: String) -> void:
	if title == _bed_title and _bed.playing:
		_fade_bed()

func _fade_bed() -> void:
	_bed_title = ""
	if _bed_tween:
		_bed_tween.kill()
	_bed_tween = create_tween()
	_bed_tween.tween_property(_bed, "volume_db", -40.0, THOUGHT_BED_FADE)
	_bed_tween.tween_callback(_bed.stop)
