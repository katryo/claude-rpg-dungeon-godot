extends RefCounted
## Static game database: heroes, skills, items, equipment, enemies and the castle map.

const STAT_KEYS := ["hp", "mp", "atk", "def", "mag", "mdf", "spd"]
const STAT_NAMES := {
	"hp": "Max HP", "mp": "Max MP", "atk": "Attack", "def": "Defense",
	"mag": "Magic", "mdf": "Spirit", "spd": "Speed",
}
const SLOTS := ["weapon", "head", "body", "accessory"]
const SLOT_NAMES := {"weapon": "Weapon", "head": "Head", "body": "Body", "accessory": "Accessory"}

const ELEMENT_COLORS := {
	"none": Color(1.0, 0.95, 0.85),
	"fire": Color(1.0, 0.45, 0.15),
	"ice": Color(0.45, 0.85, 1.0),
	"thunder": Color(1.0, 0.92, 0.3),
	"holy": Color(1.0, 0.95, 0.6),
	"dark": Color(0.65, 0.25, 1.0),
	"heal": Color(0.4, 1.0, 0.55),
	"buff": Color(1.0, 0.75, 0.3),
}

# ---------------------------------------------------------------- Heroes ----
# Stats at level L = base + growth * (L - 1)
const HEROES := {
	"arlen": {
		"name": "Arlen",
		"job": "Magic Warrior",
		"sprite": "arlen",
		"bio": "A young spellblade from the border village of Eldmoor. He fuses sword and sorcery, imbuing his blade with the elements.",
		"base": {"hp": 120, "mp": 30, "atk": 20, "def": 14, "mag": 15, "mdf": 12, "spd": 14},
		"growth": {"hp": 18, "mp": 5, "atk": 3.0, "def": 2.0, "mag": 2.5, "mdf": 2.0, "spd": 1.5},
		"skills": {1: ["flame_blade", "cure"], 5: ["thunder_slash"], 7: ["arcane_edge"], 9: ["lumina_blade"]},
		"equip": {"weapon": "rune_saber", "head": "leather_band", "body": "mythril_mail", "accessory": ""},
	},
	"garrick": {
		"name": "Garrick",
		"job": "Armored Warrior",
		"sprite": "garrick",
		"bio": "Arlen's sworn shield and oldest friend. Clad in heavy plate, he stands between his companions and every blow.",
		"base": {"hp": 160, "mp": 12, "atk": 22, "def": 22, "mag": 6, "mdf": 10, "spd": 9},
		"growth": {"hp": 24, "mp": 2, "atk": 3.0, "def": 3.0, "mag": 0.8, "mdf": 1.5, "spd": 1.0},
		"skills": {1: ["shield_bash", "provoke"], 5: ["iron_wall"], 7: ["war_cry"], 9: ["earthsplitter"]},
		"equip": {"weapon": "knight_sword", "head": "great_helm", "body": "plate_armor", "accessory": ""},
	},
	"theia": {
		"name": "Theia",
		"job": "Arch Mage",
		"sprite": "theia",
		"bio": "Oracle-born arch mage of the Delphic Order, robed in the chiton of the old gods. Her wand channels starfire itself.",
		"base": {"hp": 90, "mp": 50, "atk": 8, "def": 9, "mag": 24, "mdf": 20, "spd": 12},
		"growth": {"hp": 12, "mp": 8, "atk": 1.0, "def": 1.2, "mag": 3.5, "mdf": 2.8, "spd": 1.3},
		"skills": {1: ["fire", "blizzard", "thunder", "heal_all"], 5: ["raise", "focus"], 8: ["meteor"], 10: ["holy"]},
		"equip": {"weapon": "oak_wand", "head": "laurel_wreath", "body": "delphic_chiton", "accessory": ""},
	},
}
const PARTY_ORDER := ["arlen", "garrick", "theia"]
const START_LEVEL := 5

