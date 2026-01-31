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

# Itens por fase:
# IMPORTANT: This is "Nth unique conversation gives item", NOT "NPC index in scene".
const PHASE_ITEMS := {
	2: { 3: "monoculo" },      # 3ª conversa da fase 2 dá o monóculo
	3: { 1: "relogio" },       # 1ª conversa da fase 3 dá o relógio
	4: { 3: "visao_fase4" },   # 3ª conversa da fase 4 dá a visão
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

# Prevent farming the same NPC:
# instance_id -> true
var talked_npcs := {}

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
	_set_crowd_clickable(false)
	_start_intro_dialogue()

func _start_intro_dialogue() -> void:
	var balloon = BALLOON_SCENE.instantiate()
	get_tree().current_scene.add_child(balloon)

	DialogueManager.dialogue_ended.connect(_on_intro_ended, CONNECT_ONE_SHOT)
	balloon.start(INTRO_DIALOGUE, "start")

func _on_intro_ended(_resource) -> void:
	if state != GameState.CUTSCENE:
		return
	_fade_to_phase(2)

func _fade_to_phase(phase: int) -> void:
	_set_crowd_clickable(false)
	in_dialogue = true

	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	tween.tween_callback(_start_phase.bind(phase))
	tween.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func(): in_dialogue = false)

func _start_phase(phase: int) -> void:
	# Reset phase-local state
	current_phase = phase
	npc_dialogue_index = 0
	pending_item = ""
	current_dialogue_npc = null
	talked_npcs.clear()
	in_dialogue = false

	crowd_spawner.set_phase(phase)

	if phase > 6:
		_victory()
		return

	message_label.text = "Fase %d - Encontre o alvo!" % phase
	score_label.text = "Alvos eliminados: %d/5" % correct_kills

	# Start timer at phase start (as your friend intended)
	time_left = round_time
	round_active = true
	_update_timer_ui()

	await crowd_spawner.spawn_crowd()

	# Apply monocle if owned
	if Inventory.has("monoculo"):
		crowd_spawner.apply_monoculo_to_sinner()

	# ✅ FIX: cast Variant -> int
	var npcs_needed: int = int(NPCS_PER_PHASE.get(phase, 0))

	if npcs_needed > 0:
		state = GameState.NPC_DIALOGUE
	else:
		state = GameState.PLAYING

	_set_crowd_clickable(true)

func _process(delta: float) -> void:
	if not round_active:
		return

	# Timer should only run during these states
	if state != GameState.NPC_DIALOGUE and state != GameState.PLAYING:
		return

	# Pause timer during dialogue balloons / transitions
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

	if round_active and (state == GameState.NPC_DIALOGUE or state == GameState.PLAYING) and not in_dialogue:
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
	# Hard gate during any dialogue balloon / transition
	if in_dialogue:
		return

	# Safety
	if npc == null or not is_instance_valid(npc):
		return

	match state:
		GameState.NPC_DIALOGUE:
			_handle_npc_dialogue(npc)
		GameState.PLAYING:
			_handle_kill(npc)
		_:
			pass

func _handle_npc_dialogue(npc: CrowdNPC) -> void:
	# ✅ FIX: cast Variant -> int
	var needed: int = int(NPCS_PER_PHASE.get(current_phase, 0))

	# Enforce: must talk to N NPCs before killing sinner
	if npc.is_sinner:
		if npc_dialogue_index < needed:
			message_label.text = "Converse com mais %d pessoa(s)..." % (needed - npc_dialogue_index)
			return
		state = GameState.PLAYING
		_handle_kill(npc)
		return

	# Prevent talking to the same NPC multiple times
	var id := npc.get_instance_id()
	if talked_npcs.has(id):
		message_label.text = "Você já falou com essa pessoa."
		return
	talked_npcs[id] = true

	_set_crowd_clickable(false)
	npc_dialogue_index += 1

	# Mark NPC as "in dialogue"
	current_dialogue_npc = npc
	npc.color = Color(0.5, 0.1, 0.1)  # vinho

	# Check pending item for this conversation number
	var phase_items = PHASE_ITEMS.get(current_phase, {})
	if phase_items.has(npc_dialogue_index):
		pending_item = phase_items[npc_dialogue_index]

	var dialogue_resource = NPC_DIALOGUES.get(current_phase)
	if dialogue_resource:
		in_dialogue = true
		var title := "npc_%d" % npc_dialogue_index

		var balloon = BALLOON_SCENE.instantiate()
		get_tree().current_scene.add_child(balloon)

		DialogueManager.dialogue_ended.connect(_on_npc_dialogue_ended, CONNECT_ONE_SHOT)
		balloon.start(dialogue_resource, title)
	else:
		_on_npc_dialogue_ended(null)

func _on_npc_dialogue_ended(_resource) -> void:
	in_dialogue = false

	# Restore NPC color
	if current_dialogue_npc and is_instance_valid(current_dialogue_npc):
		current_dialogue_npc.color = Color.GRAY
	current_dialogue_npc = null

	# Collect item
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

		var tween := create_tween()
		tween.tween_property(npc, "modulate", Color.WHITE * 2.0, 0.08)
		tween.tween_callback(_start_sinner_dialogue)
	else:
		_game_over("Você matou um inocente. Você perdeu.")

func _start_sinner_dialogue() -> void:
	state = GameState.SINNER_DIALOGUE
	in_dialogue = true

	var dialogue_resource = PRINCIPAL_DIALOGUES.get(current_phase)
	if dialogue_resource:
		var balloon = BALLOON_SCENE.instantiate()
		get_tree().current_scene.add_child(balloon)

		DialogueManager.dialogue_ended.connect(_on_sinner_dialogue_ended, CONNECT_ONE_SHOT)
		balloon.start(dialogue_resource, "start")
	else:
		in_dialogue = false
		_advance_phase()

func _on_sinner_dialogue_ended(_resource) -> void:
	in_dialogue = false
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
	in_dialogue = false

	message_label.text = "Você completou a Limpeza! Glória ao Deus Ocultus!"
	timer_label.text = ""

	_set_crowd_clickable(false)
	_freeze_crowd()

func _game_over(reason: String) -> void:
	round_active = false
	state = GameState.GAMEOVER
	in_dialogue = false

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

	# Reset local state
	talked_npcs.clear()
	pending_item = ""
	current_dialogue_npc = null
	in_dialogue = false

	# Reset spawner modifiers
	crowd_spawner.speed_modifier = 1.0
	crowd_spawner.distractor_modifier = 1.0

	crowd_spawner.clear()
	correct_kills = 0
	_update_items_ui()

	# Restart flow directly at phase 2
	state = GameState.CUTSCENE
	_fade_to_phase(2)
