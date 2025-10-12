#@tool
class_name Parser extends Node3D

#####################################
#######GPS using Praxismapper plugin
var gps_provider
var url_test = "https://api.openstreetmap.org/api/0.6/map?bbox=11.54,48.14,11.543,48.145" #link that downloads an xml file that can be drawn as a map
#var url_base_official = "https://api.openstreetmap.org/api/0.6/map?bbox=" #official editing api of openstreetmap.org. This is only for testing purposes
var url_base = "https://overpass-api.de/api/map?bbox=" #allows limited public use. Guideline: maximum of 1000 requests per day
var url
const decimalPlace = "%.5f" #the number of decimal places the latitude/longitude has in the api request. 5 decimal places loads a map of ~200mx200m around the player. 3 decimal places loads about 2000mx2000m
const offset = 0.001 #offset from center of the map to the boundary
const boundaryDelimiter = 0.7 #the boundary map is 90% of the map size (calculated from x_max)

var filePath
var allow_new_mapRequest = true
var new_mapRequest = true

##########################
###mercator calculation: transforms gps coordinates(lat,lon) into mercator coordinats(x,z)
var lat:float
var lon:float

const r := 6378137.0

########
###calculate path3D
const streetPath3D = preload("res://assets/scenes/instances/streetPath3D.tscn")
const street_primary_Path3D = preload("res://assets/scenes/instances/street_primary_Path3D.tscn")
const street_secondary_Path3D = preload("res://assets/scenes/instances/street_secondary_Path3D.tscn")
const buildingPath3D = preload("res://assets/scenes/instances/buildingPath3D.tscn")
const waterPath3D = preload("res://assets/scenes/instances/waterPath3D.tscn")
const railPath3D = preload("res://assets/scenes/instances/railPath3D.tscn")

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

var currentMapData := MapData.new()

class BoundaryData:
	var minimum: Vector2
	var maximum: Vector2
	var center: Vector2
	var valid: bool = false

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

	func get_length() -> float:
		return (maximum.x - center.x) * boundaryDelimiter

class MapData:
	var streetMatrix: Array[PackedVector3Array] = [] #contains subset of xzMatrix: all street waypoints (all other streets and ways)
	var streetMatrix_primary: Array[PackedVector3Array] = [] #contains subset of xzMatrix: all primary street waypoints (big streets)
	var streetMatrix_secondary: Array[PackedVector3Array] = [] #contains subset of xzMatrix: all street waypoints (middle sized streets)
	var buildMatrix: Array[PackedVector3Array] = [] #contains subset of xzMatrix: all building waypoints
	var waterMatrix: Array[PackedVector3Array] = [] #contains subset of xzMatrix: all water waypoints
	var railMatrix: Array[PackedVector3Array] = [] #contains subset of xzMatrix: all railway waypoints
	var boundaryData := BoundaryData.new()

func _ready():
	Signals.connect("mapUpdated", parseXML)
	Signals.connect("enableGPS", checkGPS)
	$HTTPRequest.request_completed.connect(_on_request_completed)
	filePath = str(OS.get_user_data_dir() , "/myMap.xml")
	var userOS = OS.get_name()

	if userOS == "Windows" || userOS == "Linux":
		print(OS.get_name())
		#parseXML(filePath)
		# Parse the XML in the project for the first load
		# to make it faster

		lat = 47.376398
		lon = 8.539606

		parseAndReplaceMap("res://assets/osmFiles/myMap.xml")
		if allow_new_mapRequest:
			downloadMap(lat, lon)
	else:
		if FileAccess.file_exists(filePath):
			parseAndReplaceMap(filePath)

		else:
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
		playerBounds(vec.x,vec.y)

	counti = counti+1
	$VBoxContainer/Label.text = str(counti, " lat: " , lat, ", lon:  " ,lon)

	if allow_new_mapRequest && new_mapRequest:
		downloadMap(lat,lon)
		print ("download new map")

func downloadMap(_lat,_lon):
	print("downloadMap - ", _lat, ", ", _lon)
	if allow_new_mapRequest == false:
		assert(false)
		return

	#it takes a bit do download and calculate the new map. Within that time new_mapRequest might get called multiple times within a short span of time.
	#to avoid multiple downloads of the same map at the same time, set allow_new_mapRequest false until after the new map is drawn
	allow_new_mapRequest = false
	#this map request has been fullfilled
	new_mapRequest = false

	var _lat_min:String = decimalPlace % (_lat - offset)
	var _lon_min:String = decimalPlace % (_lon - offset)
	var _lat_max:String = decimalPlace % (_lat + offset)
	var _lon_max:String = decimalPlace % (_lon + offset)

	url = url_base + _lon_min + "," + _lat_min + "," + _lon_max + "," + _lat_max
	print("REQUESTING ", url)
	filePath = str(OS.get_user_data_dir() , "/myMap.xml")
	$HTTPRequest.set_download_file(filePath)
	$HTTPRequest.request(url)


