extends Node2D
class_name GameDirector

@export var round_time := 15.0

var time_left := 0.0
var round_active := false

@onready var timer_label: Label = $UI/TimerLabel
@onready var score_label: Label = $UI/ScoreLabel
@onready var message_label: Label = $UI/MessageLabel
@onready var items_label: Label = $UI/ItemsLabel
@onready var fade_rect: ColorRect = $FadeLayer/FadeRect
@onready var crowd_spawner: CrowdSpawner = $CrowdSpawner

# Diálogos
const INTRO_DIALOGUE = preload("res://dialogues/intro.dialogue")
const BALLOON_SCENE = preload("res://ui/visual_novel_balloon.tscn")

# Diálogos por fase - NPCs
const NPC_DIALOGUES := {
	2: preload("res://dialogues/fase2_npcs.dialogue"),
	3: preload("res://dialogues/fase3_npcs.dialogue"),
	4: preload("res://dialogues/fase4_npcs.dialogue"),
	5: preload("res://dialogues/fase5_npcs.dialogue"),
	6: preload("res://dialogues/fase6_npcs.dialogue"),
}

# Diálogos por fase - Principal (alvo/sinner)
const PRINCIPAL_DIALOGUES := {
	2: preload("res://dialogues/fase2_principal.dialogue"),
	3: preload("res://dialogues/fase3_principal.dialogue"),
	4: preload("res://dialogues/fase4_principal.dialogue"),
	5: preload("res://dialogues/fase5_principal.dialogue"),
	6: preload("res://dialogues/fase6_principal.dialogue"),
}

# Mapeamento de itens: fase -> { npc_index -> item_name }
const PHASE_ITEMS := {
	2: { 3: "monoculo" },  # NPC 3 da fase 2 dá o monóculo
	3: { 1: "relogio" },   # NPC 1 da fase 3 dá o relógio
	4: { 3: "visao_fase4" },  # NPC 3 da fase 4 dá a visão
}

# Número de NPCs a conversar por fase antes de poder clicar no sinner
const NPCS_PER_PHASE := {
	2: 3,
	3: 3,
	4: 3,
	5: 2,
	6: 0,
}

enum GameState { CUTSCENE, NPC_DIALOGUE, PLAYING, SINNER_DIALOGUE, GAMEOVER, VICTORY }
var state: GameState = GameState.CUTSCENE

var current_phase := 2
var npc_dialogue_index := 0
var correct_kills := 0
var pending_item: String = ""
var in_dialogue := false
var current_dialogue_npc: CrowdNPC = null

func _ready() -> void:
	randomize()
	state = GameState.CUTSCENE
	round_active = false
	crowd_spawner.npc_selected.connect(_on_npc_selected)
	Inventory.item_collected.connect(_on_item_collected)
	_update_items_ui()
	_play_fade_in()

func _play_fade_in() -> void:
	# Mantém tela preta durante o diálogo inicial
	fade_rect.modulate.a = 1.0
	_start_intro_dialogue()

func _start_intro_dialogue() -> void:
	DialogueManager.dialogue_ended.connect(_on_intro_ended)
	var balloon = BALLOON_SCENE.instantiate()
	get_tree().current_scene.add_child(balloon)
	balloon.start(INTRO_DIALOGUE, "start")

func _on_intro_ended(_resource) -> void:
	if state != GameState.CUTSCENE:
		return

	if DialogueManager.dialogue_ended.is_connected(_on_intro_ended):
		DialogueManager.dialogue_ended.disconnect(_on_intro_ended)

	_fade_to_phase(2)

func _fade_to_phase(phase: int) -> void:
	# Fade out
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	tween.tween_callback(_start_phase.bind(phase))
	tween.tween_property(fade_rect, "modulate:a", 0.0, 0.8)

