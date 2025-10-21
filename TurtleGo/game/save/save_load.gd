class_name SaveLoad extends Node

var settings: SettingsData
var inventory: InventoryData

func _ready():
	_load_settings()
	_load_inventory()


func get_inventory_save_filepath() -> String:
	# we have to make the "save" folder if it doesn't exist
	# otherwise we can't save it
	DirAccess.make_dir_recursive_absolute("user://saves/")
	return "user://saves/inventory.tres"


func get_settings_save_filepath() -> String:
	# we have to make the "save" folder if it doesn't exist
	# otherwise we can't save it
	DirAccess.make_dir_recursive_absolute("user://saves/")
	return "user://saves/settings.tres"


func add_collectable(collectable_id: String):
	var icd := inventory.collectables.get_or_add(collectable_id, InventoryCollectableData.new()) as InventoryCollectableData
	icd.num_collected += 1
	Signals.inventory_collectables_updated.emit(collectable_id, icd)
	_save_inventory()


func _save_inventory():
	if !inventory.resource_path:
		inventory.resource_path = get_inventory_save_filepath()

	ResourceSaver.save(inventory)
	Signals.inventory_saved.emit(inventory)


func _save_settings():
	if !settings.resource_path:
		settings.resource_path = get_settings_save_filepath()

	ResourceSaver.save(settings)
	Signals.settings_saved.emit(settings)


func _new_inventory() -> InventoryData:
	var inv := InventoryData.new()
	inv.reset()
	inv.resource_path = get_inventory_save_filepath()
	return inv 


func _new_settings() -> SettingsData:
	var data := SettingsData.new()
	data.reset()
	data.resource_path = get_settings_save_filepath()
	return data 
	

func _load_inventory():
	if ResourceLoader.exists(get_inventory_save_filepath()):
		inventory = ResourceLoader.load(get_inventory_save_filepath()) as InventoryData
		if not inventory:
			assert(false)
			DirAccess.remove_absolute(get_inventory_save_filepath())

	if not inventory:
		inventory = _new_inventory()

	Signals.player_pickedup_collectable.connect(
		func(id: String) -> void:
			add_collectable(id)
	)

	Signals.creature_combat_delayed.connect(func(data: CreatureData) -> void:
		var icd := inventory.creatures.get_or_add(data.name, InventoryCreatureData.new()) as InventoryCreatureData
		icd.name_id = data.name
		icd.num_waiting_to_fight += 1
		Signals.inventory_creatures_updated.emit(data.name, icd)
		_save_inventory()
	)

	Signals.creature_captured.connect(func(data: CreatureData) -> void:
		var icd := inventory.creatures.get_or_add(data.name, InventoryCreatureData.new()) as InventoryCreatureData
		icd.name_id = data.name
		assert(icd.num_waiting_to_fight > 0)
		icd.num_waiting_to_fight -= 1
		icd.num_captured += 1
		Signals.inventory_creatures_updated.emit(data.name, icd)
		_save_inventory()
	)

	for collectable_id: String in inventory.collectables:
		Signals.inventory_collectables_updated.emit(collectable_id, inventory.collectables[collectable_id])

	for creature_id: String in inventory.creatures:
		Signals.inventory_creatures_updated.emit(creature_id, inventory.creatures[creature_id])
	
	print("loaded inventory: ", inventory)
	Signals.inventory_loaded.emit(inventory)


func _load_settings():
	if ResourceLoader.exists(get_settings_save_filepath()):
		settings = ResourceLoader.load(get_settings_save_filepath()) as SettingsData
		if not settings:
			assert(false)
			DirAccess.remove_absolute(get_settings_save_filepath())

	if not settings:
		settings = _new_settings()

	print("loaded settings: ", settings)
	Signals.settings_loaded.emit(settings)
