class_name StoryDirector
extends Node

#region - INIT
signal seen_story_event(id: StringName)
signal seen_conversation_end(title: String)
signal seen_plane(is_astral: bool)
signal seen_room(room_id: StringName)
signal seen_parent_moved(parent_id: StringName, location: StringName)
signal accept_finished

const MOM := &"leanne"
const DAD := &"david"
const INTRO := preload("res://dialogue/intro.dialogue")
const PUZZLE_1 := preload("res://dialogue/puzzle_1.dialogue")
const PUZZLE_2 := preload("res://dialogue/puzzle_2.dialogue")
const PUZZLE_3 := preload("res://dialogue/puzzle_3.dialogue")
const PUZZLE_4 := preload("res://dialogue/puzzle_4.dialogue")
const PUZZLE_5 := preload("res://dialogue/puzzle_5.dialogue")
const CREDITS_SCENE := "res://scenes/ui/credits_roll.tscn"
const HAND_SCENE := preload("res://scenes/ui/hand_through_door_intro.tscn")
const WAIT_POPUP := preload("res://scenes/ui/wait_popup.tscn")
const DAY_NIGHT := preload("res://resources/day_night_palette.tres")
const BEER_CAN_SOUND := preload("res://assets/audio/sfx/varied/beer_can_open.wav")
const INTRO_DONE := &"intro_done"
const FIGHT_WALL_LAYER := 1
const FIGHT_EYE_HEIGHT := 1.4
const FIGHT_PULL_STEPS := 6
const INTRO_FLAGS: Array[StringName] = [
	&"garage_handle_tried",
	&"leanne_home",
	&"mom_ignored",
	&"read_mom_thoughts"
]
#region - EXPORTS
@export var play_intro: bool = true

@export_group("Scene")
@export var player: Player
@export var room_view: RoomView
@export var astral_shift: AstralShift
@export var household: Household
@export var fade: ColorRect
@export var wake_doorway: Door
@export var clock_reveal_seconds: float = 2.3
@export var garage_voice: Speaker
@export var living_room_voice: Speaker
@export var front_door_sound: DoorSound
@export var title_card: CanvasItem
@export var pamphlet: PamphletView

@export_group("Intro")
@export var intro_time: String = "16:40"
@export var wake_fade_time: float = 3.0
@export_range(0.0, 1.0) var wake_pan_from: float = 0.0
@export_range(0.0, 1.0) var wake_pan_to: float = 1.0
@export var wake_pan_seconds: float = 4.0
@export var focus_seconds: float = 3.0
@export var end_fade_time: float = 2.0
@export var title_fade_seconds: float = 1.5
@export var title_hold_seconds: float = 3.0

@export_group("Morning")
@export var morning_time: String = "07:30"
@export var night_time: String = "23:30"
@export var morning_fade_time: float = 0.6

@export_group("Puzzle 1")
@export var p1_wait_hint_delay: float = 8.0
@export var p1_storms_to: StringName = &"parent_bedroom"
@export var p1_storm_pace: float = 1.6
@export var p1_lingers_seconds: float = 4.0
@export var p1_lingers_then_to: StringName = &"kitchen"
@export var p1_apart_minutes: int = 90

@export_group("Fight Staging")
@export var fight_gap: float = 1.4
@export var fight_stagger: float = 1.0
@export var fight_min_apart: float = 1.6
@export var fight_keep_away: float = 1.6
@export var fight_walk_timeout: float = 6.0

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
@export var p3_wake_delay: float = 1.5
@export var p3_new_day_hour: int = 7

@export_group("Puzzle 4")
@export var p4_lights_settle: float = 2.0
@export_range(0.0, 1.0) var p4_light_enough: float = 0.3

@export_group("Puzzle 5")
@export var p5_accept_presses: int = 24
@export var p5_light_seconds: float = 3.0
@export var p5_white_seconds: float = 0.5
@export var p5_white_hold: float = 1.0
@export var p5_to_black_seconds: float = 2.5
@export var p5_fight_audio: AudioStream
@export var ending_song: AudioStream = preload("res://assets/audio/music/Ayleen Valentine - white gummy.mp3")
@export var ending_song_db: float = -7.0

