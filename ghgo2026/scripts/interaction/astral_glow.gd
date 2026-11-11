class_name AstralGlow
extends Node

@export var glow_color := Color(1.0, 1.0, 1.0)
@export var glow_energy: float = 1.5
@export var glow_uses_texture: bool = true

var _material: StandardMaterial3D

func _ready() -> void:
	var mesh := get_parent() as MeshInstance3D
	if mesh == null:
		push_warning("AstralGlow must be a child of a MeshInstance3D: %s" % get_path())
		return
	var source := mesh.get_active_material(0) as StandardMaterial3D
	if source == null:
		push_warning("AstralGlow: %s has no StandardMesh3D" % mesh.name)
		return
	_material = source.duplicate()
	
	_material.emission_enabled = true
	_material.emission = glow_color
	if _material.emission_texture == null and glow_uses_texture:
		_material.emission_texture = _material.albedo_texture
	_material.emission_energy_multiplier = 0.0
	mesh.material_override = _material

func _process(_delta: float) -> void:
	if _material:
		_material.emission_energy_multiplier = glow_energy * DayNight.astral_amount
