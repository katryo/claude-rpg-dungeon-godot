extends Node
## End-to-end smoke test driven by simulated input: title -> intro -> menu ->
## encounter -> battle -> crystal -> chest -> boss -> ending -> title.
##   godot --headless --path . res://tests/flow_test.tscn

const Battle := preload("res://scripts/battle/battle.gd")
const Castle := preload("res://scripts/world/castle.gd")
const Title := preload("res://scripts/ui/title.gd")

var main: Node
var failures := 0


func _ready() -> void:
	Engine.time_scale = 3.0
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(2.0)
	_check(main.screen is Title, "title shown")
	await press("ui_accept")                     # New Game
	await _wait(2.0)
	await _skip_dialogue()
	_check(main.field != null and main.field.active, "field active after intro")
	_check(Game.intro_seen, "intro seen")

	# --- Menu: status, equipment, items, close
	await press("menu")
	await _wait(0.3)
	_check(UI.menu_open, "menu opened")
	for i in 3:
		await press("ui_down")
	await press("ui_accept")                     # Status
	await press("ui_accept")                     # pick Arlen
	await press("ui_right")                      # next member
	await press("ui_cancel")
	await press("ui_up")                         # Equipment
	await press("ui_accept")
	await press("ui_accept")                     # Arlen
	await press("ui_accept")                     # weapon slot (no candidates -> buzz)
	await _wait(1.0)
	await press("ui_cancel")
	await press("ui_up")
	await press("ui_up")                         # Items
	await press("ui_accept")
	await press("ui_accept")                     # Potion
	await press("ui_accept")                     # on Arlen (full HP -> buzz, not consumed)
	_check(Game.inventory.get("potion", 0) == 6, "potion not wasted on full HP")
	await press("ui_cancel")                     # leave Items
	await press("ui_cancel")                     # close menu
	await _wait(0.3)
	_check(not UI.menu_open, "menu closed")

	# --- Encounter in the west wing (group 3)
	var f: Node3D = main.field
	f.place_party(f.cell_pos(4, 24))
	await _wait_for(func(): return _battle() != null, 8.0)
	_check(_battle() != null, "battle started")
	await _fight()
	await _wait_for(func(): return main.field != null and main.field.is_inside_tree() and main.field.active and not UI.busy(), 8.0)
	_check(Game.defeated_groups.has(3) or Game.defeated_groups.has(5), "west wing group defeated")
	print("party after battle: ", Game.party.map(func(m): return "%s L%d %d/%d" % [m.name, m.level, m.hp, Game.max_hp(m)]))

	# --- Save crystal
	f = main.field
	f.place_party(f.cell_pos(17, 15) + Vector3(0, 0, 1.2))
	await _wait(0.3)
	await press("ui_accept")
	await _wait(0.5)
	await _skip_dialogue()
	_check(Game.party.all(func(m): return m.hp == Game.max_hp(m)), "crystal restored party")

	# --- Chest 0 (Olympian Scepter)
	f.place_party(f.cell_pos(7, 13) + Vector3(0, 0, 1.1))
	await _wait(0.3)
	await press("ui_accept")
	await _wait(1.0)
	await _skip_dialogue()
	_check(Game.equip_bag.has("olympian_scepter"), "chest gave Olympian Scepter")

	# --- Boss (power the party up so the test is quick)
	for m in Game.party:
		Game.gain_exp(m, 200000)
		m.hp = Game.max_hp(m)
		m.mp = Game.max_mp(m)
	Game.defeated_groups[0] = true
	f.remove_enemy(0)
	f.place_party(f.cell_pos(17, 8))
	await _wait(0.2)
	f.place_party(f.cell_pos(17, 4))
	await _wait(1.0)
	await _skip_dialogue()
	await _wait_for(func(): return _battle() != null, 8.0)
	_check(_battle() != null and _battle().boss, "boss battle started")
	await _fight()
	await _wait_for(func(): return main.screen is Title and main.screen.ending, 10.0)
	_check(main.screen is Title and main.screen.ending, "ending reached")
	await _wait(2.5)
	await _skip_dialogue()
	await _wait(3.0)
	await press("ui_accept")
	await _wait(3.0)
	_check(main.screen is Title and not main.screen.ending, "back to title")
	print("FLOW TEST DONE, failures: %d" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _battle() -> Node:
	for c in main.get_children():
		if c is Battle:
			return c
	return null


## Attack (or confirm) until the battle ends.
func _fight() -> void:
	var guard := 0
	while _battle() != null and guard < 2000:
		var b = _battle()
		if b.cmd_list.active or b._targeting:
			await press("ui_accept")
		elif UI.dialogue_open:
			await press("ui_accept")
		else:
			await _wait(0.1)
		guard += 1
		if guard % 40 == 0:
			print("  fight dbg: cmd=%s tgt=%s sub=%s dlg=%s banner='%s' foes=%s" % [b.cmd_list.active, b._targeting, b.sub_panel.visible, UI.dialogue_open, b.banner_label.text, b.foes.map(func(x): return x.hp)])


func _skip_dialogue() -> void:
	var guard := 0
	while guard < 60:
		if not UI.dialogue_open:
			await _wait(0.3)
			if not UI.dialogue_open:
				return
		await press("ui_accept")
		await _wait(0.05)
		guard += 1


func press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(3)
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)
	await _frames(3)


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait_for(cond: Callable, timeout: float) -> void:
	var t := 0.0
	while not cond.call() and t < timeout:
		await _wait(0.1)
		t += 0.1
