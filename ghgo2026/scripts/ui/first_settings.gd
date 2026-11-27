extends Control

const GUIDE_SCENE := "res://scenes/ui/controls_guide.tscn"
const RAMP_STEPS := 10

@export var fade_time: float = 0.6
@export var ramp_step_size := Vector2(52, 52)

@onready var panel: OptionsPanel = %OptionsPanel
@onready var ramp: HBoxContainer = %Ramp

var _leaving := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	panel.closed.connect(_continue)
	_build_ramp()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, fade_time)

func _build_ramp() -> void:
	for i in RAMP_STEPS:
		var step := ColorRect.new()
		var value := i / float(RAMP_STEPS - 1)
		step.color = Color(value, value, value)
		step.custom_minimum_size = ramp_step_size
		ramp.add_child(step)

func _continue() -> void:
	if _leaving:
		return
	_leaving = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	await tween.finished
	get_tree().change_scene_to_file(GUIDE_SCENE)
