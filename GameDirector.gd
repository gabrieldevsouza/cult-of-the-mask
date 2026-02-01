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
@onready var bad_ending_bg: TextureRect = %BadEndingBackground
@onready var crowd_spawner: CrowdSpawner = $CrowdSpawner
@onready var item_spawner: ItemSpawner = $ItemSpawner
@onready var protagonist: Protagonist = $Squares/Protagonist
@onready var squares_container: Control = $Squares

# Game Over UI
@onready var game_over_panel: Control = $FadeLayer/GameOverPanel
@onready var game_over_wave_label: Label = $FadeLayer/GameOverPanel/VBox/WaveLabel
@onready var game_over_kills_label: Label = $FadeLayer/GameOverPanel/VBox/KillsLabel
@onready var play_again_button: Button = $FadeLayer/GameOverPanel/VBox/PlayAgainButton
@onready var menu_button: Button = $FadeLayer/GameOverPanel/VBox/MenuButton

# Pause UI
@onready var pause_panel: Control = $FadeLayer/PausePanel
@onready var resume_button: Button = $FadeLayer/PausePanel/VBox/ResumeButton
@onready var pause_menu_button: Button = $FadeLayer/PausePanel/VBox/PauseMenuButton
var is_paused := false

# Tutorial UI
@onready var tutorial_panel: Control = %TutorialPanel
@onready var tutorial_item_image: TextureRect = %ItemImage
@onready var tutorial_description: Label = %Description
@onready var tutorial_ok_button: Button = %OkButton
var tutorial_shown := {}  # Track which items have shown tutorial
var tutorial_active := false

const TUTORIAL_TITLES := {
	"monoculo": "New Item!",
	"relogio": "New Item!",
	"rosario": "New Item!",
	"lagrima": "New Item!",
	"calice": "New Item!",
}

const TUTORIAL_IMAGES := {
	"monoculo": preload("res://images/monoculo_grande.png"),
	"relogio": preload("res://images/relogio_grande.png"),
	"rosario": preload("res://images/cruz_de_malta_fds_grande.png"),
	"lagrima": preload("res://images/frasco_de_lagrima_grande.png"),
	"calice": preload("res://images/grande_calice.png"),
}

const TUTORIAL_DESCRIPTIONS := {
	"monoculo": "MONOCLE OF TRUTH\n\nReveals sinners with a special glow. Lasts 3 waves.",
	"relogio": "POCKET WATCH\n\nSlows down all NPCs. Lasts 3 waves.",
	"rosario": "CORRUPTED ROSARY\n\nEvery 5 kills, gain 1 extra life. Lasts 3 waves.",
	"lagrima": "PRIESTESS TEAR\n\nNext wave will have no innocents - only sinners.",
	"calice": "BLOOD CHALICE\n\nRestores 1 life immediately.",
}

# Dead body sprite (story mode only)
const DEAD_BODY_TEXTURE := preload("res://images/corpo_morto_1.png")
var last_sinner_position: Vector2 = Vector2.ZERO

# Scenario elements (to hide in infinite mode)
@onready var scenario_casa1: Sprite2D = $ScenarioBackground/Casa1
@onready var scenario_casa2: Sprite2D = $ScenarioBackground/Casa2
@onready var scenario_casa3: Sprite2D = $ScenarioBackground/Casa3
@onready var scenario_igreja: Sprite2D = $ScenarioBackground/Igreja

const INTRO_DIALOGUE = preload("res://dialogues/intro.dialogue")
const FINAL_DIALOGUE = preload("res://dialogues/final.dialogue")
const BALLOON_SCENE = preload("res://ui/visual_novel_balloon.tscn")

# Final phase constants
const FINAL_TIME := 15.0
const FINAL_ENEMY_COUNT := 40
const FINAL_KILL_PHRASES := ["kill_1", "kill_2", "kill_3"]

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
}

const NPCS_PER_PHASE := {
	2: 3,
	3: 3,
	4: 3,
	5: 2,
	6: 1,
}

enum GameState { CUTSCENE, NPC_DIALOGUE, PLAYING, ESCAPE, SINNER_DIALOGUE, GAMEOVER, VICTORY, FINAL_PHASE }
var state: GameState = GameState.CUTSCENE

var current_phase := 2
var npc_dialogue_index := 0
var correct_kills := 0

var pending_item: String = ""
var in_dialogue := false
var current_dialogue_npc: CrowdNPC = null
var talked_npcs := {}

# Infinite mode variables (shared between Find and Kill modes)
var infinite_wave := 0
var infinite_kills := 0
var infinite_lives := 3
const INFINITE_MAX_LIVES := 3

# Kill mode specific variables
var kill_wave_enemies := 0
var kill_wave_killed := 0
var kill_wave_time := 20.0  # Time per wave in kill mode

