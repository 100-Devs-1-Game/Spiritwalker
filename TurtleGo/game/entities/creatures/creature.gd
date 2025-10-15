class_name Creature extends Node3D

enum State {
	IDLE,
	CHASING,
	FIGHTING
}

@export var data: CreatureData

@onready var player_trigger: Area3D = %PlayerTrigger
@onready var visuals: Node3D = %Visuals

var state := State.IDLE
var player: Player
var animation_player: AnimationPlayer

func _ready() -> void:
	assert(data)
	player_trigger.body_entered.connect(_on_body_entered)

	var model := data.scene.instantiate()
	visuals.add_child(model)


func _on_body_entered(body: Node3D) -> void:
	player = body as Player
	if not player:
		return

	if player.has_triggered_creature:
		return

	if state != State.IDLE:
		return

	Signals.player_entered_creature_range.emit(self)
	state = State.CHASING


func _physics_process(delta: float) -> void:
	if state == State.CHASING:
		global_position.move_toward(player.global_position, delta)
		var distance := global_position - player.global_position
		var lengthsqrd := distance.length_squared()
		if lengthsqrd <= 10*10:
			Signals.start_combat.emit(data)
			queue_free()
		elif lengthsqrd >= 100*100:
			queue_free()
		else:
			visuals.look_at(player.global_position)
