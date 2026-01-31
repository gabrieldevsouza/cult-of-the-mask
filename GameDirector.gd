extends Node2D
class_name GameDirector

@export var round_time := 15.0

var time_left := 0.0
var round_active := false

@onready var timer_label: Label = $UI/TimerLabel
@onready var score_label: Label = $UI/ScoreLabel
@onready var message_label: Label = $UI/MessageLabel
@onready var fade_rect: ColorRect = $FadeLayer/FadeRect
@onready var crowd_spawner: CrowdSpawner = $CrowdSpawner

const DIALOGUE_RESOURCE = preload("res://dialogues/test_dialogue.dialogue")
const BALLOON_SCENE = preload("res://ui/visual_novel_balloon.tscn")

enum GameState { CUTSCENE, PLAYING, GAMEOVER }
var state: GameState = GameState.CUTSCENE

var correct_kills := 0

func _ready() -> void:
	randomize()
	state = GameState.CUTSCENE
	round_active = false
	crowd_spawner.npc_selected.connect(_on_npc_selected)
	_play_fade_in()

func _play_fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 1.5)
	tween.tween_callback(_start_dialogue)

func _start_dialogue() -> void:
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	var balloon = BALLOON_SCENE.instantiate()
	get_tree().current_scene.add_child(balloon)
	balloon.start(DIALOGUE_RESOURCE, "start")

func _on_dialogue_ended(_resource) -> void:
	if state != GameState.CUTSCENE:
		return

	# Disconnect so it doesn't fire again (important on restarts)
	if DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)

	state = GameState.PLAYING
	_start_round()

func _start_round() -> void:
	if state != GameState.PLAYING:
		return

	message_label.text = "Elimine o pecador antes que ele escape."
	score_label.text = "Acertos: %d" % correct_kills

	time_left = round_time
	round_active = true
	_update_timer_ui()

	# Spawn crowd and only then enable input (because now NPCs exist)
	await crowd_spawner.spawn_crowd()

	_set_crowd_clickable(true)

func _process(delta: float) -> void:
	if state != GameState.PLAYING or not round_active:
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
	timer_label.text = "Tempo: %.1f" % time_left

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
	# Hard gate: no clicks outside gameplay
	if state != GameState.PLAYING or not round_active:
		return

	_handle_kill(npc)

func _handle_kill(npc: CrowdNPC) -> void:
	if npc.is_sinner:
		correct_kills += 1
		score_label.text = "Acertos: %d" % correct_kills
		message_label.text = "Boa. Rápido — antes que ele escape!"

		round_active = false
		_set_crowd_clickable(false)

		var tween := create_tween()
		tween.tween_property(npc, "modulate", Color.WHITE * 2.0, 0.08)
		tween.tween_callback(_start_round)
	else:
		_game_over("Você matou um inocente. Você perdeu.")

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
	crowd_spawner.clear()
	state = GameState.PLAYING
	_start_round()
