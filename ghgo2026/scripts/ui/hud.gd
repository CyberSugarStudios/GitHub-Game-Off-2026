extends CanvasLayer

@export var transition_time: float = 0.6 #fade in and out time for astral effect
@export var prompt_available_color := Color(1.0, 1.0, 1.0)
@export var prompt_blocked_color := Color(0.6, 0.6, 0.6)
@export var full_fade_delay: float = 1.0
@export var bar_fade_speed: float = 4.0
@export var struggle_shake := Vector2(2.0, 14.0)

@onready var astral_filter: ColorRect = $AstralRealmColorFilter
@onready var spirit_bars_container: HBoxContainer = $SpiritBars
@onready var crosshair: ColorRect = $Crosshair
@onready var interaction_prompt: Label = $InteractionPrompt
@onready var subtitle: RichTextLabel = $Subtitle
@onready var letterbox_top: ColorRect = $LetterboxTop
@onready var letterbox_bottom: ColorRect = $LetterboxBottom
@onready var story_prompt: Label = $StoryPrompt

var _bars: Array[PillBar] = []
var _astral_material: ShaderMaterial
var _astral_strength := 0.0
var _astral_tween: Tween
var _full_for := 0.0
var _warmup := false
var _prompt_rest := Vector2.ZERO
var _shake_tween: Tween

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
	GameState.room_changed.connect(
		func(_room_id: StringName) -> void:
			_refresh_crosshair())
	Events.shift_charge_changed.connect(_on_shift_charge_changed)
	Events.story_prompt_changed.connect(_on_story_prompt_changed)
	Events.struggle_changed.connect(_on_struggle_changed)
	
	#current state instantly on load
	_on_energy_changed(GameState.energy, GameState.max_bars)
	_set_astral_strength(1.0 if GameState.in_astral else 0.0)
	_on_controls_locked_changed(GameState.controls_locked)
	_on_interaction_prompt_changed("", false)
	_on_subtitle_changed("", "", 1.0, false)
	_refresh_crosshair()
	_on_story_prompt_changed("")
	
	_full_for = full_fade_delay
	spirit_bars_container.modulate.a = 0.0
	add_to_group("astral_visibility")

func set_warmup(on: bool) -> void:
	_warmup = on

func _process(delta: float) -> void:
	var full := GameState.energy >= GameState.max_bars - 0.001
	_full_for = _full_for + delta if full else 0.0
	var want := 1.0 if (_warmup or GameState.in_astral or _full_for < full_fade_delay) else 0.0
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
	if amount <= 0.0:
		_on_plane_changed(GameState.in_astral)
		_astral_tween.tween_callback(_set_focus_look.bind(1.0, 1.0, 1.0, 1.0))
		return
	if _astral_tween:
		_astral_tween.kill()
	_set_focus_look(
		_ramp(amount, 0.0, 0.9),	# reach: edges -> whole screen
		_ramp(amount, 0.0, 0.3),	# wave
		_ramp(amount, 0.25, 0.55),	# chrom abb
		_ramp(amount, 0.5, 0.8)		# grain
	)
	_set_astral_strength(amount)

func _set_focus_look(reach: float, wave: float, aberration: float, grain: float) -> void:
	_astral_material.set_shader_parameter("reach", reach)
	_astral_material.set_shader_parameter("wave_mix", wave)
	_astral_material.set_shader_parameter("aberration_mix", aberration)
	_astral_material.set_shader_parameter("grain_mix", grain)

static func _ramp(x: float, from: float, to: float) -> float:
	return clampf((x - from) / (to - from), 0.0, 1.0)

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

func _on_story_prompt_changed(text: String) -> void:
	story_prompt.text = text
	story_prompt.visible = text != ""

func _on_struggle_changed(progress: float) -> void:
	if _shake_tween and _shake_tween.is_running():
		_shake_tween.kill()
		story_prompt.position = _prompt_rest
	else:
		_prompt_rest = story_prompt.position
	if progress <= 0.0:
		return
	var strength := lerpf(struggle_shake.x, struggle_shake.y, progress)
	_shake_tween = create_tween()
	for i in 4:
		var shake_offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength
		_shake_tween.tween_property(story_prompt, "position", _prompt_rest + shake_offset, 0.03)
	_shake_tween.tween_property(story_prompt, "position", _prompt_rest, 0.03)
