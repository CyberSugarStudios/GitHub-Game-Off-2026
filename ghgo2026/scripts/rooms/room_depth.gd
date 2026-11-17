@tool
class_name RoomDepth
extends Node2D

@export var room_depth: float = 3.0
@export var room_height: float = 2.6

@onready var top_left: Marker2D = $BackWallTopLeft
@onready var bottom_right: Marker2D = $BackWallBottomRight
@onready var vanishing_point: Marker2D = $VanishingPoint

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func get_back_wall() -> Rect2:
	return Rect2(position + top_left.position, bottom_right.position - top_left.position)

func get_vanishing_point() -> Vector2:
	return position + vanishing_point.position

func _draw() -> void:
	if not Engine.is_editor_hint() or not is_node_ready():
		return
	var wall := Rect2(top_left.position, bottom_right.position - top_left.position)
	var vp := vanishing_point.position
	draw_rect(wall, Color.CYAN, false, 6.0)
	for corner in [wall.position, Vector2(wall.end.x, wall.position.y), wall.end, \
		Vector2(wall.position.x, wall.end.y)]:
			draw_line(vp, vp + (corner - vp) * 6.0, Color(Color.CYAN), 4.0)
	draw_circle(vp, 20.0, Color.ORANGE)
