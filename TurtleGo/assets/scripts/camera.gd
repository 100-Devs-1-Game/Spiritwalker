extends Node3D

var touchPoints = {}

var rotationSpeed = 0.2
var startDistance
var endDistance
var zoom
var zoomSpeed = 0.3

func _input(event):
	if event is InputEventScreenTouch:
		handle_touch(event)
	elif event is InputEventScreenDrag:
		handle_drag(event)

#if drag motions are detected, the camera rotates
func handle_drag(event: InputEventScreenDrag):
	touchPoints[event.index] = event.position

	#if only 1 finger, rotate screen in drag direction
	if touchPoints.size() == 1:
		#print(event.position)

		rotation_degrees.y += event.relative.x * rotationSpeed
	#if it's 2 fingers, zoom
	elif touchPoints.size() == 2:
		var touch_point_positions = touchPoints.values()
		endDistance = touch_point_positions[0].distance_to(touch_point_positions[1])
		$Camera3D/Label.text = str("startDistance / endDistance: ", startDistance / endDistance)
		zoom = clampf(scale.y * (startDistance / endDistance) , 1.0,3.0)
		scale = Vector3(zoom,zoom,zoom)
		touchPoints.clear()
	else:
		touchPoints.clear()
#2 finger pinch/extend to zoom in/out
func handle_touch(event: InputEventScreenTouch):
	touchPoints[event.index] = event.position
	#if input is 2 fingers
	if touchPoints.size() == 2:
		var touch_point_positions = touchPoints.values()
		startDistance = touch_point_positions[0].distance_to(touch_point_positions[1])
