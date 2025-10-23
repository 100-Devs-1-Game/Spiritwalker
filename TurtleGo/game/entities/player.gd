class_name Player extends AnimatableBody3D

# README
# - the player script is just the visuals for the overworld really
# - it controls how the visuals lerp to the new GPS location, to keep it looking smooth
# - it also controls the camera
# - for desktop it handles the debug movement too, modifying the fake GPS position based on keyboard input
#   but this could be done elsewhere, idk
#
# keep the following things in mind:
# - minimise as much processing as possible, for battery life. e.g use physics_process @ 10 ticks per second
# - don't go too crazy with the desktop/mobile differences, they should be representative of each other, so that we don't test on desktop and then get bugs on mobile

@export var map: Map
@onready var camera: Node3D = $Camera
@onready var targetRotator: Node3D = $TargetRotator

var speed := 0.25
var rotationSpeed := 1.0
var oldPosition: Vector3
var newPosition: Vector3

var time_since_last_update := 0.0
var time_since_last_update_pos := 0.0

var creature_chasing: Node3D = null
var gps_offset: Vector2


func _ready():
	Signals.player_position_updated.connect(_on_player_position_updated)


func _on_player_position_updated(pos: Vector3, teleport: bool):
	time_since_last_update_pos = 0.0
	if (global_position - pos).length_squared() > 1000 * 1000:
		teleport = true
		print(
			(
				"TELEPORTING PLAYER AS WE ARE VERY FAR AWAY FOR A LERP - %s vs %s"
				% [global_position, pos]
			)
		)

	if teleport:
		global_position = pos
		reset_physics_interpolation()

	oldPosition = global_position
	newPosition = pos

	$NewPosition.global_position = newPosition
	$NewPosition.reset_physics_interpolation()
	$OldPosition.global_position = oldPosition
	$OldPosition.reset_physics_interpolation()


func mobile_physics_update(_delta: float):
	pass


func desktop_physics_update(delta: float):
	if time_since_last_update >= 0.5:
		time_since_last_update = 0.0
		(
			map
			. gps_manager
			. provide_gps_data(
				{
					"latitude": map.gps_manager.last_known_gps_position.y + gps_offset.y,
					"longitude": map.gps_manager.last_known_gps_position.x + gps_offset.x,
				}
			)
		)
		gps_offset = Vector2.ZERO
	else:
		time_since_last_update += delta

	var input_dir := Vector2(
		Input.get_axis(&"left", &"right"),
		Input.get_axis(&"down", &"up"),
	)
	gps_offset += input_dir.normalized() * speed * delta * 0.005


func shared_physics_update(delta: float):
	time_since_last_update_pos += delta

	if newPosition && !oldPosition.is_equal_approx(newPosition):
		targetRotator.look_at_from_position(oldPosition, newPosition, Vector3.UP)

	rotation.y = lerp_angle(rotation.y, targetRotator.rotation.y, 2.0 * delta)

	if (oldPosition && newPosition) || (not global_position.is_equal_approx(newPosition)):
		global_position = oldPosition.lerp(newPosition, min(time_since_last_update_pos / 4.0, 1.0))

	camera.global_position = global_position
	camera.get_child(0).look_at(global_position, Vector3.UP)


func _physics_process(delta: float):
	if Utils.is_mobile_device():
		mobile_physics_update(delta)
	else:
		desktop_physics_update(delta)

	shared_physics_update(delta)
