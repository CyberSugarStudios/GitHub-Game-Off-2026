class_name PillBar
extends ColorRect

const SHADER := preload("res://shaders/pill_bar_2d.gdshader")
const FILL_TEXTURE := preload("res://assets/textures/astral_door_lock_bar.jpg")

@export_range(0.0, 1.0) var value: float = 1.0:
	set(new_value):
		value = clampf(new_value, 0.0, 1.0)
		if material:
			(material as ShaderMaterial).set_shader_parameter("fill", value)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SHADER
	shader_material.set_shader_parameter("fill_texture", FILL_TEXTURE)
	material = shader_material
	resized.connect(_update_aspect)
	_update_aspect()
	value = value

func _update_aspect() -> void:
	if size.y > 0.0:
		(material as ShaderMaterial).set_shader_parameter("aspect", size.x / size.y)
