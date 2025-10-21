extends Node

var savedInventory: SavedInventory

@onready var gps_panel := %GpsPanel
@onready var gps_label := %GpsLabel

func _ready():
	Signals.updateCollectables.connect(updateInventory)
	Signals.gps_permission_failed.connect(
		func() -> void:
			gps_label.text = "Waiting for Location Permission..."
	)
	Signals.gps_permission_succeeded.connect(
		func() -> void:
			gps_label.text = "Waiting for GPS Data..."
			await Signals.gps_data_received
			gps_panel.queue_free()
	)

func updateInventory(_collectable, _collCount):
	var node_path = str("CanvasLayer/PanelContainer/CollectableContainer/", _collectable)
	get_node(node_path).text = str(_collCount)
	#print_debug("found ", _collCount, _collectable)
