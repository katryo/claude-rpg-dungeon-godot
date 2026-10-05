extends Node
## Renders screenshots of key screens (needs a GPU / display). Output dir given by
## the SHOTS_DIR environment variable (defaults to user://shots). SHOTS_ONLY picks one group.

var out := ""


func _ready() -> void:
	out = OS.get_environment("SHOTS_DIR")
	if out == "":
		out = OS.get_user_data_dir() + "/shots"
	DirAccess.make_dir_recursive_absolute(out)
	var only := OS.get_environment("SHOTS_ONLY")
	await _frames(5)

	if only in ["", "title"]:
		var t: TitleScreen = load("res://scenes/screens/title_screen.tscn").instantiate()
		add_child(t)
		await _wait(3.5)
		await _shot("01_title")
		t.queue_free()
		await _frames(2)

	if only in ["", "field"]:
		Game.new_game()
		UI.fade_in(0.01)
		var f: Castle = load("res://scenes/field/castle.tscn").instantiate()
		add_child(f)
		await _wait(1.0)
		await _shot("02_field_entrance")
		for spec in [["03_field_great_hall", Vector2i(17, 17)], ["04_field_west_wing", Vector2i(5, 23)], ["05_field_throne_room", Vector2i(17, 7)]]:
			f.place_party(f.cell_to_world(spec[1]))
			f.active = false
			await _wait(0.6)
			await _shot(spec[0])
		var menu: PartyMenu = load("res://scenes/ui/party_menu.tscn").instantiate()
		add_child(menu)
		menu.open()
		await _wait(0.4)
		await _shot("06_menu")
		menu._show_view(menu.get_node("%StatusView"))
		menu._show_status(Game.party[2])
		await _wait(0.3)
		await _shot("07_menu_status")
		Game.add_equipment(load("res://data/equipment/starlight_blade.tres"))
		menu._equip_flow(Game.party[0])
		await _wait(0.3)
		await _shot("08_menu_equip")
		menu.queue_free()
		UI.menu_open = false
		f.queue_free()
		await _frames(2)

	if only in ["", "battle"]:
		Game.new_game()
		var b := _battle(["skeleton", "sorcerer", "gargoyle"], false)
		await _wait(2.5)
		await _shot("09_battle_command")
		b.auto_battle = true
		b._show_banner("Fira", Color(1.0, 0.7, 0.5))
		b._magic_fx(load("res://data/skills/fira.tres"), [b.foes[0]])
		b._spawn(b.bolt_fx, b.foes[2].view.global_position)
		b._popup(b.foes[1], "128", Color(1.0, 0.65, 0.25))
		b._popup(b.foes[1], "WEAK!", Color(1.0, 0.6, 0.2), 0.6, 0.6)
		b.heroes[2].view.play(&"cast")
		b.heroes[0].view.play(&"attack")
		await _wait(0.3)
		await _shot("10_battle_magic")
		b.queue_free()
		await _frames(2)

	if only in ["", "boss"]:
		Game.new_game()
		var bb := _battle(["dark_lord"], true)
		await _wait(2.6)
		await _shot("11_boss_battle")
		bb._spawn(bb.holy_pillar_fx, bb.foes[0].view.global_position, Color(1.0, 0.95, 0.6))
		bb._show_ko(bb.heroes[1], true)
		await _wait(0.25)
		await _shot("12_boss_holy")
		bb.queue_free()
		await _frames(2)

	if only in ["", "extra"]:
		Game.new_game()
		UI.fade_in(0.01)
		var f2: Castle = load("res://scenes/field/castle.tscn").instantiate()
		add_child(f2)
		await _wait(0.8)
		UI.say([["Theia", "I sense a sacred crystal in the great hall. Its light will restore us and remember our progress.", Game.party[2].hero.portrait]])
		await _wait(3.0)
		await _shot("13_dialogue")
		UI._dialogue._advance.emit()
		await _wait(0.3)
		f2.queue_free()
		var b2 := _battle(["skeleton", "skeleton"], false)
		await _wait(2.0)
		for fo in b2.foes:
			fo.hp = 0
			fo.view.hide()
		b2.get_node("%CommandPanel").hide()
		b2._victory()
		await _wait(1.5)
		await _shot("14_victory")
		b2.queue_free()
		await _frames(2)
		var e: EndingScreen = load("res://scenes/screens/ending_screen.tscn").instantiate()
		add_child(e)
		await _wait(4.0)
		await _shot("15_ending")
	get_tree().quit()


func _battle(ids: Array, boss: bool) -> Battle:
	var enemies: Array[EnemyData] = []
	for id in ids:
		enemies.append(load("res://data/enemies/%s.tres" % id))
	var b: Battle = load("res://scenes/battle/battle.tscn").instantiate()
	b.setup(enemies, boss)
	add_child(b)
	return b


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + shot_name + ".png")
	print("shot ", shot_name)