@export var wait_fade_time: float = 0.4
#endregion
var _finished: Dictionary[String, bool] = {}
var _waiting := false
var _wait_popup: WaitPopup
var _accept_progress := -1.0
var _p3_medicated := false
var _p3_last_minute := -1
var _p3_drinks := 0
var _mom_activity: StringName = &""
var _sfx: AudioStreamPlayer
#endregion

func _ready() -> void:
	Events.story_event.connect(seen_story_event.emit)
	Events.conversation_finished.connect(_on_conversation_finished)
	GameState.plane_changed.connect(seen_plane.emit)
	GameState.room_changed.connect(seen_room.emit)
	GameState.story_stage_changed.connect(_on_story_stage_changed)
	GameState.parent_location_changed.connect(seen_parent_moved.emit)
	Events.story_event.connect(_on_any_story_event)
	GameState.parent_activity_changed.connect(_on_coffee_activity)
	GameClock.hour_changed.connect(_on_coffee_hour)
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = &"SFX"
	add_child(_sfx)
	_wait_popup = WAIT_POPUP.instantiate() as WaitPopup
	add_child(_wait_popup)
	if title_card:
		title_card.modulate.a = 0.0

func _on_story_stage_changed(stage: int) -> void:
	if stage >= 1:
		GameState.set_monster_level(stage)

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
	GameState.restart_stage_timer()
	if GameState.story_stage < 1:
		GameState.set_story_stage(1)
	GameState.set_monster_level(GameState.story_stage)
	household.place_everyone()
#endregion

#region - INTRO
func _run_intro() -> void:
	await room_view.pan_to(wake_pan_to, wake_pan_seconds)
	await room_view.pan_to(wake_pan_to / 2.0, wake_pan_seconds / 2.0)
	await say("intro_wake", true)
	GameState.set_controls_locked(false)
	
	await wait_event(&"living_room_clock")
	GameState.set_flag(&"clock_shown")
	await wait(clock_reveal_seconds)
	await say("intro_clock")
	room_view.exit_locked = false
	
	await wait_room(&"")
	say_in_background("intro_david_garage")
	await wait_event(&"garage_handle")
	GameState.set_flag(&"garage_handle_tried")
	await _show_hand_through_door()
	
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
	
	if front_door_sound:
		await front_door_sound.open_and_close()
	await wait(1.0)
	GameState.set_parent_activity(MOM, &"arriving_home")
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
	if pamphlet:
		await pamphlet.closed
	await say(&"intro_pamphlet", true)
	
	_end_intro()

func _show_hand_through_door() -> void:
	GameState.set_controls_locked(true)
	var scene := HAND_SCENE.instantiate() as HandThroughDoor
	add_child(scene)
	await scene.play()
	scene.queue_free()

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
	if GameState.story_stage == 4:
		await _run_puzzle_4()
	if GameState.story_stage == 5:
		await _run_finale()

#region - PUZZLE 1
func _run_puzzle_1()  -> void:
	_teach_waiting()
	await wait_event(&"hall_painting_fell")
	await stage_fight(&"fight_painting_leanne", &"fight_painting_david")
	await say_fight("p1_painting_fight", PUZZLE_1)
	household.get_hall_parent(MOM).speed_scale = p1_storm_pace
	household.send(MOM, p1_storms_to, p1_apart_minutes)
	GameState.restore_memory()
	await wait(p1_lingers_seconds)
	household.send(DAD, p1_lingers_then_to, p1_apart_minutes)
	say_in_background("p1_after", PUZZLE_1)
	GameState.set_story_stage(2)

func _teach_waiting() -> void:
	if GameState.has_flag(&"wait_hint_heard"):
		return
	GameState.set_flag(&"wait_hint_heard")
	await wait(p1_wait_hint_delay)
	say_in_background("p1_wait_hint", PUZZLE_1)
#endregion

#region - PUZZLE 2
func _run_puzzle_2() -> void:
	GameState.parent_location_changed.connect(_on_puzzle_2_parent_moved)
	await wait_event(&"keepsake_box_fell")
	GameState.parent_location_changed.disconnect(_on_puzzle_2_parent_moved)
	await say_fight("p2_box_fight", PUZZLE_2)
	household.get_hall_parent(DAD).speed_scale = p1_storm_pace
	household.send(DAD, p2_storms_to, p2_apart_minutes)
	GameState.restore_memory()
	await wait(p2_lingers_seconds)
	household.send(MOM, p2_lingers_then_to, p2_apart_minutes)
	say_in_background("p2_after", PUZZLE_2)
	GameState.set_story_stage(3)

