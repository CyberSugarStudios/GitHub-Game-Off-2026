extends Node3D

const INTRO_VIDEO := preload("res://assets/sprites/Animations/intro_anim.ogv")
const KEY_PROMPT := preload("res://scenes/ui/key_prompt.tscn")

@export var warmup_turn_steps: int = 8
@export var warmup_frames_per_step: int = 2

@export var bus_appears_at: float = 18.3
@export var bus_transition_seconds: float = 1.75
@export var hold_video_at: float = 3.2
@export var skip_hold_seconds: float = 1.5
@export var options_prompt_seconds: float = 8.0
@export var skip_prompt_linger: float = 1.0
@export var video_to_black: float = 0.8
@export var black_hold: float = 0.3

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
var _skip_hold := 0.0
var _skip_ring: FocusRing
var _skip_prompt: KeyPrompt
var _intro_elapsed := 0.0
var _skip_visible_until := 0.0
static var _options_hint_shown := false

func _ready() -> void:
	_log_load("house built")
	fade.color.a = 1.0
	if story.play_intro and not GameState.has_flag(StoryDirector.INTRO_DONE):
		music_director.play_intro()
		_start_intro_video()
	_warm_up()

static func _log_load(what: String) -> void:
	Playtest.mark_load(what)

func _process(delta: float) -> void:
	if _video == null:
		return
	if _video_playing:
		_intro_elapsed += delta
		var holding := Input.is_action_pressed("interact")
		if holding:
			_skip_visible_until = _intro_elapsed + skip_prompt_linger
		if _skip_prompt:
			var target := 1.0 if _intro_elapsed < _skip_visible_until else 0.0
			var speed := 4.0 if target > _skip_prompt.modulate.a else 1.0
			_skip_prompt.modulate.a = move_toward(_skip_prompt.modulate.a, target, speed * delta)
		_skip_hold = clampf(_skip_hold + (delta if holding else -delta * 2.0), 0.0, skip_hold_seconds)
		if _skip_ring:
			_skip_ring.set_progress(_skip_hold / skip_hold_seconds)
		if _skip_hold >= skip_hold_seconds:
			_skip_video = true
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
		_flash_options_prompt()
	else:
		var screen := await _finish_intro_video()
		fade.color.a = 0.0
		music_director.end_intro(reveal_time)
		tween = create_tween()
		tween.tween_property(_video_box, "modulate:a", 0.0, video_to_black)
		tween.tween_interval(black_hold)
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
	_add_intro_prompts()

func _add_intro_prompts() -> void:
	_options_hint_shown = true
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 12)
	_video_screen.add_child(column)
	_pin_bottom_right(column)
	var options := _make_prompt(_options_key(), "Settings")
	column.add_child(options)
	var skip := _make_prompt("E", "Skip", "Hold")
	column.add_child(skip)
	_skip_prompt = skip
	_skip_visible_until = options_prompt_seconds
	_skip_ring = FocusRing.new()
	_skip_ring.listen_to_events = false
	_skip_ring.radius = 30.0
	skip.get_node("Key").add_child(_skip_ring)
	_skip_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tween := options.create_tween()
	tween.tween_interval(options_prompt_seconds)
	tween.tween_property(options, "modulate:a", 0.0, 1.0)

func _flash_options_prompt() -> void:
	if _options_hint_shown:
		return
	_options_hint_shown = true
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var prompt := _make_prompt(_options_key(), "Options")
	layer.add_child(prompt)
	_pin_bottom_right(prompt)
	var tween := prompt.create_tween()
	tween.tween_interval(options_prompt_seconds)
	tween.tween_property(prompt, "modulate:a", 0.0, 1.0)
	tween.tween_callback(layer.queue_free)

func _make_prompt(key: String, text: String, prefix: String = "") -> KeyPrompt:
	var prompt := KEY_PROMPT.instantiate() as KeyPrompt
	prompt.font_size = 26
	prompt.show_prompt(key, text, prefix)
	return prompt

static func _pin_bottom_right(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	control.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	control.grow_vertical = Control.GROW_DIRECTION_BEGIN
	control.offset_left = -40.0
	control.offset_right = -40.0
	control.offset_top = -40.0
	control.offset_bottom = -40.0

static func _options_key() -> String:
	return "P" if OS.has_feature("web") else "Esc"

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
	if _video_playing and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
