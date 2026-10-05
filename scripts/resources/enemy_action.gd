class_name EnemyAction
extends Resource
## One weighted entry in an enemy's action table.

@export var skill: SkillData
@export_range(1, 20) var weight := 1
