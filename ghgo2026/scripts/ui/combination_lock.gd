class_name CombinationLock
extends Control

signal unlocked
signal close_requested

@export var code: String = "2611"
@export var body_texture: Texture2D
@export var shackle_texture: Texture2D
@export var lock_scale: float = 0.8
@export var dim_color := Color(0.0, 0.0, 0.0, 0.6)

@export_group("Dials")
@export var dial_centers: Array[Vector2] = [Vector2(161, 234), Vector2(318, 230), Vector2(489, 226), Vector2(650, 222)]
@export var dial_size := Vector2(72, 124)
@export var digit_font: Font = preload("res://assets/fonts/josefin_bold.tres")
@export var digit_size: int = 72
@export var digit_color := Color("#2B211D")
@export var hover_color := Color(1.0, 1.0, 1.0, 0.12)

@export_group("Shackle")
@export var shackle_offset := Vector2(122, -363)
@export var hinge_x: float = 502.0
@export var lift: float = 70.0
@export var lift_time: float = 0.25
@export var swing_time: float = 0.45

@export_group("Sounds")
@export var turn_sound: AudioStream = preload("res://assets/audio/sfx/varied/mp3_button.wav")
@export var open_sound: AudioStream = preload("res://assets/audio/sfx/unlocking/Unlocking.wav")

var _digits: Array[int] = []
var _labels: Array[Label] = []
var _root: Control
var _shackle: TextureRect
var _top := 0.0
var _opening := false
var _sound: AudioStreamPlayer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_sound = AudioStreamPlayer.new()
	_sound.bus = &"SFX"
	add_child(_sound)
	_build()
	resized.connect(_layout)

func open() -> void:
	_opening = false
	for i in _digits.size():
		_digits[i] = 0
		_labels[i].text = "0"
		_labels[i].position.y = 0.0
		_labels[i].modulate.a = 1.0
	if _shackle:
		_shackle.position = Vector2(0.0, _top) + shackle_offset
		_shackle.scale = Vector2.ONE
	visible = true
	_layout()

func _layout() -> void:
	if _root:
		_root.scale = Vector2.ONE * lock_scale
		_root.position = (size - _root.size * lock_scale) * 0.5

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = dim_color
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var body_size := body_texture.get_size() if body_texture else Vector2(795, 556)
	_top = maxf(lift - shackle_offset.y, 0.0) if shackle_texture else 0.0
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.size = Vector2(body_size.x, body_size.y + _top)
	add_child(_root)
	if shackle_texture:
		_shackle = TextureRect.new()
		_shackle.texture = shackle_texture
		_shackle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shackle.pivot_offset = Vector2(hinge_x, 0.0)
		_root.add_child(_shackle)
	var body := TextureRect.new()
	body.texture = body_texture
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.position = Vector2(0.0, _top)
	_root.add_child(body)
	for i in dial_centers.size():
		_root.add_child(_make_dial(i, Vector2(0.0, _top) + dial_centers[i] - dial_size * 0.5))
		_digits.append(0)

func _make_dial(index: int, at: Vector2) -> Button:
	var dial := Button.new()
	dial.focus_mode = Control.FOCUS_NONE
	dial.clip_contents = true
	dial.position = at
	dial.size = dial_size
	var hover := StyleBoxFlat.new()
	hover.bg_color = hover_color
	hover.set_corner_radius_all(6)
	for style in ["normal", "focus", "disabled"]:
		dial.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	for style in ["hover", "pressed", "hover_pressed"]:
		dial.add_theme_stylebox_override(style, hover)
	dial.pressed.connect(_turn.bind(index))
	var label := Label.new()
	label.size = dial_size
	label.text = "0"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", digit_font)
	label.add_theme_font_size_override("font_size", digit_size)
	label.add_theme_color_override("font_color", digit_color)
	label.add_theme_constant_override("outline_size", 0)
	dial.add_child(label)
	_labels.append(label)
	return dial

func _turn(index: int) -> void:
	if _opening:
		return
	_digits[index] = (_digits[index] + 1) % 10
	_play(turn_sound)
	var label := _labels[index]
	label.text = str(_digits[index])
	label.position.y = dial_size.y * 0.35
	label.modulate.a = 0.0
	var roll := label.create_tween().set_parallel()
	roll.tween_property(label, "position:y", 0.0, 0.12).set_ease(Tween.EASE_OUT)
	roll.tween_property(label, "modulate:a", 1.0, 0.12)
	var entry := ""
	for digit in _digits:
		entry += str(digit)
	if entry == code:
		_open_lock()

func _open_lock() -> void:
	_opening = true
	_play(open_sound)
	var tween := create_tween()
	if _shackle:
		tween.tween_property(_shackle, "position:y", _shackle.position.y - lift, lift_time) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(_shackle, "scale:x", -1.0, swing_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		tween.tween_property(_root, "scale", Vector2.ONE * lock_scale * 1.05, 0.1)
		tween.tween_property(_root, "scale", Vector2.ONE * lock_scale, 0.15)
	await tween.finished
	unlocked.emit()

func _play(stream: AudioStream) -> void:
	if stream:
		_sound.stream = stream
		_sound.play()
