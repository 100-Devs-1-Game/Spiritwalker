class_name Encounter extends Node3D

const CREATURE_DIALOGUE := preload("res://game/encounter/creature_dialogue.dialogue")
var creature_data: CreatureData

# confusingly I named some signals "combat" but that was for the encounter, kinda? IDK
# you can figure it out I'm sure, change things up innit
@onready var combat: Combat = %Combat
@onready var texture_rect: TextureRect = %TextureRect
@onready var camera_3d: Camera3D = $Camera3D


func _ready() -> void:
	# hopefully we launched with F6
	if Engine.is_embedded_in_editor() and not creature_data:
		push_warning("loading persim data due to invalid creature")
		creature_data = preload("res://game/entities/creatures/creature_data_persim.tres")

	assert(creature_data)
	assert(creature_data.action_one)
	assert(creature_data.action_two)
	assert(creature_data.action_three)
	assert(creature_data.action_four)
	print("encounter ready for creature %s" % creature_data.name)

	var creature := creature_data.scene.instantiate()
	add_child(creature)
	#todo: might need extra logic to handle the creatures animations, emotional state, etc.

	camera_3d.make_current()

	# this is the default current scene. you may need to replace this in the future, so I'm putting it here
	# to make it very obvious that it may be a future problem for you
	# e.g when there is a scene manager handling the overworld/encounter scene change
	DialogueManager.get_current_scene = func():
		var current_scene: Node = Engine.get_main_loop().current_scene
		if current_scene == null:
			current_scene = Engine.get_main_loop().root.get_child(
				Engine.get_main_loop().root.get_child_count() - 1
			)
		return current_scene

	# we pass self because we want to access these variables in the dialogue script
	# like "combat" or "creature_data"
	# NOTE: this uses the balloon UI in "game/dialogue/balloon"
	DialogueManager.show_dialogue_balloon(CREATURE_DIALOGUE, "start", [creature_data, self])
	await DialogueManager.dialogue_ended

	camera_3d.clear_current()
	queue_free()

	SceneManager.switch_to_scene(preload("res://game/map/map.tscn"))
