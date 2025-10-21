extends Node

var dialogue_is_running := false:
	get:
		return dialogue_is_running
	set(value):
		if not value:
			await get_tree().create_timer(0.25).timeout
		dialogue_is_running = value