# ---------------------------------------------------------------- Skills ----
# kind: phys | magic | heal | revive | buff | provoke
# target: enemy | all_enemies | ally | all_allies | self | dead_ally
const SKILLS := {
	# Arlen
	"flame_blade": {"name": "Flame Blade", "mp": 6, "kind": "phys", "element": "fire", "power": 1.6, "target": "enemy",
		"desc": "Wreathes the blade in fire. Fire physical damage to one foe."},
	"thunder_slash": {"name": "Thunder Slash", "mp": 6, "kind": "phys", "element": "thunder", "power": 1.6, "target": "enemy",
		"desc": "A lightning-charged strike. Thunder physical damage to one foe."},
	"cure": {"name": "Cure", "mp": 7, "kind": "heal", "element": "heal", "power": 1.0, "target": "ally", "field": true,
		"desc": "Restores HP to one ally."},
	"arcane_edge": {"name": "Arcane Edge", "mp": 14, "kind": "phys", "element": "none", "power": 1.2, "target": "all_enemies",
		"desc": "Releases a crescent of arcane force that cuts through all foes."},
	"lumina_blade": {"name": "Lumina Blade", "mp": 20, "kind": "phys", "element": "holy", "power": 2.7, "target": "enemy",
		"desc": "The secret art of the spellblade. Massive holy damage to one foe."},
	# Garrick
	"shield_bash": {"name": "Shield Bash", "mp": 4, "kind": "phys", "element": "none", "power": 1.3, "target": "enemy",
		"debuff": {"stat": "atk", "mult": 0.75, "turns": 3},
		"desc": "Slams a foe with the shield, lowering its Attack."},
	"provoke": {"name": "Provoke", "mp": 3, "kind": "provoke", "element": "buff", "power": 0, "target": "self",
		"desc": "Draws all enemy attacks to Garrick for 3 turns and raises his Defense."},
	"iron_wall": {"name": "Iron Wall", "mp": 8, "kind": "buff", "element": "buff", "power": 0, "target": "all_allies",
		"buff": {"stat": "def", "mult": 1.5, "turns": 3}, "buff2": {"stat": "mdf", "mult": 1.3, "turns": 3},
		"desc": "Raises the Defense and Spirit of the whole party."},
	"war_cry": {"name": "War Cry", "mp": 8, "kind": "buff", "element": "buff", "power": 0, "target": "all_allies",
		"buff": {"stat": "atk", "mult": 1.4, "turns": 3},
		"desc": "A thunderous battle cry that raises the party's Attack."},
	"earthsplitter": {"name": "Earthsplitter", "mp": 12, "kind": "phys", "element": "none", "power": 1.4, "target": "all_enemies",
		"desc": "Cleaves the ground itself, striking all foes."},
	# Theia
	"fire": {"name": "Fira", "mp": 6, "kind": "magic", "element": "fire", "power": 1.5, "target": "enemy",
		"desc": "Calls down searing flame on one foe."},
	"blizzard": {"name": "Blizzara", "mp": 6, "kind": "magic", "element": "ice", "power": 1.5, "target": "enemy",
		"desc": "Encases one foe in a storm of ice."},
	"thunder": {"name": "Thundara", "mp": 6, "kind": "magic", "element": "thunder", "power": 1.5, "target": "enemy",
		"desc": "Strikes one foe with a bolt from the heavens."},
	"heal_all": {"name": "Asclepius' Grace", "mp": 12, "kind": "heal", "element": "heal", "power": 0.75, "target": "all_allies", "field": true,
		"desc": "The healing light of Asclepius restores HP to the whole party."},
	"raise": {"name": "Anastasis", "mp": 16, "kind": "revive", "element": "heal", "power": 0.4, "target": "dead_ally", "field": true,
		"desc": "Returns a fallen ally to life with 40% HP."},
	"focus": {"name": "Athena's Insight", "mp": 5, "kind": "buff", "element": "buff", "power": 0, "target": "self",
		"buff": {"stat": "mag", "mult": 1.5, "turns": 3},
		"desc": "Clears the mind, raising Theia's Magic for 3 turns."},
	"meteor": {"name": "Meteor", "mp": 24, "kind": "magic", "element": "none", "power": 1.6, "target": "all_enemies",
		"desc": "Rains fragments of falling stars upon all foes."},
	"holy": {"name": "Holy", "mp": 22, "kind": "magic", "element": "holy", "power": 3.0, "target": "enemy",
		"desc": "Pure radiance of Olympus. Devastating holy damage to one foe."},
	# Enemy skills
	"e_attack": {"name": "Attack", "mp": 0, "kind": "phys", "element": "none", "power": 1.0, "target": "enemy"},
	"bone_crush": {"name": "Bone Crush", "mp": 0, "kind": "phys", "element": "none", "power": 1.45, "target": "enemy"},
	"stone_breath": {"name": "Stone Breath", "mp": 0, "kind": "magic", "element": "none", "power": 0.7, "target": "all_enemies"},
	"dark_bolt": {"name": "Dark Bolt", "mp": 0, "kind": "magic", "element": "dark", "power": 1.3, "target": "enemy"},
	"e_fire": {"name": "Hellflame", "mp": 0, "kind": "magic", "element": "fire", "power": 0.8, "target": "all_enemies"},
	"cleave": {"name": "Cleave", "mp": 0, "kind": "phys", "element": "none", "power": 0.8, "target": "all_enemies"},
	"flame_breath": {"name": "Flame Breath", "mp": 0, "kind": "magic", "element": "fire", "power": 0.85, "target": "all_enemies"},
	"dark_nova": {"name": "Dark Nova", "mp": 0, "kind": "magic", "element": "dark", "power": 1.0, "target": "all_enemies"},
	"soul_drain": {"name": "Soul Drain", "mp": 0, "kind": "magic", "element": "dark", "power": 1.4, "target": "enemy", "drain": true},
	"hellfire": {"name": "Hellfire", "mp": 0, "kind": "magic", "element": "fire", "power": 1.9, "target": "enemy"},
	"dread_gaze": {"name": "Dread Gaze", "mp": 0, "kind": "debuff", "element": "dark", "power": 0, "target": "all_enemies",
		"debuff": {"stat": "def", "mult": 0.7, "turns": 3}},
	"abyss_charge": {"name": "Gathering Darkness", "mp": 0, "kind": "charge", "element": "dark", "power": 0, "target": "self"},
	"abyssal_ruin": {"name": "Abyssal Ruin", "mp": 0, "kind": "magic", "element": "dark", "power": 1.9, "target": "all_enemies"},
}

