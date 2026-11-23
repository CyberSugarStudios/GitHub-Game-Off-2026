class_name DiaryKeypad
extends Control

signal unlocked
signal close_requested

const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "Clear", "0", "Back"]

@export var code: String = "2611"
@export var caption_text: String = "Locked"
@export var digit_font: Font = preload("res://assets/fonts/Caveat-Bold.ttf")
@export var key_size := Vector2(104, 80)

@export_group("Colours")
@export var cover_color := Color("#51403B")
@export var key_color := Color("#5F584F")
@export var trim_color := Color("#B6AE9A")
@export var paper_color := Color("#CCCDC4")
@export var ink_color := Color("#23434A")
@export var wrong_color := Color("#5D1515")
@export var right_color := Color("#70AFA3")

@export_group("Sounds")
@export var press_sound: AudioStream
@export var wrong_sound: AudioStream
@export var right_sound: AudioStream

var _entry := ""
var _checking := false
var _cover: PanelContainer
var _slots: Array[Label] = []
var _sound: AudioStreamPlayer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_sound = AudioStreamPlayer.new()
	_sound.bus = &"SFX"
	add_child(_sound)
	_build()

func open() -> void:
	_entry = ""
	_checking = false
	_show_entry(ink_color)
	visible = true

#region - BUILD
func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_cover = PanelContainer.new()
	_cover.add_theme_stylebox_override("panel", _box(cover_color, trim_color, 18, 32))
	center.add_child(_cover)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	_cover.add_child(column)

	var caption := _handwriting(caption_text, 44)
	caption.add_theme_color_override("font_color", paper_color)
	column.add_child(caption)

	var display := HBoxContainer.new()
	display.alignment = BoxContainer.ALIGNMENT_CENTER
	display.add_theme_constant_override("separation", 12)
	column.add_child(display)
	for i in code.length():
		var slot := _handwriting("", 64)
		slot.custom_minimum_size = Vector2(64, 84)
		slot.add_theme_stylebox_override("normal", _box(paper_color, Color.TRANSPARENT, 8, 0))
		display.add_child(slot)
		_slots.append(slot)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)
	for key in KEYS:
		var button := _make_key(key)
		button.pressed.connect(_on_key.bind(key))
		grid.add_child(button)

	var close_button := _make_key("Close")
	close_button.custom_minimum_size = Vector2(key_size.x * 1.5, 56)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close_requested.emit)
	column.add_child(close_button)

func _make_key(label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = key_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 40 if label_text.length() == 1 else 24)
	var pressed_box := _box(cover_color.darkened(0.3), right_color, 10, 0)
	button.add_theme_stylebox_override("normal", _box(key_color, trim_color, 10, 0))
	button.add_theme_stylebox_override("hover", _box(key_color.lightened(0.15), right_color, 10, 0))
	button.add_theme_stylebox_override("pressed", pressed_box)
	button.add_theme_stylebox_override("hover_pressed", pressed_box)
	button.add_theme_color_override("font_pressed_color", paper_color)
	button.add_theme_color_override("font_hover_pressed_color", paper_color)
	return button

func _handwriting(label_text: String, text_size: int) -> Label:
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", digit_font)
	label.add_theme_font_size_override("font_size", text_size)
	label.add_theme_constant_override("outline_size", 0)
	return label

func _box(fill: Color, border: Color, radius: int, margin: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(0 if border.a == 0.0 else 3)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	return box
#endregion

#region - INPUT
func _on_key(key: String) -> void:
	if _checking:
		return
	match key:
		"Clear":
			_entry = ""
		"Back":
			_entry = _entry.left(-1)
		_:
			if _entry.length() < code.length():
				_entry += key
	_play(press_sound)
	_show_entry(ink_color)
	if _entry.length() == code.length():
		_check()

func _check() -> void:
	_checking = true
	if _entry == code:
		_play(right_sound)
		_show_entry(right_color)
		unlocked.emit()
		return
	_play(wrong_sound)
	_show_entry(wrong_color)
	var home := _cover.position.x
	var tween := create_tween()
	for shove: float in [14.0, -12.0, 9.0, -6.0, 0.0]:
		tween.tween_property(_cover, "position:x", home + shove, 0.05)
	tween.tween_interval(0.4)
	await tween.finished
	_entry = ""
	_checking = false
	_show_entry(ink_color)

func _show_entry(color: Color) -> void:
	for i in _slots.size():
		_slots[i].text = _entry[i] if i < _entry.length() else ""
		_slots[i].add_theme_color_override("font_color", color)

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not visible or key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_BACKSPACE:
		_on_key("Back")
	elif key.unicode >= 48 and key.unicode <= 57:
		_on_key(char(key.unicode))
	else:
		return
	get_viewport().set_input_as_handled()

func _play(stream: AudioStream) -> void:
	if stream:
		_sound.stream = stream
		_sound.play()
#endregion
