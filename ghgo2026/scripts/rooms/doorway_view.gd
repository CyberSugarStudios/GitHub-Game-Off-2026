class_name DoorwayView
extends Node3D

const WINDOW_SHADER := preload("res://shaders/doorway_window.gdshader")
const CARD_SHADER := preload("res://shaders/doorway_card.gdshader")
const PLANE_SHADER := preload("res://shaders/doorway_plane.gdshader")
const PLANE_LEFT := "DoorwayLeft"
const PLANE_RIGHT := "DoorwayRight"
const PLANE_MOVE := "DoorwayMove"

const LAYER_SHARED := 1
const LAYER_PROPS := 2
const LAYER_WALLS := 4
const LAYER_LIGHT := 8
const LAYER_ACTORS := 16
const PROP_LAYERS: Array[String] = ["BackProps", "Actors", "FrontProps"]
const FLAT_GROUP := &"doorway_flat"
const BASE_MARKER := "DoorwayBase"
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
@export var props_past_walls: float = 1.0
@export var props_past_floor: float = 20.0
@export var child_plane_offset: float = 0.01

@export_group("Performance")
@export var render_distance: float = 12.0

@onready var viewport: SubViewport = $SubViewport
@onready var camera_2d: Camera2D = $SubViewport/Camera2D
@onready var window: MeshInstance3D = $Window

var _room: Room
var _material: ShaderMaterial
var _props_viewport: SubViewport
var _actors_viewport: SubViewport
var _light_viewport: SubViewport
var _card_mesh: QuadMesh
var _cards: Dictionary[CanvasItem, MeshInstance3D] = {}
var _planes: Dictionary[CanvasItem, MeshInstance3D] = {}

var _room_size := Vector2.ZERO
var _wall := Rect2()
var _px_per_meter := 1.0
var _box := Vector3.ZERO
var _floor_map := Basis()
var _floor_unmap := Basis()
var _supports: Dictionary[CanvasItem, CanvasItem] = {}

func _ready() -> void:
	_build_window()
	if room_scene == null:
		push_warning("DoorwayView: no Room Scene set on %s" % get_path())
		return
	_room = room_scene.instantiate() as Room
	_room.is_preview = true
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
	_actors_viewport.render_target_update_mode = mode
	_light_viewport.render_target_update_mode = mode
	if active:
		_update_cards(to_local(camera_3d.global_position))

#region - THE BOX
func _fit_box() -> void:
	var depth := _room.get_node_or_null("RoomDepth") as RoomDepth
	assert(depth != null, "DoorwayView: %s has no RoomDepth node" % room_scene.resource_path)
	_wall = depth.get_back_wall()
	_px_per_meter = _wall.size.y / depth.room_height
	_box = Vector3(_wall.size.x / _px_per_meter, depth.room_height, depth.room_depth)

	var to_uv := Basis.from_scale(Vector3(1.0 / _room_size.x, 1.0 / _room_size.y, 1.0))
	var surfaces := depth.get_surfaces()
	for surface in surfaces:
		_material.set_shader_parameter("%s_map" % surface, to_uv * RoomDepth.quad_map(surfaces[surface]))
	_material.set_shader_parameter("box_size", _box)
	_floor_map = RoomDepth.quad_map(surfaces[&"floor"])
	_floor_unmap = _floor_map.inverse()

func _split_layers(view_scale: float) -> void:
	for node_name in WALL_ART:
		var art := _room.get_node_or_null(node_name) as CanvasItem
		if art:
			art.visibility_layer = LAYER_WALLS
	for node_name in PROP_LAYERS:
		var layer := _room.get_node_or_null(node_name) as CanvasItem
		if layer == null:
			continue
		var own_layer := LAYER_ACTORS if node_name == "Actors" else LAYER_PROPS
		layer.visibility_layer = own_layer | LAYER_WALLS
		for child in layer.get_children():
			if child is CanvasItem:
				(child as CanvasItem).visibility_layer = LAYER_WALLS if _is_flat(child) else own_layer
	viewport.canvas_cull_mask = LAYER_SHARED | LAYER_WALLS

	_props_viewport = _make_view(LAYER_PROPS, view_scale)
	_actors_viewport = _make_view(LAYER_ACTORS, view_scale)

	var light_sheet := ColorRect.new()
	light_sheet.color = Color.WHITE
	light_sheet.size = _room_size
	light_sheet.z_index = -4096
	light_sheet.visibility_layer = LAYER_LIGHT
	light_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room.add_child(light_sheet)
	_light_viewport = SubViewport.new()
	_light_viewport.world_2d = viewport.world_2d
	_light_viewport.disable_3d = true
	_light_viewport.size = viewport.size
	_light_viewport.canvas_cull_mask = LAYER_SHARED | LAYER_LIGHT
	add_child(_light_viewport)
	_light_viewport.canvas_transform = Transform2D.IDENTITY.scaled(Vector2(view_scale, view_scale))

