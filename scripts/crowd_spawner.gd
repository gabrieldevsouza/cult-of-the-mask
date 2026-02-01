extends Node
class_name CrowdSpawner

signal npc_selected(npc: CrowdNPC)
signal sinner_escaped()

@export var square_size := 65.0
@export var num_distractors := 30
@export var speed_min := 50.0
@export var speed_max := 150.0
@export var ui_top_margin := 120.0
@export var debug_show_sinner := true

@export var container_path: NodePath
@onready var container: Control = get_node_or_null(container_path)

var npcs: Array[CrowdNPC] = []
var current_phase := 2

# Walkable areas from collision masks
var walkable_areas: Array[Rect2] = []

# Phase config: distractors = folks count, sinner is always +1
# Base speed: 60-120, multiplied by speed_mult
const PHASE_CONFIG := {
	2: { "distractors": 15, "speed_min": 60.0,  "speed_max": 120.0 },   # 15 folks + 1 sinner
	3: { "distractors": 21, "speed_min": 60.0,  "speed_max": 120.0 },   # 21 folks + 1 sinner
	4: { "distractors": 17, "speed_min": 120.0, "speed_max": 240.0 },   # 17 folks + 1 sinner, x2 speed
	5: { "distractors": 35, "speed_min": 90.0,  "speed_max": 180.0 },   # 35 folks + 1 sinner, x1.5 speed
	6: { "distractors": 22, "speed_min": 180.0, "speed_max": 360.0 },   # 22 folks + 1 sinner, x3 speed
}

var speed_modifier := 1.0
var distractor_modifier := 1.0


func _ready() -> void:
	# Collect walkable areas from collision masks
	_collect_walkable_areas()


func _collect_walkable_areas() -> void:
	walkable_areas.clear()
	var main_node := get_tree().current_scene
	if main_node == null:
		return

	# Find all nodes that start with "MASCARA DE COLISAO"
	for child in main_node.get_children():
		if child is ColorRect and child.name.begins_with("MASCARA DE COLISAO"):
			var rect := _get_control_rect(child)
			if rect.size.x > 0 and rect.size.y > 0:
				walkable_areas.append(rect)
			# Also check children
			_collect_mask_children(child)


func _collect_mask_children(parent: Node) -> void:
	for child in parent.get_children():
		if child is ColorRect and child.name.begins_with("MASCARA DE COLISAO"):
			var rect := _get_control_rect(child)
			if rect.size.x > 0 and rect.size.y > 0:
				walkable_areas.append(rect)
			_collect_mask_children(child)


func _get_control_rect(ctrl: ColorRect) -> Rect2:
	# Get the global rect of the control
	var rect := ctrl.get_global_rect()
	return rect


func is_point_in_walkable_area(point: Vector2) -> bool:
	for area in walkable_areas:
		if area.has_point(point):
			return true
	return false


func is_rect_in_walkable_area(rect: Rect2) -> bool:
	# Check if all corners of the rect are in a walkable area
	var corners := [
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + Vector2(0, rect.size.y),
		rect.position + rect.size
	]
	for corner in corners:
		if not is_point_in_walkable_area(corner):
			return false
	return true


func get_walkable_areas() -> Array[Rect2]:
	return walkable_areas


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

		npc.setup(is_sinner, debug_show_sinner, vel, square_size, ui_top_margin)
		npc.set_walkable_areas(walkable_areas)
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
	var max_attempts := 200
	var min_distance := square_size * 1.5

	# If we have walkable areas, use them
	if walkable_areas.size() > 0:
		for _attempt in range(max_attempts):
			# Pick a random walkable area
			var area := walkable_areas[randi() % walkable_areas.size()]
			var x := randf_range(area.position.x + margin * 0.2, area.end.x - square_size - margin * 0.2)
			var y := randf_range(area.position.y + margin * 0.2, area.end.y - square_size - margin * 0.2)
			var pos := Vector2(x, y)

			# Check if position is valid (in any walkable area)
			var npc_rect := Rect2(pos, Vector2(square_size, square_size))
			if not is_point_in_walkable_area(pos + Vector2(square_size / 2, square_size / 2)):
				continue

			var ok := true
			for used in used_positions:
				if pos.distance_to(used) < min_distance:
					ok = false
					break

			if ok:
				return pos

		# Fallback: return center of first walkable area
		if walkable_areas.size() > 0:
			var area := walkable_areas[0]
			return area.position + area.size / 2 - Vector2(square_size / 2, square_size / 2)

	# Fallback to original behavior
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


func spawn_final_phase(enemy_count: int) -> void:
	spawn_kill_wave(enemy_count, 100.0, 200.0)


func spawn_kill_wave(enemy_count: int, p_speed_min: float, p_speed_max: float) -> void:
	if container == null:
		push_error("CrowdSpawner: container_path not set.")
		return

	clear()
	await get_tree().process_frame

	var viewport_size := get_viewport().get_visible_rect().size
	var margin := 60.0
	var used_positions: Array[Vector2] = []

	for i in range(enemy_count):
		var npc := CrowdNPC.new()
		npc.size = Vector2(square_size, square_size)

		var pos := _get_random_position_final(viewport_size, margin, used_positions, square_size)
		used_positions.append(pos)
		npc.position = pos

		# All enemies move and are red (sinners)
		var speed := randf_range(p_speed_min, p_speed_max)
		var angle := randf_range(0.0, TAU)
		var vel := Vector2(cos(angle), sin(angle)) * speed
		npc.setup(true, true, vel, square_size, ui_top_margin)
		npc.set_walkable_areas(walkable_areas)
		npc.selected.connect(_on_npc_selected)

		container.add_child(npc)
		npcs.append(npc)

		npc.mouse_filter = Control.MOUSE_FILTER_STOP


func _get_random_position_final(viewport_size: Vector2, margin: float, used_positions: Array[Vector2], sq_size: float) -> Vector2:
	var max_attempts := 100
	var min_distance := sq_size * 1.2

	# If we have walkable areas, use them
	if walkable_areas.size() > 0:
		for _attempt in range(max_attempts):
			var area := walkable_areas[randi() % walkable_areas.size()]
			var x := randf_range(area.position.x + margin * 0.2, area.end.x - sq_size - margin * 0.2)
			var y := randf_range(area.position.y + margin * 0.2, area.end.y - sq_size - margin * 0.2)
			var pos := Vector2(x, y)

			if not is_point_in_walkable_area(pos + Vector2(sq_size / 2, sq_size / 2)):
				continue

			var ok := true
			for used in used_positions:
				if pos.distance_to(used) < min_distance:
					ok = false
					break

			if ok:
				return pos

		if walkable_areas.size() > 0:
			var area := walkable_areas[0]
			return area.position + area.size / 2 - Vector2(sq_size / 2, sq_size / 2)

	for _attempt in range(max_attempts):
		var x := randf_range(margin, viewport_size.x - margin - sq_size)
		var y := randf_range(ui_top_margin + margin * 0.3, viewport_size.y - margin - sq_size)
		var pos := Vector2(x, y)

		var ok := true
		for used in used_positions:
			if pos.distance_to(used) < min_distance:
				ok = false
				break

		if ok:
			return pos

	return Vector2(
		randf_range(margin, viewport_size.x - margin - sq_size),
		randf_range(ui_top_margin + margin * 0.3, viewport_size.y - margin - sq_size)
	)
