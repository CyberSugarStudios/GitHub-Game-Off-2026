class_name StoryDirector
extends Node

#region - INIT
signal seen_story_event(id: StringName)
signal seen_conversation_end(title: String)
signal seen_plane(is_astral: bool)
signal seen_room(room_id: StringName)
signal seen_parent_moved(parent_id: StringName, location: StringName)

const MOM := &"leanne"
const DAD := &"david"
const INTRO := preload("res://dialogue/intro.dialogue")
const PUZZLE_1 := preload("res://dialogue/puzzle_1.dialogue")
const PUZZLE_2 := preload("res://dialogue/puzzle_2.dialogue")
const PUZZLE_3 := preload("res://dialogue/puzzle_3.dialogue")
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
@export_range(0.0, 1.0) var wake_pan_to: float = 1.0
@export var wake_pan_seconds: float = 6.0
@export var focus_seconds: float = 3.0
@export var end_fade_time: float = 2.0
@export var title_fade_seconds: float = 1.5
@export var title_hold_seconds: float = 3.0

@export_group("Morning")
@export var morning_time: String = "07:30"
@export var morning_fade_time: float = 0.6

@export_group("Puzzle 1")
@export var p1_storms_to: StringName = &"parent_bedroom"
@export var p1_storm_pace: float = 1.6
@export var p1_lingers_seconds: float = 4.0
@export var p1_lingers_then_to: StringName = &"kitchen"
@export var p1_apart_minutes: int = 90

@export_group("Puzzle 2")
@export var p2_coffee_make_minutes: int = 10
@export var p2_coffee_drink_minutes: int = 35
@export var p2_change_minutes: int = 10
@export var p2_laundry_minutes: int = 30
@export var p2_breaker_minutes: int = 20
@export var p2_storms_to: StringName = &"living_room"
@export var p2_lingers_seconds: float = 5.0
@export var p2_lingers_then_to: StringName = &"parent_bedroom"
@export var p2_apart_minutes: int = 90

@export_group("Puzzle 3")
@export var p3_drink_times: Array[String] = [
	"17:00",
	"19:00",
	"21:00"
]
@export var p3_beer_cans: Array[StringName] = [
	&"beer_can_1",
	&"beer_can_2",
	&"beer_can_3"
]
@export var p3_drunk_at: int = 2
@export var p3_pill_time: String = "21:30"
@export var p3_night_starts: String = "23:00"
@export var p3_night_ends: String = "06:00"
@export var p3_safe_minutes: int = 240
@export var p3_new_day_hour: int = 7
@export var wait_fade_time: float = 0.4
#endregion
var _finished: Dictionary[String, bool] = {}
var _waiting := false
var _p3_drinks := 0
var _p3_medicated := false
var _p3_last_minute := -1
#endregion

func _ready() -> void:
	Events.story_event.connect(seen_story_event.emit)
	Events.conversation_finished.connect(_on_conversation_finished)
	GameState.plane_changed.connect(seen_plane.emit)
	GameState.room_changed.connect(seen_room.emit)
	GameState.parent_location_changed.connect(seen_parent_moved.emit)
	Events.story_event.connect(_on_any_story_event)
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
	else:
		_run_story()

func _setup_intro() -> void:
	GameClock.set_time(1, _to_minutes(intro_time))
	GameState.set_story_stage(0)
	GameState.shift_allowed = false
	GameState.set_parent_location(DAD, &"garage")
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
	if GameState.story_stage < 1:
		GameState.set_story_stage(1)
		GameState.set_monster_level(1)
	household.place_everyone()
#endregion

#region - INTRO
func _run_intro() -> void:
	await room_view.pan_to(wake_pan_to, wake_pan_seconds)
	await room_view.pan_to(wake_pan_to / 2.0, wake_pan_seconds / 2.0)
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
	GameState.set_parent_location(MOM, &"living_room")
	living_room_voice.visible = true
	await say("intro_leanne_home")
	living_room_voice.visible = false
	household.send(MOM, &"kitchen",  24 * 60)
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

#region - STORY
func _run_story() -> void:
	if GameState.story_stage == 1:
		await _run_puzzle_1()
	if GameState.story_stage == 2:
		await _run_puzzle_2()
	if GameState.story_stage == 3:
		await _run_puzzle_3()
#	if GameState.story_stage == 4:
#		await _run_puzzle_4()
#	if GameState.story_stage == 5:
#		await _run_puzzle_5()

func _run_puzzle_1()  -> void:
	await wait_event(&"hall_painting_fell")
	await say("p1_painting_fight", true, PUZZLE_1)
	household.get_hall_parent(MOM).speed_scale = p1_storm_pace
	household.send(MOM, p1_storms_to, p1_apart_minutes)
	GameState.restore_memory()
	await wait(p1_lingers_seconds)
	household.send(DAD, p1_lingers_then_to, p1_apart_minutes)
	await say("p1_after", false, PUZZLE_1)
	GameState.set_story_stage(2)

#region - PUZZLE 2
func _run_puzzle_2() -> void:
	Events.story_event.connect(_on_puzzle_2_event)
	GameState.parent_location_changed.connect(_on_puzzle_2_parent_moved)
	await wait_event(&"keepsake_box_fell")
	Events.story_event.disconnect(_on_puzzle_2_event)
	GameState.parent_location_changed.disconnect(_on_puzzle_2_parent_moved)
	await say("p2_box_fight", true, PUZZLE_2)
	household.get_hall_parent(DAD).speed_scale = p1_storm_pace
	household.send(DAD, p2_storms_to, p2_apart_minutes)
	GameState.restore_memory()
	await wait(p2_lingers_seconds)
	household.send(MOM, p2_lingers_then_to, p2_apart_minutes)
	await say("p2_after", false, PUZZLE_2)
	GameState.set_story_stage(3)

