class_name GameStartData
extends Resource
## Initial state for a new game.

@export var party: Array[HeroData] = []
@export var start_level := 5
@export var start_gold := 120
@export var items: Dictionary[ItemData, int] = {}
## Equipped on the first party member who can wear each piece.
@export var starting_equipment: Array[EquipmentData] = []
