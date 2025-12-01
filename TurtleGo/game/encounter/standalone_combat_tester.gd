extends Node2D
@export var creature: CreatureData
@onready var combat = $Combat
func _ready() -> void:
	var buttons = $HBoxContainer.get_children()
	for idx in len(buttons):
		buttons[idx].connect("pressed", test.bind(idx))
	
	
func test(idx):
	if creature:
		creature.combat_style=idx
		if combat:
			combat.queue_free()
		combat = preload("res://game/encounter/combat.tscn").instantiate()
		add_child(combat)
		await combat.fight(creature)
		if combat.player_dead:
			prints("nice try mate")
		else:
			prints("you win")
		
	else:
		prints("No creature defined")
