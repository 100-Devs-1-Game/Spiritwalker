#@tool
class_name Parser extends Node3D

@onready var tiles := %tiles
var tiles_loaded: Dictionary[Vector2i, Tile]

var gps_provider
var url_test := "https://api.openstreetmap.org/api/0.6/map?bbox=11.54,48.14,11.543,48.145" #link that downloads an xml file that can be drawn as a map
var url_base_official := "https://api.openstreetmap.org/api/0.6/map?bbox=" #official editing api of openstreetmap.org. This is only for testing purposes
#var url_base = "https://overpass-api.de/api/map?bbox=" #allows limited public use. Guideline: maximum of 1000 requests per day
var url: String
var active_download_tilecoords: Vector2i
var file_path: String
var inflight_download_requests := 0
var lat: float
var lon: float

const STREET_PATH_SCENE = preload("res://game/map/paths/street_other.tscn")
const STREET_PRIMARY_SCENE = preload("res://game/map/paths/street_primary.tscn")
const STREET_SECONDARY_SCENE = preload("res://game/map/paths/street_secondary.tscn")
const STREET_PEDESTRIAN_SCENE = preload("res://game/map/paths/street_pedestrian.tscn")
const BUILDING_SCENE = preload("res://game/map/paths/building.tscn")
const WATER_SCENE = preload("res://game/map/paths/water.tscn")
const RAILWAY_SCENE = preload("res://game/map/paths/railway.tscn")
const TILE_SCENE = preload("res://game/map/tile.tscn")
const BOUNDARY_SCENE = preload("res://game/map/paths/boundary.tscn")

###########
###collectables on map
const CRYSTAL_BLUE_SCENE = preload("res://game/entities/collectables/crystal_blue.tscn")
const CRYSTAL_GREEN_SCENE = preload("res://game/entities/collectables/crystal_green.tscn")
const CRYSTAL_ORANGE_SCENE = preload("res://game/entities/collectables/crystal_orange.tscn")
const CRYSTAL_PINK_SCENE = preload("res://game/entities/collectables/crystal_pink.tscn")
const CRYSTAL_PURPLE_SCENE = preload("res://game/entities/collectables/crystal_purple.tscn")
const CRYSTAL_YELLOW_SCENE = preload("res://game/entities/collectables/crystal_yellow.tscn")
const items = [CRYSTAL_BLUE_SCENE, CRYSTAL_GREEN_SCENE, CRYSTAL_PINK_SCENE, CRYSTAL_PURPLE_SCENE]
#######

###Testing
var counti = 0
var countm = 0
var offline = true

var originMapData := MapData.new()
var currentMapData := MapData.new()
var tilecoords_queued_for_download: Array[Vector2i]
var tilecoords_queued_for_loading: Array[Vector2i]
var tilecoords_being_replaced: Array[Vector2i]
var player_previous_tilecoords: Vector2i

# I'm using GPS to mean lat/lon because I'm too lazy to type "lation" UwU
const WORLD_MIN_GPS := Vector2(-85.05113, -180.0)
const WORLD_MAX_GPS := Vector2(85.05113, 180.0)
const WORLD_CENTER_GPS := WORLD_MAX_GPS + WORLD_MIN_GPS # a.k.a "Null Island" lat/lon is 0/0
const WORLD_SIZE_GPS := WORLD_MAX_GPS - WORLD_MIN_GPS # the total lat/lon of the world

# MERC = (Web) mercantor projection
# web means 0,0 is top left, like in game engines. +x = right, +y = down
static var WORLD_MIN_MERC: Vector2 = mercatorProjection(WORLD_MIN_GPS.x, WORLD_MIN_GPS.y)
static var WORLD_MAX_MERC: Vector2 = mercatorProjection(WORLD_MAX_GPS.x, WORLD_MAX_GPS.y)
static var WORLD_CENTER_MERC: Vector2 = WORLD_MAX_MERC + WORLD_MIN_MERC
static var WORLD_SIZE_MERC: Vector2 = WORLD_MAX_MERC - WORLD_MIN_MERC

# pokemon go seems to use a zoom level of 17? this is 2^17 = 131,000 "square" tiles horizontally and vertically
# note that these tiles are "square" in the projected sense. that means they are not square in the real world
# so the area of each tile changes depending on how close to the poles we are
# with this, we're generate tiles that, at the equator, are about 300 meters (world range / 2^17 = 300ish meters squared)
# ... I think?
const WORLD_TILE_ZOOM_LEVEL := 18 # TEMP: WE'RE USING 18 FOR ~150m PER BOUNDARY - SIMILAR TO ~100m ORIGINAL TEST SIZE
const WORLD_TILES_PER_SIDE := pow(2, WORLD_TILE_ZOOM_LEVEL)
static var WORLD_TILE_DIMENSIONS_MERC := WORLD_SIZE_MERC / WORLD_TILES_PER_SIDE

