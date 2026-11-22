class_name CreatureLook
extends Resource

@export var frames: SpriteFrames
@export var animation_fit: Dictionary[StringName, Vector2] = {
	&"idle": Vector2(2.1, 0.0),
	&"chase_start": Vector2(2.13, 0.0),
	&"chase_loop": Vector2(2.13, 0.0),
}

@export_group("Grab Overlay")
@export var grab_screen_height: float = 1.6
@export var grab_face := Vector2(0.505, 0.11)
@export var grab_screen_point := Vector2(0.5, 0.5)
