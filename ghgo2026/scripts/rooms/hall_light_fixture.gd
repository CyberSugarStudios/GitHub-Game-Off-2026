class_name HallLightFixture
extends Node3D

@onready var off_mesh: Node3D = $HallLightOff
@onready var on_mesh: Node3D = $HallLightOn
@onready var astral_mesh: Node3D = $HallLightAstral

func _process(_delta: float) -> void:
	var astral := DayNight.astral_amount > 0.5
	var lit := DayNight.lamp_level > 0.5
	astral_mesh.visible = astral
	on_mesh.visible = lit and not astral
	off_mesh.visible = not lit and not astral
