extends Node3D

const INTRO_VIDEO := preload("res://assets/sprites/Animations/intro_anim.ogv")

@export var warmup_turn_steps: int = 8
@export var warmup_frames_per_step: int = 2

@export var bus_appears_at: float = 18.3
@export var bus_transition_seconds: float = 1.75
@export var hold_video_at: float = 3.2

@onready var fade: ColorRect = $RoomView/FadeLayer/Fade
@onready var astral_filter: ColorRect = $UI/AstralRealmColorFilter
@onready var day_night: DayNight = $DayNight
@onready var player: Node3D = $Emily
@onready var story: StoryDirector = $StoryDirector
@onready var music_director: MusicDirector = $MusicDirector

var _video_playing := false
var _skip_video := false
var _warmed := false
var _video: VideoStreamPlayer
var _video_box: AspectRatioContainer
var _video_screen: ColorRect

func _ready() -> void:
	_log_load("house built")
	fade.color.a = 1.0
	if story.play_intro and not GameState.has_flag(StoryDirector.INTRO_DONE):
		music_director.play_intro()
		_start_intro_video()
	_warm_up()

static func _log_load(what: String) -> void:
	Playtest.mark_load(what)

func _process(_delta: float) -> void:
	if _video == null:
		return
	if _video_box.ratio == 1.0:
		var texture := _video.get_video_texture()
		if texture and texture.get_height() > 0:
			_video_box.ratio = float(texture.get_width()) / texture.get_height()
	if not _warmed and not _video.paused and _video.stream_position >= hold_video_at:
		_video.paused = true

func _warm_up() -> void:
	astral_filter.visible = true
	get_tree().call_group("astral_visibility", "set_warmup", true)
	
	var start_yaw := player.rotation.y
	var slowest := 0
	for astral in [1.0, 0.0]:
		day_night.forced_astral = astral
		for step in warmup_turn_steps:
			player.rotation.y = start_yaw + TAU * step / warmup_turn_steps
			for i in warmup_frames_per_step:
				if not is_inside_tree():
					return
				var before := Time.get_ticks_msec()
				await get_tree().process_frame
				slowest = maxi(slowest, Time.get_ticks_msec() - before)
	player.rotation.y = start_yaw
	day_night.forced_astral = -1.0
	_log_load("warm-up done (slowest frame %d ms)" % slowest)
	_warmed = true
	if _video:
		_video.paused = false
	
	astral_filter.visible = GameState.in_astral
	get_tree().call_group("astral_visibility", "set_warmup", false)
	await get_tree().process_frame
	
	var reveal_time := story.prepare()
	var tween: Tween
	if GameState.has_flag(StoryDirector.INTRO_DONE):
		tween = create_tween()
		tween.tween_property(fade, "color:a", 0.0, reveal_time)
	else:
		var screen := await _finish_intro_video()
		fade.color.a = 0.0
		music_director.end_intro(reveal_time)
		tween = create_tween()
		tween.tween_property(screen, "modulate:a", 0.0, reveal_time)
		tween.tween_callback(screen.get_parent().queue_free)
	await tween.finished
	story.start()

func _start_intro_video() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_video_screen = ColorRect.new()
	_video_screen.color = Color.BLACK
	layer.add_child(_video_screen)
	_video_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video_box = AspectRatioContainer.new()
	_video_screen.add_child(_video_box)
	_video_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video = VideoStreamPlayer.new()
	_video.expand = true
	_video_box.add_child(_video)
	_video_playing = true
	_video.stream = INTRO_VIDEO
	_video.play()
	_log_load("intro video started")

func _finish_intro_video() -> ColorRect:
	if _video == null:
		_start_intro_video()
	var on_bus := false
	while _video.is_playing() and not _skip_video:
		if not on_bus and _video.stream_position >= bus_appears_at:
			on_bus = true
			music_director.intro_to_earbuds(bus_transition_seconds)
		await get_tree().process_frame
	_video_playing = false
	return _video_screen

func _unhandled_input(event: InputEvent) -> void:
	if _video_playing and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		_skip_video = true
		get_viewport().set_input_as_handled()
