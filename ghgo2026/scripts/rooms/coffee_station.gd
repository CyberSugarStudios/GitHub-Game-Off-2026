class_name CoffeeStation
extends Node

const FULL_FLAG := &"leanne_coffee_full"

@export var parent_id: StringName = &"leanne"
@export var room_id: StringName = &"kitchen"
@export var actor: RoomActor
@export var cup: Sprite2D
@export var full_texture: Texture2D
@export var empty_texture: Texture2D
@export var red_light: PointLight2D
@export var green_light: PointLight2D
@export var drink_spot: StringName = &"drinking_coffee"
@export var make_spot: StringName = &"making_coffee"
@export var sip_sound: AudioStream
@export var sip_gap := Vector2(4.0, 9.0)
@export var sips_per_cup: int = 5

var _fetching := false
var _cup_held := false
var _coffee_ready := false
var _sips := 0
var _sip_wait := 0.0
var _sip_player: AudioStreamPlayer
var _last_activity: StringName

func _ready() -> void:
	_sip_player = AudioStreamPlayer.new()
	_sip_player.bus = &"SFX"
	_sip_player.stream = sip_sound
	add_child(_sip_player)
	_last_activity = _activity()
	_cup_held = _last_activity == &"making_coffee"
	GameState.parent_activity_changed.connect(_on_parent_changed)
	GameState.parent_location_changed.connect(_on_parent_changed)
	if actor:
		actor.arrived.connect(_on_actor_arrived)

func _activity() -> StringName:
	if GameState.get_parent_location(parent_id) != room_id:
		return &""
	return GameState.get_parent_activity(parent_id)

func _on_parent_changed(id: StringName, _value: StringName) -> void:
	if id == parent_id:
		_react.call_deferred()

func _react() -> void:
	var activity := _activity()
	if activity == _last_activity:
		return
	var previous := _last_activity
	_last_activity = activity
	if activity == &"making_coffee" and not _cup_held and actor:
		_fetching = true
		actor.walk_to(drink_spot)
	elif activity == &"drinking_coffee" and previous == &"making_coffee":
		_coffee_ready = true
	elif activity == &"":
		_fetching = false
		_coffee_ready = false
		_cup_held = false

func _on_actor_arrived() -> void:
	var activity := _activity()
	if _fetching:
		_fetching = false
		_cup_held = true
		if activity == &"making_coffee":
			actor.walk_to(make_spot)
			return
	if activity == &"drinking_coffee" and (_cup_held or _coffee_ready):
		_cup_held = false
		_coffee_ready = false
		_sips = 0

func _player_here() -> bool:
	var node := get_parent()
	while node and not node is Room:
		node = node.get_parent()
	return node != null and not (node as Room).is_preview and GameState.current_room == (node as Room).room_id

func _process(delta: float) -> void:
	var full := GameState.has_flag(FULL_FLAG)
	if cup:
		cup.visible = not _cup_held
		cup.texture = full_texture if full else empty_texture
	if green_light:
		green_light.visible = _coffee_ready
	if red_light:
		red_light.visible = not _coffee_ready
	_process_sips(delta, full)

func _process_sips(delta: float, full: bool) -> void:
	var drinking := _activity() == &"drinking_coffee" and not (actor and actor.is_walking()) and _player_here()
	if not full or _cup_held or not drinking:
		_sip_wait = randf_range(1.0, sip_gap.x)
		return
	_sip_wait -= delta
	if _sip_wait > 0.0:
		return
	_sip_wait = randf_range(sip_gap.x, sip_gap.y)
	_sip_player.pitch_scale = randf_range(0.95, 1.05)
	_sip_player.play()
	_sips += 1
	if _sips >= sips_per_cup:
		GameState.clear_flag(FULL_FLAG)
