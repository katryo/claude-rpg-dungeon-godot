extends RefCounted
## A combatant in battle. Heroes read/write HP & MP straight through to their
## party member dictionary so damage persists after the fight.

const DB := preload("res://scripts/data/db.gd")

var display_name := ""
var is_hero := false
var member: Dictionary = {}
var enemy_id := ""
var data: Dictionary = {}
var weak: Array = []
var resist: Array = []
var is_boss := false

var buffs: Dictionary = {}   # stat -> {"mult": float, "turns": int}
var defending := false
var provoke := 0
var charging := false
var phase := 1

var node: Node3D
var sprite: Sprite3D
var home := Vector3.ZERO
var base_y := 0.0

var _hp := 0
var _mp := 0


static func hero(m: Dictionary) -> RefCounted:
	var b = load("res://scripts/battle/battler.gd").new()
	b.is_hero = true
	b.member = m
	b.display_name = m.name
	return b


static func enemy(id: String, suffix: String) -> RefCounted:
	var b = load("res://scripts/battle/battler.gd").new()
	b.enemy_id = id
	b.data = DB.ENEMIES[id]
	b.display_name = b.data.name + suffix
	b.weak = b.data.weak
	b.resist = b.data.resist
	b.is_boss = b.data.get("boss", false)
	b._hp = b.data.stats.hp
	return b


var hp: int:
	get:
		return member.hp if is_hero else _hp
	set(v):
		v = clampi(v, 0, max_hp())
		if is_hero:
			member.hp = v
		else:
			_hp = v

var mp: int:
	get:
		return member.mp if is_hero else 999
	set(v):
		if is_hero:
			member.mp = clampi(v, 0, max_mp())


func max_hp() -> int:
	return Game.max_hp(member) if is_hero else int(data.stats.hp)


func max_mp() -> int:
	return Game.max_mp(member) if is_hero else 999


func alive() -> bool:
	return hp > 0


func base_stat(key: String) -> int:
	if is_hero:
		return Game.stat(member, key)
	return int(data.stats[key])


func stat(key: String) -> float:
	var v := float(base_stat(key))
	if buffs.has(key):
		v *= buffs[key].mult
	if is_boss and phase >= 2 and (key == "atk" or key == "mag"):
		v *= 1.15
	return v


func add_buff(key: String, mult: float, turns: int) -> void:
	buffs[key] = {"mult": mult, "turns": turns}


## Called at the end of this battler's turn.
func tick() -> void:
	for k in buffs.keys():
		buffs[k].turns -= 1
		if buffs[k].turns <= 0:
			buffs.erase(k)
	if provoke > 0:
		provoke -= 1


func skills() -> Array:
	return member.skills if is_hero else []
