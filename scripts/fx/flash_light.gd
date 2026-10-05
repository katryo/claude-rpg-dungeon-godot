class_name FlashLight
extends OmniLight3D
## A brief burst of light for hits and spells.

@export var peak_energy := 4.0
@export var tint := Color.WHITE


func _ready() -> void:
	light_color = tint
	light_energy = 0.0
	var tw := create_tween()
	tw.tween_property(self, "light_energy", peak_energy, 0.06)
	tw.tween_property(self, "light_energy", 0.0, 0.5)
	tw.tween_callback(queue_free)
