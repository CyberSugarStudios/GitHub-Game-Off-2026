class_name InteractionRay
extends RayCast3D

@export var max_reach: float = 6.0

var current: Interactable = null

var _last_prompt := ""
var _last_available := false

func _ready() -> void:
	target_position = Vector3(0.0, 0.0, -max_reach)
	collide_with_areas = true
	collide_with_bodies = true

func _physics_process(_delta: float) -> void:
	var found: Interactable = null
	if is_colliding() and not GameState.is_in_room() and not GameState.controls_locked:
		found = get_collider() as Interactable
		if found and global_position.distance_to(get_collision_point()) > found.reach:
			found = null
	if found and not found.is_focusable():
		found = null
	current = found
	if not GameState.is_in_room():
		var parent_target := current as ParentTarget
		Powers.set_target(parent_target.parent_id if parent_target and GameState.in_astral else &"")
	_update_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and current:
		current.try_interact()
		get_viewport().set_input_as_handled()

func _update_prompt() -> void:
	var text := ""
	var available := false
	if current:
		if InteractionRules.realm_matches(current.realm):
			var reason := current.get_block_reason()
			available = reason == ""
			text = current.get_prompt_text() if available else reason
		elif not GameState.in_astral:
			text = current.get_living_label()
		else:
			text = current.get_block_reason()
	if text != _last_prompt or available != _last_available:
		_last_prompt = text
		_last_available = available
		Events.interaction_prompt_changed.emit(text, available)
