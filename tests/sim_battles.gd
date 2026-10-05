extends Node
## Headless balance simulation: auto-plays every encounter placed in castle.tscn
## (with all chest loot equipped), then the Dark Lord. Run:
##   godot --headless --path . res://tests/sim_battles.tscn

const ROUTE := [&"west_wing_north", &"west_wing_south", &"east_wing_north", &"east_wing_south",
	&"hall_west", &"hall_east", &"rest", &"throne_guardians", &"rest", &"boss"]

var encounters := {}
var chests: Array[Chest] = []


func _ready() -> void:
	Engine.time_scale = 25.0
	var castle: Node = load("res://scenes/field/castle.tscn").instantiate()
	for e: FieldEnemy in castle.get_node("Enemies").get_children():
		encounters[e.enemy_id] = e.encounter
	for c: Chest in castle.get_node("Chests").get_children():
		chests.append(c)
	var runs := 6
	var wins := 0
	for r in runs:
		if await _run_once(r):
			wins += 1
	print("SIM RESULT: boss won %d / %d" % [wins, runs])
	castle.free()
	get_tree().quit()


func _run_once(run: int) -> bool:
	Game.new_game()
	for c in chests:
		for e in c.equipment:
			Game.add_equipment(e)
		for it in c.items:
			Game.add_item(it, c.items[it])
	_equip_best()
	for step in ROUTE:
		if step == &"rest":
			Game.full_restore()
			continue
		var boss: bool = step == &"boss"
		var enemies: Array[EnemyData] = []
		if boss:
			enemies.append(load("res://data/enemies/dark_lord.tres"))
		else:
			enemies.assign(encounters[step])
		var b: Battle = load("res://scenes/battle/battle.tscn").instantiate()
		b.auto_battle = true
		b.setup(enemies, boss)
		add_child(b)
		var t0 := Time.get_ticks_msec()
		var res: String = await b.finished
		if boss:
			print("   boss hp left: %d / %d" % [b.foes[0].hp, b.foes[0].max_hp()])
		remove_child(b)
		b.queue_free()
		var hp := Game.party.map(func(m: PartyMember): return "%s L%d %d/%d MP%d" % [m.display_name, m.level, m.hp, m.max_hp(), m.mp])
		print("run %d  %-17s -> %s  [%s]  (%.1fs)" % [run, step, res, ", ".join(hp), (Time.get_ticks_msec() - t0) / 1000.0])
		if res == "lose":
			return false
		for m in Game.party:   # revive between fights, as a player would
			m.hp = maxi(m.hp, 1)
	return true


func _equip_best() -> void:
	for m in Game.party:
		for slot in EquipmentData.Slot.values():
			var best := m.get_equipment(slot)
			for e in Game.equip_candidates(m, slot):
				if _score(e) > _score(best):
					best = e
			if best != m.get_equipment(slot):
				Game.equip(m, slot, best)
		m.hp = m.max_hp()
		m.mp = m.max_mp()


func _score(e: EquipmentData) -> int:
	if e == null:
		return 0
	var s := 0
	for k in HeroData.STAT_KEYS:
		s += e.bonus(k)
	return s