static func calculate_uv_from_merc(center_merc: Vector2) -> Vector2:
	# we are UV unwrapping the world :D
	return Vector2(
		 # (percentage) how far is our center from the left edge of the world
		(center_merc.x - WORLD_MIN_MERC.x) / WORLD_SIZE_MERC.x,
		 # (percentage) how far is our center from the top edge of the world
		(WORLD_MAX_MERC.y - center_merc.y) / WORLD_SIZE_MERC.y,
	)


static func calculate_tile_coordinate_from_uv(uv_position: Vector2) -> Vector2i:
	# now we have our "uv coordinate" for the tile, on the earth
	# but we need to figure out where that is in a single "tile" coordinate
	# since we have WORLD_TILES_PER_SIDE... we just multiply them together
	# e.g for a UV of 0.01: 0.01 * WORLD_TILES_PER_SIDE = 0.01 * 131,000(ish @ zoom 17) = tile 131 in this coordinate
	# it could be a fractional number, in which case we floor it to "snap" to the nearest tile
	# so it can kinda work like an index in to an array
	# this is important for later, when we want to save and load the map
	return Vector2i(
		floori(uv_position.x * WORLD_TILES_PER_SIDE),
		floori(uv_position.y * WORLD_TILES_PER_SIDE),
	)


static func calculate_uv_from_tile_coordinate(tile_coords: Vector2i) -> Vector2:
	return Vector2(tile_coords) / WORLD_TILES_PER_SIDE


static func calculate_merc_from_uv(uv_position: Vector2) -> Vector2:
	return Vector2(
		(uv_position.x * WORLD_SIZE_MERC.x) + WORLD_MIN_MERC.x,
		 WORLD_MAX_MERC.y - (uv_position.y * WORLD_SIZE_MERC.y),
	)


# x = LON (horizontal)
# y = LAT (vertical)
# THIS IS NOT WEB - THIS IS GEOGRAPHIC
# i.e the Y starts at 0 at the bottom and goes up as it increases
static func mercatorProjection(_lat: float, _lon: float) -> Vector2:
	const WORLD_RADIUS := 6378137.0
	var x := _lon * (PI/180.0) * WORLD_RADIUS
	var y := log(tan(_lat * (PI/180.0)/2.0 + PI/4.0)) * WORLD_RADIUS
	return Vector2(x, y)


# x = LON (horizontal)
# y = LAT (vertical)
# THIS IS NOT WEB - THIS IS GEOGRAPHIC
# i.e the Y starts at 0 at the bottom and goes up as it increases
static func inverseMercatorProjection(merc: Vector2) -> Vector2:
	const WORLD_RADIUS := 6378137.0
	var _lon := (merc.x / WORLD_RADIUS) * (180.0 / PI)
	var _lat := (2.0 * atan(exp(merc.y / WORLD_RADIUS)) - PI/2.0) * (180.0 / PI)
	return Vector2(_lon, _lat)


func mercantorToGodotFromOrigin(merc: Vector2) -> Vector3:
	return Vector3(
		merc.x - originMapData.boundaryData.center.x,
		0.0,
		originMapData.boundaryData.center.y - merc.y,
	)


static func calculate_tile_bounding_box_gps(tile_coords: Vector2i) -> Rect2:
	var uv := calculate_uv_from_tile_coordinate(tile_coords)
	var top_left_merc := calculate_merc_from_uv(uv)
	#var test_top_left_merc_uv := calculate_uv_from_merc(top_left_merc)
	#var test_top_left_merc := calculate_merc_from_uv(test_top_left_merc_uv)

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


func _ready():
	Signals.mapUpdated.connect(parseXML)
	Signals.enableGPS.connect(checkGPS)
	$HTTPRequest.request_completed.connect(_on_request_completed)
	DirAccess.make_dir_recursive_absolute("user://maps/")
	file_path = "user://maps/myMap"
	var userOS = OS.get_name()

	if userOS == "Windows" || userOS == "Linux":
		print(OS.get_name())

		lat = 51.234286
		lon = -2.999235
		load_or_download_tiles(lat, lon)
	else:
		var success := parseAndReplaceMap(file_path)
		if not success:
			print("no file access")

		checkGPS()

	# infinitely try and download our (and neighbouring) tiles
	# this is... a fail safe, but it shouldn't be necessary
	regularly_load_tiles()

	# also keep unloading tiles that are far away from us
	regularly_unload_tiles()

	regularly_download_queued_tiles()
	regularly_load_queued_tiles()