func _start_phase(phase: int) -> void:
	current_phase = phase
	npc_dialogue_index = 0

	crowd_spawner.set_phase(phase)

	if phase > 6:
		_victory()
		return

	message_label.text = "Fase %d - Encontre o alvo!" % phase
	score_label.text = "Alvos eliminados: %d/5" % correct_kills

	# Iniciar timer logo no início da fase
	time_left = round_time
	round_active = true
	_update_timer_ui()

	await crowd_spawner.spawn_crowd()

	# Aplicar efeito do monóculo se tiver
	if Inventory.has("monoculo"):
		crowd_spawner.apply_monoculo_to_sinner()

	var npcs_needed = NPCS_PER_PHASE.get(phase, 0)
	if npcs_needed > 0:
		state = GameState.NPC_DIALOGUE
		_set_crowd_clickable(true)
	else:
		# Fase 6: vai direto pro gameplay
		state = GameState.PLAYING
		_set_crowd_clickable(true)

func _start_round() -> void:
	if state != GameState.PLAYING:
		return

	message_label.text = "Elimine o pecador antes que ele escape!"
	score_label.text = "Alvos eliminados: %d/5" % correct_kills
	_set_crowd_clickable(true)

func _process(delta: float) -> void:
	if not round_active:
		return

	# Timer roda durante NPC_DIALOGUE e PLAYING, mas pausa durante diálogos
	if state != GameState.NPC_DIALOGUE and state != GameState.PLAYING:
		return

	if in_dialogue:
		return

	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_update_timer_ui()
		_escape()
		return

	_update_timer_ui()
	_apply_endgame_pressure()

func _update_timer_ui() -> void:
	if timer_label == null:
		return
	if round_active and (state == GameState.NPC_DIALOGUE or state == GameState.PLAYING):
		timer_label.text = "Tempo: %.1f" % time_left
	else:
		timer_label.text = ""

func _apply_endgame_pressure() -> void:
	if time_left > 4.0:
		return

	var sinner := crowd_spawner.get_sinner()
	if sinner == null:
		return

	if randi() % 10 == 0:
		sinner.modulate = Color(1.2, 1.2, 1.2, 1.0)
	else:
		sinner.modulate = Color.WHITE

func _set_crowd_clickable(enabled: bool) -> void:
	var filter := Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for npc in crowd_spawner.npcs:
		if is_instance_valid(npc):
			npc.mouse_filter = filter

func _escape() -> void:
	round_active = false
	state = GameState.GAMEOVER
	message_label.text = "Ele escapou. Você perdeu. (Clique para recomeçar)"
	_set_crowd_clickable(false)
	_freeze_crowd()

func _freeze_crowd() -> void:
	for npc in crowd_spawner.npcs:
		if is_instance_valid(npc):
			npc.set_process(false)

func _on_npc_selected(npc: CrowdNPC) -> void:
	match state:
		GameState.NPC_DIALOGUE:
			_handle_npc_dialogue(npc)
		GameState.PLAYING:
			_handle_kill(npc)

func _handle_npc_dialogue(npc: CrowdNPC) -> void:
	if npc.is_sinner:
		# Pode clicar no sinner a qualquer momento - vai direto para o kill
		state = GameState.PLAYING
		round_active = true
		_handle_kill(npc)
		return

	_set_crowd_clickable(false)
	npc_dialogue_index += 1

	# Marca o NPC como "em diálogo" com cor vinho
	current_dialogue_npc = npc
	npc.color = Color(0.5, 0.1, 0.1)  # Tom vinho

	# Verificar se este NPC dá um item
	var phase_items = PHASE_ITEMS.get(current_phase, {})
	if phase_items.has(npc_dialogue_index):
		pending_item = phase_items[npc_dialogue_index]

	# Tocar diálogo do NPC
	var dialogue_resource = NPC_DIALOGUES.get(current_phase)
	if dialogue_resource:
		in_dialogue = true
		var title = "npc_%d" % npc_dialogue_index
		DialogueManager.dialogue_ended.connect(_on_npc_dialogue_ended)
		var balloon = BALLOON_SCENE.instantiate()
		get_tree().current_scene.add_child(balloon)
		balloon.start(dialogue_resource, title)