func _make_view(layer: int, view_scale: float) -> SubViewport:
	var view := SubViewport.new()
	view.world_2d = viewport.world_2d
	view.transparent_bg = true
	view.disable_3d = true
	view.size = viewport.size
	view.canvas_cull_mask = LAYER_SHARED | layer
	add_child(view)
	view.canvas_transform = Transform2D.IDENTITY.scaled(Vector2(view_scale, view_scale))
	return view

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
	_material.set_shader_parameter("past_walls", props_past_walls)
	_material.set_shader_parameter("past_floor", props_past_floor)
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
			if art == null or _is_flat(child):
				continue
			var left := art.get_node_or_null(PLANE_LEFT) as Node2D
			var right := art.get_node_or_null(PLANE_RIGHT) as Node2D
			if left and right and art is Sprite2D:
				var move := art.get_node_or_null(PLANE_MOVE) as Node2D
				for item in [art] + art.find_children("*", "Sprite2D", false, false):
					var plane := _make_plane(item, left.global_position, right.global_position, move)
					if item != art:
						plane.position.z += child_plane_offset
					_planes[item] = plane
			else:
				_cards[art] = _make_card(_actors_viewport if node_name == "Actors" else _props_viewport)
	for art in _cards:
		var support := _find_support(art)
		if support:
			_supports[art] = support

func _art_of(node: Node) -> CanvasItem:
	if node is Sprite2D or node is AnimatedSprite2D:
		return node as CanvasItem
	var sprite := node.get_node_or_null("Sprite")
	if sprite is Sprite2D or sprite is AnimatedSprite2D:
		return sprite as CanvasItem
	return null

func _find_support(art: CanvasItem) -> CanvasItem:
	if _is_actor(art):
		return null
	var base := _base_of(art) - Vector2(0.0, 2.0)
	for other in _cards:
		if other != art and not _is_actor(other) and _rect_of(other).has_point(base) \
			and _base_of(other).y > base.y:
				return other
	return null

func _is_actor(art: CanvasItem) -> bool:
	return art.get_parent() is RoomActor

func _is_flat(node: Node) -> bool:
	return node.is_in_group(FLAT_GROUP)

func _make_card(view: SubViewport) -> MeshInstance3D:
	var card_material := ShaderMaterial.new()
	card_material.shader = CARD_SHADER
	card_material.set_shader_parameter("props_view", view.get_texture())
	card_material.set_shader_parameter("to_room", global_transform.affine_inverse())
	var card := MeshInstance3D.new()
	card.mesh = _card_mesh
	card.material_override = card_material
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(card)
	return card

func _make_plane(art: Sprite2D, left: Vector2, right: Vector2, move: Node2D) -> MeshInstance3D:
	var rect := _rect_of(art)
	var left_v := RoomDepth.apply_map(_floor_unmap, left).y
	var right_v := RoomDepth.apply_map(_floor_unmap, right).y
	var plane_map := _plane_map(left, right, left_v, right_v, 1.0)
	var plane_unmap := plane_map.inverse()
	var lo := Vector2.ZERO
	var hi := Vector2.ONE
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var spot := RoomDepth.apply_map(plane_unmap, corner)
		lo = lo.min(spot)
		hi = hi.max(spot)
	var to_uv := Basis.from_scale(Vector3(1.0 / _room_size.x, 1.0 / _room_size.y, 1.0))
	var plane_material := ShaderMaterial.new()
	plane_material.shader = PLANE_SHADER
	plane_material.set_shader_parameter("art_texture", art.texture)
	plane_material.set_shader_parameter("light_view", _light_viewport.get_texture())
	plane_material.set_shader_parameter("to_room", global_transform.affine_inverse())
	plane_material.set_shader_parameter("art_from_room", _art_from_room(art))
	plane_material.set_shader_parameter("plane_map", to_uv * plane_map)
	var plane := MeshInstance3D.new()
	plane.mesh = _plane_mesh(_floor_point(left), _floor_point(right), lo, hi)
	if move:
		plane.position = _floor_point(move.global_position) - _floor_point(left.lerp(right, 0.5))
	plane.material_override = plane_material
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plane)
	return plane

func _plane_map(left: Vector2, right: Vector2, left_v: float, right_v: float, height: float) -> Basis:
	var left_top := left - Vector2(0.0, height * _px_per_meter_at(left_v))
	var right_top := right - Vector2(0.0, height * _px_per_meter_at(right_v))
	return RoomDepth.quad_map(PackedVector2Array([left_top, right_top, right, left]))

func _floor_point(point: Vector2) -> Vector3:
	var uv := RoomDepth.apply_map(_floor_unmap, point)
	return Vector3((uv.x - 0.5) * _box.x, 0.0, (uv.y - 1.0) * _box.z)

