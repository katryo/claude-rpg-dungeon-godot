extends Node
## Global game state: party, inventory, progression flags and checkpoints.

signal party_changed

const NEW_GAME_PATH := "res://data/new_game.tres"

var party: Array[PartyMember] = []
var inventory: Dictionary[ItemData, int] = {}
var equip_bag: Dictionary[EquipmentData, int] = {}
var gold := 0
var opened_chests: Dictionary[StringName, bool] = {}
var defeated_enemies: Dictionary[StringName, bool] = {}
var boss_defeated := false
var intro_seen := false
var field_position := Vector3.ZERO
var has_field_position := false
var play_time := 0.0

var _checkpoint: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	new_game()


func _process(delta: float) -> void:
	play_time += delta


func new_game() -> void:
	var start: GameStartData = load(NEW_GAME_PATH)
	party.clear()
	for h: HeroData in start.party:
		var m := PartyMember.create(h, start.start_level)
		m.experience = exp_for_level(m.level)
		party.append(m)
	for e: EquipmentData in start.starting_equipment:
		for m in party:
			if e.can_be_equipped_by(m.hero) and m.get_equipment(e.slot) == null:
				m.set_equipment(e.slot, e)
				break
	for m in party:
		m.hp = m.max_hp()
		m.mp = m.max_mp()
	inventory = start.items.duplicate()
	equip_bag.clear()
	gold = start.start_gold
	opened_chests.clear()
	defeated_enemies.clear()
	boss_defeated = false
	intro_seen = false
	has_field_position = false
	play_time = 0.0
	save_checkpoint()


func save_checkpoint() -> void:
	_checkpoint = {
		"party": party.map(func(m: PartyMember): return m.clone()),
		"inventory": inventory.duplicate(),
		"equip_bag": equip_bag.duplicate(),
		"gold": gold,
		"opened_chests": opened_chests.duplicate(),
		"defeated_enemies": defeated_enemies.duplicate(),
		"field_position": field_position,
		"has_field_position": has_field_position,
		"intro_seen": intro_seen,
	}


func load_checkpoint() -> void:
	party.assign(_checkpoint.party.map(func(m: PartyMember): return m.clone()))
	inventory = _checkpoint.inventory.duplicate()
	equip_bag = _checkpoint.equip_bag.duplicate()
	gold = _checkpoint.gold
	opened_chests = _checkpoint.opened_chests.duplicate()
	defeated_enemies = _checkpoint.defeated_enemies.duplicate()
	field_position = _checkpoint.field_position
	has_field_position = _checkpoint.has_field_position
	intro_seen = _checkpoint.intro_seen
	boss_defeated = false


func full_restore() -> void:
	for m in party:
		m.hp = m.max_hp()
		m.mp = m.max_mp()
	party_changed.emit()


# --------------------------------------------------------------- Leveling ---
func exp_for_level(level: int) -> int:
	return 15 * level * level


func exp_to_next(m: PartyMember) -> int:
	return maxi(0, exp_for_level(m.level + 1) - m.experience)


## Grants EXP to a member. Returns messages for level ups and new skills.
func gain_exp(m: PartyMember, amount: int) -> Array[String]:
	var msgs: Array[String] = []
	if not m.is_alive():
		return msgs
	m.experience += amount
	while m.experience >= exp_for_level(m.level + 1) and m.level < 99:
		var old_hp := m.max_hp()
		var old_mp := m.max_mp()
		m.level += 1
		m.hp += m.max_hp() - old_hp
		m.mp += m.max_mp() - old_mp
		msgs.append("%s reached level %d!" % [m.display_name, m.level])
		for s in m.hero.skills_up_to(m.level):
			if not m.skills.has(s):
				m.skills.append(s)
				msgs.append("%s learned %s!" % [m.display_name, s.display_name])
	return msgs


# -------------------------------------------------------------- Inventory ---
func add_item(item: ItemData, n: int = 1) -> void:
	inventory[item] = inventory.get(item, 0) + n


func remove_item(item: ItemData, n: int = 1) -> void:
	inventory[item] = inventory.get(item, 0) - n
	if inventory[item] <= 0:
		inventory.erase(item)


func item_list() -> Array[ItemData]:
	var out: Array[ItemData] = []
	out.assign(inventory.keys())
	return out


func add_equipment(e: EquipmentData, n: int = 1) -> void:
	equip_bag[e] = equip_bag.get(e, 0) + n


## Equipment in the bag that member m can wear in slot.
func equip_candidates(m: PartyMember, slot: EquipmentData.Slot) -> Array[EquipmentData]:
	var out: Array[EquipmentData] = []
	for e in equip_bag:
		if equip_bag[e] > 0 and e.slot == slot and e.can_be_equipped_by(m.hero):
			out.append(e)
	return out


func equip(m: PartyMember, slot: EquipmentData.Slot, e: EquipmentData) -> void:
	var old := m.get_equipment(slot)
	if old:
		add_equipment(old)
	if e:
		equip_bag[e] -= 1
		if equip_bag[e] <= 0:
			equip_bag.erase(e)
	m.set_equipment(slot, e)
	m.clamp_vitals()
	party_changed.emit()


## Stats member m would have with e in slot (for the equipment preview).
func preview_stats(m: PartyMember, slot: EquipmentData.Slot, e: EquipmentData) -> Dictionary:
	var copy := m.clone()
	copy.set_equipment(slot, e)
	var out := {}
	for k in HeroData.STAT_KEYS:
		out[k] = copy.stat(k)
	return out


## Applies an item outside battle. Returns false if it would have no effect.
func use_item_on(item: ItemData, m: PartyMember) -> bool:
	match item.kind:
		ItemData.Kind.HEAL, ItemData.Kind.HEAL_PARTY:
			if not m.is_alive() or m.hp >= m.max_hp():
				return false
			m.hp = mini(m.max_hp(), m.hp + int(item.amount))
		ItemData.Kind.RESTORE_MP:
			if not m.is_alive() or m.mp >= m.max_mp():
				return false
			m.mp = mini(m.max_mp(), m.mp + int(item.amount))
		ItemData.Kind.FULL_RESTORE:
			if not m.is_alive():
				return false
			m.hp = m.max_hp()
			m.mp = m.max_mp()
		ItemData.Kind.REVIVE:
			if m.is_alive():
				return false
			m.hp = maxi(1, int(m.max_hp() * item.amount))
	return true


## HP restored by a healing skill cast by `caster`.
func heal_amount(caster_magic: float, skill: SkillData) -> int:
	return int(skill.power * (caster_magic * 2.0 + 30.0))


func format_time() -> String:
	var t := int(play_time)
	return "%d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]
