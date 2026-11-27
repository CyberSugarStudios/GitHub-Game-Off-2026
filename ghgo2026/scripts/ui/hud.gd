extends CanvasLayer

const SPEAKER_COLORS: Dictionary[String, Color] = {
	"Leanne": Color("#948381"),
	"David": Color("#979577"),
	"Emily": Color("#70AFA3")
}
const MEMORY_SOUND := preload("res://assets/audio/sfx/varied/memory_unlocked.wav")
const KEY_PROMPT := preload("res://scenes/ui/key_prompt.tscn")

@export var transition_time: float = 0.6 #fade in and out time for astral effect
@export var prompt_available_color := Color(1.0, 1.0, 1.0)
@export var prompt_blocked_color := Color(0.6, 0.6, 0.6)
@export var click_sheet: Texture2D = preload("res://assets/sprites/ui/clicking.webp")
@export var click_frames: int = 7
@export var click_fps: float = 4.5
@export var swipe_sheet: Texture2D = preload("res://assets/sprites/ui/swiping.webp")
@export var swipe_frames: int = 25
@export var swipe_fps: float = 12.0
@export var move_hint_seconds: float = 7.0

@export var room_prompt_bottom: float = -150.0
@export var hall_prompt_bottom: float = -80.0
@export var full_fade_delay: float = 1.0
@export var bar_fade_speed: float = 4.0
@export var struggle_shake := Vector2(2.0, 14.0)

@export_group("Memory Restored")
@export var memory_pill_scale: float = 3.0
@export var memory_hold: float = 0.8
@export var memory_fly_time: float = 0.9
@export var memory_fill_time: float = 0.7
@export var memory_duck_db: float = -15.0
@export var memory_unduck_time: float = 1.5
@export var memory_duck_seconds: float = 2.5

@onready var astral_filter: ColorRect = $AstralRealmColorFilter
@onready var spirit_bars_container: HBoxContainer = $SpiritBars
@onready var crosshair: ColorRect = $Crosshair
@onready var interaction_prompt: KeyPrompt = $InteractionPrompt
@onready var subtitle: RichTextLabel = $Subtitle
@onready var letterbox_top: ColorRect = $LetterboxTop
@onready var letterbox_bottom: ColorRect = $LetterboxBottom
@onready var story_prompt: KeyPrompt = $StoryPrompt
var _key_token := RegEx.create_from_string("(?i)\\[(hold\\s+)?([a-z0-9 ]+)\\]")

var _bars: Array[PillBar] = []
var _astral_material: ShaderMaterial
var _astral_strength := 0.0
var _astral_tween: Tween
var _full_for := 0.0
var _warmup := false
var _prompt_rest := Vector2.ZERO
var _shake_tween: Tween
var _memory_player: AudioStreamPlayer
var _known_bars := 0
var _memory_animations := 0

func _ready() -> void:
	for child in spirit_bars_container.get_children():
		if child is PillBar:
			_bars.append(child)
	
	_astral_material = astral_filter.material as ShaderMaterial
	
	GameState.energy_changed.connect(_on_energy_changed)
	_known_bars = GameState.max_bars
	_memory_player = AudioStreamPlayer.new()
	_memory_player.stream = MEMORY_SOUND
	_memory_player.bus = &"SFX"
	add_child(_memory_player)
	GameState.max_bars_changed.connect(_on_max_bars_changed)
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
	GameState.room_changed.connect(_on_room_changed_for_hints)
	
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
	var want := 1.0 if (_warmup or GameState.in_astral or _full_for < full_fade_delay \
		or _memory_animations > 0) else 0.0
	spirit_bars_container.modulate.a = move_toward(spirit_bars_container.modulate.a, want,\
		bar_fade_speed * delta)

func _on_energy_changed(energy: float, max_bars: int) -> void:
	for i in _bars.size():
		_bars[i].visible = i < max_bars
		_bars[i].value = clampf(energy - i, 0.0, 1.0)

func _on_max_bars_changed(max_bars: int) -> void:
	if max_bars > _known_bars:
		_play_memory_restored(max_bars - 1)
	_known_bars = max_bars

func _unduck_after_memory() -> void:
	Music.duck(false, memory_unduck_time)

