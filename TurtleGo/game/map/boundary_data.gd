class_name BoundaryData extends Resource

# this is all in mercantor projected coordinates
@export var minimum: Vector2
@export var maximum: Vector2
@export var center: Vector2
@export var valid: bool = false

# this is which tile of the world map it represents
@export var tile_coordinate: Vector2i

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
		valid = contains_merc(center)
		assert(valid)

	if not valid:
		return

	var uv := Parser.calculate_uv_from_merc(center)
	tile_coordinate = Parser.calculate_tile_coordinate_from_uv(uv)

	return

	# recalculate center from the tilecoords, don't trust OSM to be accurate to our request
	center = Parser.calculate_merc_from_uv(Parser.calculate_uv_from_tile_coordinate(tile_coordinate))
	center += (Parser.WORLD_TILE_DIMENSIONS_MERC / 2.0)

	# recalculate min and max for the same reason, we want perfect boundaries
	minimum = Vector2(
		center.x - (Parser.WORLD_TILE_DIMENSIONS_MERC.x / 2.0),
		center.y - (Parser.WORLD_TILE_DIMENSIONS_MERC.y / 2.0),
	)
	maximum = Vector2(
		center.x + (Parser.WORLD_TILE_DIMENSIONS_MERC.x / 2.0),
		center.y + (Parser.WORLD_TILE_DIMENSIONS_MERC.y / 2.0),
	)

func get_half_length() -> float:
	return (maximum.x - center.x)

func get_dimensions() -> Vector2:
	return maximum - minimum

func contains_merc(merc: Vector2) -> bool:
	return valid && merc.x >= minimum.x && merc.x <= maximum.x && merc.y >= minimum.y && merc.y <= maximum.y
