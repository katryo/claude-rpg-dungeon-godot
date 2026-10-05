extends Node
## Renders screenshots of key screens (needs a GPU / display). Output dir given by
## the SHOTS_DIR environment variable (defaults to user://shots).

const DB := preload("res://scripts/data/db.gd")
const Castle := preload("res://scripts/world/castle.gd")
const Battle := preload("res://scripts/battle/battle.gd")
const Title := preload("res://scripts/ui/title.gd")
const Menu := preload("res://scripts/ui/menu.gd")

var out := ""


func _ready() -> void:
	out = OS.get_environment("SHOTS_DIR")
	if out == "":
		out = OS.get_user_data_dir() + "/shots"
	DirAccess.make_dir_recursive_absolute(out)
	var only := OS.get_environment("SHOTS_ONLY")
	await _frames(5)

	if only == "" or only == "title":
		var t := Title.new()
		add_child(t)
		await _wait(2.5)
		await _shot("01_title")
		t.queue_free()
		await _frames(2)

	if only == "" or only.begins_with("field"):
		Game.new_game()
		UI.fade_in(0.01)
		var f := Castle.new()
		add_child(f)
		await _wait(1.0)
		await _shot("02_field_entrance")
		f.place_party(f.cell_pos(17, 16))
		await _wait(0.6)
		await _shot("03_field_great_hall")
		f.place_party(f.cell_pos(5, 23))
		await _wait(0.6)
		await _shot("04_field_west_wing")
		f.place_party(f.cell_pos(17, 7))
		f.active = false
		await _wait(0.6)
		await _shot("05_field_throne_room")
		var menu := Menu.new()
		add_child(menu)
		menu.open()
		await _wait(0.4)
		await _shot("06_menu")
		menu._show_status(Game.party[2])
		await _wait(0.3)
		await _shot("07_menu_status")
		Game.add_equipment("starlight_blade")
		Game.add_equipment("power_ring")
		menu._equip_flow(0)
		await _wait(0.3)
		await _shot("08_menu_equip")
		menu.queue_free()
		UI.menu_open = false
		f.queue_free()
		await _frames(2)

	if only == "" or only == "battle":
		Game.new_game()
		var b := Battle.new()
		b.setup(["skeleton", "sorcerer", "gargoyle"], false)
		add_child(b)
		await _wait(2.5)
		await _shot("09_battle_command")
		b.auto_battle = true
		b._show_banner("Fira", Color(1.0, 0.7, 0.5))
		b._magic_fx("fire", "fire", [b.foes[0]])
		b._bolt(b.foes[2].node.position)
		b._popup(b.foes[1], "128", Color(1.0, 0.65, 0.25))
		b._popup(b.foes[1], "WEAK!", Color(1.0, 0.6, 0.2), 0.6, 0.6)
		await _wait(0.3)
		await _shot("10_battle_magic")
		b.queue_free()
		await _frames(2)

	if only == "" or only == "boss":
		Game.new_game()
		var bb := Battle.new()
		bb.setup(["dark_lord"], true)
		add_child(bb)
		await _wait(2.6)
		await _shot("11_boss_battle")
		bb._pillar(bb.foes[0].node.position, Color(1.0, 0.95, 0.6))
		await _wait(0.25)
		await _shot("12_boss_holy")
	if only == "" or only == "extra":
		Game.new_game()
		UI.fade_in(0.01)
		var f2 := Castle.new()
		add_child(f2)
		await _wait(0.8)
		UI.say([["Theia", "I sense a sacred crystal in the great hall. Its light will restore us and remember our progress.", "theia"]])
		await _wait(3.0)
		await _shot("13_dialogue")
		UI._advance.emit()
		await _wait(0.3)
		f2.queue_free()
		var b2 := Battle.new()
		b2.setup(["skeleton", "skeleton"], false)
		add_child(b2)
		await _wait(2.0)
		for fo in b2.foes:
			fo.hp = 0
			fo.node.hide()
		b2.cmd_panel.visible = false
		b2._victory()
		await _wait(1.5)
		await _shot("14_victory")
		b2.queue_free()
		await _frames(2)
		var t2 := Title.new()
		t2.ending = true
		add_child(t2)
		await _wait(4.0)
		await _shot("15_ending")
	get_tree().quit()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out + "/" + name + ".png")
	print("shot ", name)
