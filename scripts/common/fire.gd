class_name Fire
extends Node3D
## A flickering fire: particles plus a warm light. Size and light are tunable per instance.

@export var size := 1.0
@export var light_energy := 2.6
@export var light_range := 7.0


func _ready() -> void:
	$Flames.scale = Vector3.ONE * size
	$Light.base_energy = light_energy
	$Light.omni_range = light_range
