extends Node2D

const SQUARE_SIZE := 50
const TARGET_COLOR := Color.RED
const DISTRACTOR_COLOR := Color.GRAY
const BASE_SPEED_MIN := 50.0
const BASE_SPEED_MAX := 150.0

# Quantidade de distratores por fase (diminui progressivamente)
var phase_distractors := {
	2: 30,  # Maximo
	3: 22,
	4: 15,
	5: 7,
	6: 0,   # Nenhum distrator na fase final
}

# Multiplicador de velocidade por fase (diminui progressivamente)
var phase_speed_multiplier := {
	2: 1.0,   # Velocidade maxima
	3: 0.75,
	4: 0.5,
	5: 0.25,
	6: 0.0,   # Sem movimento na fase final
}

var score := 0
var target_square: ColorRect = null
var square_velocities: Dictionary = {}
var game_started := false

@onready var score_label: Label = $UI/ScoreLabel
@onready var message_label: Label = $UI/MessageLabel
@onready var squares_container: Control = $Squares
@onready var fade_rect: ColorRect = $FadeLayer/FadeRect
@onready var items_label: Label = $UI/ItemsLabel

const BALLOON_SCENE = preload("res://ui/visual_novel_balloon.tscn")
const NPC_BALLOON_SCENE = preload("res://ui/npc_dialogue_balloon.tscn")
const SFX_CORRECT = preload("res://sounds/foom_0.wav")
const INTRO_DIALOGUE = preload("res://dialogues/intro.dialogue")

# Recursos de dialogo por fase
var phase_npc_dialogues := {
	2: preload("res://dialogues/fase2_npcs.dialogue"),
	3: preload("res://dialogues/fase3_npcs.dialogue"),
	4: preload("res://dialogues/fase4_npcs.dialogue"),
	5: preload("res://dialogues/fase5_npcs.dialogue"),
	6: preload("res://dialogues/fase6_npcs.dialogue"),
}

var phase_main_dialogues := {
	2: preload("res://dialogues/fase2_principal.dialogue"),
	3: preload("res://dialogues/fase3_principal.dialogue"),
	4: preload("res://dialogues/fase4_principal.dialogue"),
	5: preload("res://dialogues/fase5_principal.dialogue"),
	6: preload("res://dialogues/fase6_principal.dialogue"),
}

# Numero maximo de dialogos de NPC por fase
var phase_max_npc_dialogues := {
	2: 5,
	3: 5,
	4: 3,
	5: 3,
	6: 1,
}

var sfx_player: AudioStreamPlayer
var current_phase := 2  # Comeca na fase 2
var npc_dialogue_index := 0
var is_showing_npc_dialogue := false
var is_showing_main_dialogue := false

# Mapeamento de itens por fase/dialogo (fase -> {npc_index -> item_name})
# Nota: npc_dialogue_index comeca em 0, entao NPC 3 = indice 2
var item_triggers := {
	2: {2: "monoculo"},    # Fase 2, NPC 3 (indice 2)
	3: {0: "relogio"},     # Fase 3, NPC 1 (indice 0)
	4: {2: "visao_fase4"}, # Fase 4, NPC 3 (indice 2)
}

var target_pulse_tween: Tween = null
var last_shown_npc_dialogue_index := 0


func _ready() -> void:
	randomize()
	setup_audio()
	Inventory.item_collected.connect(_on_item_collected)
	play_fade_in()


func setup_audio() -> void:
	sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = SFX_CORRECT
	add_child(sfx_player)


func play_fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 1.5)
	tween.tween_callback(show_intro_dialogue)


func show_intro_dialogue() -> void:
	message_label.text = ""
	score_label.visible = false

	var balloon = BALLOON_SCENE.instantiate()
	get_tree().current_scene.add_child(balloon)
	balloon.tree_exited.connect(_on_intro_dialogue_finished)
	balloon.start(INTRO_DIALOGUE, "start")


func _on_intro_dialogue_finished() -> void:
	score_label.visible = true
	message_label.text = "Encontre o quadrado vermelho!"
	start_game()


