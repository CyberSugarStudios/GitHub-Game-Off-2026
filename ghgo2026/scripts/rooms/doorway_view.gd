class_name DoorwayView
extends Node3D

const WINDOW_SHADER := preload("res://shaders/doorway_window.gdshader")
const CARD_SHADER := preload("res://shaders/doorway_card.gdshader")

const LAYER_SHARED := 1
const LAYER_PROPS := 2
const LAYER_WALLS := 4
const PROP_LAYERS: Array[String] = ["BackProps", "Actors", "FrontProps"]
const WALL_ART: Array[String] = ["Background", "AstralBackground"]

@export var room_scene: PackedScene
@export var opening_size := Vector2(1.12, 2.04)
@export var max_view_width: float = 2048.0

@export_group("Shading")
@export_range(0.0, 1.0) var corner_shadow: float = 0.35
@export var corner_width: float = 0.4
@export_range(0.0, 1.0) var ceiling_shade: float = 0.5
@export_range(0.0, 1.0) var edge_shadow: float = 0.55
@export_range(0.0, 0.5) var edge_width: float = 0.18

@export_group("Props")
@export var min_card_depth: float = 0.15

@export_group("Performance")
@export var render_distance: float = 12.0

@onready var viewport: SubViewport = $SubViewport
@onready var camera_2d: Camera2D = $SubViewport/Camera2D
@onready var window: MeshInstance3D = $Window

var _room: Room
var _material: ShaderMaterial
var _props_viewport: SubViewport
var _card_mesh: QuadMesh
var _cards: Dictionary[CanvasItem, MeshInstance3D] = {}

var _room_size := Vector2.ZERO
var _wall := Rect2()
var _px_per_meter := 1.0
var _box := Vector3.ZERO
var _eye := Vector3.ZERO

func _ready() -> void:
	_build_window()
	if room_scene == null:
		push_warning("DoorwayView: no Room Scene set on %s" % get_path())
		return
	_room = room_scene.instantiate() as Room
	viewport.add_child(_room)

	_room_size = _room.get_room_size()
	var view_scale := minf(1.0, max_view_width / _room_size.x)
	viewport.size = Vector2i((_room_size * view_scale).round())
	camera_2d.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	camera_2d.position = Vector2.ZERO
	camera_2d.zoom = Vector2(view_scale, view_scale)
	_fit_box()
	_split_layers(view_scale)
	_build_cards()

func _process(_delta: float) -> void:
	if _room == null:
		return
	var camera_3d := get_viewport().get_camera_3d()
	var active := camera_3d != null and not GameState.is_in_room() \
			and global_position.distance_to(camera_3d.global_position) < render_distance
	var mode := SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	viewport.render_target_update_mode = mode
	_props_viewport.render_target_update_mode = mode
	if active:
		_update_cards(to_local(camera_3d.global_position))

#region - THE BOX
func _fit_box() -> void:
	var depth := _room.get_node_or_null("RoomDepth") as RoomDepth
	assert(depth != null, "DoorwayView: %s has no RoomDepth node" % room_scene.resource_path)
	_wall = depth.get_back_wall()
	var vp := depth.get_vanishing_point()

	_px_per_meter = _wall.size.y / depth.room_height
	_box = Vector3(_wall.size.x / _px_per_meter, depth.room_height, depth.room_depth)

	var spread := minf(vp.x / (vp.x - _wall.position.x), (_room_size.x - vp.x) / (_wall.end.x - vp.x))
	_eye = Vector3(
		(vp.x - _wall.get_center().x) / _px_per_meter,
		(_wall.end.y - vp.y) / _px_per_meter,
		_box.z / maxf(spread - 1.0, 0.05))

	_material.set_shader_parameter("box_size", _box)
	_material.set_shader_parameter("paint_eye", _eye)
	_material.set_shader_parameter("wall_rect", _to_uv(_wall))

