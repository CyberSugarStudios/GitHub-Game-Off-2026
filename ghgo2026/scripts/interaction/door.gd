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

@export_group("Lock")
@export_range(0, 5) var lock_bars: int = 0
@export var transfer_rate: float = 1.5

@export_group("Lock Bar Look")
@export var bar_size := Vector2(0.09, 0.045)
@export var bar_spacing: float = 0.105
@export var bar_texture: Texture2D = preload("res://assets/textures/astral_door_lock_bar.jpg")
#endregion
const LOCK_BAR_SHADER := preload("res://shaders/lock_bar.gdshader")
#region - ONREADY
@onready var lock_icon: Node3D = get_node_or_null("LockIcon")
@onready var bar_row: Node3D = get_node_or_null("LockIcon/BarPips")
#endregion
var lock: DoorLock

var _bar_materials: Array[ShaderMaterial] = []
var _icon_rest_position: Vector3
#endregion

func _ready() -> void:
	super()
	lock = DoorLock.new()
	lock.setup(room_id, lock_bars, transfer_rate)
	add_child(lock)
	lock.progress_changed.connect(_show_progress)
	lock.unlocked.connect(_on_unlocked)
	lock.failed.connect(_play_fail_shake)
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
func get_block_reason() -> String:
	if lock.transferring:
		return "Unlocking..."
	var reason := super()
	if reason != "":
		return reason
	if not is_locked() and not GameState.can_afford(pass_cost):
		return "Not enough energy"
	return ""

func get_living_label() -> String:
	return room_label

func _on_interacted() -> void:
	if is_locked():
		lock.start()
	else:
		if not GameState.try_spend(pass_cost):
			return
		Events.door_opened.emit(room_id, get_exit_transform())
#endregion

#region - LOCK
func _on_unlocked() -> void:
	unlocked.emit()
	_play_unlock_animation()
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
