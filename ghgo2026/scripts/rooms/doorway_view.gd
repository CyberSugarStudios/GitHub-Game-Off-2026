class_name DoorwayView
extends Node3D

@export var room_scene: PackedScene
@export var opening_size := Vector2(1.12, 2.04)
@export var pixels_per_meter: float = 480.0

@export_group("Projection")
@export var room_depth: float = 3.0
@export var room_height_meters: float = 2.6
@export_range(0.0, 1.0) var focus: float = 0.5
@export var depth_zoom: bool = true
@export var reference_distance: float = 2.0
@export var min_view_distance: float = 0.35

@export_group("Performance")
@export var render_distance: float = 12.0

@onready var viewport: SubViewport = $SubViewport
@onready var camera_2d: Camera2D = $SubViewport/Camera2D
@onready var window: MeshInstance3D = $Window

var _room: Room
var _room_size := Vector2.ZERO

func _ready() -> void:
	viewport.size = Vector2i(opening_size * pixels_per_meter)
	_build_window()
	if room_scene == null:
		push_warning("DoorwayView: no Room Scene set on %s" % get_path())
		return
	_room = room_scene.instantiate() as Room
	viewport.add_child(_room)
	_room_size = _room.get_room_size()

func _process(_delta: float) -> void:
	if _room == null:
		return
	var camera_3d := get_viewport().get_camera_3d()
	var active := camera_3d != null and not GameState.is_in_room() \
			and global_position.distance_to(camera_3d.global_position) < render_distance
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if active:
		_project(global_transform.affine_inverse() * camera_3d.global_position)

func _project(eye: Vector3) -> void:
	var w := opening_size.x
	var h := opening_size.y
	var distance := maxf(eye.z, min_view_distance)

	var k_shift := room_depth / distance # Always the real distance: sideways parallax.
	var k_zoom := k_shift if depth_zoom else room_depth / reference_distance

	var view_width_m := w * (1.0 + k_zoom)
	var center_x_m := -eye.x * k_shift
	var center_y_m := (h / 2.0) * (1.0 + k_zoom) - eye.y * k_zoom

	var pixels_per_meter_room := _room_size.y / room_height_meters
	var zoom := viewport.size.x / (view_width_m * pixels_per_meter_room)
	zoom = maxf(zoom, maxf(viewport.size.x / _room_size.x, viewport.size.y / _room_size.y))

	var half_view := Vector2(viewport.size) / zoom / 2.0
	var target := Vector2(
		_room_size.x * focus + center_x_m * pixels_per_meter_room,
		_room_size.y - center_y_m * pixels_per_meter_room)
	camera_2d.zoom = Vector2(zoom, zoom)
	camera_2d.position = Vector2(
		clampf(target.x, half_view.x, _room_size.x - half_view.x),
		clampf(target.y, half_view.y, _room_size.y - half_view.y))

func _build_window() -> void:
	var quad := QuadMesh.new()
	quad.size = opening_size
	window.mesh = quad
	window.position.y = opening_size.y / 2.0

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = viewport.get_texture()
	window.material_override = material
