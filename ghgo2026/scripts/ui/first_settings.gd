extends Control

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const OPTIONS_PANEL := preload("res://scenes/ui/OptionsPanel.tscn")

@export var reference_image: Texture2D
@export var fade_time: float = 0.6

var _leaving := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("#0B0B0B")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	page.add_theme_constant_override("separation", 16)
	add_child(page)
	
	var heading := Label.new()
	heading.text = "Before you begin"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 36)
	page.add_child(heading)
	
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 48)
	page.add_child(columns)
	
	var tests := _make_calibration()
	tests.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tests.size_flags_stretch_ratio = 1.0
	columns.add_child(tests)
	
	var panel := OPTIONS_PANEL.instantiate() as OptionsPanel
	panel.font_size = 22
	panel.close_text = "CONTINUE"
	panel.closed.connect(_continue)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.size_flags_stretch_ratio = 2.0
	columns.add_child(panel)
	panel.add_theme_constant_override("separation", 8)
	
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, fade_time)

func _make_calibration() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.size_flags_vertical = Control.SIZE_FILL
	if reference_image:
		var picture := TextureRect.new()
		picture.texture = reference_image
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(480, 270)
		picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(picture)
	
	var dark := ColorRect.new()
	dark.color = Color.BLACK
	dark.custom_minimum_size = Vector2(480, 120)
	var word := Label.new()
	word.text = "Interim"
	word.add_theme_font_size_override("font_size", 64)
	word.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	word.add_theme_constant_override("outline_size", 0)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	word.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.add_child(word)
	box.add_child(dark)
	box.add_child(_hint("Raise Gamma until the word above is only just visible."))
	
	var ramp := HBoxContainer.new()
	ramp.add_theme_constant_override("separation", 0)
	ramp.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 10:
		var step := ColorRect.new()
		var value := i / 9.0
		step.color = Color(value, value, value)
		step.custom_minimum_size = Vector2(48, 48)
		ramp.add_child(step)
	box.add_child(ramp)
	box.add_child(_hint("Set Brightness and Contrast so all ten steps look different."))
	return box

func _hint(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 480
	label.add_theme_font_size_override("font_size", 20)
	return label

func _continue() -> void:
	if _leaving:
		return
	_leaving = true
	Settings.save_settings()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	await tween.finished
	var title := ResourceLoader.load_threaded_get(TITLE_SCENE) as PackedScene
	if title:
		get_tree().change_scene_to_packed(title)
	else:
		get_tree().change_scene_to_file(TITLE_SCENE)
