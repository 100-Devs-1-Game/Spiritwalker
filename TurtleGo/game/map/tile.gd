class_name Tile extends Node3D

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
