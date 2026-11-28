class_name WindowView
extends Node2D

const DAY_NIGHT := preload("res://resources/day_night_palette.tres")
const SCENERY_SHADER := preload("res://shaders/window_scenery.gdshader")
const WALL_LAYER := 4

@export var sky_gradient: Gradient
@export var day_glow: float = 1.1
@export var night_level: float = 0.15
@export_range(0.0, 1.0) var sky_tint: float = 0.6
@export var astral_tint := Color(0.12, 0.4, 0.42)
@export var light_energy: float = 1.0

@export_group("Sun")
@export var sun_swing := Vector2(120.0, 90.0)
@export var sun_hours := Vector2(6.25, 18.25)

@onready var sky: CanvasItem = get_node_or_null("Sky")
@onready var window_light: PointLight2D = get_node_or_null("Light")

var _scenery := ShaderMaterial.new()
var _light_home := Vector2.ZERO

func _ready() -> void:
	z_index = -1
	if sky_gradient == null:
		sky_gradient = _default_sky()
	_scenery.shader = SCENERY_SHADER
	_scenery.set_shader_parameter("tint_amount", sky_tint)
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for child in get_children():
		var item := child as CanvasItem
		if item == null or item is Light2D or item is LightOccluder2D or item.name == "Occluders":
			continue
		item.visibility_layer = WALL_LAYER
		item.material = unlit if item == sky else _scenery
		var animated := item as AnimatedSprite2D
		if animated and animated.sprite_frames:
			animated.play()
			animated.frame = randi() % animated.sprite_frames.get_frame_count(animated.animation)
	if window_light:
		_light_home = window_light.position
		window_light.shadow_enabled = true
		window_light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		window_light.shadow_filter_smooth = 3.0

func _default_sky() -> Gradient:
	var night := Color(0.04, 0.06, 0.13)
	var day := Color(0.62, 0.78, 0.95)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.29, 0.4, 0.65, 0.75, 0.79, 1.0])
	gradient.colors = PackedColorArray([night, night, Color(0.95, 0.6, 0.45), day, day, Color(0.95, 0.5, 0.38), night, night])
	return gradient

func _process(_delta: float) -> void:
	var t := GameClock.get_day_fraction()
	var daylight := DAY_NIGHT.sun_energy.sample(t)
	var astral := DayNight.astral_amount
	var outside := sky_gradient.sample(t)
	var hue := outside / maxf(maxf(outside.r, outside.g), maxf(outside.b, 0.001))
	var sky_color := (outside * lerpf(1.0, day_glow, daylight)).lerp(astral_tint, astral)
	var lit := (hue * lerpf(night_level, day_glow, daylight)).lerp(astral_tint * 1.5, astral)
	sky_color.a = 1.0
	if sky:
		sky.modulate = sky_color
	_scenery.set_shader_parameter("light_color", Vector3(lit.r, lit.g, lit.b))
	if window_light:
		window_light.color = Color.WHITE.lerp(hue, 0.4)
		window_light.energy = light_energy * daylight * (1.0 - astral)
		window_light.visible = window_light.energy > 0.001
		var phase := clampf(inverse_lerp(sun_hours.x, sun_hours.y, t * 24.0), 0.0, 1.0)
		window_light.position = _light_home + Vector2(lerpf(-sun_swing.x, sun_swing.x, phase), -sun_swing.y * sin(phase * PI))
