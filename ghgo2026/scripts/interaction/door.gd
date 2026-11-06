class_name Door
extends Interactable

#region - INIT
signal unlocked

#region - EXPORTS
@export var room_id: StringName
@export var exit_distance: float = 0.6

@export_group("Lock")
@export_range(0, 5) var lock_bars: int = 0
@export var transfer_rate: float = 1.5
@export var unlocked_padlock_texture: Texture2D

@export_group("Lock Bar Look")
@export var bar_size := Vector2(0.16, 0.035)
@export var bar_spacing: float = 0.05
#endregion
const LOCK_BAR_SHADER := preload("res://shaders/lock_bar.gdshader")
#region - ONREADY
@onready var lock_icon: Node3D = $LockIcon
@onready var padlock: Sprite3D = $LockIcon/PadLock
@onready var bar_row: Node3D = $LockIcon/BarPips
#endregion
var _bar_materials: Array[ShaderMaterial] = []
var _progress := 0.0
var _transferring := false
var _icon_rest_position: Vector3
#endregion

func _ready() -> void:
	super()
	_icon_rest_position = lock_icon.position
	_build_bars()
	if is_locked():
		_set_progress(0.0)
	else:
		lock_icon.visible = false

func is_locked() -> bool:
	return lock_bars > 0 and not GameState.has_flag(_unlock_flag())

#region - INTERACT OVERRIDES
func get_prompt_text() -> String:
	if is_locked():
		return "Unlock (%d bars)" % lock_bars
	return prompt_text

func get_block_reason() -> String:
	if _transferring:
		return "Unlocking..."
	var reason := super()
	if reason != "":
		return reason
	if is_locked() and GameState.energy <= 0.0:
		return "No energy to unlock"
	return ""

func _on_interacted() -> void:
	if is_locked():
		_transferring = true
	else:
		Events.door_opened.emit(room_id, get_exit_transform())
		print("Door opened > room: ", room_id)
#endregion

#region - ENERGY
func _physics_process(delta: float) -> void:
	if not _transferring:
		return
	
	var wanted := minf(transfer_rate * delta, lock_bars - _progress)
	var spent := minf(wanted, GameState.energy)
	if spent > 0.0:
		GameState.try_spend(spent)
		_set_progress(_progress +  spent)
	
	if _progress >= lock_bars - 0.0001:
		_finish_unlock()
	elif spent < wanted:
		_fail_unlock()

func _finish_unlock() -> void:
	_transferring = false
	_set_progress(lock_bars)
	GameState.set_flag(_unlock_flag())
	unlocked.emit()
	_play_unlock_animation()

func _fail_unlock() -> void:
	_transferring = false
	_play_fail_shake()
	
	var drain := create_tween()
	drain.tween_interval(0.3)
	drain.tween_method(_set_progress, _progress, 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
#endregion

#region - VISUALS
func _build_bars() -> void:
	for i in lock_bars:
		var quad := QuadMesh.new()
		quad.size = bar_size
		
		var material := ShaderMaterial.new()
		material.shader = LOCK_BAR_SHADER
		
		var bar := MeshInstance3D.new()
		bar.mesh = quad
		bar.material_override = material
		bar.position.y = i * bar_spacing
		bar_row.add_child(bar)
		_bar_materials.append(material)

func _set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, lock_bars)
	for i in _bar_materials.size():
		_bar_materials[i].set_shader_parameter("fill", clampf(_progress - i, 0.0, 1.0))

func _play_unlock_animation() -> void:
	if unlocked_padlock_texture:
		padlock.texture = unlocked_padlock_texture
	var tween := create_tween()
	tween.tween_interval(0.25)
	tween.tween_property(lock_icon, "scale", Vector3.ONE * 1.25, 0.15).set_trans(Tween.TRANS_BACK) \
	.set_ease(Tween.EASE_OUT)
	tween.tween_property(lock_icon, "scale", Vector3.ONE * 0.01, 0.3).set_trans(Tween.TRANS_BACK) \
	.set_ease(Tween.EASE_IN)
	tween.tween_callback(lock_icon.hide)

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
