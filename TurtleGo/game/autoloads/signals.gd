extends Node

signal gps_enabled
signal playerPos(pos: Vector2, teleport: bool) #player location
signal addCollectable
signal updateCollectables


signal player_entered_creature_range(creature: Creature)
signal creature_combat_start(creature_data: CreatureData)
signal creature_combat_delayed(creature_data: CreatureData)
signal creature_captured(creature_data: CreatureData)


## Download Manager
signal download_started(filepath: String, gps: Vector2, coords: Vector2i)
signal download_succeeded(filepath: String, gps: Vector2, coords: Vector2i)
signal download_failed(filepath: String, gps: Vector2, coords: Vector2i)
signal download_finished(filepath: String, gps: Vector2, coords: Vector2i)

## Tile Manager
signal started_parsing_tile(filepath: String)
signal finished_parsing_tile(filepath: String, map_data: MapData)

signal started_loading_tile(map_data: MapData)
signal finished_loading_tile(tile: Tile)

signal started_unloading_tile(tile: Tile)
signal finished_unloading_tile(coords: Vector2i)
