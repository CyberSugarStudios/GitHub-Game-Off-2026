class_name DoorLock
extends Node

signal progress_changed(progress: float)
signal unlocked
signal failed

const DOOR_LINES := preload("res://dialogue/doors.dialogue")
const FEEDBACK_SECONDS := 1.5

var door_id: StringName
var lock_bars := 0
var transfer_rate := 1.5
var progress := 0.0
var transferring := false

var _feedback_left := 0.0

func setup(id: StringName, bars: int, rate: float) -> void:
	door_id = id
	lock_bars = bars
	transfer_rate = rate

func is_locked() -> bool:
	return lock_bars > 0 and not GameState.has_flag(unlock_flag())

func unlock_flag() -> StringName:
	return StringName("door_unlocked_%s" % door_id)

func is_showing_feedback() -> bool:
	return transferring or _feedback_left > 0.0

func start() -> void:
	if is_locked():
		transferring = true

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
	if progress >= lock_bars - 0.0001:
		_finish()
	elif spent < wanted:
		_fail()

func _finish() -> void:
	transferring = false
	_feedback_left = FEEDBACK_SECONDS
	_set_progress(lock_bars)
	GameState.set_flag(unlock_flag())
	unlocked.emit()

func _fail() -> void:
	transferring = false
	_feedback_left = FEEDBACK_SECONDS
	failed.emit()
	var drain := create_tween()
	drain.tween_interval(0.3)
	drain.tween_method(_set_progress, progress, 0.0, 0.5).set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN)
	_play_fail_line()

func _play_fail_line() -> void:
	var cues := DOOR_LINES.get_cues()
	var cue := "%s_locked" % door_id
	if not cue in cues:
		cue = "locked"
	if cue in cues:
		Events.conversation_requested.emit(DOOR_LINES, cue, false)

func _set_progress(value: float) -> void:
	progress = clampf(value, 0.0, lock_bars)
	progress_changed.emit(progress)
