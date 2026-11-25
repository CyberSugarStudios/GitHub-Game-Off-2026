class_name MirrorView
extends CanvasLayer

@export var open_event: StringName = &"bathroom_mirror"
@export var fog_events: Array[StringName] = [&"bathroom_shower_faucet"]
@export var fog_minutes: int = 90
@export var creature: Creature

@export_group("Art")
@export var mirror_texture: Texture2D = preload("res://assets/sprites/rooms/bathroom/mirror.webp")
@export var reflection_texture: Texture2D = preload("res://assets/sprites/rooms/bathroom/emily_reflection.webp")
@export var fog_texture: Texture2D = preload("res://assets/sprites/rooms/bathroom/fog.webp")
@export var creature_place := Vector3(0.54, 0.4, 1.1)
@export_range(0.0, 1.0) var creature_opacity: float = 0.75

@export_group("Flicker")
@export var flicker_gap := Vector2(1.2, 3.5)
@export var flicker_length := Vector2(0.08, 0.4)
@export var fade_time: float = 0.25

var _root: Control
var _reflection: TextureRect
var _creature_art: TextureRect
var _fog: TextureRect
var _fogged_at := -100000
var _flicker_left := 0.0
var _showing_creature := false

func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.clip_contents = true
	add_child(_root)
	_add_picture(mirror_texture)
	_reflection = _add_picture(reflection_texture)
	_creature_art = TextureRect.new()
	_creature_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_creature_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_creature_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_creature_art)
	_fog = _add_picture(fog_texture)
	visible = false
	Events.story_event.connect(_on_story_event)
	GameState.parent_activity_changed.connect(_on_parent_activity)

func _add_picture(texture: Texture2D) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(picture)
	return picture

func _on_story_event(id: StringName) -> void:
	if id == open_event:
		open()
	elif id in fog_events:
		_fogged_at = GameClock.get_total_minutes()

func _on_parent_activity(parent_id: StringName, activity: StringName) -> void:
	if activity == &"showering" and GameState.get_parent_location(parent_id) == &"bathroom":
		_fogged_at = GameClock.get_total_minutes()

func open() -> void:
	if visible:
		return
	visible = true
	GameState.set_controls_locked(true)
	_fog.modulate.a = _fog_amount()
	_set_creature(false, 0.0)
	_flicker_left = randf_range(flicker_gap.x, flicker_gap.y) * 0.5
	var look := creature.look_for_level() if creature else null
	var frames := look.frames if look else null
	_creature_art.texture = frames.get_frame_texture(&"idle", 0) if frames and frames.has_animation(&"idle") else null
	_place_creature()

func close() -> void:
	visible = false
	GameState.set_controls_locked(false)

func _process(delta: float) -> void:
	if not visible or not GameState.in_astral or _creature_art.texture == null:
		return
	_flicker_left -= delta
	if _flicker_left > 0.0:
		return
	_showing_creature = not _showing_creature
	_set_creature(_showing_creature, fade_time if not _showing_creature else 0.05)
	var timing := flicker_length if _showing_creature else flicker_gap
	_flicker_left = randf_range(timing.x, timing.y)

func _set_creature(on: bool, fade: float) -> void:
	_showing_creature = on
	var tween := create_tween().set_parallel()
	tween.tween_property(_creature_art, "modulate:a", creature_opacity if on else 0.0, fade)
	tween.tween_property(_reflection, "modulate:a", 0.25 if on else 1.0, fade)

func _place_creature() -> void:
	var screen := _root.size
	var height := screen.y * creature_place.z
	_creature_art.size = Vector2(height, height)
	_creature_art.position = Vector2(screen.x * creature_place.x - height * 0.5, screen.y * creature_place.y)

func _fog_amount() -> float:
	var age := GameClock.get_total_minutes() - _fogged_at
	return clampf((fog_minutes - age) / (fog_minutes / 3.0), 0.0, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var click: bool = event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if click or event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()
