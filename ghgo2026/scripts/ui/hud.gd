extends CanvasLayer

@export var transition_time: float = 0.6 #fade in and out time for astral effect

@onready var astral_filter: ColorRect = $AstralRealmColorFilter
@onready var spirit_bars_container: HBoxContainer = $SpiritBars

var _bars: Array[ProgressBar] = []
var _astral_material: ShaderMaterial
var _astral_strength := 0.0
var _astral_tween: Tween

func _ready() -> void:
	for child in spirit_bars_container.get_children():
		if child is ProgressBar:
			var bar := child as ProgressBar
			bar.max_value = 1.0
			bar.step = 0.0
			_bars.append(bar)
	
	_astral_material = astral_filter.material as ShaderMaterial
	
	GameState.energy_changed.connect(_on_energy_changed)
	GameState.plane_changed.connect(_on_plane_changed)
	
	#current state instantly on load
	_on_energy_changed(GameState.energy, GameState.max_bars)
	_on_plane_changed(GameState.in_astral)

func _on_energy_changed(energy: float, max_bars: int) -> void:
	for i in _bars.size():
		_bars[i].visible = i < max_bars
		_bars[i].value = clampf(energy - i, 0.0, 1.0)

func _on_plane_changed(in_astral: bool) -> void:
	if _astral_tween:
		_astral_tween.kill()
	_astral_tween = create_tween()
	
	if in_astral:
		_astral_tween.tween_method(_set_astral_strength, _astral_strength, 1.0, transition_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_astral_tween.tween_method(_set_astral_strength, _astral_strength, 0.0, transition_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _set_astral_strength(value: float) -> void:
	_astral_strength = value
	_astral_material.set_shader_parameter("strength", value)
	astral_filter.visible = value > 0.001