func regularly_load_tiles():
	while true:
		await get_tree().create_timer(5).timeout
		load_or_download_tiles(lat, lon)

func regularly_unload_tiles():
	while true:
		await get_tree().create_timer(4).timeout
		if not currentMapData or not currentMapData.boundaryData.valid:
			continue

		var distant_tiles: Array[Vector2i]
		for coords in tiles_loaded:
			if tile_is_distant(coords) && not tilecoords_being_replaced.has(coords):
				distant_tiles.append(coords)

		for distant_tile in distant_tiles:
			unload_tile(distant_tile)

func regularly_download_queued_tiles() -> void:
	while true:
		await get_tree().create_timer(1).timeout
		if tilecoords_queued_for_download.is_empty():
			continue

		if inflight_download_requests != 0:
			continue

		# remove any tiles that are now too far away for us
		tilecoords_queued_for_download = tilecoords_queued_for_download.filter(tile_is_not_distant)

		if tilecoords_queued_for_download.is_empty():
			continue

		var coords := tilecoords_queued_for_download[0]
		print("DL Q. TILE : %sx-%sy (%d remaining)" % [coords.x, coords.y, tilecoords_queued_for_download.size() - 1])
		download_map_tilecoords(coords)
		tilecoords_queued_for_loading.erase(coords)
		tilecoords_queued_for_download.erase(coords)

func regularly_load_queued_tiles() -> void:
	while true:
		await get_tree().create_timer(0.5).timeout
		if tilecoords_queued_for_loading.is_empty():
			continue

		tilecoords_queued_for_loading = tilecoords_queued_for_loading.filter(tile_is_not_distant)
		if tilecoords_queued_for_loading.is_empty():
			continue

		var coords := tilecoords_queued_for_loading[0]
		tilecoords_queued_for_loading.erase(coords)

		assert(has_map_tilecoords(coords))
		var file := get_tile_filename_for_coords(coords)
		var success := parseAndReplaceMap(file)
		if success:
			tilecoords_queued_for_download.erase(coords)
			print("LD Q. TILE : %sx-%sy (%d remaining)" % [coords.x, coords.y, tilecoords_queued_for_loading.size()])
			continue

		# since it failed to load, queue it for download
		if not tilecoords_queued_for_download.has(coords):
			tilecoords_queued_for_download.append(coords)

func tile_is_distant(coords: Vector2i) -> bool:
	if !currentMapData || !currentMapData.boundaryData.valid:
		# if we don't know where we are, assume everything is close to us
		return false

	const MAX_DISTANCE_IN_TILES := 3
	var distance_vec := coords - currentMapData.boundaryData.tile_coordinate
	return distance_vec.length_squared() > MAX_DISTANCE_IN_TILES * MAX_DISTANCE_IN_TILES

func tile_is_not_distant(coords: Vector2i) -> bool:
	return not tile_is_distant(coords)

func unload_tile(coords: Vector2i) -> void:
	if tilecoords_being_replaced.has(coords):
		# could remove assert if function is called elsewhere
		assert(false)
		return

	var is_loaded := tiles_loaded.has(coords)
	if not is_loaded:
		# could remove assert if function is called elsewhere
		assert(false)
		return

	var found_tile: Tile = tiles_loaded[coords]
	if not found_tile:
		 # we should never have an invalid node here... did we forget to remove it from tiles_loaded after freeing the child?
		assert(false)
		tiles_loaded.erase(coords)
		return

	if not found_tile.mapData.boundaryData.valid:
		# we should never have an invalid boundary for our tiles, even the empty ones
		assert(false)

	tilecoords_being_replaced.append(coords)
	#print("UNLDD. TILE: %sx-%sy" % [coords.x, coords.y])
	for child in found_tile.get_children():
		if child:
			for grandchild in child.get_children():
				grandchild.queue_free()
				await get_tree().process_frame
			child.queue_free()
			await get_tree().process_frame
	found_tile.queue_free()
	tiles_loaded.erase(coords)
	tilecoords_being_replaced.erase(coords)

func checkGPS():
	var allowed = OS.request_permissions()
	if allowed:
		print("gps permitted")
	else:
		print("gps not permitted")

	enableGPS()


