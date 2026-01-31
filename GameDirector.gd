extends Node2D
class_name GameDirector

@export var round_time := 15.0
@export var escape_time := 3.0
@export var escape_uniform_speed := 220.0  # crowd speed during escape phase

var time_left := 0.0
var escape_left := 0.0
var round_active := false

@onready var timer_label: Label = $UI/TimerLabel
@onready var score_label: Label = $UI/ScoreLabel
@onready var message_label: Label = $UI/MessageLabel
@onready var items_label: Label = $UI/ItemsLabel
@onready var fade_rect: ColorRect = $FadeLayer/FadeRect
@onready var crowd_spawner: CrowdSpawner = $CrowdSpawner
@onready var item_spawner: ItemSpawner = $ItemSpawner

# Game Over UI
@onready var game_over_panel: Control = $FadeLayer/GameOverPanel
@onready var game_over_wave_label: Label = $FadeLayer/GameOverPanel/VBox/WaveLabel
@onready var game_over_kills_label: Label = $FadeLayer/GameOverPanel/VBox/KillsLabel
@onready var play_again_button: Button = $FadeLayer/GameOverPanel/VBox/PlayAgainButton
@onready var menu_button: Button = $FadeLayer/GameOverPanel/VBox/MenuButton

const INTRO_DIALOGUE = preload("res://dialogues/intro.dialogue")
const BALLOON_SCENE = preload("res://ui/visual_novel_balloon.tscn")

const NPC_DIALOGUES := {
	2: preload("res://dialogues/fase2_npcs.dialogue"),
	3: preload("res://dialogues/fase3_npcs.dialogue"),
	4: preload("res://dialogues/fase4_npcs.dialogue"),
	5: preload("res://dialogues/fase5_npcs.dialogue"),
	6: preload("res://dialogues/fase6_npcs.dialogue"),
}

const PRINCIPAL_DIALOGUES := {
	2: preload("res://dialogues/fase2_principal.dialogue"),
	3: preload("res://dialogues/fase3_principal.dialogue"),
	4: preload("res://dialogues/fase4_principal.dialogue"),
	5: preload("res://dialogues/fase5_principal.dialogue"),
	6: preload("res://dialogues/fase6_principal.dialogue"),
}

const PHASE_ITEMS := {
	2: { 3: "monoculo" },
	3: { 1: "relogio" },
	4: { 3: "visao_fase4" },
}

const NPCS_PER_PHASE := {
	2: 3,
	3: 3,
	4: 3,
	5: 2,
	6: 0,
}

enum GameState { CUTSCENE, NPC_DIALOGUE, PLAYING, ESCAPE, SINNER_DIALOGUE, GAMEOVER, VICTORY }
var state: GameState = GameState.CUTSCENE

var current_phase := 2
var npc_dialogue_index := 0
var correct_kills := 0

var pending_item: String = ""
var in_dialogue := false
var current_dialogue_npc: CrowdNPC = null
var talked_npcs := {}

# Infinite mode variables
var infinite_wave := 0
var infinite_kills := 0
var infinite_lives := 3
const INFINITE_MAX_LIVES := 3

# Item duration tracking (wave when item was collected)
var item_collected_wave := {
	"monoculo": -1,
	"relogio": -1,
	"visao_fase4": -1,
}
const ITEM_DURATION := 3  # Item lasts 3 waves including collection wave


func _ready() -> void:
	randomize()
	state = GameState.CUTSCENE
	round_active = false

	crowd_spawner.npc_selected.connect(_on_npc_selected)
	crowd_spawner.sinner_escaped.connect(_on_sinner_escaped)

	Inventory.item_collected.connect(_on_item_collected)

	# Connect item spawner if in infinite mode
	if item_spawner:
		item_spawner.item_collected.connect(_on_item_collected)

	# Connect game over buttons
	if play_again_button:
		play_again_button.pressed.connect(_on_play_again_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_button_pressed)

	_update_items_ui()

	# Check for infinite mode
	if GameMode.is_infinite():
		_start_infinite_mode()
		return

	# Inicia musica de intro
	AudioManager.play_intro_music()
	_play_fade_in()


func _play_fade_in() -> void:
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


# ============== INFINITE MODE ==============

