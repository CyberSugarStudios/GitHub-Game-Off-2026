class_name InteractionRay
extends RayCast3D

@export var reach: float = 2.0

var current: Interactable = null

var _last_prompt := ""
var _last_available := false

func _ready() -> void:
	target_position = Vector3(0.0, 0.0, -reach)
	collide_with_areas = true
	collide_with_bodies = true

func _physics_process(_delta: float) -> void:
	var found: Interactable = null
	if is_colliding() and not GameState.is_in_room():
		found = get_collider() as Interactable
	if found and not found.is_focusable():
		found = null
	current = found
	_update_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and current:
		current.try_interact()
		get_viewport().set_input_as_handled()

func _update_prompt() -> void:
	var text := ""
	var available := false
	if current:
		var reason := current.get_block_reason()
		available = reason == ""
		text = current.prompt_text if available else reason
	if text != _last_prompt or available != _last_available:
		_last_prompt = text
		_last_available = available
		Events.interaction_prompt_changed.emit(text, available)