func start_game() -> void:
	game_started = true
	spawn_squares()


func _process(delta: float) -> void:
	if not game_started:
		return

	var viewport_size := get_viewport().get_visible_rect().size

	for square in squares_container.get_children():
		if not square_velocities.has(square):
			continue

		var velocity: Vector2 = square_velocities[square]
		square.position += velocity * delta

		# Quica nas bordas horizontais
		if square.position.x <= 0:
			square.position.x = 0
			velocity.x = abs(velocity.x)
		elif square.position.x + SQUARE_SIZE >= viewport_size.x:
			square.position.x = viewport_size.x - SQUARE_SIZE
			velocity.x = -abs(velocity.x)

		# Quica nas bordas verticais
		if square.position.y <= 120:
			square.position.y = 120
			velocity.y = abs(velocity.y)
		elif square.position.y + SQUARE_SIZE >= viewport_size.y:
			square.position.y = viewport_size.y - SQUARE_SIZE
			velocity.y = -abs(velocity.y)

		square_velocities[square] = velocity


func spawn_squares() -> void:
	for child in squares_container.get_children():
		square_velocities.erase(child)
		child.queue_free()

	await get_tree().process_frame

	var viewport_size := get_viewport().get_visible_rect().size
	var margin := 100
	var used_positions: Array[Vector2] = []

	# Quantidade de distratores baseada na fase atual
	var num_distractors: int = phase_distractors[current_phase]

	# Efeito da Visao Fase 4: metade dos distratores
	if Inventory.has("visao_fase4"):
		num_distractors = int(num_distractors * 0.5)

	for i in range(num_distractors):
		var square := create_square(DISTRACTOR_COLOR, false)
		var pos := get_random_position(viewport_size, margin, used_positions)
		square.position = pos
		used_positions.append(pos)
		squares_container.add_child(square)
		square_velocities[square] = get_random_velocity()

	target_square = create_square(TARGET_COLOR, true)
	var target_pos := get_random_position(viewport_size, margin, used_positions)
	target_square.position = target_pos
	squares_container.add_child(target_square)
	square_velocities[target_square] = get_random_velocity()

	# Efeito do Monoculo: pulso sutil no alvo
	if Inventory.has("monoculo"):
		apply_monoculo_effect()


func create_square(color: Color, is_target: bool) -> ColorRect:
	var square := ColorRect.new()
	square.size = Vector2(SQUARE_SIZE, SQUARE_SIZE)
	square.color = color
	square.mouse_filter = Control.MOUSE_FILTER_STOP
	square.gui_input.connect(_on_square_clicked.bind(is_target, square))
	return square


func get_random_velocity() -> Vector2:
	var multiplier: float = phase_speed_multiplier[current_phase]

	# Efeito do Relogio: 30% mais lento
	if Inventory.has("relogio"):
		multiplier *= 0.7

	var speed_min := BASE_SPEED_MIN * multiplier
	var speed_max := BASE_SPEED_MAX * multiplier
	var speed := randf_range(speed_min, speed_max)
	var angle := randf_range(0, TAU)
	return Vector2(cos(angle), sin(angle)) * speed


func get_random_position(viewport_size: Vector2, margin: int, used_positions: Array[Vector2]) -> Vector2:
	var max_attempts := 100
	var min_distance := SQUARE_SIZE * 1.5

	for attempt in range(max_attempts):
		var x := randf_range(margin, viewport_size.x - margin - SQUARE_SIZE)
		var y := randf_range(margin + 50, viewport_size.y - margin - SQUARE_SIZE)
		var pos := Vector2(x, y)

		var is_valid := true
		for used_pos in used_positions:
			if pos.distance_to(used_pos) < min_distance:
				is_valid = false
				break

		if is_valid:
			return pos

	return Vector2(
		randf_range(margin, viewport_size.x - margin - SQUARE_SIZE),
		randf_range(margin + 50, viewport_size.y - margin - SQUARE_SIZE)
	)