# ----------------------------------------------------------------- Items ----
const ITEMS := {
	"potion": {"name": "Potion", "kind": "heal", "amount": 150, "target": "ally", "desc": "Restores 150 HP to one ally."},
	"hi_potion": {"name": "Hi-Potion", "kind": "heal", "amount": 400, "target": "ally", "desc": "Restores 400 HP to one ally."},
	"ether": {"name": "Ether", "kind": "mp", "amount": 40, "target": "ally", "desc": "Restores 40 MP to one ally."},
	"phoenix": {"name": "Phoenix Down", "kind": "revive", "amount": 0.3, "target": "dead_ally", "desc": "Revives a fallen ally with 30% HP."},
	"elixir": {"name": "Elixir", "kind": "full", "amount": 0, "target": "ally", "desc": "Fully restores the HP and MP of one ally."},
	"ambrosia": {"name": "Ambrosia", "kind": "heal_all", "amount": 300, "target": "all_allies", "desc": "Food of the gods. Restores 300 HP to the party."},
}

# ------------------------------------------------------------- Equipment ----
const EQUIPMENT := {
	# Weapons
	"rune_saber": {"name": "Rune Saber", "slot": "weapon", "who": ["arlen"], "stats": {"atk": 12, "mag": 5}, "desc": "A sword etched with glowing runes."},
	"starlight_blade": {"name": "Starlight Blade", "slot": "weapon", "who": ["arlen"], "stats": {"atk": 26, "mag": 12}, "desc": "Forged from a fallen star. Hums with power."},
	"knight_sword": {"name": "Knight's Sword", "slot": "weapon", "who": ["garrick"], "stats": {"atk": 14}, "desc": "A sturdy blade of the royal guard."},
	"bastion_blade": {"name": "Bastion Blade", "slot": "weapon", "who": ["garrick"], "stats": {"atk": 28, "def": 6}, "desc": "Heavy as a castle gate, and as unyielding."},
	"oak_wand": {"name": "Oak Wand", "slot": "weapon", "who": ["theia"], "stats": {"atk": 3, "mag": 10, "mp": 10}, "desc": "Carved from the sacred oak of Dodona."},
	"olympian_scepter": {"name": "Olympian Scepter", "slot": "weapon", "who": ["theia"], "stats": {"atk": 6, "mag": 24, "mp": 25}, "desc": "Once wielded by the oracles of Olympus."},
	# Head
	"leather_band": {"name": "Leather Band", "slot": "head", "who": ["arlen"], "stats": {"def": 3}, "desc": "A simple headband. Keeps the hair out of your eyes."},
	"great_helm": {"name": "Great Helm", "slot": "head", "who": ["garrick"], "stats": {"def": 8, "mdf": 2}, "desc": "A full steel helm with a crimson crest."},
	"laurel_wreath": {"name": "Laurel Wreath", "slot": "head", "who": ["theia"], "stats": {"mag": 4, "mdf": 6}, "desc": "Woven from the laurels of Delphi."},
	"mythril_helm": {"name": "Mythril Helm", "slot": "head", "who": ["arlen", "garrick"], "stats": {"def": 12, "mdf": 6}, "desc": "Light and nearly unbreakable."},
	"circlet_of_muses": {"name": "Circlet of Muses", "slot": "head", "who": ["theia"], "stats": {"mag": 10, "mdf": 12, "mp": 15}, "desc": "Blessed by the nine Muses."},
	# Body
	"mythril_mail": {"name": "Mythril Mail", "slot": "body", "who": ["arlen"], "stats": {"def": 10, "mdf": 4}, "desc": "Fine chain mail of mythril links."},
	"plate_armor": {"name": "Plate Armor", "slot": "body", "who": ["garrick"], "stats": {"def": 16}, "desc": "Thick steel plate. Heavy, but safe."},
	"titan_plate": {"name": "Titan Plate", "slot": "body", "who": ["garrick"], "stats": {"def": 30, "mdf": 8, "hp": 60}, "desc": "Said to be forged for the Titans themselves."},
	"delphic_chiton": {"name": "Delphic Chiton", "slot": "body", "who": ["theia"], "stats": {"def": 5, "mdf": 10}, "desc": "Ceremonial robe of the Delphic Order."},
	"aegis_cuirass": {"name": "Aegis Cuirass", "slot": "body", "who": ["arlen"], "stats": {"def": 22, "mdf": 10, "hp": 40}, "desc": "Bears the visage of a gorgon. Foes hesitate."},
	# Accessories
	"power_ring": {"name": "Power Ring", "slot": "accessory", "who": [], "stats": {"atk": 10}, "desc": "Strength flows from the ruby set within."},
	"sage_pendant": {"name": "Sage's Pendant", "slot": "accessory", "who": [], "stats": {"mag": 12, "mp": 20}, "desc": "A pendant once worn by a great sage."},
	"guardian_charm": {"name": "Guardian Charm", "slot": "accessory", "who": [], "stats": {"def": 8, "mdf": 8}, "desc": "Wards off harm of every kind."},
	"hermes_sandals": {"name": "Hermes' Sandals", "slot": "accessory", "who": [], "stats": {"spd": 10}, "desc": "Winged sandals of the messenger god."},
}

