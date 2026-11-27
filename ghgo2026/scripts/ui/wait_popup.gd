class_name WaitPopup
extends CanvasLayer

signal answered(choice: StringName)

@onready var hour_button: BaseButton = %HourButton
@onready var night_button: BaseButton = %NightButton
@onready var morning_button: BaseButton = %MorningButton
@onready var back_button: BaseButton = %BackButton

func _ready() -> void:
	visible = false
	hour_button.pressed.connect(func() -> void: answered.emit(&"hour"))
	night_button.pressed.connect(func() -> void: answered.emit(&"night"))
	morning_button.pressed.connect(func() -> void: answered.emit(&"morning"))
	back_button.pressed.connect(func() -> void: answered.emit(&""))

func ask(night_time: String, morning_time: String) -> StringName:
	night_button.text = "...UNTIL NIGHT (%s)" % to_12_hour(night_time)
	morning_button.text = "...UNTIL MORNING (%s)" % to_12_hour(morning_time)
	visible = true
	GameState.set_controls_locked(true)
	var choice: StringName = await answered
	visible = false
	GameState.set_controls_locked(false)
	return choice

static func to_12_hour(time_text: String) -> String:
	var parts := time_text.split(":")
	var hour := int(parts[0])
	var suffix := "AM" if hour < 12 else "PM"
	var shown := hour % 12
	if shown == 0:
		shown = 12
	return "%d:%s %s" % [shown, parts[1], suffix]

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("move_backward"):
		answered.emit(&"")
		get_viewport().set_input_as_handled()
