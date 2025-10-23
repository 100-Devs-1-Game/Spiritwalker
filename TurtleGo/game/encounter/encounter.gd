class_name Encounter extends Node3D

# todo: this would probably be a shared dialogue for all creature types
# and then it would reference data for each creature based on its personality
# so it knows what to say
# and those things would probably be a variable in the creature_data Resource itself
const DIALOGUE_EXAMPLE := preload(
	"res://game/entities/creatures/creature_data_persim_dialogue.dialogue"
)

# todo: this would probably be given to this encounter when it's started in the overworld
# but alternatively you could store it in an autoload temporarily, or some other solution
var this_creature_data: CreatureData = preload(
	"res://game/entities/creatures/creature_data_persim.tres"
)

# confusingly I named some signals "combat" but that was for the encounter, kinda? IDK
# you can figure it out I'm sure, change things up innit
@onready var combat: Combat = %Combat


func _ready() -> void:
	var creature := this_creature_data.scene.instantiate()
	add_child(creature)
	#todo: might need extra logic to handle the creatures animations, emotional state, etc.

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
	# like "combat" or "this_creatuer_data"
	# NOTE: this uses the balloon UI in "game/dialogue/balloon"
	DialogueManager.show_dialogue_balloon(DIALOGUE_EXAMPLE, "start", [self])
	await DialogueManager.dialogue_ended
	print("dialogue ended, now we should be back to overworld innit")
	queue_free()
