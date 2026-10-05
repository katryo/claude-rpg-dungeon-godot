class_name FlickerLight
extends OmniLight3D
## Fire light with an organic flicker.

@export var base_energy := 2.6
@export var flicker_amount := 0.18

var _phase := 0.0


func _ready() -> void:
	_phase = randf() * 10.0


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var k := 1.0 - flicker_amount + flicker_amount * 0.55 * (1.0 + sin(t * 9.0 + _phase)) + flicker_amount * 0.45 * sin(t * 23.0 + _phase * 2.0)
	light_energy = base_energy * k
