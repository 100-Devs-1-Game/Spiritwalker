extends Node

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

	print_debug("loaded savegame: ", savedInventory.collectables)
	updateUI()

func updateUI():
	for _coll in savedInventory.collectables:
		Signals.updateCollectables.emit(_coll, savedInventory.collectables[_coll])
