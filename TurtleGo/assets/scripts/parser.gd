#@tool
extends Node3D

#####################################
#######GPS using Praxismapper plugin
var gps_provider
var url_test = "https://api.openstreetmap.org/api/0.6/map?bbox=11.54,48.14,11.543,48.145" #link that downloads an xml file that can be drawn as a map
#var url_base_official = "https://api.openstreetmap.org/api/0.6/map?bbox=" #official editing api of openstreetmap.org. This is only for testing purposes
var url_base = "https://overpass-api.de/api/map?bbox=" #allows limited public use. Guideline: maximum of 1000 requests per day
var url
var decimalPlace = "%.5f" #the number of decimal places the latitude/longitude has in the api request. 5 decimal places loads a map of ~200mx200m around the player. 3 decimal places loads about 2000mx2000m
var offset = 0.001 #offset from center of the map to the boundary
var boundaryBox:float  #a boundary within the map. If the player crosses it, a new map is loaded
var boundaryDelimiter = 0.7 #the boundary map is 90% of the map size (calculated from x_max)

var filePath
var downloadedMap = false
var allow_new_mapRequest = true
var new_mapRequest = true

##########################
###mercator calculation: transforms gps coordinates(lat,lon) into mercator coordinats(x,z)
var lat:float
var lon:float
#min/max coordinates of the downloaded osm file
var x_min: float
var x_max: float
var z_min:float
var z_max: float
var x_center:float # x_center = (x_min+x_max)/2
var z_center:float

#variables for Mercator projection
var x: float	 #Mercator(lon)
var z: float  #Mercator(lat)
var r = 6378137.0

##################################
#####parse osm file
var xzMatrix:Array[PackedVector3Array] = [[]] #contains the waypoints from the tag <nd> in the loaded osm file
var streetMatrix:Array[PackedVector3Array] = [[]] #contains subset of xzMatrix: all street waypoints (all other streets and ways)
var streetMatrix_primary:Array[PackedVector3Array] = [[]] #contains subset of xzMatrix: all primary street waypoints (big streets)
var streetMatrix_secondary:Array[PackedVector3Array] = [[]] #contains subset of xzMatrix: all street waypoints (middle sized streets)
var buildMatrix:Array[PackedVector3Array] = [[]] #contains subset of xzMatrix: all building waypoints
var waterMatrix:Array[PackedVector3Array] = [[]] #contains subset of xzMatrix: all water waypoints
var railMatrix:Array[PackedVector3Array] = [[]] #contains subset of xzMatrix: all railway waypoints
var memberMatrix:Array[Array] = [[]] #contains the wayIDs from the tag <member> in the loaded osm file

var xz_dict = {} #key: node ID, value: Vector3(x,0,z)  #x,z are lat,lon in Mercator projection
var wayID_to_waypoint_dict = {}

var matIDX:int = 0
var memberIDX:int = -1
var wayID:int

var listWaypoints:bool = false #if true, buildMatrix, streetMatrix, etc. add subsets from xzMatrix
var listMember:bool = false #if true, buildMatrix, streetMatrix, etc. add subsets from memberMatrix

########
###calculate path3D
var streetPath3D = preload("res://assets/scenes/instances/streetPath3D.tscn")
var street_primary_Path3D = preload("res://assets/scenes/instances/street_primary_Path3D.tscn")
var street_secondary_Path3D = preload("res://assets/scenes/instances/street_secondary_Path3D.tscn")
var buildingPath3D = preload("res://assets/scenes/instances/buildingPath3D.tscn")
var waterPath3D = preload("res://assets/scenes/instances/waterPath3D.tscn")
var railPath3D = preload("res://assets/scenes/instances/railPath3D.tscn")
var newPath3D

###########
###collectables on map
var crystal_blue = preload("res://assets/scenes/collectables/crystal_blue.tscn")
var crystal_green = preload("res://assets/scenes/collectables/crystal_green.tscn")
var crystal_orange = preload("res://assets/scenes/collectables/crystal_orange.tscn")
var crystal_pink = preload("res://assets/scenes/collectables/crystal_pink.tscn")
var crystal_purple = preload("res://assets/scenes/collectables/crystal_purple.tscn")
var crystal_yellow = preload("res://assets/scenes/collectables/crystal_yellow.tscn")
var items = [crystal_blue, crystal_green, crystal_pink, crystal_purple]
#######
###Testing
var counti = 0
var countk = 0
var countm = 0
var offline = true

