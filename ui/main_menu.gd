extends Control

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var credits_panel: Panel = $CreditsPanel
@onready var controls_panel: Panel = $ControlsPanel

func _ready() -> void:
	credits_panel.hide()
	controls_panel.hide()
	main_buttons.show()
	# Inicia musica do menu (dark ambient)
	AudioManager.play_menu_music()

func _on_start_button_pressed() -> void:
	AudioManager.play_ui_click()
	GameMode.set_story_mode()
	get_tree().change_scene_to_file("res://main.tscn")

func _on_infinite_mode_button_pressed() -> void:
	AudioManager.play_ui_click()
	GameMode.set_infinite_mode()
	get_tree().change_scene_to_file("res://main.tscn")

func _on_credits_button_pressed() -> void:
	AudioManager.play_ui_click()
	main_buttons.hide()
	credits_panel.show()

func _on_controls_button_pressed() -> void:
	AudioManager.play_ui_click()
	main_buttons.hide()
	controls_panel.show()

func _on_quit_button_pressed() -> void:
	AudioManager.play_ui_click()
	get_tree().quit()

func _on_back_button_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFXType.UI_BACK)
	credits_panel.hide()
	controls_panel.hide()
	main_buttons.show()
