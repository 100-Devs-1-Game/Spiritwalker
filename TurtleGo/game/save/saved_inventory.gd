class_name SavedInventory
extends Resource

@export var collectables: Dictionary = {}

func reset() -> void:
	collectables.clear()
