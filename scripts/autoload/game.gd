extends Node
## Global game state: party, inventory, progression flags.

const DB := preload("res://scripts/data/db.gd")

signal party_changed

var party: Array = []            # Array of member dictionaries
var inventory: Dictionary = {}   # item_id -> count
var equip_bag: Dictionary = {}   # equipment_id -> count (unequipped)
var gold: int = 0
var opened_chests: Dictionary = {}
var defeated_groups: Dictionary = {}
var boss_defeated := false
var intro_seen := false
var field_position := Vector3.ZERO
var has_field_position := false
var play_time := 0.0

var _checkpoint: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	new_game()


func _process(delta: float) -> void:
	play_time += delta


func _setup_input() -> void:
	_add_keys("ui_accept", [KEY_Z, KEY_E])
	_add_keys("ui_cancel", [KEY_X, KEY_BACKSPACE])
	_add_keys("ui_up", [KEY_W])
	_add_keys("ui_down", [KEY_S])
	_add_keys("ui_left", [KEY_A])
	_add_keys("ui_right", [KEY_D])
	if not InputMap.has_action("menu"):
		InputMap.add_action("menu")
	_add_keys("menu", [KEY_TAB, KEY_M, KEY_C])
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_Y
	InputMap.action_add_event("menu", joy)
	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")
	_add_keys("dash", [KEY_SHIFT])


func _add_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


# ------------------------------------------------------------------ Setup ---
func new_game() -> void:
	party.clear()
	for id in DB.PARTY_ORDER:
		var h: Dictionary = DB.HEROES[id]
		var m := {
			"id": id,
			"name": h.name,
			"level": DB.START_LEVEL,
			"exp": exp_for_level(DB.START_LEVEL),
			"equip": h.equip.duplicate(),
			"skills": [],
			"hp": 1,
			"mp": 1,
		}
		_learn_skills(m)
		m.hp = max_hp(m)
		m.mp = max_mp(m)
		party.append(m)
	inventory = {"potion": 6, "ether": 3, "phoenix": 2}
	equip_bag = {}
	gold = 120
	opened_chests = {}
	defeated_groups = {}
	boss_defeated = false
	intro_seen = false
	has_field_position = false
	play_time = 0.0
	save_checkpoint()


func save_checkpoint() -> void:
	_checkpoint = {
		"party": party.duplicate(true),
		"inventory": inventory.duplicate(),
		"equip_bag": equip_bag.duplicate(),
		"gold": gold,
		"opened_chests": opened_chests.duplicate(),
		"defeated_groups": defeated_groups.duplicate(),
		"field_position": field_position,
		"has_field_position": has_field_position,
		"intro_seen": intro_seen,
	}


func load_checkpoint() -> void:
	if _checkpoint.is_empty():
		new_game()
		return
	party = _checkpoint.party.duplicate(true)
	inventory = _checkpoint.inventory.duplicate()
	equip_bag = _checkpoint.equip_bag.duplicate()
	gold = _checkpoint.gold
	opened_chests = _checkpoint.opened_chests.duplicate()
	defeated_groups = _checkpoint.defeated_groups.duplicate()
	field_position = _checkpoint.field_position
	has_field_position = _checkpoint.has_field_position
	intro_seen = _checkpoint.intro_seen
	boss_defeated = false


# ------------------------------------------------------------------ Stats ---
func base_stat(m: Dictionary, key: String) -> int:
	var h: Dictionary = DB.HEROES[m.id]
	return int(h.base[key] + h.growth[key] * (m.level - 1))


func equip_bonus(m: Dictionary, key: String) -> int:
	var total := 0
	for slot in DB.SLOTS:
		var eid: String = m.equip.get(slot, "")
		if eid != "":
			total += int(DB.EQUIPMENT[eid].stats.get(key, 0))
	return total


func stat(m: Dictionary, key: String) -> int:
	return base_stat(m, key) + equip_bonus(m, key)


