class_name HeroData
extends Resource
## Static definition of a playable hero.

const STAT_KEYS := ["hp", "mp", "atk", "def", "mag", "mdf", "spd"]
const STAT_NAMES := {
	"hp": "Max HP", "mp": "Max MP", "atk": "Attack", "def": "Defense",
	"mag": "Magic", "mdf": "Spirit", "spd": "Speed",
}

@export var display_name := ""
@export var job := ""
@export_multiline var bio := ""
@export var sprite_frames: SpriteFrames
@export var portrait: Texture2D

@export_group("Stats at level 1")
@export var base_hp := 100
@export var base_mp := 10
@export var base_atk := 10
@export var base_def := 10
@export var base_mag := 10
@export var base_mdf := 10
@export var base_spd := 10

@export_group("Growth per level")
@export var growth_hp := 10.0
@export var growth_mp := 2.0
@export var growth_atk := 2.0
@export var growth_def := 2.0
@export var growth_mag := 2.0
@export var growth_mdf := 2.0
@export var growth_spd := 1.0

@export_group("Skills")
@export var learnset: Array[LearnableSkill] = []


func stat_at(stat: String, level: int) -> int:
	return int(get("base_" + stat) + get("growth_" + stat) * (level - 1))


func skills_up_to(level: int) -> Array[SkillData]:
	var out: Array[SkillData] = []
	for entry in learnset:
		if entry.level <= level and not out.has(entry.skill):
			out.append(entry.skill)
	return out
