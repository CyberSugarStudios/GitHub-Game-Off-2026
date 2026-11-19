class_name StringLights
extends Node2D

@export var on_flag: StringName = &"string_lights_on"
@export var bulb_colors := PackedColorArray([
	Color(1.0, 0.35, 0.55),
	Color(0.35, 0.6, 1.0),
	Color(0.45, 1.0, 0.5),
	Color(1.0, 0.75, 0.3),
	Color(0.75, 0.45, 1.0)
])
@export var bulb_energy: float = 1.2
@export var twinkle := Vector2(0.55, 1.15)
@export var twinkle_speed := Vector2(0.3, 1.5)
@export var glow_strength: float = 0.8
@export var power_on_seconds: float = 1.5

@onready var glow: PointLight2D = $Glow

var _bulbs: Array[PointLight2D] = []
var _phase: Array[float] = []
var _speed: Array[float] = []
var _lit_at: Array[float] = []
var _on_time := -1.0

func _ready() -> void:
	for child in get_children():
		var bulb := child as PointLight2D
		if bulb and bulb != glow:
			_bulbs.append(bulb)
	for i in _bulbs.size():
		_bulbs[i].color = bulb_colors[i % bulb_colors.size()]
		_phase.append(randf() * TAU)
		_speed.append(randf_range(twinkle_speed.x, twinkle_speed.y))
		_lit_at.append(power_on_seconds * i / maxf(_bulbs.size() - 1, 1) + randf() * 0.15)
	if GameState.has_flag(on_flag):
		_on_time = power_on_seconds + 1.0
	_apply(0.0)

func _process(delta: float) -> void:
	if _on_time < 0.0 and GameState.has_flag(on_flag):
		_on_time = 0.0
	if _on_time >= 0.0:
		_on_time += delta
	_apply(delta)

func _apply(delta: float) -> void:
	var color_sum := Color()
	var energy_sum := 0.0
	for i in _bulbs.size():
		var bulb := _bulbs[i]
		var level := 0.0
		var since_lit := _on_time - _lit_at[i]
		if _on_time >= 0.0 and since_lit >= 0.0:
			_phase[i] += delta * _speed[i] * TAU
			level = lerpf(twinkle.x, twinkle.y, 0.5 + 0.5 * sin(_phase[i])) * randf_range(0.94, 1.06)
			if since_lit < 0.3 and randf() < 0.5:
				level = 0.0
		bulb.energy = bulb_energy * level
		bulb.visible = bulb.energy > 0.001
		color_sum += bulb.color * bulb.energy
		energy_sum += bulb.energy
	
	if energy_sum > 0.001:
		glow.color = Color(
			color_sum.r / energy_sum,
			color_sum.g / energy_sum,
			color_sum.b / energy_sum
		)
		glow.energy = glow_strength * energy_sum / maxf(_bulbs.size(), 1)
		glow.visible = glow.energy > 0.001
