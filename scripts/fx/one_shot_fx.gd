class_name OneShotFX
extends Node3D
## A self-destroying visual effect. Restarts its particles, plays the "play"
## animation if present, applies an optional tint and frees itself afterwards.

@export var lifetime := 1.5
@export var tint := Color.WHITE


func _ready() -> void:
	for p in find_children("*", "GPUParticles3D", true, false):
		if tint != Color.WHITE and p.material_override is StandardMaterial3D:
			var m := p.material_override.duplicate() as StandardMaterial3D
			m.albedo_color = tint
			p.material_override = m
		p.restart()
	for l in find_children("*", "OmniLight3D", true, false):
		if tint != Color.WHITE:
			l.light_color = tint
	for mi in find_children("*", "MeshInstance3D", true, false):
		if tint != Color.WHITE and mi.material_override is StandardMaterial3D:
			var m2 := mi.material_override.duplicate() as StandardMaterial3D
			m2.albedo_color = Color(tint.r * 2.0, tint.g * 2.0, tint.b * 2.0, m2.albedo_color.a)
			mi.material_override = m2
	for s in find_children("*", "Sprite3D", true, false):
		if tint != Color.WHITE:
			s.modulate = Color(tint.r * 3.0, tint.g * 3.0, tint.b * 3.0, s.modulate.a)
	var anim := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim and anim.has_animation(&"play"):
		anim.play(&"play")
	get_tree().create_timer(lifetime, false).timeout.connect(queue_free)