func _on_puzzle_2_parent_moved(parent_id: StringName, location: StringName) -> void:
	if parent_id == DAD and location == &"garage" and _leanne_free_for_coffee():
		_send_leanne_for_coffee()

func _send_leanne_for_coffee() -> void:
	if GameState.has_flag(CoffeeStation.FULL_FLAG):
		household.send(MOM, &"kitchen", p2_coffee_drink_minutes, [], &"drinking_coffee")
	else:
		household.send(MOM, &"kitchen", p2_coffee_make_minutes, [[&"kitchen", \
			p2_coffee_drink_minutes, &"drinking_coffee"]], &"making_coffee")

func _on_coffee_activity(parent_id: StringName, activity: StringName) -> void:
	if parent_id != MOM:
		return
	if _mom_activity == &"making_coffee" and activity == &"drinking_coffee":
		GameState.set_flag(CoffeeStation.FULL_FLAG)
	elif _mom_activity == &"drinking_coffee" and activity != &"drinking_coffee":
		GameState.clear_flag(CoffeeStation.FULL_FLAG)
	_mom_activity = activity

func _on_coffee_hour(_day: int, hour: int) -> void:
	if hour == 5:
		GameState.clear_flag(CoffeeStation.FULL_FLAG)

func _leanne_free_for_coffee() -> bool:
	return GameState.get_parent_location(MOM) == &"parent_bedroom" \
		and GameState.get_parent_activity(MOM) != &"changing"
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
	var due: Array = [[p3_new_day_hour * 60, _p3_new_day], [_to_minutes(p3_pill_time), _p3_pill_time]]
	for time_text in p3_drink_times:
		due.append([_to_minutes(time_text), _p3_drink_time])
	due = due.filter(func(item: Array) -> bool: return _crossed(previous, minute, item[0]))
	due.sort_custom(func(a: Array, b: Array) -> bool:
		return posmod(a[0] - previous, 1440) < posmod(b[0] - previous, 1440))
	for item in due:
		(item[1] as Callable).call(item[0])

func _p3_drink_time(at: int) -> void:
	if household.scheduled_location_at(DAD, at) != &"living_room":
		return
	for can in p3_beer_cans:
		if not GameState.has_flag(can):
			GameState.set_flag(can)
			_p3_drinks += 1
			_play_beer_can()
			return
	say_in_background("p3_david_no_beer", PUZZLE_3)

func _play_beer_can() -> void:
	if GameState.controls_locked:
		return
	if GameState.is_in_room() and GameState.current_room != &"living_room":
		return
	_sfx.stream = BEER_CAN_SOUND
	_sfx.volume_db = 0.0 if GameState.current_room == &"living_room" else -10.0
	_sfx.play()

func _p3_pill_time(at: int) -> void:
	if household.scheduled_location_at(MOM, at) != &"parent_bedroom":
		return
	if GameState.has_flag(&"pills_hidden"):
		say_in_background("p3_leanne_no_pills", PUZZLE_3)
	else:
		_p3_medicated = true

func _p3_new_day(_at: int = 0) -> void:
	_p3_medicated = false
	_p3_drinks = 0
	GameState.clear_flag(&"pills_hidden")
	for can in p3_beer_cans:
		GameState.clear_flag(can)

func _p3_try_night() -> bool:
	if not _is_night():
		say_in_background("p3_noise_daytime", PUZZLE_3)
		GameState.add_near_miss()
		return false
	if _p3_drinks >= p3_drunk_at:
		say_in_background("p3_david_passed_out", PUZZLE_3)
		GameState.add_near_miss()
		return false
	say_in_background("p3_david_wakes", PUZZLE_3)
	await wait_room(&"")
	await wait(p3_wake_delay)
	household.get_hall_parent(DAD).speed_scale = p1_storm_pace
	household.send(DAD, &"parent_bedroom", p3_safe_minutes, [], &"opening_safe")
	await wait_parent(DAD, &"parent_bedroom")
	await wait_room(&"parent_bedroom")
	if _p3_medicated and not GameState.has_flag(&"pills_hidden"):
		await say("p3_safe_alone", true, PUZZLE_3)
		GameState.add_near_miss()
		household.send(DAD, &"living_room", 60)
		return false
	GameState.set_story_stage(4)
	await say_fight("p3_safe_fight", PUZZLE_3)
	household.send(DAD, &"living_room", 120)
	GameState.restore_memory()
	say_in_background("p3_after", PUZZLE_3)
	return true

