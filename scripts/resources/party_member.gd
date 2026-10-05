class_name PartyMember
extends Resource
## Runtime state of a hero in the party (level, HP/MP, equipment, skills).

@export var hero: HeroData
@export var level := 1
@export var experience := 0
@export var hp := 1
@export var mp := 1
@export var weapon: EquipmentData
@export var head: EquipmentData
@export var body: EquipmentData
@export var accessory: EquipmentData
@export var skills: Array[SkillData] = []

var display_name: String:
	get:
		return hero.display_name


static func create(h: HeroData, lv: int) -> PartyMember:
	var m := PartyMember.new()
	m.hero = h
	m.level = lv
	m.skills = h.skills_up_to(lv)
	m.hp = m.max_hp()
	m.mp = m.max_mp()
	return m


func clone() -> PartyMember:
	var m := duplicate() as PartyMember
	m.skills = skills.duplicate()
	return m


func get_equipment(slot: EquipmentData.Slot) -> EquipmentData:
	match slot:
		EquipmentData.Slot.WEAPON:
			return weapon
		EquipmentData.Slot.HEAD:
			return head
		EquipmentData.Slot.BODY:
			return body
	return accessory


func set_equipment(slot: EquipmentData.Slot, e: EquipmentData) -> void:
	match slot:
		EquipmentData.Slot.WEAPON:
			weapon = e
		EquipmentData.Slot.HEAD:
			head = e
		EquipmentData.Slot.BODY:
			body = e
		EquipmentData.Slot.ACCESSORY:
			accessory = e


func equip_bonus(stat: String) -> int:
	var total := 0
	for e in [weapon, head, body, accessory]:
		if e:
			total += e.bonus(stat)
	return total


func stat(key: String) -> int:
	return hero.stat_at(key, level) + equip_bonus(key)


func max_hp() -> int:
	return stat("hp")


func max_mp() -> int:
	return stat("mp")


func is_alive() -> bool:
	return hp > 0


func clamp_vitals() -> void:
	hp = clampi(hp, 0, max_hp())
	mp = clampi(mp, 0, max_mp())
