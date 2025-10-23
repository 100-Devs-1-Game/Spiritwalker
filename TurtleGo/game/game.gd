class_name Game extends Node3D

# README
# - it's called Game but it's more of a wrapper, and I didn't intend it to be the "overworld" vs the "encounter/minigame"
#   so in particular, you should try to avoid using get_tree().change_scene_packed and find an alternative
#   as destroying the map and reloading it after an encounter would be very laggy and a waste of performance
#   so please write a proper scene manager, or some other system, to handle hiding/removing the overworld during an encounter, rather than entirely destroying it


func _ready() -> void:
	# we mostly just do some basic sanity checks to make sure converting to/from some tile posititions doesn't break
	# and further down there are some signals being used to hookup the gameplay to the audio, but they could easily live elsewhere

	Maths.check_conversion(Vector2i(128887, 87467))
	Maths.check_conversion(Vector2i(128887, 87468))
	Maths.check_conversion(Vector2i(128887, 87469))
	Maths.check_conversion(Vector2i(128886, 87468))
	Maths.check_conversion(Vector2i(128887, 87468))
	Maths.check_conversion(Vector2i(128888, 87468))

	Maths.check_conversion(Vector2i(0, 0))

	Maths.check_conversion(Vector2i(0, 1))
	Maths.check_conversion(Vector2i(0, 2))

	Maths.check_conversion(Vector2i(1, 0))
	Maths.check_conversion(Vector2i(2, 0))

	Maths.check_conversion(Vector2i(1, 1))
	Maths.check_conversion(Vector2i(2, 2))

	Maths.check_conversion(Vector2i(1, 2))
	Maths.check_conversion(Vector2i(2, 1))

	Signals.creature_combat_delayed.connect(
		func(_creature_data: CreatureData) -> void: Audio.play_ui(Audio.UI_BUTTON_HIGHLIGHT)
	)

	Signals.creature_combat_started.connect(
		func(_creature_data: CreatureData) -> void: Audio.play_ui(Audio.UI_BUTTON_HIGHLIGHT)
	)

	Signals.creature_combat_delayed.connect(
		func(_creature_data: CreatureData) -> void: Audio.play_ui(Audio.UI_BUTTON_HIGHLIGHT)
	)

	Signals.player_pickedup_collectable.connect(
		func(_name_id: String) -> void: Audio.play_ui(Audio.UI_BUTTON_HIGHLIGHT)
	)
