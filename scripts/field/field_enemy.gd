class_name FieldEnemy
extends CharacterBody3D
## A visible enemy group roaming the castle. Touching it starts a battle.

signal contacted(enemy: FieldEnemy)

## Unique id used to remember that this group was defeated.
@export var enemy_id: StringName
@export var encounter: Array[EnemyData] = []
## Guards do not wander or chase.
@export var stationary := false
@export var wander_radius := 2.5
@export var wander_speed := 1.2
@export var chase_speed := 3.0
@export var chase_range := 5.5

var player: Player
var cooldown := 0.0
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _wait := 0.0
var _phase := 0.0

@onready var visual: CharacterSprite = $Visual


func _ready() -> void:
	_home = position
	_target = position
	_wait = randf_range(0.5, 2.0)
	_phase = randf() * TAU
	if not encounter.is_empty():
		visual.sprite_frames = encounter[0].sprite_frames
		visual.sprite_scale = encounter[0].sprite_scale * 0.9
	$ContactArea.body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	visible = cooldown <= 0.0 or int(cooldown * 10.0) % 2 == 0
	visual.set_bob(absf(sin(Time.get_ticks_msec() / 160.0 + _phase)) * 0.1)
	if stationary or player == null:
		return
	var speed := wander_speed
	var goal := _target
	if position.distance_to(player.position) < chase_range and cooldown <= 0.0 and player.controllable:
		goal = player.position
		speed = chase_speed
	else:
		_wait -= delta
		if _wait <= 0.0:
			_wait = randf_range(1.5, 3.5)
			_target = _home + Vector3(randf_range(-wander_radius, wander_radius), 0, randf_range(-wander_radius, wander_radius))
	var d := goal - position
	d.y = 0
	velocity = d.normalized() * speed if d.length() > 0.1 else Vector3.ZERO
	if absf(d.x) > 0.05:
		visual.flipped = d.x < 0
	move_and_slide()
	position.y = 0.0


func _on_body_entered(body: Node3D) -> void:
	if body is Player and cooldown <= 0.0 and body.controllable:
		contacted.emit(self)


## After the party flees: blink and ignore the party for a few seconds.
func start_cooldown() -> void:
	cooldown = 3.0
