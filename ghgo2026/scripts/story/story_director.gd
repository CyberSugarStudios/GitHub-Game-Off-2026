class_name StoryDirector
extends Node

#region - INIT
signal seen_story_event(id: StringName)
signal seen_conversation_end(title: String)
signal seen_plane(is_astral: bool)
signal seen_room(room_id: StringName)

const INTRO := preload("res://dialogue/intro.dialogue")
const INTRO_DONE := &"intro_done"
const INTRO_FLAGS: Array[StringName] = [
	&"garage_handle_tried",
	&"leanne_home",
	&"mom_ignored",
	&"read_mom_thoughts"
]
#region - EXPORTS
@export var play_intro: bool = true

@export_group("Scene")
@export var room_view: RoomView
@export var astral_shift: AstralShift
@export var household: Household
@export var fade: ColorRect
@export var wake_doorway: Door
@export var garage_voice: Speaker
@export var living_room_voice: Speaker
@export var front_door_sound: AudioStreamPlayer3D
@export var title_card: CanvasItem

@export_group("Intro")
@export var intro_time: String = "16:40"
@export var wake_fade_time: float = 3.0
@export_range(0.0, 1.0) var wake_pan_from: float = 0.0
@export_range(0.0, 1.0) var wake_pan_to: float = 0.5
@export var wake_pan_seconds: float = 6.0
@export var focus_seconds: float = 6.0
@export var end_fade_time: float = 2.0
@export var title_fade_seconds: float = 1.5
@export var title_hold_seconds: float = 3.0

@export_group("Morning")
@export var morning_time: String = "07:30"
@export var morning_fade_time: float = 0.6
#endregion
var _finished: Dictionary[String, bool] = {}
#endregion

func _ready() -> void:
	Events.story_event.connect(seen_story_event.emit)
	Events.conversation_finished.connect(_on_conversation_finished)
	GameState.plane_changed.connect(seen_plane.emit)
	GameState.room_changed.connect(seen_room.emit)
	if title_card:
		title_card.modulate.a = 0.0

func _exit_tree() -> void:
	Events.story_prompt_changed.emit("")
	GameState.set_controls_locked(false)

#region - OPENING
func prepare() -> float:
	if not play_intro or GameState.has_flag(INTRO_DONE):
		_setup_morning()
		return morning_fade_time
	_setup_intro()
	return wake_fade_time

func start() -> void:
	if not GameState.has_flag(INTRO_DONE):
		_run_intro()

func _setup_intro() -> void:
	GameClock.set_time(1, _to_minutes(intro_time))
	GameState.set_story_stage(0)
	GameState.shift_allowed = false
	GameState.set_parent_location(&"david", &"garage")
	GameState.set_controls_locked(true)
	room_view.open_now(&"living_room", wake_doorway.get_exit_transform())
	room_view.set_pan(wake_pan_from)
	room_view.exit_locked = true

func _setup_morning() -> void:
	GameState.set_flag(INTRO_DONE)
	for flag in INTRO_FLAGS:
		GameState.set_flag(flag)
	GameState.shift_allowed = true
	if garage_voice:
		garage_voice.visible = false
	GameClock.set_time(2, _to_minutes(morning_time))
	GameState.set_story_stage(1)
	GameState.set_monster_level(1)
	household.place_everyone()
#endregion

#region - INTRO
func _run_intro() -> void:
	await room_view.pan_to(wake_pan_to, wake_pan_seconds)
	await say("intro_wake", true)
	GameState.set_controls_locked(false)
	
	await wait_event(&"living_room_clock")
	await say("intro_clock")
	room_view.exit_locked = false
	
	await wait_room(&"")
	say_in_background("intro_david_garage")
	await wait_event(&"garage_handle")
	GameState.set_flag(&"garage_handle_tried")
	
	await say("intro_garage_handle", true)
	
	GameState.shift_allowed = true
	astral_shift.start_focus(focus_seconds)
	prompt("Try harder   [hold SHIFT]")
	await wait_event(&"fist_shift_complete")
	prompt("")
	
	GameState.shift_allowed = false
	await say("intro_astral_panic")
	GameState.shift_allowed = true
	prompt("Focus... calm down   [Shift]")
	await wait_plane(false)
	prompt("")
	GameState.shift_allowed = false
	await say("intro_back")
	
	if front_door_sound and front_door_sound.stream:
		front_door_sound.play()
	await wait(1.0)
	GameState.set_parent_location(&"leanne", &"living_room")
	living_room_voice.visible = true
	await say("intro_leanne_home")
	living_room_voice.visible = false
	household.send(&"leanne", &"kitchen",  24 * 60)
	GameState.set_flag(&"leanne_home")
	
	for i in 4:
		await wait_event(&"talk_to_mom")
		await say(&"intro_mom_%s" % (i + 1))
	GameState.set_flag(&"mom_ignored")
	
	GameState.shift_allowed = true
	prompt("Try harder   [SHIFT]")
	await wait_plane(true)
	prompt("")
	await wait_said("thoughts_leanne_stage0")
	GameState.set_flag(&"read_mom_thoughts")
	
	await wait_event(&"memorial_pamphlet")
	await say(&"intro_pamphlet", true)
	
	_end_intro()

func _end_intro() -> void:
	GameState.set_controls_locked(true)
	var tween := create_tween()
	tween.tween_property(fade,"color:a", 1.0, end_fade_time)
	await tween.finished
	if title_card:
		await _fade_item(title_card, 1.0, title_fade_seconds)
		await  wait(title_hold_seconds)
		await _fade_item(title_card, 0.0, title_fade_seconds)
	_restart_as_morning()

func _restart_as_morning() -> void:
	GameState.set_flag(INTRO_DONE)
	GameState.exit_astral()
	GameState.set_controls_locked(false)
	get_tree().reload_current_scene()
#endregion

#region - BEAT HELPERS
func say(cue: String, frozen: bool = false) -> void:
	_finished.erase(cue)
	Events.conversation_requested.emit(INTRO, cue, frozen)
	while not _finished.has(cue):
		await seen_conversation_end

func say_in_background(cue: String) -> void:
	Events.conversation_requested.emit(INTRO, cue, false)

func wait_said(title: String) -> void:
	_finished.erase(title)
	while not _finished.has(title):
		await seen_conversation_end

func wait_event(id: StringName) -> void:
	var seen: StringName = &""
	while seen != id:
		seen = await seen_story_event

func wait_plane(astral: bool) -> void:
	while GameState.in_astral != astral:
		await seen_plane

func wait_room(room_id: StringName) -> void:
	while GameState.current_room != room_id:
		await seen_room

func wait(seconds: float) -> void:
	await create_tween().tween_interval(seconds).finished

func _fade_item(item: CanvasItem, alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(item, "modulate:a", alpha, seconds)
	await tween.finished

func prompt(text: String) -> void:
	Events.story_prompt_changed.emit(text)

func _on_conversation_finished(title: String) -> void:
	_finished[title] = true
	seen_conversation_end.emit(title)

static func _to_minutes(time_text: String) -> int:
	var parts := time_text.split(":")
	return int(parts[0]) * 60 + int(parts[1])

func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo \
	and event.keycode == KEY_F4 and not GameState.has_flag(INTRO_DONE):
		get_viewport().set_input_as_handled()
		_restart_as_morning()
#endregion
