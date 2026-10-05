@tool
class_name StatBar
extends Control
## Slim JRPG-style gauge used for HP / MP / EXP.

@export var value := 1.0:
	set(v):
		value = v
		queue_redraw()
@export var max_value := 1.0:
	set(v):
		max_value = v
		queue_redraw()
@export var color := Color(0.35, 0.9, 0.45):
	set(v):
		color = v
		queue_redraw()
@export var border_color := Color(0.86, 0.74, 0.42, 0.8)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.0, 0.0, 0.0, 0.7))
	var k := clampf(value / maxf(1.0, max_value), 0.0, 1.0)
	if k > 0.0:
		var fill := Rect2(Vector2(1, 1), Vector2((size.x - 2) * k, size.y - 2))
		draw_rect(fill, color.darkened(0.25))
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, fill.size.y * 0.5)), color)
	draw_rect(r, border_color, false, 1.0)
