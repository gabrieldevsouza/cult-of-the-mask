extends Node
class_name CrowdSpawner

signal npc_selected(npc: CrowdNPC)

@export var square_size := 50.0
@export var num_distractors := 30
@export var speed_min := 50.0
@export var speed_max := 150.0
@export var ui_top_margin := 120.0
@export var debug_show_sinner := true

@export var container_path: NodePath
@onready var container: Control = get_node_or_null(container_path)

var npcs: Array[CrowdNPC] = []
var current_phase := 2

# Configurações por fase
const PHASE_CONFIG := {
	2: { "distractors": 30, "speed_min": 80.0, "speed_max": 180.0 },
	3: { "distractors": 22, "speed_min": 60.0, "speed_max": 140.0 },
	4: { "distractors": 15, "speed_min": 50.0, "speed_max": 120.0 },
	5: { "distractors": 8, "speed_min": 40.0, "speed_max": 100.0 },
	6: { "distractors": 0, "speed_min": 0.0, "speed_max": 0.0 },
}

# Modificadores de efeitos de itens
var speed_modifier := 1.0  # Relógio reduz para 0.7
var distractor_modifier := 1.0  # Visão reduz para 0.5

func set_phase(phase: int) -> void:
	current_phase = phase
	if PHASE_CONFIG.has(phase):
		var config = PHASE_CONFIG[phase]
		num_distractors = int(config["distractors"] * distractor_modifier)
		speed_min = config["speed_min"] * speed_modifier
		speed_max = config["speed_max"] * speed_modifier

func apply_relogio_effect() -> void:
	speed_modifier = 0.7
	# Aplica aos NPCs existentes
	for npc in npcs:
		if is_instance_valid(npc):
			npc.velocity *= 0.7

func apply_visao_effect() -> void:
	distractor_modifier = 0.5

func clear() -> void:
	for npc in npcs:
		if is_instance_valid(npc):
			npc.queue_free()
	npcs.clear()

func spawn_crowd() -> void:
	if container == null:
		push_error("CrowdSpawner: container_path not set.")
		return

	clear()
	await get_tree().process_frame

	var viewport_size := get_viewport().get_visible_rect().size
	var margin := 100.0
	var used_positions: Array[Vector2] = []
	var sinner_index := randi() % (num_distractors + 1)

	for i in range(num_distractors + 1):
		var is_sinner := (i == sinner_index)
		var npc := CrowdNPC.new()
		npc.size = Vector2(square_size, square_size)

		var pos := _get_random_position(viewport_size, margin, used_positions)
		used_positions.append(pos)
		npc.position = pos

		var vel := _get_random_velocity()
		if is_sinner:
			vel *= 1.15

		npc.setup(is_sinner, debug_show_sinner, vel, square_size, ui_top_margin)
		npc.selected.connect(_on_npc_selected)

		container.add_child(npc)
		npcs.append(npc)

		# Disabled by default, enabled by GameDirector
		npc.mouse_filter = Control.MOUSE_FILTER_IGNORE

func get_sinner() -> CrowdNPC:
	for npc in npcs:
		if npc.is_sinner:
			return npc
	return null

func apply_monoculo_to_sinner() -> void:
	var sinner = get_sinner()
	if sinner:
		sinner.apply_monoculo_effect()

func _on_npc_selected(npc: CrowdNPC) -> void:
	npc_selected.emit(npc)

func _get_random_velocity() -> Vector2:
	var speed := randf_range(speed_min, speed_max)
	var angle := randf_range(0.0, TAU)
	return Vector2(cos(angle), sin(angle)) * speed

func _get_random_position(viewport_size: Vector2, margin: float, used_positions: Array[Vector2]) -> Vector2:
	var max_attempts := 100
	var min_distance := square_size * 1.5

	for _attempt in range(max_attempts):
		var x := randf_range(margin, viewport_size.x - margin - square_size)
		var y := randf_range(ui_top_margin + margin * 0.5, viewport_size.y - margin - square_size)
		var pos := Vector2(x, y)

		var ok := true
		for used in used_positions:
			if pos.distance_to(used) < min_distance:
				ok = false
				break

		if ok:
			return pos

	return Vector2(
		randf_range(margin, viewport_size.x - margin - square_size),
		randf_range(ui_top_margin + margin * 0.5, viewport_size.y - margin - square_size)
	)
