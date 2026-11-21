class_name DoorLight
extends Polygon2D

@export var open_event: StringName = &"front_door_opened"
@export var needs_flag: StringName = &"creature_accepted"
@export var bloom_seconds: float = 3.0
@export var bloom_scale := Vector2(18.0, 2.0)

var _room: Room

func _ready() -> void:
	visible = false
	var node := get_parent()
	while node and not node is Room:
		node = node.get_parent()
	_room = node as Room
	Events.story_event.connect(_on_story_event)

func _on_story_event(id: StringName) -> void:
	if id != open_event or not GameState.has_flag(needs_flag):
		return
	visible = true
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "color:a", 1.0, bloom_seconds * 0.3).from(0.0)
	tween.tween_property(self, "scale", bloom_scale, bloom_seconds) \
		.from(Vector2.ONE).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

func _process(_delta: float) -> void:
	if not visible or _room == null:
		return
	var tint := _room.get_tint()
	modulate = Color(
		1.0 / maxf(tint.r, 0.01),
		1.0 / maxf(tint.g, 0.01),
		1.0 / maxf(tint.b, 0.01)
	)
