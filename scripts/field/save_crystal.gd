class_name SaveCrystal
extends StaticBody3D
## Restores the party and records a checkpoint.

signal used


func interact() -> void:
	Audio.play_sfx(&"save")
	Game.full_restore()
	used.emit()
	Game.save_checkpoint()
	$PulseAnimation.play(&"pulse")
	await UI.say([["", "A warm light pours from the crystal.\nThe party's HP and MP are fully restored.\n[color=#9fe3ff]Your progress has been recorded.[/color]"]])