func _play_memory_restored(index: int) -> void:
	Music.duck(true, 0.6, memory_duck_db)
	_memory_player.play()
	get_tree().create_timer(memory_duck_seconds).timeout.connect(_unduck_after_memory)
	if index < 0 or index >= _bars.size():
		return
	var slot := _bars[index]
	slot.modulate.a = 0.0
	_memory_animations += 1

	var pill := PillBar.new()
	pill.value = 0.0
	pill.size = slot.custom_minimum_size
	pill.pivot_offset = pill.size * 0.5
	pill.position = get_viewport().get_visible_rect().size * 0.5 - pill.pivot_offset
	pill.scale = Vector2.ONE * memory_pill_scale * 1.15
	pill.modulate.a = 0.0
	add_child(pill)

	var tween := create_tween()
	tween.tween_property(pill, "modulate:a", 1.0, 0.4)
	tween.parallel().tween_property(pill, "scale", Vector2.ONE * memory_pill_scale, 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(memory_hold)
	await tween.finished

	tween = create_tween().set_parallel()
	tween.tween_property(pill, "position", slot.global_position, memory_fly_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(pill, "scale", Vector2.ONE, memory_fly_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

	tween = create_tween()
	tween.tween_property(pill, "value", 1.0, memory_fill_time)
	await tween.finished

	slot.modulate.a = 1.0
	pill.queue_free()
	_memory_animations -= 1

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
	var line := "%s: %s" % [character, _obscure(text, clarity).replace("[", "[lb]")]
	var color: Color = SPEAKER_COLORS.get(character, Color.WHITE)
	if is_thought:
		line = "[i]%s[/i]" % line
		color = color.lerp(Color.WHITE, 0.35)
	subtitle.text = "[color=#%s]%s[/color]" % [color.to_html(false), line]
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
	var in_room := GameState.is_in_room()
	var key := ""
	if available:
		key = "E" if not in_room else ("" if click_sheet else "Click")
	interaction_prompt.icon_frames = click_frames
	interaction_prompt.icon_fps = click_fps
	interaction_prompt.icon_sheet = click_sheet if available and in_room else null
	interaction_prompt.show_prompt(key, text)
	var bottom := room_prompt_bottom if in_room else hall_prompt_bottom
	if not is_equal_approx(interaction_prompt.offset_bottom, bottom):
		var height := interaction_prompt.size.y
		interaction_prompt.offset_bottom = bottom
		interaction_prompt.offset_top = bottom - height
	interaction_prompt.modulate = prompt_available_color if available else prompt_blocked_color
	crosshair.modulate.a = 1.0 if text != "" else 0.35

func _on_room_changed_for_hints(room_id: StringName) -> void:
	if room_id != &"" or GameState.has_flag(&"move_hint_shown"):
		return
	GameState.set_flag(&"move_hint_shown")
	while GameState.controls_locked or GameState.is_in_room():
		await get_tree().process_frame
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_wasd_cluster())
	var move := _hint_prompt("", "Move")
	move.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(move)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(40.0, 0.0)
	row.add_child(gap)
	var look := _hint_prompt("", "Look around")
	look.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	look.icon_frames = swipe_frames
	look.icon_fps = swipe_fps
	look.icon_sheet = swipe_sheet
	row.add_child(look)
	add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_top = -140.0
	row.offset_bottom = -140.0
	row.modulate.a = 0.0
	var tween := row.create_tween()
	tween.tween_property(row, "modulate:a", 1.0, 0.6)
	tween.tween_interval(move_hint_seconds)
	tween.tween_property(row, "modulate:a", 0.0, 1.5)
	tween.tween_callback(row.queue_free)

func _wasd_cluster() -> VBoxContainer:
	var cluster := VBoxContainer.new()
	cluster.add_theme_constant_override("separation", 4)
	cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := _hint_prompt("W", "")
	top.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cluster.add_child(top)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 4)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for letter in ["A", "S", "D"]:
		bottom.add_child(_hint_prompt(letter, ""))
	cluster.add_child(bottom)
	return cluster

func _hint_prompt(key: String, text: String) -> KeyPrompt:
	var prompt := KEY_PROMPT.instantiate() as KeyPrompt
	prompt.font_size = 26
	prompt.show_prompt(key, text)
	return prompt

func _on_story_prompt_changed(text: String) -> void:
	story_prompt.visible = text != ""
	var key := ""
	var hold := ""
	var token := _key_token.search(text)
	if token:
		key = token.get_string(2).strip_edges().capitalize()
		hold = "Hold" if token.get_string(1) != "" else ""
		text = (text.substr(0, token.get_start()) + text.substr(token.get_end())).strip_edges()
	story_prompt.show_prompt(key, text, hold)

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
