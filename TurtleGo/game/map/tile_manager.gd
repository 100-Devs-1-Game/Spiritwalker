class_name TileManager extends Node3D

# README
# - this handles all of the tiling logic for different parts of the map
# - check the autoloads constants.gd, maths.gd, utils.gd, etc. for some related code that this will use
# - a lot of this could be cleaned up more and split out, but this should be a good starting point

@export var parser: Parser
@export var download_manager: DownloadManager
@export var gps_manager: GpsManager

var tilecoords_queued_for_download: Array[Vector2i]
var tilecoords_queued_for_loading: Array[Vector2i]

# these tiles are either being loaded or unloaded
var tilecoords_being_replaced: Array[Vector2i]

# these tiles are either waiting to load or are still loading
var tiles_waiting_to_load: int

# these tiles are either fully loaded or still being loaded
# tiles_loaded.size() - tiles_waiting_to_load = total fully loaded tiles.. ish
# the Tile contains the MapData associated with it
var tiles_loaded: Dictionary[Vector2i, Tile]

# the first map we load is considered the "0, 0" origin for all other maps
# this is used to convert from mercantor units to "godot units"
# e.g to avoid all godot positions being in the millions
var origin_map_data := MapData.new()

# the current map that the player is in, or null if we don't have it loaded yet
var current_map_data := MapData.new()

@onready var tiles := %Tiles


func _ready() -> void:
	assert(parser)
	assert(download_manager)
	assert(gps_manager)

	Signals.download_succeeded.connect(_on_map_download_succeeded)

	await gps_manager.wait_for_first_gps_position()
	start()


func start() -> void:
	# infinitely try and download our (and neighbouring) tiles
	# this is... a fail safe, but it shouldn't be necessary
	regularly_load_tiles()

	# also keep unloading tiles that are far away from the player
	regularly_unload_tiles()

	regularly_download_queued_tiles()

	for i in Constants.MAXIMUM_TILES_TO_LOAD_AT_ONCE:
		regularly_load_queued_tiles()
		await get_tree().create_timer(0.1).timeout


func _on_map_download_succeeded(filepath: String, _gps: Vector2, coords: Vector2i) -> void:
	Maths.check_conversion(coords)

	var map_data := await load_map(filepath.trim_suffix(".xml"))
	if !map_data:
		if not tilecoords_queued_for_download.has(coords):
			print("FAILED TO PARSE DOWNLOADED MAP. REATTEMPTING SOON")
			tilecoords_queued_for_download.append(coords)
		return

	if Debug.TILE_MANAGER >= Debug.Level.Some:
		print(
			(
				"LOADED TILE AFTER DOWNLOAD: %sx-%sy (%d & %d remaining)"
				% [
					map_data.boundaryData.tile_coordinate.x,
					map_data.boundaryData.tile_coordinate.y,
					tilecoords_queued_for_loading.size(),
					tilecoords_queued_for_download.size(),
				]
			)
		)

	if coords != map_data.boundaryData.tile_coordinate:
		push_warning(
			(
				"we downloaded the tile %s but we thought we were downloading the tile %s? how?"
				% [map_data.boundaryData.tile_coordinate, coords]
			)
		)
		assert(false)

	if Debug.TILE_MANAGER >= Debug.Level.All:
		print(
			(
				"erasing tile from loading/downloading queues, now that is loaded after the download: %s"
				% map_data.boundaryData.tile_coordinate
			)
		)
	tilecoords_queued_for_loading.erase(map_data.boundaryData.tile_coordinate)
	tilecoords_queued_for_download.erase(map_data.boundaryData.tile_coordinate)


func mercator_to_godot_from_origin(merc: Vector2) -> Vector3:
	if not origin_map_data or not origin_map_data.boundaryData.valid:
		return Vector3(0.0, 0.0, 0.0)

	return Vector3(
		merc.x - origin_map_data.boundaryData.center.x,
		0.0,
		origin_map_data.boundaryData.center.y - merc.y,
	)


