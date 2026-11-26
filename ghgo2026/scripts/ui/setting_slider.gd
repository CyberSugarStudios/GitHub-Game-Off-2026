@tool
class_name SettingSlider
extends HBoxContainer

signal changed(value: float)

enum Format { PERCENT, DECIMAL, MULTIPLIER }

@export var label_text: String = "Setting":
	set(value):
		label_text = value
		if is_node_ready():
			($Name as Label).text = value
@export var min_value: float = 0.0
@export var max_value: float = 1.0
@export var step: float = 0.01
@export var format: Format = Format.PERCENT

@onready var slider: HSlider = $Slider
@onready var value_label: Label = $Value

func _ready() -> void:
	($Name as Label).text = label_text
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	_show(slider.value)
	if Engine.is_editor_hint():
		return
	slider.value_changed.connect(func(value: float) -> void:
		_show(value)
		changed.emit(value))

func set_value(value: float) -> void:
	slider.set_value_no_signal(value)
	_show(value)

func _show(value: float) -> void:
	match format:
		Format.PERCENT:
			value_label.text = "%d%%" % roundi(value * 100.0)
		Format.DECIMAL:
			value_label.text = "%.2f" % value
		Format.MULTIPLIER:
			value_label.text = "%.2f×" % value
