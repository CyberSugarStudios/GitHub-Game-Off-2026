extends CanvasLayer

@export var transition_time: float = 0.6 #fade in and out time for astral effect
@export var prompt_available_color := Color(1.0, 1.0, 1.0)
@export var prompt_blocked_color := Color(0.6, 0.6, 0.6)
@export var full_fade_delay: float = 1.0
@export var bar_fade_speed: float = 4.0
@export var shift_preview: float = 0.25

@onready var astral_filter: ColorRect = $AstralRealmColorFilter
@onready var spirit_bars_container: HBoxContainer = $SpiritBars
@onready var crosshair: ColorRect = $Crosshair
@onready var interaction_prompt: Label = $InteractionPrompt
@onready var subtitle: RichTextLabel = $Subtitle
@onready var letterbox_top: ColorRect = $LetterboxTop
@onready var letterbox_bottom: ColorRect = $LetterboxBottom

var _bars: Array[PillBar] = []
var _astral_material: ShaderMaterial
var _astral_strength := 0.0
var _astral_tween: Tween
var _full_for := 0.0
var _shift_charge := 0.0
var _flickering := false

func _ready() -> void:
	for child in spirit_bars_container.get_children():
		if child is PillBar:
			_bars.append(child)
	
	_astral_material = astral_filter.material as ShaderMaterial
	
	GameState.energy_changed.connect(_on_energy_changed)
	GameState.plane_changed.connect(_on_plane_changed)
	GameState.controls_locked_changed.connect(_on_controls_locked_changed)
	Events.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	Events.subtitle_changed.connect(_on_subtitle_changed)
	GameState.room_changed.connect(func(_room_id: StringName) -> void: _refresh_crosshair())
	Events.shift_charge_changed.connect(_on_shift_charge_changed)
	Events.shift_flicker.connect(_on_shift_flicker)
	
	#current state instantly on load
	_on_energy_changed(GameState.energy, GameState.max_bars)
	_set_astral_strength(1.0 if GameState.in_astral else 0.0)
	_on_controls_locked_changed(GameState.controls_locked)
	_on_interaction_prompt_changed("", false)
	_on_subtitle_changed("", "", 1.0, false)
	_refresh_crosshair()
	
	_full_for = full_fade_delay
	spirit_bars_container.modulate.a = 0.0

func _process(delta: float) -> void:
	var full := GameState.energy >= GameState.max_bars - 0.001
	_full_for = _full_for + delta if full else 0.0
	var want := 1.0 if _full_for < full_fade_delay else 0.0
	spirit_bars_container.modulate.a = move_toward(spirit_bars_container.modulate.a, want,\
		bar_fade_speed * delta)

func _on_energy_changed(energy: float, max_bars: int) -> void:
	for i in _bars.size():
		_bars[i].visible = i < max_bars
		_bars[i].value = clampf(energy - i, 0.0, 1.0)

#region - ASTRAL EFFECT
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

func _on_shift_charge_changed(amount: float) -> void:
	_shift_charge = amount
	if _astral_tween and _astral_tween.is_running():
		return
	var resting := 1.0 if GameState.in_astral else 0.0
	var other := 1.0 - resting
	_set_astral_strength(other if _flickering else lerpf(resting, other, amount * \
		shift_preview))

func _on_shift_flicker(on: bool) -> void:
	_flickering = on
	_on_shift_charge_changed(_shift_charge)

func _set_astral_strength(value: float) -> void:
	_astral_strength = value
	_astral_material.set_shader_parameter("strength", value)
	astral_filter.visible = value > 0.001
#endregion

#region - SUBTITLES
func _on_subtitle_changed(character: String, text: String, clarity: float, is_thought: bool) -> void:
	subtitle.visible = text != ""
	if text == "":
		return
	var shown := _obscure(text, clarity).replace("[", "[lb]")
	if is_thought:
		shown = "[i]%s[/i]" % shown
	elif clarity >= 0.5:
		shown = "[b]%s:[/b] %s" %[character, shown]
	subtitle.text = shown
	subtitle.modulate.a = lerpf(0.4, 1.0, clarity)

func _obscure(text: String, clarity: float) -> String:
	if clarity >= 0.999:
		return text
	var result := ""
	for i in text.length():
		var letter := text[i]
		if letter == " ":
			result += " "
			continue
		var threshold := fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
		result += letter if threshold < clarity else "."
	return result

func _on_controls_locked_changed(locked: bool) -> void:
	letterbox_top.visible = locked
	letterbox_bottom.visible = locked
	_refresh_crosshair()
#endregion

func _refresh_crosshair() -> void:
	crosshair.visible = not GameState.is_in_room() and not GameState.controls_locked

func _on_interaction_prompt_changed(text: String, available: bool) -> void:
	interaction_prompt.visible = text != ""
	var key_hint := "Click   " if GameState.is_in_room() else "E   "
	interaction_prompt.text = (key_hint + text) if available else text
	interaction_prompt.modulate = prompt_available_color if available else prompt_blocked_color
	crosshair.modulate.a = 1.0 if text != "" else 0.35
