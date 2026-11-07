class_name Room
extends Node2D
# background	= z 0
# back props	= z 10
# actors 		= z 20
# front props	= z 30
# hotspots		= z 40

const DAY_NIGHT := preload("res://resources/day_night_palette.tres")

@export var room_id: StringName

@export_range(0.0, 1.0) var start_pan: float = 0.5

@onready var background: Sprite2D = $Background

func _process(_delta: float) -> void:
	modulate = DAY_NIGHT.room_tint.sample(GameClock.get_day_fraction())

func get_room_size() -> Vector2:
	return background.get_rect().size * background.scale
