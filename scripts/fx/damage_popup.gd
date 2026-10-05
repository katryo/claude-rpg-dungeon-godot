class_name DamagePopup
extends Node3D
## Floating battle number / status text.

@export var text := "0"
@export var color := Color.WHITE
@export var text_scale := 1.0


func _ready() -> void:
	var l: Label3D = $Label
	l.text = text
	l.modulate = color
	l.font_size = int(l.font_size * text_scale)
	$AnimationPlayer.play(&"float")
	$AnimationPlayer.animation_finished.connect(func(_a): queue_free())
