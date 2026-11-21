class_name StringLights
extends Node2D

const LIGHT_LIMIT := 16
const SPUTTER_HZ := 2.5
const DAY_NIGHT := preload("res://resources/day_night_palette.tres")

@export var on_flag: StringName = &"string_lights_on"
@export var bulb_colors := PackedColorArray([
	Color(1.0, 0.35, 0.55),
	Color(0.35, 0.6, 1.0),
	Color(0.45, 1.0, 0.5),
	Color(1.0, 0.75, 0.3),
	Color(0.75, 0.45, 1.0)
])
@export var bulb_energy: float = 1.2
@export var bulb_size: float = 0.1

@export_group("Rotation")
@export var lit_at_once: int = 10
@export var swap_every := Vector2(2.5, 5.0)
@export var ripple_seconds: float = 1.2
@export var fade_seconds: float = 0.25
@export var power_on_seconds: float = 1.5

@export_group("Twinkle")
@export var twinkle := Vector2(0.55, 1.15)
@export var twinkle_speed := Vector2(0.3, 1.5)

@export_group("Room Glow")
@export var glow_strength: float = 0.1
@export var room_fill: float = 0.035
@export_range(0.0, 1.0) var day_strength: float = 0.15

@onready var glow: PointLight2D = $Glow

var _bulbs: Array[PointLight2D] = []
var _level: Array[float] = []
var _target: Array[float] = []
var _phase: Array[float] = []
var _speed: Array[float] = []
var _on_time := 0.0
var _step := 1
var _slots := 0
var _offset := -1
var _next_offset := -1
var _handed := 0
var _ripple_clock := 0.0
var _ripple_length := 0.0
var _wait := 0.0
var _powering_on := false
var _room: Room

func _ready() -> void:
	var node := get_parent()
	while node and not node is Room:
		node = node.get_parent()
	_room = node as Room
	for child in get_children():
		var bulb := child as PointLight2D
		if bulb and bulb != glow:
			_bulbs.append(bulb)
	if _bulbs.is_empty():
		set_process(false)
		return
	_step = maxi(1, ceili(float(_bulbs.size()) / lit_at_once))
	_slots = ceili(float(_bulbs.size()) / _step)
	for i in _bulbs.size():
		_bulbs[i].color = bulb_colors[i % bulb_colors.size()]
		_bulbs[i].texture_scale = bulb_size
		_level.append(0.0)
		_target.append(0.0)
		_phase.append(randf() * TAU)
		_speed.append(randf_range(twinkle_speed.x, twinkle_speed.y))
	_check_budget()
	if GameState.has_flag(on_flag):
		_start_swap(0.0)
	_apply(0.0)

func _process(delta: float) -> void:
	if _offset < 0 and _next_offset < 0 and GameState.has_flag(on_flag):
		_start_swap(power_on_seconds)
		_powering_on = true
		_on_time = 0.0
	if _powering_on:
		_on_time += delta
	if _next_offset >= 0:
		_ripple(delta)
	elif _offset >= 0:
		_wait -= delta
		if _wait <= 0.0:
			_start_swap(ripple_seconds)
	_apply(delta)

#region - ROTATION
func _start_swap(ripple: float) -> void:
	_next_offset = randi() % _step
	if _step > 1 and _next_offset == _offset:
		_next_offset = (_next_offset + 1 + randi() % (_step - 1)) % _step
	_handed = 0
	_ripple_clock = 0.0
	_ripple_length = ripple

func _ripple(delta: float) -> void:
	_ripple_clock += delta
	var stagger := _ripple_length / _slots
	while _handed < _slots and _ripple_clock >= _handed * stagger:
		if _offset >= 0:
			_set_target(_offset + _handed * _step, 0.0)
		_set_target(_next_offset + _handed * _step, 1.0)
		_handed += 1
	if _handed >= _slots:
		_offset = _next_offset
		_next_offset = -1
		_powering_on = false
		_wait = randf_range(swap_every.x, swap_every.y)

func _set_target(index: int, value: float) -> void:
	if index >= 0 and index < _bulbs.size():
		_target[index] = value

func _check_budget() -> void:
	var stagger := ripple_seconds / _slots
	var peak := _slots + ceili(fade_seconds / maxf(stagger, 0.001)) + 1
	if peak > LIGHT_LIMIT - 1:
		push_warning("StringLights: up to %d lights at once, over the limit. Lower Lit At Once or Fade Seconds, or raise Ripple Seconds." % peak)
#endregion

#region - LIGHT
func _apply(delta: float) -> void:
	var color_sum := Color(0.0, 0.0, 0.0, 0.0)
	var energy_sum := 0.0
	for i in _bulbs.size():
		_level[i] = move_toward(_level[i], _target[i], delta / maxf(fade_seconds, 0.01))
		var brightness := 0.0
		if _level[i] > 0.0:
			_phase[i] += delta * _speed[i] * TAU
			brightness = _level[i] * lerpf(twinkle.x, twinkle.y, 0.5 + 0.5 * sin(_phase[i]))
			if not Settings.reduce_flashing:
				brightness *= randf_range(0.97, 1.03)
				if _powering_on:
					var depth := 0.45 * (1.0 - clampf(_on_time / power_on_seconds, 0.0, 1.0))
					brightness *= 1.0 - depth + depth * sin(_on_time * TAU * SPUTTER_HZ)
		var bulb := _bulbs[i]
		bulb.energy = bulb_energy * brightness
		bulb.enabled = bulb.energy > 0.001
		bulb.visible = bulb.enabled
		color_sum += bulb.color * bulb.energy
		energy_sum += bulb.energy

	if energy_sum > 0.001:
		glow.color = Color(
			color_sum.r / energy_sum,
			color_sum.g / energy_sum,
			color_sum.b / energy_sum
		)
	var daylight := DAY_NIGHT.sun_energy.sample(GameClock.get_day_fraction())
	var wash := energy_sum * lerpf(1.0, day_strength, daylight)
	glow.energy = glow_strength * wash
	glow.visible = glow.energy > 0.001
	
	if _room:
		_room.light_fill = glow.color * (room_fill * wash)
#endregion
