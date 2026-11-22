class_name OptionsPanel
extends VBoxContainer

const VOLUME_ROWS := {
	&"Master": "Master volume",
	&"Music": "Music",
	&"MP3": "Emily's music",
	&"Voices": "Voices",
	&"SFX": "Sound effects",
	&"Ambience": "Ambience",
}

@export var font_size: int = 28

const TEST_TAP := preload("res://assets/audio/sfx/footsteps/leanne_steps.tres")
const TAP_GAP_MS := 200
const HOLD_MS := 1500
const PREVIEW_FADE := 0.6

@export var previews: Dictionary[StringName, AudioStream] = {}

var _players: Dictionary[StringName, AudioStreamPlayer] = {}
var _fades: Dictionary[StringName, Tween] = {}
var _hold_until: Dictionary[StringName, int] = {}
var _last_tap_ms := 0

func _ready() -> void:
	add_theme_constant_override("separation", 14)
	custom_minimum_size.x = 680
	_build()

func _build() -> void:
	_heading("Sound")
	for bus in VOLUME_ROWS:
		_slider_row(VOLUME_ROWS[bus], Settings.volumes.get(bus, 1.0), 0.0, 1.0, 0.01,
			func(value: float) -> void:
				Settings.set_volume(bus, value)
				_play_test_sound(bus),
			func(value: float) -> String: return "%d%%" % roundi(value * 100.0))
	_heading("Display")
	_slider_row("Brightness", Settings.brightness, 0.5, 1.6, 0.05,
		func(value: float) -> void: Settings.brightness = value,
		func(value: float) -> String: return "%d%%" % roundi(value * 100.0))
	_slider_row("Contrast", Settings.contrast, 0.7, 1.4, 0.05,
		func(value: float) -> void: Settings.contrast = value,
		func(value: float) -> String: return "%d%%" % roundi(value * 100.0))
	_slider_row("Gamma", Settings.gamma, 0.6, 1.8, 0.05,
		func(value: float) -> void: Settings.gamma = value,
		func(value: float) -> String: return "%.2f" % value)
	_check_row("Reduce flashing lights", Settings.reduce_flashing,
		func(on: bool) -> void: Settings.reduce_flashing = on)
	_heading("Controls")
	_slider_row("Mouse sensitivity", Settings.look_speed, 0.25, 2.0, 0.05,
		func(value: float) -> void: Settings.look_speed = value,
		func(value: float) -> String: return "%.2f×" % value)
	_check_row("Invert mouse Y", Settings.invert_y,
		func(on: bool) -> void: Settings.invert_y = on)
	_check_row("Hold to struggle (hold Space instead of tapping)", Settings.hold_to_struggle,
		func(on: bool) -> void: Settings.hold_to_struggle = on)
	var reset := Button.new()
	reset.text = "Reset to defaults"
	reset.add_theme_font_size_override("font_size", font_size)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset.pressed.connect(_reset)
	add_child(reset)

func _reset() -> void:
	Settings.reset_to_defaults()
	for child in get_children():
		if child is AudioStreamPlayer:
			continue
		remove_child(child)
		child.queue_free()
	_build()

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

func _heading(text: String) -> void:
	var label := _label(text)
	label.add_theme_font_size_override("font_size", font_size + 10)
	add_child(label)

func _slider_row(text: String, value: float, low: float, high: float, step: float,
		on_change: Callable, format: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := _label(text)
	label.custom_minimum_size.x = 270
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var readout := _label(format.call(value))
	readout.custom_minimum_size.x = 90
	slider.value_changed.connect(
		func(new_value: float) -> void:
			on_change.call(new_value)
			readout.text = format.call(new_value)
			Settings.request_save())
	row.add_child(label)
	row.add_child(slider)
	row.add_child(readout)
	add_child(row)

func _check_row(text: String, on: bool, on_toggle: Callable) -> void:
	var box := CheckBox.new()
	box.text = text
	box.button_pressed = on
	box.add_theme_font_size_override("font_size", font_size)
	box.toggled.connect(
		func(pressed: bool) -> void:
			on_toggle.call(pressed)
			Settings.request_save())
	add_child(box)

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label
