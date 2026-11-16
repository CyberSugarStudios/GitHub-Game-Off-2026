class_name RoomActor
extends Node2D

@export var parent_id: StringName = &"leanne"
@export var frames: SpriteFrames
@export var spots: Node2D
@export var height: float = 1500.0
@export var walk_speed: float = 500.0
@export var side_faces_right: bool = false
@export var walk_animation: StringName = &"walk_side"
@export var idle_animation: StringName = &"idle"

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var placeholder: CanvasItem = get_node_or_null("Placeholder")

var _room_id: StringName
var _target := Vector2.ZERO
var _walking := false

func _ready() -> void:
	var node := get_parent()
	while node and not node is Room:
		node = node.get_parent()
	if node:
		_room_id = (node as Room).room_id
	sprite.sprite_frames = frames
	sprite.visible = frames != null
	if placeholder:
		placeholder.visible = frames == null
	_fit_click_areas()
	var click_area := get_node_or_null("ClickArea") as RoomHotspot
	if click_area:
		click_area.interacted.connect(
			func() -> void:
				Powers.set_target(parent_id)
		)
	GameState.parent_location_changed.connect(_on_parent_changed)
	GameState.parent_activity_changed.connect(_on_parent_changed)
	_refresh(false)

func _on_parent_changed(id: StringName, _value: StringName) -> void:
	if id == parent_id:
		_refresh(true)

func _refresh(walk_in: bool) -> void:
	var was_here := visible
	visible = GameState.get_parent_location(parent_id) == _room_id
	if not visible:
		_walking = false
		return
	_target = _spot(GameState.get_parent_activity(parent_id), _spot(&"default", position))
	if not walk_in:
		position = _target
		_walking = false
		_stand()
		return
	if not was_here:
		position = _spot(&"door", position)
	_walking = position.distance_to(_target) > 1.0
	if not _walking:
		_stand()

func _process(delta: float) -> void:
	if not visible or not _walking or GameState.controls_locked:
		return
	var to_target := _target - position
	var step := walk_speed * GameClock.world_speed * delta
	if to_target.length() <= step:
		position = _target
		_walking = false
		_stand()
		return
	position += to_target.normalized() * step
	_animate(walk_animation, to_target.x)

func _stand() -> void:
	var activity := GameState.get_parent_activity(parent_id)
	var anim := activity if frames and frames.has_animation(activity) else idle_animation
	_animate(anim, 0.0)

func _animate(anim: StringName, dx: float) -> void:
	if frames == null or not frames.has_animation(anim):
		return
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)
	sprite.flip_h = (dx > 0.0) != side_faces_right if dx != 0.0 else false
	sprite.speed_scale = GameClock.world_speed
	var texture := frames.get_frame_texture(anim, 0)
	if texture:
		sprite.scale = Vector2.ONE * (height / texture.get_height())
		sprite.position.y = -height * 0.5

func _spot(spot_name: StringName, fallback: Vector2) -> Vector2:
	if spots == null or spot_name == &"":
		return fallback
	var marker := spots.get_node_or_null(NodePath(spot_name)) as Node2D
	if marker == null:
		return fallback
	return (get_parent() as Node2D).to_local(marker.global_position)

func _fit_click_areas() -> void:
	var width := height * 0.35
	for child in get_children():
		var area := child as RoomHotspot
		if area:
			area.set_anchors_preset(Control.PRESET_TOP_LEFT)
			area.position =  Vector2(-width * 0.5, -height)
			area.size = Vector2(width, height)
