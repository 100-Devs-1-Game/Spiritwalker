extends Node

var savedInventory:SavedInventory
var collectCount = 0

func _ready():
	savedInventory = SavedInventory.new()
	Signals.connect("addCollectable", addInventory)
	loadInventory()

func addInventory(_collectable):
	if savedInventory.collectables.has(_collectable):
		collectCount = savedInventory.collectables[_collectable]
		collectCount += 1
		savedInventory.collectables[_collectable] = collectCount

	else:
		collectCount = 1
		savedInventory.collectables[_collectable] = collectCount

	Signals.emit_signal("updateCollectables", _collectable, collectCount)
	saveInventory()

func saveInventory():
	ResourceSaver.save(savedInventory, "res://assets/scripts/save/saveFile.tres")

func loadInventory():
	savedInventory = load("res://assets/scripts/save/saveFile.tres") as SavedInventory
	print_debug("loaded collectables: ", savedInventory.collectables)
	updateUI()

func updateUI():
	for _coll in savedInventory.collectables:
		Signals.emit_signal("updateCollectables", _coll, savedInventory.collectables[_coll])
