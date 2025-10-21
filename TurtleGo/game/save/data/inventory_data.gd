class_name InventoryData extends Resource

@export var collectables: Dictionary[String, InventoryCollectableData]
@export var creatures: Dictionary[String, InventoryCreatureData]

func reset() -> void:
	collectables.clear()
	creatures.clear()