# Item duration tracking (wave when item was collected)
var item_collected_wave := {
	"monoculo": -1,
	"relogio": -1,
	"rosario": -1,
}
const ITEM_DURATION := 3  # Item lasts 3 waves including collection wave

# Final phase variables
var final_total_enemies := 0
var final_kills := 0
var final_time_left := 0.0

# New items
var rosario_kill_count := 0
const ROSARIO_KILLS_FOR_LIFE := 5
var lagrima_active := false

# Bad ending sequence lock
var bad_ending_in_progress := false


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

	# Connect pause buttons
	if resume_button:
		resume_button.pressed.connect(_resume_game)
	if pause_menu_button:
		pause_menu_button.pressed.connect(_on_pause_menu_pressed)
	if pause_panel:
		pause_panel.hide()

	# Connect tutorial button
	if tutorial_ok_button:
		tutorial_ok_button.pressed.connect(_close_tutorial)
	if tutorial_panel:
		tutorial_panel.hide()

	# Connect background clicks
	if squares_container:
		squares_container.gui_input.connect(_on_background_input)

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

	# Show protagonist in story mode
	if protagonist:
		protagonist.show()

	# Ensure scenario elements are visible in story mode
	if scenario_casa1:
		scenario_casa1.show()
	if scenario_casa2:
		scenario_casa2.show()
	if scenario_casa3:
		scenario_casa3.show()
	if scenario_igreja:
		scenario_igreja.show()

	# Create dialogue balloon first (with background image)
	_start_intro_dialogue()

	# Then fade in from black - background image will be visible during fade
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 1.2)


func _start_intro_dialogue() -> void:
	var balloon = BALLOON_SCENE.instantiate()
	get_tree().current_scene.add_child(balloon)

	DialogueManager.dialogue_ended.connect(_on_intro_ended, CONNECT_ONE_SHOT)
	# Hide character portraits during intro dialogue, show background image
	balloon.start(INTRO_DIALOGUE, "start", [], false, true)


func _on_intro_ended(_resource) -> void:
	if state != GameState.CUTSCENE:
		return
	# Instantly go to black before balloon is destroyed
	fade_rect.modulate.a = 1.0
	# Then fade in to phase 2
	_start_phase(2)
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 0.8)


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

	# Hide protagonist in infinite mode
	if protagonist:
		protagonist.hide()

	# Hide scenario elements in infinite mode (houses and church)
	if scenario_casa1:
		scenario_casa1.hide()
	if scenario_casa2:
		scenario_casa2.hide()
	if scenario_casa3:
		scenario_casa3.hide()
	if scenario_igreja:
		scenario_igreja.hide()

	# Skip cutscene, fade in directly
	fade_rect.modulate.a = 1.0

	# Play phase music (use phase 2 music for infinite)
	AudioManager.play_phase_music(2)

	# Start first wave based on mode
	if GameMode.is_infinite_kill():
		_start_infinite_kill_wave(1)
	else:
		_start_infinite_wave(1)

	# Fade in
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 0.8)


func _start_infinite_wave(wave: int) -> void:
	infinite_wave = wave
	_set_crowd_clickable(false)

	# Check if lagrima is active (no innocents this wave)
	var no_innocents := lagrima_active
	if lagrima_active:
		lagrima_active = false
		_update_items_ui()

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

	# If lagrima was active, set no distractors
	if no_innocents:
		crowd_spawner.num_distractors = 0

	# Update UI
	_update_infinite_ui()
	if inventory_reset:
		message_label.text = "Wave %d - Inventory reset!" % wave
	else:
		message_label.text = "Wave %d - Find the sinner!" % wave

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
	score_label.text = "Kills: %d | %s" % [infinite_kills, lives_text]


func _reset_inventory() -> void:
	for key in Inventory.items.keys():
		Inventory.items[key] = false
	for key in item_collected_wave.keys():
		item_collected_wave[key] = -1
	crowd_spawner.speed_modifier = 1.0
	crowd_spawner.distractor_modifier = 1.0
	rosario_kill_count = 0
	lagrima_active = false
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


func _handle_kill_infinite(npc: CrowdNPC) -> void:
	AudioManager.stop_heartbeat()

	if npc.is_sinner:
		infinite_kills += 1
		_update_infinite_ui()

		# Check rosario bonus
		_check_rosario_bonus()

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
		# Check if lagrima is active (no innocents this wave)
		if lagrima_active:
			# This shouldn't happen if lagrima works correctly, but just in case
			pass

		# Killed innocent - lose a life
		infinite_lives -= 1
		_update_infinite_ui()
		AudioManager.play_kill_sound(true)

		if infinite_lives <= 0:
			_show_infinite_game_over()
		else:
			# Flash red on screen and show warning
			message_label.text = "Innocent killed! Lives remaining: %d" % infinite_lives
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
		message_label.text = "He escaped! Lives remaining: %d" % infinite_lives
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
	game_over_wave_label.text = "Wave reached: %d" % infinite_wave
	if GameMode.is_infinite_kill():
		game_over_kills_label.text = "Enemies eliminated: %d" % infinite_kills
	else:
		game_over_kills_label.text = "Sinners eliminated: %d" % infinite_kills

	# Show game over panel directly
	game_over_panel.show()

	AudioManager.play_gameover_music()


