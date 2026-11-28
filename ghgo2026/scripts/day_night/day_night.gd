class_name DayNight
extends Node

const PALETTE := preload("res://resources/day_night_palette.tres")

@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export var window_material: StandardMaterial3D
@export var max_sun_energy: float = 1.5
@export var max_window_glow: float = 2.0
@export var hall_ambient_energy: float = 0.0

@export_group("Lamps")
@export var hall_lamps: Array[Light3D] = []
@export var max_lamp_energy: float = 1.2
@export var lamp_color := Color(1.0, 0.851, 0.659)
@export var lamps_in_living_plane: bool = false
@export var lamp_hours: Array[Vector2] = [Vector2(5.5, 8.5), Vector2(16.5, 23.5)]
@export_range(0.0, 1.0) var lamp_daylight_cutoff: float = 0.5
@export var lamp_switch_seconds: float = 0.15
@export var lamp_glows: Array[Light3D] = []

@export_group("Astral")
@export var astral_transition_time: float = 0.6
@export var astral_fog_color := Color(0.0, 0.243, 0.322)
@export var astral_fog_density: float = 0.35
@export var astral_lamp_color := Color(0.0, 0.553, 0.71)
@export var astral_lamp_energy: float = 0.8
@export var astral_ambient_energy: float = 0.35
@export var astral_fog_energy: float = 0.5

@export_group("Astral-only Lights")
@export var astral_only_lights: Array[Light3D] = []

static var astral_amount := 0.0
static var lamp_level := 0.0

var _astral := 0.0
var _astral_light_energy: Dictionary[Light3D, float] = {}
var _preview := 0.0
var forced_astral := -1.0
var _glow_energy: Dictionary[Light3D, float] = {}

func _ready() -> void:
	_astral = 1.0 if GameState.in_astral else 0.0
	astral_amount = _astral
	
	for light in astral_only_lights:
		if is_instance_valid(light):
			_astral_light_energy[light] = light.light_energy
	for glow in lamp_glows:
		if is_instance_valid(glow):
			_glow_energy[glow] = glow.light_energy
	
	Events.shift_charge_changed.connect(
		func(amount: float) -> void:
			_preview = amount)

func _process(delta: float) -> void:
	var target := 1.0 if GameState.in_astral else 0.0
	if forced_astral >= 0.0:
		_astral = forced_astral
	else:
		_astral = move_toward(_astral, target, delta / maxf(astral_transition_time, 0.01))
		_astral = maxf(_astral, _preview)
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
		environment.ambient_light_energy = lerpf(hall_ambient_energy, astral_ambient_energy, _astral)
		environment.fog_enabled = _astral > 0.001
		environment.fog_light_color = astral_fog_color
		environment.fog_light_energy = astral_fog_energy
		environment.fog_density = astral_fog_density * _astral
	
	var lamps_on := lamps_in_living_plane and _in_lamp_hours(t * 24.0) and daylight < lamp_daylight_cutoff
	lamp_level = move_toward(lamp_level, 1.0 if lamps_on else 0.0, delta / maxf(lamp_switch_seconds, 0.01))
	var energy := lerpf(lamp_level * max_lamp_energy, astral_lamp_energy, _astral)
	var color := lamp_color.lerp(astral_lamp_color, _astral)
	for lamp in hall_lamps:
		if is_instance_valid(lamp):
			lamp.light_energy = energy
			lamp.light_color = color
			lamp.visible = energy > 0.001
	for glow in lamp_glows:
		if is_instance_valid(glow):
			glow.light_energy = _glow_energy.get(glow, 1.0) * lamp_level * living
			glow.visible = glow.light_energy > 0.001
	for light in astral_only_lights:
		if is_instance_valid(light):
			light.light_energy = _astral_light_energy.get(light, 1.0) * _astral
			light.visible = _astral > 0.001

func _in_lamp_hours(hour: float) -> bool:
	for span in lamp_hours:
		if (span.x <= span.y and hour >= span.x and hour < span.y) \
			or (span.x > span.y and (hour >= span.x or hour < span.y)):
				return true
	return false
