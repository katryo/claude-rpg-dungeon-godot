class_name EndingScreen
extends Node3D
## Ending: the castle at dawn, a few last words, then THE END.

signal finished

@export var arlen: HeroData
@export var garrick: HeroData
@export var theia: HeroData

var _waiting := false


func _ready() -> void:
	Audio.play_music(&"title")
	_run.call_deferred()


func _run() -> void:
	await UI.fade_in(2.0)
	await UI.say([
		["", "With a final cry, Malzeth crumbled into ash,\nand the long night over the realm shattered like glass."],
		["Arlen", "It's over... The dawn is finally coming back.", arlen.portrait],
		["Garrick", "Heh. Told you I'd keep you two in one piece.", garrick.portrait],
		["Theia", "The oracle's vision was true. The age of shadow has ended.", theia.portrait],
		["Arlen", "Let's go home. Eldmoor has waited long enough.", arlen.portrait],
	])
	Audio.play_sfx(&"levelup")
	%EndAnimation.play(&"the_end")
	await %EndAnimation.animation_finished
	_waiting = true


func _unhandled_input(event: InputEvent) -> void:
	if _waiting and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		_waiting = false
		finished.emit()
