class_name Combat extends Node2D

@export var player_follow_mouse_speed = 500.0
var player_dead := false
var player_active := true
var creature: CreatureData

@onready var player = $Player
@onready var player_heart = $Player/Heart

func _ready():
	$Player/Area2D.connect("area_entered", self.player_area_entered)
	draw_supercircle()
var capture_tween: Tween

func fight(creature_data: CreatureData) -> void:
	creature = creature_data
	capture_tween = create_tween()
	capture_tween.tween_property($CombatArea/MarginContainer/ProgressBar, "value", 1.0, creature_data.combat_time).from(0.0)
	await capture_tween.finished
	player_active = false
	actual_closing_speed = 0.0
	prints("returning from the fight", player_dead)
	#await get_tree().create_timer(creature_data.combat_time).timeout
	
func _physics_process(delta: float) -> void:
	var combat_style = 0
	if creature:
		combat_style = creature.combat_style
	match combat_style:
		0:
			sync_area_points()
	if player_active:
		$Player.position = $Player.position.move_toward(get_local_mouse_position(), player_follow_mouse_speed*delta).clamp($CombatArea.position, $CombatArea.position+$CombatArea.size)


@export var closing_speed = 50
var actual_closing_speed = 0.0
@export var polygon_sides = 60
var layers = [
	[1,1,0,0,0],
	[0,1,1,0,1],
	[1,0,1,1,0],
	[0,1,0,1,1],
	[0,1,1,0,1],
]


@onready var circle_container = $Obstacles/Circles
@onready var circle_container_outline = $Obstacles/CirclesOutlines

@export var polygon_layer_radius = 200
var polygon_radius = []
var min_radius = 5
var min_radius_layer_start = 100
var radius_offset = 30
var polygon_options_colors = [
	Color.WHITE, 
	Color("#e9664c"), Color("#6abab8"), Color("#488ecc"), Color("#f4b831"), Color("#b04c97"), 
	Color.WHITE
	]

var points = []
var lines_perimeter = []
var lines_perimeter2 = []
var area_segments = []
var areas = []
var labels = []
var playing_scripted = true

var rotate_speed = 0.50
var prompts = []

var lines = {}
var biases = []

func update_biases():
	var counts = [0,0,0,0,0]
	for i in biases:
		counts[i-1]+=1
	if len(biases) > 1:
		prints("update_biases", len(biases), (biases.max() - biases.min()))
		if len(biases) > 10 or (counts.max() - counts.min()) > 6:
			game_over()
			return true
	$"spider-diagram".redraw_spider(counts)
	return false

func game_over():
	player_active = false

func cleanup():
	# cleanup
	player.hide()
	points = []
	for layer in lines_perimeter:
		for line in layer:
			line.queue_free()
	for layer in lines_perimeter2:
		for line in layer:
			line.queue_free()
	for area in areas:
		area.queue_free()
	for label in labels:
		label.queue_free()
	areas = []
	lines_perimeter = []
	lines_perimeter2 = []
	area_segments = []
	polygon_radius = []


	
	
	
	
func take_hit():
	capture_tween.stop()
	player_dead = true
	player_active = false
	player_heart.modulate = Color.CRIMSON
	player_heart.beating = false
	actual_closing_speed = 0.0
	capture_tween.finished.emit()

func reset():
	player.scale = Vector2(1,1)
	player_heart.modulate = Color.WHITE
	actual_closing_speed = closing_speed
	player_active = true
	player_heart.beating = true
	player.position = Vector2.ZERO
	
	
func player_area_entered(area: Area2D):
	if not player_active:
		return
	take_hit()

func draw_supercircle(align = "right_side"):
	player.show()
	var offset = 0.0
	if align == "top":
		offset = TAU * 0.75
	elif align == "top_side":
		offset = TAU * 0.75 - TAU / polygon_sides * 0.5
	elif align == "right_side":
		offset = - (TAU / polygon_sides) * 0.5 * polygon_sides / len(layers[0])
	else:
		pass
	var current_offset = offset
	var current_option = 0
	
	for layer_idx in len(layers):
		if len(layers) > 1:
			radius_offset = 50 / len(layers)
		else:
			radius_offset = 15
		polygon_radius.append(polygon_layer_radius - (len(layers) - layer_idx - 1) * radius_offset)
		points.append([])
		lines_perimeter.append([])
		lines_perimeter2.append([])
		area_segments.append([])
		var next_option_transition = polygon_sides / len(layers[layer_idx])
		for idx in polygon_sides:
			current_option = layers[layer_idx][idx / next_option_transition]
			current_offset += TAU / polygon_sides
			points[-1].append(Vector2(cos(current_offset), sin(current_offset)))	
			draw_common(layer_idx, idx, current_option)
		sync_superpolygon_points()
		sync_area_points()
	reset()


	
func draw_common(layer_idx, idx, option):
		var line = Line2D.new()
		circle_container.add_child(line)
		line.default_color = Color.WHITE
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		lines_perimeter[-1].append(line)
		var line2 = Line2D.new()
		line2.default_color = Color.BLACK
		line2.width = 18
		line2.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line2.end_cap_mode = Line2D.LINE_CAP_ROUND
		lines_perimeter2[-1].append(line2)
		circle_container_outline.add_child(line2)
		var area = Area2D.new()
		
		area.set_meta("option_idx", option)
		var segment_collider = CollisionShape2D.new()
		segment_collider.shape = SegmentShape2D.new()
		area.add_child(segment_collider)
		area_segments[-1].append(segment_collider.shape)
		circle_container.add_child(area)
		areas.append(area)
		if option == 0:
			line.hide()
			line2.hide()
			area.monitorable = false
		else:
			pass

		
func sync_superpolygon_points():
	if not points:
		return
	if player_active:
		var last_point = points[-1][-1]
		for layer_idx in len(points):
			last_point = points[layer_idx][-1]
			for idx in len(points[layer_idx]):
				lines_perimeter[layer_idx][idx].points = [last_point* polygon_radius[layer_idx], points[layer_idx][idx] * polygon_radius[layer_idx]]
				lines_perimeter2[layer_idx][idx].points = [last_point* polygon_radius[layer_idx], points[layer_idx][idx] * polygon_radius[layer_idx]]
				last_point = points[layer_idx][idx]			

func _process(delta):
	rotate_polygon(delta)
	sync_superpolygon_points()
		
func rotate_polygon(delta):
	if rotate_speed != 0.0 and player_active:
		var direction = 1.0
		for layer_idx_ in len(points):
			var layer_idx = len(points) - layer_idx_ -1
			for idx in len(points[layer_idx]):
				points[layer_idx][idx] = points[layer_idx][idx].rotated(delta * rotate_speed * direction)
			direction *= -1.0
	for layer_idx in len(polygon_radius):
		if polygon_radius[layer_idx] < min_radius:
			continue
		polygon_radius[layer_idx]-=delta * actual_closing_speed
		if polygon_radius[layer_idx] >= min_radius_layer_start:
			break
	
func sync_area_points():
	if not points: return
	var last_point = points[-1]
	for layer_idx in len(points):
		last_point = points[layer_idx][-1]
		for idx in len(points[layer_idx]):
			area_segments[layer_idx][idx].a = last_point* polygon_radius[layer_idx]
			area_segments[layer_idx][idx].b = points[layer_idx][idx]* polygon_radius[layer_idx]
			last_point = points[layer_idx][idx]
