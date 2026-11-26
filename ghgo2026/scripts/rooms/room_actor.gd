class_name RoomActor
extends Node2D

const STEPS: Dictionary[StringName, AudioStream] = {
	&"leanne": preload("res://assets/audio/sfx/footsteps/leanne_steps.tres"),
	&"david": preload("res://assets/audio/sfx/footsteps/david_steps.tres"),
}

@export var parent_id: StringName = &"leanne"
@export var frames: SpriteFrames
@export var spots: Node2D
@export var height: float = 1500.0
@export var walk_speed: float = 500.0
@export var side_faces_right: bool = false
@export var idle_faces_right: bool = false
@export var walk_animation: StringName = &"walk_side"
@export var idle_animation: StringName = &"idle"
@export var step_stride: float = 450.0
@export var step_volume_db: float = -8.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var placeholder: CanvasItem = get_node_or_null("Placeholder")

var _room_id: StringName
var _target := Vector2.ZERO
var _walking := false
var _room: Room
var _steps: AudioStreamPlayer
var _walked := 0.0
var _leanne_frames := preload("res://assets/sprites/Animations/frames/mom/leanne_frames.tres")
var _david_frames := preload("res://assets/sprites/Animations/frames/dad/david_frames.tres")

func _ready() -> void:
	var node := get_parent()
	while node and not node is Room:
		node = node.get_parent()
	if node:
		_room_id = (node as Room).room_id
		_room = node as Room
	if spots == null and node:
		spots = node.get_node_or_null("RoomSpots") as Node2D
	_steps = AudioStreamPlayer.new()
	_steps.stream = STEPS.get(parent_id)
	_steps.bus = &"SFX"
	_steps.volume_db = step_volume_db
	_steps.max_polyphony = 2
	add_child(_steps)
	if parent_id == &"leanne":
		frames = _leanne_frames
	else:
		frames = _david_frames
	sprite.sprite_frames = frames
	sprite.visible = frames != null
	if placeholder:
		placeholder.visible = frames == null
	_fit_click_areas()
	var click_area := get_node_or_null("ClickArea") as RoomHotspot
	if click_area:
		click_area.interacted.connect(
			func() -> void:
				Powers.set_target(parent_id, [], click_area)
		)
	GameState.parent_location_changed.connect(_on_parent_changed)
	GameState.parent_activity_changed.connect(_on_parent_changed)
	Events.time_skipped.connect(_refresh.bind(false))
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
	_walked = step_stride * 0.5
	if not _walking:
		_stand()

func _process(delta: float) -> void:
	if not visible or not _walking:
		return
	var to_target := _target - position
	var step := walk_speed * GameClock.world_speed * delta
	if to_target.length() <= step:
		position = _target
		_walking = false
		_stand()
		return
	position += to_target.normalized() * step
	_count_step(step)
	_animate(walk_animation, (to_target.x > 0.0) != side_faces_right)

func _count_step(distance: float) -> void:
	_walked += distance
	if _walked < step_stride:
		return
	_walked -= step_stride
	if _room == null or _steps.stream == null:
		return
	if not _room.is_preview:
		_steps.play()
	elif not GameState.is_in_room():
		var view := _room.get_parent().get_parent() as DoorwayView
		if view:
			view.play_step(_steps.stream, global_position, step_volume_db)

func _stand() -> void:
	var activity := GameState.get_parent_activity(parent_id)
	var anim := activity if frames and frames.has_animation(activity) else idle_animation
	_animate(anim, _standing_flip(activity))

func _animate(anim: StringName, flip: float) -> void:
	if frames == null:
		return
	if frames.has_animation(anim):
		if sprite.animation != anim or not sprite.is_playing():
			sprite.play(anim)
	elif frames.has_animation(walk_animation):
		anim = walk_animation
		sprite.play(anim)
		sprite.pause()
		sprite.frame = 0
	else:
		return
	sprite.flip_h = flip
	sprite.speed_scale = GameClock.world_speed
	var texture := frames.get_frame_texture(anim, 0)
	if texture:
		sprite.scale = Vector2.ONE * (height / texture.get_height())
		sprite.position.y = -height * 0.5

func _spot_node(spot_name: StringName) -> Node2D:
	if spots == null or spot_name == &"":
		return null
	for child in spots.get_children():
		var spot := child as RoomSpot
		if spot and spot.matches(spot_name):
			return spot
	return spots.get_node_or_null(NodePath(spot_name)) as Node2D

func _spot(spot_name: StringName, fallback: Vector2) -> Vector2:
	var marker := _spot_node(spot_name)
	if marker == null:
		return fallback
	return (get_parent() as Node2D).to_local(marker.global_position)

func _standing_flip(activity: StringName) -> bool:
	var spot := _spot_node(activity)
	if spot == null:
		spot = _spot_node(&"default")
	var facing := (spot as RoomSpot).facing if spot is RoomSpot else RoomSpot.Facing.EITHER
	match facing:
		RoomSpot.Facing.LEFT:
			return idle_faces_right
		RoomSpot.Facing.RIGHT:
			return not idle_faces_right
	return randf() < 0.5

func _fit_click_areas() -> void:
	var width := height * 0.35
	for child in get_children():
		var area := child as RoomHotspot
		if area:
			area.set_anchors_preset(Control.PRESET_TOP_LEFT)
			area.position =  Vector2(-width * 0.5, -height)
			area.size = Vector2(width, height)
