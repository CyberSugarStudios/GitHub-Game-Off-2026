class_name AstralWriting
extends Label3D

@export var hint_stage: int = -1
@export var pulse_from_hint_level: int = 2

func _ready() -> void:
	modulate.a = 0.0
	outline_modulate.a = 0.0

func _process(_delta: float) -> void:
	var strength := 1.0
	if hint_stage >= 0 and GameState.story_stage == hint_stage \
	and GameState.get_hint_level() >= pulse_from_hint_level:
		strength = 0.7 + 0.3 * sin(Time.get_ticks_msec() / 250.0)
	modulate.a = DayNight.astral_amount * strength
	outline_modulate.a = modulate.a
