class_name RoomHotspot
extends TextureButton

#region - INIT
signal interacted

const SHOW_DEBUG_RECTS := true
#region - EXPORTS
@export var prompt_text: String = "Interact"
@export var realm: InteractionRules.Realm = InteractionRules.Realm.ANY
@export var energy_cost: float = 0.0
@export_range(0, 5) var required_bars: int = 0
@export var one_shot: bool = false
@export var story_id: StringName
#endregion
var _used := false
var _hovered := false
#endregion

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pressed.connect(try_interact)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	GameState.plane_changed.connect(func(_in_astral: bool) -> void: _refresh())
	GameState.energy_changed.connect(func(_energy: float, _max_bars: int) -> void: _refresh())
	_refresh()

func get_block_reason() -> String:
	return InteractionRules.get_block_reason(realm, required_bars, energy_cost)

func try_interact() -> void:
	if GameState.controls_locked:
		return
	if get_block_reason() != "":
		return
	if not InteractionRules.try_pay(energy_cost):
		return
	_used = true
	interacted.emit()
	if story_id != &"":
		Events.story_event.emit(story_id)
	_refresh()

func _refresh() -> void:
	if not is_inside_tree():
		return
	var in_main_view := get_viewport() == get_tree().root
	visible = in_main_view and InteractionRules.realm_matches(realm) and not (one_shot and _used)
	if _hovered:
		if visible:
			_send_prompt()
		else:
			_on_mouse_exited()

func _on_mouse_entered() -> void:
	_hovered = true
	_send_prompt()

func _on_mouse_exited() -> void:
	_hovered = false
	Events.interaction_prompt_changed.emit("", false)

func _send_prompt() -> void:
	var reason := get_block_reason()
	Events.interaction_prompt_changed.emit(prompt_text if reason == "" else reason, reason == "")

func _draw() -> void:
	if SHOW_DEBUG_RECTS and OS.is_debug_build():
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.0, 1.0, 0.25))
