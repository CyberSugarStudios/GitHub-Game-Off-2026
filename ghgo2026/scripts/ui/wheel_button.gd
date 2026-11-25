class_name WheelButton
extends Button

@export_range(0.0, 0.95) var hole: float = 0.0
@export_enum("Full", "Top Half", "Bottom Half") var half: int = 0
@export_range(0.0, 1.0) var glow: float = 0.15

func _ready() -> void:
	flat = true
	text = ""
	focus_mode = Control.FOCUS_NONE
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)

func _has_point(point: Vector2) -> bool:
	var offset := (point - size / 2.0) / (size / 2.0)
	var distance := offset.length()
	if distance > 1.0 or distance < hole:
		return false
	if half == 1:
		return offset.y <= 0.0
	if half == 2:
		return offset.y >= 0.0
	return true

func _draw() -> void:
	var mode := get_draw_mode()
	if mode == DRAW_NORMAL or mode == DRAW_DISABLED:
		return
	var button_is_pressed := mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
	var color := Color(1.0, 1.0, 1.0, glow * (2.0 if button_is_pressed else 1.0))
	var radius := minf(size.x, size.y) / 2.0
	var center := size / 2.0
	if hole <= 0.0 and half == 0:
		draw_circle(center, radius, color)
		return
	var start := PI if half == 1 else 0.0
	var finish := PI if half == 2 else TAU
	draw_arc(center, radius * (1.0 + hole) / 2.0, start, finish, 48, color, radius * (1.0 - hole), true)