func _ready():
	Signals.connect("mapUpdated", parseXML)
	Signals.connect("enableGPS", checkGPS)
	$HTTPRequest.request_completed.connect(_on_request_completed)
	filePath = str(OS.get_user_data_dir() , "/myMap.xml")
	var userOS = OS.get_name()

	if userOS == "Windows" || userOS == "Linux":
		print(OS.get_name())
		#parseXML(filePath)

		downloadMap(47.37804,8.53998)
		parseXML("res://assets/osmFiles/myMap.xml")
	else:
		if FileAccess.file_exists(filePath):
			parseXML(filePath)

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
	mercatorProjection(0,lat,lon)

	counti = counti+1
	$VBoxContainer/Label.text = str(counti, " lat: " , lat, ", lon:  " ,lon)

	if allow_new_mapRequest && new_mapRequest:
		downloadMap(lat,lon)
		print ("download new map")

func downloadMap(_lat,_lon):
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
	filePath = str(OS.get_user_data_dir() , "/myMap.xml")
	$HTTPRequest.set_download_file(filePath)
	$HTTPRequest.request(url)

func _on_request_completed(result, response_code, headers, body):
	#Signals.emit_signal("mapUpdated", filePath)

	countm += 1
	$VBoxContainer/Label2.text = str(countm, url)
	parseXML(filePath)

func clearParsedData():
	xzMatrix.clear()
	buildMatrix.clear()
	streetMatrix.clear()
	streetMatrix_primary.clear()
	streetMatrix_secondary.clear()
	waterMatrix.clear()
	memberMatrix.clear()
	wayID_to_waypoint_dict.clear()
	wayID = 0

#read the osm data from openstreetmap.org
func parseXML(_filePath):

	clearParsedData()
	var parser = XMLParser.new()
	parser.open(_filePath)
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			var node_name = parser.get_node_name()
			if node_name == "node":
				var id = int(parser.get_named_attribute_value_safe("id"))
				var _lat = float(parser.get_named_attribute_value_safe("lat"))
				var _lon = float(parser.get_named_attribute_value_safe("lon"))
				mercatorProjection(id, _lat, _lon)

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
					buildMatrix.append(xzMatrix[matIDX])
				elif parser.get_named_attribute_value_safe("k") == "highway":
					if parser.get_named_attribute_value_safe("v") == "primary":
						streetMatrix_primary.append(xzMatrix[matIDX])
					elif parser.get_named_attribute_value_safe("v") == "secondary":
						streetMatrix_secondary.append(xzMatrix[matIDX])
					else:
						streetMatrix.append(xzMatrix[matIDX])
				elif parser.get_named_attribute_value_safe("k") == "waterway":
					waterMatrix.append(xzMatrix[matIDX])
				elif parser.get_named_attribute_value_safe("k") == "railway":
					railMatrix.append(xzMatrix[matIDX])
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
						waterMatrix.append(_nodeIDs)

			elif listMember && node_name == "tag":
				if parser.get_named_attribute_value_safe("k") == "railway":
					for IDX in memberMatrix[memberIDX].size():
						var _wayID = memberMatrix[memberIDX][IDX]
						var _nodeIDs:PackedVector3Array = wayID_to_waypoint_dict[_wayID]
						railMatrix.append(_nodeIDs)

			elif node_name == "bounds":
				var minlat = float(parser.get_named_attribute_value_safe("minlat"))
				var maxlat = float(parser.get_named_attribute_value_safe("maxlat"))
				var minlon = float(parser.get_named_attribute_value_safe("minlon"))
				var maxlon = float(parser.get_named_attribute_value_safe("maxlon"))
				minmaxCoordinates(minlat, maxlat, minlon, maxlon)
	$VBoxContainer/Label3.text = "finished parsing"
	calcCurve3D()

func mercatorCalc(_lat, _lon):
	var _x = _lon * (PI/180) * r
	var _z = log(tan(_lat * (PI/180)/2 + PI/4)) * r
	var _vec = Vector3(_x,0,_z)
	return [_vec]

func minmaxCoordinates(_minlat, _maxlat, _minlon, _maxlon):
	x_min = _minlon * (PI/180) * r
	x_max = _maxlon * (PI/180) * r
	z_min = log(tan(_minlat * (PI/180)/2 + PI/4)) * r
	z_max = log(tan(_maxlat * (PI/180)/2 + PI/4)) * r

	x_center = (x_min + x_max) /2
	z_center = (z_min + z_max) /2
	boundaryBox = (x_max - x_center) * boundaryDelimiter

	#print_debug("boundary box: ", boundaryBox)

