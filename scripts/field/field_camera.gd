class_name FieldCamera
extends Camera3D
## HD-2D style follow camera: a fixed high angle with a long, narrow lens.

@export var target: Node3D
@export_range(10.0, 80.0) var pitch_degrees := 34.0
@export var distance := 17.0
@export var focus_height := 0.8
@export var smoothing := 5.0


func _process(delta: float) -> void:
	_follow(clampf(delta * smoothing, 0.0, 1.0))


func snap() -> void:
	_follow(1.0)


func _follow(weight: float) -> void:
	if target == null:
		return
	var pitch := deg_to_rad(pitch_degrees)
	var offset := Vector3(0, sin(pitch), cos(pitch)) * distance
	position = position.lerp(target.global_position + Vector3(0, focus_height, 0) + offset, weight)
	look_at(position - offset, Vector3.UP)
