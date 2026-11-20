class_name Creature
extends Node3D

#region - INIT
enum State { HIDDEN, LURKING, HUNTING, GRABBING, GUARDING }

const WORLD_LAYER := 1
const EYE_HEIGHT := 1.4
#region - EXPORTS
@export var player: Player
@export var spots: Node
@export var respawn_spot: Node3D
@export var fade: ColorRect

@export_group("Lurking")
@export var lurk_interval := Vector2(20.0, 45.0)
@export var lurk_seconds := Vector2(6.0, 12.0)
@export var lurk_min_distance: float = 4.0
@export var lurk_max_distance: float = 14.0
@export var lurk_vanish_distance: float = 3.0
@export var stare_seconds: float = 0.4

@export_group("Hunting")
@export var hunt_delay := Vector2(3.0, 6.0)
@export var hunt_spawn_min_distance: float = 8.0
@export var hunt_speed: float = 3.0
@export var presence_radius: float = 4.0
@export var presence_drain_per_second: float = 0.13
@export var grab_distance: float = 0.9

@export_group("Struggle")
@export var struggle_presses: int = 12
@export var presses_per_bar: int = 4
@export var grab_drain_per_second: float = 0.25
@export var escape_cooldown: float = 20.0
@export var grab_look_height: float = 1.3

@export_group("Guarding")
@export var guard_spot: Node3D
@export var guard_room: StringName = &"emily_bedroom"
@export var guard_radius: float = 6.0
@export var guard_charge_distance: float = 5.0
@export var guard_return_delay: float = 8.0
@export var guard_exit_grace: float = 2.5

@export_group("Art")
@export var size_scale: float = 0.8
@export var animation_fit: Dictionary[StringName, Vector2] = {
	&"idle": Vector2(2.1, 0.0),
	&"chase_start": Vector2(2.13, 0.0),
	&"chase_loop": Vector2(2.13, 0.0),
	&"grab": Vector2(3.68, 0.98),
}

@export_group("Grab Overlay")
@export var grab_screen_height: float = 1.6
@export var grab_face := Vector2(0.505, 0.11)

@export_group("Sounds")
@export var sting_sound: AudioStream
@export var grab_sound: AudioStream
@export var free_sound: AudioStream
@export var consume_sound: AudioStream
#endregion
#region - ONREADY
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var presence: AudioStreamPlayer3D = $Presence
@onready var stinger: AudioStreamPlayer = $Stinger
@onready var sprite: AnimatedSprite3D = get_node_or_null("Sprite")
@onready var grab_overlay: CanvasLayer = get_node_or_null("GrabOverlay")
@onready var grab_sprite: AnimatedSprite2D = get_node_or_null("GrabOverlay/GrabSprite")
#endregion
var _state := State.HIDDEN
var _timer := 0.0
var _stared := 0.0
var _presses := 0
var _repath := 0.0
var _grace := 0.0
#endregion

func _ready() -> void:
	visible = false
	add_to_group("astral_visibility")
	GameState.plane_changed.connect(_on_plane_changed)
	GameState.monster_level_changed.connect(_on_monster_level_changed)
	Events.door_opened.connect(_on_door_opened)
	Events.returned_to_hall.connect(_on_returned_to_hall)
	agent.path_desired_distance = 0.25
	agent.target_desired_distance = grab_distance * 0.5
	_timer = _lurk_delay()
	if sprite:
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		sprite.animation_finished.connect(
			func() -> void:
				if sprite.animation == &"chase_start":
					_animate(&"chase_loop"))

func set_warmup(on: bool) -> void:
	visible = on

#region - STATES
func _physics_process(delta: float) -> void:
	if _state == State.GRABBING:
		_process_grab(delta)
		return
	if GameState.monster_level <= 0 or GameState.monster_level >= 5 or GameState.controls_locked:
		return
	if GameState.is_in_room():
		if GameState.monster_level == 4 and guard_spot:
			if _state == State.HIDDEN:
				_timer -= delta
				if _timer <= 0.0:
					_appear(guard_spot.global_position, State.GUARDING)
			elif _state != State.GUARDING:
				_appear(guard_spot.global_position, State.GUARDING)
		elif _state != State.HIDDEN:
			_vanish(_lurk_delay())
		return
	match _state:
		State.HIDDEN:
			_process_hidden(delta)
		State.LURKING:
			_process_lurk(delta)
		State.HUNTING:
			_process_hunt(delta)
		State.GUARDING:
			_process_guard(delta)

