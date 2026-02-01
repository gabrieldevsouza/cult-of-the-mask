extends Node

enum Mode { STORY, INFINITE_FIND, INFINITE_KILL }
var current_mode: Mode = Mode.STORY
var show_credits_on_menu := false

func set_infinite_find_mode() -> void:
	current_mode = Mode.INFINITE_FIND

func set_infinite_kill_mode() -> void:
	current_mode = Mode.INFINITE_KILL

func set_story_mode() -> void:
	current_mode = Mode.STORY

func is_infinite() -> bool:
	return current_mode == Mode.INFINITE_FIND or current_mode == Mode.INFINITE_KILL

func is_infinite_find() -> bool:
	return current_mode == Mode.INFINITE_FIND

func is_infinite_kill() -> bool:
	return current_mode == Mode.INFINITE_KILL

func is_story() -> bool:
	return current_mode == Mode.STORY

func request_credits() -> void:
	show_credits_on_menu = true

func should_show_credits() -> bool:
	var result := show_credits_on_menu
	show_credits_on_menu = false  # Reset after checking
	return result
