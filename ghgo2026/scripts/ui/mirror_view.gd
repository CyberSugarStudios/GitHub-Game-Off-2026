class_name MirrorView
extends CanvasLayer

@export var open_event: StringName = &"bathroom_mirror"
@export var fog_events: Array[StringName] = [&"bathroom_shower_faucet"]
@export var fog_minutes: int = 120
@export var creature: Creature
@export_range(0.0, 1.0) var creature_opacity: float = 0.75

@export_group("Astral Sequence")
@export var chase_music: AudioStream = preload("res://assets/audio/music/creature_chase.mp3")
@export var chase_start: float = 9.75
@export var build_seconds: float = 5.0
@export_range(0.0, 1.0) var build_volume: float = 0.5
@export var flickers: int = 4
@export var first_flicker: float = 0.5
@export var flicker_length := Vector2(0.06, 0.18)
@export var creature_seconds: float = 0.6
@export var fade_out_seconds: float = 2.0

@onready var reflection: TextureRect = $Root/Reflection
@onready var creature_art: AnimatedSprite2D = $Root/Creature
@onready var fog: TextureRect = $Root/Fog
@onready var back_button: Button = $Root/BackButton

var _fogged_at := -100000
var _run := 0
var _has_creature := false
var _chase: AudioStreamPlayer
var _music_tween: Tween

func _ready() -> void:
	visible = false
	_chase = AudioStreamPlayer.new()
	_chase.bus = &"Music"
	add_child(_chase)
	back_button.pressed.connect(close)
	Events.story_event.connect(_on_story_event)
	GameState.parent_activity_changed.connect(_on_parent_activity)
	GameState.plane_changed.connect(_on_plane_changed)

func _on_story_event(id: StringName) -> void:
	if id == open_event:
		open()
	elif id in fog_events:
		_fogged_at = GameClock.get_total_minutes()

func _on_parent_activity(parent_id: StringName, activity: StringName) -> void:
	if activity == &"showering" and GameState.get_parent_location(parent_id) == &"bathroom":
		_fogged_at = GameClock.get_total_minutes()

func open() -> void:
	if visible:
		return
	visible = true
	GameState.set_controls_locked(true)
	var look := creature.look_for_level() if creature else null
	_has_creature = look != null and look.frames != null
	if _has_creature:
		creature_art.sprite_frames = look.frames
		if not look.frames.has_animation(creature_art.animation):
			creature_art.animation = &"idle"
		creature_art.play()
	_stop_sequence(0.0)
	if GameState.in_astral:
		_start_sequence()

func close() -> void:
	if not visible:
		return
	visible = false
	_stop_sequence(0.3)
	GameState.set_controls_locked(false)

func _process(_delta: float) -> void:
	if visible:
		fog.modulate.a = _fog_amount()

func _on_plane_changed(astral: bool) -> void:
	if not visible:
		return
	if astral:
		_start_sequence()
	else:
		_stop_sequence(0.3)

func _start_sequence() -> void:
	if not _has_creature:
		return
	_run += 1
	_play_astral(_run)

func _stop_sequence(fade: float) -> void:
	_run += 1
	_fade_chase(fade)
	_show_creature(false)

func _play_astral(run: int) -> void:
	_chase.stream = chase_music
	_chase.volume_linear = 0.0
	_chase.play(chase_start)
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_chase, "volume_linear", build_volume, build_seconds)
	var elapsed := 0.0
	for i in flickers:
		var at := first_flicker + (build_seconds - first_flicker) * float(i) / float(maxi(flickers, 1))
		if not await _wait(at - elapsed, run):
			return
		_show_creature(true)
		var blink := randf_range(flicker_length.x, flicker_length.y)
		if not await _wait(blink, run):
			return
		_show_creature(false)
		elapsed = at + blink
	if not await _wait(build_seconds - elapsed, run):
		return
	_music_tween.kill()
	_chase.volume_linear = 1.0
	_show_creature(true)
	if not await _wait(creature_seconds, run):
		return
	_show_creature(false)
	_fade_chase(fade_out_seconds)

func _show_creature(on: bool) -> void:
	creature_art.visible = on
	creature_art.modulate.a = creature_opacity
	reflection.visible = not on

func _fade_chase(seconds: float) -> void:
	if _music_tween:
		_music_tween.kill()
	if not _chase.playing:
		return
	_music_tween = create_tween()
	_music_tween.tween_property(_chase, "volume_linear", 0.0, seconds)
	_music_tween.tween_callback(_chase.stop)

func _wait(seconds: float, run: int) -> bool:
	await get_tree().create_timer(maxf(seconds, 0.0)).timeout
	return run == _run and visible

func _fog_amount() -> float:
	var age := GameClock.get_total_minutes() - _fogged_at
	return clampf(1.0 - float(age) / fog_minutes, 0.0, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("enter_astral_plane"):
		if GameState.shift_allowed:
			GameState.toggle_plane()
		get_viewport().set_input_as_handled()
		return
	var click: bool = event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if click or event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") \
			or event.is_action_pressed("move_backward"):
		close()
		get_viewport().set_input_as_handled()
