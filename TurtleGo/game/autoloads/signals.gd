extends Node

signal enableGPS
signal mapUpdated #if true, gps.gd won't download the map. This prevents that gps.gd downloads a new map evry time the gps coordinates update
signal playerPos(pos: Vector2, teleport: bool) #player location
signal addCollectable
signal updateCollectables