func regularly_load_tiles():
	while true:
		await (
			get_tree()
			. create_timer(Constants.LOAD_OR_DOWNLOAD_NEIGHBOURING_TILES_EVERY_X_SECONDS)
			. timeout
		)
		var tiles_added := await load_or_download_tiles(gps_manager.last_known_gps_position)
		if tiles_added:
			print("FAILSAFE ADDED %d TILES" % tiles_added)


func regularly_unload_tiles():
	while true:
		await get_tree().create_timer(Constants.UNLOAD_DISTANT_TILES_EVERY_X_SECONDS).timeout
		if not current_map_data or not current_map_data.boundaryData.valid:
			continue

		var distant_tiles: Array[Vector2i]
		for coords in tiles_loaded:
			if tile_is_distant(coords) && not tilecoords_being_replaced.has(coords):
				distant_tiles.append(coords)

		for distant_tile in distant_tiles:
			unload_tile(distant_tile)


func regularly_download_queued_tiles() -> void:
	while true:
		await get_tree().create_timer(Constants.DOWNLOAD_QUEUED_TILE_EVERY_X_SECONDS).timeout

		# remove any tiles that are now too far away for us
		tilecoords_queued_for_download = tilecoords_queued_for_download.filter(tile_is_not_distant)

		if tilecoords_queued_for_download.is_empty():
			continue

		if not download_manager.can_download_map():
			continue

		var coords := tilecoords_queued_for_download[0]
		if Debug.TILE_MANAGER:
			print(
				(
					"DL Q. TILE : %sx-%sy (%d remaining)"
					% [coords.x, coords.y, tilecoords_queued_for_download.size() - 1]
				)
			)

		download_manager.download_map_from_coords(coords)
		tilecoords_queued_for_loading.erase(coords)
		tilecoords_queued_for_download.erase(coords)


func regularly_load_queued_tiles() -> void:
	while true:
		await get_tree().create_timer(Constants.LOAD_QUEUED_TILE_EVERY_X_SECONDS).timeout

		# remove any tiles that are now too far away for us
		tilecoords_queued_for_loading = tilecoords_queued_for_loading.filter(tile_is_not_distant)

		if tilecoords_queued_for_loading.is_empty():
			continue

		var coords := tilecoords_queued_for_loading[0]
		tilecoords_queued_for_loading.erase(coords)

		assert(Utils.has_map_tilecoords(coords))
		var file := Utils.get_tile_filename_for_coords(coords)
		var map_data := await load_map(file)
		if map_data:
			tilecoords_queued_for_download.erase(coords)
			if Debug.PARSER:
				print(
					(
						"LD Q. TILE : %sx-%sy (%d remaining)"
						% [coords.x, coords.y, tilecoords_queued_for_loading.size()]
					)
				)
			continue

		# since it failed to load, queue it for download
		if not tilecoords_queued_for_download.has(coords):
			tilecoords_queued_for_download.append(coords)


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

	if not found_tile.map_data.boundaryData.valid:
		# we should never have an invalid boundary for our tiles, even the empty ones
		assert(false)

	tilecoords_being_replaced.append(coords)
	if Debug.TILE_MANAGER >= Debug.Level.All:
		print("UNLDD. TILE: %sx-%sy" % [coords.x, coords.y])

	Signals.tile_unloading_started.emit(found_tile)

	if Constants.WAIT_ONE_FRAME_BETWEEN_UNLOADING_PATHS:
		for child in found_tile.get_children():
			if is_instance_valid(child):
				for grandchild in child.get_children():
					if is_instance_valid(grandchild):
						grandchild.queue_free()
						if Constants.WAIT_ONE_FRAME_BETWEEN_UNLOADING_PATHS:
							await get_tree().process_frame
				child.queue_free()
				if Constants.WAIT_ONE_FRAME_BETWEEN_UNLOADING_PATHS:
					await get_tree().process_frame

	found_tile.queue_free()
	tiles_loaded.erase(coords)
	tilecoords_being_replaced.erase(coords)

	Signals.tile_unloading_finished.emit(coords)


