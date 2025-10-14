class_name Player extends AnimatableBody3D

@export var parser: Parser
@onready var camera: Node3D = $Camera
@onready var targetRotator: Node3D = $TargetRotator

var speed := 0.25
var rotationSpeed := 1.0
var oldPosition: Vector3
var newPosition: Vector3

var time_since_last_update := 0.0
var time_since_last_update_pos := 0.0

func _ready():
	Signals.playerPos.connect(updatePosition)

func updatePosition(pos: Vector3, teleport: bool):
	time_since_last_update_pos = 0.0
	#if newPosition == pos && !teleport:
		#return

	if teleport:
		global_position = pos
	#else:
	oldPosition = global_position
	newPosition = pos

	$NewPosition.global_position = newPosition
	$OldPosition.global_position = oldPosition

func _process(delta: float):
	# simulate infrequent GPS updates
	if time_since_last_update >= 0.5:
		time_since_last_update = 0.0
		parser.locationUpdate({
			"latitude": parser.lat,
			"longitude": parser.lon,
		})
	else:
		time_since_last_update += delta

	time_since_last_update_pos += delta

	if newPosition && !oldPosition.is_equal_approx(newPosition):
		targetRotator.look_at_from_position(oldPosition, newPosition, Vector3.UP)

	rotation.y = lerp_angle(rotation.y, targetRotator.rotation.y, 0.05)

	if (oldPosition && newPosition) || (global_position != newPosition):
		global_position = oldPosition.lerp(newPosition, time_since_last_update_pos / 1.0)

	var gps_offset: Vector2

	var input_dir := Vector2(
		Input.get_axis(&"left", &"right"),
		Input.get_axis(&"down", &"up"),
	)
	gps_offset = input_dir.normalized() * speed * delta * 0.005

	parser.lon += gps_offset.x
	parser.lat += gps_offset.y

	$LatPosition.global_position = parser.mercantorToGodotFromOrigin(
		Parser.mercatorProjection(parser.lat, parser.lon)
	)

	camera.global_position = global_position