func _on_square_clicked(event: InputEvent, is_target: bool, square: ColorRect) -> void:
	if not game_started:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if is_target:
				if not is_showing_main_dialogue:
					show_main_dialogue(square)
			else:
				if not is_showing_npc_dialogue:
					show_npc_dialogue()

				var original_color := square.color
				square.color = Color.DARK_RED
				await get_tree().create_timer(0.2).timeout
				if is_instance_valid(square):
					square.color = original_color


func apply_monoculo_effect() -> void:
	if target_pulse_tween:
		target_pulse_tween.kill()

	target_pulse_tween = create_tween().set_loops()
	target_pulse_tween.tween_property(target_square, "modulate", Color(1.2, 0.8, 0.8), 0.5)
	target_pulse_tween.tween_property(target_square, "modulate", Color.WHITE, 0.5)


func _on_item_collected(item_name: String) -> void:
	update_items_display()
	show_item_notification(item_name)


func update_items_display() -> void:
	var collected := []
	if Inventory.has("monoculo"):
		collected.append("[Monoculo]")
	if Inventory.has("relogio"):
		collected.append("[Relogio]")
	if Inventory.has("visao_fase4"):
		collected.append("[Visao]")
	items_label.text = " ".join(collected)


func show_item_notification(item_name: String) -> void:
	var item_names := {
		"monoculo": "Monoculo",
		"relogio": "Relogio",
		"visao_fase4": "Visao dos Nao Integros"
	}

	var display_name: String = item_names.get(item_name, item_name)
	var original_text := message_label.text
	message_label.text = "Item coletado: %s!" % display_name

	await get_tree().create_timer(2.0).timeout
	if message_label.text == "Item coletado: %s!" % display_name:
		message_label.text = original_text


func show_npc_dialogue() -> void:
	is_showing_npc_dialogue = true

	var max_dialogues: int = phase_max_npc_dialogues[current_phase]
	var dialogue_num := mini(npc_dialogue_index + 1, max_dialogues)
	var dialogue_title := "npc_%d" % dialogue_num

	# Guardar o indice do dialogo que esta sendo mostrado (0-indexed)
	last_shown_npc_dialogue_index = npc_dialogue_index

	var npc_resource: DialogueResource = phase_npc_dialogues[current_phase]

	var balloon = NPC_BALLOON_SCENE.instantiate()
	get_tree().current_scene.add_child(balloon)
	balloon.dialogue_finished.connect(_on_npc_dialogue_finished)
	balloon.start(npc_resource, dialogue_title)

	if npc_dialogue_index < max_dialogues - 1:
		npc_dialogue_index += 1


func _on_npc_dialogue_finished() -> void:
	is_showing_npc_dialogue = false

	# Verificar se o dialogo mostrado tem item associado
	if current_phase in item_triggers:
		var phase_items: Dictionary = item_triggers[current_phase]
		if last_shown_npc_dialogue_index in phase_items:
			var item_name: String = phase_items[last_shown_npc_dialogue_index]
			Inventory.collect(item_name)


func show_main_dialogue(square: ColorRect) -> void:
	is_showing_main_dialogue = true

	var tween := create_tween()
	tween.tween_property(square, "modulate", Color.WHITE * 2, 0.1)

	var main_resource: DialogueResource = phase_main_dialogues[current_phase]

	var balloon = BALLOON_SCENE.instantiate()
	get_tree().current_scene.add_child(balloon)
	balloon.tree_exited.connect(_on_main_dialogue_finished)
	balloon.start(main_resource, "start")


func _on_main_dialogue_finished() -> void:
	is_showing_main_dialogue = false

	score += 1
	score_label.text = "Pontos: %d" % score
	sfx_player.play()

	# Avanca para proxima fase
	if current_phase < 6:
		current_phase += 1
		npc_dialogue_index = 0  # Reseta contador de dialogos NPC
		message_label.text = "Fase %d" % current_phase
	else:
		message_label.text = "Fim do jogo!"
		# Aqui pode adicionar logica de fim de jogo

	# Tela preta instantanea + fade out
	fade_rect.modulate.a = 1.0
	spawn_squares()
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 1.0)
