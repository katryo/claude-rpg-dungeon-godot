class_name Battler
extends RefCounted
## A combatant in battle. Heroes read/write HP and MP straight through to their
## PartyMember so damage persists after the fight.

var display_name := ""
var member: PartyMember        # heroes
var enemy: EnemyData           # enemies
var is_hero: bool:
	get:
		return member != null
var is_boss: bool:
	get:
		return enemy != null and enemy.is_boss
var flying: bool:
	get:
		return enemy != null and enemy.flying

var buffs: Dictionary = {}   # stat -> {"mult": float, "turns": int}
var defending := false
var provoke := 0
var charging := false
var phase := 1

var view: CharacterSprite
var home := Vector3.ZERO

var _hp := 0


static func from_member(m: PartyMember) -> Battler:
	var b := Battler.new()
	b.member = m
	b.display_name = m.display_name
	return b


static func from_enemy(e: EnemyData, suffix: String) -> Battler:
	var b := Battler.new()
	b.enemy = e
	b.display_name = e.display_name + suffix
	b._hp = e.hp
	return b


var hp: int:
	get:
		return member.hp if member else _hp
	set(v):
		v = clampi(v, 0, max_hp())
		if member:
			member.hp = v
		else:
			_hp = v

var mp: int:
	get:
		return member.mp if member else 999
	set(v):
		if member:
			member.mp = clampi(v, 0, max_mp())


func max_hp() -> int:
	return member.max_hp() if member else enemy.hp


func max_mp() -> int:
	return member.max_mp() if member else 999


func alive() -> bool:
	return hp > 0


func stat(key: String) -> float:
	var v := float(member.stat(key) if member else enemy.stat(key))
	if buffs.has(key):
		v *= buffs[key].mult
	if is_boss and phase >= 2 and (key == "atk" or key == "mag"):
		v *= 1.15
	return v


func add_modifier(mod: StatModifier, extra_turns := 0) -> void:
	buffs[mod.stat] = {"mult": mod.multiplier, "turns": mod.turns + extra_turns}


func is_weak_to(el: SkillData.Element) -> bool:
	return enemy != null and enemy.is_weak_to(el)


func resists(el: SkillData.Element) -> bool:
	return enemy != null and enemy.resists(el)


## Called at the end of this battler's turn.
func tick() -> void:
	for k in buffs.keys():
		buffs[k].turns -= 1
		if buffs[k].turns <= 0:
			buffs.erase(k)
	if provoke > 0:
		provoke -= 1


func skills() -> Array[SkillData]:
	var none: Array[SkillData] = []
	return member.skills if member else none


func icon() -> Texture2D:
	return member.hero.portrait if member else enemy.sprite_frames.get_frame_texture(&"idle", 0)