func enableGPS():
	if Engine.has_singleton("PraxisMapperGPSPlugin"):
		gps_provider= Engine.get_singleton("PraxisMapperGPSPlugin")

	if gps_provider != null:
		gps_provider.onLocationUpdates.connect(locationUpdate)
		gps_provider.StartListening()


func locationUpdate(location: Dictionary) -> void:
	#update player position
	lat = location["latitude"]
	lon = location["longitude"]

	var vec := mercatorProjection(lat, lon)
	playerBounds(vec.x, vec.y)
	if currentMapData && currentMapData.boundaryData.valid:
		%LabelTileCoord.text = "tile %s" % currentMapData.boundaryData.tile_coordinate

	counti += 1
	$VBoxContainer/Label.text = str(counti, " lat: " , lat, ", lon:  " ,lon)

func get_tile_filename_for_gps(_lat: float, _lon: float) -> String:
	var merc := mercatorProjection(_lat, _lon)
	var uv := calculate_uv_from_merc(merc)
	var tile := calculate_tile_coordinate_from_uv(uv)
	return get_tile_filename_for_coords(tile)


func get_tile_filename_for_coords(coords: Vector2i) -> String:
	return "user://maps/%sx-%sy" % [coords.x, coords.y]


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


func load_or_download_tiles(_lat: float, _lon: float):
	var actual_merc := mercatorProjection(_lat, _lon)
	var actual_uv := calculate_uv_from_merc(actual_merc)
	var our_tile_coords := calculate_tile_coordinate_from_uv(actual_uv)

	var tilecoords_to_check: Array[Vector2i]

	tilecoords_to_check.append(our_tile_coords + Vector2i(-1, -1)) #topleft
	tilecoords_to_check.append(our_tile_coords + Vector2i(0, -1)) #top
	tilecoords_to_check.append(our_tile_coords + Vector2i(1, -1)) #topright

	tilecoords_to_check.append(our_tile_coords + Vector2i(-1, 1)) #botleft
	tilecoords_to_check.append(our_tile_coords + Vector2i(0, 1)) #bot
	tilecoords_to_check.append(our_tile_coords + Vector2i(1, 1)) #botright

	tilecoords_to_check.append(our_tile_coords + Vector2i(-1, 0)) #left
	tilecoords_to_check.append(our_tile_coords + Vector2i(1, 0)) #right
	# this being last is important for forcing it to the front later
	tilecoords_to_check.append(our_tile_coords)

	for coords in tilecoords_to_check:
		if tiles_loaded.has(coords):
			continue

		if tilecoords_queued_for_download.has(coords):
			# force these to the front because it might have been added before as a neighbouring tile
			# note: since our direct tile is last in our array, we force it to the front last, prioritising it more
			tilecoords_queued_for_download.erase(coords)
			tilecoords_queued_for_download.insert(0, coords)
			continue

		var is_queued_for_loading := tilecoords_queued_for_loading.has(coords)
		var has_map_downloaded := has_map_tilecoords(coords)
		if has_map_downloaded:
			if our_tile_coords == coords:
				# remove it from the queue in case it was added by someone else before
				tilecoords_queued_for_loading.erase(coords)
				# try and instantly load this tile since it's our priority
				var file := get_tile_filename_for_coords(coords)
				var success := parseAndReplaceMap(file)
				if success:
					# remove it from the queue in case it was added by someone else before
					tilecoords_queued_for_download.erase(coords)
					continue
				# else fall through and go straight to priority download
			elif not is_queued_for_loading:
				tilecoords_queued_for_loading.insert(0, coords)
				continue
			elif is_queued_for_loading:
				# repriotise the adjacent tiles to load towards the front
				# our important one should have been loaded instantly and not queued
				tilecoords_queued_for_loading.erase(coords)
				tilecoords_queued_for_loading.insert(0, coords)
				continue

		# either we didn't have a map or we failed when loading it just now
		# so let's queue up a download
		# and prioritise these over the others
		# (our main node is last to be inserted at the front, for most priority)
		tilecoords_queued_for_download.insert(0, coords)

func download_map_tilecoords(coords: Vector2i) -> void:
	var uv := calculate_uv_from_tile_coordinate(coords)
	var merc := calculate_merc_from_uv(uv)
	var gps := inverseMercatorProjection(merc)
	downloadMap(gps.y, gps.x)