func load_or_download_tiles(gps: Vector2) -> int:
	var tiles_added := 0

	if not GpsManager.is_valid_gps_position(gps):
		print(
			"tried to load or download tiles with invalid GPS location - do we have a valid location yet?"
		)
		return tiles_added

	var our_tile_coords := Maths.calculate_coords_from_gps(gps.y, gps.x)
	var tilecoords_to_check := get_adjacent_coords(our_tile_coords)

	if Debug.TILE_MANAGER == Debug.Level.All:
		print(
			(
				"TM: load_or_download_tiles called for tile %s, which has %d tiles to also check"
				% [our_tile_coords, tilecoords_to_check.size()]
			)
		)

	#this being last is important for forcing it to the front later
	tilecoords_to_check.append(our_tile_coords)

	for coords in tilecoords_to_check:
		if tiles_loaded.has(coords):
			if Debug.TILE_MANAGER == Debug.Level.All:
				print(
					"TM: tried to load/download a tile which is already loading/loaded: %s" % coords
				)
			continue

		if tilecoords_queued_for_download.has(coords):
			# force these to the front because it might have been added before as a neighbouring tile
			# note: since our direct tile is last in our array, we force it to the front last, prioritising it more
			tilecoords_queued_for_download.erase(coords)
			tilecoords_queued_for_download.insert(0, coords)
			if Debug.TILE_MANAGER == Debug.Level.All:
				print(
					(
						"TM: tried to load/download a tile which is already queued for download: %s"
						% coords
					)
				)
			continue

		var is_queued_for_loading := tilecoords_queued_for_loading.has(coords)
		var has_map_downloaded := Utils.has_map_tilecoords(coords)
		if has_map_downloaded:
			if our_tile_coords == coords:
				if Debug.TILE_MANAGER == Debug.Level.All:
					print("TM: trying to load priority tile, which is downloaded: %s" % coords)
				# remove it from the queue in case it was added by someone else before
				tilecoords_queued_for_loading.erase(coords)
				# try and instantly load this tile since it's our priority
				var file := Utils.get_tile_filename_for_coords(coords)
				var map_data := await load_map(file)
				if map_data && map_data.boundaryData.valid:
					# remove it from the queue in case it was added by someone else before
					if Debug.TILE_MANAGER == Debug.Level.All:
						print("TM: finished loading priority tile, which is: %s" % coords)
					tiles_added += 1
					tilecoords_queued_for_download.erase(coords)
					continue
				# else fall through and go straight to priority download
			elif not is_queued_for_loading:
				if Debug.TILE_MANAGER == Debug.Level.All:
					print(
						(
							"TM: trying to load/download a non-priority tile which is now queued for loading: %s"
							% coords
						)
					)
				tiles_added += 1
				tilecoords_queued_for_loading.insert(0, coords)
				continue
			elif is_queued_for_loading:
				# repriotise the adjacent tiles to load towards the front
				# our important one should have been loaded instantly and not queued
				if Debug.TILE_MANAGER == Debug.Level.All:
					print(
						(
							"TM: trying to load/download a non-priority tile which is now reprioritised for loading: %s"
							% coords
						)
					)
				tilecoords_queued_for_loading.erase(coords)
				tilecoords_queued_for_loading.insert(0, coords)
				continue

		# either we didn't have a map or we failed when loading it just now
		# so let's queue up a download
		# and prioritise these over the others
		# (our main node is last to be inserted at the front, for most priority)
		if Debug.TILE_MANAGER == Debug.Level.All:
			print("TM: trying to download tile, it is now queued at the front: %s" % coords)
		tiles_added += 1
		tilecoords_queued_for_download.insert(0, coords)

	return tiles_added