# ============== INFINITE KILL MODE ==============

func _start_infinite_kill_wave(wave: int) -> void:
	infinite_wave = wave
	_set_crowd_clickable(false)

	# Reset inventory every 10 waves
	var inventory_reset := false
	if wave > 1 and (wave - 1) % 10 == 0:
		_reset_inventory()
		inventory_reset = true
	else:
		_check_item_expiration()

	# Clear previous crowd and items
	crowd_spawner.clear()
	if item_spawner:
		item_spawner.clear()

	# Calculate difficulty for this wave
	# Start simple: 5 enemies, slow speed
	# Increase progressively
	var base_enemies := 5
	var enemies_per_wave := 2
	var enemy_count := base_enemies + (wave - 1) * enemies_per_wave
	enemy_count = mini(enemy_count, 60)  # Cap at 60 enemies

	# Speed increases every 5 waves
	var speed_tier := (wave - 1) / 5
	var base_speed_min := 40.0
	var base_speed_max := 80.0
	var speed_mult := 1.0 + speed_tier * 0.25  # +25% speed every 5 waves
	var wave_speed_min := base_speed_min * speed_mult
	var wave_speed_max := base_speed_max * speed_mult
	wave_speed_min = clampf(wave_speed_min, 40.0, 200.0)
	wave_speed_max = clampf(wave_speed_max, 80.0, 300.0)

	kill_wave_enemies = enemy_count
	kill_wave_killed = 0

	# Time increases slightly with more enemies
	kill_wave_time = 15.0 + enemy_count * 0.3
	kill_wave_time = clampf(kill_wave_time, 15.0, 45.0)

	# Update UI
	_update_infinite_ui()
	if inventory_reset:
		message_label.text = "Wave %d - Inventory reset!" % wave
	else:
		message_label.text = "Wave %d - Kill them all!" % wave

	# Reset timer
	time_left = kill_wave_time
	round_active = true

	await crowd_spawner.spawn_kill_wave(enemy_count, wave_speed_min, wave_speed_max)

	# Spawn floor items in kill mode too
	if item_spawner:
		item_spawner.spawn_items_for_wave(wave)
		item_spawner.set_items_clickable(true)

	state = GameState.PLAYING
	_set_crowd_clickable(true)
	_update_timer_ui()


func _handle_kill_infinite_kill(npc: CrowdNPC) -> void:
	AudioManager.stop_heartbeat()
	AudioManager.play_kill_sound(false)

	kill_wave_killed += 1
	infinite_kills += 1
	_update_infinite_ui()

	# Check rosario bonus
	_check_rosario_bonus()

	# Flash effect on killed enemy
	var tween := create_tween()
	tween.tween_property(npc, "modulate", Color.WHITE * 2.0, 0.08)
	tween.tween_callback(npc.queue_free)

	# Check if all enemies killed
	if kill_wave_killed >= kill_wave_enemies:
		_advance_infinite_kill_wave()


func _advance_infinite_kill_wave() -> void:
	round_active = false
	_set_crowd_clickable(false)
	if item_spawner:
		item_spawner.set_items_clickable(false)

	AudioManager.play_phase_complete()

	# Brief pause before next wave
	await get_tree().create_timer(0.5).timeout

	_start_infinite_kill_wave(infinite_wave + 1)


func _timeout_infinite_kill() -> void:
	# Time ran out - lose a life
	infinite_lives -= 1
	_update_infinite_ui()
	AudioManager.stop_heartbeat()

	if infinite_lives <= 0:
		_show_infinite_game_over()
	else:
		message_label.text = "Time's up! Lives remaining: %d" % infinite_lives
		_flash_screen_red()
		# Continue to next wave after a brief pause
		round_active = false
		_set_crowd_clickable(false)
		await get_tree().create_timer(1.0).timeout
		_start_infinite_kill_wave(infinite_wave + 1)


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

	message_label.text = "Phase %d - Find the target!" % phase
	score_label.text = "Targets eliminated: %d/5" % correct_kills

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


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()


func _toggle_pause() -> void:
	# Don't allow pause during cutscenes, dialogues, game over, victory, or bad ending
	if bad_ending_in_progress:
		return
	if state in [GameState.CUTSCENE, GameState.SINNER_DIALOGUE, GameState.GAMEOVER, GameState.VICTORY]:
		return
	if in_dialogue:
		return

	if is_paused:
		_resume_game()
	else:
		_pause_game()


