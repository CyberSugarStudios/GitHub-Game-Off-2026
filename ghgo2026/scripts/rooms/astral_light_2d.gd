class_name AstralLight2D
extends Light2D

const DAY_NIGHT := preload("res://resources/day_night_palette.tres")

@export var day_energy: float = 0.8
@export var night_energy: float = 0.3
@export var astral_color := Color(0.45, 0.85, 0.8)

func _ready() -> void:
	color = astral_color
	_apply()

func _process(_delta: float) -> void:
	_apply()

func _apply() -> void:
	var daylight := DAY_NIGHT.sun_energy.sample(GameClock.get_day_fraction())
	energy = lerpf(night_energy, day_energy, daylight) * DayNight.astral_amount
	visible = energy > 0.001