func load_map(filepath: String) -> MapData:
	const TILE_SCENE := preload("res://game/map/tile.tscn")

	var map_data := parser.parse_map(filepath)
	if not map_data or not map_data.boundaryData.valid:
		return map_data

	# the first valid map we load will become our origin tile
	if !origin_map_data || !origin_map_data.boundaryData.valid:
		origin_map_data = map_data

	var found_tile: Tile = tiles_loaded.get(map_data.boundaryData.tile_coordinate)
	if found_tile:
		assert(found_tile.map_data == map_data)
		return map_data

	if (
		map_data
		&& map_data.boundaryData.valid
		&& gps_manager.last_known_tile_coordinates == map_data.boundaryData.tile_coordinate
	):
		current_map_data = map_data

	Signals.tile_loading_started.emit(map_data)

	var new_tile: Tile = TILE_SCENE.instantiate()
	new_tile.name = str(map_data.boundaryData.tile_coordinate)
	new_tile.map_data = map_data
	tiles.add_child(new_tile)

	var offset := mercator_to_godot_from_origin(map_data.boundaryData.center)
	new_tile.global_position = offset

	tiles_loaded[map_data.boundaryData.tile_coordinate] = new_tile

	await replace_map_scene(new_tile)
	place_collectables(new_tile.collectables, map_data)
	place_creatures(new_tile.creatures, map_data)

	Signals.tile_loading_finished.emit(new_tile)

	return map_data


func create_and_update_path(
	boundary_data: BoundaryData, packed_scene: PackedScene, parent: Node3D, data: PackedVector3Array
):
	var scn := packed_scene.instantiate() as Path3D
	assert(scn)

	scn.visible = false
	scn.curve.closed = Utils.is_path_closed(data)

	# todo: cache node info of inside/outside
	#var found_node_inside_boundary := false
	#var is_inside_boundary := false

	var skipped_nodes := 0

	scn.curve.set_point_count(data.size())
	for i in data.size():
		##todo: cache node info of inside/outside
		##var is_previous_inside_boundary := is_inside_boundary
		##is_inside_boundary = boundary_data.contains_relative_merc(Vector2(data[i].x, data[i].z)
		##if not found_node_inside_boundary:
		##if is_inside_boundary:
		##found_node_inside_boundary = true

		# todo: this looks bad with really long lines because the paths no longer overlap perfectly between lots of different nodes
		# so it just doesn't really work. we would need proper deduplication by way/node ID's and rebuild paths dynamically
		# but... if we make the radius large enough, then it should be okay to help us with VERY distant nodes
		# since we'll unload those other tiles before we reach them

		# if we have nodes outside of our boundary for a unconnected path, then we don't need to draw them all
		# we only need to draw the first node outside our borders (so the path extends at least that far)
		# this helps MASSIVELY with long highways, rivers, etc
		if (
			Constants.PRUNE_NODES_BEYOND_X_TILES_ENABLED
			&& not scn.curve.closed
			and i >= 2  #make sure every path has at least two nodes
			and not boundary_data.contains_relative_merc(
				Vector2(data[i - 2].x, data[i - 2].z) / Constants.PRUNE_NODES_BEYOND_X_TILES
			)  # allow two nodes to extend outside, to be safe
			and not boundary_data.contains_relative_merc(
				Vector2(data[i - 1].x, data[i - 1].z) / Constants.PRUNE_NODES_BEYOND_X_TILES
			)
			and not boundary_data.contains_relative_merc(
				Vector2(data[i].x, data[i].z) / Constants.PRUNE_NODES_BEYOND_X_TILES
			)
		):
			#print("skipping %s %d at pos %s" % [parent.name, i, data[i]])
			skipped_nodes += 1
			continue

		if i == 0 || i == data.size() - 1:
			scn.curve.set_point_position(i - skipped_nodes, data[i])
		else:
			# by raising up the middle, we avoid weird z-fighting when two paths cross over eachother
			# i.e the unconnected ends will be below the middles, hopefully helping to hide most artifacts
			scn.curve.set_point_position(i - skipped_nodes, data[i] + Vector3(0.0, 0.1, 0.0))

		if Constants.WAIT_ONE_FRAME_BETWEEN_LOADING_EVERY_X_PATHS > 0:
			if (
				(
					Constants.LOADING_PATHS_FRAMESKIP_COUNTER
					% Constants.WAIT_ONE_FRAME_BETWEEN_LOADING_EVERY_X_PATHS
				)
				== 0
			):
				await get_tree().process_frame
			Constants.LOADING_PATHS_FRAMESKIP_COUNTER += 1

	if skipped_nodes:
		print(
			(
				"skipped %d nodes (%f%%)"
				% [skipped_nodes, (float(skipped_nodes) / float(data.size())) * 100.0]
			)
		)
	scn.curve.set_point_count(data.size() - skipped_nodes)

	parent.add_child(scn)
	# the curve is only baked when it changes, but we don't want it to bake each frame as that causes extra lag
	# so we do all the curve chanegs before we add it as a child, and then after adding it as a child, we lie and say it has changed
	# by emitting this signal, which then rebakes it, which... okay it does freeze a lil bit for long ones, but it's okay
	scn.curve_changed.emit()
	scn.visible = true