func _is_night() -> bool:
	var now := GameClock.minute
	return now >= _to_minutes(p3_night_starts) or now < _to_minutes(p3_night_ends)

static func _crossed(from: int, to: int, at: int) -> bool:
	if to >= from:
		return at > from and at <= to
	return at > from or at <= to
#endregion

#region - PUZZLE 4
func _run_puzzle_4() -> void:
	var told := false
	while true:
		await wait_room(&"emily_bedroom")
		if _p4_can_see():
			break
		if told:
			say_in_background("p4_still_dark", PUZZLE_4)
		else:
			await say("p4_too_dark", true, PUZZLE_4)
			told = true
		if await _p4_wait_for_light():
			await wait(p4_lights_settle)
			break
	await say("p4_room_reveal", true, PUZZLE_4)
	GameState.set_flag(&"emily_room_revealed")
	GameState.next_hint_step()
	await wait_room(&"emily_bedroom")
	await wait_event(&"diary_finished")
	GameState.set_story_stage(5)
	GameState.restore_memory()
	await say("p4_after", false, PUZZLE_4)

func _p4_can_see() -> bool:
	if GameState.has_flag(&"string_lights_on"):
		return true
	return DAY_NIGHT.sun_energy.sample(GameClock.get_day_fraction()) >= p4_light_enough

func _p4_wait_for_light() -> bool:
	while GameState.current_room == &"emily_bedroom":
		if _p4_can_see():
			return true
		await get_tree().process_frame
	return false
#endregion

#region - FINALE
func _run_finale() -> void:
	await wait_room(&"living_room")
	say_in_background("p5_creature_seen", PUZZLE_5)
	await wait_event(&"creature_faced")
	await say("p5_face_it", true, PUZZLE_5)
	await _accept_creature()
	say_in_background("p5_accepted", PUZZLE_5)
	await wait_event(&"front_door_opened")
	await _play_ending()

func _accept_creature() -> void:
	_accept_progress = 0.0
	GameState.set_controls_locked(true)
	prompt("Forgive yourself.   " + Settings.struggle_hint())
	Events.struggle_changed.emit(0.001)
	await accept_finished
	_accept_progress = -1.0
	GameState.set_flag(&"creature_accepted")
	prompt("")
	Events.struggle_changed.emit(0.0)
	GameState.set_controls_locked(false)

func _play_ending() -> void:
	Settings.game_completed = true
	Settings.save_settings()
	GameState.clear_checkpoint()
	GameState.set_controls_locked(true)
	if ending_song:
		Music.play(ending_song, p5_light_seconds, 0.0, db_to_linear(ending_song_db))
	else:
		Music.stop(p5_light_seconds)
	await wait(p5_light_seconds)
	fade.color = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, p5_white_seconds)
	tween.tween_interval(p5_white_hold)
	await tween.finished
	if p5_fight_audio:
		Music.play(p5_fight_audio, p5_to_black_seconds)
	GameState.set_controls_locked(false)
	RenderingServer.set_default_clear_color(Color.WHITE)
	get_tree().change_scene_to_file(CREDITS_SCENE)

func _debug_jump_to_finale() -> void:
	while GameState.max_bars < 5:
		GameState.restore_memory()
	GameState.set_story_stage(5)
	_run_finale()

func _debug_next_stage() -> void:
	GameState.set_story_stage(GameState.story_stage + 1)
	GameState.restore_memory()
	GameState.exit_astral()
	GameState.set_controls_locked(false)
	get_tree().reload_current_scene()
#endregion

