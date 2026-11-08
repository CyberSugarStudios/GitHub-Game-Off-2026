class_name ParentTarget
extends Interactable

var parent_id: StringName = &""

func _ready() -> void:
	super()
	realm = InteractionRules.Realm.ASTRAL_ONLY
	var hall_parent := get_parent() as HallParent
	if hall_parent:
		parent_id = hall_parent.parent_id

func get_prompt_text() -> String:
	var power := Powers.get_selected()
	if power == null:
		return "No powers yet"
	return "%s (%s bars)" % [power.display_name, str(power.energy_cost)]

func get_block_reason() -> String:
	var reason := super()
	if reason != "":
		return reason
	var power := Powers.get_selected()
	if power and not GameState.can_afford(power.energy_cost):
		return "Not enough energy for %s" % power.display_name
	return ""

func _on_interacted() -> void:
	Powers.use_selected()
