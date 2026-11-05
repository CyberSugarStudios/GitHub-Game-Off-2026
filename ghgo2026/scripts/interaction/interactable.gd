class_name Interactable
extends Area3D

signal interacted

enum Realm { ANY, LIVING_ONLY, ASTRAL_ONLY }

@export var prompt_text: String = "Interact"
@export var realm: Realm = Realm.ANY
@export var energy_cost: float = 0.0
@export_range(0, 5) var required_bars: int = 0
@export var one_shot: bool = false
@export var story_id: StringName

var _used := false

func _ready() -> void:
	collision_layer = 0
	set_collision_layer_value(2, true) # Layer 2 = interactable
	collision_mask = 0
	monitoring = false

func is_focusable() -> bool:
	if one_shot and _used:
		return false
	return is_visible_in_tree()

func get_prompt_text() -> String:
	return prompt_text

func get_block_reason() -> String:
	match realm:
		Realm.LIVING_ONLY:
			if GameState.in_astral:
				return "Only in the living world"
		Realm.ASTRAL_ONLY:
			if not GameState.in_astral:
				return "Only in the astral plane"
	if not GameState.has_unlocked_bars(required_bars):
		return "Requires %d bars" % required_bars
	if not GameState.can_afford(energy_cost):
		return "Not enough energy"
	return ""

func try_interact() -> bool:
	if get_block_reason() != "":
		return false
	if energy_cost > 0.0 and not GameState.try_spend(energy_cost):
		return false
	_used = true
	interacted.emit()
	if story_id != &"":
		Events.story_event.emit(story_id)
	_on_interacted()
	return true

func _on_interacted() -> void:
	pass