func _pause_game() -> void:
	is_paused = true
	get_tree().paused = true
	if pause_panel:
		pause_panel.show()
	AudioManager.play_ui_click()


func _resume_game() -> void:
	is_paused = false
	get_tree().paused = false
	if pause_panel:
		pause_panel.hide()
	AudioManager.play_ui_click()


func _on_pause_menu_pressed() -> void:
	_resume_game()
	_return_to_menu()


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
			# In kill mode, timeout means lose a life
			if GameMode.is_infinite_kill():
				_timeout_infinite_kill()
			else:
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

	elif state == GameState.FINAL_PHASE:
		final_time_left -= delta
		if final_time_left <= 0.0:
			final_time_left = 0.0
			_update_timer_ui()
			_final_timeout()
			return

		_update_timer_ui()
		_apply_endgame_pressure()


func _begin_escape_phase() -> void:
	state = GameState.ESCAPE
	escape_left = escape_time

	message_label.text = "HE IS ESCAPING!"
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

	if GameMode.is_infinite_kill():
		if state == GameState.PLAYING:
			timer_label.text = "Wave %d | %d/%d | Time: %.1f" % [infinite_wave, kill_wave_killed, kill_wave_enemies, time_left]
		else:
			timer_label.text = ""
	elif GameMode.is_infinite_find():
		if state == GameState.ESCAPE:
			timer_label.text = "Wave %d | Escape: %.1f" % [infinite_wave, escape_left]
		elif state == GameState.PLAYING:
			timer_label.text = "Wave %d | Time: %.1f" % [infinite_wave, time_left]
		else:
			timer_label.text = ""
	else:
		if state == GameState.ESCAPE:
			timer_label.text = "Escape: %.1f" % escape_left
		elif state == GameState.NPC_DIALOGUE or state == GameState.PLAYING:
			timer_label.text = "Time: %.1f" % time_left
		elif state == GameState.FINAL_PHASE:
			timer_label.text = "FINAL: %.1f" % final_time_left
		else:
			timer_label.text = ""


func _apply_endgame_pressure() -> void:
	var current_time := time_left if state != GameState.FINAL_PHASE else final_time_left

	if current_time > 4.0:
		AudioManager.stop_heartbeat()
		return

	# Inicia heartbeat quando tempo esta baixo
	AudioManager.start_heartbeat()

	# Skip sinner effect during final phase (all are sinners)
	if state == GameState.FINAL_PHASE:
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

	# Also enable/disable background clicks
	if squares_container:
		squares_container.mouse_filter = filter


func _on_background_input(event: InputEvent) -> void:
	if bad_ending_in_progress:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if in_dialogue or is_paused:
			return
		if state == GameState.GAMEOVER or state == GameState.VICTORY or state == GameState.CUTSCENE:
			return

		# Move protagonist to click position
		if protagonist:
			protagonist.move_to(event.position)


func _position_npc_beside_protagonist(npc: CrowdNPC) -> void:
	if not protagonist or not npc:
		return

	var npc_size := npc.square_size
	var npc_center := npc.position + Vector2(npc_size / 2, npc_size / 2)
	var offset := 5.0  # Distance between protagonist and NPC

	# Calculate position for protagonist beside the NPC (same Y level)
	var prota_target: Vector2
	var viewport_size := get_viewport().get_visible_rect().size

	# Align Y so both are on the same horizontal line (bottom aligned)
	var target_y := npc.position.y + npc_size - protagonist.sprite_size

	# Put protagonist to the left of NPC by default
	prota_target = Vector2(npc.position.x - protagonist.sprite_size - offset, target_y)

	# If NPC is on the left side of screen, put protagonist on the right
	if npc_center.x < viewport_size.x / 2:
		prota_target.x = npc.position.x + npc_size + offset

	# Keep protagonist within bounds
	prota_target.x = clamp(prota_target.x, 0, viewport_size.x - protagonist.sprite_size)
	prota_target.y = clamp(prota_target.y, 120, viewport_size.y - protagonist.sprite_size)

	# Move protagonist to position beside NPC (with animation) and look at NPC when arrived
	protagonist.move_to_and_look_at(
		prota_target + Vector2(protagonist.sprite_size / 2, protagonist.sprite_size / 2),
		npc_center
	)

	# Make NPC look at protagonist's target position
	npc.look_at_position(prota_target + Vector2(protagonist.sprite_size / 2, protagonist.sprite_size / 2))


func _on_npc_selected(npc: CrowdNPC) -> void:
	if bad_ending_in_progress:
		return
	if in_dialogue:
		return
	if npc == null or not is_instance_valid(npc):
		return

	# Move protagonist to the NPC
	if protagonist:
		var target := npc.position + npc.size / 2
		protagonist.move_to(target)

	match state:
		GameState.NPC_DIALOGUE:
			_handle_npc_dialogue(npc)
		GameState.PLAYING, GameState.ESCAPE:
			if GameMode.is_infinite_kill():
				_handle_kill_infinite_kill(npc)
			elif GameMode.is_infinite_find():
				_handle_kill_infinite(npc)
			else:
				_handle_kill(npc)
		GameState.FINAL_PHASE:
			_handle_final_kill(npc)
		_:
			pass


