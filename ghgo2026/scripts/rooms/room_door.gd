class_name RoomDoor
extends RoomHotspot

signal unlocked

@export_group("Door")
@export var door_id: StringName
@export var leads_to: StringName
@export_range(0, 5) var lock_bars: int = 0
@export var transfer_rate: float = 6.25

@export_group("Lock Bar Look")
@export var bar_size := Vector2(120, 60)
@export var bar_spacing: int = 20

@onready var bar_row: HBoxContainer = get_node_or_null("BarRow")

var lock: DoorLock
var _bars: Array[PillBar] = []
var _bar_rest_x := 0.0

func _ready() -> void:
	lock = DoorLock.new()
	lock.setup(door_id, lock_bars, transfer_rate)
	add_child(lock)
	lock.progress_changed.connect(_show_progress)
	lock.unlocked.connect(_on_unlocked)
	lock.failed.connect(_play_fail_shake)
	super()
	if bar_row:
		bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_row.add_theme_constant_override("separation", bar_spacing)
		_bar_rest_x = bar_row.position.x
		_build_bars()
		if lock.is_locked():
			_show_progress(0.0)

func _process(_delta: float) -> void:
	if bar_row:
		bar_row.modulate.a = 1.0 if lock.is_showing_feedback() else DayNight.astral_amount

func get_block_reason() -> String:
	if lock.transferring:
		return "Unlocking..."
	return super()

func _on_interacted() -> void:
	if lock.is_locked():
		lock.start()
	else:
		Events.story_event.emit(StringName("%s_opened" % door_id))
		if leads_to != &"":
			Events.room_door_opened.emit(leads_to)

func _build_bars() -> void:
	for i in lock_bars:
		var bar := PillBar.new()
		bar.custom_minimum_size = bar_size
		bar_row.add_child(bar)
		_bars.append(bar)

func _show_progress(progress: float) -> void:
	for i in _bars.size():
		_bars[i].value = clampf(progress - i, 0.0, 1.0)

func _on_unlocked() -> void:
	unlocked.emit()
	var tween := create_tween().set_parallel()
	for i in _bars.size():
		var bar_material := _bars[i].material as ShaderMaterial
		var set_flash := func(v: float) -> void:
			bar_material.set_shader_parameter("flash", v)
		var set_opacity := func(v: float) -> void:
			bar_material.set_shader_parameter("opacity", v)
		var start := 0.15 + i * 0.08
		tween.tween_method(set_flash, 0.0, 1.0, 0.12).set_delay(start)
		tween.tween_method(set_flash, 1.0, 0.0, 0.4).set_delay(start + 0.12)
		tween.tween_method(set_opacity, 1.0, 0.0, 0.5).set_delay(start + 0.12)
	tween.chain().tween_callback(bar_row.hide)

func _play_fail_shake() -> void:
	var tween := create_tween()
	for offset in [12.0, -12.0, 8.0, 0.0]:
		tween.tween_property(bar_row, "position:x", _bar_rest_x + offset, 0.05)
