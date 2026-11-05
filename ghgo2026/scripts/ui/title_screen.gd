extends Control

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

func _ready() -> void:
	var app_version = ProjectSettings.get_setting("application/config/version")
	version_number_label.text = "v" + app_version
	continue_game_button.disabled = true
	quit_button.visible = false
	#if save file exists
		#continue_game_button.disabled = false
	#if on PC (not HTML)
		#quit_button.visible = true
	
	options_button.pressed.connect(on_options_menu_button_pressed)
	close_options_button.pressed.connect(on_close_options_button_pressed)
	credits_button.pressed.connect(on_credits_menu_button_pressed)
	close_credits_button.pressed.connect(on_close_credits_button_pressed)
	quit_button.pressed.connect(on_quit_button_pressed)
	confirm_close_button.pressed.connect(on_confirm_close_button_pressed)
	cancel_close_button.pressed.connect(on_cancel_close_button_pressed)

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
	queue_free()

func on_cancel_close_button_pressed() -> void:
	confirm_close_menu.visible = false
	title_and_buttons.visible = true
