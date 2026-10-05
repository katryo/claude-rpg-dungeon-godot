class_name Player
extends CharacterBody3D
## The party leader on the field. Records a trail for the followers to walk.

@export var walk_speed := 4.6
@export var dash_speed := 7.5
@export var trail_spacing := 0.16

var controllable := true
var trail: Array[Vector3] = []
var _step_timer := 0.0

@onready var visual: CharacterSprite = $Visual
@onready var _interact_area: Area3D = $InteractArea


func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if controllable:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dashing := Input.is_action_pressed("dash")
	velocity = Vector3(dir.x, 0, dir.y) * (dash_speed if dashing else walk_speed)
	move_and_slide()
	position.y = 0.0
	if trail.is_empty() or position.distance_to(trail[0]) > trail_spacing:
		trail.push_front(position)
		if trail.size() > 64:
			trail.pop_back()
	if dir.length() > 0.1:
		visual.play(&"walk")
		visual.sprite().speed_scale = 1.5 if dashing else 1.0
		if absf(dir.x) > 0.1:
			visual.flipped = dir.x < 0.0
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.22 if dashing else 0.32
			Audio.play_sfx(&"step", randf_range(0.8, 1.2))
	else:
		visual.play(&"idle")


## Teleports the party and lines the trail up behind (south of) the leader.
func place(p: Vector3) -> void:
	position = p
	trail.clear()
	var back := p
	var space := get_world_3d().direct_space_state
	for i in 64:
		var query := PhysicsRayQueryParameters3D.create(back + Vector3.UP * 0.5, back + Vector3(0, 0.5, trail_spacing + 0.4), 1)
		if space.intersect_ray(query).is_empty():
			back += Vector3(0, 0, trail_spacing)
		trail.append(back)


func trail_point(index: int) -> Vector3:
	if trail.is_empty():
		return position
	return trail[mini(index, trail.size() - 1)]


## The nearest interactable in reach, or null.
func find_interactable() -> Interactable:
	var best: Interactable = null
	var best_d := INF
	for a in _interact_area.get_overlapping_areas():
		if a is Interactable and a.can_interact():
			var d := global_position.distance_to(a.global_position)
			if d < best_d:
				best = a
				best_d = d
	return best