func _on_any_story_event(id: StringName) -> void:
	match id:
		&"wait_hour":
			_ask_wait()
		&"lose_hour":
			_skip_hour()
		&"coffee_spilled":
			GameState.clear_flag(CoffeeStation.FULL_FLAG)
		&"coffee_on_leanne":
			GameState.clear_flag(CoffeeStation.FULL_FLAG)
			say_in_background("p2_leanne_coffee", PUZZLE_2)
			household.send(MOM, &"parent_bedroom", p2_change_minutes, [[&"garage", \
				p2_laundry_minutes, &"laundry"]], &"changing")
		&"david_checks_breaker":
			say_in_background("p2_david_breaker", PUZZLE_2)
			household.send(DAD,  &"garage", p2_breaker_minutes, [], &"checking_breaker")

func _ask_wait() -> void:
	if _waiting or _wait_popup.visible:
		return
	var choice: StringName = await _wait_popup.ask(night_time, morning_time)
	match choice:
		&"hour":
			await _wait_minutes(60)
		&"night":
			await _wait_minutes(_minutes_until(night_time))
		&"morning":
			await _wait_minutes(_minutes_until(morning_time))

func _wait_minutes(minutes: int) -> void:
	if _waiting or minutes <= 0:
		return
	_waiting = true
	GameState.set_controls_locked(true)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, wait_fade_time)
	await tween.finished
	_skip_minutes(minutes)
	GameState.refill_energy()
	await wait(0.3)
	tween = create_tween()
	tween.tween_property(fade, "color:a", 0.0, wait_fade_time)
	await tween.finished
	GameState.set_controls_locked(false)
	_waiting = false

func _minutes_until(time_text: String) -> int:
	return posmod(_to_minutes(time_text) - GameClock.minute, GameClock.MINUTES_PER_DAY)

func _skip_hour() -> void:
	_skip_minutes(60)

func _skip_minutes(minutes: int) -> void:
	Events.dialogue_interrupt_requested.emit()
	GameClock.set_time(GameClock.day, GameClock.minute + minutes)
	household.settle_everyone()
	Events.time_skipped.emit()
#endregion

#region - BEAT HELPERS
func say(cue: String, frozen: bool = false, dialogue: DialogueResource = INTRO) -> void:
	if frozen:
		GameState.exit_astral()
	_finished.erase(cue)
	Events.conversation_requested.emit(dialogue, cue, frozen)
	while not _finished.has(cue):
		await seen_conversation_end

func say_in_background(cue: String, dialogue: DialogueResource = INTRO) -> void:
	Events.conversation_requested.emit(dialogue, cue, false)

func say_fight(cue: String, dialogue: DialogueResource) -> void:
	player.watch({
		"Leanne": household.get_hall_parent(MOM),
		"David": household.get_hall_parent(DAD)
	})
	room_view.follow_speakers(true)
	await say(cue, true, dialogue)
	player.watch({})
	room_view.follow_speakers(false)

func stage_fight(leanne_mark: StringName, david_mark: StringName) -> void:
	GameState.exit_astral()
	GameState.set_controls_locked(true)
	var middle := arrange_fight(leanne_mark, david_mark)
	player.face_toward(middle + Vector3.UP * FIGHT_EYE_HEIGHT, 0.6)
	Events.parents_staged.emit(MOM, leanne_mark)
	Events.parents_staged.emit(DAD, david_mark)
	var mom := household.get_hall_parent(MOM)
	var dad := household.get_hall_parent(DAD)
	var waited := 0.0
	while waited < fight_walk_timeout and not (_stands_at(mom, leanne_mark) and _stands_at(dad, david_mark)):
		await get_tree().process_frame
		waited += get_process_delta_time()

func _stands_at(parent: HallParent, mark_id: StringName) -> bool:
	if parent == null or not parent.visible:
		return true
	return parent.standing_at != null and parent.standing_at.mark_id == mark_id

