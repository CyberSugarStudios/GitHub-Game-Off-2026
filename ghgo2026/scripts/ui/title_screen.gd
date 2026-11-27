extends Control

#region - INIT
const GAME_SCENE_PATH := "res://scenes/main.tscn"
const MENU_MUSIC := preload("res://assets/audio/music/main_menu_music.mp3")
const MENU_MUSIC_DB := -8.0
const MENU_FADE_IN := 4.0
const LEAVE_FADE := 1.5
const LABEL_FONT := preload("res://assets/fonts/josefin_semibold.tres")
const LABEL_HOVER_FONT := preload("res://assets/fonts/josefin_bold.tres")
const LABEL_COLOR := Color(0.72156864, 0.8745098, 0.84705883)
const LABEL_HOVER_COLOR := Color(0.92, 0.98, 0.97)
const BUTTON_HOVER_ALPHA := 1.5
const BUTTON_PRESS_ALPHA := 1.8
const HOVER_SOUND := preload("res://assets/audio/ui/haptic_noise.mp3")
const SELECT_SOUND := preload("res://assets/audio/ui/select_noise.mp3")
const SELECT_VOLUME_DB := 8.0
const DISABLED_COLOR := Color(0.45, 0.45, 0.45)
const HOVER_FADE := 0.12
#region - VARS
@onready var version_number_label = $VersionNumberLabel

@onready var title = $Title
@onready var title_and_buttons = $GameTitleAndButtons
@onready var options_menu = $OptionsMenu
@onready var credits_menu = $CreditsMenu
@onready var confirm_close_menu = $ConfirmClosePopUp

@onready var continue_game_button = $GameTitleAndButtons/TitleButtons/ContinueGameButton
@onready var new_game_button = $GameTitleAndButtons/TitleButtons/NewGameButton
@onready var options_button = $GameTitleAndButtons/TitleButtons/OptionsButton
@onready var credits_button = $GameTitleAndButtons/TitleButtons/CreditsButton
@onready var quit_button = $GameTitleAndButtons/TitleButtons/QuitButton

@onready var close_credits_button = %CloseCreditsButton
@onready var options_panel: OptionsPanel = $OptionsMenu/OptionsPanel

@onready var confirm_close_button = $ConfirmClosePopUp/ConfirmCloseBackground/ConfirmCloseButtons/ConfirmCloseButton
@onready var cancel_close_button = $ConfirmClosePopUp/ConfirmCloseBackground/ConfirmCloseButtons/CancelCloseButton
#endregion
var _hover_sound: AudioStreamPlayer
var _select_sound: AudioStreamPlayer
#endregion

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Music.play(MENU_MUSIC, MENU_FADE_IN, 0.0, db_to_linear(MENU_MUSIC_DB))
	new_game_button.pressed.connect(on_new_game_pressed)
	
	var app_version = ProjectSettings.get_setting("application/config/version")
	var playtest_build := str(ProjectSettings.get_setting("application/config/playtest_build", 1))
	version_number_label.text = "v" + app_version + ("-pt." + playtest_build if OS.has_feature("playtest") else "")
	
	continue_game_button.disabled = not GameState.has_checkpoint()
	if continue_game_button.disabled:
		_grey_out(continue_game_button)
	continue_game_button.pressed.connect(on_continue_pressed)
	
	quit_button.visible = not OS.has_feature("web")
	
	options_button.pressed.connect(on_options_menu_button_pressed)
	options_panel.closed.connect(on_close_options_button_pressed)
	credits_button.pressed.connect(on_credits_menu_button_pressed)
	close_credits_button.pressed.connect(on_close_credits_button_pressed)
	quit_button.pressed.connect(on_quit_button_pressed)
	confirm_close_button.pressed.connect(on_confirm_close_button_pressed)
	cancel_close_button.pressed.connect(on_cancel_close_button_pressed)
	
	if ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(GAME_SCENE_PATH, "", true)
	_warn_if_software_rendering()
	_hover_sound = _make_sound(HOVER_SOUND, 0.0)
	_select_sound = _make_sound(SELECT_SOUND, SELECT_VOLUME_DB * 2.5)
	for button in [continue_game_button, new_game_button, options_button, credits_button, quit_button]:
		_add_hover_effect(button)

func on_new_game_pressed() -> void:
	GameState.clear_checkpoint()
	GameState.reset()
	GameClock.reset()
	_enter_game(new_game_button)

func on_continue_pressed() -> void:
	if not GameState.load_checkpoint():
		continue_game_button.disabled = true
		_grey_out(continue_game_button)
		return
	GameClock.reset()
	_enter_game(continue_game_button)

