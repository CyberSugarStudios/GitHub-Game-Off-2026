class_name PowerMenu
extends VBoxContainer

@export var dim_alpha: float = 0.5

func _ready() -> void:
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
	
	var powers := Powers.get_unlocked()
	for i in powers.size():
		var power := powers[i]
		var button := Button.new()
		button.text = "%d   %s   (%s bars)" % [i + 1, power.display_name, str(power.energy_cost)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void:
			Powers.select(i)
			Powers.use_selected())
		add_child(button)
	_refresh()

func _refresh() -> void:
	var powers := Powers.get_unlocked()
	for i in get_child_count():
		var button := get_child(i) as Button
		button.disabled = not GameState.can_afford(powers[i].energy_cost)
		button.modulate.a = 1.0 if i == Powers.selected else dim_alpha