# --------------------------------------------------------------- Enemies ----
const ENEMIES := {
	"skeleton": {"name": "Skeleton Knight", "sprite": "skeleton", "scale": 1.0,
		"stats": {"hp": 170, "atk": 32, "def": 16, "mag": 8, "mdf": 10, "spd": 10},
		"exp": 40, "gold": 18, "weak": ["holy", "fire"], "resist": ["dark", "ice"],
		"actions": [["e_attack", 7], ["bone_crush", 3]]},
	"gargoyle": {"name": "Gargoyle", "sprite": "gargoyle", "scale": 1.05, "fly": true,
		"stats": {"hp": 150, "atk": 30, "def": 26, "mag": 20, "mdf": 14, "spd": 16},
		"exp": 46, "gold": 22, "weak": ["thunder"], "resist": ["ice"],
		"actions": [["e_attack", 6], ["stone_breath", 3]]},
	"sorcerer": {"name": "Dark Sorcerer", "sprite": "sorcerer", "scale": 1.0,
		"stats": {"hp": 130, "atk": 12, "def": 10, "mag": 34, "mdf": 26, "spd": 13},
		"exp": 50, "gold": 30, "weak": ["holy"], "resist": ["dark"],
		"actions": [["dark_bolt", 6], ["e_fire", 3]]},
	"armor": {"name": "Living Armor", "sprite": "armor", "scale": 1.15,
		"stats": {"hp": 300, "atk": 40, "def": 36, "mag": 5, "mdf": 10, "spd": 7},
		"exp": 72, "gold": 40, "weak": ["thunder"], "resist": [],
		"actions": [["e_attack", 6], ["cleave", 3]]},
	"hellhound": {"name": "Hellbeast", "sprite": "hellhound", "scale": 1.2,
		"stats": {"hp": 200, "atk": 35, "def": 18, "mag": 26, "mdf": 14, "spd": 18},
		"exp": 56, "gold": 26, "weak": ["ice"], "resist": ["fire"],
		"actions": [["e_attack", 6], ["flame_breath", 3]]},
	"dark_lord": {"name": "Dark Lord Malzeth", "sprite": "dark_lord", "scale": 2.0, "boss": true,
		"stats": {"hp": 3400, "atk": 50, "def": 30, "mag": 48, "mdf": 30, "spd": 20},
		"exp": 0, "gold": 0, "weak": [], "resist": ["dark"],
		"actions": [["e_attack", 4], ["dark_nova", 3], ["soul_drain", 2], ["hellfire", 3], ["dread_gaze", 1]]},
}

