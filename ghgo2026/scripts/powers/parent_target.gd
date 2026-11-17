class_name ParentTarget
extends PowerTarget

@export_group("Talk (living plane)") # INTRO only
@export var talk_prompt: String = "Talk to mom"
@export var talk_story_id: StringName = &"talk_to_mom"
@export var talk_requires_flag: StringName = &"leanne_home"
@export var talk_hidden_after_flag: StringName = &"mom_ignored"

func _ready() -> void:
	super()
	realm = InteractionRules.Realm.ANY
	var hall_parent := get_parent() as HallParent
	if hall_parent:
		target_id = hall_parent.parent_id

func is_focusable() -> bool:
	if not GameState.in_astral and not _talking():
		return false
	return super()

func get_prompt_text() -> String:
	return talk_prompt if _talking() else super()

func get_block_reason() -> String:
	return "" if _talking() else super()

func _on_interacted() -> void:
	if _talking():
		Events.story_event.emit(talk_story_id)
	else:
		super()

func _talking() -> bool:
	return not GameState.in_astral and talk_prompt != "" and InteractionRules.story_open(talk_requires_flag, \
		talk_hidden_after_flag)
