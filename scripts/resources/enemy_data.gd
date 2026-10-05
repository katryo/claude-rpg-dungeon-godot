class_name EnemyData
extends Resource
## Static definition of an enemy.

@export var display_name := ""
@export var sprite_frames: SpriteFrames
@export var sprite_scale := 1.0
@export var flying := false
@export var is_boss := false

@export_group("Stats")
@export var hp := 100
@export var atk := 10
@export var def := 10
@export var mag := 10
@export var mdf := 10
@export var spd := 10

@export_group("Rewards")
@export var exp_reward := 10
@export var gold_reward := 10

@export_group("Elements")
@export_flags("Fire", "Ice", "Thunder", "Holy", "Dark") var weaknesses := 0
@export_flags("Fire", "Ice", "Thunder", "Holy", "Dark") var resistances := 0

@export_group("AI")
@export var actions: Array[EnemyAction] = []


func stat(key: String) -> int:
	return int(get(key))


static func _bit(element: SkillData.Element) -> int:
	if element >= SkillData.Element.FIRE and element <= SkillData.Element.DARK:
		return 1 << (element - 1)
	return 0


func is_weak_to(element: SkillData.Element) -> bool:
	return weaknesses & _bit(element) != 0


func resists(element: SkillData.Element) -> bool:
	return resistances & _bit(element) != 0


func pick_action() -> SkillData:
	var total := 0
	for a in actions:
		total += a.weight
	var r := randi() % maxi(1, total)
	for a in actions:
		r -= a.weight
		if r < 0:
			return a.skill
	return actions[0].skill
