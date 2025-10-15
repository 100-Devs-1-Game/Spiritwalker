extends Area3D

var spawnTime = 600 #time this collectable is on map

func _ready():
	await get_tree().create_timer(spawnTime).timeout
	queue_free()

func _on_body_entered(body):
	#on player body enters Area3D, signals to add its name to player inventory and save
	#if a node is instantiated more than once, godot replaces that node's name with "[typeofnode]@[number]"
	#therefore we use the child's name which stays unchanged
	var player := body as Player
	if not player:
		print("not player")
		return

	var collectable: String = get_child(0).name
	Signals.addCollectable.emit(collectable)
	queue_free()
