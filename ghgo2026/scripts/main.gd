extends Node3D

const HALL_MUSIC := preload("res://assets/audio/music/WIP_child_ghost_background_2.mp3")

@export var fade_in_time: float = 0.6
@export var warmup_turn_steps: int = 8
@export var warmup_frames_per_step: int = 2

@onready var fade: ColorRect = $RoomView/FadeLayer/Fade
@onready var astral_filter: ColorRect = $UI/AstralRealmColorFilter
@onready var day_night: DayNight = $DayNight
@onready var player: Node3D = $Emily

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
	
	var start_yaw := player.rotation.y
	for astral in [1.0, 0.0]:
		day_night.forced_astral = astral
		for step in warmup_turn_steps:
			player.rotation.y = start_yaw + TAU * step / warmup_frames_per_step
			for i in warmup_frames_per_step:
				if not is_inside_tree():
					return
				await get_tree().process_frame
	player.rotation.y = start_yaw
	day_night.forced_astral = -1.0
	
	astral_filter.visible = GameState.in_astral
	get_tree().call_group("astral_visibility", "set_warmup", false)
	await get_tree().process_frame
	
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, fade_in_time)