const MAX_NPC_DIALOGUES_PER_PHASE := {
	2: 5,
	3: 5,
	4: 3,
	5: 3,
	6: 1,
}

func _handle_npc_dialogue(npc: CrowdNPC) -> void:
	# Allow killing sinner at any time (no NPC conversation requirement)
	if npc.is_sinner:
		state = GameState.PLAYING
		_handle_kill(npc)
		return

	var id := npc.get_instance_id()
	if talked_npcs.has(id):
		message_label.text = "You already talked to this person."
		return

	# Check if we've reached the max dialogues for this phase
	var max_dialogues: int = MAX_NPC_DIALOGUES_PER_PHASE.get(current_phase, 3)
	if npc_dialogue_index >= max_dialogues:
		message_label.text = "Find the sinner!"
		return

	talked_npcs[id] = true

	# Toca som de selecao de NPC
	AudioManager.play_npc_select()

	_set_crowd_clickable(false)
	npc_dialogue_index += 1

	current_dialogue_npc = npc
	npc.freeze()
	_position_npc_beside_protagonist(npc)

	# Set sprite info for visual novel
	GameMode.set_current_npc_sprite(npc.sinner_sprite_index, npc.is_sinner)

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
		current_dialogue_npc.unfreeze()
	current_dialogue_npc = null

	# Clear sprite info
	GameMode.clear_current_npc_sprite()

	if pending_item != "":
		Inventory.collect(pending_item)
		pending_item = ""

	_set_crowd_clickable(true)


func _handle_kill(npc: CrowdNPC) -> void:
	# Para o heartbeat ao eliminar
	AudioManager.stop_heartbeat()

	if npc.is_sinner:
		correct_kills += 1
		score_label.text = "Targets eliminated: %d/5" % correct_kills

		# Save sinner position before moving them (for dead body spawn)
		last_sinner_position = npc.position

		round_active = false
		_set_crowd_clickable(false)
		npc.freeze()
		_position_npc_beside_protagonist(npc)

		# Set sprite info for visual novel
		GameMode.set_current_npc_sprite(npc.sinner_sprite_index, true)

		# Flash no sinner (sound plays after dialogue in _advance_phase)
		var tween := create_tween()
		tween.tween_property(npc, "modulate", Color.WHITE * 2.0, 0.08)
		tween.tween_callback(_start_sinner_dialogue)
	else:
		# Innocent clicked - just show a message, don't game over
		message_label.text = "That's not the sinner..."


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
	# Play kill sound after sinner dialogue ends
	AudioManager.play_kill_sound(false)

	# Spawn dead body at sinner's original position (story mode only)
	_spawn_dead_body(last_sinner_position)

	# Check if we're completing phase 6 - start final phase
	if current_phase == 6:
		crowd_spawner.clear()
		_start_final_phase()
		return

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
	message_label.text = ""
	_set_crowd_clickable(false)
	_freeze_crowd()
	timer_label.text = ""

	# Clear the game area
	crowd_spawner.clear()
	_clear_dead_bodies()

	# Update game over panel for story mode
	game_over_wave_label.text = "Phase reached: %d" % current_phase
	game_over_kills_label.text = "Sinners eliminated: %d/5" % correct_kills

	# Show game over panel
	game_over_panel.show()

	# Audio: para heartbeat e toca musica de game over
	AudioManager.stop_heartbeat()
	AudioManager.play_gameover_music()


func _freeze_crowd() -> void:
	for npc in crowd_spawner.npcs:
		if is_instance_valid(npc):
			npc.set_process(false)


func _on_item_collected(item_name: String) -> void:
	# Track when item was collected (for infinite mode duration)
	if GameMode.is_infinite() and item_name in item_collected_wave:
		item_collected_wave[item_name] = infinite_wave

	_update_items_ui()

	# Som de coleta de item (especial para itens importantes)
	var is_special := item_name in ["monoculo", "relogio", "rosario"]
	AudioManager.play_item_collect(is_special)

	# Show tutorial if first time collecting this item
	if item_name in TUTORIAL_DESCRIPTIONS and not tutorial_shown.get(item_name, false):
		_show_tutorial(item_name)

	var duration_msg := " (lasts 3 waves)" if GameMode.is_infinite() else ""

	match item_name:
		"monoculo":
			message_label.text = "Monocle obtained! The target now pulses." + duration_msg
			crowd_spawner.apply_monoculo_to_sinner()
		"relogio":
			message_label.text = "Clock obtained! NPCs are slower." + duration_msg
			crowd_spawner.apply_relogio_effect()
		"calice":
			_apply_calice_effect()
		"lagrima":
			_apply_lagrima_effect()
		"rosario":
			message_label.text = "Corrupted Rosary obtained! Every 5 kills, gain 1 life." + duration_msg


