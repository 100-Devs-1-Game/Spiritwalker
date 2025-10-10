class_name Player extends AnimatableBody3D
var speed = 0.25
var rotationSpeed = 1
var newPosition
var targetRotator

func _ready():
	Signals.connect("playerPos", updatePosition)
	targetRotator = get_parent().get_node("TargetRotator")

func updatePosition(_playerPos):
	newPosition = _playerPos

func _process(delta):
	if newPosition != null:
		targetRotator.look_at(newPosition,Vector3.UP)
		rotation.y = lerp_angle(rotation.y, targetRotator.rotation.y,1)
		position = position.lerp(newPosition, delta * speed)

	if Input.is_action_pressed("ui_right"):
		# Move as long as the key/button is pressed.
		position.x += speed * delta * 100.0
	elif Input.is_action_pressed("ui_left"):
		position.x -= speed * delta * 100.0
	elif Input.is_action_pressed("ui_up"):
		position.z -= speed * delta * 100.0
	elif Input.is_action_pressed("ui_down"):
		position.z += speed * delta * 100.0