func _start_infinite_mode() -> void:
	state = GameState.PLAYING
	infinite_wave = 0
	infinite_kills = 0
	infinite_lives = INFINITE_MAX_LIVES

	# Reset item tracking
	for key in item_collected_wave.keys():
		item_collected_wave[key] = -1

	# Hide game over panel if visible
	if game_over_panel:
		game_over_panel.hide()

	# Skip cutscene, fade in directly
	fade_rect.modulate.a = 1.0

	# Play phase music (use phase 2 music for infinite)
	AudioManager.play_phase_music(2)

	# Start first wave
	_start_infinite_wave(1)

	# Fade in
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 0.8)


func _start_infinite_wave(wave: int) -> void:
	infinite_wave = wave
	_set_crowd_clickable(false)

	# Reset inventory every 10 waves (at wave 11, 21, 31, etc.)
	var inventory_reset := false
	if wave > 1 and (wave - 1) % 10 == 0:
		_reset_inventory()
		inventory_reset = true
	else:
		# Check for expired items (only if not doing full reset)
		_check_item_expiration()

	# Clear previous crowd and items
	crowd_spawner.clear()
	if item_spawner:
		item_spawner.clear()

	# Configure spawner for this wave
	crowd_spawner.set_infinite_wave(wave)

	# Update UI
	_update_infinite_ui()
	if inventory_reset:
		message_label.text = "Onda %d - Inventario resetado!" % wave
	else:
		message_label.text = "Onda %d - Encontre o pecador!" % wave

	# Reset timer
	time_left = round_time
	escape_left = escape_time
	round_active = true

	await crowd_spawner.spawn_crowd()

	# Apply item effects if player has them
	if Inventory.has("monoculo"):
		crowd_spawner.apply_monoculo_to_sinner()

	# Spawn floor items in infinite mode
	if item_spawner:
		item_spawner.spawn_items_for_wave(wave)
		item_spawner.set_items_clickable(true)

	state = GameState.PLAYING
	_set_crowd_clickable(true)
	_update_timer_ui()


func _update_infinite_ui() -> void:
	var lives_text := ""
	for i in range(infinite_lives):
		lives_text += "♥"
	for i in range(INFINITE_MAX_LIVES - infinite_lives):
		lives_text += "♡"
	score_label.text = "Eliminados: %d | %s" % [infinite_kills, lives_text]


func _reset_inventory() -> void:
	for key in Inventory.items.keys():
		Inventory.items[key] = false
	for key in item_collected_wave.keys():
		item_collected_wave[key] = -1
	crowd_spawner.speed_modifier = 1.0
	crowd_spawner.distractor_modifier = 1.0
	_update_items_ui()


func _check_item_expiration() -> void:
	var expired_items: Array[String] = []

	for item_name in item_collected_wave.keys():
		var collected_wave: int = item_collected_wave[item_name]
		if collected_wave < 0:
			continue

		# Item expires after ITEM_DURATION waves (3 waves including collection)
		if infinite_wave > collected_wave + ITEM_DURATION - 1:
			expired_items.append(item_name)

	for item_name in expired_items:
		_expire_item(item_name)

	if not expired_items.is_empty():
		_update_items_ui()


func _expire_item(item_name: String) -> void:
	Inventory.items[item_name] = false
	item_collected_wave[item_name] = -1

	match item_name:
		"relogio":
			crowd_spawner.speed_modifier = 1.0
		"visao_fase4":
			crowd_spawner.distractor_modifier = 1.0


func _handle_kill_infinite(npc: CrowdNPC) -> void:
	AudioManager.stop_heartbeat()

	if npc.is_sinner:
		infinite_kills += 1
		_update_infinite_ui()

		round_active = false
		_set_crowd_clickable(false)
		if item_spawner:
			item_spawner.set_items_clickable(false)

		AudioManager.play_kill_sound(false)

		# Flash effect
		var tween := create_tween()
		tween.tween_property(npc, "modulate", Color.WHITE * 2.0, 0.08)
		tween.tween_callback(_advance_infinite_wave)
	else:
		# Killed innocent - lose a life
		infinite_lives -= 1
		_update_infinite_ui()
		AudioManager.play_kill_sound(true)

		if infinite_lives <= 0:
			_show_infinite_game_over()
		else:
			# Flash red on screen and show warning
			message_label.text = "Inocente morto! Vidas restantes: %d" % infinite_lives
			_flash_screen_red()