func _show_tutorial(item_name: String) -> void:
	if not tutorial_panel or not TUTORIAL_IMAGES.has(item_name):
		return

	tutorial_shown[item_name] = true
	tutorial_active = true

	# Set image and description
	tutorial_item_image.texture = TUTORIAL_IMAGES[item_name]
	tutorial_description.text = TUTORIAL_DESCRIPTIONS[item_name]

	# Show panel and pause timer
	tutorial_panel.show()
	tutorial_ok_button.grab_focus()
	round_active = false  # Pause the timer


func _close_tutorial() -> void:
	if not tutorial_panel:
		return

	tutorial_active = false
	tutorial_panel.hide()

	# Resume timer if game is in playing state
	if state == GameState.PLAYING or state == GameState.FINAL_PHASE:
		round_active = true


func _update_items_ui() -> void:
	if items_label == null:
		return

	var items_text := ""

	if Inventory.has("monoculo"):
		var remaining := _get_item_remaining_waves("monoculo")
		if remaining > 0:
			items_text += "🔍 Monocle [%d waves]\n" % remaining
		else:
			items_text += "🔍 Monocle\n"

	if Inventory.has("relogio"):
		var remaining := _get_item_remaining_waves("relogio")
		if remaining > 0:
			items_text += "⏱️ Clock [%d waves]\n" % remaining
		else:
			items_text += "⏱️ Clock\n"

	if Inventory.has("rosario"):
		var remaining := _get_item_remaining_waves("rosario")
		if remaining > 0:
			items_text += "✝ Rosary [%d waves] %d/%d kills\n" % [remaining, rosario_kill_count, ROSARIO_KILLS_FOR_LIFE]
		else:
			items_text += "✝ Rosary %d/%d kills\n" % [rosario_kill_count, ROSARIO_KILLS_FOR_LIFE]

	if lagrima_active:
		items_text += "💧 Tear [next wave]\n"

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

	message_label.text = "You completed the Cleansing! Glory to the Occultus God!"
	timer_label.text = ""

	_set_crowd_clickable(false)
	_freeze_crowd()
	# Audio: toca musica de vitoria (ambigua, nao celebrativa)
	AudioManager.play_victory_music()


func _game_over(reason: String) -> void:
	round_active = false
	state = GameState.GAMEOVER
	in_dialogue = false

	message_label.text = reason + " (Click to restart)"
	_set_crowd_clickable(false)
	_freeze_crowd()
	# Audio: para heartbeat e toca musica de game over
	AudioManager.stop_heartbeat()
	AudioManager.play_gameover_music()


func _unhandled_input(event: InputEvent) -> void:
	if bad_ending_in_progress:
		return

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

	# Restore scenario elements visibility
	if scenario_casa1:
		scenario_casa1.show()
	if scenario_casa2:
		scenario_casa2.show()
	if scenario_casa3:
		scenario_casa3.show()
	if scenario_igreja:
		scenario_igreja.show()

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

	# Clear dead bodies from previous game
	_clear_dead_bodies()

	_update_items_ui()

	# Restart based on game mode
	if GameMode.is_infinite():
		_start_infinite_mode()
	else:
		_restart_game()


func _on_menu_button_pressed() -> void:
	AudioManager.play_ui_click()
	_return_to_menu()


func _restart_game() -> void:
	if bad_ending_in_progress:
		return

	for key in Inventory.items.keys():
		Inventory.items[key] = false

	talked_npcs.clear()
	pending_item = ""
	current_dialogue_npc = null
	in_dialogue = false

	crowd_spawner.speed_modifier = 1.0
	crowd_spawner.distractor_modifier = 1.0

	crowd_spawner.clear()
	_clear_dead_bodies()
	correct_kills = 0
	_update_items_ui()

	state = GameState.CUTSCENE
	_fade_to_phase(2)


# ============== FINAL PHASE ==============

func _start_final_phase() -> void:
	state = GameState.FINAL_PHASE
	round_active = false
	in_dialogue = true

	# Show dramatic message
	message_label.text = "Everyone turns against you!"

	# Play final phase music
	AudioManager.play_final_phase_music()

	# Fade to black then setup
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	tween.tween_callback(_setup_final_phase)
	tween.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func(): in_dialogue = false)


func _setup_final_phase() -> void:
	final_kills = 0
	final_total_enemies = FINAL_ENEMY_COUNT
	final_time_left = FINAL_TIME

	# Spawn enemies for final phase
	_spawn_final_enemies()

	score_label.text = "Enemies: %d/%d" % [final_kills, final_total_enemies]
	message_label.text = "ELIMINATE EVERYONE!"

	round_active = true
	_set_crowd_clickable(true)
	_update_timer_ui()


