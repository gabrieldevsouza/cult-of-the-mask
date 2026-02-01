extends Control

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var credits_panel: Control = $CreditsPanel
@onready var controls_panel: Panel = $ControlsPanel
@onready var infinite_mode_panel: Panel = $InfiniteModePanel

const HOVER_COLOR := Color(1.3, 1.3, 1.3, 1.0)  # Mais claro
const NORMAL_COLOR := Color(1.0, 1.0, 1.0, 1.0)

func _ready() -> void:
	controls_panel.hide()
	infinite_mode_panel.hide()

	# Inicia musica do menu (dark ambient)
	AudioManager.play_menu_music()

	# Conecta efeitos de hover nos botões
	_setup_button_hover_effects()

	# Check if we should show credits (after completing the game)
	if GameMode.should_show_credits():
		main_buttons.hide()
		credits_panel.show()
	else:
		credits_panel.hide()
		main_buttons.show()

func _on_start_button_pressed() -> void:
	AudioManager.play_ui_click()
	GameMode.set_story_mode()
	get_tree().change_scene_to_file("res://main.tscn")

func _on_infinite_mode_button_pressed() -> void:
	AudioManager.play_ui_click()
	main_buttons.hide()
	infinite_mode_panel.show()

func _on_find_mode_pressed() -> void:
	AudioManager.play_ui_click()
	GameMode.set_infinite_find_mode()
	get_tree().change_scene_to_file("res://main.tscn")

func _on_kill_mode_pressed() -> void:
	AudioManager.play_ui_click()
	GameMode.set_infinite_kill_mode()
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
	infinite_mode_panel.hide()
	main_buttons.show()


func _setup_button_hover_effects() -> void:
	for button in main_buttons.get_children():
		if button is TextureButton:
			button.mouse_entered.connect(_on_button_hover.bind(button))
			button.mouse_exited.connect(_on_button_unhover.bind(button))


func _on_button_hover(button: TextureButton) -> void:
	var tween := create_tween()
	tween.tween_property(button, "modulate", HOVER_COLOR, 0.1)
	AudioManager.play_ui_hover()


func _on_button_unhover(button: TextureButton) -> void:
	var tween := create_tween()
	tween.tween_property(button, "modulate", NORMAL_COLOR, 0.1)
