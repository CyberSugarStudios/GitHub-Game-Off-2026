class_name Door
extends Interactable

#region - INIT
signal unlocked

#region - EXPORTS
@export_group("Room Base")
@export var room_id: StringName
@export var room_label: String = ""
@export var exit_distance: float = 0.6
@export var pass_cost: float = 0.0

@export_group("Living Plane")
@export var observe_in_living: bool = true
@export var enterable: bool = true

@export_group("Lock")
@export_range(0, 5) var lock_bars: int = 0
@export var transfer_rate: float = 1.5

@export_group("Lock Bar Look")
@export var bar_size := Vector2(0.09, 0.045)
@export var bar_spacing: float = 0.105
@export var bar_texture: Texture2D = preload("res://assets/textures/astral_door_lock_bar.jpg")

@export_group("Sounds")
@export var unlock_sound: AudioStream = preload("res://assets/audio/sfx/Unlocking.wav")
@export var unlock_pitch_range := Vector2(0.6, 2.0)
#endregion
const LOCK_BAR_SHADER := preload("res://shaders/lock_bar.gdshader")
const PARENT_NAMES: Dictionary[StringName, String] = {
	&"leanne": "Mom",
	&"david": "Dad"
}
#region - ONREADY
@onready var lock_icon: Node3D = get_node_or_null("LockIcon")
@onready var bar_row: Node3D = get_node_or_null("LockIcon/BarPips")
#endregion
var lock: DoorLock

var _bar_materials: Array[ShaderMaterial] = []
var _icon_rest_position: Vector3
var _sound: AudioStreamPlayer3D
var _sound_fade: Tween
#endregion

func _ready() -> void:
	super()
	lock = DoorLock.new()
	lock.setup(room_id, lock_bars, transfer_rate)
	add_child(lock)
	lock.progress_changed.connect(_show_progress)
	lock.unlocked.connect(_on_unlocked)
	lock.failed.connect(_play_fail_shake)
	lock.failed.connect(_fade_unlock_sound)
	_sound = AudioStreamPlayer3D.new()
	_sound.bus = &"SFX"
	add_child(_sound)
	if lock_icon == null:
		return
	_icon_rest_position = lock_icon.position
	_build_bars()
	if is_locked():
		_show_progress(0.0)

func _process(_delta: float) -> void:
	if _bar_materials.is_empty():
		return
	var shown := 1.0 if lock.is_showing_feedback() else DayNight.astral_amount
	for material in _bar_materials:
		material.set_shader_parameter("visibility", shown)

func is_locked() -> bool:
	return lock.is_locked()

#region - INTERACT OVERRIDES
func get_prompt_text() -> String:
	return room_label if _observing() else _with_who_is_inside(prompt_text)

func get_block_reason() -> String:
	if _observing():
		return "" if _observe_cue() != "" else room_label
	var reason := _entry_block_reason()
	return _with_who_is_inside(reason) if reason != "" else ""

func _entry_block_reason() -> String:
	if not enterable:
		return room_label
	if GameState.guarded_room == room_id:
		return "It won't let me near..."
	if lock.transferring:
		return "Using energy..."
	var reason := super.get_block_reason()
	if reason != "":
		return reason
	if not is_locked() and not GameState.can_afford(pass_cost):
		return "Not enough energy"
	return ""

func get_living_label() -> String:
	return room_label

func _on_interacted() -> void:
	if _observing():
		Events.conversation_requested.emit(DoorLock.DOOR_LINES, _observe_cue(), false)
		return
	if is_locked():
		lock.start()
		_play_unlock_sound()
	else:
		if not GameState.try_spend(pass_cost):
			return
		Events.door_opened.emit(room_id, get_exit_transform())

func _observing() -> bool:
	return observe_in_living and not GameState.in_astral

func _observe_cue() -> String:
	var cues := DoorLock.DOOR_LINES.get_cues()
	for cue in ["%s_observe_stage%d" % [room_id, GameState.story_stage], "%s_observe" % room_id]:
		if cue in cues:
			return cue
	return ""

