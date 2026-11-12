class_name Interactable
extends Area3D

signal interacted

@export var prompt_text: String = "Interact"
@export var realm: InteractionRules.Realm = InteractionRules.Realm.ANY
@export var energy_cost: float = 0.0 #energy spent on task, measured in bars (0.25 = 1/4 bar, 0 = free)
@export_range(0, 5) var required_bars: int = 0 
@export var one_shot: bool = false #can only be used once
@export var story_id: StringName
@export var reach: float = 2.0

@export_group("Story")
@export var requires_flag: StringName
@export var hidden_after_flag: StringName

var _used := false

func _ready() -> void:
	collision_layer = 0
	set_collision_layer_value(2, true) # Layer 2 = interactable
	collision_mask = 0
	monitoring = false
	
	GameState.flag_set.connect(
		func(_id: StringName) -> void:
			_refresh_story_gate()
	)

func is_focusable() -> bool:
	if one_shot and _used:
		return false
	return is_story_open() and is_visible_in_tree()

func is_story_open()  -> bool:
	return InteractionRules.story_open(requires_flag, hidden_after_flag)

func _refresh_story_gate() -> void:
	set_collision_layer_value(2, is_story_open())

func get_prompt_text() -> String:
	return prompt_text

func get_block_reason() -> String:
	return InteractionRules.get_block_reason(realm, required_bars, energy_cost)

func get_living_label() -> String:
	return ""

func try_interact() -> bool:
	if get_block_reason() != "":
		return false
	if not InteractionRules.try_pay(energy_cost):
		return false
	_used = true
	interacted.emit()
	if story_id != &"":
		Events.story_event.emit(story_id)
	_on_interacted()
	return true

func _on_interacted() -> void:
	pass
