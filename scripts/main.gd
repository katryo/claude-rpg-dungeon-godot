extends Node
## Top-level flow: title -> castle exploration <-> battles -> ending / game over.
## Every screen is a PackedScene assigned in main.tscn.

@export var title_scene: PackedScene
@export var castle_scene: PackedScene
@export var battle_scene: PackedScene
@export var ending_scene: PackedScene
@export var game_over_scene: PackedScene
@export_group("Dialogue portraits")
@export var arlen: HeroData
@export var garrick: HeroData
@export var theia: HeroData
@export var dark_lord_portrait: Texture2D

var field: Castle
var screen: Node

@onready var menu: PartyMenu = $PartyMenu


func _ready() -> void:
	UI.set_black()
	show_title.call_deferred()


func _set_screen(node: Node) -> void:
	if is_instance_valid(screen):
		if screen.get_parent() == self:
			remove_child(screen)
		screen.queue_free()
	screen = node
	if node:
		add_child(node)


# ----------------------------------------------------------------- Title ---
func show_title() -> void:
	_drop_field()
	var t: TitleScreen = title_scene.instantiate()
	_set_screen(t)
	var choice: StringName = await t.chosen
	if choice == &"quit":
		get_tree().quit()
		return
	await UI.fade_out(0.8)
	Game.new_game()
	_set_screen(null)
	_make_field()
	await UI.fade_in(0.8)
	await _intro()


func _intro() -> void:
	Game.intro_seen = true
	await get_tree().create_timer(0.4).timeout
	await UI.say([
		["Arlen", "This is it... Castle Nocturne. The Dark Lord Malzeth waits in the throne room at its heart.", arlen.portrait],
		["Garrick", "This place reeks of death. Keep your guard up, Arlen. I'll take the front.", garrick.portrait],
		["Theia", "I sense a sacred crystal in the great hall. Its light will restore us and remember our progress.", theia.portrait],
		["Theia", "His servants roam these halls, and treasure lies forgotten in the side wings. We should be thorough.", theia.portrait],
		["Arlen", "Then let's go. For Eldmoor... and for the dawn!", arlen.portrait],
	])
	Game.save_checkpoint()
	UI.notify("Press X / Tab to open the party menu")


# ----------------------------------------------------------------- Field ---
func _make_field() -> void:
	field = castle_scene.instantiate()
	add_child(field)
	field.encounter.connect(_on_encounter)
	field.boss_triggered.connect(_on_boss)
	field.menu_requested.connect(_on_menu)
	Audio.play_music(&"castle")


func _drop_field() -> void:
	if is_instance_valid(field):
		if field.get_parent() == self:
			remove_child(field)
		field.queue_free()
	field = null


func _on_menu() -> void:
	field.active = false
	await menu.open()
	field.active = true


func _on_encounter(enemy: FieldEnemy) -> void:
	var result := await _battle(enemy.encounter, false)
	match result:
		"win":
			Game.defeated_enemies[enemy.enemy_id] = true
			enemy.queue_free()
		"flee":
			enemy.start_cooldown()
	if result != "lose":
		await _return_to_field()


func _on_boss() -> void:
	Audio.play_sfx(&"dark")
	await UI.say([
		["Malzeth", "So... the spellblade of Eldmoor finally crawls before my throne.", dark_lord_portrait],
		["Arlen", "Your endless night ends here, Malzeth!", arlen.portrait],
		["Garrick", "Stay behind me, both of you. Whatever he throws, I'll take it.", garrick.portrait],
		["Theia", "The oracle foresaw this hour. By the light of Olympus, we will not fall!", theia.portrait],
		["Malzeth", "Then come, children of the dawn. Let me show you the abyss!", dark_lord_portrait],
	])
	var result := await _battle([preload("res://data/enemies/dark_lord.tres")], true)
	if result == "win":
		Game.boss_defeated = true
		await _ending()


## Runs a battle with the field set aside. Returns "win", "flee" or "lose".
func _battle(enemies: Array[EnemyData], boss: bool) -> String:
	field.active = false
	await UI.battle_transition()
	field.suspend()
	remove_child(field)
	var b: Battle = battle_scene.instantiate()
	b.setup(enemies, boss)
	add_child(b)
	var result: String = await b.finished
	await UI.fade_out(0.6, Color.WHITE if (boss and result == "win") else Color.BLACK)
	remove_child(b)
	b.queue_free()
	if result == "lose":
		await _game_over()
	return result


func _return_to_field() -> void:
	add_child(field)
	field.resume()
	Audio.play_music(&"castle")
	await UI.fade_in(0.5)


func _ending() -> void:
	_drop_field()
	var e: EndingScreen = ending_scene.instantiate()
	_set_screen(e)
	await e.finished
	await UI.fade_out(1.0)
	_set_screen(null)
	show_title()


func _game_over() -> void:
	_drop_field()
	var g: GameOverScreen = game_over_scene.instantiate()
	_set_screen(g)
	var retry: bool = await g.chosen
	await UI.fade_out(0.6)
	_set_screen(null)
	if retry:
		Game.load_checkpoint()
		_make_field()
		await UI.fade_in(0.6)
	else:
		show_title()
