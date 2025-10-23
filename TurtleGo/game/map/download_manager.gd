class_name DownloadManager extends Node3D

# README
# - This should only download one thing at a time
# - It could be changed to download more, but usually the tile bottleneck is in loading them, not downloading them
# - If we later need to do mass downloads to cache lots of tiles for offline usage, then multiple downloads at once would make sense
# - the TileManager is handling the download queue for tiles, which could be here instead, but it was easier to keep all the various queuing logic together
# - sometimes downloads will fail, especially using the overpass-api. you might need to test that situation again, it's been a while since I tried it

# official editing api of openstreetmap.org. This is only for testing purposes
const URL_BASE := "https://api.openstreetmap.org/api/0.6/map?bbox="
# allows limited public use. Guideline: maximum of 1000 requests per day
#const URL_BASE = "https://overpass-api.de/api/map?bbox="

@onready var http_request: HTTPRequest = %HTTPRequest

var url: String
var active_download_gps: Vector2
var active_download_tilecoords: Vector2i
var filepath: String
var _inflight_download_requests := 0


func _ready() -> void:
	http_request.request_completed.connect(_on_request_completed)


func can_download_map() -> bool:
	return _inflight_download_requests <= 0


func download_map_from_coords(coords: Vector2i):
	download_map_from_gps(Maths.calculate_gps_from_coords(coords))


func download_map_from_gps(gps: Vector2):
	if gps == Vector2.ZERO:
		push_error("tried to download a map for lat/lon of 0/0 - do we have a valid position yet?")
		assert(false)
		return

	if not can_download_map():
		assert(false)
		return

	_inflight_download_requests += 1
	active_download_gps = gps
	active_download_tilecoords = Maths.calculate_coords_from_gps(gps.y, gps.x)

	var tile_bbox := Maths.calculate_tile_bounding_box_gps(active_download_tilecoords)
	var tile_center := tile_bbox.get_center()

	#the number of decimal places the latitude/longitude has in the api request. 5 decimal places loads a map of ~200mx200m around the player. 3 decimal places loads about 2000mx2000m
	const decimal_places := "%.6f"
	var _lat_min: String = decimal_places % (tile_center.y - (tile_bbox.size.y / 2.0))
	var _lon_min: String = decimal_places % (tile_center.x - (tile_bbox.size.x / 2.0))
	var _lat_max: String = decimal_places % (tile_center.y + (tile_bbox.size.y / 2.0))
	var _lon_max: String = decimal_places % (tile_center.x + (tile_bbox.size.x / 2.0))
	url = URL_BASE + _lon_min + "," + _lat_min + "," + _lon_max + "," + _lat_max

	if Debug.DOWNLOAD_MANAGER:
		print(
			(
				"DOWNLOADING: %sx-%sy          (%s)"
				% [active_download_tilecoords.x, active_download_tilecoords.y, url]
			)
		)

	filepath = Utils.get_tile_filename_for_coords(active_download_tilecoords) + ".xml"
	$HTTPRequest.set_download_file(filepath)
	$HTTPRequest.request(url)
	Signals.download_started.emit(filepath, active_download_gps, active_download_tilecoords)


func _on_request_completed(
	_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray
):
	#counter_downloads_completed += 1
	#$VBoxContainer/Label2.text = str(counter_downloads_completed, url)
	if Debug.DOWNLOAD_MANAGER:
		print(
			(
				"DOWNLOADED : %sx-%sy CODE %d (%s)"
				% [active_download_tilecoords.x, active_download_tilecoords.y, response_code, url]
			)
		)

	if response_code != 200:
		push_error(
			(
				"DOWNLOADED : %sx-%sy CODE %d (%s)"
				% [active_download_tilecoords.x, active_download_tilecoords.y, response_code, url]
			)
		)
		# pause for a second before we let anyone download another map
		await get_tree().create_timer(Constants.DELAY_NEXT_DOWNLOAD_BY_X_SECONDS).timeout
		Signals.download_failed.emit(filepath, active_download_gps, active_download_tilecoords)
		_finish_download()
		return

	# pause for a second before we let anyone download another map
	await get_tree().create_timer(Constants.DELAY_NEXT_DOWNLOAD_BY_X_SECONDS).timeout
	Signals.download_succeeded.emit(filepath, active_download_gps, active_download_tilecoords)
	_finish_download()


func _finish_download() -> void:
	_inflight_download_requests -= 1
	assert(_inflight_download_requests >= 0)

	var fp := filepath
	var gps := active_download_gps
	var coords := active_download_tilecoords

	filepath = ""
	active_download_tilecoords = Vector2.ZERO
	active_download_gps = Vector2.ZERO

	Signals.download_finished.emit(fp, gps, coords)
