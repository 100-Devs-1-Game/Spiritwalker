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

	var uv := Maths.calculate_uv_from_merc(center)
	tile_coordinate = Maths.calculate_tile_coordinate_from_uv(uv)
	Maths.check_conversion(tile_coordinate)

	# recalculate center from the tilecoords, don't trust OSM to be accurate to our request
	center = Maths.calculate_merc_from_uv(Maths.calculate_uv_from_tile_coordinate(tile_coordinate))
	center.x += (Maths.WORLD_TILE_DIMENSIONS_MERC.x / 2.0)
	center.y -= (Maths.WORLD_TILE_DIMENSIONS_MERC.y / 2.0)

	# recalculate min and max for the same reason, we want perfect boundaries
	minimum = Vector2(
		center.x - (Maths.WORLD_TILE_DIMENSIONS_MERC.x / 2.0),
		center.y - (Maths.WORLD_TILE_DIMENSIONS_MERC.y / 2.0),
	)
	maximum = Vector2(
		center.x + (Maths.WORLD_TILE_DIMENSIONS_MERC.x / 2.0),
		center.y + (Maths.WORLD_TILE_DIMENSIONS_MERC.y / 2.0),
	)

	var coords_new := Maths.calculate_tile_coordinate_from_uv(Maths.calculate_uv_from_tile_coordinate(tile_coordinate))
	assert(tile_coordinate == coords_new)
	Maths.check_conversion(coords_new)
	tile_coordinate = coords_new

func get_half_length() -> float:
	return (maximum.x - center.x)

func get_dimensions() -> Vector2:
	return maximum - minimum

# this is merc in "world space" (i.e the whole world, relative to lat/lon 0,0)
func contains_merc(merc: Vector2) -> bool:
	return valid && merc.x >= minimum.x && merc.x <= maximum.x && merc.y >= minimum.y && merc.y <= maximum.y

# i.e the merc is relative to this boundaries center. useful for the paths that were processed for it
func contains_relative_merc(merc: Vector2) -> bool:
	merc += center
	return valid && merc.x >= minimum.x && merc.x <= maximum.x && merc.y >= minimum.y && merc.y <= maximum.y
