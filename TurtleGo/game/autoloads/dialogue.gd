extends Node

# use this autoload for anything you might want to access in dialogue scripts, I guess? idk
# you can always use the other autoloads too, or pass scripts in when creating the balloon, like I did with "self"

# this is used for some reason in PaperTown and I don't remember why, so let's not question it okay
var dialogue_is_running := false:
	get:
		return dialogue_is_running
	set(value):
		if not value:
			await get_tree().create_timer(0.25).timeout
		dialogue_is_running = value

# don't forget there is the DialogueManager autoload from the addon itself
