class_name AstralGlow
extends Node

@export var glow_color := Color(1.0, 1.0, 1.0)
@export var glow_energy: float = 1.5
@export var glow_uses_texture: bool = true

var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _original: Material

func _ready() -> void:
	_mesh = get_parent() as MeshInstance3D
	if _mesh == null:
		push_warning("AstralGlow must be a child of a MeshInstance3D: %s" % get_path())
		return
	var source := _mesh.get_active_material(0) as StandardMaterial3D
	if source == null:
		push_warning("AstralGlow: %s has no StandardMaterial3D" % _mesh.name)
		return
	_original = _mesh.get_surface_override_material(0)
	_material = source.duplicate()
	_material.emission_enabled = true
	_material.emission = glow_color
	if _material.emission_texture == null and glow_uses_texture:
		_material.emission_texture = _material.albedo_texture
	_material.emission_energy_multiplier = 0.0
	_mesh.set_surface_override_material(0, _material)

func _process(_delta: float) -> void:
	if _material:
		_material.emission_energy_multiplier = glow_energy * DayNight.astral_amount

func _exit_tree() -> void:
	set_process(false)
	if _mesh and _material and _mesh.get_surface_override_material(0) == _material:
		_mesh.set_surface_override_material(0, _original)
	_material = null
