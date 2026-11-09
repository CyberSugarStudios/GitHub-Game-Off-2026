class_name  DoorwayView
extends Node3D

@export var room_scene: PackedScene
@export var opening_size := Vector2(1.05, 2.0)
@export var pixels_per_meter: float = 480.0
@export_range(0.0, 1.0) var focus: float = 0.5
@export var parallax_pixels: float = 700.0
@export var follow_speed: float = 6.0
@export var render_distance: float = 10.0

@onready var viewport: SubViewport = $SubViewport
@onready var camera_2d: Camera2D = $SubViewport/Camera2D
@onready var window: MeshInstance3D = $Window

var _room: Room
var _room_size := Vector2.ZERO
var _view_x := 0.0

func _ready() -> void:
	viewport.size = Vector2i(opening_size * pixels_per_meter)
	_build_window()
	if room_scene == null:
		push_warning("DoorwayView: no Room Scene set on %s" % get_path())
		return
	_room = room_scene.instantiate() as Room
	viewport.add_child(_room)
	_room_size = _room.get_room_size()
	
	var zoom := viewport.size.y / _room_size.y
	camera_2d.zoom = Vector2(zoom, zoom)
	camera_2d.position.y = _room_size.y / 2.0
	_view_x = _room_size.x * focus
	camera_2d.position.x = _view_x

func _process(delta: float) -> void:
	if _room == null:
		return
	var camera_3d := get_viewport().get_camera_3d()
	var active := camera_3d != null and not GameState.is_in_room() and global_position.distance_to(\
		camera_3d.global_position) < render_distance
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if not active:
		return
	
	var local := global_transform.affine_inverse() * camera_3d.global_position
	var lean := clampf(-local.x / maxf(local.z, 0.5), -1.0, 1.0)
	var target := _room_size.x * focus + lean * parallax_pixels
	var half_view := viewport.size.x / camera_2d.zoom.x / 2.0
	target = clampf(target, half_view, _room_size.x - half_view)
	_view_x = lerpf(_view_x, target, 1.0 - exp(-follow_speed * delta))
	camera_2d.position.x = _view_x

func _build_window() -> void:
	var quad := QuadMesh.new()
	quad.size = opening_size
	window.mesh = quad
	window.position.y = opening_size.y / 2.0
	
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = viewport.get_texture()
	window.material_override = material
