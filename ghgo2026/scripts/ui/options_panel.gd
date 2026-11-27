class_name OptionsPanel
extends VBoxContainer

signal closed

const VOLUME_SLIDERS := {
	&"Master": "MasterVolume",
	&"Music": "MusicVolume",
	&"MP3": "Mp3Volume",
	&"Voices": "VoicesVolume",
	&"SFX": "SfxVolume",
	&"Ambience": "AmbienceVolume",
}

const TEST_TAP := preload("res://assets/audio/sfx/footsteps/leanne_steps.tres")
const TAP_GAP_MS := 200
const HOLD_MS := 1500
const PREVIEW_FADE := 0.6

@export var font_size: int = 26
@export var previews: Dictionary[StringName, AudioStream] = {}
@export var close_text: String = ""

var _players: Dictionary[StringName, AudioStreamPlayer] = {}
var _fades: Dictionary[StringName, Tween] = {}
var _hold_until: Dictionary[StringName, int] = {}
var _last_tap_ms := 0

func _ready() -> void:
	_apply_font_size()
	_load_values()
	for bus: StringName in VOLUME_SLIDERS:
		var row := get_node("%" + VOLUME_SLIDERS[bus]) as SettingSlider
		row.changed.connect(func(value: float) -> void:
			Settings.set_volume(bus, value)
			_play_test_sound(bus)
			Settings.request_save())
	_bind_slider(%Brightness, func(value: float) -> void: Settings.brightness = value)
	_bind_slider(%Contrast, func(value: float) -> void: Settings.contrast = value)
	_bind_slider(%Gamma, func(value: float) -> void: Settings.gamma = value)
	_bind_slider(%Sensitivity, func(value: float) -> void: Settings.look_speed = value)
	_bind_check(%ReduceFlashing, func(on: bool) -> void: Settings.reduce_flashing = on)
	_bind_check(%InvertY, func(on: bool) -> void: Settings.invert_y = on)
	_bind_check(%HoldToStruggle, func(on: bool) -> void: Settings.hold_to_struggle = on)
	(%ResetButton as BaseButton).pressed.connect(_reset)
	var close_button := %CloseOptionsButton as TitleButton
	if close_text != "":
		close_button.text = close_text
	close_button.pressed.connect(save_and_close)

func _load_values() -> void:
	for bus: StringName in VOLUME_SLIDERS:
		(get_node("%" + VOLUME_SLIDERS[bus]) as SettingSlider).set_value(Settings.volumes.get(bus, 1.0))
	(%Brightness as SettingSlider).set_value(Settings.brightness)
	(%Contrast as SettingSlider).set_value(Settings.contrast)
	(%Gamma as SettingSlider).set_value(Settings.gamma)
	(%Sensitivity as SettingSlider).set_value(Settings.look_speed)
	(%ReduceFlashing as CheckBox).set_pressed_no_signal(Settings.reduce_flashing)
	(%InvertY as CheckBox).set_pressed_no_signal(Settings.invert_y)
	(%HoldToStruggle as CheckBox).set_pressed_no_signal(Settings.hold_to_struggle)

func _bind_slider(row: SettingSlider, apply: Callable) -> void:
	row.changed.connect(func(value: float) -> void:
		apply.call(value)
		Settings.request_save())

func _bind_check(box: CheckBox, apply: Callable) -> void:
	box.toggled.connect(func(on: bool) -> void:
		apply.call(on)
		Settings.request_save())

func _reset() -> void:
	Settings.reset_to_defaults()
	_load_values()

func save_and_close() -> void:
	Settings.save_settings()
	closed.emit()

func focus_close() -> void:
	(%CloseOptionsButton as Control).grab_focus()

func _apply_font_size() -> void:
	for node in find_children("*", "", true, false):
		if node is CheckBox or (node is Label and not String(node.name).ends_with("Heading")):
			(node as Control).add_theme_font_size_override("font_size", font_size)

#region - TEST SOUNDS
func _play_test_sound(bus: StringName) -> void:
	var stream: AudioStream = previews.get(bus)
	if stream == null:
		_tap(bus)
		return
	if bus == &"Music" and Music.current_stream() == stream:
		return
	var player := _player_for(bus)
	_hold_until[bus] = Time.get_ticks_msec() + HOLD_MS
	set_process(true)
	if _fades.has(bus):
		_fades[bus].kill()
		_fades.erase(bus)
	player.volume_linear = 1.0
	if player.playing:
		return
	player.stream = stream
	player.play()
	if bus == &"Music":
		Music.step_aside(true)

func _tap(bus: StringName) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_tap_ms < TAP_GAP_MS:
		return
	_last_tap_ms = now
	var player := _player_for(&"tap")
	player.bus = bus
	player.stream = TEST_TAP
	player.play()

func _player_for(key: StringName) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = _players.get(key)
	if not is_instance_valid(player):
		player = AudioStreamPlayer.new()
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		if key != &"tap":
			player.bus = key
		add_child(player)
		_players[key] = player
	return player

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	for bus: StringName in _hold_until.keys():
		if now >= _hold_until[bus]:
			_hold_until.erase(bus)
			_fade_out(bus)
	set_process(not _hold_until.is_empty())

func _fade_out(bus: StringName) -> void:
	var player: AudioStreamPlayer = _players.get(bus)
	if is_instance_valid(player) and player.playing:
		var tween := create_tween()
		tween.tween_property(player, "volume_linear", 0.0, PREVIEW_FADE)
		tween.tween_callback(player.stop)
		_fades[bus] = tween
	if bus == &"Music":
		Music.step_aside(false)

func _exit_tree() -> void:
	if _hold_until.has(&"Music"):
		Music.step_aside(false)
#endregion
