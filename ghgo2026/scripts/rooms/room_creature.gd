class_name RoomCreature
extends Node2D

@export var appears_at_stage: int = 5
@export var gone_flag: StringName = &"creature_accepted"
@export var blocks: RoomHotspot
@export var frames: SpriteFrames

@onready var sprite: AnimatedSprite2D = $Sprite

var _acceptance := 0.0
var _time := 0.0
var _creature_frames := preload("res://assets/sprites/Animations/frames/creature/creature_frames.tres")

func _ready() -> void:
	GameState.story_stage_changed.connect(
		func(_stage: int) -> void:
			_refresh()
	)
	GameState.flag_set.connect(
		func(_id: StringName) -> void:
			_refresh()
	)
	Events.struggle_changed.connect(
		func(amount: float) -> void:
			_acceptance = amount
	)
	frames = _creature_frames
	_refresh()

func _refresh() -> void:
	visible = GameState.story_stage >= appears_at_stage and not GameState.has_flag(gone_flag)
	if blocks:
		blocks.blocker = self if visible else null