func _advance_infinite_wave() -> void:
	AudioManager.play_phase_complete()

	# Brief pause before next wave
	await get_tree().create_timer(0.5).timeout

	_start_infinite_wave(infinite_wave + 1)


func _escape_infinite() -> void:
	infinite_lives -= 1
	_update_infinite_ui()
	AudioManager.stop_heartbeat()

	if infinite_lives <= 0:
		_show_infinite_game_over()
	else:
		message_label.text = "Ele escapou! Vidas restantes: %d" % infinite_lives
		_flash_screen_red()
		# Continue to next wave after a brief pause
		round_active = false
		_set_crowd_clickable(false)
		await get_tree().create_timer(1.0).timeout
		_start_infinite_wave(infinite_wave + 1)


func _flash_screen_red() -> void:
	var original_color := fade_rect.color
	fade_rect.color = Color(0.8, 0.0, 0.0, 1.0)
	fade_rect.modulate.a = 0.5

	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): fade_rect.color = original_color)


func _show_infinite_game_over() -> void:
	round_active = false
	state = GameState.GAMEOVER
	in_dialogue = false

	_set_crowd_clickable(false)
	if item_spawner:
		item_spawner.set_items_clickable(false)
	_freeze_crowd()

	# Clear the game area
	crowd_spawner.clear()
	if item_spawner:
		item_spawner.clear()

	# Update game over panel
	game_over_wave_label.text = "Onda alcancada: %d" % infinite_wave
	game_over_kills_label.text = "Pecadores eliminados: %d" % infinite_kills

	# Show game over panel directly
	game_over_panel.show()

	AudioManager.play_gameover_music()


# ============== END INFINITE MODE ==============


func _fade_to_phase(phase: int) -> void:
	_set_crowd_clickable(false)
	in_dialogue = true

	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	tween.tween_callback(_start_phase.bind(phase))
	tween.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func(): in_dialogue = false)


func _start_phase(phase: int) -> void:
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

	# Toca musica apropriada para a fase
	AudioManager.play_phase_music(phase)

	# Iniciar timer logo no início da fase
	time_left = round_time
	escape_left = escape_time
	round_active = true
	_update_timer_ui()

	await crowd_spawner.spawn_crowd()

	if Inventory.has("monoculo"):
		crowd_spawner.apply_monoculo_to_sinner()

	var npcs_needed: int = int(NPCS_PER_PHASE.get(phase, 0))
	state = GameState.NPC_DIALOGUE if npcs_needed > 0 else GameState.PLAYING
	_set_crowd_clickable(true)


func _process(delta: float) -> void:
	if not round_active:
		return
	if in_dialogue:
		return

	if state == GameState.NPC_DIALOGUE or state == GameState.PLAYING:
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			_update_timer_ui()
			_begin_escape_phase()
			return

		_update_timer_ui()
		_apply_endgame_pressure()

	elif state == GameState.ESCAPE:
		escape_left -= delta
		if escape_left <= 0.0:
			escape_left = 0.0
			_update_timer_ui()
			_escape()
			return

		_update_timer_ui()


func _begin_escape_phase() -> void:
	state = GameState.ESCAPE
	escape_left = escape_time

	message_label.text = "ELE ESTÁ FUGINDO!"
	crowd_spawner.begin_escape_phase(escape_time, escape_uniform_speed)
	_update_timer_ui()


func _on_sinner_escaped() -> void:
	# Failsafe only: only end if timer is essentially done.
	# This keeps the UI truthful: timer == time until escape.
	if state != GameState.ESCAPE:
		return

	if escape_left <= 0.05:
		_escape()
	# else ignore (we expect escape exactly when timer ends)


func _update_timer_ui() -> void:
	if timer_label == null:
		return

	if not round_active:
		timer_label.text = ""
		return

	if GameMode.is_infinite():
		if state == GameState.ESCAPE:
			timer_label.text = "Onda %d | Fuga: %.1f" % [infinite_wave, escape_left]
		elif state == GameState.PLAYING:
			timer_label.text = "Onda %d | Tempo: %.1f" % [infinite_wave, time_left]
		else:
			timer_label.text = ""
	else:
		if state == GameState.ESCAPE:
			timer_label.text = "Fuga: %.1f" % escape_left
		elif state == GameState.NPC_DIALOGUE or state == GameState.PLAYING:
			timer_label.text = "Tempo: %.1f" % time_left
		else:
			timer_label.text = ""


