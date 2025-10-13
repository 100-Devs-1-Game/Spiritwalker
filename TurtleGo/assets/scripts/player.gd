class_name Player extends AnimatableBody3D

@export var parser: Parser

var speed := 0.25
var rotationSpeed := 1.0
var newPosition
var targetRotator

func _ready():
	Signals.connect("playerPos", updatePosition)
	targetRotator = get_parent().get_node("TargetRotator")

	while true:
		parser.locationUpdate({
			"latitude": parser.lat,
			"longitude": parser.lon,
		})
		await get_tree().create_timer(0.5).timeout

func updatePosition(_playerPos):
	newPosition = _playerPos

func _process(delta: float):
	if newPosition != null:
		targetRotator.look_at(newPosition,Vector3.UP)
		#rotation.y = lerp_angle(rotation.y, targetRotator.rotation.y,1)
		position = position.lerp(newPosition, delta * speed * 100.0)

	var gps_offset: Vector2

	# Move as long as the key/button is pressed.
	if Input.is_action_pressed("ui_right"):
		gps_offset.x = speed * delta * 0.001
	elif Input.is_action_pressed("ui_left"):
		gps_offset.x = speed * delta * 0.001 * -1.0
	elif Input.is_action_pressed("ui_up"):
		gps_offset.y = speed * delta * 0.001 * -1.0
	elif Input.is_action_pressed("ui_down"):
		gps_offset.y = speed * delta * 0.001

	if gps_offset != Vector2.ZERO:
		parser.locationUpdate({
			"latitude": gps_offset.x + parser.lat,
			"longitude": gps_offset.y + parser.lon,
		})
