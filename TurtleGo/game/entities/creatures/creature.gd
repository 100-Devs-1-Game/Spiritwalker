class_name Creature extends Node3D

const SPEED := 100.0

enum State {
	IDLE,
	TRIGGERED,
	CHASING,
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

	if state != State.IDLE:
		return

	Signals.player_entered_creature_range.emit(self)
	state = State.TRIGGERED


func player_is_overlapping() -> bool:
	return player in player_trigger.get_overlapping_bodies()


func _physics_process(delta: float) -> void:
	if !player:
		return

	var distance := player.global_position - global_position
	var lengthsqrd := distance.length_squared()

	if state == State.TRIGGERED:
		if Debug.CREATURE:
			print(self, " triggered")
		if not player_is_overlapping:
			if Debug.CREATURE:
				print(self, " turning to idle")
			state = State.IDLE
		else:
			if Debug.CREATURE:
				print(self, " facing player")
			visuals.look_at(player.global_position, Vector3.UP, true)

			if !player.creature_chasing:
				if Debug.CREATURE:
					print(self, " turning to chasing")
				player.creature_chasing = self
				state = State.CHASING

	elif state == State.CHASING:
		assert(player.creature_chasing == self)
		if Debug.CREATURE:
			print(self, " chasing")
		global_position = global_position.move_toward(player.global_position, SPEED * delta)
		if lengthsqrd <= 10 * 10:
			Signals.creature_combat_started.emit(data)
			if Debug.CREATURE:
				print(self, " COMBAT")
			player.creature_chasing = null
			queue_free()
		elif lengthsqrd >= 1000 * 1000:
			if Debug.CREATURE:
				print(self, " %s TOO FAR AWAY" % lengthsqrd)
			player.creature_chasing = null
			Signals.creature_combat_delayed.emit(data)
			queue_free()
		else:
			if Debug.CREATURE:
				print(self, " LOOK AT ME")
			# TODO: why do I need to flip Z here? it should be correct already :/
			visuals.look_at(player.global_position, Vector3.UP, true)
