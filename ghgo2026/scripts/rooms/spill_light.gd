class_name SpillLight
extends AreaLight3D

@export var doorway: DoorwayView
@export var brightness: float = 1.5
@export var daylight_strength: float = 1.0
@export var lamp_strength: float = 0.5
@export var full_size_scale: float = 4.0
@export var smoothing: float = 10.0

var _tint: CanvasModulate
var _lights: Array[Light2D] = []

func _ready() -> void:
	light_energy = 0.0
	_find_sources.call_deferred()

func _find_sources() -> void:
	var room := doorway.get_room() if doorway else null
	if room == null:
		push_warning("SpillLight: %s has no doorway room to read." % name)
		return
	for node in room.find_children("*", "CanvasModulate", true, false):
		_tint = node as CanvasModulate
		break
	for node in room.find_children("*", "Light2D", true, false):
		var light := node as Light2D
		if light.blend_mode == Light2D.BLEND_MODE_ADD:
			_lights.append(light)

func _process(delta: float) -> void:
	var total := Color(0.0, 0.0, 0.0)
	if _tint:
		total += _tint.color * daylight_strength
	for light in _lights:
		if is_instance_valid(light) and light.enabled and light.is_visible_in_tree():
			var reach := 1.0
			if light is PointLight2D:
				reach = minf((light as PointLight2D).texture_scale / full_size_scale, 1.0)
			total += light.color * light.energy * reach * lamp_strength
	var peak := maxf(total.r, maxf(total.g, total.b))
	var blend := minf(delta * smoothing, 1.0)
	if peak > 0.0:
		light_color = light_color.lerp(Color(total.r / peak, total.g / peak, total.b / peak), blend)
	light_energy = lerpf(light_energy, peak * brightness, blend)
	visible = light_energy > 0.01
