extends Node

@onready var menu_start_bg := %MenuStartBg
@onready var gps_panel := %GpsPanel
@onready var gps_label := %GpsLabel

func _ready():
	menu_start_bg.visible = false
	gps_label.visible = true

	Signals.inventory_collectables_updated.connect(_on_inventory_collectables_updated)
	
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


func _on_inventory_collectables_updated(id: String, data: InventoryCollectableData):
	var node_path = str("CanvasLayer/PanelContainer/CollectableContainer/", id)
	get_node(node_path).text = str(data.num_collected)
