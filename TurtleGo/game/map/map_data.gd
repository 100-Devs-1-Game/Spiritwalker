class_name MapData extends Resource

#all street waypoints (all other streets and ways)
@export var streetMatrix: Array[PackedVector3Array] = []
#all "streets" for people, e.g pavement or shared usage
@export var streetMatrix_pedestrian: Array[PackedVector3Array] = []
#all motorways/autobahn
@export var streetMatrix_trunk: Array[PackedVector3Array] = []
#all primary street waypoints (big streets)
@export var streetMatrix_primary: Array[PackedVector3Array] = []
#all street waypoints (middle sized streets)
@export var streetMatrix_secondary: Array[PackedVector3Array] = []
#all building waypoints
@export var buildMatrix: Array[PackedVector3Array] = []
#all water waypoints
@export var waterMatrix: Array[PackedVector3Array] = []
#all railway waypoints
@export var railMatrix: Array[PackedVector3Array] = []
#the location and size data for this area
@export var boundaryData := BoundaryData.new()

func updateBoundaryData(_minlat, _maxlat, _minlon, _maxlon):
	var minimum := Maths.mercatorProjection(_minlat, _minlon)
	var maximum := Maths.mercatorProjection(_maxlat, _maxlon)
	var center := Vector2(
		(minimum.x + maximum.x) / 2.0,
		(minimum.y + maximum.y) / 2.0,
	)

	boundaryData = BoundaryData.new(minimum, maximum, center)
	assert(boundaryData.valid)

func is_empty():
	return (buildMatrix.is_empty()
			&& railMatrix.is_empty()
			&& streetMatrix.is_empty()
			&& streetMatrix_primary.is_empty()
			&& streetMatrix_secondary.is_empty()
			&& streetMatrix_trunk.is_empty()
			&& streetMatrix_pedestrian.is_empty()
			&& waterMatrix.is_empty())
