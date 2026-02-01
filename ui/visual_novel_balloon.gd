extends CanvasLayer

const FADE_DURATION := 0.3

@export var next_action: StringName = &"ui_accept"
@export var skip_action: StringName = &"ui_cancel"

var resource: DialogueResource
var temporary_game_states: Array = []
var is_waiting_for_input: bool = false
var will_hide_balloon: bool = false
var locals: Dictionary = {}
var hide_characters: bool = false

# Guard rail to prevent rapid clicking
var input_cooldown: float = 0.0
const INPUT_COOLDOWN_TIME: float = 0.3  # 300ms between inputs

var _locale: String = TranslationServer.get_locale()

var dialogue_line: DialogueLine:
	set(value):
		if value:
			dialogue_line = value
			apply_dialogue_line()
		else:
			# Emit dialogue_ended signal before closing
			DialogueManager.dialogue_ended.emit(resource)
			queue_free()
	get:
		return dialogue_line

var mutation_cooldown: Timer = Timer.new()

@onready var balloon: Control = %Balloon
@onready var character_label: RichTextLabel = %CharacterLabel
@onready var dialogue_label: DialogueLabel = %DialogueLabel
@onready var responses_menu: DialogueResponsesMenu = %ResponsesMenu
@onready var left_character: ColorRect = %LeftCharacter
@onready var right_character: ColorRect = %RightCharacter

# Character to side mapping
var character_sides: Dictionary = {
	"Alice": "left",
	"Bob": "right",
	"Elisa": "left",
	"Masked": "right",
	"Leader Altiza": "right",
	"Guillinger": "right",
	"Narrator": "left"
}

var character_colors: Dictionary = {
	"Alice": Color(0.6, 0.3, 0.7, 1),
	"Bob": Color(0.3, 0.6, 0.7, 1),
	"Elisa": Color(0.8, 0.7, 0.5, 1),  # Golden
	"Masked": Color(0.5, 0.2, 0.2, 1),  # Dark red
	"Leader Altiza": Color(0.7, 0.5, 0.8, 1),  # Purple
	"Guillinger": Color(0.4, 0.5, 0.6, 1),  # Steel gray
	"Narrator": Color(0.7, 0.7, 0.7, 1)  # Gray
}


func _ready() -> void:
	balloon.hide()
	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)

	if responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action

	mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(mutation_cooldown)


func _process(delta: float) -> void:
	if input_cooldown > 0:
		input_cooldown -= delta


func _unhandled_input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _locale != TranslationServer.get_locale() and is_instance_valid(dialogue_label):
		_locale = TranslationServer.get_locale()
		var visible_ratio = dialogue_label.visible_ratio
		self.dialogue_line = await resource.get_next_dialogue_line(dialogue_line.id)
		if visible_ratio < 1:
			dialogue_label.skip_typing()


func start(dialogue_resource: DialogueResource, title: String, extra_game_states: Array = [], show_characters: bool = true) -> void:
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false
	resource = dialogue_resource
	hide_characters = not show_characters
	input_cooldown = INPUT_COOLDOWN_TIME  # Apply cooldown at dialogue start
	self.dialogue_line = await resource.get_next_dialogue_line(title, temporary_game_states)


func apply_dialogue_line() -> void:
	mutation_cooldown.stop()

	# Apply cooldown when new dialogue line appears
	input_cooldown = INPUT_COOLDOWN_TIME

	is_waiting_for_input = false
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()

	# Atualiza o nome do personagem
	character_label.visible = not dialogue_line.character.is_empty()
	character_label.text = tr(dialogue_line.character, "dialogue")

	# Atualiza os sprites dos personagens
	update_character_display(dialogue_line.character)

	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line

	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses

	balloon.show()
	will_hide_balloon = false

	dialogue_label.show()
	if not dialogue_line.text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing

	if dialogue_line.responses.size() > 0:
		balloon.focus_mode = Control.FOCUS_NONE
		responses_menu.show()
	elif dialogue_line.time != "":
		var time = dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		await get_tree().create_timer(time).timeout
		next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()


func update_character_display(character_name: String) -> void:
	# Hide character portraits if hide_characters is true
	if hide_characters:
		left_character.hide()
		right_character.hide()
		# Still update character name color
		if character_colors.has(character_name):
			character_label.add_theme_color_override("default_color", character_colors[character_name])
		return

	var side = character_sides.get(character_name, "")

	# Dim inactive characters, highlight active one
	var inactive_color := Color(0.5, 0.5, 0.5, 1)

	if side == "left":
		show_character(left_character, character_name, true)
		if right_character.visible:
			dim_character(right_character)
	elif side == "right":
		show_character(right_character, character_name, true)
		if left_character.visible:
			dim_character(left_character)

	# Update character name color
	if character_colors.has(character_name):
		character_label.add_theme_color_override("default_color", character_colors[character_name])


func show_character(character_node: ColorRect, character_name: String, is_active: bool) -> void:
	if not character_node.visible:
		character_node.modulate.a = 0
		character_node.show()
		var tween := create_tween()
		tween.tween_property(character_node, "modulate:a", 1.0, FADE_DURATION)

	if is_active:
		highlight_character(character_node)

	# Atualiza a cor do placeholder
	if character_colors.has(character_name):
		character_node.color = character_colors[character_name]


func highlight_character(character_node: ColorRect) -> void:
	var tween := create_tween()
	tween.tween_property(character_node, "modulate", Color.WHITE, 0.2)


func dim_character(character_node: ColorRect) -> void:
	var tween := create_tween()
	tween.tween_property(character_node, "modulate", Color(0.6, 0.6, 0.6, 1), 0.2)


func next(next_id: String) -> void:
	self.dialogue_line = await resource.get_next_dialogue_line(next_id, temporary_game_states)


#region Signals

func _on_mutation_cooldown_timeout() -> void:
	if will_hide_balloon:
		will_hide_balloon = false
		balloon.hide()


func _on_mutated(_mutation: Dictionary) -> void:
	is_waiting_for_input = false
	will_hide_balloon = true
	mutation_cooldown.start(0.1)


func _on_balloon_gui_input(event: InputEvent) -> void:
	# Guard rail: ignore input during cooldown
	if input_cooldown > 0:
		get_viewport().set_input_as_handled()
		return

	if dialogue_label.is_typing:
		var mouse_was_clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()
		var skip_button_was_pressed: bool = event.is_action_pressed(skip_action)
		if mouse_was_clicked or skip_button_was_pressed:
			get_viewport().set_input_as_handled()
			dialogue_label.skip_typing()
			input_cooldown = INPUT_COOLDOWN_TIME  # Apply cooldown after skipping typing
			return

	if not is_waiting_for_input: return
	if dialogue_line.responses.size() > 0: return

	get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		input_cooldown = INPUT_COOLDOWN_TIME  # Apply cooldown before advancing
		next(dialogue_line.next_id)
	elif event.is_action_pressed(next_action) and get_viewport().gui_get_focus_owner() == balloon:
		input_cooldown = INPUT_COOLDOWN_TIME  # Apply cooldown before advancing
		next(dialogue_line.next_id)


func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	next(response.next_id)


func _on_skip_button_pressed() -> void:
	# Pula todo o diálogo - emite o sinal e destrói o balloon
	DialogueManager.dialogue_ended.emit(resource)
	queue_free()

#endregion
