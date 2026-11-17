class_name DoorwayView
extends Node3D

const WINDOW_SHADER := preload("res://shaders/doorway_window.gdshader")

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

@export_group("Depth")
@export var inset: float = 0.0
@export var view_margin: float = 820.0
@export var layer_depths: Dictionary[String, float] = {
	"BackProps": 2.5,
	"Actors": 1.8,
	"FrontProps": 1.1
}
@export_range(0.0, 1.0) var edge_shadow: float = 0.55
@export_range(0.0, 0.5) var edge_width: float = 0.18

@export_group("Performance")
@export var render_distance: float = 12.0

@onready var viewport: SubViewport = $SubViewport
@onready var camera_2d: Camera2D = $SubViewport/Camera2D
@onready var window: MeshInstance3D = $Window

var _room: Room
var _room_size := Vector2.ZERO
var _layer_depth: Dictionary[Node2D, float] = {}
var _layer_base: Dictionary[Node2D, Vector2] = {}

func _ready() -> void:
	viewport.size = Vector2i(opening_size * pixels_per_meter)
	_build_window()
	if room_scene == null:
		push_warning("DoorwayView: no Room Scene set on %s" % get_path())
		return
	_room = room_scene.instantiate() as Room
	viewport.add_child(_room)
	_room_size = _room.get_room_size()
	for layer_name in layer_depths:
		var layer := _room.get_node_or_null(layer_name) as Node2D
		if layer:
			_layer_depth[layer] = layer_depths[layer_name]
			_layer_base[layer] = layer.position
	for node in _room.find_children("*", "CanvasItem", true, false):
		if node.is_in_group("hidden_in_doorway"):
			(node as CanvasItem).visible = false

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
	var distance := maxf(eye.z + inset, min_view_distance)

	var k_shift := room_depth / distance # Always the real distance: sideways parallax.
	var k_zoom := k_shift if depth_zoom else room_depth / reference_distance

	var view_width_m := w * (1.0 + k_zoom)
	var center_x_m := -eye.x * k_shift
	var center_y_m := (h / 2.0) * (1.0 + k_zoom) - eye.y * k_zoom

	var pixels_per_meter_room := _room_size.y / room_height_meters
	var zoom := viewport.size.x / (view_width_m * pixels_per_meter_room)
	var usable_width := maxf(_room_size.x - view_margin * 2.0, 1.0)
	zoom = maxf(zoom, maxf(viewport.size.x / usable_width, viewport.size.y / _room_size.y))

	var half_view := Vector2(viewport.size) / zoom / 2.0
	var target := Vector2(
		_room_size.x * focus + center_x_m * pixels_per_meter_room,
		_room_size.y - center_y_m * pixels_per_meter_room)
	camera_2d.zoom = Vector2(zoom, zoom)
	camera_2d.position = Vector2(
		clampf(target.x, half_view.x, _room_size.x - half_view.x),
		clampf(target.y, half_view.y, _room_size.y - half_view.y))
	var view_left := camera_2d.position.x - half_view.x
	var view_right := camera_2d.position.x + half_view.x
	for layer in _layer_depth:
		var shift := -eye.x * (room_depth - _layer_depth[layer]) / distance * pixels_per_meter_room
		shift = clampf(shift, view_right - (_room_size.x - view_margin), view_left - view_margin)
		layer.position.x = _layer_base[layer].x + shift

func _build_window() -> void:
	var quad := QuadMesh.new()
	quad.size = opening_size
	window.mesh = quad
	window.position = Vector3(0.0, opening_size.y / 2.0, -inset)

	var material := ShaderMaterial.new()
	material.shader = WINDOW_SHADER
	material.set_shader_parameter("room_view", viewport.get_texture())
	material.set_shader_parameter("edge_shadow", edge_shadow)
	material.set_shader_parameter("edge_width", edge_width)
	window.material_override = material

func _exit_tree() -> void:
	window.material_override = null
