extends Control

#region - INIT
const GAME_SCENE_PATH := "res://scenes/main.tscn"
const MENU_MUSIC := preload("res://assets/audio/music/main_menu_music.mp3")
#region - VARS
@onready var version_number_label = $VersionNumberLabel

@onready var title_and_buttons = $GameTitleAndButtons
@onready var options_menu = $OptionsMenu
@onready var credits_menu = $CreditsMenu
@onready var confirm_close_menu = $ConfirmClosePopUp

@onready var continue_game_button = $GameTitleAndButtons/TitleButtons/ContinueGameButton
@onready var new_game_button = $GameTitleAndButtons/TitleButtons/NewGameButton
@onready var options_button = $GameTitleAndButtons/TitleButtons/OptionsButton
@onready var credits_button = $GameTitleAndButtons/TitleButtons/CreditsButton
@onready var quit_button = $GameTitleAndButtons/TitleButtons/QuitButton

@onready var close_options_button = $OptionsMenu/CloseOptionsButton
@onready var close_credits_button = $CreditsMenu/CloseCreditsButton

@onready var confirm_close_button = $ConfirmClosePopUp/ConfirmCloseBackground/ConfirmCloseButtons/ConfirmCloseButton
@onready var cancel_close_button = $ConfirmClosePopUp/ConfirmCloseBackground/ConfirmCloseButtons/CancelCloseButton
#endregion
#endregion

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Music.play(MENU_MUSIC)
	new_game_button.pressed.connect(on_new_game_pressed)
	
	var app_version = ProjectSettings.get_setting("application/config/version")
	version_number_label.text = "v" + app_version
	
	continue_game_button.disabled = not GameState.has_checkpoint()
	continue_game_button.pressed.connect(on_continue_pressed)
	
	# Brower can't use quit button
	quit_button.visible = not OS.has_feature("web")
	
	options_button.pressed.connect(on_options_menu_button_pressed)
	close_options_button.pressed.connect(on_close_options_button_pressed)
	credits_button.pressed.connect(on_credits_menu_button_pressed)
	close_credits_button.pressed.connect(on_close_credits_button_pressed)
	quit_button.pressed.connect(on_quit_button_pressed)
	confirm_close_button.pressed.connect(on_confirm_close_button_pressed)
	cancel_close_button.pressed.connect(on_cancel_close_button_pressed)
	
	ResourceLoader.load_threaded_request(GAME_SCENE_PATH)

func on_new_game_pressed() -> void:
	GameState.clear_checkpoint()
	GameState.reset()
	GameClock.reset()
	_enter_game(new_game_button)

func on_continue_pressed() -> void:
	if not GameState.load_checkpoint():
		continue_game_button.disabled = true
		return
	GameClock.reset()
	_enter_game(continue_game_button)

func _enter_game(pressed: Button) -> void:
	new_game_button.disabled = true
	continue_game_button.disabled = true
	pressed.text = "Loading..."
	while ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	var scene := ResourceLoader.load_threaded_get(GAME_SCENE_PATH) as PackedScene
	if scene:
		get_tree().change_scene_to_packed(scene)
	else:
		get_tree().change_scene_to_file(GAME_SCENE_PATH)

func on_options_menu_button_pressed() -> void:
	options_menu.visible = true
	title_and_buttons.visible = false

func on_close_options_button_pressed() -> void:
	options_menu.visible = false
	title_and_buttons.visible = true

func on_credits_menu_button_pressed() -> void:
	credits_menu.visible = true
	title_and_buttons.visible = false

func on_close_credits_button_pressed() -> void:
	credits_menu.visible = false
	title_and_buttons.visible = true

func on_quit_button_pressed() -> void:
	confirm_close_menu.visible = true
	title_and_buttons.visible = false

func on_confirm_close_button_pressed() -> void:
	get_tree().quit()

func on_cancel_close_button_pressed() -> void:
	confirm_close_menu.visible = false
	title_and_buttons.visible = true
