class_name DayNight
extends Node

const PALETTE := preload("res://resources/day_night_palette.tres")

@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export var window_material: StandardMaterial3D
@export var max_sun_energy: float = 1.5
@export var max_window_glow: float = 2.0

@export var hall_lamps: Array[Light3D] = []
@export var max_lamp_energy: float = 1.2

func _process(_delta: float) -> void:
	var t := GameClock.get_day_fraction()
	var sky := PALETTE.sky_color.sample(t)
	var daylight := PALETTE.sun_energy.sample(t)
	
	if sun:
		sun.light_color = sky
		sun.light_energy = daylight * max_sun_energy
	if world_environment and world_environment.environment:
		world_environment.environment.ambient_light_color = PALETTE.ambient_color.sample(t)
	if window_material:
		window_material.emission = sky
		window_material.emission_energy_multiplier = lerpf(0.15, max_window_glow, daylight)
	
	var lamp_energy := (1.0 - daylight) * max_lamp_energy
	for lamp in hall_lamps:
		if is_instance_valid(lamp):
			lamp.light_energy = lamp_energy
