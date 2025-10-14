class_name Tile extends Node3D

@onready var collectables: Node3D = $collectables
@onready var buildings: Node3D = $buildings
@onready var water: Node3D = $water
@onready var railway: Node3D = $railway
@onready var other: Node3D = $other
@onready var streets: Node3D = $streets
@onready var boundary: Node3D = $boundary

var mapData: MapData
