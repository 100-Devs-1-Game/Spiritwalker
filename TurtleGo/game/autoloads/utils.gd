extends Node

static func remove_recursive(directory: String) -> Error:
	var err := Error.OK
	for dir_name in DirAccess.get_directories_at(directory):
		var err1 := remove_recursive(directory.path_join(dir_name))
		if err1 != Error.OK:
			err = err1

	for file_name in DirAccess.get_files_at(directory):
		var err2 := DirAccess.remove_absolute(directory.path_join(file_name))
		if err2 != Error.OK:
			err = err2

	var err3 := DirAccess.remove_absolute(directory)

	if err3 != Error.OK:
		err = err3

	return err


# "other" is an extra bit of data to make different RNG's for the same tile
# e.g one RNG for creatures, and another for crystals
func get_deterministic_rng(coords: Vector2i, other: int) -> RandomNumberGenerator:
	#The seed is the current date and time. This way, every user sees the same collectables on their device.
	var date := Time.get_datetime_string_from_system()
	#get date in the format YYYY-MM-DDTHH:MM:SS
	#cut date to YYYY-MM-DDTHH:M and use as seed for pseudo-random generator of collectable placement
	var seed_data := "%s %s %s" % [date.substr(0, 15), coords, other]
	var random := RandomNumberGenerator.new()
	random.set_seed(hash(seed_data))
	return random


func get_tile_filename_for_gps(_lat: float, _lon: float) -> String:
	var merc := Maths.mercatorProjection(_lat, _lon)
	var uv := Maths.calculate_uv_from_merc(merc)
	var tile := Maths.calculate_tile_coordinate_from_uv(uv)
	return get_tile_filename_for_coords(tile)


func get_tile_filename_for_coords(coords: Vector2i) -> String:
	return "user://maps/z%d/%sx-%sy" % [Constants.WORLD_TILE_ZOOM_LEVEL, coords.x, coords.y]


func has_map_xml(_lat: float, _lon: float) -> bool:
	return FileAccess.file_exists(get_tile_filename_for_gps(_lat, _lon) + ".xml")


func has_map_resource(_lat: float, _lon: float) -> bool:
	return ResourceLoader.exists(get_tile_filename_for_gps(_lat, _lon) + ".tres")


func has_map_xml_tilecoords(coords: Vector2i) -> bool:
	return FileAccess.file_exists(get_tile_filename_for_coords(coords) + ".xml")


func has_map_resource_tilecoords(coords: Vector2i) -> bool:
	return ResourceLoader.exists(get_tile_filename_for_coords(coords) + ".tres")


func has_map(_lat: float, _lon: float) -> bool:
	return has_map_xml(_lat, _lon) || has_map_resource(_lat, _lon)


func has_map_tilecoords(coords: Vector2i) -> bool:
	return has_map_xml_tilecoords(coords) || has_map_resource_tilecoords(coords)


func is_path_closed(path: PackedVector3Array) -> bool:
	return path && path.size() >= 3 && path[0].is_equal_approx(path[path.size() - 1])
