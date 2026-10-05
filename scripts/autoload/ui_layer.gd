extends Node
## Global UI services: dialogue window, screen transitions, vignette and toasts.
## The node tree lives in ui_layer.tscn.

var menu_open := false
var transitioning := false
var dialogue_open: bool:
	get:
		return _dialogue.is_open

@onready var _dialogue: DialogueBox = %DialogueBox
@onready var _fade_mat: ShaderMaterial = %FadeRect.material
@onready var _vignette: CanvasLayer = %VignetteLayer
@onready var _toast: PanelContainer = %Toast
@onready var _toast_label: Label = %ToastLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_toast.modulate.a = 0.0


func busy() -> bool:
	return menu_open or dialogue_open or transitioning


func say(lines: Array) -> void:
	await _dialogue.say(lines)


func set_vignette(on: bool) -> void:
	_vignette.visible = on


# ----------------------------------------------------------- Transitions ---
func _set_fade(v: float) -> void:
	_fade_mat.set_shader_parameter("fade", v)


func _set_wipe(v: float) -> void:
	_fade_mat.set_shader_parameter("wipe", v)


func fade_out(t: float = 0.5, color: Color = Color.BLACK) -> void:
	transitioning = true
	_fade_mat.set_shader_parameter("tint", color)
	var tw := create_tween()
	tw.tween_method(_set_fade, 0.0, 1.0, t)
	await tw.finished


func fade_in(t: float = 0.5) -> void:
	_set_wipe(0.0)
	var tw := create_tween()
	tw.tween_method(_set_fade, 1.0, 0.0, t)
	await tw.finished
	transitioning = false


## Classic JRPG encounter transition: two white flashes then a diamond wipe.
func battle_transition() -> void:
	transitioning = true
	Audio.play_sfx(&"encounter")
	for i in 2:
		_fade_mat.set_shader_parameter("tint", Color(1, 1, 1, 0.85))
		var tw := create_tween()
		tw.tween_method(_set_fade, 0.0, 1.0, 0.08)
		tw.tween_method(_set_fade, 1.0, 0.0, 0.12)
		await tw.finished
	_fade_mat.set_shader_parameter("tint", Color.BLACK)
	var tw2 := create_tween()
	tw2.tween_method(_set_wipe, 0.0, 1.0, 0.6)
	await tw2.finished
	_set_fade(1.0)
	_set_wipe(0.0)


func set_black() -> void:
	transitioning = true
	_fade_mat.set_shader_parameter("tint", Color.BLACK)
	_set_fade(1.0)


# ----------------------------------------------------------------- Toast ---
func notify(text: String) -> void:
	_toast_label.text = text
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
