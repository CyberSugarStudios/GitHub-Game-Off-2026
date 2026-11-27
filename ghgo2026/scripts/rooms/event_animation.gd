class_name EventAnimation
extends AnimatedSprite2D

@export var event_id: StringName = &"bathroom_shower_faucet"
@export var play_seconds: float = 5.5
@export var fade_seconds: float = 0.6

var _left := 0.0
var _tween: Tween

func _ready() -> void:
	visible = false
	Events.story_event.connect(_on_story_event)

func _on_story_event(id: StringName) -> void:
	if id != event_id:
		return
	_left = play_seconds
	if _tween:
		_tween.kill()
	modulate.a = 1.0
	visible = true
	play()

func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	if _left <= 0.0:
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 0.0, fade_seconds)
		_tween.tween_callback(func() -> void:
			stop()
			visible = false)
