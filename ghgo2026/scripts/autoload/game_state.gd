extends Node #Global game state (GameState)

#region - INIT
#region - SIGNALS
signal energy_changed(energy: float, max_bars: int)
signal max_bars_changed(max_bars: int)
signal plane_changed(in_astral: bool)
signal forced_out_of_astral
signal flag_set(id: StringName)
signal flag_cleared(id: StringName)
signal room_changed(room_id: StringName) #&"" should mean the hall
signal controls_locked_changed(locked: bool)
signal parent_location_changed(parent_id: StringName, location: StringName)
signal story_stage_changed(stage: int)
signal monster_level_changed(level: int)
signal parent_activity_changed(parent_id: StringName, activity: StringName)

#region - CONSTS
const STARTING_BARS := 1
const MAX_POSSIBLE_BARS := 5
const ASTRAL_DRAIN_PER_METER := 0.04 #0.04 = 25 m
const LIVING_REGEN_PER_SECOND := 0.5 #regen outside of the astral | 0.1 = 10s, 0.5 = 2s, 0.25 = 4s
const ASTRAL_REGEN_PER_SECOND := 0.05 #slow tricking in the astral
const MIN_ENERGY_TO_ENTER_ASTRAL := 0.25 #a quarter bar recharge required
const ENERGY_EPSILON := 0.001
const HALL := &"hall"
const BUS_LAYOUT := preload("res://default_bus_layout.tres")
const HINT_HOURS_PER_LEVEL := 3.0
const MAX_HINT_LEVEL := 3
const HINT_PER_NEAR_MISS := 0.5
const SAVE_PATH := "user://save.cfg"
const SAVE_VERSION := 1

#region - VARS
var max_bars := STARTING_BARS #door check
var energy: float = STARTING_BARS #powers and astral drains this
var in_astral: bool = false
var flags: Dictionary[StringName, bool]  = {}
var _awake_until: Dictionary[StringName, int] = {}
var _held: Dictionary[StringName, bool] = {}
var current_room: StringName = &""
var controls_locked := false
var parent_locations: Dictionary[StringName, StringName] = {}
var parent_activities: Dictionary[StringName, StringName] = {}
var story_stage := 0
var monster_level := 0
var _stage_started_at := 0
var _hint_bonus := 0.0
var hint_step := 0
var overlay_open := false
var shift_allowed := true
var regen_paused := false
var guarded_room: StringName = &""
#endregion
#endregion
#endregion
#endregion

func _enter_tree() -> void:
	if AudioServer.get_bus_index(&"Music") == -1:
		AudioServer.set_bus_layout(BUS_LAYOUT)

func _process(delta: float) -> void:
	if energy >= max_bars or regen_paused:
		return
	var rate := ASTRAL_REGEN_PER_SECOND if in_astral else LIVING_REGEN_PER_SECOND
	_set_energy(energy + rate * delta)

func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and \
	event.keycode == KEY_F1:
		restore_memory()
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and \
	event.keycode == KEY_F6:
		_hint_bonus += 1.0
		print("Hint level: ", get_hint_level())

#region - HOUSEHOLD
func set_parent_location(parent_id: StringName, location: StringName) -> void:
	if parent_locations.get(parent_id, &"") == location:
		return
	parent_locations[parent_id] = location
	if OS.is_debug_build():
		print("[%s] %s > %s" % [GameClock.get_time_text(), parent_id, location])
	parent_location_changed.emit(parent_id, location)

func get_parent_location(parent_id: StringName) -> StringName:
	return parent_locations.get(parent_id, &"")

func set_parent_activity(parent_id: StringName, activity: StringName) -> void:
	if parent_activities.get(parent_id, &"") == activity:
		return
	parent_activities[parent_id] = activity
	parent_activity_changed.emit(parent_id, activity)

func get_parent_activity(parent_id: StringName) -> StringName:
	return parent_activities.get(parent_id, &"")

func set_story_stage(stage: int) -> void:
	if story_stage == stage:
		return
	story_stage = stage
	restart_stage_timer()
	story_stage_changed.emit(stage)
	if stage >= 1:
		save_checkpoint()

func restart_stage_timer() -> void:
	_stage_started_at = GameClock.get_total_minutes()
	_hint_bonus = 0.0
	hint_step = 0

func next_hint_step() -> void:
	var step := hint_step + 1
	restart_stage_timer()
	hint_step = step

func set_monster_level(level: int) -> void:
	if monster_level == level:
		return
	monster_level = level
	monster_level_changed.emit(level)

func get_hint_level() -> int:
	var hours := (GameClock.get_total_minutes() - _stage_started_at) / 60.0
	return clampi(floori(hours / HINT_HOURS_PER_LEVEL + _hint_bonus), 0, MAX_HINT_LEVEL)

func add_near_miss(source: StringName = &"") -> void:
	_hint_bonus += HINT_PER_NEAR_MISS
	Events.near_missed.emit(source)

func raise_hint_level() -> void:
	if get_hint_level() < MAX_HINT_LEVEL:
		_hint_bonus += 1.0
#endregion

#region - PLANE
func toggle_plane() -> void:
	if in_astral:
		exit_astral()
	else:
		enter_astral()

