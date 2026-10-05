class_name GameOverScreen
extends CanvasLayer
## Shown when the whole party falls.

signal chosen(retry: bool)


func _ready() -> void:
	Audio.stop_music()
	%ChoiceList.set_items([{"text": "Retry from last crystal"}, {"text": "Return to title"}])
	_run.call_deferred()


func _run() -> void:
	await UI.fade_in(0.8)
	var c: int = await %ChoiceList.choose()
	chosen.emit(c == 0)