func _on_puzzle_2_event(id: StringName) -> void:
	match id:
		&"coffee_on_leanne":
			say_in_background("p2_leanne_coffee", PUZZLE_2)
			household.send(MOM, &"parent_bedroom", p2_change_minutes, \
				[[&"garage", p2_laundry_minutes, &"laundry"]], &"changing")
		&"david_checks_breaker":
			say_in_background("p2_david_breaker", PUZZLE_2)
			household.send(DAD, &"garage", p2_breaker_minutes, [], &"checking_breaker")

func _on_puzzle_2_parent_moved(parent_id: StringName, location: StringName) -> void:
	if parent_id == DAD and location == &"garage" and not household.has_errand(MOM):
		household.send(MOM, &"kitchen", p2_coffee_make_minutes, [[&"kitchen", \
			p2_coffee_drink_minutes, &"drinking_coffee"]], &"making_coffee")
#endregion
#region - PUZZLE 3
func _run_puzzle_3() -> void:
	_p3_last_minute = GameClock.minute
	GameClock.minute_changed.connect(_on_puzzle_3_minute)
	while true:
		await wait_event(&"night_noise")
		if await _p3_try_night():
			break
	GameClock.minute_changed.disconnect(_on_puzzle_3_minute)
	GameState.set_story_stage(4)

func _on_puzzle_3_minute(_day: int, minute: int) -> void:
	var previous := _p3_last_minute
	_p3_last_minute = minute
	if _crossed(previous, minute, p3_new_day_hour * 60):
		_p3_new_day()
	for time_text in p3_drink_times:
		if _crossed(previous, minute, _to_minutes(time_text)):
			_p3_drink_time()
	if _crossed(previous, minute, _to_minutes(p3_pill_time)):
		_p3_pill_time()

func _p3_drink_time() -> void:
	if GameState.get_parent_location(DAD) != &"living_room":
		return
	for can in p3_beer_cans:
		if not GameState.has_flag(can):
			GameState.set_flag(can)
			_p3_drinks += 1
			return
	say_in_background("p3_david_no_beer", PUZZLE_3)

func _p3_pill_time() -> void:
	if GameState.get_parent_location(MOM) != &"parent_bedroom":
		return
	if GameState.has_flag(&"pills_hidden"):
		say_in_background("p3_leanne_no_pills", PUZZLE_3)
	else:
		_p3_medicated = true

func _p3_new_day() -> void:
	_p3_drinks = 0
	_p3_medicated = false
	for can in p3_beer_cans:
		GameState.clear_flag(can)
	GameState.clear_flag(&"pills_hidden")

func _p3_try_night() -> bool:
	if not _is_night():
		say_in_background("p3_noise_daytime", PUZZLE_3)
		GameState.add_near_miss()
		return false
	if _p3_drinks >= p3_drunk_at:
		say_in_background("p3_david_passed_out", PUZZLE_3)
		GameState.add_near_miss()
		return false
	household.get_hall_parent(DAD).speed_scale = p1_storm_pace
	household.send(DAD, &"parent_closet", p3_safe_minutes)
	say_in_background("p3_david_wakes", PUZZLE_3)
	await wait_parent(DAD, &"parent_closet")
	await wait_room(&"parent_closet")
	if _p3_medicated:
		await say("p3_safe_alone", true, PUZZLE_3)
		GameState.add_near_miss()
		household.send(DAD, &"living_room", 60)
		return false
	await say("p3_safe_fight", true, PUZZLE_3)
	household.send(DAD, &"living_room", 120)
	GameState.restore_memory()
	await say("p3_after", false, PUZZLE_3)
	return true

func _is_night() -> bool:
	var now := GameClock.minute
	return now >= _to_minutes(p3_night_starts) or now < _to_minutes(p3_night_ends)

static func _crossed(from: int, to: int, at: int) -> bool:
	if to >= from:
		return at > from and at <= to
	return at > from or at <= to
#endregion

func _on_any_story_event(id: StringName) -> void:
	if id == &"wait_hour":
		_wait_an_hour()

func _wait_an_hour() -> void:
	if _waiting:
		return
	_waiting = true
	GameState.set_controls_locked(true)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, wait_fade_time)
	await tween.finished
	GameClock.set_time(GameClock.day, GameClock.minute + 60)
	await wait(0.3)
	tween = create_tween()
	tween.tween_property(fade, "color:a", 0.0, wait_fade_time)
	await tween.finished
	GameState.set_controls_locked(false)
	_waiting = false
#endregion

#region - BEAT HELPERS
func say(cue: String, frozen: bool = false, dialogue: DialogueResource = INTRO) -> void:
	_finished.erase(cue)
	Events.conversation_requested.emit(dialogue, cue, frozen)
	while not _finished.has(cue):
		await seen_conversation_end

func say_in_background(cue: String, dialogue: DialogueResource = INTRO) -> void:
	Events.conversation_requested.emit(dialogue, cue, false)

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

func wait_parent(parent_id: StringName, location: StringName) -> void:
	while GameState.get_parent_location(parent_id) != location:
		await seen_parent_moved

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