func downloadMap(_lat: float, _lon: float):
	if _lat == 0.0 && _lon == 0.0:
		push_error("tried to download a map for lat/lon of 0/0 - do we have a valid position yet?")
		assert(false)
		return

	if inflight_download_requests != 0:
		assert(false)
		return

	inflight_download_requests += 1

	var actual_merc := mercatorProjection(_lat, _lon)
	var actual_uv := calculate_uv_from_merc(actual_merc)
	var our_tile_coords := calculate_tile_coordinate_from_uv(actual_uv)
	var tile_bbox := calculate_tile_bounding_box_gps(our_tile_coords)
	var tile_center := tile_bbox.get_center()
	const decimal_places := "%.6f" #the number of decimal places the latitude/longitude has in the api request. 5 decimal places loads a map of ~200mx200m around the player. 3 decimal places loads about 2000mx2000m
	var _lat_min:String = decimal_places % (tile_center.y - (tile_bbox.size.y / 2.0))
	var _lon_min:String = decimal_places % (tile_center.x - (tile_bbox.size.x / 2.0))
	var _lat_max:String = decimal_places % (tile_center.y + (tile_bbox.size.y / 2.0))
	var _lon_max:String = decimal_places % (tile_center.x + (tile_bbox.size.x / 2.0))
	active_download_tilecoords = our_tile_coords
	url = url_base_official + _lon_min + "," + _lat_min + "," + _lon_max + "," + _lat_max
	print("DOWNLOADING: %sx-%sy          (%s)" % [active_download_tilecoords.x, active_download_tilecoords.y, url])
	file_path = get_tile_filename_for_coords(our_tile_coords) + ".xml"
	$HTTPRequest.set_download_file(file_path)
	$HTTPRequest.request(url)


func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
	#Signals.emit_signal("mapUpdated", file_path)
	print("DOWNLOADED : %sx-%sy CODE %d (%s)" % [active_download_tilecoords.x, active_download_tilecoords.y, response_code, url])
	countm += 1
	$VBoxContainer/Label2.text = str(countm, url)

	if response_code != 200:
		push_error("    ^^^ FAILED TO DOWNLOAD MAP")
		# pause for a second before we let anyone download another map
		await get_tree().create_timer(1.0).timeout
		inflight_download_requests -= 1
		return

	# pause for a second before we let anyone download another map
	await get_tree().create_timer(1.0).timeout

	var mapData := parseAndReplaceMap(file_path.trim_suffix(".xml"))
	if !mapData:
		inflight_download_requests -= 1
		if inflight_download_requests == 0:
			print("FAILED TO PARSE DOWNLOADED MAP, RETRYING")
			downloadMap(lat, lon)
		return

	if tilecoords_queued_for_download.has(mapData.boundaryData.tile_coordinate) || tilecoords_queued_for_loading.has(mapData.boundaryData.tile_coordinate):
		print("LOADED TILE: %sx-%sy (%d & %d remaining)" % [
			mapData.boundaryData.tile_coordinate.x,
			mapData.boundaryData.tile_coordinate.y,
			tilecoords_queued_for_loading.size(),
			tilecoords_queued_for_download.size(),
		])

	if active_download_tilecoords != mapData.boundaryData.tile_coordinate:
		push_warning("we downloaded the tile %s but we thought we were downloading the tile %s? how?" % [mapData.boundaryData.tile_coordinate, active_download_tilecoords])

	tilecoords_queued_for_loading.erase(mapData.boundaryData.tile_coordinate)
	tilecoords_queued_for_download.erase(mapData.boundaryData.tile_coordinate)
	inflight_download_requests -= 1
	active_download_tilecoords = Vector2.ZERO


