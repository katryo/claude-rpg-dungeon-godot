@tool
class_name CharacterSprite
extends Node3D
## An HD-2D character: an animated pixel-art billboard standing on a blob shadow.
## Animations: idle, walk, attack, cast, hurt and (heroes) ko.

const BASE_PIXEL_SIZE := 0.058

@export var sprite_frames: SpriteFrames:
	set(v):
		sprite_frames = v
		_apply()
@export var sprite_scale := 1.0:
	set(v):
		sprite_scale = v
		_apply()
## Sprites are drawn facing right; flip to face left.
@export var flipped := false:
	set(v):
		flipped = v
		_apply()
@export var show_shadow := true:
	set(v):
		show_shadow = v
		_apply()

var base_y := 0.0


func _ready() -> void:
	_apply()


func _apply() -> void:
	var s := get_node_or_null("Sprite") as AnimatedSprite3D
	if s == null:
		return
	s.sprite_frames = sprite_frames
	s.pixel_size = BASE_PIXEL_SIZE * sprite_scale
	s.flip_h = flipped
	var h := frame_pixels()
	base_y = h * s.pixel_size * 0.5 - s.pixel_size
	s.position.y = base_y
	var shadow := get_node_or_null("Shadow") as MeshInstance3D
	if shadow:
		shadow.visible = show_shadow
		shadow.scale = Vector3.ONE * h * s.pixel_size * 0.5
	if sprite_frames and sprite_frames.has_animation(&"idle") and not Engine.is_editor_hint():
		s.play(&"idle")


func sprite() -> AnimatedSprite3D:
	return $Sprite


func frame_pixels() -> int:
	if sprite_frames == null or not sprite_frames.has_animation(&"idle"):
		return 32
	return sprite_frames.get_frame_texture(&"idle", 0).get_height()


## World-space height of the sprite's frame.
func height() -> float:
	return frame_pixels() * BASE_PIXEL_SIZE * sprite_scale


func play(anim: StringName) -> void:
	var s := sprite()
	if s.sprite_frames and s.sprite_frames.has_animation(anim) and s.animation != anim:
		s.play(anim)


## Plays a non-looping animation and returns to idle when it ends.
func play_once(anim: StringName) -> void:
	var s := sprite()
	if not s.sprite_frames.has_animation(anim):
		return
	s.play(anim)
	await s.animation_finished
	if s.animation == anim:
		s.play(&"idle")


func set_tint(c: Color) -> void:
	sprite().modulate = c


func get_tint() -> Color:
	return sprite().modulate


## Vertical bob offset on top of the grounded position.
func set_bob(offset: float) -> void:
	sprite().position.y = base_y + offset
