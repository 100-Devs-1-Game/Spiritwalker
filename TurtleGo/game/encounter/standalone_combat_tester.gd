extends Node2D
@export var creature: CreatureData

func _ready() -> void:
	if creature:
		await $Combat.fight(creature)
		if $Combat.player_dead:
			prints("nice try mate")
		else:
			prints("you win")
		
	else:
		prints("No creature defined")
