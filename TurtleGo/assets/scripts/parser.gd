#@tool
class_name Parser extends Node3D

@onready var tiles := %tiles

#####################################
#######GPS using Praxismapper plugin
var gps_provider
var url_test := "https://api.openstreetmap.org/api/0.6/map?bbox=11.54,48.14,11.543,48.145" #link that downloads an xml file that can be drawn as a map
var url_base_official := "https://api.openstreetmap.org/api/0.6/map?bbox=" #official editing api of openstreetmap.org. This is only for testing purposes
#var url_base = "https://overpass-api.de/api/map?bbox=" #allows limited public use. Guideline: maximum of 1000 requests per day
var url: String
const decimalPlace := "%.5f" #the number of decimal places the latitude/longitude has in the api request. 5 decimal places loads a map of ~200mx200m around the player. 3 decimal places loads about 2000mx2000m

var filePath: String
var inflight_download_requests := 0
var new_mapRequest := true

##########################
###mercator calculation: transforms gps coordinates(lat,lon) into mercator coordinats(x,z)
var lat: float
var lon: float

const WORLD_RADIUS := 6378137.0

########
###calculate path3D
const streetPath3D = preload("res://assets/scenes/instances/streetPath3D.tscn")
const street_primary_Path3D = preload("res://assets/scenes/instances/street_primary_Path3D.tscn")
const street_secondary_Path3D = preload("res://assets/scenes/instances/street_secondary_Path3D.tscn")
const STREET_PEDESTRIAN_SCENE = preload("res://assets/scenes/instances/street_pedestrian.tscn")
const buildingPath3D = preload("res://assets/scenes/instances/buildingPath3D.tscn")
const waterPath3D = preload("res://assets/scenes/instances/waterPath3D.tscn")
const railPath3D = preload("res://assets/scenes/instances/railPath3D.tscn")
const TILE_SCENE = preload("res://assets/scenes/tile.tscn")
const BOUNDARY_SCENE = preload("res://assets/scenes/instances/boundary.tscn")

###########
###collectables on map
const crystal_blue = preload("res://assets/scenes/collectables/crystal_blue.tscn")
const crystal_green = preload("res://assets/scenes/collectables/crystal_green.tscn")
const crystal_orange = preload("res://assets/scenes/collectables/crystal_orange.tscn")
const crystal_pink = preload("res://assets/scenes/collectables/crystal_pink.tscn")
const crystal_purple = preload("res://assets/scenes/collectables/crystal_purple.tscn")
const crystal_yellow = preload("res://assets/scenes/collectables/crystal_yellow.tscn")
const items = [crystal_blue, crystal_green, crystal_pink, crystal_purple]
#######

###Testing
var counti = 0
var countk = 0
var countm = 0
var offline = true

var originMapData := MapData.new()
var currentMapData := MapData.new()
var already_replacing_map_scene := false

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
	var x := _lon * (PI/180.0) * WORLD_RADIUS
	var y := log(tan(_lat * (PI/180.0)/2.0 + PI/4.0)) * WORLD_RADIUS
	return Vector2(x, y)


# x = LON (horizontal)
# y = LAT (vertical)
# THIS IS NOT WEB - THIS IS GEOGRAPHIC
# i.e the Y starts at 0 at the bottom and goes up as it increases
static func inverseMercatorProjection(merc: Vector2) -> Vector2:
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
	filePath = "user://maps/myMap"
	var userOS = OS.get_name()

	if userOS == "Windows" || userOS == "Linux":
		print(OS.get_name())

		lat = 51.234286
		lon = -2.999235
		if has_map(lat, lon):
			var filename := get_tile_filename_for_gps(lat, lon)
			var success := parseAndReplaceMap(filename)
			assert(success)
	else:
		var success := parseAndReplaceMap(filePath)
		if not success:
			print("no file access")

		checkGPS()


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
	var _lat = location["latitude"]
	var _lon = location["longitude"]

	lat = _lat
	lon = _lon

	if currentMapData.boundaryData.valid:
		var vec := mercatorProjection(lat, lon)
		playerBounds(vec.x, vec.y)
	elif inflight_download_requests == 0 && new_mapRequest:
		downloadMap(lat, lon)
		print ("download new map")

	counti = counti+1
	$VBoxContainer/Label.text = str(counti, " lat: " , lat, ", lon:  " ,lon)


