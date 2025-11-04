extends Node

var current_scene: Node
var inactive_scenes: Array[Node]
var hidden_scene_parent: Node


func _ready() -> void:
	hidden_scene_parent = Node.new()
	hidden_scene_parent.name = "Hidden"
	hidden_scene_parent.process_mode = PROCESS_MODE_DISABLED
	hidden_scene_parent.set_process(false)
	hidden_scene_parent.set_physics_process(false)
	add_child(hidden_scene_parent)


func switch_to_scene(scene: PackedScene, hide: bool = true) -> Node:
	return switch_to_node(scene.instantiate(), hide)


func switch_to_node(node: Node, hide: bool = true) -> Node:
	if not node.scene_file_path:
		assert(false)
		node.free()
		return null

	if not current_scene:
		current_scene = node
		add_child(current_scene)
		return current_scene

	print("switching scene from %s to %s" % [current_scene.scene_file_path, node.scene_file_path])

	if current_scene.scene_file_path == node.scene_file_path:
		return null

	if hide:
		_hide_current_scene()
	else:
		_deactivate_current_scene()

	# reuse the scene if we already have it
	for inactive_scene in inactive_scenes:
		if inactive_scene.scene_file_path == node.scene_file_path:
			current_scene = inactive_scene
			_activate_current_scene()
			assert(node != inactive_scene)
			node.free()
			return current_scene

	# reuse the scene if we already have it
	for hidden_scene in hidden_scene_parent.get_children():
		if hidden_scene.scene_file_path == node.scene_file_path:
			current_scene = hidden_scene
			_show_current_scene()
			assert(node != hidden_scene)
			node.free()
			return current_scene

	# otherwise we need to use it
	current_scene = node
	add_child(current_scene)
	return current_scene


func _hide_current_scene() -> void:
	current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	current_scene.set_physics_process(false)
	current_scene.set_process(false)
	if current_scene is CanvasItem:
		(current_scene as Node2D).visible = false
	if current_scene is Node3D:
		(current_scene as Node3D).visible = false
	remove_child(current_scene)
	hidden_scene_parent.add_child(current_scene)


func _show_current_scene() -> void:
	hidden_scene_parent.remove_child(current_scene)
	current_scene.process_mode = Node.PROCESS_MODE_INHERIT
	current_scene.set_physics_process(true)
	current_scene.set_process(true)
	add_child(current_scene)
	if current_scene is CanvasItem:
		(current_scene as Node2D).visible = true
	if current_scene is Node3D:
		(current_scene as Node3D).visible = true


func _deactivate_current_scene() -> void:
	current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	current_scene.set_physics_process(false)
	current_scene.set_process(false)
	remove_child(current_scene)
	inactive_scenes.append(current_scene)


func _activate_current_scene() -> void:
	inactive_scenes.erase(current_scene)
	current_scene.process_mode = Node.PROCESS_MODE_INHERIT
	current_scene.set_physics_process(true)
	current_scene.set_process(true)
	add_child(current_scene)
