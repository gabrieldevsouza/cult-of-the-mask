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