func _split_layers(view_scale: float) -> void:
	for node_name in WALL_ART:
		var art := _room.get_node_or_null(node_name) as CanvasItem
		if art:
			art.visibility_layer = LAYER_WALLS
	for node_name in PROP_LAYERS:
		var layer := _room.get_node_or_null(node_name) as CanvasItem
		if layer:
			layer.visibility_layer = LAYER_PROPS
	viewport.canvas_cull_mask = LAYER_SHARED | LAYER_WALLS

	_props_viewport = SubViewport.new()
	_props_viewport.world_2d = viewport.world_2d
	_props_viewport.transparent_bg = true
	_props_viewport.disable_3d = true
	_props_viewport.size = viewport.size
	_props_viewport.canvas_cull_mask = LAYER_SHARED | LAYER_PROPS
	add_child(_props_viewport)
	_props_viewport.canvas_transform = Transform2D.IDENTITY.scaled(Vector2(view_scale, view_scale))

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
#endregion

#region - PROP CARDS
func _build_cards() -> void:
	_card_mesh = QuadMesh.new()
	_card_mesh.center_offset = Vector3(0.0, 0.5, 0.0)
	for node_name in PROP_LAYERS:
		var layer := _room.get_node_or_null(node_name)
		if layer == null:
			continue
		for child in layer.get_children():
			var art := _art_of(child)
			if art:
				_cards[art] = _make_card()

func _art_of(node: Node) -> CanvasItem:
	if node is Sprite2D or node is AnimatedSprite2D:
		return node as CanvasItem
	var sprite := node.get_node_or_null("Sprite")
	if sprite is Sprite2D or sprite is AnimatedSprite2D:
		return sprite as CanvasItem
	return null

func _make_card() -> MeshInstance3D:
	var card_material := ShaderMaterial.new()
	card_material.shader = CARD_SHADER
	card_material.set_shader_parameter("props_view", _props_viewport.get_texture())
	card_material.set_shader_parameter("to_room", global_transform.affine_inverse())
	var card := MeshInstance3D.new()
	card.mesh = _card_mesh
	card.material_override = card_material
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(card)
	return card

func _update_cards(camera: Vector3) -> void:
	for art in _cards:
		var card := _cards[art]
		card.visible = art.is_visible_in_tree()
		if not card.visible:
			continue
		var rect := _rect_of(art)
		var base := _paint_to_room(Vector2(rect.get_center().x, rect.end.y))
		var size := rect.size * _meters_per_pixel(base)
		card.position = base
		card.rotation.y = atan2(camera.x - base.x, camera.z - base.z)
		card.scale = Vector3(size.x, size.y, 1.0)
		(card.material_override as ShaderMaterial).set_shader_parameter("region", _to_uv(rect))

func _rect_of(art: CanvasItem) -> Rect2:
	var local: Rect2 = (art as Sprite2D).get_rect() if art is Sprite2D else (art as AnimatedSprite2D).get_rect()
	return art.get_global_transform() * local

func _paint_to_room(point: Vector2) -> Vector3:
	var on_wall := Vector3(
		(point.x - _wall.get_center().x) / _px_per_meter,
		(_wall.end.y - point.y) / _px_per_meter,
		-_box.z)
	var spot := on_wall
	if on_wall.y < 0.0:
		spot = _eye + (on_wall - _eye) * (_eye.y / (_eye.y - on_wall.y))
	spot.z = clampf(spot.z, -_box.z + 0.02, -min_card_depth)
	return spot

func _meters_per_pixel(spot: Vector3) -> float:
	return (_eye.z - spot.z) / (_eye.z + _box.z) / _px_per_meter

func _to_uv(rect: Rect2) -> Vector4:
	return Vector4(rect.position.x / _room_size.x, rect.position.y / _room_size.y,
		rect.end.x / _room_size.x, rect.end.y / _room_size.y)
#endregion

func _exit_tree() -> void:
	window.material_override = null
	for card in _cards.values():
		card.material_override = null
