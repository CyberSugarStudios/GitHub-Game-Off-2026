class_name Room
extends Node2D
# background	= z 0
# back props	= z 10
# actors 		= z 20
# front props	= z 30
# hotspots		= z 40

const DAY_NIGHT := preload("res://resources/day_night_palette.tres")
const PLACEHOLDER_SHADER := preload("res://shaders/placeholder_prop.gdshader")

@export var room_id: StringName

@export_range(0.0, 1.0) var start_pan: float = 0.5
@export var exits_to: StringName

@export_group("Lighting")
@export var keep_dark: bool = false
@export var dark_tint := Color(0.04, 0.04, 0.06)

@onready var background: Sprite2D = $Background

var _night_tint: CanvasModulate
var light_fill := Color(0.0, 0.0, 0.0, 0.0)
var is_preview := false

func _ready() -> void:
	_night_tint = CanvasModulate.new()
	add_child(_night_tint)
	_soften_placeholders()

func _soften_placeholders() -> void:
	var prop_material := ShaderMaterial.new()
	prop_material.shader = PLACEHOLDER_SHADER
	for layer_name in ["BackProps", "FrontProps"]:
		var layer := get_node_or_null(layer_name)
		if layer == null:
			continue
		for node in layer.find_children("*", "Sprite2D", true, false):
			var sprite := node as Sprite2D
			if sprite.material == null and _is_placeholder(sprite.texture):
				sprite.material = prop_material

static func _is_placeholder(texture: Texture2D) -> bool:
	if texture is GradientTexture1D:
		return true
	return texture is CanvasTexture and (texture as CanvasTexture).diffuse_texture == null

func _process(_delta: float) -> void:
	if keep_dark:
		var dark := dark_tint + light_fill
		dark.a = 1.0
		_night_tint.color = dark
		return
	var day := GameClock.get_day_fraction()
	var tint := DAY_NIGHT.room_tint.sample(day).lerp(DAY_NIGHT.room_tint.sample(0.0), DayNight.astral_amount)
	_night_tint.color = Color(
		maxf(tint.r, light_fill.r),
		maxf(tint.g, light_fill.g),
		maxf(tint.b, light_fill.b)
	)

func get_tint() -> Color:
	return _night_tint.color

func get_room_size() -> Vector2:
	return background.get_rect().size * background.scale