func get_tile_filename_for_gps(_lat: float, _lon: float) -> String:
	var merc := mercatorProjection(_lat, _lon)
	var uv := calculate_uv_from_merc(merc)
	var tile := calculate_tile_coordinate_from_uv(uv)
	return get_tile_filename_for_coords(tile)


func get_tile_filename_for_coords(coords: Vector2i) -> String:
	return "user://maps/%sx-%sy" % [coords.x, coords.y]


func has_map_xml(_lat: float, _lon: float):
	return FileAccess.file_exists(get_tile_filename_for_gps(_lat, _lon) + ".xml")


func has_map_resource(_lat: float, _lon: float):
	return ResourceLoader.exists(get_tile_filename_for_gps(_lat, _lon) + ".tres")


func has_map(_lat: float, _lon: float):
	return has_map_xml(_lat, _lon) || has_map_resource(_lat, _lon)


func downloadMap(_lat: float, _lon: float):
	if _lat == 0.0 && _lon == 0.0:
		push_error("tried to download a map for lat/lon of 0/0 - do we have a valid position yet?")
		assert(false)
		return

	# instead of downloading that exact map location, we want to download that "tile" instead
	# to do that, we convert the lat all the way to a tile coordinate and then back again
	# so that we can get the tile that this gps coordinate is actually in
	# note that this won't be centered on the player now, because the map center isn't based on the player position
	# but rather the center of that tile

	print("downloadMap - ", _lat, ", ", _lon)
	if inflight_download_requests != 0:
		assert(false)
		return

	#it takes a bit do download and calculate the new map. Within that time new_mapRequest might get called multiple times within a short span of time.
	#to avoid multiple downloads of the same map at the same time, set allow_new_mapRequest false until after the new map is drawn
	inflight_download_requests += 1
	#this map request has been fullfilled
	new_mapRequest = false

	var actual_merc := mercatorProjection(_lat, _lon)
	var actual_uv := calculate_uv_from_merc(actual_merc)
	var our_tile_coords := calculate_tile_coordinate_from_uv(actual_uv)
	var tile_bbox := calculate_tile_bounding_box_gps(our_tile_coords)
	var tile_center := tile_bbox.get_center()
	var _lat_min:String = decimalPlace % (tile_center.y - (tile_bbox.size.y / 2.0))
	var _lon_min:String = decimalPlace % (tile_center.x - (tile_bbox.size.x / 2.0))
	var _lat_max:String = decimalPlace % (tile_center.y + (tile_bbox.size.y / 2.0))
	var _lon_max:String = decimalPlace % (tile_center.x + (tile_bbox.size.x / 2.0))

	print("downloadMap - tile center is ", tile_center)

	url = url_base_official + _lon_min + "," + _lat_min + "," + _lon_max + "," + _lat_max
	print("REQUESTING ", url)
	filePath = get_tile_filename_for_coords(our_tile_coords) + ".xml"
	$HTTPRequest.set_download_file(filePath)
	$HTTPRequest.request(url)


func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
	#Signals.emit_signal("mapUpdated", filePath)
	print("REQUEST COMPLETED WITH CODE %d FOR FILE %s" % [response_code, filePath])
	countm += 1
	$VBoxContainer/Label2.text = str(countm, url)

	if response_code != 200:
		print("FAILED TO DOWNLOAD MAP")
		#allow new map downloads only after the new map has been downloaded, parsed and drawn
		#this prevents multiple requests at once
		await get_tree().create_timer(1.0).timeout
		inflight_download_requests -= 1
		return

	await get_tree().create_timer(1.0).timeout
	var success := parseAndReplaceMap(filePath.trim_suffix(".xml"))
	if !success:
		await get_tree().create_timer(1.0).timeout
		inflight_download_requests -= 1
		if inflight_download_requests == 0:
			downloadMap(lat, lon)
		return

	inflight_download_requests -= 1


