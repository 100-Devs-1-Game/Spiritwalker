class_name Attack extends Node2D

var creature: CreatureData
@onready var player = $Player
@onready var player_heart = $Player/Heart
@export var attack_time = 3.0
@export var height = 400.0
var player_dead = true
var combat_rect: Rect2
func _ready():
	player.position = Vector2(0, height)
	combat_rect = $CombatArea.get_rect()
	$Player/Area2D.area_entered.connect(self.player_area_entered)
	$Player/Area2D.area_exited.connect(self.player_area_exited)
	
var capture_tween: Tween
var heart_tween: Tween
func fight(creature_data: CreatureData) -> void:
	prints("starting fight", creature_data)
	creature = creature_data
	capture_tween = create_tween()
	capture_tween.tween_property(%CaptureProgressBar, "value", 1.0, attack_time).from(0.0)
	heart_tween = create_tween()
	heart_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	heart_tween.set_trans(Tween.TRANS_QUAD)
	heart_tween.tween_property(player, "position", Vector2(0, -height), attack_time*0.5).set_ease(Tween.EASE_OUT)
	heart_tween.tween_property(player, "position", Vector2(0, height), attack_time*0.5).set_ease(Tween.EASE_IN)
	await capture_tween.finished
	if player_heart.modulate == Color("66dd00"):
		player_dead = false
	else:
		prints(abs(player.position.y), height/3.0)
		if abs(player.position.y)<height/3.0:
			player_heart.modulate = Color.YELLOW
			player_dead = false
	prints("returning from the attack", player_dead)


func player_area_entered(_area: Area2D):
	player_heart.modulate = Color("66dd00")

func player_area_exited(_area: Area2D):
	player_heart.modulate = Color.RED
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if capture_tween.is_running():
			capture_tween.stop()
			heart_tween.stop()
			capture_tween.finished.emit.call_deferred()
			
		