func _with_who_is_inside(text: String) -> String:
	var inside := PackedStringArray()
	for node in get_tree().get_nodes_in_group("hall_parents"):
		var parent := node as HallParent
		if not parent.visible and GameState.get_parent_location(parent.parent_id) == room_id:
			var parent_name: String = PARENT_NAMES.get(parent.parent_id, String(parent.parent_id).capitalize())
			inside.append(parent_name)
	if inside.is_empty():
		return text
	return "%s\n%s %s inside" % [text, " and ".join(inside), "is" if inside.size() == 1 else "are"]
#endregion

#region - LOCK
func _on_unlocked() -> void:
	unlocked.emit()
	_play_unlock_animation()

func _play_unlock_sound() -> void:
	if unlock_sound == null or lock.transfer_rate <= 0.0:
		return
	var length := unlock_sound.get_length()
	var fill_seconds := (lock.lock_bars - lock.progress) / lock.transfer_rate
	if length <= 0.0 or fill_seconds <= 0.0:
		return
	var pitch := clampf(length / fill_seconds, unlock_pitch_range.x, unlock_pitch_range.y)
	if _sound_fade:
		_sound_fade.kill()
	_sound.stream = unlock_sound
	_sound.pitch_scale = pitch
	_sound.volume_db = 0.0
	_sound.play(maxf(length - fill_seconds * pitch, 0.0))

func _fade_unlock_sound() -> void:
	if not _sound.playing:
		return
	_sound_fade = create_tween()
	_sound_fade.tween_property(_sound, "volume_db", -40.0, 0.2)
	_sound_fade.tween_callback(_sound.stop)
#endregion

#region - VISUALS
func _build_bars() -> void:
	for i in lock_bars:
		var quad := QuadMesh.new()
		quad.size = bar_size
		
		var material := ShaderMaterial.new()
		material.shader = LOCK_BAR_SHADER
		material.set_shader_parameter("fill_texture", bar_texture)
		material.set_shader_parameter("aspect", bar_size.x / bar_size.y)
		
		var bar := MeshInstance3D.new()
		bar.mesh = quad
		bar.material_override = material
		bar.position.x = (i - (lock_bars - 1) / 2.0) * bar_spacing
		bar_row.add_child(bar)
		_bar_materials.append(material)

func _show_progress(progress: float) -> void:
	for i in _bar_materials.size():
		_bar_materials[i].set_shader_parameter("fill", clampf(progress - i, 0.0, 1.0))

func _play_unlock_animation() -> void:
	var tween := create_tween().set_parallel()
	for i in _bar_materials.size():
		var material := _bar_materials[i]
		var start := 0.15 + i * 0.08
		tween.tween_method(func(v: float) -> void:
			material.set_shader_parameter("flash", v), 0.0, 1.0, 0.12).set_delay(start)
		tween.tween_method(func(v: float) -> void:
			material.set_shader_parameter("flash", v), 1.0, 0.0, 0.4).set_delay(start + 0.12)
		tween.tween_method(func(v: float) -> void:
			material.set_shader_parameter("opacity", v), 1.0, 0.0, 0.5).set_delay(start + 0.12)
	tween.tween_property(lock_icon, "position:y", _icon_rest_position.y + 0.04, 0.9) \
			.set_delay(0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(lock_icon.hide)

func _play_fail_shake() -> void:
	var tween := create_tween()
	for offset in [0.03, -0.03, 0.02, 0.0]:
		tween.tween_property(lock_icon, "position:x", _icon_rest_position.x + offset, 0.05)
#endregion

func get_exit_transform() -> Transform3D:
	var into_hall := global_basis.z.normalized()
	into_hall.y = 0.0
	var spot := global_position + into_hall * exit_distance
	return Transform3D(Basis.looking_at(into_hall, Vector3.UP), spot)

func _unlock_flag() -> StringName:
	return StringName("door_unlocked_%s" % room_id)
