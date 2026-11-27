class_name ActivitySwap
extends Node

@export var parent_id: StringName = &"david"
@export var activity: StringName = &"checking_breaker"
@export var actor: RoomActor
@export var shown_during: Array[CanvasItem] = []
@export var hidden_during: Array[CanvasItem] = []

var _room_id: StringName

func _ready() -> void:
	var node := get_parent()
	while node and not node is Room:
		node = node.get_parent()
	if node:
		_room_id = (node as Room).room_id
	GameState.parent_activity_changed.connect(_on_parent_changed)
	GameState.parent_location_changed.connect(_on_parent_changed)
	if actor:
		actor.arrived.connect(_refresh)
	_refresh.call_deferred()

func _on_parent_changed(id: StringName, _value: StringName) -> void:
	if id == parent_id:
		_refresh.call_deferred()

func _refresh() -> void:
	var active := GameState.get_parent_location(parent_id) == _room_id \
		and GameState.get_parent_activity(parent_id) == activity
	if actor:
		active = active and actor.visible and not actor.is_walking()
	for item in shown_during:
		item.visible = active
	for item in hidden_during:
		item.visible = not active
