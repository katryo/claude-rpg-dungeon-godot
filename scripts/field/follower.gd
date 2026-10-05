class_name Follower
extends Node3D
## A party member trailing behind the leader.

@export var follow_smoothing := 0.35

@onready var visual: CharacterSprite = $Visual


func follow(target: Vector3) -> void:
	var prev := position
	position = position.lerp(target, follow_smoothing)
	var moved := position.distance_to(prev)
	if absf(position.x - prev.x) > 0.005:
		visual.flipped = position.x < prev.x
	visual.play(&"walk" if moved > 0.01 else &"idle")