func _process_hidden(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	if GameState.monster_level == 4:
		if guard_spot:
			_appear(guard_spot.global_position, State.GUARDING)
			return
	if _hunts_now():
		_start_hunt()
	else:
		_start_lurk()

func _start_lurk() -> void:
	var spot := _pick_spot(lurk_min_distance, lurk_max_distance, true)
	if spot == null:
		_timer = 3.0
		return
	_appear(spot.global_position, State.LURKING)
	_timer = randf_range(lurk_seconds.x, lurk_seconds.y)
	_stared = 0.0

func _process_lurk(delta: float) -> void:
	_face_player()
	_timer -= delta
	if _player_can_see(global_position + Vector3.UP * EYE_HEIGHT):
		_stared += delta
		if _stared >= stare_seconds:
			_play(sting_sound)
			_vanish(_lurk_delay())
			return
		if _distance_to_player() < lurk_vanish_distance or _timer <= 0.0:
			_vanish(_lurk_delay())

func _start_hunt() -> void:
	var spot := _pick_spot(hunt_spawn_min_distance, INF, true)
	if spot == null:
		spot = _pick_spot(hunt_spawn_min_distance, INF, false)
	if spot == null:
		_timer = 2.0
		return
	_appear(spot.global_position, State.HUNTING)
	_repath = 0.0

func _process_hunt(delta: float) -> void:
	_repath -= delta
	if _repath <= 0.0:
		agent.target_position = player.global_position
		_repath = 0.25
	var distance := _distance_to_player()
	if distance <= grab_distance:
		_start_grab()
		return
	if distance <= presence_radius:
		GameState.drain(presence_drain_per_second * delta)
	_move_along_path(delta)
	_face_player()

func _process_guard(delta: float) -> void:
	_face_player()
	_grace -= delta
	if _grace <= 0.0 and _distance_to_player() <= guard_charge_distance:
		_state = State.HUNTING
		_repath = 0.0
		_animate(&"chase_start")

func _start_grab() -> void:
	_state = State.GRABBING
	_presses = 0
	_show_grab_overlay(true)
	GameState.set_controls_locked(true)
	GameState.regen_paused = true
	player.face_toward(global_position + Vector3.UP * grab_look_height, 0.25)
	_play(grab_sound)
	Events.story_prompt_changed.emit("Struggle!   [SPACE]")
	Events.struggle_changed.emit(0.001)

func _process_grab(delta: float) -> void:
	GameState.drain(grab_drain_per_second * delta, true)
	_face_player()
	if GameState.energy <= GameState.ENERGY_EPSILON:
		_consume()

func _escape() -> void:
	_play(free_sound)
	Events.story_prompt_changed.emit("")
	Events.struggle_changed.emit(0.0)
	GameState.set_controls_locked(false)
	GameState.regen_paused = false
	_vanish(escape_cooldown)

func _consume() -> void:
	GameState.regen_paused = false
	_vanish(escape_cooldown)
	_play(consume_sound)
	Events.story_prompt_changed.emit("")
	Events.struggle_changed.emit(0.0)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.6)
	await tween.finished
	GameState.exit_astral()
	GameState.refill_energy()
	player.place_at(respawn_spot.global_transform)
	await  create_tween().tween_interval(1.0).finished
	tween = create_tween()
	tween.tween_property(fade, "color:a", 0.0, 0.8)
	await tween.finished
	GameState.set_controls_locked(false)
#endregion

#region - REACTIONS
func _unhandled_input(event: InputEvent) -> void:
	if _state == State.GRABBING and event.is_action_pressed("struggle"):
		_presses += 1
		Events.struggle_changed.emit(float(_presses) / _presses_needed())
		if _presses >= _presses_needed():
			_escape()
		get_viewport().set_input_as_handled()
		return
	
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo \
		and event.keycode == KEY_F5:
			GameState.set_monster_level((GameState.monster_level + 1) % 6)
			print("Creature level: ", GameState.monster_level)

