class_name WindowView
extends Node2D

const DAY_NIGHT := preload("res://resources/day_night_palette.tres")
const WALL_LAYER := 4

@export var sky_gradient: Gradient
@export var day_glow: float = 1.1
@export var night_level: float = 0.22
@export var astral_tint := Color(0.12, 0.4, 0.42)
@export var light_energy: float = 1.0

@onready var sky: CanvasItem = get_node_or_null("Sky")
@onready var window_light: PointLight2D = get_node_or_null("Light")

var _scenery: Array[CanvasItem] = []

func _ready() -> void:
	z_index = -1
	if sky_gradient == null:
		sky_gradient = _default_sky()
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for child in get_children():
		var item := child as CanvasItem
		if item == null or item is Light2D:
			continue
		item.visibility_layer = WALL_LAYER
		item.material = unlit
		if item != sky:
			_scenery.append(item)
		var animated := item as AnimatedSprite2D
		if animated and animated.sprite_frames:
			animated.play()
			animated.frame = randi() % animated.sprite_frames.get_frame_count(animated.animation)

func _default_sky() -> Gradient:
	var night := Color(0.04, 0.06, 0.13)
	var day := Color(0.66, 0.78, 0.88)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.29, 0.4, 0.65, 0.75, 0.79, 1.0])
	gradient.colors = PackedColorArray([night, night, Color(0.93, 0.64, 0.52), day, day, Color(0.9, 0.56, 0.46), night, night])
	return gradient

func _process(_delta: float) -> void:
	var t := GameClock.get_day_fraction()
	var daylight := DAY_NIGHT.sun_energy.sample(t)
	var astral := DayNight.astral_amount
	var outside := sky_gradient.sample(t)
	var sky_color := (outside * lerpf(1.0, day_glow, daylight)).lerp(astral_tint, astral)
	var lit := (Color.WHITE.lerp(outside, 0.35) * lerpf(night_level, day_glow, daylight)).lerp(astral_tint, astral)
	sky_color.a = 1.0
	lit.a = 1.0
	if sky:
		sky.modulate = sky_color
	for item in _scenery:
		item.modulate = lit
	if window_light:
		window_light.color = lit
		window_light.energy = light_energy * daylight * (1.0 - astral)
		window_light.visible = window_light.energy > 0.001
