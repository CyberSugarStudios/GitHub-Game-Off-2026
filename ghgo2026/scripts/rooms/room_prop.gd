class_name RoomProp
extends RoomHotspot

enum Anim { NONE, WOBBLE, TIP_OVER, FLICKER, FALL }

@export_group("Power Target")
@export var target_id: StringName
@export var accepts: Array[StringName] = []

@export_group("Reaction")
@export var needs_parents: Array[StringName] = []
@export var success_event: StringName
@export var near_miss_event: StringName
@export var done_flag: StringName
@export var success_anim: Anim = Anim.TIP_OVER
@export var near_miss_anim: Anim = Anim.WOBBLE
@export var only_during: StringName
@export var works_during: StringName
@export var guarded_by: Array[StringName] = []
@export var caught_anim: Anim = Anim.WOBBLE
@export var caught_dialogue: DialogueResource
@export var caught_cue: String
@export var caught_awake_minutes: int = 10

@export_group("Art")
@export var art: Node2D
@export var done_reveal: CanvasItem
@export var fall_distance: float = 300.0
@export var fit_to_art: bool = true
@export var art_always_visible: bool = false
@export var active_texture: Texture2D
@export var hide_art_when_done: bool = false

@export_group("Hints")
@export var hint_stage: int = -1

@export_group("Sounds")
@export var success_sound: AudioStream
@export var near_miss_sound: AudioStream

var _room_id: StringName
var _rest_position := Vector2.ZERO
var _rest_rotation := 0.0
var _sound: AudioStreamPlayer
var _done_shown := false
var _tipped := false
var _base_texture: Texture2D
var _art_gone := false

func _ready() -> void:
	realm = InteractionRules.Realm.ASTRAL_ONLY
	if done_flag != &"":
		hidden_after_flag = done_flag
	var node := get_parent()
	while node and not node is Room:
		node = node.get_parent()
	if node:
		_room_id = (node as Room).room_id
	super()
	if art:
		_rest_position = art.position
		_rest_rotation = art.rotation
	if fit_to_art:
		_fit_to_art()
	if done_reveal:
		done_reveal.visible = false
	_sound = AudioStreamPlayer.new()
	_sound.bus = &"SFX"
	add_child(_sound)
	Events.power_used.connect(_on_power_used)
	GameState.flag_set.connect(_on_flag_set)
	GameState.flag_cleared.connect(_on_flag_cleared)
	if _is_done():
		_done_shown = true
		_animate(success_anim, true)
		_show_done()
	GameState.parent_activity_changed.connect(_on_parent_changed)
	GameState.parent_location_changed.connect(_on_parent_changed)
	_update_art()

func _process(_delta: float) -> void:
	if art == null or hint_stage < 0:
		return
	var glow := 0.0
	if GameState.story_stage == hint_stage and not _is_done():
		var level := GameState.get_hint_level()
		glow = (0.3 + 0.3 * level) * DayNight.astral_amount
		if level >= 3:
			glow *= 0.75 + 0.25 * sin(Time.get_ticks_msec() / 250.0)
	art.self_modulate = Color(1.0 + glow, 1.0 + glow, 1.0 + glow)

func _on_interacted() -> void:
	Powers.set_target(target_id, accepts, self)

func _on_power_used(power_id: StringName, id: StringName) -> void:
	if id != target_id or not power_id in accepts:
		return
	if get_viewport() != get_tree().root:
		return
	if _guarded():
		_wake_guards()
		_play(near_miss_sound)
		GameState.add_near_miss()
		if caught_dialogue and caught_cue != "":
			Events.conversation_requested.emit(caught_dialogue, caught_cue, false)
		await  _animate(caught_anim, false)
		return

	if _parents_here():
		_play(success_sound)
		_done_shown = true
		if done_flag != &"":
			GameState.set_flag(done_flag)
		await _animate(success_anim, false)
		_show_done()
		if success_event != &"":
			Events.story_event.emit(success_event)
	else:
		_play(near_miss_sound)
		GameState.add_near_miss(target_id)
		if near_miss_event != &"":
			Events.story_event.emit(near_miss_event)
		await _animate(near_miss_anim, false)

