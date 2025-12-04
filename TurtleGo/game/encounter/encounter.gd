class_name Encounter extends Control

const CREATURE_DIALOGUE := preload("res://game/encounter/creature_dialogue.dialogue")
var creature_data: CreatureData

# confusingly I named some signals "combat" but that was for the encounter, kinda? IDK
# you can figure it out I'm sure, change things up innit
@onready var combat = %Combat
@onready var camera_3d: Camera3D = %Camera3D
@onready var creature_container: Node3D = %CreatureContainer
var creature: Node3D
func replace_combat_with_attack():
	var container = combat.get_parent()
	combat.queue_free()
	combat = preload("res://game/encounter/attack.tscn").instantiate()
	container.add_child(combat)

func play_creature_animation(animation:String, wait:bool=true):
	var root = creature
	while root.get_children():
		var animation_player := root.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if animation_player:
			animation_player.play(animation)
			if wait:
				await animation_player.animation_finished
				animation_player.play("01_idle")
			break
		root = root.get_child(0)

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

	creature = creature_data.scene.instantiate()
	creature_container.add_child(creature)
	play_creature_animation("01_idle", false)
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