func parseAndReplaceMap(_filePath: String) -> bool:
	var mapData := MapData.new()

	if ResourceLoader.exists(_filePath + ".tres"):
		mapData = ResourceLoader.load(_filePath + ".tres", "", ResourceLoader.CACHE_MODE_REPLACE) as MapData
		if not mapData:
			print("how is that possible? ", _filePath + ".tres")
			print_stack()

	if not mapData or not mapData.boundaryData.valid:
		if not FileAccess.file_exists(_filePath + ".xml"):
			print("failed to find .tres or xml: ", _filePath)
			return false

		print("failed to find .tres, parsing xml: ", _filePath)
		mapData = parseXML(_filePath + ".xml")
		if not mapData or not mapData.boundaryData.valid:
			print("parsed xml but generated invalid boundary: ", _filePath)
			return false

		if (mapData.buildMatrix.is_empty()
			&& mapData.railMatrix.is_empty()
			&& mapData.streetMatrix.is_empty()
			&& mapData.streetMatrix_primary.is_empty()
			&& mapData.streetMatrix_secondary.is_empty()
			&& mapData.waterMatrix.is_empty()):
				#print("parsed xml but generated empty matrices: ", _filePath)
				#push_error("parsed xml but generated empty matrices: ", _filePath)
				#DirAccess.remove_absolute(_filePath + ".xml")
				#if inflight_download_requests == 0:
					#downloadMap(lat, lon)
				return false

		mapData.resource_path = _filePath + ".tres"
		assert(mapData.resource_path)
		print("parsed xml, saving tile to file: ", mapData.resource_path)
		ResourceSaver.save(mapData)
	else:
		print("found .tres: ", _filePath)

	$VBoxContainer/Label3.text = "finished parsing"
	currentMapData = mapData
	if !originMapData || !originMapData.boundaryData.valid:
		originMapData = currentMapData

	var tilename := str(currentMapData.boundaryData.tile_coordinate)
	var found_tile: Tile
	for tile in tiles.get_children():
		if tile.name == tilename:
			found_tile = tile

	if not found_tile:
		found_tile = TILE_SCENE.instantiate()
		found_tile.name = tilename
		var offset := Vector2(
			(currentMapData.boundaryData.center.x - originMapData.boundaryData.center.x) / 2.0,
			(originMapData.boundaryData.center.y - currentMapData.boundaryData.center.y) / 2.0,
		)
		tiles.add_child(found_tile)
		found_tile.global_position = Vector3(offset.x, 0.0, offset.y)
		replaceMapScene(found_tile, currentMapData)
		placeCollectables(found_tile.collectables, currentMapData.streetMatrix)

	#replaceMapScene(previousTile_node, previousMapData)
	#placeCollectables(previousTile_node.collectables, previousMapData.streetMatrix)
	#previousTile_node.global_position = Vector3(offset.x, 0, offset.y)

	# now we've updated the map, let's tell the player where the new center is
	# so they can move there
	# and if they are outside the bounds after moving
	# then we will load the next map
	var player_vector := mercatorProjection(lat, lon)
	playerBounds(player_vector.x, player_vector.y)

	return true

