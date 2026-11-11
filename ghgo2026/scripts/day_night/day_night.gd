class_name DayNight
extends Node

const PALETTE := preload("res://resources/day_night_palette.tres")

@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export var window_material: StandardMaterial3D
@export var max_sun_energy: float = 1.5
@export var max_window_glow: float = 2.0

@export_group("Lamps")
@export var hall_lamps: Array[Light3D] = []
@export var max_lamp_energy: float = 1.2
@export var lamp_color := Color(1.0, 0.851, 0.659)
@export var lamps_in_living_plane: bool = false

@export_group("Astral")
@export var astral_transition_time: float = 0.6
@export var astral_fog_color := Color(0.0, 0.243, 0.322)
@export var astral_fog_density: float = 0.35
@export var astral_lamp_color := Color(0.0, 0.553, 0.71)
@export var astral_lamp_energy: float = 0.8
@export var astral_ambient_energy: float = 0.35
@export var astral_fog_energy: float = 0.5

static var astral_amount := 0.0

var _astral := 0.0

func _ready() -> void:
	_astral = 1.0 if GameState.in_astral else 0.0
	astral_amount = _astral

func _process(delta: float) -> void:
	var target := 1.0 if GameState.in_astral else 0.0
	_astral = move_toward(_astral, target, delta / maxf(astral_transition_time, 0.01))
	astral_amount = _astral
	
	var t := GameClock.get_day_fraction()
	var sky := PALETTE.sky_color.sample(t)
	var daylight := PALETTE.sun_energy.sample(t)
	var living := 1.0 - _astral
	
	if sun:
		sun.light_color = sky
		sun.light_energy = daylight * max_sun_energy * living
	if window_material:
		window_material.emission = sky
		window_material.emission_energy_multiplier = lerpf(0.15, max_window_glow, daylight) * living
	
	if world_environment and world_environment.environment:
		var environment := world_environment.environment
		var night_ambient := PALETTE.ambient_color.sample(0.0)
		environment.ambient_light_color = PALETTE.ambient_color.sample(t).lerp(night_ambient, _astral)
		environment.ambient_light_energy = lerpf(1.0, astral_ambient_energy, _astral)
		environment.fog_enabled = _astral > 0.001
		environment.fog_light_color = astral_fog_color
		environment.fog_light_energy = astral_fog_energy
		environment.fog_density = astral_fog_density * _astral
	
	var living_energy := (1.0 - daylight) * max_lamp_energy if lamps_in_living_plane else 0.0
	var energy := lerpf(living_energy, astral_lamp_energy, _astral)
	var color := lamp_color.lerp(astral_lamp_color, _astral)
	for lamp in hall_lamps:
		if is_instance_valid(lamp):
			lamp.light_energy = energy
			lamp.light_color = color