# Enemy groups, in the order their 'E' markers appear on the map (row-major).
const ENCOUNTERS := [
	["armor", "sorcerer", "armor"],      # guardians of the throne corridor
	["gargoyle", "sorcerer", "gargoyle"],
	["hellhound", "hellhound"],
	["skeleton", "skeleton"],
	["gargoyle", "gargoyle"],
	["skeleton", "sorcerer", "skeleton"],
	["hellhound", "skeleton"],
]

# Field sprite for each encounter (the group "leader").
static func encounter_leader(idx: int) -> String:
	return ENCOUNTERS[idx][0]

# Chests, in the order their 'C' markers appear on the map (row-major).
const CHESTS := [
	{"equip": ["olympian_scepter"]},
	{"equip": ["starlight_blade"]},
	{"items": {"hi_potion": 3, "elixir": 1}, "equip": ["bastion_blade"]},
	{"equip": ["guardian_charm", "mythril_helm"], "items": {"ether": 2}},
	{"equip": ["titan_plate", "power_ring"]},
	{"equip": ["sage_pendant", "aegis_cuirass", "circlet_of_muses", "hermes_sandals"], "items": {"phoenix": 2, "ambrosia": 1}},
]

# ------------------------------------------------------------------- Map ----
# '#' wall  '.' floor  'r' carpet  'i' pillar  'b' brazier
# 'P' party start  'E' enemy  'C' chest  'S' save crystal  'B' the Dark Lord's throne
const MAP := [
	"###################################",
	"###################################",
	"############i..rrBrr..i############",
	"############b...rrr...b############",
	"############....rrr....############",
	"############i...rrr...i############",
	"############....rrr....############",
	"############b...rrr...b############",
	"################rrr################",
	"################.r.################",
	"################.E.################",
	"################.r.################",
	"######b.....i....r....i.....b######",
	"######.C.........r.........C.######",
	"######i.........rrr.........i######",
	"######....E.....rSr.....E....######",
	"######i.........rrr.........i######",
	"######b..........r..........b######",
	"################.r.################",
	"################.r.################",
	"#b..C....b######.r.######b....C..b#",
	"#.........######.r.######.........#",
	"#...E.....##b...rrr...b##.....E...#",
	"#...............rrr...............#",
	"#i.......i##i...rrr...i##i.......i#",
	"#....E....##....rrr....##....E....#",
	"#b.......b##b...rPr...b##b.......b#",
	"#..C......##....rrr....##......C..#",
	"############....rrr....############",
	"############b...rrr...b############",
	"###################################",
	"###################################",
]
