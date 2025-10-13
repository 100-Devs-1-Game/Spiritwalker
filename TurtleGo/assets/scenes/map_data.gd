class_name MapData extends Resource

@export_storage var streetMatrix: Array[PackedVector3Array] = [] #contains subset of xzMatrix: all street waypoints (all other streets and ways)
@export_storage var streetMatrix_primary: Array[PackedVector3Array] = [] #contains subset of xzMatrix: all primary street waypoints (big streets)
@export_storage var streetMatrix_secondary: Array[PackedVector3Array] = [] #contains subset of xzMatrix: all street waypoints (middle sized streets)
@export_storage var buildMatrix: Array[PackedVector3Array] = [] #contains subset of xzMatrix: all building waypoints
@export_storage var waterMatrix: Array[PackedVector3Array] = [] #contains subset of xzMatrix: all water waypoints
@export_storage var railMatrix: Array[PackedVector3Array] = [] #contains subset of xzMatrix: all railway waypoints
@export_storage var boundaryData := BoundaryData.new()

func updateBoundaryData(_minlat, _maxlat, _minlon, _maxlon):
	var minimum := Parser.mercatorProjection(_minlat, _minlon)
	var maximum := Parser.mercatorProjection(_maxlat, _maxlon)
	var center := Vector2(
		(minimum.x + maximum.x) / 2.0,
		(minimum.y + maximum.y) / 2.0,
	)

	boundaryData = BoundaryData.new(minimum, maximum, center)
	assert(boundaryData.valid)
