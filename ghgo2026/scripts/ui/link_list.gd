class_name LinkList
extends VBoxContainer

const TITLE_BUTTON := preload("res://scenes/ui/title_button.tscn")
const ALLURA := preload("res://assets/fonts/Allura-Regular.ttf")
const TEAL := Color(0.4392157, 0.6862745, 0.6392157)

@export var links: PackedStringArray = [
	"# CyberSugar Studios",
	"Website|https://cybersugarstudios.com",
	"itch.io|https://cybersugarstudios.itch.io",
	"",
	"# Team Links",
	"Phrenix|",
	"Sunny Bee|",
	"KatyaArt132|",
	"Lee Campos|",
	"Rhys Cassidy|",
	"Jura Leopold|",
	"",
	"# Featured Musicians",
	"Faye Ophelia|https://beacons.ai/fayeophelia",
	"Joe Leytrick|https://www.instagram.com/joeleytrick",
	"Ayleen Valentine|linktr.ee/ayleenvalentine",
]
@export var heading_size: int = 44
@export var group_gap: float = 18.0

func _ready() -> void:
	for line in links:
		add_child(_make(line))

func _make(line: String) -> Control:
	if line.strip_edges() == "":
		var gap := Control.new()
		gap.custom_minimum_size.y = group_gap
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return gap
	if line.begins_with("#"):
		var label := Label.new()
		label.text = line.trim_prefix("#").strip_edges()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", ALLURA)
		label.add_theme_font_size_override("font_size", heading_size)
		label.add_theme_color_override("font_color", TEAL)
		return label
	var parts := line.split("|")
	var button := TITLE_BUTTON.instantiate() as TitleButton
	button.text = parts[0].strip_edges().to_upper()
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var url := parts[1].strip_edges() if parts.size() > 1 else ""
	if url == "":
		button.disabled = true
	else:
		button.pressed.connect(func() -> void: OS.shell_open(url))
	return button
