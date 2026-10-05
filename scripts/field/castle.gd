class_name Castle
extends Node3D
## Field exploration of Castle Nocturne. The level itself (GridMap, props,
## chests, enemies, crystal, throne) is authored in castle.tscn.

signal encounter(enemy: FieldEnemy)
signal boss_triggered
signal menu_requested

var active := true

@onready var player: Player = %Player
@onready var followers: Array = [%Follower1, %Follower2]
@onready var camera: FieldCamera = %FieldCamera
@onready var grid: GridMap = %GridMap
@onready var _hud: CanvasLayer = %HUD
@onready var _boss: Node3D = $Throne/DarkLord


func _ready() -> void:
	# Party appearance comes from the current party.
	player.visual.sprite_frames = Game.party[0].hero.sprite_frames
	for i in followers.size():
		followers[i].visual.sprite_frames = Game.party[i + 1].hero.sprite_frames
	for e: FieldEnemy in %Enemies.get_children():
		if Game.defeated_enemies.has(e.enemy_id):
			e.queue_free()
		else:
			e.player = player
			e.contacted.connect(_on_enemy_contacted)
	if Game.boss_defeated:
		_boss.queue_free()
	%BossTrigger.body_entered.connect(_on_boss_trigger)
	place_party(Game.field_position if Game.has_field_position else %PlayerStart.position)


func _process(_delta: float) -> void:
	player.controllable = active and not UI.busy()
	for i in followers.size():
		followers[i].follow(player.trail_point((i + 1) * 9))
	Game.field_position = player.position
	Game.has_field_position = true


func _unhandled_input(event: InputEvent) -> void:
	if not active or UI.busy():
		return
	if event.is_action_pressed("interact"):
		var target := player.find_interactable()
		if target:
			get_viewport().set_input_as_handled()
			active = false
			await target.interact()
			active = true
	elif event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		Audio.play_sfx(&"confirm")
		menu_requested.emit()


## World position of a map cell (column, row) on the floor.
func cell_to_world(cell: Vector2i) -> Vector3:
	var p := grid.map_to_local(Vector3i(cell.x, 0, cell.y))
	return Vector3(p.x, 0.0, p.z)


func place_party(p: Vector3) -> void:
	player.place(p)
	for i in followers.size():
		followers[i].position = player.trail_point((i + 1) * 9)
	camera.snap()


func resume() -> void:
	active = true
	camera.make_current()
	_hud.show()


func suspend() -> void:
	active = false
	_hud.hide()


func _on_enemy_contacted(enemy: FieldEnemy) -> void:
	if active and not UI.busy():
		active = false
		encounter.emit(enemy)


func _on_boss_trigger(body: Node3D) -> void:
	if body == player and active and not Game.boss_defeated:
		active = false
		boss_triggered.emit()
