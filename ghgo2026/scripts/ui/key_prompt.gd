@tool
class_name KeyPrompt
extends HBoxContainer

const KEY_ART := preload("res://assets/sprites/letter_key.png")
const WIDE_KEY_ART := preload("res://assets/sprites/shift.png")
const SEMIBOLD := preload("res://assets/fonts/josefin_semibold.tres")

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
@export var icon: Texture2D:
	set(value):
		icon = value
		_refresh()

func show_prompt(new_key: String, new_text: String, new_prefix: String = "") -> void:
	key = new_key
	text = new_text
	prefix = new_prefix

func _ready() -> void:
	_refresh()

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
	key_rect.visible = key != "" or icon != null
	var wide := key.length() > 1
	key_rect.texture = icon if icon else (WIDE_KEY_ART if wide else KEY_ART)
	var art := key_rect.texture
	key_rect.custom_minimum_size = Vector2(key_height * art.get_width() / art.get_height(), key_height)
	key_label.text = "" if icon else key
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
