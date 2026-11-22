class_name RoomCreature
extends Node2D

const CREATURE_FRAMES := preload("res://assets/sprites/Animations/frames/creature/mom_creature_frames.tres")
const LIGHT_MASK := preload("res://assets/textures/light_mask.webp")

@export var appears_at_stage: int = 5
@export var gone_flag: StringName = &"creature_accepted"
@export var blocks: RoomHotspot
@export var height: float = 1900.0
@export var idle_animation: StringName = &"idle"
@export var breathe_amount: float = 0.025
@export var breathe_speed: float = 0.3

@export_group("Glow")
@export var glow_color := Color(0.45, 0.85, 0.8)
@export var glow_energy: float = 0.8
@export var glow_size: float = 2.5
@export_range(0.0, 1.0) var night_lift: float = 0.6

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var placeholder: CanvasItem = get_node_or_null("Placeholder")
@onready var click_area: Control = get_node_or_null("ClickArea")

var _acceptance := 0.0
var _time := 0.0
var _fit_scale := 1.0
var _glow: PointLight2D
var _room: Room

func _ready() -> void:
	sprite.sprite_frames = CREATURE_FRAMES
	var texture := CREATURE_FRAMES.get_frame_texture(idle_animation, 0)
	if texture:
		_fit_scale = height / texture.get_height()
	sprite.play(idle_animation)
	_glow = PointLight2D.new()
	_glow.texture = LIGHT_MASK
	_glow.texture_scale = glow_size
	_glow.color = glow_color
	_glow.position = Vector2(0.0, -height * 0.55)
	add_child(_glow)
	var node := get_parent()
	while node and not node is Room:
		node = node.get_parent()
	_room = node as Room
	if placeholder:
		placeholder.visible = false
	if click_area:
		var width := height * 0.35
		click_area.set_anchors_preset(Control.PRESET_TOP_LEFT)
		click_area.position = Vector2(-width * 0.5, -height)
		click_area.size = Vector2(width, height)
	GameState.story_stage_changed.connect(
		func(_stage: int) -> void:
			_refresh())
	GameState.flag_set.connect(
		func(_id: StringName) -> void:
			_refresh())
	Events.struggle_changed.connect(
		func(amount: float) -> void:
			_acceptance = amount)
	_refresh()

func _refresh() -> void:
	visible = GameState.story_stage >= appears_at_stage and not GameState.has_flag(gone_flag)
	if blocks:
		blocks.blocker = self if visible else null

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	var breath := 1.0 + sin(_time * TAU * breathe_speed) * breathe_amount
	var shrink := 1.0 - _acceptance * 0.15
	sprite.scale = Vector2(shrink, shrink * breath) * _fit_scale
	sprite.position.y = -height * 0.5 * shrink * breath
	_glow.energy = glow_energy * (1.0 - _acceptance)
	var lift := Color.WHITE
	if _room:
		var tint := _room.get_tint()
		var cancel := Color(1.0 / maxf(tint.r, 0.01), 1.0 / maxf(tint.g, 0.01), 1.0 / maxf(tint.b, 0.01))
		lift = Color.WHITE.lerp(cancel, night_lift)
	var pale := 1.0 + _acceptance
	sprite.modulate = Color(lift.r * pale, lift.g * pale, lift.b * pale, 1.0 - _acceptance)
