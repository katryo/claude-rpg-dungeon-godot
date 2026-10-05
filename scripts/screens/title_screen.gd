class_name TitleScreen
extends Node3D
## Title screen: the moonlit castle on the horizon.

signal chosen(choice: StringName)  ## &"new" or &"quit"

@onready var _menu: SelectList = %MenuList


func _ready() -> void:
	%MenuPanel.hide()
	Audio.play_music(&"title")
	_run.call_deferred()


func _run() -> void:
	await UI.fade_in(1.0)
	%IntroAnimation.play(&"intro")
	await %IntroAnimation.animation_finished
	%MenuPanel.show()
	_menu.set_items([{"text": "New Game"}, {"text": "Quit"}])
	var c := await _menu.choose()
	chosen.emit(&"new" if c == 0 else &"quit")
