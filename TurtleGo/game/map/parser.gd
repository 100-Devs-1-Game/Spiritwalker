class_name Parser extends Node3D

#read the osm data from openstreetmap.org
func parse_xml(filepath: String) -> MapData:
	var matIDX: int = 0
	var listWaypoints: bool = false #if true, buildMatrix, streetMatrix, etc. add subsets from xzMatrix
	var listMember: bool = false #if true, buildMatrix, streetMatrix, etc. add subsets from memberMatrix

	var wayID_to_waypoint_dict = {}
	var wayID: int
	var xzMatrix: Array[PackedVector3Array] = [] #contains the waypoints from the tag <nd> in the loaded osm file
	var memberMatrix: Array[Array] = [[]] #contains the wayIDs from the tag <member> in the loaded osm file
	var xz_dict = {} #key: node ID, value: Vector3(x,0,z)  #x,z are lat,lon in Mercator projection
	var memberIDX: int = -1

	var map_data := MapData.new()

	var parser = XMLParser.new()
	var result := parser.open(filepath)
	if result != OK:
		push_error(
			"failed to open map (%s) when parsing with error %s" % [filepath, result]
		)

		if result == Error.ERR_FILE_CORRUPT:
			DirAccess.remove_absolute(filepath)

		return map_data

	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			var node_name = parser.get_node_name()
			if node_name == "node":
				var id_xml = int(parser.get_named_attribute_value_safe("id"))
				var lat_xml = float(parser.get_named_attribute_value_safe("lat"))
				var lon_xml = float(parser.get_named_attribute_value_safe("lon"))

				var vec := Maths.mercatorProjection(lat_xml, lon_xml)
				
				xz_dict[id_xml] = Vector3(
					vec.x - map_data.boundaryData.center.x,
					0,
					map_data.boundaryData.center.y - vec.y,
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
					if Debug.PARSER_XML:
						print("found nd with id '%s' but it's not in our dict" % id)
				#then add subsets of xzMatrix to the buildMatrix, streetMatrix, etc.
			elif listWaypoints && node_name == "tag":
				var key := parser.get_named_attribute_value_safe("k")
				var value := parser.get_named_attribute_value_safe("v")
				if key == "building":
					map_data.buildMatrix.append(xzMatrix[matIDX])
				elif key == "highway":
					if value == "trunk":
						map_data.streetMatrix_trunk.append(xzMatrix[matIDX])
					elif value == "primary":
						map_data.streetMatrix_primary.append(xzMatrix[matIDX])
					elif value == "secondary":
						map_data.streetMatrix_secondary.append(xzMatrix[matIDX])
					elif (value == "pedestrian"
						|| value == "living_street"
						|| value == "footway"
						|| value == "bridleway"
						|| value == "steps"):
						map_data.streetMatrix_pedestrian.append(xzMatrix[matIDX])
					else:
						map_data.streetMatrix.append(xzMatrix[matIDX])
				elif key == "footway":
					# https://wiki.openstreetmap.org/wiki/Key:sidewalk
					# TODO: figure out how to parse this properly
					pass
				elif key == "waterway" || (key == "natural" && value == "coastline"):
					map_data.waterMatrix.append(xzMatrix[matIDX])
				elif key == "railway" && value != "razed":
					map_data.railMatrix.append(xzMatrix[matIDX])
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
							map_data.waterMatrix.append(_nodeIDs)
						else:
							if Debug.PARSER_XML:
								print("tried to add water way with ID %s, but we don't know about it" % _wayID)

			elif listMember && node_name == "tag":
				var key := parser.get_named_attribute_value_safe("k")
				var value := parser.get_named_attribute_value_safe("v")
				if key == "railway" && value != "razed":
					for IDX in memberMatrix[memberIDX].size():
						var _wayID = memberMatrix[memberIDX][IDX]
						if wayID_to_waypoint_dict.has(_wayID):
							var _nodeIDs:PackedVector3Array = wayID_to_waypoint_dict[_wayID]
							map_data.railMatrix.append(_nodeIDs)
						else:
							if Debug.PARSER_XML:
								print("tried to add railway way with ID %s, but we don't know about it" % _wayID)

			elif node_name == "bounds":
				var minlat = float(parser.get_named_attribute_value_safe("minlat"))
				var maxlat = float(parser.get_named_attribute_value_safe("maxlat"))
				var minlon = float(parser.get_named_attribute_value_safe("minlon"))
				var maxlon = float(parser.get_named_attribute_value_safe("maxlon"))
				map_data.updateBoundaryData(minlat, maxlat, minlon, maxlon)

	return map_data
