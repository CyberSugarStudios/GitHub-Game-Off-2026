class_name ParentSprite
extends AnimatedSprite3D

@export var height: float = 1.68
@export_range(10.0, 85.0) var side_angle: float = 60.0
@export var side_faces_right: bool = false
@export var front_animation: StringName = &"walk_front"
@export var side_animation: StringName = &"walk_side"
@export var back_animation: StringName = &"walk_back"
@export var idle_animation: StringName = &"idle"
@export var idle_faces_right: bool = false

@onready var parent := get_parent() as HallParent

var _action: StringName = &""

func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	shaded = true
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	if sprite_frames == null:
		visible = false
		return
	var body := parent.get_node_or_null("Body") as Node3D
	if body:
		body.visible = false
	animation_finished.connect(
		func() -> void:
			_action = &""
	)

func _process(_delta: float) -> void:
	if sprite_frames == null or not is_visible_in_tree() or _action != &"":
		return
	var linger := parent.current_linger
	if linger and sprite_frames.has_animation(linger.linger_activity):
		_play(linger.linger_activity)
		flip_h = _flip_toward(linger.get_look_direction(global_position))
		speed_scale = GameClock.world_speed
		return
	if not parent.is_moving and sprite_frames.has_animation(idle_animation):
		_play(idle_animation)
		var look := parent.standing_at.get_look_direction(global_position) if parent.standing_at \
			else parent.facing
		flip_h = _flip_toward(look)
		speed_scale = GameClock.world_speed
		return
	var settled := not parent.is_walking() or parent.current_linger != null
	if settled and not parent.is_moving and sprite_frames.has_animation(idle_animation):
		_play(idle_animation)
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var to_camera := camera.global_position - global_position
	to_camera.y = 0.0
	to_camera = to_camera.normalized()
	var toward := parent.facing.dot(to_camera)
	var limit := cos(deg_to_rad(side_angle))
	if toward >= limit:
		_play(front_animation)
		flip_h = false
	elif toward <= -limit:
		_play(back_animation)
		flip_h = false
	else:
		_play(side_animation)
		var walks_right := parent.facing.cross(Vector3.UP).dot(to_camera) > 0.0
		flip_h = walks_right != side_faces_right
	speed_scale = GameClock.world_speed * parent.speed_scale if parent.is_moving else 0.0

func play_action(anim: StringName) -> void:
	if sprite_frames == null or not sprite_frames.has_animation(anim):
		return
	_action = anim
	play(anim)
	speed_scale = 1.0
	flip_h = false
	_fit_height(anim)

func _flip_toward(direction: Vector3) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null or direction.length() < 0.001:
		return flip_h
	var looks_screen_right := direction.dot(camera.global_basis.x) > 0.0
	return looks_screen_right != idle_faces_right

func _play(anim: StringName) -> void:
	if animation == anim and is_playing():
		return
	var progress := 0.0
	if sprite_frames.has_animation(animation) and sprite_frames.get_frame_count(animation) > 0:
		progress = float(frame) / sprite_frames.get_frame_count(animation)
	play(anim)
	frame = int(progress * sprite_frames.get_frame_count(anim))
	_fit_height(anim)

func _fit_height(anim: StringName) -> void:
	var texture := sprite_frames.get_frame_texture(anim, 0)
	if texture:
		pixel_size = height / texture.get_height()
		position.y = height * 0.5
