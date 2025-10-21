extends Node

signal playerPos(pos: Vector2, teleport: bool) #player location
signal addCollectable
signal updateCollectables


signal player_entered_creature_range(creature: Creature)
signal creature_combat_start(creature_data: CreatureData)
signal creature_combat_delayed(creature_data: CreatureData)
signal creature_captured(creature_data: CreatureData)


## GPS Manager
signal gps_permission_failed
signal gps_permission_succeeded
signal gps_enabled(gps_manager: GpsManager)
signal gps_data_received(gps_manager: GpsManager)

## Download Manager
signal download_started(filepath: String, gps: Vector2, coords: Vector2i)
signal download_succeeded(filepath: String, gps: Vector2, coords: Vector2i)
signal download_failed(filepath: String, gps: Vector2, coords: Vector2i)
signal download_finished(filepath: String, gps: Vector2, coords: Vector2i)

## Tile Manager
signal tile_parsing_started(filepath: String)
signal tile_parsing_finished(filepath: String, map_data: MapData)

signal tile_loading_started(map_data: MapData)
signal tile_loading_finished(tile: Tile)

signal tile_unloading_started(tile: Tile)
signal tile_unloading_finished(coords: Vector2i)
