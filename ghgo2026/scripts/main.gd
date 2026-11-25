extends Node3D

const INTRO_VIDEO := preload("res://assets/sprites/Animations/intro_anim.ogv")

@export var warmup_turn_steps: int = 8
@export var warmup_frames_per_step: int = 2

@export var bus_appears_at: float = 19.8

@onready var fade: ColorRect = $RoomView/FadeLayer/Fade
@onready var astral_filter: ColorRect = $UI/AstralRealmColorFilter
@onready var day_night: DayNight = $DayNight
@onready var player: Node3D = $Emily
@onready var story: StoryDirector = $StoryDirector
@onready var music_director: MusicDirector = $MusicDirector

var _video_playing := false
var _skip_video := false

func _ready() -> void:
	fade.color.a = 1.0
	if story.play_intro and not GameState.has_flag(StoryDirector.INTRO_DONE):
		music_director.play_intro()
	_warm_up()

func _warm_up() -> void:
	astral_filter.visible = true
	get_tree().call_group("astral_visibility", "set_warmup", true)
	
	var start_yaw := player.rotation.y
	for astral in [1.0, 0.0]:
		day_night.forced_astral = astral
		for step in warmup_turn_steps:
			player.rotation.y = start_yaw + TAU * step / warmup_turn_steps
			for i in warmup_frames_per_step:
				if not is_inside_tree():
					return
				await get_tree().process_frame
	player.rotation.y = start_yaw
	day_night.forced_astral = -1.0
	
	astral_filter.visible = GameState.in_astral
	get_tree().call_group("astral_visibility", "set_warmup", false)
	await get_tree().process_frame
	
	var reveal_time := story.prepare()
	var tween: Tween
	if GameState.has_flag(StoryDirector.INTRO_DONE):
		tween = create_tween()
		tween.tween_property(fade, "color:a", 0.0, reveal_time)
	else:
		var screen := await _play_intro_videos()
		fade.color.a = 0.0
		music_director.end_intro(reveal_time)
		tween = create_tween()
		tween.tween_property(screen, "modulate:a", 0.0, reveal_time)
		tween.tween_callback(screen.get_parent().queue_free)
	await tween.finished
	story.start()

func _play_intro_videos() -> ColorRect:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	var screen := ColorRect.new()
	screen.color = Color.BLACK
	layer.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := AspectRatioContainer.new()
	screen.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var video := VideoStreamPlayer.new()
	video.expand = true
	box.add_child(video)
	_video_playing = true
	video.stream = INTRO_VIDEO
	video.play()
	await get_tree().process_frame
	var texture := video.get_video_texture()
	if texture and texture.get_height() > 0:
		box.ratio = float(texture.get_width()) / texture.get_height()
	var on_bus := false
	while video.is_playing() and not _skip_video:
		if not on_bus and video.stream_position >= bus_appears_at:
			on_bus = true
			music_director.intro_to_earbuds()
		await get_tree().process_frame
	_video_playing = false
	return screen

func _unhandled_input(event: InputEvent) -> void:
	if _video_playing and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		_skip_video = true
		get_viewport().set_input_as_handled()
