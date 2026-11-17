class_name DoorwayView
extends Node3D

const WINDOW_SHADER := preload("res://shaders/doorway_window.gdshader")

@export var room_scene: PackedScene
@export var opening_size := Vector2(1.12, 2.04)
@export var max_view_width: float = 2048.0

@export_group("Shading")
@export_range(0.0, 1.0) var corner_shadow: float = 0.35
@export var corner_width: float = 0.4
@export_range(0.0, 1.0) var ceiling_shade: float = 0.5
@export_range(0.0, 1.0) var edge_shadow: float = 0.55
@export_range(0.0, 0.5) var edge_width: float = 0.18

@export_group("Performance")
@export var render_distance: float = 12.0

@onready var viewport: SubViewport = $SubViewport
@onready var camera_2d: Camera2D = $SubViewport/Camera2D
@onready var window: MeshInstance3D = $Window

var _room: Room
var _material: ShaderMaterial

func _ready() -> void:
	_build_window()
	if room_scene == null:
		push_warning("DoorwayView: no Room Scene set on %s" % get_path())
		return
	_room = room_scene.instantiate() as Room
	viewport.add_child(_room)
	
	var room_size := _room.get_room_size()
	var view_scale := minf(1.0, max_view_width / room_size.x)
	viewport.size = Vector2i((room_size * view_scale).round())
	camera_2d.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	camera_2d.position = Vector2.ZERO
	camera_2d.zoom = Vector2(view_scale, view_scale)
	_fit_box(room_size)

func _process(_delta: float) -> void:
	if _room == null:
		return
	var camera_3d := get_viewport().get_camera_3d()
	var active := camera_3d != null and not GameState.is_in_room() and global_position.distance_to( \
		camera_3d.global_position) < render_distance
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED

func _fit_box(room_size: Vector2) -> void:
	var depth := _room.get_node_or_null("RoomDepth") as RoomDepth
	assert(depth != null, "DoorwayView: %s has not RoomDepth node" % room_scene.resource_path)
	var wall := depth.get_back_wall()
	var vp := depth.get_vanishing_point()
	
	var px_per_meter := wall.size.y / depth.room_height
	var box := Vector3(
		wall.size.x / px_per_meter,
		depth.room_height,
		depth.room_depth
	)
	
	var spread := minf(vp.x / (vp.x - wall.position.x), (room_size.x - vp.x) / (wall.end.x - vp.x))
	var eye := Vector3(
		(vp.x - wall.get_center().x) / px_per_meter,
		(wall.end.y - vp.y) / px_per_meter,
		box.z / maxf(spread - 1.0, 0.05)
	)
	
	_material.set_shader_parameter("box_size", box)
	_material.set_shader_parameter("paint_eye", eye)
	_material.set_shader_parameter("wall_rect", Vector4(
		wall.position.x / room_size.x,
		wall.position.y / room_size.y,
		wall.end.x / room_size.x,
		wall.end.y / room_size.y
	))

func _build_window() -> void:
	var quad := QuadMesh.new()
	quad.size = opening_size
	window.mesh = quad
	window.position = Vector3(0.0, opening_size.y / 2.0, 0.0)
	
	_material = ShaderMaterial.new()
	_material.shader = WINDOW_SHADER
	_material.set_shader_parameter("room_view", viewport.get_texture())
	_material.set_shader_parameter("floor_offset", opening_size.y / 2.0)
	_material.set_shader_parameter("corner_shadow", corner_shadow)
	_material.set_shader_parameter("corner_width", corner_width)
	_material.set_shader_parameter("ceiling_shade", ceiling_shade)
	_material.set_shader_parameter("edge_shadow", edge_shadow)
	_material.set_shader_parameter("edge_width", edge_width)
	window.material_override = _material

func _exit_tree() -> void:
	window.material_override = null