func create_and_update_polygon(packed_scene: PackedScene, parent: Node3D, data: PackedVector3Array):
	var scn := packed_scene.instantiate() as Node3D
	assert(scn)
	var csg := scn.get_child(0) as CSGPolygon3D
	assert(csg)

	scn.visible = false
	parent.add_child(scn)
	var arr := PackedVector2Array()
	arr.resize(data.size())
	for i in data.size():
		arr[i] = Vector2(data[i].x, data[i].z)
		if Constants.WAIT_ONE_FRAME_BETWEEN_LOADING_EVERY_X_POLYGONS > 0:
			if (
				(
					Constants.LOADING_POLYGONS_FRAMESKIP_COUNTER
					% Constants.WAIT_ONE_FRAME_BETWEEN_LOADING_EVERY_X_POLYGONS
				)
				== 0
			):
				await get_tree().process_frame
			Constants.LOADING_POLYGONS_FRAMESKIP_COUNTER += 1
	csg.polygon = arr
	scn.visible = true


func replace_map_scene(tile: Tile):
	const STREET_PATH_SCENE := preload("res://game/map/paths/street_other.tscn")
	const STREET_PRIMARY_SCENE := preload("res://game/map/paths/street_primary.tscn")
	const STREET_SECONDARY_SCENE := preload("res://game/map/paths/street_secondary.tscn")
	const STREET_PEDESTRIAN_SCENE := preload("res://game/map/paths/street_pedestrian.tscn")
	#const STREET_ENCLOSED_SCENE := preload("res://game/map/paths/street_enclosed.tscn")
	const BUILDING_SCENE := preload("res://game/map/paths/building.tscn")
	const BUILDING_ENCLOSED_SCENE := preload("res://game/map/paths/building_enclosed.tscn")
	const WATER_SCENE := preload("res://game/map/paths/water.tscn")
	const WATER_ENCLOSED_SCENE := preload("res://game/map/paths/water_enclosed.tscn")
	const RAILWAY_SCENE := preload("res://game/map/paths/railway.tscn")
	const BOUNDARY_SCENE := preload("res://game/map/paths/boundary.tscn")

	tiles_waiting_to_load += 1

	while (
		(
			is_instance_valid(tile)
			&& tilecoords_being_replaced.size() >= Constants.MAXIMUM_TILES_TO_LOAD_AT_ONCE
			&& tiles_loaded.has(tile.map_data.boundaryData.tile_coordinate)  # make sure it's still in the "loaded" state, which was done before this
			&& not tile_is_distant(tile.map_data.boundaryData.tile_coordinate)
		)
		|| (
			is_instance_valid(tile)
			&& tilecoords_being_replaced.has(tile.map_data.boundaryData.tile_coordinate)
		)
	):
		await get_tree().create_timer(0.5).timeout

	# tried to replace a tile which was unloaded, or will be unloaded soon
	if (
		not is_instance_valid(tile)
		or not tiles_loaded.has(tile.map_data.boundaryData.tile_coordinate)
		or tile_is_distant(tile.map_data.boundaryData.tile_coordinate)
	):
		tiles_waiting_to_load -= 1
		return

	#map_node.visible = true
	tilecoords_being_replaced.append(tile.map_data.boundaryData.tile_coordinate)

	#delete all path3D instances of the old map
	for way in tile.get_children():
		for path in way.get_children():
			if path is Path3D:
				# this shouldn't be possible anymore, right?
				assert(false)
				path.queue_free()

	var boundaryBox: float = tile.map_data.boundaryData.get_half_length()
	var boundary: PackedVector3Array = [
		Vector3(boundaryBox, 0, boundaryBox),
		Vector3(-boundaryBox, 0, boundaryBox),
		Vector3(-boundaryBox, 0, -boundaryBox),
		Vector3(boundaryBox, 0, -boundaryBox),
		Vector3(boundaryBox, 0, boundaryBox)
	]

	await create_and_update_path(
		tile.map_data.boundaryData, BOUNDARY_SCENE, tile.boundary, boundary
	)

	for ways in tile.map_data.streetMatrix.size():
		if Constants.WAIT_ONE_FRAME_BETWEEN_LOADING_MATRIX:
			await get_tree().process_frame
		await create_and_update_path(
			tile.map_data.boundaryData,
			STREET_PATH_SCENE,
			tile.streets,
			tile.map_data.streetMatrix[ways]
		)

	for ways in tile.map_data.streetMatrix_trunk.size():
		if Constants.WAIT_ONE_FRAME_BETWEEN_LOADING_MATRIX:
			await get_tree().process_frame
		await create_and_update_path(
			tile.map_data.boundaryData,
			STREET_PRIMARY_SCENE,
			tile.streets_trunk,
			tile.map_data.streetMatrix_trunk[ways]
		)

	for ways in tile.map_data.streetMatrix_primary.size():
		if Constants.WAIT_ONE_FRAME_BETWEEN_LOADING_MATRIX:
			await get_tree().process_frame
		await create_and_update_path(
			tile.map_data.boundaryData,
			STREET_PRIMARY_SCENE,
			tile.streets_primary,
			tile.map_data.streetMatrix_primary[ways]
		)

	for ways in tile.map_data.streetMatrix_secondary.size():
		if Constants.WAIT_ONE_FRAME_BETWEEN_LOADING_MATRIX:
			await get_tree().process_frame
		await create_and_update_path(
			tile.map_data.boundaryData,
			STREET_SECONDARY_SCENE,
			tile.streets_secondary,
			tile.map_data.streetMatrix_secondary[ways]
		)

	for ways in tile.map_data.streetMatrix_pedestrian.size():
		if Constants.WAIT_ONE_FRAME_BETWEEN_LOADING_MATRIX:
			await get_tree().process_frame
		if Utils.is_path_closed(tile.map_data.streetMatrix_pedestrian):
			#await create_and_update_polygon(STREET_ENCLOSED_SCENE, streets_pedestrian, map_data.streetMatrix_pedestrian[ways])
			# TODO: there's something to differentiate here: some enclosed paths should be areas, and others... not
			await create_and_update_path(
				tile.map_data.boundaryData,
				STREET_PEDESTRIAN_SCENE,
				tile.streets_pedestrian,
				tile.map_data.streetMatrix_pedestrian[ways]
			)
		else:
			await create_and_update_path(
				tile.map_data.boundaryData,
				STREET_PEDESTRIAN_SCENE,
				tile.streets_pedestrian,
				tile.map_data.streetMatrix_pedestrian[ways]
			)

	for ways in tile.map_data.buildMatrix.size():
		if Constants.WAIT_ONE_FRAME_BETWEEN_LOADING_MATRIX:
			await get_tree().process_frame
		if Utils.is_path_closed(tile.map_data.buildMatrix[ways]):
			await create_and_update_polygon(
				BUILDING_ENCLOSED_SCENE, tile.buildings, tile.map_data.buildMatrix[ways]
			)
		else:
			assert(false)
			await create_and_update_path(
				tile.map_data.boundaryData,
				BUILDING_SCENE,
				tile.buildings,
				tile.map_data.buildMatrix[ways]
			)

	for ways in tile.map_data.waterMatrix.size():
		if Constants.WAIT_ONE_FRAME_BETWEEN_LOADING_MATRIX:
			await get_tree().process_frame
		if Utils.is_path_closed(tile.map_data.waterMatrix[ways]):
			await create_and_update_polygon(
				WATER_ENCLOSED_SCENE, tile.water, tile.map_data.waterMatrix[ways]
			)
		else:
			await create_and_update_path(
				tile.map_data.boundaryData, WATER_SCENE, tile.water, tile.map_data.waterMatrix[ways]
			)

	for ways in tile.map_data.railMatrix.size():
		if Constants.WAIT_ONE_FRAME_BETWEEN_LOADING_MATRIX:
			await get_tree().process_frame
		await create_and_update_path(
			tile.map_data.boundaryData, RAILWAY_SCENE, tile.railway, tile.map_data.railMatrix[ways]
		)

	#map_node.visible = true
	tilecoords_being_replaced.erase(tile.map_data.boundaryData.tile_coordinate)
	tiles_waiting_to_load -= 1


