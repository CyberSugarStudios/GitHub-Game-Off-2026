class_name AstralVisibility
extends Node

enum Mode { ASTRAL_ONLY, LIVING_ONLY, ANY }

@export var mode: Mode = Mode.ASTRAL_ONLY

@onready var _target: Node = get_parent()

func _ready() -> void:
	GameState.plane_changed.connect(_apply)
	_apply(GameState.in_astral)

func _apply(in_astral: bool) -> void:
	var should_show := true
	match mode:
		Mode.ASTRAL_ONLY:
			should_show = in_astral
		Mode.LIVING_ONLY:
			should_show = not in_astral
	_target.set("visible", should_show)
