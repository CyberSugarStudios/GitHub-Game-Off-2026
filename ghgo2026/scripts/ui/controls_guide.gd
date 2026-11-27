class_name ControlsGuide
extends Control

signal closed

const KEY_PROMPT := preload("res://scenes/ui/key_prompt.tscn")
const TITLE_BUTTON := preload("res://scenes/ui/title_button.tscn")
const UI_THEME := preload("res://resources/interim_theme.tres")
const ALLURA := preload("res://assets/fonts/Allura-Regular.ttf")
const CLICK_SHEET := preload("res://assets/sprites/ui/clicking.webp")
const SWIPE_SHEET := preload("res://assets/sprites/ui/swiping.webp")
const TEAL := Color(0.4392157, 0.6862745, 0.6392157)

@export var next_scene: String = "res://scenes/ui/title_screen.tscn"
@export var heading_text: String = "How to play"
@export var hall_controls: PackedStringArray = [
	"W A S D|Move",
	"Mouse|Look around",
	"E    or Click|Open doors and interact",
	"Shift|Cross between planes",
	"Scroll or 1 2 3|Choose a power",
	"E    or Click|Use the chosen power",
	"Space|Struggle free (Change in options to hold)",
	"H|Ask for a hint",
	"Esc or P|Pause and settings",
]
@export var room_controls: PackedStringArray = [
	"A D or Mouse|Look left and right",
	"Click|Interact",
	"S|Leave the room",
]
@export var tips: PackedStringArray = [
	"Time keeps moving while you explore. Use the living room clock to wait an hour, or until night or morning.",
	"Your parents follow their own routines. Look into a room from the hall to see who's inside and what they're doing.",
	"Your parents only open up to each other when they're in the same room. Find ways to bring them together.",
	"Powers use energy. It refills faster while you're in the living world.",
	"Stuck? Press H for a hint.",
]
@export var font_size: int = 24
@export var key_height: float = 34.0
@export var fade_time: float = 0.5

var _leaving := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI_THEME
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var background := ColorRect.new()
	background.color = Color(0.043, 0.043, 0.043, 0.97)
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	margin.add_child(page)
	page.add_child(_heading(heading_text, 90, HORIZONTAL_ALIGNMENT_CENTER))

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 80)
	page.add_child(columns)

	var left := _column(columns)
	left.add_child(_heading("In the hall", 56))
	for line in hall_controls:
		left.add_child(_control_row(line))

	var right := _column(columns)
	right.add_child(_heading("In rooms", 56))
	for line in room_controls:
		right.add_child(_control_row(line))
	right.add_child(_heading("How it works", 56))
	for tip in tips:
		right.add_child(_tip(tip))

	var button := TITLE_BUTTON.instantiate() as TitleButton
	button.text = "CONTINUE" if next_scene != "" else "CLOSE"
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_leave)
	page.add_child(button)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, fade_time)

func _column(parent: Control) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	parent.add_child(column)
	return column

func _heading(text: String, heading_size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_override("font", ALLURA)
	label.add_theme_font_size_override("font_size", heading_size)
	label.add_theme_color_override("font_color", TEAL)
	return label

func _control_row(line: String) -> HBoxContainer:
	var parts := line.split("|")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var keys := HBoxContainer.new()
	keys.custom_minimum_size.x = 240.0
	keys.alignment = BoxContainer.ALIGNMENT_END
	keys.add_theme_constant_override("separation", 6)
	row.add_child(keys)
	if parts[0].strip_edges() == "W A S D":
		keys.add_child(_wasd())
	else:
		for token in parts[0].split(" ", false):
			keys.add_child(_key(token))
	var action := Label.new()
	action.text = parts[1] if parts.size() > 1 else ""
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action.add_theme_font_size_override("font_size", font_size)
	row.add_child(action)
	return row

func _wasd() -> VBoxContainer:
	var cluster := VBoxContainer.new()
	cluster.add_theme_constant_override("separation", 4)
	var top := _key("W")
	top.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cluster.add_child(top)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 4)
	for letter in ["A", "S", "D"]:
		bottom.add_child(_key(letter))
	cluster.add_child(bottom)
	return cluster

func _key(token: String) -> Control:
	if token == "or":
		var word := Label.new()
		word.text = "or"
		word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		word.add_theme_font_size_override("font_size", roundi(font_size * 0.8))
		return word
	var prompt := KEY_PROMPT.instantiate() as KeyPrompt
	prompt.key_height = key_height
	prompt.font_size = font_size
	prompt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	match token:
		"Click":
			prompt.icon_sheet = CLICK_SHEET
			prompt.icon_frames = 7
			prompt.icon_fps = 4.5
			prompt.icon_height = key_height * 1.3
			prompt.show_prompt("", "")
		"Mouse":
			prompt.icon_sheet = SWIPE_SHEET
			prompt.icon_frames = 25
			prompt.icon_fps = 12.0
			prompt.icon_height = key_height * 1.3
			prompt.show_prompt("", "")
		_:
			prompt.show_prompt(token, "")
	return prompt

func _tip(text: String) -> Label:
	var label := Label.new()
	label.text = "•  " + text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1.0
	label.add_theme_font_size_override("font_size", font_size - 2)
	return label

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") \
			or event.is_action_pressed("ui_accept"):
		_leave()
		get_viewport().set_input_as_handled()

func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	await tween.finished
	if next_scene == "":
		closed.emit()
		queue_free()
		return
	Settings.onboarding_seen = Settings.ONBOARDING_VERSION
	Settings.save_settings()
	if ResourceLoader.load_threaded_get_status(next_scene) == ResourceLoader.THREAD_LOAD_LOADED:
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(next_scene) as PackedScene)
	else:
		get_tree().change_scene_to_file(next_scene)
