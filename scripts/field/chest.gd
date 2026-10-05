class_name Chest
extends StaticBody3D
## A treasure chest. Its contents are set in the inspector.

@export var chest_id: StringName
@export var equipment: Array[EquipmentData] = []
@export var items: Dictionary[ItemData, int] = {}

@onready var _anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	if Game.opened_chests.has(chest_id):
		_anim.play(&"opened")


func can_interact() -> bool:
	return not Game.opened_chests.has(chest_id)


func interact() -> void:
	Game.opened_chests[chest_id] = true
	Audio.play_sfx(&"chest")
	_anim.play(&"open")
	$Sparkles.restart()
	var lines: Array = []
	for e in equipment:
		Game.add_equipment(e)
		lines.append(["", "Found [color=#ffd36a]%s[/color]!" % e.display_name])
	for it in items:
		Game.add_item(it, items[it])
		lines.append(["", "Found [color=#9fe3ff]%s[/color] x%d!" % [it.display_name, items[it]]])
	await get_tree().create_timer(0.3).timeout
	await UI.say(lines)