func _on_plane_changed(in_astral: bool) -> void:
	if GameState.monster_level != 2:
		return
	if in_astral:
		if _state == State.LURKING:
			_state = State.HUNTING
			_repath = 0.0
			_animate(&"chase_start")
		elif _state == State.HIDDEN:
			_timer = minf(_timer, randf_range(hunt_delay.x, hunt_delay.y))
	elif _state == State.HUNTING:
		_vanish(_lurk_delay())

func _on_door_opened(_room_id: StringName, _exit_spot: Transform3D) -> void:
	if _state == State.HUNTING:
		_vanish(_lurk_delay())

func _on_returned_to_hall(_exit_spot: Transform3D) -> void:
	_grace = guard_exit_grace

func _on_monster_level_changed(_level: int) -> void:
	if _state != State.GRABBING:
		_vanish(2.0)
#endregion

#region - HELPERS
func _appear(at: Vector3, state: State) -> void:
	global_position = at
	_state = state
	_animate(&"chase_start" if state == State.HUNTING else &"idle")
	visible = true
	if state == State.GUARDING:
		GameState.guarded_room = guard_room
	_face_player()
	if presence.stream:
		presence.play()

func _animate(anim: StringName) -> void:
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim):
		return
	if sprite.animation == anim and sprite.is_playing():
		return
	sprite.play(anim)
	var texture := sprite.sprite_frames.get_frame_texture(anim, 0)
	var fit: Vector2 = animation_fit.get(anim, Vector2(2.1, 0.0))
	if texture:
		sprite.pixel_size = fit.x * size_scale / texture.get_height()
		sprite.position.y = (fit.x * 0.5 - fit.y) * size_scale

func _show_grab_overlay(on: bool) -> void:
	if grab_overlay == null or grab_sprite == null:
		return
	grab_overlay.visible = on
	if sprite:
		sprite.visible = not on
	if not on:
		grab_sprite.stop()
		return
	var texture := grab_sprite.sprite_frames.get_frame_texture(&"grab", 0)
	var screen := get_viewport().get_visible_rect().size
	grab_sprite.scale = Vector2.ONE * (screen.y * grab_screen_height / texture.get_height())
	grab_sprite.offset = (Vector2(0.5, 0.5) - grab_face) * texture.get_size() # Face at the sprite's origin.
	grab_sprite.position = screen * 0.5
	grab_sprite.play(&"grab")

func _vanish(next_in: float) -> void:
	_show_grab_overlay(false)
	_state = State.HIDDEN
	visible = false
	presence.stop()
	GameState.guarded_room = &""
	_timer = next_in

func _pick_spot(min_distance: float, max_distance: float, out_of_sight: bool) ->  Node3D:
	var choices: Array[Node3D] = []
	for child in spots.get_children():
		var spot := child as Node3D
		if spot == null:
			continue
		var distance := spot.global_position.distance_to(player.global_position)
		if distance < min_distance or distance > max_distance:
			continue
		if out_of_sight and _player_can_see(spot.global_position + Vector3.UP * EYE_HEIGHT):
			continue
		choices.append(spot)
	if choices.is_empty():
		return null
	return choices.pick_random()

func _player_can_see(point: Vector3) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not camera.is_position_in_frustum(point):
		return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, point, WORLD_LAYER)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _move_along_path(delta: float) -> void:
	if agent.is_navigation_finished():
		return
	var next := agent.get_next_path_position()
	var to_next := next - global_position
	to_next.y = 0.0
	var step := hunt_speed * delta
	if to_next.length() <= step:
		global_position = Vector3(next.x, global_position.y, next.z)
	else:
		global_position += to_next.normalized() * step

func _face_player() -> void:
	var target := player.global_position
	target.y = global_position.y
	if global_position.distance_to(target) > 0.01:
		look_at(target, Vector3.UP)

func _distance_to_player() -> float:
	var offset := player.global_position - global_position
	offset.y = 0.0
	return offset.length()

func _lurk_delay() -> float:
	return randf_range(lurk_interval.x, lurk_interval.y)

func _hunts_now() -> bool:
	var level := GameState.monster_level
	return level == 3 or (level == 2 and GameState.in_astral)

func _presses_needed() -> int:
	return struggle_presses + presses_per_bar * GameState.max_bars

func _play(stream: AudioStream) -> void:
	if stream:
		stinger.stream = stream
		stinger.play()
#endregion
