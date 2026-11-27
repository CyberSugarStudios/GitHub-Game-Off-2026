extends Node

signal changed

const PATH := "user://settings.cfg"
const BUSES: Array[StringName] = [&"Master", &"Music", &"MP3", &"Voices", &"SFX", &"Ambience"]
const STRUGGLE_PRESSES_PER_SECOND := 8.0
const SAVE_DELAY := 0.6
const DEFAULT_VOLUME := 1.0
const DEFAULT_LOOK_SPEED := 1.0
const DEFAULT_INVERT_Y := false
const DEFAULT_HOLD_TO_STRUGGLE := false
const DEFAULT_BRIGHTNESS := 1.0
const DEFAULT_CONTRAST := 1.0
const DEFAULT_GAMMA := 1.0
const DEFAULT_REDUCE_FLASHING := false
const DEFAULT_ALWAYS_SHOW_HINTS := false
const ONBOARDING_VERSION := 5

var volumes: Dictionary[StringName, float] = {}
var look_speed := DEFAULT_LOOK_SPEED
var invert_y := DEFAULT_INVERT_Y
var hold_to_struggle := DEFAULT_HOLD_TO_STRUGGLE
var brightness := DEFAULT_BRIGHTNESS
var contrast := DEFAULT_CONTRAST
var gamma := DEFAULT_GAMMA
var reduce_flashing := DEFAULT_REDUCE_FLASHING
var always_show_hints := DEFAULT_ALWAYS_SHOW_HINTS
var onboarding_seen := 0
var game_completed := false
var lullaby_unlocked := false

var _struggling := false
var _struggle_held := false
var _press_clock := 0.0
var _save_in := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in BUSES:
		volumes[bus] = DEFAULT_VOLUME
	load_settings()
	for bus in BUSES:
		_apply_volume(bus)
	Events.struggle_changed.connect(
		func(amount: float) -> void:
			_struggling = amount > 0.0)

#region - VALUES
func set_volume(bus: StringName, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	_apply_volume(bus)

func _apply_volume(bus: StringName) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var value: float = volumes.get(bus, 1.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(index, value <= 0.001)

func fade_color() -> Color:
	return ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color", Color.BLACK)

func struggle_hint() -> String:
	return "[HOLD SPACE]" if hold_to_struggle else "[SPACE]"

func reset_to_defaults() -> void:
	for bus in BUSES:
		set_volume(bus, DEFAULT_VOLUME)
	look_speed = DEFAULT_LOOK_SPEED
	invert_y = DEFAULT_INVERT_Y
	hold_to_struggle = DEFAULT_HOLD_TO_STRUGGLE
	brightness = DEFAULT_BRIGHTNESS
	contrast = DEFAULT_CONTRAST
	gamma = DEFAULT_GAMMA
	reduce_flashing = DEFAULT_REDUCE_FLASHING
	always_show_hints = DEFAULT_ALWAYS_SHOW_HINTS
	request_save()
#endregion

#region - SAVING
func request_save() -> void:
	_save_in = SAVE_DELAY
	changed.emit()

func save_settings() -> void:
	var config := ConfigFile.new()
	for bus in BUSES:
		config.set_value("audio", String(bus), volumes[bus])
	config.set_value("controls", "look_speed", look_speed)
	config.set_value("controls", "invert_y", invert_y)
	config.set_value("controls", "hold_to_struggle", hold_to_struggle)
	config.set_value("controls", "always_show_hints", always_show_hints)
	config.set_value("general", "onboarding_seen", onboarding_seen)
	config.set_value("unlocks", "game_completed", game_completed)
	config.set_value("unlocks", "lullaby_unlocked", lullaby_unlocked)
	config.set_value("display", "brightness", brightness)
	config.set_value("display", "contrast", contrast)
	config.set_value("display", "gamma", gamma)
	config.set_value("display", "reduce_flashing", reduce_flashing)
	config.save(PATH)

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	for bus in BUSES:
		volumes[bus] = config.get_value("audio", String(bus), DEFAULT_VOLUME)
	look_speed = config.get_value("controls", "look_speed", DEFAULT_LOOK_SPEED)
	invert_y = config.get_value("controls", "invert_y", DEFAULT_INVERT_Y)
	hold_to_struggle = config.get_value("controls", "hold_to_struggle", DEFAULT_HOLD_TO_STRUGGLE)
	always_show_hints = config.get_value("controls", "always_show_hints", DEFAULT_ALWAYS_SHOW_HINTS)
	onboarding_seen = config.get_value("general", "onboarding_seen", 0)
	game_completed = config.get_value("unlocks", "game_completed", false)
	lullaby_unlocked = config.get_value("unlocks", "lullaby_unlocked", false)
	brightness = config.get_value("display", "brightness", DEFAULT_BRIGHTNESS)
	contrast = config.get_value("display", "contrast", DEFAULT_CONTRAST)
	gamma = config.get_value("display", "gamma", DEFAULT_GAMMA)
	reduce_flashing = config.get_value("display", "reduce_flashing", DEFAULT_REDUCE_FLASHING)
#endregion

#region - HOLD TO STRUGGLE
func _input(event: InputEvent) -> void:
	if event is InputEventAction or event.is_echo():
		return
	if event.is_action("struggle"):
		_struggle_held = event.is_pressed()
		_press_clock = 0.0

func _process(delta: float) -> void:
	if _save_in > 0.0:
		_save_in -= delta
		if _save_in <= 0.0:
			save_settings()
	if not (hold_to_struggle and _struggling and _struggle_held) or get_tree().paused:
		return
	_press_clock += delta
	if _press_clock >= 1.0 / STRUGGLE_PRESSES_PER_SECOND:
		_press_clock = 0.0
		var press := InputEventAction.new()
		press.action = &"struggle"
		press.pressed = true
		Input.parse_input_event(press)
#endregion
