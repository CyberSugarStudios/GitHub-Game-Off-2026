class_name AstralLight2D
extends Light2D

@export var astral_energy: float = 2.0

var _full_energy := 0.0

func _ready() -> void:
	_full_energy = energy
	_apply()

func _process(_delta: float) -> void:
	_apply()

func _apply() -> void:
	energy = astral_energy * DayNight.astral_amount
	visible = energy > 0.001
