extends Node
class_name ItemSpawner

signal item_collected(item_name: String)

const COLLECTIBLE_SCENE = preload("res://scripts/collectible_item.tscn")

# Persistent items (stay in inventory until expire/reset)
const PERSISTENT_ITEMS := ["monoculo", "relogio", "visao_fase4", "rosario"]
# Instant items (immediate effect, can spawn again)
const INSTANT_ITEMS := ["calice", "lagrima"]
# All items combined
const AVAILABLE_ITEMS := ["monoculo", "relogio", "visao_fase4", "calice", "lagrima", "rosario"]

@export var container_path: NodePath
@export var base_spawn_chance := 0.30
@export var max_items_per_wave := 2
@export var ui_top_margin := 120.0

@onready var container: Control = get_node_or_null(container_path)

var spawned_items: Array[CollectibleItem] = []


func spawn_items_for_wave(wave: int) -> void:
	if container == null:
		push_error("ItemSpawner: container_path not set.")
		return

	clear()

	# Itens disponiveis para spawn
	var spawnable_items: Array[String] = []

	# Persistent items: only spawn if player doesn't have them
	for item in PERSISTENT_ITEMS:
		if not Inventory.has(item):
			spawnable_items.append(item)

	# Instant items: always available to spawn
	for item in INSTANT_ITEMS:
		spawnable_items.append(item)

	if spawnable_items.is_empty():
		return

	# Chance aumenta levemente a cada onda
	var spawn_chance := base_spawn_chance + (wave - 1) * 0.02
	spawn_chance = clampf(spawn_chance, 0.0, 0.8)

	var items_spawned := 0
	var viewport_size := get_viewport().get_visible_rect().size

	# Shuffle to randomize which items spawn
	spawnable_items.shuffle()

	for item_name in spawnable_items:
		if items_spawned >= max_items_per_wave:
			break

		if randf() > spawn_chance:
			continue

		var item := _create_collectible(item_name)
		var pos := _get_random_position(viewport_size)
		item.position = pos

		container.add_child(item)
		spawned_items.append(item)
		items_spawned += 1


func _create_collectible(item_name: String) -> CollectibleItem:
	var item := COLLECTIBLE_SCENE.instantiate() as CollectibleItem
	item.setup(item_name)
	item.collected.connect(_on_item_collected)
	return item


func _on_item_collected(item_name: String) -> void:
	Inventory.collect(item_name)
	item_collected.emit(item_name)


func _get_random_position(viewport_size: Vector2) -> Vector2:
	var margin := 60.0
	var item_size := 40.0

	var x := randf_range(margin, viewport_size.x - margin - item_size)
	var y := randf_range(ui_top_margin + margin, viewport_size.y - margin - item_size)

	return Vector2(x, y)


func clear() -> void:
	for item in spawned_items:
		if is_instance_valid(item):
			item.queue_free()
	spawned_items.clear()


func set_items_clickable(enabled: bool) -> void:
	var filter := Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for item in spawned_items:
		if is_instance_valid(item):
			item.mouse_filter = filter
