extends CanvasLayer

@onready var astral_filter: ColorRect = $AstralRealmColorFilter
@onready var spirit_bars_container: HBoxContainer = $SpiritBars

var _bars: Array[ProgressBar] = []

func _ready() -> void:
	for child in spirit_bars_container.get_children():
		if child is ProgressBar:
			var bar := child as ProgressBar
			bar.max_value = 1.0
			bar.step = 0.0
			_bars.append(bar)
	
	GameState.energy_changed.connect(_on_energy_changed)
	GameState.plane_changed.connect(_on_plane_changed)
	
	_on_energy_changed(GameState.energy, GameState.max_bars)
	_on_plane_changed(GameState.in_astral)

func _on_energy_changed(energy: float, max_bars: int) -> void:
	for i in _bars.size():
		_bars[i].visible = i < max_bars
		_bars[i].value = clampf(energy - i, 0.0, 1.0)

func _on_plane_changed(in_astral: bool) -> void:
	astral_filter.visible = in_astral