func enter_astral() -> bool:
	if in_astral:
		return true
	if energy < MIN_ENERGY_TO_ENTER_ASTRAL:
		return false
	in_astral = true
	plane_changed.emit(in_astral)
	return true

func exit_astral() -> void:
	if not in_astral:
		return
	in_astral = false
	plane_changed.emit(in_astral)
#endregion

#region - ASTRAL BARS
func drain_for_movement(meters: float) -> void:
	drain(meters * ASTRAL_DRAIN_PER_METER)

func drain(amount: float, any_plane: bool = false) -> void:
	if (not in_astral and not any_plane) or amount <= 0.0:
		return
	_set_energy(energy - amount)
	if energy <= 0.0 and in_astral:
		exit_astral()
		forced_out_of_astral.emit() 

func refill_energy() -> void:
	_set_energy(max_bars)

func has_unlocked_bars(required: int) -> bool:
	return max_bars >= required

func can_afford(cost: float) -> bool:
	return energy >= cost - ENERGY_EPSILON

func try_spend(cost: float) -> bool:
	if not can_afford(cost):
		return false
	_set_energy(energy - cost)
	return true

func refund(amount: float) -> void:
	if amount > 0.0:
		_set_energy(energy + amount)

func restore_memory() -> void:
	if max_bars >= MAX_POSSIBLE_BARS:
		return
	max_bars += 1
	max_bars_changed.emit(max_bars)
	_set_energy(max_bars)
#endregion

#region - FLAGS
func set_flag(id: StringName) -> void:
	if flags.has(id):
		return
	flags[id] = true
	flag_set.emit(id)

func has_flag(id: StringName) -> bool:
	return flags.has(id)

func clear_flag(id: StringName) -> void:
	if flags.erase(id):
		flag_cleared.emit(id)
#endregion

#region - ROOMS
func enter_room(room_id: StringName) -> void:
	current_room = room_id
	room_changed.emit(room_id)

func leave_room() -> void:
	if current_room == &"":
		return
	current_room = &""
	room_changed.emit(&"")

func is_in_room() -> bool:
	return current_room != &""

func set_controls_locked(locked: bool) -> void:
	if controls_locked == locked:
		return
	controls_locked = locked
	controls_locked_changed.emit(locked)
#endregion

func reset() -> void:
	max_bars = STARTING_BARS
	in_astral = false
	max_bars_changed.emit(max_bars)
	plane_changed.emit(false)
	_set_energy(max_bars)
	flags.clear()
	current_room = &""
	controls_locked = false
	parent_locations.clear()
	parent_activities.clear()
	story_stage = 0
	monster_level = 0
	_hint_bonus = 0.0
	shift_allowed = true
	regen_paused = false
	guarded_room = &""
	_awake_until.clear()
	_held.clear()

func keep_awake(parent_id: StringName, minutes: int) -> void:
	_awake_until[parent_id] = GameClock.get_total_minutes() + minutes

func hold_parent(parent_id: StringName, on: bool) -> void:
	if on:
		_held[parent_id] = true
	else:
		_held.erase(parent_id)

func is_parent_held(parent_id: StringName) -> bool:
	return _held.has(parent_id)

func is_parent_asleep(parent_id: StringName) -> bool:
	if is_kept_awake(parent_id) or get_parent_location(parent_id) == HALL:
		return false
	var activity := String(get_parent_activity(parent_id))
	if activity == "sleeping":
		return true
	if not activity.contains("sleep"):
		return false
	var hour := GameClock.get_day_fraction() * 24.0
	return hour >= 23.0 or hour < 6.0

func is_kept_awake(parent_id: StringName) -> bool:
	if has_flag(StringName("hugged_%s" % parent_id)):
		return true
	return GameClock.get_total_minutes() < _awake_until.get(parent_id, -1)

#region - SAVING
func save_checkpoint() -> void:
	var config := ConfigFile.new()
	config.set_value("save", "version", SAVE_VERSION)
	config.set_value("save", "story_stage", story_stage)
	config.set_value("save", "max_bars", max_bars)
	config.set_value("save", "flags", PackedStringArray(flags.keys()))
	config.save(SAVE_PATH)

func has_checkpoint() -> bool:
	var config := ConfigFile.new()
	return config.load(SAVE_PATH) == OK and config.get_value("save", "version", 0) == SAVE_VERSION

func load_checkpoint() -> bool:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK or config.get_value("save", "version", 0) != SAVE_VERSION:
		return false
	reset()
	story_stage = config.get_value("save", "story_stage", 0)
	max_bars = config.get_value("save", "max_bars", STARTING_BARS)
	for flag: String in config.get_value("save", "flags", PackedStringArray()):
		flags[StringName(flag)] = true
	max_bars_changed.emit(max_bars)
	_set_energy(max_bars)
	return true

func clear_checkpoint() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
#endregion

func _set_energy(value: float) -> void:
	var clamped := clampf(value, 0.0, max_bars)
	if value > energy and clamped > max_bars - ENERGY_EPSILON:
		clamped = max_bars
	if clamped == energy:
		return
	energy = clamped
	energy_changed.emit(energy, max_bars)