func _spawn_final_enemies() -> void:
	# Use crowd spawner to spawn all red enemies
	crowd_spawner.spawn_final_phase(FINAL_ENEMY_COUNT)


func _handle_final_kill(npc: CrowdNPC) -> void:
	AudioManager.stop_heartbeat()
	AudioManager.play_kill_sound(false)

	final_kills += 1
	score_label.text = "Enemies: %d/%d" % [final_kills, final_total_enemies]

	# Spawn dead body at NPC position (story mode only - final phase is part of story)
	_spawn_dead_body(npc.position)

	# Flash effect on killed enemy
	var tween := create_tween()
	tween.tween_property(npc, "modulate", Color.WHITE * 2.0, 0.08)
	tween.tween_callback(npc.queue_free)

	# Check if all enemies killed
	if final_kills >= final_total_enemies:
		_final_victory()


func _spawn_dead_body(pos: Vector2) -> void:
	# Only spawn in story mode (not infinite)
	if GameMode.is_infinite():
		return

	var body := TextureRect.new()
	body.texture = DEAD_BODY_TEXTURE
	body.position = pos
	body.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	body.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	body.size = Vector2(60, 40)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.z_index = -1  # Behind NPCs but above ground

	if squares_container:
		squares_container.add_child(body)


func _clear_dead_bodies() -> void:
	if not squares_container:
		return

	# Remove all dead body sprites (TextureRect with DEAD_BODY_TEXTURE)
	for child in squares_container.get_children():
		if child is TextureRect and child.texture == DEAD_BODY_TEXTURE:
			child.queue_free()


func _final_timeout() -> void:
	round_active = false
	state = GameState.GAMEOVER
	bad_ending_in_progress = true  # Lock all input during bad ending sequence
	_set_crowd_clickable(false)
	_freeze_crowd()

	# Move protagonist to center of screen
	if protagonist:
		protagonist.show()
		var viewport_size := get_viewport().get_visible_rect().size
		var center := viewport_size / 2
		protagonist.move_to(center)

	# Wait for protagonist to reach center, then start dialogue
	await get_tree().create_timer(1.5).timeout

	# Play first part of bad ending dialogue
	in_dialogue = true
	var balloon = BALLOON_SCENE.instantiate()
	get_tree().current_scene.add_child(balloon)

	DialogueManager.dialogue_ended.connect(_on_bad_ending_part1_ended, CONNECT_ONE_SHOT)
	balloon.start(FINAL_DIALOGUE, "ending_bad_1", [], false)


var npc_circle_targets: Dictionary = {}  # NPC instance ID -> target position on circle

func _on_bad_ending_part1_ended(_resource) -> void:
	in_dialogue = false

	var viewport_size := get_viewport().get_visible_rect().size
	var center := viewport_size / 2
	var circle_radius := 35.0  # Diameter of 70 pixels

	# Count valid NPCs
	var valid_npcs: Array[CrowdNPC] = []
	for npc in crowd_spawner.npcs:
		if is_instance_valid(npc):
			valid_npcs.append(npc)

	var npc_count := valid_npcs.size()
	if npc_count == 0:
		_trigger_bad_ending_fade()
		return

	# Assign each NPC a position on the circle
	npc_circle_targets.clear()
	for i in range(npc_count):
		var npc := valid_npcs[i]
		var angle := (TAU / npc_count) * i  # Evenly distribute around circle
		var target_pos := center + Vector2(cos(angle), sin(angle)) * circle_radius
		# Adjust for NPC size (target is for NPC center)
		target_pos -= Vector2(npc.square_size / 2, npc.square_size / 2)
		npc_circle_targets[npc.get_instance_id()] = target_pos

		# Unfreeze and set up movement
		npc.set_process(true)
		npc.is_frozen = false
		npc.escaping = true
		npc.allow_bounce = false

		# Calculate direction to target position
		var direction := (target_pos - npc.position).normalized()
		npc.escape_dir = direction
		npc.escape_speed = 80.0  # Slow, menacing speed
		npc._update_sprite_direction()

	# Start tracking NPC progress for fade
	_start_crowd_approach_tracking()


func _start_crowd_approach_tracking() -> void:
	var arrival_threshold := 5.0  # How close counts as "arrived"

	# Wait and check progress
	var fade_triggered := false
	while not fade_triggered:
		await get_tree().create_timer(0.1).timeout

		var arrived_count := 0
		var total_count := 0

		for npc in crowd_spawner.npcs:
			if is_instance_valid(npc):
				var npc_id := npc.get_instance_id()
				if npc_circle_targets.has(npc_id):
					total_count += 1
					var target_pos: Vector2 = npc_circle_targets[npc_id]
					var distance := npc.position.distance_to(target_pos)

					if distance <= arrival_threshold:
						# NPC has arrived, stop it
						npc.escape_speed = 0.0
						npc.set_process(false)
						arrived_count += 1
					else:
						# Update direction in case NPC overshot
						var direction := (target_pos - npc.position).normalized()
						npc.escape_dir = direction

		if total_count > 0:
			var arrival_percentage := float(arrived_count) / float(total_count)
			# When 75% have arrived at their positions, trigger fade
			if arrival_percentage >= 0.75:
				fade_triggered = true
				_trigger_bad_ending_fade()


