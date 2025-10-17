extends Node

signal enableGPS
signal mapUpdated #if true, gps.gd won't download the map. This prevents that gps.gd downloads a new map evry time the gps coordinates update
signal playerPos(pos: Vector2, teleport: bool) #player location
signal addCollectable
signal updateCollectables


signal player_entered_creature_range(creature: Creature)
signal creature_combat_start(creature_data: CreatureData)
signal creature_combat_delayed(creature_data: CreatureData)
signal creature_captured(creature_data: CreatureData)
