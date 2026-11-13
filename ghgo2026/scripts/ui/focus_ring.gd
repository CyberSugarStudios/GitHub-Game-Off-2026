class_name FocusRing
extends Control

@export var radius: float = 22.0
@export var width: float = 3.0
@export var color := Color(0.8, 0.804, 0.769, 0.9) # color: #CCCDC4, 90%
@export var track_color := Color(0.8, 0.804, 0.769, 0.2)
@export var fade_speed: float = 6.0

var _progress := 0.0
var _showing := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	Events.shift_charge_changed.connect(_on_shift_charge_changed)
	Events.struggle_changed.connect(_on_shift_charge_changed)

func _on_shift_charge_changed(amount: float) -> void:
	_showing = amount > 0.0
	if _showing:
		_progress = amount
		queue_redraw()

func _process(delta: float) -> void:
	modulate.a = move_toward(modulate.a, 1.0 if _showing else 0.0, fade_speed * delta)

func _draw() -> void:
	var center := size / 2.0
	draw_arc(center, radius, 0.0, TAU, 64, track_color, width, true)
	if _progress > 0.0:
		draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + TAU * _progress, 64, color, width, true)
