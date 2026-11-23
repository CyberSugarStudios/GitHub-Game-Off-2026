class_name ActivitySound
extends AudioStreamPlayer

@export var parent_id: StringName = &"leanne"
@export var activity: StringName
@export var every_seconds := Vector2.ZERO
@export var fade_time: float = 0.6

var _room_id: StringName
var _active := false
var _wait := 0.0
var _level_db := 0.0
var _tween: Tween

func _ready() -> void:
	bus = &"SFX"
	_level_db = volume_db
	var node := get_parent()
	while node and not node is Room:
		node = node.get_parent()
	if node == null or (node as Room).is_preview:
		set_process(false)
		return
	_room_id = (node as Room).room_id
	GameState.parent_activity_changed.connect(_on_parent_changed)
	GameState.parent_location_changed.connect(_on_parent_changed)
	_refresh()

func _on_parent_changed(id: StringName, _value: StringName) -> void:
	if id == parent_id:
		_refresh()

func _refresh() -> void:
	var on := GameState.get_parent_location(parent_id) == _room_id \
		and GameState.get_parent_activity(parent_id) == activity
	if on == _active:
		return
	_active = on
	if not on:
		_fade_out()
	elif every_seconds == Vector2.ZERO:
		_fade_in()
	else:
		_wait = randf_range(0.3, every_seconds.x)

func _process(delta: float) -> void:
	if not _active or every_seconds == Vector2.ZERO or playing:
		return
	_wait -= delta
	if _wait <= 0.0:
		volume_db = _level_db
		pitch_scale = randf_range(0.95, 1.05)
		play()
		_wait = randf_range(every_seconds.x, every_seconds.y)

func _fade_in() -> void:
	if _tween:
		_tween.kill()
	volume_db = -40.0
	play()
	_tween = create_tween()
	_tween.tween_property(self, "volume_db", _level_db, fade_time)

func _fade_out() -> void:
	if _tween:
		_tween.kill()
	if not playing:
		return
	_tween = create_tween()
	_tween.tween_property(self, "volume_db", -40.0, fade_time)
	_tween.tween_callback(stop)