func foreach_nodepos(map_data: MapData, matrix: Array[PackedVector3Array], f: Callable) -> void:
	for ways in matrix.size():
		for i in matrix[ways].size():
			var node_pos := matrix[ways][i]
			var merc_offset := Vector2(node_pos.x, node_pos.z)
			if not map_data.boundaryData.contains_merc(merc_offset + map_data.boundaryData.center):
				continue

			f.call(node_pos)


func place_collectables(parent: Node3D, map_data: MapData) -> void:
	const CRYSTAL_BLUE_SCENE := preload("res://game/entities/collectables/crystal_blue.tscn")
	const CRYSTAL_GREEN_SCENE := preload("res://game/entities/collectables/crystal_green.tscn")
	#const CRYSTAL_ORANGE_SCENE := preload("res://game/entities/collectables/crystal_orange.tscn")
	const CRYSTAL_PINK_SCENE := preload("res://game/entities/collectables/crystal_pink.tscn")
	const CRYSTAL_PURPLE_SCENE := preload("res://game/entities/collectables/crystal_purple.tscn")
	#const CRYSTAL_YELLOW_SCENE := preload("res://game/entities/collectables/crystal_yellow.tscn")
	const items := [
		CRYSTAL_BLUE_SCENE, CRYSTAL_GREEN_SCENE, CRYSTAL_PINK_SCENE, CRYSTAL_PURPLE_SCENE
	]

	var rng := Utils.get_deterministic_rng(map_data.boundaryData.tile_coordinate, 0)
	var f := func(node_pos: Vector3):
		var randomInt := rng.randi_range(0, 50)
		if randomInt <= 1:
			var new_crystal = items[rng.randi_range(0, items.size() - 1)].instantiate()
			new_crystal.scale = Vector3(10, 10, 10)
			new_crystal.name = "%d - %s" % [parent.get_child_count(), new_crystal.name]
			parent.add_child(new_crystal)
			new_crystal.position = node_pos

	foreach_nodepos(map_data, map_data.streetMatrix, f)
	foreach_nodepos(map_data, map_data.streetMatrix_pedestrian, f)
	foreach_nodepos(map_data, map_data.streetMatrix_trunk, f)
	foreach_nodepos(map_data, map_data.streetMatrix_primary, f)
	foreach_nodepos(map_data, map_data.streetMatrix_secondary, f)