func _on_npc_dialogue_ended(_resource) -> void:
	if DialogueManager.dialogue_ended.is_connected(_on_npc_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_npc_dialogue_ended)

	in_dialogue = false

	# Restaura cor cinza do NPC
	if current_dialogue_npc and is_instance_valid(current_dialogue_npc):
		current_dialogue_npc.color = Color.GRAY
	current_dialogue_npc = null

	# Coletar item pendente
	if pending_item != "":
		Inventory.collect(pending_item)
		pending_item = ""

	_set_crowd_clickable(true)

func _handle_kill(npc: CrowdNPC) -> void:
	if npc.is_sinner:
		correct_kills += 1
		score_label.text = "Alvos eliminados: %d/5" % correct_kills

		round_active = false
		_set_crowd_clickable(false)

		# Flash no sinner
		var tween := create_tween()
		tween.tween_property(npc, "modulate", Color.WHITE * 2.0, 0.08)
		tween.tween_callback(_start_sinner_dialogue)
	else:
		_game_over("Você matou um inocente. Você perdeu.")

func _start_sinner_dialogue() -> void:
	state = GameState.SINNER_DIALOGUE
	# Manter movimento dos quadrados durante o diálogo

	var dialogue_resource = PRINCIPAL_DIALOGUES.get(current_phase)
	if dialogue_resource:
		DialogueManager.dialogue_ended.connect(_on_sinner_dialogue_ended)
		var balloon = BALLOON_SCENE.instantiate()
		get_tree().current_scene.add_child(balloon)
		balloon.start(dialogue_resource, "start")
	else:
		_advance_phase()

func _on_sinner_dialogue_ended(_resource) -> void:
	if DialogueManager.dialogue_ended.is_connected(_on_sinner_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_sinner_dialogue_ended)

	_advance_phase()

func _advance_phase() -> void:
	crowd_spawner.clear()
	_fade_to_phase(current_phase + 1)

func _on_item_collected(item_name: String) -> void:
	_update_items_ui()

	match item_name:
		"monoculo":
			message_label.text = "Monóculo obtido! O alvo agora pulsa."
			crowd_spawner.apply_monoculo_to_sinner()
		"relogio":
			message_label.text = "Relógio obtido! Os NPCs estão mais lentos."
			crowd_spawner.apply_relogio_effect()
		"visao_fase4":
			message_label.text = "Visão obtida! Menos distratores nas próximas fases."
			crowd_spawner.apply_visao_effect()

func _update_items_ui() -> void:
	if items_label == null:
		return

	var items_text := ""
	if Inventory.has("monoculo"):
		items_text += "🔍 Monóculo\n"
	if Inventory.has("relogio"):
		items_text += "⏱️ Relógio\n"
	if Inventory.has("visao_fase4"):
		items_text += "👁️ Visão\n"

	items_label.text = items_text

func _victory() -> void:
	state = GameState.VICTORY
	round_active = false
	message_label.text = "Você completou a Limpeza! Glória ao Deus Ocultus!"
	timer_label.text = ""
	_freeze_crowd()

func _game_over(reason: String) -> void:
	round_active = false
	state = GameState.GAMEOVER
	message_label.text = reason + " (Clique para recomeçar)"
	_set_crowd_clickable(false)
	_freeze_crowd()

func _unhandled_input(event: InputEvent) -> void:
	if state != GameState.GAMEOVER:
		return

	if event is InputEventMouseButton and event.pressed:
		_restart_game()

func _restart_game() -> void:
	# Reset inventory
	for key in Inventory.items.keys():
		Inventory.items[key] = false

	# Reset spawner modifiers
	crowd_spawner.speed_modifier = 1.0
	crowd_spawner.distractor_modifier = 1.0

	crowd_spawner.clear()
	correct_kills = 0
	_update_items_ui()
	_start_phase(2)
