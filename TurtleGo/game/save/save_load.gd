class_name SaveLoad extends Node

var savedInventory: SavedInventory
var collectCount := 0

func _ready():
	loadInventory()

func get_save_filepath() -> String:
	# we have to make the "save" folder if it doesn't exist
	# otherwise we can't save it
	DirAccess.make_dir_recursive_absolute("user://saves/")
	return "user://saves/save.tres"

func addInventory(_collectable):
	if savedInventory.collectables.has(_collectable):
		collectCount = savedInventory.collectables[_collectable]
		collectCount += 1
		savedInventory.collectables[_collectable] = collectCount

	else:
		collectCount = 1
		savedInventory.collectables[_collectable] = collectCount

	Signals.updateCollectables.emit(_collectable, collectCount)
	saveInventory()

func saveInventory():
	if !savedInventory.resource_path:
		savedInventory.resource_path = get_save_filepath()

	ResourceSaver.save(savedInventory)

func loadInventory():
	if ResourceLoader.exists(get_save_filepath()):
		savedInventory = ResourceLoader.load(get_save_filepath()) as SavedInventory

	if not savedInventory:
		savedInventory = SavedInventory.new()
		savedInventory.reset()
		savedInventory.resource_path = get_save_filepath()

	Signals.addCollectable.connect(addInventory)

	Signals.creature_combat_delayed.connect(func(data: CreatureData) -> void:
		var ccd := savedInventory.codex.get_or_add(data.name, CodexCreatureData.new()) as CodexCreatureData
		ccd.name_id = data.name
		ccd.num_waiting_to_fight += 1
		saveInventory()
	)

	Signals.creature_captured.connect(func(data: CreatureData) -> void:
		var ccd := savedInventory.codex.get_or_add(data.name, CodexCreatureData.new()) as CodexCreatureData
		ccd.name_id = data.name
		ccd.num_waiting_to_fight -= 1
		ccd.num_captured += 1
		saveInventory()
	)

	print_debug("loaded savegame: ", savedInventory.collectables)
	updateUI()

func updateUI():
	for _coll in savedInventory.collectables:
		Signals.updateCollectables.emit(_coll, savedInventory.collectables[_coll])
