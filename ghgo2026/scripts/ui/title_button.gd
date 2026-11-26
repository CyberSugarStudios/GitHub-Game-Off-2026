@tool
class_name TitleButton
extends TextureButton

const FONT := preload("res://assets/fonts/josefin_semibold.tres")
const HOVER_FONT := preload("res://assets/fonts/josefin_bold.tres")
const HOVER_SOUND := preload("res://assets/audio/ui/haptic_noise.mp3")
const SELECT_SOUND := preload("res://assets/audio/ui/select_noise.mp3")

@export var text: String = "":
	set(value):
		text = value
		if is_node_ready():
			($Label as Label).text = value
@export var color := Color(0.72156864, 0.8745098, 0.84705883)
@export var hover_color := Color(0.92, 0.98, 0.97)
@export var disabled_color := Color(0.45, 0.45, 0.45)
@export var hover_alpha: float = 1.5
@export var press_alpha: float = 1.8
@export var fade: float = 0.12
@export var select_volume_db: float = 6.0

var _hovered := false
var _was_disabled := false

func _ready() -> void:
	var label := $Label as Label
	if text == "":
		text = label.text
	label.text = text
	_apply_idle()
	if Engine.is_editor_hint():
		return
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	button_down.connect(_fade_to.bind(press_alpha))
	button_up.connect(func() -> void: _fade_to(hover_alpha if _hovered else 1.0))
	pressed.connect(_play.bind(SELECT_SOUND, select_volume_db))

func _process(_delta: float) -> void:
	if disabled != _was_disabled:
		_apply_idle()

func _apply_idle() -> void:
	_was_disabled = disabled
	_hovered = false
	self_modulate.a = 1.0
	var label := $Label as Label
	label.add_theme_font_override("font", FONT)
	var idle := disabled_color if disabled else color
	label.add_theme_color_override("font_color", idle)
	label.add_theme_color_override("font_outline_color", idle)
	if disabled and texture_disabled == null and not Engine.is_editor_hint():
		texture_disabled = _grey(texture_normal)

func _set_hover(on: bool) -> void:
	if disabled:
		return
	_hovered = on
	_fade_to(hover_alpha if on else 1.0)
	if on:
		_play(HOVER_SOUND, 0.0)
	var label := $Label as Label
	label.add_theme_font_override("font", HOVER_FONT if on else FONT)
	var target := hover_color if on else color
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "theme_override_colors/font_color", target, fade)
	tween.tween_property(label, "theme_override_colors/font_outline_color", target, fade)

func _fade_to(alpha: float) -> void:
	create_tween().tween_property(self, "self_modulate:a", alpha, fade)

func _play(stream: AudioStream, volume_db: float) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = &"SFX"
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

static func _grey(source: Texture2D) -> Texture2D:
	var gradient_texture := source as GradientTexture2D
	if gradient_texture == null or gradient_texture.gradient == null:
		return source
	var grey := gradient_texture.duplicate() as GradientTexture2D
	grey.gradient = gradient_texture.gradient.duplicate() as Gradient
	for i in grey.gradient.get_point_count():
		var c := grey.gradient.get_color(i)
		var shade := c.get_luminance() * 0.6
		grey.gradient.set_color(i, Color(shade, shade, shade, c.a))
	return grey
