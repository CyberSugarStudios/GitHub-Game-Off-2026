extends Node

const PATH := "user://settings.cfg"
const BUSES: Array[StringName] = [&"Master", &"Music", &"MP3", &"Voices", &"SFX", &"Ambience"]
const STRUGGLE_PRESSES_PER_SECOND := 8.0
const SAVE_DELAY := 0.6

var volumes: Dictionary[StringName, float] = {}
var look_speed := 1.0
var invert_y := false
var hold_to_struggle := false

var _struggling := false
var _struggle_held := false
var _press_clock := 0.0
var _save_in := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in BUSES:
		volumes[bus] = 1.0
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

func struggle_hint() -> String:
	return "[HOLD SPACE]" if hold_to_struggle else "[SPACE]"
#endregion

#region - SAVING
func request_save() -> void:
	_save_in = SAVE_DELAY

func save_settings() -> void:
	var config := ConfigFile.new()
	for bus in BUSES:
		config.set_value("audio", String(bus), volumes[bus])
	config.set_value("controls", "look_speed", look_speed)
	config.set_value("controls", "invert_y", invert_y)
	config.set_value("controls", "hold_to_struggle", hold_to_struggle)
	config.save(PATH)

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	for bus in BUSES:
		volumes[bus] = config.get_value("audio", String(bus), 1.0)
	look_speed = config.get_value("controls", "look_speed", 1.0)
	invert_y = config.get_value("controls", "invert_y", false)
	hold_to_struggle = config.get_value("controls", "hold_to_struggle", false)
#endregion

#region - HOLD TO STRUGGLE
func _input(event: InputEvent) -> void:
	if event is InputEventAction:
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
