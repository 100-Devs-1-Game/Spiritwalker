class_name Combat extends Node2D

# this is the combat minigame bullet hell thingy, do stuff in here when things happen in the dialogue part of the encounter?
# e.g pause/unpause it, subtract player health, start the next encounter dialogue section, etc

var player_dead := false
var creature_dead := false


func fight() -> void:
	await get_tree().create_timer(1.0).timeout
	if randf_range(0, 2) < 1:
		player_dead = randi()
		creature_dead = randi()
		print("player_dead = %s, creature_dead = %s" % [player_dead, creature_dead])
