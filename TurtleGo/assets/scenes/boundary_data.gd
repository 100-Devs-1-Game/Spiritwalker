class_name BoundaryData extends Resource

# this is all in mercantor projected coordinates
@export_storage var minimum: Vector2
@export_storage var maximum: Vector2
@export_storage var center: Vector2
@export_storage var valid: bool = false

# this is which tile of the world map it represents
@export_storage var tile_coordinate: Vector2i

func _init(
	p_minimum: Vector2 = Vector2.ZERO,
	p_maximum: Vector2 = Vector2.ZERO,
	p_center: Vector2 = Vector2.ZERO,
	) -> void:
	minimum = p_minimum
	maximum = p_maximum
	center = p_center

	if (minimum != Vector2.ZERO
		&& maximum != Vector2.ZERO
		&& center != Vector2.ZERO):
			valid = true

	if valid:
		var uv := Parser.calculate_uv_from_merc(center)
		tile_coordinate = Parser.calculate_tile_coordinate_from_uv(uv)

func get_half_length() -> float:
	return (maximum.x - center.x)

func get_dimensions() -> Vector2:
	return maximum - minimum
