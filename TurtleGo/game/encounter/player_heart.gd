extends Node2D

@export var beating = true

var elapsed := 0.0
func _process(delta):
	if beating:
		elapsed += delta * 4
		scale = Vector2(1.0 + cos(elapsed) * 0.1, 1.0 - cos(elapsed) * 0.1)
