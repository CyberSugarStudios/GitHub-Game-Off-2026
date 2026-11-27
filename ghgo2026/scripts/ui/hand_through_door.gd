class_name HandThroughDoor
extends CanvasLayer

@export var hold_seconds: float = 0.5
@export var fade_seconds: float = 0.4

@onready var root: Control = $Root
@onready var hand: AnimatedSprite2D = $Root/Hand

func play() -> void:
	root.modulate.a = 0.0
	hand.stop()
	hand.frame = 0
	visible = true
	var tween := create_tween()
	tween.tween_property(root, "modulate:a", 1.0, fade_seconds)
	await tween.finished
	hand.play()
	await hand.animation_finished
	await get_tree().create_timer(hold_seconds).timeout
	tween = create_tween()
	tween.tween_property(root, "modulate:a", 0.0, fade_seconds)
	await tween.finished
	visible = false
