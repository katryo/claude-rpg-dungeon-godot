class_name SkillData
extends Resource
## A battle or field skill used by heroes and enemies.

enum Kind { PHYSICAL, MAGIC, HEAL, REVIVE, BUFF, PROVOKE, DEBUFF, CHARGE }
enum Element { NONE, FIRE, ICE, THUNDER, HOLY, DARK, HEAL, BUFF }
enum Target { ENEMY, ALL_ENEMIES, ALLY, ALL_ALLIES, SELF, DEAD_ALLY }

const ELEMENT_COLORS := {
	Element.NONE: Color(1.0, 0.95, 0.85),
	Element.FIRE: Color(1.0, 0.45, 0.15),
	Element.ICE: Color(0.45, 0.85, 1.0),
	Element.THUNDER: Color(1.0, 0.92, 0.3),
	Element.HOLY: Color(1.0, 0.95, 0.6),
	Element.DARK: Color(0.65, 0.25, 1.0),
	Element.HEAL: Color(0.4, 1.0, 0.55),
	Element.BUFF: Color(1.0, 0.75, 0.3),
}

@export var display_name := ""
@export_multiline var description := ""
@export var mp_cost := 0
@export var kind := Kind.PHYSICAL
@export var element := Element.NONE
@export var power := 1.0
@export var target := Target.ENEMY
## Can be used from the field menu (healing / revival).
@export var usable_in_field := false
## Heals the user for half the damage dealt.
@export var drain := false
@export_group("Stat effects")
@export var buffs: Array[StatModifier] = []
@export var debuff: StatModifier


func color() -> Color:
	return ELEMENT_COLORS.get(element, Color.WHITE)


func is_physical() -> bool:
	return kind == Kind.PHYSICAL
