extends CanvasLayer

const MAIN_SCENE := "res://scenes/main.tscn"
const KEYS: Array[String] = [
	"F1   Restore a memory bar",
	"F2   Clock +15 min",
	"F3   Astral focus on/off",
	"F4   Skip intro / restart intro",
	"F5   Creature level +1",
	"F6   Hint level +1",
	"F7   Next story stage",
	"F8   Jump to the finale",
	"`    Toggle this list",
]

var _panel: PanelContainer

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panel()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F4:
			_skip_or_restart_intro()
		KEY_QUOTELEFT:
			_panel.visible = not _panel.visible
		_:
			return
	get_viewport().set_input_as_handled()

func _skip_or_restart_intro() -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != MAIN_SCENE:
		return
	get_tree().paused = false
	if GameState.has_flag(&"intro_done"):
		GameState.reset()
		GameClock.reset()
	else:
		GameState.set_flag(&"intro_done")
		GameState.exit_astral()
		GameState.set_controls_locked(false)
	get_tree().reload_current_scene()

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "DEBUG\n" + "\n".join(PackedStringArray(KEYS))
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.85))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(label)
	add_child(_panel)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
