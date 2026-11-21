extends CanvasLayer

const SHADER := preload("res://shaders/screen_grade.gdshader")

var _rect: ColorRect
var _material: ShaderMaterial

func _ready() -> void:
	layer = 99
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)
	Settings.changed.connect(_apply)
	_apply()

func _apply() -> void:
	_material.set_shader_parameter("brightness", Settings.brightness)
	_material.set_shader_parameter("contrast", Settings.contrast)
	_material.set_shader_parameter("gamma", Settings.gamma)
	_rect.visible = not (is_equal_approx(Settings.brightness, 1.0) \
			and is_equal_approx(Settings.contrast, 1.0) and is_equal_approx(Settings.gamma, 1.0))