func mercatorProjection(_id, _lat, _lon):
	x = _lon * (PI/180) * r
	z = log(tan(_lat * (PI/180)/2 + PI/4)) * r

	# if x&z are player coordinates...
	if(_id == 0):
		#...and the center of the map has been calculated from the osm xml file...
		if x_max  >= 1:
			#...center player on the map
			playerBounds(x,z)
	else:
		xz_dict[_id] = Vector3(x - x_center,0,-(z - z_center))

#center player on the map
#and check if player is within boundary box (else download new map)
func playerBounds(_x, _z):
	var player_x = _x - x_center
	var player_z = -(_z - z_center)
	var _playerPos = Vector3(player_x , 0, player_z)
	Signals.emit_signal("playerPos", _playerPos)

	if abs(player_x) >= abs(boundaryBox):
		if allow_new_mapRequest == true:
			countk = countk +1
			new_mapRequest = true
			downloadMap(lat,lon)
			$VBoxContainer/Label5.text = str(countk, "out of x bounds!")
			print_debug("out of bounds")

	elif abs(player_z) >= abs(boundaryBox):
		if allow_new_mapRequest == true:
			countk = countk +1
			new_mapRequest = true
			downloadMap(lat,lon)
			$VBoxContainer/Label5.text = str(countk,"out of z bounds!")
	else:
		$VBoxContainer/Label5.text = "player within boundary box"

func calcCurve3D():
	#delete all path3D instances of the old map
	for way in 	$paths.get_children():
		for path in way.get_children():
			path.queue_free()

	##calculate all ways at once, including water, boundaries, buildings, etc
	#for ways in xzMatrix.size():
		#newPath3D = waterPath3D.instantiate()
		#$paths/other.add_child(newPath3D)
		#newPath3D.curve = Curve3D.new()
		#for i in xzMatrix[ways].size():
			#newPath3D.curve.add_point(xzMatrix[ways][i])

	for ways in streetMatrix.size():
		newPath3D = streetPath3D.instantiate()
		$paths/streets.add_child(newPath3D)
		newPath3D.curve = Curve3D.new()
		for i in streetMatrix[ways].size():
			newPath3D.curve.add_point(streetMatrix[ways][i])

	for ways in streetMatrix_primary.size():
		newPath3D = street_primary_Path3D.instantiate()
		$paths/streets.add_child(newPath3D)
		newPath3D.curve = Curve3D.new()
		for i in streetMatrix_primary[ways].size():
			newPath3D.curve.add_point(streetMatrix_primary[ways][i])

	for ways in streetMatrix_secondary.size():
		newPath3D = street_secondary_Path3D.instantiate()
		$paths/streets.add_child(newPath3D)
		newPath3D.curve = Curve3D.new()
		for i in streetMatrix_secondary[ways].size():
			newPath3D.curve.add_point(streetMatrix_secondary[ways][i])

	for ways in buildMatrix.size():
		newPath3D = buildingPath3D.instantiate()
		$paths/buildings.add_child(newPath3D)
		newPath3D.curve = Curve3D.new()
		for i in buildMatrix[ways].size():
			newPath3D.curve.add_point(buildMatrix[ways][i])

	for ways in waterMatrix.size():
		newPath3D = waterPath3D.instantiate()
		$paths/water.add_child(newPath3D)
		newPath3D.curve = Curve3D.new()
		for i in waterMatrix[ways].size():
			newPath3D.curve.add_point(waterMatrix[ways][i])

	for ways in railMatrix.size():
		newPath3D = railPath3D.instantiate()
		$paths/railway.add_child(newPath3D)
		newPath3D.curve = Curve3D.new()
		for i in railMatrix[ways].size():
			newPath3D.curve.add_point(railMatrix[ways][i])

	#draw boundary box. If player exits boundary box, a new map is downloaded
	var boundary:PackedVector3Array = [Vector3(boundaryBox,0,boundaryBox),Vector3(-boundaryBox,0,boundaryBox), Vector3(-boundaryBox,0,-boundaryBox), Vector3(boundaryBox,0,-boundaryBox),Vector3(boundaryBox,0,boundaryBox)]
	newPath3D = waterPath3D.instantiate()
	$paths/boundary.add_child(newPath3D)
	newPath3D.curve = Curve3D.new()
	for i in boundary.size():
			newPath3D.curve.add_point(boundary[i])

	placeCollectables()
	#allow new map downloads only after the new map has been downloaded, parsed and drawn
	#this prevents multiple requests at once
	allow_new_mapRequest = true

#TESTING: boundary box - teleport player out of boundary box
func _on_button_pressed():
	if allow_new_mapRequest == true:
		new_mapRequest = true
		downloadMap(47.37804,8.53998)

func placeCollectables():
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
