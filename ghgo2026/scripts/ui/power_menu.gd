class_name PowerMenu
extends VBoxContainer

const KEY_PROMPT := preload("res://scenes/ui/key_prompt.tscn")
const CLICK_SHEET := preload("res://assets/sprites/ui/clicking.webp")
const TAUGHT_FLAG := &"power_click_taught"

@export var row_size := Vector2(300, 40)
@export var cost_bar_size := Vector2(36, 18)
@export var cost_bar_gap: float = 4.0
@export var anchor_gap: float = 16.0
@export var screen_margin: float = 12.0

var _home: Array[float] = []
var _buttons: Array[Button] = []

func _ready() -> void:
	_home = [offset_left, offset_top, offset_right, offset_bottom]
	Events.power_used.connect(func(_power: StringName, _target: StringName) -> void:
		if not GameState.has_flag(TAUGHT_FLAG):
			GameState.set_flag(TAUGHT_FLAG))
	grow_horizontal = Control.GROW_DIRECTION_END
	Powers.target_changed.connect(
		func(_id: StringName) -> void:
			_rebuild())
	Powers.selection_changed.connect(
		func(_index: int) -> void:
			_refresh())
	GameState.plane_changed.connect(
		func(_astral: bool) -> void:
			_rebuild())
	GameState.max_bars_changed.connect(
		func(_bars: int) -> void:
			_rebuild())
	GameState.flag_set.connect(
		func(_id: StringName) -> void:
			_rebuild())
	GameState.energy_changed.connect(
		func(_e: float, _m: int) -> void:
			_refresh())
	_rebuild()

func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	visible = Powers.target != &"" and GameState.in_astral
	if not visible:
		return

	var in_room := GameState.is_in_room()
	var powers := Powers.get_usable()
	_buttons.clear()
	if in_room and not GameState.has_flag(TAUGHT_FLAG):
		var hint := KEY_PROMPT.instantiate() as KeyPrompt
		hint.font_size = 22
		hint.icon_height = 48.0
		hint.icon_frames = 7
		hint.icon_fps = 4.5
		hint.icon_sheet = CLICK_SHEET
		hint.show_prompt("", "Choose a power")
		add_child(hint)
	for i in powers.size():
		var power := powers[i]
		var button := Button.new()
		button.custom_minimum_size = row_size
		button.text = power.display_name
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP if in_room else Control.MOUSE_FILTER_IGNORE
		button.pressed.connect(
			func() -> void:
				Powers.select(i)
				Powers.use_selected())
		button.add_child(_make_cost_bars(power.energy_cost))
		add_child(button)
		_buttons.append(button)
	_refresh()

func _process(_delta: float) -> void:
	if not visible:
		return
	var anchor := Powers.target_anchor
	if GameState.is_in_room() and is_instance_valid(anchor) and anchor.is_inside_tree():
		_place_beside(anchor.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, anchor.size))
	elif offset_left != _home[0] or offset_top != _home[1]:
		offset_left = _home[0]
		offset_top = _home[1]
		offset_right = _home[2]
		offset_bottom = _home[3]

func _place_beside(item: Rect2) -> void:
	var menu := get_combined_minimum_size()
	var view := get_viewport_rect().size
	var x := item.end.x + anchor_gap
	if x + menu.x > view.x - screen_margin:
		x = item.position.x - anchor_gap - menu.x
	var y := item.get_center().y - menu.y * 0.5
	global_position = Vector2(
		clampf(x, screen_margin, view.x - menu.x - screen_margin),
		clampf(y, screen_margin, view.y - menu.y - screen_margin))

func _refresh() -> void:
	var powers := Powers.get_usable()
	for i in _buttons.size():
		var button := _buttons[i]
		button.disabled = not GameState.can_afford(powers[i].energy_cost)
		var marker := ""
		if not GameState.is_in_room():
			marker = "> " if i == Powers.selected else "   "
		button.text = marker + powers[i].display_name

func _make_cost_bars(cost: float) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if cost <= 0.0:
		return holder
	
	var count := ceili(cost - 0.001)
	var total_width := count * cost_bar_size.x + (count - 1) * cost_bar_gap
	holder.position = Vector2(row_size.x - total_width - 10.0, (row_size.y - cost_bar_size.y) / 2.0)
	
	var remaining := cost
	for i in count:
		var bar := PillBar.new()
		bar.custom_minimum_size = cost_bar_size
		bar.size = cost_bar_size
		bar.position = Vector2(i * (cost_bar_size.x + cost_bar_gap), 0.0)
		bar.value = clampf(remaining, 0.0, 1.0)
		holder.add_child(bar)
		remaining -= 1.0
	return holder