func place_creatures(parent: Node3D, map_data: MapData) -> void:
	const CREATURE_SCENE := preload("res://game/entities/creatures/creature.tscn")
	const CREATURE_PERSIM_DATA := (
		preload("res://game/entities/creatures/creature_data_persim.tres") as CreatureData
	)
	const CREATURES_DATA: Array[CreatureData] = [CREATURE_PERSIM_DATA]

	var rng := Utils.get_deterministic_rng(map_data.boundaryData.tile_coordinate, 1)
	var f := func(node_pos: Vector3):
		var randomInt := rng.randi_range(0, 50)
		if randomInt <= 1:
			var creature_data := CREATURES_DATA[rng.randi_range(0, CREATURES_DATA.size() - 1)]
			var new_creature = CREATURE_SCENE.instantiate() as Creature
			new_creature.data = creature_data
			new_creature.name = "%d - %s" % [parent.get_child_count(), creature_data.name]
			parent.add_child(new_creature)
			new_creature.position = node_pos

	foreach_nodepos(map_data, map_data.streetMatrix, f)
	foreach_nodepos(map_data, map_data.streetMatrix_pedestrian, f)
	foreach_nodepos(map_data, map_data.streetMatrix_trunk, f)
	foreach_nodepos(map_data, map_data.streetMatrix_primary, f)
	foreach_nodepos(map_data, map_data.streetMatrix_secondary, f)


