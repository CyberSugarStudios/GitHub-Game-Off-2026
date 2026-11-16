extends Node

signal target_changed(parent_id: StringName)
signal selection_changed(index: int)

var all_powers: Array[Power] = [
	preload("res://data/powers/read_thoughts.tres"),
	preload("res://data/powers/chill.tres"),
	preload("res://data/powers/nudge.tres"),
	preload("res://data/powers/electrify.tres")
]

var target: StringName = &""
var target_accepts: Array[StringName] = []
var selected := 0

func _ready() -> void:
	GameState.room_changed.connect(
		func(_room: StringName) -> void:
			set_target(&""))
	GameState.plane_changed.connect(
		func(in_astral: bool) -> void:
			if not in_astral:
				set_target(&""))

func get_unlocked() -> Array[Power]:
	var result: Array[Power] = []
	for power in all_powers:
		if GameState.has_unlocked_bars(power.required_bars) \
			and InteractionRules.story_open(power.requires_flag, &""):
				result.append(power)
	return result

func get_usable() -> Array[Power]:
	var result: Array[Power] = []
	for power in get_unlocked():
		if target_accepts.is_empty():
			if power.on_parents:
				result.append(power)
		elif power.id in target_accepts:
			result.append(power)
	return result

func get_selected() -> Power:
	var usable := get_usable()
	if usable.is_empty():
		return null
	return usable[clampi(selected, 0, usable.size() - 1)]

func set_target(id: StringName, accepts: Array[StringName] = []) -> void:
	if target == id and target_accepts == accepts:
		return
	target = id
	target_accepts = accepts
	selected = 0
	target_changed.emit(id)

func select(index: int) -> void:
	var count := get_usable().size()
	if count == 0:
		return
	selected = clampi(index, 0, count - 1)
	selection_changed.emit(selected)

func cycle(step: int) -> void:
	var count := get_usable().size()
	if count > 0:
		select(posmod(selected + step, count))

func use_selected() -> bool:
	var power := get_selected()
	if target == &"" or power == null or not GameState.in_astral:
		return false
	if not GameState.try_spend(power.energy_cost):
		return false
	Events.power_used.emit(power.id, target)
	if GameState.is_in_room():
		set_target(&"")
	return true

func _unhandled_input(event: InputEvent) -> void:
	if target == &"":
		return
	if event is InputEventMouseButton and event.pressed:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle(-1)
		elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle(1)
		elif mouse.button_index == MOUSE_BUTTON_RIGHT and GameState.is_in_room():
			set_target(&"")
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key >= KEY_1 and key <= KEY_5:
			select(key - KEY_1)
			get_viewport().set_input_as_handled()
