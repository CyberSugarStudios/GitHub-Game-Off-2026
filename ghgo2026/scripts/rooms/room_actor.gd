class_name RoomActor
extends Node2D

@export var parent_id: StringName = &"leanne"

var _room_id: StringName = &""

func _ready() -> void:
	var node := get_parent()
	while node and not node is Room:
		node = node.get_parent()
	if node:
		_room_id = (node as Room).room_id
	GameState.parent_location_changed.connect(_on_parent_location_changed)
	_refresh()
	
	var click_area := get_node_or_null("ClickArea") as RoomHotspot
	if click_area:
		click_area.interacted.connect(
			func() -> void:
				Powers.set_target(parent_id))

func _on_parent_location_changed(id: StringName, _location: StringName) -> void:
	if id == parent_id:
		_refresh()

func _refresh() -> void:
	visible = GameState.get_parent_location(parent_id) == _room_id