func _apply_endgame_pressure() -> void:
	if time_left > 4.0:
		AudioManager.stop_heartbeat()
		return

	# Inicia heartbeat quando tempo esta baixo
	AudioManager.start_heartbeat()

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


func _on_npc_selected(npc: CrowdNPC) -> void:
	if in_dialogue:
		return
	if npc == null or not is_instance_valid(npc):
		return

	match state:
		GameState.NPC_DIALOGUE:
			_handle_npc_dialogue(npc)
		GameState.PLAYING, GameState.ESCAPE:
			if GameMode.is_infinite():
				_handle_kill_infinite(npc)
			else:
				_handle_kill(npc)
		_:
			pass


func _handle_npc_dialogue(npc: CrowdNPC) -> void:
	var needed: int = int(NPCS_PER_PHASE.get(current_phase, 0))

	if npc.is_sinner:
		if npc_dialogue_index < needed:
			message_label.text = "Converse com mais %d pessoa(s)..." % (needed - npc_dialogue_index)
			return
		state = GameState.PLAYING
		_handle_kill(npc)
		return

	var id := npc.get_instance_id()
	if talked_npcs.has(id):
		message_label.text = "Você já falou com essa pessoa."
		return
	talked_npcs[id] = true

	# Toca som de selecao de NPC
	AudioManager.play_npc_select()

	_set_crowd_clickable(false)
	npc_dialogue_index += 1

	current_dialogue_npc = npc
	npc.color = Color(0.5, 0.1, 0.1)

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

	if current_dialogue_npc and is_instance_valid(current_dialogue_npc):
		current_dialogue_npc.color = Color.GRAY
	current_dialogue_npc = null

	if pending_item != "":
		Inventory.collect(pending_item)
		pending_item = ""

	_set_crowd_clickable(true)


func _handle_kill(npc: CrowdNPC) -> void:
	# Para o heartbeat ao eliminar
	AudioManager.stop_heartbeat()

	if npc.is_sinner:
		correct_kills += 1
		score_label.text = "Alvos eliminados: %d/5" % correct_kills

		round_active = false
		_set_crowd_clickable(false)

		# Som de eliminacao
		AudioManager.play_kill_sound(false)

		# Flash no sinner
		var tween := create_tween()
		tween.tween_property(npc, "modulate", Color.WHITE * 2.0, 0.08)
		tween.tween_callback(_start_sinner_dialogue)
	else:
		# Som de matar inocente (dissonancia)
		AudioManager.play_kill_sound(true)
		_game_over("Você matou um inocente. Você perdeu.")


func _start_sinner_dialogue() -> void:
	state = GameState.SINNER_DIALOGUE
	in_dialogue = true

	# Toca musica melancolica do sinner
	AudioManager.play_sinner_music()

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
	# Som de fase completa
	AudioManager.play_phase_complete()
	crowd_spawner.clear()
	_fade_to_phase(current_phase + 1)


func _escape() -> void:
	if GameMode.is_infinite():
		_escape_infinite()
		return

	round_active = false
	state = GameState.GAMEOVER
	message_label.text = "Ele escapou da cidade. Você perdeu. (Clique para recomeçar)"
	_set_crowd_clickable(false)
	_freeze_crowd()
	timer_label.text = ""
	# Audio: para heartbeat e toca musica de game over
	AudioManager.stop_heartbeat()
	AudioManager.play_gameover_music()


func _freeze_crowd() -> void:
	for npc in crowd_spawner.npcs:
		if is_instance_valid(npc):
			npc.set_process(false)