func parseAndReplaceMap(_file_path: String) -> MapData:
	var mapData := MapData.new()

	if ResourceLoader.exists(_file_path + ".tres"):
		mapData = ResourceLoader.load(_file_path + ".tres", "", ResourceLoader.CACHE_MODE_REPLACE) as MapData
		if not mapData:
			print("how is that possible? ", _file_path + ".tres")
			print_stack()
			DirAccess.remove_absolute(_file_path + ".tres")

	if not mapData or not mapData.boundaryData.valid:
		if not FileAccess.file_exists(_file_path + ".xml"):
			print("failed to find .tres or xml: ", _file_path)
			return null

		#print("failed to find .tres, parsing xml: ", _file_path)
		mapData = parseXML(_file_path + ".xml")
		if not mapData or not mapData.boundaryData.valid:
			print("parsed xml but generated invalid boundary: ", _file_path)
			return null

		mapData.resource_path = _file_path + ".tres"
		assert(mapData.resource_path)
		#print("parsed xml, saving tile to file: ", mapData.resource_path)
		ResourceSaver.save(mapData)
	else:
		pass
		#print("found .tres: ", _file_path)

	$VBoxContainer/Label3.text = "finished parsing"
	var player_current_tilecoords := calculate_tile_coordinate_from_uv(calculate_uv_from_merc(mercatorProjection(lat, lon)))
	if mapData && mapData.boundaryData.valid:
		if player_current_tilecoords == mapData.boundaryData.tile_coordinate:
			currentMapData = mapData
		if !originMapData || !originMapData.boundaryData.valid:
			originMapData = mapData

	var found_tile: Tile = tiles_loaded.get(mapData.boundaryData.tile_coordinate)

	if not found_tile:
		found_tile = TILE_SCENE.instantiate()
		found_tile.name = str(mapData.boundaryData.tile_coordinate)
		found_tile.mapData = mapData
		tiles.add_child(found_tile)

		var offset := mercantorToGodotFromOrigin(mapData.boundaryData.center) / 2.0
		found_tile.global_position = offset

		tiles_loaded[mapData.boundaryData.tile_coordinate] = found_tile

		replaceMapScene(found_tile, mapData)
		placeCollectables(found_tile.collectables, mapData.streetMatrix)

	# force everything to update after we load a map
	# e.g this can trigger other maps to load/download
	# and this also causes the player position to update
	var player_vector := mercatorProjection(lat, lon)
	playerBounds(player_vector.x, player_vector.y)
	return mapData

#read the osm data from openstreetmap.org
func parseXML(_file_path: String) -> MapData:
	var matIDX: int = 0
	var listWaypoints: bool = false #if true, buildMatrix, streetMatrix, etc. add subsets from xzMatrix
	var listMember: bool = false #if true, buildMatrix, streetMatrix, etc. add subsets from memberMatrix

	var wayID_to_waypoint_dict = {}
	var wayID: int
	var xzMatrix: Array[PackedVector3Array] = [] #contains the waypoints from the tag <nd> in the loaded osm file
	var memberMatrix: Array[Array] = [[]] #contains the wayIDs from the tag <member> in the loaded osm file
	var xz_dict = {} #key: node ID, value: Vector3(x,0,z)  #x,z are lat,lon in Mercator projection
	var memberIDX: int = -1

	var mapData := MapData.new()

	var parser = XMLParser.new()
	var result := parser.open(_file_path)
	if result != OK:
		push_error(
			"failed to open map (%s) when parsing with error %s" % [_file_path, result]
		)
		return mapData

	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			var node_name = parser.get_node_name()
			if node_name == "node":
				var id_xml = int(parser.get_named_attribute_value_safe("id"))
				var lat_xml = float(parser.get_named_attribute_value_safe("lat"))
				var lon_xml = float(parser.get_named_attribute_value_safe("lon"))

				var vec := mercatorProjection(lat_xml, lon_xml)
				xz_dict[id_xml] = Vector3(
					vec.x - mapData.boundaryData.center.x,
					0,
					-(vec.y - mapData.boundaryData.center.y)
				)

			#if parsing the way nodes...
			elif node_name == "way":
				#store the key way id and the value ref in the wayID_to_waypoint_dict.
				# This allows us to look up <relation> tags
				if wayID >= 1:
					wayID_to_waypoint_dict[wayID] = xzMatrix[matIDX]
				matIDX = matIDX + 1
				xzMatrix.resize(matIDX + 1)
				wayID = int(parser.get_named_attribute_value_safe("id"))
				listWaypoints = true

			elif node_name == "nd":
				#...add the waypoints to xzMatrix
				var id := int(parser.get_named_attribute_value_safe("ref"))
				if xz_dict.has(id):
					xzMatrix[matIDX].append(xz_dict[id])
				else:
					print("found nd with id '%s' but it's not in our dict" % id)
				#then add subsets of xzMatrix to the buildMatrix, streetMatrix, etc.
			elif listWaypoints && node_name == "tag":
				var key := parser.get_named_attribute_value_safe("k")
				var value := parser.get_named_attribute_value_safe("v")
				if key == "building":
					mapData.buildMatrix.append(xzMatrix[matIDX])
				elif key == "highway":
					if value == "trunk":
						mapData.streetMatrix_trunk.append(xzMatrix[matIDX])
					elif value == "primary":
						mapData.streetMatrix_primary.append(xzMatrix[matIDX])
					elif value == "secondary":
						mapData.streetMatrix_secondary.append(xzMatrix[matIDX])
					elif (value == "pedestrian"
						|| value == "living_street"
						|| value == "footway"
						|| value == "bridleway"
						|| value == "steps"):
						mapData.streetMatrix_pedestrian.append(xzMatrix[matIDX])
					else:
						mapData.streetMatrix.append(xzMatrix[matIDX])
				elif key == "footway":
					# https://wiki.openstreetmap.org/wiki/Key:sidewalk
					# TODO: figure out how to parse this properly
					pass
				elif key == "waterway":
					mapData.waterMatrix.append(xzMatrix[matIDX])
				elif key == "railway":
					mapData.railMatrix.append(xzMatrix[matIDX])
			#the <member> nodes gather many wayIDs with the same tag, i.e. "water"
			#we list these wayIDs in the memberMatrix and append them to the appropiate subset Matrix, i.e. waterMatrix
			elif node_name == "relation":
				memberIDX = memberIDX + 1
				memberMatrix.resize(memberIDX + 1)
				listWaypoints = false
				listMember = true

			elif node_name == "member":
			#...add the way ids to the memberMatrix.
				memberMatrix[memberIDX].append(int(parser.get_named_attribute_value_safe("ref")))
			#if the current relation has a relevant tag, i.e. water,
			elif listMember && node_name == "tag":
				if parser.get_named_attribute_value_safe("v") == "water":
					for IDX in memberMatrix[memberIDX].size():
						var _wayID = memberMatrix[memberIDX][IDX]
						if wayID_to_waypoint_dict.has(_wayID):
							var _nodeIDs:PackedVector3Array = wayID_to_waypoint_dict[_wayID]
							mapData.waterMatrix.append(_nodeIDs)
						else:
							print("tried to add water way with ID %s, but we don't know about it" % _wayID)

			elif listMember && node_name == "tag":
				if parser.get_named_attribute_value_safe("k") == "railway":
					for IDX in memberMatrix[memberIDX].size():
						var _wayID = memberMatrix[memberIDX][IDX]
						if wayID_to_waypoint_dict.has(_wayID):
							var _nodeIDs:PackedVector3Array = wayID_to_waypoint_dict[_wayID]
							mapData.railMatrix.append(_nodeIDs)
						else:
							print("tried to add railway way with ID %s, but we don't know about it" % _wayID)

			elif node_name == "bounds":
				var minlat = float(parser.get_named_attribute_value_safe("minlat"))
				var maxlat = float(parser.get_named_attribute_value_safe("maxlat"))
				var minlon = float(parser.get_named_attribute_value_safe("minlon"))
				var maxlon = float(parser.get_named_attribute_value_safe("maxlon"))
				mapData.updateBoundaryData(minlat, maxlat, minlon, maxlon)

	return mapData

