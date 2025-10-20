extends Node3D

func _ready() -> void:
	Maths.check_conversion(Vector2i(128887, 87467))
	Maths.check_conversion(Vector2i(128887, 87468))
	Maths.check_conversion(Vector2i(128887, 87469))
	Maths.check_conversion(Vector2i(128886, 87468))
	Maths.check_conversion(Vector2i(128887, 87468))
	Maths.check_conversion(Vector2i(128888, 87468))
	
	Maths.check_conversion(Vector2i(0, 0))
	
	Maths.check_conversion(Vector2i(0, 1))
	Maths.check_conversion(Vector2i(0, 2))

	Maths.check_conversion(Vector2i(1, 0))
	Maths.check_conversion(Vector2i(2, 0))
	
	Maths.check_conversion(Vector2i(1, 1))
	Maths.check_conversion(Vector2i(2, 2))

	Maths.check_conversion(Vector2i(1, 2))
	Maths.check_conversion(Vector2i(2, 1))
