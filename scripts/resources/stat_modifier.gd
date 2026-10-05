class_name StatModifier
extends Resource
## A temporary multiplier applied to one stat for a number of turns.

@export_enum("atk", "def", "mag", "mdf", "spd") var stat: String = "atk"
@export var multiplier := 1.0
@export var turns := 3
