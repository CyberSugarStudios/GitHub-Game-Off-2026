class_name DoorLock
extends Node

signal progress_changed(progress: float)
signal unlocked
signal failed

const DOOR_LINES := preload("res://dialogue/doors.dialogue")
const FEEDBACK_SECONDS := 1.5
const DRAIN_DELAY := 0.3
const DRAIN_SECONDS := 0.5
const UNLOCK_SOUNDS: Array[AudioStream] = [
	preload("res://assets/audio/sfx/unlocking/Unlocking 2.wav"),
	preload("res://assets/audio/sfx/unlocking/Unlocking 3.wav"),
	preload("res://assets/audio/sfx/unlocking/Unlocking 4.wav"),
	preload("res://assets/audio/sfx/unlocking/Unlocking 5.wav"),
	preload("res://assets/audio/sfx/unlocking/Unlocking.wav"),
]
const CLICK_AT := 3.15
const RING_OUT_SECONDS := 1.05
const FAIL_FADE_SECONDS := 0.2

var door_id: StringName
var lock_bars := 0
var transfer_rate := 1.5
var progress := 0.0
var transferring := false

var _feedback_left := 0.0
var _drain: Tween
var _sound: AudioStreamPlayer
var _sound_fade: Tween

func setup(id: StringName, bars: int, rate: float) -> void:
	door_id = id
	lock_bars = bars
	transfer_rate = rate

func _ready() -> void:
	_sound = AudioStreamPlayer.new()
	_sound.bus = &"SFX"
	add_child(_sound)

func is_locked() -> bool:
	return lock_bars > 0 and not GameState.has_flag(unlock_flag())

func unlock_flag() -> StringName:
	return StringName("door_unlocked_%s" % door_id)

func is_showing_feedback() -> bool:
	return transferring or _feedback_left > 0.0

func start() -> void:
	if is_locked():
		if _drain:
			_drain.kill()
		transferring = true
		_play_sound()

func _process(delta: float) -> void:
	_feedback_left = maxf(_feedback_left - delta, 0.0)

func _physics_process(delta: float) -> void:
	if not transferring:
		return
	var wanted := minf(transfer_rate * delta, lock_bars - progress)
	var spent := minf(wanted, GameState.energy)
	if spent > 0.0:
		GameState.try_spend(spent)
		_set_progress(progress + spent)
	if progress >= lock_bars - GameState.ENERGY_EPSILON:
		_finish()
	elif spent < wanted - GameState.ENERGY_EPSILON:
		_fail()

func _finish() -> void:
	transferring = false
	_feedback_left = FEEDBACK_SECONDS
	_set_progress(lock_bars)
	GameState.set_flag(unlock_flag())
	unlocked.emit()
	_fade_sound(RING_OUT_SECONDS)

func _fail() -> void:
	transferring = false
	_feedback_left = FEEDBACK_SECONDS
	failed.emit()
	_fade_sound(FAIL_FADE_SECONDS)
	_drain = create_tween()
	_drain.tween_interval(DRAIN_DELAY)
	_drain.tween_method(_refund_to, progress, 0.0, DRAIN_SECONDS).set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN)
	_play_fail_line()

func _refund_to(value: float) -> void:
	var returned := progress - value
	_set_progress(value)
	GameState.refund(returned)

func _play_fail_line() -> void:
	var cues := DOOR_LINES.get_cues()
	for cue in ["%s_locked_stage%d" % [door_id, GameState.story_stage], "%s_locked" % door_id, "locked"]:
		if cue in cues:
			Events.conversation_requested.emit(DOOR_LINES, cue, false)
			return

func _set_progress(value: float) -> void:
	progress = clampf(value, 0.0, lock_bars)
	progress_changed.emit(progress)

#region - SOUND
func _play_sound() -> void:
	if transfer_rate <= 0.0:
		return
	var fill_seconds := (lock_bars - progress) / transfer_rate
	if _sound_fade:
		_sound_fade.kill()
	_sound.volume_db = 0.0
	_sound.stream = UNLOCK_SOUNDS.pick_random()
	_sound.play(maxf(CLICK_AT - fill_seconds, 0.0))

func _fade_sound(seconds: float) -> void:
	if not _sound.playing:
		return
	if _sound_fade:
		_sound_fade.kill()
	_sound_fade = create_tween()
	_sound_fade.tween_property(_sound, "volume_db", -40.0, seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_sound_fade.tween_callback(_sound.stop)
#endregion
