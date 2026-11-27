@tool
class_name OutlineCircle
extends Polygon2D

@export var radius: float = 66.0:
	set(value):
		radius = value
		_build()
@export_range(8, 128) var segments: int = 48:
	set(value):
		segments = value
		_build()

func _ready() -> void:
	_build()

func _build() -> void:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	polygon = points
