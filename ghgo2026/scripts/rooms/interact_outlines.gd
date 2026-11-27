class_name InteractOutlines
extends Node2D

const OUTLINE_SHADER := preload("res://shaders/interact_outline.gdshader")
const SHAPE_NAME := "OutlineShape"

class Outline:
	var button: Control
	var source: CanvasItem
	var node: Node2D
	var strength := 0.0

@export var room_view: RoomView
@export var glow_color := Color(0.82, 1.0, 0.95, 0.9)
@export var outline_px: float = 4.0
@export var near_px: float = 24.0
@export var far_px: float = 220.0
@export var fade_speed: float = 6.0

var _room: Room
var _outlines: Array[Outline] = []

func _process(delta: float) -> void:
	var room := room_view.current_room() if room_view else null
	if room != _room:
		_rebuild(room)
	var mouse := get_viewport().get_mouse_position()
	var allowed := room != null and not GameState.controls_locked
	for outline in _outlines:
		if not is_instance_valid(outline.button) or not is_instance_valid(outline.source):
			outline.node.visible = false
			continue
		var target := 0.0
		if allowed and outline.button.is_visible_in_tree() and outline.source.is_visible_in_tree():
			var rect := outline.button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, outline.button.size)
			target = 1.0 - clampf((_distance(rect, mouse) - near_px) / maxf(far_px - near_px, 1.0), 0.0, 1.0)
		outline.strength = move_toward(outline.strength, target, fade_speed * delta)
		outline.node.visible = outline.strength > 0.01
		if outline.node.visible:
			_sync(outline)

func _distance(rect: Rect2, point: Vector2) -> float:
	var dx := maxf(maxf(rect.position.x - point.x, point.x - rect.end.x), 0.0)
	var dy := maxf(maxf(rect.position.y - point.y, point.y - rect.end.y), 0.0)
	return Vector2(dx, dy).length()

func _rebuild(room: Room) -> void:
	for outline in _outlines:
		if is_instance_valid(outline.node):
			outline.node.queue_free()
	_outlines.clear()
	_room = room
	if room == null:
		return
	for node in room.find_children("*", "TextureButton", true, false):
		if node is RoomHotspot:
			_add(node as RoomHotspot)

func _add(hotspot: RoomHotspot) -> void:
	var outline := Outline.new()
	outline.button = hotspot
	var shape := hotspot.get_node_or_null(SHAPE_NAME) as Polygon2D
	var actor := hotspot.get_parent() as RoomActor
	var art: Variant = hotspot.get("art")
	if shape:
		outline.source = shape
		var points := PackedVector2Array()
		for point in shape.polygon:
			points.append(point + shape.offset)
		outline.node = _make_lines(points)
	elif actor and actor.sprite:
		outline.source = actor.sprite
		outline.node = _make_sprite()
	elif art is Sprite2D and (art as Sprite2D).texture and not (art as Sprite2D).region_enabled:
		outline.source = art
		outline.node = _make_sprite()
	else:
		outline.source = hotspot
		var size := hotspot.size
		outline.node = _make_lines(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]))
	outline.node.visible = false
	add_child(outline.node)
	_outlines.append(outline)

func _make_lines(points: PackedVector2Array) -> Node2D:
	var holder := Node2D.new()
	for layer in [[3.0, 0.25], [1.0, 1.0]]:
		var line := Line2D.new()
		line.points = points
		line.closed = true
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.antialiased = true
		line.default_color = Color(glow_color, glow_color.a * float(layer[1]))
		line.set_meta("width_scale", float(layer[0]))
		holder.add_child(line)
	return holder

func _make_sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.region_enabled = true
	var glow_material := ShaderMaterial.new()
	glow_material.shader = OUTLINE_SHADER
	glow_material.set_shader_parameter("glow_color", glow_color)
	sprite.material = glow_material
	return sprite

func _source_texture(source: CanvasItem) -> Texture2D:
	if source is AnimatedSprite2D:
		var animated := source as AnimatedSprite2D
		if animated.sprite_frames == null:
			return null
		return animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
	return (source as Sprite2D).texture

func _sync(outline: Outline) -> void:
	var xform := outline.source.get_global_transform_with_canvas()
	outline.node.transform = xform
	var canvas_scale := maxf(absf(xform.get_scale().x), 0.0001)
	if outline.node is Sprite2D:
		var sprite := outline.node as Sprite2D
		var texture := _source_texture(outline.source)
		if texture == null:
			sprite.visible = false
			return
		var centered: bool = outline.source.get("centered")
		var offset: Vector2 = outline.source.get("offset")
		var radius := outline_px * 2.0 / canvas_scale
		var size := texture.get_size()
		sprite.texture = texture
		sprite.centered = centered
		sprite.flip_h = outline.source.get("flip_h")
		sprite.flip_v = outline.source.get("flip_v")
		sprite.region_rect = Rect2(-radius, -radius, size.x + radius * 2.0, size.y + radius * 2.0)
		sprite.offset = offset - (Vector2.ZERO if centered else Vector2(radius, radius))
		var glow_material := sprite.material as ShaderMaterial
		glow_material.set_shader_parameter("radius", radius)
		glow_material.set_shader_parameter("strength", outline.strength)
	else:
		outline.node.modulate.a = outline.strength
		for line in outline.node.get_children():
			(line as Line2D).width = outline_px * float(line.get_meta("width_scale")) / canvas_scale
