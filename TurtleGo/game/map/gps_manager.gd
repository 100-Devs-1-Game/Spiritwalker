class_name GpsManager extends Node3D

# README
# - this wraps the android plugin, which isn't very high quality
# - ideally that plugin can be easily replaced in the future, just changing this script as needed
# - most of the data we get isn't being used, only the GPS position atm, but some of the other data might be useful?

var has_gps_location_permission := false

var last_known_gps_position := Vector2(NAN, NAN)
var last_known_merc_position := Vector2(NAN, NAN)
var last_known_tile_coordinates := Vector2i(-1, -1)
var last_known_accuracy := NAN
var last_known_vertical_accuracy := NAN
var last_known_altitude := NAN
var last_known_speed := NAN
var last_known_bearing := NAN
var last_known_time: int = -1

var _gps_provider
var _enabling_gps := false
var _enabled_gps := false


static func is_valid_gps_position(gps: Vector2) -> bool:
	return not gps.is_zero_approx() && not is_nan(gps.x) && not is_nan(gps.y)


func wait_for_first_gps_position() -> void:
	if is_valid_gps_position(last_known_gps_position):
		return

	#%LabelTileCoord.text = "WAITING FOR GPS DATA"
	await enable_gps_async()

	while not is_valid_gps_position(last_known_gps_position):
		await Signals.gps_data_received


func enable_gps_async():
	if _enabled_gps:
		return

	if _enabling_gps:
		await Signals.gps_enabled
		return

	_enabling_gps = true

	if Utils.is_mobile_device():
		while not has_gps_location_permission:
			has_gps_location_permission = OS.request_permissions()
			if has_gps_location_permission:
				Signals.gps_permission_succeeded.emit()
				continue

				#%LabelTileCoord.text = "ENABLE LOCATION PERMISSIONS"
				#print("gps not permitted")
			Signals.gps_permission_failed.emit()
			await get_tree().create_timer(3.0).timeout
	else:
		Signals.gps_permission_succeeded.emit()

	_enable_gps()
	_enabling_gps = false


func _enable_gps():
	assert(not _enabled_gps)
	assert(_enabling_gps)

	if _gps_provider:
		return

	if not Utils.is_mobile_device():
		_enabled_gps = true
		Signals.gps_enabled.emit(self)
		return

	if Engine.has_singleton("PraxisMapperGPSPlugin"):
		_gps_provider = Engine.get_singleton("PraxisMapperGPSPlugin")

	if _gps_provider != null:
		_gps_provider.onLocationUpdates.connect(_on_real_gps_location_updated)
		_gps_provider.StartListening()
	else:
		print("NO GPS PROVIDER??? are we on android?")
		assert(false)

	_enabled_gps = true
	Signals.gps_enabled.emit(self)


func provide_gps_data(data: Dictionary) -> void:
	last_known_gps_position = Vector2(data.get("longitude", NAN), data.get("latitude", NAN))
	last_known_merc_position = Maths.mercatorProjection(
		last_known_gps_position.y, last_known_gps_position.x
	)
	last_known_tile_coordinates = Maths.calculate_coords_from_gps(
		last_known_gps_position.y, last_known_gps_position.x
	)

	last_known_accuracy = data.get("accuracy", last_known_accuracy)
	last_known_vertical_accuracy = data.get("verticalAccuracyMeters", last_known_vertical_accuracy)
	last_known_altitude = data.get("altitude", last_known_altitude)
	last_known_speed = data.get("speed", last_known_speed)
	last_known_time = data.get("time", last_known_time)
	last_known_bearing = data.get("bearing", last_known_bearing)

	Signals.gps_data_received.emit(self)


func _on_real_gps_location_updated(data: Dictionary) -> void:
	provide_gps_data(data)
