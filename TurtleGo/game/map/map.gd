class_name Map extends Node3D

# Debug Counters
var counter_location_updates := 0
var counter_downloads_completed := 0

var previous_tile_coordinates := Vector2i.ZERO

@onready var tile_manager: TileManager = %TileManager
@onready var download_manager: DownloadManager = %DownloadManager
@onready var gps_manager: GpsManager = %GpsManager
@onready var parser: Parser = %Parser
@onready var player: Player = %Player
@onready var tp_button: Button = $Button

func _ready():
	tp_button.pressed.connect(_on_button_pressed)

	Signals.gps_data_received.connect(_on_gps_data_received)
	Signals.tile_parsing_finished.connect(_tile_parsing_finished)
	Signals.tile_loading_started.connect(_tile_loading_started)
	Signals.tile_loading_finished.connect(_tile_loading_finished)

	var err := DirAccess.make_dir_recursive_absolute("user://maps/z%d/" % Constants.WORLD_TILE_ZOOM_LEVEL)
	if err != Error.OK:
		push_error("failed to create maps directory: ", err)

	await gps_manager.enable_gps_async()

	if not Utils.is_mobile_device():
		print("ON DESKTOP - SETTING DEBUG LOCATION")
		
		var lat := 0.0
		var lon := 0.0
		# England
		#lat = 51.234286
		#lon = -2.999235
		# Germany
		lat = 48.05941
		lon = 8.46027
		# Portugal
		#lat = 37.168008
		#lon = -8.533642
		gps_manager.provide_gps_data({"latitude": lat, "longitude": lon})

	if OS.is_debug_build():
		%FPS.visible = true
		while true:
			%FPS.text = "%dfps" % Engine.get_frames_per_second()
			await get_tree().process_frame

func _on_gps_data_received(p_gps_manager: GpsManager) -> void:
	#print("RECEIVED NEW GPS DATA: TILE COORDINATES ARE %s" % p_gps_manager.last_known_tile_coordinates)
	assert(p_gps_manager == gps_manager)

	if not tile_manager.origin_map_data || not tile_manager.origin_map_data.boundaryData.valid:
		await tile_manager.load_or_download_tiles(p_gps_manager.last_known_gps_position)
	
	counter_location_updates += 1

	var player_pos := tile_manager.mercator_to_godot_from_origin(gps_manager.last_known_merc_position)
	# TODO: if we are more than... 100 tiles? away, then reset the origin?
	Signals.playerPos.emit(player_pos, false)
	
	await check_if_new_map_needed()

	if OS.is_debug_build():
		if tile_manager.current_map_data && tile_manager.current_map_data.boundaryData.valid:
			%LabelTileCoord.text = "tile %s" % tile_manager.current_map_data.boundaryData.tile_coordinate

	if OS.is_debug_build():
		$VBoxContainer/Label.text = str(
			counter_location_updates,
			" lat: ", p_gps_manager.last_known_gps_position.y,
			", lon:  ", p_gps_manager.last_known_gps_position.x
		)
	
	#print("UPDATED PREVIOUS PLAYER TILE COORDINATE FROM %s TO %s" % [previous_tile_coordinates, p_gps_manager.last_known_tile_coordinates])
	previous_tile_coordinates = p_gps_manager.last_known_tile_coordinates


func check_if_new_map_needed():
	if gps_manager.last_known_tile_coordinates != previous_tile_coordinates:
		#print("PLAYER HAS CHANGED TILE - from %s to %s" % [previous_tile_coordinates, gps_manager.last_known_tile_coordinates])
		tile_manager.current_map_data = null

	if tile_manager.tiles_loaded.has(gps_manager.last_known_tile_coordinates):
		tile_manager.current_map_data = tile_manager.tiles_loaded[gps_manager.last_known_tile_coordinates].map_data

	var needsNewMap := false
	if !tile_manager.current_map_data || tile_manager.current_map_data.boundaryData.valid == false:
		#print("PLAYER IS IN A TILE AND NOW WE NEED TO LOAD/DOWNLOAD IT - %s" % gps_manager.last_known_tile_coordinates)
		needsNewMap = true

	# QLD = queued for loading
	# QDl = queued for downloading
	# LD = loading
	# TTL = total
	if OS.is_debug_build():
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
		if OS.is_debug_build():
			$VBoxContainer/Label5.text = "player within boundary box!"
		return

	if OS.is_debug_build():
		$VBoxContainer/Label5.text = "out of bounds!"
	
	await tile_manager.load_or_download_tiles(gps_manager.last_known_gps_position)


func _on_button_pressed():
	gps_manager.provide_gps_data({
		"latitude": gps_manager.last_known_gps_position.y + 0.001,
		"longitude": gps_manager.last_known_gps_position.x
	})


func _tile_parsing_finished(_map_data: MapData) -> void:
	if OS.is_debug_build():
		$VBoxContainer/Label3.text = "finished parsing"


func _tile_loading_started(_map_data: MapData) -> void:
	pass
	#check_if_new_map_needed.call_deferred()


func _tile_loading_finished(_tile: Tile) -> void:
	if OS.is_debug_build():
		$VBoxContainer/Label4.text = str(Time.get_datetime_string_from_system())


func _physics_process(_delta: float) -> void:
	if not OS.is_debug_build():
		%DebugFutureGpsPosition.visible = false
		set_physics_process(false)
	
	if not GpsManager.is_valid_gps_position(gps_manager.last_known_gps_position):
		return
	
	%DebugFutureGpsPosition.global_position = tile_manager.mercator_to_godot_from_origin(
		Maths.mercatorProjection(
			gps_manager.last_known_gps_position.y + player.gps_offset.y,
			gps_manager.last_known_gps_position.x + player.gps_offset.x,
		)
	)