#read the osm data from openstreetmap.org
func parseXML(_filePath: String) -> MapData:
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
	var result := parser.open(_filePath)
	if result != OK:
		push_error(
			"failed to open map (%s) when parsing with error %s" % [_filePath, result]
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

#center player on the map
#and check if player is within boundary box (else download new map)
func playerBounds(x_merc: float, y_merc: float):
	var player_pos := mercantorToGodotFromOrigin(Vector2(x_merc, y_merc))
	if not originMapData.boundaryData.valid:
		player_pos.x = 0.0
		player_pos.z = 0.0

	var player_distance_to_current_tile := Vector2(x_merc, y_merc) - currentMapData.boundaryData.center
	var boundary_half_length := absf(currentMapData.boundaryData.get_half_length())
	var needsNewMap := false
	if (absf(player_distance_to_current_tile.x) >= boundary_half_length
		|| absf(player_distance_to_current_tile.y) >= boundary_half_length
		|| currentMapData.boundaryData.valid == false):
		needsNewMap = true

	# if we are more than N tiles away from the current tile, force a teleport
	const N := 10.0
	var teleportPlayer := false
	if player_distance_to_current_tile.length() > absf(currentMapData.boundaryData.get_half_length()) * N:
		teleportPlayer = true
		print("TELEPORTING PLAYER AS WE ARE VERY FAR AWAY FOR A LERP")

	# TODO: if we are more than... 100 tiles? away, then reset the origin?

	Signals.playerPos.emit(player_pos, teleportPlayer)

	if !needsNewMap:
		$VBoxContainer/Label5.text = "player within boundary box"
		return

	$VBoxContainer/Label5.text = str(countk, "out of bounds!")

	var merc := mercatorProjection(lat, lon)
	var uv := calculate_uv_from_merc(merc)
	var tile := calculate_tile_coordinate_from_uv(uv)
	if tile == currentMapData.boundaryData.tile_coordinate:
		$VBoxContainer/Label5.text = "need new map but its already current: %s" % tile
		return

	if has_map(lat, lon):
		var file := get_tile_filename_for_gps(lat, lon)
		var success := parseAndReplaceMap(file)
		if success:
			$VBoxContainer/Label5.text = "loaded saved map %s" % file
			return

	if inflight_download_requests == 0:
		countk = countk +1
		new_mapRequest = true
		downloadMap(lat, lon)
		return

func create_and_update_path(packed_scene: PackedScene, parent: Node3D, data: PackedVector3Array):
	var scn := packed_scene.instantiate() as Path3D
	assert(scn)
	scn.curve.set_point_count(data.size())
	for i in data.size():
		scn.curve.set_point_position(i, data[i])
	parent.add_child(scn)


func replaceMapScene(mapNode: Node3D, mapData: MapData):
	while (already_replacing_map_scene):
		#mapNode.visible = false
		await get_tree().process_frame

	#mapNode.visible = true
	already_replacing_map_scene = true

	#delete all path3D instances of the old map
	for way in mapNode.get_children():
		for path in way.get_children():
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
		create_and_update_path(streetPath3D, streetNode, mapData.streetMatrix[ways])

	for ways in mapData.streetMatrix_trunk.size():
		await get_tree().process_frame
		create_and_update_path(street_primary_Path3D, streets_trunk, mapData.streetMatrix_trunk[ways])

	for ways in mapData.streetMatrix_primary.size():
		await get_tree().process_frame
		create_and_update_path(street_primary_Path3D, streets_primary, mapData.streetMatrix_primary[ways])

	for ways in mapData.streetMatrix_secondary.size():
		await get_tree().process_frame
		create_and_update_path(street_secondary_Path3D, streets_secondary, mapData.streetMatrix_secondary[ways])

	for ways in mapData.streetMatrix_pedestrian.size():
		await get_tree().process_frame
		create_and_update_path(STREET_PEDESTRIAN_SCENE, streets_pedestrian, mapData.streetMatrix_pedestrian[ways])

	for ways in mapData.buildMatrix.size():
		await get_tree().process_frame
		create_and_update_path(buildingPath3D, buildingNode, mapData.buildMatrix[ways])

	for ways in mapData.waterMatrix.size():
		await get_tree().process_frame
		create_and_update_path(waterPath3D, waterNode, mapData.waterMatrix[ways])

	for ways in mapData.railMatrix.size():
		await get_tree().process_frame
		create_and_update_path(railPath3D, railwayNode, mapData.railMatrix[ways])

	#mapNode.visible = true
	already_replacing_map_scene = false

#TESTING: boundary box - teleport player out of boundary box
func _on_button_pressed():
	if inflight_download_requests == 0:
		new_mapRequest = true
		lat += 0.001
		downloadMap(lat, lon)

func placeCollectables(parent: Node3D, streetMatrix: Array[PackedVector3Array]) -> void:
	#place the collectables on the map. Use deterministic pseudo-random numbers.
	#The seed is the current date and time. This way, every user sees the same collectables on their device.
	var date = Time.get_datetime_string_from_system()
	#get date in the format YYYY-MM-DDTHH:MM:SS
	#cut date to YYYY-MM-DDTHH:M and use as seed for pseudo-random generator of collectable placement
	var seed_crystal = date.substr(0,15)

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
