extends Node3D

func _ready() -> void:
	Events.story_event.connect(func(id: StringName) -> void: print("Story event: ", id)) #TEMP
