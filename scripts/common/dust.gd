class_name DustMotes
extends GPUParticles3D
## Drifting embers / dust motes filling a box volume.

@export var extents := Vector3(10, 3, 10)
@export var color := Color(1.0, 0.75, 0.45, 0.7)


func _ready() -> void:
	var mat := process_material.duplicate() as ParticleProcessMaterial
	mat.emission_box_extents = extents
	process_material = mat
	var m := material_override.duplicate() as StandardMaterial3D
	m.albedo_color = color
	material_override = m
	visibility_aabb = AABB(-extents - Vector3.ONE, (extents + Vector3.ONE) * 2.0)
