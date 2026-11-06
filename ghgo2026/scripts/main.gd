extends Node3D

@export var warmup_frames: int = 10
@export var fade_in_time: float = 0.6

@onready var fade: ColorRect = $RoomView/FadeLayer/Fade
@onready var astral_filter: ColorRect = $UI/AstralRealmColorFilter

func _ready() -> void:
	Events.story_event.connect(func(id: StringName) -> void: print("Story event: ", id)) #TEMP
	
	fade.color.a = 1.0
	_warm_up()

func _warm_up() -> void:
	astral_filter.visible = true
	get_tree().call_group("astral_visibility", "set_warmup", true)
	
	for i in warmup_frames:
		await get_tree().process_frame
	
	astral_filter.visible = GameState.in_astral
	get_tree().call_group("astral_visibility", "set_warmup", true)
	
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, fade_in_time)
