extends Node2D

@export var speed = 100.0
@export var direction = Vector2.DOWN
var velocity = Vector2.ZERO

#func _ready() -> void:
#	set_process(false)

#func _physics_process(delta: float) -> void:
#	velocity = speed * direction
#	translate(velocity * delta)
