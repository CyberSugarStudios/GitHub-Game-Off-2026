extends Node3D

const HALL_MUSIC := preload("res://assets/audio/music/WIP_child_ghost_background_2.mp3")

@export var warmup_frames: int = 10
@export var fade_in_time: float = 0.6

@onready var fade: ColorRect = $RoomView/FadeLayer/Fade
@onready var astral_filter: ColorRect = $UI/AstralRealmColorFilter

func _ready() -> void:
	Music.play(HALL_MUSIC)
	Events.story_event.connect(_on_story_event_test) #TEMP
	
	fade.color.a = 1.0
	_warm_up()

func _on_story_event_test(id: StringName) -> void:
	print("Story event: ", id)
	var dialogue := load("res://dialogue/test.dialogue") as DialogueResource
	match id:
		&"test_box":
			Events.conversation_requested.emit(dialogue, "kitchen_murmur", false) # Live
		&"test_box_living_only":
			Events.conversation_requested.emit(dialogue, "portrait_falls", true)  # Frozen: grants a memory"

func _warm_up() -> void:
	astral_filter.visible = true
	get_tree().call_group("astral_visibility", "set_warmup", true)
	
	for i in warmup_frames:
		if not is_inside_tree():
			return
		await get_tree().process_frame
	
	astral_filter.visible = GameState.in_astral
	get_tree().call_group("astral_visibility", "set_warmup", false)
	
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, fade_in_time)
