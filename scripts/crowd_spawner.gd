extends Node
class_name CrowdSpawner

signal npc_selected(npc: CrowdNPC)
signal sinner_escaped()

@export var square_size := 64.0
@export var num_distractors := 30
@export var speed_min := 50.0
@export var speed_max := 150.0
@export var ui_top_margin := 120.0
@export var debug_show_sinner := true
@export var debug_tint_sinner := false

@export var container_path: NodePath
@onready var container: Control = get_node_or_null(container_path)

var npcs: Array[CrowdNPC] = []
var current_phase := 2

const PHASE_CONFIG := {
	2: { "distractors": 30, "speed_min": 80.0, "speed_max": 180.0 },
	3: { "distractors": 22, "speed_min": 60.0, "speed_max": 140.0 },
	4: { "distractors": 15, "speed_min": 50.0, "speed_max": 120.0 },
	5: { "distractors": 8,  "speed_min": 40.0, "speed_max": 100.0 },
	6: { "distractors": 0,  "speed_min": 0.0,  "speed_max": 0.0 },
}

var speed_modifier := 1.0
var distractor_modifier := 1.0

# Infinite mode constants
const INFINITE_BASE_DISTRACTORS := 15
const INFINITE_BASE_SPEED_MIN := 60.0
const INFINITE_BASE_SPEED_MAX := 140.0


func set_phase(phase: int) -> void:
	current_phase = phase
	if PHASE_CONFIG.has(phase):
		var config = PHASE_CONFIG[phase]
		num_distractors = int(config["distractors"] * distractor_modifier)
		speed_min = float(config["speed_min"]) * speed_modifier
		speed_max = float(config["speed_max"]) * speed_modifier


func apply_relogio_effect() -> void:
	speed_modifier = 0.7
	for npc in npcs:
		if is_instance_valid(npc):
			npc.set_speed_magnitude(npc.velocity.length() * 0.7)


func apply_visao_effect() -> void:
	distractor_modifier = 0.5


func set_infinite_wave(wave: int) -> void:
	# Tier aumenta a cada 5 ondas
	var tier := (wave - 1) / 5  # 0, 1, 2, 3...

	# Alternancia: tiers impares aumentam distractors, tiers pares aumentam velocidade
	# tier 0: base
	# tier 1 (ondas 6-10): +1 nivel de distractors
	# tier 2 (ondas 11-15): +1 nivel de velocidade
	# tier 3 (ondas 16-20): +2 niveis de distractors
	# tier 4 (ondas 21-25): +2 niveis de velocidade
	var distractor_level := (tier + 1) / 2  # 0, 1, 1, 2, 2, 3, 3...
	var speed_level := tier / 2              # 0, 0, 1, 1, 2, 2, 3...

	# Distractors: +10 por nivel
	num_distractors = int((INFINITE_BASE_DISTRACTORS + distractor_level * 10) * distractor_modifier)
	num_distractors = clampi(num_distractors, 5, 80)

	# Speed: juros simples (+15% por nivel)
	var speed_mult := 1.0 + speed_level * 0.15
	speed_min = INFINITE_BASE_SPEED_MIN * speed_mult * speed_modifier
	speed_max = INFINITE_BASE_SPEED_MAX * speed_mult * speed_modifier
	speed_min = clampf(speed_min, 40.0, 300.0)
	speed_max = clampf(speed_max, 100.0, 450.0)


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

		npc.setup(is_sinner, debug_show_sinner, debug_tint_sinner, vel, square_size, ui_top_margin)
		npc.selected.connect(_on_npc_selected)
		npc.escaped.connect(_on_npc_escaped)

		container.add_child(npc)
		npcs.append(npc)

		npc.mouse_filter = Control.MOUSE_FILTER_IGNORE


func get_sinner() -> CrowdNPC:
	for npc in npcs:
		if npc.is_sinner:
			return npc
	return null


func apply_monoculo_to_sinner() -> void:
	var sinner := get_sinner()
	if sinner and is_instance_valid(sinner):
		sinner.apply_monoculo_effect()


# ✅ New: timed escape
func begin_escape_phase(duration: float, crowd_uniform_speed: float) -> void:
	# Everyone gets the same speed magnitude
	for npc in npcs:
		if not is_instance_valid(npc):
			continue
		npc.set_speed_magnitude(crowd_uniform_speed)

	# Sinner: move to a target outside screen in exactly duration
	var sinner := get_sinner()
	if sinner and is_instance_valid(sinner):
		var target := _compute_escape_target(sinner)
		sinner.start_timed_escape_to(target, duration)


func _compute_escape_target(sinner: CrowdNPC) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size

	# Use sinner's center for edge choice
	var center := sinner.position + Vector2(square_size * 0.5, square_size * 0.5)

	var dist_left := center.x
	var dist_right := viewport_size.x - center.x
	var dist_top := center.y
	var dist_bottom := viewport_size.y - center.y

	var best := dist_left
	var dir := Vector2.LEFT

	if dist_right < best:
		best = dist_right
		dir = Vector2.RIGHT
	if dist_top < best:
		best = dist_top
		dir = Vector2.UP
	if dist_bottom < best:
		best = dist_bottom
		dir = Vector2.DOWN

	# Pick a target outside the screen along that edge
	var margin_out := 80.0  # ensure fully outside
	var target := sinner.position

	if dir == Vector2.LEFT:
		target.x = -margin_out - square_size
		target.y = clamp(sinner.position.y, ui_top_margin, viewport_size.y - square_size)
	elif dir == Vector2.RIGHT:
		target.x = viewport_size.x + margin_out
		target.y = clamp(sinner.position.y, ui_top_margin, viewport_size.y - square_size)
	elif dir == Vector2.UP:
		target.y = -margin_out - square_size
		target.x = clamp(sinner.position.x, 0.0, viewport_size.x - square_size)
	else: # DOWN
		target.y = viewport_size.y + margin_out
		target.x = clamp(sinner.position.x, 0.0, viewport_size.x - square_size)

	return target


func _on_npc_selected(npc: CrowdNPC) -> void:
	npc_selected.emit(npc)


func _on_npc_escaped(npc: CrowdNPC) -> void:
	if npc and is_instance_valid(npc) and npc.is_sinner:
		# Stop updates so it doesn't re-emit
		npc.set_process(false)
		sinner_escaped.emit()


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