# coords_from would e.g be the tile the player is in
func tile_is_distant(coords: Vector2i) -> bool:
	if !current_map_data || !current_map_data.boundaryData.valid:
		# if we don't know where we are, assume everything is close to us
		return false

	var distance_vec := coords - current_map_data.boundaryData.tile_coordinate
	return (
		absf(distance_vec.x) + absf(distance_vec.y)
		> Constants.TILE_UNLOAD_RANGE + Constants.TILE_UNLOAD_RANGE
	)


func tile_is_not_distant(coords: Vector2i) -> bool:
	return not tile_is_distant(coords)


func get_adjacent_coords(coords: Vector2i) -> Array[Vector2i]:
	var adjacent_coords: Array[Vector2i]
	for y in range(Constants.ADJACENT_TILE_RANGE):
		adjacent_coords.append(coords + Vector2i(0, y + 1))
		adjacent_coords.append(coords + Vector2i(0, -y - 1))

	for x in range(Constants.ADJACENT_TILE_RANGE):
		adjacent_coords.append(coords + Vector2i(x + 1, 0))
		adjacent_coords.append(coords + Vector2i(-x - 1, 0))

	for y in range(Constants.ADJACENT_TILE_RANGE):
		for x in range(Constants.ADJACENT_TILE_RANGE):
			adjacent_coords.append(coords + Vector2i(x + 1, -y - 1))
			adjacent_coords.append(coords + Vector2i(x + 1, y + 1))
			adjacent_coords.append(coords + Vector2i(-x - 1, y + 1))
			adjacent_coords.append(coords + Vector2i(-x - 1, -y - 1))

	adjacent_coords = adjacent_coords.filter(
		func(coord: Vector2i) -> bool:
			if (
				coord.x < 0
				|| coord.y < 0
				|| coord.x > Maths.WORLD_TILES_PER_SIDE
				|| coord.y > Maths.WORLD_TILES_PER_SIDE
			):
				return false
			return true
	)

	adjacent_coords = adjacent_coords.filter(tile_is_not_distant)
	# sort it so the closest vectors are at the end, allowing them to be prioritised
	adjacent_coords.sort_custom(
		func(a, b) -> bool:
			return (
				absf(a.x - coords.x) + absf(a.y - coords.y)
				> absf(b.x - coords.x) + absf(b.y - coords.y)
			)
	)

	return adjacent_coords
