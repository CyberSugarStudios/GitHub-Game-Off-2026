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

const TEST_SOUND := preload("res://assets/audio/sfx/footsteps/leanne_steps.tres")
const TEST_SOUND_GAP_MS := 200

var _test_player: AudioStreamPlayer
var _last_test_ms := 0

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
		remove_child(child)
		child.queue_free()
	_build()

func _play_test_sound(bus: StringName) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_test_ms < TEST_SOUND_GAP_MS:
		return
	_last_test_ms = now
	if not is_instance_valid(_test_player):
		_test_player = AudioStreamPlayer.new()
		_test_player.stream = TEST_SOUND
		_test_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_test_player)
	_test_player.bus = bus
	_test_player.play()

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
