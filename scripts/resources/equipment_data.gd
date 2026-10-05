class_name EquipmentData
extends Resource
## A piece of equipment and the stat bonuses it grants.

enum Slot { WEAPON, HEAD, BODY, ACCESSORY }
const SLOT_NAMES := ["Weapon", "Head", "Body", "Accessory"]

@export var display_name := ""
@export_multiline var description := ""
@export var slot := Slot.WEAPON
## Heroes allowed to equip this. Empty means anyone.
@export var allowed_heroes: Array[HeroData] = []
@export_group("Bonuses")
@export var hp := 0
@export var mp := 0
@export var atk := 0
@export var def := 0
@export var mag := 0
@export var mdf := 0
@export var spd := 0


func bonus(stat: String) -> int:
	return int(get(stat))


func can_be_equipped_by(hero: HeroData) -> bool:
	return allowed_heroes.is_empty() or allowed_heroes.has(hero)