func _wake_guards() -> void:
	for parent_id in guarded_by:
		if GameState.get_parent_location(parent_id) == _room_id and GameState.is_parent_asleep(parent_id):
			GameState.keep_awake(parent_id, caught_awake_minutes)

func _guarded() -> bool:
	for parent_id in guarded_by:
		if GameState.get_parent_location(parent_id) == _room_id:
			return true
	return false

func _on_flag_set(id: StringName) -> void:
	if id != done_flag or _done_shown:
		return
	_done_shown = true
	await _animate(success_anim, false)
	_show_done()

func _show_done() -> void:
	if done_reveal:
		done_reveal.visible = true
	if hide_art_when_done:
		_art_gone = true
		_update_art()

func _on_flag_cleared(id: StringName) -> void:
	if id != done_flag or not _done_shown:
		return
	_done_shown = false
	if art:
		art.position = _rest_position
		art.rotation = _rest_rotation
		art.modulate = Color.WHITE
		_tipped = false
		_art_gone = false
		_update_art()
	if done_reveal:
		done_reveal.visible = false
	_refresh()

func _is_done() -> bool:
	return done_flag != &"" and GameState.has_flag(done_flag)

func _fit_to_art() -> void:
	var sprite := art as Sprite2D
	var parent := get_parent() as CanvasItem
	if sprite == null or parent == null:
		return
	var art_to_parent := parent.get_global_transform().affine_inverse() * sprite.get_global_transform()
	var rect := art_to_parent * sprite.get_rect()
	var before := position
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = rect.position
	size = rect.size
	var moved := position - before
	for child in get_children():
		if child is Node2D:
			(child as Node2D).position -= moved

func _parents_here() -> bool:
	for parent_id in needs_parents:
		if GameState.get_parent_location(parent_id) != _room_id:
			return false
		if works_during != &"" and GameState.get_parent_activity(parent_id) != works_during:
			return false
	return true

func _on_parent_changed(_id: StringName, _value: StringName) -> void:
	_refresh()
	_update_art()

func _is_available() -> bool:
	return _exists()

func _exists() -> bool:
	if only_during == &"":
		return true
	for parent_id in GameState.parent_activities:
		if GameState.parent_activities[parent_id] == only_during \
			and GameState.get_parent_location(parent_id) == _room_id:
				return true
	return false

func _update_art() -> void:
	if art == null:
		return
	art.visible = (art_always_visible or _exists()) and not _art_gone
	var sprite := art as Sprite2D
	if sprite and active_texture:
		if _base_texture == null:
			_base_texture = sprite.texture
		sprite.texture = active_texture if _exists() and not _tipped else _base_texture

func _animate(anim: Anim, instant: bool) -> void:
	if art == null or anim == Anim.NONE:
		return
	if anim == Anim.TIP_OVER or anim == Anim.FALL:
		_tipped = true
		_update_art()
	var tween := create_tween()
	match anim:
		Anim.WOBBLE:
			for degrees in [8.0, -6.0, 3.0, 0.0]:
				tween.tween_property(art, "rotation", _rest_rotation + deg_to_rad(degrees), 0.08)
		Anim.TIP_OVER:
			tween.tween_property(art, "rotation", _rest_rotation + deg_to_rad(90.0), 0.35) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		Anim.FLICKER:
			var flashes := 1 if Settings.reduce_flashing else 3
			var bright := Color(1.3, 1.3, 1.3) if Settings.reduce_flashing else Color(1.8, 1.8, 1.8)
			var dark := Color(0.7, 0.7, 0.75) if Settings.reduce_flashing else Color(0.4, 0.4, 0.5)
			for i in flashes * 2:
				tween.tween_property(art, "modulate", bright if i % 2 == 0 else dark, 0.17)
			tween.tween_property(art, "modulate", Color.WHITE, 0.1)
		Anim.FALL:
			tween.tween_property(art, "position:y", _rest_position.y + fall_distance, 0.45) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.parallel().tween_property(art, "rotation", _rest_rotation + deg_to_rad(25.0), 0.45)
	if instant:
		tween.custom_step(10.0)
	else:
		await tween.finished

func _play(stream: AudioStream) -> void:
	if stream:
		_sound.stream = stream
		_sound.play()
