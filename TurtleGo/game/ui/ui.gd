extends Node

var savedInventory:SavedInventory

func _ready():
	Signals.connect("updateCollectables", updateInventory)

func updateInventory(_collectable, _collCount):
	var node_path = str("CanvasLayer/PanelContainer/CollectableContainer/", _collectable)
	get_node(node_path).text = str(_collCount)
	#print_debug("found ", _collCount, _collectable)

func _on_enable_gps_pressed():
	print("button pressed")
	Signals.emit_signal("enableGPS")
