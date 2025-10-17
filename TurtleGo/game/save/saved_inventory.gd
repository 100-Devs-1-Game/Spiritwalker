class_name SavedInventory
extends Resource

@export var collectables: Dictionary = {}
@export var codex: Dictionary[String, CodexCreatureData]

func reset() -> void:
	collectables.clear()
	codex.clear()