# handle the player exiting their current tile
# and loading/downloading new maps as a result
func playerBounds(x_merc: float, y_merc: float):
	var player_pos := mercantorToGodotFromOrigin(Vector2(x_merc, y_merc))

	if not originMapData.boundaryData.valid:
		player_pos.x = 0.0
		player_pos.z = 0.0

	var player_current_tilecoords := calculate_tile_coordinate_from_uv(calculate_uv_from_merc(Vector2(x_merc, y_merc)))
	if player_current_tilecoords != player_previous_tilecoords:
		currentMapData = null

	player_previous_tilecoords = player_current_tilecoords

	if tiles_loaded.has(player_current_tilecoords):
		currentMapData = tiles_loaded[player_current_tilecoords].mapData

	var needsNewMap := false
	if !currentMapData || currentMapData.boundaryData.valid == false:
		needsNewMap = true

	# TODO: if we are more than... 100 tiles? away, then reset the origin?
	Signals.playerPos.emit(player_pos, false)

	if !needsNewMap:
		$VBoxContainer/Label5.text = "player within boundary box! %d & %d tiles queued" % [tilecoords_queued_for_loading.size(), tilecoords_queued_for_download.size()]
		return

	$VBoxContainer/Label5.text = "out of bounds! %d & %d tiles queued" % [tilecoords_queued_for_loading.size(), tilecoords_queued_for_download.size()]

	load_or_download_tiles(lat, lon)

func create_and_update_path(packed_scene: PackedScene, parent: Node3D, data: PackedVector3Array):
	var scn := packed_scene.instantiate() as Path3D
	assert(scn)
	scn.curve.set_point_count(data.size())
	for i in data.size():
		scn.curve.set_point_position(i, data[i])
	parent.add_child(scn)


