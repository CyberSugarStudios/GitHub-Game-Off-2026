class_name AstralVisibility
extends Node

enum Mode { ASTRAL_ONLY, LIVING_ONLY, ANY }

@export var mode: Mode = Mode.ASTRAL_ONLY

@onready var _target: Node3D = get_parent() as Node3D

func _ready() -> void:
	GameState.plane_changed.connect(_apply)
	_apply(GameState.in_astral)

func _apply(in_astral: bool) -> void:
	match mode:
		Mode.ASTRAL_ONLY:
			_target.visible = in_astral
		Mode.LIVING_ONLY:
			_target.visible = not in_astral
		Mode.ANY:
			_target.visible = true
