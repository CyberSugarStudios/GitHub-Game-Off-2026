class_name Door
extends Interactable

@export var room_id: StringName
@export var pip_unlocked_color := Color(0.3, 0.8, 1.0)
@export var pip_missing_color := Color(0.25, 0.25, 0.3)
@export var pip_size := Vector2(0.04, 0.1)
@export var pip_spacing: float = 0.07

@onready var lock_icon: Node3D = $LockIcon
@onready var bar_pips: Node3D = $LockIcon/BarPips

func _ready() -> void:
	super()
	_build_pips()
	GameState.max_bars_changed.connect(_refresh_lock)
	_refresh_lock(GameState.max_bars)

func _on_interacted() -> void:
	Events.door_opened.emit(room_id)
	print("Door opened > room: ", room_id)

func _build_pips() -> void:
	for i in required_bars:
		var quad := QuadMesh.new()
		quad.size = pip_size
		
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		
		var pip := MeshInstance3D.new()
		pip.mesh = quad
		pip.material_override = material
		pip.position.x = (i - (required_bars - 1) / 2.0) * pip_spacing
		bar_pips.add_child(pip)

func _refresh_lock(max_bars: int) -> void:
	var locked := not GameState.has_unlocked_bars(required_bars)
	lock_icon.visible = required_bars > 0 and locked
	for i in bar_pips.get_child_count():
		var pip := bar_pips.get_child(1) as MeshInstance3D
		var material := pip.material_override as StandardMaterial3D
		material.albedo_color  = pip_unlocked_color if i < max_bars else pip_missing_color
