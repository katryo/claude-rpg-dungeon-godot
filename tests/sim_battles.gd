extends Node
## Headless balance simulation: auto-plays every encounter in map order, then the
## Dark Lord, using a simple AI. Run:
##   godot --headless --path . res://tests/sim_battles.tscn

const DB := preload("res://scripts/data/db.gd")
const Battle := preload("res://scripts/battle/battle.gd")

# Typical route: west wing, east wing, great hall, crystal, guardian, crystal, boss.
const ROUTE := [3, 5, 4, 6, 1, 2, "rest", 0, "rest", "boss"]


func _ready() -> void:
	Engine.time_scale = 25.0
	var runs := 6
	var wins := 0
	for r in runs:
		if await _run_once(r):
			wins += 1
	print("SIM RESULT: boss won %d / %d" % [wins, runs])
	get_tree().quit()


func _run_once(run: int) -> bool:
	Game.new_game()
	for c in DB.CHESTS:
		for e in c.get("equip", []):
			Game.add_equipment(e)
		for i in c.get("items", {}):
			Game.add_item(i, c.items[i])
	_equip_best()
	for step in ROUTE:
		if step is String and step == "rest":
			Game.full_restore()
			continue
		var boss: bool = step is String and step == "boss"
		var ids: Array = ["dark_lord"] if boss else DB.ENCOUNTERS[step]
		var b := Battle.new()
		b.auto_battle = true
		b.setup(ids, boss)
		add_child(b)
		var t0 := Time.get_ticks_msec()
		var res: String = await b.finished
		if boss:
			print("   boss hp left: %d / %d" % [b.foes[0].hp, b.foes[0].max_hp()])
		remove_child(b)
		b.queue_free()
		var hp := []
		for m in Game.party:
			hp.append("%s L%d %d/%d MP%d" % [m.name, m.level, m.hp, Game.max_hp(m), m.mp])
		print("run %d  %-6s %-30s -> %s  [%s]  (%.1fs)" % [run, str(step), str(ids), res, ", ".join(hp), (Time.get_ticks_msec() - t0) / 1000.0])
		if res == "lose":
			return false
		# Revive the fallen between fights like a player would with Phoenix Downs.
		for m in Game.party:
			if m.hp <= 0:
				m.hp = 1
	return true


func _equip_best() -> void:
	for m in Game.party:
		for slot in DB.SLOTS:
			var best: String = m.equip.get(slot, "")
			var best_score := _score(best)
			for eid in Game.equip_candidates(m, slot):
				if _score(eid) > best_score:
					best = eid
					best_score = _score(eid)
			if best != m.equip.get(slot, ""):
				Game.equip(m, slot, best)
		m.hp = Game.max_hp(m)
		m.mp = Game.max_mp(m)


func _score(eid: String) -> int:
	if eid == "":
		return 0
	var s := 0
	for k in DB.EQUIPMENT[eid].stats:
		s += DB.EQUIPMENT[eid].stats[k]
	return s
