class_name Speaker
extends Node3D

@export var character_name: String = ""

@onready var voice: AudioStreamPlayer3D = $Voice

func _ready() -> void:
	add_to_group("speakers")