static func _plane_mesh(left: Vector3, right: Vector3, lo: Vector2, hi: Vector2) -> ArrayMesh:
	var corners := PackedVector2Array([lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)])
	var vertices := PackedVector3Array()
	for corner in corners:
		vertices.append(left.lerp(right, corner.x) + Vector3.UP * (1.0 - corner.y))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = corners
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _update_cards(camera: Vector3) -> void:
	for art in _planes:
		var plane := _planes[art]
		plane.visible = art.is_visible_in_tree()
		if plane.visible:
			var plane_material := plane.material_override as ShaderMaterial
			plane_material.set_shader_parameter("tint", art.modulate * art.self_modulate)
			plane_material.set_shader_parameter("art_from_room", _art_from_room(art as Sprite2D))
	for art in _cards:
		var card := _cards[art]
		card.visible = art.is_visible_in_tree()
		if not card.visible:
			continue
		var rect := _rect_of(art)
		var support: CanvasItem = _supports.get(art)
		var marker := art.get_node_or_null(BASE_MARKER) as Node2D
		var ground := _base_of(art)
		if marker:
			ground = marker.global_position
		elif support:
			ground = _base_of(support)
		var depth := _depth_of(ground)
		var base := _stand_at(_base_of(art), depth)
		if support and not marker:
			base += Vector3(camera.x - base.x, 0.0, camera.z - base.z).normalized() * 0.03
		var size := rect.size / _px_per_meter_at(depth)
		card.position = base
		card.rotation.y = atan2(camera.x - base.x, camera.z - base.z)
		card.scale = Vector3(size.x, size.y, 1.0)
		(card.material_override as ShaderMaterial).set_shader_parameter("region", _to_uv(rect))

func _rect_of(art: CanvasItem) -> Rect2:
	var local: Rect2
	if art is Sprite2D:
		local = (art as Sprite2D).get_rect()
	else:
		local = _frame_rect(art as AnimatedSprite2D)
	return art.get_global_transform() * local

func _frame_rect(sprite: AnimatedSprite2D) -> Rect2:
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) \
		if sprite.sprite_frames else null
	var size := texture.get_size() if texture else Vector2.ONE
	var top_left := sprite.offset - (size / 2.0 if sprite.centered else Vector2.ZERO)
	return Rect2(top_left, size)

func _base_of(art: CanvasItem) -> Vector2:
	var rect := _rect_of(art)
	return Vector2(rect.get_center().x, rect.end.y)

func _depth_of(point: Vector2) -> float:
	var v := 0.0
	if point.y > _wall.end.y:
		v = RoomDepth.apply_map(_floor_unmap, point).y
	return clampf(
		v,
		0.02 / _box.z,
		1.0 - min_card_depth / _box.z
	)

func _row(v: float) -> PackedVector2Array:
	return PackedVector2Array([
		RoomDepth.apply_map(_floor_map, Vector2(0.0, v)),
		RoomDepth.apply_map(_floor_map, Vector2(1.0, v))
	])

func _stand_at(point: Vector2, v: float) -> Vector3:
	var row := _row(v)
	var u := inverse_lerp(row[0].x, row[1].x, point.x)
	var floor_y := lerpf(row[0].y, row[1].y, u)
	var lift := maxf(floor_y - point.y, 0.0) / _px_per_meter_at(v)
	return Vector3(
		(u - 0.5) * _box.x,
		lift,
		(v - 1.0) * _box.z
	)

func _px_per_meter_at(v: float) -> float:
	var row := _row(v)
	return (row[1].x - row[0].x) / _box.x

func _art_from_room(art: Sprite2D) -> Basis:
	var rect := art.get_rect()
	var to_texture := Transform2D(Vector2(1.0 / rect.size.x, 0.0), Vector2(0.0, 1.0 / rect.size.y), -rect.position / rect.size)
	var from_uv := Transform2D(Vector2(_room_size.x, 0.0), Vector2(0.0, _room_size.y), Vector2.ZERO)
	var t := to_texture * art.get_global_transform().affine_inverse() * from_uv
	return Basis(Vector3(t.x.x, t.x.y, 0.0), Vector3(t.y.x, t.y.y, 0.0), Vector3(t.origin.x, t.origin.y, 1.0))

func _to_uv(rect: Rect2) -> Vector4:
	return Vector4(rect.position.x / _room_size.x, rect.position.y / _room_size.y,
		rect.end.x / _room_size.x, rect.end.y / _room_size.y)
#endregion

func play_step(stream: AudioStream, room_point: Vector2, volume_db: float) -> void:
	if _room_size == Vector2.ZERO:
		return
	var step := AudioStreamPlayer3D.new()
	step.stream = stream
	step.bus = DoorSound.muffled_bus(false)
	step.volume_db = volume_db
	step.unit_size = 4.0
	step.position = _floor_point(room_point)
	step.finished.connect(step.queue_free)
	add_child(step)
	step.play()

func _exit_tree() -> void:
	window.material_override = null
	for card in _cards.values():
		card.material_override = null
	for plane in _planes.values():
		plane.material_override = null
