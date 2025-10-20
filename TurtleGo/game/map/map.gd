#@tool
class_name Map extends Node3D

var loading_from_playerbounds := false

var gps_provider
var lat: float
var lon: float

###Testing
var counter_location_updates := 0
var counter_downloads_completed := 0

var player_previous_tilecoords: Vector2i

@onready var tile_manager: TileManager = %TileManager
@onready var download_manager: DownloadManager = %DownloadManager
@onready var parser: Parser = %Parser

func _ready():
	Signals.gps_enabled.connect(check_gps)
	Signals.finished_parsing_tile.connect(_finished_parsing_tile)
	Signals.finished_loading_tile.connect(_finished_loading_tile)

	var userOS = OS.get_name()

	var err := DirAccess.make_dir_recursive_absolute("user://maps/z%d/" % Constants.WORLD_TILE_ZOOM_LEVEL)
	if err != Error.OK:
		push_error("failed to create maps directory: ", err)

	if userOS == "Windows" || userOS == "Linux":
		if Debug.PARSER:
			print("ON DESKTOP - SETTING DEBUG LOCATION")

		# England
		#lat = 51.234286
		#lon = -2.999235
		# Germany
		#lat = 48.05941
		#lon = 8.46027
		# Portugal
		lat = 37.168008
		lon = -8.533642
		await tile_manager.load_or_download_tiles(lat, lon)
	else:
		#var err := remove_recursive("user://maps/z%d/" % WORLD_TILE_ZOOM_LEVEL)
		#if err != Error.OK:
			#push_error("failed to remove maps directory: ", err)
		#err = DirAccess.make_dir_recursive_absolute("user://maps/z%d/" % WORLD_TILE_ZOOM_LEVEL)
		#if err != Error.OK:
			#push_error("failed to create maps directory: ", err)
		#err = remove_recursive("user://saves/")
		#if err != Error.OK:
			#push_error("failed to create saves directory: ", err)
		check_gps()

	if OS.is_debug_build():
		%FPS.visible = true
		while true:
			%FPS.text = "%dfps" % Engine.get_frames_per_second()
			await get_tree().process_frame

func check_gps():
	var has_permission := false
	while not has_permission:
		has_permission = OS.request_permissions()
		if has_permission:
			print("gps permitted")
		else:
			%LabelTileCoord.text = "ENABLE LOCATION PERMISSIONS"
			print("gps not permitted")
		await get_tree().create_timer(0.5).timeout

	enable_gps()

	while is_nan(lat) || is_nan(lon) || (is_zero_approx(lat) && is_zero_approx(lon)):
		%LabelTileCoord.text = "WAITING FOR GPS DATA"
		await get_tree().create_timer(0.5).timeout

func enable_gps():
	if Engine.has_singleton("PraxisMapperGPSPlugin"):
		gps_provider = Engine.get_singleton("PraxisMapperGPSPlugin")

	if gps_provider != null:
		gps_provider.onLocationUpdates.connect(location_update)
		gps_provider.StartListening()
	else:
		print("NO GPS PROVIDER???")
		assert(false)

func location_update(location: Dictionary) -> void:
	# update player position
	lat = location["latitude"]
	lon = location["longitude"]
	tile_manager.last_known_gps = Vector2(lon, lat)

	var vec := Maths.mercatorProjection(lat, lon)
	playerBounds(vec.x, vec.y)
	if tile_manager.current_map_data && tile_manager.current_map_data.boundaryData.valid:
		%LabelTileCoord.text = "tile %s" % tile_manager.current_map_data.boundaryData.tile_coordinate

	counter_location_updates += 1
	$VBoxContainer/Label.text = str(counter_location_updates, " lat: " , lat, ", lon:  " ,lon)

# handle the player exiting their current tile
# and loading/downloading new maps as a result
func playerBounds(x_merc: float, y_merc: float):
	var player_pos := tile_manager.mercator_to_godot_from_origin(Vector2(x_merc, y_merc))

	if not tile_manager.origin_map_data.boundaryData.valid:
		player_pos.x = 0.0
		player_pos.z = 0.0

	var player_current_tilecoords: Vector2i
	if tile_manager.current_map_data && tile_manager.current_map_data.boundaryData.contains_merc(Vector2(x_merc, y_merc)):
		#print("current map contains player")
		player_current_tilecoords = tile_manager.current_map_data.boundaryData.tile_coordinate
	else:
		#print("we have to calculate our tile coordinate since the current map does not contain the player")
		player_current_tilecoords = Maths.calculate_tile_coordinate_from_uv(Maths.calculate_uv_from_merc(Vector2(x_merc, y_merc)))

	if player_current_tilecoords != player_previous_tilecoords:
		tile_manager.current_map_data = null

	player_previous_tilecoords = player_current_tilecoords

	if tile_manager.tiles_loaded.has(player_current_tilecoords):
		tile_manager.current_map_data = tile_manager.tiles_loaded[player_current_tilecoords].map_data

	var needsNewMap := false
	if !tile_manager.current_map_data || tile_manager.current_map_data.boundaryData.valid == false:
		needsNewMap = true

	# TODO: if we are more than... 100 tiles? away, then reset the origin?
	Signals.playerPos.emit(player_pos, false)

	# QLD = queued for loading
	# QDl = queued for downloading
	# LD = loading
	# TTL = total
	%LabelTilesStatus.text = (
		"%d/%d/%d/%d tiles QLD/QDL/LD/TTL" %
			[
				tile_manager.tilecoords_queued_for_loading.size(),
				tile_manager.tilecoords_queued_for_download.size(),
				tile_manager.tiles_waiting_to_load,
				tile_manager.tiles_loaded.size() - tile_manager.tiles_waiting_to_load
			]
	)

	if !needsNewMap:
		$VBoxContainer/Label5.text = "player within boundary box!"
		return

	$VBoxContainer/Label5.text = "out of bounds!"

	if !loading_from_playerbounds:
		loading_from_playerbounds = true
		await tile_manager.load_or_download_tiles(lat, lon)
		loading_from_playerbounds = false


func _on_button_pressed():
	lat += 0.001
	location_update({
		"latitude": lat,
		"longitude": lon,
	})

func _finished_parsing_tile(_map_data: MapData) -> void:
	$VBoxContainer/Label3.text = "finished parsing"

func _finished_loading_tile(_map_data: MapData) -> void:
	$VBoxContainer/Label4.text = str(Time.get_datetime_string_from_system())
	# force everything to update after we load a map
	# e.g this can trigger other maps to load/download
	# and this also causes the player position to update
	# we defer it until the next frame to prevent infinite loops
	# (infinite loops shouldn't happen anyway, but sometimes we've seen them)
	if !loading_from_playerbounds:
		var f := func() -> void:
			var player_vector := Maths.mercatorProjection(lat, lon)
			playerBounds(player_vector.x, player_vector.y)
		f.call_deferred()
		
		
func _physics_process(_delta: float) -> void:
	$LatPosition.global_position = tile_manager.mercator_to_godot_from_origin(
		Maths.mercatorProjection(lat, lon)
	)
