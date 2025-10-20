extends Node

# I'm using GPS to mean lat/lon because I'm too lazy to type "lation" UwU
const WORLD_MIN_GPS := Vector2(-180.0, -85.05113)
const WORLD_MAX_GPS := Vector2(180.0,   85.05113)
const WORLD_CENTER_GPS := WORLD_MAX_GPS + WORLD_MIN_GPS # a.k.a "Null Island" lat/lon is 0/0
const WORLD_SIZE_GPS := WORLD_MAX_GPS - WORLD_MIN_GPS # the total lat/lon of the world

static var WORLD_MIN_MERC: Vector2 = Vector2(-20037508.0, -20037508.0)
static var WORLD_MAX_MERC: Vector2 = Vector2(20037508.0, 20037508.0)
static var WORLD_CENTER_MERC: Vector2 = WORLD_MAX_MERC + WORLD_MIN_MERC
static var WORLD_SIZE_MERC: Vector2 = WORLD_MAX_MERC - WORLD_MIN_MERC

const WORLD_TILES_PER_SIDE := pow(2, Constants.WORLD_TILE_ZOOM_LEVEL)
static var WORLD_TILE_DIMENSIONS_MERC := WORLD_SIZE_MERC / WORLD_TILES_PER_SIDE

func calculate_uv_from_merc(center_merc: Vector2) -> Vector2:
	# we are UV unwrapping the world :D
	const epsilon := 1e-9
	return Vector2(
		 # (percentage) how far is our center from the left edge of the world
		((center_merc.x - WORLD_MIN_MERC.x) + epsilon) / WORLD_SIZE_MERC.x,
		 # (percentage) how far is our center from the top edge of the world
		((WORLD_MAX_MERC.y - center_merc.y) + epsilon) / WORLD_SIZE_MERC.y,
	)


func calculate_merc_from_uv(uv_position: Vector2) -> Vector2:
	return Vector2(
		(uv_position.x * WORLD_SIZE_MERC.x) + WORLD_MIN_MERC.x,
		 WORLD_MAX_MERC.y - (uv_position.y * WORLD_SIZE_MERC.y),
	)


func calculate_tile_coordinate_from_uv(uv_position: Vector2) -> Vector2i:
	# now we have our "uv coordinate" for the tile, on the earth
	# but we need to figure out where that is in a single "tile" coordinate
	# since we have WORLD_TILES_PER_SIDE... we just multiply them together
	# e.g for a UV of 0.01: 0.01 * WORLD_TILES_PER_SIDE = 0.01 * 131,000(ish @ zoom 17) = tile 131 in this coordinate
	# it could be a fractional number, in which case we floor it to "snap" to the nearest tile
	# so it can kinda work like an index in to an array
	# this is important for later, when we want to save and load the map

	# offsetting by this very small number is important for avoiding
	# invalid conversions when done back and forth multiple times
	const epsilon := 1e-7
	return Vector2i(
		floori((uv_position.x+epsilon) * WORLD_TILES_PER_SIDE),
		floori((uv_position.y+epsilon) * WORLD_TILES_PER_SIDE),
	)


func calculate_uv_from_tile_coordinate(tile_coords: Vector2i) -> Vector2:
	return Vector2(tile_coords) / WORLD_TILES_PER_SIDE


# x = LON (horizontal)
# y = LAT (vertical)
# THIS IS NOT WEB - THIS IS GEOGRAPHIC
# i.e the Y starts at 0 at the bottom and goes up as it increases
func mercatorProjection(_lat: float, _lon: float) -> Vector2:
	const WORLD_RADIUS := 6378137.0
	var x := _lon * PI / 180.0 * WORLD_RADIUS
	var y := log(tan(_lat * (PI / 180.0 / 2.0) + PI/4.0)) * WORLD_RADIUS
	return Vector2(x, y)


# x = LON (horizontal)
# y = LAT (vertical)
# THIS IS NOT WEB - THIS IS GEOGRAPHIC
# i.e the Y starts at 0 at the bottom and goes up as it increases
func inverseMercatorProjection(merc: Vector2) -> Vector2:
	const WORLD_RADIUS := 6378137.0
	var _lon := (merc.x / WORLD_RADIUS) * 180.0 / PI
	var _lat := (2.0 * atan(exp( merc.y / WORLD_RADIUS)) - (PI / 2.0 )) * 180.0 / PI
	return Vector2(_lon, _lat)


func calculate_tile_bounding_box_gps(tile_coords: Vector2i) -> Rect2:
	check_conversion(tile_coords)
	var uv := calculate_uv_from_tile_coordinate(tile_coords)
	var top_left_merc := calculate_merc_from_uv(uv)

	# now we have the top-left corner of the tile, but we want its bounding box
	# we have to calculate the width/height of the tile, but we know that already in mercantor projection
	# because the mercantor space is a consistent square

	var top_left_gps := inverseMercatorProjection(top_left_merc)
	#var test_top_left_gps_merc := mercatorProjection(top_left_gps.y, top_left_gps.x)
	var bottom_right_merc := top_left_merc + Vector2(WORLD_TILE_DIMENSIONS_MERC.x, -WORLD_TILE_DIMENSIONS_MERC.y)
	var bottom_right_gps := inverseMercatorProjection(bottom_right_merc)
	var lon_min := top_left_gps.x
	var lat_max := top_left_gps.y
	var lon_max := bottom_right_gps.x
	var lat_min := bottom_right_gps.y

	return Rect2(
		Vector2(lon_min, lat_min), # top left
		Vector2(lon_max - lon_min, lat_max - lat_min) # size
	)

func check_conversion(coords: Vector2i) -> void:
	var uv := calculate_uv_from_tile_coordinate(coords)
	var merc := calculate_merc_from_uv(uv)
	var gps := inverseMercatorProjection(merc)
	var merc_inv := mercatorProjection(gps.y, gps.x)
	var uv_inv := calculate_uv_from_merc(merc_inv)
	var coords_inv := calculate_tile_coordinate_from_uv(uv_inv)
	assert(uv.is_equal_approx(uv_inv))
	assert(merc.is_equal_approx(merc_inv))
	assert(coords == coords_inv)
	var uv2 := calculate_uv_from_tile_coordinate(coords_inv)
	var merc2 := calculate_merc_from_uv(uv2)
	var gps2 := inverseMercatorProjection(merc2)
	var merc_inv2 := mercatorProjection(gps2.y, gps2.x)
	var uv_inv2 := calculate_uv_from_merc(merc_inv2)
	var coords_inv2 := calculate_tile_coordinate_from_uv(uv_inv2)
	assert(uv2.is_equal_approx(uv_inv2))
	assert(merc2.is_equal_approx(merc_inv2))
	assert(coords_inv == coords_inv2)


func mercantorToGodotFromOrigin(merc: Vector2) -> Vector3:
	return Vector3(
		merc.x - Parser.originMapData.boundaryData.center.x,
		0.0,
		Parser.originMapData.boundaryData.center.y - merc.y,
	)
