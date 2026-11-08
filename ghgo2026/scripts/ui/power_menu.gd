class_name PowerMenu
extends VBoxContainer

@export var dim_alpha: float = 0.5
@export var row_size := Vector2(300, 40)
@export var cost_bar_size := Vector2(36, 10)
@export var cost_bar_gap: float = 4.0
@export var cost_bar_color := Color(0.0, 0.6, 0.6)

var _fill_style: StyleBoxFlat

func _ready() -> void:
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_END
	_fill_style = StyleBoxFlat.new()
	_fill_style.bg_color = cost_bar_color
	Powers.target_changed.connect(func(_id: StringName) -> void: _rebuild())
	Powers.selection_changed.connect(func(_index: int) -> void: _refresh())
	GameState.plane_changed.connect(func(_astral: bool) -> void: _rebuild())
	GameState.max_bars_changed.connect(func(_bars: int) -> void: _rebuild())
	GameState.energy_changed.connect(func(_e: float, _m: int) -> void: _refresh())
	_rebuild()

func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	visible = Powers.target != &"" and GameState.in_astral
	if not visible:
		return

	var in_room := GameState.is_in_room()
	var powers := Powers.get_unlocked()
	for i in powers.size():
		var power := powers[i]
		var button := Button.new()
		button.custom_minimum_size = row_size
		button.text = "%d   %s" % [i + 1, power.display_name]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP if in_room else Control.MOUSE_FILTER_IGNORE
		button.pressed.connect(func() -> void:
			Powers.select(i)
			Powers.use_selected())
		button.add_child(_make_cost_bars(power.energy_cost))
		add_child(button)
	_refresh()

func _refresh() -> void:
	var powers := Powers.get_unlocked()
	for i in get_child_count():
		var button := get_child(i) as Button
		button.disabled = not GameState.can_afford(powers[i].energy_cost)
		button.modulate.a = 1.0 if i == Powers.selected else dim_alpha

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
		var bar := ProgressBar.new()
		bar.custom_minimum_size = cost_bar_size
		bar.size = cost_bar_size
		bar.position = Vector2(i * (cost_bar_size.x + cost_bar_gap), 0.0)
		bar.max_value = 1.0
		bar.step = 0.0
		bar.value = clampf(remaining, 0.0, 1.0)
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("fill", _fill_style)
		holder.add_child(bar)
		remaining -= 1.0
	return holder
