extends Node

enum Mode { STORY, INFINITE }
var current_mode: Mode = Mode.STORY

func set_infinite_mode() -> void:
	current_mode = Mode.INFINITE

func set_story_mode() -> void:
	current_mode = Mode.STORY

func is_infinite() -> bool:
	return current_mode == Mode.INFINITE

func is_story() -> bool:
	return current_mode == Mode.STORY