func _trigger_bad_ending_fade() -> void:
	# Stop all NPCs
	for npc in crowd_spawner.npcs:
		if is_instance_valid(npc):
			npc.set_process(false)

	# Stop the music
	AudioManager.stop_bgm(false)

	# Fade to black
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 1.0)
	tween.tween_callback(_play_bad_ending_sounds)


func _play_bad_ending_sounds() -> void:
	# Clear all NPCs while sounds play
	crowd_spawner.clear()

	# Hide protagonist
	if protagonist:
		protagonist.hide()

	# Play sounds one after another with 1 second interval
	var sounds := [
		"res://audio/piercing-1a.wav",
		"res://audio/sword-1a.wav",
		"res://audio/sword-1b.wav"
	]

	for i in range(sounds.size()):
		await get_tree().create_timer(1.0).timeout
		AudioManager.play_sound_from_path(sounds[i])

	# Wait for last sound to finish before showing dialogue
	await get_tree().create_timer(1.5).timeout

	# Now show the second part of dialogue
	_show_bad_ending_part2()


func _show_bad_ending_part2() -> void:
	# Show bad ending background image
	if bad_ending_bg:
		bad_ending_bg.show()

	# Play second part of bad ending dialogue
	in_dialogue = true
	var balloon = BALLOON_SCENE.instantiate()
	get_tree().current_scene.add_child(balloon)

	DialogueManager.dialogue_ended.connect(_on_bad_ending_ended, CONNECT_ONE_SHOT)
	balloon.start(FINAL_DIALOGUE, "ending_bad_2", [], false)


func _on_bad_ending_ended(_resource) -> void:
	in_dialogue = false
	bad_ending_in_progress = false

	# Hide bad ending background
	if bad_ending_bg:
		bad_ending_bg.hide()

	# Fade to black before showing credits
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 1.5)
	tween.tween_interval(1.0)
	tween.tween_callback(_go_to_credits)


func _final_victory() -> void:
	round_active = false
	state = GameState.VICTORY
	_set_crowd_clickable(false)

	# Clear remaining enemies
	crowd_spawner.clear()

	# Play good ending dialogue
	in_dialogue = true
	var balloon = BALLOON_SCENE.instantiate()
	get_tree().current_scene.add_child(balloon)

	DialogueManager.dialogue_ended.connect(_on_good_ending_ended, CONNECT_ONE_SHOT)
	balloon.start(FINAL_DIALOGUE, "ending_good", [], false)


func _on_good_ending_ended(_resource) -> void:
	in_dialogue = false
	# Fade to black and stay there
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 2.0)
	# After some time, show credits
	tween.tween_interval(3.0)
	tween.tween_callback(_go_to_credits)


func _go_to_credits() -> void:
	GameMode.request_credits()
	_return_to_menu()


# ============== NEW ITEM EFFECTS ==============

func _apply_calice_effect() -> void:
	# Blood Chalice: recover 1 life
	if infinite_lives < INFINITE_MAX_LIVES:
		infinite_lives += 1
		_update_infinite_ui()
		message_label.text = "Blood Chalice! +1 life"
		_flash_screen_green()
	else:
		message_label.text = "Blood Chalice! (lives full)"


func _apply_lagrima_effect() -> void:
	# Priestess Tear: next wave has no innocents
	lagrima_active = true
	message_label.text = "Priestess Tear! Next wave has no innocents."
	_flash_screen_blue()
	_update_items_ui()


func _check_rosario_bonus() -> void:
	if not Inventory.has("rosario"):
		return

	rosario_kill_count += 1
	if rosario_kill_count >= ROSARIO_KILLS_FOR_LIFE:
		rosario_kill_count = 0
		if infinite_lives < INFINITE_MAX_LIVES:
			infinite_lives += 1
			_update_infinite_ui()
			message_label.text = "Corrupted Rosary! +1 life"
			_flash_screen_green()

	_update_items_ui()


func _flash_screen_green() -> void:
	var original_color := fade_rect.color
	fade_rect.color = Color(0.0, 0.8, 0.2, 1.0)
	fade_rect.modulate.a = 0.4

	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): fade_rect.color = original_color)


func _flash_screen_blue() -> void:
	var original_color := fade_rect.color
	fade_rect.color = Color(0.2, 0.4, 0.9, 1.0)
	fade_rect.modulate.a = 0.4

	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): fade_rect.color = original_color)
