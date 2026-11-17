@tool
class_name RoomDepth
extends Node2D

@export var room_depth: float = 3.0
@export var room_height: float = 2.6

@onready var top_left: Marker2D = $BackWallTopLeft
@onready var bottom_right: Marker2D = $BackWallBottomRight
@onready var ceiling_left: Marker2D = $CeilingLeft
@onready var ceiling_right: Marker2D = $CeilingRight
@onready var floor_left: Marker2D = $FloorLeft
@onready var floor_right: Marker2D = $FloorRight

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func get_back_wall() -> Rect2:
	return Rect2(position + top_left.position, bottom_right.position - top_left.position)

func get_surfaces() -> Dictionary[StringName, PackedVector2Array]:
	var wall := get_back_wall()
	var tl := wall.position
	var top_right := Vector2(wall.end.x, wall.position.y)
	var br := wall.end
	var bl := Vector2(wall.position.x, wall.end.y)
	var cl := position + ceiling_left.position
	var cr := position + ceiling_right.position
	var fl := position + floor_left.position
	var fr := position + floor_right.position
	return {
		&"back": PackedVector2Array([tl, top_right, br, bl]),
		&"floor": PackedVector2Array([bl, br, fr, fl]),
		&"ceiling": PackedVector2Array([tl, top_right, cr, cl]),
		&"left": PackedVector2Array([tl, cl, fl, bl]),
		&"right": PackedVector2Array([top_right, cr, fr, br]),
	}

static func quad_map(corners: PackedVector2Array) -> Basis:
	var p0 := corners[0]
	var p1 := corners[1]
	var p2 := corners[2]
	var p3 := corners[3]
	var d1 := p1 - p2
	var d2 := p3 - p2
	var d3 := p0 - p1 + p2 - p3
	var den := d1.x * d2.y - d2.x * d1.y
	var g := (d3.x * d2.y - d2.x * d3.y) / den
	var h := (d1.x * d3.y - d3.x * d1.y) / den
	return Basis(
		Vector3(p1.x - p0.x + g * p1.x, p1.y - p0.y + g * p1.y, g),
		Vector3(p3.x - p0.x + h * p3.x, p3.y - p0.y + h * p3.y, h),
		Vector3(p0.x, p0.y, 1.0))

static func apply_map(map: Basis, point: Vector2) -> Vector2:
	var p := map * Vector3(point.x, point.y, 1.0)
	return Vector2(p.x, p.y) / p.z

func _draw() -> void:
	if not Engine.is_editor_hint() or not is_node_ready():
		return
	draw_set_transform(-position)
	var surfaces := get_surfaces()
	for corners in surfaces.values():
		draw_polyline(corners + PackedVector2Array([corners[0]]), Color.CYAN, 4.0)
	var floor_map := quad_map(surfaces[&"floor"])
	for i in range(1, 6):
		var v := i / 6.0
		draw_line(apply_map(floor_map, Vector2(0.0, v)), apply_map(floor_map, Vector2(1.0, v)),
			Color(Color.ORANGE, 0.7), 3.0)
	for marker in [ceiling_left, ceiling_right, floor_left, floor_right]:
		draw_circle(position + marker.position, 20.0, Color.ORANGE)