func replaceMapScene(mapNode: Node3D, mapData: MapData):
	while is_instance_valid(mapNode) && tilecoords_being_replaced.has(mapData.boundaryData.tile_coordinate):
		await get_tree().create_timer(0.25 + randf_range(0.25, 0.75)).timeout

	# tried to replace a tile which was unloaded
	if not is_instance_valid(mapNode):
		return
	#mapNode.visible = true
	tilecoords_being_replaced.append(mapData.boundaryData.tile_coordinate)

	#delete all path3D instances of the old map
	for way in mapNode.get_children():
		for path in way.get_children():
			# this shouldn't be possible anymore, right?
			assert(false)
			path.queue_free()

	var streetNode := mapNode.get_node("streets")
	assert(streetNode)
	var streets_trunk := mapNode.get_node("streets_trunk")
	assert(streets_trunk)
	var streets_primary := mapNode.get_node("streets_primary")
	assert(streets_primary)
	var streets_secondary := mapNode.get_node("streets_secondary")
	assert(streets_secondary)
	var streets_pedestrian := mapNode.get_node("streets_pedestrian")
	assert(streets_pedestrian)
	var buildingNode := mapNode.get_node("buildings")
	assert(buildingNode)
	var waterNode := mapNode.get_node("water")
	assert(waterNode)
	var railwayNode := mapNode.get_node("railway")
	assert(railwayNode)
	var boundaryNode := mapNode.get_node("boundary")
	assert(boundaryNode)

	var boundaryBox: float = mapData.boundaryData.get_half_length()
	var boundary: PackedVector3Array = [
		Vector3(boundaryBox, 0, boundaryBox),
		Vector3(-boundaryBox, 0, boundaryBox),
		Vector3(-boundaryBox, 0, -boundaryBox),
		Vector3(boundaryBox, 0, -boundaryBox),
		Vector3(boundaryBox, 0, boundaryBox)
	]

	create_and_update_path(BOUNDARY_SCENE, boundaryNode, boundary)

	for ways in mapData.streetMatrix.size():
		await get_tree().process_frame
		create_and_update_path(STREET_PATH_SCENE, streetNode, mapData.streetMatrix[ways])

	for ways in mapData.streetMatrix_trunk.size():
		await get_tree().process_frame
		create_and_update_path(STREET_PRIMARY_SCENE, streets_trunk, mapData.streetMatrix_trunk[ways])

	for ways in mapData.streetMatrix_primary.size():
		await get_tree().process_frame
		create_and_update_path(STREET_PRIMARY_SCENE, streets_primary, mapData.streetMatrix_primary[ways])

	for ways in mapData.streetMatrix_secondary.size():
		await get_tree().process_frame
		create_and_update_path(STREET_SECONDARY_SCENE, streets_secondary, mapData.streetMatrix_secondary[ways])

	for ways in mapData.streetMatrix_pedestrian.size():
		await get_tree().process_frame
		create_and_update_path(STREET_PEDESTRIAN_SCENE, streets_pedestrian, mapData.streetMatrix_pedestrian[ways])

	for ways in mapData.buildMatrix.size():
		await get_tree().process_frame
		create_and_update_path(BUILDING_SCENE, buildingNode, mapData.buildMatrix[ways])

	for ways in mapData.waterMatrix.size():
		await get_tree().process_frame
		create_and_update_path(WATER_SCENE, waterNode, mapData.waterMatrix[ways])

	for ways in mapData.railMatrix.size():
		await get_tree().process_frame
		create_and_update_path(RAILWAY_SCENE, railwayNode, mapData.railMatrix[ways])

	#mapNode.visible = true
	tilecoords_being_replaced.erase(mapData.boundaryData.tile_coordinate)

#TESTING: boundary box - teleport player out of boundary box
func _on_button_pressed():
	lat += 0.001
	load_or_download_tiles(lat, lon)

func placeCollectables(parent: Node3D, streetMatrix: Array[PackedVector3Array]) -> void:
	#place the collectables on the map. Use deterministic pseudo-random numbers.
	#The seed is the current date and time. This way, every user sees the same collectables on their device.
	var date = Time.get_datetime_string_from_system()
	#get date in the format YYYY-MM-DDTHH:MM:SS
	#cut date to YYYY-MM-DDTHH:M and use as seed for pseudo-random generator of collectable placement
	var seed_crystal = date.substr(0, 15)

	var random = RandomNumberGenerator.new()
	random.set_seed(int(seed_crystal))
	var randomInt

	$VBoxContainer/Label4.text = str(date)

	for ways in streetMatrix.size():
		for i in streetMatrix[ways].size():
			randomInt = random.randi_range(0,50)
			if(randomInt <= 3):
				var newCrystal = items[randomInt].instantiate()
				newCrystal.scale = Vector3(10,10,10)
				parent.add_child(newCrystal)
				newCrystal.position = streetMatrix[ways][i]