func max_hp(m: Dictionary) -> int:
	return stat(m, "hp")


func max_mp(m: Dictionary) -> int:
	return stat(m, "mp")


func is_alive(m: Dictionary) -> bool:
	return m.hp > 0


func member(id: String) -> Dictionary:
	for m in party:
		if m.id == id:
			return m
	return {}


func clamp_vitals(m: Dictionary) -> void:
	m.hp = clampi(m.hp, 0, max_hp(m))
	m.mp = clampi(m.mp, 0, max_mp(m))


func full_restore() -> void:
	for m in party:
		m.hp = max_hp(m)
		m.mp = max_mp(m)
	party_changed.emit()


# --------------------------------------------------------------- Leveling ---
func exp_for_level(level: int) -> int:
	return 15 * level * level


func exp_to_next(m: Dictionary) -> int:
	return max(0, exp_for_level(m.level + 1) - m.exp)


## Grants EXP to a member. Returns an array of message strings (level ups / new skills).
func gain_exp(m: Dictionary, amount: int) -> Array:
	var msgs: Array = []
	if not is_alive(m):
		return msgs
	m.exp += amount
	while m.exp >= exp_for_level(m.level + 1) and m.level < 99:
		var old_hp := max_hp(m)
		var old_mp := max_mp(m)
		m.level += 1
		m.hp += max_hp(m) - old_hp
		m.mp += max_mp(m) - old_mp
		msgs.append("%s reached level %d!" % [m.name, m.level])
		for s in _learn_skills(m):
			msgs.append("%s learned %s!" % [m.name, DB.SKILLS[s].name])
	return msgs


func _learn_skills(m: Dictionary) -> Array:
	var learned: Array = []
	var table: Dictionary = DB.HEROES[m.id].skills
	var levels := table.keys()
	levels.sort()
	for lv in levels:
		if lv <= m.level:
			for s in table[lv]:
				if not m.skills.has(s):
					m.skills.append(s)
					learned.append(s)
	return learned


# -------------------------------------------------------------- Inventory ---
func add_item(id: String, n: int = 1) -> void:
	inventory[id] = inventory.get(id, 0) + n


func remove_item(id: String, n: int = 1) -> void:
	inventory[id] = inventory.get(id, 0) - n
	if inventory[id] <= 0:
		inventory.erase(id)


func item_list() -> Array:
	var ids := inventory.keys()
	ids.sort_custom(func(a, b): return DB.ITEMS.keys().find(a) < DB.ITEMS.keys().find(b))
	return ids


func add_equipment(id: String, n: int = 1) -> void:
	equip_bag[id] = equip_bag.get(id, 0) + n


func can_equip(m: Dictionary, eid: String) -> bool:
	var who: Array = DB.EQUIPMENT[eid].who
	return who.is_empty() or who.has(m.id)


## Candidates from the bag that member m can wear in slot.
func equip_candidates(m: Dictionary, slot: String) -> Array:
	var out: Array = []
	for eid in equip_bag.keys():
		if equip_bag[eid] > 0 and DB.EQUIPMENT[eid].slot == slot and can_equip(m, eid):
			out.append(eid)
	return out


func equip(m: Dictionary, slot: String, eid: String) -> void:
	var old: String = m.equip.get(slot, "")
	if old != "":
		add_equipment(old)
	if eid != "":
		equip_bag[eid] -= 1
		if equip_bag[eid] <= 0:
			equip_bag.erase(eid)
	m.equip[slot] = eid
	clamp_vitals(m)
	party_changed.emit()


## Stats member m would have with eid in slot (for preview).
func preview_stats(m: Dictionary, slot: String, eid: String) -> Dictionary:
	var copy := m.duplicate(true)
	copy.equip[slot] = eid
	var out := {}
	for k in DB.STAT_KEYS:
		out[k] = stat(copy, k)
	return out


func format_time() -> String:
	var t := int(play_time)
	return "%d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]