func _on_item_collected(item_name: String) -> void:
	# Track when item was collected (for infinite mode duration)
	if GameMode.is_infinite():
		item_collected_wave[item_name] = infinite_wave

	_update_items_ui()

	# Som de coleta de item (especial para itens importantes)
	var is_special := item_name in ["monoculo", "relogio", "visao_fase4"]
	AudioManager.play_item_collect(is_special)

	var duration_msg := " (dura 3 ondas)" if GameMode.is_infinite() else ""

	match item_name:
		"monoculo":
			message_label.text = "Monóculo obtido! O alvo agora pulsa." + duration_msg
			crowd_spawner.apply_monoculo_to_sinner()
		"relogio":
			message_label.text = "Relógio obtido! Os NPCs estão mais lentos." + duration_msg
			crowd_spawner.apply_relogio_effect()
		"visao_fase4":
			message_label.text = "Visão obtida! Menos distratores." + duration_msg
			crowd_spawner.apply_visao_effect()


func _update_items_ui() -> void:
	if items_label == null:
		return

	var items_text := ""

	if Inventory.has("monoculo"):
		var remaining := _get_item_remaining_waves("monoculo")
		if remaining > 0:
			items_text += "🔍 Monóculo (%d)\n" % remaining
		else:
			items_text += "🔍 Monóculo\n"

	if Inventory.has("relogio"):
		var remaining := _get_item_remaining_waves("relogio")
		if remaining > 0:
			items_text += "⏱️ Relógio (%d)\n" % remaining
		else:
			items_text += "⏱️ Relógio\n"

	if Inventory.has("visao_fase4"):
		var remaining := _get_item_remaining_waves("visao_fase4")
		if remaining > 0:
			items_text += "👁️ Visão (%d)\n" % remaining
		else:
			items_text += "👁️ Visão\n"

	items_label.text = items_text


func _get_item_remaining_waves(item_name: String) -> int:
	if not GameMode.is_infinite():
		return 0

	var collected_wave: int = item_collected_wave.get(item_name, -1)
	if collected_wave < 0:
		return 0

	var remaining := ITEM_DURATION - (infinite_wave - collected_wave)
	return maxi(remaining, 0)


func _victory() -> void:
	state = GameState.VICTORY
	round_active = false
	in_dialogue = false

	message_label.text = "Você completou a Limpeza! Glória ao Deus Ocultus!"
	timer_label.text = ""

	_set_crowd_clickable(false)
	_freeze_crowd()
	# Audio: toca musica de vitoria (ambigua, nao celebrativa)
	AudioManager.play_victory_music()


func _game_over(reason: String) -> void:
	round_active = false
	state = GameState.GAMEOVER
	in_dialogue = false

	message_label.text = reason + " (Clique para recomeçar)"
	_set_crowd_clickable(false)
	_freeze_crowd()
	# Audio: para heartbeat e toca musica de game over
	AudioManager.stop_heartbeat()
	AudioManager.play_gameover_music()


func _unhandled_input(event: InputEvent) -> void:
	if state != GameState.GAMEOVER and state != GameState.VICTORY:
		return

	# In infinite mode, use buttons instead of click anywhere
	if GameMode.is_infinite():
		return

	if event is InputEventMouseButton and event.pressed:
		_restart_game()


func _return_to_menu() -> void:
	# Reset inventory
	for key in Inventory.items.keys():
		Inventory.items[key] = false

	# Reset modifiers
	crowd_spawner.speed_modifier = 1.0
	crowd_spawner.distractor_modifier = 1.0

	# Hide game over panel
	if game_over_panel:
		game_over_panel.hide()

	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _on_play_again_pressed() -> void:
	AudioManager.play_ui_click()

	# Hide game over panel
	game_over_panel.hide()

	# Reset inventory
	for key in Inventory.items.keys():
		Inventory.items[key] = false

	# Reset modifiers
	crowd_spawner.speed_modifier = 1.0
	crowd_spawner.distractor_modifier = 1.0

	_update_items_ui()

	# Restart infinite mode
	_start_infinite_mode()


func _on_menu_button_pressed() -> void:
	AudioManager.play_ui_click()
	_return_to_menu()


func _restart_game() -> void:
	for key in Inventory.items.keys():
		Inventory.items[key] = false

	talked_npcs.clear()
	pending_item = ""
	current_dialogue_npc = null
	in_dialogue = false

	crowd_spawner.speed_modifier = 1.0
	crowd_spawner.distractor_modifier = 1.0

	crowd_spawner.clear()
	correct_kills = 0
	_update_items_ui()

	state = GameState.CUTSCENE
	_fade_to_phase(2)