func arrange_fight(leanne_mark: StringName, david_mark: StringName) -> Vector3:
	var marks: Array[HallMark] = [_find_mark(leanne_mark), _find_mark(david_mark)]
	if marks[0] == null or marks[1] == null:
		return player.global_position
	var center := (marks[0].global_position + marks[1].global_position) * 0.5
	var sight := center - player.global_position
	sight.y = 0.0
	if sight.length() < fight_keep_away:
		var camera := player.get_viewport().get_camera_3d()
		sight = -camera.global_basis.z if camera else Vector3.FORWARD
		sight.y = 0.0
	sight = sight.normalized()
	var flat_offset := center - player.global_position
	flat_offset.y = 0.0
	var min_center := fight_keep_away + fight_gap * 0.5
	if flat_offset.length() < min_center:
		center = _clear_push(center, sight, min_center)
	var across := Vector3(-sight.z, 0.0, sight.x) * fight_gap * 0.5
	var spots: Array[Vector3] = []
	var stagger := fight_stagger
	for attempt in 6:
		var ahead := sight * stagger * 0.5
		var tried: Array[Vector3] = [
			_fight_spot(center + across + ahead, center, fight_keep_away),
			_fight_spot(center - across - ahead, center, fight_keep_away)
		]
		if spots.is_empty() or tried[0].distance_to(tried[1]) > spots[0].distance_to(spots[1]):
			spots = tried
		if spots[0].distance_to(spots[1]) >= fight_min_apart:
			break
		stagger += 0.4
	var mom := household.get_hall_parent(MOM)
	var dad := household.get_hall_parent(DAD)
	if mom and dad and mom.global_position.distance_to(spots[1]) + dad.global_position.distance_to(spots[0]) \
			< mom.global_position.distance_to(spots[0]) + dad.global_position.distance_to(spots[1]):
		spots.reverse()
	for i in marks.size():
		var spot := spots[i]
		spot.y = marks[i].global_position.y
		marks[i].global_position = spot
	return (spots[0] + spots[1]) * 0.5

func _fight_spot(spot: Vector3, center: Vector3, keep_away: float) -> Vector3:
	var away := spot - player.global_position
	away.y = 0.0
	if away.length() < keep_away:
		var push := away.normalized() if away.length() > 0.01 else Vector3.FORWARD
		spot = player.global_position + push * keep_away
	for step in FIGHT_PULL_STEPS + 1:
		var tried := _on_floor(center.lerp(spot, 1.0 - float(step) / FIGHT_PULL_STEPS))
		if _in_sight(center, tried) and _far_from_player(tried, keep_away):
			return tried
	return _on_floor(center)

func _clear_push(center: Vector3, sight: Vector3, distance: float) -> Vector3:
	var eye := Vector3.UP * FIGHT_EYE_HEIGHT
	var step := distance
	while step >= fight_keep_away:
		var tried := _on_floor(player.global_position + sight * step)
		if _clear_line(player.global_position + eye, tried + eye):
			return tried
		step -= 0.25
	return center

func _far_from_player(spot: Vector3, keep_away: float) -> bool:
	var offset := spot - player.global_position
	offset.y = 0.0
	return offset.length() >= keep_away * 0.9

func _on_floor(point: Vector3) -> Vector3:
	var on_floor := NavigationServer3D.map_get_closest_point(player.get_world_3d().navigation_map, point)
	return on_floor if on_floor != Vector3.ZERO else point

func _in_sight(center: Vector3, spot: Vector3) -> bool:
	var eye := Vector3.UP * FIGHT_EYE_HEIGHT
	if not _clear_line(center + eye, spot + eye):
		return false
	var camera := player.get_viewport().get_camera_3d()
	return camera == null or _clear_line(camera.global_position, spot + eye)

func _clear_line(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, FIGHT_WALL_LAYER, [player.get_rid()])
	return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _find_mark(mark_id: StringName) -> HallMark:
	for node in get_tree().get_nodes_in_group("hall_marks"):
		var mark := node as HallMark
		if mark and mark.mark_id == mark_id:
			return mark
	return null

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
	if _accept_progress >= 0.0 and event.is_action_pressed("struggle"):
		_accept_progress = minf(_accept_progress + 1.0 / p5_accept_presses, 1.0)
		Events.struggle_changed.emit(_accept_progress)
		if _accept_progress >= 1.0:
			accept_finished.emit()
		get_viewport().set_input_as_handled()
		return
	
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo \
	and event.keycode == KEY_END and GameState.has_flag(INTRO_DONE):
		get_viewport().set_input_as_handled()
		_debug_jump_to_finale()
	
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo \
	and event.keycode == KEY_F7 and GameState.has_flag(INTRO_DONE):
		get_viewport().set_input_as_handled()
		_debug_next_stage()
#endregion
