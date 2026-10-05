extends Node
## Top-level flow: title -> castle exploration <-> battles -> ending.

const DB := preload("res://scripts/data/db.gd")
const Castle := preload("res://scripts/world/castle.gd")
const Battle := preload("res://scripts/battle/battle.gd")
const Menu := preload("res://scripts/ui/menu.gd")
const Title := preload("res://scripts/ui/title.gd")
const SelectList := preload("res://scripts/ui/select_list.gd")

var field: Node3D
var menu: CanvasLayer
var screen: Node


func _ready() -> void:
	menu = Menu.new()
	add_child(menu)
	UI.set_black()
	show_title.call_deferred()


func _set_screen(node: Node) -> void:
	if screen and is_instance_valid(screen):
		if screen.get_parent() == self:
			remove_child(screen)
		screen.queue_free()
	screen = node
	if node:
		add_child(node)


# ----------------------------------------------------------------- Title ---
func show_title() -> void:
	_drop_field()
	var t := Title.new()
	_set_screen(t)
	var choice: String = await t.chosen
	if choice == "quit":
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
		["Arlen", "This is it... Castle Nocturne. The Dark Lord Malzeth waits in the throne room at its heart.", "arlen"],
		["Garrick", "This place reeks of death. Keep your guard up, Arlen. I'll take the front.", "garrick"],
		["Theia", "I sense a sacred crystal in the great hall. Its light will restore us and remember our progress.", "theia"],
		["Theia", "His servants roam these halls, and treasure lies forgotten in the side wings. We should be thorough.", "theia"],
		["Arlen", "Then let's go. For Eldmoor... and for the dawn!", "arlen"],
	])
	Game.save_checkpoint()
	UI.notify("Press X / Tab to open the party menu")


# ----------------------------------------------------------------- Field ---
func _make_field() -> void:
	field = Castle.new()
	add_child(field)
	field.encounter.connect(_on_encounter)
	field.boss_triggered.connect(_on_boss)
	field.menu_requested.connect(_on_menu)
	Sfx.play_music("castle")


func _drop_field() -> void:
	if field and is_instance_valid(field):
		if field.get_parent() == self:
			remove_child(field)
		field.queue_free()
	field = null


func _on_menu() -> void:
	field.active = false
	await menu.open()
	field.active = true


func _on_encounter(idx: int) -> void:
	await _battle(DB.ENCOUNTERS[idx], false, idx)


func _on_boss() -> void:
	field.active = false
	Sfx.play("dark")
	await UI.say([
		["Malzeth", "So... the spellblade of Eldmoor finally crawls before my throne.", "dark_lord"],
		["Arlen", "Your endless night ends here, Malzeth!", "arlen"],
		["Garrick", "Stay behind me, both of you. Whatever he throws, I'll take it.", "garrick"],
		["Theia", "The oracle foresaw this hour. By the light of Olympus, we will not fall!", "theia"],
		["Malzeth", "Then come, children of the dawn. Let me show you the abyss!", "dark_lord"],
	])
	await _battle(["dark_lord"], true, -1)


func _battle(ids: Array, boss: bool, idx: int) -> void:
	field.active = false
	await UI.battle_transition()
	field.suspend()
	remove_child(field)
	var b := Battle.new()
	b.setup(ids, boss)
	add_child(b)
	var result: String = await b.finished
	await UI.fade_out(0.6, Color.WHITE if (boss and result == "win") else Color.BLACK)
	remove_child(b)
	b.queue_free()
	match result:
		"win":
			if boss:
				Game.boss_defeated = true
				await _ending()
				return
			Game.defeated_groups[idx] = true
			add_child(field)
			field.remove_enemy(idx)
		"flee":
			add_child(field)
			field.enemy_cooldown(idx)
		"lose":
			await _game_over()
			return
	field.resume()
	Sfx.play_music("castle")
	await UI.fade_in(0.5)


func _ending() -> void:
	_drop_field()
	var t := Title.new()
	t.ending = true
	_set_screen(t)
	await t.chosen
	await UI.fade_out(1.0)
	_set_screen(null)
	show_title()


func _game_over() -> void:
	_drop_field()
	Sfx.stop_music()
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme
	layer.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.0, 0.02)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var l := Label.new()
	l.text = "The party has fallen..."
	l.add_theme_font_size_override("font_size", 48)
	l.add_theme_color_override("font_color", Color(0.85, 0.2, 0.3))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_right = 1.0
	l.offset_top = 220
	root.add_child(l)
	var panel := PanelContainer.new()
	panel.position = Vector2(480, 380)
	panel.custom_minimum_size = Vector2(320, 0)
	root.add_child(panel)
	var list := SelectList.new()
	list.allow_cancel = false
	panel.add_child(list)
	list.set_items([{"text": "Retry from last crystal"}, {"text": "Return to title"}])
	await UI.fade_in(0.8)
	var c := await list.choose()
	await UI.fade_out(0.6)
	layer.queue_free()
	if c == 0:
		Game.load_checkpoint()
		_make_field()
		await UI.fade_in(0.6)
	else:
		show_title()
