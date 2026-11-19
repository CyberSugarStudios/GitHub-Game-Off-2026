class_name AstralLight2D
extends Light2D

@export var astral_energy: float = 0.3
@export var astral_color := Color(0.45, 0.85, 0.8)

func _ready() -> void:
	color = astral_color
	_apply()

func _process(_delta: float) -> void:
	_apply()

func _apply() -> void:
	energy = astral_energy * DayNight.astral_amount
	visible = energy > 0.001
