class_name EventParticles
extends CPUParticles2D

@export var event_id: StringName = &"bathroom_shower_faucet"
@export var emit_seconds: float = 5.5

var _left := 0.0

func _ready() -> void:
	emitting = false
	Events.story_event.connect(_on_story_event)

func _on_story_event(id: StringName) -> void:
	if id != event_id:
		return
	_left = emit_seconds
	emitting = true

func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	if _left <= 0.0:
		emitting = false
