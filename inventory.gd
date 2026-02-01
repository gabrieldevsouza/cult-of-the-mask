extends Node

var items := {
	"monoculo": false,
	"relogio": false,
	"rosario": false,
}

signal item_collected(item_name: String)

func collect(item_name: String) -> void:
	if item_name in items and not items[item_name]:
		items[item_name] = true
		item_collected.emit(item_name)

func has(item_name: String) -> bool:
	return items.get(item_name, false)
