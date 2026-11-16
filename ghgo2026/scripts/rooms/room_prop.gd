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

@export_group("Art")
@export var art: Node2D
@export var done_reveal: CanvasItem
@export var fall_distance: float = 300.0
@export var fit_to_art: bool = true

@export_group("Hints")
@export var hint_stage: int = -1

@export_group("Sounds")
@export var success_sound: AudioStream
@export var near_miss_sound: AudioStream

var _room_id: StringName
var _rest_position := Vector2.ZERO
var _rest_rotation := 0.0
var _sound: AudioStreamPlayer

func _ready() -> void:
	realm = InteractionRules.Realm.ASTRAL_ONLY
	if done_flag != &"":
		hidden_after_flag = done_flag
	super()
	var node := get_parent()
	while node and not node is Room:
		node = node.get_parent()
	if node:
		_room_id = (node as Room).room_id
	if art:
		_rest_position = art.position
		_rest_rotation = art.rotation
	if fit_to_art:
		_fit_to_art()
	if done_reveal:
		done_reveal.visible = false
	_sound = AudioStreamPlayer.new()
	add_child(_sound)
	Events.power_used.connect(_on_power_used)
	if _is_done():
		_animate(success_anim, true)
		if done_reveal:
			done_reveal.visible = true

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
	Powers.set_target(target_id, accepts)

func _on_power_used(power_id: StringName, id: StringName) -> void:
	if id != target_id or not power_id in accepts:
		return
	if get_viewport() != get_tree().root:
		return
	if _parents_here():
		_play(success_sound)
		if done_flag != &"":
			GameState.set_flag(done_flag)
		await _animate(success_anim, false)
		if done_reveal:
			done_reveal.visible = true
		if success_event != &"":
			Events.story_event.emit(success_event)
	else:
		_play(near_miss_sound)
		GameState.add_near_miss()
		if near_miss_event != &"":
			Events.story_event.emit(near_miss_event)
		await _animate(near_miss_anim, false)

func _is_done() -> bool:
	return done_flag != &"" and GameState.has_flag(done_flag)

func _fit_to_art() -> void:
	var sprite := art as Sprite2D
	var parent := get_parent() as CanvasItem
	if sprite == null or parent == null:
		return
	var art_to_parent := parent.get_global_transform().affine_inverse() * sprite.get_global_transform()
	var rect := art_to_parent * sprite.get_rect()
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = rect.position
	size = rect.size

func _parents_here() -> bool:
	for parent_id in needs_parents:
		if GameState.get_parent_location(parent_id) != _room_id:
			return false
	return true

func _animate(anim: Anim, instant: bool) -> void:
	if art == null or anim == Anim.NONE:
		return
	var tween := create_tween()
	match anim:
		Anim.WOBBLE:
			for degrees in [8.0, -6.0, 3.0, 0.0]:
				tween.tween_property(art, "rotation", _rest_rotation + deg_to_rad(degrees), 0.08)
		Anim.TIP_OVER:
			tween.tween_property(art, "rotation", _rest_rotation + deg_to_rad(90.0), 0.35) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		Anim.FLICKER:
			for i in 6:
				var flash := Color(1.8, 1.8, 1.8) if i % 2 == 0 else Color(0.4, 0.4, 0.5)
				tween.tween_property(art, "modulate", flash, 0.05)
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
