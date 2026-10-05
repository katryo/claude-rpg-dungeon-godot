class_name ItemData
extends Resource
## A consumable item.

enum Kind { HEAL, RESTORE_MP, REVIVE, FULL_RESTORE, HEAL_PARTY }

@export var display_name := ""
@export_multiline var description := ""
@export var kind := Kind.HEAL
## HP/MP restored, or the fraction of max HP for revival.
@export var amount := 0.0
@export var target := SkillData.Target.ALLY