func _on_request_completed(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
	#Signals.emit_signal("mapUpdated", filePath)
	print("REQUEST COMPLETED ", _response_code)
	countm += 1
	$VBoxContainer/Label2.text = str(countm, url)
	parseAndReplaceMap(filePath)
	#allow new map downloads only after the new map has been downloaded, parsed and drawn
	#this prevents multiple requests at once
	allow_new_mapRequest = true


func parseAndReplaceMap(_filePath: String) -> void:
	var mapData := parseXML(_filePath)
	if not mapData.boundaryData.valid:
		return

	$VBoxContainer/Label3.text = "finished parsing"
	currentMapData = mapData
	replaceMapScene($paths, mapData)
	placeCollectables(mapData.streetMatrix)

	var player_vector := mercatorProjection(lat, lon)
	playerBounds(player_vector.x, player_vector.y)

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
		assert(false)
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
				#store the key way id and the value ref in the wayID_to_waypoint_dict. This allows us to look up <relation> tags
				if wayID >= 1:
					wayID_to_waypoint_dict[wayID] = xzMatrix[matIDX]
				matIDX = matIDX + 1
				xzMatrix.resize(matIDX + 1)
				wayID = int(parser.get_named_attribute_value_safe("id"))
				listWaypoints = true

			elif node_name == "nd":
				#...add the waypoints to xzMatrix
				xzMatrix[matIDX].append(xz_dict[int(parser.get_named_attribute_value_safe("ref"))])
				#then add subsets of xzMatrix to the buildMatrix, streetMatrix, etc.
			elif listWaypoints && node_name == "tag":
				if parser.get_named_attribute_value_safe("k") == "building":
					mapData.buildMatrix.append(xzMatrix[matIDX])
				elif parser.get_named_attribute_value_safe("k") == "highway":
					if parser.get_named_attribute_value_safe("v") == "primary":
						mapData.streetMatrix_primary.append(xzMatrix[matIDX])
					elif parser.get_named_attribute_value_safe("v") == "secondary":
						mapData.streetMatrix_secondary.append(xzMatrix[matIDX])
					else:
						mapData.streetMatrix.append(xzMatrix[matIDX])
				elif parser.get_named_attribute_value_safe("k") == "waterway":
					mapData.waterMatrix.append(xzMatrix[matIDX])
				elif parser.get_named_attribute_value_safe("k") == "railway":
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
						var _nodeIDs:PackedVector3Array = wayID_to_waypoint_dict[_wayID]
						mapData.waterMatrix.append(_nodeIDs)

			elif listMember && node_name == "tag":
				if parser.get_named_attribute_value_safe("k") == "railway":
					for IDX in memberMatrix[memberIDX].size():
						var _wayID = memberMatrix[memberIDX][IDX]
						var _nodeIDs:PackedVector3Array = wayID_to_waypoint_dict[_wayID]
						mapData.railMatrix.append(_nodeIDs)

			elif node_name == "bounds":
				var minlat = float(parser.get_named_attribute_value_safe("minlat"))
				var maxlat = float(parser.get_named_attribute_value_safe("maxlat"))
				var minlon = float(parser.get_named_attribute_value_safe("minlon"))
				var maxlon = float(parser.get_named_attribute_value_safe("maxlon"))

				# when we update the boundary box we also update the player again
				#...center player on the map
				mapData.boundaryData = calculateBoundaryData(minlat, maxlat, minlon, maxlon)

	return mapData

func calculateBoundaryData(_minlat, _maxlat, _minlon, _maxlon) -> BoundaryData:
	var minimum := mercatorProjection(_minlat, _minlon)
	var maximum := mercatorProjection(_maxlat, _maxlon)
	var center := Vector2(
		(minimum.x + maximum.x) / 2.0,
		(minimum.y + maximum.y) / 2.0,
	)

	var boundaryData := BoundaryData.new(minimum, maximum, center)
	assert(boundaryData.valid)

	return boundaryData

func mercatorProjection(_lat: float, _lon: float) -> Vector2:
	var x := _lon * (PI/180.0) * r 							#Mercator(lon)
	var z := log(tan(_lat * (PI/180.0)/2.0 + PI/4.0)) * r 	#Mercator(lat)

	return Vector2(x,z)

#center player on the map
#and check if player is within boundary box (else download new map)
func playerBounds(_x, _z):
	var player_x = _x - currentMapData.boundaryData.center.x
	var player_z = -(_z - currentMapData.boundaryData.center.y)

	var _playerPos = Vector3(player_x , 0, player_z)
	Signals.playerPos.emit(_playerPos)

	if abs(player_x) >= abs(currentMapData.boundaryData.get_length()):
		if allow_new_mapRequest == true:
			countk = countk +1
			new_mapRequest = true
			downloadMap(lat,lon)
			$VBoxContainer/Label5.text = str(countk, "out of x bounds!")
			print_debug("out of bounds")

	elif abs(player_z) >= abs(currentMapData.boundaryData.get_length()):
		if allow_new_mapRequest == true:
			countk = countk +1
			new_mapRequest = true
			downloadMap(lat,lon)
			$VBoxContainer/Label5.text = str(countk,"out of z bounds!")
	else:
		$VBoxContainer/Label5.text = "player within boundary box"

func replaceMapScene(mapNode: Node3D, mapData: MapData):
	var newPath3D
	#delete all path3D instances of the old map
	for way in 	mapNode.get_children():
		for path in way.get_children():
			path.queue_free()

	##calculate all ways at once, including water, boundaries, buildings, etc
	#for ways in xzMatrix.size():
		#newPath3D = waterPath3D.instantiate()
		#$paths/other.add_child(newPath3D)
		#newPath3D.curve = Curve3D.new()
		#for i in xzMatrix[ways].size():
			#newPath3D.curve.add_point(xzMatrix[ways][i])

	for ways in mapData.streetMatrix.size():
		newPath3D = streetPath3D.instantiate()
		mapNode.get_node("streets").add_child(newPath3D)
		newPath3D.curve = Curve3D.new()
		for i in mapData.streetMatrix[ways].size():
			newPath3D.curve.add_point(mapData.streetMatrix[ways][i])

	for ways in mapData.streetMatrix_primary.size():
		newPath3D = street_primary_Path3D.instantiate()
		mapNode.get_node("streets").add_child(newPath3D)
		newPath3D.curve = Curve3D.new()
		for i in mapData.streetMatrix_primary[ways].size():
			newPath3D.curve.add_point(mapData.streetMatrix_primary[ways][i])

	for ways in mapData.streetMatrix_secondary.size():
		newPath3D = street_secondary_Path3D.instantiate()
		mapNode.get_node("streets").add_child(newPath3D)
		newPath3D.curve = Curve3D.new()
		for i in mapData.streetMatrix_secondary[ways].size():
			newPath3D.curve.add_point(mapData.streetMatrix_secondary[ways][i])

	for ways in mapData.buildMatrix.size():
		newPath3D = buildingPath3D.instantiate()
		mapNode.get_node("buildings").add_child(newPath3D)
		newPath3D.curve = Curve3D.new()
		for i in mapData.buildMatrix[ways].size():
			newPath3D.curve.add_point(mapData.buildMatrix[ways][i])

	for ways in mapData.waterMatrix.size():
		newPath3D = waterPath3D.instantiate()
		mapNode.get_node("water").add_child(newPath3D)
		newPath3D.curve = Curve3D.new()
		for i in mapData.waterMatrix[ways].size():
			newPath3D.curve.add_point(mapData.waterMatrix[ways][i])

	for ways in mapData.railMatrix.size():
		newPath3D = railPath3D.instantiate()
		mapNode.get_node("railway").add_child(newPath3D)
		newPath3D.curve = Curve3D.new()
		for i in mapData.railMatrix[ways].size():
			newPath3D.curve.add_point(mapData.railMatrix[ways][i])

	#draw boundary box. If player exits boundary box, a new map is downloaded
	var boundaryBox: float = mapData.boundaryData.get_length()
	var boundary:PackedVector3Array = [
		Vector3(boundaryBox,0,boundaryBox),
		Vector3(-boundaryBox,0,boundaryBox),
		Vector3(-boundaryBox,0,-boundaryBox),
		Vector3(boundaryBox,0,-boundaryBox),
		Vector3(boundaryBox,0,boundaryBox)
	]

	newPath3D = waterPath3D.instantiate()
	mapNode.get_node("boundary").add_child(newPath3D)
	newPath3D.curve = Curve3D.new()
	for i in boundary.size():
			newPath3D.curve.add_point(boundary[i])

#TESTING: boundary box - teleport player out of boundary box
func _on_button_pressed():
	if allow_new_mapRequest == true:
		new_mapRequest = true
		lat += 0.001
		downloadMap(lat, lon)

func placeCollectables(streetMatrix: Array[PackedVector3Array]) -> void:
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
				$collectables.add_child(newCrystal)
				newCrystal.position = streetMatrix[ways][i]
