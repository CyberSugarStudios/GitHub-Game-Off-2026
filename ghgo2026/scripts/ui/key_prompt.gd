@tool
class_name KeyPrompt
extends HBoxContainer

const KEY_ART := preload("res://assets/sprites/letter_key.png")
const WIDE_KEY_ART := preload("res://assets/sprites/shift.png")
const SEMIBOLD := preload("res://assets/fonts/josefin_semibold.tres")
const INK_SHADER := preload("res://shaders/ink_tint.gdshader")

@export var key: String = "E":
	set(value):
		key = value
		_refresh()
@export var prefix: String = "":
	set(value):
		prefix = value
		_refresh()
@export_multiline var text: String = "":
	set(value):
		text = value
		_refresh()
@export var key_height: float = 44.0:
	set(value):
		key_height = value
		_refresh()
@export var font_size: int = 30:
	set(value):
		font_size = value
		_refresh()
@export var key_color := Color(0.8, 0.804, 0.769)
@export var scaled_keys: PackedStringArray = ["Space"]
@export var scaled_key_size: float = 1.12

@export_group("Animated Icon")
@export var icon_sheet: Texture2D:
	set(value):
		icon_sheet = value
		_frame = 0
		_refresh()
@export var icon_frames: int = 1
@export var icon_fps: float = 8.0
@export var icon_height: float = 72.0

var _atlas: AtlasTexture
var _ink: ShaderMaterial
var _frame := 0
var _frame_time := 0.0

func show_prompt(new_key: String, new_text: String, new_prefix: String = "") -> void:
	key = new_key
	text = new_text
	prefix = new_prefix

func _ready() -> void:
	_refresh()

func _process(delta: float) -> void:
	if icon_sheet == null or icon_frames <= 1 or not is_visible_in_tree():
		return
	_frame_time += delta
	var step := 1.0 / maxf(icon_fps, 0.01)
	while _frame_time >= step:
		_frame_time -= step
		_frame = (_frame + 1) % icon_frames
	_show_frame()

func _show_frame() -> void:
	if _atlas == null or icon_sheet == null:
		return
	var width := float(icon_sheet.get_width()) / maxi(icon_frames, 1)
	_atlas.region = Rect2(width * _frame, 0.0, width, icon_sheet.get_height())

func _refresh() -> void:
	if not is_node_ready():
		return
	var prefix_label := $Prefix as Label
	var key_rect := $Key as TextureRect
	var key_label := $Key/KeyLabel as Label
	var text_label := $Text as RichTextLabel
	prefix_label.text = prefix
	prefix_label.visible = prefix != ""
	prefix_label.add_theme_font_size_override("font_size", font_size)

	var wide := key.length() > 1
	key_rect.visible = key != "" or icon_sheet != null
	if icon_sheet:
		if _atlas == null:
			_atlas = AtlasTexture.new()
			_atlas.filter_clip = true
		if _ink == null:
			_ink = ShaderMaterial.new()
			_ink.shader = INK_SHADER
		_ink.set_shader_parameter("ink", key_color)
		_atlas.atlas = icon_sheet
		_show_frame()
		key_rect.texture = _atlas
		key_rect.material = _ink
		var frame_width := float(icon_sheet.get_width()) / maxi(icon_frames, 1)
		key_rect.custom_minimum_size = Vector2(icon_height * frame_width / icon_sheet.get_height(), icon_height)
	else:
		key_rect.material = null
		key_rect.texture = WIDE_KEY_ART if wide else KEY_ART
		var art := key_rect.texture
		var height := key_height * (scaled_key_size if key in scaled_keys else 1.0)
		key_rect.custom_minimum_size = Vector2(height * art.get_width() / art.get_height(), height)

	key_label.text = "" if icon_sheet else key
	key_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	key_label.anchor_bottom = 0.76
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.add_theme_font_override("font", SEMIBOLD)
	key_label.add_theme_font_size_override("font_size", roundi(key_height * (0.4 if wide else 0.5)))
	key_label.add_theme_color_override("font_color", key_color)
	text_label.text = text
	text_label.visible = text != ""
	text_label.add_theme_font_override("bold_font", SEMIBOLD)
	text_label.add_theme_font_size_override("normal_font_size", font_size)
	text_label.add_theme_font_size_override("bold_font_size", font_size)
