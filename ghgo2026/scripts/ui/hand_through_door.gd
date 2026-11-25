class_name HandThroughDoor
extends CanvasLayer

@export var reach_to := Vector2(1159.5, 358.5)
@export var reach_seconds: float = 1.5
@export var hold_seconds: float = 1.0
@export_range(0.0, 1.0) var hand_opacity_after: float = 0.5
@export var fade_seconds: float = 0.4

@onready var root: Control = $Root
@onready var hand: Sprite2D = $Root/Hand
@onready var door_handle: CanvasItem = $Root/DoorHandle

func play() -> void:
	root.modulate.a = 0.0
	visible = true
	var tween := create_tween()
	tween.tween_property(root, "modulate:a", 1.0, fade_seconds)
	tween.tween_property(hand, "position", reach_to, reach_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	hand.modulate.a = hand_opacity_after
	door_handle.visible = true
	await get_tree().create_timer(hold_seconds).timeout
	tween = create_tween()
	tween.tween_property(root, "modulate:a", 0.0, fade_seconds)
	await tween.finished
	visible = false
