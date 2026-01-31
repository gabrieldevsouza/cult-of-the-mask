extends Node2D

const SQUARE_SIZE := 50
const NUM_DISTRACTORS := 30
const TARGET_COLOR := Color.RED
const DISTRACTOR_COLOR := Color.GRAY
const SPEED_MIN := 50.0
const SPEED_MAX := 150.0

var score := 0
var target_square: ColorRect = null
var square_velocities: Dictionary = {}  # Armazena velocidade de cada quadrado
var game_started := false

@onready var score_label: Label = $UI/ScoreLabel
@onready var message_label: Label = $UI/MessageLabel
@onready var squares_container: Control = $Squares
@onready var fade_rect: ColorRect = $FadeLayer/FadeRect

const DIALOGUE_RESOURCE = preload("res://dialogues/test_dialogue.dialogue")
const BALLOON_SCENE = preload("res://ui/visual_novel_balloon.tscn")


func _ready() -> void:
	randomize()
	play_fade_in()


func play_fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 1.5)
	tween.tween_callback(start_dialogue)


func start_dialogue() -> void:
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	var balloon = BALLOON_SCENE.instantiate()
	get_tree().current_scene.add_child(balloon)
	balloon.start(DIALOGUE_RESOURCE, "start")


func _on_dialogue_ended(_resource) -> void:
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
		if square.position.y <= 120:  # Margem para UI
			square.position.y = 120
			velocity.y = abs(velocity.y)
		elif square.position.y + SQUARE_SIZE >= viewport_size.y:
			square.position.y = viewport_size.y - SQUARE_SIZE
			velocity.y = -abs(velocity.y)

		square_velocities[square] = velocity


func spawn_squares() -> void:
	# Limpa quadrados existentes e suas velocidades
	for child in squares_container.get_children():
		square_velocities.erase(child)
		child.queue_free()

	# Aguarda um frame para garantir que foram removidos
	await get_tree().process_frame

	var viewport_size := get_viewport().get_visible_rect().size
	var margin := 100  # Margem das bordas
	var used_positions: Array[Vector2] = []

	# Cria quadrados distratores (cinzas)
	for i in range(NUM_DISTRACTORS):
		var square := create_square(DISTRACTOR_COLOR, false)
		var pos := get_random_position(viewport_size, margin, used_positions)
		square.position = pos
		used_positions.append(pos)
		squares_container.add_child(square)
		square_velocities[square] = get_random_velocity()

	# Cria o quadrado alvo (vermelho)
	target_square = create_square(TARGET_COLOR, true)
	var target_pos := get_random_position(viewport_size, margin, used_positions)
	target_square.position = target_pos
	squares_container.add_child(target_square)
	square_velocities[target_square] = get_random_velocity()


func create_square(color: Color, is_target: bool) -> ColorRect:
	var square := ColorRect.new()
	square.size = Vector2(SQUARE_SIZE, SQUARE_SIZE)
	square.color = color
	square.mouse_filter = Control.MOUSE_FILTER_STOP

	# Conecta o sinal de clique
	square.gui_input.connect(_on_square_clicked.bind(is_target, square))

	return square


func get_random_velocity() -> Vector2:
	var speed := randf_range(SPEED_MIN, SPEED_MAX)
	var angle := randf_range(0, TAU)  # Ângulo aleatório em radianos
	return Vector2(cos(angle), sin(angle)) * speed


func get_random_position(viewport_size: Vector2, margin: int, used_positions: Array[Vector2]) -> Vector2:
	var max_attempts := 100
	var min_distance := SQUARE_SIZE * 1.5  # Distância mínima entre quadrados

	for attempt in range(max_attempts):
		var x := randf_range(margin, viewport_size.x - margin - SQUARE_SIZE)
		var y := randf_range(margin + 50, viewport_size.y - margin - SQUARE_SIZE)  # +50 para não sobrepor UI
		var pos := Vector2(x, y)

		# Verifica se não está muito perto de outros quadrados
		var is_valid := true
		for used_pos in used_positions:
			if pos.distance_to(used_pos) < min_distance:
				is_valid = false
				break

		if is_valid:
			return pos

	# Se não encontrou posição válida, retorna uma aleatória
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
				# Acertou!
				score += 1
				score_label.text = "Pontos: %d" % score
				message_label.text = "Muito bem! Encontre o próximo!"

				# Efeito visual simples
				var tween := create_tween()
				tween.tween_property(square, "modulate", Color.WHITE * 2, 0.1)
				tween.tween_callback(spawn_squares)
			else:
				# Errou!
				message_label.text = "Esse não! Continue procurando..."

				# Feedback visual de erro
				var original_color := square.color
				square.color = Color.DARK_RED
				await get_tree().create_timer(0.2).timeout
				square.color = original_color
