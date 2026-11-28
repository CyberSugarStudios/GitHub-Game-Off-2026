class_name WindowView
extends Node2D

const DAY_NIGHT := preload("res://resources/day_night_palette.tres")
const SCENERY_SHADER := preload("res://shaders/window_scenery.gdshader")
const WALL_LAYER := 4
const ACTORS_Z := 20

@export var sky_gradient: Gradient
@export var day_glow: float = 1.1
@export var night_level: float = 0.15
@export_range(0.0, 1.0) var sky_tint: float = 0.6
@export var astral_tint := Color(0.12, 0.4, 0.42)
@export var light_energy: float = 1.0

@export_group("Sun Patch")
@export var pane_mask: Texture2D
@export var patch_energy: float = 1.2
@export var sun_hours := Vector2(6.25, 18.25)
@export var patch_lean: float = 0.9
@export var patch_length := Vector2(0.45, 1.1)
@export var patch_reach: float = 0.0
@export var patch_lights_actors: bool = true

@onready var sky: CanvasItem = get_node_or_null("Sky")
@onready var window_light: PointLight2D = get_node_or_null("Light")

var _scenery := ShaderMaterial.new()
var _patch: PointLight2D
var _center := Vector2.ZERO
var _sill: float = 0.0
var _slope: float = 0.0
var _height: float = 0.0

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
		if item == null or item is Light2D:
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
	if pane_mask:
		_build_patch.call_deferred()

func _build_patch() -> void:
	var room := _find_room()
	var backdrop := get_node_or_null("Backdrop") as Sprite2D
	var mask := pane_mask.get_image()
	if room == null or backdrop == null or mask == null:
		return
	if mask.is_compressed():
		mask.decompress()
	var room_space := room.get_global_transform().affine_inverse()
	var area := room_space * backdrop.get_global_transform() * backdrop.get_rect()
	var px := Vector2(mask.get_size()) / room.get_room_size()
	var region := Rect2i(Rect2(area.position * px, area.size * px)).intersection(Rect2i(Vector2i.ZERO, mask.get_size()))
	var columns := _lit_columns(mask, region)
	if columns.is_empty():
		return
	var lit := Rect2i(columns[0].x, region.end.y, 0, 0)
	for column in columns:
		lit = lit.expand(Vector2i(column.x, column.y)).expand(Vector2i(column.x, column.z))
	lit.size += Vector2i.ONE
	_patch = PointLight2D.new()
	_patch.name = "SunPatch"
	_patch.texture = ImageTexture.create_from_image(mask.get_region(lit))
	_patch.texture_scale = 1.0 / px.x
	if not patch_lights_actors:
		_patch.range_z_max = ACTORS_Z - 1
	var to_local := get_global_transform().affine_inverse() * room.get_global_transform()
	var center_px := Vector2(lit.position) + Vector2(lit.size) * 0.5
	var fit := _fit_sill(columns, center_px.x)
	_center = to_local * (center_px / px)
	_sill = (to_local * (Vector2(center_px.x, fit.x + 1.0) / px)).y
	_slope = fit.y
	_height = _sill - (to_local * (Vector2(lit.position) / px)).y
	add_child(_patch)

func _lit_columns(mask: Image, region: Rect2i) -> Array[Vector3i]:
	var columns: Array[Vector3i] = []
	var tallest := 0
	for x in range(region.position.x, region.end.x):
		var top := -1
		var bottom := -1
		var count := 0
		for y in range(region.position.y, region.end.y):
			if mask.get_pixel(x, y).v >= 0.5:
				if top < 0:
					top = y
				bottom = y
				count += 1
		if count > 0:
			columns.append(Vector3i(x, top, bottom))
			tallest = maxi(tallest, count)
	return columns.filter(func(column: Vector3i) -> bool: return column.z - column.y + 1 >= tallest * 0.25)

func _fit_sill(columns: Array[Vector3i], at_x: float) -> Vector2:
	var n := float(columns.size())
	var sum_x := 0.0
	var sum_y := 0.0
	var sum_xx := 0.0
	var sum_xy := 0.0
	for column in columns:
		sum_x += column.x
		sum_y += column.z
		sum_xx += column.x * column.x
		sum_xy += column.x * column.z
	var spread := n * sum_xx - sum_x * sum_x
	var slope := 0.0 if absf(spread) < 0.001 else (n * sum_xy - sum_x * sum_y) / spread
	var mean_y := sum_y / n
	var mean_x := sum_x / n
	return Vector2(mean_y + slope * (at_x - mean_x), slope)

func _find_room() -> Room:
	var node := get_parent()
	while node and not node is Room:
		node = node.get_parent()
	return node as Room

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
		var lean := lerpf(patch_lean, -patch_lean, phase)
		var length := lerpf(patch_length.x, patch_length.y, low)
		if patch_reach > 0.0 and _height > 0.0:
			length = minf(length, patch_reach / _height)
		var rise := _sill - _center.y
		var x_axis := Vector2(1.0 + _slope * lean, _slope * (1.0 + length))
		_patch.transform = Transform2D(x_axis, Vector2(-lean, -length), Vector2(_center.x + lean * rise, _sill + length * rise))
