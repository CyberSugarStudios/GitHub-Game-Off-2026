class_name WindowView
extends Node2D

const DAY_NIGHT := preload("res://resources/day_night_palette.tres")
const SCENERY_SHADER := preload("res://shaders/window_scenery.gdshader")
const WALL_LAYER := 4
const MASK_WIDTH := 96

@export var sky_gradient: Gradient
@export var day_glow: float = 1.1
@export var night_level: float = 0.15
@export_range(0.0, 1.0) var sky_tint: float = 0.6
@export var astral_tint := Color(0.12, 0.4, 0.42)
@export var light_energy: float = 1.0

@export_group("Sun Patch")
@export var patch_energy: float = 1.2
@export var sun_hours := Vector2(6.25, 18.25)
@export var patch_swing: float = 200.0
@export var patch_drop := Vector2(260.0, 420.0)
@export var patch_squash := Vector2(0.45, 0.75)
@export var patch_skew_degrees: float = 25.0

@onready var sky: CanvasItem = get_node_or_null("Sky")
@onready var window_light: PointLight2D = get_node_or_null("Light")

var _scenery := ShaderMaterial.new()
var _patch: PointLight2D
var _patch_home := Vector2.ZERO

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
		if item == null or item is Light2D or item.name == "Panes":
			continue
		item.visibility_layer = WALL_LAYER
		var look: Material = _scenery
		if item == sky:
			look = unlit
		item.material = look
		var animated := item as AnimatedSprite2D
		if animated and animated.sprite_frames:
			animated.play()
			animated.frame = randi() % animated.sprite_frames.get_frame_count(animated.animation)
	var panes := get_node_or_null("Panes") as CanvasItem
	if panes:
		panes.visible = false
		_build_patch(panes)

func _build_patch(panes: Node) -> void:
	var polygons: Array[PackedVector2Array] = []
	var bounds := Rect2()
	var started := false
	for child in panes.get_children():
		var pane := child as Polygon2D
		if pane == null or pane.polygon.is_empty():
			continue
		var points := PackedVector2Array()
		for point in pane.polygon:
			points.append(pane.transform * (point + pane.offset))
		polygons.append(points)
		for point in points:
			if started:
				bounds = bounds.expand(point)
			else:
				bounds = Rect2(point, Vector2.ZERO)
				started = true
	if polygons.is_empty() or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var width := MASK_WIDTH
	var height := maxi(int(round(MASK_WIDTH * bounds.size.y / bounds.size.x)), 1)
	var mask := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var at := bounds.position + Vector2(x + 0.5, y + 0.5) * bounds.size / Vector2(width, height)
			for points in polygons:
				if Geometry2D.is_point_in_polygon(at, points):
					mask.set_pixel(x, y, Color.WHITE)
					break
	_patch = PointLight2D.new()
	_patch.name = "SunPatch"
	_patch.texture = ImageTexture.create_from_image(mask)
	_patch.texture_scale = bounds.size.x / width
	_patch_home = bounds.get_center()
	_patch.position = _patch_home
	add_child(_patch)

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
	var sunlight := Color.WHITE.lerp(hue, 0.4)
	if window_light:
		window_light.color = sunlight
		window_light.energy = light_energy * daylight * (1.0 - astral)
		window_light.visible = window_light.energy > 0.001
	if _patch:
		var phase := clampf(inverse_lerp(sun_hours.x, sun_hours.y, t * 24.0), 0.0, 1.0)
		var low := 1.0 - sin(phase * PI)
		_patch.color = sunlight
		_patch.energy = patch_energy * daylight * (1.0 - astral)
		_patch.visible = _patch.energy > 0.001
		_patch.position = _patch_home + Vector2(lerpf(patch_swing, -patch_swing, phase), lerpf(patch_drop.x, patch_drop.y, low))
		_patch.scale = Vector2(1.0, lerpf(patch_squash.x, patch_squash.y, low))
		_patch.skew = deg_to_rad(lerpf(-patch_skew_degrees, patch_skew_degrees, phase))
