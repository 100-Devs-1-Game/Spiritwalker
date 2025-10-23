class_name Tile extends Node3D

# README
# - it doesn't do much, but some of the TileManager logic could be handled in here directly, e.g placing creatures
# - this represents a tile in the overworld map, but I also use the word map and tile to mean the same thing in multiple places
#   e.g the has_map util is talking about tiles, which are saved in the "maps" folder. please feel free to clean that terminology up, it evolved over time

@onready var collectables: Node3D = $Collectables
@onready var creatures: Node3D = $Creatures
@onready var buildings: Node3D = $Buildings
@onready var water: Node3D = $Water
@onready var railway: Node3D = $Railway
@onready var other: Node3D = $Other
@onready var streets: Node3D = $Streets
@onready var streets_trunk: Node3D = $StreetsTrunk
@onready var streets_primary: Node3D = $StreetsPrimary
@onready var streets_secondary: Node3D = $StreetsSecondary
@onready var streets_pedestrian: Node3D = $StreetsPedestrian
@onready var boundary: Node3D = $Boundary

var map_data: MapData


func _ready() -> void:
	boundary.visible = OS.is_debug_build()