func _enter_game(pressed: BaseButton) -> void:
	new_game_button.disabled = true
	continue_game_button.disabled = true
	var label := pressed.get_node_or_null("Label") as Label
	if label:
		label.text = "LOADING..."
	Playtest.start_load_clock()
	var bar := _make_load_bar()
	var progress := []
	while ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH, progress) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		bar.value = progress[0]
		await get_tree().process_frame
	bar.value = 1.0
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_out()
	var scene := ResourceLoader.load_threaded_get(GAME_SCENE_PATH) as PackedScene
	Playtest.mark_load("title faded")
	if scene:
		get_tree().change_scene_to_packed(scene)
	else:
		get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _fade_out() -> void:
	var black := ColorRect.new()
	black.color = Settings.fade_color()
	black.color.a = 0.0
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(black)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Music.stop(LEAVE_FADE)
	await create_tween().tween_property(black, "color:a", 1.0, LEAVE_FADE).finished

func _make_load_bar() -> PillBar:
	var bar := PillBar.new()
	bar.value = 1.0
	Playtest.mark_load("loaded")
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -240.0
	bar.offset_right = 240.0
	bar.offset_top = -96.0
	bar.offset_bottom = -78.0
	add_child(bar)
	return bar

func on_options_menu_button_pressed() -> void:
	title.visible = false
	options_menu.visible = true
	title_and_buttons.visible = false

func on_close_options_button_pressed() -> void:
	title.visible = true
	options_menu.visible = false
	title_and_buttons.visible = true

func on_credits_menu_button_pressed() -> void:
	title.visible = false
	credits_menu.visible = true
	title_and_buttons.visible = false

func on_close_credits_button_pressed() -> void:
	title.visible = true
	credits_menu.visible = false
	title_and_buttons.visible = true

func on_quit_button_pressed() -> void:
	title.visible = false
	confirm_close_menu.visible = true
	title_and_buttons.visible = false

func on_confirm_close_button_pressed() -> void:
	get_tree().quit()

func on_cancel_close_button_pressed() -> void:
	title.visible = true
	confirm_close_menu.visible = false
	title_and_buttons.visible = true

func _make_sound(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = &"SFX"
	player.max_polyphony = 4
	add_child(player)
	return player

func _add_hover_effect(button: BaseButton) -> void:
	var label := button.get_node_or_null("Label") as Label
	button.mouse_entered.connect(_set_hover.bind(button, label, true))
	button.mouse_exited.connect(_set_hover.bind(button, label, false))
	button.button_down.connect(_fade_button.bind(button, BUTTON_PRESS_ALPHA))
	button.button_up.connect(func() -> void:
		_fade_button(button, BUTTON_HOVER_ALPHA if button.get_meta(&"hovered", false) else 1.0))
	button.pressed.connect(_select_sound.play)

func _set_hover(button: BaseButton, label: Label, hovered: bool) -> void:
	if button.disabled:
		return
	button.set_meta(&"hovered", hovered)
	_fade_button(button, BUTTON_HOVER_ALPHA if hovered else 1.0)
	if hovered:
		_hover_sound.play()
	if label == null:
		return
	label.add_theme_font_override("font", LABEL_HOVER_FONT if hovered else LABEL_FONT)
	var color := LABEL_HOVER_COLOR if hovered else LABEL_COLOR
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "theme_override_colors/font_color", color, HOVER_FADE)
	tween.tween_property(label, "theme_override_colors/font_outline_color", color, HOVER_FADE)

func _fade_button(button: BaseButton, alpha: float) -> void:
	button.create_tween().tween_property(button, "self_modulate:a", alpha, HOVER_FADE)

func _grey_out(button: TextureButton) -> void:
	var normal := button.texture_normal as GradientTexture2D
	if normal and normal.gradient:
		var grey := normal.duplicate() as GradientTexture2D
		grey.gradient = normal.gradient.duplicate() as Gradient
		for i in grey.gradient.get_point_count():
			var color := grey.gradient.get_color(i)
			var shade := color.get_luminance() * 0.6
			grey.gradient.set_color(i, Color(shade, shade, shade, color.a))
		button.texture_disabled = grey
	var label := button.get_node_or_null("Label") as Label
	if label:
		label.add_theme_color_override("font_color", DISABLED_COLOR)
		label.add_theme_color_override("font_outline_color", DISABLED_COLOR)

func _warn_if_software_rendering() -> void:
	if not Playtest.is_software_rendering():
		return
	var warning := Label.new()
	warning.text = "Graphics acceleration seems to be turned off in your browser, so the game may run slowly.\n" \
		+ "Turn on \"Use graphics acceleration when available\" in your browser settings, then reload."
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_theme_font_size_override("font_size", 20)
	warning.add_theme_color_override("font_color", Color("#D9A35A"))
	warning.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 16)
	add_child(warning)
