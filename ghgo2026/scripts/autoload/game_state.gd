extends Node #Global game state (GameState)

#region - INIT
#region - SIGNALS
signal energy_changed(energy: float, max_bars: int)
signal max_bars_changed(max_bars: int)
signal plane_changed(in_astral: bool)
signal forced_out_of_astral
signal flag_set(id: StringName)

#region - CONSTS
const STARTING_BARS := 1
const MAX_POSSIBLE_BARS := 5
const ASTRAL_DRAIN_PER_METER := 0.04 #0.04 = 25 m
const LIVING_REGEN_PER_SECOND := 0.1 #regen outside of the stral 0.1 = 10s
const MIN_ENERGY_TO_ENTER_ASTRAL := 1.0 #one full bar recharge required

#region - VARS
var max_bars: int = STARTING_BARS #door check
var energy: float = STARTING_BARS #powers and astral drains this
var in_astral: bool = false
var flags: Dictionary[StringName, bool]  = {}
#endregion
#endregion
#endregion
#endregion

func _process(delta: float) -> void:
	if not in_astral and energy < max_bars:
		_set_energy(energy + LIVING_REGEN_PER_SECOND * delta)

func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and \
	event.keycode == KEY_F1:
		restore_memory()

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
	if not in_astral or meters <= 0.0:
		return
	_set_energy(energy - meters * ASTRAL_DRAIN_PER_METER)
	if energy <= 0.0:
		exit_astral()
		forced_out_of_astral.emit()

func has_unlocked_bars(required: int) -> bool:
	return max_bars >= required

func can_afford(cost: float) -> bool:
	return energy >= cost

func try_spend(cost: float) -> bool:
	if not can_afford(cost):
		return false
	_set_energy(energy - cost)
	return true

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
#endregion

func reset() -> void:
	max_bars = STARTING_BARS
	in_astral = false
	max_bars_changed.emit(max_bars)
	plane_changed.emit(false)
	_set_energy(max_bars)
	flags.clear()

func _set_energy(value: float) -> void:
	var clamped := clampf(value, 0.0, max_bars)
	if is_equal_approx(clamped, energy):
		return
	energy = clamped
	energy_changed.emit(energy, max_bars)
