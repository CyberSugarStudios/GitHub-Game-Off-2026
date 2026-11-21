class_name HallThermostat
extends PowerTarget

@export var works_at_stage: int = 2
@export var trips_event: StringName = &"david_checks_breaker"
@export var dead_seconds: float = 4.0

@export_group("Sounds")
@export var shock_sound: AudioStream

@onready var screen: MeshInstance3D = $Screen
@onready var sound: AudioStreamPlayer3D = $Sound

var _screen_tween: Tween

func _ready() -> void:
	super()
	Events.power_used.connect(_on_power_used)

func get_living_label() -> String:
	return "Thermostat"

func _on_power_used(power_id: StringName, id: StringName) -> void:
	if id != target_id or power_id != &"static":
		return
	if shock_sound:
		sound.stream = shock_sound
		sound.play()
	if _trips_breaker():
		_go_dark(dead_seconds)
		Events.story_event.emit(trips_event)
	else:
		_go_dark(0.3)
		if GameState.story_stage == works_at_stage:
			GameState.add_near_miss()

func _trips_breaker() -> bool:
	return GameState.story_stage == works_at_stage \
		and GameState.get_parent_activity(&"david") != &"sleeping"

func _go_dark(seconds: float) -> void:
	if _screen_tween:
		_screen_tween.kill()
	screen.visible = false
	_screen_tween = create_tween()
	_screen_tween.tween_interval(seconds)
	_screen_tween.tween_callback(screen.show)
