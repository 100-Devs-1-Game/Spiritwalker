class_name Player extends AnimatableBody3D

@export var parser: Parser

var speed := 0.25
var rotationSpeed := 1.0
var oldPosition: Vector3
var newPosition: Vector3
var targetRotator

var time_since_last_update := 0.0

func _ready():
	Signals.playerPos.connect(updatePosition)
	targetRotator = get_parent().get_node("TargetRotator")

func updatePosition(pos: Vector3, teleport: bool):
	if teleport:
		global_position = pos

	oldPosition = global_position
	newPosition = pos

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

	if oldPosition != newPosition:
		if targetRotator.position != newPosition:
			targetRotator.look_at(newPosition,Vector3.UP)
		#rotation.y = lerp_angle(rotation.y, targetRotator.rotation.y,1)
		global_position = oldPosition.lerp(newPosition, time_since_last_update)

	var gps_offset: Vector2

	# Move as long as the key/button is pressed.
	if Input.is_action_pressed("ui_right"):
		gps_offset.x = speed * delta * 0.001
	elif Input.is_action_pressed("ui_left"):
		gps_offset.x = speed * delta * 0.001 * -1.0
	elif Input.is_action_pressed("ui_up"):
		gps_offset.y = speed * delta * 0.001
	elif Input.is_action_pressed("ui_down"):
		gps_offset.y = speed * delta * 0.001 * -1.0

	parser.lon += gps_offset.x
	parser.lat += gps_offset.y

	# force a location update if we're moving
	if gps_offset != Vector2.ZERO:
		parser.locationUpdate({
			"latitude": parser.lat,
			"longitude": parser.lon,
		})
